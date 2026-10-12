class_name RunWorld
extends "res://scripts/run_ceremonies.gd"
## Floor construction and traversal: teardown/rebuild of the forest world, the
## player and Mote, objective placement, stairs, interaction and the camera.
## Combat and lullaby state it resets live in RunCombat.

## The floor the pool last granted a wish on, so one sparkle buys one small
## blessing per floor and the pool never becomes a heal fountain.
var _wish_floor := 0

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const FloorSurprise := preload("res://scripts/floor_surprise.gd")
## This floor's one surprise — spawned with the floor, polled while walking.
var _surprise: Node3D
## Seconds spent standing inside the star glade; the glade grants its warmth
## to a hero who stops for a breath, so the timer lives with the walker.
var _glade_time := 0.0

func _update_camera(delta: float) -> void:
    if player == null or not is_instance_valid(player):
        return
    var target := player.global_position + CAMERA_OFFSET
    var weight := 1.0 if bool(settings.get("reduced_motion", false)) else 1.0 - exp(-delta * 5.2)
    camera.global_position = camera.global_position.lerp(target, weight)
    # The offset and look target have the same relationship every frame, so
    # orientation stays exactly fixed. No interpolation can introduce roll.
    # Intentionally no mouse aim, no recoil, no trauma, and no shake.

func _load_floor(number: int, menu_stage: bool = false) -> void:
    ending_pending = false
    ending_countdown = 0.0
    _wish_floor = 0
    _reset_lullaby()
    if is_instance_valid(world):
        world.get_parent().remove_child(world)
        world.queue_free()
    # The waypoint hangs off the world, so the teardown above frees it too.
    # Holding the stale reference would make _set_waypoint_active() try to
    # reparent a freed node on the next floor.
    _waypoint = null
    notes.clear()
    wisps.clear()

    floor_number = maxi(1, number)
    dungeon = DungeonGenerator.generate(floor_number)
    region = BeautyContent.region_for_floor(floor_number)
    world = ForestWorld.new()
    world.name = "ForestFloor%d" % floor_number
    add_child(world)
    world.build_floor(floor_number, dungeon, bool(settings.get("reduced_motion", false)))
    _set_world_processing(mode in [Mode.MENU, Mode.PLAYING])

    player = Player.new()
    player.name = "Wanderer"
    world.add_child(player)
    player.setup(dungeon, charm_effects, bool(settings.get("reduced_motion", false)))
    var spawn_room: Dictionary = dungeon["rooms"][0]
    player.global_position = Vector3(spawn_room["cx"], 0.05, spawn_room["cy"])
    player.footstep.connect(_on_player_footstep)
    player.dashed.connect(_on_player_dashed)
    if mote and is_instance_valid(mote):
        var old_parent := mote.get_parent()
        if old_parent:
            old_parent.remove_child(mote)
        world.add_child(mote)
    else:
        mote = _build_mote()
        world.add_child(mote)
    mote.global_position = player.global_position + START_POSITIONS

    stair_visible = true
    merchant_exists = false
    dragon_exists = false
    dragon_finale = false
    _soothes_this_floor = 0
    _mote_joy = 0.0
    _surprise = null
    _glade_time = 0.0
    floor_modifier = BeautyContent.random_modifier(BeautyContent.story_floor(floor_number)) if not menu_stage else {}

    if not menu_stage:
        _spawn_wisps()
        _spawn_surprise()
        var story := BeautyContent.story_floor(floor_number)
        merchant_exists = story in [2, 4, 7, 10] and not BeautyContent.is_dragon_floor(floor_number)
        dragon_exists = BeautyContent.is_dragon_floor(floor_number)
        dragon_finale = story == 13
        if dragon_exists:
            # The hero arrives at the centre of rooms[0], and Snoozle is 5m of
            # sleeping barrel with no collider to push the hero out. Sleeping in
            # the spawn clearing means the player opens the floor standing inside
            # the dragon, so Snoozle takes the biggest *other* clearing and the
            # walk over to meet it is the point of the floor.
            var dragon_room: Dictionary = dungeon["rooms"][0]
            var largest: Dictionary = dragon_room
            var largest_area := -1.0
            for room: Dictionary in dungeon["rooms"]:
                if room == dragon_room:
                    continue
                if float(room["area"]) > largest_area:
                    largest_area = float(room["area"])
                    largest = room
            world.build_dragon(largest, dragon_finale)
            # Relocate BEFORE building the chimes. build_dream_chimes() seeds its
            # spread with the cells the landmark props already own, stair included,
            # so building the chimes first reserved the STALE stair position and
            # left them free to settle on the stairwell the relocation was about to
            # move into their clearing (measured on 5 of 30 dragon floors). Order
            # was the shared cause; the stair now knows its final home first.
            _relocate_stair_from(largest)
            var chime_room := _farthest_non_dragon_room(largest)
            world.build_dream_chimes(chime_room)
            stair_visible = false
        world.set_objectives_visible(stair_visible, merchant_exists, dragon_exists)
        hit_this_floor = false
        pulse_cooldown = 0.0
        note_cooldown = 0.0
        invulnerable_time = 1.0
        _next_petal_shower = play_seconds + _rng.randf_range(32.0, 56.0)
    else:
        # The menu is the first thing a player sees, and it was an EMPTY
        # clearing: no wisps, no objectives, nothing glowing, under a scrim.
        # Measured, the menu backdrop sat at a mean luminance of 99 against
        # 176 in gameplay -- the darkest screen in a bright golden-dusk game.
        # A few wandering wisps give the forest something to be, without
        # turning the title card into a playable floor: they idle, nothing
        # spawns a boss or a Big Feeling, and _gameplay_controls_enabled() is
        # false so nothing can be hugged, sung to or hurt.
        _spawn_menu_wisps()
        world.set_objectives_visible(false, false, false)
        # Nothing on the title floor is an objective: without this, the
        # stair branch in _update_waypoint parked a glowing marker on an
        # invisible stairwell through the whole menu.
        stair_visible = false

    camera.global_position = player.global_position + CAMERA_OFFSET
    camera.look_at(player.global_position + Vector3.UP * 0.78, Vector3.UP)
    # Odd floors hum each region's variation, so a long walk hears two songs
    # per region instead of one loop forever (see MusicDirector.floor_song).
    music.play_region(music.floor_song(String(region.get("ambient", region["key"])), floor_number))
    ui.set_map(dungeon, player.global_position)
    _refresh_ui()
    if not menu_stage:
        player.set_control_enabled(true)
        var vignette: Array = BeautyContent.story_for_floor(floor_number)
        if not vignette.is_empty():
            # The floor's opening page arrives illustrated: the region's own
            # mark rides above the words, the way the intro's pages do.
            ui.show_story(String(vignette[0]), String(vignette[1]), 3.8, String(region.get("glyph", "mote")))
        # A region says hello on its first floor: `min` is that floor for the
        # campaign's own regions and for a composed endless chapter alike.
        # A toast, not the hidden log: the greeting is the region's one moment.
        # Floor 1 is the exception -- its vignette card IS the welcome, and a
        # second greeting would put a sentence over the walk itself.
        if floor_number > 1 and floor_number == int(region.get("min", 1)):
            ui.show_toast(String(region["entry"]), 3.6)
        ui.add_log("Mote: “Today’s forecast: %s — %s.”" % [String(floor_modifier.get("name", "soft air")), String(floor_modifier.get("description", "the woods are humming"))])
        # A milestone cheer: every tenth floor the forest throws petals, so a
        # long walk has something to look forward to that is not a threat.
        if floor_number > 1 and floor_number % 10 == 0:
            CozyVFX.burst(world, player.global_position + Vector3(0, 3.0, 0), Color("#ffe9a8"), 56, 1.6, 2.6)
            ui.show_toast("The forest cheers — %d floors deep!" % floor_number, 3.0)
        if merchant_exists:
            ui.show_toast("Peddle’s cart is nearby — walk up and press E to browse.", 3.2)
        if _has_feeling_floor():
            ui.show_toast("A Big Feeling wanders this floor. Wait for its GOLD halo, then press E nearby and sing with it.")
        if _surprise != null:
            # One soft announcement, the same voice that names the cart: the
            # surprise is something you wander INTO, so it is named once and
            # never chased.
            ui.show_toast("You spot %s — %s" % [String(_surprise.get_meta("surprise_name")), FloorSurprise.kind_for_floor(floor_number)["line"]], 3.2)

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
                _learn_fact("A mossy doodle on floor %d taught it: “%s”" % [floor_number, String(BeautyLore.FACTS[randi() % BeautyLore.FACTS.size()])])
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

## A handful of wisps for the title backdrop.
##
## Deliberately not _spawn_wisps(): that one scales with the floor, spawns a
## boss every third story floor and a Big Feeling on floors 4/8/12, all of
## which the menu must not contain. These just drift near the spawn so the
## forest behind the title card is alive.
func _spawn_menu_wisps() -> void:
    var occupied: Dictionary = {}
    var spawn_room: Dictionary = dungeon["rooms"][0]
    for index in range(5):
        var cell := DungeonGenerator.random_floor_cell(dungeon, _rng, Vector2(spawn_room["cx"], spawn_room["cy"]), 6.0, occupied)
        occupied[cell] = true
        var wisp := _new_wisp(cell, BeautyContent.pick_wisp_type(1), 1)
        # The title's backdrop souls drift contentedly mid-warmth: the walk's
        # truth is "sad until helped", but the first screen should promise the
        # middle of that journey, not its loneliest moment.
        wisp.set_happiness(0.55)
        wisp.set_meta("attack_cooldown", _rng.randf_range(0.2, 1.1))
        wisp.set_meta("said_grumble", false)

func _farthest_non_dragon_room(dragon_room: Dictionary) -> Dictionary:
    var spawn_room: Dictionary = dungeon["rooms"][0]
    var best: Dictionary = dragon_room
    var best_distance := -1.0
    for room: Dictionary in dungeon["rooms"]:
        if room == dragon_room:
            continue
        var distance := Vector2(room["cx"] - spawn_room["cx"], room["cy"] - spawn_room["cy"]).length()
        if distance > best_distance:
            best_distance = distance
            best = room
    return best

## Move the stairwell off Snoozle's clearing, onto the chime clearing.
##
## It must NOT be rooms[0]. rooms[0] is the spawn clearing, and the hero always
## starts at its centre, so relocating there put the revealed stairwell exactly
## under the player's feet: the floor's whole tail is "wander down to the stair"
## and the interact radius is 2.3m, so one press of E descended without walking
## a step (measured on 21 of 30 dragon floors). The chimes are already built in
## the clearing farthest from the spawn, so the stair belongs there instead --
## a real walk, and it finishes where the last chime was.
func _relocate_stair_from(room: Dictionary) -> void:
    if not _point_in_room(world.stair_position, room):
        return
    var spawn_room: Dictionary = dungeon["rooms"][0]
    var candidate: Dictionary = _farthest_non_dragon_room(room)
    if candidate == spawn_room or candidate == room:
        return
    world.stair_position = Vector3(candidate["cx"], 0, candidate["cy"])
    var stair := world.get_node_or_null("Stairwell")
    if stair:
        (stair as Node3D).position = world.stair_position

func _point_in_room(point: Vector3, room: Dictionary) -> bool:
    return DungeonGenerator.point_in_room(room, point.x, point.z)

func _nearest_chime() -> Node3D:
    if not dragon_exists or world == null:
        return null
    var best: Node3D
    var best_distance := 1.7
    for chime in world.chimes:
        if not is_instance_valid(chime):
            continue
        var distance := player.global_position.distance_to(chime.global_position)
        if distance < best_distance:
            best_distance = distance
            best = chime
    return best

func _try_interact() -> void:
    # The finale epilogue keeps Mode.PLAYING so the story can play out, so this
    # needs the same gate Dash uses: without it E and the touch SING button
    # answered with a stray "wander toward whatever is glowing" while the
    # controls were off and the ending card owned the screen.
    if not _gameplay_controls_enabled():
        return
    if _lullaby_active:
        _judge_lullaby_beat()
        return
    # One key for every nearby kindness. Peddle's cart used to want its own
    # key (F), which is one more thing to learn and one more thing to forget
    # at the moment of use; the context pill and the touch button now carry
    # the whole truth ("E · Peddle's cart"), and F keeps working as an
    # alias for hands that already learned it. Opening the stall is the
    # director's move (see the hook in RunState), so this asks, not does.
    if _near_merchant() and _try_open_nearby_shop():
        return
    if stair_visible and world and is_instance_valid(world.get_node_or_null("Stairwell")):
        var stair := world.get_node("Stairwell") as Node3D
        if stair.visible and player.global_position.distance_to(stair.global_position) < 2.3:
            _descend()
            return
    var feeling := _near_feeling(4.5)
    if feeling != null and feeling.is_boss_vulnerable():
        _begin_feeling_lullaby(feeling)
        return
    if world and is_instance_valid(world.get_node_or_null("WishingPool")):
        var pool := world.get_node("WishingPool") as Node3D
        if pool and player.global_position.distance_to(pool.global_position) < 2.6:
            _make_a_wish()
            return
    # The floor's own surprise answers before the generic cue does.
    if _surprise_interact():
        return
    var near_chime := _nearest_chime()
    if near_chime != null:
        ui.add_cue("chimes drift close — no button")
        return
    ui.add_cue("wander toward whatever glows")

## What the hero is standing beside, in one verb — the same senses, in the
## same order, as _try_interact answers them. The context pill ("E · Descend")
## and the touch action button's face are both fed from here, so the hint and
## the press can never disagree about what E does right now.
func _interact_hint_text() -> String:
    if _lullaby_active or player == null or not is_instance_valid(player):
        return ""
    if _near_merchant():
        return "Peddle's cart"
    if stair_visible and world and is_instance_valid(world.get_node_or_null("Stairwell")):
        var stair := world.get_node("Stairwell") as Node3D
        if stair.visible and player.global_position.distance_to(stair.global_position) < 2.3:
            return "Descend"
    var feeling := _near_feeling(4.5)
    if feeling != null and feeling.is_boss_vulnerable():
        return "Sing together"
    if world and is_instance_valid(world.get_node_or_null("WishingPool")):
        var pool := world.get_node("WishingPool") as Node3D
        if pool and player.global_position.distance_to(pool.global_position) < 2.6:
            return "Make a wish"
    return _surprise_hint_text()

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

## Feed the pill and the touch button from the same sense. An empty verb
## hides the pill and rests the button; a panel opening hides it via
## close_panels, so no stale "press E" survives a modal.
func _update_context_hint() -> void:
    if ui == null or not is_instance_valid(ui):
        return
    var verb := ""
    if mode == Mode.PLAYING and not ending_pending:
        verb = _interact_hint_text()
    ui.show_context_hint(verb)
    ui.set_action_label(verb)

## The wishing pool was the one landmark nothing could do anything with: an
## elaborate prop whose only interaction was Mote's generic fallback line. Now
## E near the water tosses one sparkle and the pool answers with a ring of
## light and a little warmth -- once per floor, so it stays a small ritual,
## not a heal fountain. A player with no sparkles gets told what it wants.
func _make_a_wish() -> void:
    if _wish_floor == floor_number:
        ui.add_cue("the pool heard you already")
        return
    if sparkles < 1:
        ui.add_cue("the pool likes a sparkle")
        return
    # A full lantern would clamp the warmth away: payment with nothing back.
    # The pool waits -- a wish is still there once a bump has made room.
    if hp >= hp_max:
        ui.add_cue("your lantern is already full")
        return
    _wish_floor = floor_number
    sparkles -= 1
    hp = minf(hp_max, hp + 15.0)
    var pool := world.get_node("WishingPool") as Node3D
    CozyVFX.ring(world, pool.global_position + Vector3.UP * 0.3, Color("#ffe9a8"), 2.8, 1.2)
    audio.play_chord([523.25, 659.25, 880.0], 0.6, 0.08)
    ui.show_story("The pool glows ✦", "%s\n+15 warmth, with the forest’s thanks." % String(BeautyContent.random_choice(BeautyLore.WISH_LINES)), 3.6)
    _refresh_ui()

func _descend() -> void:
    hp = minf(hp_max, hp + 30.0)
    if not hit_this_floor:
        _award_sticker("pacifist")
        ui.add_log("Mote: “Not a single bump! I’m writing a ballad about this.”")
    var next_floor := floor_number + 1
    if next_floor >= 6:
        _award_sticker("kindling")
    meta["best_floor"] = maxi(int(meta.get("best_floor", 0)), next_floor)
    BeautyData.save_meta(meta)
    ui.add_log("Floor %d cleared. You rest by the stairwell (+30 warmth), then wander down." % floor_number)
    ui.add_log("Mote: “%s”" % String(BeautyContent.random_choice(BeautyLore.DESCEND_LINES)))
    audio.play_chord([392.0, 493.88, 587.33], 0.72, 0.09)
    _load_floor(next_floor, false)

func _build_mote() -> Node3D:
    var root := Node3D.new()
    root.name = "Mote"
    mote_core = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    sphere.radial_segments = 16
    sphere.rings = 10
    mote_core.mesh = sphere
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#fff0aa")
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = Color("#ffe486")
    material.emission_energy_multiplier = 3.0
    mote_core.material_override = material
    root.add_child(mote_core)
    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.033
        eye_mesh.height = 0.06
        eye.mesh = eye_mesh
        var eye_material := StandardMaterial3D.new()
        eye_material.albedo_color = Color("#4a3729")
        eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        eye.material_override = eye_material
        eye.position = Vector3(side * 0.07, 0.02, -0.205)
        root.add_child(eye)
    var halo := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.28
    torus.outer_radius = 0.34
    halo.mesh = torus
    var halo_material := StandardMaterial3D.new()
    halo_material.albedo_color = Color(1, 0.84, 0.35, 0.30)
    halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    halo.mesh.material = halo_material
    root.add_child(halo)
    mote_light = OmniLight3D.new()
    mote_light.light_color = Color("#ffe595")
    mote_light.light_energy = 0.45
    mote_light.omni_range = 3.8
    root.add_child(mote_light)
    _mote_seed = randf() * TAU
    return root

func _update_mote(delta: float) -> void:
    if mote == null or not is_instance_valid(mote) or player == null or not is_instance_valid(player):
        return
    _mote_seed += delta * 0.72
    _mote_joy = maxf(0.0, _mote_joy - delta * 0.8)
    var orbit := Vector3.ZERO
    if not bool(settings.get("reduced_motion", false)):
        var joy_hop := _mote_joy * 0.22
        orbit = Vector3(sin(_mote_seed) * 0.18, sin(_mote_seed * 1.7) * 0.10 + joy_hop * sin(_mote_seed * 6.0), cos(_mote_seed * 0.8) * 0.18)
    var target := player.global_position + Vector3(-0.72, 1.48, 0.42) + orbit
    var weight := 1.0 - exp(-delta * (3.0 if mode == Mode.MENU else 5.0))
    mote.global_position = mote.global_position.lerp(target, weight)
    if mote_core:
        mote_core.rotation.y += delta * 0.8
    if mote_light and is_instance_valid(mote_light):
        mote_light.light_energy = 0.45 + _mote_joy * 0.55
    if not bool(settings.get("reduced_motion", false)):
        mote.scale = Vector3.ONE * (1.0 + sin(_mote_seed * 2.0) * 0.035 + _mote_joy * 0.12)
    else:
        # Reduced motion holds the mote STILL, and still means its rest shape:
        # without this reset the scale stayed frozen at whatever the wobble
        # sine held when the setting landed -- the one companion visibly left
        # mid-wobble (or mid-joy) forever.
        mote.scale = Vector3.ONE
