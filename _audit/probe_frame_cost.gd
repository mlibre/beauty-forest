extends SceneTree

## Dev probe: what does a floor actually cost per frame, and how does it scale
## with depth? Not shipped.
##
## All times are MICROSECONDS. The total column is the per-frame budget of the
## six phases that _physics_process runs once each -- not a sum of per-wisp costs:
## only tick_behavior loops, and it is already measured across every wisp at
## once (hence its "(all)" label). At floor 40 that reads ~800us, i.e. under a
## millisecond against a 16667us frame, so the walk has ~95% of its frame left.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for frames in 20:
		await process_frame

	print("%-6s %5s  %-34s %s" % ["floor", "wisps", "avg us/call", "total us/frame"])
	for floor_number in [1, 6, 13, 20, 30, 40]:
		game._start_run(floor_number, true)
		for frames in 6:
			await process_frame
		var wisps: int = game.wisps.size()
		var samples := 40
		# Each of these is what one _physics_process calls once per frame.
		var timers := {
			"_refresh_wisp_shields": func(): game._refresh_wisp_shields(),
			"_separate_wisps": func(): game._separate_wisps(),
			"_auto_combat": func(): game._auto_combat(0.016),
			"_refresh_ui": func(): game._refresh_ui(),
			"_minimap_markers": func(): game._minimap_markers(),
			"tick_behavior(all)": func():
				for wisp: Wisp in game.wisps:
					if is_instance_valid(wisp) and wisp.alive:
						wisp.tick_behavior(0.016, game.player.global_position, 14.0, 1.0, 1.0),
		}
		var row := []
		var total := 0.0
		for name: String in timers:
			var call: Callable = timers[name]
			var start := Time.get_ticks_usec()
			for index in samples:
				call.call()
			var per_call := float(Time.get_ticks_usec() - start) / float(samples)
			row.append("%s=%.1f" % [name.trim_prefix("_"), per_call])
			total += per_call
		print("%-6d %5d  %-34s %.2f" % [floor_number, wisps, "  ".join(row), total])
		game.floor_number = floor_number - 1

	root.remove_child(game)
	game.free()
	quit(0)
