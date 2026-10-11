class_name CozyVFX
extends RefCounted

## Lightweight procedural GPU particles and impact rings. Every effect is
## warm, readable, and disposable; no effect is allowed to move the camera.

static func burst(parent: Node, world_position: Vector3, color: Color, amount: int = 24, power: float = 2.2, lifetime: float = 0.9) -> GPUParticles3D:
    if parent == null or not parent.is_inside_tree():
        return null
    var particles := GPUParticles3D.new()
    particles.amount = maxi(1, amount)
    particles.lifetime = maxf(0.15, lifetime)
    particles.one_shot = true
    particles.explosiveness = 0.94
    particles.randomness = 0.45
    particles.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))

    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    process.emission_sphere_radius = 0.16
    process.direction = Vector3.UP
    process.spread = 180.0
    process.initial_velocity_min = power * 0.45
    process.initial_velocity_max = power
    process.gravity = Vector3(0.0, -1.8, 0.0)
    process.damping_min = 1.2
    process.damping_max = 2.8
    process.scale_min = 0.65
    process.scale_max = 1.55
    # The color lives on the draw material's albedo, not here: without
    # vertex_color_use_as_albedo the particle path never reads this field.
    particles.process_material = process

    var mesh := SphereMesh.new()
    mesh.radius = 0.045
    mesh.height = 0.09
    mesh.radial_segments = 6
    mesh.rings = 3
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = Color(color.r, color.g, color.b)
    material.emission_energy_multiplier = 2.8
    mesh.material = material
    particles.draw_pass_1 = mesh

    parent.add_child(particles)
    particles.global_position = world_position
    particles.emitting = true
    _dispose_after_lifecycle(parent, particles)
    return particles

static func heart_burst(parent: Node, world_position: Vector3) -> void:
    burst(parent, world_position, Color("#ff9fb4"), 18, 1.8, 0.8)
    ring(parent, world_position + Vector3.UP * 0.12, Color("#ffd1df"), 1.5, 0.55)

static func soothe_celebration(parent: Node, world_position: Vector3, big: bool) -> void:
    ## The layered thank-you for a guided wisp: warm petals plus a soft ring.
    ## One call, still disposable, still never touches the camera.
    ## world_position is the wisp's ground position; heights match the old
    ## burst (0.8 x scale) and ring (0.15) placement.
    var lift := 2.8 if big else 0.8
    var color := Color("#ffe49a") if big else Color("#fff0a5")
    burst(parent, world_position + Vector3.UP * lift, color, 38 if big else 24, 2.7, 1.15)
    ring(parent, world_position + Vector3.UP * 0.15, color, 2.8 if big else 1.8, 0.72)
    burst(parent, world_position + Vector3.UP * (lift + 0.4), Color("#ffd1e8"), 10 if big else 6, 1.1, 0.8)

static func pulse_ring(parent: Node, world_position: Vector3, color: Color, final_radius: float = 2.4) -> void:
    ring(parent, world_position + Vector3.UP * 0.16, color, final_radius, 0.52)

static func ring(parent: Node, world_position: Vector3, color: Color, final_radius: float = 2.0, duration: float = 0.5) -> MeshInstance3D:
    if parent == null or not parent.is_inside_tree():
        return null
    var mesh := TorusMesh.new()
    mesh.inner_radius = maxf(0.12, final_radius - 0.10)
    mesh.outer_radius = final_radius
    mesh.rings = 40
    mesh.ring_segments = 8
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 2.2
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.material = material

    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.scale = Vector3(0.16, 0.16, 0.16)
    parent.add_child(visual)
    visual.global_position = world_position
    var tween := visual.create_tween()
    tween.set_parallel(true)
    tween.tween_property(visual, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(material, "albedo_color", Color(color.r, color.g, color.b, 0.0), duration)
    tween.chain().tween_callback(visual.queue_free)
    return visual

static func trail_tick(parent: Node, world_position: Vector3, color: Color) -> void:
    burst(parent, world_position, color, 3, 0.35, 0.36)

static func trail(world: Node, from: Vector3, to: Vector3, color: Color, motes: int = 7, reduced_motion: bool = false) -> void:
    ## A quick fading streak between two points -- the hero's dash, drawn as a
    ## handful of soft glints sweeping down the path and dissolving at the far
    ## end. With reduced_motion it degrades to one soft pulse at the arrival
    ## point: no travel, no scatter.
    if world == null or not world.is_inside_tree():
        return
    if reduced_motion:
        _soft_pulse(world, to, color)
        return
    var count := clampi(motes, 2, 16)
    var travel := 0.26
    for index in range(count):
        var t := float(index) / float(count - 1)
        # The formation starts spread along most of the path and sweeps into
        # the arrival point; the tail is smaller and lags a touch, so the
        # streak tapers like a comet rather than a marching column.
        var head := from.lerp(to, t * 0.7)
        var mote := _soft_mote(world, head, Color(color.r, color.g, color.b, 0.85), 0.10 + 0.05 * t)
        var material := (mote.mesh as QuadMesh).material as StandardMaterial3D
        var delay := t * 0.06
        var tween := mote.create_tween()
        tween.set_parallel(true)
        tween.tween_property(mote, "global_position", to, travel).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.tween_property(material, "albedo_color", Color(color.r, color.g, color.b, 0.0), travel).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        tween.chain().tween_callback(mote.queue_free)

static func sparkle_crown(world: Node, at: Vector3, color: Color, sparks: int = 9, reduced_motion: bool = false) -> void:
    ## A small crown of sparkles that springs up around a point, hangs for a
    ## breath, and fades -- the level-up draft's quiet fanfare. With
    ## reduced_motion it degrades to a single soft pulse.
    if world == null or not world.is_inside_tree():
        return
    if reduced_motion:
        _soft_pulse(world, at + Vector3.UP * 0.35, color)
        return
    var particles := GPUParticles3D.new()
    particles.amount = clampi(sparks, 3, 24)
    particles.lifetime = 0.85
    particles.one_shot = true
    particles.explosiveness = 0.92
    particles.randomness = 0.35
    particles.visibility_aabb = AABB(Vector3(-1.6, -0.4, -1.6), Vector3(3.2, 3.0, 3.2))

    var process := ParticleProcessMaterial.new()
    # Sparks are born on a small ring around the point and rise from it, so
    # the fanfare reads as a crown rather than a fountain from one spot.
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
    process.emission_ring_axis = Vector3.UP
    process.emission_ring_radius = 0.42
    process.emission_ring_inner_radius = 0.26
    process.emission_ring_height = 0.05
    process.direction = Vector3.UP
    process.spread = 14.0
    process.initial_velocity_min = 1.0
    process.initial_velocity_max = 1.6
    process.gravity = Vector3(0.0, -1.5, 0.0)
    process.damping_min = 0.8
    process.damping_max = 1.6
    process.scale_min = 0.55
    process.scale_max = 1.05
    # A swell-then-shrink scale curve: no spark ever pops into or out of
    # existence at full size.
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 0.25))
    curve.add_point(Vector2(0.30, 1.0))
    curve.add_point(Vector2(1.0, 0.0))
    var curve_texture := CurveTexture.new()
    curve_texture.curve = curve
    process.scale_curve = curve_texture
    # No process.color: the draw material below is unshaded with a fixed
    # albedo, so a process-material color would never reach the screen (the
    # same rule every emitter in this file follows).
    particles.process_material = process

    particles.draw_pass_1 = _soft_mote_mesh(0.09, color, 2.4)
    world.add_child(particles)
    particles.global_position = at + Vector3.UP * 0.55
    particles.emitting = true
    _dispose_after_lifecycle(world, particles)

static func spawn_ambient_motes(parent: Node, region: Dictionary, amount: int = 100) -> GPUParticles3D:
    var particles := GPUParticles3D.new()
    particles.amount = amount
    particles.lifetime = 8.0
    particles.preprocess = 5.0
    particles.randomness = 0.8
    particles.visibility_aabb = AABB(Vector3(-45, 0, -45), Vector3(90, 14, 90))

    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(42, 2.5, 42)
    process.direction = Vector3(0.35, 1.0, 0.1)
    process.spread = 28.0
    process.initial_velocity_min = 0.15
    process.initial_velocity_max = 0.55
    process.gravity = Vector3(0.03, 0.08, 0.01)
    process.scale_min = 0.25
    process.scale_max = 0.80
    # The accent color lives on the draw material below; a process material's
    # color is only read when the draw material opts into vertex colors, and
    # this one does not (it is unshaded with a fixed albedo).
    particles.process_material = process

    var quad := QuadMesh.new()
    quad.size = Vector2(0.075, 0.075)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.albedo_texture = _soft_mote_texture()
    material.albedo_color = Color(region["accent"])
    material.emission_enabled = true
    material.emission = Color(region["accent"])
    material.emission_energy_multiplier = 2.4
    quad.material = material
    particles.draw_pass_1 = quad
    parent.add_child(particles)
    particles.position = Vector3.ZERO
    return particles

static func _dispose_after_lifecycle(parent: Node, emitter: GPUParticles3D) -> void:
    ## Frees a one-shot emitter when its show is over. Some Forward+
    ## driver/Godot combinations do not deliver the one-shot `finished` signal
    ## even after emitting flips false. Keep a bounded fallback so invisible
    ## emitter nodes and their GPU resources cannot accumulate. Capture the
    ## instance id, not the emitter node: the floor teardown may free the
    ## world (and the emitter with it) before this timer fires, and a freed
    ## Object capture makes the engine log "Lambda capture at index 0 was
    ## freed" *before* any is_instance_valid guard in the body can run.
    emitter.finished.connect(emitter.queue_free, CONNECT_ONE_SHOT)
    var cleanup_delay := emitter.lifetime * (1.0 + emitter.explosiveness) + 0.1
    var emitter_id := emitter.get_instance_id()
    parent.get_tree().create_timer(cleanup_delay).timeout.connect(
        func() -> void:
            var emitter_node := instance_from_id(emitter_id)
            if emitter_node != null and is_instance_valid(emitter_node):
                emitter_node.queue_free(),
        CONNECT_ONE_SHOT
    )

static func _soft_mote_mesh(size: float, color: Color, energy: float = 2.2) -> QuadMesh:
    ## One billboarded soft-edged glint quad: the shared atom of the trail,
    ## crown, and pulse effects. Never a raw square -- the radial gradient
    ## fades it to nothing at the edges.
    var quad := QuadMesh.new()
    quad.size = Vector2(size, size)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.albedo_texture = _soft_mote_texture()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = Color(color.r, color.g, color.b)
    material.emission_energy_multiplier = energy
    quad.material = material
    return quad

static func _soft_mote(parent: Node, at: Vector3, color: Color, size: float) -> MeshInstance3D:
    ## Places one glint in the world; the caller owns the tween that moves,
    ## fades, and frees it.
    var mote := MeshInstance3D.new()
    mote.mesh = _soft_mote_mesh(size, color)
    parent.add_child(mote)
    mote.global_position = at
    return mote

static func _soft_pulse(parent: Node, at: Vector3, color: Color) -> void:
    ## The reduced-motion stand-in for the bigger one-shots: a single glint
    ## that swells once and dissolves in place. No travel, no scatter.
    var mote := _soft_mote(parent, at, color, 0.16)
    var material := (mote.mesh as QuadMesh).material as StandardMaterial3D
    var tween := mote.create_tween()
    tween.set_parallel(true)
    tween.tween_property(mote, "scale", Vector3.ONE * 1.6, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(material, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.chain().tween_callback(mote.queue_free)

static func _soft_mote_texture() -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
    gradient.colors = PackedColorArray([
        Color(1.0, 1.0, 1.0, 0.95),
        Color(1.0, 1.0, 1.0, 0.48),
        Color(1.0, 1.0, 1.0, 0.0),
    ])
    var texture := GradientTexture2D.new()
    texture.width = 32
    texture.height = 32
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    texture.gradient = gradient
    return texture
