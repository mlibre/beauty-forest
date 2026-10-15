class_name BeautyContent
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyEndless := preload("res://scripts/beauty_endless.gd")

## Canonical game content: styles, wisp types, regions, floors, wares, stanzas,
## counter-melodies, facts and story beats. Behaviour-free data plus the small
## queries that read it. Persistence and loadout math live in BeautyData.

## Re-exported from BeautyEndless, where the source of truth now lives: the
## content tables depend on the endless module, never the reverse. Every
## existing BeautyContent.CAMPAIGN_LENGTH reader keeps working unchanged.
const CAMPAIGN_LENGTH := BeautyEndless.CAMPAIGN_LENGTH

## How many wares the hero can wear, and how that number grows.
##
## It used to be a flat 3, which is the same mistake as the old level curve: the
## creatures below grow without bound, so a loadout that stops at three is a
## loadout that stops meaning anything. A player who earned the whole shelf
## could use a fifth of it, forever, and the only lever left was which third.
##
## So capacity GROWS with depth, one socket per floor, and by the last floor of
## a campaign there is room for one of EVERY charm on the shelf. That is the
## honest shape: a floor-by-floor walk earns its way out of having to choose,
## while the deeper copies still compete for the same sockets -- so a second
## purchase is always a real trade, never a free upgrade nobody had to think
## about. Past the end of the campaign the sockets keep opening.
static func loadout_capacity(depth: int) -> int:
    return LOADOUT_BASE + maxi(0, depth - 1)

## Sockets on floor 1, before the walk has earned any more.
const LOADOUT_BASE := 3

## How many charms can be worn at once -- the shelf, less tea, which is a
## consumable you drink rather than a ware you wear. Capacity must be able to
## reach this by the end of the campaign, or the cart would be selling wares the
## hero can buy but never put on.
static func wearable_charms() -> int:
    var count := 0
    for entry: Dictionary in CHARMS:
        if String(entry["key"]) != "tea":
            count += 1
    return count

## Charm tiers. A charm can be bought twice: the second purchase is the same
## ware made stronger, not a new icon, so the shelf keeps deepening forever
## without the content table growing a combinatorial number of rows.
##
## `tier_scale` is the multiplier on every effect that charm carries.
const TIER_NAMES := ["", "I", "II", "III"]
const TIER_SCALES := [1.0, 1.0, 1.6, 2.3]

static func tier_index(tier: int) -> int:
    return clampi(tier, 1, TIER_SCALES.size() - 1)

static func tier_name(tier: int) -> String:
    return TIER_NAMES[tier_index(tier)]

static func tier_scale(tier: int) -> float:
    return TIER_SCALES[tier_index(tier)]

const STYLE_DATA := {
    "gentle": {
        "name": "Gentle Trail",
        "description": "Softer bumps and 15% extra starting warmth.",
        "damage_taken": 0.60,
        "soul": 1.0,
        "heart_bonus": 0.15,
        "heart_bonus_flat": 15.0,
    },
    "standard": {
        "name": "Forest Trail",
        "description": "The balanced way Mote planned.",
        "damage_taken": 1.0,
        "soul": 1.0,
        "heart_bonus": 0.0,
        "heart_bonus_flat": 0.0,
    },
    "bold": {
        "name": "Brave Trail",
        "description": "Brisk and brave: richer souls, slightly softer heart bonus.",
        "damage_taken": 1.25,
        "soul": 1.5,
        "heart_bonus": -0.05,
        "heart_bonus_flat": -5.0,
    },
}

const NICKNAMES := [
    "Barnaby", "Petunia", "Gerald", "Moira", "Clive", "Sprocket", "Waffles", "Ingrid",
    "Douglas", "Pip", "Margaret", "Kevin", "Biscuit", "Tansy", "Wobble", "Posy", "Crumpet", "Fig",
    "Plum", "Doodle", "Mabel", "Puddles", "Thimble", "Sorrel",
]

const REGIONS := [
    {
        "key": "sunlit-roots", "name": "Sunlit Roots", "min": 1, "max": 4,
        "sky": "#f8e7ae", "horizon": "#fff3c4", "fog": "#dbe6a3", "sun": "#ffe29a",
        "foliage": "#65b947", "tip": "#b7dc55", "flower": "#ffd1e8", "ground": "#87bd62", "accent": "#fff0a5",
        "entry": "Sunlit Roots hum hello. The map says ‘here, but cozier’.",
    },
    {
        "key": "pollen-halls", "name": "Pollen Halls", "min": 5, "max": 8,
        "sky": "#f6d890", "horizon": "#ffe6a3", "fog": "#e9d78f", "sun": "#ffd06a",
        "foliage": "#91b943", "tip": "#dac95b", "flower": "#ffe98d", "ground": "#a8bf55", "accent": "#fff2aa",
        "entry": "Pollen Halls drift golden. Mote sneezes heroically and apologizes to the air.",
    },
    {
        "key": "mushroom-lull", "name": "Mushroom Lull", "min": 9, "max": 12,
        "sky": "#f4c98d", "horizon": "#ffd9a8", "fog": "#e5c08d", "sun": "#ffc06e",
        "foliage": "#b68150", "tip": "#e3b66d", "flower": "#d9c8ff", "ground": "#9ba552", "accent": "#ffd58d",
        "entry": "Mushroom Lull glows amber and kind. Somewhere below, something enormous snores in tune.",
    },
    {
        "key": "roost", "name": "Snoozle’s Roost", "min": 13, "max": 13,
        "sky": "#fff0c8", "horizon": "#fff5d4", "fog": "#e9e4ac", "sun": "#ffe08a",
        "foliage": "#78bd5e", "tip": "#b9dd69", "flower": "#fff3b0", "ground": "#9ac765", "accent": "#ffeaa0",
        "entry": "The Roost glows like the inside of a lantern. Tuck in your scarf.",
    },
    {
        "key": "dewdrop-terraces", "name": "Dewdrop Terraces", "min": 14, "max": 17,
        "sky": "#f2f0cf", "horizon": "#fdf6d8", "fog": "#d8e8c0", "sun": "#ffeaa6",
        "foliage": "#5cb554", "tip": "#a9dd66", "flower": "#bfe4ff", "ground": "#7cc065", "accent": "#e8f4c0",
        "entry": "Dewdrop Terraces ring like tiny bells. Every leaf holds its own little sky.",
    },
    {
        "key": "honeywind-boughs", "name": "Honeywind Boughs", "min": 18, "max": 21,
        "sky": "#f8d99a", "horizon": "#ffe9b8", "fog": "#ecd9a0", "sun": "#ffd37e",
        "foliage": "#a2b945", "tip": "#e0cd5e", "flower": "#ffd9a0", "ground": "#b0bd55", "accent": "#fff0b0",
        "entry": "Honeywind Boughs sway slow and golden. The breeze tastes faintly of dessert.",
    },
    {
        "key": "glowcap-meadow", "name": "Glowcap Meadow", "min": 22, "max": 25,
        "sky": "#f7cf9e", "horizon": "#ffdcb0", "fog": "#e8c9a2", "sun": "#ffc47e",
        "foliage": "#b98d52", "tip": "#e8bc72", "flower": "#ffe3f2", "ground": "#a3a858", "accent": "#ffd9a8",
        "entry": "Glowcap Meadow leans in close to listen. Every mushroom is a tiny reading lamp.",
    },
    {
        "key": "starpetal-vale", "name": "Starpetal Vale", "min": 26, "max": 29,
        "sky": "#f9e2c2", "horizon": "#fff3d8", "fog": "#e9e2b8", "sun": "#ffe5a2",
        "foliage": "#6dbb58", "tip": "#c0e468", "flower": "#e6d5ff", "ground": "#8cc468", "accent": "#fff0c0",
        "entry": "Starpetal Vale glows softly from below, like a lantern under a quilt.",
    },
    {
        "key": "grand-roost", "name": "The Grand Roost", "min": 30, "max": 30,
        "sky": "#fff3d4", "horizon": "#fff8e0", "fog": "#eee9b8", "sun": "#ffe89a",
        "foliage": "#7fc260", "tip": "#bfe06e", "flower": "#fff4bc", "ground": "#9ecb6a", "accent": "#ffeab0",
        "entry": "The Grand Roost glows like the inside of a lantern. The whole family is waiting.",
    },
]

const FLOOR_MODIFIERS := [
    {"name": "Extra hearts tonight", "description": "grateful wisps leave more thank-you hearts", "heart_rate": 0.60},
    {"name": "Rich souls", "description": "wisps carry extra soul-light (+50% soul)", "soul": 1.50},
    {"name": "Brisk wisps", "description": "everyone is a little speedier today", "speed": 1.25},
    {"name": "Lantern festival", "description": "the wood is gentler; wisps notice you later", "aggro": 0.70},
    {"name": "Dewbright morning", "description": "thank-you hearts drift gently toward you", "heart_drift": true},
    {"name": "Kind updrafts", "description": "updrafts carry song-notes 20% farther", "note_range": 1.20},
    {"name": "Bouncy caps", "description": "mushroom caps bounce hearts toward you", "heart_drift": true},
    {"name": "Firefly evening", "description": "fireflies hum along: song-notes fly a little farther", "note_range": 1.15},
    {"name": "Honeyed air", "description": "everything feels possible: richer souls and warmer hearts", "soul": 1.20, "heart_rate": 0.15},
    {"name": "Golden updrafts", "description": "the deep wood exhales: song-notes fly much farther", "note_range": 1.30},
    {"name": "Grandmoss evening", "description": "the oldest moss hums: everyone is a shade gentler", "speed": 0.85, "aggro": 0.85},
    {"name": "Comet season", "description": "bright tails everywhere: much richer souls, brisker wisps", "soul": 1.35, "speed": 1.15},
    {"name": "Heart of the wood", "description": "the forest is grateful: hearts everywhere, drifting to you", "heart_rate": 0.70, "heart_drift": true},
    {"name": "Lantern bloom", "description": "flowers glow like little lamps: richer souls and softer bumps", "soul": 1.15},
]

const CHARMS := [
    {"key": "tea", "name": "Warm Tea", "description": "Restores all warmth instantly", "price": 3},
    {"key": "boots", "name": "Swift Boots", "description": "Walk 15% swifter this run", "price": 5, "speed": 1.15},
    {"key": "scarf", "name": "Wool Scarf", "description": "+30 max warmth; itchy-nice", "price": 6, "max_hp": 30},
    {"key": "echo", "name": "Echo Chime", "description": "Lantern song recharges 35% faster", "price": 7, "cooldown": 0.65},
    {"key": "ember", "name": "Ember Mitten", "description": "Song-notes sing 20% stronger", "price": 6, "song_damage": 1.20},
    {"key": "dandelion", "name": "Dandelion Clock", "description": "Hearts find you from 50% farther", "price": 5, "pickup": 1.50},
    {"key": "moss", "name": "Moss Pillow", "description": "Bumps hurt 15% less", "price": 6, "damage_taken": 0.85},
    {"key": "honey", "name": "Honey Drop", "description": "Each thank-you heart restores +10 warmth", "price": 4, "heart_heal": 10},
    {"key": "pebble", "name": "Pebble Pal", "description": "Starry shield lasts +0.3 seconds", "price": 4, "invulnerable": 0.30},
    {"key": "firefly", "name": "Firefly Jar", "description": "Soul-light glows 25% richer", "price": 7, "soul": 1.25},
    {"key": "socks", "name": "Wool Socks", "description": "Warm wool; dash rests sooner", "price": 5, "dash_cooldown": 0.75},
    {"key": "lullaby", "name": "Lullaby Bell", "description": "Gold beat window is 30% roomier", "price": 8, "lullaby_window": 1.30},
    {"key": "acorn", "name": "Acorn Pocket", "description": "Warmer notes; lantern catches a breath slower", "price": 6, "song_damage": 1.10, "cooldown": 1.10},
    {"key": "chorus", "name": "Chorus Leaf", "description": "Richer souls; bumps come a little closer", "price": 6, "soul": 1.15, "damage_taken": 1.10},
    {"key": "quilt", "name": "Petal Quilt", "description": "Softer bumps, 10% gentler notes", "price": 5, "damage_taken": 0.90, "song_damage": 0.90},
    {"key": "dew", "name": "Dew Lantern", "description": "Hearts come closer; souls drift lighter", "price": 5, "pickup": 1.30, "soul": 0.90},
]

const STANZAS := [
    {"key": "petals", "name": "Verse of Petals", "description": "Lantern pulses slow nearby wisps for 2.5 seconds.", "pulse_slow": 0.35},
    {"key": "echoes", "name": "Verse of Echoes", "description": "+1 song-note; each distant note is 10% gentler.", "song_cap": 1, "song_damage": 0.90},
    {"key": "hearth", "name": "Verse of Hearth", "description": "Thank-you hearts drift toward you.", "heart_magnet": true},
    {"key": "dawn", "name": "Verse of Dawn", "description": "A wider pulse that catches its breath 10% slower.", "pulse_radius": 0.60, "pulse_cooldown": 1.10},
    {"key": "pollen", "name": "Verse of Pollen", "description": "Song-notes ride golden updrafts: faster and longer.", "song_speed": 1.20, "song_life": 0.35},
    {"key": "moss", "name": "Verse of Moss", "description": "More hearts; soothed souls drift 5% lighter.", "heart_rate": 0.12, "soul": 0.95},
    {"key": "lullaby", "name": "Verse of the Lullaby Moth", "description": "Notes linger; a new note starts one breath later.", "song_life": 0.50, "note_cooldown": 1.10},
    {"key": "sunmotes", "name": "Verse of Sunmotes", "description": "Distant soothes gain 15% soul; close pulse is gentler.", "distant_soul": 1.15, "pulse_damage": 0.95},
    {"key": "brook", "name": "Verse of the Brook", "description": "Quicker pulse; distant notes are 5% gentler.", "pulse_cooldown": 0.90, "song_damage": 0.95},
    {"key": "grove", "name": "Verse of the Grove", "description": "A wider pulse; new notes take one extra breath.", "pulse_radius": 0.40, "note_cooldown": 1.05},
]

const MOTE_VERSES := [
    {"key": "", "name": "No Counter-melody", "description": "Mote hums happily beside you."},
    {"key": "lodestar", "name": "Counter-melody of the Lodestar", "description": "Hearts and sparkles find you from farther away.", "pickup": 1.20},
    {"key": "puddlelight", "name": "Counter-melody of Puddlelight", "description": "The puddlelight keeps a kind ripple: your starry shield lasts +0.25 seconds after a bump.", "invulnerable": 0.25},
    {"key": "longnote", "name": "Counter-melody of the Long Note", "description": "Song-notes hold their hum 0.4 seconds longer.", "song_life": 0.40},
    {"key": "warmheart", "name": "Counter-melody of the Warm Heart", "description": "Soothed wisps leave warmer hearts.", "heart_rate": 0.10},
    {"key": "firefly", "name": "Counter-melody of the Fireflies", "description": "Distant soothes sparkle 10% richer.", "distant_soul": 1.10},
    {"key": "softstep", "name": "Counter-melody of Soft Steps", "description": "The forest makes every bump 10% softer.", "damage_taken": 0.90},
]

const FEELINGS := {
    4: {"name": "The Lonely", "farewell": "Thank you for sitting with me. I feel found."},
    8: {"name": "The Hurried", "farewell": "Slowing down… together… ahh. That is the whole trick."},
    12: {"name": "The Snuffly", "farewell": "*sniff* Blew my nose on a star. Feel much better now."},
    16: {"name": "The Wakeful", "farewell": "Ohh. Heavy things feel lighter when somebody stays. Stay was all you did."},
    20: {"name": "The Giggly", "farewell": "Hee… hee… *snorf* Thank you. I had that laugh saved up for ages."},
    24: {"name": "The Dreamy", "farewell": "Was I humming? You hummed WITH me. Now it is a song. Sleep well, friend."},
    28: {"name": "The Snuggly", "farewell": "You may borrow this hug anytime. It renews itself. That is the trick of hugs."},
}

## Every sticker the journal can pin: the name it shows and the award line the
## toast speaks. One home -- these tables used to live apart and could drift.
const STICKERS := {
    "first_nap": {"name": "First Nap", "line": "dozed off and got tucked in by wisps"},
    "dragon_friend": {"name": "Dragon Friend", "line": "sang Snoozle to sleep"},
    "big_hug": {"name": "Big Hug", "line": "soothed a Very Big Wisp"},
    "pacifist": {"name": "Not A Single Bump", "line": "cleared a floor untouched"},
    "shopper": {"name": "Peddle’s Favorite", "line": "bought something lovely"},
    "fact_finder": {"name": "Curious Mind", "line": "learned ten facts from Mote"},
    "feeling_friend": {"name": "Feeling Friend", "line": "sat with a Big Feeling"},
    "curious": {"name": "Curious Companion", "line": "listened to a curious wisp"},
    "long_lullaby": {"name": "Long-Distance Lullaby", "line": "sang a distant wisp all the way home"},
    "kindling": {"name": "Kindling Light", "line": "wandered down to floor six"},
    "century": {"name": "Century of Kindness", "line": "guided a hundred lost wisps home"},
}

## The journal's name for a sticker, or the key itself when unknown.
static func sticker_name(key: String) -> String:
    return String(STICKERS.get(key, {}).get("name", key))

## The award-toast line for a sticker, or a gentle fallback.
static func sticker_line(key: String) -> String:
    return String(STICKERS.get(key, {}).get("line", "a gentle thing worth remembering"))

## The picture a sticker wears in the memory book. Each sticker borrows the
## glyph of the thing that earned it — the dragon sticker wears the dragon,
## the cart sticker wears Peddle's cart — so a shelf of them reads as a row
## of little memories rather than eleven identical hearts. Unknown keys fall
## back to the heart: every sticker is a kindness first.
const STICKER_GLYPHS := {
    "first_nap": "mote",
    "dragon_friend": "dragon",
    "big_hug": "wisp",
    "pacifist": "shield",
    "shopper": "cart",
    "fact_finder": "book",
    "feeling_friend": "heart",
    "curious": "soul",
    "long_lullaby": "chime",
    "kindling": "lantern",
    "century": "sparkle",
}

static func sticker_glyph(key: String) -> String:
    return String(STICKER_GLYPHS.get(key, "heart"))

## The charm behind `key`, or an empty dict if the key is not a charm.
##
## Callers read the shelf through this rather than indexing CHARMS, so a charm
## can carry a tier and a price curve without every call site knowing.
static func charm(key: String) -> Dictionary:
    for entry: Dictionary in CHARMS:
        if String(entry["key"]) == key:
            return entry
    return {}

## What a charm costs at a given tier.
##
## Tier 1 is the shelf price. Each tier costs a flat multiple on top, so a
## deep walk's second copies stay worth having without making the first one
## look pointless.
static func charm_price(key: String, tier: int) -> int:
    var entry := charm(key)
    if entry.is_empty():
        return 0
    return roundi(float(entry.get("price", 0)) * TIER_PRICE_SCALE[tier_index(tier)])

## The charm's effects at a given tier: the same multipliers, scaled.
##
## Multiplicative effects (speed, cooldown, damage_taken) compound, while flat
## additions (max_hp, heart_heal, invulnerable) scale as amounts. Treating both
## the same way would make a tier-II Wool Scarf add 48 warmth and a tier-II
## Moss Pillow soften bumps by 36%, which is not what "stronger" means.
const TIER_PRICE_SCALE := [1.0, 1.0, 2.2, 4.6]

static func charm_effects_at(key: String, tier: int) -> Dictionary:
    var entry := charm(key)
    if entry.is_empty():
        return {}
    var scale := tier_scale(tier)
    var out := {}
    for field: String in entry:
        if field in ["key", "name", "description", "price"]:
            continue
        var value: Variant = entry[field]
        if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
            continue
        if typeof(value) == TYPE_INT:
            out[field] = int(round(float(value) * scale))
        else:
            out[field] = lerpf(1.0, float(value), scale)
    return out

## The charm's name at a tier, so a stronger copy is visibly the same ware.
static func charm_label(key: String, tier: int) -> String:
    var entry := charm(key)
    if entry.is_empty():
        return key
    var suffix := tier_name(tier)
    if suffix.is_empty():
        return String(entry["name"])
    return "%s %s" % [String(entry["name"]), suffix]

## The charm's own words at a tier.
##
## Recomputed from the scaled effects rather than reusing the tier-1 sentence,
## because "Walk 15% swifter this run" describing a 24% pair of boots is a lie
## the player reads in the one place they look for the truth.
static func charm_blurb(key: String, tier: int) -> String:
    var entry := charm(key)
    if entry.is_empty():
        return ""
    if String(entry.get("key", "")) == "tea":
        return String(entry["description"])
    var scaled := charm_effects_at(key, tier)
    var parts: Array[String] = []
    if scaled.has("speed"):
        parts.append("Walk %d%% swifter this run" % roundi(float(scaled["speed"]) * 100.0))
    if scaled.has("cooldown"):
        parts.append("Lantern song recharges %d%% faster" % roundi((1.0 - float(scaled["cooldown"])) * 100.0))
    if scaled.has("song_damage"):
        parts.append("Song-notes sing %d%% stronger" % roundi((float(scaled["song_damage"]) - 1.0) * 100.0))
    if scaled.has("max_hp"):
        parts.append("+%d max warmth" % int(scaled["max_hp"]))
    if scaled.has("damage_taken"):
        parts.append("Bumps hurt %d%% less" % roundi((1.0 - float(scaled["damage_taken"])) * 100.0))
    if scaled.has("heart_heal"):
        parts.append("Each thank-you heart restores +%d warmth" % int(scaled["heart_heal"]))
    if scaled.has("invulnerable"):
        parts.append("Starry shield lasts +%.1f seconds" % float(scaled["invulnerable"]))
    if scaled.has("soul"):
        parts.append("Soul-light glows %d%% richer" % roundi((float(scaled["soul"]) - 1.0) * 100.0))
    if scaled.has("pickup"):
        parts.append("Hearts find you from %d%% farther" % roundi(float(scaled["pickup"]) * 100.0))
    if scaled.has("dash_cooldown"):
        parts.append("Warm wool; dash rests sooner")
    if scaled.has("lullaby_window"):
        parts.append("Gold beat window is %d%% roomier" % roundi((float(scaled["lullaby_window"]) - 1.0) * 100.0))
    if parts.is_empty():
        return String(entry["description"])
    return "; ".join(parts)

static func story_floor(floor_number: int) -> int:
    return ((floor_number - 1) % CAMPAIGN_LENGTH) + 1

static func region_for_floor(floor_number: int) -> Dictionary:
    var composed := BeautyEndless.region_for_floor(floor_number)
    if not composed.is_empty():
        return composed
    var story := story_floor(floor_number)
    for region: Dictionary in REGIONS:
        if story >= int(region["min"]) and story <= int(region["max"]):
            return region
    return REGIONS[0]

## The Big Feeling sitting on this floor, or an empty dict. The campaign's
## three are hand-placed; the endless chapters grow two of their own each.
static func feeling_for_floor(floor_number: int) -> Dictionary:
    if BeautyEndless.is_endless(floor_number):
        return BeautyEndless.feeling_for_floor(floor_number)
    return FEELINGS.get(story_floor(floor_number), {})

## The last floor of any chapter — the campaign's Grand Roost, or an endless
## chapter's own finale — the one floor whose dragon hands the walk to the
## ending card instead of revealing a stair.
static func is_chapter_final_floor(floor_number: int) -> bool:
    if BeautyEndless.is_endless(floor_number):
        return floor_number == BeautyEndless.CAMPAIGN_LENGTH + BeautyEndless.chapter_for_floor(floor_number) * BeautyEndless.CHAPTER_LENGTH
    return story_floor(floor_number) == BeautyEndless.CAMPAIGN_LENGTH

## The floor's position in the story ITSELF belongs to: below the Roost that
## is the campaign's thirty-floor wrap, above it the chapter's thirteen. The
## merchant cadence, the dragon naps and the Roost's hush all read this — a
## deep chapter keeps the rhythm the campaign taught, instead of a 30-floor
## echo landing its beats on whatever chapter floor happens to be underneath.
static func story_plan(floor_number: int) -> int:
    if BeautyEndless.is_endless(floor_number):
        return BeautyEndless.story_in_chapter(floor_number)
    return story_floor(floor_number)

## Where Peddle parks the cart. The campaign's hand-placed floors; an endless
## chapter keeps the opening rhythm's own shape (2, 4, 7, 10), so a chapter
## reads as a small campaign of its own — a cart to visit on the second and
## fourth floors, a cousin to tuck in on the fifth, the roost at the end —
## and never a cart on a sleeping dragon's floor.
static func is_merchant_floor(floor_number: int) -> bool:
    if BeautyEndless.is_endless(floor_number):
        return BeautyEndless.story_in_chapter(floor_number) in [2, 4, 7, 10]
    return story_floor(floor_number) in [2, 4, 7, 10, 14, 16, 19, 22, 25, 27]

static func is_dragon_floor(floor_number: int) -> bool:
    ## The endless chapters promise their own sleeper: the fifth beat of every
    ## chapter is "Someone Sleeps Here" (five Dream Chimes, Mote translating),
    ## and a chapter finale is its own roost. The old answer read the campaign
    ## wrap at every depth, so the beat's chimes almost never had a dragon
    ## under them while wrap dragons materialised on floors whose beat says
    ## nothing of sleeping cousins.
    if BeautyEndless.is_endless(floor_number):
        return BeautyEndless.story_in_chapter(floor_number) == 5 or is_chapter_final_floor(floor_number)
    return story_floor(floor_number) in [5, 13, 21, 29] or is_chapter_final_floor(floor_number)

static func random_choice(items: Array) -> Variant:
    if items.is_empty():
        return null
    return items[randi() % items.size()]

static func modifier_for_floor(floor_number: int) -> Dictionary:
    ## The Lantern-hush belongs to the roost beat — campaign story 13, the
    ## campaign's own final floor, and every endless chapter's thirteenth.
    var story := story_plan(floor_number)
    if story == 13 or story == BeautyEndless.CAMPAIGN_LENGTH:
        return {"name": "Lantern-hush morning", "description": "the Roost rests easy", "heart_rate": 0.55}
    return FLOOR_MODIFIERS[randi() % FLOOR_MODIFIERS.size()].duplicate(true)

