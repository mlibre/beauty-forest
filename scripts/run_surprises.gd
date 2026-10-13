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
const Adventures := preload("res://scripts/floor_surprise_adventures.gd")
## This floor's one surprise — spawned with the floor, polled while walking.
var _surprise: Node3D
## The floor's small wonders: two sparkle glints scattered beside the main
## surprise. Pure finds — walked into, never chased by an objective.
var _minor_wonders: Array[Node3D] = []
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
    _minor_wonders.clear()
    for _wonder in range(2):
        _minor_wonders.append(Adventures.spawn_minor(world, dungeon, _rng, occupied))

## The surprise's proximity senses, polled while walking: standing in the star
## glade warms, walking through puffs pops them, leaning into a lantern bloom
## lights it. Interact-kind surprises are answered from _try_interact.
func _tick_surprise(delta: float) -> void:
    if _surprise == null or not is_instance_valid(_surprise):
        return
    _tick_minor_wonders()
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
        "rainbow_puddle":
            # Stand in the puddle and the rainbow rings out. No button, no
            # chase — one moment of colour that pays a little warmth.
            if not _surprise.get_meta("surprise_used"):
                if player.global_position.distance_to(_surprise.global_position) < 1.5:
                    _surprise.set_meta("surprise_used", true)
                    hp = minf(hp_max, hp + 10.0)
                    CozyVFX.ring(world, _surprise.global_position + Vector3.UP * 0.2, Color("#bfe8ff"), 3.0, 1.1)
                    audio.play_chord([523.25, 659.25, 783.99, 987.77], 0.8, 0.07)
                    ui.show_toast("The rainbow rings out under your feet. +10 warmth.", 3.0)
                    _refresh_ui()
        "hedge_nook":
            # The resting kind of adventure: the nook warms a hero who stops
            # long enough to use it, on the same stop-and-breathe clock the
            # star glade runs. One surprise per floor, so the two never share
            # the timer by accident.
            if not _surprise.get_meta("surprise_used"):
                if player.global_position.distance_to(_surprise.global_position) < 1.9:
                    _glade_time += delta
                    if _glade_time >= 2.5:
                        _surprise.set_meta("surprise_used", true)
                        hp = minf(hp_max, hp + 15.0)
                        CozyVFX.ring(world, _surprise.global_position + Vector3.UP * 0.3, Color("#d9b06e"), 2.4, 1.0)
                        audio.play_chord([392.0, 493.88, 587.33], 0.7, 0.07)
                        ui.show_toast("The nook tucks you in for a moment. +15 warmth.", 3.0)
                        _refresh_ui()
                else:
                    _glade_time = 0.0
        "butterfly_parade":
            # Walk into the parade and it swirls: the butterflies cross to
            # the hero's side of the clearing and pay a sparkle each. Nothing
            # is caught, nothing is chased.
            if not _surprise.get_meta("surprise_used"):
                if player.global_position.distance_to(_surprise.global_position) < 3.2:
                    _surprise.set_meta("surprise_used", true)
                    sparkles += 2
                    for index in range(6):
                        var wing := _surprise.get_node_or_null("Butterfly%d" % index) as Node3D
                        if wing != null:
                            CozyVFX.burst(world, wing.global_position, Color("#ffd1e8"), 8, 0.8, 0.6)
                    audio.play_chord([659.25, 783.99, 1046.5], 0.7, 0.07)
                    ui.show_toast("The parade swirls around you — the meadow's applause. +2 sparkles.", 3.2)
                    _refresh_ui()

## The floor's small wonders, answered on walk-in: one sparkle each, a soft
## chord, a burst of light. A wonder nobody finds costs nothing — that is
## what makes it a wonder and not a chore.
func _tick_minor_wonders() -> void:
    for wonder in _minor_wonders:
        if not is_instance_valid(wonder) or bool(wonder.get_meta("wonder_used")):
            continue
        if player.global_position.distance_to(wonder.global_position) < 1.6:
            wonder.set_meta("wonder_used", true)
            wonder.visible = false
            sparkles += 1
            audio.play_tone(987.77, 0.30, 0.05, 1)
            CozyVFX.burst(world, wonder.global_position + Vector3.UP * 0.3, Color("#ffe9a8"), 12, 0.9, 0.7)
            _refresh_ui()

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
        "wisp_choir":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                sparkles += 2
                for step in range(4):
                    audio.play_tone(440.0 * pow(1.26, float(step)), 0.45, 0.06, 1)
                CozyVFX.burst(world, _surprise.global_position + Vector3.UP * 0.6, Color("#fff3c8"), 24, 1.2, 1.0)
                ui.show_toast("The choir bows — your hum fit right in. +2 sparkles.", 3.2)
                _refresh_ui()
                return true
        "lantern_release":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                audio.play_tone(783.99, 1.0, 0.05, 1)
                var lantern := _surprise.get_node_or_null("Lantern") as Node3D
                if lantern != null:
                    for step in range(6):
                        CozyVFX.burst(world, lantern.global_position + Vector3(0, float(step) * 1.4, 0), Color("#ffdf9e"), 10, 1.0, 0.7)
                var heart := HeartPickup.new()
                world.add_child(heart)
                heart.setup(_surprise.global_position + Vector3(-0.7, 0.8, 0), 12.0, 1.0, true)
                heart.heart_collected.connect(_on_heart_collected)
                heart.heart_expired.connect(_on_heart_expired)
                ui.show_toast("The lantern climbs, and the sky says thank you with a heart.", 3.4)
                return true
        "treasure_sprout":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                sparkles += 3
                var bud := _surprise.get_node_or_null("Bud") as MeshInstance3D
                if bud != null:
                    bud.material_override = Adventures.glow(Color("#ffe9a8"), 2.4)
                audio.play_chord([523.25, 783.99, 1046.5], 0.8, 0.08)
                CozyVFX.burst(world, _surprise.global_position + Vector3.UP * 0.6, Color("#ffd77e"), 22, 1.3, 1.0)
                ui.show_toast("The sprout opens golden — it was saving these. +3 sparkles.", 3.2)
                _refresh_ui()
                return true
        "mushroom_house":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                sparkles += 1
                _learn_fact("A knock on a mushroom house was answered")
                audio.play_tone(392.0, 0.25, 0.06, 1)
                audio.play_tone(523.25, 0.4, 0.06, 1)
                CozyVFX.burst(world, _surprise.global_position + Vector3.UP * 0.7, Color("#fff3c8"), 16, 1.0, 0.8)
                ui.show_toast("Somebody home! They trade a fact for the visit. +1 sparkle.", 3.2)
                _refresh_ui()
                return true
        "shooting_star":
            if near and not used:
                _surprise.set_meta("surprise_used", true)
                audio.play_tone(1318.5, 0.8, 0.05, 1)
                CozyVFX.ring(world, _surprise.global_position + Vector3.UP * 0.3, Color("#fff3a0"), 2.6, 1.0)
                var heart := HeartPickup.new()
                world.add_child(heart)
                heart.setup(_surprise.global_position + Vector3(0.6, 0.8, 0), 12.0, 1.0, true)
                heart.heart_collected.connect(_on_heart_collected)
                heart.heart_expired.connect(_on_heart_expired)
                ui.show_toast("The star twinkles — it waited all flight for you. A thank-you heart!", 3.4)
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
