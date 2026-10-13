class_name HeroTailor
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyMaterials := preload("res://scripts/cozy_materials.gd")

## The hero's workshop: the traveler's hat, the four limbs, and the three
## material mixes every part of the rig wears. Split out of HeroRig when the
## rig file outgrew the 500-line ceiling -- the rig stays the living body
## (its per-frame sway, blink and warmth), this stays the cloth and the
## joinery it is built from. All builders are static: they assemble nodes and
## hand them back, and every node name they create is load-bearing (the
## animation tracks and the suites walk these paths).

## The flat paint the prop parts wear (feather quill, boot cuffs).
static func toot(color: Color) -> StandardMaterial3D:
    return CozyMaterials.pbr(color, 0.78)

## The toon body mix every cloth part wears.
static func toon(color: Color, glow: float, roughness: float) -> ShaderMaterial:
    return CozyMaterials.toon(color, glow, roughness, 0.26)

## The lamp-fire and ember mix.
static func emissive(color: Color, energy: float) -> StandardMaterial3D:
    return CozyMaterials.emissive(color, energy)

## A wide-brimmed traveler's hat with a soft, flopped crown and a feather:
## the single biggest silhouette upgrade the hero can wear, readable from
## any angle and against any backdrop the canopy offers. Returns the pivot
## the rig animates (null when there is no head to pin it to).
static func build_hat(rig: Node3D, scarf_material: ShaderMaterial) -> Node3D:
    var head := rig.get_node_or_null("Model/Hips/Head")
    if head == null:
        return null
    var hat_pivot := Node3D.new()
    hat_pivot.name = "HatPivot"
    hat_pivot.position = Vector3(0, 0.20, 0.01)
    hat_pivot.rotation_degrees = Vector3(4.0, 0.0, -3.0)
    head.add_child(hat_pivot)

    var brim := MeshInstance3D.new()
    var brim_mesh := CylinderMesh.new()
    brim_mesh.top_radius = 0.46
    brim_mesh.bottom_radius = 0.50
    brim_mesh.height = 0.035
    brim_mesh.radial_segments = 18
    brim.mesh = brim_mesh
    brim.material_override = toon(Color("#5f8f5a"), 0.08, 0.84)
    brim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    hat_pivot.add_child(brim)

    # The crown leans back and its tip flops forward: a cone split at the top
    # would need bones, so the flop is one extra bent segment kissing the first.
    var crown := MeshInstance3D.new()
    var crown_mesh := CylinderMesh.new()
    crown_mesh.top_radius = 0.16
    crown_mesh.bottom_radius = 0.30
    crown_mesh.height = 0.34
    crown_mesh.radial_segments = 14
    crown.mesh = crown_mesh
    crown.material_override = toon(Color("#5f8f5a"), 0.08, 0.84)
    crown.position = Vector3(0, 0.18, -0.02)
    crown.rotation.x = -0.10
    crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    hat_pivot.add_child(crown)
    var flop := MeshInstance3D.new()
    var flop_mesh := SphereMesh.new()
    flop_mesh.radius = 0.155
    flop_mesh.height = 0.30
    flop.mesh = flop_mesh
    flop.material_override = toon(Color("#548057"), 0.08, 0.84)
    flop.position = Vector3(0, 0.36, 0.05)
    flop.rotation.x = 0.85
    flop.scale = Vector3(1.0, 1.0, 1.25)
    hat_pivot.add_child(flop)

    # The band repeats the scarf, so hat and neck answer each other.
    var band := MeshInstance3D.new()
    var band_mesh := CylinderMesh.new()
    band_mesh.top_radius = 0.305
    band_mesh.bottom_radius = 0.315
    band_mesh.height = 0.09
    band_mesh.radial_segments = 16
    band.mesh = band_mesh
    band.material_override = scarf_material
    band.position = Vector3(0, 0.045, -0.02)
    hat_pivot.add_child(band)

    # One goose feather, pinned where band meets crown, tips forward-left.
    var quill := MeshInstance3D.new()
    var quill_mesh := CylinderMesh.new()
    quill_mesh.top_radius = 0.008
    quill_mesh.bottom_radius = 0.014
    quill_mesh.height = 0.26
    quill_mesh.radial_segments = 6
    quill.mesh = quill_mesh
    quill.material_override = toot(Color("#c9b48a"))
    quill.position = Vector3(-0.24, 0.19, -0.06)
    quill.rotation_degrees = Vector3(-12.0, 0.0, -38.0)
    hat_pivot.add_child(quill)
    var vane := MeshInstance3D.new()
    var vane_mesh := SphereMesh.new()
    vane_mesh.radius = 0.05
    vane_mesh.height = 0.20
    vane.mesh = vane_mesh
    vane.material_override = toon(Color("#e8707a"), 0.10, 0.78)
    vane.position = Vector3(-0.32, 0.28, -0.07)
    vane.rotation.z = -0.55
    vane.scale = Vector3(0.35, 1.0, 0.8)
    hat_pivot.add_child(vane)
    return hat_pivot

## The swing joint every limb hangs from, pinned to the hips.
static func attach_pivot(rig: Node3D, node_name: String, pivot_position: Vector3) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = node_name
    pivot.position = pivot_position
    var hips := rig.get_node_or_null("Model/Hips")
    if hips:
        hips.add_child(pivot)
    return pivot

## One arm: sleeve capsule, sphere hand. Returns the pivot the walk cycle
## swings.
static func build_arm(rig: Node3D, node_name: String, pivot_position: Vector3, arm_material: Material, sleeve_material: Material) -> Node3D:
    var pivot := attach_pivot(rig, node_name, pivot_position)
    var sleeve := MeshInstance3D.new()
    var sleeve_mesh := CapsuleMesh.new()
    sleeve_mesh.radius = 0.115
    sleeve_mesh.height = 0.42
    sleeve.mesh = sleeve_mesh
    sleeve.material_override = sleeve_material
    sleeve.position = Vector3(0, -0.18, 0)
    pivot.add_child(sleeve)
    var hand := MeshInstance3D.new()
    hand.mesh = SphereMesh.new()
    hand.mesh.radius = 0.115
    hand.mesh.height = 0.22
    hand.material_override = arm_material
    hand.position = Vector3(0, -0.42, 0)
    pivot.add_child(hand)
    return pivot

## One leg: trouser capsule, squashed boot sphere, fur cuff at the top
## warming the line between trouser and boot the way a collar does at the
## neck.
static func build_leg(rig: Node3D, node_name: String, pivot_position: Vector3, trouser_material: Material, boot_material: Material) -> void:
    var pivot := attach_pivot(rig, node_name, pivot_position)
    var leg := MeshInstance3D.new()
    var leg_mesh := CapsuleMesh.new()
    leg_mesh.radius = 0.13
    leg_mesh.height = 0.58
    leg.mesh = leg_mesh
    leg.material_override = trouser_material
    leg.position = Vector3(0, -0.29, 0)
    pivot.add_child(leg)
    var boot := MeshInstance3D.new()
    var boot_mesh := SphereMesh.new()
    boot_mesh.radius = 0.15
    boot_mesh.height = 0.30
    boot.mesh = boot_mesh
    boot.material_override = boot_material
    boot.position = Vector3(0, -0.62, -0.055)
    boot.scale = Vector3(1.0, 0.70, 1.25)
    pivot.add_child(boot)
    var cuff := MeshInstance3D.new()
    var cuff_mesh := CylinderMesh.new()
    cuff_mesh.top_radius = 0.145
    cuff_mesh.bottom_radius = 0.16
    cuff_mesh.height = 0.09
    cuff_mesh.radial_segments = 10
    cuff.mesh = cuff_mesh
    cuff.material_override = toot(Color("#e8d9b8"))
    cuff.position = Vector3(0, -0.50, -0.02)
    pivot.add_child(cuff)
