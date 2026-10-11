extends SceneTree

# Dev probe — Not shipped.
#
# Walks a long chain of floors and reports the engine's object and node
# counts at each step. A floor teardown that forgets something (a wisp, a
# particle emitter, a timer's lambda capture) shows up here as a trend that
# never comes back down: the same floor loaded twice must cost the same
# amount both times. Pairs with probe_frame_cost.gd, which answers "how
# fast", while this answers "for how long".

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._start_run(1)
	await process_frame

	# Pass 1 descends deep enough to cross a chapter boundary and visit both
	# a merchant floor and a dragon floor; pass 2 RE-visits the same band, so
	# a leak that grows per unique floor and one that grows per floor visited
	# are both visible.
	var marks := {}
	for floor_number in range(2, 42):
		game._load_floor(floor_number, true)
		for _frame in range(3):
			await process_frame
		if floor_number % 10 == 0 or floor_number == 14:
			var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			marks[floor_number] = {"objects": objects, "nodes": nodes}
			print("SOAK floor %4d | objects %6d | nodes %5d" % [floor_number, objects, nodes])

	print("SOAK second pass over 12..32 (same floors again):")
	var growth := 0
	for floor_number in range(12, 33):
		game._load_floor(floor_number, true)
		for _frame in range(3):
			await process_frame
		if floor_number % 10 == 0 or floor_number == 32:
			var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var before: Dictionary = marks.get(floor_number, {})
			var delta: int = objects - int(before.get("objects", objects))
			growth = mini(growth, delta)
			print("SOAK floor %4d | objects %6d | nodes %5d | vs first pass %+d objects" % [
				floor_number, objects, nodes, delta])
	# A small drift is normal (the mote, caches, the hero's rig); a climb on
	# every re-visited floor is a leak the second pass makes undeniable.
	print("SOAK verdict: %s" % ("OK" if growth < 2000 else "LEAK -- re-visited floors kept %d objects" % growth))
	quit()
