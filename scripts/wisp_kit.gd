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
