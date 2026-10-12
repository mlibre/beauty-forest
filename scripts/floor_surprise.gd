class_name FloorSurprise
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")

## Every floor hides exactly one small surprise — a place you stumble on, not
## a task you are given. The kind is chosen deterministically from the floor
## number, so a floor is itself ("the mushroom-ring floor") and neighbouring
## floors never repeat, while the dungeon around it is freshly random every
## walk. All props are the game's own primitives; nothing here can hurt, and
## every reward is small by design — the surprise IS the reward.

const KINDS: Array = [
    {"key": "picnic", "name": "a wisp picnic", "line": "Three wisps are sharing something on a blanket."},
    {"key": "star_glade", "name": "a star glade", "line": "A little ring of stars hums in a clearing."},
    {"key": "singing_ring", "name": "a singing mushroom ring", "line": "Mushrooms stand in a perfect circle, waiting."},
    {"key": "lantern_bloom", "name": "a lantern bloom", "line": "Five unlit lantern-flowers lean toward the path."},
    {"key": "comet_log", "name": "a comet-watching log", "line": "A soft log sits alone, pointed at the sky."},
    {"key": "mossy_doodle", "name": "a mossy doodle", "line": "Something drew a glowing picture in the moss."},
    {"key": "balloon_puffs", "name": "balloon puffs", "line": "A few round puffs float just above the grass."},
]

## The multipliers that keep consecutive floors on different surprises:
## five shares no factor with seven, so stepping one floor always turns the
## wheel to a different kind.
const WHEEL_STEP := 5

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
    parent.add_child(root)
    return root

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
