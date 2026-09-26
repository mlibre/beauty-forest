class_name BeautyContent
extends RefCounted

## Canonical game content: styles, wisp types, regions, floors, wares, stanzas,
## counter-melodies, facts and story beats. Behaviour-free data plus the small
## queries that read it. Persistence and loadout math live in BeautyData.

const CAMPAIGN_LENGTH := 13
const MAX_CHARMS := 3
const MAX_STANZAS := 2

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

const WISP_TYPES := {
    "Shambler": {
        "hp": 24.0, "speed": 2.1, "damage": 8.0, "soul": 6.0, "scale": 1.0, "color": "#7fae6a",
        "grumbles": ["I lost my hat down here.", "Is it Tuesday?", "The dusk is very opinionated. In a cozy way."],
        "farewells": ["Ah. That is better.", "Thank you! I left the stove on!", "Tell my cactus I love it."],
    },
    "Crawler": {
        "hp": 14.0, "speed": 3.4, "damage": 5.0, "soul": 4.0, "scale": 0.75, "color": "#b07a72",
        "grumbles": ["Must scuttle! Busy! Very busy!", "No time! Things to bump into!"],
        "farewells": ["Oh! I can see my house from here!", "Zipping off — byeee!"],
    },
    "Warden": {
        "hp": 55.0, "speed": 1.7, "damage": 14.0, "soul": 15.0, "scale": 1.45, "color": "#7288b5", "shielder": true,
        "grumbles": ["I guard a door that leads nowhere.", "Rules! I have so many rules!"],
        "farewells": ["Finally… off shift.", "You are promoted. To friend."],
    },
    "Hummingbird": {
        "hp": 10.0, "speed": 4.6, "damage": 3.0, "soul": 8.0, "scale": 0.6, "color": "#d4b05a", "flighty": true,
        "grumbles": ["Can’t catch me! Nobody ever catches me!", "Too many feelings, must flit!"],
        "farewells": ["You caught me. Emotionally.", "Okay okay, I’ll slow down!"],
    },
    "Dandelion": {
        "hp": 12.0, "speed": 3.0, "damage": 4.0, "soul": 7.0, "scale": 0.7, "color": "#f0e6c8", "flighty": true,
        "grumbles": ["I was a wish once. It went great!", "Puff! Did you feel that breeze? That was me.", "Hold still, I am trying to drift dramatically."],
        "farewells": ["Landing softly. Like a proper wish.", "Tell the wind I said thanks!"],
    },
    "Pebble": {
        "hp": 40.0, "speed": 1.5, "damage": 10.0, "soul": 10.0, "scale": 0.9, "color": "#b8b0a0",
        "grumbles": ["I am not lost. I am sediment.", "Rolling is just falling with confidence."],
        "farewells": ["Ah. A nice sunny spot. I shall sit here forever.", "You rock. I would know."],
    },
    "Teacup": {
        "hp": 20.0, "speed": 2.4, "damage": 6.0, "soul": 6.0, "scale": 0.85, "color": "#86c8c0",
        "grumbles": ["I am mostly tea. The wisp part is garnish.", "Careful! I slosh when startled."],
        "farewells": ["Mmm. All warmed through now.", "Do visit for tea sometime. I insist."],
    },
    "Mossbell": {
        "hp": 55.0, "speed": 1.6, "damage": 12.0, "soul": 15.0, "scale": 1.3, "color": "#c79df0",
        "grumbles": ["Dong. Sorry. That just happens now.", "I ring very slowly. It is called ambience.", "Moss takes ages to grow. I can wait."],
        "farewells": ["A final soft chime, just for you.", "The ringing fades. The cozy stays."],
    },
    "Lantern Moth": {
        "hp": 16.0, "speed": 2.2, "damage": 5.0, "soul": 9.0, "scale": 0.8, "color": "#f7c98a", "flighty": true, "lingers": true,
        "grumbles": ["Just circling. Lovingly.", "Your lantern smells like warm honey. Compliments.", "I live here now. By the light. Hope that is fine."],
        "farewells": ["Fluttering home, pockets full of glow.", "Tell the lantern I said thanks for the warmth!"],
    },
    "Giggle Puff": {
        "hp": 30.0, "speed": 2.6, "damage": 7.0, "soul": 8.0, "scale": 1.0, "color": "#f2a0b0", "splits_gently": true,
        "grumbles": ["Hee! That tickles! Everything tickles!", "I am full of giggles and cannot hold them. Hee!"],
        "farewells": ["Hee-hee! Splitting happily ever after!", "Two giggles are better than one! Byeee!"],
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
]

const FLOOR_MODIFIERS := [
    {},
    {"name": "Extra hearts tonight", "description": "grateful wisps leave more thank-you hearts", "heart_rate": 0.60},
    {"name": "Rich souls", "description": "wisps carry extra soul-light (+50% soul)", "soul": 1.50},
    {"name": "Brisk wisps", "description": "everyone is a little speedier today", "speed": 1.25},
    {"name": "Lantern festival", "description": "the wood is gentler; wisps notice you later", "aggro": 0.70},
    {"name": "Dewbright morning", "description": "thank-you hearts drift gently toward you", "heart_drift": true},
    {"name": "Kind updrafts", "description": "updrafts carry song-notes 20% farther", "note_range": 1.20},
    {"name": "Bouncy caps", "description": "mushroom caps bounce hearts toward you", "heart_drift": true},
    {"name": "Firefly evening", "description": "fireflies hum along: song-notes fly a little farther", "note_range": 1.15},
    {"name": "Honeyed air", "description": "everything feels possible: richer souls and warmer hearts", "soul": 1.20, "heart_rate": 0.15},
]

const CHARMS := [
    {"key": "tea", "name": "Warm Tea", "description": "Restores all warmth instantly", "price": 3},
    {"key": "boots", "name": "Swift Boots", "description": "Walk 15% swifter this run", "price": 5, "speed": 1.15},
    {"key": "scarf", "name": "Wool Scarf", "description": "+30 max warmth; itchy-nice", "price": 6, "max_hp": 30},
    {"key": "echo", "name": "Echo Chime", "description": "Lantern song recharges 35% faster", "price": 7, "cooldown": 0.65},
    {"key": "ember", "name": "Ember Mitten", "description": "Song-notes glow 20% warmer", "price": 6, "song_damage": 1.20},
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

const FACTS := [
    "Octopuses have three hearts — two just for the gills.",
    "Honey found in ancient Egyptian tombs is still perfectly edible.",
    "Bananas are berries; strawberries are not.",
    "A day on Venus is longer than its year.",
    "Sea otters hold hands while sleeping so they don’t drift apart.",
    "The Eiffel Tower grows about 15 cm taller in summer heat.",
    "Wombats produce cube-shaped droppings. Science remains polite about it.",
    "There are more possible chess games than atoms in the observable universe.",
    "Some turtles can breathe through their rear ends. Nature is resourceful.",
    "Sunlight takes about eight minutes to reach us. You are seeing the past!",
    "A group of flamingos is called a flamboyance.",
    "Oxford University is older than the Aztec Empire.",
    "Banana plants are giant herbs, not trees.",
    "Cows have best friends and get stressed when separated.",
    "Butterflies taste with their feet.",
    "Hot water can freeze faster than cold water under the right conditions.",
    "Fireflies talk to each other in flashes — each species has its own Morse code.",
    "A single teaspoon of honey is the life's work of about twelve bees.",
    "Otters hold hands while sleeping so they don't drift apart — twice as cozy as rumored.",
    "Mushrooms breathe out a little mist every night, like tiny forest kettles.",
    "A snail can sleep for three years when the weather is unkind. Relatable.",
    "Dandelion seeds can ride the wind for miles on their tiny parachutes.",
    "Bees can recognize human faces, and they gossip about the kind ones.",
    "Trees share sugar with their seedlings through underground fungal post.",
]

const MOTE_LINES := [
    "You’re doing wonderfully. Statistically, even.",
    "Fun fact: I am made of leftover starlight and optimism.",
    "If you get lost, we are lost together. That’s teamwork.",
    "I counted the wisps. There are… several.",
    "You smell like courage. Or bread. Hard to tell down here.",
    "Every floor is new. Like a sandwich, but spatial.",
    "Take your time. The forest has nowhere to be either.",
    "I named a rock earlier. It’s called Kevin. Very reliable.",
    "That mushroom glows because it read a lot as a spore.",
    "Wandering counts as a plan. A lovely, leaf-crunchy plan.",
    "I polished your lantern while you blinked. You blinked beautifully.",
    "The pollen says hello. I translated. It was kind.",
    "My map says we are exactly where the cozy is.",
    "Somewhere a dragon is snoring in your honor. Probably.",
    "No rush, no fuss. The stairs will wait. They are stairs.",
    "I packed snacks. They are made of light. Zero crumbs.",
    "That wisp just waved at you. With its whole body. Charming.",
    "Your lantern is humming in a major key today. Fancy.",
    "I asked a mushroom for directions. It said ‘down, but prettily’.",
    "Somewhere, a pebble is cheering for you. Quietly. Like a pebble.",
    "You walk like someone who waves at trees. The trees noticed.",
    "Deep breath in… smell that? That is Tuesday. Cozy Tuesday.",
]

const SOOTHE_LINES := [
    "Oh, that one floated home smiling. Lovely work.",
    "Gentle! That wisp is practically purring.",
    "Home they go, warm as toast. You did that.",
    "That soothe was softer than a dandelion sneeze.",
    "The lantern sang, the wisp sighed happily. Teamwork.",
    "Guided home! The forest applauds, quietly, with leaves.",
    "That wisp is telling everyone about you. In glows.",
    "Softer than soup! And twice as warming.",
]

const DESCEND_LINES := [
    "Down we go! I will hold the map. And your sleeve. Lightly.",
    "New floor, same wonderful you. The stairs approve.",
    "Mind the first step. It is dramatic and loves attention.",
    "Deeper still! The cozy thickens most beautifully.",
    "I can smell adventure. Or soup. Either way, onward.",
    "Another floor, another blanket of moss. The forest shows off for you.",
    "Careful, the stairs are showing off their glow again.",
]

const FEELINGS := {
    4: {"name": "The Lonely", "farewell": "Thank you for sitting with me. I feel found."},
    8: {"name": "The Hurried", "farewell": "Slowing down… together… ahh. That is the whole trick."},
    12: {"name": "The Snuffly", "farewell": "*sniff* Blew my nose on a star. Feel much better now."},
}

const STORY := {
    1: ["The Descent Begins", "Mote heard a rumor: far below sleeps a dragon who hasn’t napped properly in centuries. You two will fix that."],
    2: ["A Warm Draft", "Warm air rises past you, smelling of moss and lavender. ‘Dragons snore harmonically,’ Mote whispers, impressed."],
    3: ["Distant Thunder", "A slow, rumbling snore shakes dust from the canopy. The wisps below seem calmer near it."],
    4: ["The Lullaby Problem", "Mote explains: the dragon wakes grumpy without five Dream Chimes sung in harmony. They’re lost on the floor below. Naturally."],
    5: ["Snoozle’s Nap Chamber", "Five chimes glimmer among the roots. ‘Snoozle!’ Mote squeaks. ‘Remember: E on the gold, gentle as pancakes.’"],
    6: ["Snoozle Sleeps Soundly", "Mote waves goodbye. ‘One dragon tucked in! But she mumbled about cousins below. Big family. Bigger snores.’"],
    7: ["Pollen Postcards", "Golden pollen drifts up like tiny letters. ‘The cousins write in sneezes,’ Mote translates, sneezing fluently."],
    8: ["The Family Hum", "Every snore down here harmonizes. ‘That’s a family choir,’ Mote whispers. ‘Snoozle is the soprano. Obviously.’"],
    9: ["Mushroom Mail", "A cap bounces a heart-shaped spore toward you. ‘A gift from the Roost!’ Mote declares. ‘Or lunch. Either way, heartwarming.’"],
    10: ["Cousin Rumbles", "The floor purrs like a giant kettle. ‘That’s not one dragon,’ Mote says. ‘That’s a whole cuddle-pile.’"],
    11: ["Lullaby Practice", "Mote rehearses his softest hum. ‘The Roost is near. Grandma dragons are picky about lullabies.’"],
    12: ["Almost to the Roost", "Warm light pools from below. ‘Nearly there,’ Mote breathes. ‘Tuck in your scarf. Family reunions need coziness.’"],
    13: ["The Roost", "The Roost glows like the inside of a lantern. Snoozle’s whole family dreams here — time for the biggest, softest lullaby."],
}

const SIGNS := [
    "Wander kindly. Rest often.",
    "Wisps: please stop losing yourselves.",
    "Free hugs. Ask the glowing one.",
    "Beware: excellent moss ahead.",
    "Stairs down. Or up. Perspective.",
    "This grove is swept daily.",
    "Lost? Me too. Lovely evening though.",
    "Nap often. The ferns insist.",
    "You are exactly where the cozy is.",
    "Sing softly. The walls hum along.",
    "Kevin the rock was here. Still reliable.",
    "No grumps past this point, by decree.",
    "Honk softly if you love lanterns.",
    "This way to the coziest moss. All ways, actually.",
    "Wisps guided home today: too many to count, happily.",
]

const STICKERS := {
    "first_nap": "First Nap", "dragon_friend": "Dragon Friend", "big_hug": "Big Hug",
    "pacifist": "Not A Single Bump", "shopper": "Peddle’s Favorite", "long_lullaby": "Long-Distance Lullaby",
    "century": "Century of Kindness", "fact_finder": "Curious Mind", "feeling_friend": "Feeling Friend",
    "curious": "Curious Companion", "kindling": "Kindling Light",
}

static func story_floor(floor_number: int) -> int:
    return ((floor_number - 1) % CAMPAIGN_LENGTH) + 1

static func region_for_floor(floor_number: int) -> Dictionary:
    var story := story_floor(floor_number)
    for region: Dictionary in REGIONS:
        if story >= int(region["min"]) and story <= int(region["max"]):
            return region
    return REGIONS[0]

static func is_dragon_floor(floor_number: int) -> bool:
    return story_floor(floor_number) in [5, 13]

static func random_choice(items: Array) -> Variant:
    if items.is_empty():
        return null
    return items[randi() % items.size()]

static func random_modifier(story: int) -> Dictionary:
    if story == 13:
        return {"name": "Lantern-hush morning", "description": "the Roost rests easy", "heart_rate": 0.55}
    return FLOOR_MODIFIERS[1 + (randi() % (FLOOR_MODIFIERS.size() - 1))].duplicate(true)

static func wisp_pool(floor_number: int) -> Array:
    if floor_number == 1:
        return [["Shambler", 40], ["Crawler", 60], ["Dandelion", 8], ["Teacup", 8], ["Lantern Moth", 6]]
    return [
        ["Shambler", 40], ["Crawler", 33], ["Warden", 15], ["Hummingbird", 12],
        ["Dandelion", 8], ["Teacup", 8], ["Pebble", 7], ["Mossbell", 7],
        ["Lantern Moth", 6], ["Giggle Puff", 6],
    ]

static func pick_wisp_type(floor_number: int) -> String:
    var pool := wisp_pool(floor_number)
    var total := 0
    for entry: Array in pool:
        total += int(entry[1])
    var roll := randi() % total
    for entry: Array in pool:
        roll -= int(entry[1])
        if roll < 0:
            return String(entry[0])
    return "Shambler"
