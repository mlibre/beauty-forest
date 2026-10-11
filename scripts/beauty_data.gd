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
## Stable throwaway directory for a script run that never named a profile.
static var _unscoped_profile := ""

## Point persistence at an isolated directory (tests, previews, demos). Pass an
## empty string to go back to the real player profile.
static func use_test_profile(directory: String) -> void:
    if not directory.is_empty():
        _unscoped_profile = ""
    if directory.is_empty():
        _profile_save_path = ""
        _profile_settings_path = ""
        return
    DirAccess.make_dir_recursive_absolute(directory)
    _profile_save_path = directory.path_join("beauty_forest_save.json")
    _profile_settings_path = directory.path_join("beauty_forest_settings.cfg")

## True when this process was launched as a script (godot --script tests/...gd).
## Such a process is a tool, not the game: it must never write the real player
## profile, and eleven of the fourteen suites had no TestProfile.begin() to say
## so. regression_ui saved text_scale = 2.0 into the player's own config, which
## then made every later run of that suite fail its own layout checks -- the
## suite depended on a clean disk it never guaranteed.
static func _is_script_run() -> bool:
    for argument in OS.get_cmdline_args():
        if argument == "--script" or argument.ends_with(".gd"):
            return true
    return false

## The profile this process may write to. Un-redirected script runs get an
## automatic throwaway directory instead of the player's real files, so a suite
## that forgets TestProfile.begin() fails visibly (writes nowhere useful)
## rather than silently corrupting a profile. TestProfile.begin() still wins, so
## a suite that wants a named directory keeps it.
##
## The fallback is cached: it has to be the SAME directory for the life of the
## process, or a save followed by a load lands in two different throwaway
## folders and the round trip silently reads empty.
static func _write_path_for(overridden: String, fallback: String) -> String:
    if not overridden.is_empty():
        return overridden
    if not _is_script_run():
        return fallback
    if _unscoped_profile.is_empty():
        var scratch := "user://test_profiles/unscoped_%d" % Time.get_ticks_usec()
        DirAccess.make_dir_recursive_absolute(scratch)
        _unscoped_profile = scratch
    return _unscoped_profile.path_join(fallback.get_file())

static func save_path() -> String:
    return _write_path_for(_profile_save_path, SAVE_PATH)

static func settings_path() -> String:
    return _write_path_for(_profile_settings_path, SETTINGS_PATH)

static func default_meta() -> Dictionary:
    return {
        "version": 2,
        "runs": 0,
        "best_floor": 0,
        "wisps_soothed": 0,
        "facts": 0,
        "facts_from_wisps": 0,
        "dragons_sung": 0,
        "style": "standard",
        "stickers": [],
        "facts_learned": [],
    }

## What happened to the satchel this session, if anything went wrong.
##
## A read failure must never be persistable as a new profile. load_meta() used
## to answer "unreadable" and "brand new player" with the same empty dict, so a
## crash-truncated file made 400 runs of history vanish on the next ordinary
## save -- the blank dict was written straight over the only copy. Now an
## unreadable satchel is MOVED ASIDE first, so the bytes are still on disk to
## recover by hand, and the empty profile the game continues with is marked as a
## read failure so save_meta() can tell them apart.
static var _meta_read_failed := false
## True only while an unreadable file still SITS AT the live save path, which
## happens when moving it aside failed. Then the next save would destroy the only
## remaining copy, so it is refused. Once the file is safely aside the live path is
## free and saving works normally again; the quarantined bytes stay untouched
## either way.
static var _meta_write_blocked := false

static func meta_read_failed() -> bool:
    return _meta_read_failed

## Move an unreadable file aside instead of overwriting it. Returns the backup
## path, or "" when the move failed and the original is still in place.
##
## The name is stamped per SECOND, so two quarantines in the same second collide
## -- the second finds the first already there and overwrites it. That made this
## hard to test (the suite had to guess this format to plant a blocking path) and
## easy to get wrong, so the format lives in one named function instead of being
## spelled out at the call site and again in the test.
static func _quarantine(path: String, label: String) -> String:
    var backup := quarantine_path(path)
    var error := DirAccess.rename_absolute(path, backup)
    if error != OK:
        push_warning("Could not set the damaged %s aside (%s); leaving it in place." % [label, error_string(error)])
        return ""
    push_warning("The %s could not be read, so it was kept at %s rather than overwritten." % [label, backup])
    return backup

## Where a damaged file at `path` gets moved. Exposed so a test can plant the
## exact path this will try and make a rename fail on purpose.
static func quarantine_path(path: String) -> String:
    return "%s.corrupt-%s" % [path, Time.get_datetime_string_from_system()
        .replace(":", "-").replace("T", "_")]

static func load_meta() -> Dictionary:
    var target := save_path()
    _meta_read_failed = false
    _meta_write_blocked = false
    if not FileAccess.file_exists(target):
        return default_meta()
    var file := FileAccess.open(target, FileAccess.READ)
    if file == null:
        push_warning("Could not open the Beauty Forest satchel; using a fresh one.")
        _meta_read_failed = true
        _meta_write_blocked = _quarantine(target, "satchel").is_empty()
        return default_meta()
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        # The realistic shape: a crash or a full disk mid-write leaves a partial
        # JSON file, which is exactly what the next save would overwrite.
        push_warning("The Beauty Forest satchel was unreadable; using a fresh one.")
        _meta_read_failed = true
        _meta_write_blocked = _quarantine(target, "satchel").is_empty()
        return default_meta()
    return _clean_meta(parsed as Dictionary)

static func save_meta(meta: Dictionary) -> bool:
    # Refuse only while an unreadable satchel is still sitting at the live save
    # path -- i.e. when moving it aside failed. Writing now would destroy the only
    # copy of a file we already failed to understand. Once it is safely aside,
    # saving resumes and the preserved bytes are never touched again.
    if _meta_write_blocked:
        push_warning("Not writing over a satchel that could not be read this session; the damaged file is kept aside.")
        return false
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
    for key in ["runs", "best_floor", "wisps_soothed", "facts", "facts_from_wisps", "dragons_sung"]:
        clean[key] = _stored_count(source.get(key, 0))
    var stored_style := String(source.get("style", "standard"))
    clean["style"] = stored_style if BeautyContent.STYLE_DATA.has(stored_style) else "standard"
    # Test the value we are about to iterate, not the source dictionary: an
    # older or hand-edited satchel may simply not carry the key, and
    # `source.get(key, []) is Array` is true for the missing case too.
    var stored_stickers: Variant = source.get("stickers", [])
    if stored_stickers is Array:
        var seen := {}
        var stickers: Array[String] = []
        for value: Variant in stored_stickers as Array:
            if typeof(value) != TYPE_STRING:
                continue
            var key := String(value)
            if seen.has(key):
                continue
            seen[key] = true
            stickers.append(key)
        clean["stickers"] = stickers.slice(-40)
    var stored_facts: Variant = source.get("facts_learned", [])
    if stored_facts is Array:
        var learned: Array[String] = []
        for value: Variant in stored_facts as Array:
            if typeof(value) == TYPE_STRING:
                learned.append(String(value))
        var retained_facts: Array = learned.slice(-120)
        clean["facts_learned"] = retained_facts
        # `facts` is how many facts are in the book, so it is derived from the
        # book rather than carried forward. Keeping the larger of the two let a
        # stale counter outlive the entries it counted, which is how the pause
        # card and the memory book came to disagree.
        clean["facts"] = retained_facts.size()
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

## Settings have the same data-loss shape as the satchel, and it is milder but
## still real: a truncated config made every accessibility choice silently revert
## to stock, including the ones a player needs to play comfortably at all. Keep
## the damaged file aside for the same reason, and do not overwrite it.
static func load_settings() -> Dictionary:
    var result := default_settings()
    var config := ConfigFile.new()
    if config.load(settings_path()) != OK:
        # A missing file is a first run; only a file that EXISTS and will not
        # parse is damage worth preserving.
        if FileAccess.file_exists(settings_path()):
            push_warning("Beauty Forest settings could not be read, so the damaged file was kept aside.")
            _quarantine(settings_path(), "settings")
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

## The loadout arithmetic: worn charms and verses turned into multipliers.
##
## `worn` is the list of things the hero has on -- each entry a
## `{"key": String, "tier": int}` -- so a charm can be owned twice and both
## copies worn. Content tables live in BeautyContent.

## Multiplicative charm effects. These COMPOUND across the loadout, which is
## what makes a deeper walk feel stronger rather than merely bigger.
const CHARM_MULTIPLIERS := ["speed", "cooldown", "song_damage", "damage_taken",
    "soul", "pickup", "dash_cooldown", "lullaby_window"]
## Flat charm effects, which ADD. See `charm_effects_at` for why the two kinds
## are scaled differently by a charm's tier.
const CHARM_ADDITIONS := ["max_hp", "heart_heal", "invulnerable"]

static func charm_effects(worn: Array) -> Dictionary:
    var effects := {}
    for field: String in CHARM_MULTIPLIERS:
        effects[field] = 1.0
    for field: String in CHARM_ADDITIONS:
        effects[field] = 0.0
    for entry: Dictionary in worn:
        var scaled := BeautyContent.charm_effects_at(String(entry.get("key", "")), int(entry.get("tier", 1)))
        for field: String in CHARM_MULTIPLIERS:
            if scaled.has(field):
                effects[field] = float(effects[field]) * float(scaled[field])
        for field: String in CHARM_ADDITIONS:
            if scaled.has(field):
                effects[field] = float(effects[field]) + float(scaled[field])
    return effects

static func stanza_effects(equipped: Dictionary) -> Dictionary:
    var effects := {
        "pulse_slow": 0.0, "song_cap": 0, "song_damage": 1.0, "heart_magnet": false,
        "pulse_radius": 0.0, "pulse_cooldown": 1.0, "song_speed": 1.0, "song_life": 0.0,
        "note_cooldown": 1.0, "distant_soul": 1.0, "pulse_damage": 1.0,
        "heart_rate": 0.0, "soul": 1.0,
    }
    for stanza: Dictionary in BeautyContent.STANZAS:
        if not _dictionary_flag(equipped, String(stanza["key"])):
            continue
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

## Loadout queries shared by Peddle's cart and the shop shelf UI, so both
## answer "what does the hero own or wear" from the same arithmetic.

## The next tier of `key` the hero does not own yet, or 0 when it owns them all.
static func next_tier(owned: Array, key: String) -> int:
    var best := 0
    for entry: Variant in owned:
        if entry is Dictionary and String((entry as Dictionary).get("key", "")) == key:
            best = maxi(best, int((entry as Dictionary).get("tier", 1)))
    return best + 1 if best < BeautyContent.TIER_SCALES.size() - 1 else 0

static func owns(owned: Array, key: String, tier: int) -> bool:
    for entry: Variant in owned:
        if entry is Dictionary and String((entry as Dictionary).get("key", "")) == key \
                and int((entry as Dictionary).get("tier", 1)) == tier:
            return true
    return false

static func wearing(equipped: Array, key: String, tier: int) -> bool:
    return owns(equipped, key, tier)

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
