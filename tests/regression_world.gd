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

    # The checks that need REAL generated floors live in regression_world_gen
    # now; everything here runs against the synthetic fixture.
    _check_reduced_motion_initial_state(world)
    _check_pool_water_animates(world)
    _check_ambient_life_centering(world, dungeon)
    _check_objective_layout(world)
    await _check_arrived_marker_goes_dark(world)
    _check_objective_props_do_not_stack(world, dungeon)
    _check_camera_facing_visuals(world)
    _check_web_render_calibration(world)

    var room: Dictionary = dungeon["rooms"][0]
    world.build_dragon(room, false)
    world.build_dream_chimes(room)
    var collected: Node3D = world.chimes.pop_front()
    world.remove_child(collected)
    collected.free()
    _check_chimes_avoid_the_landmark_props(world)
    _check_reduced_motion_settles_props_to_rest(world)
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
    # The arch's vines hang FROM the ring: each vine's top must stay within
    # the arch band at its own x. A vine whose top pokes above the ring reads
    # as a stalk floating past the arch, not one growing out of it.
    var vine_count := 0
    for child in stair.get_children():
        var mesh_instance := child as MeshInstance3D
        if mesh_instance == null or not (mesh_instance.mesh is CylinderMesh):
            continue
        var vine_mesh := mesh_instance.mesh as CylinderMesh
        if vine_mesh.height >= 1.0 or mesh_instance.position.y < 0.3:
            continue
        vine_count += 1
        var vine_top := mesh_instance.position.y + vine_mesh.height * 0.5
        var ring_top_at_x := 0.20 + sqrt(maxf(0.0, 1.30 * 1.30 - mesh_instance.position.x * mesh_instance.position.x))
        ok(vine_top <= ring_top_at_x + 0.06,
            "an arch vine's top (%.2f) pokes above the arch band at its x (%.2f); it floats past the ring instead of hanging from it" % [vine_top, ring_top_at_x])
    ok(vine_count == 3, "the arch should carry three hanging vines, found %d" % vine_count)

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

func _check_web_render_calibration(world: ForestWorld) -> void:
    ## The web build runs gl_compatibility, which has no SSAO/SSIL and a softer
    ## glow, so the Forward+ numbers rendered the web walk brighter and harsher
    ## than the desktop one. The correction is a pure function of the renderer
    ## name, so a headless run can hold every dial exactly.
    const Scenery := preload("res://scripts/world_scenery.gd")
    var environment := Environment.new()
    environment.ambient_light_energy = 0.48
    environment.glow_intensity = 0.58
    Scenery._calibrate_for_renderer(environment, "forward_plus")
    ok(is_equal_approx(environment.ambient_light_energy, 0.48),
        "the desktop renderer must keep the authored environment untouched")
    ok(is_equal_approx(environment.glow_intensity, 0.58),
        "the desktop renderer must keep the authored glow untouched")
    Scenery._calibrate_for_renderer(environment, "gl_compatibility")
    ok(environment.ambient_light_energy < 0.48,
        "the web calibration must rein the ambient light in (SSAO/SSIL are missing there)")
    ok(environment.glow_intensity > 0.58,
        "the web calibration must strengthen the glow that compatibility lands softer")
    ok(environment.adjustment_enabled, "the web calibration never enabled its color grade")
    ok(environment.adjustment_contrast < 1.0, "the web grade must soften the contrast")
    ok(environment.adjustment_brightness < 1.0, "the web grade must ease the brightness")
    ok(environment.adjustment_saturation > 1.0, "the web grade must hand the warmth back")

    # The ground is the largest bright surface on screen and the environment
    # dial alone left it washed out on web (the shader colors render flat with
    # no SSAO/SSIL to crease them). The moss has its own pure-function dial.
    var ground := ShaderMaterial.new()
    ground.shader = load("res://shaders/forest_ground.gdshader")
    var authored_base := Color("#87bd62").darkened(0.13)
    ground.set_shader_parameter("base_color", authored_base)
    ground.set_shader_parameter("light_patch", authored_base.lerp(Color("#d6cf82"), 0.27))
    ground.set_shader_parameter("deep_patch", authored_base.lerp(Color("#3f6b33"), 0.34))
    Scenery._calibrate_ground_for_renderer(ground, "forward_plus")
    ok(is_equal_approx((ground.get_shader_parameter("base_color") as Color).r, authored_base.r),
        "the desktop renderer must keep the authored moss untouched")
    ok(is_equal_approx(float(ground.get_shader_parameter("pool_strength")), 1.0),
        "the desktop renderer must keep the sun pools at full strength")
    Scenery._calibrate_ground_for_renderer(ground, "gl_compatibility")
    var web_base := ground.get_shader_parameter("base_color") as Color
    ok(web_base.r < authored_base.r and web_base.g < authored_base.g,
        "the web calibration must darken the moss itself")
    var web_light := ground.get_shader_parameter("light_patch") as Color
    ok(web_light.r < (authored_base.lerp(Color("#d6cf82"), 0.27)).r,
        "the web calibration must dim the bright sun-patch color")
    ok(float(ground.get_shader_parameter("pool_strength")) < 1.0,
        "the web calibration must shrink how much floor the sun pools light")

    # The pure functions are half the contract; the build path is the other
    # half. The floor the world actually builds must carry the AUTHORED moss
    # dials on this headless renderer (neither forward_plus nor
    # gl_compatibility), which fails if anyone ever applies the web
    # calibration unconditionally -- the one way this check can fail, and
    # the failure names the dial.
    var moss := world.get_node_or_null("MossFloor") as MeshInstance3D
    if not ok(moss != null and moss.material_override is ShaderMaterial,
            "the built floor carries no moss material to hold dials on"):
        return
    var live := moss.material_override as ShaderMaterial
    ok(is_equal_approx(float(live.get_shader_parameter("pool_strength")), 1.0),
        "the live floor lost the authored sun-pool strength to an unconditional calibration")

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
    ## stairwell's 1.0 m glow disc, on Peddle's cart, or on the wishing pool.
    for chime: Node3D in world.chimes:
        var stair_distance := Vector2(chime.global_position.x - world.stair_position.x,
            chime.global_position.z - world.stair_position.z).length()
        ok(stair_distance > 2.0,
            "a dream chime settled %.2f m from the stairwell, on top of its glow disc" % stair_distance)
        var merchant_distance := Vector2(chime.global_position.x - world.merchant_position.x,
            chime.global_position.z - world.merchant_position.z).length()
        ok(merchant_distance > 2.0,
            "a dream chime settled %.2f m from Peddle's cart" % merchant_distance)
        var pool := world.get_node_or_null("WishingPool") as Node3D
        if pool != null:
            var pool_distance := Vector2(chime.global_position.x - pool.position.x,
                chime.global_position.z - pool.position.z).length()
            ok(pool_distance > 2.0,
                "a dream chime settled %.2f m from the wishing pool, on top of its rim" % pool_distance)

func _check_reduced_motion_settles_props_to_rest(world: ForestWorld) -> void:
    ## The early return used to freeze the ambient animations at whatever
    ## phase they were in when the setting landed: a chime hung up to 13cm
    ## off its hover line, the dragon's breath and halo held arbitrary
    ## mid-swing values until the next floor rebuild. Rest is the promise,
    ## not a paused swing.
    world.set("_reduced_motion", false)
    world.set("_time", 0.0)
    world._process(0.25)
    var chime: Node3D = world.chimes[0]
    var base_y: float = float(chime.get_meta("base_y", 0.78))
    var drifted: float = chime.position.y - base_y
    if not ok(absf(drifted) > 0.01, "fixture expected a mid-bob chime, offset was %f" % drifted):
        return
    var body: Node3D = world.get("_dragon_body")
    var breath: float = (body.scale.x if body else 1.0)
    if not ok(absf(breath - 1.0) > 0.001, "fixture expected a mid-breath dragon, scale was %f" % breath):
        return
    var light: OmniLight3D = world.get("_dragon_light")
    var energy: float = (light.light_energy if light else 1.2)
    if not ok(absf(energy - 1.2) > 0.005, "fixture expected a mid-pulse halo, energy was %f" % energy):
        return
    world.set_reduced_motion(true)
    world._process(0.25)
    ok(is_equal_approx(chime.position.y, base_y),
        "reduced motion left a chime %f m off its hover line" % (chime.position.y - base_y))
    if body:
        ok(body.scale.is_equal_approx(Vector3.ONE),
            "reduced motion left the dragon's breath frozen at scale %f" % body.scale.x)
    if light:
        ok(is_equal_approx(light.light_energy, 1.2),
            "reduced motion left the halo frozen at energy %f" % light.light_energy)
    world.set_reduced_motion(false)

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
