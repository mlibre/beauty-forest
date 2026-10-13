class_name HeroRigAnim
extends RefCounted

## The hero's choreography data: the three clips (idle, walk, swing) and the
## blend tree that mixes them, split out of HeroRig when the rig file outgrew
## the 500-line ceiling. Everything here is static assembly of Animation
## resources -- the rig stays the living body that drives them. The track
## paths are load-bearing: they name the pivots HeroTailor builds, so a rename
## on either side is a silent broken pose and must happen on both sides at
## once.

## The blend tree the rig's AnimationTree drives: Idle and Walk under a
## locomotion blend, Swing layered over the moving gait.
static func blend_tree() -> AnimationNodeBlendTree:
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
    return root

static func make_idle() -> Animation:
    var animation := Animation.new()
    animation.length = 2.4
    animation.loop_mode = Animation.LOOP_LINEAR
    add_vector_track(animation, "Model/Hips:position", [Vector3(0, 0.78, 0), Vector3(0, 0.805, 0), Vector3(0, 0.78, 0)], [0.0, 1.2, 2.4])
    add_vector_track(animation, "Model/Hips/LeftArmPivot:rotation", [Vector3(0.06, 0, -0.08), Vector3(0.10, 0, -0.10), Vector3(0.06, 0, -0.08)], [0.0, 1.2, 2.4])
    add_vector_track(animation, "Model/Hips/RightArmPivot:rotation", [Vector3(-0.08, 0, 0.08), Vector3(-0.03, 0, 0.11), Vector3(-0.08, 0, 0.08)], [0.0, 1.2, 2.4])
    return animation

static func make_walk() -> Animation:
    var animation := Animation.new()
    animation.length = 0.72
    animation.loop_mode = Animation.LOOP_LINEAR
    add_vector_track(animation, "Model/Hips/LeftLegPivot:rotation", [Vector3(0.52, 0, 0), Vector3(-0.52, 0, 0), Vector3(0.52, 0, 0)], [0.0, 0.36, 0.72])
    add_vector_track(animation, "Model/Hips/RightLegPivot:rotation", [Vector3(-0.52, 0, 0), Vector3(0.52, 0, 0), Vector3(-0.52, 0, 0)], [0.0, 0.36, 0.72])
    add_vector_track(animation, "Model/Hips/LeftArmPivot:rotation", [Vector3(-0.42, 0, -0.08), Vector3(0.42, 0, -0.08), Vector3(-0.42, 0, -0.08)], [0.0, 0.36, 0.72])
    add_vector_track(animation, "Model/Hips/RightArmPivot:rotation", [Vector3(0.42, 0, 0.08), Vector3(-0.42, 0, 0.08), Vector3(0.42, 0, 0.08)], [0.0, 0.36, 0.72])
    # A walk cycle is two bounce arcs per circuit, so the hips ride five keys:
    # down, rise, down, rise, down. Passing it through as one up-down cycle
    # let the second rise never exist and the hero looked like half a walk.
    add_vector_track(animation, "Model/Hips:position", [Vector3(0, 0.78, 0), Vector3(0, 0.83, 0), Vector3(0, 0.78, 0), Vector3(0, 0.83, 0), Vector3(0, 0.78, 0)], [0.0, 0.18, 0.36, 0.54, 0.72])
    return animation

static func make_swing() -> Animation:
    var animation := Animation.new()
    animation.length = 0.52
    animation.loop_mode = Animation.LOOP_NONE
    # The arm reaches the flourish at 0.17, holds it through the note until
    # 0.34, and returns by 0.52. Dropping the hold key made the arm rebound
    # the instant it reached the pose.
    add_vector_track(animation, "Model/Hips/RightArmPivot:rotation", [Vector3(-0.15, 0, 0.12), Vector3(-1.15, 0, -0.20), Vector3(-1.15, 0, -0.20), Vector3(-0.15, 0, 0.12)], [0.0, 0.17, 0.34, 0.52])
    add_vector_track(animation, "Model/Hips/RightArmPivot/StaffPivot:rotation", [Vector3(0, 0, 0), Vector3(0.32, -0.22, -0.16), Vector3(0.32, -0.22, -0.16), Vector3(0, 0, 0)], [0.0, 0.17, 0.34, 0.52])
    add_vector_track(animation, "Model/Hips:rotation", [Vector3(0, 0, 0), Vector3(-0.08, 0.16, 0), Vector3(0, 0, 0)], [0.0, 0.20, 0.52])
    return animation

## One cubic value track on `animation`, one key per value at the matching
## time: authoring more times than keys would silently drop the ride the
## invisible key was meant to hold.
static func add_vector_track(animation: Animation, track_path: String, values: Array, times: Array) -> void:
    var track := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(track, NodePath(track_path))
    animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
    for index in range(times.size()):
        animation.track_insert_key(track, float(times[index]), values[index])
