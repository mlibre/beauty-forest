class_name CozyCard
extends Control

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const GardenGlyphs := preload("res://scripts/garden_glyphs.gd")
const CozyMaterials := preload("res://scripts/cozy_materials.gd")

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

const ICON_SIDE := 52.0
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
## The purse this card was painted against, or -1 when unknown. While the ware
## is out of reach, the card draws a thin gold line under its price that fills
## with the purse -- "saving toward" as ink, no words needed.
var purse := -1
var high_contrast := false

func _ready() -> void:
        custom_minimum_size = Vector2(138.0, 130.0)
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
        draw_style_box(CozyMaterials.plate(fill, rim, 14, 3 if selected else 2), rect)

        var icon_center := Vector2(size.x * 0.5, ICON_SIDE * 0.5 + 10.0)
        if selected:
                # The halo is what "you are wearing this" looks like. A ring of light
                # behind the picture reads as lit from within, which no word does.
                _arc(icon_center, ICON_SIDE * 0.62, Color("#ffe08a"), 2.2)
        var glyph := GardenGlyphs.get_glyph(glyph_key())
        var icon_box := Rect2(icon_center - Vector2(ICON_SIDE, ICON_SIDE) * 0.5, Vector2(ICON_SIDE, ICON_SIDE))
        draw_texture_rect(glyph, icon_box, false, Color(1, 1, 1, 1.0 if affordable else 0.45))

        var font := _font()
        var name_tint := Color("#fff0c8") if affordable else Color(1.0, 1.0, 1.0, 0.45)
        draw_string(font, Vector2(6.0, ICON_SIDE + 30.0), item_name(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 12.0, NAME_SIZE, name_tint)
        _draw_tier_pips()
        _draw_worn_badge()
        _draw_price(font)

## Which copy of a ware this card offers, as dots -- a charm can be owned
## twice and the second copy is the same ware made stronger. Two pips under
## the name read at a glance where a "(tier 2)" sentence would have been a
## third line of words on every card.
func _draw_tier_pips() -> void:
        var tier := int(item.get("tier", 1))
        if tier <= 1:
                return
        var tint := Color("#ffe08a") if affordable else Color(1.0, 1.0, 1.0, 0.40)
        var span := float(tier) * 10.0 - 4.0
        for pip in range(tier):
                var at := Vector2((size.x - span) * 0.5 + float(pip) * 10.0 + 2.0, ICON_SIDE + 37.0)
                draw_circle(at, 2.2, tint)

## Wearing this right now: a small gold heart pinned to the card's corner.
## The rim and the halo already say it, but a shelf where several cards wear
## gold rims reads faster when "wearing" is also a single mark you can find
## without comparing corners.
func _draw_worn_badge() -> void:
        if not selected:
                return
        var center := Vector2(size.x - 17.0, 17.0)
        draw_circle(center, 10.0, Color("#ffd257"))
        var glyph := GardenGlyphs.get_glyph(GardenGlyphs.HEART)
        draw_texture_rect(glyph, Rect2(center - Vector2(6, 6), Vector2(12, 12)), false, Color("#5c3d2c"))

## What it costs, in the game's own picture: a sparkle and a number for a ware
## with a price, a heart for a free gift -- both resting on a small dark pill
## so the digits stay legible over whatever the shelf draws behind them.
func _draw_price(font: Font) -> void:
        var baseline := size.y - 10.0
        var tint := Color("#ffd257") if affordable else Color(1.0, 1.0, 1.0, 0.40)
        var glyph := GardenGlyphs.get_glyph(GardenGlyphs.HEART if free_item else GardenGlyphs.SPARKLE)
        var glyph_side := 15.0
        var digits := "" if free_item else str(price)
        var digits_width := 0.0
        if not free_item:
                digits_width = font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE).x
        var total := glyph_side + (6.0 + digits_width if not free_item else 0.0)
        var pill := Rect2(Vector2((size.x - total) * 0.5 - 8.0, baseline - glyph_side - 6.0), Vector2(total + 16.0, glyph_side + 10.0))
        draw_style_box(CozyMaterials.plate(Color(0.05, 0.10, 0.07, 0.55), Color(1, 1, 1, 0.10), 8, 1), pill)
        var at := Vector2((size.x - total) * 0.5, baseline - glyph_side)
        draw_texture_rect(glyph, Rect2(at, Vector2(glyph_side, glyph_side)), false, tint)
        if not free_item:
                draw_string(font, Vector2(at.x + glyph_side + 6.0, baseline), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, PRICE_SIZE, tint)
        _draw_saving_line(pill)

## The saving line: a thin gold fill under the price of a ware the purse cannot
## reach yet, its width the fraction of the price already carried. A dimmed
## card says "not yet"; this says how close "yet" is, in the same ink the rim
## and the price already speak. Full or over-full purses draw nothing -- when
## the blocker is not money (warmth, full sockets), a full bar would claim a
## purchase the tap cannot make.
func _draw_saving_line(pill: Rect2) -> void:
        if purse < 0 or free_item or owned or affordable:
                return
        var progress := float(purse) / float(maxi(price, 1))
        if progress >= 1.0 or progress <= 0.0:
                return
        var from := pill.position + Vector2(3.0, pill.size.y - 2.0)
        var span := pill.size.x - 6.0
        draw_line(from + Vector2(span, 0.0), from + Vector2(span * (1.0 - progress), 0.0),
                Color(1.0, 1.0, 1.0, 0.12), 1.6)
        draw_line(from, from + Vector2(span * progress, 0.0), Color(1.0, 0.83, 0.42, 0.9), 1.6)

func _arc(center: Vector2, radius: float, color: Color, width: float) -> void:
        var steps := 40
        for step in range(steps):
                var angle := TAU * float(step) / float(steps)
                draw_circle(center + Vector2(cos(angle), sin(angle)) * radius, width * 0.5, color)

func _font() -> Font:
        return ThemeDB.fallback_font