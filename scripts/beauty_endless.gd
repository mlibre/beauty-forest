class_name BeautyEndless
extends RefCounted

## The Endless Bloom: everything below floor 13.
##
## The base campaign tells one story — Snoozle's family, thirteen floors — and
## the ending screen offers "Wander deeper". What the walker found down there
## used to be the same four regions and the same three Big Feelings wrapped
## around again, which quietly retracted the game's whole promise: nothing in
## this forest has a ceiling, but past the Roost the scenery started looping.
##
## So every chapter of thirteen floors past the campaign composes its OWN
## region, its own two Big Feelings, its own story vignettes and its own finale
## dragon, from the warm pools below, seeded by the chapter number. The same
## chapter is always the same forest (saves, waymarks and word of mouth stay
## true), and the name walk visits every adjective x noun pairing exactly once
## before it cycles -- no two of the first 196 chapters ever read alike.

## The campaign's floor count lives here, not in BeautyContent: the content
## tables ask this module endless questions (region, feeling, story), so every
## dependency between the two must point one way -- content -> endless. A const
## borrowed back the other way would be a cycle no loader can resolve.
const CAMPAIGN_LENGTH := 13

const CHAPTER_LENGTH := 13

## Ambient moods the music already knows. Every composed region borrows one,
## so the score keeps its four voices and no chapter adds a new stream.
const AMBIENT_MOODS := ["sunlit-roots", "pollen-halls", "mushroom-lull", "roost"]

const REGION_ADJECTIVES := [
    "Amber", "Honey", "Gilded", "Peach", "Copper", "Candied", "Sunwarmed",
    "Rosy", "Golden", "Maple", "Buttercup", "Pollen", "Lantern", "Cinnamon",
]
const REGION_NOUNS := [
    "Hollow", "Terrace", "Grove", "Fen", "Meadows", "Warrens", "Vale",
    "Rootways", "Boughs", "Clearing", "Steps", "Loft", "Underglade", "Thickets",
]
const REGION_ENTRIES := [
    "%s smells of warm bread and old sunlight. Mote says maps down here are more of a hopeful art.",
    "The %s hum in a major key. Everything here is two shades cozier than the floor above.",
    "Warm light pools between the roots of the %s like it has all the time in the world. It does.",
    "Someone hung tiny lanterns through the %s. Nobody lives here. The forest just likes light.",
    "The %s drift past like slow golden weather. Mote sneezes, apologizes to the air, sneezes again.",
    "The moss in the %s is the exact temperature of a just-finished nap. Verified personally.",
    "Fireflies in the %s blink in slow patterns, spelling something kind in a language nobody remembers.",
    "A breeze through the %s carries the sound of a very large yawn from far below.",
]

## Bright, warm palettes — each a full region set, nudged per chapter so no two
## chapters read identical but none ever drifts dark (AGENTS.md forbids it).
const REGION_PALETTES := [
    {"sky": "#f8e7ae", "horizon": "#fff3c4", "fog": "#dbe6a3", "sun": "#ffe29a", "foliage": "#65b947", "tip": "#b7dc55", "flower": "#ffd1e8", "ground": "#87bd62", "accent": "#fff0a5"},
    {"sky": "#f6d890", "horizon": "#ffe6a3", "fog": "#e9d78f", "sun": "#ffd06a", "foliage": "#91b943", "tip": "#dac95b", "flower": "#ffe98d", "ground": "#a8bf55", "accent": "#fff2aa"},
    {"sky": "#f4c98d", "horizon": "#ffd9a8", "fog": "#e5c08d", "sun": "#ffc06e", "foliage": "#b68150", "tip": "#e3b66d", "flower": "#d9c8ff", "ground": "#9ba552", "accent": "#ffd58d"},
    {"sky": "#f9e3b8", "horizon": "#fff1cf", "fog": "#e3e2a8", "sun": "#ffe69c", "foliage": "#7cbf58", "tip": "#c3e060", "flower": "#ffc9de", "ground": "#8fc267", "accent": "#ffedb0"},
    {"sky": "#f2d49b", "horizon": "#ffe2ae", "fog": "#e7cf94", "sun": "#ffd47c", "foliage": "#a3b948", "tip": "#d4cc60", "flower": "#fff0a0", "ground": "#a9bd58", "accent": "#fff4b8"},
    {"sky": "#f8ddad", "horizon": "#ffeec2", "fog": "#ecd7a2", "sun": "#ffdb8a", "foliage": "#8bb94e", "tip": "#c8d95e", "flower": "#ffd9ec", "ground": "#97c05f", "accent": "#ffeaa8"},
    {"sky": "#f5cf9a", "horizon": "#ffddab", "fog": "#e9c98f", "sun": "#ffca70", "foliage": "#9db054", "tip": "#d8c366", "flower": "#ffe4a8", "ground": "#a5b757", "accent": "#ffefae"},
    {"sky": "#fae6bb", "horizon": "#fff4d2", "fog": "#e6e0a6", "sun": "#ffe79e", "foliage": "#6fb850", "tip": "#bbe05e", "flower": "#ffd5e4", "ground": "#8ac063", "accent": "#fff2b4"},
]

const FEELING_NAMES := [
    "The Wistful", "The Giggly", "The Dreamy", "The Meandering", "The Toasty",
    "The Forgetful", "The Sockless", "The Overcooked", "The Cotangent", "The Dewy",
    "The Half-Woken", "The Very Polite", "The Slightly Damp", "The Over-Fulled",
]
const FEELING_FAREWELLS := [
    "Thank you. I will remember this warmth on purpose, from now on.",
    "Oh, that is better. I was carrying that around for everyone. I can put it down.",
    "You sat with me the whole way. That was the whole trick, wasn’t it?",
    "I feel approximately nine sizes lighter. Keep the rest.",
    "If you ever need a big soft thing to stand near you, whistle warmly.",
    "I will tell the moss about you. The moss tells everyone, you know.",
    "Ahh. Warm again. Tell the stairs I said thank you.",
    "I was never lost, exactly. I was just very far from somewhere cozy. Like now, but better.",
]

## Story beats composed per chapter, one per story position. `%s` is the region
## name; each keeps the run's gentle plot — cousins below, lullaby practice,
## the family choir — so the endless walk stays one long, warm fairy tale.
const CHAPTER_BEATS := [
    ["Below the %s", "Mote peers over the edge: ‘The light down there is different. Warmer. That is either a cousin or a very confident campfire.’"],
    ["Warm Drafts Again", "Warm air rises through the %s, smelling faintly of cinnamon. ‘Dragons season their naps,’ Mote says, with deep respect."],
    ["A Bigger Snore", "The snore below rattles the pollen. It is in harmony with the floor above. ‘A choir,’ Mote whispers. ‘A warm, enormous choir.’"],
    ["Lullaby Practice, Again", "Mote rehearses in the %s. ‘Every family has its own favorite verse. We will learn theirs. Kindly.’"],
    ["Someone Sleeps Here", "Five Dream Chimes glimmer among the roots of the %s. ‘Cousin wants tucking in,’ Mote translates. ‘Gently. E on the gold.’"],
    ["A Letter in Pollen", "Golden pollen arranges itself into a thank-you note. It is signed with a paw print the size of a hammock."],
    ["The Moss Remembers", "The moss of the %s is patterned like a lullaby sheet. ‘The forest writes things down,’ Mote says. ‘In moss, mostly.’"],
    ["A Very Big Sigh", "An enormous, contented sigh drifts up from below and rustles every leaf at once. Mote holds onto your sleeve, delighted."],
    ["Spore Post", "A mushroom cap bounces a heart-shaped spore toward you, then a second, apologetically. ‘Gifts from deeper down,’ Mote says."],
    ["The Warmth Grows", "The lantern glows easier here, like walking downhill in good company. Mote hums two bars and approves of the acoustics."],
    ["Family Rumors", "‘Grandma dragon down there,’ Mote confides, ‘once slept through a decade and woke up better rested, not grumpy. Aspire.’"],
    ["Nearly There", "Warm light pools below the %s like the inside of a lantern. Mote straightens your scarf without being asked."],
    ["The Next Roost", "This roost is smaller and older and snoozier. The whole family of it dreams here — time for another biggest, softest lullaby."],
]

const DEEP_WISP_ROTATIONS := [
    [["Puffcap", 20], ["Comet", 12], ["Snugbug", 10]],
    [["Comet", 16], ["Snugbug", 16], ["Giggle Puff", 10]],
    [["Puffcap", 14], ["Snugbug", 14], ["Hummingbird", 12]],
]

static func is_endless(floor_number: int) -> bool:
    return floor_number > CAMPAIGN_LENGTH

## The endless chapter a floor belongs to: 1 = floors 14–26, 2 = 27–39, forever.
static func chapter_for_floor(floor_number: int) -> int:
    return (floor_number - CAMPAIGN_LENGTH - 1) / CHAPTER_LENGTH + 1

## The campaign-relative story position (1..13) inside its chapter.
static func story_in_chapter(floor_number: int) -> int:
    return (floor_number - CAMPAIGN_LENGTH - 1) % CHAPTER_LENGTH + 1

## A chapter's composed region. Deterministic per chapter: chapter 7 is always
## the same forest, or saves and stories could not agree about it.
static func region(chapter: int) -> Dictionary:
    ## The name walks every adjective x noun pairing exactly once before it
    ## cycles: chapter c's pairing is unique across the whole 196-chapter bloom
    ## and both words move every chapter, so no two chapters of one run ever
    ## read alike. A seeded draw could not promise that -- it re-served forests
    ## as little as three chapters apart.
    var index := maxi(1, chapter) - 1
    var adjective: String = REGION_ADJECTIVES[index % REGION_ADJECTIVES.size()]
    var noun: String = REGION_NOUNS[((index / REGION_NOUNS.size()) + index) % REGION_NOUNS.size()]
    var name := "%s %s" % [adjective, noun]
    ## Palettes and entry lines stay a seeded, deterministic draw per chapter.
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("endless-palette-%d" % maxi(1, chapter))
    var palette: Dictionary = REGION_PALETTES[rng.randi() % REGION_PALETTES.size()]
    var shift := float(chapter % 5) * 0.02
    var colors := {}
    for field: String in palette:
        var base := Color(String(palette[field]))
        var rotated := base.lerp(Color("#fff2c4"), shift * 0.4)
        colors[field] = "#" + rotated.to_html(false)
    var first_floor := CAMPAIGN_LENGTH + (chapter - 1) * CHAPTER_LENGTH + 1
    var composed := {
        "key": "endless-%d" % chapter,
        "ambient": AMBIENT_MOODS[chapter % AMBIENT_MOODS.size()],
        "name": name,
        "min": first_floor,
        "max": first_floor + CHAPTER_LENGTH - 1,
        "entry": String(REGION_ENTRIES[rng.randi() % REGION_ENTRIES.size()]) % name,
    }
    composed.merge(colors)
    return composed

## The region for any floor: the campaign's own answer below the Roost, a
## composed chapter above it.
static func region_for_floor(floor_number: int) -> Dictionary:
    if not is_endless(floor_number):
        return {}
    return region(chapter_for_floor(floor_number))

## The Big Feeling sitting on this floor, or an empty dict. The campaign keeps
## its hand-placed three; every endless chapter grows two of its own, at the
## same gentle positions (story 4 and 8) so the rhythm below feels learned.
static func feeling_for_floor(floor_number: int) -> Dictionary:
    if not is_endless(floor_number):
        return {}
    var story := story_in_chapter(floor_number)
    if story != 4 and story != 8:
        return {}
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("endless-feeling-%d-%d" % [chapter_for_floor(floor_number), story])
    return {
        "name": FEELING_NAMES[rng.randi() % FEELING_NAMES.size()],
        "farewell": FEELING_FAREWELLS[rng.randi() % FEELING_FAREWELLS.size()],
    }

## The chapter's story vignette for a floor: [title, body]. The campaign keeps
## its hand-written thirteen; endless chapters compose from the beat pool, so
## every floor still opens a new page and no page is a repeat of a base one.
static func story_for_floor(floor_number: int) -> Array:
    if not is_endless(floor_number):
        return []
    var story := story_in_chapter(floor_number)
    var beat: Array = CHAPTER_BEATS[story - 1]
    var region_name := String(region(chapter_for_floor(floor_number))["name"])
    var title := String(beat[0]) % region_name if "%s" in String(beat[0]) else String(beat[0])
    var body := String(beat[1]) % region_name if "%s" in String(beat[1]) else String(beat[1])
    # A per-chapter greeting rides along so chapter openers feel addressed.
    if story == 1:
        body += " Welcome to the %s." % region_name
    return [title, body]

## Deeper floors rotate new wisp types into the pool: the depths are supposed
## to keep meeting you with things you have not soothed yet.
static func deep_wisp_rotation(floor_number: int) -> Array:
    if not is_endless(floor_number):
        return []
    return DEEP_WISP_ROTATIONS[(chapter_for_floor(floor_number) - 1) % DEEP_WISP_ROTATIONS.size()]
