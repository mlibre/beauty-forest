class_name WorldLandmarks
extends "res://scripts/world_grove_places.gd"
## Objective landmarks built into every floor: the stairwell, Peddle's cart, the
## wishing pool and the forest sign. Placement rules (farthest room, pool never
## on the stair) are resolved in _build_clearings.

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

