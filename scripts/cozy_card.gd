class_name CozyCard
extends Control

## One ware on Peddle's shelf, painted as a picture instead of a sentence.
##
## A card used to be a row of words: an icon, the name, a status line ("in
## pocket -- tap to wear", "swap it in for a verse you're humming", "take for
## sparkles 5") and a price tag, so browsing the cart meant reading a hundred
## labels to find the six things you actually wanted. Everything a card can say
## in words it now says in paint:
##
##   the icon IS the ware
##   the rim is whether you are wearing it (gold) or not (moss)
##   the brightness is whether you can afford it
##   the price is a sparkle and a number -- or a heart, when it is a gift
##
## Two words survive on purpose: the ware's own name, because two wares can
## look alike and a shelf of nameless pictures is a guessing game, and the
## price digits, because no icon says "7". What a ware DOES is in the card's
## tooltip, which the player asks for by hovering -- so browsing stays
## scanning, not reading.

const ICON_SIDE := 46.0
const NAME_SIZE := 13
const PRICE_SIZE := 14

var item: Dictionary = {}
var price := 0
## Wearing this right now. Painted as the gold rim and the lit halo.
var selected := false
## Already yours, so the price is irrelevant and the card must stay live even
## with an empty purse. What the card must NOT paint is a claim to own a free
## verse: those arrive as `free_item`, never as owned.
var owned := false
var free_item := false
## A price you cannot meet. The card dims rather than disappearing, so the
## player can still see what they are saving toward.
var affordable := true
var high_contrast := false

func _ready() -> void:
	custom_minimum_size = Vector2(126.0, 116.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The ware's own name, and the key it is filed under. The regression suites
## read these instead of scraping painted text, so a card can be found without
## the census having to count it.
func item_name() -> String:
	return String(item.get("name", String(item.get("key", ""))))

func item_key() -> String:
	return String(item.get("key", ""))

## Charms, verses and counter-melodies share one key namespace -- `moss` and
## `lullaby` are each in two tables -- so a card asks for its glyph by kind.
## A key with no glyph falls back to Mote's mark rather than a hole.
func glyph_key() -> String:
	var kind := String(item.get("kind", "charm"))
	var key := item_key()
	if kind == "verse":
		return GardenGlyphs.STANZA_PREFIX + key
	if kind == "mote":
		return GardenGlyphs.VERSE_PREFIX + key
	return key if GardenGlyphs.has_glyph(key) else GardenGlyphs.MOTE

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var rim := Color("#ffd257") if selected else (Color("#8abf75") if affordable else Color(1.0, 1.0, 1.0, 0.18))
	var fill := Color(0.20, 0.38, 0.23, 0.96) if selected else Color(0.10, 0.21, 0.13, 0.94)
	if high_contrast:
		fill = fill.darkened(0.45)
	if not affordable:
		fill = Color(0.09, 0.14, 0.11, 0.90)
	draw_style_box(_plate(fill, rim, 14, 3 if selected else 2), rect)

	var icon_center := Vector2(size.x * 0.5, ICON_SIDE * 0.5 + 8.0)
	if selected:
		# The halo is what "you are wearing this" looks like. A ring of light
		# behind the picture reads as lit from within, which no word does.
		_arc(icon_center, ICON_SIDE * 0.62, Color("#ffe08a"), 2.0)
	var glyph := GardenGlyphs.get_glyph(glyph_key())
	var icon_box := Rect2(icon_center - Vector2(ICON_SIDE, ICON_SIDE) * 0.5, Vector2(ICON_SIDE, ICON_SIDE))
	draw_texture_rect(glyph, icon_box, false, Color(1, 1, 1, 1.0 if affordable else 0.45))

	var font := _font()
	var name_tint := Color("#fff0c8") if affordable else Color(1.0, 1.0, 1.0, 0.45)
	draw_string(font, Vector2(6.0, ICON_SIDE + 26.0), item_name(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 12.0, NAME_SIZE, name_tint)
	_draw_price(font)

## What it costs, in the game's own picture: a sparkle and a number for a ware
## with a price, a heart for a free gift. Nothing else -- no "take for", no
## "free gift", no "already yours".
func _draw_price(font: Font) -> void:
	var baseline := size.y - 12.0
	var tint := Color("#ffd257") if affordable else Color(1.0, 1.0, 1.0, 0.40)
	var glyph := GardenGlyphs.get_glyph(GardenGlyphs.HEART if free_item else GardenGlyphs.SPARKLE)
	var glyph_side := 15.0
	var digits := "" if free_item else str(price)
	var digits_width := 0.0
	if not free_item:
		digits_width = font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
	var total := glyph_side + (6.0 + digits_width if not free_item else 0.0)
	var at := Vector2((size.x - total) * 0.5, baseline - glyph_side)
	draw_texture_rect(glyph, Rect2(at, Vector2(glyph_side, glyph_side)), false, tint)
	if not free_item:
		draw_string(font, Vector2(at.x + glyph_side + 6.0, baseline), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE, tint)

func _arc(center: Vector2, radius: float, color: Color, width: float) -> void:
	var steps := 40
	for step in range(steps):
		var angle := TAU * float(step) / float(steps)
		draw_circle(center + Vector2(cos(angle), sin(angle)) * radius, width * 0.5, color)

func _plate(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _font() -> Font:
	return ThemeDB.fallback_font