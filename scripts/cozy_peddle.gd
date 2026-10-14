class_name CozyPeddle
extends Control

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyData := preload("res://scripts/beauty_data.gd")

## Peddle, drawn: the keeper of the cart gets a face in the shop the way the
## stall gets one in the world -- a round glowing body under a little hat,
## eyes that blink, a warmth that breathes. Pure _draw() primitives, so the
## portrait costs no assets and scales with the card it sits in. Reduced
## motion holds the pose: the keeper simply keeps still and keeps smiling.

var _time := 0.0
var _blink_timer := 2.2
var _blink_time := 0.0
var _reduced_motion := false

func _init() -> void:
    custom_minimum_size = Vector2(52, 52)
    size = custom_minimum_size
    tooltip_text = "Peddle -- keeper of the cart, and the forest's most honest prices."
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_reduced_motion(value: bool) -> void:
    _reduced_motion = value
    queue_redraw()

func _process(delta: float) -> void:
    if _reduced_motion:
        return
    _time += delta
    _blink_timer -= delta
    if _blink_timer <= 0.0:
        _blink_timer = randf_range(2.6, 5.4)
        _blink_time = 0.15
    if _blink_time > 0.0:
        _blink_time = maxf(0.0, _blink_time - delta)
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var breathe := 1.0 if _reduced_motion else 1.0 + sin(_time * 1.9) * 0.014
    var r := size.y * 0.30 * breathe
    var blink := 1.0
    if not _reduced_motion and _blink_time > 0.0:
        blink = 0.10 if _blink_time > 0.05 else lerpf(0.10, 1.0, 1.0 - _blink_time / 0.05)
    # The glow the world's Peddle carries: three soft rings behind the body,
    # so the portrait reads as a LIT keeper even on a busy shelf backdrop.
    var glow_colors: Array[Color] = [
        Color(1.0, 0.94, 0.66, 0.05), Color(1.0, 0.94, 0.66, 0.08), Color(1.0, 0.94, 0.66, 0.12),
    ]
    var glow_scales: Array[float] = [1.95, 1.62, 1.34]
    for ring_index in range(3):
        draw_circle(center, r * glow_scales[ring_index], glow_colors[ring_index])
    # The body: warm cream with a lighter pool where the light would sit.
    draw_circle(center, r, Color("#fff0a4"))
    draw_circle(center + Vector2(-r * 0.22, -r * 0.25), r * 0.60, Color(1.0, 0.97, 0.84, 0.55))
    # The hat: a wide brim (a circle flattened by the draw transform) with
    # the cone above it, tipped the same jaunty way the world's hat leans.
    draw_set_transform(center + Vector2(r * 0.02, -r * 0.78), -0.05, Vector2(1.0, 0.30))
    draw_circle(Vector2.ZERO, r * 0.92, Color("#a85e50"))
    draw_set_transform(center + Vector2(0.0, 0.0), 0.0, Vector2.ONE)
    var brim_y := center.y - r * 0.78
    var hat_base := Vector2(center.x - r * 0.52, brim_y + r * 0.02)
    var hat_tip := Vector2(center.x + r * 0.18, brim_y - r * 0.78)
    draw_colored_polygon(PackedVector2Array([
        hat_base, Vector2(center.x + r * 0.56, brim_y + r * 0.02), hat_tip,
    ]), Color("#b8695a"))
    # The face: two dark eyes that blink, rosy cheeks, one small smile arc.
    var eye_r := r * 0.115
    for side in [-1.0, 1.0]:
        var eye_pos := center + Vector2(side * r * 0.34, -r * 0.02)
        draw_set_transform(eye_pos, 0.0, Vector2(1.0, blink))
        draw_circle(Vector2.ZERO, eye_r, Color("#493a2e"))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    for side in [-1.0, 1.0]:
        var cheek_pos := center + Vector2(side * r * 0.58, r * 0.28)
        draw_circle(cheek_pos, r * 0.13, Color(1.0, 0.76, 0.76, 0.45))
    var smile_center := center + Vector2(0.0, r * 0.22)
    draw_arc(smile_center, r * 0.30, PI * 0.18, PI * 0.82, 12, Color("#6b4a3a"), r * 0.055, true)

## Peddle's one line under the heading, tuned to what the cart can see of the
## visit. Every branch answers a state the shelves themselves show -- an empty
## purse, a full lantern, warmth already carried -- so the greeting never
## contradicts the wares it sits above. (Moved here from the panel file: the
## keeper's words belong with the keeper's face.)
static func greeting(sparkles: int, warmth_full: bool, slots_full: bool) -> String:
    if warmth_full and slots_full and sparkles >= 9:
        return "Warm, lantern full, and a purse that still sings — the deeper shelves are watching you."
    if warmth_full and sparkles == 0:
        return "Warm as a toast and not a sparkle to spare — browse anyway. The wares keep."
    if warmth_full:
        return "You look warm as a toast. The shelf glitters a little brighter for it."
    if slots_full:
        return "That lantern is full of light! Wander deeper — the floors below open more room."
    if sparkles == 0:
        return "The purse hums quietly today. The heart-gifts are always free."
    if sparkles >= 12:
        return "A glittering purse! The top shelf is yours to browse."
    return "Welcome back to the cart. Everything is leaf-wrapped and waiting."

## The one ware Peddle would press in the visitor's boots, as plain facts and
## one line of keeper's advice. It is INK, not a second button -- the shelves
## stay the only place a purchase happens, so the pick can never drift out of
## step with a card's own price or afford-state. Tea first when the lantern
## is low, then the cheapest charm the purse can reach, then a free verse,
## then nothing -- a full, happy keeper suggests nothing at all.
static func peddles_pick(state: Dictionary) -> Dictionary:
    var sparkles := int(state.get("sparkles", 0))
    var warmth_full := float(state.get("hp", 0.0)) >= float(state.get("hp_max", 1.0))
    if not warmth_full and BeautyContent.charm_price("tea", 1) <= sparkles:
        return {"kind": "charm", "key": "tea", "tier": 1,
            "line": "Warm tea first — adventures wait, shivers don't."}
    var owned: Array = state.get("owned", [])
    var best_key := ""
    var best_tier := 0
    var best_price := 1 << 30
    for charm: Dictionary in BeautyContent.CHARMS:
        var key := String(charm["key"])
        if key == "tea":
            continue
        var tier := BeautyData.next_tier(owned, key)
        if tier == 0:
            continue
        var price := BeautyContent.charm_price(key, tier)
        if price <= sparkles and price < best_price:
            best_key = key
            best_tier = tier
            best_price = price
    if not best_key.is_empty():
        return {"kind": "charm", "key": best_key, "tier": best_tier,
            "line": "%s would suit the road below — the kindest thing on the shelf for %d sparkles." % [
                BeautyContent.charm_label(best_key, best_tier), best_price]}
    var stanzas: Dictionary = state.get("stanzas", {})
    for stanza: Dictionary in BeautyContent.STANZAS:
        if not bool(stanzas.get(String(stanza["key"]), false)):
            return {"kind": "verse", "key": String(stanza["key"]),
                "line": "A verse costs nothing, and this one hums well at your depth."}
    return {"kind": "", "key": "", "tier": 0, "line": ""}
