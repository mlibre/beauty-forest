class_name WorldScenery
extends Node3D

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyMaterials := preload("res://scripts/cozy_materials.gd")
const CozyVFX := preload("res://scripts/cozy_vfx.gd")
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")
const GroundDetails := preload("res://scripts/ground_details.gd")

## Scenery half of a forest floor: sky and lights, ground collision, instanced
## grove and decor, sunbeams and ambient life, plus the material factories and
## map-cell helpers those builders share. Landmarks and per-floor runtime live
## in WorldLandmarks / ForestWorld, which extend this.

var dungeon: Dictionary = {}
var region: Dictionary = {}
var floor_number := 1
var stair_position := Vector3.ZERO
var merchant_position := Vector3.ZERO
var dragon_position := Vector3.ZERO
var pool_position := Vector3.ZERO
var dragon_visual: Node3D
var merchant_visual: Node3D
var chimes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _wind_materials: Array[ShaderMaterial] = []
var _water_material: ShaderMaterial
var _dragon_body: Node3D
var _dragon_light: OmniLight3D
var _merchant_body: Node3D
var _time := 0.0
var _reduced_motion := false

func _build_environment() -> void:
    var world_environment := WorldEnvironment.new()
    world_environment.name = "GoldenDuskEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(region["sky"])
    sky_material.sky_horizon_color = Color(region["horizon"])
    sky_material.ground_horizon_color = Color(region["fog"])
    sky_material.ground_bottom_color = Color(region["ground"]).darkened(0.18)
    sky_material.sun_angle_max = 24.0
    sky_material.sun_curve = 0.12
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_color = Color("#fff1c9")
    environment.ambient_light_energy = 0.48
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.tonemap_exposure = 0.80
    environment.tonemap_white = 1.75
    environment.fog_enabled = true
    environment.fog_mode = Environment.FOG_MODE_DEPTH
    environment.fog_light_color = Color(region["fog"])
    environment.fog_light_energy = 0.75
    environment.fog_density = 0.010
    environment.fog_depth_begin = 20.0
    environment.fog_depth_end = 86.0
    environment.fog_sky_affect = 0.35
    environment.glow_enabled = true
    environment.glow_intensity = 0.58
    environment.glow_strength = 0.95
    environment.glow_bloom = 0.12
    environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
    environment.glow_hdr_threshold = 0.92
    environment.ssao_enabled = true
    environment.ssao_radius = 1.5
    environment.ssao_intensity = 1.25
    environment.ssil_enabled = true
    environment.ssil_intensity = 0.75
    environment.ssil_normal_rejection = 0.6
    _calibrate_for_renderer(environment, RenderingServer.get_current_rendering_method())
    world_environment.environment = environment
    add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.name = "GoldenHourSun"
    sun.light_color = Color(region["sun"])
    sun.light_energy = 1.25
    sun.light_specular = 0.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 72.0
    sun.directional_shadow_split_1 = 0.16
    sun.directional_shadow_split_2 = 0.48
    sun.directional_shadow_split_3 = 0.82
    sun.directional_shadow_blend_splits = true
    sun.shadow_bias = 0.035
    sun.shadow_normal_bias = 1.2
    sun.rotation_degrees = Vector3(-52, -34, 0)
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.name = "SkyFill"
    fill.light_color = Color("#d9edff")
    fill.light_energy = 0.28
    fill.shadow_enabled = false
    fill.rotation_degrees = Vector3(-28, 142, 0)
    add_child(fill)

## One environment, two renderers. Forward+ (desktop) runs SSAO 1.25 and SSIL
## 0.75, which darken every crease and bounce soft light between leaves; the
## web build runs gl_compatibility, which silently drops both and lands glow
## softer — so the identical numbers rendered the web walk measurably brighter
## and harsher than the desktop one. The correction below is a pure function of
## the renderer name so tests/regression_world can hold it exactly on a machine
## that cannot render either target. Adjustments are the last dial because the
## compatibility renderer ignores them on some driver stacks: the ambient and
## glow corrections carry the fix on their own.
##
## The GROUND needs its own correction, separate from the sky's: the moss plane
## is the single largest bright surface on screen and it reads its color
## straight from a shader with no lighting tricks to hide behind, so an
## environment-only fix left the floor itself still washed out on web. The
## ground dial lives in _calibrate_ground_for_renderer, called from
## _build_ground_and_collisions with the same renderer name.
static func _calibrate_for_renderer(environment: Environment, rendering_method: String) -> void:
    if rendering_method != "gl_compatibility":
        return
    environment.ambient_light_energy = 0.32
    environment.tonemap_exposure = 0.73
    environment.glow_intensity = 0.62
    environment.glow_bloom = 0.16
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 0.92
    environment.adjustment_contrast = 0.96
    environment.adjustment_saturation = 1.08

## The moss floor's own web correction. The shader colors are baked bright for
## Forward+'s creased, indirect-lit render; compatibility renders them flat and
## full-strength, which is why the web walk's ground still glowed after the
## environment was calibrated. Pure function of the renderer name, so the
## regression suite can hold every darkening exactly.
static func _calibrate_ground_for_renderer(material: ShaderMaterial, rendering_method: String) -> void:
    if rendering_method != "gl_compatibility":
        return
    var base := material.get_shader_parameter("base_color") as Color
    material.set_shader_parameter("base_color", base.darkened(0.16))
    # The light patches are what read as "the floor is glowing": keep the moss
    # varied but pull the bright end visibly down and shrink how much of the
    # floor lights up.
    var light := material.get_shader_parameter("light_patch") as Color
    material.set_shader_parameter("light_patch", light.darkened(0.22))
    material.set_shader_parameter("pool_strength", 0.55)
    var deep := material.get_shader_parameter("deep_patch") as Color
    material.set_shader_parameter("deep_patch", Color(deep.r * 0.86, deep.g * 0.86, deep.b * 0.86))

func _build_ground_and_collisions() -> void:
    var width := int(dungeon["width"])
    var depth := int(dungeon["height"])
    var static_body := StaticBody3D.new()
    static_body.name = "ForestPhysics"
    static_body.collision_layer = 1
    static_body.collision_mask = 0
    add_child(static_body)

    var ground_shape := CollisionShape3D.new()
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(float(width), 0.50, float(depth))
    ground_shape.shape = ground_box
    ground_shape.position = Vector3(float(width) * 0.5, -0.25, float(depth) * 0.5)
    static_body.add_child(ground_shape)

    # Greedy horizontal collision runs keep the Jolt world light even when the
    # forest contains hundreds of grove cells.
    for z in depth:
        var run_start := -1
        for x in range(width + 1):
            var is_wall := x < width and not DungeonGenerator.is_floor(dungeon, x, z)
            if is_wall and run_start < 0:
                run_start = x
            elif not is_wall and run_start >= 0:
                _add_wall_run(static_body, run_start, x - run_start, z)
                run_start = -1

    # One shaded ground plane avoids a distracting tile grid while the Jolt body
    # above still provides exact, native collision for every grove cell.
    var ground_visual := MeshInstance3D.new()
    ground_visual.name = "MossFloor"
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(float(width), float(depth))
    ground_visual.mesh = ground_mesh
    var ground_material := ShaderMaterial.new()
    ground_material.shader = load("res://shaders/forest_ground.gdshader")
    var ground_base := Color(region["ground"]).darkened(0.13)
    ground_material.set_shader_parameter("base_color", ground_base)
    ground_material.set_shader_parameter("light_patch", ground_base.lerp(Color("#d6cf82"), 0.27))
    ground_material.set_shader_parameter("deep_patch", ground_base.lerp(Color("#3f6b33"), 0.34))
    # The floor's own warm details: bare earth where the turf thins, fallen
    # leaves gathered along its edges, clover in the turf. Region-tinted so a
    # terrace's floor is not a meadow's floor.
    ground_material.set_shader_parameter("dirt_color", ground_base.lerp(Color("#8a6f42"), 0.55))
    ground_material.set_shader_parameter("litter_color", Color("#c98a4e").lerp(Color(region["flower"]), 0.22))
    ground_material.set_shader_parameter("clover_strength", 0.55)
    # The web renderer paints this plane flat and bright (no SSAO/SSIL to crease
    # it), so the same calibration that fixes the sky also reins the moss in.
    _calibrate_ground_for_renderer(ground_material, RenderingServer.get_current_rendering_method())
    ground_visual.material_override = ground_material
    ground_visual.position = Vector3(float(width) * 0.5, 0.0, float(depth) * 0.5)
    ground_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ground_visual)

func _add_wall_run(body: StaticBody3D, start_x: int, run_length: int, z: int) -> void:
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(float(run_length), 1.70, 1.0)
    shape.shape = box
    shape.position = Vector3(float(start_x) + float(run_length) * 0.5, 0.85, float(z) + 0.5)
    body.add_child(shape)

func _build_grove_visual() -> void:
    var width := int(dungeon["width"])
    var depth := int(dungeon["height"])
    var trunk_transforms: Array[Transform3D] = []
    var trunk_colors: Array[Color] = []
    var flare_transforms: Array[Transform3D] = []
    var crown_transforms: Array[Transform3D] = []
    var crown_colors: Array[Color] = []
    var grid: PackedInt32Array = dungeon["grid"]
    for z in depth:
        for x in width:
            if grid[z * width + x] == DungeonGenerator.FLOOR:
                continue
            if _point_inside_room(x, z, 1):
                continue
            var base := Vector3(float(x) + 0.5 + _rng.randf_range(-0.12, 0.12), 0, float(z) + 0.5 + _rng.randf_range(-0.12, 0.12))
            # One grove cell in twelve is an elder: taller, wider, with a
            # second crown blob. A wall of same-sized trees reads as a fence;
            # a few elders break the roofline the way an old forest does.
            var elder := _rng.randf() < 0.085
            var trunk_height := _rng.randf_range(1.35, 2.25) * (1.55 if elder else 1.0)
            var trunk_girth := _rng.randf_range(0.78, 1.18) * (1.35 if elder else 1.0)
            var trunk_basis := Basis.IDENTITY.scaled(Vector3(trunk_girth, trunk_height, trunk_girth))
            trunk_transforms.append(Transform3D(trunk_basis, base + Vector3(0, trunk_height * 0.5, 0)))
            # Bark lightens with age: elders wear the palest wood of the stand.
            var bark := Color("#8a603d").lerp(Color("#a97e52"), _rng.randf_range(0.0, 0.45 if elder else 0.2))
            trunk_colors.append(bark)
            # A root flare — a low, wide cone hugging the trunk's feet — so
            # every tree meets the ground grown-out instead of potted.
            flare_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(trunk_girth * 1.9, 0.34, trunk_girth * 1.9)), base + Vector3(0, 0.10, 0)))
            var crown_count := (3 if elder else 0) + (2 if _rng.randf() < 0.72 else 1)
            for crown_index in range(crown_count):
                var crown_scale := Vector3.ONE * _rng.randf_range(0.72, 1.18) * (1.30 if elder else 1.0)
                crown_scale.y *= _rng.randf_range(0.80, 1.12)
                var crown_position := base + Vector3(_rng.randf_range(-0.48, 0.48), trunk_height + _rng.randf_range(0.15, 0.65), _rng.randf_range(-0.48, 0.48))
                crown_transforms.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf_range(0, TAU), 0)).scaled(crown_scale), crown_position))
                crown_colors.append(Color(region["foliage"]).lerp(Color(region["tip"]), _rng.randf_range(0.0, 0.72)))
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.14
    trunk_mesh.bottom_radius = 0.23
    trunk_mesh.height = 1.0
    trunk_mesh.radial_segments = 7
    var trunk_material := _pbr(Color("#8a603d"), 0.93)
    # Per-instance bark: elders wear the palest wood of the stand, so the
    # material must actually read the instance colors it is given.
    trunk_material.vertex_color_use_as_albedo = true
    _add_multimesh("GroveTrunks", trunk_mesh, trunk_material, trunk_transforms, trunk_colors)
    # The flare shares the trunk's material so bark and roots shade as one.
    var flare_mesh := CylinderMesh.new()
    flare_mesh.top_radius = 0.16
    flare_mesh.bottom_radius = 0.30
    flare_mesh.height = 1.0
    flare_mesh.radial_segments = 7
    _add_multimesh("GroveFlares", flare_mesh, _pbr(Color("#7d563a"), 0.95), flare_transforms, [])

    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 0.80
    crown_mesh.height = 1.60
    crown_mesh.radial_segments = 10
    crown_mesh.rings = 6
    var crown_material := _foliage_material(Color(region["foliage"]), Color(region["tip"]))
    _add_multimesh("GroveCanopies", crown_mesh, crown_material, crown_transforms, crown_colors)

func _build_decor() -> void:
    var width := int(dungeon["width"])
    var depth := int(dungeon["height"])
    var flower_stems: Array[Transform3D] = []
    var petals: Array[Transform3D] = []
    var petal_colors: Array[Color] = []
    var mushrooms_stems: Array[Transform3D] = []
    var mushrooms_caps: Array[Transform3D] = []
    var mushroom_colors: Array[Color] = []
    var rocks: Array[Transform3D] = []
    var desired_flowers := int(float(width * depth) / 48.0)
    var desired_mushrooms := int(float(width * depth) / 78.0)
    var desired_rocks := int(float(width * depth) / 95.0)

    for index in range(desired_flowers + desired_mushrooms + desired_rocks):
        var cell := _random_floor_cell()
        var position := DungeonGenerator.cell_to_world(cell) + Vector3(_rng.randf_range(-0.25, 0.25), 0.0, _rng.randf_range(-0.25, 0.25))
        if _distance_to_nearest_room(position) < 2.2:
            continue
        if index < desired_flowers:
            var stem_height := _rng.randf_range(0.22, 0.43)
            flower_stems.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.65, stem_height, 0.65)), position + Vector3(0, stem_height * 0.5, 0)))
            for petal_index in range(5):
                var angle := TAU * float(petal_index) / 5.0
                petals.append(Transform3D(Basis.from_euler(Vector3(0, angle, 0)).scaled(Vector3.ONE * _rng.randf_range(0.75, 1.08)), position + Vector3(cos(angle) * 0.095, stem_height, sin(angle) * 0.095)))
                # One color per petal keeps the color array parallel to the
                # transforms; without it the multimesh silently drops all
                # petal colors and the flowers bloom white.
                petal_colors.append(Color(region["flower"]).lerp(Color("#fff2a8"), _rng.randf() * 0.42))
        elif index < desired_flowers + desired_mushrooms:
            var stem_height := _rng.randf_range(0.18, 0.42)
            mushrooms_stems.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, stem_height, 0.7)), position + Vector3(0, stem_height * 0.5, 0)))
            var cap_scale := _rng.randf_range(0.72, 1.25)
            mushrooms_caps.append(Transform3D(Basis.IDENTITY.scaled(Vector3(cap_scale, cap_scale * 0.55, cap_scale)), position + Vector3(0, stem_height, 0)))
            mushroom_colors.append(Color(region["flower"]).lerp(Color(region["accent"]), _rng.randf()))
        else:
            var rock_scale := _rng.randf_range(0.35, 0.82)
            rocks.append(Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0, TAU), _rng.randf_range(-0.2, 0.2))).scaled(Vector3(rock_scale, rock_scale * 0.62, rock_scale * 0.82)), position + Vector3(0, rock_scale * 0.30, 0)))

    var stem_mesh := CylinderMesh.new()
    stem_mesh.top_radius = 0.018
    stem_mesh.bottom_radius = 0.025
    stem_mesh.height = 1.0
    stem_mesh.radial_segments = 5
    _add_multimesh("FlowerStems", stem_mesh, _pbr(Color("#4f994f"), 0.92), flower_stems, [])
    var petal_mesh := SphereMesh.new()
    petal_mesh.radius = 0.075
    petal_mesh.height = 0.15
    petal_mesh.radial_segments = 6
    petal_mesh.rings = 3
    var petal_material := _emissive(Color.WHITE, 0.22)
    petal_material.vertex_color_use_as_albedo = true
    _add_multimesh("GlowingPetals", petal_mesh, petal_material, petals, petal_colors)
    var mushroom_stem_mesh := CylinderMesh.new()
    mushroom_stem_mesh.top_radius = 0.07
    mushroom_stem_mesh.bottom_radius = 0.11
    mushroom_stem_mesh.height = 1.0
    mushroom_stem_mesh.radial_segments = 8
    _add_multimesh("MushroomStems", mushroom_stem_mesh, _pbr(Color("#f1dfb7"), 0.86), mushrooms_stems, [])
    var mushroom_cap_mesh := SphereMesh.new()
    mushroom_cap_mesh.radius = 0.20
    mushroom_cap_mesh.height = 0.22
    mushroom_cap_mesh.radial_segments = 10
    mushroom_cap_mesh.rings = 5
    var mushroom_material := _emissive(Color.WHITE, 0.35)
    mushroom_material.vertex_color_use_as_albedo = true
    _add_multimesh("MushroomCaps", mushroom_cap_mesh, mushroom_material, mushrooms_caps, mushroom_colors)
    var rock_mesh := SphereMesh.new()
    rock_mesh.radius = 0.42
    rock_mesh.height = 0.42
    rock_mesh.radial_segments = 8
    rock_mesh.rings = 4
    _add_multimesh("WarmPebbles", rock_mesh, _pbr(Color("#bcae89"), 0.98), rocks, [])

## The ground's third layer, above the shader and the decor: swaying grass
## tufts, fallen leaves and clover clumps, one instanced draw call each.
func _build_ground_details() -> void:
    GroundDetails.scatter(self, dungeon, _rng, region, _wind_materials)

func _build_sunbeams() -> void:
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
    if dungeon["rooms"].is_empty():
        return
    var count := 4 + (1 if floor_number >= 5 else 0)
    for beam_index in range(count):
        var room: Dictionary = dungeon["rooms"][beam_index % dungeon["rooms"].size()]
        var base_radius := _rng.randf_range(0.62, 1.05)
        var height := _rng.randf_range(9.5, 12.5)
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
        material.set_shader_parameter("beam_color", Color(region["accent"]))
        material.set_shader_parameter("intensity", _rng.randf_range(0.13, 0.20))
        material.set_shader_parameter("base_radius", base_radius)
        material.set_shader_parameter("tip_radius", base_radius * 0.30)
        material.set_shader_parameter("beam_height", height)
        material.set_shader_parameter("drift", _rng.randf_range(0.0, TAU))
        beam.material_override = material
        # Anchored to the room but pushed out to the grove side so the shaft
        # frames the clearing instead of veiling the hero standing in it.
        var lean := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(4.0, 7.0)
        beam.position = Vector3(float(room["cx"]) + lean.x, height * 0.5, float(room["cy"]) + lean.y)
        beam.rotation_degrees = Vector3(_rng.randf_range(-7, 7), _rng.randf_range(0, 360), _rng.randf_range(-7, 7))
        add_child(beam)

func _build_ambient_life() -> void:
    var map_center := Vector3(float(dungeon["width"]) * 0.5, 0.0, float(dungeon["height"]) * 0.5)
    var ambient_motes := CozyVFX.spawn_ambient_motes(self, region, 125 if floor_number < 9 else 150)
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
    leaf_material.albedo_color = Color(region["tip"], 0.72)
    leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    leaf_mesh.material = leaf_material
    leaves.draw_pass_1 = leaf_mesh
    leaves.position = map_center
    add_child(leaves)

func _foliage_material(base: Color, tip: Color) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/foliage.gdshader")
    material.set_shader_parameter("base_color", base)
    material.set_shader_parameter("tip_color", tip)
    material.set_shader_parameter("wind_strength", 0.026)
    _wind_materials.append(material)
    return material

func _pbr(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
    return CozyMaterials.pbr(color, roughness, metallic)

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    return CozyMaterials.emissive(color, energy, true)

func _toon(color: Color, glow: float, roughness: float) -> ShaderMaterial:
    return CozyMaterials.toon(color, glow, roughness)

func _add_multimesh(node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D], colors: Array[Color]) -> MultiMeshInstance3D:
    if transforms.is_empty():
        return null
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = not colors.is_empty() and colors.size() == transforms.size()
    multimesh.mesh = mesh
    multimesh.instance_count = transforms.size()
    for index in range(transforms.size()):
        multimesh.set_instance_transform(index, transforms[index])
        if multimesh.use_colors:
            multimesh.set_instance_color(index, colors[index])
    var instance := MultiMeshInstance3D.new()
    instance.name = node_name
    instance.multimesh = multimesh
    instance.material_override = material
    add_child(instance)
    return instance

func _point_inside_room(x: int, z: int, margin: int) -> bool:
    return DungeonGenerator.point_in_any_room(dungeon["rooms"], float(x), float(z), float(margin))

func _random_floor_cell() -> Vector2i:
    return DungeonGenerator.random_floor_cell(dungeon, _rng, Vector2(-1000, -1000), 0.0)

func _distance_to_nearest_room(position: Vector3) -> float:
    var best := INF
    for room: Dictionary in dungeon["rooms"]:
        best = minf(best, Vector2(position.x - float(room["cx"]), position.z - float(room["cy"])).length())
    return best

func _spread_cell(room: Dictionary, occupied: Dictionary, separation: float, index: int) -> Vector2i:
    var best := Vector2i(int(room["cx"]), int(room["cy"]))
    var best_score := -1.0
    for _attempt in range(70):
        var x := _rng.randi_range(int(room["x"]), int(room["x"]) + int(room["w"]) - 1)
        var z := _rng.randi_range(int(room["y"]), int(room["y"]) + int(room["h"]) - 1)
        if not DungeonGenerator.is_floor(dungeon, x, z) or occupied.has(Vector2i(x, z)):
            continue
        var score := INF
        for used: Vector2i in occupied.keys():
            score = minf(score, Vector2(used - Vector2i(x, z)).length_squared())
        if score > best_score:
            best_score = score
            best = Vector2i(x, z)
        if score >= separation * separation:
            break
    return best
