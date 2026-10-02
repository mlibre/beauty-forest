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
	_report("PLAYING", ui._root)

	ui.show_menu({"has_save": true, "run": {}, "settings": _settings()})
	await _frames(4)
	_report("MENU", ui._root)

	ui.show_pause({"hp": 73.0, "hp_max": 100.0, "level": 4, "xp": 30, "xp_next": 50,
		"attack": 22, "sparkles": 11, "region_name": "Sunlit Roots", "forecast": "a calm dusk",
		"charm_names": ["Wool Scarf", "Swift Boots"], "charm_keys": ["scarf", "boots"],
		"floor": 2, "floor_total": 6})
	await _frames(4)
	_report("PAUSE", ui._root)

	ui.show_shop({"sparkles": 9, "charms": {"scarf": true}, "owned": {"scarf": true},
		"stanzas": {"moss": true}, "mote_verse": {"key": "lullaby"}, "hp": 100.0, "hp_max": 100.0})
	await _frames(4)
	_report("SHOP", ui._shop_content)

	root.remove_child(game)
	game.free()
	quit(0)

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

func _report(screen: String, node: Node) -> void:
	var chars := 0
	var labels := 0
	for label in node.find_children("*", "Label", true, false):
		var l := label as Label
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty():
			continue
		labels += 1
		chars += l.text.length()
		print("        [%s] %s" % [screen, l.text.left(70)])
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
	print("%-8s %2d labels / %4d chars" % [screen, labels, chars])

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