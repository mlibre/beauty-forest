# Exact API and Project-Setting Verification

Never invent a class, method, property, signal, enum, constant, or project-setting key. Verify version-sensitive names against the exact editor used by the project.

## Source priority

1. Existing project instructions, `project.godot`, scenes/scripts/resources, tests, and presets.
2. `godot --version` plus live `ClassDB` data from that executable.
3. Official English Godot 4.7 manual/class reference: <https://docs.godotengine.org/en/4.7/>.
4. The pinned 4.7 migration guide when crossing 4.6/4.7.
5. Community material only as a discovery hint, never as final API authority.

`project.godot`'s `config/features` describes project feature tags, not the exact editor patch. A class existing in `ClassDB` also does not prove renderer, module, platform, or export support; check the pinned class page and exercise the target configuration.

## Installed `ClassDB` helper

From this skill's root directory (do **not** run from inside `scripts/` — `--path scripts` would treat the scripts folder as a project):

```bash
# Case-insensitive substring search over installed class names
godot --headless --path scripts --script api_lookup.gd -- classes CharacterBody

# Exact class plus inherited methods/properties/signals/enums/constants
godot --headless --path scripts --script api_lookup.gd -- class CharacterBody3D

# Case-insensitive member substring (omit the text to list all members)
godot --headless --path scripts --script api_lookup.gd -- member Node get_node
godot --headless --path scripts --script api_lookup.gd -- member Input is_action_pressed

# Search declarations across the installed engine API
godot --headless --path scripts --script api_lookup.gd -- search tween_await
```

The helper reads live editor metadata. It prints:

- API type, parent, inheriters, instantiability, and enabled state.
- Methods with argument/return types, default values, and static/virtual/const/vararg flags.
- Properties with types, defaults, and accessors.
- Signals, enums/bitfields, and integer constants.

`class` and `member` include inherited API by default. `search` deliberately inspects declarations only to avoid repeating inherited members under every descendant. Exit codes are `0` for success, `64` for usage errors, and `65` for missing classes/members. `ClassDB` covers only native engine classes: built-in value types (`Vector2`, `Transform3D`) and global-scope helpers (`lerp`, `randf`) are documented in the class reference but are **not** in `ClassDB` — verify those on the pinned class page instead.

`ClassDB` describes engine/registered native classes. It does **not** list GDScript `class_name` globals. For those, use `ProjectSettings.get_global_class_list()`, load the registered script, and inspect `Script.get_script_method_list()`, `get_script_property_list()`, and `get_script_signal_list()`. `Object.get_class()`/`is_class()` refer to the native class, not a script's `class_name`.

The helper is a signature/name verifier, not semantic documentation. Release-export reflection may also contain less metadata than an editor binary, so run it with the editor.

## Generate an exact local API dump

Linux packages may not bundle online class-reference descriptions. Generate a fresh snapshot with the exact editor:

```bash
rm -rf /tmp/opencode/godot-api-472
mkdir -p /tmp/opencode/godot-api-472
godot --headless --doctool /tmp/opencode/godot-api-472
```

`--doctool` starts the editor, waits for imports, writes documentation, and quits. It can merge with an existing output directory, so use a fresh directory for an unambiguous snapshot and do not commit the generated XML.

Inspect:

- `doc/classes/*.xml` for core classes.
- `modules/*/doc_classes/*.xml` for module classes.
- `platform/*/doc_classes/*.xml` for platform exporter classes.

The XML includes signatures, defaults, inheritance, API type, and—depending on build/source generation—tutorial/description text. Blank descriptions in a local `--doctool` dump are not evidence that the online class page is blank; use the official page for semantics.

## Generated skill indexes

`references/class-index.md` is generated from the exact local core/module/platform XML and includes documented classes plus built-in Variant/math types. It intentionally omits C#/.NET and native binding-interface classes. Internal `ClassDB` entries without official class XML are not listed; use the helper for those.

`references/manual-index.md` is generated from the official 4.7 docs checkout, pins `/en/4.7/` links, omits pages marked `:article_outdated: True`, and filters C#/.NET, C++/GDExtension, engine compilation, and embedding material.

Rebuild both from clean/pinned sources with:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/build_reference_indexes.py \
    --docs <clean-godot-docs-4.7-checkout> \
    --api <exact-doctool-root> \
    --output references \
    --engine-version "$(godot --version)" \
    --expected-docs-revision <full-commit>
```

## Reading an official class page

- **Inherits** identifies the base; inherited members are part of the exposed API.
- **Description** and ** Tutorials** explain intended use and constraints.
- **Properties** are state; setters can validate, transform, or emit side effects.
- **Methods** show argument types/defaults; ownership transfer and thread constraints matter.
- **Signals** describe event timing but do not imply ownership.
- **Constants/enums** are exact identifiers; prefer enum names over magic integers.
- **Theme Properties/Theme Icons** matter when styling Controls.
- Method/property notes may be editor-only, main-thread-only, or renderer/platform-specific.

Class URLs are based on the lowercased class name. Names beginning with `@` are percent-encoded, for example `class_%40globalscope.html`; always prefer the generated class index or search rather than constructing URLs manually.

## Engine sources as ground truth

When docs and `ClassDB` do not spell out delivery or timing semantics (notification propagation, who quits on a close request, asynchronous server drains), the engine C++ sources settle it — e.g. `scene/main/window.cpp`, `scene/main/scene_tree.cpp`, `main/main.cpp`, `core/config/project_settings.cpp` in `godotengine/godot`. Read the tag or branch matching the project's engine version; `master` drifts. Do not guess tutorial URLs either: an invented `tutorials/...` path 404s — locate the page through `references/manual-index.md` or search instead, same as class pages.

## Project settings

Built-in settings have registered defaults even when absent from `project.godot`. Check optional custom keys before reading them:

```gdscript
const KEY := "gameplay/dash/duration"
if ProjectSettings.has_setting(KEY):
    var duration: float = ProjectSettings.get_setting(KEY)
```

When feature-tag overrides can affect the answer, use the effective API:

```gdscript
var renderer := ProjectSettings.get_setting_with_override(
    "rendering/renderer/rendering_method"
)
```

`get_setting()` returns the ordinary/base value. `get_setting_with_override()` applies the active feature override. `override.cfg`, export/runtime feature configuration, platform builds, and applicable command-line options can further affect active configuration. For CI-supplied custom features, also consider `get_setting_with_override_and_custom_features()`.

Use the editor's Project Settings search to discover a key; never infer a slash-delimited key from a UI label.

## GDScript and scene checks

Use several layers:

- Static types and typed containers at meaningful boundaries.
- Project warning settings; scope `@warning_ignore` narrowly with a reason.
- `assert()` for invariants in debug/editor runs, not user-facing error handling or security. Its condition is omitted from release exports, so never put required side effects inside it.
- `godot --headless --path <project> --check-only --script res://path.gd` to parse.
- Shader parameter names are project-declared strings, not engine API: cross-check every `set_shader_parameter()` name against the `uniform` declarations by reading the `.gdshader` file. A wrong name fails at runtime, and no parser or `ClassDB` lookup catches it.
- Runtime tests that load real scenes/resources and exercise signals, process timing, saves, and failure paths.

A clean parser does not prove node paths, scene wiring, layers/masks, resources, localization, platform features, or runtime behavior.

## Common false assumptions

- Godot 3 names such as `Spatial`, `KinematicBody`, `yield`, `export var`, `onready var`, and `instance()` are not Godot 4 APIs.
- `_process(delta)` is frame-rate-dependent; fixed-step movement/collision belongs in `_physics_process(delta)` with a `CharacterBody` workflow.
- `get_node()` succeeding in one scene does not prove another instance is wired.
- Signal parameters do not imply ownership.
- `await` suspends the caller and returns the emitted signal's result (one value, an `Array` for multiple values, or `null` for none), not the `Signal` object itself.
- A class reference describes an editor API surface, not every platform/renderer capability of the resulting export.
- A project setting's registered default is not necessarily its effective override-aware value.

## Official sources

- [How to read the API](https://docs.godotengine.org/en/4.7/tutorials/scripting/how_to_read_the_godot_api.html)
- [Class index](https://docs.godotengine.org/en/4.7/classes/index.html)
- [`ClassDB`](https://docs.godotengine.org/en/4.7/classes/class_classdb.html)
- [`ProjectSettings`](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html)
- [`Script`](https://docs.godotengine.org/en/4.7/classes/class_script.html)
- [Command-line tutorial](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)
- [GDScript warnings](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/warning_system.html)
