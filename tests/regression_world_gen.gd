extends "res://tests/support/test_case.gd"
## The world checks that need REAL generated floors rather than the synthetic
## fixture: objective placement across the generator's slot-swap, the dragon
## floor's stairwell relocation, and the wishing pool's payment guard. Split
## out of regression_world.gd, which holds the fixture-driven checks.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")
const ForestWorld := preload("res://scripts/forest_world.gd")

func _initialize() -> void:
        suite_name = "BEAUTY_FOREST_WORLD_GEN"
        # Both driven checks start runs, which save meta -- keep that write in
        # the throwaway profile.
        TestProfile.begin("world_gen")
        call_deferred("_run")

func _run() -> void:
        _check_objective_props_do_not_stack_on_generated_floors()
        await _check_the_relocated_stair_leaves_the_spawn()
        await _check_the_pool_never_takes_a_sparkle_for_nothing()
        finish(null, "BEAUTY_FOREST_WORLD_GEN")

func _check_objective_props_do_not_stack_on_generated_floors() -> void:
        ## The synthetic fixture hand-picks its rooms, so it never exercises the
        ## generator's slot-swap that put the farthest clearing in rooms[1]. Build
        ## real floors, which is the layout the player actually walks into.
        var probe := ForestWorld.new()
        root.add_child(probe)
        probe.set_process(false)
        for floor_number in [5, 13, 30]:
                for attempt in range(8):
                        var real_floor: int = floor_number + attempt * 97
                        var generated := DungeonGenerator.generate(real_floor)
                        probe.build_floor(real_floor, generated, true)
                        var stair := probe.stair_position
                        var merchant := probe.get_node_or_null("Peddle") as Node3D
                        ok(merchant != null, "floor %d built no Peddle cart" % real_floor)
                        if merchant != null:
                                var separation := Vector2(stair.x - merchant.position.x, stair.z - merchant.position.z).length()
                                ok(separation > 4.0,
                                        "floor %d stacked the stairwell and Peddle's cart %.2f m apart" % [real_floor, separation])
                        # Chimes only exist on a dragon floor, and they are built against a
                        # cleared room rather than by build_floor itself. Snoozle takes the
                        # biggest non-spawn clearing, exactly as run_world does.
                        var rooms: Array = generated["rooms"]
                        var dragon_room: Dictionary = rooms[0]
                        var largest_area := -1.0
                        for room: Dictionary in rooms:
                                if room == rooms[0]:
                                        continue
                                if float(room["area"]) > largest_area:
                                        largest_area = float(room["area"])
                                        dragon_room = room
                        probe.build_dragon(dragon_room, real_floor == 30)
                        var chime_room: Dictionary = rooms[0]
                        var farthest := -1.0
                        for room: Dictionary in rooms:
                                if room == dragon_room:
                                        continue
                                var reach := Vector2(room["cx"] - rooms[0]["cx"], room["cy"] - rooms[0]["cy"]).length()
                                if reach > farthest:
                                        farthest = reach
                                        chime_room = room
                        probe.build_dream_chimes(chime_room)
                        ok(not probe.chimes.is_empty(), "floor %d built no dream chimes" % real_floor)
                        for chime: Node3D in probe.chimes:
                                var chime_to_stair := Vector2(chime.global_position.x - stair.x, chime.global_position.z - stair.z).length()
                                ok(chime_to_stair > 2.0,
                                        "floor %d put a dream chime %.2f m from the stairwell" % [real_floor, chime_to_stair])
                                var pool := probe.get_node_or_null("WishingPool") as Node3D
                                if pool != null:
                                        var chime_to_pool := Vector2(chime.global_position.x - pool.position.x,
                                                chime.global_position.z - pool.position.z).length()
                                        ok(chime_to_pool > 2.0,
                                                "floor %d put a dream chime %.2f m from the wishing pool" % [real_floor, chime_to_pool])
        root.remove_child(probe)
        probe.free()

func _check_the_relocated_stair_leaves_the_spawn() -> bool:
        ## A dragon floor relocates the stairwell when the generator happened to put
        ## it in Snoozle's clearing. It has to land somewhere the hero is NOT
        ## standing: the whole tail of the floor is "wander down to the stair", and
        ## the interact radius is 2.3 m. Taking the first room that is not the
        ## dragon's room is rooms[0] -- the spawn clearing -- so the revealed
        ## stairwell appeared exactly on the hero, and one press of E descended
        ## without walking a step.
        ##
        ## Driven through the real game, because the relocation lives on the run
        ## state rather than on ForestWorld.
        var packed: PackedScene = load("res://scenes/main.tscn")
        var game: Node = packed.instantiate()
        root.add_child(game)
        await frames(2)
        game._start_run(1)
        await frames(4)
        var dragon_floors := 0
        var on_spawn := 0
        # A wide contiguous band. Both defects here are LAYOUT-DEPENDENT -- they only
        # misfire on some generated floors -- so a narrow arithmetic sweep that
        # landed on 4 dragon floors could not see either one. This band covers 30.
        for real_floor in range(1, 200):
                game._load_floor(real_floor, false)
                await frames(2)
                if not game.dragon_exists:
                        continue
                dragon_floors += 1
                var rooms: Array = game.dungeon["rooms"]
                var spawn_room: Dictionary = rooms[0]
                var stair: Vector3 = game.world.stair_position
                var spawn := Vector3(float(spawn_room["cx"]), 0, float(spawn_room["cy"]))
                var separation := Vector2(stair.x - spawn.x, stair.z - spawn.z).length()
                if separation < 2.3:
                        on_spawn += 1
                ok(separation > 2.3,
                        "floor %d left the relocated stairwell %.2f m from the spawn -- inside the 2.3 m interact radius, so the hero descends without walking" % [real_floor, separation])
                ok(not game._point_in_room(stair, spawn_room),
                        "floor %d left the relocated stairwell inside the spawn clearing the hero starts in" % real_floor)
                # And the chimes must have spread AROUND the stairwell's final home.
                # build_dream_chimes() seeds its spread from the landmark positions, so
                # if the stair is relocated after it runs, the chimes were told to avoid
                # a spot the stair then moved into. That fires on 14 of 30 dragon floors.
                for chime: Node3D in game.world.chimes:
                        var chime_to_stair := Vector2(chime.global_position.x - stair.x, chime.global_position.z - stair.z).length()
                        ok(chime_to_stair > 2.0,
                                "floor %d settled a dream chime %.2f m from the relocated stairwell" % [real_floor, chime_to_stair])
        root.remove_child(game)
        game.free()
        await frames(2)
        if dragon_floors == 0:
                fail("no dragon floors were generated, so the relocated stairwell was never checked")
                return false
        printerr("RELOCATION_SAMPLE: %d dragon floors, %d put the stair on the spawn" % [dragon_floors, on_spawn])
        return true

func _check_the_pool_never_takes_a_sparkle_for_nothing() -> void:
        ## The wish pool charges one sparkle and answers with +15 warmth. A walker
        ## whose lantern was already full got nothing back for it: the sparkle was
        ## spent, the warmth clamped away, and the story card still said "with the
        ## forest's thanks". A gift that takes payment and gives nothing in return
        ## is a shop trick, so the pool politely waits until the warmth can land.
        ## Driven through the real game, because the wish lives on the run state.
        var packed: PackedScene = load("res://scenes/main.tscn")
        var game: Node = packed.instantiate()
        root.add_child(game)
        await frames(2)
        game._start_run(1)
        await frames(4)
        game.sparkles = 5
        game.hp = game.hp_max
        game._make_a_wish()
        if not ok(game.sparkles == 5,
                        "the pool took a sparkle from a walker whose lantern was already full"):
                root.remove_child(game)
                game.free()
                return
        # And the wish still works the moment the warmth has somewhere to go.
        game.hp = game.hp_max - 30.0
        game._make_a_wish()
        ok(game.sparkles == 4, "a hurt walker's wish was refused too")
        ok(absf(game.hp - (game.hp_max - 15.0)) < 0.01,
                        "the wish healed %.1f instead of 15" % [game.hp - (game.hp_max - 30.0)])
        root.remove_child(game)
        game.free()
        await frames(2)
