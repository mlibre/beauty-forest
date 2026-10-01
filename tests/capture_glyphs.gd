extends SceneTree

## Renders every known glyph into one contact sheet so the icon language can be
## eyeballed as a set. Dev tool, not shipped.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var keys: Array[String] = [
		GardenGlyphs.LANTERN, GardenGlyphs.SPARKLE, GardenGlyphs.STAIRS, GardenGlyphs.SOUL,
		GardenGlyphs.MOTE, GardenGlyphs.WISP, GardenGlyphs.HEART, GardenGlyphs.SHIELD,
		GardenGlyphs.CAMP, GardenGlyphs.BOOK, GardenGlyphs.CART, GardenGlyphs.CHIME,
		GardenGlyphs.DRAGON,
	]
	for charm: Dictionary in BeautyContent.CHARMS:
		keys.append(String(charm["key"]))
	for stanza: Dictionary in BeautyContent.STANZAS:
		keys.append(String(stanza["key"]))
	keys.append("mystery_key")

	var columns := 8
	var cell := 72
	var rows := int(ceil(float(keys.size()) / float(columns)))
	var sheet := Image.create(columns * cell, rows * cell, false, Image.FORMAT_RGBA8)
	# A dark green cell background so pale glyph edges are visible.
	sheet.fill(Color("#1d3a28"))
	for index in keys.size():
		var image := GardenGlyphs._render(keys[index], GardenGlyphs.CACHE_SIZE)
		var at := Vector2i((index % columns) * cell + 4, (index / columns) * cell + 4)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, Vector2i(GardenGlyphs.CACHE_SIZE, GardenGlyphs.CACHE_SIZE)), at)
		print("%2d %-14s glyph=%s" % [index, keys[index], "known" if GardenGlyphs.has_glyph(keys[index]) else "PLACEHOLDER"])
	sheet.save_png("res://glyph_sheet.png")
	print("\nwrote res://glyph_sheet.png  (%d glyphs, %dx%d)" % [keys.size(), sheet.get_width(), sheet.get_height()])
	quit(0)
