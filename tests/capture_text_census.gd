extends SceneTree

## Counts the text the player can actually SEE on each screen, so "the game is
## full of text" can be checked rather than argued about. Dev tool, not shipped.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(4)
	var ui: GameUI = game.ui

	# The walk screen has to be MEASURED, not assumed. Instantiating the scene
	# leaves the game in MENU with the whole HUD hidden, so a census taken here
	# reported "PLAYING 0 labels" while nothing was ever visible -- it passed on
	# an empty tree. Start a real run and assert the walk screen is on screen
	# before counting it.
	game._start_run(1)
	await _frames(12)
	ui.close_panels()
	ui.set_text_chrome_visible(false)
	await _frames(4)
	_walking_screen_is_live(ui)
	var walked := _report("PLAYING", ui._root)

	# The zero above is honest about the HUD, but it was hiding the one voice
	# that actually speaks during a walk. The toast is invisible at rest and
	# paints a cue the moment something happens -- "Wait for the GOLD halo", "−7
	# warmth" -- and the walk screen budget of zero said nothing about any of it.
	# A cue is short and transient by design, but "transient" is not "free", and
	# a run where Mote narrates every swing is the exact future this project is
	# trying not to ship. The longest cue the game can produce is measured, so
	# adding one that cannot be read at a glance fails here.
	var longest_cue := _longest_cue()
	print("%-8s %2d labels / %4d chars  (longest cue: %d = \"%s\")" % [
		"WALK-CUE", 1, longest_cue.length(), longest_cue.length(), longest_cue])
	if longest_cue.length() > CUE_BUDGET:
		printerr("CENSUS_FAIL: the longest walk cue is %d chars (\"%s\"), over its %d budget -- a cue has to be readable at a glance" % [
			longest_cue.length(), longest_cue, CUE_BUDGET])

	ui.show_menu({"has_save": true, "run": {}, "settings": _settings()})
	await _frames(4)
	var menu_seen := _report("MENU", ui._root)

	ui.show_pause({"hp": 73.0, "hp_max": 100.0, "level": 4, "xp": 30, "xp_next": 50,
		"attack": 22, "sparkles": 11, "region_name": "Sunlit Roots", "forecast": "a calm dusk",
		"charm_names": ["Wool Scarf", "Swift Boots"], "charm_keys": ["scarf", "boots"],
		"floor": 2, "floor_total": 6})
	await _frames(4)
	var pause_seen := _report("PAUSE", ui._root)

	ui.show_shop({"sparkles": 9, "charms": {"scarf": true}, "owned": {"scarf": true},
		"stanzas": {"moss": true}, "mote_verse": {"key": "lullaby"}, "hp": 100.0, "hp_max": 100.0})
	await _frames(4)
	var shop_seen := _report("SHOP", ui._shop_content)

	# The screens below existed before the budget did, and none of them was
	# measured: the census walked the player through play, menu, pause and cart
	# and stopped. So the nap card, the dragons-are-snuggled card, Mote's memory
	# book and the cozy-options panel could each have grown into a wall of prose
	# and the tool would still have reported four healthy screens. Every screen
	# the player can open is now measured, including the ones that only appear at
	# the end of a run -- those are the screens a player reads most carefully,
	# which is exactly why they are the easiest place to add a paragraph nobody
	# notices until the whole game is made of them.
	# Each of these is measured on a clean tree. `_show_overlay` does not touch
	# the cart's scrim, so measuring a nap card while the cart was still standing
	# behind it reported 45 labels / 834 chars for a card that paints six lines --
	# and if that overlap is reachable in real play it is a bug, not a census
	# problem. Closing first keeps the number honest either way: what is counted
	# is what a player sees on that screen, not another screen left standing.
	ui.close_panels()
	ui.show_death(4, {"runs": 7, "best_floor": 6, "wisps_soothed": 19, "facts": 5, "dragons_sung": 2})
	await _frames(4)
	var nap_seen := _report("NAP", ui._root)

	ui.close_panels()
	ui.show_ending(2, {"runs": 7, "best_floor": 6, "wisps_soothed": 19, "facts": 5, "dragons_sung": 2})
	await _frames(4)
	var ending_seen := _report("ENDING", ui._root)

	ui.close_panels()
	ui.show_journal({"runs": 7, "best_floor": 6, "wisps_soothed": 19, "dragons_sung": 2},
		["A group of jellyfish called themselves a parliament.",
		 "Octopuses taste with their arms, so a whole arm can be a tongue."],
		["first_nap", "gentle_giant"])
	await _frames(4)
	var journal_seen := _report("JOURNAL", ui._shop_content)

	ui.close_panels()
	ui.show_settings({"high_contrast": false, "reduced_motion": false, "compact_hud": false,
		"text_scale": 1.0, "damage_taken": 1.0, "rhythm_window": 1.0, "wisp_speed": 1.0,
		"volume": 0.8, "muted": false})
	await _frames(4)
	var settings_seen := _report("SETTINGS", ui._shop_content)

	root.remove_child(game)
	game.free()
	# The walk screen has a hard budget of zero: AGENTS.md says it paints no
	# sentences, and this tool exists to hold that line. Reporting the count and
	# exiting 0 anyway leaves the rule to whoever reads the output.
	#
	# Every other screen gets a real budget too, because a budget nobody enforces
	# is a wish. Each is set a little ABOVE the current count -- room for one more
	# short row, not for a paragraph -- so ordinary additions pass and a wall of
	# prose does not.
	#
	# These counts were all wrong once, and the errors were not rounding:
	#
	#   - The census only swept Labels, so every Button and CheckButton in the
	#     game was invisible to it. The cozy panel claimed 102 chars while its
	#     four checkboxes held more than that between them; the menu claimed 252
	#     while six of its buttons went uncounted. _report now sweeps BaseButton
	#     and LineEdit too.
	#   - A headless run reports is_touchscreen_available() as true, so the six
	#     on-screen control buttons were counted on the walk screen. They are
	#     excluded by name (see _visible_labels).
	#   - Four screens were never measured at all until this pass: the nap card,
	#     the ending, the memory book and the cozy panel. A gate covering only the
	#     screens somebody remembered to point it at is half a gate.
	#
	# With the blind spots closed, these are the numbers, each measured on a real
	# screen and repeated across runs:
	#   PLAYING    0   the rule in AGENTS.md
	#   MENU     360   298: title, subtitle, 3 promise captions, 6 buttons, record
	#   PAUSE    820   705 + one drawn floor-mood line (see below)
	#   SHOP     700   601: 34 ware names, 4 shelf headings, sparkle count
	#   NAP      250   200: the cozy-nap card (two floor rows + one warm line)
	#   ENDING   240   176: the dragons-are-snuggled card (dragon, heart, chime)
	#   JOURNAL  380   294: two facts and two stickers; grows with collection
	#   SETTINGS 320   250: checkboxes and slider rows
	#
	# JOURNAL's budget has the most room on purpose. Its length is a player's
	# collection, not an author's paragraph -- every fact they found and every
	# sticker they earned is one more line -- so it is the one screen where the
	# count going up means the player got more, not that someone wrote more.
	#
	# PAUSE is the one budget that cannot be a single observation, because the
	# pause card shows the FLOOR'S MOOD and `random_modifier` draws a different
	# FLOOR_MODIFIERS line every run -- "wisps carry extra soul-light (+50%
	# soul)" is 41 chars, "the wood is gentler; wisps notice you later" is 42,
	# "everything feels possible: richer souls and warmer hearts" is 60. The
	# budget therefore sits above the LONGEST line plus headroom, and that is
	# stated here rather than discovered later as a flaky test.
	var failed := 0
	if longest_cue.length() > CUE_BUDGET:
		failed += 1
	var measured := {"PLAYING": walked, "MENU": menu_seen, "PAUSE": pause_seen, "SHOP": shop_seen,
		"NAP": nap_seen, "ENDING": ending_seen, "JOURNAL": journal_seen, "SETTINGS": settings_seen}
	for screen: String in BUDGETS:
		var budget: int = int(BUDGETS[screen])
		var chars := int((measured[screen] as Dictionary)["chars"])
		if chars > budget:
			printerr("CENSUS_FAIL: %s painted %d chars, over its %d budget -- the screens are getting wordy again" % [
				screen, chars, budget])
			failed += 1
	quit(1 if failed > 0 else 0)

## The longest cue the game can put on screen during a walk, found by reading
## every `add_cue` call in the source rather than by triggering them.
##
## Triggering them would need a real run to land on a shielded wisp, a Big
## Feeling and a hit all at once; reading the call sites costs a millisecond and
## cannot miss a cue because the fight did not happen to cooperate. A call with a
## `%d` in it is measured with the widest figure a three-digit warmth loss could
## produce, because "−7 warmth" being readable does not mean "−700 warmth" is.
##
## Every visible cue counts even though only one is on screen at a time: they
## queue, and a run that stacks three of them is the case worth catching.
func _longest_cue() -> String:
	var longest := ""
	for path in ["res://scripts/run_combat.gd", "res://scripts/main.gd", "res://scripts/game_ui.gd"]:
		if not FileAccess.file_exists(path):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var stripped := line.strip_edges()
			if not stripped.begins_with("ui.add_cue(") and not stripped.begins_with("add_cue("):
				continue
			for literal in _literals(stripped):
				# A formatted figure is as wide as the largest number it can print.
				var text := literal
				if text.find("%d") >= 0:
					text = text.replace("%d", "999")
				if text.length() > longest.length():
					longest = text
	return longest

## How long the longest walk-screen cue may be.
##
## The toast is the only voice on the walk screen, so this is the whole budget
## for words during play -- and it is deliberately smaller than any screen's. A
## cue lands while the player is moving, in the middle of a fight, and has to be
## read at a glance; "Almost! Wait for the GOLD halo" is 28 characters and is
## already at the edge of what a glance covers. A sentence here would be a
## sentence across the middle of the game.
const CUE_BUDGET := 32

## The per-screen character budgets this tool enforces. See _run for why each
## number is what it is. Every screen the player can open appears here -- a gate
## that covers only the screens somebody remembered to point it at is half a gate.
const BUDGETS := {
	"PLAYING": 0,
	"MENU": 360,
	"PAUSE": 820,
	"SHOP": 700,
	"NAP": 250,
	"ENDING": 240,
	"JOURNAL": 380,
	"SETTINGS": 320,
}

## Fails loudly if the walk screen is not actually drawn: a census over a hidden
## HUD reports zero for the wrong reason and would hide any text added to it.
func _walking_screen_is_live(ui: GameUI) -> void:
	if not ui._hud.visible:
		printerr("CENSUS_UNMEASURABLE: the HUD is hidden, so PLAYING would report 0 for the wrong reason")
		quit(1)
		return
	if not is_instance_valid(ui._minimap) or not ui._minimap.is_visible_in_tree():
		printerr("CENSUS_PARTIAL: the grove map is not on the walk screen; its text was not measured")
	if not is_instance_valid(ui._vitals) or not ui._vitals.is_visible_in_tree():
		printerr("CENSUS_PARTIAL: the vitals strip is not on the walk screen; its text was not measured")

func _settings() -> Dictionary:
	return {"high_contrast": false, "reduced_motion": false, "compact_hud": false, "text_scale": 1.0}

func _report(screen: String, node: Node) -> Dictionary:
	var chars := 0
	var labels := 0
	for label in _visible_labels(node):
		var l := label as Label
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty():
			continue
		labels += 1
		chars += l.text.length()
		print("        [%s] %s" % [screen, l.text.left(70)])
	# Labels are only half the words. A Button, a CheckButton and a LineEdit all
	# paint text, and none of them is a Label -- so find_children("Label") walked
	# straight past them. The cozy panel reported 102 chars while its four
	# checkboxes alone ("Still forest — calm decorative motion (walk stays
	# readable)" is 58) were invisible to it, which is the same blindness the
	# draw_string sweep below already fixes for hand-painted captions: the tool
	# was measuring the absence of its own gaps. BaseButton covers Button,
	# CheckButton, CheckBox and OptionButton; LineEdit covers the editable
	# fields; RichTextLabel is already a Label subclass.
	for button in _visible_buttons(node):
		var b := button as BaseButton
		if b.text.strip_edges().is_empty():
			continue
		labels += 1
		chars += b.text.length()
		print("        [%s] (button) %s" % [screen, b.text.left(70)])
	for field in _visible_buttons(node, "LineEdit"):
		var e := field as LineEdit
		if e.text.strip_edges().is_empty():
			continue
		labels += 1
		chars += e.text.length()
		print("        [%s] (field) %s" % [screen, e.text.left(70)])
	# Labels are not the only text a Control can paint: a `draw_string` call is
	# invisible to a find_children sweep. The minimap once labelled itself
	# "GROVE MAP" this way, straight onto the walk screen, and the Label-only
	# count still reported zero. A headless viewport never rasterizes custom
	# _draw output, so the strings are recovered from each visible item's own
	# script source instead.
	for item in _visible_custom_drawers(node):
		for literal: String in _string_literals_in_draw_calls(item):
			if literal.begins_with("#") or literal.find(":") >= 0:
				continue  # a colour literal, not a word
			labels += 1
			chars += literal.length()
			print("        [%s] (draw_string in %s) %s" % [screen, item.get_class(), literal.left(70)])
	# A ware card paints its name with draw_string(item_name()), so it is not a
	# LITERAL in the source and the sweep above cannot see it either. Left
	# uncounted, Peddle's cart could have carried a sentence on every card and
	# still reported a handful of labels -- the tool would have measured the
	# absence of its own blindness rather than the absence of text. A card
	# paints exactly two things: its name and its price digits, so those are
	# what it counts.
	for card: CozyCard in _visible_ware_cards(node):
		var painted: String = card.item_name()
		if not card.free_item:
			painted += str(card.price)
		labels += 1
		chars += painted.length()
		print("        [%s] (card) %s" % [screen, painted.left(70)])
	print("%-8s %2d labels / %4d chars" % [screen, labels, chars])
	return {"labels": labels, "chars": chars}

## Every visible Label under `node`, minus the on-screen touch controls.
##
## The touch cluster (SING / DASH / CART / BOOK / COZY / PAUSE) is built behind
## `DisplayServer.is_touchscreen_available()`, so a desktop player never sees it.
## A headless run, though, reports that as TRUE -- the boolean has no display to
## be truthful about -- so the census counted six buttons, 31 characters, on the
## walk screen and failed PLAYING's zero budget for chrome nobody reading this
## game on a keyboard ever sees.
##
## They are excluded BY NAME rather than by flipping the availability flag: the
## buttons are real and a touch player does see them, so the honest statement is
## "the walk screen paints no sentences for a player using keys", not "the walk
## screen paints no sentences while pretending it is a phone".
func _visible_labels(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for label in node.find_children("*", "Label", true, false):
		if _under_touch_controls(label):
			continue
		if label is Label and (label as Label).is_visible_in_tree():
			found.append(label)
	return found

## True when `node` sits inside the on-screen controls root.
func _under_touch_controls(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent.name == "TouchControls":
			return true
		parent = parent.get_parent()
	return false

## Every visible button (or any other `class_name` type) under `node`, minus the
## on-screen touch controls -- see _visible_labels for why they are left out.
func _visible_buttons(node: Node, type_name := "BaseButton") -> Array[Node]:
	var found: Array[Node] = []
	for button in node.find_children("*", type_name, true, false):
		if _under_touch_controls(button):
			continue
		if button is CanvasItem and (button as CanvasItem).is_visible_in_tree():
			found.append(button)
	return found

## Every ware card a player can see under `node`.
func _visible_ware_cards(node: Node) -> Array[CozyCard]:
	var found: Array[CozyCard] = []
	for child in node.find_children("*", "CozyCard", true, false):
		var card := child as CozyCard
		if card != null and card.is_visible_in_tree():
			found.append(card)
	return found

## Every visible Control under `node` that runs its own _draw, which is where
## a hand-painted caption would live.
func _visible_custom_drawers(node: Node) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	for child in node.find_children("*", "", true, false):
		var item := child as CanvasItem
		if item == null or not item.is_visible_in_tree():
			continue
		if _calls_draw_itself(item):
			found.append(item)
	return found

func _calls_draw_itself(item: CanvasItem) -> bool:
	var script := item.get_script() as Script
	if script == null:
		return false
	return script.source_code.contains("\nfunc _draw(") or script.source_code.begins_with("func _draw(")

## The literal words a script hands to draw_string / draw_multiline_string.
## A call that formats a number instead (str(sparkles)) has no words to count
## and is skipped, because the census counts sentences, not digits.
func _string_literals_in_draw_calls(item: CanvasItem) -> Array[String]:
	var script := item.get_script() as Script
	var found: Array[String] = []
	if script == null:
		return found
	var in_draw := false
	for line in script.source_code.split("\n"):
		if line.begins_with("func "):
			in_draw = line.contains("_draw(") and not line.contains("func _draws")
		if not in_draw:
			continue
		var call := line.strip_edges()
		if not call.begins_with("draw_string(") and not call.begins_with("draw_multiline_string("):
			continue
		for literal in _literals(call):
			found.append(literal)
	return found

## String literals on one line that hold no format placeholder and no call --
## the ones a reader would actually read as words.
func _literals(line: String) -> Array[String]:
	var found: Array[String] = []
	var rest := line
	var open := rest.find("\"")
	while open >= 0:
		var close := rest.find("\"", open + 1)
		if close < 0:
			break
		var body := rest.substr(open + 1, close - open - 1)
		if body.find("%") < 0 and body.find("(") < 0 and not body.is_empty():
			found.append(body)
		rest = rest.substr(close + 1)
		open = rest.find("\"")
	return found

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame