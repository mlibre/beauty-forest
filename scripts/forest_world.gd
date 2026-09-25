class_name ForestWorld
extends WorldLandmarks

## Floor lifecycle and per-frame ambience: builds a complete bright forest
## floor from the inherited scenery (WorldScenery) and landmarks
## (WorldLandmarks), then owns the Dream Chimes, the sleeping dragon family and
## objective visibility.

func build_floor(p_floor: int, p_dungeon: Dictionary, reduced_motion: bool = false) -> void:
    _teardown_floor()
    floor_number = p_floor
    dungeon = p_dungeon
    region = BeautyContent.region_for_floor(p_floor)
    _reduced_motion = reduced_motion
    _rng.seed = int(dungeon.get("seed", 1))
    _build_environment()
    _build_ground_and_collisions()
    _build_grove_visual()
    _build_decor()
    _build_sunbeams()
    _build_ambient_life()
    _build_clearings()
    _set_particle_motion(self, _reduced_motion)

func _teardown_floor() -> void:
    for child: Node in get_children():
        _free_child(child)
    chimes.clear()
    _wind_materials.clear()
    _water_material = null
    _time = 0.0
    stair_position = Vector3.ZERO
    merchant_position = Vector3.ZERO
    dragon_position = Vector3.ZERO
    dragon_visual = null
    merchant_visual = null
    _dragon_body = null
    _dragon_light = null
    _merchant_body = null

func _free_child(node: Node) -> void:
    if not is_instance_valid(node):
        return
    var parent := node.get_parent()
    if parent == self:
        remove_child(node)
    elif parent != null:
        return
    node.queue_free()

func build_dragon(room: Dictionary, finale: bool) -> Node3D:
    _free_child(dragon_visual)
    dragon_visual = null
    _dragon_body = null
    _dragon_light = null
    var dragon := Node3D.new()
    dragon.name = "Snoozle" if not finale else "SnoozlesFamily"
    dragon.position = Vector3(room["cx"], 0, room["cy"])
    dragon.rotation.y = _rng.randf_range(-0.45, 0.45)
    dragon.scale = Vector3.ONE * (1.0 if not finale else 0.92)
    add_child(dragon)
    dragon_visual = dragon
    dragon_position = dragon.position

    var body := Node3D.new()
    body.name = "BreathingBody"
    dragon.add_child(body)
    _dragon_body = body
    var body_color := Color("#b7cf72") if not finale else Color("#d2b96b")
    var belly_color := Color("#f2df9c")
    var body_mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 1.22
    capsule.height = 4.7
    body_mesh.mesh = capsule
    body_mesh.material_override = _toon(body_color, 0.10, 0.78)
    body_mesh.rotation.z = PI * 0.5
    body_mesh.position = Vector3(0, 1.45, 0)
    body_mesh.scale = Vector3(1.15, 1.0, 0.92)
    body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    body.add_child(body_mesh)
    var belly := MeshInstance3D.new()
    var belly_mesh := SphereMesh.new()
    belly_mesh.radius = 1.0
    belly_mesh.height = 1.3
    belly.mesh = belly_mesh
    belly.material_override = _toon(belly_color, 0.08, 0.82)
    belly.position = Vector3(0.1, 0.98, -0.78)
    belly.scale = Vector3(1.45, 0.68, 0.35)
    body.add_child(belly)

    for side in [-1.0, 1.0]:
        var wing := MeshInstance3D.new()
        var wing_mesh := PrismMesh.new()
        wing_mesh.size = Vector3(3.0, 2.5, 0.16)
        wing.mesh = wing_mesh
        wing.material_override = _toon(body_color.lightened(0.08), 0.08, 0.82)
        wing.position = Vector3(side * 1.05, 2.15, 0.65)
        wing.rotation = Vector3(deg_to_rad(18), deg_to_rad(side * 25), deg_to_rad(side * -18))
        body.add_child(wing)
        for foot_side in [-1.0, 1.0]:
            var leg := MeshInstance3D.new()
            var leg_mesh := CapsuleMesh.new()
            leg_mesh.radius = 0.38
            leg_mesh.height = 1.25
            leg.mesh = leg_mesh
            leg.material_override = _toon(body_color.darkened(0.06), 0.06, 0.84)
            leg.position = Vector3(side * 0.72 + foot_side * 0.32, 0.55, -0.38)
            body.add_child(leg)

    var neck := Node3D.new()
    neck.name = "Neck"
    neck.position = Vector3(1.55, 1.70, 0)
    neck.rotation.z = -0.32
    body.add_child(neck)
    var neck_mesh := MeshInstance3D.new()
    var neck_capsule := CapsuleMesh.new()
    neck_capsule.radius = 0.72
    neck_capsule.height = 2.0
    neck_mesh.mesh = neck_capsule
    neck_mesh.material_override = _toon(body_color, 0.08, 0.80)
    neck_mesh.position = Vector3(0.65, 0.15, 0)
    neck_mesh.rotation.z = PI * 0.5
    neck.add_child(neck_mesh)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.78
    head_mesh.height = 1.38
    head.mesh = head_mesh
    head.material_override = _toon(body_color.lightened(0.06), 0.10, 0.76)
    head.scale = Vector3(1.12, 0.88, 0.92)
    head.position = Vector3(1.62, 0.28, 0)
    neck.add_child(head)
    for side in [-1.0, 1.0]:
        var horn := MeshInstance3D.new()
        var horn_mesh := CylinderMesh.new()
        horn_mesh.top_radius = 0.0
        horn_mesh.bottom_radius = 0.10
        horn_mesh.height = 0.52
        horn.mesh = horn_mesh
        horn.material_override = _pbr(Color("#f2dda0"), 0.72)
        horn.position = Vector3(1.62, 0.83, side * 0.36)
        horn.rotation.z = -0.18
        neck.add_child(horn)
        var eye := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.10
        eye_mesh.height = 0.18
        eye.mesh = eye_mesh
        eye.material_override = _emissive(Color("#5c4727"), 0.5)
        eye.position = Vector3(2.15, 0.42, side * 0.30)
        neck.add_child(eye)
    var snout := MeshInstance3D.new()
    var snout_mesh := SphereMesh.new()
    snout_mesh.radius = 0.45
    snout_mesh.height = 0.72
    snout.mesh = snout_mesh
    snout.material_override = _toon(body_color.lightened(0.10), 0.08, 0.80)
    snout.position = Vector3(2.16, 0.10, 0)
    snout.scale = Vector3(0.85, 0.65, 0.88)
    neck.add_child(snout)

    if finale:
        for child_index in range(3):
            var child := _dragon_duplicate_small(body, child_index)
            dragon.add_child(child)

    _dragon_light = OmniLight3D.new()
    _dragon_light.light_color = Color("#ffe0a0")
    _dragon_light.light_energy = 1.2
    _dragon_light.omni_range = 10.0
    _dragon_light.position = Vector3(0, 2.2, 0)
    dragon.add_child(_dragon_light)
    return dragon

func _dragon_duplicate_small(source: Node3D, index: int) -> Node3D:
    # A few warm curled shapes suggest the surrounding family without cloning a
    # full expensive rig or obscuring the lullaby target.
    var child := Node3D.new()
    child.name = "SleepyCousin%d" % index
    child.position = Vector3(-2.0 - float(index) * 1.55, 0, 1.7 + float(index % 2) * 1.1)
    child.scale = Vector3.ONE * (0.44 - float(index) * 0.035)
    child.rotation.y = -0.7 + float(index) * 0.6
    for segment in range(4):
        var sphere := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.72
        mesh.height = 1.30
        sphere.mesh = mesh
        sphere.material_override = _toon(Color("#d3b56c").lerp(Color("#a7c96a"), float(index) * 0.12), 0.06, 0.82)
        sphere.position = Vector3(float(segment) * 1.25 - 1.6, 0.56, sin(float(segment)) * 0.18)
        sphere.scale = Vector3(1.0, 0.72, 0.86)
        child.add_child(sphere)
    return child

func build_dream_chimes(room: Dictionary) -> Array[Node3D]:
    for chime: Node3D in chimes:
        _free_child(chime)
    chimes.clear()
    var occupied := {}
    for chime_index in range(5):
        var cell := _spread_cell(room, occupied, 2.8, chime_index)
        occupied[cell] = true
        var chime := Node3D.new()
        chime.name = "DreamChime%d" % chime_index
        chime.position = DungeonGenerator.cell_to_world(cell, 0.78)
        chime.set_meta("chime_index", chime_index)
        chime.set_meta("base_y", 0.78)
        add_child(chime)
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.30
        torus.outer_radius = 0.42
        torus.rings = 32
        torus.ring_segments = 8
        ring.mesh = torus
        ring.material_override = _emissive(Color("#bfe8ff"), 2.3)
        chime.add_child(ring)
        var crystal := MeshInstance3D.new()
        var prism := PrismMesh.new()
        prism.size = Vector3(0.34, 0.72, 0.34)
        crystal.mesh = prism
        crystal.material_override = _emissive(Color("#d9f3ff"), 2.0)
        crystal.position = Vector3(0, -0.50, 0)
        chime.add_child(crystal)
        var clapper := MeshInstance3D.new()
        var clapper_mesh := SphereMesh.new()
        clapper_mesh.radius = 0.10
        clapper_mesh.height = 0.18
        clapper.mesh = clapper_mesh
        clapper.material_override = _emissive(Color("#ffe5a2"), 2.1)
        clapper.position = Vector3(0, -0.90, 0)
        chime.add_child(clapper)
        chimes.append(chime)
    return chimes

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value
    _set_particle_motion(self, value)

func _set_particle_motion(node: Node, still: bool) -> void:
    if node is GPUParticles3D:
        (node as GPUParticles3D).speed_scale = 0.18 if still else 1.0
    for child in node.get_children():
        _set_particle_motion(child, still)

func set_objectives_visible(stair_visible: bool, merchant_visible: bool, dragon_visible: bool) -> void:
    var stair := get_node_or_null("Stairwell")
    if stair:
        (stair as Node3D).visible = stair_visible
    if merchant_visual:
        merchant_visual.visible = merchant_visible
    if dragon_visual:
        dragon_visual.visible = dragon_visible

func reveal_stairwell() -> void:
    var stair := get_node_or_null("Stairwell")
    if stair:
        (stair as Node3D).visible = true

func _process(delta: float) -> void:
    for index in range(chimes.size() - 1, -1, -1):
        if not is_instance_valid(chimes[index]):
            chimes.remove_at(index)

    if _reduced_motion:
        return

    _time += delta
    for material: ShaderMaterial in _wind_materials:
        material.set_shader_parameter("wind_time", _time)
    if _water_material != null and is_instance_valid(_water_material):
        _water_material.set_shader_parameter("time_seconds", _time)
    for index in range(chimes.size()):
        var chime: Node3D = chimes[index]
        var base_y := float(chime.get_meta("base_y", 0.78))
        chime.position.y = base_y + sin(_time * 1.8 + float(index) * 0.9) * 0.13
        chime.rotation.y += delta * 0.65
    if _dragon_body:
        var breath := 1.0 + sin(_time * 0.9) * 0.028
        _dragon_body.scale = Vector3(breath, 1.0 + (breath - 1.0) * 0.45, breath)
    if _dragon_light:
        _dragon_light.light_energy = 1.2 + sin(_time * 0.9) * 0.10
    if _merchant_body:
        _merchant_body.position.y = sin(_time * 1.65) * 0.045
        _merchant_body.rotation.z = sin(_time * 0.82) * 0.018
