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

	ui.close_panels()
	ui.set_text_chrome_visible(false)
	await _frames(4)
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
	print("%-8s %2d labels / %4d chars" % [screen, labels, chars])

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame