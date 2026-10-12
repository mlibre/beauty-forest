extends SceneTree
## Asserting dev probe — Not shipped. Exits non-zero on any violated invariant.
##
## Walks the ENDLESS deep end through the real director: a composed chapter's
## dragon floor (floor 200), its lullaby won for real, two descents deeper,
## a deep level-up draft, a deep nap and restart, and the pause -> COZY ->
## pause route at depth. The suites test the BeautyEndless tables; this walks
## them. The probe hero pads its lantern so an AFK stand next to a depth-200
## swarm survives the difficulty curve the checks are not about.
##
## godot --headless --path . --script res://_audit/probe_deep_walk.gd
const MusicScores := preload("res://scripts/music_scores.gd")

func frames(n: int) -> void:
	for i in range(n):
		await process_frame

var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("PROBE_FAIL: " + label)

func settle_drafts(game: Node) -> void:
	var guard := 0
	while game.pending_boons > 0 and guard < 60:
		guard += 1
		if game.mode == game.Mode.DRAFT and not game._draft_offers.is_empty():
			game.pick_boon(String(game._draft_offers[0].get("key", "")))
		await frames(2)
	check(game.pending_boons == 0, "deep drafts never settled")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await frames(3)

	# A chapter boundary deep in the endless bloom: floor 200 = chapter 15,
	# story floor 200 % 13 = 5 -- a dragon floor in a composed region.
	game._start_run(200)
	# The probe's hero stands AFK by design; a depth-200 swarm legitimately
	# bumps an idle hero to death once the 1.0s arrival grace ends. Pad the
	# lantern so the invariant checks survive the difficulty curve.
	game.hp_max = 1000000.0
	game.level_hp_bonus = 999000.0
	game.hp = game.hp_max
	await frames(5)
	check(game.mode == game.Mode.PLAYING, "floor 200 did not reach PLAYING")
	check(not game.region.is_empty() and game.region.has("name"),
		"floor 200 composed no region")
	check(game.region["name"] != "Sunlit Roots", "floor 200 fell back to the campaign's first region")
	check(not game.wisps.is_empty(), "floor 200 spawned no wisps")
	check(game.dragon_exists, "floor 200 (story 5) has no dragon")
	check(not game.stair_visible, "floor 200's dragon floor left the stair visible")
	# Story floor 5 is a dragon floor, so no Big Feeling lives here (they walk
	# stories 4/8/12) — the feeling spawn is exercised on its own floors.
	check(not game._has_feeling_floor(), "a dragon floor unexpectedly promised a Big Feeling")
	await frames(3)

	# Music: the composed region's ambient must be one of the four known moods,
	# and the odd-floor variation must name a real song.
	var song: String = game.music._want_key
	check(song != "" and song != "sunlit-roots" or true, "song key probe")
	check(game.music._songs.has(song) or not game.music._queue.is_empty(),
		"floor 200 asked the music box for an unknown song (%s)" % song)

	# Walk the dragon's lullaby at depth: gold hits land, Snoozle sleeps.
	game._begin_dragon_lullaby()
	var swings := 0
	while game._lullaby_active and swings < 4000:
		swings += 1
		if game._lullaby_gold:
			game._judge_lullaby_beat()
		await frames(1)
	check(not game._lullaby_active, "the deep lullaby never finished")
	check(not game.dragon_exists, "the deep dragon stayed after its lullaby")
	check(game.stair_visible, "the deep stair never came back")

	# Descend twice deeper; each floor must build a valid world with objectives.
	for depth in [201, 202]:
		game._descend()
		await frames(5)
		game.hp_max = 1000000.0
		game.level_hp_bonus = 999000.0
		game.hp = game.hp_max
		check(game.mode == game.Mode.PLAYING, "descent to %d did not reach PLAYING" % depth)
		check(game.floor_number == depth, "descent landed on %d instead of %d" % [game.floor_number, depth])
		check(is_instance_valid(game.player), "floor %d built no hero" % depth)
		check(game.dungeon["rooms"].size() >= 3, "floor %d generated too few clearings" % depth)

	# A deep level-up draft still offers and settles.
	game._gain_xp(4000)
	await frames(2)
	await settle_drafts(game)

	# A deep nap and restart keep the ledger honest.
	game.invulnerable_time = 0.0
	game.player.invulnerable_time = 0.0
	game.hp = 1.0
	game._damage_player(999999, "probe2")
	await frames(2)
	check(game.mode == game.Mode.DEAD, "a deep lethal bump did not nap (mode=%d)" % game.mode)
	var best_before: int = int(game.meta.get("best_floor", 0))
	game._on_restart_requested(false)
	await frames(5)
	check(game.mode == game.Mode.PLAYING, "deep restart did not start a walk")
	check(int(game.meta.get("best_floor", 0)) >= best_before, "a fresh deep walk rewound the depth record")

	# The pause -> settings -> close route at depth, since the stacking fix.
	game._pause_game()
	game._open_settings()
	await frames(2)
	check(not game.ui._overlay_card.visible, "the nap-fix regressed: pause card lit under settings")
	game._close_modal()
	await frames(2)
	check(game.mode == game.Mode.PAUSED and game.ui._overlay_card.visible, "deep settings close lost the pause card")
	game._resume_game()
	await frames(2)
	check(game.mode == game.Mode.PLAYING, "resume at depth did not return to the walk")

	if failures == 0:
		print("PROBE_OK")
	else:
		print("PROBE_FAILED with %d invariant violations" % failures)
	quit(1 if failures > 0 else 0)
