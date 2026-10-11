extends TestCase

const D := preload("res://scripts/dungeon_generator.gd")

func _initialize() -> void:
	suite_name = "BEAUTY_FOREST_DUNGEON"
	call_deferred("_run")

func _run() -> void:
	_test_line_of_sight_endpoints()
	_test_generated_topology()
	_test_no_invisible_walls_around_clearings()
	finish(null, "BEAUTY_FOREST_DUNGEON")

func _test_line_of_sight_endpoints() -> void:
	var dungeon := {
		"width": 3,
		"height": 1,
		"grid": PackedInt32Array([D.FLOOR, D.WALL, D.FLOOR]),
		"rooms": [],
	}
	# The short-distance shortcut skipped cell validation, so a target inside a wall could appear visible.
	if D.has_line_of_sight(dungeon, Vector3(0.99, 0.0, 0.50), Vector3(1.01, 0.0, 0.50)):
		fail("line of sight returned true for a target inside a wall")
	# The zero-distance shortcut also bypassed all floor validation.
	if D.has_line_of_sight(dungeon, Vector3(1.10, 0.0, 0.50), Vector3(1.11, 0.0, 0.50)):
		fail("line of sight returned true for two points inside a wall")

func _test_generated_topology() -> void:
	for floor_number: int in [1, 2, 5, 13, 100]:
		for sample: int in range(8):
			var dungeon: Dictionary = D.generate(floor_number)
			_validate_dungeon(dungeon, floor_number, sample)

func _test_no_invisible_walls_around_clearings() -> void:
	# The grove visual deliberately skips drawing a tree on any wall cell within
	# one cell of a clearing, but collision came straight from is_floor(). Any
	# wall inside that margin was therefore an invisible barrier ringing every
	# room: measured 28 such cells across 11 of 13 campaign floors, each one
	# stopping the player dead against empty moss.
	for sample: int in range(40):
		var dungeon: Dictionary = D.generate(1 + sample)
		var rooms: Array = dungeon.get("rooms", [])
		for room: Dictionary in rooms:
			var room_x := int(room["x"])
			var room_y := int(room["y"])
			for z in range(room_y - 1, room_y + int(room["h"]) + 1):
				for x in range(room_x - 1, room_x + int(room["w"]) + 1):
					if D.is_floor(dungeon, x, z):
						continue
					fail("floor %d sample %d generated an undrawable wall at %d,%d inside a clearing's margin"
						% [1 + sample, sample, x, z])
					return

func _validate_dungeon(dungeon: Dictionary, floor_number: int, sample: int) -> void:
	var width := int(dungeon.get("width", -1))
	var height := int(dungeon.get("height", -1))
	var grid: PackedInt32Array = dungeon.get("grid", PackedInt32Array())
	if width <= 0 or height <= 0 or grid.size() != width * height:
		fail("floor %d sample %d has an invalid grid" % [floor_number, sample])
		return
	var rooms: Array = dungeon.get("rooms", [])
	if rooms.size() != 3:
		fail("floor %d sample %d does not have three rooms" % [floor_number, sample])
		return
	for room_index: int in range(rooms.size()):
		var room: Dictionary = rooms[room_index]
		var room_x := int(room.get("x", -1))
		var room_y := int(room.get("y", -1))
		var room_width := int(room.get("w", 0))
		var room_height := int(room.get("h", 0))
		if room_x < 0 or room_y < 0 or room_width <= 0 or room_height <= 0 \
				or room_x + room_width > width or room_y + room_height > height:
			fail("floor %d sample %d room %d is out of bounds" % [floor_number, sample, room_index])
			continue
		for y in range(room_y, room_y + room_height):
			for x in range(room_x, room_x + room_width):
				if grid[y * width + x] != D.FLOOR:
					fail("floor %d sample %d room %d contains a wall" % [floor_number, sample, room_index])
					break
	for first_index: int in range(rooms.size()):
		for second_index: int in range(first_index):
			var first := Vector2i(int(rooms[first_index]["cx"]), int(rooms[first_index]["cy"]))
			var second := Vector2i(int(rooms[second_index]["cx"]), int(rooms[second_index]["cy"]))
			if not _reachable(grid, width, height, first, second):
				fail("floor %d sample %d disconnects rooms %d and %d" % [floor_number, sample, first_index, second_index])
	var spawn_room: Dictionary = rooms[0]
	var farthest_index := 0
	var farthest_distance := -1.0
	for room_index: int in range(1, rooms.size()):
		var candidate: Dictionary = rooms[room_index]
		var distance := Vector2(
			float(candidate["cx"]) - float(spawn_room["cx"]),
			float(candidate["cy"]) - float(spawn_room["cy"])
		).length()
		if distance > farthest_distance:
			farthest_distance = distance
			farthest_index = room_index
	if farthest_index != 1:
		fail("floor %d sample %d puts the stair clearing in the pool slot" % [floor_number, sample])
	var pool_room: Dictionary = rooms[rooms.size() - 1]
	var stair_room: Dictionary = rooms[farthest_index]
	if pool_room == stair_room or Vector2(
			float(pool_room["cx"]) - float(stair_room["cx"]),
			float(pool_room["cy"]) - float(stair_room["cy"])
	).length() <= 3.0:
		fail("floor %d sample %d places the wishing pool on the stair clearing" % [floor_number, sample])
	var components := _floor_components(grid, width, height)
	if components.size() != 1:
		fail("floor %d sample %d has %d disconnected floor components" % [floor_number, sample, components.size()])
	for x in range(width):
		if grid[x] != D.WALL or grid[(height - 1) * width + x] != D.WALL:
			fail("floor %d sample %d has an open horizontal border" % [floor_number, sample])
			break
	for y in range(height):
		if grid[y * width] != D.WALL or grid[y * width + width - 1] != D.WALL:
			fail("floor %d sample %d has an open vertical border" % [floor_number, sample])
			break

func _floor_components(grid: PackedInt32Array, width: int, height: int) -> Array:
	var visited := {}
	var components: Array = []
	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if grid[y * width + x] != D.FLOOR or visited.has(start):
				continue
			var queue: Array[Vector2i] = [start]
			visited[start] = true
			var component: Array[Vector2i] = []
			while not queue.is_empty():
				var point: Vector2i = queue.pop_back()
				component.append(point)
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var neighbor := point + offset
					if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < width and neighbor.y < height \
							and not visited.has(neighbor) and grid[neighbor.y * width + neighbor.x] == D.FLOOR:
						visited[neighbor] = true
						queue.append(neighbor)
			components.append(component)
	return components

func _reachable(grid: PackedInt32Array, width: int, height: int, start: Vector2i, goal: Vector2i) -> bool:
	if grid[start.y * width + start.x] != D.FLOOR or grid[goal.y * width + goal.x] != D.FLOOR:
		return false
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	while not queue.is_empty():
		var point: Vector2i = queue.pop_back()
		if point == goal:
			return true
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor := point + offset
			if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < width and neighbor.y < height \
					and not visited.has(neighbor) and grid[neighbor.y * width + neighbor.x] == D.FLOOR:
				visited[neighbor] = true
				queue.append(neighbor)
	return false
