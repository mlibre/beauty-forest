extends "res://tests/support/test_case.gd"
## The loadout arithmetic: every verse and every charm applies (the old caps
## were the level-curve bug one level up), a malformed entry is ignored, and
## weighted picks honor their own odds.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyData := preload("res://scripts/beauty_data.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_DATA_RULES"
    TestProfile.begin("data_rules")
    call_deferred("_run")

func _run() -> void:
    _test_loadout_is_uncapped()
    _test_weighted_pick_boundaries()
    finish(null, "BEAUTY_FOREST_DATA_RULES")

func _test_loadout_is_uncapped() -> void:
    # This suite used to prove the caps held: that only the first two canonical
    # stanzas and the first three canonical charms had any effect. Both caps are
    # gone -- they were the same bug as the old level curve, one level up -- so
    # the assertion inverts. Now EVERY song applies and EVERY charm applies, and
    # a malformed entry is ignored rather than counted.
    var every_stanza := {}
    for stanza: Dictionary in BeautyContent.STANZAS:
        every_stanza[String(stanza["key"])] = true
    var stanza_effect: Dictionary = BeautyData.stanza_effects(every_stanza)
    ok(float(stanza_effect.get("pulse_radius", 0.0)) > 0.0,
        "every verse must apply once there is no cap (pulse_radius %f)" % float(stanza_effect.get("pulse_radius", 0.0)))
    # The Grove and the Dawn both widen the pulse, so two verses must stack.
    ok(is_equal_approx(float(stanza_effect.get("pulse_radius", 0.0)), 1.0),
        "the two widening verses must compound, not be truncated")

    var every_charm: Array = []
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) == "tea":
            continue
        every_charm.append({"key": String(charm["key"]), "tier": 1})
    var charm_effect: Dictionary = BeautyData.charm_effects(every_charm)
    # The Wool Scarf is the only flat-warmth charm, so with no cap it is worth
    # exactly its 30 -- which the old cap made unreachable.
    ok(is_equal_approx(float(charm_effect.get("max_hp", -1.0)), 30.0),
        "the scarf's warmth must count once, uncapped (got %f)" % float(charm_effect.get("max_hp", -1.0)))
    # Multiplicative charms COMPOUND across the loadout, which is what makes a
    # deeper walk feel stronger rather than merely bigger. Ember Mitten (+20%)
    # and Acorn Pocket (+10%) both warm song-notes, so owning both must be worth
    # 1.32 -- more than either alone. Only one charm carries `speed`, so this is
    # checked on the multiplier the shelf actually stacks.
    ok(is_equal_approx(float(charm_effect.get("song_damage", 0.0)), 1.10 * 1.20 * 0.90),
        "every warming charm must compound with no cap (song_damage %f)" % float(charm_effect.get("song_damage", 0.0)))
    ok(is_equal_approx(float(charm_effect.get("speed", 1.0)), 1.15),
        "the one speedier charm must apply exactly once")

    # A malformed entry must be skipped, not applied: a blank key has no charm
    # behind it and must not contribute an effect.
    var with_junk: Array = every_charm.duplicate()
    with_junk.append({"key": "", "tier": 1})
    with_junk.append({"key": "not-a-charm", "tier": 1})
    var junk_effect: Dictionary = BeautyData.charm_effects(with_junk)
    ok(is_equal_approx(float(junk_effect.get("speed", 0.0)), float(charm_effect.get("speed", 0.0))),
        "a charm key with no ware behind it must change nothing")
    ok(is_equal_approx(float(junk_effect.get("max_hp", -1.0)), 30.0),
        "a charm key with no ware behind it must not add warmth")

func _test_weighted_pick_boundaries() -> void:
    # A weighted pick must honor weight/total odds exactly: roll r belongs to
    # the first entry with cumulative weight above r. The loop used to accept
    # the boundary roll for the current entry (<= 0 after subtracting), so the
    # first pool entry stole one outcome from its neighbor and a 1,1 pool could
    # never yield its second entry at all.
    for floor_number in [1, 5]:
        var pool := BeautyContent.wisp_pool(floor_number)
        var total := 0
        for entry: Array in pool:
            total += int(entry[1])
        var checked := 0
        for s in range(400):
            seed(s)
            var roll := randi() % total
            seed(s)
            var actual := BeautyContent.pick_wisp_type(floor_number)
            var remaining := roll
            var expected := "Shambler"
            for entry: Array in pool:
                var weight := int(entry[1])
                if remaining < weight:
                    expected = String(entry[0])
                    break
                remaining -= weight
            ok(actual == expected, "seed %d rolled %d on floor %d: picked %s instead of %s" % [s, roll, floor_number, actual, expected])
            checked += 1
        ok(checked == 400, "the weighted-pick sweep did not run")
    randomize()
