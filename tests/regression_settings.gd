extends TestCase

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

    finish(game, "BEAUTY_FOREST_SETTINGS")

func _check_settings_open_from_every_modal(game: Node) -> bool:
    ## The COZY button stays lit and enabled while Peddle's cart or the memory
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
                "COZY did nothing while the %s was open (mode stayed %d)" % [origin, game.mode]):
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
    ## The menu's own key line advertises "Cozy options: C", but nothing on that
    ## screen emitted settings_open_requested and _unhandled_input returned
    ## before the bf_settings branch in every non-playing mode -- so the only way
    ## in was to start a run, pause it, and find COZY from there. A player who
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
            if (candidate as Button).text.contains("gentler"):
                cozy = candidate as Button
        if not ok(cozy != null, "the menu offered no way into the gentler-forest panel"):
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
            if (candidate as Button).text.begins_with("♥  Back to"):
                label = (candidate as Button).text
        if not ok(label == "♥  Back to %s" % wanted[origin],
                "from the %s the settings Back button says %s" % [origin, label if label != "" else "nothing"]):
            return false
        # Pressing Restore must not re-point the button at a hardcoded screen.
        for candidate in game.ui._shop_frame.find_children("*", "Button", true, false):
            if (candidate as Button).text.contains("Restore gentle defaults"):
                (candidate as Button).pressed.emit()
        await frames(3)
        label = ""
        for candidate in game.ui._shop_frame.find_children("*", "Button", true, false):
            if (candidate as Button).text.begins_with("♥  Back to"):
                label = (candidate as Button).text
        if not ok(label == "♥  Back to %s" % wanted[origin],
                "Restore from the %s re-pointed the Back button to %s" % [origin, label if label != "" else "nothing"]):
            return false
        game.ui.settings_closed.emit()
        await frames(3)
    return true
