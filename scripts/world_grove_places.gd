class_name WorldGrovePlaces
extends "res://scripts/world_scenery.gd"

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyLore := preload("res://scripts/beauty_lore.gd")
const WorldPlaceDressing := preload("res://scripts/world_place_dressing.gd")

## The grove's places to visit: Peddle's stall, the wishing pool and the
## spawn-side sign. Split out of WorldLandmarks when that file outgrew the
## 500-line ceiling -- this file is one chain link between the scenery base
## (materials, multimeshes, members like _merchant_body and _water_material)
## and WorldLandmarks, which keeps the clearings and the stairwell. Every
## node name and position here is load-bearing: suites and the minimap walk
## these trees.

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

    # The lived-in layer -- drying herbs, paper price tags, a rolled blanket
    # against the counter -- hung by the dressing static so the furniture
    # above stays exactly where the suites and the minimap expect it.
    WorldPlaceDressing.dress_stall(body)

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
