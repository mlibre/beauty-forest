extends "res://tests/support/test_case.gd"
## The satchel's integrity: what the player profile saves, reads back, and
## refuses. The save-guard quarantine work lives beside it in
## regression_data_guard.gd; the loadout arithmetic lives in
## regression_data_rules.gd. One suite per question, none over 500 lines.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyData := preload("res://scripts/beauty_data.gd")
const BeautyLore := preload("res://scripts/beauty_lore.gd")

var had_save := false
var had_settings := false
var original_save := PackedByteArray()
var original_settings := PackedByteArray()

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_DATA_REGRESSION"
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
    _test_missing_collection_keys_keep_the_satchel()
    _test_save_failures_preserve_data()
    _test_profile_isolation()
    _test_unscoped_script_runs_are_isolated_too()
    _restore_file(BeautyData.save_path(), had_save, original_save)
    _restore_file(BeautyData.settings_path(), had_settings, original_settings)
    _remove_path(BeautyData.save_path() + ".tmp")
    _remove_path(BeautyData.settings_path() + ".tmp")
    # finish() tears the throwaway profile down (TestProfile.end()) itself.
    finish(null, "BEAUTY_FOREST_DATA_REGRESSION")

func _test_sticker_tables_agree() -> void:
    # "Century of Kindness" once went missing from the toast-line table, so
    # earning it announced generic fallback words instead of what it was. The
    # two tables now share one home in BeautyContent, and the check guards the
    # shape every reader depends on: a name AND a line per sticker.
    for key: String in BeautyContent.STICKERS.keys():
        ok(not BeautyContent.sticker_name(key).is_empty(),
            "sticker '%s' has no journal name" % key)
        ok(not BeautyContent.sticker_line(key).is_empty(),
            "sticker '%s' has no award line" % key)
        ok(BeautyContent.sticker_line(key) != "a gentle thing worth remembering",
            "sticker '%s' fell back to the generic toast line" % key)

func _test_meta_recovery() -> void:
    var facts: Array[String] = []
    for index in range(121):
        facts.append(String(BeautyLore.FACTS[index % BeautyLore.FACTS.size()]))
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
    ok(int(loaded.get("runs", -1)) == 0, "a boolean must not become a visit count")
    ok(int(loaded.get("best_floor", -1)) == 0, "a malformed floor must fall back to zero")
    ok(int(loaded.get("wisps_soothed", -1)) == 7, "valid meta counters must survive loading")
    # `facts` counts what is in the book, so it is derived from the journal and
    # must NOT outlive the entries it counted. It previously took the larger of
    # the stored counter and the retained history, which is how the pause card
    # and the ending tally came to read 480 while the memory book listed 120 --
    # and those 120 were 96 duplicate copies of 24 facts. Nothing reads `facts`
    # as a threshold or gate, so deriving it is the honest meaning.
    ok(int(loaded.get("facts", -1)) == 120,
        "the fact counter must match the journal it counts, not a stale larger total")
    var learned: Array = loaded.get("facts_learned", [])
    ok(learned.size() == 120, "learned facts must honor the 120-fact journal bound")
    if learned.size() == 120:
        ok(String(learned[0]) == facts[1], "the oldest fact outside the bound must be discarded")
        ok(String(learned[-1]) == facts[-1], "the newest learned fact must survive bounded history")
    var stickers: Array = loaded.get("stickers", [])
    ok(stickers.size() == 40, "sanitized stickers must honor the 40-sticker journal bound")
    if stickers.size() == 40:
        ok(String(stickers[0]) == "sticker_02", "the oldest sticker outside the bound must be discarded")
        ok(String(stickers[-1]) == "sticker_41", "the newest sticker must survive bounded history")

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
    ok(loaded == BeautyData.default_meta(), "null and container meta values must recover to defaults")

func _test_settings_recovery() -> void:
    var config := ConfigFile.new()
    config.set_value("cozy", "reduced_motion", "false")
    config.set_value("cozy", "text_scale", "wide")
    config.set_value("cozy", "high_contrast", 0)
    config.set_value("audio", "muted", 1)
    config.set_value("cozy", "damage_taken", null)
    config.set_value("cozy", "rhythm_window", NAN)
    config.set_value("audio", "volume", {})
    ok(config.save(BeautyData.settings_path()) == OK, "the malformed settings fixture must be writable")
    var loaded: Dictionary = BeautyData.load_settings()
    var defaults: Dictionary = BeautyData.default_settings()
    ok(not bool(loaded.get("reduced_motion", true)), "a non-boolean must not become true")
    ok(is_equal_approx(float(loaded.get("text_scale", -1.0)), float(defaults["text_scale"])), "a malformed text scale must use its default")
    ok(not bool(loaded.get("high_contrast", true)), "an integer zero must not become true")
    ok(not bool(loaded.get("muted", true)), "an integer one must not become true")
    ok(is_equal_approx(float(loaded.get("damage_taken", 0.0)), float(defaults["damage_taken"])), "a null damage setting must use its default")
    ok(is_equal_approx(float(loaded.get("rhythm_window", 0.0)), float(defaults["rhythm_window"])), "a non-finite rhythm setting must use its default")
    ok(is_equal_approx(float(loaded.get("volume", 0.0)), float(defaults["volume"])), "a container volume setting must use its default")

func _test_save_round_trips() -> void:
    var facts: Array[String] = []
    for index in range(121):
        facts.append(String(BeautyLore.FACTS[index % BeautyLore.FACTS.size()]))
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
    ok(BeautyData.save_meta(malformed), "a valid normalized meta save must succeed")
    var loaded_meta: Dictionary = BeautyData.load_meta()
    ok(int(loaded_meta.get("version", -1)) == 2, "saving must write the current meta version")
    ok(int(loaded_meta.get("runs", -1)) == 0, "saving must reject a null counter")
    ok(int(loaded_meta.get("best_floor", 0)) <= BeautyData.MAX_META_COUNT, "an extreme counter must be bounded before future increments")
    ok((loaded_meta.get("stickers", []) as Array) == ["first_nap", "big_hug"], "saving must normalize sticker values and duplicates")
    var saved_facts: Array = loaded_meta.get("facts_learned", [])
    ok(saved_facts.size() == 120, "a save/load round trip must retain only the newest 120 learned facts")
    if saved_facts.size() == 120:
        ok(String(saved_facts[0]) == facts[1], "bounded saved facts must start after the oldest entry")
        ok(String(saved_facts[-1]) == facts[-1], "the newest saved fact must survive the bound")

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
    ok(BeautyData.save_settings(malformed_settings), "a valid normalized settings save must succeed")
    var loaded_settings: Dictionary = BeautyData.load_settings()
    ok(not bool(loaded_settings.get("reduced_motion", true)), "saving must reject a null flag")
    ok(is_equal_approx(float(loaded_settings.get("text_scale", 0.0)), 2.0), "saved text scale must be clamped")
    ok(not bool(loaded_settings.get("high_contrast", false)), "saving must reject an integer flag")
    ok(not bool(loaded_settings.get("muted", true)), "saving must reject a string flag")
    ok(is_equal_approx(float(loaded_settings.get("damage_taken", 0.0)), 0.25), "saved damage must be clamped")
    ok(is_equal_approx(float(loaded_settings.get("rhythm_window", 0.0)), 3.0), "saved rhythm must be clamped")
    ok(is_equal_approx(float(loaded_settings.get("volume", 0.0)), 1.0), "saved volume must be clamped")
    ok(not FileAccess.file_exists(BeautyData.save_path() + ".tmp"), "a committed meta save must not leave its staging file")
    ok(not FileAccess.file_exists(BeautyData.settings_path() + ".tmp"), "committed settings must not leave their staging file")

func _test_missing_collection_keys_keep_the_satchel() -> void:
    # An older build (or a hand-edited file) simply has no `stickers` or
    # `facts_learned` key. The guard used to test the defaulted value, which is
    # true for the missing case too, so the body re-indexed the absent key,
    # threw, and `load_meta` handed back a near-empty dict that the next
    # `save_meta` then committed over the player's real history.
    var sparse: Dictionary = {"runs": 42, "best_floor": 9, "dragons_sung": 3, "wisps_soothed": 31}
    var clean: Dictionary = BeautyData._clean_meta(sparse)
    ok(int(clean.get("runs", -1)) == 42, "a save missing its collection keys must keep its counters")
    ok(int(clean.get("best_floor", -1)) == 9, "a save missing its collection keys must keep its best floor")
    ok(int(clean.get("wisps_soothed", -1)) == 31, "a save missing its collection keys must keep its soothed count")
    ok((clean.get("stickers", []) as Array).is_empty(), "a missing sticker list must normalize to empty")
    ok((clean.get("facts_learned", []) as Array).is_empty(), "a missing fact list must normalize to empty")

    # The whole point: a load/save round trip must not shrink the satchel.
    var rich: Dictionary = BeautyData.default_meta()
    rich["runs"] = 42
    rich["best_floor"] = 9
    rich["dragons_sung"] = 3
    rich["stickers"] = ["first_nap", "big_hug"]
    ok(BeautyData.save_meta(rich), "the populated satchel fixture must save")
    var handle := FileAccess.open(BeautyData.save_path(), FileAccess.WRITE)
    handle.store_string(JSON.stringify(sparse, "  "))
    handle.close()
    var loaded: Dictionary = BeautyData.load_meta()
    ok(int(loaded.get("runs", -1)) == 42, "loading a keyless satchel must not wipe its counters")
    ok(BeautyData.save_meta(loaded), "re-saving a keyless satchel must succeed")
    var reread: Dictionary = BeautyData.load_meta()
    ok(int(reread.get("runs", -1)) == 42, "a keyless satchel must survive a full load/save cycle")
    ok(int(reread.get("best_floor", -1)) == 9, "a keyless satchel must keep its best floor across a round trip")
    ok(BeautyData.save_meta(rich), "restoring the populated satchel must succeed")

func _test_save_failures_preserve_data() -> void:
    var stable_meta := BeautyData.default_meta()
    stable_meta["runs"] = 23
    ok(BeautyData.save_meta(stable_meta), "the stable meta save fixture must succeed")
    _remove_path(BeautyData.save_path() + ".tmp")
    ok(DirAccess.make_dir_absolute(BeautyData.save_path() + ".tmp") == OK, "the blocked meta staging fixture must be creatable")
    ok(not BeautyData.save_meta({"runs": 999}), "a blocked meta staging path must report failure")
    ok(int(BeautyData.load_meta().get("runs", -1)) == 23, "a failed meta save must preserve the prior save")

    var stable_settings := BeautyData.default_settings()
    stable_settings["text_scale"] = 1.25
    ok(BeautyData.save_settings(stable_settings), "the stable settings fixture must succeed")
    _remove_path(BeautyData.settings_path() + ".tmp")
    ok(DirAccess.make_dir_absolute(BeautyData.settings_path() + ".tmp") == OK, "the blocked settings staging fixture must be creatable")
    ok(not BeautyData.save_settings({"text_scale": 2.0}), "a blocked settings staging path must report failure")
    ok(is_equal_approx(float(BeautyData.load_settings().get("text_scale", 0.0)), 1.25), "a failed settings save must preserve prior settings")
    _remove_path(BeautyData.save_path() + ".tmp")
    _remove_path(BeautyData.settings_path() + ".tmp")

func _test_profile_isolation() -> void:
    ## The whole point of the redirect: a test run must not touch the player's
    ## real profile. It demonstrably did (dragons_sung reached 143), so assert
    ## a sentinel written through the test profile is absent from the real one.
    var sentinel := BeautyData.default_meta()
    sentinel["runs"] = 987654
    ok(BeautyData.save_meta(sentinel), "the isolation sentinel save must succeed")
    ok(BeautyData.save_path() != BeautyData.SAVE_PATH, "the test profile must redirect away from the real save")
    ok(BeautyData.settings_path() != BeautyData.SETTINGS_PATH, "the test profile must redirect away from the real settings")
    ok(int(BeautyData.load_meta().get("runs", -1)) == 987654, "the isolated profile must be the one persistence reads")
    if FileAccess.file_exists(BeautyData.SAVE_PATH):
        var real_file := FileAccess.open(BeautyData.SAVE_PATH, FileAccess.READ)
        if real_file != null:
            var real_text := real_file.get_as_text()
            ok(not real_text.contains("987654"), "the test run leaked its sentinel into the player's real save")
    var stable := BeautyData.default_meta()
    stable["runs"] = 5
    ok(BeautyData.save_meta(stable), "restoring a clean isolated meta must succeed")

func _test_unscoped_script_runs_are_isolated_too() -> void:
    ## The redirect above only protects suites that remember to call
    ## TestProfile.begin(). Eleven of the fourteen did not, and one of them saved
    ## text_scale = 2.0 into the player's own config -- which then made every
    ## later run of that suite fail its own layout checks, because the suite
    ## depended on a clean disk it never guaranteed. So forget the redirect
    ## entirely and the write target must STILL not be the real profile.
    #
    ## This plants nothing and reads nothing outside the disposable directory.
    ## A regression must not need to damage the developer's player profile to
    ## prove itself -- an earlier revision wrote the real config on purpose and
    ## then had to restore it, which is the same class of hazard it was testing
    ## for. Asserting the resolved PATH is enough: if save_path() and
    ## settings_path() do not point at the real files, no write can land there.
    var named := TestProfile.directory()
    BeautyData.use_test_profile("")
    ok(BeautyData.save_path() != BeautyData.SAVE_PATH,
        "a script run with no test profile must not write the player's real save")
    ok(BeautyData.settings_path() != BeautyData.SETTINGS_PATH,
        "a script run with no test profile must not write the player's real settings")
    ok(BeautyData.save_path().contains("test_profiles"),
        "an un-redirected script run must land in the disposable directory, got %s" % BeautyData.save_path())
    ok(BeautyData.settings_path().contains("test_profiles"),
        "an un-redirected script run must land in the disposable directory, got %s" % BeautyData.settings_path())

    # The resolved path must be STABLE, or a save followed by a load lands in two
    # different throwaway folders and the round trip silently reads empty.
    var resolved := BeautyData.save_path()
    ok(BeautyData.save_path() == resolved, "the throwaway save path changed between two reads")
    ok(BeautyData.settings_path() == BeautyData.settings_path(), "the throwaway settings path changed between two reads")
    ok(resolved != BeautyData.settings_path().path_join("../beauty_forest_save.json"),
        "the throwaway save path must not resolve out of its directory")

    # And the round trip must actually work inside that directory, or suites that
    # forget the redirect would silently lose every write.
    var sentinel := BeautyData.default_settings()
    sentinel["text_scale"] = 1.75
    ok(BeautyData.save_settings(sentinel), "the unscoped settings sentinel must save somewhere")
    ok(FileAccess.file_exists(BeautyData.settings_path()),
        "an un-redirected script run wrote nothing at all (path %s)" % BeautyData.settings_path())
    ok(is_equal_approx(float(BeautyData.load_settings().get("text_scale", 0.0)), 1.75),
        "an un-redirected script run must be able to read back what it wrote")
    var meta_sentinel := BeautyData.default_meta()
    meta_sentinel["runs"] = 424242
    ok(BeautyData.save_meta(meta_sentinel), "the unscoped meta sentinel must save somewhere")
    ok(int(BeautyData.load_meta().get("runs", -1)) == 424242,
        "an un-redirected script run must be able to read back the satchel it wrote")

    # Put the named profile back so the rest of the suite still reads its fixture.
    BeautyData.use_test_profile(named)
    ok(BeautyData.save_path() == BeautyData._profile_save_path,
        "an explicitly named test profile must still win over the script-run fallback")

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
        ok(false, "could not write fixture %s" % path)
        return
    file.store_string(JSON.stringify(value, "  "))
    file.flush()

func _remove_path(path: String) -> void:
    if DirAccess.dir_exists_absolute(path):
        DirAccess.remove_absolute(path)
    elif FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
