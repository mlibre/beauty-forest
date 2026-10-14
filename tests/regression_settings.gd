extends "res://tests/support/test_case.gd"
## The gentler-forest panel is reachable from everywhere a player might want to
## change how the forest feels, and it hands them back to the screen they opened
## it from.
##
## Split out of regression_main_flow.gd. These checks are all about navigating
## TO a panel and back again, which needs no combat or loadout fixture -- so
## giving them their own suite keeps each one about one thing.
##
## The bodies moved verbatim from regression_main_flow.gd; only the helper names
## changed, to the ones on TestCase.

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_SETTINGS"
    TestProfile.begin("settings")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)

    if not await _check_settings_open_from_every_modal(game):
        return
    if not await _check_settings_open_from_the_menu(game):
        return
    if not await _check_settings_back_button_names_where_it_goes(game):
        return

    # The pause card's own keys line promises "Comfort options: C" -- painted on
    # the very card where the key answered nothing. The key must open the
    # panel from the pause card exactly like its button does, and closing it
    # must hand the pause card back.
    game._start_run(2)
    await frames(4)
    game._pause_game()
    await frames(3)
    var pause_key := InputEventKey.new()
    pause_key.pressed = true
    pause_key.physical_keycode = KEY_C
    game._unhandled_input(pause_key)
    await frames(3)
    if not ok(game.mode == game.Mode.SETTINGS,
            "the C key did nothing from the pause card its own keys line advertises it on (mode %d)" % game.mode):
        return
    game.ui.settings_closed.emit()
    await frames(3)
    if not ok(game.mode == game.Mode.PAUSED,
            "leaving settings opened from the pause card did not hand the pause card back (mode %d)" % game.mode):
        return

    if not await _check_settings_hands_the_nap_and_ending_cards_back(game):
        return

    if not await _check_a_slider_drag_applies_once(game):
        return

    if not await _check_the_calm_toggle_reaches_the_glow(game):
        return

    finish(game, "BEAUTY_FOREST_SETTINGS")

func _check_a_slider_drag_applies_once(game: Node) -> bool:
    ## A slider fires value_changed for every tick of a drag, and the panel
    ## used to pay the FULL pipeline once per tick: a settings-file write, a
    ## full interface refresh, a whole responsive layout pass, and a second
    ## write from the director -- dozens of times for one drag, stuttering the
    ## frame budget on every platform. The drag now applies ONCE, shortly
    ## after the last tick; the value label still follows the handle live;
    ## toggles still apply the moment they are pressed.
    game.ui.close_panels()
    game.ui.show_settings(game.ui._settings)
    await frames(4)
    var emissions := [0]
    game.ui.settings_changed.connect(func(_value): emissions[0] += 1)
    var row := _find_slider_row(game.ui._shop_content, "Text size")
    if not ok(row != null, "the Text size row is missing"):
        return false
    var slider: HSlider = null
    var value_label: Label = null
    for child in row.get_children():
        if child is HSlider:
            slider = child
        elif child is Label and child != row.get_child(0) and (child as Label).text.begins_with("%"):
            value_label = child
    if not ok(slider != null, "the Text size row has no slider"):
        return false
    # Six rapid ticks: one drag, six value_changed emissions from the handle.
    for tick in [1.1, 1.2, 1.3, 1.4, 1.5, 1.6]:
        slider.value = tick
    await frames(2)
    if value_label == null:
        # The label lives at the row's end; find it the honest way if the
        # heuristic above missed.
        for child in row.get_children():
            if child is Label and (child as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
                value_label = child
    ok(value_label != null and value_label.text == "160%",
            "the value label did not follow the handle live (got %s)" % (value_label.text if value_label != null else "nothing"))
    ok(emissions[0] == 0,
            "a drag applied %d times BEFORE the settle -- the jank the debounce exists to remove" % emissions[0])
    # The settle is 0.3 WALL seconds (a Timer, not a frame count): headless
    # frames run uncapped, so awaiting frames would outpace the clock the
    # player's own device ticks on.
    await root.get_tree().create_timer(0.5).timeout
    await frames(2)
    ok(emissions[0] == 1,
            "a six-tick drag emitted settings_changed %d times (want exactly 1 after the settle)" % emissions[0])
    ok(is_equal_approx(float(game.ui._settings.get("text_scale", 0.0)), 1.6),
            "the settled settings lost the last tick's value (%s)" % str(game.ui._settings.get("text_scale")))
    # A toggle is a discrete press: it applies the moment it happens, not on
    # a timer.
    var before: int = emissions[0]
    game.ui._settings["muted"] = not bool(game.ui._settings.get("muted", false))
    game.ui._emit_settings()
    await frames(2)
    ok(emissions[0] == before + 1, "a toggle did not apply immediately")
    game.ui.close_panels()
    await frames(2)
    return true

func _find_slider_row(node: Node, title: String) -> HBoxContainer:
    for row in _slider_rows(node):
        for lbl in row.find_children("*", "Label", true, false):
            var label := lbl as Label
            if label != null and label.text == title:
                return row
    return null

func _slider_rows(node: Node) -> Array[HBoxContainer]:
    var out: Array[HBoxContainer] = []
    for child in node.get_children():
        if child is HBoxContainer:
            out.append(child)
        out.append_array(_slider_rows(child))
    return out

func _check_settings_open_from_every_modal(game: Node) -> bool:
    ## The COMFORT button stays lit and enabled while Peddle's cart or the memory
    ## book is open, so pressing it has to do something. _open_settings used to
    ## early-return in SHOP and JOURNAL, so the press vanished with no log line
    ## and no panel — and settings was unreachable from either modal.
    for origin in ["journal", "shop"]:
        game._start_run(2)
        await frames(4)
        if origin == "journal":
            game._open_journal()
        else:
            # The cart only opens at Peddle's actual position.
            game.player.global_position = game.world.merchant_position + Vector3(1.0, 0.0, 0.0)
            await frames(2)
            game._open_shop()
        await frames(3)
        if not ok(game.mode in [game.Mode.SHOP, game.Mode.JOURNAL],
                "the %s did not open (mode %d)" % [origin, game.mode]):
            return false
        game._open_settings()
        await frames(3)
        if not ok(game.mode == game.Mode.SETTINGS,
                "COMFORT did nothing while the %s was open (mode stayed %d)" % [origin, game.mode]):
            return false
        # The cart, the memory book and the settings panel deliberately share
        # one card, which gets refilled -- so what must change is the CONTENT,
        # not the card. "Make it yours" is the settings heading.
        var headings := 0
        for label in texts_in(game.ui._shop_frame):
            if label.contains("Make it yours") or label.contains("memory book"):
                headings += 1
        if not ok(headings == 1 and has_text(game.ui._shop_frame, "Make it yours"),
                "the %s content was left on screen instead of the settings panel" % origin):
            return false
        game.ui.settings_closed.emit()
        await frames(3)
        if not ok(game.mode == game.Mode.PLAYING,
                "closing settings did not return to play from the %s (mode %d)" % [origin, game.mode]):
            return false
        if not ok(game.player.control_enabled,
                "the hero was left unable to move after closing settings from the %s" % origin):
            return false
    if not await _check_settings_open_from_the_menu(game):
        return false
    if not await _check_settings_back_button_names_where_it_goes(game):
        return false
    game._start_run(1)
    await frames(4)
    return true

func _check_settings_open_from_the_menu(game: Node) -> bool:
    ## The menu's own key line advertises "Comfort options: C", but nothing on that
    ## screen emitted settings_open_requested and _unhandled_input returned
    ## before the bf_settings branch in every non-playing mode -- so the only way
    ## in was to start a run, pause it, and find COMFORT from there. A player who
    ## wants the gentler forest had to be inside a run to ask for it.
    if not await _open_settings_from_the_menu(game, "the button"):
        return false
    # The same promise, made by the key line, has to hold for the key itself.
    if not await _open_settings_from_the_menu(game, "the C key"):
        return false
    game._show_menu()
    await frames(3)
    return true

func _open_settings_from_the_menu(game: Node, way: String) -> bool:
    game._show_menu()
    await frames(3)
    if not ok(game.mode == game.Mode.MENU, "the menu did not open for %s (mode %d)" % [way, game.mode]):
        return false
    if way == "the button":
        var cozy: Button = null
        for candidate in game.ui._overlay_content.find_children("*", "Button", true, false):
            if (candidate as Button).text.contains("Comfort options"):
                cozy = candidate as Button
        if not ok(cozy != null, "the menu offered no way into the comfort-options panel"):
            return false
        cozy.pressed.emit()
    else:
        var key := InputEventKey.new()
        key.pressed = true
        key.physical_keycode = KEY_C
        game._unhandled_input(key)
    await frames(3)
    if not ok(game.mode == game.Mode.SETTINGS,
            "%s did nothing from the menu (mode stayed %d)" % [way, game.mode]):
        return false
    if not ok(has_text(game.ui._shop_frame, "Make it yours"),
            "closing the menu for %s left the menu content on screen instead of the settings panel" % way):
        return false
    game.ui.settings_closed.emit()
    await frames(3)
    # Closing has to hand the MENU back, not close every panel and leave the
    # player staring at an empty screen.
    if not ok(game.mode == game.Mode.MENU,
            "closing settings did not return to the menu after %s (mode %d)" % [way, game.mode]):
        return false
    return ok(game.ui._overlay_card.visible,
            "the menu card was left hidden after closing settings opened by %s" % way)

func _check_settings_back_button_names_where_it_goes(game: Node) -> bool:
    ## The panel's Back button read "Back to the walk" from every screen that
    ## can open it, but only one of those returns to a walk: the menu has no walk
    ## at all, and Peddle's cart or the memory book are closed on the way in, so
    ## the player lands in play -- the walk. The button must name the screen the
    ## director will actually restore, or it promises a destination the game does
    ## not deliver.
    var wanted := {"menu": "the menu", "pause": "the pause card", "play": "the walk"}
    for origin: String in wanted:
        if origin == "menu":
            game._show_menu()
        else:
            game._start_run(2)
            await frames(4)
            if origin == "pause":
                game._pause_game()
        await frames(3)
        # From any origin the director routes the press; the origin only decides
        # which screen we stand on before asking for the panel.
        game._open_settings()
        await frames(3)
        var label := ""
        for candidate in game.ui._shop_frame.find_children("*", "Button", true, false):
            if (candidate as Button).text.begins_with("Back to"):
                label = (candidate as Button).text
        if not ok(label == "Back to %s" % wanted[origin],
                "from the %s the settings Back button says %s" % [origin, label if label != "" else "nothing"]):
            return false
        # Pressing Restore must not re-point the button at a hardcoded screen.
        for candidate in game.ui._shop_frame.find_children("*", "Button", true, false):
            if (candidate as Button).text.contains("Restore gentle defaults"):
                (candidate as Button).pressed.emit()
        await frames(3)
        label = ""
        for candidate in game.ui._shop_frame.find_children("*", "Button", true, false):
            if (candidate as Button).text.begins_with("Back to"):
                label = (candidate as Button).text
        if not ok(label == "Back to %s" % wanted[origin],
                "Restore from the %s re-pointed the Back button to %s" % [origin, label if label != "" else "nothing"]):
            return false
        game.ui.settings_closed.emit()
        await frames(3)
    return true

func _check_settings_hands_the_nap_and_ending_cards_back(game: Node) -> bool:
    ## The COMFORT button sits above the overlay scrim, so on a touchscreen it
    ## answers from the nap and ending cards too -- and leaving settings used
    ## to run close_panels(), which hides exactly the overlay card those modes
    ## still live on: a touch player closed the panel into an empty frozen
    ## world where nothing could bring the nap back. The Back button also
    ## promised "the menu" from both. Leaving settings now re-raises the card
    ## it came from, under its own name.
    game._start_run(2)
    await frames(4)
    game.mode = game.Mode.DEAD
    game.ui.show_death(game.floor_number, game.meta)
    await frames(2)
    game.ui.settings_open_requested.emit()
    await frames(3)
    if not ok(game.mode == game.Mode.SETTINGS,
            "COMFORT did nothing on the nap card (mode %d)" % game.mode):
        return false
    var label := ""
    for candidate in game.ui._shop_frame.find_children("*", "Button", true, false):
        if (candidate as Button).text.begins_with("Back to"):
            label = (candidate as Button).text
    if not ok(label == "Back to the nap card",
            "from the nap card the settings Back button says %s" % [label if label != "" else "nothing"]):
        return false
    game.ui.close_settings()
    await frames(3)
    if not ok(game.mode == game.Mode.DEAD,
            "leaving settings did not hand back the nap (mode %d)" % game.mode):
        return false
    if not ok(game.ui._overlay_card.visible,
            "leaving settings erased the nap card -- a touch player has no way back to it"):
        return false
    game.mode = game.Mode.ENDING
    game.ui.show_ending(int(game.meta.get("dragons_sung", 0)), game.meta)
    await frames(2)
    game.ui.settings_open_requested.emit()
    await frames(3)
    if not ok(game.mode == game.Mode.SETTINGS,
            "COMFORT did nothing on the ending card (mode %d)" % game.mode):
        return false
    game.ui.close_settings()
    await frames(3)
    if not ok(game.mode == game.Mode.ENDING and game.ui._overlay_card.visible,
            "leaving settings did not hand back the ending card (mode %d, card visible %s)" % [
                    game.mode, str(game.ui._overlay_card.visible)]):
        return false
    print("SETTINGS nap/ending: the card comes back, under its own name")
    return true

func _check_the_calm_toggle_reaches_the_glow(game: Node) -> bool:
    ## Reduced Motion used to stop at the world, the wisps and the hero: the
    ## waypoint glow took the setting only at birth, so one raised before the
    ## toggle kept bobbing and pulsing against the calm the player had asked
    ## every other piece of the forest for. The run's own settings handler now
    ## carries it, and the suite holds the propagation open BOTH ways -- a
    ## toggle that can only switch things on is half a toggle.
    game._start_run(2)
    await frames(4)
    game._set_waypoint_active(true)
    await frames(2)
    if not ok(game._waypoint != null and is_instance_valid(game._waypoint),
            "the waypoint glow never rose for the calm-toggle check"):
        return false
    if not ok(not game._waypoint._reduced_motion,
            "a fresh waypoint did not follow the setting the run already holds"):
        return false
    var calm: Dictionary = game.settings.duplicate(true)
    calm["reduced_motion"] = true
    game._apply_settings(calm)
    if not ok(game._waypoint._reduced_motion,
            "the calm toggle did not reach a waypoint raised before it"):
        return false
    if not ok(game.world._reduced_motion,
            "the calm toggle no longer reaches the world beside the waypoint"):
        return false
    calm["reduced_motion"] = false
    game._apply_settings(calm)
    if not ok(not game._waypoint._reduced_motion,
            "the calm toggle's exit did not release the waypoint either"):
        return false
    return true
