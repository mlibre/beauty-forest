extends "res://tests/support/test_case.gd"
## The end-to-end cold-boot guard.
##
## A player's very first `godot .` on a fresh clone runs without the editor's
## global-class cache (.godot/ is gitignored and plain runs never build it).
## That boot broke once -- "Could not resolve super class RunWorld" at
## main.gd:1 -- and nothing file-by-file caught it, because every in-process
## suite runs with the cache already built. So this suite replays the player's
## exact situation: it copies the project (sans .godot, tests and VCS noise)
## into a throwaway directory, launches a second engine process against the
## copy with no cache at all, and requires that process to reach main.gd's
## BEAUTY_FOREST_BOOT_OK marker with zero parse errors, then quit on its own.
## regression_architecture holds the same invariant per file; this one proves
## the whole graph actually boots from cold.

const DEST := "user://coldboot_copy"
const DEADLINE_FRAMES := 2400

func _initialize() -> void:
	suite_name = "BEAUTY_FOREST_COLD_BOOT"
	call_deferred("_run")

func _run() -> void:
	var dest := ProjectSettings.globalize_path(DEST)
	_wipe(dest)
	var copied := _copy_dir("res://", dest)
	ok(copied > 40, "cold copy holds only %d files" % copied)

	var args: PackedStringArray = [
		"--headless",
		"--path", dest,
		"--quit-after", "300",
		"--log-file", dest + "/boot_log.txt",
	]
	var pid := OS.create_process(OS.get_executable_path(), args)
	if not ok(pid > 0, "second engine process failed to launch (pid %d)" % pid):
		_wipe(dest)
		finish(null, "BEAUTY_FOREST_COLD_BOOT")
		return

	var waited := 0
	while waited < DEADLINE_FRAMES and OS.is_process_running(pid):
		waited += 1
		await frames(1)
	if not ok(not OS.is_process_running(pid),
			"cold boot never quit on its own (killed after %d frames)" % waited):
		OS.kill(pid)
		_wipe(dest)
		finish(null, "BEAUTY_FOREST_COLD_BOOT")
		return

	var log_path := dest + "/boot_log.txt"
	var log_text := FileAccess.get_file_as_string(log_path)
	ok(log_text.contains("BEAUTY_FOREST_BOOT_OK"),
			"cold boot never reached main.gd's boot marker")
	ok(not log_text.contains("SCRIPT ERROR"), "cold boot logged a SCRIPT ERROR")
	ok(not log_text.contains("Parse Error"), "cold boot logged a Parse Error")
	ok(not log_text.contains("Could not resolve"), "cold boot could not resolve a class")
	ok(not log_text.contains("Failed to load script"), "cold boot failed to load a script")

	_wipe(dest)
	finish(null, "BEAUTY_FOREST_COLD_BOOT")

# ------------------------------------------------------------------ helpers

func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path + "/" + entry
		if dir.current_is_dir():
			_wipe(full)
		else:
			DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

func _copy_dir(from: String, to: String) -> int:
	var dir := DirAccess.open(from)
	if dir == null:
		return 0
	DirAccess.make_dir_recursive_absolute(to)
	var count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var src := from + "/" + entry
		var dst := to + "/" + entry
		if dir.current_is_dir():
			# .godot is the whole point (a fresh clone has none), tests do not
			# take part in a player's boot, and .git is host noise.
			if entry != ".godot" and entry != ".git" and entry != "tests":
				count += _copy_dir(src, dst)
		else:
			var bytes := FileAccess.get_file_as_bytes(src)
			var out := FileAccess.open(dst, FileAccess.WRITE)
			if out != null:
				out.store_buffer(bytes)
				out.close()
				count += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return count
