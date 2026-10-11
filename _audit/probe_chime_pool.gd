extends SceneTree

# Dev probe — Not shipped.
#
# The chime spread reserves the stair, Peddle's cart and Snoozle, but not the
# wishing pool -- a landmark prop of the same visual family (rim torus 1.38m
# plus stones at 1.28m). The stair fix measured 1.72m as the combined visible
# radius of two props; this measures how close a chime actually settles to the
# pool across every dragon floor of a long walk, mirroring run_world's
# dragon->relocate-stair->chimes order exactly.
#
# Tree-entry lesson (same one probe_growth learned): during _initialize the
# root window itself is not yet inside the tree, so global_position reads
# identity until a frame has passed. Enter the tree first, build, then measure
# in the same frame so the chime bob never moves a measurement.

const DungeonGenerator := preload("res://scripts/dungeon_generator.gd")
const ForestWorld := preload("res://scripts/forest_world.gd")
const BeautyContent := preload("res://scripts/beauty_content.gd")

func _initialize() -> void:
	await process_frame
	await process_frame
	var worst := 999.0
	var worst_floor := -1
	var under := 0
	var floors := 0
	for floor_number in range(1, 200):
		if not BeautyContent.is_dragon_floor(floor_number):
			continue
		floors += 1
		var dungeon: Dictionary = DungeonGenerator.generate(floor_number)
		var world: Node3D = ForestWorld.new()
		root.add_child(world)
		world.build_floor(floor_number, dungeon, false)
		var rooms: Array = dungeon["rooms"]
		var spawn_room: Dictionary = rooms[0]
		var dragon_room: Dictionary = spawn_room
		var largest_area := -1.0
		for room: Dictionary in rooms:
			if room == spawn_room:
				continue
			if float(room["area"]) > largest_area:
				largest_area = float(room["area"])
				dragon_room = room
		world.build_dragon(dragon_room, false)
		# Mirror run_world._relocate_stair_from: only when the stair fell
		# inside the dragon's clearing.
		if DungeonGenerator.point_in_room(dragon_room, world.stair_position.x, world.stair_position.z):
			var candidate: Dictionary = _farthest_room_from(rooms, spawn_room, dragon_room)
			if candidate != spawn_room and candidate != dragon_room:
				world.stair_position = Vector3(candidate["cx"], 0, candidate["cy"])
				var stair := world.get_node_or_null("Stairwell")
				if stair:
					(stair as Node3D).position = world.stair_position
		world.build_dream_chimes(_farthest_room_from(rooms, spawn_room, dragon_room))
		var pool := world.get_node_or_null("WishingPool")
		if pool != null:
			for chime: Node3D in world.chimes:
				var d: float = chime.global_position.distance_to((pool as Node3D).global_position)
				if d < worst:
					worst = d
					worst_floor = floor_number
				if d < 1.8:
					under += 1
		world.queue_free()
	print("PROBE chime-pool: floors=%d worst=%.2fm at floor %d, chimes under 1.8m of the pool: %d" % [
		floors, worst, worst_floor, under])
	quit(0)

func _farthest_room_from(rooms: Array, spawn_room: Dictionary, exclude: Dictionary) -> Dictionary:
	var best: Dictionary = exclude
	var best_distance := -1.0
	for room: Dictionary in rooms:
		if room == exclude:
			continue
		var distance := Vector2(room["cx"] - spawn_room["cx"], room["cy"] - spawn_room["cy"]).length()
		if distance > best_distance:
			best_distance = distance
			best = room
	return best
