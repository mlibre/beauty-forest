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
    # Snoozle is the warmest thing in the game and the reason the whole
    # descent exists, so the body carries four readable tones instead of one:
    # a pale belly, the base coat, a dark saddle, and cream spines. The camera
    # looks down from above at one big rounded body under a bright golden-hour
    # sun, so a single light coat renders as a featureless beige lump and the
    # base colours are deliberately deeper than they look on paper.
    #
    # The wings are FOLDED against the back, not spread. A spread wing is a big
    # flat prism: from the fixed isometric camera it shows its 0.16m edge as a
    # paper triangle, and a dragon that is meant to be asleep reads as
    # mid-flight instead.
    var body_color := Color("#8ab24e") if not finale else Color("#c2a03c")
    var belly_color := Color("#f4e2a4")
    var saddle_color := Color("#5d8436") if not finale else Color("#8d6f26")
    var wing_color := saddle_color.lightened(0.10)
    var spine := Color("#f6e6b4")
    var body_mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 1.22
    capsule.height = 4.7
    body_mesh.mesh = capsule
    body_mesh.material_override = _toon(body_color, 0.02, 0.80)
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
    belly.material_override = _toon(belly_color, 0.03, 0.84)
    belly.position = Vector3(0.1, 0.98, -0.78)
    belly.scale = Vector3(1.45, 0.68, 0.35)
    body.add_child(belly)
    # The saddle rides ON TOP of the barrel (capsule top = 1.45 + 1.22 = 2.67),
    # clear of it. Placed at 2.10 it was swallowed whole by the body and the
    # two-tone silhouette never appeared.
    var saddle := MeshInstance3D.new()
    var saddle_mesh := SphereMesh.new()
    saddle_mesh.radius = 1.0
    saddle_mesh.height = 1.0
    saddle.mesh = saddle_mesh
    saddle.material_override = _toon(saddle_color, 0.02, 0.86)
    saddle.position = Vector3(-0.10, 2.46, 0.02)
    saddle.scale = Vector3(1.34, 0.30, 0.70)
    body.add_child(saddle)

    # A crest of pale spines along the saddle. Big enough to survive the
    # isometric distance, which the first 0.17-radius cones did not.
    for spine_index in range(5):
        for row in [-1.0, 1.0]:
            var spike := MeshInstance3D.new()
            var spike_mesh := CylinderMesh.new()
            spike_mesh.top_radius = 0.0
            spike_mesh.bottom_radius = 0.23
            spike_mesh.height = 0.70
            spike_mesh.radial_segments = 6
            spike.mesh = spike_mesh
            spike.material_override = _pbr(spine, 0.74)
            spike.position = Vector3(1.00 - float(spine_index) * 0.60, 2.66 - float(spine_index) * 0.10, 0.16 * row)
            spike.rotation = Vector3(deg_to_rad(-18.0 * row), 0.0, deg_to_rad(12.0 + float(spine_index) * 4.0))
            body.add_child(spike)

    # A tapering tail that overlaps into one continuous curve. The steps are
    # shorter than each segment (0.62 apart, 2.5+ long) on purpose: spaced
    # further, the segments read as a row of loose beads trailing off the back
    # rather than as one tail.
    var tail_steps := 4
    var tail_step := Vector3(-0.62, -0.16, 0.26)
    var tail_root := Vector3(-1.70, 1.18, 0.22)
    for segment in range(tail_steps):
        var tail := MeshInstance3D.new()
        var tail_mesh := CapsuleMesh.new()
        tail_mesh.radius = 0.70 - float(segment) * 0.145
        tail_mesh.height = 1.20
        tail.mesh = tail_mesh
        tail.material_override = _toon(body_color if segment < 2 else saddle_color, 0.02, 0.82)
        tail.position = tail_root + tail_step * float(segment)
        # Alternate the yaw so the tail curls instead of running straight, and
        # keep the roll shallow so the segments stay stacked on one another.
        var tail_sway := -1.0 if segment % 2 == 0 else 1.0
        tail.rotation = Vector3(0.0, deg_to_rad(13.0 * float(segment) * tail_sway), deg_to_rad(5.0 + float(segment) * 6.0))
        body.add_child(tail)
    # Anchor the spade fin to where the last segment actually ends, so the two
    # cannot drift apart if the chain is retuned.
    var tail_fin := MeshInstance3D.new()
    var fin_mesh := PrismMesh.new()
    fin_mesh.size = Vector3(0.85, 0.95, 0.14)
    tail_fin.mesh = fin_mesh
    tail_fin.material_override = _pbr(spine, 0.74)
    tail_fin.position = tail_root + tail_step * float(tail_steps) + Vector3(-0.10, -0.22, 0.06)
    tail_fin.rotation = Vector3(deg_to_rad(14.0), deg_to_rad(-18.0), deg_to_rad(52.0))
    body.add_child(tail_fin)

    for side in [-1.0, 1.0]:
        # Folded wing: a long tapered membrane lying along the saddle, lifted
        # a little at the shoulder, with three finger struts fanning back.
        var wing_root := Node3D.new()
        wing_root.name = "WingRoot%s" % ("R" if side > 0.0 else "L")
        wing_root.position = Vector3(side * 0.42, 2.34, 0.62 * side)
        wing_root.rotation = Vector3(deg_to_rad(side * 8.0), deg_to_rad(side * 6.0), deg_to_rad(12.0))
        body.add_child(wing_root)
        # A SphereMesh's long axis is local Y, so it must be laid on its side
        # (rotation.z = 90 deg) to run along the body. Left upright it stood
        # vertically at the shoulder and read as a pair of dark ears.
        var wing := MeshInstance3D.new()
        var wing_mesh := SphereMesh.new()
        wing_mesh.radius = 0.90
        wing_mesh.height = 2.4
        wing.mesh = wing_mesh
        wing.material_override = _toon(wing_color, 0.02, 0.84)
        # Local X becomes world Y, local Y becomes world X: 0.68 tall, 2.4 long,
        # 0.43 wide, lying along the saddle.
        wing.scale = Vector3(0.38, 1.0, 0.24)
        wing.position = Vector3(-1.30, 0.16, side * 0.10)
        wing.rotation.z = PI * 0.5 + deg_to_rad(side * -5.0)
        wing_root.add_child(wing)
        for finger in range(3):
            var strut := MeshInstance3D.new()
            var strut_mesh := CapsuleMesh.new()
            strut_mesh.radius = 0.10 - float(finger) * 0.018
            strut_mesh.height = 2.7 - float(finger) * 0.40
            strut.mesh = strut_mesh
            strut.material_override = _pbr(saddle_color.darkened(0.10), 0.82)
            strut.position = Vector3(-1.35 + float(finger) * 0.34, 0.10 - float(finger) * 0.06, side * (0.06 + float(finger) * 0.12))
            strut.rotation.z = PI * 0.5 + deg_to_rad(-3.0 + float(finger) * 5.0)
            wing_root.add_child(strut)
        for foot_side in [-1.0, 1.0]:
            var leg := MeshInstance3D.new()
            var leg_mesh := CapsuleMesh.new()
            leg_mesh.radius = 0.38
            leg_mesh.height = 1.25
            leg.mesh = leg_mesh
            leg.material_override = _toon(body_color.darkened(0.10), 0.02, 0.86)
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
    neck_mesh.material_override = _toon(body_color, 0.02, 0.82)
    neck_mesh.position = Vector3(0.65, 0.15, 0)
    neck_mesh.rotation.z = PI * 0.5
    neck.add_child(neck_mesh)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.86
    head_mesh.height = 1.50
    head.mesh = head_mesh
    head.material_override = _toon(body_color.lightened(0.08), 0.03, 0.78)
    head.scale = Vector3(1.12, 0.88, 0.92)
    head.position = Vector3(1.62, 0.28, 0)
    neck.add_child(head)
    # A pale brow plate between the horns keeps the face from reading as one
    # unbroken dome from directly above.
    var brow := MeshInstance3D.new()
    var brow_mesh := SphereMesh.new()
    brow_mesh.radius = 0.62
    brow_mesh.height = 0.70
    brow.mesh = brow_mesh
    brow.material_override = _toon(belly_color, 0.03, 0.80)
    brow.scale = Vector3(0.42, 0.30, 1.02)
    brow.position = Vector3(1.78, 0.66, 0.0)
    neck.add_child(brow)
    for side in [-1.0, 1.0]:
        var horn := MeshInstance3D.new()
        var horn_mesh := CylinderMesh.new()
        horn_mesh.top_radius = 0.0
        horn_mesh.bottom_radius = 0.12
        horn_mesh.height = 0.62
        horn_mesh.radial_segments = 8
        horn.mesh = horn_mesh
        horn.material_override = _pbr(Color("#f2dda0"), 0.72)
        horn.position = Vector3(1.60, 0.92, side * 0.40)
        horn.rotation = Vector3(deg_to_rad(side * 14.0), 0.0, -0.18)
        neck.add_child(horn)
        # Sleeping eyes: a wide, flat, downward-curved lid per side. The two
        # old 0.10-radius beads were too small and too round to survive the
        # isometric camera's distance, so the friendliest thing about the
        # friendliest creature in the game simply was not visible.
        var lid := MeshInstance3D.new()
        var lid_mesh := SphereMesh.new()
        lid_mesh.radius = 0.30
        lid_mesh.height = 0.22
        lid.mesh = lid_mesh
        lid.material_override = _pbr(Color("#4a3728"), 0.62)
        lid.scale = Vector3(0.42, 0.30, 1.05)
        lid.position = Vector3(2.24, 0.50, side * 0.31)
        lid.rotation = Vector3(deg_to_rad(side * -12.0), 0.0, deg_to_rad(8.0))
        neck.add_child(lid)
        var lash := MeshInstance3D.new()
        var lash_mesh := SphereMesh.new()
        lash_mesh.radius = 0.20
        lash_mesh.height = 0.10
        lash.mesh = lash_mesh
        lash.material_override = _pbr(Color("#4a3728"), 0.62)
        lash.scale = Vector3(0.30, 0.16, 1.05)
        lash.position = Vector3(2.28, 0.34, side * 0.31)
        lash.rotation = Vector3(0.0, 0.0, deg_to_rad(20.0))
        neck.add_child(lash)
        var cheek := MeshInstance3D.new()
        var cheek_mesh := SphereMesh.new()
        cheek_mesh.radius = 0.20
        cheek_mesh.height = 0.12
        cheek.mesh = cheek_mesh
        cheek.material_override = _toon(Color("#d98d78"), 0.02, 0.90)
        cheek.scale = Vector3(0.26, 0.16, 0.80)
        cheek.position = Vector3(2.06, 0.24, side * 0.44)
        neck.add_child(cheek)
    var snout := MeshInstance3D.new()
    var snout_mesh := SphereMesh.new()
    snout_mesh.radius = 0.50
    snout_mesh.height = 0.80
    snout.mesh = snout_mesh
    snout.material_override = _toon(body_color.lightened(0.12), 0.03, 0.82)
    snout.position = Vector3(2.24, 0.06, 0)
    snout.scale = Vector3(0.85, 0.62, 0.92)
    neck.add_child(snout)
    # A drowsy little smile: three beads along the snout, the same trick the
    # hero rig uses, so the two faces of the game rhyme with each other.
    var smile_points := [Vector3(2.56, -0.06, -0.16), Vector3(2.60, -0.11, 0.0), Vector3(2.56, -0.06, 0.16)]
    for point: Vector3 in smile_points:
        var smile := MeshInstance3D.new()
        smile.mesh = SphereMesh.new()
        smile.mesh.radius = 0.032
        smile.mesh.height = 0.05
        smile.material_override = _pbr(Color("#6a4a33"), 0.60)
        smile.position = point
        neck.add_child(smile)
    for side in [-1.0, 1.0]:
        var nostril := MeshInstance3D.new()
        nostril.mesh = SphereMesh.new()
        nostril.mesh.radius = 0.045
        nostril.mesh.height = 0.035
        nostril.material_override = _pbr(Color("#8a6a44"), 0.60)
        nostril.position = Vector3(2.60, 0.10, side * 0.13)
        neck.add_child(nostril)

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
        # The sleeping cousins share Snoozle's new deeper palette so the finale family reads as one animal.
        sphere.material_override = _toon(Color("#c9a355").lerp(Color("#8ab24e"), float(index) * 0.14), 0.02, 0.84)
        sphere.position = Vector3(float(segment) * 1.25 - 1.6, 0.56, sin(float(segment)) * 0.18)
        sphere.scale = Vector3(1.0, 0.72, 0.86)
        child.add_child(sphere)
    return child

func build_dream_chimes(room: Dictionary) -> Array[Node3D]:
    for chime: Node3D in chimes:
        _free_child(chime)
    chimes.clear()
    var occupied := {}
    # Seed the spread with the cells the landmark props already own, so a chime
    # cannot settle on top of the stairwell's glow disc or Peddle's canopy.
    for landmark: Vector3 in [stair_position, merchant_position, dragon_position]:
        if landmark == Vector3.ZERO:
            continue
        occupied[Vector2i(int(landmark.x), int(landmark.z))] = true
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
