class_name TestCase
extends SceneTree

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyCard := preload("res://scripts/cozy_card.gd")
const GardenGlyphs := preload("res://scripts/garden_glyphs.gd")
const TestProfile := preload("res://tests/support/test_profile.gd")

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

## How many checks failed. `quit()` keeps only the last exit code a caller asks
## for, so `ok()` alone cannot be the authority: a suite that records a failure
## and then reaches `finish()` would have its `quit(1)` overwritten by
## `finish()`'s `quit(0)` and report success. `finish()` therefore reads this.
var failures := 0

## True once finish() or stop() has run, so the watchdog below can tell
## "reached the end" from "unwound halfway".
var _finished := false

## Whether the stall watchdog is already running.
var _watching := false

## Frames the watchdog will let a suite go without making a new check before
## calling it dead. Generous on purpose: between two checks a suite may legitimately
## wait out a settle loop of up to ~80 frames, and this must never fire on a
## healthy run -- only on one that has already failed and stopped progressing.
const STALL_FRAMES := 600

## Assert, then give the caller its condition back.
##
## Returning the condition rather than forcing every call site into an early
## return is what keeps a long check body readable; the suites that want the
## guard write `if not ok(...)`.
##
## This does NOT quit. A suite is free to keep checking after one failure, and
## a run that reported one problem should report every problem it found. The
## exit code is `finish()`'s to decide.
func ok(condition: bool, message: String) -> bool:
	checks_run += 1
	if condition:
		return true
	failures += 1
	push_error("%s_FAILED: %s" % [suite_name, message])
	_watch_stalls()
	return false

## Watch for a suite that has already failed and then stopped progressing.
##
## `ok()` does not quit, so a guard (`if not ok(...): return false`) can unwind
## the whole check body and the `_run()` loop, leaving nothing to call
## finish() or stop(). The SceneTree then spins forever: a hang is worse than a
## failure, because it looks like a slow test and blocks whatever waits on it.
##
## So this runs on the first failure and quits once the failure count stops
## moving for STALL_FRAMES. It keys on the COUNT, not on a timer alone, so a
## suite that keeps finding new problems is never killed mid-report.
func _watch_stalls() -> void:
	if _watching:
		return
	_watching = true
	_await_stall_watchdog()

func _await_stall_watchdog() -> void:
	var seen := failures
	var quiet := 0
	while not _finished and quiet < STALL_FRAMES:
		await process_frame
		if failures != seen:
			seen = failures
			quiet = 0
			continue
		quiet += 1
	if _finished:
		return
	TestProfile.end()
	push_error("%s_FAILED: stalled after %d checks (%d failed)" % [suite_name, checks_run, failures])
	quit(1)

## Fail without a condition -- for a path that has no boolean to test.
func fail(message: String) -> bool:
	return ok(false, message)

## Leave the suite early because a guard failed, cleanly.
##
## `ok()` deliberately does not quit, so a suite can report every problem it
## found rather than only the first. That makes `return` the natural way to
## stop once continuing would only produce noise from a broken precondition --
## but a bare `return` from `_run()` never reaches `finish()` and the SceneTree
## keeps running forever, which reads as a hung test rather than a failed one.
## Every guard therefore ends in `if not ok(...): stop(game, token); return`.
##
## `stop()` does NOT record a second failure: `ok()` already did. It only makes
## sure the profile is torn down and the process exits non-zero.
func stop(game: Node, ok_token: String) -> void:
	_finished = true
	TestProfile.end()
	if game != null and is_instance_valid(game):
		root.remove_child(game)
		game.free()
	quit(1)

## Wait `count` frames. Godot lays out and settles over several frames, so a
## check that reads a control's size has to let it move first.
func frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

## Every string a control subtree paints: Label text and Button text alike.
##
## Shop rows and cards build their wording out of child Labels rather than on a
## single property, so searching Button.text alone misses most of the screen.
## Every visible Label string in `node`, joined by newlines.
##
## This is how a test reads a screen that still speaks in words. Rows that paint
## themselves as pictures (a ware card, the pause summary) are read by identity
## and by their glyph children instead -- see `find_ware`.
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

## The joined words of the visible Labels under `node`, as ONE string.
##
## The pause summary is now icon-plus-number rows, so its figures are found by
## looking for the number in the whole block rather than in a named label that
## no longer exists.
func block_text(node: Node) -> String:
	return "\n".join(texts_in(node))

## The glyph keys a control draws as icons, read from its TextureRect children.
##
## Icon rows carry their meaning in these, so "does this row show a lantern?"
## is a question about pictures, not about a name spelled out beside them.
func glyph_keys_in(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.get_children():
		if child is TextureRect and (child as TextureRect).visible:
			out.append(String((child as TextureRect).name))
		out.append_array(glyph_keys_in(child))
	return out

func buttons_in(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		if child is Button:
			out.append(child)
		out.append_array(buttons_in(child))
	return out

## Everything a shop row says, joined.
##
## Kept for the rows that still speak -- settings rows, journal lines -- but a
## ware card paints its words as ink, so `find_ware` is how you look one up.
func row_text(button: Button) -> String:
	var parts: Array[String] = []
	if not button.text.strip_edges().is_empty():
		parts.append(button.text.strip_edges())
	for label in button.find_children("*", "Label", true, false):
		parts.append((label as Label).text.strip_edges())
	return "\n".join(parts)

## Every ware card in a subtree, in shelf order.
##
## Peddle's cart paints its wares rather than labelling them, so a card cannot
## be found by scraping text -- it is found by being a CozyCard. Anything
## asserting on a ware's state reads the card's own flags.
func ware_cards(node: Node) -> Array[CozyCard]:
	var found: Array[CozyCard] = []
	for child in node.find_children("*", "CozyCard", true, false):
		found.append(child as CozyCard)
	return found

## The card for one ware, by its data key, or null.
##
## `key` is the game's own key (charm["key"], stanza["key"], verse["key"]), so
## a suite asks for "boots" rather than for a name it would have to scrape.
## Mote's silence is filed under the empty key, so `find_ware(node, "")` finds it.
func find_ware(node: Node, key: String) -> CozyCard:
	for card in ware_cards(node):
		if card.item_key() == key:
			return card
	return null

## The free wares -- every verse and every counter-melody.
##
## Nobody buys these, so their cards carry `free_item` instead of a price, and a
## suite checking how free things are described needs exactly this set.
func free_item_cards(node: Node) -> Array[CozyCard]:
	var found: Array[CozyCard] = []
	for card in ware_cards(node):
		if card.free_item:
			found.append(card)
	return found

## The Button wrapping one ware card, which is what a press actually hits.
func ware_button(card: CozyCard) -> Button:
	return card.get_parent() as Button

## Whether a loadout list (owned or worn) holds `key` at `tier`.
##
## Charms are `{"key", "tier"}` entries rather than flag keys, because a charm
## can be bought twice and both copies are distinct things. Suites should not
## have to reach into that shape, so they ask this instead.
func wears(list: Array, key: String, tier: int = 1) -> bool:
	for entry: Variant in list:
		if entry is Dictionary and String((entry as Dictionary).get("key", "")) == key \
				and int((entry as Dictionary).get("tier", 1)) == tier:
			return true
	return false

## A loadout list built from plain keys, for fixtures that only care WHICH wares
## are present. Every entry lands at tier 1 unless a tier is given.
##
## Returns the typed `Array[Dictionary]` the run's own fields declare, because
## assigning a plain `Array` to them is rejected at runtime -- a fixture that
## "just builds a list" fails only once the whole suite is loaded.
func loadout(keys: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in keys:
		if entry is String:
			out.append({"key": String(entry), "tier": 1})
		elif entry is Array and (entry as Array).size() == 2:
			out.append({"key": String((entry as Array)[0]), "tier": int((entry as Array)[1])})
		elif entry is Dictionary:
			out.append((entry as Dictionary).duplicate())
	return out

## The glyph keys a loadout list would paint, in order. Tier 1 is the ware's
## own key; deeper tiers carry a tier prefix, so a suite can tell the two copies
## of a charm apart.
func worn_keys(list: Array) -> Array:
	var out: Array = []
	for entry: Variant in list:
		if entry is Dictionary:
			out.append(GardenGlyphs.worn_key(String((entry as Dictionary).get("key", "")),
				int((entry as Dictionary).get("tier", 1))))
	return out

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
##
## This is the ONLY place a suite quits, and it decides the exit code from the
## failure count, so a suite cannot pass by accident. The OK line is printed
## first either way: a failing run should say what it reached, and only the exit
## code carries the verdict.
func finish(game: Node, ok_token: String) -> void:
	_finished = true
	print("%s_OK (%d checks)" % [ok_token, checks_run])
	TestProfile.end()
	if game != null and is_instance_valid(game):
		root.remove_child(game)
		game.free()
	if failures > 0:
		quit(1)
		return
	quit(0)