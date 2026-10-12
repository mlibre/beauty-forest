class_name RunSurprises
extends "res://scripts/run_ceremonies.gd"

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.

## The floor's one small surprise, and its whole life: spawned with the floor,
## sensed while the hero walks (glades warm, blooms light, puffs pop,
## fireflies are chased, star trails answer in order) and answered on E
## (picnics shared, rings joined, comets watched, shells listened to). Split
## out of RunWorld so floor construction and traversal stay one file while
## the surprise's three lives live in another.

const FloorSurprise := preload("res://scripts/floor_surprise.gd")
## This floor's one surprise — spawned with the floor, polled while walking.
var _surprise: Node3D
## Seconds spent standing inside the star glade; the glade grants its warmth
## to a hero who stops for a breath, so the timer lives with the walker.
var _glade_time := 0.0

## Every floor hides one small surprise (see FloorSurprise). Spawned after the
## wisps so the occupied-cell set already holds their homes; the surprise is
## placed like anything else that belongs to the floor, far from the spawn.
func _spawn_surprise() -> void:
    var occupied: Dictionary = {}
    for wisp: Wisp in wisps:
        if is_instance_valid(wisp):
            occupied[Vector2i(int(round(wisp.global_position.x)), int(round(wisp.global_position.z)))] = true
    _surprise = FloorSurprise.spawn(world, dungeon, _rng, floor_number, occupied)

## The surprise's proximity senses, polled while walking: standing in the star
## glade warms, walking through puffs pops them, leaning into a lantern bloom
## lights it. Interact-kind surprises are answered from _try_interact.
func _tick_surprise(delta: float) -> void:
    if _surprise == null or not is_instance_valid(_surprise):
        return
    match String(_surprise.get_meta("surprise_key")):
        "star_glade":
            if player.global_position.distance_to(_surprise.global_position) < 2.4 and not _surprise.get_meta("surprise_used"):
                _glade_time += delta
                if _glade_time >= 2.5:
                    _surprise.set_meta("surprise_used", true)
                    hp = minf(hp_max, hp + 15.0)
                    CozyVFX.ring(world, _surprise.global_position + Vector3.UP * 0.4, Color("#fff3a0"), 2.6, 1.0)
                    audio.play_chord([659.25, 783.99, 987.77], 0.7, 0.07)
                    ui.show_toast("The stars lend you their light. +15 warmth.", 3.0)
                    _refresh_ui()
        "lantern_bloom":
            if not _surprise.get_meta("surprise_used"):
                var lit := 0
                for index in range(5):
                    var bulb := _surprise.get_node_or_null("Bulb%d" % index) as MeshInstance3D
                    if bulb == null:
                        continue
                    if String(bulb.get_meta("lit", "")) == "yes":
                        lit += 1
                        continue
                    if player.global_position.distance_to(bulb.global_position) < 1.8:
                        bulb.material_override = FloorSurprise.glow(Color("#ffe2a0"), 2.0)
                        bulb.set_meta("lit", "yes")
                        lit += 1
                        audio.play_tone(523.25 + float(index) * 78.0, 0.30, 0.06, 1)
                        CozyVFX.burst(world, bulb.global_position, Color("#ffe9a8"), 12, 0.9, 0.8)
                if lit >= 5:
                    _surprise.set_meta("surprise_used", true)
                    sparkles += 3
                    audio.play_chord([523.25, 659.25, 783.99], 0.8, 0.08)
                    ui.show_toast("Every lantern is lit — the bloom hums thanks. +3 sparkles.", 3.0)
                    _refresh_ui()
        "balloon_puffs":
            var popped := 0
            for index in range(4):
                var puff := _surprise.get_node_or_null("Puff%d" % index) as MeshInstance3D
                if puff == null or not puff.visible:
                    popped += 1
                    continue
                if player.global_position.distance_to(puff.global_position) < 1.4:
                    puff.visible = false
                    popped += 1
                    sparkles += 1
                    audio.play_tone(880.0 + float(index) * 110.0, 0.20, 0.055, 1)
                    CozyVFX.burst(world, puff.global_position, Color("#ffd1dc"), 14, 1.0, 0.7)
                    _refresh_ui()
            if popped >= 4 and not _surprise.get_meta("surprise_used"):
                _surprise.set_meta("surprise_used", true)
                sparkles += 2
                audio.play_chord([659.25, 880.0], 0.5, 0.07)
                ui.show_toast("Every puff is popped — the seeds drift down. +2 sparkles.", 3.0)
                _refresh_ui()
        "firefly_chase":
            # A small optional adventure: catch all three fireflies by walking
            # to them. Each one caught pays a sparkle on the spot; the last
            # one pays a bonus. Ignoring them costs nothing but the sparkle.
            if not _surprise.get_meta("surprise_used"):
                var caught := 0
                for index in range(3):
                    var fly := _surprise.get_node_or_null("Fly%d" % index) as MeshInstance3D
                    if fly == null or not fly.visible:
                        caught += 1
                        continue
                    if player.global_position.distance_to(fly.global_position) < 1.6:
                        fly.visible = false
                        caught += 1
                        sparkles += 1
                        audio.play_tone(920.0 + float(index) * 90.0, 0.22, 0.05, 1)
                        CozyVFX.burst(world, fly.global_position, Color("#fff3a0"), 14, 1.0, 0.7)
                        _refresh_ui()
                if caught >= 3:
                    _surprise.set_meta("surprise_used", true)
                    sparkles += 2
                    audio.play_chord([659.25, 880.0, 1046.5], 0.6, 0.07)
                    ui.show_toast("Every firefly caught — they wave their little lights goodbye. +2 sparkles.", 3.2)
                    _refresh_ui()
        "star_trail":
            # Another optional adventure: five stars that only answer in
            # order. Walking the whole trail ends in a thank-you heart; the
            # trail is never an objective and never blocks the stair.
            if not _surprise.get_meta("surprise_used"):
                var next := int(_surprise.get_meta("trail_next", 0))
                var stone := _surprise.get_node_or_null("Star%d" % next) as Node3D
                if stone != null and player.global_position.distance_to(stone.global_position) < 1.7:
                    _surprise.set_meta("trail_next", next + 1)
                    stone.material_override = FloorSurprise.glow(Color("#ffe9a8"), 2.2)
                    audio.play_tone(523.25 * pow(1.26, float(next)), 0.30, 0.055, 1)
                    CozyVFX.burst(world, stone.global_position, Color("#bfe8ff"), 12, 0.9, 0.7)
                    if next + 1 >= 5:
                        _surprise.set_meta("surprise_used", true)
                        var heart := HeartPickup.new()
                        world.add_child(heart)
                        heart.setup(_surprise.global_position + Vector3(0.6, 0.8, 0), 12.0, 1.0, true)
                        heart.heart_collected.connect(_on_heart_collected)
                        heart.heart_expired.connect(_on_heart_expired)
                        ui.show_toast("The star trail ends in a thank-you heart.", 3.2)

## The surprise's E-answers, tried before the generic wander cue. Returns
## true when the press belonged to the surprise, so the caller stops there.
func _surprise_interact() -> bool:
    if _surprise == null or not is_instance_valid(_surprise):
        return false
    var key := String(_surprise.get_meta("surprise_key"))
    var used: bool = _surprise.get_meta("surprise_used")
    var near := player.global_position.distance_to(_surprise.global_position) < 2.6
    match key:
        "picnic":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                sparkles += 2
                audio.play_chord([523.25, 659.25, 783.99], 0.6, 0.075)
                CozyVFX.burst(world, _surprise.global_position + Vector3.UP * 0.5, Color("#fff3c8"), 20, 1.1, 1.0)
                ui.show_toast("The picnic wisps share their snacks. +2 sparkles.", 3.0)
                _refresh_ui()
                return true
        "singing_ring":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                for step in range(4):
                    audio.play_tone(523.25 * pow(1.26, float(step)), 0.45, 0.055, 1)
                floor_modifier["note_range"] = float(floor_modifier.get("note_range", 1.0)) * 1.2
                CozyVFX.ring(world, _surprise.global_position + Vector3.UP * 0.4, Color("#e3b66d"), 3.0, 1.1)
                ui.show_toast("The ring hums along — song-notes fly farther this floor.", 3.2)
                return true
        "comet_log":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                audio.play_tone(1318.5, 0.9, 0.05, 1)
                var comet_from := _surprise.global_position + Vector3(-5.0, 7.0, -2.0)
                for step in range(7):
                    CozyVFX.burst(world, comet_from + Vector3(float(step) * 1.2, -float(step) * 0.8, 0.0), Color("#fff3a0"), 8, 0.8, 0.6)
                var heart := HeartPickup.new()
                world.add_child(heart)
                heart.setup(_surprise.global_position + Vector3(0.8, 0.8, 0), 12.0, 1.0, true)
                heart.heart_collected.connect(_on_heart_collected)
                heart.heart_expired.connect(_on_heart_expired)
                ui.show_toast("A comet! It saw you looking, and sent a thank-you heart.", 3.4)
                return true
        "mossy_doodle":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                sparkles += 1
                # The fact itself is picked and spoken inside _learn_fact; the
                # reason here only ever feeds its curious-wisp branch, which a
                # doodle is not, so it stays one short honest clause.
                _learn_fact("A mossy doodle offered a fact")
                audio.play_chord([783.99, 987.77], 0.5, 0.06)
                _refresh_ui()
                return true
        "echo_shell":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                for step in range(3):
                    audio.play_tone(392.0 * pow(1.335, float(step)), 0.5, 0.06, 1)
                # The shell's echo settles the whole floor a shade: a small,
                # honest blessing that is over the moment you hear it.
                floor_modifier["aggro"] = float(floor_modifier.get("aggro", 1.0)) * 0.90
                CozyVFX.ring(world, _surprise.global_position + Vector3.UP * 0.5, Color("#cfe8ff"), 2.6, 1.0)
                ui.show_toast("The shell echoes the forest's hum — the wisps settle a little this floor.", 3.2)
                return true
        _:
            pass
    return false

## The floor surprise's own verb, when the hero is close enough to answer it.
func _surprise_hint_text() -> String:
    if _surprise == null or not is_instance_valid(_surprise):
        return ""
    if bool(_surprise.get_meta("surprise_used")):
        return ""
    if player == null or not is_instance_valid(player):
        return ""
    if player.global_position.distance_to(_surprise.global_position) >= 2.6:
        return ""
    return FloorSurprise.verb_for(String(_surprise.get_meta("surprise_key")))
