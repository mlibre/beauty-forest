class_name FloorSurprise
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")
const Adventures := preload("res://scripts/floor_surprise_adventures.gd")

## Every floor hides exactly one small surprise — a place you stumble on, not
## a task you are given. The kind is chosen deterministically from the floor
## number, so a floor is itself ("the mushroom-ring floor") and neighbouring
## floors never repeat, while the dungeon around it is freshly random every
## walk. All props are the game's own primitives; nothing here can hurt, and
## every reward is small by design — the surprise IS the reward.
##
## Three of the kinds are little ADVENTURES rather than single finds: a
## firefly chase, a star trail to walk in order, a shell that answers a
## listen. Every one of them is strictly optional — none is ever counted as
## an objective, none gates the stair, and a hero who ignores the whole lot
## descends exactly as freely as one who chased every firefly. The reward is
## a few sparkles or a heart, never progress.

const KINDS: Array = [
    {"key": "picnic", "name": "a wisp picnic", "line": "Three wisps are sharing something on a blanket."},
    {"key": "star_glade", "name": "a star glade", "line": "A little ring of stars hums in a clearing."},
    {"key": "singing_ring", "name": "a singing mushroom ring", "line": "Mushrooms stand in a perfect circle, waiting."},
    {"key": "wisp_choir", "name": "a wisp choir", "line": "Three little wisps hum a round, off-key and earnest."},
    {"key": "lantern_bloom", "name": "a lantern bloom", "line": "Five unlit lantern-flowers lean toward the path."},
    {"key": "comet_log", "name": "a comet-watching log", "line": "A soft log sits alone, pointed at the sky."},
    {"key": "lantern_release", "name": "a waiting sky-lantern", "line": "A little paper lantern rests on a stick, ready to fly."},
    {"key": "mossy_doodle", "name": "a mossy doodle", "line": "Something drew a glowing picture in the moss."},
    {"key": "balloon_puffs", "name": "balloon puffs", "line": "A few round puffs float just above the grass."},
    {"key": "treasure_sprout", "name": "a treasure sprout", "line": "A golden sprout shivers in the shade, thirsty."},
    {"key": "firefly_chase", "name": "a firefly chase", "line": "Three fireflies zigzag above the grass, playing catch-me."},
    {"key": "rainbow_puddle", "name": "a rainbow puddle", "line": "A shallow puddle holds a whole small rainbow."},
    {"key": "star_trail", "name": "a star trail", "line": "Little blue stars dot a winding path, one after another."},
    {"key": "mushroom_house", "name": "a mushroom house", "line": "A tiny round door waits under a big red cap."},
    {"key": "echo_shell", "name": "an echo shell", "line": "A big spiral shell sits quietly, holding a sound."},
    {"key": "shooting_star", "name": "a fallen star", "line": "A small star steams gently in the grass, still warm."},
    {"key": "hedge_nook", "name": "a hedge nook", "line": "A soft leaf bed hides in the hedge, big enough for a nap."},
    {"key": "butterfly_parade", "name": "a butterfly parade", "line": "Butterflies cross the clearing in a slow glittering line."},
    {"key": "dew_web", "name": "a dew-web harp", "line": "Four dewdrops hang from a silver web, heavy with waiting."},
]

## The multipliers that keep consecutive floors on different surprises: the
## step shares no factor with the wheel's size (7 against 19), so stepping
## one floor always turns the wheel to a different kind, and a full turn of
## the wheel visits every kind.
const WHEEL_STEP := 7

## The verb the context hint speaks for each kind a PRESS can answer, or ""
## when the kind answers proximity instead (the glade warms, the bloom lights,
## the puffs pop — no button involved). The hint pill, the touch action
## button and the press itself all read from this one table, so the three can
## never disagree about what E does beside a surprise.
static func verb_for(key: String) -> String:
    match key:
        "picnic":
            return "Share the picnic"
        "singing_ring":
            return "Join the song"
        "comet_log":
            return "Watch the comet"
        "mossy_doodle":
            return "Look closer"
        "echo_shell":
            return "Listen to the shell"
        "wisp_choir":
            return "Hum along"
        "lantern_release":
            return "Release the lantern"
        "treasure_sprout":
            return "Water the sprout"
        "mushroom_house":
            return "Knock on the door"
        "shooting_star":
            return "Greet the star"
    return ""

static func kind_for_floor(floor_number: int) -> Dictionary:
    return KINDS[posmod(int(floor_number) * WHEEL_STEP, KINDS.size())]

## Build the surprise in `parent` at a free cell far from the spawn clearing,
## and hand the node back (or null if the floor has nowhere to put one). The
## node carries its state in meta, so the run chain can poll it without
## holding a second copy of the truth.
static func spawn(parent: Node3D, dungeon: Dictionary, rng: RandomNumberGenerator, floor_number: int, occupied: Dictionary) -> Node3D:
    var kind := kind_for_floor(floor_number)
    var spawn_room: Dictionary = dungeon["rooms"][0]
    var cell := DungeonGenerator.random_floor_cell(dungeon, rng, Vector2(spawn_room["cx"], spawn_room["cy"]), 9.0, occupied)
    occupied[cell] = true
    var at := Vector3(float(cell.x), 0.0, float(cell.y))
    var root := Node3D.new()
    root.name = "FloorSurprise"
    root.position = at
    root.set_meta("surprise_key", String(kind["key"]))
    root.set_meta("surprise_name", String(kind["name"]))
    root.set_meta("surprise_used", false)
    match String(kind["key"]):
        "picnic":
            _build_picnic(root)
        "star_glade":
            _build_star_glade(root)
        "singing_ring":
            _build_singing_ring(root)
        "lantern_bloom":
            _build_lantern_bloom(root, rng)
        "comet_log":
            _build_comet_log(root)
        "mossy_doodle":
            _build_mossy_doodle(root)
        "balloon_puffs":
            _build_balloon_puffs(root, rng)
        "firefly_chase":
            _build_firefly_chase(root, rng)
        "star_trail":
            _build_star_trail(root, rng)
        "echo_shell":
            _build_echo_shell(root)
        "wisp_choir":
            Adventures._build_wisp_choir(root)
        "lantern_release":
            Adventures._build_lantern_release(root)
        "treasure_sprout":
            Adventures._build_treasure_sprout(root)
        "rainbow_puddle":
            Adventures._build_rainbow_puddle(root)
        "mushroom_house":
            Adventures._build_mushroom_house(root)
        "shooting_star":
            Adventures._build_shooting_star(root)
        "hedge_nook":
            Adventures._build_hedge_nook(root)
        "butterfly_parade":
            Adventures._build_butterfly_parade(root, rng)
        "dew_web":
            _build_dew_web(root)
    # The scatter around the surprise's cell is blind to the forest the
    # generator just drew: a bulb, a puff, a firefly or a star can land
    # inside a grove trunk's collision box, where the hero can never walk
    # close enough to answer it -- and an optional adventure that cannot be
    # finished is a small lie. Pull walled-in props home to the surprise's
    # own cell (a proven floor cell), keeping their height.
    _keep_reachable(root, dungeon)
    parent.add_child(root)
    return root

## Props whose world cell is not a floor cell come home: their horizontal
## offset shrinks to a sliver of the surprise's own cell, which the spawner
## chose from the floor. Both sampling conventions are checked (floor and
## round), because a prop sitting exactly on a cell boundary reads as floor
## to one and wall to the other -- and a prop that is reachable under only
## one of them is a prop a bump or a nudge can take away.
static func _keep_reachable(root: Node3D, dungeon: Dictionary) -> void:
    var base := Vector2(root.position.x, root.position.z)
    var pulled := 0
    for child in root.get_children():
        var prop := child as Node3D
        if prop == null or prop == root:
            continue
        var world := base + Vector2(prop.position.x, prop.position.z)
        if _is_floor_cell(dungeon, world):
            continue
        # The sliver has to stay INSIDE the root's own cell: the root stands
        # at the cell's corner (an integer position), so keeping the offset's
        # sign at one-tenth -- or any offset past half a cell -- landed the
        # rescued prop in the NEIGHBOURING cell, which on a walled border is
        # exactly the wall the rescue came from. Pulled props queue along the
        # inner diagonal instead, where floor and round both read the root's
        # own cell and every rescued prop keeps its own spot on the strand.
        var step := 0.10 + 0.07 * float(pulled)
        prop.position = Vector3(step, prop.position.y, step)
        pulled += 1

## Whether a world-space position sits on a cell the hero can walk to, under
## both sampling conventions (floor and round): a prop on a cell boundary is
## reachable under one and lost under the other, and reachable is the only
## honest answer.
static func _is_floor_cell(dungeon: Dictionary, world: Vector2) -> bool:
    return DungeonGenerator.is_floor(dungeon, int(floor(world.x)), int(floor(world.y))) \
        and DungeonGenerator.is_floor(dungeon, int(round(world.x)), int(round(world.y)))

static func _pbr(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.82
    return material

static func glow(color: Color, energy: float = 1.6) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    return material

static func _ball(radius: float, color: Color, lit: bool = false) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    visual.mesh = mesh
    visual.material_override = glow(color) if lit else _pbr(color)
    return visual

## The dew-web harp: a silver web strung low, carrying four hanging dewdrops
## at fixed points of the compass-plus-diagonal so every one sits in a spot a
## hero can stand beneath. The drops are direct children named Drop0..3 -- the
## same contract the star trail's Star0..4 keep -- so the reachability pass
## can pull a walled-in drop home and the run chain can find each one.
static func _build_dew_web(root: Node3D) -> void:
    var web := MeshInstance3D.new()
    var web_mesh := CylinderMesh.new()
    web_mesh.top_radius = 0.95
    web_mesh.bottom_radius = 0.95
    web_mesh.height = 0.03
    web.mesh = web_mesh
    web.material_override = _pbr(Color("#cdd9e8"))
    web.position = Vector3(0, 1.15, 0)
    root.add_child(web)
    var bead := _ball(0.05, Color("#e8f0fa"), true)
    bead.position = Vector3(0, 1.17, 0)
    root.add_child(bead)
    for index in range(4):
        var angle := TAU * float(index) / 4.0 + 0.4
        var drop := _ball(0.09, Color("#bfe8ff"), true)
        drop.name = "Drop%d" % index
        drop.position = Vector3(cos(angle) * 0.55, 0.62, sin(angle) * 0.55)
        root.add_child(drop)

static func _build_picnic(root: Node3D) -> void:
    # A checkered blanket (two flat boxes), a basket, and three little guests
    # seated around it.
    var blanket := MeshInstance3D.new()
    var blanket_mesh := BoxMesh.new()
    blanket_mesh.size = Vector3(1.7, 0.04, 1.7)
    blanket.mesh = blanket_mesh
    blanket.material_override = _pbr(Color("#c9564e"))
    blanket.position = Vector3(0, 0.02, 0)
    root.add_child(blanket)
    for corner: Vector3 in [Vector3(0.42, 0.03, 0.42), Vector3(-0.42, 0.03, -0.42)]:
        var patch := MeshInstance3D.new()
        var patch_mesh := BoxMesh.new()
        patch_mesh.size = Vector3(0.42, 0.05, 0.42)
        patch.mesh = patch_mesh
        patch.material_override = _pbr(Color("#f2e3c2"))
        patch.position = corner
        root.add_child(patch)
    var basket := _ball(0.16, Color("#a8794a"))
    basket.scale = Vector3(1.0, 0.7, 1.0)
    basket.position = Vector3(0, 0.16, -0.55)
    root.add_child(basket)
    for angle: float in [0.0, 2.1, 4.2]:
        var guest := _ball(0.14, Color("#fff3c8"), true)
        guest.position = Vector3(cos(angle) * 1.05, 0.34, sin(angle) * 1.05)
        root.add_child(guest)

static func _build_star_glade(root: Node3D) -> void:
    for index in range(7):
        var angle := TAU * float(index) / 7.0
        var star := _ball(0.11, Color("#fff3a0"), true)
        star.position = Vector3(cos(angle) * 1.9, 0.42 + sin(float(index) * 2.1) * 0.12, sin(angle) * 1.9)
        root.add_child(star)

static func _build_singing_ring(root: Node3D) -> void:
    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var cap := MeshInstance3D.new()
        var cap_mesh := CylinderMesh.new()
        cap_mesh.top_radius = 0.01
        cap_mesh.bottom_radius = 0.24
        cap_mesh.height = 0.22
        cap.mesh = cap_mesh
        cap.material_override = _pbr(Color("#c98a5e"))
        cap.position = Vector3(cos(angle) * 1.7, 0.32, sin(angle) * 1.7)
        root.add_child(cap)
        var stem := MeshInstance3D.new()
        var stem_mesh := CylinderMesh.new()
        stem_mesh.top_radius = 0.07
        stem_mesh.bottom_radius = 0.09
        stem_mesh.height = 0.32
        stem.mesh = stem_mesh
        stem.material_override = _pbr(Color("#efe3c8"))
        stem.position = Vector3(cos(angle) * 1.7, 0.16, sin(angle) * 1.7)
        root.add_child(stem)

static func _build_lantern_bloom(root: Node3D, rng: RandomNumberGenerator) -> void:
    for index in range(5):
        var angle := TAU * float(index) / 5.0 + rng.randf_range(-0.2, 0.2)
        var spot := Vector3(cos(angle) * 1.8, 0, sin(angle) * 1.8)
        var stem := MeshInstance3D.new()
        var stem_mesh := CylinderMesh.new()
        stem_mesh.top_radius = 0.04
        stem_mesh.bottom_radius = 0.06
        stem_mesh.height = 0.5
        stem.mesh = stem_mesh
        stem.material_override = _pbr(Color("#6f9c52"))
        stem.position = spot + Vector3(0, 0.25, 0)
        root.add_child(stem)
        # Unlit until the hero leans in: the bulb carries a dead grey glass
        # now, and the run chain swaps its material for a lit one.
        var bulb := _ball(0.16, Color("#8a8a7a"))
        bulb.name = "Bulb%d" % index
        bulb.position = spot + Vector3(0, 0.62, 0)
        root.add_child(bulb)

static func _build_comet_log(root: Node3D) -> void:
    var log := MeshInstance3D.new()
    var log_mesh := CylinderMesh.new()
    log_mesh.top_radius = 0.26
    log_mesh.bottom_radius = 0.26
    log_mesh.height = 1.8
    log.mesh = log_mesh
    log.material_override = _pbr(Color("#7b593c"))
    log.rotation.z = PI * 0.5
    log.position = Vector3(0, 0.26, 0)
    root.add_child(log)
    # The comet itself arrives on watch; its seat of light marks the spot.
    var ember := _ball(0.10, Color("#ffe2a0"), true)
    ember.position = Vector3(0.55, 0.45, 0)
    root.add_child(ember)

static func _build_mossy_doodle(root: Node3D) -> void:
    var stone := MeshInstance3D.new()
    var stone_mesh := SphereMesh.new()
    stone_mesh.radius = 0.55
    stone_mesh.height = 0.6
    stone.mesh = stone_mesh
    stone.material_override = _pbr(Color("#9aa27c"))
    stone.scale = Vector3(1.0, 0.6, 1.0)
    stone.position = Vector3(0, 0.18, 0)
    root.add_child(stone)
    # A little spiral of glowing moss, the forest's own doodle.
    for index in range(12):
        var angle := float(index) * 0.7
        var radius := 0.08 + float(index) * 0.035
        var dot := _ball(0.045, Color("#bfe98a"), true)
        dot.position = Vector3(cos(angle) * radius, 0.46, sin(angle) * radius)
        root.add_child(dot)

static func _build_balloon_puffs(root: Node3D, rng: RandomNumberGenerator) -> void:
    for index in range(4):
        var puff := _ball(0.30, Color("#ffd1dc"))
        puff.name = "Puff%d" % index
        puff.position = Vector3(
            rng.randf_range(-1.6, 1.6),
            rng.randf_range(0.7, 1.4),
            rng.randf_range(-1.6, 1.6))
        root.add_child(puff)

static func _build_firefly_chase(root: Node3D, rng: RandomNumberGenerator) -> void:
    ## Three fireflies scattered a small wander apart. Nothing chases back:
    ## the hero walks to each one and the chase is over in twenty gentle
    ## seconds — a sprint for a toddler, a stroll for everyone else.
    for index in range(3):
        var fly := _ball(0.12, Color("#fff3a0"), true)
        fly.name = "Fly%d" % index
        var angle := TAU * float(index) / 3.0 + rng.randf_range(-0.3, 0.3)
        var reach := rng.randf_range(1.3, 2.0)
        fly.position = Vector3(cos(angle) * reach, rng.randf_range(0.55, 1.0), sin(angle) * reach)
        root.add_child(fly)

static func _build_star_trail(root: Node3D, rng: RandomNumberGenerator) -> void:
    ## Five blue stars in a short winding path, meant to be walked in order:
    ## the game only answers the NEXT star, so the trail teaches its own
    ## sequence and never asks the hero to read a word about it.
    var angle := rng.randf_range(0.0, TAU)
    for index in range(5):
        angle += rng.randf_range(0.55, 1.05)
        var star := _ball(0.10, Color("#bfe8ff"), true)
        star.name = "Star%d" % index
        star.position = Vector3(cos(angle) * 1.6, 0.34 + float(index) * 0.04, sin(angle) * 1.6)
        root.add_child(star)

static func _build_echo_shell(root: Node3D) -> void:
    ## A big spiral shell that holds the forest's own hum. One press, one
    ## chord, one small blessing — the quietest kind of adventure.
    var shell := MeshInstance3D.new()
    var shell_mesh := SphereMesh.new()
    shell_mesh.radius = 0.42
    shell_mesh.height = 0.72
    shell.mesh = shell_mesh
    shell.material_override = _pbr(Color("#e8d8b8"))
    shell.scale = Vector3(1.0, 0.82, 1.0)
    shell.position = Vector3(0, 0.30, 0)
    root.add_child(shell)
    var mouth := MeshInstance3D.new()
    var mouth_mesh := CylinderMesh.new()
    mouth_mesh.top_radius = 0.28
    mouth_mesh.bottom_radius = 0.28
    mouth_mesh.height = 0.03
    mouth_mesh.radial_segments = 14
    mouth.mesh = mouth_mesh
    mouth.material_override = _pbr(Color("#c9b088"))
    mouth.position = Vector3(0.10, 0.40, 0.30)
    mouth.rotation.x = PI * 0.42
    root.add_child(mouth)
    var pearl := _ball(0.07, Color("#ffe9c8"), true)
    pearl.position = Vector3(-0.10, 0.55, -0.05)
    root.add_child(pearl)
