extends SceneTree

## Headless integration smoke test. Exercises menu boot, a live floor,
## progression/soothe rewards, shops/journal, and both dragon chamber types.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # Never let this suite write the player's real profile.
    TestProfile.begin("smoke")
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    game._start_run(1)
    await _frames(24)
    assert(game.mode == game.Mode.PLAYING)
    assert(game.wisps.size() >= 8)
    game._gain_xp(18)
    assert(game.level >= 2)
    if not game.wisps.is_empty():
        game._soothe_wisp(game.wisps[0], false)
    game.merchant_exists = true
    game.player.global_position = game.world.merchant_position
    game._open_shop()
    game.sparkles = 20
    game._on_buy_requested("boots")
    assert(game.charms_owned.get("boots", false))
    assert(game.charms_equipped.get("boots", false))
    await _frames(3)
    game._on_shop_closed()
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._on_stanza_equip_requested("dawn")
    assert(game.stanzas_equipped.size() == 2)
    assert(game.stanzas_equipped.get("dawn", false))
    game._pause_game()
    game.ui.settings_open_requested.emit()
    await _frames(2)
    assert(game.mode == game.Mode.SETTINGS)
    game._on_settings_closed()
    assert(game.mode == game.Mode.PAUSED)
    game._resume_game()
    game._open_journal()
    await _frames(3)
    game._on_journal_closed()

    for floor_number in [4, 5, 8, 12, 13]:
        game._load_floor(floor_number, false)
        await _frames(8)
        assert(game.world != null)
        if BeautyContent.is_dragon_floor(floor_number):
            assert(game.dragon_exists)
            assert(game.world.chimes.size() == 5)
            if floor_number == 5:
                game._lullaby_active = true
                game._lullaby_kind = "dragon"
                game._dragon_hits = 3
                game._lullaby_gold = true
                game._judge_lullaby_beat()
                assert(game.stair_visible)
        if BeautyContent.FEELINGS.has(BeautyContent.story_floor(floor_number)):
            assert(game._has_feeling_floor())
            var feeling: Wisp = null
            for candidate: Wisp in game.wisps:
                if candidate.is_feeling:
                    feeling = candidate
                    break
            assert(feeling != null)
            game._begin_feeling_lullaby(feeling)
            game._lullaby_gold = true
            game._feeling_hits = 2
            game._feeling_round = 2
            game._judge_lullaby_beat()
            assert(not game._lullaby_active)

    print("BEAUTY_FOREST_SMOKE_OK")
    TestProfile.end()
    root.remove_child(game)
    game.free()
    # AudioServer drains stopped playbacks asynchronously (see the same note
    # in regression_audio.gd); quitting before it settles leaks
    # AudioStreamPlayback refs at exit.
    await _frames(30)
    quit(0)

func _frames(count: int) -> void:
    for _frame in range(count):
        await process_frame
