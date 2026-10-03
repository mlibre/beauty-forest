extends SceneTree

## Behavioral regression for the hero rig's animation graph and the minimap.
##
## The blend graph used to be "active" with an auto-created `output` node that
## was never connected to the Locomotion blend, so the tree evaluated happily
## and drove nothing: the hero stood in a fixed pose with no walk cycle, no
## idle bob and no lantern swing. Checking `parameters/.../blend_amount` (as
## the old coverage did) cannot see that, so these checks sample the actual
## bone transforms the AnimationPlayer writes.

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func _run() -> void:
	var rig: HeroRig = HeroRig.new()
	root.add_child(rig)
	await _frames(2)

	var leg: Node3D = rig.get_node("Model/Hips/LeftLegPivot")
	rig.set_motion(1.0, 0.0)
	var walk_samples := await _sample(leg, "rotation:x", 8)
	_check(_varied(walk_samples), "the walk cycle never moves the leg: %s" % str(walk_samples))

	var walk: Animation = rig._make_walk_animation()
	var hips_track := -1
	for track in range(walk.get_track_count()):
		if walk.track_get_path(track) == NodePath("Model/Hips:position"):
			hips_track = track
	_check(hips_track >= 0, "the walk animation has no hips track")
	if hips_track >= 0:
		_check(walk.track_get_key_count(hips_track) == 5,
			"the walk bob collapsed to %d of its 5 authored keys" % walk.track_get_key_count(hips_track))
	var swing: Animation = rig._make_swing_animation()
	var arm_track := -1
	for track in range(swing.get_track_count()):
		if swing.track_get_path(track) == NodePath("Model/Hips/RightArmPivot:rotation"):
			arm_track = track
	_check(arm_track >= 0, "the swing animation has no arm track")
	if arm_track >= 0:
		_check(swing.track_get_key_count(arm_track) == 4,
			"the lantern swing collapsed to %d of its 4 authored keys" % swing.track_get_key_count(arm_track))

	var arm: Node3D = rig.get_node("Model/Hips/RightArmPivot")
	rig.set_motion(0.0, 1.0)
	var swing_samples := await _sample(arm, "rotation:z", 10)
	_check(_varied(swing_samples), "the lantern swing never moves the arm: %s" % str(swing_samples))

	# Walking back to rest must settle the pose instead of freezing mid-stride.
	rig.set_motion(0.0, 0.0)
	for _frame in range(40):
		await process_frame
	var settled := await _sample(leg, "rotation:x", 4)
	_check(not _varied(settled, 0.02), "the hero never settles after motion stops: %s" % str(settled))

	# Soothing a wisp and levelling up both call set_happy(). That state used to
	# be written and never read, so the celebration the game announced produced
	# no visible reaction at all.
	rig.set_reduced_motion(false)
	var model: Node3D = rig.get_node("Model")
	rig.set_happy(true)
	var happy_samples := await _sample(model, "position:y", 10)
	_check(_varied(happy_samples, 0.005), "the hero never reacted to a happy moment: %s" % str(happy_samples))
	rig.set_happy(false)
	for _frame in range(40):
		await process_frame
	var calm_samples := await _sample(model, "position:y", 4)
	_check(not _varied(calm_samples, 0.005), "the hero never settled after the celebration: %s" % str(calm_samples))
	_check(absf(model.position.y) < 0.01, "the hero stayed lifted after the celebration ended (%f)" % model.position.y)

	# Reduced motion must not freeze the rig outright (it only calms decoration).
	rig.set_reduced_motion(true)
	rig.set_motion(1.0, 0.0)
	var reduced_samples := await _sample(leg, "rotation:x", 6)
	_check(_varied(reduced_samples), "reduced motion froze the walk cycle completely: %s" % str(reduced_samples))

	if _failures > 0:
		root.remove_child(rig)
		rig.free()
		quit(1)
		return

	await _check_minimap_grid_cache()

	print("BEAUTY_FOREST_RIG_OK")
	root.remove_child(rig)
	rig.free()
	await _frames(2)
	quit(0)

func _check_minimap_grid_cache() -> void:
	## The grove grid is static between floors, but the minimap redraws every
	## frame for the moving player dot. Rebuilding every cell as its own
	## draw_rect meant up to 5,184 draw commands per frame for data that never
	## changes, so the static layer is baked once and reused. Headless cannot
	## measure the wall-clock win, so assert the invariant that produces it.
	var dungeon := DungeonGenerator.generate(13)
	var map := CozyMinimap.new()
	root.add_child(map)
	map.size = Vector2(172, 184)
	map.set_map(dungeon, Vector3.ZERO)

	var width := int(dungeon["width"])
	var height := int(dungeon["height"])
	var floor_color := Color(0.57, 0.72, 0.35, 0.72)
	var wall_color := Color(0.16, 0.34, 0.21, 0.88)
	map._ensure_grid_texture(width, height, floor_color, wall_color)
	var first: ImageTexture = map._grid_texture
	_check(first != null, "the minimap did not bake its grove layer")
	if first == null:
		return
	_check(first.get_width() == width and first.get_height() == height,
		"the baked grove layer is %dx%d for a %dx%d grid" % [first.get_width(), first.get_height(), width, height])

	# Redrawing must reuse the same baked layer, not rebuild it per frame.
	map._ensure_grid_texture(width, height, floor_color, wall_color)
	_check(map._grid_texture == first, "the minimap rebuilt its static grove layer instead of reusing it")

	# The baked pixels must still be a real map, not a blank or inverted sheet.
	var image := first.get_image()
	var grid: PackedInt32Array = dungeon["grid"]
	var floor_cells := 0
	var wall_cells := 0
	for z in height:
		for x in width:
			var expected := floor_color if grid[z * width + x] == 1 else wall_color
			# FORMAT_RGBA8 quantizes to 8 bits per channel, so compare with one
			# 8-bit step of tolerance rather than float equality.
			if image.get_pixel(x, z).is_equal_approx(Color(expected.r, expected.g, expected.b, expected.a)) \
					or absf(image.get_pixel(x, z).r - expected.r) <= 1.0 / 255.0 \
					and absf(image.get_pixel(x, z).g - expected.g) <= 1.0 / 255.0 \
					and absf(image.get_pixel(x, z).b - expected.b) <= 1.0 / 255.0:
				if grid[z * width + x] == 1:
					floor_cells += 1
				else:
					wall_cells += 1
	_check(floor_cells > 0 and wall_cells > 0, "the baked grove layer lost its floor/wall detail (%d floor, %d wall cells)" % [floor_cells, wall_cells])

	# A new floor, a resize, or a contrast flip must invalidate the cache.
	map.set_map(DungeonGenerator.generate(2), Vector3.ZERO)
	var floor_two := map.dungeon
	map._ensure_grid_texture(int(floor_two["width"]), int(floor_two["height"]), floor_color, wall_color)
	_check(map._grid_texture != first, "the minimap reused a stale grove layer for a different floor")
	# Two floors that share grid dimensions must still rebake (the generator
	# caps the width, so e.g. floors 9-12 are all the same size).
	map.set_map(DungeonGenerator.generate(10), Vector3.ZERO)
	var floor_ten := map.dungeon
	var before_same_size: ImageTexture = map._grid_texture
	var same_size := int(floor_ten["width"]) == int(floor_two["width"]) and int(floor_ten["height"]) == int(floor_two["height"])
	map._ensure_grid_texture(int(floor_ten["width"]), int(floor_ten["height"]), floor_color, wall_color)
	_check(not same_size or map._grid_texture != before_same_size,
		"the minimap reused one floor's grove layer for another floor of the same size")
	map.set_map(dungeon, Vector3.ZERO)
	map._ensure_grid_texture(width, height, floor_color, wall_color)
	first = map._grid_texture
	map.size = Vector2(96, 108)
	map._ensure_grid_texture(width, height, floor_color, wall_color)
	_check(map._grid_texture != first, "the minimap reused a grove layer baked for a different size")
	map.high_contrast = true
	map._ensure_grid_texture(width, height, Color("#b7cf73"), Color("#304c35"))
	_check(map._grid_texture != null, "the minimap failed to rebake for the high-contrast palette")
	map.high_contrast = false

	root.remove_child(map)
	map.free()

func _sample(node: Node3D, property: String, frames: int) -> Array[float]:
	var samples: Array[float] = []
	var parts := property.split(":")
	for _frame in range(frames):
		await process_frame
		await process_frame
		var value: Variant = node.get(parts[0])
		if value is Vector3:
			samples.append((value as Vector3)[parts[1]])
	return samples

func _varied(samples: Array[float], threshold: float = 0.01) -> bool:
	if samples.size() < 2:
		return false
	var low := samples[0]
	var high := samples[0]
	for value: float in samples:
		low = minf(low, value)
		high = maxf(high, value)
	return high - low > threshold
