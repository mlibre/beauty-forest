extends "res://tests/support/test_case.gd"
## Focused regressions for automatic combat and reward nodes.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const HeartPickup := preload("res://scripts/heart_pickup.gd")
const Player := preload("res://scripts/player.gd")
const Wisp := preload("res://scripts/wisp.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_COMBAT_NODES"
    call_deferred("_run")

func _run() -> void:
    if not await _test_magnet_heart_acquires_player_before_contact():
        stop(null, suite_name)
        return
    if not await _test_giggle_split_children_get_spawn_grace():
        stop(null, suite_name)
        return
    finish(null, "BEAUTY_FOREST_COMBAT_NODES")

func _test_magnet_heart_acquires_player_before_contact() -> bool:
    var fixture := Node3D.new()
    root.add_child(fixture)

    var player := Player.new()
    player.position = Vector3(2.5, 0.05, 0.0)
    fixture.add_child(player)
    player.set_physics_process(false)

    var heart := HeartPickup.new()
    fixture.add_child(heart)
    heart.setup(Vector3.ZERO, 15.0, 1.0, true)
    heart.set_process(false)

    # The player is inside the intended 3.5 m attraction range, but remains
    # outside the 0.9 m collection shape. A magnet must acquire it on contact
    # with its attraction sensor, then pull the heart toward the player.
    await physics_frame
    await physics_frame
    if not ok(is_instance_valid(heart), "magnet heart vanished before its normal pickup range"):
        return false
    var before := heart.global_position
    heart._process(1.0 / 60.0)
    if not ok(heart.global_position.distance_to(before) >= 0.01,
            "magnet heart did not move after acquiring a nearby player"):
        return false

    fixture.free()
    return true

func _test_giggle_split_children_get_spawn_grace() -> bool:
    # A Giggle Puff splits gently into two children on the spot where it was
    # soothed — often right beside the hero. Like every other spawned wisp,
    # the children must arrive with a contact grace cooldown, otherwise the
    # split can nick the player on the very next physics tick.
    TestProfile.begin("combat_giggle")
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)
    game._start_run(1)
    await frames(2)
    var parent := Wisp.new()
    parent.setup("Giggle Puff", 1)
    parent.position = game.player.global_position + Vector3(0.8, 0.0, 0.0)
    game.world.add_child(parent)
    game.wisps.append(parent)
    game._soothe_wisp(parent, false)
    var children: Array = []
    for wisp: Wisp in game.wisps:
        if is_instance_valid(wisp) and wisp != parent and bool(wisp.get_meta("no_split", false)):
            children.append(wisp)
    if not ok(children.size() == 2,
            "soothing a Giggle Puff produced %d split children instead of 2" % children.size()):
        return false
    for child: Wisp in children:
        if not ok(float(child.get_meta("attack_cooldown", 0.0)) > 0.0,
                "a split gigglelet arrived with no contact grace and can bump instantly"):
            return false
    TestProfile.end()
    root.remove_child(game)
    game.free()
    await frames(2)
    return true
