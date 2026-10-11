extends "res://tests/support/test_case.gd"
## How a run ends, and the dragon floor's tail: the frame that kills must stop
## everything queued behind it, a parked chime must start the lullaby, the
## epilogue must gate the controls, the finale delay must belong to gameplay,
## and the chimes must gather themselves with an honest pickup count. Split
## out of regression_main_flow.gd by the 500-line rule; the question is a
## different one (endings, not transitions), so it lives in its own suite.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const Wisp := preload("res://scripts/wisp.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_FINALE"
    TestProfile.begin("finale")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)

    # The frame that ends the run must end it. A lethal contact bump switches
    # mode to DEAD inside the wisp loop, and everything queued after that loop
    # (automatic combat, chime pickups, the song ceremonies) used to keep
    # running: on a dragon floor the final Dream Chime gathered in the same
    # frame, so the lullaby began and painted "The Lullaby" over the nap screen.
    game._start_run(1)
    await frames(4)
    game._load_floor(5, false)
    await frames(6)
    var killer: Wisp = null
    for wisp: Wisp in game.wisps:
        if is_instance_valid(wisp) and wisp.alive and not wisp.is_big and not wisp.is_feeling:
            killer = wisp
            break
    if not ok(killer != null, "the dragon floor spawned no plain wisp to end the run with"):
        return
    killer.set_shielded(false)
    killer.global_position = game.player.global_position + Vector3(0.5, 0.0, 0.0)
    killer.set_meta("attack_cooldown", 0.0)
    killer.set_meta("said_grumble", true)
    # Park the last chime on the hero so collecting it would start the lullaby.
    while game.world.chimes.size() > 1:
        var extra: Node3D = game.world.chimes[0]
        game.world.chimes.remove_at(0)
        game.world.remove_child(extra)
        extra.queue_free()
    game.world.chimes[0].global_position = game.player.global_position + Vector3(0.9, 0.0, 0.0)
    game.hp = 1.0
    game.invulnerable_time = 0.0
    game.player.invulnerable_time = 0.0
    await physics_frame
    await physics_frame
    if not ok(game.mode == game.Mode.DEAD, "the lethal bump did not end the run (mode %d)" % game.mode):
        return
    if not ok(not game._lullaby_active, "a song ceremony started on the frame that ended the run"):
        return
    if not ok(not game.ui._story_card.visible, "the lullaby story card was left on top of the nap screen"):
        return
    game._start_run(1)
    await frames(4)

    # The short final lullaby epilogue must not let the remaining wisps finish
    # the player while the ending story is still playing. A dragon song is a
    # success state: the player should be safely held until the ending screen.
    for old_wisp: Wisp in game.wisps:
        if is_instance_valid(old_wisp):
            game.world.remove_child(old_wisp)
            old_wisp.queue_free()
    game.wisps.clear()
    var finale_wisp := Wisp.new()
    finale_wisp.setup("Shambler", game.floor_number)
    finale_wisp.position = game.player.global_position + Vector3(0.5, 0.0, 0.0)
    finale_wisp.set_meta("attack_cooldown", 0.0)
    finale_wisp.set_meta("said_grumble", true)
    game.world.add_child(finale_wisp)
    game.wisps.append(finale_wisp)
    game.pulse_cooldown = 9999.0
    game.note_cooldown = 9999.0
    game.invulnerable_time = 0.0
    game.player.invulnerable_time = 0.0
    game.hp = 1.0
    game.dragon_exists = true
    game.dragon_finale = true
    game.world.dragon_position = game.player.global_position + Vector3(0.0, 0.0, 3.0)
    game._win_dragon()
    game.ending_countdown = 10.0
    game.player.move_direction = Vector3(1.0, 0.0, 0.0)
    game.player.dash_cooldown = 0.0
    game._touch_dash()
    if not ok(is_zero_approx(game.player.dash_time), "touch Dash still started during the finale epilogue"):
        return
    # Hug/Sing is gated the same way Dash is. During the epilogue the controls
    # are off and the ending story owns the screen, but E and the touch button
    # still answered with a stray "wander toward whatever is glowing" line.
    game.ui._log_label.text = ""
    game.ui.touch_interact_requested.emit()
    await frames(2)
    if not ok(game.ui._log_label.text.is_empty(), "Hug/Sing still answered during the finale epilogue: %s" % game.ui._log_label.text):
        return
    game.ui._log_label.text = ""
    game._try_interact()
    await frames(2)
    if not ok(game.ui._log_label.text.is_empty(), "E still answered during the finale epilogue: %s" % game.ui._log_label.text):
        return
    if not ok(game.ui._story_card.visible, "the finale story was replaced by an interaction"):
        return
    await frames(8)
    if not ok(game.mode == game.Mode.PLAYING, "a successful finale was interrupted by a wisp"):
        return
    if not ok(is_equal_approx(game.hp, 1.0), "a successful finale let a wisp damage the player"):
        return
    if not ok(not game.player.control_enabled, "the player could still wander during the finale epilogue"):
        return
    game._open_journal()
    await frames(2)
    if not ok(game.mode == game.Mode.JOURNAL, "the journal did not open during the finale epilogue"):
        return
    game._on_journal_closed()
    await frames(2)
    if not ok(not game.player.control_enabled, "closing the journal re-enabled control during the finale epilogue"):
        return
    game._pause_game()
    await frames(2)
    game._resume_game()
    await frames(2)
    if not ok(not game.player.control_enabled, "resuming a paused finale re-enabled player control"):
        return
    game.ending_pending = false
    game.ending_countdown = 0.0
    game.dragon_finale = false
    game.dragon_exists = false
    game.wisps.clear()
    game.player.set_control_enabled(true)

    # A finale delay belongs to active gameplay, not to modal wall-clock time.
    game.ending_pending = true
    game.ending_countdown = 0.01
    game._pause_game()
    var paused_countdown: float = game.ending_countdown
    await frames(6)
    if not ok(game.mode == game.Mode.PAUSED, "finale delay advanced while paused"):
        return
    if not ok(game.ending_pending, "finale pending state was cleared while paused"):
        return
    if not ok(is_equal_approx(game.ending_countdown, paused_countdown), "finale countdown changed while paused"):
        return
    if not ok(game.ui._hud.visible, "pause UI was replaced by the ending UI"):
        return

    game._resume_game()
    await frames(4)
    if not ok(game.mode == game.Mode.ENDING, "finale did not complete during PLAYING"):
        return
    if not ok(not game.ending_pending, "completed finale remained pending"):
        return
    if not ok(not game.ui._hud.visible, "ending UI did not replace the gameplay HUD"):
        return

    # "Wander deeper" continues the SAME walk. Sparkles, level and charms
    # earned on the journey must survive it; only a fresh walk may reset them.
    var earned_sparkles: int = game.sparkles + 40
    var earned_level: int = 5
    var earned_xp: int = game.xp
    game.sparkles = earned_sparkles
    game.level = earned_level
    game.charms_owned = loadout(["boots"])
    game.charms_equipped = loadout(["boots"])
    var ending_floor: int = game.floor_number
    var visits_before_continue := int(game.meta.get("runs", 0))
    game._on_restart_requested(true)
    await frames(6)
    if not ok(game.mode == game.Mode.PLAYING, "continuing deeper did not return to PLAYING"):
        return
    if not ok(game.floor_number == ending_floor + 1, "continuing deeper did not go one floor down"):
        return
    if not ok(int(game.meta.get("runs", 0)) == visits_before_continue, "continuing deeper counted a second visit for the same walk"):
        return
    if not ok(game.sparkles == earned_sparkles, "continuing deeper wiped earned sparkles (%d, expected %d)" % [game.sparkles, earned_sparkles]):
        return
    if not ok(game.level == earned_level, "continuing deeper wiped the lantern level (%d, expected %d)" % [game.level, earned_level]):
        return
    if not ok(wears(game.charms_owned, "boots"), "continuing deeper wiped an owned charm"):
        return
    if not ok(wears(game.charms_equipped, "boots"), "continuing deeper unwore equipped charms"):
        return
    if not ok(game.xp >= earned_xp, "continuing deeper wiped lantern soul"):
        return

    # Dream chimes promise to gather themselves once the hero walks close
    # ("chimes gather themselves" / "let the chime drift close on its own").
    # They used to bob in place forever, so a player who waited for them saw
    # nothing happen and the dragon floor became unclear to finish.
    game.dragon_exists = true
    game.world.build_dream_chimes(game.dungeon["rooms"][0])
    if not ok(game.world.chimes.size() == 5, "the dragon floor did not build five chimes"):
        return
    # Silence automatic combat so its chatter cannot push the pickup line out
    # of the four-line log window, and park the other four chimes far away so
    # exactly one gathers during the wait.
    for wisp: Wisp in game.wisps:
        if is_instance_valid(wisp):
            wisp.queue_free()
    game.wisps.clear()
    game.pulse_cooldown = 9999.0
    game.note_cooldown = 9999.0
    var chime: Node3D = game.world.chimes[0]
    game.player.global_position = chime.global_position + Vector3(2.6, 0.0, 0.0)
    for other: Node3D in game.world.chimes:
        if other != chime:
            other.global_position = game.player.global_position + Vector3(50.0, 0.0, 50.0)
    game.ui._log_label.text = ""
    for _step in range(90):
        await physics_frame
    if not ok(not is_instance_valid(chime), "the chime never gathered to the waiting hero"):
        return
    # The pickup log must agree with the HUD objective: it counts secured
    # chimes upward (1/5), not the remaining ones downward (4/5).
    if not ok(game.ui._log_label.text.contains("Dream Chime secured! (1/5)"), "the chime pickup log disagreed with the secured count: %s" % game.ui._log_label.text):
        return
    finish(game, "BEAUTY_FOREST_FINALE")
