class_name HeroRig
extends Node3D

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyMaterials := preload("res://scripts/cozy_materials.gd")
const HeroTailor := preload("res://scripts/hero_tailor.gd")
const HeroRigAnim := preload("res://scripts/hero_rig_anim.gd")

## A fully procedural, articulated 3D hero. AnimationTree blends idle, walk,
## and the lantern's cosmetic staff-swing; no manual attack input exists.

var animation_tree: AnimationTree
var _walk_target := 0.0
var _swing_target := 0.0
var _walk_current := 0.0
var _swing_current := 0.0
var _happy := false
## 0..1. How full the lantern is. The HUD ring, the lantern's own light and the
## ember vignette all read from this one number, so the world and the readout
## can never disagree.
var _warmth := 1.0
var _time := 0.0
var _reduced_motion := false
var _lantern_light: OmniLight3D
var _lantern_core: MeshInstance3D
var _scarf: MeshInstance3D
var _model: Node3D
var _staff_pivot: Node3D
var _blink_timer := 2.8
var _blink_time := 0.0
var _eye_meshes: Array[MeshInstance3D] = []
var _cape: MeshInstance3D
var _cape_hem: MeshInstance3D
var _contact_shadow: MeshInstance3D
var _hat_pivot: Node3D
var _spark_pivot: Node3D

func _ready() -> void:
    _build_character()
    _build_animations()

func _build_character() -> void:
    var model := Node3D.new()
    model.name = "Model"
    add_child(model)
    _model = model

    var skin := HeroTailor.toon(Color("#f2c6a5"), 0.06, 0.72)
    var skin_shadow := HeroTailor.toon(Color("#d99b7e"), 0.04, 0.80)
    var hair := HeroTailor.toon(Color("#74492f"), 0.05, 0.86)
    var tunic := HeroTailor.toon(Color("#5ea96b"), 0.10, 0.78)
    var tunic_light := HeroTailor.toon(Color("#83c878"), 0.09, 0.74)
    var trousers := HeroTailor.toot(Color("#445f62"))
    var boots := HeroTailor.toot(Color("#6d4632"))
    var scarf_mat := HeroTailor.toon(Color("#ef8d84"), 0.16, 0.70)
    var gold := HeroTailor.toon(Color("#ffe49a"), 0.45, 0.40)

    var hips := Node3D.new()
    hips.name = "Hips"
    hips.position = Vector3(0, 0.78, 0)
    model.add_child(hips)

    var torso := MeshInstance3D.new()
    var torso_mesh := CapsuleMesh.new()
    torso_mesh.radius = 0.31
    torso_mesh.height = 0.80
    torso.mesh = torso_mesh
    torso.material_override = tunic
    torso.position = Vector3(0, 0.28, 0)
    torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    hips.add_child(torso)

    var tunic_overlay := MeshInstance3D.new()
    var tunic_mesh := CylinderMesh.new()
    tunic_mesh.top_radius = 0.34
    tunic_mesh.bottom_radius = 0.42
    tunic_mesh.height = 0.48
    tunic_overlay.mesh = tunic_mesh
    tunic_overlay.material_override = tunic_light
    tunic_overlay.position = Vector3(0, 0.16, 0)
    hips.add_child(tunic_overlay)

    # A leather satchel rides the right hip; its strap crosses the chest, so
    # the hero reads as a traveler even from the front where the cape hides.
    var satchel := MeshInstance3D.new()
    var satchel_mesh := BoxMesh.new()
    satchel_mesh.size = Vector3(0.17, 0.15, 0.10)
    satchel.mesh = satchel_mesh
    satchel.material_override = HeroTailor.toot(Color("#7a5236"))
    satchel.position = Vector3(0.33, 0.05, 0.02)
    hips.add_child(satchel)
    var satchel_flap := MeshInstance3D.new()
    var flap_mesh := BoxMesh.new()
    flap_mesh.size = Vector3(0.18, 0.06, 0.11)
    satchel_flap.mesh = flap_mesh
    satchel_flap.material_override = HeroTailor.toot(Color("#8a5e3b"))
    satchel_flap.position = Vector3(0.33, 0.115, 0.02)
    hips.add_child(satchel_flap)
    var strap := MeshInstance3D.new()
    var strap_mesh := BoxMesh.new()
    strap_mesh.size = Vector3(0.075, 0.62, 0.03)
    strap.mesh = strap_mesh
    strap.material_override = HeroTailor.toot(Color("#6d4632"))
    strap.position = Vector3(-0.10, 0.30, -0.30)
    strap.rotation.z = 0.62
    hips.add_child(strap)
    var buckle := MeshInstance3D.new()
    var buckle_mesh := BoxMesh.new()
    buckle_mesh.size = Vector3(0.075, 0.055, 0.036)
    buckle.mesh = buckle_mesh
    buckle.material_override = gold
    # The buckle rides the strap's lower reach, just above the belt: the
    # chest is a capsule, and at the buckle's old perch near the shoulder it
    # curved back ~0.13 behind the strap plane — the gold plate floated off
    # the chest. At the belt line the capsule is at its widest and the
    # buckle sits flush on the strap.
    buckle.position = Vector3(0.043, 0.10, -0.322)
    buckle.rotation.z = 0.62
    hips.add_child(buckle)

    var belt := MeshInstance3D.new()
    belt.mesh = TorusMesh.new()
    belt.mesh.inner_radius = 0.29
    belt.mesh.outer_radius = 0.35
    belt.material_override = boots
    belt.position = Vector3(0, 0.03, 0)
    hips.add_child(belt)

    var head := Node3D.new()
    head.name = "Head"
    head.position = Vector3(0, 0.88, 0)
    hips.add_child(head)
    var face := MeshInstance3D.new()
    face.mesh = SphereMesh.new()
    face.mesh.radius = 0.31
    face.mesh.height = 0.58
    face.material_override = skin
    face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    head.add_child(face)

    var hair_cap := MeshInstance3D.new()
    hair_cap.mesh = SphereMesh.new()
    hair_cap.mesh.radius = 0.325
    hair_cap.mesh.height = 0.38
    hair_cap.material_override = hair
    hair_cap.position = Vector3(0, 0.16, 0.015)
    head.add_child(hair_cap)
    for side in [-1.0, 1.0]:
        var curl := MeshInstance3D.new()
        curl.mesh = SphereMesh.new()
        curl.mesh.radius = 0.11
        curl.mesh.height = 0.24
        curl.material_override = hair
        curl.position = Vector3(side * 0.255, 0.10, 0.0)
        head.add_child(curl)

    for side in [-1.0, 1.0]:
        var eye_white := MeshInstance3D.new()
        eye_white.mesh = SphereMesh.new()
        eye_white.mesh.radius = 0.072
        eye_white.mesh.height = 0.12
        eye_white.material_override = HeroTailor.toot(Color("#fffaf0"))
        eye_white.position = Vector3(side * 0.105, 0.02, -0.285)
        head.add_child(eye_white)
        _eye_meshes.append(eye_white)
        var pupil := MeshInstance3D.new()
        pupil.mesh = SphereMesh.new()
        pupil.mesh.radius = 0.034
        pupil.mesh.height = 0.062
        pupil.material_override = HeroTailor.toot(Color("#38271f"))
        pupil.position = Vector3(side * 0.105, 0.02, -0.345)
        head.add_child(pupil)
        var cheek := MeshInstance3D.new()
        cheek.mesh = SphereMesh.new()
        cheek.mesh.radius = 0.045
        cheek.mesh.height = 0.025
        cheek.material_override = HeroTailor.toon(Color("#ef9b91"), 0.05, 0.9)
        cheek.position = Vector3(side * 0.17, -0.075, -0.292)
        head.add_child(cheek)

    # Three tiny beads make a readable upward smile without font assets.
    var smile_points := [Vector3(-0.055, -0.095, -0.338), Vector3(0, -0.12, -0.348), Vector3(0.055, -0.095, -0.338)]
    for point: Vector3 in smile_points:
        var smile := MeshInstance3D.new()
        smile.mesh = SphereMesh.new()
        smile.mesh.radius = 0.018
        smile.mesh.height = 0.03
        smile.material_override = HeroTailor.toot(Color("#4a2e28"))
        smile.position = point
        head.add_child(smile)

    # A hair shine: two pale beads where the light would land first, so the
    # cap of hair has a highlight instead of reading as one flat brown mass.
    var shine_color := Color("#9a6a45")
    for shine_point in [Vector3(-0.10, 0.27, -0.22), Vector3(0.06, 0.29, -0.245)]:
        var shine := MeshInstance3D.new()
        shine.mesh = SphereMesh.new()
        shine.mesh.radius = 0.028
        shine.mesh.height = 0.04
        shine.material_override = HeroTailor.toon(shine_color, 0.10, 0.55)
        shine.position = shine_point
        head.add_child(shine)

    _scarf = MeshInstance3D.new()
    _scarf.mesh = TorusMesh.new()
    _scarf.mesh.inner_radius = 0.22
    _scarf.mesh.outer_radius = 0.34
    _scarf.material_override = scarf_mat
    _scarf.position = Vector3(0, 0.66, 0)
    hips.add_child(_scarf)

    # A round coin purse hangs off the belt's back-left, so even the rear view
    # reads "traveler who owns exactly two important things".
    var purse := MeshInstance3D.new()
    var purse_mesh := SphereMesh.new()
    purse_mesh.radius = 0.085
    purse_mesh.height = 0.15
    purse.mesh = purse_mesh
    purse.material_override = HeroTailor.toot(Color("#8a5e3b"))
    purse.position = Vector3(-0.28, -0.02, -0.28)
    purse.scale = Vector3(1.0, 1.15, 0.8)
    hips.add_child(purse)
    var purse_knot := MeshInstance3D.new()
    var knot_mesh := SphereMesh.new()
    knot_mesh.radius = 0.03
    knot_mesh.height = 0.05
    purse_knot.mesh = knot_mesh
    purse_knot.material_override = gold
    purse_knot.position = Vector3(-0.28, 0.05, -0.28)
    hips.add_child(purse_knot)

    # The cloak hangs from a pivot at the shoulders so it sways as one
    # piece; the tailor cuts the mantle, the three panels, the lining and
    # their gold hems, and hands back the center pair the sway drives.
    var cape_pivot := Node3D.new()
    cape_pivot.name = "CapePivot"
    cape_pivot.position = Vector3(0, 0.62, 0.36)
    cape_pivot.rotation.x = 0.14
    hips.add_child(cape_pivot)
    var cloak := HeroTailor.build_cloak(self, cape_pivot,
        HeroTailor.toon(Color("#3f7a52"), 0.08, 0.82),
        HeroTailor.toon(Color("#9fc49b"), 0.06, 0.88),
        gold)
    _cape = cloak["panel"]
    _cape_hem = cloak["hem"]

    # A soft contact shadow grounds the hero even where the canopy thins the
    # directional light: a quiet dark pool, not a second silhouette.
    _contact_shadow = MeshInstance3D.new()
    var shadow_mesh := CylinderMesh.new()
    shadow_mesh.top_radius = 0.30
    shadow_mesh.bottom_radius = 0.38
    shadow_mesh.height = 0.012
    shadow_mesh.radial_segments = 20
    _contact_shadow.mesh = shadow_mesh
    var shadow_material := StandardMaterial3D.new()
    shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow_material.albedo_color = Color(0.04, 0.07, 0.05, 0.17)
    shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    shadow_material.no_depth_test = false
    _contact_shadow.mesh.material = shadow_material
    _contact_shadow.position = Vector3(0, 0.015, 0)
    _contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_contact_shadow)
    var scarf_tail := MeshInstance3D.new()
    scarf_tail.mesh = BoxMesh.new()
    scarf_tail.mesh.size = Vector3(0.16, 0.42, 0.055)
    scarf_tail.material_override = scarf_mat
    scarf_tail.position = Vector3(-0.20, 0.39, 0.20)
    scarf_tail.rotation.z = -0.18
    hips.add_child(scarf_tail)

    HeroTailor.build_arm(self, "LeftArmPivot", Vector3(-0.37, 0.58, 0), skin_shadow, tunic_light)
    var right_arm := HeroTailor.build_arm(self, "RightArmPivot", Vector3(0.37, 0.58, 0), skin_shadow, tunic_light)
    HeroTailor.build_leg(self, "LeftLegPivot", Vector3(-0.18, 0.02, 0), trousers, boots)
    HeroTailor.build_leg(self, "RightLegPivot", Vector3(0.18, 0.02, 0), trousers, boots)

    # A leather patch on each knee, sewn where a traveler actually kneels.
    for knee_side in [-1.0, 1.0]:
        var knee := get_node_or_null("Model/Hips/%sPivot" % ("Left" if knee_side < 0.0 else "Right"))
        if knee == null:
            continue
        var patch := MeshInstance3D.new()
        var patch_mesh := SphereMesh.new()
        patch_mesh.radius = 0.075
        patch_mesh.height = 0.05
        patch.mesh = patch_mesh
        patch.material_override = HeroTailor.toot(Color("#7a5236"))
        patch.position = Vector3(0, -0.28, -0.115)
        patch.scale = Vector3(1.0, 0.6, 0.75)
        knee.add_child(patch)

    _hat_pivot = HeroTailor.build_hat(self, scarf_mat)

    # The staff is attached to the hand and is purely cosmetic; automatic
    # lantern combat is implemented by the game, never by this prop.
    var staff_pivot := Node3D.new()
    staff_pivot.name = "StaffPivot"
    _staff_pivot = staff_pivot
    right_arm.add_child(staff_pivot)
    staff_pivot.position = Vector3(0, -0.43, -0.05)
    var staff := MeshInstance3D.new()
    var staff_mesh := CylinderMesh.new()
    staff_mesh.top_radius = 0.026
    staff_mesh.bottom_radius = 0.035
    staff_mesh.height = 1.65
    staff.mesh = staff_mesh
    staff.material_override = HeroTailor.toot(Color("#8a5e3b"))
    staff.rotation.z = -0.12
    staff.position = Vector3(0.12, -0.26, 0)
    staff_pivot.add_child(staff)
    var crown := Node3D.new()
    crown.name = "LanternCrown"
    crown.position = Vector3(0.21, 0.49, 0)
    staff_pivot.add_child(crown)
    var lantern_frame_top := MeshInstance3D.new()
    lantern_frame_top.mesh = TorusMesh.new()
    lantern_frame_top.mesh.inner_radius = 0.13
    lantern_frame_top.mesh.outer_radius = 0.18
    lantern_frame_top.material_override = gold
    lantern_frame_top.rotation.x = PI * 0.5
    crown.add_child(lantern_frame_top)
    # Embers that escaped the core circle the crown; the pivot turns them all,
    # so the orbit costs one transform per frame instead of one per spark.
    _spark_pivot = Node3D.new()
    _spark_pivot.name = "LanternSparks"
    crown.add_child(_spark_pivot)
    for spark_index in range(3):
        var spark := MeshInstance3D.new()
        var spark_mesh := SphereMesh.new()
        spark_mesh.radius = 0.022
        spark_mesh.height = 0.04
        spark.mesh = spark_mesh
        spark.material_override = HeroTailor.emissive(Color("#ffe9ad"), 2.6)
        var spark_angle := TAU * float(spark_index) / 3.0
        spark.position = Vector3(sin(spark_angle) * 0.22, 0.06 + 0.05 * cos(spark_angle * 2.0), cos(spark_angle) * 0.22)
        _spark_pivot.add_child(spark)
    _lantern_core = MeshInstance3D.new()
    _lantern_core.mesh = SphereMesh.new()
    _lantern_core.mesh.radius = 0.145
    _lantern_core.mesh.height = 0.29
    _lantern_core.material_override = HeroTailor.emissive(Color("#ffe49a"), 3.0)
    crown.add_child(_lantern_core)
    _lantern_light = OmniLight3D.new()
    _lantern_light.light_color = Color("#ffd990")
    _lantern_light.light_energy = 1.35
    _lantern_light.omni_range = 7.5
    _lantern_light.shadow_enabled = false
    crown.add_child(_lantern_light)
    # The lamp's cage and glass go on last, so the light sits inside a built
    # thing -- four gold posts, a foot ring, a finial and a breath of glass.
    HeroTailor.dress_lantern(crown, gold)

func _build_animations() -> void:
    var player := AnimationPlayer.new()
    player.name = "AnimationPlayer"
    add_child(player)
    var library := AnimationLibrary.new()

    var idle := HeroRigAnim.make_idle()
    var walk := HeroRigAnim.make_walk()
    var swing := HeroRigAnim.make_swing()
    library.add_animation("idle", idle)
    library.add_animation("walk", walk)
    library.add_animation("swing", swing)
    player.add_animation_library("", library)

    animation_tree = AnimationTree.new()
    animation_tree.name = "AnimationTree"
    add_child(animation_tree)
    animation_tree.anim_player = NodePath("../AnimationPlayer")
    animation_tree.tree_root = HeroRigAnim.blend_tree()
    animation_tree.active = true
    set_motion(0.0, 0.0)

func set_walk_motion(walk_amount: float) -> void:
    _walk_target = clampf(walk_amount, 0.0, 1.0)

func set_motion(walk_amount: float, swing_amount: float) -> void:
    set_walk_motion(walk_amount)
    _swing_target = clampf(swing_amount, 0.0, 1.0)

func trigger_swing() -> void:
    _swing_target = 1.0

func set_happy(value: bool) -> void:
    _happy = value

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value

func _process(delta: float) -> void:
    _time += delta
    if _swing_target > 0.0:
        _swing_target = maxf(0.0, _swing_target - delta * 2.7)
    _walk_current = lerpf(_walk_current, _walk_target, 1.0 - exp(-delta * 10.0))
    _swing_current = lerpf(_swing_current, _swing_target, 1.0 - exp(-delta * 18.0))
    # A slow, soft blink keeps the hero feeling alive between adventures.
    # Only the eye meshes squash — never the legs, arms or model root, which
    # the animation blend graph owns.
    _blink_timer -= delta
    if _blink_timer <= 0.0:
        _blink_timer = randf_range(2.4, 5.2)
        _blink_time = 0.16
    var blink_squash := 1.0
    if _blink_time > 0.0:
        _blink_time = maxf(0.0, _blink_time - delta)
        blink_squash = 0.12 if _blink_time > 0.04 else lerpf(0.12, 1.0, 1.0 - _blink_time / 0.04)
    for eye: MeshInstance3D in _eye_meshes:
        if is_instance_valid(eye):
            eye.scale.y = blink_squash
    # The lantern staff sways a breath with the walk; the arm pivots above
    # stay owned by the AnimationTree so the walk/swing tests keep passing.
    if _staff_pivot and is_instance_valid(_staff_pivot):
        var sway := sin(_time * 2.0) * 0.03 + _walk_current * sin(_time * 7.0) * 0.05
        if _reduced_motion:
            sway *= 0.25
        _staff_pivot.rotation.x = sway
    if animation_tree:
        animation_tree.set("parameters/Locomotion/blend_amount", _walk_current)
        animation_tree.set("parameters/MoveLayer/blend_amount", _swing_current)
    if _model:
        # Soothing a wisp and levelling up both call set_happy(). A short hop and
        # a brighter lantern are the visible thank-you; reduced motion calms the
        # hop but keeps the light.
        var hop := absf(sin(_time * 7.0)) * 0.09 if _happy and not _reduced_motion else 0.0
        _model.position.y = lerpf(_model.position.y, hop, 1.0 - exp(-delta * 14.0))
    if _lantern_light:
        var pulse := 1.0 if _reduced_motion else 1.0 + sin(_time * 2.2) * 0.07
        # The lantern dims and reddens as warmth falls, so being hurt is visible
        # in the WORLD rather than only on a HUD number. Bright gold at full
        # warmth, a small ember at the end -- never off, never grey.
        _lantern_light.light_energy = (1.55 if _happy else 1.35) * pulse * _warmth_scale()
        _lantern_light.light_color = _lantern_light.light_color.lerp(_warmth_tint(), 1.0 - exp(-delta * 4.0))
    if _lantern_core:
        var s := 1.0 if _reduced_motion else 1.0 + sin(_time * 3.1) * 0.035
        _lantern_core.scale = Vector3(s, s, s)
        var core_material := _lantern_core.material_override as StandardMaterial3D
        if core_material != null:
            core_material.emission_energy_multiplier = (3.0 if _happy else 2.6) * _warmth_scale()
            core_material.emission = core_material.emission.lerp(_warmth_tint(), 1.0 - exp(-delta * 4.0))
    if _scarf:
        _scarf.rotation.z = 0.0 if _reduced_motion else sin(_time * 1.6) * 0.025
    if _hat_pivot and is_instance_valid(_hat_pivot):
        # The hat breathes against the walk: a nod that peaks on each step,
        # folded into the pivot's authored tilt so the base pose never moves.
        var hat_nod := sin(_time * 7.0) * 0.045 * _walk_current
        _hat_pivot.rotation.x = 0.07 + (0.0 if _reduced_motion else hat_nod)
    if _spark_pivot and is_instance_valid(_spark_pivot):
        # Lantern embers circle the crown once every few seconds; Still Forest
        # pins the wheel instead of hiding it, so the sparks stay lit.
        _spark_pivot.rotation.y += 0.0 if _reduced_motion else delta * 1.9
        _spark_pivot.rotation.x = 0.0 if _reduced_motion else sin(_time * 1.3) * 0.18
    if _cape and is_instance_valid(_cape):
        # The cape sways as one cloth: a slow breath plus a walk flutter that
        # rises with pace. Reduced motion keeps a whisper of the breath.
        var flutter := 0.0 if _reduced_motion else _walk_current * sin(_time * 7.4) * 0.085
        var breath := sin(_time * 1.8) * (0.008 if _reduced_motion else 0.022)
        _cape.get_parent().rotation.x = 0.14 + breath + flutter
    if _contact_shadow and is_instance_valid(_contact_shadow):
        # The shadow pool shrinks on the happy hop so the hero truly leaves
        # the ground for a beat; it never fades out entirely.
        var shadow_scale := 1.0 - (_model.position.y if _model else 0.0) * 1.4
        _contact_shadow.scale = Vector3(maxf(0.62, shadow_scale), 1.0, maxf(0.62, shadow_scale))

func set_warmth(fraction: float) -> void:
    ## How full the lantern is, 0..1. Driven by the director each HUD refresh.
    _warmth = clampf(fraction, 0.0, 1.0)

func _warmth_scale() -> float:
    ## Light output by warmth. Floors at 0.45 so a low-warmth lantern is dim
    ## and warm-toned but still lights the path -- the game must never become
    ## unreadable or look like a power outage.
    return lerpf(0.45, 1.0, sqrt(_warmth))

func _warmth_tint() -> Color:
    ## The lantern's colour by warmth: warm gold when thriving, ember when low.
    return Color("#ff8a5e").lerp(Color("#ffd990"), clampf((_warmth - 0.15) / 0.55, 0.0, 1.0))
