extends "res://tests/support/test_case.gd"
## The floor-surprise wheel: every floor hides exactly one surprise, adjacent
## floors never repeat a kind, every kind builds on a real floor, and every
## kind answers the hero — by E or by proximity — exactly once. Three of the
## kinds are little optional adventures (a firefly chase, a star trail, an
## echo shell): they pay sparkles or a heart and never block the stair.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const FloorSurprise := preload("res://scripts/floor_surprise.gd")
const GameScene := preload("res://scenes/main.tscn")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_SURPRISE_REGRESSION"
    call_deferred("_run")

func _run() -> void:
    # The wheel: forty floors of kinds, adjacent floors always different.
    var previous := ""
    for floor_number in range(1, 41):
        var kind := FloorSurprise.kind_for_floor(floor_number)
        if not ok(String(kind["key"]) != previous,
                "floors %d and %d share the same surprise (%s)" % [floor_number - 1, floor_number, previous]):
            stop(null, suite_name)
            return
        previous = String(kind["key"])
    var seen := {}
    for floor_number in range(1, 41):
        seen[String(FloorSurprise.kind_for_floor(floor_number)["key"])] = true
    if not ok(seen.size() == FloorSurprise.KINDS.size(),
            "forty floors only met %d of the %d kinds" % [seen.size(), FloorSurprise.KINDS.size()]):
        stop(null, suite_name)
        return

    # A live walk: every campaign floor carries its one surprise, of the kind
    # the wheel promised, and every kind answers the hero exactly once.
    var game: Node = GameScene.instantiate()
    root.add_child(game)
    await frames(4)
    game._start_run(1)
    await frames(4)
    for floor_number in range(1, BeautyContent.CAMPAIGN_LENGTH + 1):
        if game.mode == game.Mode.DRAFT:
            game.pick_boon(String(game._draft_offers[0].get("key", "")))
            await frames(2)
        game._load_floor(floor_number, false)
        await frames(3)
        if not ok(game._surprise != null and is_instance_valid(game._surprise),
                "floor %d spawned no surprise" % floor_number):
            game.free()
            await frames(1)
            stop(null, suite_name)
            return
        var wanted := String(FloorSurprise.kind_for_floor(floor_number)["key"])
        if not ok(String(game._surprise.get_meta("surprise_key")) == wanted,
                "floor %d hid %s where the wheel promised %s" % [floor_number, game._surprise.get_meta("surprise_key"), wanted]):
            game.free()
            await frames(1)
            stop(null, suite_name)
            return
        if not await _check_surprise_answers(game, floor_number, wanted):
            game.free()
            await frames(1)
            stop(null, suite_name)
            return
    # Reachability: a prop scattered into a wall cell comes home, a prop on
    # a floor cell keeps its scatter, and the check fails for the reason it
    # names (see the mutation note below).
    _check_walled_in_props_come_home()

    # AudioServer drains stopped playbacks asynchronously (see the same note
    # in runtime_smoke.gd); quitting before it settles leaks ObjectDB refs.
    await frames(30)
    game.free()
    await frames(1)
    finish(null, "BEAUTY_FOREST_SURPRISE_REGRESSION")

## Walk one kind's answer: put the hero where the surprise listens, pull the
## trigger, and require the meta to flip — used twice must be a no-op.
func _check_surprise_answers(game: Node, floor_number: int, key: String) -> bool:
    var surprise: Node3D = game._surprise
    var player: Node3D = game.player
    var before_sparkles := int(game.sparkles)
    match key:
        "picnic", "singing_ring", "comet_log", "mossy_doodle", "wisp_choir", "lantern_release", "treasure_sprout", "mushroom_house", "shooting_star":
            player.global_position = surprise.global_position + Vector3(1.2, 0.05, 0)
            if not ok(game._surprise_interact(), "floor %d's %s did not answer E" % [floor_number, key]):
                return false
            if not ok(bool(surprise.get_meta("surprise_used")), "floor %d's %s did not mark itself used" % [floor_number, key]):
                return false
            if not ok(not game._surprise_interact(), "floor %d's %s answered twice" % [floor_number, key]):
                return false
        "star_glade":
            player.global_position = surprise.global_position + Vector3(0.2, 0.05, 0)
            for _tick in range(3):
                game._tick_surprise(1.0)
            if not ok(bool(surprise.get_meta("surprise_used")), "standing in the glade on floor %d granted nothing" % floor_number):
                return false
            if not ok(game.hp > 100.0 or is_equal_approx(game.hp, game.hp_max), "the glade's warmth did not land (hp %f)" % game.hp):
                return false
        "lantern_bloom":
            for index in range(5):
                var bulb := surprise.get_node_or_null("Bulb%d" % index) as Node3D
                if not ok(bulb != null, "floor %d's bloom is missing bulb %d" % [floor_number, index]):
                    return false
                player.global_position = bulb.global_position + Vector3(0.5, 0.05, 0)
                game._tick_surprise(0.05)
            if not ok(bool(surprise.get_meta("surprise_used")), "lighting every bulb on floor %d granted nothing" % floor_number):
                return false
        "balloon_puffs":
            for index in range(4):
                var puff := surprise.get_node_or_null("Puff%d" % index) as Node3D
                if not ok(puff != null, "floor %d's puffs are missing puff %d" % [floor_number, index]):
                    return false
                player.global_position = puff.global_position + Vector3(0.4, 0.05, 0)
                game._tick_surprise(0.05)
            if not ok(bool(surprise.get_meta("surprise_used")), "popping every puff on floor %d granted nothing" % floor_number):
                return false
        "firefly_chase":
            for index in range(3):
                var fly := surprise.get_node_or_null("Fly%d" % index) as Node3D
                if not ok(fly != null, "floor %d's chase is missing firefly %d" % [floor_number, index]):
                    return false
                player.global_position = fly.global_position + Vector3(0.4, 0.05, 0)
                game._tick_surprise(0.05)
            if not ok(bool(surprise.get_meta("surprise_used")), "catching every firefly on floor %d granted nothing" % floor_number):
                return false
        "star_trail":
            # The trail answers only the NEXT star, in order — walk it wrong
            # and it stays quiet, walk it right and it pays a heart.
            var stars := surprise.get_node_or_null("Star4") as Node3D
            if not ok(stars != null, "floor %d's trail is missing its last star" % floor_number):
                return false
            player.global_position = stars.global_position + Vector3(0.4, 0.05, 0)
            game._tick_surprise(0.05)
            if not ok(not bool(surprise.get_meta("surprise_used")),
                    "floor %d's trail answered the LAST star first — the order is not taught" % floor_number):
                return false
            for index in range(5):
                var star := surprise.get_node_or_null("Star%d" % index) as Node3D
                if not ok(star != null, "floor %d's trail is missing star %d" % [floor_number, index]):
                    return false
                player.global_position = star.global_position + Vector3(0.4, 0.05, 0)
                game._tick_surprise(0.05)
            if not ok(bool(surprise.get_meta("surprise_used")), "walking every star on floor %d granted nothing" % floor_number):
                return false
        "echo_shell":
            player.global_position = surprise.global_position + Vector3(1.2, 0.05, 0)
            if not ok(game._surprise_interact(), "floor %d's echo shell did not answer E" % floor_number):
                return false
            if not ok(bool(surprise.get_meta("surprise_used")), "floor %d's echo shell did not mark itself used" % floor_number):
                return false
            if not ok(not game._surprise_interact(), "floor %d's echo shell answered twice" % floor_number):
                return false
        "rainbow_puddle":
            player.global_position = surprise.global_position + Vector3(0.2, 0.05, 0)
            game._tick_surprise(0.05)
            if not ok(bool(surprise.get_meta("surprise_used")), "standing in the puddle on floor %d granted nothing" % floor_number):
                return false
        "hedge_nook":
            player.global_position = surprise.global_position + Vector3(0.2, 0.05, 0)
            game._tick_surprise(1.0)
            if not ok(not bool(surprise.get_meta("surprise_used")), "a one-second stop in floor %d's nook already paid out" % floor_number):
                return false
            game._tick_surprise(2.0)
            if not ok(bool(surprise.get_meta("surprise_used")), "resting in the nook on floor %d granted nothing" % floor_number):
                return false
        "butterfly_parade":
            player.global_position = surprise.global_position + Vector3(1.0, 0.05, 0)
            game._tick_surprise(0.05)
            if not ok(bool(surprise.get_meta("surprise_used")), "walking into the parade on floor %d granted nothing" % floor_number):
                return false
        _:
            return fail("floor %d carries an unknown surprise kind '%s'" % [floor_number, key])
    print("SURPRISE_FLOOR_%02d kind=%s sparkles %d -> %d" % [floor_number, key, before_sparkles, int(game.sparkles)])
    return true


## A synthetic six-by-six dungeon (FLOOR=1, WALL=0): a floor ring with one
## wall block at (3,2). A prop pushed toward +X from cell (2,2) lands inside
## the wall at (3,2), where the hero can never walk close enough to answer
## it -- a chase that can never end. The pull-home is a pure static, so it
## is held directly: the walled-in prop comes home, the floor-cell prop
## keeps its scatter. Mutation evidence: comment the _keep_reachable call
## in FloorSurprise.spawn and the first check fails by name.
func _check_walled_in_props_come_home() -> void:
    var dungeon := {
        "width": 6, "height": 6,
        "grid": PackedInt32Array([
            0, 0, 0, 0, 0, 0,
            0, 1, 1, 1, 1, 0,
            0, 1, 1, 0, 1, 0,
            0, 1, 1, 1, 1, 0,
            0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0,
        ]),
    }
    var parent := Node3D.new()
    root.add_child(parent)
    var surprise_root := Node3D.new()
    surprise_root.position = Vector3(2, 0, 2)
    parent.add_child(surprise_root)
    var walled := Node3D.new()
    walled.position = Vector3(1.7, 0.5, 0)
    surprise_root.add_child(walled)
    var free := Node3D.new()
    free.position = Vector3(0.3, 0.4, 1.2)
    surprise_root.add_child(free)
    FloorSurprise._keep_reachable(surprise_root, dungeon)
    # Reach is horizontal: the hero walks the floor plane, so height never
    # kept a prop away and never will.
    var reach := Vector2(walled.position.x, walled.position.z).length()
    if not ok(reach <= 0.3,
            "a prop inside the wall block stayed out of reach (reach %.2f)" % reach):
        return
    if not ok(is_equal_approx(free.position.x, 0.3) and is_equal_approx(free.position.z, 1.2),
            "a prop on a floor cell lost its scatter (at %s)" % free.position):
        return
    # The live path: spawning on this dungeon never leaves a prop in a wall
    # cell, whichever kind the wheel turns up.
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    dungeon["rooms"] = [{"cx": 2, "cy": 2, "x": 1, "y": 1, "w": 2, "h": 2}]
    var spawned := FloorSurprise.spawn(parent, dungeon, rng, 8, {})
    if not ok(spawned != null, "the synthetic floor spawned no surprise"):
        return
    var home := Vector2(spawned.position.x, spawned.position.z)
    for child in spawned.get_children():
        var prop := child as Node3D
        if prop == null:
            continue
        var world := home + Vector2(prop.position.x, prop.position.z)
        if not ok(FloorSurprise._is_floor_cell(dungeon, world),
                "a spawned prop stands inside a wall cell (at %s)" % world):
            return
    parent.queue_free()
