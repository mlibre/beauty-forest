extends "res://tests/support/test_case.gd"
## Every way to reach the pause card, and the way back out.
##
## Split out of regression_main_flow.gd, which is about run-state transitions.
##
## The touchscreen cluster is the reason this suite exists. It used to offer
## SING, DASH, CART, BOOK and COMFORT -- and nothing that paused. A touch-only
## player could sing and shop but never open the pause card, read the run
## summary or take the button that says "back to the menu"; this project maps
## no back gesture either, so Escape was unreachable on a phone.
##
## Today the cluster carries BOOK and PAUSE only, and the point-4 contract is
## the inverse of the old one: no SING, DASH or ASCEND plate may ever sit on
## the walk screen. Every action verb lives in the golden hint that appears
## beside the object itself -- and on a touchscreen that hint IS the button,
## so the checks below also drive it: shown, tapped, heard, hidden.
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
        if not await _check_a_relayout_does_not_resurrect_the_hidden_log(game):
                return
        if not await _check_resuming_restores_the_walk_screens_pictures(game):
                return
        if not await _check_the_walk_screen_offers_no_action_plates(game):
                return
        if not await _check_the_golden_hint_answers_a_tap(game):
                return

        finish(game, "BEAUTY_FOREST_TOUCH")

func _check_resuming_restores_the_walk_screens_pictures(game: Node) -> bool:
        ## The walk screen is pictures only: the lantern ring, sparkles, depth and the
        ## charm sockets are its entire readout, and AGENTS.md forbids sentences there.
        ## show_pause() calls set_text_chrome_visible(true) to bring Mote's chatter and
        ## the key hints back for the summary -- which HIDES the vitals strip, because
        ## the two are mutually exclusive by construction. But _resume_game() only
        ## closed the panels; it never turned the pictures back on. So one pause left
        ## the player walking with no lantern ring, no sparkle count and no depth, and
        ## with prose painted on the screen they had already left.
        ##
        ## This is the one HUD invariant that has no test: the relayout check above
        ## guards the log coming BACK when it should stay hidden, and nothing guarded
        ## the vitals going away when they should return.
        game._start_run(1)
        await frames(4)
        if not ok(game.ui._vitals.visible,
                        "the walk started with its pictures hidden"):
                return false
        if not ok(not game.ui._log_label.visible,
                        "the walk started with prose painted on it"):
                return false

        game._pause_game()
        await frames(3)
        if not ok(not game.ui._vitals.visible,
                        "the pause card should own the readout while it is open"):
                return false

        game._resume_game()
        await frames(3)
        if not ok(game.ui._vitals.visible,
                        "resuming left the walk screen with no lantern ring, sparkles or depth"):
                return false
        if not ok(not game.ui._log_label.visible,
                        "resuming left Mote's chatter painted on the walk screen"):
                return false

        # It must be a steady state, not a one-frame flicker: pause again and the
        # pictures have to come back again.
        game._pause_game()
        await frames(3)
        game._resume_game()
        await frames(3)
        if not ok(game.ui._vitals.visible and not game.ui._log_label.visible,
                        "a second pause/resume cycle did not restore the pictures either"):
                return false
        return true

func _check_a_relayout_does_not_resurrect_the_hidden_log(game: Node) -> bool:
        ## Start of a walk hides the white chatter (set_text_chrome_visible(false)).
        ## On a touch device the very NEXT relayout -- a window resize, a slider
        ## change, a panel close -- used to re-read the layout's own answer and
        ## paint Mote's log right back onto the play screen.
        game._start_run(1)
        await frames(4)
        ok(not game.ui._log_label.visible, "the walk started with its log painted")
        game.ui._touch_root.visible = true
        game.ui._fit_layout()
        await frames(2)
        if not ok(not game.ui._log_label.visible,
                        "a relayout resurrected the hidden log on a touch device"):
                return false
        game.ui._touch_root.visible = false
        return true

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
## The point-4 contract: no SING, DASH or ASCEND plate may ever sit on the
## walk screen. The verbs moved out of the corner -- the pause card's keys
## line tells them, and the golden hint beside the object carries the action
## itself -- so if a plate with one of those words ever grows back under the
## TouchControls root, this check names it.
func _check_the_walk_screen_offers_no_action_plates(game: Node) -> bool:
        game._start_run(1)
        await frames(6)
        # The cluster is touchscreen-only and headless is not; the relayout
        # check above uses the same door to walk the cluster anyway.
        game.ui._touch_root.visible = true
        var banned: Array[String] = ["sing", "dash", "ascend"]
        var clean := true
        for button in buttons_in(game.ui._touch_root):
                var row := button as Button
                if row == null:
                        continue
                var text := row_text(row).to_lower()
                for word in banned:
                        if text.contains(word):
                                ok(false, "the walk screen grew a %s plate back: %s" % [word, text])
                                clean = false
        if clean:
                if not ok(true, "the walk screen carries no SING, DASH or ASCEND plate"):
                        return false
        game.ui._touch_root.visible = false
        return clean

## The golden hint is the whole action layer now: on a touchscreen it is the
## button. So it must appear when the director names a verb, answer a press
## with the very signal the E key speaks through, and leave when the verb
## goes. A hint that only LOOKS tappable would strand a touch-only player
## beside every stair in the forest.
func _check_the_golden_hint_answers_a_tap(game: Node) -> bool:
        game._start_run(1)
        await frames(6)
        var fired: Array[bool] = [false]
        game.ui.touch_interact_requested.connect(func(): fired[0] = true)
        game.ui.show_context_hint("Descend")
        await frames(2)
        var pill := game.ui._context_hint as BaseButton
        if not ok(pill != null and pill.visible,
                        "the golden hint did not appear when a verb was named"):
                return false
        pill.pressed.emit()
        await frames(1)
        if not ok(fired[0], "tapping the golden hint did not speak the interact signal"):
                return false
        game.ui.show_context_hint("")
        await frames(2)
        return ok(not game.ui._context_hint.visible,
                        "the golden hint stayed on the screen after its verb left")
