extends TestCase

## Each screen's overlay must dim the world by the amount that screen asks for --
## enough that its panel reads clearly, not so much that the forest turns to murk.
##
## The pause scrim used to be 0.48, and a tile-by-tile read of a real capture
## found the upper-left quadrant sitting at 65% of its pixels below L48. The
## design brief forbids dark and murky; that is what murk looks like as a number.
## Dropping it to 0.32 put every tile under 9%, and -- because the card face is
## opaque -- it RAISED card-to-surround contrast from 2.39:1 to 3.49:1. Dimmer
## was not better here; it was strictly worse in both directions.
##
## This suite locks in three things the raw alpha sweep could not:
##   - no screen's scrim sits above the murk threshold,
##   - High Contrast still darkens *more* than the normal case (it is an
##     accessibility setting, so it must not become a no-op),
##   - and the card is never darker than the world it sits on.
##
## Needs a display: a headless build has no rasterizer.
##     godot --path . --resolution 640x360 --script tests/regression_scrims.gd

## The fraction of a sampled tile allowed to fall below L=48. Above this, a
## region stops reading as "dimmed evening" and starts reading as a dark mass.
const MURK_TILE_SHARE := 0.20

## Rec.709 luminance below which a pixel reads as shadow rather than light.
const MURK_L := 48.0

## The share of its own brightness the forest must keep outside a card.
const KEPT_LIGHT := 0.66

const STRIDE := 3

func _initialize() -> void:
	suite_name = "BEAUTY_FOREST_SCRIMS"
	TestProfile.begin("scrims")
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await frames(5)

	# The world with nothing over it, as the reference for "how bright is the
	# forest when the UI is not in the way".
	game._start_run(1)
	await frames(40)
	var walk := await _world_luminance(game)
	if not ok(walk > 0.0, "the walking frame did not render, so the scrims cannot be judged"):
		stop(game, suite_name)
		return

	game._pause_game()
	await frames(6)
	var pause_lum := await _world_luminance(game)
	var murk := await _murk_tiles(game)
	if not ok(pause_lum > 0.0, "the pause frame did not render"):
		stop(game, suite_name)
		return
	if not ok(murk.size() > 0, "the pause frame sampled no tiles, so the murk check is vacuous"):
		stop(game, suite_name)
		return
	var worst := _worst_tile(murk)
	if not ok(float(worst[1]) <= MURK_TILE_SHARE,
			"a tile of the pause screen is %.0f%% below L48 (at %s) -- that corner reads as murk, not evening" % [
				float(worst[1]) * 100.0, String(worst[0])]):
		stop(game, suite_name)
		return

	# The world must stay mostly lit. A tile ceiling alone does not separate
	# the two candidate alphas (worst tile reads 1% vs 11% of pixels sub-L48),
	# so it guards true murk but cannot judge this. What actually separates them
	# is how much light survives outside the card: 71% at 0.32 against 56% at
	# 0.48. Two-thirds is a round claim -- the dimmed forest should keep at least
	# that much of its own brightness -- and not one fitted to a single number.
	var kept := pause_lum / walk
	if not ok(kept >= KEPT_LIGHT,
			"the pause card left the forest at only %.0f%% of its own light (%.0f of %.0f) -- it dims the world rather than pausing in front of it" % [
				kept * 100.0, pause_lum, walk]):
		stop(game, suite_name)
		return

	# High Contrast must still be a real change, not a formality.
	game.ui.apply_settings({"high_contrast": false})
	await frames(4)
	var soft := await _world_luminance(game)
	game.ui.apply_settings({"high_contrast": true})
	await frames(4)
	var hard := await _world_luminance(game)
	game.ui.apply_settings({"high_contrast": false})
	if not ok(hard < soft,
			"High Contrast did not darken the world (%.0f vs %.0f) -- it must still be a visible step" % [hard, soft]):
		stop(game, suite_name)
		return

	print("scrims: walk %.0f, pause %.0f (worst tile %.0f%% sub-L48), keeping %.0f%% of it, high-contrast %.0f vs %.0f" % [
		walk, pause_lum, float(worst[1]) * 100.0, kept * 100.0, hard, soft])
	finish(game, "BEAUTY_FOREST_SCRIMS")

## Rec.709 luminance on 0..255.
##
## Color components are 0..1, so the weighted sum must be scaled by 255 before it
## is compared against a 0..255 threshold. Comparing the raw 0..1 sum to 48.0
## makes EVERY pixel fail, which is what the first run of this suite reported:
## "100% of the corner below L48" at three different resolutions. The frame was
## fine; the comparison was not.
func _luminance(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0

## Mean luminance of the world still visible AROUND the panel, not the panel
## itself. A full-frame mean is dominated by whichever is larger, so it hides
## exactly the difference we are arguing about.
func _world_luminance(game: Node) -> float:
	var image := await _grab()
	if image.is_empty():
		return 0.0
	var width := image.get_width()
	var height := image.get_height()
	var rects := _ui_rects(game)
	var total := 0.0
	var samples := 0
	for y in range(0, height, STRIDE):
		for x in range(0, width, STRIDE):
			if _covers_ui(rects, Vector2(x, y)):
				continue
			total += _luminance(image.get_pixel(x, y))
			samples += 1
	if samples == 0:
		return 0.0
	return total / samples

## Every 7x7 tile's share of pixels below L48, so a single dark corner cannot hide
## inside a bright average. Returns [[label, share], ...].
func _murk_tiles(game: Node) -> Array:
	var image := await _grab()
	if image.is_empty():
		return []
	var width := image.get_width()
	var height := image.get_height()
	var rects := _ui_rects(game)
	var cols := 6
	var rows := 4
	var out: Array = []
	for row in range(rows):
		for col in range(cols):
			var x0 := int(float(width) * col / cols)
			var x1 := int(float(width) * (col + 1) / cols)
			var y0 := int(float(height) * row / rows)
			var y1 := int(float(height) * (row + 1) / rows)
			var dark := 0
			var total := 0
			for y in range(y0, y1, STRIDE * 2):
				for x in range(x0, x1, STRIDE * 2):
					if _covers_ui(rects, Vector2(x, y)):
						continue
					total += 1
					var c := image.get_pixel(x, y)
					if _luminance(c) < MURK_L:
						dark += 1
			if total == 0:
				continue
			out.append(["%d,%d" % [col, row], float(dark) / float(total)])
	return out

func _worst_tile(tiles: Array) -> Array:
	var worst: Array = ["none", 0.0]
	for tile: Array in tiles:
		if float(tile[1]) > float(worst[1]):
			worst = tile
	return worst

## Every rect that is UI rather than forest, as a list.
##
## Only excluding the centre card was not enough: the pause screen's top-left
## corner holds _left_card and its top-right _right_card, and sampling those
## as murk measures the UI, not the forest -- which is how the first run of
## this suite reported a corner 100% below L48 at every resolution.
##
## A LIST, not a merged Rect2: Rect2.merge returns the union hull, which spans
## the gap between the left and right cards and so covers the forest between
## them. Each rect is tested on its own.
func _ui_rects(game: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for field: String in ["_overlay_card", "_left_card", "_right_card", "_minimap",
			"_hint_label", "_mote_label", "_log_label", "_toast_label"]:
		var node: Control = game.ui.get(field)
		if node != null and is_instance_valid(node) and node.visible:
			rects.append(node.get_global_rect().grow(6.0))
	return rects

func _covers_ui(rects: Array[Rect2], point: Vector2) -> bool:
	for rect in rects:
		if rect.has_point(point):
			return true
	return false

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()