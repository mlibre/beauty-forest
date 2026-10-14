class_name WorldPlaceDressing
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyMaterials := preload("res://scripts/cozy_materials.gd")

## The finishing touches the grove's places wear: the small props that turn a
## built stall into a LIVED-IN stall. Static dressers that hang their work on
## the node they are handed; nothing here is load-bearing -- no suite walks
## these names -- so the dressing can grow without moving the furniture.

## The flat paint the dressing wears.
static func pbr(color: Color, roughness: float) -> StandardMaterial3D:
    return CozyMaterials.pbr(color, roughness)

## Herb bundles hanging under the stall's canopy rim: lavender, sage and
## mint, tied and drying. The one smell a market has even in a forest with
## no noses. Three bundles, slightly different heights, because a row of
## identical bundles would read as manufactured.
static func dress_stall(body: Node3D) -> void:
    var bundle_spots: Array[Vector3] = [
        Vector3(-0.52, 1.50, 0.98), Vector3(0.02, 1.56, 1.00), Vector3(0.54, 1.47, 0.97),
    ]
    var bundle_colors: Array[Color] = [
        Color("#8f7ab0"), Color("#7a8f5a"), Color("#6fa07a"),
    ]
    for bundle_index in range(bundle_spots.size()):
        var spot := bundle_spots[bundle_index]
        var hang := MeshInstance3D.new()
        var hang_mesh := CylinderMesh.new()
        hang_mesh.top_radius = 0.004
        hang_mesh.bottom_radius = 0.004
        hang_mesh.height = 0.09
        hang_mesh.radial_segments = 4
        hang.mesh = hang_mesh
        hang.material_override = pbr(Color("#c9b48a"), 0.9)
        hang.position = spot + Vector3(0, 0.055, 0)
        body.add_child(hang)
        var bundle := MeshInstance3D.new()
        var bundle_mesh := CylinderMesh.new()
        bundle_mesh.top_radius = 0.028
        bundle_mesh.bottom_radius = 0.042
        bundle_mesh.height = 0.14
        bundle_mesh.radial_segments = 7
        bundle.mesh = bundle_mesh
        bundle.material_override = pbr(bundle_colors[bundle_index], 0.95)
        bundle.position = spot + Vector3(0, -0.075, 0)
        body.add_child(bundle)
        var tie := MeshInstance3D.new()
        var tie_mesh := CylinderMesh.new()
        tie_mesh.top_radius = 0.036
        tie_mesh.bottom_radius = 0.036
        tie_mesh.height = 0.02
        tie_mesh.radial_segments = 7
        tie.mesh = tie_mesh
        tie.material_override = pbr(Color("#b8695a"), 0.9)
        tie.position = spot + Vector3(0, -0.028, 0)
        body.add_child(tie)
        for leaf_index in range(3):
            var leaf := MeshInstance3D.new()
            var leaf_mesh := SphereMesh.new()
            leaf_mesh.radius = 0.026
            leaf_mesh.height = 0.05
            leaf.mesh = leaf_mesh
            leaf.material_override = pbr(bundle_colors[bundle_index].lerp(Color("#5f7a4a"), 0.4), 0.96)
            var leaf_angle := TAU * float(leaf_index) / 3.0
            leaf.position = spot + Vector3(cos(leaf_angle) * 0.035, -0.145, sin(leaf_angle) * 0.035)
            body.add_child(leaf)

    # Two paper price tags swaying off the counter lid's front edge, the
    # peddler's own handwriting implied by three tiny charcoal strokes.
    for tag_spot: Vector3 in [Vector3(-0.68, 0.94, 0.64), Vector3(0.34, 0.94, 0.64)]:
        var string := MeshInstance3D.new()
        var string_mesh := CylinderMesh.new()
        string_mesh.top_radius = 0.004
        string_mesh.bottom_radius = 0.004
        string_mesh.height = 0.08
        string_mesh.radial_segments = 4
        string.mesh = string_mesh
        string.material_override = pbr(Color("#c9b48a"), 0.9)
        string.position = tag_spot + Vector3(0, 0.05, 0)
        body.add_child(string)
        var tag := MeshInstance3D.new()
        var tag_mesh := BoxMesh.new()
        tag_mesh.size = Vector3(0.10, 0.13, 0.008)
        tag.mesh = tag_mesh
        tag.material_override = pbr(Color("#efe6cf"), 0.92)
        tag.position = tag_spot + Vector3(0, -0.035, 0)
        tag.rotation.z = 0.05 if tag_spot.x < 0.0 else -0.06
        body.add_child(tag)
        for stroke_index in range(3):
            var stroke := MeshInstance3D.new()
            var stroke_mesh := BoxMesh.new()
            stroke_mesh.size = Vector3(0.055, 0.011, 0.004)
            stroke.mesh = stroke_mesh
            stroke.material_override = pbr(Color("#5a4a3a"), 0.95)
            stroke.position = tag_spot + Vector3(-0.012 + 0.012 * float(stroke_index), -0.012 - 0.032 * float(stroke_index), 0.005)
            stroke.rotation.z = 0.18 if stroke_index != 1 else -0.12
            body.add_child(stroke)

    # A rolled blanket leaning against the counter's flank, waiting for a
    # cold night's floor: the traveler's own goods, stock and bedding in one.
    var roll := MeshInstance3D.new()
    var roll_mesh := CylinderMesh.new()
    roll_mesh.top_radius = 0.085
    roll_mesh.bottom_radius = 0.085
    roll_mesh.height = 0.52
    roll_mesh.radial_segments = 12
    roll.mesh = roll_mesh
    roll.material_override = pbr(Color("#b8695a"), 0.94)
    roll.position = Vector3(-1.38, 0.09, 0.10)
    roll.rotation.z = PI * 0.5
    roll.rotation.y = 0.35
    body.add_child(roll)
    # The tie bands ride the roll as children, so they inherit its lean and
    # yaw exactly -- no second hand-rolled basis math to drift out of sync.
    for band_offset in [-0.14, 0.14]:
        var band := MeshInstance3D.new()
        var band_mesh := CylinderMesh.new()
        band_mesh.top_radius = 0.088
        band_mesh.bottom_radius = 0.088
        band_mesh.height = 0.05
        band_mesh.radial_segments = 12
        band.mesh = band_mesh
        band.material_override = pbr(Color("#e8c188"), 0.92)
        band.position = Vector3(0, band_offset, 0)
        roll.add_child(band)
