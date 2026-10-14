extends "res://tests/support/test_case.gd"
## Focused regression coverage for wisp movement state and scaling.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const Wisp := preload("res://scripts/wisp.gd")

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

    # The gold vulnerability window had the same blind spot: its halo PULSE
    # ran a sine against the wall-clock even with Still Forest on, while the
    # waypoint glow and the boss light had both already learned the setting.
    # The colour and the lift stay (state must read); only the pulse holds.
    if not await _check_gold_halo_respects_still_forest():
        stop(null, suite_name)
        return

    # Happiness is the whole arc of a wisp: sad on arrival, warmer with every
    # step of help, and the face has to carry it — frown to smile, corners
    # below centre to above it.
    if not await _check_happiness_climbs_with_each_help():
        stop(null, suite_name)
        return

    finish(null, "BEAUTY_FOREST_WISP_REGRESSION")

## The mouth corners are the two mouth dots that sit off-centre; their average
## height, in unscaled units, is the frown-to-smile read.
func _corner_lift(wisp: Wisp) -> float:
    var total := 0.0
    var count := 0
    for child: Node in wisp.find_children("*", "MeshInstance3D", true, false):
        var mesh := child as MeshInstance3D
        if mesh == null:
            continue
        if is_equal_approx(absf(mesh.position.x), 0.055) and is_equal_approx(mesh.position.z, -0.39):
            total += mesh.position.y
            count += 1
    if count != 2:
        return NAN
    return total * 0.5 / wisp.visual_scale

func _check_happiness_climbs_with_each_help() -> bool:
    var wisp := Wisp.new()
    root.add_child(wisp)
    wisp.setup("Shambler", 1)
    if not ok(is_equal_approx(wisp.happiness, 0.0),
            "a fresh wisp must arrive sad, happiness was %f" % wisp.happiness):
        wisp.free()
        await frames(1)
        return false
    var sad_lift := _corner_lift(wisp)
    if not ok(not is_nan(sad_lift) and sad_lift < 0.79,
            "a sad wisp's mouth corners must hang below centre (lift %f)" % sad_lift):
        wisp.free()
        await frames(1)
        return false
    # Each soothing pulse is one step of help, so happiness climbs one bite at
    # a time — five pulses, five rises, no plateau until the soul is sung home.
    var bite := wisp.max_health / 6.0
    var previous := wisp.happiness
    for _step in range(5):
        wisp.take_damage(bite)
        if not ok(wisp.happiness > previous,
                "a step of help must raise happiness (%f -> %f)" % [previous, wisp.happiness]):
            wisp.free()
            await frames(1)
            return false
        previous = wisp.happiness
    var happy_lift := _corner_lift(wisp)
    if not ok(not is_nan(happy_lift) and happy_lift > sad_lift,
            "the mouth must smile as happiness climbs (sad %f -> helped %f)" % [sad_lift, happy_lift]):
        wisp.free()
        await frames(1)
        return false
    if not ok(absf(wisp.happiness - 5.0 / 6.0) < 0.01,
            "five sixths of the song gone should be five sixths happy (%f)" % wisp.happiness):
        wisp.free()
        await frames(1)
        return false
    wisp.free()
    await frames(1)
    return true

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

func _check_gold_halo_respects_still_forest() -> bool:
    # The gold window is driven from tick_behavior, but the unit under test is
    # set_gold_window itself: the pulse lives there, so the check holds the
    # window open directly and samples the halo across real wall-clock time --
    # the same clock the sine reads. Still Forest must hold the lift flat at
    # its lit scale; the walk needs to SEE the pulse or the check is blind.
    for enabled in [false, true]:
        var wisp := Wisp.new()
        root.add_child(wisp)
        wisp.setup("Shambler", 3, true)
        wisp.set_reduced_motion(enabled)
        if wisp._halo == null or not is_instance_valid(wisp._halo):
            wisp.free()
            await frames(1)
            fail("the big wisp has no halo for the gold window to lift")
            return false
        for _settle in range(40):
            wisp.set_gold_window(true)
        var lowest := INF
        var highest := -INF
        var started := Time.get_ticks_msec()
        while Time.get_ticks_msec() - started < 900:
            wisp.set_gold_window(true)
            var halo_scale: float = wisp._halo.scale.x
            lowest = minf(lowest, halo_scale)
            highest = maxf(highest, halo_scale)
        var swing: float = highest - lowest
        print("GOLD_HALO_SWING reduced_motion=%s swing=%.5f" % [enabled, swing])
        if enabled and swing > 0.001:
            wisp.free()
            await frames(1)
            fail("the gold halo still pulses with Still Forest on (%.5f)" % swing)
            return false
        if not enabled and swing < 0.01:
            wisp.free()
            await frames(1)
            fail("the gold halo never pulses, so this test cannot see it (%.5f)" % swing)
            return false
        wisp.free()
        await frames(1)
    return true
