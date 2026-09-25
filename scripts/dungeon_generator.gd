class_name DungeonGenerator
extends RefCounted

const WALL := 0
const FLOOR := 1

## Generates the same three-clearing, looped forest topology as the reference
## game. The result is a flat PackedInt32Array for cheap collision/line-of-sight
## queries plus room dictionaries for objectives and landmarks.
static func generate(floor_number: int) -> Dictionary:
    var safe_floor := maxi(1, floor_number)
    var seed_value := hash("beauty-forest-%d-%d-%d" % [safe_floor, Time.get_unix_time_from_system(), randi()])
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value

    var width := 48 + mini(safe_floor * 2, 24)
    var height := width
    var grid := PackedInt32Array()
    grid.resize(width * height)
    grid.fill(FLOOR)

    var clearings: Array[Dictionary] = []
    for room_index in range(3):
        var placed: Dictionary = {}
        for _attempt in range(30):
            var room_width := rng.randi_range(7, 10)
            var room_height := rng.randi_range(7, 10)
            var room_x := rng.randi_range(4, width - room_width - 5)
            var room_y := rng.randi_range(4, height - room_height - 5)
            placed = {
                "x": room_x,
                "y": room_y,
                "w": room_width,
                "h": room_height,
                "cx": float(room_x) + room_width * 0.5,
                "cy": float(room_y) + room_height * 0.5,
                "area": room_width * room_height,
            }
            var overlaps := false
            for other: Dictionary in clearings:
                if room_x < int(other["x"]) + int(other["w"]) and int(other["x"]) < room_x + room_width \
                        and room_y < int(other["y"]) + int(other["h"]) and int(other["y"]) < room_y + room_height:
                    overlaps = true
                    break
            if not overlaps:
                break
        clearings.append(placed)

    var grove_count := int(float(width * height) / 260.0)
    for grove_index in range(grove_count):
        var gx := rng.randi_range(2, width - 3)
        var gy := rng.randi_range(2, height - 3)
        if _point_in_any_room(clearings, gx, gy):
            continue
        var radius := rng.randi_range(1, 3)
        for yy in range(gy - radius, gy + radius + 1):
            for xx in range(gx - radius, gx + radius + 1):
                if xx <= 1 or yy <= 1 or xx >= width - 2 or yy >= height - 2:
                    continue
                if _point_in_any_room(clearings, xx, yy):
                    continue
                var distance := Vector2(float(xx - gx), float(yy - gy)).length()
                if distance <= float(radius) and rng.randf() < (1.0 - distance / float(radius + 1)) * 0.88:
                    grid[yy * width + xx] = WALL

    for index in range(1, clearings.size()):
        _carve_corridor(grid, width, height, clearings[index - 1], clearings[index], 1, rng)
    if clearings.size() >= 3:
        _carve_loop(grid, width, height, clearings[2], clearings[0], 1.0)
        _carve_loop(grid, width, height, clearings[0], clearings[1], -0.65)

    for x in range(width):
        if not _point_in_any_room(clearings, x, 0):
            grid[x] = WALL
        if not _point_in_any_room(clearings, x, height - 1):
            grid[(height - 1) * width + x] = WALL
    for y in range(height):
        if not _point_in_any_room(clearings, 0, y):
            grid[y * width] = WALL
        if not _point_in_any_room(clearings, width - 1, y):
            grid[y * width + width - 1] = WALL

    _prune_disconnected_floor(grid, width, height, clearings)

    var sorted_rooms := clearings.duplicate()
    sorted_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["area"]) > float(b["area"]))
    if sorted_rooms.size() >= 3:
        # The world uses the last room for the wishing pool. Keep the farthest
        # room in the middle slot so the pool cannot land on the stair clearing.
        var spawn_room: Dictionary = sorted_rooms[0]
        var farthest_index := 0
        var farthest_distance := -1.0
        for room_index in range(1, sorted_rooms.size()):
            var candidate: Dictionary = sorted_rooms[room_index]
            var distance := Vector2(
                float(candidate["cx"]) - float(spawn_room["cx"]),
                float(candidate["cy"]) - float(spawn_room["cy"])
            ).length()
            if distance > farthest_distance:
                farthest_distance = distance
                farthest_index = room_index
        if farthest_index == sorted_rooms.size() - 1:
            var middle_room: Dictionary = sorted_rooms[1]
            sorted_rooms[1] = sorted_rooms[farthest_index]
            sorted_rooms[farthest_index] = middle_room
    return {
        "width": width,
        "height": height,
        "grid": grid,
        "rooms": sorted_rooms,
        "seed": seed_value,
        "floor": safe_floor,
    }

static func _point_in_any_room(rooms: Array[Dictionary], x: int, y: int) -> bool:
    for room: Dictionary in rooms:
        if x >= int(room["x"]) and x < int(room["x"]) + int(room["w"]) \
                and y >= int(room["y"]) and y < int(room["y"]) + int(room["h"]):
            return true
    return false

static func _carve_corridor(grid: PackedInt32Array, width: int, height: int, from_room: Dictionary, to_room: Dictionary, radius: int, rng: RandomNumberGenerator) -> void:
    var from := Vector2(from_room["cx"], from_room["cy"])
    var to := Vector2(to_room["cx"], to_room["cy"])
    var steps := maxi(1, int(from.distance_to(to)) + 1)
    for step in range(steps + 1):
        var point := from.lerp(to, float(step) / float(steps))
        point += Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))
        _clear_disc(grid, width, height, int(round(point.x)), int(round(point.y)), radius)

static func _carve_loop(grid: PackedInt32Array, width: int, height: int, from_room: Dictionary, to_room: Dictionary, bend: float) -> void:
    var from := Vector2(from_room["cx"], from_room["cy"])
    var to := Vector2(to_room["cx"], to_room["cy"])
    var control := (from + to) * 0.5 + Vector2(float(width) * 0.10 * signf(to.x - from.x + 0.001), float(height) * bend)
    for step in range(80):
        var t := float(step) / 79.0
        var inv := 1.0 - t
        var point := inv * inv * from + 2.0 * inv * t * control + t * t * to
        _clear_disc(grid, width, height, int(round(point.x)), int(round(point.y)), 1)

static func _clear_disc(grid: PackedInt32Array, width: int, height: int, center_x: int, center_y: int, radius: int) -> void:
    for y in range(center_y - radius, center_y + radius + 1):
        for x in range(center_x - radius, center_x + radius + 1):
            if x > 1 and y > 1 and x < width - 2 and y < height - 2:
                grid[y * width + x] = FLOOR

static func _prune_disconnected_floor(grid: PackedInt32Array, width: int, height: int, rooms: Array[Dictionary]) -> void:
    if width <= 0 or height <= 0 or rooms.is_empty():
        return
    var start := _room_cell(rooms[0], width, height)
    if grid[start.y * width + start.x] != FLOOR:
        grid[start.y * width + start.x] = FLOOR
    var reachable := _flood_floor(grid, width, height, start)
    for room_index in range(1, rooms.size()):
        var room_cell := _room_cell(rooms[room_index], width, height)
        if reachable[room_cell.y * width + room_cell.x] != 0:
            continue
        # The random corridors should connect every room. Keep a deterministic
        # repair path for an unlucky placement instead of returning a split map.
        _carve_room_link(grid, width, height, start, room_cell)
        reachable = _flood_floor(grid, width, height, start)
    for index in range(grid.size()):
        if grid[index] == FLOOR and reachable[index] == 0:
            grid[index] = WALL

static func _flood_floor(grid: PackedInt32Array, width: int, height: int, start: Vector2i) -> PackedByteArray:
    var reachable := PackedByteArray()
    reachable.resize(width * height)
    if start.x < 0 or start.y < 0 or start.x >= width or start.y >= height:
        return reachable
    if grid[start.y * width + start.x] != FLOOR:
        return reachable
    var queue: Array[Vector2i] = [start]
    reachable[start.y * width + start.x] = 1
    while not queue.is_empty():
        var point: Vector2i = queue.pop_back()
        for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var neighbor := point + offset
            if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
                continue
            var index := neighbor.y * width + neighbor.x
            if reachable[index] != 0 or grid[index] != FLOOR:
                continue
            reachable[index] = 1
            queue.append(neighbor)
    return reachable

static func _room_cell(room: Dictionary, width: int, height: int) -> Vector2i:
    return Vector2i(
        clampi(int(room.get("cx", 1)), 0, width - 1),
        clampi(int(room.get("cy", 1)), 0, height - 1)
    )

static func _carve_room_link(grid: PackedInt32Array, width: int, height: int, from_cell: Vector2i, to_cell: Vector2i) -> void:
    var current := from_cell
    while current.x != to_cell.x:
        current.x += 1 if current.x < to_cell.x else -1
        _clear_disc(grid, width, height, current.x, current.y, 1)
    while current.y != to_cell.y:
        current.y += 1 if current.y < to_cell.y else -1
        _clear_disc(grid, width, height, current.x, current.y, 1)
    _clear_disc(grid, width, height, current.x, current.y, 1)

static func is_floor(dungeon: Dictionary, grid_x: int, grid_z: int) -> bool:
    if dungeon.is_empty():
        return false
    var width := int(dungeon["width"])
    var height := int(dungeon["height"])
    if grid_x < 0 or grid_z < 0 or grid_x >= width or grid_z >= height:
        return false
    return (dungeon["grid"] as PackedInt32Array)[grid_z * width + grid_x] == FLOOR

static func cell_to_world(cell: Vector2i, height: float = 0.0) -> Vector3:
    return Vector3(float(cell.x) + 0.5, height, float(cell.y) + 0.5)

static func random_floor_cell(dungeon: Dictionary, rng: RandomNumberGenerator, away_from: Vector2, minimum_distance: float = 0.0, occupied: Dictionary = {}) -> Vector2i:
    var width := int(dungeon["width"])
    var height := int(dungeon["height"])
    var fallback := Vector2i(2, 2)
    var best := Vector2i(-1, -1)
    var best_distance := -1.0
    for _attempt in range(180):
        var x := rng.randi_range(2, width - 3)
        var y := rng.randi_range(2, height - 3)
        if not is_floor(dungeon, x, y):
            continue
        var key := Vector2i(x, y)
        if occupied.has(key):
            continue
        var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(away_from)
        if distance >= minimum_distance:
            return key
        if distance > best_distance:
            best_distance = distance
            best = key
    if best.x >= 0:
        return best
    for room: Dictionary in dungeon["rooms"]:
        return Vector2i(int(room["cx"]), int(room["cy"]))
    return fallback

static func has_line_of_sight(dungeon: Dictionary, from: Vector3, to: Vector3) -> bool:
    var from_cell := Vector2i(floori(from.x), floori(from.z))
    var to_cell := Vector2i(floori(to.x), floori(to.z))
    if not is_floor(dungeon, from_cell.x, from_cell.y) or not is_floor(dungeon, to_cell.x, to_cell.y):
        return false
    var distance := Vector2(to.x - from.x, to.z - from.z).length()
    if distance < 0.05:
        return true
    var steps := maxi(1, int(ceil(distance / 0.65)))
    for step in range(1, steps + 1):
        var t := float(step) / float(steps)
        var point := from.lerp(to, t)
        if not is_floor(dungeon, floori(point.x), floori(point.z)):
            return false
    return true
