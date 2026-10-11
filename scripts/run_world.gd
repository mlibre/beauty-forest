class_name RunWorld
extends "res://scripts/run_ceremonies.gd"
## Floor construction and traversal: teardown/rebuild of the forest world, the
## player and Mote, objective placement, stairs, interaction and the camera.
## Combat and lullaby state it resets live in RunCombat.

## The floor the pool last granted a wish on, so one sparkle buys one small
## blessing per floor and the pool never becomes a heal fountain.
var _wish_floor := 0

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
    floor_modifier = BeautyContent.random_modifier(BeautyContent.story_floor(floor_number)) if not menu_stage else {}

    if not menu_stage:
        _spawn_wisps()
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
    audio.start_ambient(String(region.get("ambient", region["key"])))
    ui.set_map(dungeon, player.global_position)
    _refresh_ui()
    if not menu_stage:
        player.set_control_enabled(true)
        var vignette: Array = BeautyContent.story_for_floor(floor_number)
        if not vignette.is_empty():
            ui.show_story(String(vignette[0]), String(vignette[1]))
        # A region says hello on its first floor: `min` is that floor for the
        # campaign's own regions and for a composed endless chapter alike.
        # A toast, not the hidden log: the greeting is the region's one moment.
        # Floor 1 is the exception -- its vignette card IS the welcome, and a
        # second greeting would put a sentence over the walk itself.
        if floor_number > 1 and floor_number == int(region.get("min", 1)):
            ui.show_toast(String(region["entry"]), 3.6)
        ui.add_log("Mote: “Today’s forecast: %s — %s.”" % [String(floor_modifier.get("name", "cozy air")), String(floor_modifier.get("description", "the woods are humming"))])
        # A milestone cheer: every tenth floor the forest throws petals, so a
        # long walk has something to look forward to that is not a threat.
        if floor_number > 1 and floor_number % 10 == 0:
            CozyVFX.burst(world, player.global_position + Vector3(0, 3.0, 0), Color("#ffe9a8"), 56, 1.6, 2.6)
            ui.show_toast("The forest cheers — %d floors deep!" % floor_number, 3.0)
        if merchant_exists:
            ui.show_toast("Peddle’s cart is nearby. Press F when you’re ready to browse.")
        if _has_feeling_floor():
            ui.show_toast("A Big Feeling wanders this floor. Wait for its GOLD halo, then press E nearby and sing with it.")

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
    var near_chime := _nearest_chime()
    if near_chime != null:
        ui.add_cue("chimes drift close — no button")
        return
    ui.add_cue("wander toward whatever glows")

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
