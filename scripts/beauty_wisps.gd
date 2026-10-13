class_name BeautyWisps
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyEndless := preload("res://scripts/beauty_endless.gd")

## The wisps of the forest: who lives here, who visits each floor, and how
## the meeting is rolled. Split out of BeautyContent when that file outgrew
## the 500-line ceiling -- the wisp tables are their own domain, read by the
## wisp bodies, the glyph book and the growth suites.

const WISP_TYPES := {
    "Shambler": {
        "hp": 24.0, "speed": 2.1, "damage": 8.0, "soul": 6.0, "scale": 1.0, "color": "#7fae6a",
        "grumbles": ["I lost my hat down here.", "Is it Tuesday?", "The dusk is very opinionated. In a friendly way."],
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
        "farewells": ["A final soft chime, just for you.", "The ringing fades. The quiet stays."],
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
    "Puffcap": {
        "hp": 36.0, "speed": 1.8, "damage": 9.0, "soul": 12.0, "scale": 1.1, "color": "#e8b78a", "lingers": true,
        "grumbles": ["I am 90% hat. The rest is also hat.", "Spores are my love language."],
        "farewells": ["Off to spore somewhere sunnier!", "Keep a puff for yourself. On me."],
    },
    "Comet": {
        "hp": 12.0, "speed": 5.2, "damage": 4.0, "soul": 14.0, "scale": 0.65, "color": "#ffd98a", "flighty": true,
        "grumbles": ["Wheee—sorry—wheee!", "I have somewhere to be! Everywhere! All at once!"],
        "farewells": ["Tail of gold, heart of calm. Byeee!", "Slowing down was the adventure. Bye!"],
    },
    "Snugbug": {
        "hp": 64.0, "speed": 1.2, "damage": 11.0, "soul": 16.0, "scale": 1.2, "color": "#c9a2e8",
        "grumbles": ["I am rolled up for warmth. It is working. Mostly.", "Bugs hug back, you know."],
        "farewells": ["Unrolling… ahh. Hello, world.", "A snug bug am I, homeward-bound. Toodle-oo."],
    },
}


static func wisp_pool(floor_number: int) -> Array:
    if floor_number == 1:
        return [["Shambler", 40], ["Crawler", 60], ["Dandelion", 8], ["Teacup", 8], ["Lantern Moth", 6]]
    var pool := [
        ["Shambler", 40], ["Crawler", 33], ["Warden", 15], ["Hummingbird", 12],
        ["Dandelion", 8], ["Teacup", 8], ["Pebble", 7], ["Mossbell", 7],
        ["Lantern Moth", 6], ["Giggle Puff", 6],
    ]
    # The endless depths keep meeting you with newcomers: each chapter rotates
    # the deep types in, so a long walk never settles into the same crowd.
    var rotation := BeautyEndless.deep_wisp_rotation(floor_number)
    if rotation.is_empty():
        return pool
    var deepened := []
    for entry: Array in pool:
        deepened.append([String(entry[0]), int(float(entry[1]) * 0.82)])
    deepened.append_array(rotation)
    return deepened

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
