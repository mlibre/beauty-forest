class_name FloorSurpriseAdventures
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")

## The newer half of the floor-surprise builders: the eight adventure kinds
## added when one surprise per floor grew into a whole shelf of them, plus
## the two sparkle glints every floor scatters beside its main surprise.
## The builders live apart so FloorSurprise stays inside the 500-line rule.
## The prop factories (_ball, glow, _pbr) mirror FloorSurprise's own on
## purpose: they are eight lines, and a shared factory file for three
## one-liners would be a longer home than the code.

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

static func _build_wisp_choir(root: Node3D) -> void:
    ## Three little souls on a mossy stage, mid-round. Standing close and
    ## pressing E joins the hum; the choir bows with a chord and a sparkle.
    var stage := MeshInstance3D.new()
    var stage_mesh := CylinderMesh.new()
    stage_mesh.top_radius = 0.85
    stage_mesh.bottom_radius = 1.05
    stage_mesh.height = 0.12
    stage_mesh.radial_segments = 12
    stage.mesh = stage_mesh
    stage.material_override = _pbr(Color("#6f9c52"))
    stage.position = Vector3(0, 0.06, 0)
    root.add_child(stage)
    for index in range(3):
        var angle := -0.9 + float(index) * 0.9
        var singer := _ball(0.16, Color("#fff3c8"), true)
        singer.name = "Singer%d" % index
        singer.position = Vector3(sin(angle) * 0.75, 0.30, -cos(angle) * 0.4)
        root.add_child(singer)

static func _build_lantern_release(root: Node3D) -> void:
    ## A paper lantern on a cedar stick. One press and it climbs, trailing
    ## warm light — the forest's own send-off.
    var stick := MeshInstance3D.new()
    var stick_mesh := CylinderMesh.new()
    stick_mesh.top_radius = 0.03
    stick_mesh.bottom_radius = 0.04
    stick_mesh.height = 0.9
    stick_mesh.radial_segments = 6
    stick.mesh = stick_mesh
    stick.material_override = _pbr(Color("#7b593c"))
    stick.position = Vector3(0, 0.45, 0)
    root.add_child(stick)
    var lantern := MeshInstance3D.new()
    var lantern_mesh := SphereMesh.new()
    lantern_mesh.radius = 0.20
    lantern_mesh.height = 0.30
    lantern.mesh = lantern_mesh
    lantern.name = "Lantern"
    lantern.scale = Vector3(1.0, 1.25, 1.0)
    lantern.material_override = glow(Color("#ffdf9e"), 1.6)
    lantern.position = Vector3(0.12, 1.02, 0)
    root.add_child(lantern)

static func _build_treasure_sprout(root: Node3D) -> void:
    ## A golden sprout that wants one drop of song. It grows when watered
    ## and pays a little treasure of sparkles.
    var stem := MeshInstance3D.new()
    var stem_mesh := CylinderMesh.new()
    stem_mesh.top_radius = 0.03
    stem_mesh.bottom_radius = 0.05
    stem_mesh.height = 0.34
    stem_mesh.radial_segments = 6
    stem.mesh = stem_mesh
    stem.material_override = _pbr(Color("#5d9448"))
    stem.position = Vector3(0, 0.17, 0)
    root.add_child(stem)
    var bud := _ball(0.13, Color("#ffd77e"), true)
    bud.name = "Bud"
    bud.position = Vector3(0, 0.44, 0)
    root.add_child(bud)
    for side in [-1.0, 1.0]:
        var leaf := MeshInstance3D.new()
        var leaf_mesh := SphereMesh.new()
        leaf_mesh.radius = 0.09
        leaf_mesh.height = 0.05
        leaf.mesh = leaf_mesh
        leaf.material_override = _pbr(Color("#6f9c52"))
        leaf.position = Vector3(side * 0.12, 0.14, 0)
        leaf.rotation.z = side * 0.6
        root.add_child(leaf)

static func _build_rainbow_puddle(root: Node3D) -> void:
    ## A shallow pool with a small rainbow arched over it. Standing in it
    ## (no button) rings the colour out and warms the hero.
    var water := MeshInstance3D.new()
    var water_mesh := CylinderMesh.new()
    water_mesh.top_radius = 1.1
    water_mesh.bottom_radius = 1.2
    water_mesh.height = 0.05
    water_mesh.radial_segments = 16
    water.mesh = water_mesh
    water.material_override = _pbr(Color("#bfe8ff"))
    water.position = Vector3(0, 0.03, 0)
    root.add_child(water)
    var band_colors := [Color("#ffad9e"), Color("#ffe29a"), Color("#c9f29e"), Color("#bfe8ff"), Color("#e0c9ff")]
    for band in range(5):
        var arc := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.86 + float(band) * 0.07
        torus.outer_radius = 0.92 + float(band) * 0.07
        torus.rings = 24
        torus.ring_segments = 6
        arc.mesh = torus
        arc.material_override = glow(band_colors[band], 1.3)
        arc.position = Vector3(0, 1.35, 0)
        arc.rotation.x = PI * 0.5
        root.add_child(arc)

static func _build_mushroom_house(root: Node3D) -> void:
    ## A cap, a stem, a round door with a tiny knob. One knock and somebody
    ## home shares a fact they have been saving.
    var cap := MeshInstance3D.new()
    var cap_mesh := SphereMesh.new()
    cap_mesh.radius = 0.85
    cap_mesh.height = 0.9
    cap.mesh = cap_mesh
    cap.material_override = _pbr(Color("#c9564e"))
    cap.scale = Vector3(1.0, 0.72, 1.0)
    cap.position = Vector3(0, 0.88, 0)
    root.add_child(cap)
    for spot in range(4):
        var angle := TAU * float(spot) / 4.0 + 0.4
        var dot := _ball(0.09, Color("#fff3c8"), true)
        dot.position = Vector3(cos(angle) * 0.5, 1.12, sin(angle) * 0.5)
        root.add_child(dot)
    var stem := MeshInstance3D.new()
    var stem_mesh := CylinderMesh.new()
    stem_mesh.top_radius = 0.5
    stem_mesh.bottom_radius = 0.62
    stem_mesh.height = 0.85
    stem_mesh.radial_segments = 12
    stem.mesh = stem_mesh
    stem.material_override = _pbr(Color("#f1dfb7"))
    stem.position = Vector3(0, 0.42, 0)
    root.add_child(stem)
    var door := MeshInstance3D.new()
    var door_mesh := CylinderMesh.new()
    door_mesh.top_radius = 0.20
    door_mesh.bottom_radius = 0.20
    door_mesh.height = 0.04
    door_mesh.radial_segments = 12
    door.mesh = door_mesh
    door.name = "Door"
    door.material_override = _pbr(Color("#7b593c"))
    door.position = Vector3(0, 0.34, 0.56)
    root.add_child(door)
    var knob := _ball(0.035, Color("#ffe2a0"), true)
    knob.position = Vector3(0.09, 0.36, 0.60)
    root.add_child(knob)

static func _build_shooting_star(root: Node3D) -> void:
    ## A small star that landed, still glowing, trailing a scorch of moss.
    var star := MeshInstance3D.new()
    var star_mesh := SphereMesh.new()
    star_mesh.radius = 0.22
    star_mesh.height = 0.38
    star.mesh = star_mesh
    star.name = "Star"
    star.material_override = glow(Color("#fff3a0"), 2.2)
    star.position = Vector3(0, 0.26, 0)
    root.add_child(star)
    for index in range(5):
        var ember := _ball(0.05, Color("#e0b05e"), true)
        ember.position = Vector3(-0.4 - float(index) * 0.22, 0.04, float(index % 2) * 0.12 - 0.06)
        root.add_child(ember)

static func _build_hedge_nook(root: Node3D) -> void:
    ## A leaf bed tucked against a mossy hedge. Stand in it a moment and the
    ## nook shares its warmth — the resting kind of adventure.
    var hedge := MeshInstance3D.new()
    var hedge_mesh := BoxMesh.new()
    hedge_mesh.size = Vector3(1.9, 0.85, 0.45)
    hedge.mesh = hedge_mesh
    hedge.material_override = _pbr(Color("#4f8a46"))
    hedge.position = Vector3(0, 0.42, -0.75)
    root.add_child(hedge)
    var bed := MeshInstance3D.new()
    var bed_mesh := BoxMesh.new()
    bed_mesh.size = Vector3(1.2, 0.10, 0.9)
    bed.mesh = bed_mesh
    bed.material_override = _pbr(Color("#d9b06e"))
    bed.position = Vector3(0, 0.05, 0.1)
    root.add_child(bed)
    for pillow in range(3):
        var leaf := MeshInstance3D.new()
        var leaf_mesh := SphereMesh.new()
        leaf_mesh.radius = 0.14
        leaf_mesh.height = 0.06
        leaf.mesh = leaf_mesh
        leaf.material_override = _pbr(Color("#b7dc55"))
        leaf.position = Vector3(-0.35 + float(pillow) * 0.35, 0.10, 0.1 + (0.2 if pillow % 2 == 0 else -0.15))
        root.add_child(leaf)

static func _build_butterfly_parade(root: Node3D, rng: RandomNumberGenerator) -> void:
    ## A glittering line of butterflies mid-crossing. Walk into the parade
    ## and it swirls around the hero; nobody has to catch anything.
    for index in range(6):
        var wing := MeshInstance3D.new()
        var wing_mesh := SphereMesh.new()
        wing_mesh.radius = 0.11
        wing_mesh.height = 0.05
        wing.mesh = wing_mesh
        wing.name = "Butterfly%d" % index
        wing.material_override = glow(Color("#ffd1e8").lerp(Color("#fff3a0"), rng.randf()), 1.4)
        wing.position = Vector3(-1.2 + float(index) * 0.5, 0.5 + float(index % 3) * 0.16, float(index % 2) * 0.5 - 0.25)
        root.add_child(wing)

## One small wonder beside the floor's main surprise: a sparkle glint in
## the grass. A pure find — walk close, one sparkle, one soft chord. The
## main surprise is the adventure; the glints are the road's small change.
static func spawn_minor(parent: Node3D, dungeon: Dictionary, rng: RandomNumberGenerator, occupied: Dictionary) -> Node3D:
    var cell := DungeonGenerator.random_floor_cell(dungeon, rng, Vector2(-1000, -1000), 0.0, occupied)
    occupied[cell] = true
    var root := Node3D.new()
    root.name = "MinorWonder"
    root.position = DungeonGenerator.cell_to_world(cell)
    root.set_meta("wonder_used", false)
    var glint := _ball(0.09, Color("#ffe9a8"), true)
    glint.position = Vector3(0, 0.22, 0)
    root.add_child(glint)
    var halo := _ball(0.045, Color("#fff6d8"), true)
    halo.position = Vector3(0.12, 0.30, 0.08)
    root.add_child(halo)
    parent.add_child(root)
    return root
