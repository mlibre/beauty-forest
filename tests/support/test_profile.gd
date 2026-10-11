class_name TestProfile
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyData := preload("res://scripts/beauty_data.gd")

## Keeps automated runs out of the player's real profile.
##
## Every suite that instantiates the main scene used to load and SAVE the real
## `user://beauty_forest_save.json`, which inflated the player's Visits,
## stickers and dragons (a real profile reached dragons_sung = 143 purely from
## test runs). Suites call `begin()` before they touch the game and `end()`
## when they quit, so persistence lands in a throwaway directory instead.

const PROFILE_ROOT := "user://test_profiles"

static var _directory := ""

static func begin(label: String) -> String:
	# Sweep leftovers from earlier runs. Age-based on purpose: a suite that
	# quit through an early failure path never runs end(), but another test
	# process may be running right now, and wiping the whole root would delete
	# a live profile out from under it.
	_sweep_stale()
	var stamp := Time.get_ticks_usec()
	_directory = "%s/%s_%d" % [PROFILE_ROOT, label, stamp]
	BeautyData.use_test_profile(_directory)
	return _directory

static func _sweep_stale(max_age_usec: int = 3600 * 1000000) -> void:
	var dir := DirAccess.open(PROFILE_ROOT)
	if dir == null:
		return
	var now := Time.get_ticks_usec()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var path := "%s/%s" % [PROFILE_ROOT, entry]
			# Directory names are "<label>_<ticks_usec>"; the trailing number is
			# the creation stamp used to tell stale profiles from live ones.
			var file := entry.get_file()
			var split := file.rfind("_")
			var stamp := int(file.substr(split + 1)) if split >= 0 else 0
			# abs() because the stamp is a per-boot monotonic reading: a directory
			# left over from a PREVIOUS session has a stamp in this session's
			# future, and a signed difference would keep it alive forever.
			if dir.current_is_dir() and stamp > 0 and abs(now - stamp) > max_age_usec:
				_remove_recursive(path)
		entry = dir.get_next()
	dir.list_dir_end()

static func end() -> void:
	BeautyData.use_test_profile("")
	if _directory.is_empty():
		return
	_remove_recursive(_directory)
	_directory = ""

static func directory() -> String:
	return _directory

static func _remove_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_remove_recursive(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
