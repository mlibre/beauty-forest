class_name CozyVitals
extends Control

## The play-screen readout, drawn as icons instead of sentences.
##
## Three things are load-bearing and get the whole strip: how warm the lantern
## is, how many sparkles you hold, and how deep you are. Everything the old
## cards spelled out -- level, song power, the charm list, the forecast, Mote's
## running quote and the control hints -- is either shown here as a glyph or
## moved to the pause menu, which is the one screen the player opens on purpose.
##
## Warmth is a ring around a lantern rather than a bar: the arc length is the
## value, so the eye reads proportion without parsing a number.

const RING_RADIUS := 34.0
const RING_THICKNESS := 7.0
const RING_START := -PI * 0.5
const SLOT_SIZE := 30.0
const SLOT_GAP := 5.0

var warmth := 1.0
var sparkles := 0
var floor_number := 1
var equipped: Array[String] = []
var slot_capacity := BeautyContent.MAX_CHARMS
var high_contrast := false
## The lantern glyph reddens and the whole strip tightens its glow as warmth
## falls, so being hurt is legible before you ever read anything.
var _shown_warmth := 1.0
var _sparkle_pop := 0.0
var _last_sparkles := 0
var _time := 0.0
var _reduced_motion := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150.0, 78.0)

func set_values(state: Dictionary) -> void:
	var hp := float(state.get("hp", 100.0))
	var hp_max := maxf(1.0, float(state.get("hp_max", 100.0)))
	warmth = clampf(hp / hp_max, 0.0, 1.0)
	var new_sparkles := int(state.get("sparkles", 0))
	if new_sparkles > _last_sparkles:
		_sparkle_pop = 1.0
	_last_sparkles = new_sparkles
	sparkles = new_sparkles
	floor_number = int(state.get("floor", 1))
	var names: Array = state.get("charm_keys", [])
	equipped.clear()
	for key: String in names:
		equipped.append(key)
	queue_redraw()

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value

func _process(delta: float) -> void:
	_time += delta
	# The ring eases toward the true warmth so a hit reads as a drain rather
	# than a jump, and the sparkle count pops when a heart is collected.
	_shown_warmth = lerpf(_shown_warmth, warmth, 1.0 - exp(-delta * 9.0)) if not _reduced_motion else warmth
	_sparkle_pop = maxf(0.0, _sparkle_pop - delta * 2.2)
	queue_redraw()

func _draw() -> void:
	var backing := Color(0.06, 0.14, 0.09, 0.62) if not high_contrast else Color(0.02, 0.06, 0.04, 0.86)
	draw_style_box(_plate(backing), Rect2(Vector2.ZERO, size))
	_draw_warmth_ring()
	_draw_sparkles()
	_draw_floor()
	_draw_slots()

## Warmth: a lantern glyph in the middle of a ring that empties as you are
## hurt. The arc, not a number, is the readout.
func _draw_warmth_ring() -> void:
	var center := Vector2(44.0, 40.0)
	var radius := RING_RADIUS
	# The track, always full, so the ring's extent reads as a scale.
	_arc(center, radius, RING_START, RING_START + TAU, Color(1, 1, 1, 0.13), RING_THICKNESS)
	var low := _shown_warmth <= 0.34
	# Warm gold when thriving, ember red when nearly out. Never a flat grey.
	var tint := Color("#ff8f6e").lerp(Color("#ffd257"), clampf((_shown_warmth - 0.18) / 0.5, 0.0, 1.0))
	if low and not _reduced_motion:
		# A slow breath on the low-warmth ring, the one motion in the HUD that
		# is allowed to draw the eye.
		tint = tint.lerp(Color("#fff0b0"), (sin(_time * 4.0) * 0.5 + 0.5) * 0.18)
	if _shown_warmth > 0.005:
		_arc(center, radius, RING_START, RING_START + TAU * _shown_warmth, tint, RING_THICKNESS)
	var glyph := GardenGlyphs.get_glyph(GardenGlyphs.LANTERN)
	draw_texture_rect(glyph, Rect2(center - Vector2(19, 19), Vector2(38, 38)), false, tint)

func _draw_sparkles() -> void:
	var center := Vector2(112.0, 26.0)
	var pop := 1.0 + (sin(_sparkle_pop * PI) * 0.28 if not _reduced_motion else 0.0)
	var glyph := GardenGlyphs.get_glyph(GardenGlyphs.SPARKLE)
	var size := 26.0 * pop
	draw_texture_rect(glyph, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false)
	# The count is the one number worth printing: sparkles are a currency, and
	# no icon conveys "17".
	draw_string(_font(), Vector2(126.0, 32.0), str(sparkles), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffe58c"))

## Depth: a stair glyph and the floor, because "how deep am I" is the only
## other number a player tracks.
func _draw_floor() -> void:
	var center := Vector2(112.0, 62.0)
	var glyph := GardenGlyphs.get_glyph(GardenGlyphs.STAIRS)
	draw_texture_rect(glyph, Rect2(center - Vector2(15, 15), Vector2(30, 30)), false)
	draw_string(_font(), Vector2(126.0, 68.0), str(floor_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffe8a0"))

## Charm slots: filled sockets for what you wear, empty outlines for what you
## could still wear. The loadout is readable in a glance without naming it.
func _draw_slots() -> void:
	var origin := Vector2(14.0, 76.0)
	for index in slot_capacity:
		var at := origin + Vector2(float(index) * (SLOT_SIZE + SLOT_GAP), 0.0)
		var rect := Rect2(at, Vector2(SLOT_SIZE, SLOT_SIZE))
		var filled := index < equipped.size()
		var style := _plate(Color(0.10, 0.20, 0.13, 0.80) if not filled else Color(0.22, 0.40, 0.24, 0.92),
			Color("#8abf75") if filled else Color(1, 1, 1, 0.22), 8, 2)
		draw_style_box(style, rect)
		if filled:
			var key := equipped[index]
			# Stanzas and charms share a key namespace, so a worn song is drawn
			# from the song table and a worn charm from the charm table.
			var glyph_key := key
			if BeautyContent.STANZAS.any(func(s: Dictionary) -> bool: return String(s["key"]) == key):
				glyph_key = GardenGlyphs.STANZA_PREFIX + key
			var glyph := GardenGlyphs.get_glyph(glyph_key)
			draw_texture_rect(glyph, rect.grow(-4.0), false)

func _arc(center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, thickness: float) -> void:
	var steps := maxi(8, int(absf(to_angle - from_angle) / 0.12))
	for step in range(steps + 1):
		var angle: float = lerpf(from_angle, to_angle, float(step) / float(steps))
		draw_circle(center + Vector2(cos(angle), sin(angle)) * radius, thickness * 0.5, color)

func _plate(fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 14, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _font() -> Font:
	return ThemeDB.fallback_font
