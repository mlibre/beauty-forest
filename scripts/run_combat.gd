class_name RunCombat
extends "res://scripts/run_boons.gd"
## Automatic lantern combat, wisp spawning and rewards, thank-you hearts, and
## player damage. The song ceremonies that share this state extend it in
## RunCeremonies; progression helpers live in RunState.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")
const HeartPickup := preload("res://scripts/heart_pickup.gd")

## One soft hue per step of the lantern's round, mirroring the pentatonic arc
## AudioDirector.play_soothe sings. A volley of notes reads as a little rainbow
## arpeggio while staying pale enough for the sunlit grove.
const NOTE_MELODY: Array[Color] = [
    Color("#ffe7a4"), Color("#ffd1e8"), Color("#cdeaff"), Color("#e5d8ff"),
    Color("#fff3b0"), Color("#d8f3c8"), Color("#ffdfc2"), Color("#f6e6b4"),
]

func _spawn_wisps() -> void:
    var count := mini(6 + floor_number * 2, 40)
    var occupied: Dictionary = {}
    var spawn_room: Dictionary = dungeon["rooms"][0]
    for index in range(count):
        var cell := DungeonGenerator.random_floor_cell(dungeon, _rng, Vector2(spawn_room["cx"], spawn_room["cy"]), 7.0, occupied)
        occupied[cell] = true
        var wisp := Wisp.new()
        wisp.setup(BeautyContent.pick_wisp_type(floor_number), floor_number)
        wisp.set_reduced_motion(bool(settings.get("reduced_motion", false)))
        wisp.position = DungeonGenerator.cell_to_world(cell, 0.0)
        wisp.set_meta("attack_cooldown", _rng.randf_range(0.2, 1.1))
        wisp.set_meta("said_grumble", false)
        world.add_child(wisp)
        wisps.append(wisp)
    var story := BeautyContent.story_floor(floor_number)
    if story % 3 == 0 and story >= 3 and story != 12:
        _spawn_boss()
    var feeling := BeautyContent.feeling_for_floor(floor_number)
    if not feeling.is_empty():
        _spawn_feeling(feeling, story)

func _spawn_boss() -> void:
    var spawn_room: Dictionary = dungeon["rooms"][0]
    var cell := DungeonGenerator.random_floor_cell(dungeon, _rng, Vector2(spawn_room["cx"], spawn_room["cy"]), 7.0)
    var wisp := Wisp.new()
    wisp.setup("Shambler", floor_number, true)
    wisp.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    wisp.display_name = "The Very Big Wisp \"Chad\""
    wisp.position = DungeonGenerator.cell_to_world(cell, 0.0)
    wisp.set_meta("attack_cooldown", 1.0)
    world.add_child(wisp)
    wisps.append(wisp)
    ui.add_log("Mote: “Oh my. That wisp ate one too many sandwiches. Sing when its halo turns GOLD!”")

func _spawn_feeling(feeling: Dictionary, story: int) -> void:
    var base_types := ["Shambler", "Crawler", "Warden"]
    var base_index := posmod(story / 4 - 1, 3)
    var spawn_room: Dictionary = dungeon["rooms"][0]
    var cell := DungeonGenerator.random_floor_cell(dungeon, _rng, Vector2(spawn_room["cx"], spawn_room["cy"]), 7.0)
    var wisp := Wisp.new()
    wisp.setup(base_types[base_index], floor_number, true, feeling)
    wisp.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    wisp.position = DungeonGenerator.cell_to_world(cell, 0.0)
    wisp.set_meta("attack_cooldown", 0.8)
    world.add_child(wisp)
    wisps.append(wisp)
    ui.add_log("Mote: “A Big Feeling. Not a monster — just one feeling wearing a very big coat.”")

func _refresh_wisp_shields() -> void:
    for wisp: Wisp in wisps:
        if is_instance_valid(wisp):
            wisp.set_shielded(false)
    for warden: Wisp in wisps:
        if not is_instance_valid(warden) or not bool(warden.type_data.get("shielder", false)) or not warden.alive:
            continue
        for other: Wisp in wisps:
            if other == warden or not is_instance_valid(other) or bool(other.type_data.get("shielder", false)) or not other.alive:
                continue
            if warden.global_position.distance_squared_to(other.global_position) < 16.0:
                other.set_shielded(true)

func _separate_wisps() -> void:
    for first_index in range(wisps.size()):
        var first := wisps[first_index]
        if not is_instance_valid(first) or not first.alive:
            continue
        for second_index in range(first_index + 1, wisps.size()):
            var second := wisps[second_index]
            if not is_instance_valid(second) or not second.alive:
                continue
            var offset := first.global_position - second.global_position
            offset.y = 0.0
            var minimum := 1.8 if first.is_big or second.is_big else 0.88
            var distance := offset.length()
            if distance >= minimum:
                continue
            if distance < 0.001:
                offset = Vector3(0.01, 0, 0)
                distance = 0.01
            var correction := offset.normalized() * (minimum - distance) * 0.24
            first.global_position += correction
            second.global_position -= correction

func _update_wisp_contact(wisp: Wisp, delta: float) -> void:
    if wisp.soothed or not wisp.alive:
        return
    # Sitting with a Big Feeling is the gentle path by design. While the song
    # plays the feeling must stand and listen, not sob the player back awake:
    # a hit mid-lullaby knocked the hero away from the very circle they were
    # meant to hold. Contact resumes the moment the song ends or fails.
    if _lullaby_active:
        return
    var cooldown := float(wisp.get_meta("attack_cooldown", 0.0)) - delta
    var distance := wisp.global_position.distance_to(player.global_position)
    if not bool(wisp.get_meta("said_grumble", false)) and distance < 5.0:
        wisp.set_meta("said_grumble", true)
        var line: Variant = BeautyContent.random_choice(wisp.type_data.get("grumbles", ["Where am I?"]))
        ui.add_log("%s: “%s”" % [wisp.display_name, String(line)])
    if cooldown <= 0.0:
        if wisp.is_feeling and distance < 2.25:
            cooldown = 2.2
            var damage := minf(6.0, maxf(1.0, round(wisp.contact_damage * 0.5)))
            _damage_player(damage, "%s’s sob" % wisp.feeling_name)
            var away := player.global_position - wisp.global_position
            away.y = 0.0
            if away.length_squared() > 0.001:
                player.global_position += away.normalized() * 0.45
            player.add_sluggish_time(2.5)
        elif wisp.is_big and distance < 2.25:
            cooldown = 2.2
            _damage_player(round(wisp.contact_damage * 1.5), wisp.display_name)
        elif not wisp.is_big and distance < 1.10:
            cooldown = 1.1
            _damage_player(wisp.contact_damage, wisp.display_name)
    wisp.set_meta("attack_cooldown", maxf(0.0, cooldown))

func _auto_combat(_delta: float) -> void:
    if _lullaby_active:
        return
    if pulse_cooldown <= 0.0:
        var pulse_radius := 2.2 + float(stanza_effects.get("pulse_radius", 0.0))
        var target := _nearest_wisp(player.global_position, pulse_radius, true)
        if target != null:
            _do_pulse(target, pulse_radius)
        else:
            pulse_cooldown = 0.15
    if note_cooldown > 0.0:
        return
    var cap := 8 + int(stanza_effects.get("song_cap", 0.0))
    if notes.size() >= cap:
        note_cooldown = 0.25
        return
    var note_range := 10.0 * float(floor_modifier.get("note_range", 1.0)) * float(charm_effects.get("note_range", 1.0))
    var far_target := _nearest_wisp(player.global_position, note_range, true)
    if far_target == null:
        note_cooldown = 0.25
        return
    _fire_song_note(far_target)

func _do_pulse(target: Wisp, radius: float) -> void:
    if player.hero:
        player.hero.trigger_swing()
        var direction := target.global_position - player.global_position
        direction.y = 0.0
        if direction.length_squared() > 0.001:
            player.hero.look_at(player.global_position + direction, Vector3.UP)
    pulse_cooldown = 0.85 * float(charm_effects.get("cooldown", 1.0)) * float(stanza_effects.get("pulse_cooldown", 1.0))
    CozyVFX.pulse_ring(world, player.global_position, Color("#ffe29a"), radius)
    audio.play_hit()
    var pulse_damage := attack * float(stanza_effects.get("pulse_damage", 1.0))
    var origin := player.global_position
    for index in range(wisps.size() - 1, -1, -1):
        var wisp := wisps[index]
        if not is_instance_valid(wisp) or not wisp.alive or wisp.soothed or wisp == _lullaby_target:
            continue
        if wisp.is_feeling:
            # A Big Feeling is soothed by being SAT WITH (two gentle rounds on
            # the gold), never by the lantern's automatic pulse. Damaging it
            # here quietly skipped that whole designed moment and still paid
            # out the "sat with a Big Feeling" sticker.
            if randf() < 0.15:
                ui.add_log("Mote: “The lantern hums gentle around the Big Feeling. It needs your voice, not a push.”")
            continue
        if wisp.global_position.distance_to(origin) > radius:
            continue
        if not DungeonGenerator.has_line_of_sight(dungeon, origin, wisp.global_position):
            continue
        if wisp.shielded or (wisp.is_big and not wisp.is_boss_vulnerable()):
            # The pulse is the automatic close-range half of the song, so this is
            # a second, more frequent way to lose a beat you had right. It was a
            # 15%-chance line in the hidden log; a cue is what the player needs,
            # and the warden's shield and the wisp's halo are both already drawn
            # in the world for the words to point at.
            if randf() < 0.15:
                ui.add_cue("Wait for the GOLD halo")
            continue
        wisp.take_damage(pulse_damage)
        CozyVFX.trail_tick(world, wisp.global_position + Vector3.UP * 0.7, Color(region["accent"]))
        if float(stanza_effects.get("pulse_slow", 0.0)) > 0.0:
            wisp.apply_slow(1.0 - float(stanza_effects.get("pulse_slow", 0.0)), 2.5)
        if not wisp.alive:
            _soothe_wisp(wisp, false)

func _fire_song_note(target: Wisp) -> void:
    var note := SongNote.new()
    note.name = "HomingSongNote"
    world.add_child(note)
    var damage: float = round(attack * 0.8 * float(charm_effects.get("song_damage", 1.0)) * float(stanza_effects.get("song_damage", 1.0)))
    var note_color := NOTE_MELODY[int(meta.get("wisps_soothed", 0)) % NOTE_MELODY.size()]
    note.setup(target, damage, float(stanza_effects.get("song_speed", 1.0)), float(stanza_effects.get("song_life", 0.0)) + float(verse_effects.get("song_life", 0.0)), note_color)
    note.position = player.global_position + Vector3.UP * 1.20
    var direction := target.global_position - note.global_position
    direction.y = 0.0
    if direction.length_squared() < 0.001:
        direction = Vector3.FORWARD
    note.launch(direction)
    note.connected_wisp.connect(_on_song_connected)
    note.note_expired.connect(_on_song_expired)
    note.set_meta("target_provider", Callable(self, "_nearest_wisp_from_note"))
    notes.append(note)
    note_cooldown = 1.3 * float(charm_effects.get("cooldown", 1.0)) * float(stanza_effects.get("note_cooldown", 1.0))
    audio.play_song_launch()

func _nearest_wisp_from_note(origin: Vector3, max_distance: float) -> Wisp:
    return _nearest_wisp(origin, max_distance, true)

func _nearest_wisp(origin: Vector3, max_distance: float, require_line_of_sight: bool) -> Wisp:
    var best: Wisp
    var best_distance := max_distance * max_distance
    for wisp: Wisp in wisps:
        if not is_instance_valid(wisp) or not wisp.alive or wisp.soothed or wisp.is_feeling or wisp == _lullaby_target:
            continue
        var distance := origin.distance_squared_to(wisp.global_position)
        if distance >= best_distance:
            continue
        if require_line_of_sight and not DungeonGenerator.has_line_of_sight(dungeon, origin, wisp.global_position):
            continue
        best = wisp
        best_distance = distance
    return best

func _on_song_connected(wisp: Wisp, _note: SongNote) -> void:
    if not is_instance_valid(wisp) or not wisp.alive or wisp.soothed:
        return
    if wisp.shielded:
        ui.add_cue("A Warden is holding that shield")
        return
    if wisp.is_big and not wisp.is_boss_vulnerable():
        # The one cue that has to be seen. Short, because it lands mid-fight.
        ui.add_cue("Almost! Wait for the GOLD halo")
        return
    wisp.take_damage(_note.damage)
    CozyVFX.trail_tick(world, wisp.global_position + Vector3.UP * 0.8, Color("#bfe8ff"))
    if not wisp.alive:
        _soothe_wisp(wisp, true)
    else:
        ui.add_log("%s hums along from afar." % wisp.display_name)

func _on_song_expired(world_position: Vector3, blocked: bool) -> void:
    CozyVFX.trail_tick(world, world_position, Color("#d7c29a") if blocked else Color(region["accent"]))

func _prune_notes() -> void:
    for index in range(notes.size() - 1, -1, -1):
        if not is_instance_valid(notes[index]):
            notes.remove_at(index)

## What a wisp leaves in the purse.
##
## This used to be a flat 1 sparkle (3 for a big one) -- the same mistake as the
## old level curve, one level up. Everything the hero meets and everything the
## hero buys scales with depth, but income did not: the whole shelf of wares cost
## about 90 sparkles, income plateaued near 40 a floor, and the cart bought
## itself out by floor 7 of 13. After that the only things left to spend on were
## tea, so two thirds of the walk had no economy at all.
##
## So income now grows with depth the way the creatures do -- unbounded, and on
## the same curve -- which keeps the cart a live decision at every floor instead
## of a formality the player completes once.
func _wisp_payout(wisp: Wisp) -> int:
    var base := PAYOUT_BIG if wisp.is_big else 1
    return roundi(float(base) * _payout_scale())

## The depth multiplier on every sparkle.
##
## This is the one place the exponential is honest rather than a mistake, because
## it is exponential in DEPTH and depth is what the player is spending. The level
## curve was wrong because it grew exponentially in LEVEL -- an unbounded
## currency chasing an unbounded price. Here the same shape buys the same thing
## forever: a tier-II ware costs 2.2x a tier-I one, so income growing on the same
## curve means the cart never has a floor where it stops mattering.
##
## The slope is deliberately gentle. 1.085 per floor compounds to about 2x every
## eight floors; at 8.5% the floor-400 payout was measured at 5.7 quadrillion
## sparkles, which is not a number a player reads -- it is the purse telling them
## the shopping phase is over. At 1.02 the same walk pays a few hundred a floor,
## which still buys a deeper copy every floor but leaves the count meaningful.
func _payout_scale() -> float:
    return pow(PAYOUT_GROWTH, float(maxi(0, floor_number - 1)))

## Sparkles earned per wisp, multiplied by PAYOUT_GROWTH each floor deeper.
const PAYOUT_BIG := 3
const PAYOUT_GROWTH := 1.02

func _soothe_wisp(wisp: Wisp, distant: bool) -> void:
    if not is_instance_valid(wisp) or wisp.damage_claimed:
        return
    wisp.damage_claimed = true
    wisp.soothed = true
    var was_big := wisp.is_big
    meta["wisps_soothed"] = int(meta.get("wisps_soothed", 0)) + 1
    _soothes_this_floor += 1
    _mote_joy = 1.0
    audio.play_soothe(int(meta.get("wisps_soothed", 0)), was_big)
    if int(meta["wisps_soothed"]) >= 100:
        _award_sticker("century")
    if was_big:
        _award_sticker("big_hug")
    if wisp.is_feeling:
        _award_sticker("feeling_friend")
    sparkles += _wisp_payout(wisp)
    CozyVFX.soothe_celebration(world, wisp.global_position, was_big)
    if _soothes_this_floor > 0 and _soothes_this_floor % 6 == 0:
        # A floor milestone, not a timer: no expiry, no pressure, just the
        # forest noticing out loud every six guided wisps.
        CozyVFX.burst(world, player.global_position + Vector3(0, 3.0, 0), Color(region["flower"]), 30, 1.1, 2.0)
        ui.show_toast("Six guided home on this floor — the grove rustles happily. ♥")
    var farewell: Variant = wisp.feeling_farewell if not wisp.feeling_farewell.is_empty() else BeautyContent.random_choice(wisp.type_data.get("farewells", ["Thank you."]))
    ui.add_log("%s drifts home happily: “%s”" % [wisp.display_name, String(farewell)])
    if was_big:
        ui.add_log("Mote: “THE BIG ONE! A gentle giant. Someone give that wisp a medal.”")
    elif randf() < 0.25:
        ui.add_log("Mote: “%s”" % String(BeautyContent.random_choice(BeautyLore.SOOTHE_LINES)))
    if distant:
        _award_sticker("long_lullaby")
    if wisp.curious:
        _learn_fact("A curious wisp tucked a fact into its glow: “Psst — soothe me and it is yours!”", true)
        _award_sticker("curious")
    var style: Dictionary = BeautyContent.STYLE_DATA[selected_style]
    var soul_multiplier := float(floor_modifier.get("soul", 1.0)) * float(style.get("soul", 1.0)) * float(charm_effects.get("soul", 1.0)) * float(stanza_effects.get("soul", 1.0))
    if distant:
        soul_multiplier *= float(stanza_effects.get("distant_soul", 1.0)) * float(verse_effects.get("distant_soul", 1.0))
    var gained: int = round(wisp.soul_value * (3.0 if was_big else 1.0) * soul_multiplier)
    _gain_xp(gained)
    var heart_rate := 0.35 + float(floor_modifier.get("heart_rate", 0.0)) + float(style.get("heart_bonus", 0.0)) + float(stanza_effects.get("heart_rate", 0.0)) + float(verse_effects.get("heart_rate", 0.0))
    if randf() < heart_rate:
        var heart := HeartPickup.new()
        world.add_child(heart)
        heart.setup(wisp.global_position, 15.0 + float(style.get("heart_bonus_flat", 0.0)) + float(charm_effects.get("heart_heal", 0.0)), float(charm_effects.get("pickup", 1.0)) * float(verse_effects.get("pickup", 1.0)), bool(floor_modifier.get("heart_drift", false)) or bool(stanza_effects.get("heart_magnet", false)))
        heart.heart_collected.connect(_on_heart_collected)
        heart.heart_expired.connect(_on_heart_expired)
    if bool(wisp.type_data.get("splits_gently", false)) and not was_big and not bool(wisp.get_meta("no_split", false)):
        _spawn_gigglelets(wisp)
    world.remove_child(wisp)
    wisp.queue_free()
    wisps.erase(wisp)
    BeautyData.save_meta(meta)
    _celebrate(0.8)
    _refresh_ui()

func _spawn_gigglelets(parent: Wisp) -> void:
    for side in [-1.0, 1.0]:
        var child := Wisp.new()
        child.setup("Giggle Puff", floor_number)
        child.set_meta("no_split", true)
        child.set_reduced_motion(bool(settings.get("reduced_motion", false)))
        child.set_meta("attack_cooldown", _rng.randf_range(0.2, 1.1))
        child.set_meta("said_grumble", false)
        child.position = parent.position + Vector3(side * 0.55, 0, 0.2)
        child.scale = Vector3(0.58, 0.58, 0.58)
        world.add_child(child)
        wisps.append(child)

func _on_heart_expired(_pickup: HeartPickup) -> void:
    ui.add_log("Mote: “That thank-you heart drifted off to warm someone else. No harm done — the kindness already happened.”")

func _on_heart_collected(pickup: HeartPickup) -> void:
    if not is_instance_valid(pickup):
        return
    # The amount is captured when the heart drops. Do not rebuild it from the
    # current loadout: a charm can be swapped while the heart is still drifting.
    var amount := maxf(0.0, pickup.heal_amount)
    if amount <= 0.0:
        return
    hp = minf(hp_max, hp + amount)
    audio.play_chord([659.25, 783.99, 987.77], 0.42, 0.075)
    ui.add_log("Mote: “A thank-you heart! That’s +%d warmth.”" % int(round(amount)))
    _refresh_ui()

func _damage_player(amount: int, source: String) -> void:
    if mode != Mode.PLAYING or player == null or player.is_invulnerable() or invulnerable_time > 0.0:
        return
    var style: Dictionary = BeautyContent.STYLE_DATA[selected_style]
    var multiplier := float(style.get("damage_taken", 1.0)) * float(charm_effects.get("damage_taken", 1.0)) * (float(settings.get("damage_taken", 0.7)) / 0.7) * float(verse_effects.get("damage_taken", 1.0))
    var taken := maxi(0, roundi(float(amount) * multiplier))
    hp = maxf(0.0, hp - float(taken))
    invulnerable_time = 0.6 + float(charm_effects.get("invulnerable", 0.0)) + float(verse_effects.get("invulnerable", 0.0))
    hit_this_floor = true
    audio.play_soft_hit()
    ui.flash_warmth()
    # The lantern dims and reddens on its own, so being hurt is something you
    # SEE without any words -- that is the rule the whole HUD is built on. But
    # "how much did that cost me" is a number no lantern can say, and it went to
    # the hidden log like every other line. The cue carries the figure; it does
    # not carry the sentence that used to dress it up.
    ui.add_cue("−%d warmth" % taken)
    ui.add_log("%s nicks you for %d. The lantern hums protectively." % [source, taken])
    _refresh_ui()
    if hp <= 0.0:
        _nap()

func _nap() -> void:
    mode = Mode.DEAD
    _set_world_processing(false)
    player.set_control_enabled(false)
    audio.stop_ambient()
    meta["best_floor"] = maxi(int(meta.get("best_floor", 0)), floor_number)
    _award_sticker("first_nap")
    BeautyData.save_meta(meta)
    audio.play_sleep()
    ui.show_death(floor_number, meta)

func _on_player_footstep(world_position: Vector3) -> void:
    CozyVFX.burst(world, world_position, Color("#d9cf9a"), 3, 0.30, 0.35)
    audio.play_footstep()

func _on_player_dashed(world_position: Vector3, direction: Vector3) -> void:
    # The dash paints its whole path, not just its start: a comet streak from
    # where the hero left to where the slide ends, then the soft arrival.
    var landing := world_position + direction * player.move_speed * 2.6 * 0.28
    CozyVFX.trail(world, world_position + Vector3.UP * 0.4, landing + Vector3.UP * 0.4,
        Color("#f0d8a4"), 7, bool(settings.get("reduced_motion", false)))
    CozyVFX.burst(world, landing + Vector3.UP * 0.25, Color("#f0d8a4"), 16, 1.6, 0.7)
    audio.play_dash()
