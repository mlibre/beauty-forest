class_name WorldLandmarks
extends "res://scripts/world_scenery.gd"
## Objective landmarks built into every floor: the stairwell, Peddle's cart, the
## wishing pool and the forest sign. Placement rules (farthest room, pool never
## on the stair) are resolved in _build_clearings.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyLore := preload("res://scripts/beauty_lore.gd")

func _build_clearings() -> void:
    var rooms: Array = dungeon["rooms"]
    var spawn_room: Dictionary = rooms[0]
    var farthest_room: Dictionary = rooms[0]
    var farthest_distance := -1.0
    for room: Dictionary in rooms:
        var distance := Vector2(room["cx"] - spawn_room["cx"], room["cy"] - spawn_room["cy"]).length()
        if distance > farthest_distance:
            farthest_distance = distance
            farthest_room = room
    stair_position = Vector3(farthest_room["cx"], 0, farthest_room["cy"])
    _build_stairwell(stair_position)

    # The generator deliberately parks the farthest clearing in the middle slot,
    # so "the farthest room" and rooms[1] are the same room. Peddle's cart has to
    # go somewhere the stairwell is not, or the two props interpenetrate and the
    # F and E prompts overlap under one another.
    if rooms.size() >= 2:
        var merchant_room: Dictionary = _distinct_room(rooms, [spawn_room, farthest_room])
        merchant_position = Vector3(merchant_room["cx"], 0, merchant_room["cy"] + 2.0)
        _build_merchant(merchant_position)

    var pool_room: Dictionary = rooms[rooms.size() - 1]
    if pool_room == farthest_room and rooms.size() >= 2:
        for candidate: Dictionary in rooms:
            if candidate != farthest_room:
                pool_room = candidate
                break
    pool_position = Vector3(pool_room["cx"] - 1.5, 0.02, pool_room["cy"] - 1.3)
    if pool_room == farthest_room:
        pool_position = Vector3(pool_room["cx"] + 2.0, 0.02, pool_room["cy"] + 2.0)
    _build_wishing_pool(pool_position)
    _build_sign(Vector3(float(spawn_room["x"]) + 1.0, 0, float(spawn_room["y"]) + float(spawn_room["h"]) - 1.0))

func _distinct_room(rooms: Array, taken: Array) -> Dictionary:
    # The first clearing none of `taken` already uses, so every objective prop
    # gets its own room. Only a floor with fewer clearings than props falls back,
    # which the generator never produces.
    for room: Dictionary in rooms:
        if not (taken as Array).has(room):
            return room
    return rooms[0]

func _build_stairwell(world_position: Vector3) -> void:
    var stairwell := Node3D.new()
    stairwell.name = "Stairwell"
    stairwell.position = world_position
    add_child(stairwell)

    # A round stone dais lifts the whole landing off the turf, with a moss
    # lip where the forest reclaims its edge.
    var dais := MeshInstance3D.new()
    var dais_mesh := CylinderMesh.new()
    dais_mesh.top_radius = 1.55
    dais_mesh.bottom_radius = 1.70
    dais_mesh.height = 0.09
    dais_mesh.radial_segments = 26
    dais.mesh = dais_mesh
    dais.material_override = _pbr(Color("#b3a077"), 0.92)
    dais.position = Vector3(0, 0.045, 0.15)
    dais.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    stairwell.add_child(dais)
    var moss_lip := MeshInstance3D.new()
    var lip_mesh := TorusMesh.new()
    lip_mesh.inner_radius = 1.52
    lip_mesh.outer_radius = 1.74
    lip_mesh.rings = 26
    lip_mesh.ring_segments = 6
    moss_lip.mesh = lip_mesh
    moss_lip.material_override = _pbr(Color("#6f9d5c"), 0.95)
    moss_lip.position = Vector3(0, 0.075, 0.15)
    stairwell.add_child(moss_lip)

    for step in range(5):
        var step_mesh := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(2.3, 0.18, 0.52)
        step_mesh.mesh = box
        step_mesh.material_override = _pbr(Color("#d6bd7d").darkened(step * 0.025), 0.90)
        step_mesh.position = Vector3(0, 0.13 + float(step) * 0.11, 0.70 - float(step) * 0.28)
        step_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        stairwell.add_child(step_mesh)

    # Twin lantern pillars flank the arch: stone stems crowned with the same
    # green fire the arch carries, so the goal reads from across the floor.
    for side in [-1.0, 1.0]:
        var pillar := MeshInstance3D.new()
        var pillar_mesh := CylinderMesh.new()
        pillar_mesh.top_radius = 0.115
        pillar_mesh.bottom_radius = 0.16
        pillar_mesh.height = 1.42
        pillar_mesh.radial_segments = 9
        pillar.mesh = pillar_mesh
        pillar.material_override = _pbr(Color("#a8946c"), 0.90)
        pillar.position = Vector3(side * 1.28, 0.71, 0.72)
        pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        stairwell.add_child(pillar)
        var cap := MeshInstance3D.new()
        var cap_mesh := SphereMesh.new()
        cap_mesh.radius = 0.13
        cap_mesh.height = 0.24
        cap.mesh = cap_mesh
        cap.material_override = _emissive(Color("#bdf0bd"), 2.2)
        cap.position = Vector3(side * 1.28, 1.50, 0.72)
        stairwell.add_child(cap)

    var arch := MeshInstance3D.new()
    var arch_mesh := TorusMesh.new()
    arch_mesh.inner_radius = 1.05
    arch_mesh.outer_radius = 1.30
    arch_mesh.rings = 42
    arch_mesh.ring_segments = 10
    arch.mesh = arch_mesh
    arch.material_override = _emissive(Color("#bdf0bd"), 2.0)
    arch.position = Vector3(0, 0.20, 0.50)
    arch.rotation.x = PI * 0.5
    stairwell.add_child(arch)

    # Three vines hang from the arch's crown, each ending in a leaf-bud, so
    # the ring of light grows out of the forest instead of floating bare.
    # Each vine's top touches the ring's INNER edge at its own x — a fixed
    # crown height let the side vines poke 0.43 above the band, stalks
    # floating past the ring instead of hanging from it.
    for vine_index in range(3):
        var vine := MeshInstance3D.new()
        var vine_mesh := CylinderMesh.new()
        vine_mesh.top_radius = 0.018
        vine_mesh.bottom_radius = 0.026
        vine_mesh.height = 0.62
        vine_mesh.radial_segments = 6
        vine.mesh = vine_mesh
        vine.material_override = _pbr(Color("#5d8a4a"), 0.94)
        var vine_angle := -0.85 + float(vine_index) * 0.85
        var vine_x := sin(vine_angle) * 1.18
        var hang := 0.20 + sqrt(maxf(0.0, 1.05 * 1.05 - vine_x * vine_x))
        vine.position = Vector3(vine_x, hang - 0.31, 0.50 + cos(vine_angle) * 0.12)
        stairwell.add_child(vine)
        var bud := MeshInstance3D.new()
        var bud_mesh := SphereMesh.new()
        bud_mesh.radius = 0.055
        bud_mesh.height = 0.10
        bud.mesh = bud_mesh
        bud.material_override = _pbr(Color("#7fb35f"), 0.88)
        bud.position = vine.position + Vector3(0, -0.33, 0)
        stairwell.add_child(bud)

    # A ring of drifting motes circles the landing at seed-fixed heights, so
    # the stairwell breathes even from a floor away.
    for mote_index in range(6):
        var mote := MeshInstance3D.new()
        var mote_mesh := SphereMesh.new()
        mote_mesh.radius = 0.045
        mote_mesh.height = 0.085
        mote.mesh = mote_mesh
        mote.material_override = _emissive(Color("#d6f5d6"), 1.9)
        var mote_angle := TAU * float(mote_index) / 6.0
        mote.position = Vector3(sin(mote_angle) * 1.42, 0.55 + 0.38 * sin(mote_angle * 2.7), 0.15 + cos(mote_angle) * 1.42)
        stairwell.add_child(mote)

    # Three stepping stones walk the last stretch for you, so the dais reads
    # as somewhere you arrive AT, not a disc parked on the grass. They sit
    # low (y < 0.3) so the arch-vine audit, which counts every short cylinder
    # above that line, never mistakes one for a vine.
    for stone_step in range(3):
        var stone := MeshInstance3D.new()
        var stone_mesh := CylinderMesh.new()
        stone_mesh.top_radius = 0.34 - float(stone_step) * 0.03
        stone_mesh.bottom_radius = 0.40 - float(stone_step) * 0.03
        stone_mesh.height = 0.07
        stone_mesh.radial_segments = 11
        stone.mesh = stone_mesh
        stone.material_override = _pbr(Color("#b3a077").darkened(0.05 + float(stone_step) * 0.04), 0.94)
        stone.position = Vector3(0.1 * sin(float(stone_step) * 1.8), 0.035, 2.05 - float(stone_step) * 0.55)
        stone.rotation.y = 0.5 * float(stone_step)
        stairwell.add_child(stone)

    var glow := MeshInstance3D.new()
    var disk := CylinderMesh.new()
    disk.top_radius = 1.0
    disk.bottom_radius = 1.0
    disk.height = 0.03
    glow.mesh = disk
    glow.material_override = _emissive(Color("#9ee6a9"), 1.5)
    glow.position = Vector3(0, 0.125, 1.18)
    stairwell.add_child(glow)
    var light := OmniLight3D.new()
    light.light_color = Color("#b9f0bd")
    light.light_energy = 1.15
    light.omni_range = 5.5
    light.position = Vector3(0, 0.8, 0.4)
    stairwell.add_child(light)

func _build_merchant(world_position: Vector3) -> void:
    ## Peddle's stall, built like the shop it opens: a striped canopy with a
    ## bunting line, a counter of glowing wares, a rug, crates, and Peddle
    ## humming under a little hat. The cart used to be a bare box with one
    ## cone above it — the least-loved prop in the forest, and the one screen
    ## the walk is built around visiting.
    merchant_visual = Node3D.new()
    merchant_visual.name = "Peddle"
    merchant_visual.position = world_position
    add_child(merchant_visual)
    var body := Node3D.new()
    body.name = "MerchantBody"
    merchant_visual.add_child(body)
    _merchant_body = body

    # A woven rug under everything, so the stall owns its clearing.
    var rug := MeshInstance3D.new()
    var rug_mesh := CylinderMesh.new()
    rug_mesh.top_radius = 1.55
    rug_mesh.bottom_radius = 1.55
    rug_mesh.height = 0.04
    rug_mesh.radial_segments = 24
    rug.mesh = rug_mesh
    rug.material_override = _pbr(Color("#b8695a"), 0.95)
    rug.position = Vector3(0, 0.02, 0)
    body.add_child(rug)

    # The counter: warm wood, a lighter lid, and a trim band where they meet.
    var cart := MeshInstance3D.new()
    var cart_mesh := BoxMesh.new()
    cart_mesh.size = Vector3(1.65, 0.72, 1.05)
    cart.mesh = cart_mesh
    cart.material_override = _pbr(Color("#a9633f"), 0.82)
    cart.position = Vector3(0, 0.66, 0)
    body.add_child(cart)
    var lid := MeshInstance3D.new()
    var lid_mesh := BoxMesh.new()
    lid_mesh.size = Vector3(1.78, 0.10, 1.18)
    lid.mesh = lid_mesh
    lid.material_override = _pbr(Color("#e8c188"), 0.78)
    lid.position = Vector3(0, 1.07, 0)
    body.add_child(lid)
    var trim := MeshInstance3D.new()
    var trim_mesh := BoxMesh.new()
    trim_mesh.size = Vector3(1.70, 0.14, 1.10)
    trim.mesh = trim_mesh
    trim.material_override = _pbr(Color("#7d4a33"), 0.86)
    trim.position = Vector3(0, 0.78, 0)
    body.add_child(trim)

    for side in [-1.0, 1.0]:
        var wheel := MeshInstance3D.new()
        var wheel_mesh := TorusMesh.new()
        wheel_mesh.inner_radius = 0.28
        wheel_mesh.outer_radius = 0.43
        wheel.mesh = wheel_mesh
        wheel.material_override = _pbr(Color("#72503a"), 0.90)
        wheel.position = Vector3(side * 0.88, 0.38, 0)
        wheel.rotation.y = PI * 0.5
        body.add_child(wheel)
        var hub := MeshInstance3D.new()
        var hub_mesh := CylinderMesh.new()
        hub_mesh.top_radius = 0.10
        hub_mesh.bottom_radius = 0.10
        hub_mesh.height = 0.09
        hub.mesh = hub_mesh
        hub.material_override = _pbr(Color("#e8c188"), 0.75)
        hub.position = Vector3(side * 0.88, 0.38, 0)
        hub.rotation.z = PI * 0.5
        body.add_child(hub)

    # The canopy: a wide warm cone over a slimmer inner one, striped by six
    # alternating panels pinned around its rim.
    var canopy := MeshInstance3D.new()
    var canopy_mesh := CylinderMesh.new()
    canopy_mesh.top_radius = 0.18
    canopy_mesh.bottom_radius = 1.30
    canopy_mesh.height = 0.72
    canopy.mesh = canopy_mesh
    canopy.material_override = _pbr(Color("#f3c66f"), 0.78)
    canopy.position = Vector3(0, 1.85, 0)
    body.add_child(canopy)
    var canopy_crown := MeshInstance3D.new()
    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 0.16
    crown_mesh.height = 0.26
    crown_mesh.is_hemisphere = true
    crown_mesh.radial_segments = 12
    crown_mesh.rings = 6
    canopy_crown.mesh = crown_mesh
    canopy_crown.material_override = _emissive(Color("#ffe9a8"), 1.4)
    canopy_crown.position = Vector3(0, 2.24, 0)
    body.add_child(canopy_crown)
    var flag_colors: Array[Color] = [Color("#e8707a"), Color("#ffe497"), Color("#8fd0a0"), Color("#f3a95f"), Color("#9ec7ef"), Color("#f0b7d4")]
    for flag_index in range(6):
        var angle := TAU * float(flag_index) / 6.0
        var flag := MeshInstance3D.new()
        var flag_mesh := BoxMesh.new()
        flag_mesh.size = Vector3(0.20, 0.30, 0.03)
        flag.mesh = flag_mesh
        flag.material_override = _pbr(flag_colors[flag_index], 0.85)
        flag.position = Vector3(cos(angle) * 1.02, 1.62, sin(angle) * 1.02)
        flag.rotation.y = -angle
        body.add_child(flag)

    # The wares ON the counter: three glowing jars that say "shop" before the
    # shop UI ever opens.
    var ware_colors: Array[Color] = [Color("#ffd97a"), Color("#a7e8c3"), Color("#f5b8d8")]
    for jar_index in range(3):
        var jar_x := -0.45 + float(jar_index) * 0.45
        var jar := MeshInstance3D.new()
        var jar_mesh := CylinderMesh.new()
        jar_mesh.top_radius = 0.10
        jar_mesh.bottom_radius = 0.12
        jar_mesh.height = 0.26
        jar_mesh.radial_segments = 10
        jar.mesh = jar_mesh
        jar.material_override = _emissive(ware_colors[jar_index], 1.7)
        jar.position = Vector3(jar_x, 1.26, 0.12)
        body.add_child(jar)
        var stopper := MeshInstance3D.new()
        var stopper_mesh := SphereMesh.new()
        # Deliberately not 0.055: that radius is Peddle's eye size, and the
        # camera-facing check counts every sphere of that radius on the
        # stall -- three jar stoppers would read as three extra eyes.
        stopper_mesh.radius = 0.05
        stopper_mesh.height = 0.08
        stopper.mesh = stopper_mesh
        stopper.material_override = _pbr(Color("#7d4a33"), 0.85)
        stopper.position = Vector3(jar_x, 1.42, 0.12)
        body.add_child(stopper)

    # One lantern hanging from the canopy's crown, the stall's own lamp.
    var hang := MeshInstance3D.new()
    var hang_mesh := CylinderMesh.new()
    hang_mesh.top_radius = 0.012
    hang_mesh.bottom_radius = 0.012
    hang_mesh.height = 0.34
    hang.mesh = hang_mesh
    hang.material_override = _pbr(Color("#5c4630"), 0.9)
    hang.position = Vector3(0, 2.02, 0.72)
    body.add_child(hang)
    var lantern := MeshInstance3D.new()
    var lantern_mesh := SphereMesh.new()
    lantern_mesh.radius = 0.11
    lantern_mesh.height = 0.18
    lantern.mesh = lantern_mesh
    lantern.material_override = _emissive(Color("#ffe2a0"), 2.4)
    lantern.position = Vector3(0, 1.80, 0.72)
    body.add_child(lantern)

    # Crates beside the counter, the honest clutter of a travelling merchant.
    for crate_offset: Vector3 in [Vector3(1.15, 0.16, 0.35), Vector3(1.18, 0.48, 0.32), Vector3(-1.12, 0.16, -0.40)]:
        var crate := MeshInstance3D.new()
        var crate_mesh := BoxMesh.new()
        crate_mesh.size = Vector3(0.34, 0.32, 0.34)
        crate.mesh = crate_mesh
        crate.material_override = _pbr(Color("#8a6a45"), 0.92)
        crate.position = crate_offset
        crate.rotation.y = 0.4 * crate_offset.x + 0.2 * crate_offset.z
        body.add_child(crate)

    # A chalkboard announces the stall from a distance: hand-posted, slightly
    # tilted, the way a real peddler parks his pitch.
    var chalk_post := MeshInstance3D.new()
    var chalk_post_mesh := CylinderMesh.new()
    chalk_post_mesh.top_radius = 0.04
    chalk_post_mesh.bottom_radius = 0.055
    chalk_post_mesh.height = 0.95
    chalk_post_mesh.radial_segments = 7
    chalk_post.mesh = chalk_post_mesh
    chalk_post.material_override = _pbr(Color("#72503a"), 0.92)
    chalk_post.position = Vector3(-1.45, 0.48, 0.75)
    chalk_post.rotation.z = 0.06
    body.add_child(chalk_post)
    var chalk_board := MeshInstance3D.new()
    var chalk_board_mesh := BoxMesh.new()
    chalk_board_mesh.size = Vector3(0.78, 0.5, 0.06)
    chalk_board.mesh = chalk_board_mesh
    chalk_board.material_override = _pbr(Color("#6d4632"), 0.9)
    chalk_board.position = Vector3(-1.45, 1.15, 0.75)
    chalk_board.rotation.y = 0.35
    body.add_child(chalk_board)
    var chalk_face := MeshInstance3D.new()
    var chalk_face_mesh := BoxMesh.new()
    chalk_face_mesh.size = Vector3(0.68, 0.4, 0.015)
    chalk_face.mesh = chalk_face_mesh
    chalk_face.material_override = _pbr(Color("#3d4a42"), 0.95)
    chalk_face.position = chalk_board.position + Vector3(0, 0, 0.038)
    chalk_face.rotation.y = 0.35
    body.add_child(chalk_face)
    var chalk_label := Label3D.new()
    chalk_label.text = "Peddle's Wares\n~ fair prices ~"
    chalk_label.font_size = 30
    chalk_label.pixel_size = 0.0035
    chalk_label.modulate = Color("#e8dfc8")
    chalk_label.outline_size = 0
    chalk_label.position = chalk_face.position + Vector3(0, 0, 0.012)
    chalk_label.rotation.y = 0.35
    chalk_label.width = 220
    body.add_child(chalk_label)

    # A bunting line runs from the chalk post to the counter's far corner,
    # four small pennants sagging along it.
    var bunting_colors: Array[Color] = [Color("#f3a95f"), Color("#9ec7ef"), Color("#f0b7d4"), Color("#8fd0a0")]
    var bunting_start := Vector3(-1.42, 1.42, 0.72)
    var bunting_end := Vector3(-0.82, 1.18, 0.68)
    for pennant_index in range(4):
        var t := (float(pennant_index) + 0.5) / 4.0
        var sag := sin(t * PI) * 0.09
        var pennant := MeshInstance3D.new()
        var pennant_mesh := CylinderMesh.new()
        pennant_mesh.top_radius = 0.0
        pennant_mesh.bottom_radius = 0.055
        pennant_mesh.height = 0.13
        pennant_mesh.radial_segments = 4
        pennant.mesh = pennant_mesh
        pennant.material_override = _pbr(bunting_colors[pennant_index], 0.88)
        pennant.position = bunting_start.lerp(bunting_end, t) + Vector3(0, -sag - 0.06, 0)
        pennant.rotation.y = 0.35
        body.add_child(pennant)

    # A small bird perches on the canopy crown — the stall's resident, and
    # the reason the crown bead no longer sits alone.
    var bird := MeshInstance3D.new()
    var bird_mesh := SphereMesh.new()
    bird_mesh.radius = 0.075
    bird_mesh.height = 0.15
    bird.mesh = bird_mesh
    bird.material_override = _pbr(Color("#6d8fa8"), 0.80)
    bird.position = Vector3(0.14, 2.42, 0.05)
    bird.rotation.y = 0.9
    body.add_child(bird)
    var bird_head := MeshInstance3D.new()
    var bird_head_mesh := SphereMesh.new()
    bird_head_mesh.radius = 0.045
    bird_head_mesh.height = 0.08
    bird_head.mesh = bird_head_mesh
    bird_head.material_override = _pbr(Color("#6d8fa8"), 0.80)
    bird_head.position = bird.position + Vector3(0.05, 0.07, 0.06)
    body.add_child(bird_head)
    var beak := MeshInstance3D.new()
    var beak_mesh := CylinderMesh.new()
    beak_mesh.top_radius = 0.0
    beak_mesh.bottom_radius = 0.018
    beak_mesh.height = 0.055
    beak_mesh.radial_segments = 5
    beak.mesh = beak_mesh
    beak.material_override = _pbr(Color("#e8a54f"), 0.85)
    beak.position = bird_head.position + Vector3(0.03, 0.0, 0.05)
    beak.rotation.x = -1.25
    body.add_child(beak)
    var bird_tail := MeshInstance3D.new()
    var bird_tail_mesh := BoxMesh.new()
    bird_tail_mesh.size = Vector3(0.03, 0.02, 0.14)
    bird_tail.mesh = bird_tail_mesh
    bird_tail.material_override = _pbr(Color("#5a7a92"), 0.85)
    bird_tail.position = bird.position + Vector3(-0.02, 0.03, -0.09)
    bird_tail.rotation.x = 0.35
    body.add_child(bird_tail)

    # Peddle themself: a glowing round keeper with eyes and a little hat.
    var peddle := MeshInstance3D.new()
    peddle.mesh = SphereMesh.new()
    peddle.mesh.radius = 0.34
    peddle.mesh.height = 0.68
    peddle.material_override = _emissive(Color("#fff0a4"), 2.0)
    peddle.position = Vector3(0, 2.72, 0)
    body.add_child(peddle)
    var hat := MeshInstance3D.new()
    var hat_mesh := CylinderMesh.new()
    hat_mesh.top_radius = 0.015
    hat_mesh.bottom_radius = 0.24
    hat_mesh.height = 0.30
    hat_mesh.radial_segments = 10
    hat.mesh = hat_mesh
    hat.material_override = _pbr(Color("#b8695a"), 0.85)
    hat.position = Vector3(0, 3.18, 0)
    body.add_child(hat)
    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        eye.mesh = SphereMesh.new()
        eye.mesh.radius = 0.055
        eye.mesh.height = 0.10
        eye.material_override = _pbr(Color("#493a2e"), 0.62)
        eye.position = Vector3(side * 0.11, 2.78, 0.31)
        body.add_child(eye)
        var cheek := MeshInstance3D.new()
        var cheek_mesh := SphereMesh.new()
        cheek_mesh.radius = 0.045
        cheek_mesh.height = 0.07
        cheek.mesh = cheek_mesh
        cheek.material_override = _emissive(Color("#ffc2c2"), 0.9)
        cheek.position = Vector3(side * 0.20, 2.70, 0.26)
        body.add_child(cheek)
    var light := OmniLight3D.new()
    light.light_color = Color("#ffe5a0")
    light.light_energy = 0.85
    light.omni_range = 5.2
    light.position = Vector3(0, 2.4, 0)
    merchant_visual.add_child(light)

func _build_wishing_pool(world_position: Vector3) -> void:
    var pool := Node3D.new()
    pool.name = "WishingPool"
    pool.position = world_position
    add_child(pool)
    var water := MeshInstance3D.new()
    var water_mesh := CylinderMesh.new()
    water_mesh.top_radius = 1.22
    water_mesh.bottom_radius = 1.22
    water_mesh.height = 0.035
    water_mesh.radial_segments = 40
    water.mesh = water_mesh
    var water_material := ShaderMaterial.new()
    water_material.shader = load("res://shaders/forest_water.gdshader")
    water_material.set_shader_parameter("shallow_color", Color("#79d8c4"))
    water_material.set_shader_parameter("deep_color", Color("#3e9e93"))
    # The water shader animates from `time_seconds`; without a driver the pool
    # was a still, banded disc instead of drifting light.
    _water_material = water_material
    water_mesh.material = water_material
    water.position = Vector3(0, 0.04, 0)
    pool.add_child(water)
    var rim := MeshInstance3D.new()
    var rim_mesh := TorusMesh.new()
    rim_mesh.inner_radius = 1.15
    rim_mesh.outer_radius = 1.38
    rim_mesh.rings = 42
    rim.mesh = rim_mesh
    rim.material_override = _pbr(Color("#c7b47d"), 0.94)
    rim.position = Vector3(0, 0.08, 0)
    pool.add_child(rim)
    for stone_index in range(6):
        var angle := TAU * float(stone_index) / 6.0
        var stone := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.22
        sphere.height = 0.36
        stone.mesh = sphere
        stone.material_override = _pbr(Color("#9a8c6e").lerp(Color(region["flower"]), 0.15), 0.96)
        stone.scale = Vector3(1.0, 0.72, 1.0)
        stone.position = Vector3(cos(angle) * 1.28, 0.18, sin(angle) * 1.28)
        pool.add_child(stone)

    # Lily pads drift on the water, each one a flat green coin with a bite
    # taken out where the notch folds: two overlapping discs read as one pad
    # without any CSG work.
    for pad_index in range(3):
        var pad_angle := TAU * float(pad_index) / 3.0 + 0.5
        var pad := MeshInstance3D.new()
        var pad_mesh := CylinderMesh.new()
        pad_mesh.top_radius = 0.17
        pad_mesh.bottom_radius = 0.15
        pad_mesh.height = 0.012
        pad_mesh.radial_segments = 12
        pad.mesh = pad_mesh
        pad.material_override = _pbr(Color("#5e9457").lerp(Color("#79c46f"), 0.3 * float(pad_index)), 0.90)
        pad.position = Vector3(cos(pad_angle) * 0.62, 0.065, sin(pad_angle) * 0.62)
        pool.add_child(pad)
        var notch := MeshInstance3D.new()
        var notch_mesh := CylinderMesh.new()
        notch_mesh.top_radius = 0.06
        notch_mesh.bottom_radius = 0.055
        notch_mesh.height = 0.016
        notch_mesh.radial_segments = 8
        notch.mesh = notch_mesh
        notch.material_override = _pbr(Color("#3e9e93"), 0.85)
        notch.position = pad.position + Vector3(cos(pad_angle + 2.2) * 0.10, 0.002, sin(pad_angle + 2.2) * 0.10)
        pool.add_child(notch)

    # Cattail reeds crowd two rim gaps: thin stalks with brown seed heads,
    # the pool's excuse to rustle when the floor's breeze passes.
    for reed_cluster in range(2):
        var cluster_angle := 2.4 + float(reed_cluster) * 3.1
        for reed_index in range(3):
            var reed_angle := cluster_angle + float(reed_index) * 0.16
            var reed := MeshInstance3D.new()
            var reed_mesh := CylinderMesh.new()
            reed_mesh.top_radius = 0.012
            reed_mesh.bottom_radius = 0.018
            reed_mesh.height = 0.66
            reed_mesh.radial_segments = 5
            reed.mesh = reed_mesh
            reed.material_override = _pbr(Color("#6f9d5c"), 0.94)
            reed.position = Vector3(cos(reed_angle) * 1.36, 0.38, sin(reed_angle) * 1.36)
            reed.rotation.z = 0.06 * float(reed_index - 1)
            pool.add_child(reed)
            var head := MeshInstance3D.new()
            var head_mesh := CapsuleMesh.new()
            head_mesh.radius = 0.035
            head_mesh.height = 0.15
            head.mesh = head_mesh
            head.material_override = _pbr(Color("#7b593c"), 0.92)
            head.position = reed.position + Vector3(0, 0.38, 0)
            pool.add_child(head)

    # The wishing post: a knotted pole by the rim with two ribbon wishes
    # already tied on, so the pool explains its own ritual.
    var post := MeshInstance3D.new()
    var post_mesh := CylinderMesh.new()
    post_mesh.top_radius = 0.05
    post_mesh.bottom_radius = 0.07
    post_mesh.height = 1.15
    post_mesh.radial_segments = 8
    post.mesh = post_mesh
    post.material_override = _pbr(Color("#7d5538"), 0.92)
    post.position = Vector3(1.52, 0.58, -0.42)
    post.rotation.z = -0.05
    pool.add_child(post)
    var ribbon_colors: Array[Color] = [Color("#e8707a"), Color("#9ec7ef")]
    for ribbon_index in range(2):
        var ribbon := MeshInstance3D.new()
        var ribbon_mesh := BoxMesh.new()
        ribbon_mesh.size = Vector3(0.05, 0.34, 0.014)
        ribbon.mesh = ribbon_mesh
        ribbon.material_override = _pbr(ribbon_colors[ribbon_index], 0.88)
        ribbon.position = Vector3(1.52 - 0.02 + float(ribbon_index) * 0.045, 1.02 - float(ribbon_index) * 0.09, -0.42 + 0.02)
        ribbon.rotation.z = 0.16 - float(ribbon_index) * 0.3
        ribbon.rotation.x = 0.1 * float(ribbon_index)
        pool.add_child(ribbon)

    # Four water motes hover over the pool, the wish-light the sign in the
    # lobby promises. Seed-fixed heights, the same trick the stairwell uses.
    for mote_index in range(4):
        var mote_angle := TAU * float(mote_index) / 4.0 + 0.4
        var mote := MeshInstance3D.new()
        var mote_mesh := SphereMesh.new()
        mote_mesh.radius = 0.04
        mote_mesh.height = 0.075
        mote.mesh = mote_mesh
        mote.material_override = _emissive(Color("#c8f0e2"), 2.0)
        mote.position = Vector3(cos(mote_angle) * 0.8, 0.42 + 0.16 * sin(mote_angle * 3.1), sin(mote_angle) * 0.8)
        pool.add_child(mote)

func _build_sign(world_position: Vector3) -> void:
    var sign := Node3D.new()
    sign.name = "ForestSign"
    sign.position = world_position
    sign.rotation.y = _rng.randf_range(-0.35, 0.35)
    add_child(sign)
    var post := MeshInstance3D.new()
    var post_mesh := CylinderMesh.new()
    post_mesh.top_radius = 0.07
    post_mesh.bottom_radius = 0.09
    post_mesh.height = 1.4
    post.mesh = post_mesh
    post.material_override = _pbr(Color("#7d5538"), 0.9)
    post.position = Vector3(0, 0.7, 0)
    sign.add_child(post)
    var board := MeshInstance3D.new()
    var board_mesh := BoxMesh.new()
    board_mesh.size = Vector3(1.65, 0.72, 0.12)
    board.mesh = board_mesh
    board.material_override = _pbr(Color("#c99558"), 0.88)
    board.position = Vector3(0, 1.35, 0)
    sign.add_child(board)
    var label := Label3D.new()
    label.text = String(BeautyContent.random_choice(BeautyLore.SIGNS))
    label.font_size = 22
    label.pixel_size = 0.006
    label.modulate = Color("#5c3d2c")
    label.outline_size = 0
    label.position = Vector3(0, 1.35, 0.071)
    label.rotation.y = 0.0
    label.width = 250
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sign.add_child(label)
