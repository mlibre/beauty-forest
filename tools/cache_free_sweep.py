#!/usr/bin/env python3
"""Make this project's GDScript fully cache-independent (cold-boot safe). v2

v1 lesson: a const alias declared in a chain ancestor is a MEMBER of every
derived class, so a descendant must not re-declare it ("member already exists
in parent class"). v2 therefore:

  0. strips any previously generated alias blocks (idempotent re-runs)
  1. bare `extends <ProjectClass>`  ->  extends "res://path/to/class.gd"
  2. computes each file's bare body references (comments/strings stripped)
  3. subtracts aliases already declared by chain ancestors (path-extends tree,
     ancestors processed first) and inserts the remainder as one const block
  4. verifies the resulting preload graph is a DAG (Tarjan SCC)
"""
import os, re, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAN_DIRS = ["scripts", "tests"]
APPLY = "--apply" in sys.argv

GEN_BLOCK = re.compile(
    r"\n?# Deps are pinned by path on purpose: a fresh clone ships no\n"
    r"# editor-built global-class cache, and bare names would not parse\n"
    r"# on first boot\. regression_architecture holds this file to it\.\n"
    r"(?:const [A-Za-z_]\w* := preload\(\"res://[^\"]+\"\)\n?)+"
)

def code_only(text: str) -> str:
    out = []
    i, n = 0, len(text)
    state = "code"
    while i < n:
        c = text[i]
        if state == "code":
            if c == "#":
                while i < n and text[i] != "\n":
                    out.append(" "); i += 1
                continue
            if c == "'":
                state = "sq"; out.append(" "); i += 1; continue
            if c == '"':
                if text[i:i+3] == '"""':
                    state = "block3"; out.append("   "); i += 3; continue
                state = "dq"; out.append(" "); i += 1; continue
            out.append(c); i += 1; continue
        if state in ("sq", "dq"):
            if c == "\\" and i + 1 < n:
                out.append("  "); i += 2; continue
            if (state == "sq" and c == "'") or (state == "dq" and c == '"'):
                state = "code"
            out.append(c if c == "\n" else " "); i += 1; continue
        if state == "block3":
            if text[i:i+3] == '"""':
                state = "code"; out.append("   "); i += 3; continue
            out.append(c if c == "\n" else " "); i += 1; continue
    return "".join(out)

DECL = re.compile(r"^class_name\s+([A-Za-z_]\w*)\s*$", re.M)
EXT_NAME = re.compile(r"^extends\s+([A-Za-z_]\w*)\s*$", re.M)
EXT_PATH = re.compile(r'^extends\s+"res://([^"]+)"\s*$', re.M)
CONST = re.compile(r"^(?:static\s+)?const\s+([A-Za-z_]\w*)", re.M)
MEMBER = re.compile(r"^(?:static\s+)?(?:var|func|signal|enum)\s+([A-Za-z_]\w*)", re.M)

class_file, text_of = {}, {}
gd_files = []
for d in SCAN_DIRS:
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, d)):
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                p = os.path.join(dirpath, fn)
                rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
                gd_files.append(rel)
                text = open(p).read()
                m = DECL.search(text[:4000])
                if m:
                    class_file[m.group(1)] = rel
                text_of[rel] = text
names = set(class_file)
gd_set = set(gd_files)
# NOTE: the path-extends target is a STRING literal, so it must be parsed from
# the RAW text -- code_only() blanks strings and would hide every chain link.
parent_of = {}
for rel in gd_files:
    m = EXT_PATH.search(text_of[rel][:2000])
    if m:
        parent_of[rel] = m.group(1)
children = defaultdict(list)
for rel, par in parent_of.items():
    if par in gd_set:
        children[par].append(rel)

# topo order: roots (no project parent) before descendants
order, seen = [], set()
def visit(rel):
    if rel in seen:
        return
    seen.add(rel)
    par = parent_of.get(rel)
    if par in gd_set:
        visit(par)
    order.append(rel)
for rel in sorted(gd_files):
    visit(rel)

ancestor_alias = {}   # rel -> set of class names aliased somewhere up-chain
own_need, report = {}, []
for rel in order:
    text = text_of[rel]
    stripped = GEN_BLOCK.sub("", text)
    while "\n\n\n" in stripped:
        stripped = stripped.replace("\n\n\n", "\n\n")
    code = code_only(stripped)
    own = (DECL.search(stripped[:4000]) or [None]) and DECL.search(stripped[:4000])
    own = own.group(1) if own else None
    ext_m = EXT_NAME.search(code[:2000])
    extended = ext_m.group(1) if ext_m and ext_m.group(1) in names else None

    # 1. bare extends -> path (idempotent: quoted form no longer matches)
    if extended:
        stripped = EXT_NAME.sub(f'extends "res://{class_file[extended]}"', stripped, count=1)
        code = EXT_NAME.sub(f'extends "res://{class_file[extended]}"', code, count=1)

    need = set()
    for cls in names:
        if cls in (own, extended):
            continue
        if re.search(r"\b%s\b" % cls, code):
            need.add(cls)

    # ancestors' aliases (chain map built on the FINAL path-extends state)
    anc = set()
    walker = parent_of.get(rel)
    while walker in gd_set:
        anc |= ancestor_alias.get(walker, set())
        walker = parent_of.get(walker)

    real_consts = set(CONST.findall(code))
    real_members = set(MEMBER.findall(code))
    conflicts = []
    for cls in sorted(need):
        if cls in real_consts:
            if not re.search(r"const\s+%s\s*:?=\s*preload\(" % cls, code):
                conflicts.append(cls)
    need -= anc          # inherited from a chain ancestor already
    need -= set(conflicts)
    if conflicts:
        report.append(f"  CONFLICT {rel}: {conflicts} -- manual fix")
    own_need[rel] = need
    ancestor_alias[rel] = anc | need

    out = stripped
    if need:
        block = ["", "# Deps are pinned by path on purpose: a fresh clone ships no",
                 "# editor-built global-class cache, and bare names would not parse",
                 "# on first boot. regression_architecture holds this file to it."]
        for cls in sorted(need):
            block.append(f'const {cls} := preload("res://{class_file[cls]}")')
        lines = out.split("\n")
        at = 0
        for i, ln in enumerate(lines[:8]):
            if ln.startswith("extends "):
                at = i
        at += 1
        while at < len(lines) and lines[at].strip() != "":
            at += 1
        lines[at:at] = block
        out = "\n".join(lines)
    if out != text_of[rel]:
        report.append(f"  rewrote {rel}: aliases {sorted(need) if need else '(inherited)'}")
        text_of[rel] = out

print("\n".join(report) if report else "  no changes needed")
if APPLY:
    for rel in gd_files:
        with open(os.path.join(ROOT, rel), "w") as f:
            f.write(text_of[rel])

# ---- cycle check on final preload graph (aliases + path extends)
graph = defaultdict(set)
for rel in gd_files:
    code = code_only(text_of[rel])
    for cls in names:
        if cls == class_file.get(rel) and False:
            continue
        m = re.search(r"const\s+%s\s*:?=\s*preload\(\"res://([^\"]+)\"\)" % cls, code)
        if m:
            graph[rel].add(m.group(1))
    pm = EXT_PATH.search(text_of[rel][:2000])
    if pm and pm.group(1) in gd_set:
        graph[rel].add(pm.group(1))

sys.setrecursionlimit(10000)
idx, low, on, stack, cnt = {}, {}, {}, [], [0]
sccs = []
def sc(v):
    idx[v] = low[v] = cnt[0]; cnt[0] += 1
    stack.append(v); on[v] = True
    for w in graph.get(v, ()):
        if w not in idx:
            sc(w); low[v] = min(low[v], low[w])
        elif on.get(w):
            low[v] = min(low[v], idx[w])
    if low[v] == idx[v]:
        comp = []
        while True:
            w = stack.pop(); on[w] = False; comp.append(w)
            if w == v: break
        sccs.append(comp)
for v in list(graph):
    if v not in idx:
        sc(v)
bad = [c for c in sccs if len(c) > 1 or (len(c) == 1 and c[0] in graph.get(c[0], ()))]
print("\n=== preload/extends graph cycle check ===")
print("  CYCLES FOUND:" if bad else "  none - graph is a DAG, safe to ship")
for comp in bad:
    for f in comp:
        print(f"    {f} -> {sorted(graph[f] & set(comp))}")
print("\nAPPLIED" if APPLY else "DRY RUN (no files written)")
