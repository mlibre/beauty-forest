extends "res://tests/support/test_case.gd"
## The story intro: the menu's Play button tells three pages over the still
## menu forest, then starts floor 1; taps and keys turn pages, Escape and Skip
## end the telling, and a direct start_requested never meets the intro at all.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const GameScene := preload("res://scenes/main.tscn")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_INTRO_REGRESSION"
    call_deferred("_run")

func _run() -> void:
    var game: Node = GameScene.instantiate()
    root.add_child(game)
    await frames(4)
    if not ok(game.mode == game.Mode.MENU, "boot did not land on the menu (mode %d)" % int(game.mode)):
        stop(null, suite_name)
        return

    # PLAY tells the story: menu card down, storybook up, still MENU.
    var play := _find_button(game, "Play")
    if not ok(play != null, "the menu offered no Play button"):
        stop(null, suite_name)
        return
    play.pressed.emit()
    await frames(2)
    if not ok(game._intro_active, "pressing Play did not begin the story"):
        stop(null, suite_name)
        return
    if not ok(game.mode == game.Mode.MENU, "the story left the menu (mode %d)" % int(game.mode)):
        stop(null, suite_name)
        return
    if not ok(game.ui._intro_root.visible, "the storybook did not show"):
        stop(null, suite_name)
        return
    if not ok(not game.ui._overlay_card.visible, "the menu card stayed up under the storybook"):
        stop(null, suite_name)
        return
    var first_title := String(game.ui._intro_title.text)
    if not ok(not first_title.is_empty(), "the first story page has no title"):
        stop(null, suite_name)
        return

    # A tap turns the page; the pages actually change.
    game.ui.intro_advance_requested.emit()
    await frames(2)
    if not ok(String(game.ui._intro_title.text) != first_title, "turning the page repainted the same title"):
        stop(null, suite_name)
        return
    # Any key turns it too (the path a keyboard walker lives on).
    var key := InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_SPACE
    game._unhandled_input(key)
    await frames(2)
    if not ok(game._intro_active and game._intro_page == 2, "a key press did not advance the story (page %d)" % game._intro_page):
        stop(null, suite_name)
        return
    # The storybook is an illustrated book now: one progress dot per page,
    # a tinted glow plate behind each picture, and every page carrying its
    # own tint and glyph.
    if not ok(game.ui._intro_dots.get_child_count() == game.INTRO_PAGES.size(),
            "the progress dots did not grow one per page (%d dots for %d pages)" % [
                game.ui._intro_dots.get_child_count(), game.INTRO_PAGES.size()]):
        stop(null, suite_name)
        return
    if not ok(game.ui._intro_glow != null and is_instance_valid(game.ui._intro_glow),
            "the page's glow plate never built"):
        stop(null, suite_name)
        return
    var tints := {}
    for page: Dictionary in game.INTRO_PAGES:
        if page.has("tint") and page["tint"] is Color:
            tints[page["title"]] = true
    if not ok(tints.size() == game.INTRO_PAGES.size(), "a story page is missing its tint"):
        stop(null, suite_name)
        return

    # The remaining turns land on floor 1, PLAYING, storybook down. The
    # story is five pages now; turn until it ends rather than assuming a
    # fixed count, so the contract is "the telling finishes" and not
    # "the telling is exactly this long".
    var turns := 0
    while game._intro_active and turns < game.INTRO_PAGES.size() + 2:
        game.ui.intro_advance_requested.emit()
        await frames(2)
        turns += 1
    if not ok(not game._intro_active, "the story never ended"):
        stop(null, suite_name)
        return
    if not ok(game.mode == game.Mode.PLAYING and game.floor_number == 1,
            "the story's end did not start floor 1 (mode %d, floor %d)" % [int(game.mode), game.floor_number]):
        stop(null, suite_name)
        return
    if not ok(not game.ui._intro_root.visible, "the storybook stayed up after the walk began"):
        stop(null, suite_name)
        return

    # Escape ends the whole telling in one press.
    game._back_to_title()
    await frames(3)
    play = _find_button(game, "Play")
    play.pressed.emit()
    await frames(2)
    if not ok(game._intro_active, "the second telling did not begin"):
        stop(null, suite_name)
        return
    var escape := InputEventKey.new()
    escape.pressed = true
    escape.keycode = KEY_ESCAPE
    game._unhandled_input(escape)
    await frames(4)
    if not ok(not game._intro_active and game.mode == game.Mode.PLAYING,
            "Escape during the story did not start the walk (mode %d)" % int(game.mode)):
        stop(null, suite_name)
        return

    # A direct start_requested IS the walk: no story in the way.
    game._back_to_title()
    await frames(3)
    game.ui.start_requested.emit("standard")
    await frames(4)
    if not ok(game.mode == game.Mode.PLAYING and not game._intro_active,
            "a direct start got tangled in the story (mode %d)" % int(game.mode)):
        stop(null, suite_name)
        return

    # A menu asked for mid-telling ends the telling cleanly.
    game._back_to_title()
    await frames(3)
    play = _find_button(game, "Play")
    play.pressed.emit()
    await frames(2)
    game._show_menu()
    await frames(3)
    if not ok(not game._intro_active and game.mode == game.Mode.MENU and game.ui._overlay_card.visible,
            "a menu request left the story half-told underneath"):
        stop(null, suite_name)
        return
    if not ok(not game.ui._intro_root.visible, "the storybook stayed visible under the menu"):
        stop(null, suite_name)
        return

    # AudioServer drains stopped playbacks asynchronously (see the same note
    # in runtime_smoke.gd); quitting before it settles leaks ObjectDB refs.
    await frames(30)
    game.free()
    await frames(1)
    finish(null, "BEAUTY_FOREST_INTRO_REGRESSION")

func _find_button(game: Node, label: String) -> Button:
    var found: Button = null
    for candidate in game.ui._overlay_content.find_children("*", "Button", true, false):
        var button := candidate as Button
        if button != null and button.text == label:
            found = button
    return found
