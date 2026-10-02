class_name TestCase
extends SceneTree

## Shared scaffolding for the multi-step regression suites.
##
## A suite is a SceneTree that boots the main scene, drives the game, and has to
## be able to fail loudly. Godot's own `assert()` only logs a SCRIPT ERROR and
## carries on, so a suite written with it prints its _OK line and exits 0 with
## the game broken -- which is how `regression_graphics.gd` and
## `runtime_smoke.gd` used to report success. Everything here exists so a
## failure is a failure.
##
## `ok()` returns its condition, so a check is both the assertion and the guard
## for the next step:
##
##     if not ok(game.mode == game.Mode.PLAYING, "run did not start"):
##         return
##
## The tree helpers here (text collection, button walking, frame waiting) are the
## same handful the suites kept copying into each other.

## The suite's name, used to prefix its failure line so a failing run says which
## suite it came from without needing the shell command that launched it.
var suite_name := "TestCase"

## Collected so a suite can report how many checks it made, and so `fail()` can
## be called from a helper that does not itself want to unwind.
var checks_run := 0


## Assert, then give the caller its condition back.
##
## Returning the condition rather than forcing every call site into an early
## return is what keeps a long check body readable; the suites that want the
## guard write `if not ok(...)`.
func ok(condition: bool, message: String) -> bool:
	checks_run += 1
	if condition:
		return true
	push_error("%s_FAILED: %s" % [suite_name, message])
	quit(1)
	return false


## Fail without a condition -- for a path that has no boolean to test.
func fail(message: String) -> bool:
	return ok(false, message)


## Wait `count` frames. Godot lays out and settles over several frames, so a
## check that reads a control's size has to let it move first.
func frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


## Every string a control subtree paints: Label text and Button text alike.
##
## Shop rows and cards build their wording out of child Labels rather than on a
## single property, so searching Button.text alone misses most of the screen.
func texts_in(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
		out.append_array(texts_in(child))
	return out


func has_text(node: Node, needle: String) -> bool:
	for text in texts_in(node):
		if text.contains(needle):
			return true
	return false


func buttons_in(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		if child is Button:
			out.append(child)
		out.append_array(buttons_in(child))
	return out


## Everything a shop row says, joined.
##
## A row is a composite of an icon, a name, a status and a price, so its wording
## lives in child Labels rather than on Button.text.
func row_text(button: Button) -> String:
	var parts: Array[String] = []
	if not button.text.strip_edges().is_empty():
		parts.append(button.text.strip_edges())
	for label in button.find_children("*", "Label", true, false):
		parts.append((label as Label).text.strip_edges())
	return "\n".join(parts)


## The first Button in a subtree whose painted text contains `needle`.
func button_with_text(node: Node, needle: String) -> Button:
	for candidate in buttons_in(node):
		var button := candidate as Button
		if row_text(button).contains(needle):
			return button
	return null


## The newest log line mentioning `needle`, searching from the bottom.
##
## Log lines keep arriving while a test runs -- wisps drift home, the shop
## refills -- so "the newest line" is not the same thing as "the line I caused".
## Falling back to the final line is deliberate: a caller checking that a
## message ARRIVED wants to see whatever is there when it did not, not an empty
## string that reads like an absence of logging.
func newest_line_mentioning(log: Label, needle: String) -> String:
	var haystack: PackedStringArray = String(log.text).split("\n")
	var fallback: String = haystack[haystack.size() - 1]
	for i in range(haystack.size() - 1, -1, -1):
		if haystack[i].to_lower().contains(needle.to_lower()):
			return haystack[i]
	return fallback


## Finish a suite: the OK line, the profile teardown and the teardown of the
## scene under test. Order matters -- TestProfile.end() must come before quit()
## or the throwaway directory is left behind.
func finish(game: Node, ok_token: String) -> void:
	print("%s_OK (%d checks)" % [ok_token, checks_run])
	TestProfile.end()
	if game != null and is_instance_valid(game):
		root.remove_child(game)
		game.free()
	quit(0)