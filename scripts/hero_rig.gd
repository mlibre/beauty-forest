class_name HeroRig
extends Node3D

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

func _ready() -> void:
    _build_character()
    _build_animations()

func _build_character() -> void:
    var model := Node3D.new()
    model.name = "Model"
    add_child(model)
    _model = model

    var skin := _toon(Color("#f2c6a5"), 0.06, 0.72)
    var skin_shadow := _toon(Color("#d99b7e"), 0.04, 0.80)
    var hair := _toon(Color("#74492f"), 0.05, 0.86)
    var tunic := _toon(Color("#5ea96b"), 0.10, 0.78)
    var tunic_light := _toon(Color("#83c878"), 0.09, 0.74)
    var trousers := _toot(Color("#445f62"))
    var boots := _toot(Color("#6d4632"))
    var scarf_mat := _toon(Color("#ef8d84"), 0.16, 0.70)
    var gold := _toon(Color("#ffe49a"), 0.45, 0.40)

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
        eye_white.material_override = _toot(Color("#fffaf0"))
        eye_white.position = Vector3(side * 0.105, 0.02, -0.285)
        head.add_child(eye_white)
        _eye_meshes.append(eye_white)
        var pupil := MeshInstance3D.new()
        pupil.mesh = SphereMesh.new()
        pupil.mesh.radius = 0.034
        pupil.mesh.height = 0.062
        pupil.material_override = _toot(Color("#38271f"))
        pupil.position = Vector3(side * 0.105, 0.02, -0.345)
        head.add_child(pupil)
        var cheek := MeshInstance3D.new()
        cheek.mesh = SphereMesh.new()
        cheek.mesh.radius = 0.045
        cheek.mesh.height = 0.025
        cheek.material_override = _toon(Color("#ef9b91"), 0.05, 0.9)
        cheek.position = Vector3(side * 0.17, -0.075, -0.292)
        head.add_child(cheek)

    # Three tiny beads make a readable upward smile without font assets.
    var smile_points := [Vector3(-0.055, -0.095, -0.338), Vector3(0, -0.12, -0.348), Vector3(0.055, -0.095, -0.338)]
    for point: Vector3 in smile_points:
        var smile := MeshInstance3D.new()
        smile.mesh = SphereMesh.new()
        smile.mesh.radius = 0.018
        smile.mesh.height = 0.03
        smile.material_override = _toot(Color("#4a2e28"))
        smile.position = point
        head.add_child(smile)

    _scarf = MeshInstance3D.new()
    _scarf.mesh = TorusMesh.new()
    _scarf.mesh.inner_radius = 0.22
    _scarf.mesh.outer_radius = 0.34
    _scarf.material_override = scarf_mat
    _scarf.position = Vector3(0, 0.66, 0)
    hips.add_child(_scarf)
    var scarf_tail := MeshInstance3D.new()
    scarf_tail.mesh = BoxMesh.new()
    scarf_tail.mesh.size = Vector3(0.16, 0.42, 0.055)
    scarf_tail.material_override = scarf_mat
    scarf_tail.position = Vector3(-0.20, 0.39, 0.20)
    scarf_tail.rotation.z = -0.18
    hips.add_child(scarf_tail)

    _build_arm("LeftArmPivot", Vector3(-0.37, 0.58, 0), skin_shadow, tunic_light)
    var right_arm := _build_arm("RightArmPivot", Vector3(0.37, 0.58, 0), skin_shadow, tunic_light)
    _build_leg("LeftLegPivot", Vector3(-0.18, 0.02, 0), trousers, boots)
    _build_leg("RightLegPivot", Vector3(0.18, 0.02, 0), trousers, boots)

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
    staff.material_override = _toot(Color("#8a5e3b"))
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
    _lantern_core = MeshInstance3D.new()
    _lantern_core.mesh = SphereMesh.new()
    _lantern_core.mesh.radius = 0.145
    _lantern_core.mesh.height = 0.29
    _lantern_core.material_override = _emissive(Color("#ffe49a"), 3.0)
    crown.add_child(_lantern_core)
    _lantern_light = OmniLight3D.new()
    _lantern_light.light_color = Color("#ffd990")
    _lantern_light.light_energy = 1.35
    _lantern_light.omni_range = 7.5
    _lantern_light.shadow_enabled = false
    crown.add_child(_lantern_light)

func _build_arm(node_name: String, pivot_position: Vector3, arm_material: Material, sleeve_material: Material) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = node_name
    pivot.position = pivot_position
    var hips := get_node_or_null("Model/Hips")
    if hips:
        hips.add_child(pivot)
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

func _build_leg(node_name: String, pivot_position: Vector3, trouser_material: Material, boot_material: Material) -> void:
    var pivot := Node3D.new()
    pivot.name = node_name
    pivot.position = pivot_position
    var hips := get_node_or_null("Model/Hips")
    if hips:
        hips.add_child(pivot)
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

func _toot(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    material.metallic = 0.0
    return material

func _toon(color: Color, glow: float, roughness: float) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/soft_toon.gdshader")
    material.set_shader_parameter("base_color", color)
    material.set_shader_parameter("rim_color", Color("#ffe8a8"))
    material.set_shader_parameter("rim_strength", 0.26)
    material.set_shader_parameter("glow", glow)
    material.set_shader_parameter("roughness_value", roughness)
    return material

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    return material

func _build_animations() -> void:
    var player := AnimationPlayer.new()
    player.name = "AnimationPlayer"
    add_child(player)
    var library := AnimationLibrary.new()

    var idle := _make_idle_animation()
    var walk := _make_walk_animation()
    var swing := _make_swing_animation()
    library.add_animation("idle", idle)
    library.add_animation("walk", walk)
    library.add_animation("swing", swing)
    player.add_animation_library("", library)

    animation_tree = AnimationTree.new()
    animation_tree.name = "AnimationTree"
    add_child(animation_tree)
    animation_tree.anim_player = NodePath("../AnimationPlayer")

    var root := AnimationNodeBlendTree.new()
    var locomotion := AnimationNodeBlend2.new()
    var moving_layer := AnimationNodeBlend2.new()
    var idle_node := AnimationNodeAnimation.new()
    idle_node.animation = &"idle"
    var walk_node := AnimationNodeAnimation.new()
    walk_node.animation = &"walk"
    var swing_node := AnimationNodeAnimation.new()
    swing_node.animation = &"swing"
    root.add_node("Locomotion", locomotion, Vector2(320, 120))
    root.add_node("MoveLayer", moving_layer, Vector2(120, 120))
    root.add_node("Idle", idle_node, Vector2(-80, 40))
    root.add_node("Walk", walk_node, Vector2(-80, 120))
    root.add_node("Swing", swing_node, Vector2(-80, 220))
    root.connect_node("Locomotion", 0, "Idle")
    root.connect_node("Locomotion", 1, "MoveLayer")
    root.connect_node("MoveLayer", 0, "Walk")
    root.connect_node("MoveLayer", 1, "Swing")
    root.connect_node("output", 0, "Locomotion")
    animation_tree.tree_root = root
    animation_tree.active = true
    set_motion(0.0, 0.0)

func _make_idle_animation() -> Animation:
    var animation := Animation.new()
    animation.length = 2.4
    animation.loop_mode = Animation.LOOP_LINEAR
    _add_vector_track(animation, "Model/Hips:position", Vector3(0, 0.78, 0), Vector3(0, 0.805, 0), Vector3(0, 0.78, 0), [0.0, 1.2, 2.4])
    _add_vector_track(animation, "Model/Hips/LeftArmPivot:rotation", Vector3(0.06, 0, -0.08), Vector3(0.10, 0, -0.10), Vector3(0.06, 0, -0.08), [0.0, 1.2, 2.4])
    _add_vector_track(animation, "Model/Hips/RightArmPivot:rotation", Vector3(-0.08, 0, 0.08), Vector3(-0.03, 0, 0.11), Vector3(-0.08, 0, 0.08), [0.0, 1.2, 2.4])
    return animation

func _make_walk_animation() -> Animation:
    var animation := Animation.new()
    animation.length = 0.72
    animation.loop_mode = Animation.LOOP_LINEAR
    _add_vector_track(animation, "Model/Hips/LeftLegPivot:rotation", Vector3(0.52, 0, 0), Vector3(-0.52, 0, 0), Vector3(0.52, 0, 0), [0.0, 0.36, 0.72])
    _add_vector_track(animation, "Model/Hips/RightLegPivot:rotation", Vector3(-0.52, 0, 0), Vector3(0.52, 0, 0), Vector3(-0.52, 0, 0), [0.0, 0.36, 0.72])
    _add_vector_track(animation, "Model/Hips/LeftArmPivot:rotation", Vector3(-0.42, 0, -0.08), Vector3(0.42, 0, -0.08), Vector3(-0.42, 0, -0.08), [0.0, 0.36, 0.72])
    _add_vector_track(animation, "Model/Hips/RightArmPivot:rotation", Vector3(0.42, 0, 0.08), Vector3(-0.42, 0, 0.08), Vector3(0.42, 0, 0.08), [0.0, 0.36, 0.72])
    _add_vector_track(animation, "Model/Hips:position", Vector3(0, 0.78, 0), Vector3(0, 0.83, 0), Vector3(0, 0.78, 0), [0.0, 0.18, 0.36, 0.54, 0.72])
    return animation

func _make_swing_animation() -> Animation:
    var animation := Animation.new()
    animation.length = 0.52
    animation.loop_mode = Animation.LOOP_NONE
    _add_vector_track(animation, "Model/Hips/RightArmPivot:rotation", Vector3(-0.15, 0, 0.12), Vector3(-1.15, 0, -0.20), Vector3(-0.15, 0, 0.12), [0.0, 0.17, 0.34, 0.52])
    _add_vector_track(animation, "Model/Hips/RightArmPivot/StaffPivot:rotation", Vector3(0, 0, 0), Vector3(0.32, -0.22, -0.16), Vector3(0, 0, 0), [0.0, 0.17, 0.34, 0.52])
    _add_vector_track(animation, "Model/Hips:rotation", Vector3(0, 0, 0), Vector3(-0.08, 0.16, 0), Vector3(0, 0, 0), [0.0, 0.20, 0.52])
    return animation

func _add_vector_track(animation: Animation, track_path: String, from: Vector3, middle: Vector3, to: Vector3, times: Array) -> void:
    var track := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(track, NodePath(track_path))
    animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
    animation.track_insert_key(track, float(times[0]), from)
    if times.size() >= 3:
        animation.track_insert_key(track, float(times[1]), middle)
    animation.track_insert_key(track, float(times[-1]), to)

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
