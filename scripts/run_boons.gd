class_name RunBoons
extends "res://scripts/run_shop.gd"
## The level-up draft: every level earned offers three gifts, and the walker
## chooses. Levelling used to hand out a random perk, which made the game's
## one real growth moment a slot machine -- the numbers went up either way,
## and "which one do I want" never got asked. Now the question IS the reward:
## three glyph cards, one pick, every level, forever. The pool itself grows
## with depth, so the choice deepens as the walk does.

## What the next level-up offers. `effect` entries use the charm schema and
## fold into the run's charm_effects (multipliers compound, additions add),
## so a boon stacks with wares exactly the way a second ware would.
const BOON_POOL := [
    {"key": "warmth", "glyph": GardenGlyphs.HEART, "word": "Warmer",
        "weight": 30, "hint": "+20 max warmth, filled now"},
    {"key": "song", "glyph": GardenGlyphs.CHIME, "word": "Brighter",
        "weight": 30, "hint": "+4 song power"},
    {"key": "both", "glyph": GardenGlyphs.SOUL, "word": "Both",
        "weight": 22, "hint": "+10 warmth and +2 song"},
    {"key": "swift", "glyph": "boots", "word": "Swifter",
        "weight": 16, "min_floor": 3, "hint": "walk 6% swifter this run",
        "effect": {"speed": 1.06}},
    {"key": "lantern", "glyph": "ember", "word": "Farther",
        "weight": 16, "min_floor": 3, "hint": "song-notes fly 8% farther",
        "effect": {"note_range": 1.08}},
    {"key": "kind", "glyph": "honey", "word": "Kindlier",
        "weight": 14, "min_floor": 5, "hint": "each heart restores +4 warmth",
        "effect": {"heart_heal": 4}},
    {"key": "gleaner", "glyph": "dandelion", "word": "Nearer",
        "weight": 14, "min_floor": 5, "hint": "hearts find you from 8% farther",
        "effect": {"pickup": 1.08}},
    {"key": "ward", "glyph": "moss", "word": "Softer",
        "weight": 14, "min_floor": 5, "hint": "bumps hurt 5% less",
        "effect": {"damage_taken": 0.95}},
]
const BOON_MULTIPLIER_FIELDS := ["speed", "note_range", "pickup", "damage_taken"]
const BOON_ADDITION_FIELDS := ["heart_heal"]

var boon_effects := {}
var pending_boons := 0
var _draft_offers: Array = []

## Called once per level gained, from RunState._gain_xp. The gift is not
## applied here: it is offered. Levels queue, so a huge soothe that earns
## three levels deals out three picks, one card at a time.
func _apply_level_up_boon() -> void:
    pending_boons += 1

## Offer the next pending gift whenever the walk is the thing on screen, and
## the song is not. The director's 0.1 s throttle usually spaces these calls,
## but a soothe that levels up opens the draft the same tick: _soothe_wisp
## calls _refresh_ui directly, so the world can pause mid-physics with the
## cards up. That is survivable by construction -- the only work after the
## pivot in the same tick is chime gathering and a no-op lullaby beat, neither
## of which can damage a frozen hero. An active lullaby also
## holds the mode machine: bystander wisps keep getting soothed all through a
## ceremony, so a level can land mid-song, and seizing the beat ring to deal
## cards would freeze the song on its own gold note. The gift waits; the
## same tick offers it the moment the last beat lands.
func _refresh_ui() -> void:
    super()
    if pending_boons > 0 and mode == Mode.PLAYING and not ending_pending and not _lullaby_active:
        _open_draft()

func _open_draft() -> void:
    _draft_offers = _roll_offers()
    if _draft_offers.is_empty():
        # No gift can be offered (an empty pool is a content bug, not a state
        # the player made). Grant the plain warmth boon rather than swallowing
        # a level, and say so in the log where a developer will see it.
        push_warning("Boon pool offered nothing; applying the warmth boon directly.")
        _grant_warmth_boon()
        pending_boons -= 1
        return
    mode = Mode.DRAFT
    _set_world_processing(false)
    player.set_control_enabled(false)
    ui.show_draft(_draft_offers, level)

## Three distinct gifts, weighted, from everything this depth has unlocked.
func _roll_offers() -> Array:
    var available: Array = []
    for boon: Dictionary in BOON_POOL:
        if floor_number >= int(boon.get("min_floor", 1)):
            available.append(boon)
    var offers: Array = []
    while offers.size() < 3 and not available.is_empty():
        var total := 0
        for boon: Dictionary in available:
            total += int(boon.get("weight", 1))
        var roll := randi() % total
        var picked: Dictionary = available[0]
        for boon: Dictionary in available:
            roll -= int(boon.get("weight", 1))
            if roll < 0:
                picked = boon
                break
        available.erase(picked)
        offers.append(picked)
    return offers

## The player answered the cards. Applies the gift, closes the screen, and
## offers the next queued level if one is waiting.
func pick_boon(key: String) -> void:
    if mode != Mode.DRAFT:
        return
    var picked: Dictionary = {}
    for offer: Dictionary in _draft_offers:
        if String(offer.get("key", "")) == key:
            picked = offer
            break
    if picked.is_empty():
        return
    _apply_boon(picked)
    pending_boons = maxi(0, pending_boons - 1)
    _draft_offers = []
    audio.play_chord([523.25, 659.25, 783.99], 0.5, 0.08)
    CozyVFX.sparkle_crown(world, player.global_position + Vector3.UP * 0.4, Color("#ffe99a"),
        9, bool(settings.get("reduced_motion", false)))
    ui.close_panels()
    ui.set_text_chrome_visible(false)
    if pending_boons > 0:
        _open_draft()
        return
    mode = Mode.PLAYING
    _set_world_processing(true)
    player.set_control_enabled(_gameplay_controls_enabled())
    _refresh_ui()

func _apply_boon(boon: Dictionary) -> void:
    match String(boon.get("key", "")):
        "warmth":
            _grant_warmth_boon()
        "song":
            attack += 4.0
        "both":
            level_hp_bonus += 10.0
            hp_max += 10.0
            hp = hp_max
            attack += 2.0
        _:
            var effect: Dictionary = boon.get("effect", {})
            for field: String in effect:
                if field in BOON_MULTIPLIER_FIELDS:
                    boon_effects[field] = float(boon_effects.get(field, 1.0)) * float(effect[field])
                elif field in BOON_ADDITION_FIELDS:
                    boon_effects[field] = float(boon_effects.get(field, 0.0)) + float(effect[field])
            _recalculate_loadout(false)
    ui.add_log("Mote: “%s — a lovely pick.”" % String(boon.get("hint", "A gift from the forest")))

func _grant_warmth_boon() -> void:
    level_hp_bonus += 20.0
    hp_max += 20.0
    hp = hp_max

## Fold the boon multipliers into the run's charm effects so every consumer --
## the hero's walk, the song-note range, the heart pickup radius -- reads one
## merged answer, the same way wares stack. The base class rebuilt
## charm_effects from the worn loadout alone; the fold reapplies the boons on
## top and re-teaches the hero, so a boon picked on floor 9 still walks on
## floor 40.
func _recalculate_loadout(reset_hp: bool) -> void:
    super(reset_hp)
    if boon_effects.is_empty():
        return
    for field: String in boon_effects:
        if field in BOON_MULTIPLIER_FIELDS:
            charm_effects[field] = float(charm_effects.get(field, 1.0)) * float(boon_effects[field])
        elif field in BOON_ADDITION_FIELDS:
            charm_effects[field] = float(charm_effects.get(field, 0.0)) + float(boon_effects[field])
    if player and is_instance_valid(player):
        player.setup(dungeon, charm_effects, bool(settings.get("reduced_motion", false)))
        player.set_control_enabled(_gameplay_controls_enabled())
