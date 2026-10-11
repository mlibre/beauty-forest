extends TestCase

## Headless integration smoke test. Exercises menu boot, a live floor,
## progression/soothe rewards, shops/journal, and both dragon chamber types.

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_SMOKE"
    # Never let this suite write the player's real profile.
    TestProfile.begin("smoke")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)

    game._start_run(1)
    await frames(24)
    ok(game.mode == game.Mode.PLAYING, "the run did not enter PLAYING")
    ok(game.wisps.size() >= 8, "floor one spawned only %d wisps" % game.wisps.size())
    game._gain_xp(18)
    ok(game.level >= 2, "gaining 18 xp left the hero at level %d" % game.level)
    if not game.wisps.is_empty():
        game._soothe_wisp(game.wisps[0], false)
    game.merchant_exists = true
    game.player.global_position = game.world.merchant_position
    game._open_shop()
    game.sparkles = 20
    game._on_buy_requested("boots")
    ok(wears(game.charms_owned, "boots"), "buying Swift Boots did not put it in the satchel")
    ok(wears(game.charms_equipped, "boots"), "buying Swift Boots did not wear it")
    await frames(3)
    game._on_shop_closed()
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._on_stanza_equip_requested("dawn")
    # Verses are free and uncapped, so humming a third ADDS to the two already
    # sung. This used to assert the count stayed at 2 -- the old cap, which sent
    # a player who had found a third song back to the cart for a charm instead.
    ok(game.stanzas_equipped.size() == 3, "equipping Dawn alongside two verses left %d songs" % game.stanzas_equipped.size())
    ok(game.stanzas_equipped.get("dawn", false), "equipping Dawn did not wear it")
    # Resting it must remove only itself, leaving the other two humming.
    game._on_stanza_equip_requested("dawn")
    ok(game.stanzas_equipped.size() == 2 and not game.stanzas_equipped.get("dawn", false),
        "resting Dawn did not leave the other two songs alone: %s" % str(game.stanzas_equipped))
    game._on_stanza_equip_requested("dawn")
    game._pause_game()
    game.ui.settings_open_requested.emit()
    await frames(2)
    ok(game.mode == game.Mode.SETTINGS, "COZY from the pause menu did not open the settings")
    game._on_settings_closed()
    ok(game.mode == game.Mode.PAUSED, "closing the settings left the game in %s" % str(game.mode))
    game._resume_game()
    game._open_journal()
    await frames(3)
    game._on_journal_closed()

    for floor_number in [4, 5, 8, 12, 13]:
        game._load_floor(floor_number, false)
        await frames(8)
        ok(game.world != null, "floor %d built no world" % floor_number)
        if BeautyContent.is_dragon_floor(floor_number):
            ok(game.dragon_exists, "dragon floor %d has no dragon" % floor_number)
            ok(game.world.chimes.size() == 5, "dragon floor %d has %d chimes" % [floor_number, game.world.chimes.size()])
            if floor_number == 5:
                game._lullaby_active = true
                game._lullaby_kind = "dragon"
                game._dragon_hits = 3
                game._lullaby_gold = true
                game._judge_lullaby_beat()
                ok(game.stair_visible, "finishing the dragon lullaby on floor 5 revealed no stairs")
        if BeautyContent.FEELINGS.has(BeautyContent.story_floor(floor_number)):
            ok(game._has_feeling_floor(), "floor %d should host a Big Feeling" % floor_number)
            var feeling: Wisp = null
            for candidate: Wisp in game.wisps:
                if candidate.is_feeling:
                    feeling = candidate
                    break
            if ok(feeling != null, "floor %d spawned no Big Feeling wisp" % floor_number):
                game._begin_feeling_lullaby(feeling)
                game._lullaby_gold = true
                game._feeling_hits = 2
                game._feeling_round = 2
                game._judge_lullaby_beat()
                ok(not game._lullaby_active, "the Big Feeling lullaby on floor %d never finished" % floor_number)

    # AudioServer drains stopped playbacks asynchronously (see the same note
    # in regression_audio.gd); quitting before it settles leaks
    # AudioStreamPlayback refs at exit.
    await frames(30)
    finish(game, "BEAUTY_FOREST_SMOKE")
