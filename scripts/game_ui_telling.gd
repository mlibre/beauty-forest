class_name GameUITelling
extends "res://scripts/game_ui_screens.gd"

## The interface's voice: the story vignettes and their ink, the intro
## storybook's pages and fireflies, the ceremony letterboxing and the page
## turn. Split out of GameUI when that file outgrew the 500-line ceiling --
## this file is the top chain link between the screens and the concrete
## GameUI, which keeps the HUD updates, toasts, logs and beat ring. All the
## state it drives lives on GameUIState, and every member it touches is
## shared down the chain.

func show_story(title: String, body: String, duration: float = 3.8, glyph: String = "") -> void:
    _cancel_story()
    var generation := _story_generation
    _story_title.text = title
    _story_body.text = body
    # The vignette's picture, when the story carries one: the region's mark
    # rides above the words, the way the intro's pages are illustrated.
    if _story_glyph != null and is_instance_valid(_story_glyph):
        var has_glyph := not glyph.is_empty()
        _story_glyph.visible = has_glyph
        if has_glyph:
            _story_glyph.texture = GardenGlyphs.get_glyph(glyph)
    _story_card.visible = true
    # The picture changes the card's height, and re-fitting here is a trap
    # the gate already sprung once: a fit that runs before the container's
    # own layout pass measures the words at a stale (or never-laid-out)
    # width and grows the card to 1911px on a 720p window. The next layout
    # pass (resize, panel open, window settle) absorbs the glyph's ~44px;
    # a card briefly 44px proud on a very short window beats one that
    # balloons past the whole screen.
    _story_card.modulate.a = 0.0
    _story_tween = create_tween()
    _story_tween.tween_property(_story_card, "modulate:a", 1.0, 0.35)
    _story_tween.tween_interval(maxf(0.0, duration))
    _story_tween.tween_property(_story_card, "modulate:a", 0.0, 0.55)
    _story_tween.tween_callback(func():
        if generation != _story_generation or not is_instance_valid(_story_card):
            return
        _story_card.visible = false
        _story_tween = null
    )
    _begin_story_arrival()
    # The prose pours in as an ink wash: rows of the already-laid-out label
    # draw top-down, so the vignette reads as something being WRITTEN while
    # the card holds still underneath it.
    _pour_ink(_story_body, clampf(0.9 + float(body.length()) * 0.010, 0.9, 1.8))

## The ink wash driver, shared by the vignette and the intro's pages. The
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

## The vignette's arrival, staged like a book plate: the card settles the last
## few pixels into place and breathes a 1.5% scale into rest, a band of
## lamplight crosses it once, and the picture's mark rings like pressed ink
## while the title and body land on a short stagger. Every part is one-shot
## and settles -- nothing on the card loops, breathes or drifts, so the
## interface's stillness rules hold. Reduced motion keeps only the plain
## fade.
##
## Deliberately NO typewriter: animating visible_ratio on an autowrap label
## makes its minimum size dance while it types (zero visible glyphs report a
## zero-width longest word, and the card's height follows it up to 1945px --
## the battery caught exactly that). Scale, position and alpha never touch
## layout, so those are the only channels the arrival animates.
func _begin_story_arrival() -> void:
    if _story_arrival_tween != null and _story_arrival_tween.is_valid():
        _story_arrival_tween.kill()
    _story_arrival_tween = null
    var ripple := _story_ripple
    var ripple_shown := ripple != null and is_instance_valid(ripple) and \
        _story_glyph != null and is_instance_valid(_story_glyph) and _story_glyph.visible
    if ripple != null and is_instance_valid(ripple):
        ripple.visible = ripple_shown
        if ripple_shown:
            ripple.modulate.a = 0.9
            ripple.scale = Vector2(0.55, 0.55)
    var sweep := _story_sweep
    if sweep != null and is_instance_valid(sweep):
        sweep.visible = false
    if _reduced_motion:
        if _story_card != null and is_instance_valid(_story_card):
            _story_card.scale = Vector2.ONE
            _story_card.pivot_offset = _story_card.size * 0.5
        if ripple != null and is_instance_valid(ripple):
            ripple.visible = false
        return
    var tween := create_tween()
    tween.set_parallel(true)
    # The settle: the card breathes a 1.5% scale into rest from its top
    # edge. Deliberately no position rise: a container-housed panel moved
    # before its first sort shapes its autowrap body at width 1 and stays
    # there (1911px), and a rise cancelled mid-flight bakes its half-risen y
    # as the next telling's rest -- the card walked up the screen one
    # overlapped vignette at a time. Scale always tweens back to ONE, so a
    # cancelled settle self-corrects on the next show.
    _story_card.pivot_offset = _story_card.size * Vector2(0.5, 0.0)
    _story_card.scale = Vector2(0.985, 0.985)
    tween.tween_property(_story_card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if ripple_shown:
        tween.tween_property(ripple, "scale", Vector2.ONE, 0.50).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(ripple, "modulate:a", 0.0, 0.50).set_delay(0.08)
    # The lamp band crosses once, then the card is still.
    if sweep != null and is_instance_valid(sweep):
        sweep.size = Vector2(_story_card.size.x * 0.42, maxf(0.0, _story_card.size.y - 8.0))
        sweep.position = Vector2(_story_card.position.x - sweep.size.x, _story_card.position.y + 4.0)
        sweep.visible = true
        sweep.modulate.a = 0.0
        tween.tween_property(sweep, "modulate:a", 1.0, 0.12).set_delay(0.12)
        tween.tween_property(sweep, "position:x", _story_card.position.x + _story_card.size.x, 0.62).set_delay(0.12)
        tween.tween_property(sweep, "modulate:a", 0.0, 0.20).set_delay(0.54)
        tween.chain().tween_callback(func():
            if is_instance_valid(sweep):
                sweep.visible = false
        )
    _story_arrival_tween = tween

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

## The cinema: letterbox bars that frame the song ceremonies while they play
## and leave when the song ends. The walk's biggest moments stage themselves
## instead of arriving as prose over the normal HUD.
func set_cinematic(on: bool, owner_tag: String = "") -> void:
    if _cinematic_top == null or _cinematic_bottom == null or not is_instance_valid(_cinematic_top):
        return
    if _cinematic_tween != null and _cinematic_tween.is_valid():
        _cinematic_tween.kill()
    _cinematic_tween = null
    _cinematic_on = on
    _cinematic_owner = owner_tag if on else ""
    if not on:
        _cinematic_top.visible = false
        _cinematic_bottom.visible = false
        return
    var bar_height := _root.size.y * 0.085
    _cinematic_top.visible = true
    _cinematic_bottom.visible = true
    if _reduced_motion:
        _cinematic_top.offset_bottom = bar_height
        _cinematic_bottom.offset_top = -bar_height
        return
    _cinematic_top.offset_bottom = 0.0
    _cinematic_bottom.offset_top = 0.0
    _cinematic_tween = create_tween()
    _cinematic_tween.set_parallel(true)
    _cinematic_tween.tween_property(_cinematic_top, "offset_bottom", bar_height, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _cinematic_tween.tween_property(_cinematic_bottom, "offset_top", -bar_height, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The floor's opening scene, staged like film: the letterbox slides in, the
## floor's page arrives with its ink and its mark, and then the story KEEPS
## PLAYING across its next two shots -- cut, line, cut, line -- the way a
## film carries a scene past its first frame. Nothing pauses and nothing
## blocks: the walk stays live underneath the whole time, exactly like a
## movie's dialogue over a living shot. A newer floor (or Still Forest)
## cancels the rest through the generation, and a ceremony that claims the
## letterbox mid-scene is left alone: the prologue only lowers bars it
## still owns.
var _prologue_generation := 0

## One beat of the prologue's clock, as a tween owned by THIS node. A bare
## SceneTreeTimer outlives the interface -- if the floor (or the whole game)
## tears down mid-scene, its timeout would resume this coroutine on a freed
## instance; a node-bound tween is killed with the node, so the scene just
## quietly never speaks again.
func _prologue_wait(seconds: float) -> void:
    var beat := create_tween()
    beat.tween_interval(seconds)
    await beat.finished

func play_floor_prologue(story: Array, shots: Array, glyph: String) -> void:
    _prologue_generation += 1
    var generation := _prologue_generation
    if story.is_empty():
        return
    var title := String(story[0])
    var body := String(story[1])
    if _reduced_motion:
        # Still Forest: one page, no cinema. The story arrives exactly as it
        # always did; the shots stay in the telling for readers who seek it.
        show_story(title, body, 3.8, glyph)
        return
    set_cinematic(true, "prologue")
    show_story(title, body, 5.0, glyph)
    for shot: String in shots:
        await _prologue_wait(3.1)
        if generation != _prologue_generation or not is_inside_tree():
            return
        if _cinematic_owner != "prologue":
            # A ceremony claimed the cinema mid-scene: the story stops cutting
            # and leaves the stage -- and the bars -- to the ceremony, whose
            # own card (and exit) now owns the moment.
            return
        # The cut: the previous card is cancelled mid-hold and the next shot
        # arrives with the same ink and mark, so the scene reads as one story
        # speaking in frames rather than three cards queueing.
        show_story(title, shot, 5.0, glyph)
    await _prologue_wait(3.3)
    if generation != _prologue_generation or not is_inside_tree():
        return
    if _cinematic_owner == "prologue":
        set_cinematic(false, "prologue")

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

