class_name RunState
extends Node3D

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const AudioDirector := preload("res://scripts/audio_director.gd")
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyData := preload("res://scripts/beauty_data.gd")
const BeautyLore := preload("res://scripts/beauty_lore.gd")
const CozyVFX := preload("res://scripts/cozy_vfx.gd")
const CozyWaypoint := preload("res://scripts/cozy_waypoint.gd")
const ForestWorld := preload("res://scripts/forest_world.gd")
const GameUI := preload("res://scripts/game_ui.gd")
const GardenGlyphs := preload("res://scripts/garden_glyphs.gd")
const HeroRig := preload("res://scripts/hero_rig.gd")
const Player := preload("res://scripts/player.gd")
const SongNote := preload("res://scripts/song_note.gd")
const Wisp := preload("res://scripts/wisp.gd")

## Run state, player profile progression and the HUD feed for one walk: the
## numbers that make a run and the world marker that says where to go next.
## The director wires this up in main.gd; Peddle's cart extends this in
## RunShop, the level-up draft in RunBoons, combat in RunCombat and floor
## construction in RunWorld.

enum Mode { MENU, PLAYING, PAUSED, DRAFT, SHOP, JOURNAL, SETTINGS, DEAD, ENDING }

const CAMERA_OFFSET := Vector3(6.4, 8.8, 6.4)
const CHIME_TONES: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0]
const LULLABY_STEP := 0.80
const CHIME_GATHER_RADIUS := 4.0
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
## What the hero owns and what it has on.
##
## Both are lists of `{"key": String, "tier": int}`. They used to be flag
## dictionaries with a flat cap of three, which meant the same charm could only
## ever be bought once, so the whole loadout stopped growing the moment the
## third slot filled no matter how deep the walk went. A list with a tier lets
## one ware be owned twice -- the second copy stronger -- so the shelf keeps
## paying out for as long as the walk lasts.
var charms_owned: Array[Dictionary] = []
var charms_equipped: Array[Dictionary] = []
## Verses are free, so there is no purse to stop them and no cap worth having:
## the hero can hum every one it has found.
var stanzas_equipped: Dictionary = {"petals": true, "echoes": true}
var mote_verse_key := ""
var charm_effects: Dictionary = {}
var stanza_effects: Dictionary = {}
var verse_effects: Dictionary = {}
var hit_this_floor := false
## The one-time lantern lesson: the first bump shows a short story card naming
## warmth for what it is, because the lantern dims in the world but the WORD
## "warmth" is only ever spoken on screens. Cleared on a fresh walk.
var _lantern_taught := false
## Facts learned since the last draft card. Mote used to write every fact into
## the hidden log strip, so the Learning promise landed where nobody reads;
## now each fresh fact rides its next level-up card and is spoken out loud.
var fresh_facts: Array = []
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

## One level's gift, offered to the player. RunState only defines the hook;
## RunBoons implements it as the level-up draft, so the moment a level lands
## the walker is asked what they want rather than handed a random perk.
func _apply_level_up_boon() -> void:
    pass

func _gain_xp(amount: int) -> void:
    xp += maxi(0, amount)
    var levels := 0
    while xp >= xp_next:
        xp -= xp_next
        level += 1
        levels += 1
        xp_next = _next_level_cost()
        _apply_level_up_boon()
        _learn_fact("A level-up lantern fact")
    if levels > 0:
        CozyVFX.burst(world, player.global_position + Vector3.UP * 1.1, Color("#ffe99a"), 44, 2.0, 1.25)
        CozyVFX.ring(world, player.global_position + Vector3.UP * 0.2, Color("#ffe99a"), 3.2, 0.9)
        audio.play_level()
        ui.show_toast("✦ Level %d — %d new fact%s in the Atlas!" % [level, levels, "" if levels == 1 else "s"])
        _celebrate(1.0)
    _refresh_ui()

## What the NEXT level costs.
##
## This is the heart of the answer to "the creatures below can grow forever, so
## why can't the hero". It used to be `xp_next *= 1.35` -- exponential -- while
## everything the hero faces scales LINEARLY with depth, and the soul the hero
## collects per floor grows linearly too. Exponential cost against linear income
## means the hero stops levelling: simulated to floor 400, level 41 against
## creatures scaled x72, so the song-to-creature ratio fell from 1.20 at floor 1
## to 0.12 and kept falling forever. The loadout grew but the hero did not, so
## past roughly floor 30 the only difficulty knob left was the player's own
## reaction time.
##
## A LINEAR cost matches the world it lives in. Level count then grows about one
## to one per floor, and the song-to-creature ratio settles in the 1.4-1.6 band
## and stays there -- measured to floor 400, where the hero is level 538. Growth
## is then unbounded in the way the creatures are: forever, and never running
## away from the player either. Re-measure with _audit/probe_growth.gd.
func _next_level_cost() -> int:
    return maxi(2, roundi(LEVEL_COST_BASE + LEVEL_COST_SLOPE * float(level)))

const LEVEL_COST_BASE := 10.0
## Soul needed per level beyond the first. Measured against the per-floor soul
## supply: this slope keeps the hero gaining roughly one level a floor.
const LEVEL_COST_SLOPE := 45.0

## How many wares the hero can wear at this depth. The HUD needs this too, and
## the HUD does not inherit from RunShop, so it lives with the run's other
## depth-derived facts rather than inside one subclass.
func loadout_capacity() -> int:
    return BeautyContent.loadout_capacity(floor_number)

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
    # The Atlas holds BeautyLore.FACTS entries and this picks by index, so it
    # cycles. It used to append unconditionally, which filled the journal with
    # duplicate copies of the same facts: measured after 12 runs, 120 entries
    # holding only 24 distinct ones, until the 120-entry cap dropped the
    # player's oldest facts and the memory book renumbered the survivors. Mote's
    # memory book is a collection, so it should hold each fact once.
    var learned: Array = meta.get("facts_learned", [])
    var available: Array[String] = []
    for entry: Variant in BeautyLore.FACTS:
        var text := String(entry)
        if not learned.has(text):
            available.append(text)
    if available.is_empty():
        # Everything Mote knows is already in the book, so there is nothing new
        # to write down -- but the curious-wisp route still counts toward its
        # sticker, which measures discoveries rather than distinct texts and is
        # named as a route in the journal.
        if counts_toward_finder:
            _count_wisp_fact()
        BeautyData.save_meta(meta)
        return
    var fact: String = available[learned.size() % available.size()]
    learned.append(fact)
    meta["facts_learned"] = learned
    fresh_facts.append(fact)
    # `facts` is the number of facts in the book, which is what every screen
    # that shows it means: the pause card and the ending tally both print it
    # beside "Fun facts", while the memory book lists facts_learned. They
    # diverged before (480 counted against 120 listed, and the 120 were 96
    # duplicate copies of 24 facts), so the counter is now derived from the
    # journal rather than kept as a separate tally that can drift from it.
    meta["facts"] = learned.size()
    if counts_toward_finder:
        _count_wisp_fact()
    ui.add_log("Mote: “%s”" % fact)
    if not reason.is_empty() and reason.contains("curious"):
        ui.add_log(reason)
    BeautyData.save_meta(meta)

func _count_wisp_fact() -> void:
    meta["facts_from_wisps"] = int(meta.get("facts_from_wisps", 0)) + 1
    if int(meta["facts_from_wisps"]) >= 10:
        _award_sticker("fact_finder")

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
    return not BeautyContent.feeling_for_floor(floor_number).is_empty()

func _award_sticker(key: String) -> void:
    var stickers: Array = meta.get("stickers", [])
    if stickers.has(key):
        return
    stickers.append(key)
    meta["stickers"] = stickers.slice(-40)
    if not BeautyData.save_meta(meta):
        # The game is about to congratulate the player for something it could
        # not write down -- a full or read-only disk makes this routine, and the
        # failure used to reach only the console, so the next launch would forget
        # the sticker the toast just announced. Say so, once, gently.
        ui.add_log("Mote: “Oh — I couldn't be saved just now. This sticker may not stay.”")
    ui.show_toast("Sticker earned: %s — %s" % [BeautyContent.sticker_name(key), BeautyContent.sticker_line(key)])
    audio.play_tone(783.99, 0.42, 0.055, 1)

func _refresh_ui() -> void:
    if ui == null or player == null or not is_instance_valid(player):
        return
    # The HUD is fed ICONS, not sentences. Each worn ware arrives as its glyph
    # key; a charm's tier rides along in the key itself so the socket can show
    # WHICH copy it is, and the pause menu can name it.
    var charm_keys: Array[String] = []
    for worn: Dictionary in charms_equipped:
        charm_keys.append(GardenGlyphs.worn_key(String(worn.get("key", "")), int(worn.get("tier", 1))))
    for key: String in stanzas_equipped.keys():
        if bool(stanzas_equipped.get(key, false)):
            # Stanzas share keys with charms (`moss`, `lullaby`), so the socket
            # list must carry which table each key is for -- as an inked key a
            # card or socket can paint with no guessing.
            charm_keys.append(GardenGlyphs.STANZA_PREFIX + key)
    var charm_names: Array[String] = []
    for worn: Dictionary in charms_equipped:
        charm_names.append(BeautyContent.charm_label(String(worn.get("key", "")), int(worn.get("tier", 1))))
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
        "capacity": loadout_capacity(),
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
    if mode != Mode.PLAYING:
        # The walk glow belongs to the walk itself. On the title backdrop it
        # answered with a beacon over an invisible stair; on DEAD/ENDING the
        # cards own the world. The parked text stays for PAUSED/SHOP/JOURNAL/
        # SETTINGS, where the pause card reads it back to the player.
        _set_waypoint_active(false)
        if mode == Mode.MENU or mode == Mode.DEAD or mode == Mode.ENDING:
            ui._walker_objective = ""
        return
    var target := Vector3.ZERO
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
        tint = Color("#ffe095")
        urgency = 0.85
        has_target = true
        objective = "Wander to the glow over Snoozle and start the lullaby"
    elif _has_feeling_floor():
        var feeling := _near_feeling(40.0)
        if feeling != null:
            target = feeling.global_position
            tint = Color("#ffad72") if not feeling.is_boss_vulnerable() else Color("#ffe066")
            urgency = 0.6
            has_target = true
            objective = "Sit with the Very Big Wisp and sing it down"
    elif not world.chimes.is_empty():
        target = world.chimes[0].global_position
        tint = Color("#bfe8ff")
        urgency = 0.7
        has_target = true
        objective = "Follow the chime — it is holding a fact for you"
    elif merchant_exists:
        target = world.merchant_position
        tint = Color("#ffd56e")
        urgency = 0.35 if _near_merchant() else 0.2
        has_target = true
        objective = "Wander to Peddle's cart and browse the cozy things"
    elif stair_visible:
        target = world.stair_position
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
    _waypoint.configure(tint, urgency)
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
