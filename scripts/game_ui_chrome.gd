class_name GameUIChrome
extends "res://scripts/game_ui_state.gd"
## Builds the interface once at boot: HUD cards, minimap, modal cards, story
## card, beat ring and the touch controls.

func _build_interface() -> void:
    _root = Control.new()
    _root.name = "Interface"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.theme = Theme.new()
    _root.theme.default_font_size = 18
    add_child(_root)

    _hud = Control.new()
    _hud.name = "HUD"
    _hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_hud)

    # The icon readout, built first so it is the FIRST thing drawn under the
    # play screen. Everything below it is legacy chrome that only appears on
    # screens the player opened deliberately.
    _vitals = CozyVitals.new()
    _vitals.name = "Vitals"
    _vitals.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _vitals.position = Vector2(18, 16)
    _hud.add_child(_vitals)
    _vitals.tooltip_text = "Your lantern's warmth, sparkles, depth and worn charms. Warmth is the ring; it empties as bumps land."

    _minimap = CozyMinimap.new()
    _minimap.position = Vector2(-190, -202)
    _minimap.size = Vector2(172, 184)
    _minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud.add_child(_minimap)

    # The walk-screen control hint used to stand here, and the pause card painted
    # a longer version of the same sentence inside its own card (see
    # _keys_reference). Both were visible at once: "WASD wander · Shift dash · J
    # journal · C comfort options" along the bottom of the world, and "Wander: WASD /
    # arrows / stick · Dash: Shift · Hug, sing & descend: E · Cart: F · Memories:
    # J · Comfort options: C · Pause: Esc" on the card you opened to pause. Fifty-five
    # characters of the smaller one are a strict subset of the larger, so a
    # player who opened the card -- the one who asked for the reference -- read
    # the same controls twice. It lives in _keys_reference now, once.
    #
    # The HUD keeps no prose of its own, which is the rule AGENTS.md states for
    # the walk screen: pictures and digits, and the words live in the pause card
    # the player opens on purpose.

    # Mote's running chatter hangs directly on the scene as bare text, so pale
    # cream lines sat on pale moss and were close to unreadable exactly when
    # something interesting happened. A dark outline lifts the transcript off
    # any background without moving or re-parenting the label, which the
    # touch-aware layout and its regression suite both measure.
    _log_label = _label("", 13, Color("#f4f0d2"))
    _log_label.position = Vector2(20, -152)
    _log_label.custom_minimum_size = Vector2(470, 126)
    _log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    _log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _log_label.add_theme_color_override("font_outline_color", Color(0.06, 0.11, 0.07, 0.92))
    _log_label.add_theme_constant_override("outline_size", 5)
    _hud.add_child(_log_label)

    _toast_label = _label("", 16, Color("#fff2c4"))
    _toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _toast_label.position = Vector2(-290, 96)
    _toast_label.custom_minimum_size = Vector2(580, 54)
    _toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # The toast is the one voice that speaks over a walk; it crosses sunbeams,
    # gold light and pale blossoms, so it wears the same warm-dark outline as
    # the big headings.
    _toast_label.add_theme_color_override("font_outline_color", Color(0.14, 0.10, 0.05, 0.85))
    _toast_label.add_theme_constant_override("outline_size", 4)
    _toast_label.modulate.a = 0.0
    _hud.add_child(_toast_label)

    # Two scrims, not one. The pause card wants the world to step back and
    # stay there; the title menu must NOT crush the forest it is introducing.
    # They used to share one 0.48 rect, which made the menu the darkest
    # screen in a game that measures 173-186 everywhere else.
    _menu_scrim = ColorRect.new()
    _menu_scrim.name = "MenuScrim"
    _menu_scrim.color = Color(0.055, 0.12, 0.08, MENU_SCRIM_ALPHA)
    _menu_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _menu_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    _menu_scrim.visible = false
    _root.add_child(_menu_scrim)
    _overlay_scrim = ColorRect.new()
    _overlay_scrim.color = Color(0.055, 0.12, 0.08, PAUSE_SCRIM_ALPHA)
    _overlay_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay_scrim.visible = false
    _root.add_child(_overlay_scrim)
    _overlay_card = _card(Color(0.12, 0.23, 0.15, 0.96), Color("#ffe29a"), 28, 2)
    _overlay_card.set_anchors_preset(Control.PRESET_CENTER)
    # Anchor offsets are relative to the center preset, so size the card as a
    # fraction of the live viewport: fixed 900x630 clips on small/portrait
    # windows even with canvas_items+expand stretch.
    var viewport_size := get_viewport().get_visible_rect().size
    var card_size := Vector2(minf(900.0, viewport_size.x * 0.94), minf(630.0, viewport_size.y * 0.92))
    _overlay_card.position = -card_size * 0.5
    _overlay_card.size = card_size
    _overlay_card.custom_minimum_size = Vector2(minf(900.0, card_size.x), minf(630.0, card_size.y))
    _overlay_card.visible = false
    _root.add_child(_overlay_card)
    var overlay_margin := _margin(34, 30, 34, 30)
    _overlay_card.add_child(overlay_margin)
    var overlay_scroll := ScrollContainer.new()
    overlay_scroll.name = "OverlayScroll"
    # Rows wrap to the card width (see _refit_content); a sideways scrollbar
    # could only ever be the 12px wrap overflow, and it clipped the menu copy
    # mid-word with a grey bar across the bottom of the panel.
    overlay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    overlay_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    overlay_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    overlay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    overlay_scroll.custom_minimum_size = Vector2.ZERO
    _style_scrollbars(overlay_scroll)
    overlay_margin.add_child(overlay_scroll)
    _overlay_content = VBoxContainer.new()
    _overlay_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # 10 rather than 12: the menu is the tallest screen in the game and every
    # pixel of separation it gives up is a pixel the start button gets back.
    _overlay_content.add_theme_constant_override("separation", 10)
    overlay_scroll.add_child(_overlay_content)

    _shop_scrim = ColorRect.new()
    _shop_scrim.color = Color(0.04, 0.09, 0.06, SHOP_SCRIM_ALPHA)
    _shop_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _shop_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    _shop_scrim.visible = false
    _root.add_child(_shop_scrim)
    _shop_card = _card(Color(0.10, 0.20, 0.13, 0.98), Color("#ffe19a"), 26, 2)
    _shop_card.set_anchors_preset(Control.PRESET_CENTER)
    var shop_viewport := get_viewport().get_visible_rect().size
    var shop_size := Vector2(minf(900.0, shop_viewport.x * 0.94), minf(630.0, shop_viewport.y * 0.92))
    _shop_card.position = -shop_size * 0.5
    _shop_card.custom_minimum_size = Vector2(minf(900.0, shop_size.x), minf(630.0, shop_size.y))
    _shop_card.visible = false
    _root.add_child(_shop_card)
    var shop_margin := _margin(26, 22, 26, 22)
    _shop_card.add_child(shop_margin)
    # The scrolling list hangs DIRECTLY off a VBox under the card, and that VBox
    # fills the card. A ScrollContainer reports a ZERO minimum height on its
    # scrolling axis (that is what lets it scroll), so it can only be given
    # room by SIZE_EXPAND_FILL inside a parent that has spare height to give.
    # The list used to be nested one level deeper, inside a VBox that was
    # itself sized to its own minimum, so the scroll always resolved to zero
    # and the memory book rendered empty.
    _shop_frame = VBoxContainer.new()
    _shop_frame.name = "ShopFrame"
    _shop_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _shop_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _shop_frame.add_theme_constant_override("separation", 10)
    shop_margin.add_child(_shop_frame)
    _shop_scroll = ScrollContainer.new()
    _shop_scroll.name = "ShopScroll"
    _shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _shop_scroll.custom_minimum_size = Vector2.ZERO
    _style_scrollbars(_shop_scroll)
    _shop_frame.add_child(_shop_scroll)
    _shop_content = VBoxContainer.new()
    _shop_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _shop_content.add_theme_constant_override("separation", 10)
    _shop_scroll.add_child(_shop_content)

    _story_card = _card(Color(0.13, 0.24, 0.16, 0.90), Color("#ffe29a"), 20, 2)
    _story_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _story_card.position = Vector2(-300, 150)
    _story_card.size = Vector2(560, 0)
    _story_card.custom_minimum_size = Vector2(560, 0)
    _story_card.visible = false
    _story_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_story_card)
    var story_margin := _margin(24, 18, 24, 18)
    _story_card.add_child(story_margin)
    var story_box := VBoxContainer.new()
    story_margin.add_child(story_box)
    # The vignette's picture: the region's own mark, shown when the story
    # carries one. A floor's opening line lands with its picture, the same
    # way the intro's pages do.
    _story_glyph = TextureRect.new()
    _story_glyph.custom_minimum_size = Vector2(30, 30)
    _story_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _story_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _story_glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _story_glyph.visible = false
    _story_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    story_box.add_child(_story_glyph)
    _story_title = _label("", 22, Color("#ffe69d"))
    _story_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    story_box.add_child(_story_title)
    _story_body = _label("", 15, Color("#fff0c8"))
    _story_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    story_box.add_child(_story_body)

    _beat_ring = Panel.new()
    _beat_ring.custom_minimum_size = Vector2(138, 138)
    _beat_ring.size = Vector2(138, 138)
    _beat_ring.set_anchors_preset(Control.PRESET_CENTER)
    _beat_ring.position = Vector2(-69, -69)
    _beat_ring.visible = false
    _beat_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_beat_ring)
    var ring_style := StyleBoxFlat.new()
    ring_style.bg_color = Color(1, 1, 1, 0.03)
    ring_style.border_color = Color("#ffe17c")
    ring_style.set_border_width_all(7)
    ring_style.set_corner_radius_all(69)
    _beat_ring.add_theme_stylebox_override("panel", ring_style)
    _beat_inner = Panel.new()
    _beat_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _beat_inner.offset_left = 13
    _beat_inner.offset_top = 13
    _beat_inner.offset_right = -13
    _beat_inner.offset_bottom = -13
    _beat_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var inner_style := StyleBoxFlat.new()
    inner_style.bg_color = Color(1, 0.82, 0.30, 0.16)
    inner_style.set_corner_radius_all(54)
    _beat_inner.add_theme_stylebox_override("panel", inner_style)
    _beat_ring.add_child(_beat_inner)

    _warm_flash = ColorRect.new()
    _warm_flash.color = Color(1.0, 0.68, 0.38, 0.0)
    _warm_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _warm_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_warm_flash)
    _build_context_hint()
    _build_intro()
    _build_touch_controls()

## The bottom-centre hint pill: the one piece of prose the walk screen is
## allowed to paint, and only while a press would actually do something.
## "E · Descend" appears when the hero reaches the stair, "E · Peddle's cart"
## at the cart, and so on -- the button hints itself at the moment of use,
## instead of a permanent control line the eye learns to ignore.
func _build_context_hint() -> void:
    _context_hint = PanelContainer.new()
    _context_hint.name = "ContextHint"
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.14, 0.09, 0.88)
    style.border_color = Color("#ffe29a")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    _context_hint.add_theme_stylebox_override("panel", style)
    _context_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _context_label = _label("", 15, Color("#fff2c4"))
    _context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _context_label.add_theme_color_override("font_outline_color", Color(0.06, 0.11, 0.07, 0.9))
    _context_label.add_theme_constant_override("outline_size", 4)
    _context_hint.add_child(_context_label)
    _context_hint.visible = false
    _root.add_child(_context_hint)

## The storybook intro: one page at a time over the still-bright menu forest.
## A tap turns the page, the Skip plate ends the telling; the world behind it
## never stops being the forest the pages are describing.
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
    # Four buttons, not six. CART is gone because E answers it: the action
    # button below IS the context, so standing beside Peddle re-labels it
    # "CART" and a touch press opens the stall -- one button that is always
    # the right one, wherever the hero stands. COMFORT moved into the pause
    # card, which a touch player reaches with the PAUSE button and which
    # already carries the "Comfort options" door; a cluster of six crowded
    # plates taught none of them.
    var use_button := _touch_button("SING ♥", Color("#ffe29a"), Vector2(-280, -180))
    use_button.tooltip_text = "Whatever is near you: hug, sing, wish, or go down. Same as E."
    use_button.pressed.connect(func(): touch_interact_requested.emit())
    touch_root.add_child(use_button)
    _touch_action_button = use_button
    var dash_button := _touch_button("DASH", Color("#a9d9ff"), Vector2(-170, -180))
    dash_button.tooltip_text = "A quick soft hop. Same as Shift."
    dash_button.pressed.connect(func(): touch_dash_requested.emit())
    touch_root.add_child(dash_button)
    var journal_button := _touch_button("BOOK ♥", Color("#c9e7a6"), Vector2(-280, -118))
    journal_button.tooltip_text = "Your memories and stickers. Same as J."
    journal_button.pressed.connect(func(): touch_journal_requested.emit())
    touch_root.add_child(journal_button)

    # A touchscreen has no Escape key and this project maps no back gesture,
    # so without this the buttons above are only half the control set: the
    # player could sing, dash and read but never reach the pause card -- the
    # card that carries the comfort options, the summary and the way home.
    var pause_button := _touch_button("PAUSE", Color("#cfd8e8"), Vector2(-170, -118))
    pause_button.tooltip_text = "Rest a moment. Same as Esc."
    pause_button.pressed.connect(func(): touch_pause_requested.emit())
    touch_root.add_child(pause_button)

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
