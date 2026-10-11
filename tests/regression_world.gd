extends "res://tests/support/test_case.gd"
## Focused regressions for ForestWorld lifecycle, accessibility, objective layout,
## and camera-facing generated visuals.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyWaypoint := preload("res://scripts/cozy_waypoint.gd")
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")
const ForestWorld := preload("res://scripts/forest_world.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_WORLD_REGRESSION"
    # The relocated-stair check below drives the real game, and starting a run
    # saves meta -- keep that write in the throwaway profile.
    TestProfile.begin("world")
    call_deferred("_run")

func _run() -> void:
    var dungeon := _synthetic_dungeon()
    var world := ForestWorld.new()
    root.add_child(world)
    world.set_process(false)
    world.build_floor(1, dungeon, true)

    _check_objective_props_do_not_stack_on_generated_floors()
    await _check_the_relocated_stair_leaves_the_spawn()
    _check_reduced_motion_initial_state(world)
    _check_pool_water_animates(world)
    _check_ambient_life_centering(world, dungeon)
    _check_objective_layout(world)
    await _check_arrived_marker_goes_dark(world)
    _check_objective_props_do_not_stack(world, dungeon)
    _check_camera_facing_visuals(world)

    var room: Dictionary = dungeon["rooms"][0]
    world.build_dragon(room, false)
    world.build_dream_chimes(room)
    var collected: Node3D = world.chimes.pop_front()
    world.remove_child(collected)
    collected.free()
    _check_chimes_avoid_the_landmark_props(world)
    world.build_floor(2, dungeon, false)
    _check_rebuild_teardown(world)

    finish(world, "BEAUTY_FOREST_WORLD_REGRESSION")

func _check_reduced_motion_initial_state(world: ForestWorld) -> void:
    for child in world.get_children():
        if child is GPUParticles3D:
            ok(is_equal_approx((child as GPUParticles3D).speed_scale, 0.18),
                "reduced motion should apply to particles during initial build")
    var wind_materials: Array = world.get("_wind_materials")
    if wind_materials.is_empty():
        ok(false, "floor should own a wind material")
        return
    var wind_material := wind_materials[0] as ShaderMaterial
    wind_material.set_shader_parameter("wind_time", 0.0)
    world.set("_time", 0.0)
    var before: float = wind_material.get_shader_parameter("wind_time")
    world._process(0.25)
    var after: float = wind_material.get_shader_parameter("wind_time")
    ok(is_equal_approx(before, after), "reduced motion should hold foliage wind time steady")

func _check_pool_water_animates(world: ForestWorld) -> void:
    ## forest_water.gdshader drifts from `time_seconds`, so the pool must be
    ## fed a live clock. Reduced motion still holds it steady.
    var water: ShaderMaterial = world.get("_water_material")
    if water == null:
        ok(false, "the wishing pool built no water material to animate")
        return
    ok(water.shader != null, "the pool water has no shader")
    world.set("_time", 0.0)
    world.set("_reduced_motion", false)
    # Sentinel: if nothing drives the uniform it keeps this value forever.
    water.set_shader_parameter("time_seconds", -1.0)
    world._process(0.25)
    var moving: float = water.get_shader_parameter("time_seconds")
    ok(moving > 0.0, "the wishing pool never animated (time_seconds stayed at %f)" % moving)
    world.set("_reduced_motion", true)
    water.set_shader_parameter("time_seconds", 3.0)
    world._process(0.25)
    ok(is_equal_approx(water.get_shader_parameter("time_seconds"), 3.0), "reduced motion should hold the pool's drift steady")
    world.set("_reduced_motion", false)

func _check_ambient_life_centering(world: ForestWorld, dungeon: Dictionary) -> void:
    var expected := Vector3(float(dungeon["width"]) * 0.5, 0.0, float(dungeon["height"]) * 0.5)
    var particle_count := 0
    for child in world.get_children():
        if child is GPUParticles3D:
            particle_count += 1
            ok((child as GPUParticles3D).position.is_equal_approx(expected),
                "ambient particle fields should be centered on their floor")
    ok(particle_count == 2, "floor should own ambient motes and leaves")

func _check_objective_layout(world: ForestWorld) -> void:
    var stair := world.get_node_or_null("Stairwell") as Node3D
    var pool := world.get_node_or_null("WishingPool") as Node3D
    ok(stair != null and pool != null, "stair and wishing pool should exist")
    if stair and pool:
        var separation := Vector2(stair.position.x - pool.position.x, stair.position.z - pool.position.z).length()
        ok(separation > 3.0, "stair and wishing pool should not share the same clearing center")
    if stair == null:
        return
    var visible_step_count := 0
    for child in stair.get_children():
        var step := child as MeshInstance3D
        if step != null and step.mesh is BoxMesh and step.position.y < 1.0:
            var bounds: AABB = step.global_transform * step.get_aabb()
            if bounds.position.y >= -0.001:
                visible_step_count += 1
    ok(visible_step_count == 5, "all five stair treads should remain above the ground plane")
    var glow: MeshInstance3D
    for child in stair.get_children():
        if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh:
            glow = child as MeshInstance3D
    ok(glow != null and is_zero_approx(glow.global_position.y - 0.125),
        "stair glow should sit above the top tread")

func _check_camera_facing_visuals(world: ForestWorld) -> void:
    var sign := world.get_node_or_null("ForestSign")
    var label := _find_label(sign)
    ok(label != null, "forest sign should have a label")
    if label:
        ok(is_zero_approx(label.rotation.y), "sign label should face the fixed +Z camera side")
        ok(label.position.z > 0.0, "sign label should sit on the camera-facing board face")
    var merchant := world.merchant_visual
    ok(merchant != null, "Peddle should be built before visibility filtering")
    if merchant:
        var eye_count := 0
        var camera_facing_eye_count := 0
        for node in _descendants(merchant):
            if node is MeshInstance3D:
                var mesh := (node as MeshInstance3D).mesh as SphereMesh
                if mesh != null and is_equal_approx(mesh.radius, 0.055):
                    eye_count += 1
                    if node.global_position.z > merchant.global_position.z:
                        camera_facing_eye_count += 1
        ok(eye_count == 2 and camera_facing_eye_count == eye_count,
            "Peddle's eyes should be visible from the fixed camera")

func _check_arrived_marker_goes_dark(world: ForestWorld) -> void:
    ## set_arrived faded the core and halo but let the OmniLight keep pulsing,
    ## so the floor kept glowing under a marker the player had already
    ## answered -- an on-screen paragraph saying "someone is still here".
    ##
    ## This awaits, so the caller must await it too: `_run()` would otherwise
    ## carry on and rebuild the floor underneath, whose teardown frees every
    ## child of the world -- including this marker. The check then resumed into
    ## a freed instance and died on `_light` with a SCRIPT ERROR that a suite
    ## printing its OK line would swallow. A torn-down marker is exactly what
    ## set_arrived() is here to prevent, so the check has to survive the walk.
    var marker := CozyWaypoint.new()
    world.add_child(marker)
    marker.set_reduced_motion(false)
    await create_timer(0.05).timeout
    if not is_instance_valid(marker):
        ok(false, "the floor teardown freed the waypoint under the arrival check")
        return
    ok(marker._light.light_energy > 0.0,
            "the waypoint light never lit up in the first place: %.2f" % marker._light.light_energy)
    marker.set_arrived(true)
    await create_timer(0.05).timeout
    if not is_instance_valid(marker):
        ok(false, "the floor teardown freed the waypoint while it was checking arrival")
        return
    ok(marker._light.light_energy == 0.0,
            "the waypoint light kept burning after arrival: %.2f" % marker._light.light_energy)
    marker.set_arrived(false)
    await create_timer(0.05).timeout
    if not is_instance_valid(marker):
        return
    ok(marker._light.light_energy > 0.0,
            "stepping away did not relight the waypoint")
    marker.queue_free()

func _check_rebuild_teardown(world: ForestWorld) -> void:
    var world_environments := 0
    var physics_bodies := 0
    var old_dragons := 0
    var old_chimes := 0
    for child in world.get_children():
        if child is WorldEnvironment:
            world_environments += 1
        elif child is StaticBody3D:
            physics_bodies += 1
        elif child.name.begins_with("DreamChime"):
            old_chimes += 1
    for node in _descendants(world):
        if node.name == "Snoozle" or node.name == "SnoozlesFamily":
            old_dragons += 1
    ok(world_environments == 1, "rebuilding a floor should leave one WorldEnvironment")
    ok(physics_bodies == 1, "rebuilding a floor should leave one collision body")
    ok(old_dragons == 0, "rebuilding should tear down the previous dragon")
    ok(old_chimes == 0, "rebuilding should tear down the previous chimes")

func _find_label(node: Node) -> Label3D:
    if node == null:
        return null
    if node is Label3D:
        return node as Label3D
    for child in node.get_children():
        var found := _find_label(child)
        if found:
            return found
    return null

func _descendants(node: Node) -> Array[Node]:
    var result: Array[Node] = []
    for child in node.get_children():
        result.append(child)
        result.append_array(_descendants(child))
    return result

func _check_objective_props_do_not_stack_on_generated_floors() -> void:
    ## The synthetic fixture above hand-picks its rooms, so it never exercises the
    ## generator's slot-swap that put the farthest clearing in rooms[1]. Build
    ## real floors, which is the layout the player actually walks into.
    var probe := ForestWorld.new()
    root.add_child(probe)
    probe.set_process(false)
    for floor_number in [5, 13]:
        for attempt in range(8):
            var real_floor: int = floor_number + attempt * 97
            var generated := DungeonGenerator.generate(real_floor)
            probe.build_floor(real_floor, generated, true)
            var stair := probe.stair_position
            var merchant := probe.get_node_or_null("Peddle") as Node3D
            ok(merchant != null, "floor %d built no Peddle cart" % real_floor)
            if merchant != null:
                var separation := Vector2(stair.x - merchant.position.x, stair.z - merchant.position.z).length()
                ok(separation > 4.0,
                    "floor %d stacked the stairwell and Peddle's cart %.2f m apart" % [real_floor, separation])
            # Chimes only exist on a dragon floor, and they are built against a
            # cleared room rather than by build_floor itself. Snoozle takes the
            # biggest non-spawn clearing, exactly as run_world does.
            var rooms: Array = generated["rooms"]
            var dragon_room: Dictionary = rooms[0]
            var largest_area := -1.0
            for room: Dictionary in rooms:
                if room == rooms[0]:
                    continue
                if float(room["area"]) > largest_area:
                    largest_area = float(room["area"])
                    dragon_room = room
            probe.build_dragon(dragon_room, real_floor == 13)
            var chime_room: Dictionary = rooms[0]
            var farthest := -1.0
            for room: Dictionary in rooms:
                if room == dragon_room:
                    continue
                var reach := Vector2(room["cx"] - rooms[0]["cx"], room["cy"] - rooms[0]["cy"]).length()
                if reach > farthest:
                    farthest = reach
                    chime_room = room
            probe.build_dream_chimes(chime_room)
            ok(not probe.chimes.is_empty(), "floor %d built no dream chimes" % real_floor)
            for chime: Node3D in probe.chimes:
                var chime_to_stair := Vector2(chime.global_position.x - stair.x, chime.global_position.z - stair.z).length()
                ok(chime_to_stair > 2.0,
                    "floor %d put a dream chime %.2f m from the stairwell" % [real_floor, chime_to_stair])
    root.remove_child(probe)
    probe.free()

func _check_objective_props_do_not_stack(world: ForestWorld, dungeon: Dictionary) -> void:
    ## The generator deliberately parks the farthest clearing in the middle slot,
    ## so "the farthest room" (the stairwell) and rooms[1] (Peddle's cart) are the
    ## same room. Shipping both at that room's centre left the stair glow disc,
    ## the arch ring and the cart canopy interpenetrating, with the E and F
    ## prompts stacked on top of each other.
    var merchant := world.get_node_or_null("Peddle") as Node3D
    ok(merchant != null, "Peddle's cart should exist")
    if merchant == null:
        return
    var stair := world.stair_position
    var separation := Vector2(stair.x - merchant.position.x, stair.z - merchant.position.z).length()
    ok(separation > 4.0,
        "the stairwell and Peddle's cart are %.2f m apart in the same clearing; they need their own rooms" % separation)
    var pool := world.get_node_or_null("WishingPool") as Node3D
    if pool != null:
        var pool_separation := Vector2(pool.position.x - merchant.position.x, pool.position.z - merchant.position.z).length()
        ok(pool_separation > 2.0, "Peddle's cart should not sit on the wishing pool")

func _check_chimes_avoid_the_landmark_props(world: ForestWorld) -> void:
    ## Chimes are spread inside one clearing, so a chime could settle on the
    ## stairwell's 1.0 m glow disc or on Peddle's cart.
    for chime: Node3D in world.chimes:
        var stair_distance := Vector2(chime.global_position.x - world.stair_position.x,
            chime.global_position.z - world.stair_position.z).length()
        ok(stair_distance > 2.0,
            "a dream chime settled %.2f m from the stairwell, on top of its glow disc" % stair_distance)
        var merchant_distance := Vector2(chime.global_position.x - world.merchant_position.x,
            chime.global_position.z - world.merchant_position.z).length()
        ok(merchant_distance > 2.0,
            "a dream chime settled %.2f m from Peddle's cart" % merchant_distance)

func _synthetic_dungeon() -> Dictionary:
    var size := 48
    var grid := PackedInt32Array()
    grid.resize(size * size)
    grid.fill(DungeonGenerator.FLOOR)
    var rooms: Array[Dictionary] = [
        {"x": 6, "y": 6, "w": 8, "h": 8, "cx": 10.0, "cy": 10.0, "area": 64},
        {"x": 28, "y": 8, "w": 9, "h": 9, "cx": 32.5, "cy": 12.5, "area": 81},
        {"x": 12, "y": 29, "w": 8, "h": 8, "cx": 16.0, "cy": 33.0, "area": 64},
    ]
    return {"width": size, "height": size, "grid": grid, "rooms": rooms, "seed": 123, "floor": 1}

func _check_the_relocated_stair_leaves_the_spawn() -> bool:
    ## A dragon floor relocates the stairwell when the generator happened to put
    ## it in Snoozle's clearing. It has to land somewhere the hero is NOT
    ## standing: the whole tail of the floor is "wander down to the stair", and
    ## the interact radius is 2.3 m. Taking the first room that is not the
    ## dragon's room is rooms[0] -- the spawn clearing -- so the revealed
    ## stairwell appeared exactly on the hero, and one press of E descended
    ## without walking a step.
    ##
    ## Driven through the real game, because the relocation lives on the run
    ## state rather than on ForestWorld.
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)
    game._start_run(1)
    await frames(4)
    var dragon_floors := 0
    var on_spawn := 0
    # A wide contiguous band. Both defects here are LAYOUT-DEPENDENT -- they only
    # misfire on some generated floors -- so a narrow arithmetic sweep that
    # landed on 4 dragon floors could not see either one. This band covers 30.
    for real_floor in range(1, 200):
        game._load_floor(real_floor, false)
        await frames(2)
        if not game.dragon_exists:
            continue
        dragon_floors += 1
        var rooms: Array = game.dungeon["rooms"]
        var spawn_room: Dictionary = rooms[0]
        var stair: Vector3 = game.world.stair_position
        var spawn := Vector3(float(spawn_room["cx"]), 0, float(spawn_room["cy"]))
        var separation := Vector2(stair.x - spawn.x, stair.z - spawn.z).length()
        if separation < 2.3:
            on_spawn += 1
        ok(separation > 2.3,
            "floor %d left the relocated stairwell %.2f m from the spawn -- inside the 2.3 m interact radius, so the hero descends without walking" % [real_floor, separation])
        ok(not game._point_in_room(stair, spawn_room),
            "floor %d left the relocated stairwell inside the spawn clearing the hero starts in" % real_floor)
        # And the chimes must have spread AROUND the stairwell's final home.
        # build_dream_chimes() seeds its spread from the landmark positions, so
        # if the stair is relocated after it runs, the chimes were told to avoid
        # a spot the stair then moved into. That fires on 14 of 30 dragon floors.
        for chime: Node3D in game.world.chimes:
            var chime_to_stair := Vector2(chime.global_position.x - stair.x, chime.global_position.z - stair.z).length()
            ok(chime_to_stair > 2.0,
                "floor %d settled a dream chime %.2f m from the relocated stairwell" % [real_floor, chime_to_stair])
    root.remove_child(game)
    game.free()
    await frames(2)
    if dragon_floors == 0:
        fail("no dragon floors were generated, so the relocated stairwell was never checked")
        return false
    printerr("RELOCATION_SAMPLE: %d dragon floors, %d put the stair on the spawn" % [dragon_floors, on_spawn])
    return true
