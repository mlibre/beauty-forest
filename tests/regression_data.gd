extends SceneTree

var failures: Array[String] = []
var had_save := false
var had_settings := false
var original_save := PackedByteArray()
var original_settings := PackedByteArray()

func _initialize() -> void:
    # Every fixture below writes/deletes real files; keep them disposable.
    TestProfile.begin("data")
    if FileAccess.file_exists(BeautyData.save_path()):
        had_save = true
        var save_file := FileAccess.open(BeautyData.save_path(), FileAccess.READ)
        if save_file != null:
            original_save = save_file.get_buffer(save_file.get_length())
    if FileAccess.file_exists(BeautyData.settings_path()):
        had_settings = true
        var settings_file := FileAccess.open(BeautyData.settings_path(), FileAccess.READ)
        if settings_file != null:
            original_settings = settings_file.get_buffer(settings_file.get_length())
    call_deferred("_run")

func _run() -> void:
    _test_sticker_tables_agree()
    _test_meta_recovery()
    _test_settings_recovery()
    _test_save_round_trips()
    _test_save_failures_preserve_data()
    _test_loadout_limits()
    _test_weighted_pick_boundaries()
    _test_profile_isolation()
    _restore_file(BeautyData.save_path(), had_save, original_save)
    _restore_file(BeautyData.settings_path(), had_settings, original_settings)
    _remove_path(BeautyData.save_path() + ".tmp")
    _remove_path(BeautyData.settings_path() + ".tmp")
    TestProfile.end()
    if failures.is_empty():
        print("BEAUTY_FOREST_DATA_REGRESSION_OK")
        quit(0)
        return
    for failure: String in failures:
        printerr("FAIL: ", failure)
    quit(1)

func _test_meta_recovery() -> void:
    var facts: Array[String] = []
    for index in range(121):
        facts.append(String(BeautyContent.FACTS[index % BeautyContent.FACTS.size()]))
    var mixed_facts: Array = []
    mixed_facts.append_array(facts)
    mixed_facts.append(null)
    var sticker_values: Array[String] = []
    for index in range(42):
        sticker_values.append("sticker_%02d" % index)
    var mixed_stickers: Array = []
    mixed_stickers.append_array(sticker_values)
    mixed_stickers.append(sticker_values[0])
    mixed_stickers.append(99)
    var malformed := {
        "version": 2,
        "runs": true,
        "best_floor": "not-a-floor",
        "wisps_soothed": 7,
        "facts": facts.size(),
        "dragons_sung": 2,
        "stickers": mixed_stickers,
        "facts_learned": mixed_facts,
    }
    _write_json(BeautyData.save_path(), malformed)
    var loaded: Dictionary = BeautyData.load_meta()
    check(int(loaded.get("runs", -1)) == 0, "a boolean must not become a visit count")
    check(int(loaded.get("best_floor", -1)) == 0, "a malformed floor must fall back to zero")
    check(int(loaded.get("wisps_soothed", -1)) == 7, "valid meta counters must survive loading")
    check(int(loaded.get("facts", -1)) == facts.size(), "a higher lifetime fact counter must survive bounded history")
    var learned: Array = loaded.get("facts_learned", [])
    check(learned.size() == 120, "learned facts must honor the 120-fact journal bound")
    if learned.size() == 120:
        check(String(learned[0]) == facts[1], "the oldest fact outside the bound must be discarded")
        check(String(learned[-1]) == facts[-1], "the newest learned fact must survive bounded history")
    var stickers: Array = loaded.get("stickers", [])
    check(stickers.size() == 40, "sanitized stickers must honor the 40-sticker journal bound")
    if stickers.size() == 40:
        check(String(stickers[0]) == "sticker_02", "the oldest sticker outside the bound must be discarded")
        check(String(stickers[-1]) == "sticker_41", "the newest sticker must survive bounded history")

    _write_json(BeautyData.save_path(), {
        "runs": null,
        "best_floor": {},
        "wisps_soothed": [],
        "facts": false,
        "dragons_sung": "many",
        "stickers": {},
        "facts_learned": "not-an-array",
    })
    loaded = BeautyData.load_meta()
    check(loaded == BeautyData.default_meta(), "null and container meta values must recover to defaults")

func _test_settings_recovery() -> void:
    var config := ConfigFile.new()
    config.set_value("cozy", "reduced_motion", "false")
    config.set_value("cozy", "text_scale", "wide")
    config.set_value("cozy", "high_contrast", 0)
    config.set_value("audio", "muted", 1)
    config.set_value("cozy", "damage_taken", null)
    config.set_value("cozy", "rhythm_window", NAN)
    config.set_value("audio", "volume", {})
    check(config.save(BeautyData.settings_path()) == OK, "the malformed settings fixture must be writable")
    var loaded: Dictionary = BeautyData.load_settings()
    var defaults: Dictionary = BeautyData.default_settings()
    check(not bool(loaded.get("reduced_motion", true)), "a non-boolean must not become true")
    check(is_equal_approx(float(loaded.get("text_scale", -1.0)), float(defaults["text_scale"])), "a malformed text scale must use its default")
    check(not bool(loaded.get("high_contrast", true)), "an integer zero must not become true")
    check(not bool(loaded.get("muted", true)), "an integer one must not become true")
    check(is_equal_approx(float(loaded.get("damage_taken", 0.0)), float(defaults["damage_taken"])), "a null damage setting must use its default")
    check(is_equal_approx(float(loaded.get("rhythm_window", 0.0)), float(defaults["rhythm_window"])), "a non-finite rhythm setting must use its default")
    check(is_equal_approx(float(loaded.get("volume", 0.0)), float(defaults["volume"])), "a container volume setting must use its default")

func _test_save_round_trips() -> void:
    var facts: Array[String] = []
    for index in range(121):
        facts.append(String(BeautyContent.FACTS[index % BeautyContent.FACTS.size()]))
    var mixed_facts: Array = []
    mixed_facts.append_array(facts)
    mixed_facts.append(null)
    var malformed: Dictionary = {
        "version": 999,
        "runs": null,
        "best_floor": 1e100,
        "wisps_soothed": 4,
        "facts": 0,
        "dragons_sung": 1,
        "stickers": ["first_nap", "first_nap", null, "big_hug"],
        "facts_learned": mixed_facts,
    }
    check(BeautyData.save_meta(malformed), "a valid normalized meta save must succeed")
    var loaded_meta: Dictionary = BeautyData.load_meta()
    check(int(loaded_meta.get("version", -1)) == 2, "saving must write the current meta version")
    check(int(loaded_meta.get("runs", -1)) == 0, "saving must reject a null counter")
    check(int(loaded_meta.get("best_floor", 0)) <= BeautyData.MAX_META_COUNT, "an extreme counter must be bounded before future increments")
    check((loaded_meta.get("stickers", []) as Array) == ["first_nap", "big_hug"], "saving must normalize sticker values and duplicates")
    var saved_facts: Array = loaded_meta.get("facts_learned", [])
    check(saved_facts.size() == 120, "a save/load round trip must retain only the newest 120 learned facts")
    if saved_facts.size() == 120:
        check(String(saved_facts[0]) == facts[1], "bounded saved facts must start after the oldest entry")
        check(String(saved_facts[-1]) == facts[-1], "the newest saved fact must survive the bound")

    var malformed_settings: Dictionary = {
        "reduced_motion": null,
        "text_scale": 99.0,
        "high_contrast": 1,
        "muted": "false",
        "damage_taken": -5.0,
        "rhythm_window": 4.0,
        "wisp_speed": 0.5,
        "volume": 2.0,
    }
    check(BeautyData.save_settings(malformed_settings), "a valid normalized settings save must succeed")
    var loaded_settings: Dictionary = BeautyData.load_settings()
    check(not bool(loaded_settings.get("reduced_motion", true)), "saving must reject a null flag")
    check(is_equal_approx(float(loaded_settings.get("text_scale", 0.0)), 2.0), "saved text scale must be clamped")
    check(not bool(loaded_settings.get("high_contrast", false)), "saving must reject an integer flag")
    check(not bool(loaded_settings.get("muted", true)), "saving must reject a string flag")
    check(is_equal_approx(float(loaded_settings.get("damage_taken", 0.0)), 0.25), "saved damage must be clamped")
    check(is_equal_approx(float(loaded_settings.get("rhythm_window", 0.0)), 3.0), "saved rhythm must be clamped")
    check(is_equal_approx(float(loaded_settings.get("volume", 0.0)), 1.0), "saved volume must be clamped")
    check(not FileAccess.file_exists(BeautyData.save_path() + ".tmp"), "a committed meta save must not leave its staging file")
    check(not FileAccess.file_exists(BeautyData.settings_path() + ".tmp"), "committed settings must not leave their staging file")

func _test_save_failures_preserve_data() -> void:
    var stable_meta := BeautyData.default_meta()
    stable_meta["runs"] = 23
    check(BeautyData.save_meta(stable_meta), "the stable meta save fixture must succeed")
    _remove_path(BeautyData.save_path() + ".tmp")
    check(DirAccess.make_dir_absolute(BeautyData.save_path() + ".tmp") == OK, "the blocked meta staging fixture must be creatable")
    check(not BeautyData.save_meta({"runs": 999}), "a blocked meta staging path must report failure")
    check(int(BeautyData.load_meta().get("runs", -1)) == 23, "a failed meta save must preserve the prior save")

    var stable_settings := BeautyData.default_settings()
    stable_settings["text_scale"] = 1.25
    check(BeautyData.save_settings(stable_settings), "the stable settings fixture must succeed")
    _remove_path(BeautyData.settings_path() + ".tmp")
    check(DirAccess.make_dir_absolute(BeautyData.settings_path() + ".tmp") == OK, "the blocked settings staging fixture must be creatable")
    check(not BeautyData.save_settings({"text_scale": 2.0}), "a blocked settings staging path must report failure")
    check(is_equal_approx(float(BeautyData.load_settings().get("text_scale", 0.0)), 1.25), "a failed settings save must preserve prior settings")
    _remove_path(BeautyData.save_path() + ".tmp")
    _remove_path(BeautyData.settings_path() + ".tmp")

func _test_profile_isolation() -> void:
    ## The whole point of the redirect: a test run must not touch the player's
    ## real profile. It demonstrably did (dragons_sung reached 143), so assert
    ## a sentinel written through the test profile is absent from the real one.
    var sentinel := BeautyData.default_meta()
    sentinel["runs"] = 987654
    check(BeautyData.save_meta(sentinel), "the isolation sentinel save must succeed")
    check(BeautyData.save_path() != BeautyData.SAVE_PATH, "the test profile must redirect away from the real save")
    check(BeautyData.settings_path() != BeautyData.SETTINGS_PATH, "the test profile must redirect away from the real settings")
    check(int(BeautyData.load_meta().get("runs", -1)) == 987654, "the isolated profile must be the one persistence reads")
    if FileAccess.file_exists(BeautyData.SAVE_PATH):
        var real_file := FileAccess.open(BeautyData.SAVE_PATH, FileAccess.READ)
        if real_file != null:
            var real_text := real_file.get_as_text()
            check(not real_text.contains("987654"), "the test run leaked its sentinel into the player's real save")
    var stable := BeautyData.default_meta()
    stable["runs"] = 5
    check(BeautyData.save_meta(stable), "restoring a clean isolated meta must succeed")

func _test_loadout_limits() -> void:
    var every_stanza := {}
    for stanza: Dictionary in BeautyContent.STANZAS:
        every_stanza[String(stanza["key"])] = true
    var stanza_effect: Dictionary = BeautyData.stanza_effects(every_stanza)
    check(is_zero_approx(float(stanza_effect.get("pulse_radius", -1.0))), "only the first two canonical stanzas may apply")

    var every_charm := {}
    for charm: Dictionary in BeautyContent.CHARMS:
        every_charm[String(charm["key"])] = true
    every_charm["boots"] = null
    var charm_effect: Dictionary = BeautyData.charm_effects(every_charm)
    check(is_equal_approx(float(charm_effect.get("max_hp", -1.0)), 30.0), "only three canonical charms may apply")
    check(is_equal_approx(float(charm_effect.get("speed", -1.0)), 1.0), "a null charm flag must not apply an effect")

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
            check(actual == expected, "seed %d rolled %d on floor %d: picked %s instead of %s" % [s, roll, floor_number, actual, expected])
            checked += 1
        check(checked == 400, "the weighted-pick sweep did not run")
    randomize()

func _restore_file(path: String, existed: bool, contents: PackedByteArray) -> void:
    if existed:
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file != null:
            file.store_buffer(contents)
            file.flush()
    elif FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)

func _write_json(path: String, value: Dictionary) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        check(false, "could not write fixture %s" % path)
        return
    file.store_string(JSON.stringify(value, "  "))
    file.flush()

func _remove_path(path: String) -> void:
    if DirAccess.dir_exists_absolute(path):
        DirAccess.remove_absolute(path)
    elif FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _test_sticker_tables_agree() -> void:
    # Two parallel tables describe the same stickers: BeautyContent.STICKERS
    # holds the name shown in the journal, and RunState._sticker_description()
    # holds the line shown in the award toast. "Century of Kindness" was
    # missing from the second, so earning it announced the generic fallback
    # text instead of what it actually was. Keep them in step.
    for key: String in BeautyContent.STICKERS.keys():
        check(RunState.STICKER_DESCRIPTIONS.has(key),
            "sticker '%s' has a name but no description" % key)
    for key: String in RunState.STICKER_DESCRIPTIONS.keys():
        check(BeautyContent.STICKERS.has(key), "sticker '%s' is described but has no name" % key)
