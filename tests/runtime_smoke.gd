extends SceneTree

## Headless integration smoke test. Exercises menu boot, a live floor,
## progression/soothe rewards, shops/journal, and both dragon chamber types.
##
## assert() only logs a SCRIPT ERROR here and keeps going, so this suite used to
## print SMOKE_OK and exit 0 with a broken run flow. Every gate collects into
## _failures instead, matching regression_graphics.gd.

var _failures: Array[String] = []

func _check(condition: bool, message: String) -> bool:
    if not condition:
        _failures.append(message)
    return condition

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
    _check(game.mode == game.Mode.PLAYING, "the run did not enter PLAYING")
    _check(game.wisps.size() >= 8, "floor one spawned only %d wisps" % game.wisps.size())
    game._gain_xp(18)
    _check(game.level >= 2, "gaining 18 xp left the hero at level %d" % game.level)
    if not game.wisps.is_empty():
        game._soothe_wisp(game.wisps[0], false)
    game.merchant_exists = true
    game.player.global_position = game.world.merchant_position
    game._open_shop()
    game.sparkles = 20
    game._on_buy_requested("boots")
    _check(game.charms_owned.get("boots", false), "buying Swift Boots did not put it in the satchel")
    _check(game.charms_equipped.get("boots", false), "buying Swift Boots did not wear it")
    await _frames(3)
    game._on_shop_closed()
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._on_stanza_equip_requested("dawn")
    _check(game.stanzas_equipped.size() == 2, "equipping Dawn over a full pair left %d songs" % game.stanzas_equipped.size())
    _check(game.stanzas_equipped.get("dawn", false), "equipping Dawn did not wear it")
    game._pause_game()
    game.ui.settings_open_requested.emit()
    await _frames(2)
    _check(game.mode == game.Mode.SETTINGS, "COZY from the pause menu did not open the settings")
    game._on_settings_closed()
    _check(game.mode == game.Mode.PAUSED, "closing the settings left the game in %s" % str(game.mode))
    game._resume_game()
    game._open_journal()
    await _frames(3)
    game._on_journal_closed()

    for floor_number in [4, 5, 8, 12, 13]:
        game._load_floor(floor_number, false)
        await _frames(8)
        _check(game.world != null, "floor %d built no world" % floor_number)
        if BeautyContent.is_dragon_floor(floor_number):
            _check(game.dragon_exists, "dragon floor %d has no dragon" % floor_number)
            _check(game.world.chimes.size() == 5, "dragon floor %d has %d chimes" % [floor_number, game.world.chimes.size()])
            if floor_number == 5:
                game._lullaby_active = true
                game._lullaby_kind = "dragon"
                game._dragon_hits = 3
                game._lullaby_gold = true
                game._judge_lullaby_beat()
                _check(game.stair_visible, "finishing the dragon lullaby on floor 5 revealed no stairs")
        if BeautyContent.FEELINGS.has(BeautyContent.story_floor(floor_number)):
            _check(game._has_feeling_floor(), "floor %d should host a Big Feeling" % floor_number)
            var feeling: Wisp = null
            for candidate: Wisp in game.wisps:
                if candidate.is_feeling:
                    feeling = candidate
                    break
            if _check(feeling != null, "floor %d spawned no Big Feeling wisp" % floor_number):
                game._begin_feeling_lullaby(feeling)
                game._lullaby_gold = true
                game._feeling_hits = 2
                game._feeling_round = 2
                game._judge_lullaby_beat()
                _check(not game._lullaby_active, "the Big Feeling lullaby on floor %d never finished" % floor_number)

    if _failures.is_empty():
        print("BEAUTY_FOREST_SMOKE_OK")
    else:
        for failure in _failures:
            printerr("SMOKE_REGRESSION_FAIL: " + failure)
    TestProfile.end()
    root.remove_child(game)
    game.free()
    # AudioServer drains stopped playbacks asynchronously (see the same note
    # in regression_audio.gd); quitting before it settles leaks
    # AudioStreamPlayback refs at exit.
    await _frames(30)
    quit(1 if _failures.size() > 0 else 0)

func _frames(count: int) -> void:
    for _frame in range(count):
        await process_frame