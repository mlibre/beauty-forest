class_name GardenGlyphs
extends GardenInk

## The game's icon language: one procedurally drawn glyph per concept, so the
## HUD can name a thing without a sentence.
##
## Everything is rasterized into an ImageTexture on first request and cached, so
## a glyph costs one small texture and a `draw_texture_rect`, never a live
## draw loop. Glyphs are keyed by the game's own data (`charm["key"]`,
## `stanza["key"]`) plus a handful of HUD words, so adding a charm without a
## glyph is a visible miss rather than a blank square.

const CACHE_SIZE := 64

## Charm, stanza, verse and wisp keys all live in one flat table, and `moss`
## and `lullaby` are each in two of them. Callers disambiguate with these
## prefixes so a charm is never drawn with a stanza's glyph.
const STANZA_PREFIX := "verse:"
const VERSE_PREFIX := "hum:"
const WISP_PREFIX := "wisp:"

## Concepts that are not wares. Kept as constants so the call sites read as
## the words a designer would say.
const LANTERN := "lantern"
const SPARKLE := "sparkle"
const STAIRS := "stairs"
const SOUL := "soul"
const MOTE := "mote"
const WISP := "wisp"
const HEART := "heart"
const SHIELD := "shield"
const CAMP := "camp"
const BOOK := "book"
const CART := "cart"
const CHIME := "chime"
const DRAGON := "dragon"

static var _cache: Dictionary = {}

## Drops every cached glyph. Called when High Contrast flips, because the
## glyphs bake their palette at raster time.
static func clear_cache() -> void:
	_cache.clear()

static func get_glyph(key: String) -> Texture2D:
	## The cached texture for `key`, or an empty placeholder if the key has no
	## glyph yet. Callers must handle the placeholder: an unknown key is a bug
	## worth showing, not something to hide behind a generic dot.
	var cache_key := "%s@%d" % [key, CACHE_SIZE]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var image := _render(key, CACHE_SIZE)
	var texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture

static func has_glyph(key: String) -> bool:
	# A created Image's data buffer is never empty, so the old guard
	# `not _draw_glyph(...).get_data().is_empty()` reported ink for every key
	# and could not tell the hollow-ring fallback apart from a real glyph.
	return _is_known(key)

static func _is_known(key: String) -> bool:
	if key in [LANTERN, SPARKLE, STAIRS, SOUL, MOTE, WISP, HEART, SHIELD, CAMP, BOOK, CART, CHIME, DRAGON]:
		return true
	# Charm, stanza and verse keys share a namespace, and `moss`/`lullaby`
	# exist in two tables at once, so wares ask with a prefix. An unprefixed
	# key must resolve against the charm table only: letting it claim a
	# stanza or verse of ink let a bare 'petals' paint the hollow gap-ring.
	var bare := key
	if bare.begins_with(VERSE_PREFIX):
		return _verse_glyphs().has(bare.trim_prefix(VERSE_PREFIX))
	if bare.begins_with(STANZA_PREFIX):
		return _stanza_glyphs().has(bare.trim_prefix(STANZA_PREFIX))
	if bare.begins_with(WISP_PREFIX):
		return BeautyContent.WISP_TYPES.has(bare.trim_prefix(WISP_PREFIX))
	for charm: Dictionary in BeautyContent.CHARMS:
		if String(charm["key"]) == bare:
			return true
	return false

# --- palette ---------------------------------------------------------------
# Warm, bright and unmistakably friendly: nothing here is ever dark, grey or
# desaturated, because these glyphs sit on a sunlit forest palette and a muddy
# one would read as damage. The tints below are all nudged toward yellow
# (#r >= #b, green highest) -- a literal sky blue or violet here measured
# visibly colder than the ground it sits on and read as a foreign object.

static func _ink() -> Color:
	return Color("#fff3cf")

static func _gold() -> Color:
	return Color("#ffd257")

static func _leaf() -> Color:
	return Color("#8fd35f")

static func _sky() -> Color:
	return Color("#a8e4e8")

static func _rose() -> Color:
	return Color("#ff9fb6")

static func _plum() -> Color:
	return Color("#eec4f2")

static func _clay() -> Color:
	return Color("#e89a63")

## The faded passes used for the echo/dawn/chime glyphs. These must stay warm
## too: at 40% alpha a cool tint's residual pixels still shifted the whole
## glyph's measured warmth negative.
static func _faint(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

static func _blank_image() -> Image:
	return Image.create(CACHE_SIZE, CACHE_SIZE, false, Image.FORMAT_RGBA8)

static func _render(key: String, size: int) -> Image:
	var image := _blank_image()
	image.fill(Color(0, 0, 0, 0))
	_draw_glyph(image, key, size)
	return image

# --- drawing helpers -------------------------------------------------------
# Every glyph draws inside a 0..1 unit box and is scaled by `s`, so the shapes
# only have to be authored once.

static func _draw_glyph(image: Image, key: String, size: int) -> Image:
	var s := float(size)
	match key:
		LANTERN:
			# A lantern is a frame around a flame, so it must stay an OUTLINE.
			# The glow pass at 1.55x radius flooded the box (68% coverage) and
			# read as a solid blob rather than a lantern.
			_ellipse_ring(image, _at(0.5, 0.60, s), s * 0.21, s * 0.26, _ink(), 3)
			_line(image, _at(0.5, 0.34, s), _at(0.5, 0.42, s), _ink(), 3)
			_arc_cap(image, _at(0.5, 0.34, s), s * 0.13, PI, TAU, _ink(), 3)
			# The flame inside: a small glow, not a fill of the whole body.
			_glow_dot(image, _at(0.5, 0.60, s), s * 0.10, _gold())
		SPARKLE:
			var c := _at(0.5, 0.5, s)
			_star(image, c, s * 0.34, s * 0.11, 4, _gold())
			_star(image, c + Vector2(s * 0.20, -s * 0.22), s * 0.13, s * 0.045, 4, _ink())
		STAIRS:
			for step in 4:
				var base := 0.20 + float(step) * 0.18
				_line(image, _at(0.20, base, s), _at(0.20 + float(step + 1) * 0.15, base, s), _leaf(), 4)
				_line(image, _at(0.20 + float(step + 1) * 0.15, base, s), _at(0.20 + float(step + 1) * 0.15, base - 0.18, s), _leaf(), 4)
		SOUL:
			_star(image, _at(0.5, 0.5, s), s * 0.30, s * 0.13, 5, _plum())
			_ellipse_ring(image, _at(0.5, 0.5, s), s * 0.36, s * 0.36, Color(1, 1, 1, 0.35), 2)
		MOTE:
			_glow_dot(image, _at(0.5, 0.46, s), s * 0.26, _gold())
			_ellipse_ring(image, _at(0.5, 0.62, s), s * 0.20, s * 0.06, _ink(), 3)
			_arc_cap(image, _at(0.5, 0.66, s), s * 0.24, PI, TAU, Color(1, 1, 1, 0.5), 2)
		WISP:
			_ellipse_ring(image, _at(0.5, 0.56, s), s * 0.22, s * 0.26, _sky(), 3)
			_ellipse_ring(image, _at(0.5, 0.30, s), s * 0.13, s * 0.13, _sky(), 3)
			_dot(image, _at(0.42, 0.53, s), s * 0.030, _ink())
			_dot(image, _at(0.58, 0.53, s), s * 0.030, _ink())
		HEART:
			_heart(image, _at(0.5, 0.52, s), s * 0.34, _rose())
		SHIELD:
			_poly(image, PackedVector2Array([
				_at(0.5, 0.18, s), _at(0.80, 0.30, s), _at(0.80, 0.56, s),
				_at(0.5, 0.84, s), _at(0.20, 0.56, s), _at(0.20, 0.30, s),
			]), _sky(), 3, true)
		CAMP:
			_poly(image, PackedVector2Array([
				_at(0.5, 0.20, s), _at(0.82, 0.78, s), _at(0.18, 0.78, s),
			]), _clay(), 3, true)
			_glow_dot(image, _at(0.5, 0.66, s), s * 0.10, _gold())
		BOOK:
			_poly(image, PackedVector2Array([
				_at(0.22, 0.24, s), _at(0.50, 0.30, s), _at(0.78, 0.24, s),
				_at(0.78, 0.76, s), _at(0.50, 0.70, s), _at(0.22, 0.76, s),
			]), _ink(), 3, true)
			_line(image, _at(0.5, 0.30, s), _at(0.5, 0.70, s), _clay(), 2)
		CART:
			_rect(image, _at(0.20, 0.34, s), s * 0.58, s * 0.30, _clay(), true, 3)
			_ellipse_ring(image, _at(0.32, 0.78, s), s * 0.09, s * 0.09, _ink(), 3)
			_ellipse_ring(image, _at(0.68, 0.78, s), s * 0.09, s * 0.09, _ink(), 3)
		CHIME:
			_line(image, _at(0.5, 0.16, s), _at(0.5, 0.52, s), _sky(), 3)
			_ellipse_ring(image, _at(0.5, 0.58, s), s * 0.13, s * 0.13, _sky(), 3)
			_arc_cap(image, _at(0.5, 0.52, s), s * 0.17, 0.0, PI, _sky(), 2)
		DRAGON:
			_ellipse_ring(image, _at(0.5, 0.56, s), s * 0.26, s * 0.22, _leaf(), 3)
			_poly(image, PackedVector2Array([
				_at(0.28, 0.36, s), _at(0.40, 0.18, s), _at(0.50, 0.36, s),
			]), _leaf(), 2, true)
			_poly(image, PackedVector2Array([
				_at(0.50, 0.36, s), _at(0.60, 0.18, s), _at(0.72, 0.36, s),
			]), _leaf(), 2, true)
			_dot(image, _at(0.42, 0.54, s), s * 0.028, _ink())
			_dot(image, _at(0.58, 0.54, s), s * 0.028, _ink())
		"tea":
			_poly(image, PackedVector2Array([
				_at(0.32, 0.30, s), _at(0.68, 0.30, s), _at(0.64, 0.72, s), _at(0.36, 0.72, s),
			]), _clay(), 3, true)
			_arc_cap(image, _at(0.72, 0.44, s), s * 0.11, -PI * 0.5, PI * 0.5, _clay(), 3)
			for wisp_index in 2:
				_arc_cap(image, _at(0.42 + float(wisp_index) * 0.16, 0.20, s), s * 0.06, PI, TAU, Color(1, 1, 1, 0.6), 2)
		"boots":
			_poly(image, PackedVector2Array([
				_at(0.28, 0.24, s), _at(0.46, 0.24, s), _at(0.46, 0.58, s),
				_at(0.76, 0.62, s), _at(0.76, 0.76, s), _at(0.28, 0.76, s),
			]), _leaf(), 3, true)
		"scarf":
			_arc_cap(image, _at(0.5, 0.42, s), s * 0.22, PI, TAU, _rose(), 6)
			_poly(image, PackedVector2Array([
				_at(0.60, 0.50, s), _at(0.76, 0.50, s), _at(0.72, 0.80, s), _at(0.58, 0.78, s),
			]), _rose(), 3, true)
		"echo":
			_arc_cap(image, _at(0.36, 0.52, s), s * 0.14, -PI * 0.5, PI * 0.5, _sky(), 3)
			_arc_cap(image, _at(0.44, 0.52, s), s * 0.24, -PI * 0.5, PI * 0.5, _sky(), 3)
			_arc_cap(image, _at(0.52, 0.52, s), s * 0.34, -PI * 0.5, PI * 0.5, Color(0.56, 0.82, 0.95, 0.6), 2)
		"ember":
			_heart(image, _at(0.5, 0.56, s), s * 0.30, _clay())
			_arc_cap(image, _at(0.5, 0.26, s), s * 0.14, PI, TAU, _gold(), 3)
		"dandelion":
			_line(image, _at(0.5, 0.44, s), _at(0.5, 0.80, s), _leaf(), 3)
			for petal in 8:
				var angle := TAU * float(petal) / 8.0
				var from := _at(0.5, 0.40, s) + Vector2(cos(angle), sin(angle)) * s * 0.12
				# Warm cream, not near-white: a pure white seed head measured
				# 0.25 saturation and read as washed out against the moss.
				_line(image, from, from + Vector2(cos(angle), sin(angle)) * s * 0.13, Color("#ffe9a8"), 2)
		"moss":
			for blob in [[0.36, 0.56], [0.54, 0.50], [0.66, 0.60], [0.46, 0.66]]:
				_glow_dot(image, _at(blob[0], blob[1], s), s * 0.15, _leaf())
		"honey":
			_poly(image, PackedVector2Array([
				_at(0.5, 0.20, s), _at(0.78, 0.44, s), _at(0.5, 0.82, s), _at(0.22, 0.44, s),
			]), _gold(), 3, true)
		"pebble":
			_ellipse_ring(image, _at(0.46, 0.60, s), s * 0.24, s * 0.19, _clay(), 3)
			_arc_cap(image, _at(0.40, 0.52, s), s * 0.10, PI, TAU, Color(1, 1, 1, 0.7), 2)
		"firefly":
			_glow_dot(image, _at(0.40, 0.44, s), s * 0.11, _gold())
			_glow_dot(image, _at(0.62, 0.58, s), s * 0.08, _gold())
			_ellipse_ring(image, _at(0.40, 0.44, s), s * 0.20, s * 0.20, Color(1, 0.9, 0.5, 0.35), 2)
		"socks":
			_arc_cap(image, _at(0.44, 0.40, s), s * 0.18, PI, TAU, _rose(), 5)
			_poly(image, PackedVector2Array([
				_at(0.36, 0.42, s), _at(0.36, 0.68, s), _at(0.62, 0.72, s), _at(0.62, 0.46, s),
			]), _rose(), 3, true)
		"lullaby":
			_arc_cap(image, _at(0.5, 0.44, s), s * 0.20, 0.0, PI, _gold(), 4)
			_dot(image, _at(0.5, 0.60, s), s * 0.05, _ink())
			_line(image, _at(0.5, 0.64, s), _at(0.5, 0.80, s), _ink(), 3)
		"acorn":
			_arc_cap(image, _at(0.5, 0.44, s), s * 0.22, PI, TAU, _clay(), 4)
			_ellipse_ring(image, _at(0.5, 0.60, s), s * 0.14, s * 0.18, _gold(), 3)
		"chorus":
			for note in 3:
				_dot(image, _at(0.28 + float(note) * 0.22, 0.44 + float(note % 2) * 0.16, s), s * 0.075, _plum())
			_arc_cap(image, _at(0.5, 0.72, s), s * 0.26, PI, TAU, Color(0.8, 0.65, 0.95, 0.7), 2)
		"quilt":
			for row in 2:
				for column in 3:
					var tint: Color = [Color(1, 0.75, 0.85), Color(0.75, 0.92, 0.7), Color(0.78, 0.85, 1.0)][(row * 3 + column) % 3]
					_rect(image, _at(0.24 + float(column) * 0.19, 0.30 + float(row) * 0.22, s), s * 0.17, s * 0.20, tint, true, 2)
		"dew":
			_heart(image, _at(0.42, 0.46, s), s * 0.22, _rose())
			_drop(image, _at(0.66, 0.62, s), s * 0.20, _gold())
		_:
			# Wares whose keys collide across tables, and the wisp roster, are
			# drawn by their own tables. Anything left over is a real gap.
			if key.begins_with(STANZA_PREFIX):
				_draw_stanza(image, key.trim_prefix(STANZA_PREFIX), s)
			elif key.begins_with(VERSE_PREFIX):
				_draw_verse(image, key.trim_prefix(VERSE_PREFIX), s)
			elif key.begins_with(WISP_PREFIX):
				_draw_wisp(image, key.trim_prefix(WISP_PREFIX), s)
			else:
				# Unknown key: a hollow ring, so the gap is visible and
				# reportable rather than a blank square nobody notices.
				_ellipse_ring(image, _at(0.5, 0.5, s), s * 0.26, s * 0.26, Color(1, 1, 1, 0.30), 2)
	return image

## Lantern songs. Each one is a note or a motion, so they share a musical
## vocabulary: a head, a stem, and a small flourish that carries the meaning.
static func _draw_stanza(image: Image, key: String, s: float) -> void:
	match key:
		"petals":
			# A note with petals drifting off it.
			_draw_note(image, s, _rose())
			for petal in 3:
				_dot(image, _at(0.66 + float(petal) * 0.06, 0.30 + float(petal) * 0.14, s), s * 0.045, _faint(_rose(), 0.8))
		"echoes":
			# A note plus two trailing echoes.
			_draw_note(image, s, _sky())
			for echo in 2:
				_arc_cap(image, _at(0.30 - float(echo) * 0.16, 0.56, s), s * (0.16 + float(echo) * 0.08), -PI * 0.5, PI * 0.5, _faint(_sky(), 0.7 - float(echo) * 0.25), 2)
		"hearth":
			# A note wrapped in a hearth's arc.
			_draw_note(image, s, _clay())
			_arc_cap(image, _at(0.5, 0.62, s), s * 0.30, PI, TAU, _gold(), 3)
		"dawn":
			# A note under a rising sun.
			_draw_note(image, s, _gold())
			_arc_cap(image, _at(0.5, 0.34, s), s * 0.20, PI, TAU, _ink(), 3)
			_line(image, _at(0.5, 0.14, s), _at(0.5, 0.22, s), _ink(), 2)
		"pollen":
			# A note riding an updraft: three rising motes.
			_draw_note(image, s, _gold())
			for mote in 3:
				_dot(image, _at(0.30 - float(mote) * 0.10, 0.66 - float(mote) * 0.16, s), s * 0.05, _faint(_gold(), 0.85 - float(mote) * 0.2))
		"moss":
			_draw_note(image, s, _leaf())
			for blob in [[0.36, 0.72], [0.54, 0.66], [0.64, 0.76]]:
				_dot(image, _at(blob[0], blob[1], s), s * 0.055, _leaf())
		"lullaby":
			# The longest note: a note with a held trailing bar.
			_draw_note(image, s, _plum())
			_line(image, _at(0.62, 0.60, s), _at(0.84, 0.60, s), _plum(), 3)
			_dot(image, _at(0.84, 0.60, s), s * 0.04, _plum())
		"sunmotes":
			_draw_note(image, s, _gold())
			for mote in 4:
				_dot(image, _at(0.70 + float(mote % 2) * 0.10, 0.36 + float(mote) * 0.11, s), s * 0.04, _faint(_gold(), 0.85))
		"brook":
			# The quickest note: a note over running water.
			_draw_note(image, s, _sky())
			for wave in 2:
				_arc_cap(image, _at(0.44, 0.76 + float(wave) * 0.08, s), s * (0.16 + float(wave) * 0.08), PI, TAU, _faint(_sky(), 0.8 - float(wave) * 0.3), 2)
		"grove":
			# A wider pulse: a note inside concentric rings.
			_draw_note(image, s, _leaf())
			_ellipse_ring(image, _at(0.5, 0.56, s), s * 0.34, s * 0.34, _faint(_leaf(), 0.55), 2)
		_:
			_ellipse_ring(image, _at(0.5, 0.5, s), s * 0.26, s * 0.26, Color(1, 1, 1, 0.30), 2)

## Mote's counter-melodies: a speech-tail note, so the player can tell at a
## glance that this row is Mote talking and not a lantern song.
static func _draw_verse(image: Image, key: String, s: float) -> void:
	match key:
		"":
			# "No Counter-melody" is a real choice, so it gets a real glyph: a
			# quiet note with no tail.
			_draw_note(image, s, _ink())
		"lodestar":
			_draw_note(image, s, _sky())
			_star(image, _at(0.74, 0.30, s), s * 0.10, s * 0.035, 4, _ink())
		"puddlelight":
			_draw_note(image, s, _sky())
			_arc_cap(image, _at(0.5, 0.76, s), s * 0.26, PI, TAU, _faint(_sky(), 0.7), 2)
		"longnote":
			_draw_note(image, s, _plum())
			_line(image, _at(0.60, 0.52, s), _at(0.86, 0.52, s), _plum(), 3)
		"warmheart":
			_draw_note(image, s, _clay())
			_heart(image, _at(0.76, 0.68, s), s * 0.13, _rose())
		"firefly":
			_draw_note(image, s, _gold())
			_glow_dot(image, _at(0.76, 0.32, s), s * 0.06, _gold())
		"softstep":
			_draw_note(image, s, _ink())
			for step in 2:
				_arc_cap(image, _at(0.42 - float(step) * 0.14, 0.80, s), s * (0.12 + float(step) * 0.06), PI, TAU, _faint(_ink(), 0.7 - float(step) * 0.25), 2)
		_:
			_ellipse_ring(image, _at(0.5, 0.5, s), s * 0.26, s * 0.26, Color(1, 1, 1, 0.30), 2)

## The shared music note every song glyph is built on.
static func _draw_note(image: Image, s: float, tint: Color) -> void:
	_ellipse_ring(image, _at(0.42, 0.62, s), s * 0.15, s * 0.11, tint, 3)
	_line(image, _at(0.57, 0.62, s), _at(0.57, 0.24, s), tint, 3)
	_arc_cap(image, _at(0.62, 0.26, s), s * 0.09, PI, PI * 1.5, tint, 3)

## Wisps take their colour straight from the wisp table, so a mark on the map
## and the creature it marks are the same object. Scale and head size carry the
## rest of the type's identity.
static func _draw_wisp(image: Image, key: String, s: float) -> void:
	if not BeautyContent.WISP_TYPES.has(key):
		_ellipse_ring(image, _at(0.5, 0.5, s), s * 0.26, s * 0.26, Color(1, 1, 1, 0.30), 2)
		return
	var data: Dictionary = BeautyContent.WISP_TYPES[key]
	var tint := Color(String(data.get("color", "#ffffff")))
	var body: float = float(data.get("scale", 1.0))
	# Cap the radius below the scale's own maximum: the glow pass stamps at
	# 1.55x this, and a 1.45-scale Warden at the uncapped radius reached 57%
	# coverage -- a filled disc rather than a creature.
	var radius := s * 0.19 * clampf(body, 0.6, 1.15)
	_glow_dot(image, _at(0.5, 0.56, s), radius, tint)
	_dot(image, _at(0.42, 0.52, s), s * 0.026, _ink())
	_dot(image, _at(0.58, 0.52, s), s * 0.026, _ink())
	if bool(data.get("flighty", false)):
		# Wings, for the types that drift.
		for side in [-1.0, 1.0]:
			_arc_cap(image, _at(0.5 + float(side) * radius * 1.3, 0.48, s), radius * 0.7, -PI * 0.5, PI * 0.5, _faint(_gold(), 0.75), 2)
	if bool(data.get("shielder", false)):
		# A shield rim, for the type that holds one.
		_arc_cap(image, _at(0.5, 0.60, s), radius * 1.5, PI, TAU, _faint(_sky(), 0.8), 2)
	if bool(data.get("splits_gently", false)):
		_dot(image, _at(0.76, 0.34, s), radius * 0.5, tint)

## The glyph tables, kept beside the dispatchers that read them so a new song
## has exactly one obvious home.
static func _stanza_glyphs() -> Array[String]:
	return ["petals", "echoes", "hearth", "dawn", "pollen", "moss", "lullaby", "sunmotes", "brook", "grove"]

static func _verse_glyphs() -> Array[String]:
	var keys: Array[String] = [""]
	for verse: Dictionary in BeautyContent.MOTE_VERSES:
		keys.append(String(verse["key"]))
	return keys

# --- primitives ------------------------------------------------------------
# Thin, antialiased-feeling primitives over a normalized box. Each stamps a
# disc of radius `w` along the shape so the result is a smooth thick line, not
# a staircase of hard pixels.
