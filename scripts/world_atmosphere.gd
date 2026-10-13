class_name WorldAtmosphere
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyVFX := preload("res://scripts/cozy_vfx.gd")

## The air of the forest: the sunbeams that lean through the canopy and the
## drifting motes and leaves that keep a floor alive. Split out of
## WorldScenery when that file outgrew the 500-line ceiling -- static
## builders that read the world's region, depth and rng and hang their
## results on the world node itself.

static func build_sunbeams(world: Node3D) -> void:
    # Soft god rays through the canopy, not translucent slabs.
    #
    # The first version dropped 6-8 unshaded additive cylinders (2.3m base
    # radius, 14m tall, CULL_DISABLED so both walls drew) straight into the
    # play area. The fixed isometric camera looks down through them, so the
    # whole floor washed out into flat yellow haze, the grove behind them
    # disappeared, and every region read as the same overexposed smear.
    #
    # These are slimmer, softer-edged, dimmer, and lifted so the bright part
    # sits above the canopy instead of across the hero.
    if world.dungeon["rooms"].is_empty():
        return
    var count := 4 + (1 if world.floor_number >= 5 else 0)
    for beam_index in range(count):
        var room: Dictionary = world.dungeon["rooms"][beam_index % world.dungeon["rooms"].size()]
        var base_radius: float = world._rng.randf_range(0.62, 1.05)
        var height: float = world._rng.randf_range(9.5, 12.5)
        var beam := MeshInstance3D.new()
        beam.name = "Sunbeam%d" % beam_index
        var mesh := CylinderMesh.new()
        mesh.top_radius = base_radius * 0.30
        mesh.bottom_radius = base_radius
        mesh.height = height
        mesh.radial_segments = 14
        mesh.cap_top = false
        mesh.cap_bottom = false
        beam.mesh = mesh
        var material := ShaderMaterial.new()
        material.shader = load("res://shaders/sunbeam.gdshader")
        material.set_shader_parameter("beam_color", Color(world.region["accent"]))
        material.set_shader_parameter("intensity", world._rng.randf_range(0.13, 0.20))
        material.set_shader_parameter("base_radius", base_radius)
        material.set_shader_parameter("tip_radius", base_radius * 0.30)
        material.set_shader_parameter("beam_height", height)
        material.set_shader_parameter("drift", world._rng.randf_range(0.0, TAU))
        beam.material_override = material
        # Anchored to the room but pushed out to the grove side so the shaft
        # frames the clearing instead of veiling the hero standing in it.
        var lean: Vector2 = Vector2(world._rng.randf_range(-1.0, 1.0), world._rng.randf_range(-1.0, 1.0)).normalized() * world._rng.randf_range(4.0, 7.0)
        beam.position = Vector3(float(room["cx"]) + lean.x, height * 0.5, float(room["cy"]) + lean.y)
        beam.rotation_degrees = Vector3(world._rng.randf_range(-7, 7), world._rng.randf_range(0, 360), world._rng.randf_range(-7, 7))
        world.add_child(beam)

static func build_ambient_life(world: Node3D) -> void:
    var map_center := Vector3(float(world.dungeon["width"]) * 0.5, 0.0, float(world.dungeon["height"]) * 0.5)
    var ambient_motes := CozyVFX.spawn_ambient_motes(world, world.region, 125 if world.floor_number < 9 else 150)
    ambient_motes.position = map_center
    var leaves := GPUParticles3D.new()
    leaves.amount = 65
    leaves.lifetime = 10.0
    leaves.preprocess = 6.0
    leaves.visibility_aabb = AABB(Vector3(-45, 0, -45), Vector3(90, 15, 90))
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(42, 5, 42)
    process.direction = Vector3(0.4, -1, 0.1)
    process.spread = 22
    process.initial_velocity_min = 0.35
    process.initial_velocity_max = 0.75
    process.gravity = Vector3(0.08, -0.12, 0.02)
    process.angular_velocity_min = -80
    process.angular_velocity_max = 80
    process.scale_min = 0.45
    process.scale_max = 1.0
    # No process.color: the draw material below is unshaded with a fixed
    # albedo, so the vertex color a process material emits is never read. The
    # 0.72 alpha lives in that albedo on purpose -- routing the color through
    # the particle path instead would need vertex_color_use_as_albedo and
    # would multiply the alpha back to opaque.
    leaves.process_material = process
    var leaf_mesh := QuadMesh.new()
    leaf_mesh.size = Vector2(0.11, 0.055)
    var leaf_material := StandardMaterial3D.new()
    leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    leaf_material.albedo_color = Color(world.region["tip"], 0.72)
    leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    leaf_mesh.material = leaf_material
    leaves.draw_pass_1 = leaf_mesh
    leaves.position = map_center
    world.add_child(leaves)
