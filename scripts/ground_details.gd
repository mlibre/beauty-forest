class_name GroundDetails
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")

## The ground's third layer, above the shader and the decor: instanced grass
## tufts that sway with the same wind as the canopy, fallen leaves scattered
## across the turf, and clover clumps. The moss plane gives the floor its
## colour; these give it depth — a floor made only of a plane reads as paint
## no matter how good the shader is, because nothing on it has an edge.

## One grass tuft: a thin cone, tinted per instance from the region's foliage
## toward its tip colour. MultiMesh keeps a few hundred of them at one draw
## call, which the web build needs.
static func scatter(parent: Node3D, dungeon: Dictionary, rng: RandomNumberGenerator, region: Dictionary, wind_materials: Array[ShaderMaterial]) -> void:
    var tufts: Array[Transform3D] = []
    var tuft_colors: Array[Color] = []
    var leaves: Array[Transform3D] = []
    var leaf_colors: Array[Color] = []
    var clovers: Array[Transform3D] = []
    var area := float(int(dungeon["width"])) * float(int(dungeon["height"]))
    var wanted_tufts := int(area / 14.0)
    var wanted_leaves := int(area / 20.0)
    var wanted_clovers := int(area / 42.0)
    for index in range(wanted_tufts + wanted_leaves + wanted_clovers):
        var cell := DungeonGenerator.random_floor_cell(dungeon, rng, Vector2(-1000, -1000))
        var at := DungeonGenerator.cell_to_world(cell) + Vector3(rng.randf_range(-0.42, 0.42), 0, rng.randf_range(-0.42, 0.42))
        if index < wanted_tufts:
            var lean := rng.randf_range(-0.22, 0.22)
            var tuft_basis := Basis.from_euler(Vector3(lean, rng.randf_range(0, TAU), rng.randf_range(-0.22, 0.22))) \
                .scaled(Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.7, 1.45), rng.randf_range(0.8, 1.3)))
            tufts.append(Transform3D(tuft_basis, at))
            var grass := Color(region["foliage"]).lerp(Color(region["tip"]), rng.randf_range(0.1, 0.85))
            tuft_colors.append(grass.darkened(rng.randf_range(0.0, 0.22)))
        elif index < wanted_tufts + wanted_leaves:
            var flat := Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0, TAU), rng.randf_range(-0.35, 0.35)))
            leaves.append(Transform3D(flat, at + Vector3(0, 0.015, 0)))
            # Fallen leaves are warm even in the coolest region: a floor gets
            # its amber from spent things, not only from the sun.
            var warm := Color("#c98a4e").lerp(Color("#e0b05e"), rng.randf())
            leaf_colors.append(warm.lerp(Color(region["flower"]), rng.randf_range(0.0, 0.30)))
        else:
            for clump_index in range(3):
                var angle := TAU * float(clump_index) / 3.0 + rng.randf_range(-0.4, 0.4)
                var dot_scale := rng.randf_range(0.7, 1.25)
                var clover_basis := Basis.IDENTITY.scaled(Vector3.ONE * dot_scale)
                clovers.append(Transform3D(clover_basis, at + Vector3(cos(angle) * 0.09, 0.02, sin(angle) * 0.09)))
    _tufts(parent, tufts, tuft_colors, wind_materials)
    _fallen_leaves(parent, leaves, leaf_colors)
    _clover(parent, clovers, region)

static func _tufts(parent: Node3D, transforms: Array[Transform3D], colors: Array[Color], wind_materials: Array[ShaderMaterial]) -> void:
    if transforms.is_empty():
        return
    var blade := CylinderMesh.new()
    blade.top_radius = 0.012
    blade.bottom_radius = 0.05
    blade.height = 0.34
    blade.radial_segments = 4
    blade.rings = 1
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/foliage.gdshader")
    material.set_shader_parameter("wind_strength", 0.045)
    material.set_shader_parameter("tip_gradient", 0.5)
    material.set_shader_parameter("glow_amount", 0.03)
    material.set_shader_parameter("base_color", Color("#3f7d33"))
    material.set_shader_parameter("tip_color", Color("#b7dc55"))
    # The tufts sway on the same clock as the canopy: the caller's list is
    # what ForestWorld._process ticks, so the whole floor leans together.
    wind_materials.append(material)
    _multimesh(parent, "GrassTufts", blade, material, transforms, colors)

static func _fallen_leaves(parent: Node3D, transforms: Array[Transform3D], colors: Array[Color]) -> void:
    if transforms.is_empty():
        return
    var leaf := QuadMesh.new()
    leaf.size = Vector2(0.15, 0.10)
    var material := StandardMaterial3D.new()
    material.roughness = 0.9
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _multimesh(parent, "FallenLeaves", leaf, material, transforms, colors)

static func _clover(parent: Node3D, transforms: Array[Transform3D], region: Dictionary) -> void:
    if transforms.is_empty():
        return
    var dot := SphereMesh.new()
    dot.radius = 0.045
    dot.height = 0.07
    dot.radial_segments = 6
    dot.rings = 3
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(region["foliage"]).darkened(0.25)
    material.roughness = 0.85
    _multimesh(parent, "CloverClumps", dot, material, transforms, [])

static func _multimesh(parent: Node3D, node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D], colors: Array[Color]) -> void:
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
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
