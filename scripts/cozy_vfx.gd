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
    process.color = color
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
    particles.finished.connect(particles.queue_free, CONNECT_ONE_SHOT)
    # Some Forward+ driver/Godot combinations do not deliver the one-shot
    # `finished` signal even after emitting flips false. Keep a bounded fallback
    # so invisible emitter nodes and their GPU resources cannot accumulate.
    # Capture the instance id, not the emitter node: the floor teardown may
    # free the world (and the emitter with it) before this timer fires, and a
    # freed Object capture makes the engine log "Lambda capture at index 0
    # was freed" *before* any is_instance_valid guard in the body can run.
    var cleanup_delay := particles.lifetime * (1.0 + particles.explosiveness) + 0.1
    var emitter_id := particles.get_instance_id()
    parent.get_tree().create_timer(cleanup_delay).timeout.connect(
        func() -> void:
            var emitter := instance_from_id(emitter_id)
            if emitter != null and is_instance_valid(emitter):
                emitter.queue_free(),
        CONNECT_ONE_SHOT
    )
    return particles

static func heart_burst(parent: Node, world_position: Vector3) -> void:
    burst(parent, world_position, Color("#ff9fb4"), 18, 1.8, 0.8)
    ring(parent, world_position + Vector3.UP * 0.12, Color("#ffd1df"), 1.5, 0.55)

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
    process.color = Color(region["accent"])
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
