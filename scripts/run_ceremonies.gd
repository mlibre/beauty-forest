class_name RunCeremonies
extends "res://scripts/run_combat.gd"
## The two song ceremonies: gathering the five Dream Chimes that open Snoozle's
## tuck-in, and sitting with a Big Feeling across two gentle rounds. Gold-window
## judging, rest beats and the win/reset transitions live here.

func _check_chime_pickups(delta: float) -> void:
    if not dragon_exists:
        return
    for index in range(world.chimes.size() - 1, -1, -1):
        var chime := world.chimes[index]
        if not is_instance_valid(chime):
            world.chimes.remove_at(index)
            continue
        var distance := chime.global_position.distance_to(player.global_position)
        # The HUD and Mote both promise "chimes gather themselves" once the
        # hero walks close, so honor it: inside the gather radius a chime
        # drifts toward the hero and is collected on arrival. The search still
        # matters — the hero has to walk up to the clearing first.
        if distance < CHIME_GATHER_RADIUS and distance > 0.05:
            var to_player := player.global_position + Vector3.UP * 0.78 - chime.global_position
            chime.global_position += to_player.normalized() * minf(to_player.length(), CHIME_GATHER_SPEED * delta)
            distance = chime.global_position.distance_to(player.global_position)
        if distance < 1.4:
            var chime_index := int(chime.get_meta("chime_index", index))
            world.chimes.remove_at(index)
            world.remove_child(chime)
            chime.queue_free()
            audio.play_pickup(chime_index)
            CozyVFX.burst(world, player.global_position + Vector3.UP, Color("#bfe8ff"), 24, 1.8, 0.9)
            ui.add_log("Dream Chime secured! (%d/5)" % (5 - world.chimes.size()))
            if world.chimes.is_empty():
                _begin_dragon_lullaby()
                break

func _begin_dragon_lullaby() -> void:
    if _lullaby_active:
        return
    _reset_lullaby()
    _lullaby_active = true
    _lullaby_kind = "dragon"
    _lullaby_timer = 1.2
    ui.show_story("The Lullaby", "Mote hums the tune. Press E when the ring glows GOLD. Missed notes merely let the forest wait.", 4.5)
    ui.add_log("Mote: “Follow me… E on the gold!”")
    audio.play_tone(523.25, 0.4, 0.07, 1)

func _begin_feeling_lullaby(target: Wisp) -> void:
    if _lullaby_active or not is_instance_valid(target) or not target.alive or not target.is_feeling:
        return
    _reset_lullaby()
    _lullaby_active = true
    _lullaby_kind = "feeling"
    _lullaby_target = target
    _feeling_round = 1
    _feeling_hits = 0
    _feeling_rest = 0
    _lullaby_timer = 1.2
    ui.show_story("A Big Feeling", "%s wobbles close, sniffly and huge. Hum with it — E on the gold, rest when the ring dims." % target.feeling_name, 4.5)
    ui.add_log("Mote: “Gentle… two little rounds, with breaths between. Missed notes just stretch the song.”")

func _tick_lullaby(delta: float) -> void:
    if not _lullaby_active:
        ui.set_beat(false, false)
        return
    _lullaby_timer -= delta
    if _lullaby_timer > 0.0:
        return
    _lullaby_step += 1
    var window := LULLABY_STEP * (float(settings.get("rhythm_window", 1.4)) / 1.4) * float(charm_effects.get("lullaby_window", 1.0))
    _lullaby_timer += window
    if _lullaby_kind == "feeling" and _feeling_rest > 0:
        _feeling_rest -= 1
        _lullaby_gold = false
        ui.set_beat(true, false)
        return
    _lullaby_gold = _lullaby_step % 2 == 0
    ui.set_beat(true, _lullaby_gold)
    if _lullaby_gold:
        audio.play_gold_beat()

func _judge_lullaby_beat() -> void:
    if not _lullaby_active:
        return
    if _lullaby_kind == "feeling":
        _judge_feeling_beat()
    else:
        if not _lullaby_gold:
            ui.add_log("Mote: “Almost! Wait for the gold…”")
            audio.play_miss()
            return
        _lullaby_gold = false
        _dragon_hits += 1
        ui.set_beat(true, false)
        audio.play_tone(523.25 + float(_dragon_hits) * 60.0, 0.40, 0.085, 1)
        CozyVFX.burst(world, world.dragon_position + Vector3.UP * 2.2, Color("#ffe9a0"), 22, 1.8, 0.9)
        if _dragon_hits >= 4:
            _win_dragon()

func _judge_feeling_beat() -> void:
    if _feeling_rest > 0:
        ui.add_log("Mote: “Breathe… the next round starts soon.”")
        audio.play_miss()
        return
    if not _lullaby_gold:
        ui.add_log("Mote: “Almost! Wait for the gold…”")
        audio.play_miss()
        return
    _lullaby_gold = false
    _feeling_hits += 1
    ui.set_beat(true, false)
    audio.play_tone(CHIME_TONES[(_feeling_hits - 1 + (_feeling_round - 1) * 3) % CHIME_TONES.size()], 0.40, 0.085, 1)
    if is_instance_valid(_lullaby_target):
        CozyVFX.burst(world, _lullaby_target.global_position + Vector3.UP * 2.0, Color("#ffe9a0"), 22, 1.8, 0.9)
    if _feeling_hits < 3:
        return
    if _feeling_round >= 2:
        _win_feeling()
        return
    _feeling_round += 1
    _feeling_hits = 0
    _feeling_rest = 2
    ui.add_log("Mote: “Round %d of 2 — rest a breath…”" % _feeling_round)

func _win_feeling() -> void:
    if not is_instance_valid(_lullaby_target):
        _reset_lullaby()
        return
    var target := _lullaby_target
    _lullaby_active = false
    ui.set_beat(false, false)
    target.take_damage(target.health + 1.0)
    CozyVFX.burst(world, target.global_position + Vector3.UP * 1.4, Color("#ffe7a0"), 48, 2.5, 1.4)
    CozyVFX.ring(world, target.global_position + Vector3.UP * 0.1, Color("#fff0ad"), 3.6, 0.9)
    _soothe_wisp(target, false)
    ui.add_log("Mote: “That big feeling feels littler already.”")
    _lullaby_target = null
    audio.play_chord(CHIME_TONES, 1.1, 0.10)

func _win_dragon() -> void:
    _lullaby_active = false
    ui.set_beat(false, false)
    meta["dragons_sung"] = int(meta.get("dragons_sung", 0)) + 1
    meta["best_floor"] = maxi(int(meta.get("best_floor", 0)), floor_number)
    _award_sticker("dragon_friend")
    BeautyData.save_meta(meta)
    audio.stop_ambient()
    audio.play_sleep()
    CozyVFX.burst(world, world.dragon_position + Vector3.UP * 2.2, Color("#ffe6a0"), 64, 2.8, 1.8)
    # Snoozle is tucked in: the floor has no dragon objective anymore. Leaving
    # this true kept the waypoint, objective text and minimap dot parked on the
    # sleeping dragon, and the stair's arrival marker never fired.
    dragon_exists = false
    if dragon_finale:
        player.set_control_enabled(false)
        ui.show_story("SNOOZLE PURRS", "The mountain-sized dragon opens one eye, looks at you like you’re a particularly good dream, purrs until the dust rearranges itself, and hands you a warm scale.", 3.2)
        ending_pending = true
        ending_countdown = 3.4
    else:
        world.reveal_stairwell()
        stair_visible = true
        # Snoozle's lullaby silences the grove so the song reads clearly, but
        # the hero keeps playing on this floor. Bring the ambience back, or the
        # coziest moment in the game leaves the rest of the run muted.
        audio.start_ambient(String(region.get("ambient", region.get("key", "sunlit-roots"))))
        ui.show_story("DEEPER STILL", "Snoozle snoozes on, warm and enormous. But Mote tugs your sleeve: there are cousins below, and the forest grows deeper than any map.", 4.2)
        ui.add_log("Mote: “Snoozle sleeps soundly. The stair is glowing now.”")

func _reset_lullaby() -> void:
    _lullaby_active = false
    _lullaby_kind = "dragon"
    _lullaby_target = null
    _lullaby_step = -1
    _lullaby_timer = 0.0
    _lullaby_gold = false
    _dragon_hits = 0
    _feeling_round = 1
    _feeling_hits = 0
    _feeling_rest = 0
    if ui:
        ui.set_beat(false, false)
