extends TestCase

## The game must LOOK bright, not merely render without errors.
##
## The endless-bug-hunt rule that "renders without errors is not proof of correct
## rendering" needs something measurable to check against, and a headless run
## rasterizes nothing. So this suite renders real frames and measures them.
##
## What it caught: the title menu carried the pause card's 0.48 scrim and an
## empty clearing, and measured at a mean luminance of 99 while gameplay measured
## 176. That is the darkest screen in a game whose whole brief is "bright,
## cozy, welcoming -- NEVER dark or murky", and nothing about it was visible
## from a passing test run.
##
## Every threshold here is derived from what the game actually measures now, with
## the design rules setting the floor, not the other way round.
##
## Run this one WITHOUT --headless. A headless build has no rasterizer, so
## RenderingServer.frame_post_draw never fires and the run hangs until the
## timeout -- I measured that the hard way. The other suites are headless-safe;
## this one is not.
##
##     godot --path . --resolution 640x360 --script tests/regression_luminance.gd

## Sample every Nth pixel. The frames are 1280x720 and a stride of 2 still leaves
## 115k samples per frame, far more than the spread between the screens.
const STRIDE := 2

## A walking screen is the bright reference. Measured 173-186.
const WALK_MIN := 140.0

## The title menu is allowed to be softer than the walk -- it has a card over it
## -- but it must not be a different, darker game. Measured 98 after the fix,
## against 81 before it.
const MENU_MIN := 85.0

## How far below gameplay the menu may sit. Measured gap 78 (99 vs 176); the
## gate allows a little more than that.
const MENU_MAX_GAP := 95.0

func _initialize() -> void:
	suite_name = "BEAUTY_FOREST_LUMINANCE"
	TestProfile.begin("luminance")
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await frames(5)

	var menu := await _measure(game)
	if not ok(menu > 0.0, "the menu frame did not render, so it cannot be judged"):
		stop(game, suite_name)
		return
	game._start_run(1)
	await frames(40)
	var walk := await _measure(game)

	if not ok(walk >= WALK_MIN,
			"the walking screen measured %.0f, below the %.0f floor -- the forest is reading dark" % [walk, WALK_MIN]):
		stop(game, suite_name)
		return
	if not ok(menu >= MENU_MIN,
			"the title menu measured %.0f, below the %.0f floor -- the first thing a player sees is dim" % [menu, MENU_MIN]):
		stop(game, suite_name)
		return
	if not ok(walk - menu <= MENU_MAX_GAP,
			"the title menu measures %.0f against gameplay's %.0f, a gap of %.0f" % [walk - menu, walk, menu]):
		stop(game, suite_name)
		return

	print("luminance: menu %.0f, walk %.0f, gap %.0f" % [menu, walk, walk - menu])
	finish(game, "BEAUTY_FOREST_LUMINANCE")

## Mean relative luminance of the current frame, 0-255, or 0.0 if the viewport
## gave nothing back.
##
## `RenderingServer.frame_post_draw` is what makes this work at all: a headless
## `get_image()` before the frame is composited returns an empty texture, which is
## why earlier attempts to measure brightness in a headless run read as black.
func _measure(game: Node) -> float:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return 0.0
	var width := image.get_width()
	var height := image.get_height()
	var total := 0.0
	var samples := 0
	for y in range(0, height, STRIDE):
		for x in range(0, width, STRIDE):
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			samples += 1
	if samples == 0:
		return 0.0
	return total / samples * 255.0