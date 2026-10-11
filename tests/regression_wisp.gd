extends TestCase

## Focused regression coverage for wisp movement state and scaling.

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_WISP_REGRESSION"
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
    await frames(1)
    if not ok(is_equal_approx(slowed_speed, expected_speed * 0.5) \
            and is_equal_approx(expired_speed, expected_speed),
            "a slowed wisp must run at half speed and return to full once the slow expires (slowed %f, expired %f, full %f)" % [
                slowed_speed, expired_speed, expected_speed]):
        stop(null, suite_name)
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
    await frames(1)
    if not ok(is_equal_approx(big_feeling_speed, expected_feeling_speed),
            "a Big Feeling must move at %f, the big wisp speed calmed by 0.8 (got %f)" % [expected_feeling_speed, big_feeling_speed]):
        stop(null, suite_name)
        return

    # Still Forest has to still every animated channel a wisp owns. The boss
    # light breathes via sin() and was the one channel that never consulted the
    # setting, so a player who asked for stillness still got a pulsing light.
    if not await _check_boss_light_respects_still_forest():
        stop(null, suite_name)
        return

    finish(null, "BEAUTY_FOREST_WISP_REGRESSION")

func _check_boss_light_respects_still_forest() -> bool:
    for enabled in [false, true]:
        var wisp := Wisp.new()
        root.add_child(wisp)
        wisp.setup("Shambler", 3, true)
        wisp.set_reduced_motion(enabled)
        var light: Light3D = null
        for child: Node in wisp.find_children("*", "Light3D", true, false):
            light = child
            break
        if light == null:
            wisp.free()
            await frames(1)
            fail("the big wisp has no light to still")
            return false

        # The breath is driven by Time.get_ticks_msec(), so the sample has to
        # span real wall-clock time or every read lands inside one period.
        var lowest := INF
        var highest := -INF
        var target := wisp.global_position + Vector3(5.0, 0.0, 0.0)
        var started := Time.get_ticks_msec()
        while Time.get_ticks_msec() - started < 1200:
            wisp.tick_behavior(1.0 / 60.0, target, 40.0, 1.0, 1.0)
            lowest = minf(lowest, light.light_energy)
            highest = maxf(highest, light.light_energy)
        var swing: float = highest - lowest
        print("BOSS_LIGHT_SWING reduced_motion=%s swing=%.5f" % [enabled, swing])

        if enabled and swing > 0.001:
            wisp.free()
            await frames(1)
            fail("the boss light still breathes with Still Forest on (%.5f)" % swing)
            return false
        if not enabled and swing < 0.01:
            wisp.free()
            await frames(1)
            fail("the boss light never breathes, so this test cannot see it (%.5f)" % swing)
            return false
        wisp.free()
        await frames(1)
    return true
