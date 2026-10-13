extends SceneTree

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyWisps := preload("res://scripts/beauty_wisps.gd")
const GardenGlyphs := preload("res://scripts/garden_glyphs.gd")

## Every glyph the game can ask for, checked numerically: each one must be
## actually drawn (not the unknown-key placeholder), centred, bright and warm.
## Dev tool, not shipped.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	# (label, key) pairs, namespaced the way the real call sites namespace them.
	var cases: Array = []
	for constant: String in [GardenGlyphs.LANTERN, GardenGlyphs.SPARKLE, GardenGlyphs.STAIRS,
			GardenGlyphs.SOUL, GardenGlyphs.MOTE, GardenGlyphs.WISP, GardenGlyphs.HEART,
			GardenGlyphs.SHIELD, GardenGlyphs.CAMP, GardenGlyphs.BOOK, GardenGlyphs.CART,
			GardenGlyphs.CHIME, GardenGlyphs.DRAGON]:
		cases.append([constant, constant])
	for charm: Dictionary in BeautyContent.CHARMS:
		cases.append([String(charm["key"]), String(charm["key"])])
	for stanza: Dictionary in BeautyContent.STANZAS:
		cases.append([String(stanza["key"]), GardenGlyphs.STANZA_PREFIX + String(stanza["key"])])
	for verse: Dictionary in BeautyContent.MOTE_VERSES:
		cases.append([String(verse["key"]), GardenGlyphs.VERSE_PREFIX + String(verse["key"])])
	for wisp: String in BeautyWisps.WISP_TYPES:
		cases.append([wisp, GardenGlyphs.WISP_PREFIX + wisp])
	# Tiered wares: every tier the shelf sells must carry its own stamped ink.
	# Tier III arrived with the Endless Bloom and its pips were never checked --
	# a worn tier-III charm painting tier-II pips would lie on the hero's chest.
	for charm: Dictionary in BeautyContent.CHARMS:
		if String(charm["key"]) == "tea":
			continue
		for tier in range(2, BeautyContent.TIER_SCALES.size()):
			var worn := GardenGlyphs.worn_key(String(charm["key"]), tier)
			cases.append([worn, worn])
	# The control: an unknown key MUST still paint something visible.
	cases.append(["mystery_key", "mystery_key"])

	print("%-18s %5s %6s %6s %6s %6s %7s  %s" % ["key", "px", "cover%", "cx", "cy", "lum", "sat", "verdict"])
	for entry: Array in cases:
		var label := String(entry[0])
		var key := String(entry[1])
		var unknown := key == "mystery_key"
		var image: Image = GardenGlyphs._render(key, GardenGlyphs.CACHE_SIZE)
		var painted := 0
		var sum := Vector2.ZERO
		var luminance := 0.0
		var saturation := 0.0
		var weight := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a <= 0.02:
					continue
				painted += 1
				sum += Vector2(x, y)
				luminance += (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a
				# HSL saturation: how far the tint sits from grey. A muddy or
				# washed-out icon scores near zero here even when it is bright.
				var high := maxf(c.r, maxf(c.g, c.b))
				var low := minf(c.r, minf(c.g, c.b))
				var lightness := (high + low) * 0.5
				var chroma: float = 0.0 if high == low else (high - low) / (1.0 - absf(2.0 * lightness - 1.0)) if lightness > 0.5 else (high - low) / absf(2.0 * lightness - 1.0)
				saturation += chroma * c.a
				weight += c.a
		var known := GardenGlyphs.has_glyph(key)
		var coverage := 100.0 * float(painted) / float(image.get_width() * image.get_height())
		var center := sum / float(maxi(1, painted))
		var mean_luma := luminance / maxf(1.0, weight)
		var mean_saturation := saturation / maxf(1.0, weight)
		var verdict: Array[String] = []
		if unknown:
			# The control: an unknown key must NOT be claimed as known, and it
			# must still paint a visible placeholder rather than nothing.
			if known:
				verdict.append("UNKNOWN KEY CLAIMED KNOWN")
			if painted < 90:
				verdict.append("PLACEHOLDER INVISIBLE")
		else:
			if not known:
				verdict.append("NO GLYPH (placeholder)")
			if painted < 90:
				verdict.append("TOO EMPTY")
			if coverage > 55.0:
				verdict.append("TOO SOLID")
			if center.x < 12.0 or center.x > 52.0 or center.y < 12.0 or center.y > 52.0:
				verdict.append("OFF-CENTRE")
			# The palette rule that actually matters is VIVIDNESS, not warmth.
			# An earlier version of this check demanded mean(#r - #b) > 0 and
			# failed 13 legitimate glyphs -- the soft cyan Echoes, the Chime, a
			# blue shield rim -- because a genuinely cool icon hue was measured
			# as "not warm". Genshin's own element icons are blue and green, and
			# this game's AGENTS rule is about never going DARK or grim, not
			# about banning a cool tint. What must never happen is a muddy or
			# washed-out icon, so saturation and luminance are the gates.
			#
			# Wisp glyphs are the one exemption: they wear the creature's own
			# colour on purpose, so a Wisp-Pebble really is a stone grey. Their
			# gate is only that they stay bright enough to read.
			var is_wisp := key.begins_with(GardenGlyphs.WISP_PREFIX)
			if not is_wisp and mean_saturation < 0.28:
				verdict.append("MUDDY")
			# Nothing may be dark enough to vanish against the forest floor.
			if mean_luma < 0.32:
				verdict.append("TOO DARK")
		var fail := verdict.size() > 0
		if fail:
			failures += 1
		print("%-18s %5d %6.2f %6.1f %6.1f %6.3f %+7.3f  %s" % [
			label, painted, coverage, center.x, center.y, mean_luma, mean_saturation,
			"OK" if not fail else " ".join(verdict)])
	print("\n%d glyph(s) need attention, of %d checked" % [failures, cases.size()])
	quit(1 if failures > 0 else 0)
