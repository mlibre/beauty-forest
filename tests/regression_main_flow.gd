extends SceneTree

## Regression coverage for central run-state transitions. In particular, an
## automatic song-note already in flight must not grant combat rewards while
## the game is paused or behind another modal.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # Never let this suite write the player's real profile.
    TestProfile.begin("main_flow")
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await _frames(2)

    game._start_run(1)
    await _frames(4)
    if not _check(game.mode == game.Mode.PLAYING, "run did not enter PLAYING"):
        return
    if not _check(not game.wisps.is_empty(), "floor spawned no wisps"):
        return

    # A heart's warmth is fixed when it drops. Changing charms before walking
    # over it must not silently recalculate the reward the player already
    # earned (the old callback rebuilt the amount from current loadout).
    var stored_heart := HeartPickup.new()
    stored_heart.heal_amount = 30.0
    game.hp = 40.0
    game.charms_equipped.clear()
    game.charm_effects = {"heart_heal": 10.0}
    game._on_heart_collected(stored_heart)
    if not _check(is_equal_approx(game.hp, 70.0), "a heart used the current charm loadout instead of its stored warmth (%f, expected 70.0)" % game.hp):
        stored_heart.free()
        return
    stored_heart.free()

    # Loading a charm must not erase max warmth earned by earlier level-ups.
    # Recomputing the loadout used to reset hp_max to the base style + scarf
    # only, so the first shop/stanza interaction silently discarded progress.
    game.hp_max = 140.0
    game.hp = 140.0
    game.level_hp_bonus = 40.0
    game.charms_owned["boots"] = true
    game._on_charm_equip_requested("boots")
    if not _check(is_equal_approx(game.hp_max, 140.0), "wearing a charm erased level-up max warmth (%f, expected 140.0)" % game.hp_max):
        return

    # Buying the Wool Scarf grants +30 max warmth exactly once, and only while
    # it is actually worn. Max warmth is recomputed from the equipped loadout on
    # every shop change, so a direct bump here was overwritten a few lines later
    # (and would have been double-counted if it had not been).
    game._pause_game()
    game.selected_style = "standard"
    game.level_hp_bonus = 0.0
    game.charms_owned.clear()
    game.charms_equipped.clear()
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game.mote_verse_key = ""
    game._recalculate_loadout(false)
    if not _check(is_equal_approx(game.hp_max, 100.0), "the scarf fixture did not start from 100 max warmth (%f)" % game.hp_max):
        return
    game.sparkles = 40
    game._on_buy_requested("scarf")
    if not _check(is_equal_approx(game.hp_max, 130.0), "a worn Wool Scarf gave %f max warmth, expected 130.0" % game.hp_max):
        return
    # Three worn charms leave no slot, so the scarf stays in the pocket and must
    # not inflate max warmth behind the player's back.
    game.charms_equipped = {"boots": true, "moss": true, "honey": true}
    game.charms_owned = {"boots": true, "moss": true, "honey": true}
    game._recalculate_loadout(false)
    var pocketed_before: float = game.hp_max
    game._on_buy_requested("scarf")
    if not _check(is_equal_approx(game.hp_max, pocketed_before), "a pocketed Wool Scarf changed max warmth (%f -> %f)" % [pocketed_before, game.hp_max]):
        return
    game._resume_game()
    await _frames(2)

    # Escape must close a modal through the same path as its visible button.
    # The direct state callback used to resume gameplay while leaving Peddle's
    # shop card and scrim on screen, so the next input landed behind a dead
    # modal instead of the walk.
    game.merchant_exists = true
    game.player.global_position = game.world.merchant_position
    game._open_shop()
    await _frames(2)
    if not _check(game.mode == game.Mode.SHOP, "shop did not open for modal-dismiss regression"):
        return
    game._close_modal()
    await _frames(2)
    if not _check(game.mode == game.Mode.PLAYING, "Escape did not close the shop"):
        return
    if not _check(not game.ui._shop_card.visible and not game.ui._shop_scrim.visible, "Escape left the shop card and scrim visible"):
        return
    if not _check(game.player.control_enabled, "Escape left the player disabled after closing the shop"):
        return

    # A Big Feeling is meant to be soothed by SITTING with it (two gentle
    # rounds of E-on-gold). The automatic lantern must never wear it down
    # instead: that skipped the whole designed moment and still handed out
    # the "sat with a Big Feeling" sticker.
    var feeling: Wisp = null
    game._spawn_feeling(8)
    for wisp: Wisp in game.wisps:
        if wisp.is_feeling:
            feeling = wisp
    if not _check(feeling != null, "the feeling floor spawned no Big Feeling"):
        return
    feeling.global_position = game.player.global_position + Vector3(1.2, 0.0, 0.0)
    feeling._boss_window = 1.0  # the gold window is open
    var feeling_health: float = feeling.health
    game._do_pulse(feeling, 2.2)
    if not _check(is_equal_approx(feeling.health, feeling_health), "the automatic pulse damaged a Big Feeling (%f -> %f)" % [feeling_health, feeling.health]):
        return
    game._do_pulse(feeling, 2.2)
    if not _check(is_equal_approx(feeling.health, feeling_health), "repeated automatic pulses damaged a Big Feeling (%f -> %f)" % [feeling_health, feeling.health]):
        return
    if not _check(feeling.alive and not feeling.soothed, "the automatic pulse soothed a Big Feeling on its own"):
        return

    # The intended path must still work: sit with it and hum on the gold.
    game._begin_feeling_lullaby(feeling)
    for _hit in range(6):
        if game._feeling_rest > 0:
            game._feeling_rest = 0  # the breathing beats have elapsed
        game._lullaby_gold = true
        game._judge_feeling_beat()
    if not _check(feeling.soothed or not is_instance_valid(feeling), "the Big Feeling could not be soothed by sitting with it"):
        return

    # A heal that cannot happen must never be charged for. Pause the live
    # floor while checking the accounting so automatic combat cannot add
    # sparkles between the direct purchase and its assertion.
    game._pause_game()
    game.hp = game.hp_max
    game.sparkles = 9
    game._on_buy_requested("tea")
    await _frames(2)
    if not _check(game.sparkles == 9, "buying Warm Tea at full warmth charged %d sparkles for nothing" % (9 - game.sparkles)):
        return
    game.hp = game.hp_max - 40.0
    game._on_buy_requested("tea")
    await _frames(2)
    if not _check(game.sparkles == 6, "a needed Warm Tea did not cost 3 sparkles (%d left)" % game.sparkles):
        return
    if not _check(game.hp == game.hp_max, "Warm Tea did not restore the warmth it promised"):
        return
    game._resume_game()
    await _frames(2)

    var target: Wisp = game.wisps[0]
    var retained: Array[Wisp] = [target]
    for wisp: Wisp in game.wisps:
        if wisp != target:
            wisp.queue_free()
    game.wisps.assign(retained)
    target.global_position = game.player.global_position + Vector3(1.0, 0.0, 0.0)
    target.health = 1000.0
    target.max_health = 1000.0
    target.set_shielded(false)
    for old_note: SongNote in game.notes:
        old_note.queue_free()
    game.notes.clear()

    game.xp = 0
    game.sparkles = 0
    game._fire_song_note(target)
    var note: SongNote = game.notes.back()
    target.health = note.damage
    game.pulse_cooldown = 9999.0
    game.note_cooldown = 9999.0

    game._pause_game()
    note.global_position = target.global_position + Vector3.UP * (0.70 * target.visual_scale)
    note.launch(Vector3.ZERO)
    await physics_frame
    await physics_frame

    if not _check(game.mode == game.Mode.PAUSED, "pause did not retain PAUSED mode"):
        return
    if not _check(is_instance_valid(target) and not target.soothed, "an in-flight song-note progressed combat while paused"):
        return
    if not _check(game.xp == 0, "combat XP was granted while paused"):
        return
    if not _check(game.sparkles == 0, "combat sparkles were granted while paused"):
        return

    game._resume_game()
    await _frames(8)
    if not _check(not is_instance_valid(target) or target.soothed, "the automatic note did not resolve after resuming"):
        return
    if not _check(game.xp > 0, "combat XP was lost after resuming"):
        return
    if not _check(game.sparkles > 0, "combat sparkles were lost after resuming"):
        return

    # Touch callbacks must obey the same gameplay boundary as keyboard input.
    var stair: Node3D = game.world.get_node("Stairwell") as Node3D
    if not _check(stair != null, "floor stairwell was unavailable for touch regression"):
        return
    game.stair_visible = true
    stair.visible = true
    game.player.global_position = stair.global_position
    game._pause_game()
    var paused_floor: int = game.floor_number
    var paused_world: ForestWorld = game.world
    game.ui.touch_interact_requested.emit()
    await _frames(4)
    if not _check(game.mode == game.Mode.PAUSED, "touch interaction changed paused mode"):
        return
    if not _check(game.floor_number == paused_floor, "touch interaction descended while paused"):
        return
    if not _check(game.world == paused_world, "touch interaction replaced the paused world"):
        return
    if not _check(not game.player.control_enabled, "paused player regained control after touch interaction"):
        return

    game._resume_game()
    game.ui.touch_interact_requested.emit()
    await _frames(4)
    if not _check(game.mode == game.Mode.PLAYING, "playing touch interaction left PLAYING mode"):
        return
    if not _check(game.floor_number == paused_floor + 1, "playing touch interaction did not descend"):
        return
    if not _check(game.world != paused_world, "playing touch interaction did not replace the floor"):
        return
    if not _check(game.player.control_enabled, "playing interaction left the player disabled"):
        return

    # The frame that ends the run must end it. A lethal contact bump switches
    # mode to DEAD inside the wisp loop, and everything queued after that loop
    # (automatic combat, chime pickups, the song ceremonies) used to keep
    # running: on a dragon floor the final Dream Chime gathered in the same
    # frame, so the lullaby began and painted "The Lullaby" over the nap screen.
    game._start_run(1)
    await _frames(4)
    game._load_floor(5, false)
    await _frames(6)
    var killer: Wisp = null
    for wisp: Wisp in game.wisps:
        if is_instance_valid(wisp) and wisp.alive and not wisp.is_big and not wisp.is_feeling:
            killer = wisp
            break
    if not _check(killer != null, "the dragon floor spawned no plain wisp to end the run with"):
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
    if not _check(game.mode == game.Mode.DEAD, "the lethal bump did not end the run (mode %d)" % game.mode):
        return
    if not _check(not game._lullaby_active, "a song ceremony started on the frame that ended the run"):
        return
    if not _check(not game.ui._story_card.visible, "the lullaby story card was left on top of the nap screen"):
        return
    game._start_run(1)
    await _frames(4)

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
    if not _check(is_zero_approx(game.player.dash_time), "touch Dash still started during the finale epilogue"):
        return
    # Hug/Sing is gated the same way Dash is. During the epilogue the controls
    # are off and the ending story owns the screen, but E and the touch button
    # still answered with a stray "wander toward whatever is glowing" line.
    game.ui._log_label.text = ""
    game.ui.touch_interact_requested.emit()
    await _frames(2)
    if not _check(game.ui._log_label.text.is_empty(), "Hug/Sing still answered during the finale epilogue: %s" % game.ui._log_label.text):
        return
    game.ui._log_label.text = ""
    game._try_interact()
    await _frames(2)
    if not _check(game.ui._log_label.text.is_empty(), "E still answered during the finale epilogue: %s" % game.ui._log_label.text):
        return
    if not _check(game.ui._story_card.visible, "the finale story was replaced by an interaction"):
        return
    await _frames(8)
    if not _check(game.mode == game.Mode.PLAYING, "a successful finale was interrupted by a wisp"):
        return
    if not _check(is_equal_approx(game.hp, 1.0), "a successful finale let a wisp damage the player"):
        return
    if not _check(not game.player.control_enabled, "the player could still wander during the finale epilogue"):
        return
    game._open_journal()
    await _frames(2)
    if not _check(game.mode == game.Mode.JOURNAL, "the journal did not open during the finale epilogue"):
        return
    game._on_journal_closed()
    await _frames(2)
    if not _check(not game.player.control_enabled, "closing the journal re-enabled control during the finale epilogue"):
        return
    game._pause_game()
    await _frames(2)
    game._resume_game()
    await _frames(2)
    if not _check(not game.player.control_enabled, "resuming a paused finale re-enabled player control"):
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
    await _frames(6)
    if not _check(game.mode == game.Mode.PAUSED, "finale delay advanced while paused"):
        return
    if not _check(game.ending_pending, "finale pending state was cleared while paused"):
        return
    if not _check(is_equal_approx(game.ending_countdown, paused_countdown), "finale countdown changed while paused"):
        return
    if not _check(game.ui._hud.visible, "pause UI was replaced by the ending UI"):
        return

    game._resume_game()
    await _frames(4)
    if not _check(game.mode == game.Mode.ENDING, "finale did not complete during PLAYING"):
        return
    if not _check(not game.ending_pending, "completed finale remained pending"):
        return
    if not _check(not game.ui._hud.visible, "ending UI did not replace the gameplay HUD"):
        return

    # "Wander deeper" continues the SAME walk. Sparkles, level and charms
    # earned on the journey must survive it; only a fresh walk may reset them.
    var earned_sparkles: int = game.sparkles + 40
    var earned_level: int = 5
    var earned_xp: int = game.xp
    game.sparkles = earned_sparkles
    game.level = earned_level
    game.charms_owned["boots"] = true
    game.charms_equipped["boots"] = true
    var ending_floor: int = game.floor_number
    var visits_before_continue := int(game.meta.get("runs", 0))
    game._on_restart_requested(true)
    await _frames(6)
    if not _check(game.mode == game.Mode.PLAYING, "continuing deeper did not return to PLAYING"):
        return
    if not _check(game.floor_number == ending_floor + 1, "continuing deeper did not go one floor down"):
        return
    if not _check(int(game.meta.get("runs", 0)) == visits_before_continue, "continuing deeper counted a second visit for the same walk"):
        return
    if not _check(game.sparkles == earned_sparkles, "continuing deeper wiped earned sparkles (%d, expected %d)" % [game.sparkles, earned_sparkles]):
        return
    if not _check(game.level == earned_level, "continuing deeper wiped the lantern level (%d, expected %d)" % [game.level, earned_level]):
        return
    if not _check(bool(game.charms_owned.get("boots", false)), "continuing deeper wiped an owned charm"):
        return
    if not _check(bool(game.charms_equipped.get("boots", false)), "continuing deeper unwore equipped charms"):
        return
    if not _check(game.xp >= earned_xp, "continuing deeper wiped lantern soul"):
        return

    # Dream chimes promise to gather themselves once the hero walks close
    # ("chimes gather themselves" / "let the chime drift close on its own").
    # They used to bob in place forever, so a player who waited for them saw
    # nothing happen and the dragon floor became unclear to finish.
    game.dragon_exists = true
    game.world.build_dream_chimes(game.dungeon["rooms"][0])
    if not _check(game.world.chimes.size() == 5, "the dragon floor did not build five chimes"):
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
    if not _check(not is_instance_valid(chime), "the chime never gathered to the waiting hero"):
        return
    # The pickup log must agree with the HUD objective: it counts secured
    # chimes upward (1/5), not the remaining ones downward (4/5).
    if not _check(game.ui._log_label.text.contains("Dream Chime secured! (1/5)"), "the chime pickup log disagreed with the secured count: %s" % game.ui._log_label.text):
        return
    game.dragon_exists = false

    # A celebration timer belongs to the hero that earned it. Soothe a wisp,
    # descend at once, and the deferred "all done being happy" must not reach the
    # hero that replaced them.
    game._start_run(1)
    await _frames(4)
    game.pulse_cooldown = 9999.0
    game.note_cooldown = 9999.0
    var celebration_wisp: Wisp = null
    for candidate: Wisp in game.wisps:
        if is_instance_valid(candidate) and candidate.alive and not candidate.soothed:
            celebration_wisp = candidate
            break
    if not _check(celebration_wisp != null, "no live wisp was available for the celebration timer regression"):
        return
    game._soothe_wisp(celebration_wisp, false)
    game._load_floor(2, false)
    await _frames(2)
    game.player.hero.set_happy(true)
    await game.get_tree().create_timer(1.0).timeout
    if not _check(game.player.hero._happy, "a stale celebration timer cleared the new hero's celebration"):
        return

    # A fresh walk from the menu still starts clean.
    game._start_run(1)
    await _frames(4)
    if not _check(game.sparkles == 0, "a fresh walk kept stale sparkles"):
        return
    if not _check(game.charms_owned.is_empty(), "a fresh walk kept stale charms"):
        return
    if not _check(game.level == 1, "a fresh walk kept a stale level"):
        return

    if not await _check_dragon_never_sleeps_in_the_spawn_clearing(game):
        return
    if not await _check_homing_note_reaches_a_very_big_wisp(game):
        return
    if not await _check_ambience_returns_after_a_non_finale_dragon(game):
        return
    if not await _check_settings_open_from_every_modal(game):
        return
    if not await _check_buying_past_the_charm_cap_says_so(game):
        return
    if not await _check_a_full_slot_swap_names_the_evicted_charm(game):
        return
    if not await _check_a_full_slot_verse_swap_says_what_steps_back(game):
        return
    if not await _check_free_items_do_not_claim_to_be_owned(game):
        return

    print("BEAUTY_FOREST_MAIN_FLOW_OK")
    TestProfile.end()
    root.remove_child(game)
    game.free()
    await _frames(12)
    quit(0)

func _check_dragon_never_sleeps_in_the_spawn_clearing(game: Node) -> bool:
    ## Snoozle is a 5m sleeping barrel with no collider, and the hero arrives at
    ## the centre of rooms[0]. The generator already sorts rooms largest-first,
    ## so the old "find the biggest room" scan just re-picked the spawn room and
    ## every dragon floor opened with the player standing inside the dragon.
    for floor_number in [5, 13]:
        game._load_floor(floor_number, false)
        await _frames(4)
        if not _check(game.dragon_exists, "floor %d should be a dragon floor" % floor_number):
            return false
        var spawn_room: Dictionary = game.dungeon["rooms"][0]
        var in_spawn: bool = game._point_in_room(game.world.dragon_position, spawn_room)
        if not _check(not in_spawn,
                "floor %d put Snoozle in the spawn clearing, on top of the hero" % floor_number):
            return false
        var separation := Vector2(
            game.world.dragon_position.x - game.player.global_position.x,
            game.world.dragon_position.z - game.player.global_position.z).length()
        if not _check(separation > 3.0,
                "floor %d spawned the hero %.2f m from Snoozle's centre" % [floor_number, separation]):
            return false
    game._start_run(1)
    await _frames(4)
    return true

func _check_homing_note_reaches_a_very_big_wisp(game: Node) -> bool:
    ## A Big Feeling renders at 3.5x scale. The note used to aim at a fixed 0.72m
    ## above the wisp while the connect test measured 0.70 * visual_scale, so the
    ## homing note converged 1.7m below the test sphere and always expired.
    for is_big in [false, true]:
        game._load_floor(3, false)
        await _frames(4)
        var target: Wisp = game.wisps[0]
        target.setup("Shambler", 13, is_big)
        target.global_position = game.player.global_position + Vector3(6.0, 0.0, 0.0)
        var note := SongNote.new()
        game.world.add_child(note)
        var connected := [false]
        var expired := [false]
        note.connected_wisp.connect(func(_w: Wisp, _n: SongNote) -> void: connected[0] = true)
        note.note_expired.connect(func(_p: Vector3, _b: bool) -> void: expired[0] = true)
        note.setup(target, 10.0, 1.0, 99.0, Color("#ffe6a0"))
        note.position = game.player.global_position + Vector3.UP * 1.2
        note.launch(Vector3(1.0, 0.0, 0.0))
        for _step in range(600):
            note._physics_process(1.0 / 60.0)
            if connected[0] or expired[0]:
                break
        var label := "a Very Big Wisp" if is_big else "a plain wisp"
        if not _check(connected[0] and not expired[0],
                "a homing song-note could not connect to %s (scale %.1f)" % [label, target.visual_scale]):
            if is_instance_valid(note):
                note.free()
            return false
        if is_instance_valid(note):
            note.free()
        await _frames(2)
    game._start_run(1)
    await _frames(4)
    return true

func _check_ambience_returns_after_a_non_finale_dragon(game: Node) -> bool:
    ## Singing Snoozle to sleep silences the grove so the lullaby reads clearly,
    ## but on a non-finale floor the hero keeps wandering. Nothing re-armed the
    ## ambience, so the rest of the run played silent until a pause or descent.
    game._start_run(5)
    await _frames(6)
    if not _check(game.audio._ambient_player.playing, "floor 5 should arrive with ambience playing"):
        return false
    game._win_dragon()
    await _frames(6)
    if not _check(game.audio._ambient_player.playing and game.audio._ambient_should_play,
            "the grove stayed silent after Snoozle snoozed, though the walk continues"):
        return false
    # The finale hands the audio over to the ending, so it must stay quiet.
    game._start_run(13)
    await _frames(6)
    game._win_dragon()
    await _frames(6)
    if not _check(not game.audio._ambient_should_play,
            "the finale ending should keep the grove hushed"):
        return false
    game._start_run(1)
    await _frames(4)
    return true

func _check_settings_open_from_every_modal(game: Node) -> bool:
    ## The COZY button stays lit and enabled while Peddle's cart or the memory
    ## book is open, so pressing it has to do something. _open_settings used to
    ## early-return in SHOP and JOURNAL, so the press vanished with no log line
    ## and no panel — and settings was unreachable from either modal.
    for origin in ["journal", "shop"]:
        game._start_run(2)
        await _frames(4)
        if origin == "journal":
            game._open_journal()
        else:
            # The cart only opens at Peddle's actual position.
            game.player.global_position = game.world.merchant_position + Vector3(1.0, 0.0, 0.0)
            await _frames(2)
            game._open_shop()
        await _frames(3)
        if not _check(game.mode in [game.Mode.SHOP, game.Mode.JOURNAL],
                "the %s did not open (mode %d)" % [origin, game.mode]):
            return false
        game._open_settings()
        await _frames(3)
        if not _check(game.mode == game.Mode.SETTINGS,
                "COZY did nothing while the %s was open (mode stayed %d)" % [origin, game.mode]):
            return false
        # The cart, the memory book and the settings panel deliberately share
        # one card, which gets refilled -- so what must change is the CONTENT,
        # not the card. "Make it yours" is the settings heading.
        var headings := 0
        for label in _texts_in(game.ui._shop_frame):
            if label.contains("Make it yours") or label.contains("memory book"):
                headings += 1
        if not _check(headings == 1 and _has_text(game.ui._shop_frame, "Make it yours"),
                "the %s content was left on screen instead of the settings panel" % origin):
            return false
        game.ui.settings_closed.emit()
        await _frames(3)
        if not _check(game.mode == game.Mode.PLAYING,
                "closing settings did not return to play from the %s (mode %d)" % [origin, game.mode]):
            return false
        if not _check(game.player.control_enabled,
                "the hero was left unable to move after closing settings from the %s" % origin):
            return false
    game._start_run(1)
    await _frames(4)
    return true

func _check_buying_past_the_charm_cap_says_so(game: Node) -> bool:
    ## Filling all three charm slots and then buying a fourth charged the
    ## sparkles and logged "One Ember Mitten... It suits you." -- while the charm
    ## sat unequipped and did nothing, with nothing anywhere saying the slots were
    ## full. A player pays for a power they never receive and has no idea why.
    game._start_run(2)
    await _frames(6)
    game.player.global_position = game.world.merchant_position + Vector3(1.0, 0.0, 0.0)
    await _frames(2)
    game.sparkles = 999
    for key in ["boots", "scarf", "echo"]:
        game._on_buy_requested(key)
    await _frames(2)
    if not _check(game.charms_equipped.size() == BeautyContent.MAX_CHARMS,
            "the fixture did not fill all %d charm slots (got %d)" % [
                BeautyContent.MAX_CHARMS, game.charms_equipped.size()]):
        return false

    game._on_buy_requested("ember")
    await _frames(2)
    if not _check(bool(game.charms_owned.get("ember", false)), "the fourth charm was not recorded as owned"):
        return false
    if not _check(not bool(game.charms_equipped.get("ember", false)),
            "the fourth charm should not auto-equip past the cap"):
        return false
    # Look for the line THIS purchase produced rather than the newest line in
    # the log: the floor keeps ticking while the shop is open, and a wisp
    # drifting home can push a line above it, which made this check fail for
    # reasons that had nothing to do with the purchase.
    var last_line: String = _newest_line_mentioning(game, "ember")
    if not _check(last_line.to_lower().contains("ember mitten"),
            "the newest log line is not about the capped purchase: %s" % last_line):
        return false
    if not _check(last_line.contains("pocket"),
            "buying a charm past the cap never says it is waiting in the pocket: %s" % last_line):
        return false
    if not _check(not last_line.contains("It suits you"),
            "Peddle still promised the capped charm would be worn: %s" % last_line):
        return false

    # The shop itself must not promise a swap it cannot describe honestly either.
    game._open_shop()
    await _frames(3)
    var ember_tip := ""
    for button in _buttons_in(game.ui._shop_frame):
        var label := (button as Button).text
        if label.to_lower().contains("ember"):
            ember_tip = (button as Button).tooltip_text
            break
    if not _check(not ember_tip.is_empty(), "the owned charm had no tooltip in the shop"):
        return false
    if not _check(ember_tip.contains("swap"),
            "the shop promised a wear the cap cannot give: %s" % ember_tip):
        return false
    game._resume_game()
    await _frames(3)
    game._start_run(1)
    await _frames(4)
    return true

func _buttons_in(node: Node) -> Array[Node]:
    var out: Array[Node] = []
    for child in node.get_children():
        if child is Button:
            out.append(child)
        out.append_array(_buttons_in(child))
    return out

func _has_text(node: Node, needle: String) -> bool:
    for text in _texts_in(node):
        if text.contains(needle):
            return true
    return false

func _texts_in(node: Node) -> Array[String]:
    var out: Array[String] = []
    for child in node.get_children():
        if child is Label:
            out.append((child as Label).text)
        elif child is Button:
            out.append((child as Button).text)
        out.append_array(_texts_in(child))
    return out

func _frames(count: int) -> void:
    for _frame in range(count):
        await process_frame

func _check(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("BEAUTY_FOREST_MAIN_FLOW_FAILED: %s" % message)
    quit(1)
    return false


## Swapping a pocketed charm in with every slot full used to evict whichever
## charm fell last in charms_owned order, and said nothing at all. The player
## watched a build change with no explanation. The eviction must be stable and
## it must be named.
func _check_a_full_slot_swap_names_the_evicted_charm(game: Node) -> bool:
    game.sparkles = 100000
    game.charms_owned = {}
    game.charms_equipped = {}
    for key in ["boots", "scarf", "echo", "ember"]:
        game._on_buy_requested(key)
        for _i in range(2):
            await _frames(2)
    if game.charms_equipped.size() < BeautyContent.MAX_CHARMS:
        print("FAIL: could not fill the charm slots to test a swap")
        return false

    var worn_before: Array = game.charms_equipped.keys()
    var owned_before: int = game.charms_owned.size()
    game._on_charm_equip_requested("ember")
    for _i in range(3):
        await _frames(2)

    var newest: String = _newest_line_mentioning(game, String(charm_name_for("ember")))
    print("CHARMSWAP equipped=%s log=%s" % [str(game.charms_equipped.keys()), newest])

    if not game.charms_equipped.has("ember"):
        print("FAIL: swapping a pocketed charm in did not equip it")
        return false
    if game.charms_equipped.size() > BeautyContent.MAX_CHARMS:
        print("FAIL: the swap exceeded the charm cap: %s" % str(game.charms_equipped.keys()))
        return false
    if game.charms_owned.size() != owned_before:
        print("FAIL: the swap lost ownership: %d -> %d" % [
            owned_before, game.charms_owned.size()])
        return false
    if not newest.contains("rests in your pocket"):
        print("FAIL: a full-slot swap did not say which charm it set aside (%s)" % newest)
        return false

    # The charm that was set aside must be named, and must still be owned so
    # the player can swap it back.
    var evicted := ""
    for key in worn_before:
        if not game.charms_equipped.has(key):
            evicted = key
            break
    if evicted == "":
        print("FAIL: a full-slot swap evicted nothing")
        return false
    if not game.charms_owned.has(evicted):
        print("FAIL: the evicted charm %s is no longer owned" % evicted)
        return false
    var evicted_name: String = charm_name_for(evicted)
    if not newest.contains(evicted_name):
        print("FAIL: the swap did not name the evicted charm %s (%s)" % [evicted_name, newest])
        return false

    # The same swap twice must evict the same charm: the rule is a rule.
    var first_evicted := evicted
    for key2 in ["moss", "dew", "acorn"]:
        game.charms_owned[key2] = true
    game._on_charm_equip_requested("moss")
    for _i in range(3):
        await _frames(2)
    var second := ""
    for key3 in worn_before:
        if key3 != first_evicted and not game.charms_equipped.has(key3):
            second = key3
            break
    print("CHARMSWAP second eviction=%s (first was %s)" % [second, first_evicted])
    if second == "" and game.charms_equipped.size() == BeautyContent.MAX_CHARMS:
        print("FAIL: the second full-slot swap evicted nothing")
        return false
    return true


## The newest log line that mentions `needle`, searching from the bottom. Log
## lines keep arriving while a test runs -- wisps drift home, the shop refills
## -- so "the newest line" is not the same thing as "the line I caused".
func _newest_line_mentioning(game: Node, needle: String) -> String:
    var haystack: PackedStringArray = String(game.ui._log_label.text).split("\n")
    var fallback: String = haystack[haystack.size() - 1]
    for i in range(haystack.size() - 1, -1, -1):
        if haystack[i].to_lower().contains(needle.to_lower()):
            return haystack[i]
    return fallback

func charm_name_for(key: String) -> String:
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) == key:
            return String(charm["name"])
    return key


## The verse swap is the sibling of the charm swap above: with both slots full it
## evicts one, and it used to do so in total silence -- the log did not change
## at all. Mote now names what steps back.
func _check_a_full_slot_verse_swap_says_what_steps_back(game: Node) -> bool:
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._recalculate_loadout(false)
    for _i in range(2):
        await _frames(2)
    var before: Array = game.stanzas_equipped.keys()
    game._on_stanza_equip_requested("hearth")
    for _i in range(3):
        await _frames(2)

    var newest: String = String(game.ui._log_label.text.split("\n")[-1])
    print("STANZASWAP equipped=%s log=%s" % [str(game.stanzas_equipped.keys()), newest])
    if not _check(game.stanzas_equipped.has("hearth"),
            "swapping a verse in did not equip it"):
        return false
    if not _check(game.stanzas_equipped.size() <= BeautyContent.MAX_STANZAS,
            "the verse swap exceeded the cap: %s" % str(game.stanzas_equipped.keys())):
        return false

    var stepped_aside := ""
    for key in before:
        if not game.stanzas_equipped.has(key):
            stepped_aside = key
            break
    if not _check(stepped_aside != "", "a full-slot verse swap evicted nothing"):
        return false
    if not _check(newest.contains("steps back"),
            "a full-slot verse swap said nothing about what it displaced (%s)" % newest):
        return false
    var wanted := ""
    for stanza: Dictionary in BeautyContent.STANZAS:
        if String(stanza["key"]) == stepped_aside:
            wanted = String(stanza["name"])
            break
    if not _check(newest.contains(wanted),
            "the verse swap did not name %s (%s)" % [wanted, newest]):
        return false
    # Every verse is free, so the one that stepped back must be tap-able again.
    game._on_stanza_equip_requested(stepped_aside)
    for _i in range(3):
        await _frames(2)
    if not _check(game.stanzas_equipped.has(stepped_aside),
            "the displaced verse could not be swapped straight back"):
        return false
    return true

## Verses and Mote's counter-melodies are free gifts that nobody owns, and the
## shop listed every unworn one as "in pocket -- tap to wear" and "already
## yours". That describes a purchase which never happened. Nothing here may
## claim a pocket or an ownership.
func _check_free_items_do_not_claim_to_be_owned(game: Node) -> bool:
    game.ui.show_shop(game._shop_state())
    for _i in range(4):
        await _frames(2)
    # The rows live inside a ScrollContainer, so search the whole frame subtree.
    var free_rows := 0
    var free_items := BeautyContent.STANZAS.size() + BeautyContent.MOTE_VERSES.size()
    for button in _buttons_in(game.ui._shop_frame):
        var b := button as Button
        if b == null:
            continue
        var label: String = b.text.strip_edges()
        if not (label.contains("free gift")):
            continue
        free_rows += 1
        # A worn item says "wearing it now", which is true. An UNWORN one must
        # not describe a pocket or a purchase.
        if label.contains("♥ WEARING"):
            continue
        if not _check(not label.contains("in pocket"),
                "a free item claimed a pocket: %s" % label):
            return false
        if not _check(not b.tooltip_text.contains("already yours"),
                "a free item claimed ownership: %s" % b.tooltip_text):
            return false
    print("FREE_ITEMS rows=%d of %d expected, none claim ownership or a pocket" % [
        free_rows, free_items])
    if not _check(free_rows == free_items,
            "expected %d free rows (every verse and counter-melody), found %d" % [
                free_items, free_rows]):
        return false
    game.ui.close_panels()
    for _i in range(2):
        await _frames(2)
    return true
