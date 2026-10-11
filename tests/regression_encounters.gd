extends "res://tests/support/test_case.gd"
## Floor-level encounters: where Snoozle sleeps, whether a homing song-note
## reaches a Very Big Wisp, and whether the forest's ambience comes back after a
## dragon is tucked in.
##
## Split out of regression_main_flow.gd. Each of these needs a specific floor
## and a specific creature on it, which is a different fixture from the run-state
## transitions the main flow suite drives.
##
## The bodies moved verbatim from regression_main_flow.gd; only the helper names
## changed, to the ones on TestCase.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const SongNote := preload("res://scripts/song_note.gd")
const Wisp := preload("res://scripts/wisp.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_ENCOUNTERS"
    TestProfile.begin("encounters")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)

    if not await _check_dragon_never_sleeps_in_the_spawn_clearing(game):
        return
    if not await _check_homing_note_reaches_a_very_big_wisp(game):
        return
    if not await _check_ambience_returns_after_a_non_finale_dragon(game):
        return
    if not await _check_dragon_clear_hands_the_way_to_the_stair(game):
        return
    if not await _check_the_lullaby_pauses_contact_damage(game):
        return

    finish(game, "BEAUTY_FOREST_ENCOUNTERS")

func _check_dragon_never_sleeps_in_the_spawn_clearing(game: Node) -> bool:
    ## Snoozle is a 5m sleeping barrel with no collider, and the hero arrives at
    ## the centre of rooms[0]. The generator already sorts rooms largest-first,
    ## so the old "find the biggest room" scan just re-picked the spawn room and
    ## every dragon floor opened with the player standing inside the dragon.
    for floor_number in [5, 13]:
        game._load_floor(floor_number, false)
        await frames(4)
        if not ok(game.dragon_exists, "floor %d should be a dragon floor" % floor_number):
            return false
        var spawn_room: Dictionary = game.dungeon["rooms"][0]
        var in_spawn: bool = game._point_in_room(game.world.dragon_position, spawn_room)
        if not ok(not in_spawn,
                "floor %d put Snoozle in the spawn clearing, on top of the hero" % floor_number):
            return false
        var separation := Vector2(
            game.world.dragon_position.x - game.player.global_position.x,
            game.world.dragon_position.z - game.player.global_position.z).length()
        if not ok(separation > 3.0,
                "floor %d spawned the hero %.2f m from Snoozle's centre" % [floor_number, separation]):
            return false
    game._start_run(1)
    await frames(4)
    return true

func _check_dragon_clear_hands_the_way_to_the_stair(game: Node) -> bool:
    ## After Snoozle is tucked in on a non-finale floor the walk continues: the
    ## waypoint, minimap and stair-arrival must all treat the floor as
    ## dragon-free. `dragon_exists` used to stay true until the next floor, so
    ## the glow stayed parked on a sleeping dragon and the stair marker never
    ## registered arrival.
    game._start_run(5)
    await frames(6)
    if not ok(game.dragon_exists, "floor 5 should open as a dragon floor"):
        return false
    # The real game only starts the dragon lullaby once every Dream Chime is
    # gathered; mirror that end state so the objective after the win is the
    # stair, not a chime pickup that cannot still be outstanding.
    for chime in game.world.chimes:
        if is_instance_valid(chime):
            game.world.remove_child(chime)
            chime.free()
    game.world.chimes.clear()
    game._win_dragon()
    await frames(12)
    if not ok(not game.dragon_exists, "dragon_exists survived the dragon being tucked in"):
        return false
    # The objective line repaints on the same 0.10 s pulse that hops the HUD; a
    # headless run tips under that horizon by frame-count timing, so spin
    # until the refresh has actually had its say.
    var saw_stair := false
    for _i in range(30):
        await frames(1)
        if game.ui._walker_objective.contains("glowing stair"):
            saw_stair = true
            break
    if not ok(saw_stair,
            "after the lullaby the objective still read: %s" % game.ui._walker_objective):
        return false
    game._start_run(1)
    await frames(4)
    return true

func _check_the_lullaby_pauses_contact_damage(game: Node) -> bool:
    ## The sit-with ceremony is the calmest path to soothe a Big Feeling; it
    ## must not meet its own sob — during the song the feeling's contact rule
    ## has to hold its breath.
    game._start_run(8)
    await frames(6)
    var patient: Wisp = null
    for wisp: Wisp in game.wisps:
        if wisp.is_feeling and wisp.alive:
            patient = wisp
    if not ok(patient != null, "the feeling floor spawned no Big Feeling"):
        return false
    patient.global_position = game.player.global_position + Vector3(1.0, 0.0, 0.0)
    patient.set_meta("attack_cooldown", 0.0)
    game.hp = game.hp_max
    game.invulnerable_time = 0.0
    game.player.invulnerable_time = 0.0
    game._begin_feeling_lullaby(patient)
    var warmth_before: float = game.hp
    for _step in range(30):
        await physics_frame
    if not ok(is_equal_approx(game.hp, warmth_before),
            "the Big Feeling's sob met the player mid-lullaby (%.0f -> %.0f)" % [warmth_before, game.hp]):
        return false
    game._reset_lullaby()
    game._start_run(1)
    await frames(4)
    return true

func _check_homing_note_reaches_a_very_big_wisp(game: Node) -> bool:
    ## A Big Feeling renders at 3.5x scale. The note used to aim at a fixed 0.72m
    ## above the wisp while the connect test measured 0.70 * visual_scale, so the
    ## homing note converged 1.7m below the test sphere and always expired.
    for is_big in [false, true]:
        game._load_floor(3, false)
        await frames(4)
        var target: Wisp = game.wisps[0]
        target.setup("Shambler", 13, is_big)
        target.global_position = game.player.global_position + Vector3(6.0, 0.0, 0.0)
        var note := SongNote.new()
        game.world.add_child(note)
        var connected := [false]
        var expired := [false]
        note.connected_wisp.connect(func(_w: Wisp, _n: SongNote) -> void: connected[0] = true)
        note.note_expired.connect(func(_p: Vector3, _b: bool) -> void: expired[0] = true)
        note.setup(target, 10.0, 1.0, 99.0, Color("#ffe6a0"))
        note.position = game.player.global_position + Vector3.UP * 1.2
        note.launch(Vector3(1.0, 0.0, 0.0))
        for _step in range(600):
            note._physics_process(1.0 / 60.0)
            if connected[0] or expired[0]:
                break
        var label := "a Very Big Wisp" if is_big else "a plain wisp"
        if not ok(connected[0] and not expired[0],
                "a homing song-note could not connect to %s (scale %.1f)" % [label, target.visual_scale]):
            if is_instance_valid(note):
                note.free()
            return false
        if is_instance_valid(note):
            note.free()
        await frames(2)
    game._start_run(1)
    await frames(4)
    return true

func _check_ambience_returns_after_a_non_finale_dragon(game: Node) -> bool:
    ## Singing Snoozle to sleep silences the grove so the lullaby reads clearly,
    ## but on a non-finale floor the hero keeps wandering. Nothing re-armed the
    ## ambience, so the rest of the run played silent until a pause or descent.
    game._start_run(5)
    await frames(6)
    if not ok(game.audio._ambient_player.playing, "floor 5 should arrive with ambience playing"):
        return false
    game._win_dragon()
    await frames(6)
    if not ok(game.audio._ambient_player.playing and game.audio._ambient_should_play,
            "the grove stayed silent after Snoozle snoozed, though the walk continues"):
        return false
    # The finale hands the audio over to the ending, so it must stay quiet.
    game._start_run(13)
    await frames(6)
    game._win_dragon()
    await frames(6)
    if not ok(not game.audio._ambient_should_play,
            "the finale ending should keep the grove hushed"):
        return false
    game._start_run(1)
    await frames(4)
    return true
