class_name BeautyData
extends RefCounted

## Player profile persistence (satchel + gentler-forest settings) and the
## loadout math that turns equipped wares into multipliers. Content tables live
## in BeautyContent.

const SAVE_PATH := "user://beauty_forest_save.json"
const SETTINGS_PATH := "user://beauty_forest_settings.cfg"
const MAX_META_COUNT := 1_000_000_000_000

## Persistence targets. The constants above are the real player profile; tests
## redirect them with use_test_profile() so a test run can never inflate the
## player's Visits/stickers/dragons (which it demonstrably did: dragons_sung
## reached 143 in a real profile).
static var _profile_save_path := ""
static var _profile_settings_path := ""

## Point persistence at an isolated directory (tests, previews, demos). Pass an
## empty string to go back to the real player profile.
static func use_test_profile(directory: String) -> void:
    if directory.is_empty():
        _profile_save_path = ""
        _profile_settings_path = ""
        return
    DirAccess.make_dir_recursive_absolute(directory)
    _profile_save_path = directory.path_join("beauty_forest_save.json")
    _profile_settings_path = directory.path_join("beauty_forest_settings.cfg")

static func save_path() -> String:
    return _profile_save_path if not _profile_save_path.is_empty() else SAVE_PATH

static func settings_path() -> String:
    return _profile_settings_path if not _profile_settings_path.is_empty() else SETTINGS_PATH
static func default_meta() -> Dictionary:
    return {
        "version": 2,
        "runs": 0,
        "best_floor": 0,
        "wisps_soothed": 0,
        "facts": 0,
        "dragons_sung": 0,
        "stickers": [],
        "facts_learned": [],
    }

static func load_meta() -> Dictionary:
    var target := save_path()
    if not FileAccess.file_exists(target):
        return default_meta()
    var file := FileAccess.open(target, FileAccess.READ)
    if file == null:
        push_warning("Could not open the Beauty Forest satchel; using a fresh one.")
        return default_meta()
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_warning("The Beauty Forest satchel was unreadable; using a fresh one.")
        return default_meta()
    return _clean_meta(parsed as Dictionary)

static func save_meta(meta: Dictionary) -> bool:
    var temp_path := save_path() + ".tmp"
    var target := save_path()
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        push_warning("Could not stage the Beauty Forest satchel for saving.")
        return false
    var stored := file.store_string(JSON.stringify(_clean_meta(meta), "  "))
    file.flush()
    var write_error := file.get_error() if stored else ERR_FILE_CANT_WRITE
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(temp_path)
        push_warning("Could not finish saving the Beauty Forest satchel: %s" % error_string(write_error))
        return false
    var replace_error := DirAccess.rename_absolute(temp_path, target)
    if replace_error != OK:
        DirAccess.remove_absolute(temp_path)
        push_warning("Could not replace the Beauty Forest satchel: %s" % error_string(replace_error))
        return false
    return true

static func _clean_meta(source: Dictionary) -> Dictionary:
    var clean := default_meta()
    for key in ["runs", "best_floor", "wisps_soothed", "facts", "dragons_sung"]:
        clean[key] = _stored_count(source.get(key, 0))
    if source.get("stickers", []) is Array:
        var seen := {}
        var stickers: Array[String] = []
        for value: Variant in source["stickers"] as Array:
            if typeof(value) != TYPE_STRING:
                continue
            var key := String(value)
            if seen.has(key):
                continue
            seen[key] = true
            stickers.append(key)
        clean["stickers"] = stickers.slice(-40)
    if source.get("facts_learned", []) is Array:
        var learned: Array[String] = []
        for value: Variant in source["facts_learned"] as Array:
            if typeof(value) == TYPE_STRING:
                learned.append(String(value))
        var retained_facts: Array = learned.slice(-120)
        clean["facts_learned"] = retained_facts
        clean["facts"] = maxi(int(clean["facts"]), retained_facts.size())
    return clean

static func _stored_count(value: Variant) -> int:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return 0
    var number := float(value)
    if not is_finite(number) or number <= 0.0:
        return 0
    if number >= float(MAX_META_COUNT):
        return MAX_META_COUNT
    return int(number)

static func default_settings() -> Dictionary:
    return {
        "reduced_motion": false,
        "text_scale": 1.0,
        "high_contrast": false,
        "damage_taken": 0.70,
        "rhythm_window": 1.40,
        "wisp_speed": 0.85,
        "volume": 0.80,
        "muted": false,
    }

static func load_settings() -> Dictionary:
    var result := default_settings()
    var config := ConfigFile.new()
    if config.load(settings_path()) != OK:
        return result
    result["reduced_motion"] = _setting_bool(config.get_value("cozy", "reduced_motion", false))
    result["text_scale"] = _setting_float(config.get_value("cozy", "text_scale", result["text_scale"]), 0.75, 2.0, result["text_scale"])
    result["high_contrast"] = _setting_bool(config.get_value("cozy", "high_contrast", false))
    result["damage_taken"] = _setting_float(config.get_value("cozy", "damage_taken", result["damage_taken"]), 0.25, 3.0, result["damage_taken"])
    result["rhythm_window"] = _setting_float(config.get_value("cozy", "rhythm_window", result["rhythm_window"]), 0.25, 3.0, result["rhythm_window"])
    result["wisp_speed"] = _setting_float(config.get_value("cozy", "wisp_speed", result["wisp_speed"]), 0.25, 3.0, result["wisp_speed"])
    result["volume"] = _setting_float(config.get_value("audio", "volume", result["volume"]), 0.0, 1.0, result["volume"])
    result["muted"] = _setting_bool(config.get_value("audio", "muted", false))
    return result

static func save_settings(settings: Dictionary) -> bool:
    var clean := _clean_settings(settings)
    var config := ConfigFile.new()
    config.set_value("cozy", "reduced_motion", clean["reduced_motion"])
    config.set_value("cozy", "text_scale", clean["text_scale"])
    config.set_value("cozy", "high_contrast", clean["high_contrast"])
    config.set_value("cozy", "damage_taken", clean["damage_taken"])
    config.set_value("cozy", "rhythm_window", clean["rhythm_window"])
    config.set_value("cozy", "wisp_speed", clean["wisp_speed"])
    config.set_value("audio", "volume", clean["volume"])
    config.set_value("audio", "muted", clean["muted"])
    var temp_path := settings_path() + ".tmp"
    var target := settings_path()
    var write_error := config.save(temp_path)
    if write_error != OK:
        push_warning("Could not save Beauty Forest settings: %s" % error_string(write_error))
        return false
    var replace_error := DirAccess.rename_absolute(temp_path, target)
    if replace_error != OK:
        DirAccess.remove_absolute(temp_path)
        push_warning("Could not replace Beauty Forest settings: %s" % error_string(replace_error))
        return false
    return true

static func _clean_settings(source: Dictionary) -> Dictionary:
    var clean := default_settings()
    for key in ["reduced_motion", "high_contrast", "muted"]:
        clean[key] = _setting_bool(source.get(key, clean[key]))
    clean["text_scale"] = _setting_float(source.get("text_scale", clean["text_scale"]), 0.75, 2.0, clean["text_scale"])
    clean["damage_taken"] = _setting_float(source.get("damage_taken", clean["damage_taken"]), 0.25, 3.0, clean["damage_taken"])
    clean["rhythm_window"] = _setting_float(source.get("rhythm_window", clean["rhythm_window"]), 0.25, 3.0, clean["rhythm_window"])
    clean["wisp_speed"] = _setting_float(source.get("wisp_speed", clean["wisp_speed"]), 0.25, 3.0, clean["wisp_speed"])
    clean["volume"] = _setting_float(source.get("volume", clean["volume"]), 0.0, 1.0, clean["volume"])
    return clean

static func _setting_bool(value: Variant) -> bool:
    return typeof(value) == TYPE_BOOL and bool(value)

static func _setting_float(value: Variant, minimum: float, maximum: float, fallback: float) -> float:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return clampf(fallback, minimum, maximum)
    var number := float(value)
    if not is_finite(number):
        return clampf(fallback, minimum, maximum)
    return clampf(number, minimum, maximum)

static func charm_effects(owned: Dictionary) -> Dictionary:
    var effects := {
        "speed": 1.0, "cooldown": 1.0, "song_damage": 1.0, "damage_taken": 1.0,
        "soul": 1.0, "pickup": 1.0, "dash_cooldown": 1.0, "lullaby_window": 1.0,
        "max_hp": 0.0, "heart_heal": 0.0, "invulnerable": 0.0,
    }
    var equipped := 0
    for charm: Dictionary in BeautyContent.CHARMS:
        var key := String(charm["key"])
        if key == "tea" or not _dictionary_flag(owned, key):
            continue
        equipped += 1
        if equipped > BeautyContent.MAX_CHARMS:
            break
        for effect_key in ["speed", "cooldown", "song_damage", "damage_taken", "soul", "pickup", "dash_cooldown", "lullaby_window"]:
            if charm.has(effect_key):
                effects[effect_key] = float(effects[effect_key]) * float(charm[effect_key])
        for effect_key in ["max_hp", "heart_heal", "invulnerable"]:
            if charm.has(effect_key):
                effects[effect_key] = float(effects[effect_key]) + float(charm[effect_key])
    return effects

static func stanza_effects(equipped: Dictionary) -> Dictionary:
    var effects := {
        "pulse_slow": 0.0, "song_cap": 0, "song_damage": 1.0, "heart_magnet": false,
        "pulse_radius": 0.0, "pulse_cooldown": 1.0, "song_speed": 1.0, "song_life": 0.0,
        "note_cooldown": 1.0, "distant_soul": 1.0, "pulse_damage": 1.0,
        "heart_rate": 0.0, "soul": 1.0,
    }
    var equipped_count := 0
    for stanza: Dictionary in BeautyContent.STANZAS:
        if not _dictionary_flag(equipped, String(stanza["key"])):
            continue
        equipped_count += 1
        if equipped_count > BeautyContent.MAX_STANZAS:
            break
        for effect_key in stanza.keys():
            if effect_key in ["key", "name", "description"]:
                continue
            if effect_key in ["song_cap", "pulse_radius", "song_life", "pulse_slow", "heart_rate"]:
                effects[effect_key] = float(effects[effect_key]) + float(stanza[effect_key])
            elif effect_key == "heart_magnet":
                effects[effect_key] = bool(effects[effect_key]) or bool(stanza[effect_key])
            else:
                effects[effect_key] = float(effects[effect_key]) * float(stanza[effect_key])
    return effects

static func _dictionary_flag(flags: Dictionary, key: String) -> bool:
    var value: Variant = flags.get(key, false)
    if typeof(value) != TYPE_BOOL:
        return false
    return bool(value)

static func mote_verse_effects(verse_key: String) -> Dictionary:
    for verse: Dictionary in BeautyContent.MOTE_VERSES:
        if String(verse["key"]) == verse_key:
            return verse
    return {}
