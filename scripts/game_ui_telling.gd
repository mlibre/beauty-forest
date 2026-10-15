class_name GameUITelling
extends "res://scripts/game_ui_screens.gd"

## The interface's storytelling voice: the intro storybook's pages and
## fireflies, the ink wash that pours the prose onto a page, and the page-turn
## wipe. Split out of GameUI when that file outgrew the 500-line ceiling --
## this file is the top chain link between the screens and the concrete
## GameUI, which keeps the HUD updates, toasts, logs and beat ring. All the
## state it drives lives on GameUIState, and every member it touches is
## shared down the chain.

## The ink wash driver, shared by the intro's pages. The
## label is always laid out at full text; the shader only chooses which rows
## draw, so the reveal can never make an autowrap label's minimum size dance
## the way the typewriter did (the battery caught that once already).
func _pour_ink(label: Label, duration: float) -> void:
    if label == null or not is_instance_valid(label):
        return
    var material := label.material as ShaderMaterial
    if material == null or material.shader == null:
        return
    if _ink_tween != null and _ink_tween.is_valid():
        _ink_tween.kill()
    _ink_tween = null
    if _reduced_motion:
        material.set_shader_parameter("reveal", 1.0)
        return
    _ink_label = label
    material.set_shader_parameter("reveal", 0.0)
    var wash := create_tween()
    wash.tween_method(_set_ink_reveal, 0.0, 1.0, maxf(0.1, duration))
    wash.set_trans(Tween.TRANS_SINE)
    wash.set_ease(Tween.EASE_OUT)
    _ink_tween = wash

func _set_ink_reveal(value: float) -> void:
    if _ink_label == null or not is_instance_valid(_ink_label):
        return
    var material := _ink_label.material as ShaderMaterial
    if material != null:
        material.set_shader_parameter("reveal", value)

## The storybook intro, one page at a time. The director owns the pacing and
## the pages; the interface only draws what it is handed — and draws it as a
## little scene: the page's tint re-lights the glow plate and the picture,
## the progress dots mark where the telling is, and the words arrive on a
## short rise so a page turn feels like a page TURN. `close_panels`
## deliberately does NOT touch the intro — the intro lives above the menu
## card, and closing panels is a menu-world operation the director calls
## around it.
func set_intro_page_count(count: int) -> void:
    _intro_page_count = maxi(0, count)
    if _intro_dots == null or not is_instance_valid(_intro_dots):
        return
    while _intro_dots.get_child_count() < _intro_page_count:
        var dot := Panel.new()
        dot.custom_minimum_size = Vector2(9, 9)
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var dot_style := StyleBoxFlat.new()
        dot_style.bg_color = Color(1, 1, 1, 0.22)
        dot_style.set_corner_radius_all(5)
        dot.add_theme_stylebox_override("panel", dot_style)
        _intro_dots.add_child(dot)
    while _intro_dots.get_child_count() > _intro_page_count:
        var child := _intro_dots.get_child(_intro_dots.get_child_count() - 1)
        _intro_dots.remove_child(child)
        child.queue_free()

func show_intro_page(page: Dictionary, page_index: int = 0) -> void:
    if _intro_root == null or not is_instance_valid(_intro_root):
        return
    _menu_scrim.visible = false
    _overlay_card.visible = false
    _overlay_scrim.visible = false
    _hud.visible = false
    _intro_root.visible = true
    var tint := page.get("tint") as Color if page.get("tint") is Color else Color("#ffe9a0")
    _intro_glyph.texture = GardenGlyphs.get_glyph(String(page.get("glyph", GardenGlyphs.MOTE)))
    _intro_title.text = String(page.get("title", ""))
    _intro_body.text = String(page.get("body", ""))
    # The page's light: glow plate, picture and the lit dot all wear this
    # page's color, so each spread of the book reads as its own place.
    if _intro_glow != null and is_instance_valid(_intro_glow):
        var glow_style := _intro_glow.get_theme_stylebox("panel") as StyleBoxFlat
        if glow_style != null:
            glow_style.bg_color = Color(tint.r, tint.g, tint.b, 0.22)
        _intro_glow.queue_redraw()
    _intro_glyph.modulate = tint.lerp(Color.WHITE, 0.35)
    if _intro_dots != null and is_instance_valid(_intro_dots):
        for index in range(_intro_dots.get_child_count()):
            var dot := _intro_dots.get_child(index) as Panel
            if dot == null:
                continue
            var dot_style := dot.get_theme_stylebox("panel") as StyleBoxFlat
            if dot_style == null:
                continue
            var told := _intro_page_count > 0 and index <= page_index
            dot_style.bg_color = Color(tint.r, tint.g, tint.b, 0.95 if index == page_index else 0.40) if told else Color(1, 1, 1, 0.22)
            dot.custom_minimum_size = Vector2(13 if index == page_index else 9, 9)
            dot.queue_redraw()
        _intro_dots.reset_size()
    # The page arrives: the picture blooms, the words rise into place. A
    # page turn is one motion, not three popping parts -- and never two at
    # once, because a fast reader turns pages faster than a bloom finishes.
    if _intro_turn_tween != null and _intro_turn_tween.is_valid():
        _intro_turn_tween.kill()
    _intro_turn_tween = null
    if not _reduced_motion:
        _intro_glyph.pivot_offset = _intro_glyph.custom_minimum_size * 0.5
        _intro_glyph.scale = Vector2(0.82, 0.82)
        _intro_glyph.modulate.a = 0.0
        _intro_title.modulate.a = 0.0
        _intro_body.modulate.a = 0.0
        _intro_turn_tween = create_tween()
        var turn := _intro_turn_tween
        turn.set_parallel(true)
        # The ink-ripple rings once behind the picture, a stamp pressed into
        # the page as it turns.
        if _intro_ripple != null and is_instance_valid(_intro_ripple):
            _intro_ripple.visible = true
            _intro_ripple.modulate.a = 0.8
            _intro_ripple.scale = Vector2(0.62, 0.62)
            turn.tween_property(_intro_ripple, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            turn.tween_property(_intro_ripple, "modulate:a", 0.0, 0.55).set_delay(0.10)
        turn.tween_property(_intro_glyph, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        turn.tween_property(_intro_glyph, "modulate:a", 1.0, 0.24)
        turn.tween_property(_intro_title, "modulate:a", 1.0, 0.26).set_delay(0.08)
        turn.tween_property(_intro_body, "modulate:a", 1.0, 0.26).set_delay(0.16)
        # The prose arrives as an ink wash a beat behind the picture: the
        # page turns, then the words pour onto it.
        _pour_ink(_intro_body, clampf(0.8 + float(String(page.get("body", "")).length()) * 0.012, 0.8, 2.0))
    _animate_intro_fireflies(tint)
    _settle_in(_intro_root)

func hide_intro() -> void:
    if _intro_root != null and is_instance_valid(_intro_root):
        _intro_root.visible = false
        if _intro_ripple != null and is_instance_valid(_intro_ripple):
            _intro_ripple.visible = false
    _stop_intro_fireflies()

## The book's fireflies: each mote walks a small loop around its rest spot,
## a staggered circuit so the plate never looks mechanised. One home for the
## loops, killed on every page turn, so a fast reader never stacks two
## tweens on the same mote.
func _animate_intro_fireflies(tint: Color) -> void:
    _stop_intro_fireflies()
    if _intro_fireflies.is_empty():
        return
    var warm := tint.lerp(Color.WHITE, 0.55)
    for index in range(_intro_fireflies.size()):
        var firefly := _intro_fireflies[index]
        if not is_instance_valid(firefly):
            continue
        var style := firefly.get_theme_stylebox("panel") as StyleBoxFlat
        if style != null:
            style.bg_color = Color(warm.r, warm.g, warm.b, 0.85)
            firefly.queue_redraw()
        if _reduced_motion:
            firefly.modulate.a = 0.5
            continue
        firefly.modulate.a = 0.9
        var home := Vector2(52.0, 52.0) + Vector2(cos(TAU * float(index) / 5.0 + 0.6) * 34.0, sin(TAU * float(index) / 5.0 + 0.6) * 26.0)
        firefly.position = home
        var drift := Vector2(6.0 + float(index), -4.0 + float(index) * 0.5)
        var loop := create_tween()
        loop.tween_property(firefly, "position", home + drift, 1.4 + float(index) * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        loop.tween_property(firefly, "position", home + Vector2(drift.x * -0.6, drift.y * 1.4), 1.2 + float(index) * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        loop.tween_property(firefly, "position", home, 1.5 + float(index) * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        loop.set_loops()
        _intro_firefly_tweens.append(loop)

func _stop_intro_fireflies() -> void:
    for tween in _intro_firefly_tweens:
        if tween != null and tween.is_valid():
            tween.kill()
    _intro_firefly_tweens.clear()

## The page-turn wipe: one wash of ivory light when the walk goes deeper, so
## a floor changes the way a book turns its page instead of snapping. A
## one-shot that always ends transparent and hides itself.
func play_page_wipe() -> void:
    if _page_wipe == null or not is_instance_valid(_page_wipe):
        return
    if _page_wipe_tween != null and _page_wipe_tween.is_valid():
        _page_wipe_tween.kill()
    _page_wipe_tween = null
    if _reduced_motion:
        return
    _page_wipe.modulate.a = 0.0
    var wipe := create_tween()
    wipe.tween_property(_page_wipe, "modulate:a", 0.55, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    wipe.tween_property(_page_wipe, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    wipe.tween_callback(func():
        if is_instance_valid(_page_wipe):
            _page_wipe.modulate.a = 0.0
    )
    _page_wipe_tween = wipe

