extends SceneTree

## Focused regressions for ForestWorld lifecycle, accessibility, objective layout,
## and camera-facing generated visuals.

var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dungeon := _synthetic_dungeon()
    var world := ForestWorld.new()
    root.add_child(world)
    world.set_process(false)
    world.build_floor(1, dungeon, true)

    _check_reduced_motion_initial_state(world)
    _check_pool_water_animates(world)
    _check_ambient_life_centering(world, dungeon)
    _check_objective_layout(world)
    _check_camera_facing_visuals(world)

    var room: Dictionary = dungeon["rooms"][0]
    world.build_dragon(room, false)
    world.build_dream_chimes(room)
    var collected: Node3D = world.chimes.pop_front()
    world.remove_child(collected)
    collected.free()
    var animation_owners = world.get("_animated_chimes")
    if animation_owners is Array:
        for owner in animation_owners:
            _check(is_instance_valid(owner), "collected chimes must not remain in an animation owner array")
    world.build_floor(2, dungeon, false)
    _check_rebuild_teardown(world)

    root.remove_child(world)
    world.free()
    if failures == 0:
        print("BEAUTY_FOREST_WORLD_REGRESSION_OK")
    quit(failures)

func _check_reduced_motion_initial_state(world: ForestWorld) -> void:
    for child in world.get_children():
        if child is GPUParticles3D:
            _check(is_equal_approx((child as GPUParticles3D).speed_scale, 0.18),
                "reduced motion should apply to particles during initial build")
    var wind_materials: Array = world.get("_wind_materials")
    if wind_materials.is_empty():
        _check(false, "floor should own a wind material")
        return
    var wind_material := wind_materials[0] as ShaderMaterial
    wind_material.set_shader_parameter("wind_time", 0.0)
    world.set("_time", 0.0)
    var before: float = wind_material.get_shader_parameter("wind_time")
    world._process(0.25)
    var after: float = wind_material.get_shader_parameter("wind_time")
    _check(is_equal_approx(before, after), "reduced motion should hold foliage wind time steady")

func _check_pool_water_animates(world: ForestWorld) -> void:
    ## forest_water.gdshader drifts from `time_seconds`, so the pool must be
    ## fed a live clock. Reduced motion still holds it steady.
    var water: ShaderMaterial = world.get("_water_material")
    if water == null:
        _check(false, "the wishing pool built no water material to animate")
        return
    _check(water.shader != null, "the pool water has no shader")
    world.set("_time", 0.0)
    world.set("_reduced_motion", false)
    # Sentinel: if nothing drives the uniform it keeps this value forever.
    water.set_shader_parameter("time_seconds", -1.0)
    world._process(0.25)
    var moving: float = water.get_shader_parameter("time_seconds")
    _check(moving > 0.0, "the wishing pool never animated (time_seconds stayed at %f)" % moving)
    world.set("_reduced_motion", true)
    water.set_shader_parameter("time_seconds", 3.0)
    world._process(0.25)
    _check(is_equal_approx(water.get_shader_parameter("time_seconds"), 3.0), "reduced motion should hold the pool's drift steady")
    world.set("_reduced_motion", false)

func _check_ambient_life_centering(world: ForestWorld, dungeon: Dictionary) -> void:
    var expected := Vector3(float(dungeon["width"]) * 0.5, 0.0, float(dungeon["height"]) * 0.5)
    var particle_count := 0
    for child in world.get_children():
        if child is GPUParticles3D:
            particle_count += 1
            _check((child as GPUParticles3D).position.is_equal_approx(expected),
                "ambient particle fields should be centered on their floor")
    _check(particle_count == 2, "floor should own ambient motes and leaves")

func _check_objective_layout(world: ForestWorld) -> void:
    var stair := world.get_node_or_null("Stairwell") as Node3D
    var pool := world.get_node_or_null("WishingPool") as Node3D
    _check(stair != null and pool != null, "stair and wishing pool should exist")
    if stair and pool:
        var separation := Vector2(stair.position.x - pool.position.x, stair.position.z - pool.position.z).length()
        _check(separation > 3.0, "stair and wishing pool should not share the same clearing center")
    if stair == null:
        return
    var visible_step_count := 0
    for child in stair.get_children():
        var step := child as MeshInstance3D
        if step != null and step.mesh is BoxMesh and step.position.y < 1.0:
            var bounds: AABB = step.global_transform * step.get_aabb()
            if bounds.position.y >= -0.001:
                visible_step_count += 1
    _check(visible_step_count == 5, "all five stair treads should remain above the ground plane")
    var glow: MeshInstance3D
    for child in stair.get_children():
        if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh:
            glow = child as MeshInstance3D
    _check(glow != null and is_zero_approx(glow.global_position.y - 0.125),
        "stair glow should sit above the top tread")

func _check_camera_facing_visuals(world: ForestWorld) -> void:
    var sign := world.get_node_or_null("ForestSign")
    var label := _find_label(sign)
    _check(label != null, "forest sign should have a label")
    if label:
        _check(is_zero_approx(label.rotation.y), "sign label should face the fixed +Z camera side")
        _check(label.position.z > 0.0, "sign label should sit on the camera-facing board face")
    var merchant := world.merchant_visual
    _check(merchant != null, "Peddle should be built before visibility filtering")
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
        _check(eye_count == 2 and camera_facing_eye_count == eye_count,
            "Peddle's eyes should be visible from the fixed camera")

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
    _check(world_environments == 1, "rebuilding a floor should leave one WorldEnvironment")
    _check(physics_bodies == 1, "rebuilding a floor should leave one collision body")
    _check(old_dragons == 0, "rebuilding should tear down the previous dragon")
    _check(old_chimes == 0, "rebuilding should tear down the previous chimes")

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

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    printerr("FAIL: ", message)
