#!/usr/bin/env python3
"""Build version-pinned manual and installed-API indexes for the Godot skill.

The official Godot 4.7 manual and the exact local ``--doctool`` output remain
the sources of truth. This script only produces navigation indexes.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote

DOCS_URL_BASE = "https://docs.godotengine.org/en/4.7"
OUTDATED_RE = re.compile(r"^\s*:article_outdated:\s*true\s*$", re.IGNORECASE | re.MULTILINE)

MANUAL_ROOTS = ("about", "getting_started", "tutorials", "community")
EXCLUDED_MANUAL_PREFIXES = (
    "tutorials/scripting/c_sharp/",
    "tutorials/scripting/cpp/",
)
EXCLUDED_MANUAL_FILES = {
    # Language bindings outside the native editor/GDScript scope.
    "tutorials/scripting/cross_language_scripting.rst",
    "tutorials/scripting/other_languages.rst",
    # Engine development/embedding rather than an end-user project workflow.
    "tutorials/editor/game_embedding.rst",
    "tutorials/editor/using_engine_compilation_configuration_editor.rst",
}

# These are engine binding interfaces, not native-editor/GDScript end-user APIs.
# C#/.NET names are also excluded defensively if a .NET doctool dump is supplied.
EXCLUDED_CLASS_NAMES = {
    "AnimationNodeExtension",
    "CSharpScript",
    "EditorExportPlatformExtension",
    "GDExtension",
    "GDExtensionManager",
    "ImageFormatLoaderExtension",
    "MultiplayerAPIExtension",
    "MultiplayerPeerExtension",
    "PacketPeerExtension",
    "PhysicsDirectBodyState2DExtension",
    "PhysicsDirectBodyState3DExtension",
    "PhysicsDirectSpaceState2DExtension",
    "PhysicsDirectSpaceState3DExtension",
    "PhysicsServer2DExtension",
    "PhysicsServer3DExtension",
    "RenderDataExtension",
    "RenderSceneBuffersExtension",
    "RenderSceneDataExtension",
    "ScriptExtension",
    "StreamPeerExtension",
    "TextServerExtension",
    "WebRTCDataChannelExtension",
    "WebRTCPeerConnectionExtension",
    "XRInterfaceExtension",
}
EXCLUDED_CLASS_PREFIXES = ("CSharp", "GodotSharp", "Mono")
EXCLUDED_API_MODULE_NAMES = {"mono"}

TUTORIAL_GROUP_NAMES = {
    "2d": "2D",
    "3d": "3D",
    "animation": "Animation",
    "assets_pipeline": "Assets Pipeline",
    "audio": "Audio",
    "best_practices": "Best Practices",
    "editor": "Editor",
    "export": "Export",
    "i18n": "Internationalization",
    "importing": "Importing",
    "inputs": "Input",
    "io": "File I/O",
    "migrating": "Migration",
    "networking": "Networking",
    "performance": "Performance",
    "physics": "Physics",
    "platform": "Platforms",
    "plugins": "Editor Plugins",
    "rendering": "Rendering",
    "scripting": "GDScript and Scripting",
    "shaders": "Shaders",
    "troubleshooting": "Troubleshooting",
    "ui": "UI",
}


@dataclass(frozen=True)
class ManualPage:
    relative: str
    title: str
    url: str


@dataclass(frozen=True)
class ClassRow:
    name: str
    parent: str
    api_type: str
    source: str
    url: str


@dataclass(frozen=True)
class ManualBuildStats:
    included: int
    outdated: int
    out_of_scope: int


@dataclass(frozen=True)
class ClassBuildStats:
    included: int
    builtins: int
    excluded: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate pinned Godot 4.7 manual and installed-class indexes."
    )
    parser.add_argument(
        "--docs",
        type=Path,
        required=True,
        help="Path to a clean official godot-docs 4.7 checkout.",
    )
    parser.add_argument(
        "--api",
        type=Path,
        required=True,
        help="Path containing doc/classes, modules/*/doc_classes, and platform/*/doc_classes from --doctool.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Output references directory.",
    )
    parser.add_argument(
        "--engine-version",
        required=True,
        help="Exact `godot --version` string for the API dump.",
    )
    parser.add_argument(
        "--expected-docs-revision",
        help="Optional exact docs commit to require.",
    )
    parser.add_argument(
        "--allow-dirty-docs",
        action="store_true",
        help="Allow a modified docs worktree (the recorded commit no longer fully identifies the source).",
    )
    return parser.parse_args()


def run_git(docs_root: Path, *args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", *args],
            cwd=docs_root,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError(f"Unable to read git {' '.join(args)} from {docs_root}") from error


def docs_revision(docs_root: Path, allow_dirty: bool) -> str:
    revision = run_git(docs_root, "rev-parse", "HEAD")
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError(f"Unexpected docs revision: {revision!r}")
    if not allow_dirty and run_git(docs_root, "status", "--porcelain=v1"):
        raise ValueError(
            f"Docs checkout {docs_root} is modified; commit it or pass --allow-dirty-docs"
        )
    return revision


def rst_title(path: Path) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    for index in range(len(lines) - 1):
        title = lines[index].strip()
        underline = lines[index + 1].strip()
        if title and re.fullmatch(r"[=\-~^\"'`#*+_]{3,}", underline):
            return title
    return path.stem.replace("_", " ").replace("-", " ").title()


def markdown_text(value: str) -> str:
    return value.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]")


def manual_out_of_scope(relative: str) -> bool:
    return relative.startswith(EXCLUDED_MANUAL_PREFIXES) or relative in EXCLUDED_MANUAL_FILES


def manual_group(relative: str) -> str:
    parts = relative.split("/")
    if parts[0] in {"about", "getting_started", "community"}:
        return parts[0].replace("_", " ").title()
    if parts[0] != "tutorials":
        return "Manual — Other"
    if len(parts) == 2 and parts[1].endswith(".rst"):
        section = parts[1].removesuffix(".rst")
    else:
        section = parts[1]
    return TUTORIAL_GROUP_NAMES.get(section, section.replace("_", " ").title())


def build_manual_index(
    docs_root: Path,
    output: Path,
    expected_revision: str | None,
    allow_dirty: bool,
) -> ManualBuildStats:
    revision = docs_revision(docs_root, allow_dirty)
    if expected_revision and revision != expected_revision:
        raise ValueError(
            f"Docs checkout is {revision}, expected {expected_revision}"
        )

    pages: list[ManualPage] = []
    outdated_count = 0
    out_of_scope_count = 0
    for root_name in MANUAL_ROOTS:
        root = docs_root / root_name
        if not root.is_dir():
            continue
        for path in root.rglob("*.rst"):
            relative = path.relative_to(docs_root).as_posix()
            if manual_out_of_scope(relative):
                out_of_scope_count += 1
                continue
            text = path.read_text(encoding="utf-8")
            if OUTDATED_RE.search(text):
                outdated_count += 1
                continue
            url_path = relative.removesuffix(".rst") + ".html"
            pages.append(
                ManualPage(
                    relative=relative,
                    title=rst_title(path),
                    url=f"{DOCS_URL_BASE}/{url_path}",
                )
            )

    groups: dict[str, list[ManualPage]] = defaultdict(list)
    for page in pages:
        groups[manual_group(page.relative)].append(page)

    lines = [
        "# Godot 4.7 End-User Manual Index",
        "",
        f"> Generated from the official `godot-docs` 4.7 checkout at commit `{revision}`.",
        "> Links are pinned to `/en/4.7/`; open the official page for authoritative details.",
        "> Pages marked `:article_outdated: True` and pages outside native-editor/GDScript end-user scope are omitted.",
        "",
        "## Coverage",
        "",
    ]
    for group in sorted(groups):
        lines.append(f"- [{group}](#{slug(group)}) — {len(groups[group])} pages")
    lines.extend(
        (
            "",
            f"Included: **{len(pages)}** pages; omitted as outdated: **{outdated_count}**; "
            f"omitted as out of scope: **{out_of_scope_count}**.",
        )
    )
    for group in sorted(groups):
        lines.extend(("", f"## {group}", ""))
        for page in sorted(groups[group], key=lambda item: (item.title.casefold(), item.relative)):
            lines.append(f"- [{markdown_text(page.title)}]({page.url})")

    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return ManualBuildStats(len(pages), outdated_count, out_of_scope_count)


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9 -]", "", value.lower()).replace(" ", "-")


def class_url(class_name: str) -> str:
    encoded_name = quote(class_name.lower(), safe="")
    return f"{DOCS_URL_BASE}/classes/class_{encoded_name}.html"


def class_is_excluded(class_name: str, source_group: str) -> bool:
    if class_name in EXCLUDED_CLASS_NAMES or class_name.startswith(EXCLUDED_CLASS_PREFIXES):
        return True
    if source_group.startswith("module:"):
        return source_group.removeprefix("module:") in EXCLUDED_API_MODULE_NAMES
    return False


def api_xml_files(api_root: Path) -> list[tuple[Path, str]]:
    files: list[tuple[Path, str]] = []
    core_dir = api_root / "doc" / "classes"
    if not core_dir.is_dir():
        raise ValueError(f"Missing API directory: {core_dir}")
    files.extend((path, "core") for path in core_dir.glob("*.xml"))

    for module_dir in sorted(api_root.glob("modules/*/doc_classes")):
        module_name = module_dir.parent.name
        files.extend((path, f"module:{module_name}") for path in module_dir.glob("*.xml"))

    for platform_dir in sorted(api_root.glob("platform/*/doc_classes")):
        platform_name = platform_dir.parent.name
        files.extend((path, f"platform:{platform_name}") for path in platform_dir.glob("*.xml"))

    if not files:
        raise ValueError(f"No API XML files found below {api_root}")
    return sorted(files, key=lambda item: item[0].relative_to(api_root).as_posix())


def build_class_index(
    api_root: Path,
    output: Path,
    engine_version: str,
) -> ClassBuildStats:
    files = api_xml_files(api_root)
    digest = hashlib.sha256()
    rows: list[ClassRow] = []
    seen: dict[str, Path] = {}
    excluded_count = 0
    builtin_count = 0

    for path, source in files:
        try:
            relative = path.relative_to(api_root).as_posix()
        except ValueError:  # All normal files are below api_root.
            relative = path.as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")

        root = ET.parse(path).getroot()
        name = root.attrib.get("name", "")
        if not name:
            raise ValueError(f"Missing class name in {path}")
        if name in seen:
            raise ValueError(f"Duplicate class XML for {name}: {seen[name]} and {path}")
        seen[name] = path
        if class_is_excluded(name, source):
            excluded_count += 1
            continue

        api_type = root.attrib.get("api_type", "")
        if not api_type:
            api_type = "builtin"
            builtin_count += 1
        rows.append(
            ClassRow(
                name=name,
                parent=root.attrib.get("inherits", ""),
                api_type=api_type,
                source=source,
                url=class_url(name),
            )
        )

    rows.sort(key=lambda row: row.name.casefold())
    lines = [
        "# Installed Godot 4.7 Class Index",
        "",
        f"> Generated from the exact local `--doctool` API dump for **{engine_version}**.",
        f"> API source digest (all core/module/platform class XML): `{digest.hexdigest()}`.",
        "> Use `scripts/api_lookup.gd` to verify signatures, defaults, inheritance, and runtime availability in the installed editor.",
        "> The standard native build has no C#/.NET support. C#/.NET and native binding-interface classes are excluded by scope.",
        "> Internal `ClassDB` entries without official class XML are not listed; built-in Variant/math types are included.",
        "",
        "| Class | Inherits | API | Source |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        parent = f"[`{markdown_text(row.parent)}`]({class_url(row.parent)})" if row.parent else "—"
        lines.append(
            f"| [`{markdown_text(row.name)}`]({row.url}) | {parent} | `{row.api_type}` | `{row.source}` |"
        )
    lines.extend(
        (
            "",
            f"Included: **{len(rows)}** documented classes/built-in types; "
            f"built-in types: **{builtin_count}**; omitted by scope: **{excluded_count}**.",
        )
    )
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return ClassBuildStats(len(rows), builtin_count, excluded_count)


def main() -> None:
    args = parse_args()
    docs_root = args.docs.resolve()
    api_root = args.api.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    manual_stats = build_manual_index(
        docs_root,
        output / "manual-index.md",
        args.expected_docs_revision,
        args.allow_dirty_docs,
    )
    class_stats = build_class_index(api_root, output / "class-index.md", args.engine_version)
    print(
        f"Wrote {manual_stats.included} manual pages and {class_stats.included} "
        f"class/built-in rows to {output}"
    )
    print(
        f"Manual omissions: {manual_stats.outdated} outdated, "
        f"{manual_stats.out_of_scope} out of scope"
    )
    print(f"Class omissions: {class_stats.excluded} out of scope")


if __name__ == "__main__":
    main()
