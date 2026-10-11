extends TestCase

## Focused regression for player-driven locomotion and the automatic hero swing.

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_PLAYER"
    call_deferred("_run")

func _horizontal_speed(player: Player) -> float:
    return Vector2(player.velocity.x, player.velocity.z).length()

func _run() -> void:
    for action: StringName in [&"bf_left", &"bf_right", &"bf_forward", &"bf_back", &"bf_dash"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    for action: StringName in [&"bf_left", &"bf_right", &"bf_forward", &"bf_back"]:
        Input.action_release(action)

    var player := Player.new()
    root.add_child(player)
    await frames(1)

    # Main triggers the cosmetic swing during its parent physics callback, before
    # Player performs the same frame's locomotion update. Reproduce that ordering.
    player.set_physics_process(false)
    player.set_control_enabled(true)
    player.set_touch_vector(Vector2(0.0, -1.0))
    player.hero.trigger_swing()
    player._physics_process(1.0 / 60.0)
    player.hero._process(1.0 / 60.0)
    var swing_blend := float(player.hero.animation_tree.get("parameters/MoveLayer/blend_amount"))
    ok(swing_blend > 0.0, "the automatic swing was cancelled by the locomotion update")

    # Dead zone: a resting-thumb wobble must stay still, not sprint.
    player.set_control_enabled(true)
    player.set_touch_vector(Vector2(0.05, 0.0))
    player._physics_process(1.0 / 60.0)
    ok(_horizontal_speed(player) < 0.01, "micro touch deflection moved the hero at %f u/s" % _horizontal_speed(player))

    # Analog magnitude: half deflection should stroll at half speed.
    player.set_touch_vector(Vector2(0.0, -0.5))
    player._physics_process(1.0 / 60.0)
    ok(absf(_horizontal_speed(player) - player.move_speed * 0.5) < 0.05, "half touch deflection ran at %f u/s instead of ~%f" % [_horizontal_speed(player), player.move_speed * 0.5])

    # Full deflection still runs at full speed.
    player.set_touch_vector(Vector2(0.0, -1.0))
    player._physics_process(1.0 / 60.0)
    ok(absf(_horizontal_speed(player) - player.move_speed) < 0.05, "full touch deflection ran at %f u/s instead of ~%f" % [_horizontal_speed(player), player.move_speed])

    # Digital keyboard diagonals are unchanged: still full speed, due east.
    player.set_touch_vector(Vector2.ZERO)
    Input.action_press("bf_right")
    Input.action_press("bf_back")
    player._physics_process(1.0 / 60.0)
    Input.action_release("bf_right")
    Input.action_release("bf_back")
    ok(absf(_horizontal_speed(player) - player.move_speed) < 0.05, "keyboard diagonal ran at %f u/s instead of ~%f" % [_horizontal_speed(player), player.move_speed])
    ok(absf(player.velocity.x - player.move_speed) < 0.05 and absf(player.velocity.z) < 0.05, "keyboard diagonal drifted off +X: %s" % str(player.velocity))

    # A dash started from analog input still bursts at full dash speed.
    player.set_touch_vector(Vector2(0.0, -0.5))
    player._physics_process(1.0 / 60.0)
    player.trigger_dash(player.move_direction)
    player._physics_process(1.0 / 60.0)
    ok(absf(_horizontal_speed(player) - player.move_speed * 2.6) < 0.05, "analog dash burst at %f u/s instead of ~%f" % [_horizontal_speed(player), player.move_speed * 2.6])
    ok(player.dash_cooldown > 0.0, "dash did not start its cooldown")

    # Disabling control parks the hero even with a live touch vector.
    player.set_touch_vector(Vector2(0.0, -1.0))
    player.set_control_enabled(false)
    player._physics_process(1.0 / 60.0)
    ok(_horizontal_speed(player) < 0.01, "disabled hero kept drifting at %f u/s" % _horizontal_speed(player))
    ok(player.move_direction.length_squared() < 0.001, "disabled hero kept a stale move_direction")

    finish(player, "BEAUTY_FOREST_PLAYER")
