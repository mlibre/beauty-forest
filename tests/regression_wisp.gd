extends SceneTree

## Focused regression coverage for wisp movement state and scaling.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var wisp := Wisp.new()
    root.add_child(wisp)
    wisp.setup("Shambler", 1)

    var target := wisp.global_position + Vector3.RIGHT * 5.0
    wisp.apply_slow(0.5, 1.0)
    wisp.tick_behavior(0.4, target, 10.0, 1.0, 1.0)
    var slowed_speed := wisp.velocity.length()

    wisp.tick_behavior(0.7, target, 10.0, 1.0, 1.0)
    var expired_speed := wisp.velocity.length()
    var expected_speed := wisp.move_speed
    print("WISP_SLOW_EXPIRED_SPEED expected=%f actual=%f" % [expected_speed, expired_speed])
    wisp.free()
    await process_frame
    if not is_equal_approx(slowed_speed, expected_speed * 0.5) \
            or not is_equal_approx(expired_speed, expected_speed):
        print("BEAUTY_FOREST_WISP_REGRESSION_FAILED")
        quit(1)
        return

    var regular_big := Wisp.new()
    root.add_child(regular_big)
    regular_big.setup("Shambler", 4, true)
    var regular_big_speed := regular_big.move_speed
    regular_big.free()

    var big_feeling := Wisp.new()
    root.add_child(big_feeling)
    big_feeling.setup("Shambler", 4, true, BeautyContent.FEELINGS[4])
    var big_feeling_speed := big_feeling.move_speed
    var expected_feeling_speed := regular_big_speed * 0.8
    print("WISP_FEELING_SPEED expected=%f actual=%f" % [expected_feeling_speed, big_feeling_speed])
    big_feeling.free()
    await process_frame
    if not is_equal_approx(big_feeling_speed, expected_feeling_speed):
        print("BEAUTY_FOREST_WISP_REGRESSION_FAILED")
        quit(1)
        return

    print("BEAUTY_FOREST_WISP_REGRESSION_OK")
    quit(0)
