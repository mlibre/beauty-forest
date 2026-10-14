class_name WispKit
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyMaterials := preload("res://scripts/cozy_materials.gd")

## The wisp's little mesh kit: the four primitives every body part, prop and
## costume piece is assembled from, all wearing the same flat paint. Split
## out of Wisp when that file outgrew the 500-line ceiling; static builders
## that hand back a ready MeshInstance3D.

static func sphere(radius: float, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    visual.mesh = mesh
    visual.material_override = toot(color)
    return visual

static func box(size: Vector3, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.material_override = toot(color)
    return visual

static func cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    visual.mesh = mesh
    visual.material_override = toot(color)
    return visual

static func cone(radius: float, height: float, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.01
    mesh.bottom_radius = radius
    mesh.height = height
    visual.mesh = mesh
    visual.material_override = toot(color)
    return visual

static func toot(color: Color) -> StandardMaterial3D:
    return CozyMaterials.pbr(color, 0.82)

## The pool of light a wisp casts on the grass under itself: a flat additive
## disc, the way the hero's contact shadow is a flat dark one. It is what
## makes a wisp read as a LANTERN-creature from across a clearing instead of
## a floating costume -- light has to land somewhere.
static func ground_glow(radius: float, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 0.35
    mesh.height = 0.012
    mesh.radial_segments = 20
    visual.mesh = mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.albedo_color = Color(color.r, color.g, color.b, 0.16)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.1
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    visual.mesh.material = material
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return visual
