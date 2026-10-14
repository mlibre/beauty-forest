class_name GameUIIntro
extends "res://scripts/game_ui_factories.gd"

## The interface's storybook overlay and its touch controls: the intro's
## picture-plate pages with their fireflies and page dots, and the walk
## corner's BOOK / PAUSE plates with the drift joystick. Split out of
## GameUIChrome when that file outgrew the 500-line ceiling -- this file is
## one chain link between the widget factories and the chrome, which keeps
## the identity bands, scrims and cinema bars. Every node name here is
## load-bearing: suites and the page-turn logic walk these trees.

func _build_intro() -> void:
    _intro_root = Control.new()
    _intro_root.name = "StoryIntro"
    _intro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _intro_root.mouse_filter = Control.MOUSE_FILTER_STOP
    _intro_root.visible = false
    _root.add_child(_intro_root)
    var dim := ColorRect.new()
    dim.name = "IntroDim"
    dim.color = Color(0.04, 0.09, 0.06, 0.42)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intro_root.add_child(dim)
    var page := PanelContainer.new()
    page.name = "IntroPage"
    page.add_theme_stylebox_override("panel", _button_style(Color(0.10, 0.20, 0.13, 0.96), Color("#ffe29a"), 24))
    page.set_anchors_preset(Control.PRESET_CENTER)
    page.custom_minimum_size = Vector2(520, 0)
    page.grow_horizontal = Control.GROW_DIRECTION_BOTH
    page.grow_vertical = Control.GROW_DIRECTION_BOTH
    page.mouse_filter = Control.MOUSE_FILTER_STOP
    _intro_root.add_child(page)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    column.custom_minimum_size = Vector2(440, 0)
    var page_margin := _margin(28, 26, 28, 24)
    page.add_child(page_margin)
    page_margin.add_child(column)
    # The page's own little scene: a tinted glow the picture sits in. Each page
    # of the story wears its own color (the dragon's ember, the lantern's gold,
    # the wisps' blue, the promise's rose, the descent's moss), so turning a
    # page changes the light the way a illustrated book changes plates.
    var glow_holder := CenterContainer.new()
    glow_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(glow_holder)
    _intro_glow = Panel.new()
    _intro_glow.custom_minimum_size = Vector2(104, 104)
    _intro_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow_holder.add_child(_intro_glow)
    var glow_style := StyleBoxFlat.new()
    glow_style.bg_color = Color("#ffe9a0", 0.22)
    glow_style.set_corner_radius_all(52)
    _intro_glow.add_theme_stylebox_override("panel", glow_style)
    # The ink-ripple: added before the glyph holder, so it rings BEHIND the
    # picture -- pressed like a stamp with every page turn, then gone.
    _intro_ripple = Panel.new()
    _intro_ripple.set_anchors_preset(Control.PRESET_FULL_RECT)
    _intro_ripple.offset_left = -8
    _intro_ripple.offset_top = -8
    _intro_ripple.offset_right = 8
    _intro_ripple.offset_bottom = 8
    _intro_ripple.pivot_offset = Vector2(60, 60)
    _intro_ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intro_ripple.visible = false
    var intro_ripple_style := StyleBoxFlat.new()
    intro_ripple_style.bg_color = Color(1.0, 0.92, 0.62, 0.10)
    intro_ripple_style.border_color = Color("#ffe9a0")
    intro_ripple_style.set_border_width_all(2)
    intro_ripple_style.set_corner_radius_all(60)
    _intro_ripple.add_theme_stylebox_override("panel", intro_ripple_style)
    _intro_glow.add_child(_intro_ripple)
    # The page's own fireflies: five motes that live inside the glow plate,
    # behind the picture. A storybook's picture is a window -- something is
    # always moving out there. show_intro_page tints them with the page and
    # keeps their loops turning; reduced motion leaves them parked and faint.
    var firefly_holder := Control.new()
    firefly_holder.name = "IntroFireflies"
    firefly_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    firefly_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intro_glow.add_child(firefly_holder)
    for firefly_index in range(5):
        var firefly := Panel.new()
        firefly.custom_minimum_size = Vector2(6, 6)
        firefly.size = Vector2(6, 6)
        firefly.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var firefly_style := StyleBoxFlat.new()
        firefly_style.bg_color = Color(1.0, 0.95, 0.75, 0.85)
        firefly_style.set_corner_radius_all(3)
        firefly.add_theme_stylebox_override("panel", firefly_style)
        # Authored rest positions, spread across the plate; the drift loops
        # move each one a few pixels around its own anchor.
        var rest_angle := TAU * float(firefly_index) / 5.0 + 0.6
        firefly.position = Vector2(52.0, 52.0) + Vector2(cos(rest_angle) * 34.0, sin(rest_angle) * 26.0)
        firefly_holder.add_child(firefly)
        _intro_fireflies.append(firefly)
    var glyph_holder := CenterContainer.new()
    glyph_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glyph_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _intro_glow.add_child(glyph_holder)
    _intro_glyph = TextureRect.new()
    _intro_glyph.custom_minimum_size = Vector2(64, 64)
    _intro_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _intro_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _intro_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glyph_holder.add_child(_intro_glyph)
    _intro_title = _label("", 28, Color("#ffe6a0"))
    _intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_intro_title)
    _intro_body = _label("", 17, Color("#eef3d8"))
    _intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # The prose pours in through the same ink wash the vignette wears: full
    # text laid out from the first frame, rows revealed top-down in draw
    # space. The page never reflows while it tells.
    var intro_ink := ShaderMaterial.new()
    intro_ink.shader = load("res://shaders/ink_reveal.gdshader")
    intro_ink.set_shader_parameter("reveal", 1.0)
    _intro_body.material = intro_ink
    column.add_child(_intro_body)
    column.add_child(_spacer(4))
    # One dot per page: where the telling is, and how much story is left. A
    # row of dots reads without words, which is the intro's whole grammar. The
    # dots themselves are grown by show_intro_page, which learns the page
    # count from the director — the story's length belongs to the story.
    _intro_dots = HBoxContainer.new()
    _intro_dots.alignment = BoxContainer.ALIGNMENT_CENTER
    _intro_dots.add_theme_constant_override("separation", 8)
    _intro_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(_intro_dots)
    column.add_child(_spacer(2))
    _intro_hint = _centered_label("tap to continue  ·  Esc skips", 12, Color("#9fb892"))
    column.add_child(_intro_hint)
    # The one plate on the intro that ends it: bottom-right, honest word.
    var skip := _menu_button("Skip", false, GardenGlyphs.STAIRS)
    skip.custom_minimum_size = Vector2(110, 44)
    skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    skip.position = Vector2(-128, -62)
    skip.tooltip_text = "Straight to the walk."
    skip.pressed.connect(func(): intro_skip_requested.emit())
    _intro_root.add_child(skip)
    _intro_root.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed:
            intro_advance_requested.emit()
    )
    page.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed:
            intro_advance_requested.emit()
    )

func _build_touch_controls() -> void:
    var touch_root := Control.new()
    _touch_root = touch_root
    _touch_buttons.clear()
    touch_root.name = "TouchControls"
    touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    touch_root.visible = DisplayServer.is_touchscreen_available()
    _hud.add_child(touch_root)

    var joystick := TouchJoystick.new()
    _touch_joystick = joystick
    joystick.name = "MoveJoystick"
    joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    joystick.position = Vector2(24, -180)
    joystick.vector_changed.connect(func(value): touch_vector_changed.emit(value))
    touch_root.add_child(joystick)

    # `position` on a bottom-right anchored Control is the top-left offset from
    # that anchor. Keep every row above the bottom edge and to the right of the
    # centered desktop hint; the old positive row offset put OPTIONS (and most
    # of SHOP) off a 1280x720 viewport.
    #
    # The whole cluster lands in the same bottom-right corner the grove map
    # wants, so GameUILayout measures these live rects and moves the map (and
    # the log, under the joystick) out of the way instead of letting the opaque
    # buttons paint over them.
    #
    # One cluster, two plates. The corner keeps BOOK and PAUSE only: every
    # action verb -- sing, wish, descend, hug, the cart -- lives in the golden
    # hint that appears beside the object itself, and that hint IS the button
    # on a touchscreen (tapping it plays the same move the E key would). The
    # DASH is the stick: a quick double-tap is a hop (the pause card's keys
    # line says so). Nothing else ever paints itself onto the walk screen.
    var journal_button := _touch_button("BOOK ♥", Color("#c9e7a6"), Vector2(-280, -118))
    journal_button.tooltip_text = "Your memories and stickers. Same as J."
    journal_button.pressed.connect(func(): touch_journal_requested.emit())
    touch_root.add_child(journal_button)

    # A touchscreen has no Escape key and this project maps no back gesture,
    # so without this the button above is only half the control set: the
    # player could read but never reach the pause card -- the card that
    # carries the comfort options, the summary and the way home.
    var pause_button := _touch_button("PAUSE", Color("#cfd8e8"), Vector2(-170, -118))
    pause_button.tooltip_text = "Rest a moment. Same as Esc."
    pause_button.pressed.connect(func(): touch_pause_requested.emit())
    touch_root.add_child(pause_button)
    # A quick double-tap on the stick is the dash: the thumb never has to
    # leave home to hop, and the corner never grows a DASH plate back.
    joystick.dash_flicked.connect(func(): touch_dash_requested.emit())

func _touch_button(text: String, color: Color, offset: Vector2) -> Button:
    var button := _button(text, true)
    button.custom_minimum_size = Vector2(98, 54)
    button.size = Vector2(98, 54)
    button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    button.position = offset
    button.add_theme_color_override("font_color", color)
    # The labels make several of these wider than the 98px minimum (BOOK ♥
    # measures 109px), so the layout has to read the real rects.
    _touch_buttons.append(button)
    return button
