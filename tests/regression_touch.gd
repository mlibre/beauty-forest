extends TestCase

## Every way to reach the pause card, and the way back out.
##
## Split out of regression_main_flow.gd, which is about run-state transitions.
##
## The touchscreen cluster is the reason this suite exists. It offers SING, DASH,
## CART, BOOK and COZY -- and nothing that pauses. A touch-only player could sing
## and shop but never open the pause card, read the run summary or take the
## button that says "back to the menu"; this project maps no back gesture either,
## so Escape was unreachable on a phone.
##
## The check drives the touch cluster directly and requires that the state it
## reaches matches the Escape key's, because a second implementation of "what
## does pause mean" is how the two drift apart.

func _initialize() -> void:
	suite_name = "BEAUTY_FOREST_TOUCH"
	TestProfile.begin("touch")
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await frames(2)

	if not await _check_the_touch_cluster_can_reach_the_pause_card(game):
		return
	if not await _check_touch_pause_matches_the_escape_key(game):
		return

	finish(game, "BEAUTY_FOREST_TOUCH")

func _touch_button_named(game: Node, needle: String) -> Button:
	for button in buttons_in(game.ui._touch_root):
		var row := button as Button
		if row != null and row_text(row).to_lower().contains(needle.to_lower()):
			return row
	return null

func _check_the_touch_cluster_can_reach_the_pause_card(game: Node) -> bool:
	game._start_run(1)
	await frames(6)
	if not ok(game.mode == game.Mode.PLAYING, "the walk did not start for the touch check"):
		return false
	var pause := _touch_button_named(game, "pause")
	if not ok(pause != null,
			"the touch cluster offers no way to pause, so a touch-only player can never open the pause card"):
		return false
	pause.pressed.emit()
	await frames(3)
	if not ok(game.mode == game.Mode.PAUSED, "the touch pause button did not open the pause card"):
		return false
	game._resume_game()
	await frames(2)
	return ok(game.mode == game.Mode.PLAYING, "the walk did not resume after the touch pause")

## The touch button and the Escape key must land in the SAME state. If they ever
## disagree -- one pauses where the other closes a modal -- a player gets a
## different game depending on which input they happen to own. So this drives
## the identical starting state twice and compares the two results, rather than
## asserting that nothing happens (which was my first mistake: pausing is
## supposed to change the mode).
func _check_touch_pause_matches_the_escape_key(game: Node) -> bool:
	# Reference the modes by NAME. The enum is MENU, PLAYING, PAUSED, SHOP,
	# JOURNAL, SETTINGS, DEAD, ENDING -- not the order I first assumed, so
	# index arithmetic here would quietly compare the wrong states.
	for state: Dictionary in [
		{"label": "walk", "enter": "PLAYING"},
		{"label": "modal", "enter": "JOURNAL"},
		{"label": "card", "enter": "PAUSED"},
	]:
		var label := String(state["label"])
		var wanted: int = game.Mode[String(state["enter"])]
		var reached: Array[int] = []
		for via_touch: bool in [false, true]:
			await _enter(game, String(state["enter"]))
			var before: int = game.mode
			if not ok(before == wanted, "the %s state was not %s (%d), got %d" % [label, String(state["enter"]), wanted, before]):
				return false
			if via_touch:
				var pause := _touch_button_named(game, "pause")
				if not ok(pause != null, "the pause button vanished from the %s state" % label):
					return false
				pause.pressed.emit()
			else:
				var escape := InputEventKey.new()
				escape.physical_keycode = KEY_ESCAPE
				escape.pressed = true
				game._unhandled_input(escape)
			await frames(3)
			reached.append(game.mode)
		if not ok(reached[0] == reached[1],
				"from the %s, Escape reached mode %d but the touch button reached %d" % [label, reached[0], reached[1]]):
			return false
	return true

## Put the game into one of the three states a pause button has to handle: the
## walk, a modal panel, or the pause card.
func _enter(game: Node, state_name: String) -> void:
	game._start_run(1)
	await frames(5)
	if state_name == "JOURNAL":
		game._open_journal()
	elif state_name == "PAUSED":
		game._pause_game()
	await frames(3)