class_name RunState
extends Node3D

## Run state, player profile progression and the HUD feed for one walk. The
## director wires this up in main.gd; combat extends it in RunCombat and floor
## construction in RunWorld.

enum Mode { MENU, PLAYING, PAUSED, SHOP, JOURNAL, SETTINGS, DEAD, ENDING }

const CAMERA_OFFSET := Vector3(6.4, 8.8, 6.4)
const CHIME_TONES: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0]
const LULLABY_STEP := 0.80
const CHIME_GATHER_RADIUS := 4.0
## The award-toast line for each sticker. Keys mirror BeautyContent.STICKERS,
## which holds the name the journal shows; both tables must stay in step.
const STICKER_DESCRIPTIONS := {
    "first_nap": "dozed off and got tucked in by wisps",
    "dragon_friend": "sang Snoozle to sleep",
    "big_hug": "soothed a Very Big Wisp",
    "pacifist": "cleared a floor untouched",
    "shopper": "bought something cozy",
    "fact_finder": "learned ten facts from Mote",
    "feeling_friend": "sat with a Big Feeling",
    "curious": "listened to a curious wisp",
    "long_lullaby": "sang a distant wisp all the way home",
    "kindling": "wandered down to floor six",
    "century": "guided a hundred lost wisps home",
}
const CHIME_GATHER_SPEED := 2.4
const START_POSITIONS := Vector3(-0.7, 1.45, 0.4)
const QUIT_DRAIN_SECONDS := 0.5

var mode := Mode.MENU
var previous_mode := Mode.PLAYING
var selected_style := "standard"
var settings: Dictionary = {}
var meta: Dictionary = {}
var world: ForestWorld
var player: Player
var camera: Camera3D
var ui: GameUI
var audio: AudioDirector
var mote: Node3D
var mote_core: MeshInstance3D
var mote_light: OmniLight3D
## The diegetic "go here" glow. Lives in the world, not the HUD, so it reads as
## part of the scene rather than another overlay.
var _waypoint: CozyWaypoint

var floor_number := 1
var dungeon: Dictionary = {}
var region: Dictionary = {}
var floor_modifier: Dictionary = {}
var hp := 100.0
var hp_max := 100.0
var level_hp_bonus := 0.0
var attack := 10.0
var level := 1
var xp := 0
var xp_next := 10
var sparkles := 0
var charms_owned: Dictionary = {}
var charms_equipped: Dictionary = {}
var stanzas_equipped: Dictionary = {"petals": true, "echoes": true}
## What a full-slot swap pushed aside, so Peddle or Mote can name it.
var _evicted := ""
var _evicted_stanza := ""
var mote_verse_key := ""
var charm_effects: Dictionary = {}
var stanza_effects: Dictionary = {}
var verse_effects: Dictionary = {}
var hit_this_floor := false
var play_seconds := 0.0
var pulse_cooldown := 0.0
var note_cooldown := 0.0
var invulnerable_time := 0.0
var wisps: Array[Wisp] = []
var notes: Array[SongNote] = []
var stair_visible := true
var merchant_exists := false
var dragon_exists := false
var dragon_finale := false
var ending_pending := false
var ending_countdown := 0.0
var _rng := RandomNumberGenerator.new()
var _mote_line_timer := 24.0
var _mote_line := "The forest keeps your place warm."
var _mote_seed := 0.0
var _ui_refresh := 0.0
var _next_petal_shower := 38.0
var _lullaby_active := false
var _lullaby_kind := "dragon"
var _lullaby_target: Wisp
var _lullaby_step := -1
var _lullaby_timer := 0.0
var _lullaby_gold := false
var _dragon_hits := 0
var _feeling_round := 1
var _feeling_hits := 0
var _feeling_rest := 0
var _quitting := false
var _soothes_this_floor := 0
var _mote_joy := 0.0

func _gameplay_controls_enabled() -> bool:
    return mode == Mode.PLAYING and not ending_pending

func _shop_state() -> Dictionary:
    var current_mote: Dictionary = {}
    for verse: Dictionary in BeautyContent.MOTE_VERSES:
        if String(verse["key"]) == mote_verse_key:
            current_mote = verse
            break
    return {
        "sparkles": sparkles,
        "charms": charms_equipped,
        "owned": charms_owned,
        "stanzas": stanzas_equipped,
        "mote_verse": current_mote,
        "hp": hp,
        "hp_max": hp_max,
    }

func _on_buy_requested(key: String) -> void:
    var record: Dictionary = {}
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) == key:
            record = charm
            break
    if record.is_empty():
        return
    var price := int(record.get("price", 0))
    if sparkles < price:
        ui.show_toast("Not quite enough sparkles. The wares will keep.")
        return
    if key == "tea":
        if hp >= hp_max:
            # Belt and braces: never charge for a heal that cannot happen.
            ui.add_log("Peddle: “No tea for you — you are warm as a toast. Save those sparkles!”")
            return
        sparkles -= price
        hp = hp_max
        audio.play_chord([523.25, 659.25, 783.99], 0.55, 0.08)
        ui.add_log("Peddle: “Sip slowly. Forest time is wonderfully flexible.”")
    else:
        if bool(charms_owned.get(key, false)):
            return
        sparkles -= price
        charms_owned[key] = true
        var equipped_count := charms_equipped.size()
        if equipped_count < BeautyContent.MAX_CHARMS:
            charms_equipped[key] = true
        elif bool(charms_equipped.get(key, false)):
            # Already wearing one of the three, so the purchase is a pure
            # duplicate -- see the owned check above.
            return
        if key == "scarf":
            # Max warmth is owned by _recalculate_loadout below, which rebuilds
            # it from the equipped loadout. Bumping it here did nothing (the
            # recompute overwrote it four lines later) and read as a second
            # source of truth, so only the scarf's warming heal stays.
            hp = minf(hp_max, hp + 30.0)
        audio.play_chord([392.0, 523.25, 659.25], 0.62, 0.09)
        if charms_equipped.has(key):
            ui.add_log("Peddle: “One %s, wrapped in a leaf. It suits you.”" % String(record["name"]))
        else:
            # All three slots are taken, so this one waits in the pocket. Say so:
            # taking the sparkles and saying "it suits you" while the charm does
            # nothing is how a player ends up hunting for a power they never got.
            ui.add_log("Peddle: “One %s, tucked safely in your pocket. Swap a charm on to wear it.”" % String(record["name"]))
    _award_sticker("shopper")
    _recalculate_loadout(false)
    ui.show_shop(_shop_state())
    _refresh_ui()

func _on_charm_equip_requested(key: String) -> void:
    if not bool(charms_owned.get(key, false)):
        return
    if bool(charms_equipped.get(key, false)):
        charms_equipped.erase(key)
    else:
        if charms_equipped.size() >= BeautyContent.MAX_CHARMS:
            charms_equipped = _loadout_replacing(key)
            var rested := _evicted_charm_name()
            ui.add_log("Peddle: “%s on. %s rests in your pocket — tap it any time to swap back.”" % [
                _charm_name(key), rested])
        else:
            charms_equipped[key] = true
    _recalculate_loadout(false)
    audio.play_tone(587.33, 0.24, 0.055, 1)
    ui.show_shop(_shop_state())

## The loadout after swapping `key` in with every slot already full. Which worn
## charm came off used to fall out of charms_owned.keys() order: the LAST owned
## key that was wearing, which is neither the weakest nor the one a player would
## pick, and the UI never said so. Iterating the WORN set instead and keeping the
## first MAX_CHARMS-1 means the evicted charm is a stable, explainable choice,
## and Peddle now names it out loud.
func _loadout_replacing(key: String) -> Dictionary:
    var next_loadout: Dictionary = {key: true}
    var equipped_count := 1
    for worn_key: String in charms_equipped.keys():
        if worn_key == key:
            continue
        if equipped_count >= BeautyContent.MAX_CHARMS:
            break
        next_loadout[worn_key] = true
        equipped_count += 1
    _evicted = ""
    for worn_key: String in charms_equipped.keys():
        if not next_loadout.has(worn_key):
            _evicted = worn_key
            break
    return next_loadout

func _charm_name(key: String) -> String:
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) == key:
            return String(charm["name"])
    return key

func _evicted_charm_name() -> String:
    if _evicted == "":
        return "The one underneath"
    return _charm_name(_evicted)

func _on_stanza_equip_requested(key: String) -> void:
    if bool(stanzas_equipped.get(key, false)):
        stanzas_equipped.erase(key)
    else:
        if stanzas_equipped.size() >= BeautyContent.MAX_STANZAS:
            stanzas_equipped = _stanzas_replacing(key)
            ui.add_log("Mote: “%s it is. %s steps back for now — tap it again any time.”" % [
                _stanza_name(key), _evicted_stanza_name()])
        else:
            stanzas_equipped[key] = true
    _recalculate_loadout(false)
    audio.play_tone(659.25, 0.24, 0.055, 1)
    ui.show_shop(_shop_state())

## The stanza loadout after a swap. Same shape as _loadout_replacing: name what
## steps aside, because the shop offers "try it on" for every verse and the
## player has no other way to tell that one of the two they were humming just
## stopped being sung.
func _stanzas_replacing(key: String) -> Dictionary:
    var next_stanzas: Dictionary = {key: true}
    var stanza_count := 1
    for existing: String in stanzas_equipped.keys():
        if existing == key:
            continue
        if stanza_count >= BeautyContent.MAX_STANZAS:
            break
        next_stanzas[existing] = true
        stanza_count += 1
    _evicted_stanza = ""
    for existing: String in stanzas_equipped.keys():
        if not next_stanzas.has(existing):
            _evicted_stanza = existing
            break
    return next_stanzas

func _stanza_name(key: String) -> String:
    for stanza: Dictionary in BeautyContent.STANZAS:
        if String(stanza["key"]) == key:
            return String(stanza["name"])
    return key

func _evicted_stanza_name() -> String:
    if _evicted_stanza == "":
        return "The other verse"
    return _stanza_name(_evicted_stanza)

func _on_mote_verse_requested(key: String) -> void:
    mote_verse_key = key
    _recalculate_loadout(false)
    audio.play_tone(783.99, 0.30, 0.055, 1)
    ui.add_log("Mote: “%s — I’ll hum that beside you.”" % (String(BeautyContent.random_choice(BeautyContent.MOTE_LINES)) if not key.is_empty() else "I’ll hum softly beside you."))
    ui.show_shop(_shop_state())

func _recalculate_loadout(reset_hp: bool) -> void:
    charm_effects = BeautyData.charm_effects(charms_equipped)
    stanza_effects = BeautyData.stanza_effects(stanzas_equipped)
    verse_effects = BeautyData.mote_verse_effects(mote_verse_key)
    var base_hp_max := 100.0 + (15.0 if selected_style == "gentle" else 0.0) + level_hp_bonus + float(charm_effects.get("max_hp", 0.0))
    if reset_hp:
        hp_max = base_hp_max
        hp = hp_max
    else:
        hp_max = base_hp_max
        hp = minf(hp, hp_max)
    if player and is_instance_valid(player):
        player.setup(dungeon, charm_effects, bool(settings.get("reduced_motion", false)))
        player.set_control_enabled(_gameplay_controls_enabled())

func _apply_settings(value: Dictionary, persist: bool) -> void:
    settings = value.duplicate(true)
    ui.apply_settings(settings)
    # The HUD collapses based on text_scale, but apply_settings lives in the base
    # UI class and cannot call the layout pass defined further down the mixin
    # chain. Without this, raising the text size on a short window leaves the
    # wide layout in place — the left card grows to 590x454 and overlaps the
    # hint bar — until something else happens to resize the window.
    ui._fit_layout()
    if audio:
        audio.set_volume(float(settings.get("volume", 0.8)))
        audio.set_muted(bool(settings.get("muted", false)))
    if world and is_instance_valid(world):
        world.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    for wisp: Wisp in wisps:
        if is_instance_valid(wisp):
            wisp.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    if player and is_instance_valid(player) and player.hero:
        player.hero.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    if persist:
        BeautyData.save_settings(settings)

func _gain_xp(amount: int) -> void:
    xp += maxi(0, amount)
    var levels := 0
    while xp >= xp_next:
        xp -= xp_next
        level += 1
        levels += 1
        xp_next = maxi(2, roundi(float(xp_next) * 1.35))
        var roll := randf()
        if roll < 0.40:
            level_hp_bonus += 20.0
            hp_max += 20.0
            hp = hp_max
            ui.add_log("Level %d! Your heart grows two sizes (+20 max warmth)." % level)
        elif roll < 0.80:
            attack += 4.0
            ui.add_log("Level %d! Your song carries farther (+4 Song)." % level)
        else:
            level_hp_bonus += 10.0
            hp_max += 10.0
            attack += 2.0
            hp = hp_max
            ui.add_log("Level %d! Heart and song both grow." % level)
        _learn_fact("A level-up lantern fact")
    if levels > 0:
        CozyVFX.burst(world, player.global_position + Vector3.UP * 1.1, Color("#ffe99a"), 44, 2.0, 1.25)
        CozyVFX.ring(world, player.global_position + Vector3.UP * 0.2, Color("#ffe99a"), 3.2, 0.9)
        audio.play_level()
        ui.show_toast("✦ Level %d — %d new fact%s in the Atlas!" % [level, levels, "" if levels == 1 else "s"])
        _celebrate(1.0)
    _refresh_ui()

func _celebrate(duration: float) -> void:
    ## Soothing a wisp or levelling up makes THIS hero hop and glow, then settle.
    ## The deferred clear captures the rig's instance id: reading `player` from a
    ## timer instead would reach the hero that replaced this one after a floor
    ## change and cut its own celebration short.
    if not (player and is_instance_valid(player) and player.hero):
        return
    var hero_id := player.hero.get_instance_id()
    player.hero.set_happy(true)
    get_tree().create_timer(duration).timeout.connect(func():
        var hero := instance_from_id(hero_id) as HeroRig
        if hero != null and is_instance_valid(hero):
            hero.set_happy(false)
    )

## One fact, from either source, into the Atlas.
##
## `counts_toward_finder` marks the curious-wisp route specifically. The Atlas
## counter is shared with level-up facts, so a single counter would hand
## Curious Mind to the first ten level-ups and the wisp route could never win it
## -- while the journal still told players a curious wisp was a way to earn it.
## `facts_from_wisps` is its own tally so the sticker means what it says.
func _learn_fact(reason: String, counts_toward_finder: bool = false) -> void:
    var fact := String(BeautyContent.FACTS[int(meta.get("facts", 0)) % BeautyContent.FACTS.size()])
    var learned: Array = meta.get("facts_learned", [])
    learned.append(fact)
    meta["facts_learned"] = learned
    meta["facts"] = int(meta.get("facts", 0)) + 1
    if counts_toward_finder:
        meta["facts_from_wisps"] = int(meta.get("facts_from_wisps", 0)) + 1
        if int(meta["facts_from_wisps"]) >= 10:
            _award_sticker("fact_finder")
    ui.add_log("Mote: “%s”" % fact)
    if not reason.is_empty() and reason.contains("curious"):
        ui.add_log(reason)
    BeautyData.save_meta(meta)

func _near_merchant() -> bool:
    return merchant_exists and world != null and player != null and player.global_position.distance_to(world.merchant_position) < 2.8

func _near_feeling(max_distance: float) -> Wisp:
    var best: Wisp
    var best_distance := max_distance
    for wisp in wisps:
        if not is_instance_valid(wisp) or not wisp.alive or wisp.soothed or not wisp.is_feeling:
            continue
        var distance := player.global_position.distance_to(wisp.global_position)
        if distance < best_distance:
            best_distance = distance
            best = wisp
    return best

func _has_feeling_floor() -> bool:
    return BeautyContent.FEELINGS.has(BeautyContent.story_floor(floor_number))

func _award_sticker(key: String) -> void:
    var stickers: Array = meta.get("stickers", [])
    if stickers.has(key):
        return
    stickers.append(key)
    meta["stickers"] = stickers.slice(-40)
    BeautyData.save_meta(meta)
    ui.show_toast("Sticker earned: %s — %s" % [String(BeautyContent.STICKERS.get(key, key)), _sticker_description(key)])
    audio.play_tone(783.99, 0.42, 0.055, 1)

func _sticker_description(key: String) -> String:
    return STICKER_DESCRIPTIONS.get(key, "a gentle thing worth remembering")

func _refresh_ui() -> void:
    if ui == null or player == null or not is_instance_valid(player):
        return
    # The HUD is fed ICONS, not sentences. Charm KEYS drive the vitals sockets;
    # charm NAMES are sent too, but only the pause menu ever paints them.
    var charm_keys: Array[String] = []
    for key: String in charms_equipped.keys():
        charm_keys.append(key)
    for key: String in stanzas_equipped.keys():
        if bool(stanzas_equipped.get(key, false)):
            charm_keys.append(key)
    var charm_names: Array[String] = []
    for key: String in charms_equipped.keys():
        for charm: Dictionary in BeautyContent.CHARMS:
            if String(charm["key"]) == key:
                charm_names.append(String(charm["name"]))
                break
    ui.update_hud({
        "floor": floor_number,
        "region_name": String(region.get("name", "Sunlit Roots")),
        "forecast": String(floor_modifier.get("description", "a warm, unhurried path")),
        "hp": roundi(hp),
        "hp_max": roundi(hp_max),
        "xp": xp,
        "xp_next": xp_next,
        "level": level,
        "attack": roundi(attack),
        "sparkles": sparkles,
        "charm_keys": charm_keys,
        "charm_names": charm_names,
    })
    ui.update_map_player(player.global_position, _minimap_markers())
    # The lantern itself dims and reddens with warmth, so being hurt reads in
    # the world and not only on the HUD ring.
    if player != null and is_instance_valid(player) and player.hero != null and is_instance_valid(player.hero):
        player.hero.set_warmth(clampf(hp / maxf(1.0, hp_max), 0.0, 1.0))
    _update_waypoint()

## Where the walk wants to go, shown as a glow in the world rather than a
## sentence in the corner. One marker at a time: the thing that matters most on
## this floor, which is not always the stair.
func _update_waypoint() -> void:
    if world == null or not is_instance_valid(world) or player == null or not is_instance_valid(player):
        return
    var target := Vector3.ZERO
    var glyph := GardenGlyphs.STAIRS
    var tint := Color("#bdf0bd")
    var urgency := 0.0
    var has_target := false
    # The words for whatever this picks, published for the pause menu. It used
    # to be a fixed "Wander toward the glowing stair", which sent the player
    # looking for a stairwell that dragon floors do not have.
    var objective := ""
    if _lullaby_active:
        # During a lullaby the beat ring owns the screen; a floor marker would
        # compete with it.
        _set_waypoint_active(false)
        ui._walker_objective = "Sing the lullaby — the glow will wait"
        return
    if dragon_exists:
        target = world.dragon_position
        glyph = GardenGlyphs.DRAGON
        tint = Color("#ffe095")
        urgency = 0.85
        has_target = true
        objective = "Wander to the glow over Snoozle and start the lullaby"
    elif _has_feeling_floor():
        var feeling := _near_feeling(40.0)
        if feeling != null:
            target = feeling.global_position
            glyph = GardenGlyphs.HEART
            tint = Color("#ffad72") if not feeling.is_boss_vulnerable() else Color("#ffe066")
            urgency = 0.6
            has_target = true
            objective = "Sit with the Very Big Wisp and sing it down"
    elif not world.chimes.is_empty():
        target = world.chimes[0].global_position
        glyph = GardenGlyphs.CHIME
        tint = Color("#bfe8ff")
        urgency = 0.7
        has_target = true
        objective = "Follow the chime — it is holding a fact for you"
    elif merchant_exists:
        target = world.merchant_position
        glyph = GardenGlyphs.CART
        tint = Color("#ffd56e")
        urgency = 0.35 if _near_merchant() else 0.2
        has_target = true
        objective = "Wander to Peddle's cart and browse the cozy things"
    elif stair_visible:
        target = world.stair_position
        glyph = GardenGlyphs.STAIRS
        urgency = 0.0
        has_target = true
        objective = "Wander toward the glowing stair"
    ui._walker_objective = objective
    if not has_target:
        _set_waypoint_active(false)
        return
    _set_waypoint_active(true)
    if _waypoint == null or not is_instance_valid(_waypoint):
        return
    _waypoint.global_position = target
    _waypoint.configure(glyph, tint, urgency)
    # Stop asking once the player is standing at the stair.
    _waypoint.set_arrived(stair_visible and not dragon_exists and player.global_position.distance_to(world.stair_position) < 2.3)

func _set_waypoint_active(active: bool) -> void:
    if active and (_waypoint == null or not is_instance_valid(_waypoint)):
        _waypoint = CozyWaypoint.new()
        _waypoint.name = "Waypoint"
        world.add_child(_waypoint)
        _waypoint.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    if _waypoint != null and is_instance_valid(_waypoint):
        _waypoint.visible = active

func _minimap_markers() -> Array[Dictionary]:
    var markers: Array[Dictionary] = []
    if stair_visible:
        markers.append({"x": world.stair_position.x, "z": world.stair_position.z, "color": Color("#9ee6a9")})
    if merchant_exists:
        markers.append({"x": world.merchant_position.x, "z": world.merchant_position.z, "color": Color("#ffd56e")})
    if dragon_exists:
        markers.append({"x": world.dragon_position.x, "z": world.dragon_position.z, "color": Color("#ffe095")})
        for chime in world.chimes:
            if is_instance_valid(chime):
                markers.append({"x": chime.global_position.x, "z": chime.global_position.z, "color": Color("#bfe8ff")})
    for wisp: Wisp in wisps:
        if not is_instance_valid(wisp):
            continue
        if wisp.is_feeling:
            markers.append({"x": wisp.global_position.x, "z": wisp.global_position.z, "color": Color("#ffe066") if wisp.is_boss_vulnerable() else Color("#ffad72")})
        elif wisp.is_big and wisp.is_boss_vulnerable():
            markers.append({"x": wisp.global_position.x, "z": wisp.global_position.z, "color": Color("#ffe066")})
    return markers

func _set_world_processing(enabled: bool) -> void:
    if world != null and is_instance_valid(world):
        world.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
