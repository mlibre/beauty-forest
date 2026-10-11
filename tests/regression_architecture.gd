extends "res://tests/support/test_case.gd"
## Guards the cold-boot invariant, file by file.
##
## A fresh clone ships no .godot/global_script_class_cache.cfg (it is
## gitignored), and a plain `godot .` never builds one -- only the editor
## does. Every bare global class name (`extends RunWorld`, `BeautyData.x`)
## therefore failed to PARSE on a player's first boot, which is exactly the
## report this suite exists to prevent forever. Two mechanical rules:
##
##   1. `extends X` must name an engine class (resolvable from ClassDB) or
##      quote a res:// path. Bare project-class names are forbidden.
##   2. a bare global-class reference in real code (comments and string
##      literals stripped, multi-line strings included) must be backed by a
##      `const <Name> := preload("res://...")` in this file or in any chain
##      ancestor -- inherited consts are members, so a child may use them.
##
## As a third check, every preload const must point at the file that actually
## declares the class it is named after, so a renamed class cannot leave a
## quietly wrong path behind. regression_cold_boot proves the same invariant
## end-to-end on a real cache-less boot; this suite proves it per file.
##
## As a fourth check, no engine type-string lookup (find_children, find_child,
## is_class) may name a project class. Those type strings resolve through
## ClassDB, and a script class is registered there only while the editor's
## global-class cache is warm -- on a cold or stale boot the lookup matches
## nothing, silently. That is exactly how the shop once read as empty on a
## stale-cache machine while every suite stayed green on the one that had
## built the cache: the shared harness asked find_children for "CozyCard".
## Walk the tree and cast (as / is) instead -- both are compile-time.

func _initialize() -> void:
        suite_name = "BEAUTY_FOREST_ARCHITECTURE"
        call_deferred("_run")

var _classes := {}         # class name -> res:// path that declares it
var _files: Array[String] = []

func _run() -> void:
        _collect("res://scripts")
        _collect("res://tests")
        # The audit probes are user-facing tools the docs tell people to run;
        # they parse under the same cold-boot rules and were invisible here.
        _collect("res://_audit")
        ok(_files.size() > 40, "script census found only %d files" % _files.size())
        # Pass one: inventory every class_name before any checking, so a file
        # checked early still knows about classes declared later in the walk.
        var decl := RegEx.create_from_string("(?m)^class_name[ \\t]+([A-Za-z_]\\w*)[ \\t]*$")
        for path in _files:
                var m := decl.search(FileAccess.get_file_as_string(path).substr(0, 4000))
                if m == null:
                        continue
                var cls := m.get_string(1)
                if _classes.has(cls) and _classes[cls] != path:
                        fail("%s re-declares class_name %s (owned by %s)" % [path, cls, _classes[cls]])
                _classes[cls] = path
        ok(_classes.size() > 30, "class census found only %d classes" % _classes.size())
        for path in _files:
                _check_file(path)
        finish(null, "BEAUTY_FOREST_ARCHITECTURE")

# ---------------------------------------------------------------- inventory

func _collect(base: String) -> void:
        var dir := DirAccess.open(base)
        if dir == null:
                return
        dir.list_dir_begin()
        var entry := dir.get_next()
        while entry != "":
                var path := base + "/" + entry
                if dir.current_is_dir():
                        if not entry.begins_with("."):
                                _collect(path)
                elif entry.ends_with(".gd"):
                        _files.append(path)
                entry = dir.get_next()
        dir.list_dir_end()

# ---------------------------------------------------------------- per file

func _check_file(path: String) -> void:
        var raw := FileAccess.get_file_as_string(path)
        var decl := RegEx.create_from_string("(?m)^class_name[ \\t]+([A-Za-z_]\\w*)[ \\t]*$")
        var own := ""
        var m := decl.search(raw.substr(0, 4000))
        if m != null:
                own = m.get_string(1)
        var parent_path := _parent_of(raw)
        # Rule 1: bare extends must resolve from ClassDB alone.
        var bare := RegEx.create_from_string("(?m)^extends[ \\t]*([A-Za-z_]\\w*)[ \\t]*$")
        var em := bare.search(raw.substr(0, 2000))
        if em != null and not ClassDB.class_exists(em.get_string(1)):
                fail("%s extends %s by bare name; quote the res:// path instead" % [path, em.get_string(1)])
        # Rule 2: bare class references must be backed by a preload const.
        var code := _code_only(raw)
        for cls: String in _classes:
                if cls == own:
                        continue
                var word := RegEx.create_from_string("\\b%s\\b" % cls)
                if word.search(code) == null:
                        continue
                if not _backed(path, parent_path, cls):
                        fail("%s uses %s with no const preload in it or its chain ancestors" % [path, cls])
        # Rule 3: preload consts must name the class their path declares.
        var pin := RegEx.create_from_string("(?m)^const\\s+([A-Za-z_]\\w*)\\s*:?=[ \\t]*preload\\(\"res://([^\"]+)\"\\)")
        var pm := pin.search(raw)
        while pm != null:
                var alias := pm.get_string(1)
                var target := "res://" + pm.get_string(2)
                if _classes.has(alias) and _classes[alias] != target:
                        fail("%s: const %s points at %s but %s lives in %s" % [path, alias, target, alias, _classes[alias]])
                pm = pin.search(raw, pm.get_end() + 1)
        # Rule 4: engine type-string lookups must not name a project class.
        # find_children/find_child/is_class resolve that string through ClassDB,
        # and a script class is only registered there with a warm editor cache
        # -- a cold or stale boot would match nothing, with no error anywhere.
        # Searched on the raw text, because the offending name IS a literal.
        var lookup := RegEx.create_from_string("\\b(find_children?|is_class)\\s*\\(([^\\)]*)\\)")
        var lm := lookup.search(raw)
        while lm != null:
                for lit in _string_literals(lm.get_string(2)):
                        if _classes.has(lit):
                                fail("%s passes class name %s to %s by string; that lookup needs a warm editor cache -- walk the tree and cast instead" % [path, lit, lm.get_string(1)])
                lm = lookup.search(raw, lm.get_end() + 1)

func _string_literals(text: String) -> Array[String]:
        var found: Array[String] = []
        var lit := RegEx.create_from_string("\"([^\"]+)\"")
        var m := lit.search(text)
        while m != null:
                found.append(m.get_string(1))
                m = lit.search(text, m.get_end() + 1)
        return found

func _parent_of(raw: String) -> String:
        var link := RegEx.create_from_string("(?m)^extends[ \\t]*\"res://([^\"]+)\"[ \\t]*$")
        var m := link.search(raw.substr(0, 2000))
        return m.get_string(1) if m != null else ""

func _backed(path: String, parent_path: String, cls: String) -> bool:
        var backed := RegEx.create_from_string("(?m)^const\\s+%s\\s*:?=[ \\t]*preload\\(" % cls)
        var walker := path
        var hops := 0
        while walker != "" and hops < 16:
                var text := FileAccess.get_file_as_string(walker)
                if backed.search(text) != null:
                        return true
                walker = _parent_of(text)
                hops += 1
        return false

# ------------------------------------------------- code_only: strip strings
# A whole-file state machine blanks string literals and comments so only real
# code is searched for class references. Multi-line strings are tracked, so a
# verse that happens to say "Wisp" never asks for an alias.

func _code_only(raw: String) -> String:
        var lines: Array[String] = []
        var line := ""
        var state := "code"
        var i := 0
        var n := raw.length()
        while i < n:
                var c := raw[i]
                if state == "code":
                        if c == "#":
                                while i < n and raw[i] != "\n":
                                        i += 1
                                continue
                        if c == "'":
                                state = "sq"
                                line += " "
                                i += 1
                                continue
                        if c == "\"":
                                if raw.substr(i, 3) == "\"\"\"":
                                        state = "block"
                                        line += "   "
                                        i += 3
                                        continue
                                state = "dq"
                                line += " "
                                i += 1
                                continue
                        line += c
                        i += 1
                        continue
                if state == "sq" or state == "dq":
                        if c == "\\" and i + 1 < n:
                                line += "  "
                                i += 2
                                continue
                        if (state == "sq" and c == "'") or (state == "dq" and c == "\""):
                                state = "code"
                        line += " " if c != "\n" else "\n"
                        if c == "\n":
                                lines.append(line)
                                line = ""
                        i += 1
                        continue
                if state == "block":
                        if raw.substr(i, 3) == "\"\"\"":
                                state = "code"
                                line += "   "
                                i += 3
                                continue
                        if c == "\n":
                                lines.append(line)
                                line = ""
                        else:
                                line += " "
                        i += 1
                        continue
        if line != "":
                lines.append(line)
        return "\n".join(lines)
