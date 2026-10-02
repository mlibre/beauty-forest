class_name GameUIChrome
extends GameUIState

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

    var left_card := _card(Color(0.08, 0.17, 0.12, 0.83), Color("#f4d583"), 18)
    _left_card = left_card
    left_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
    left_card.position = Vector2(18, 16)
    left_card.custom_minimum_size = Vector2(315, 0)
    _hud.add_child(left_card)
    var left_margin := _margin(16, 14, 16, 14)
    left_card.add_child(left_margin)
    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 5)
    left_margin.add_child(left)
    left.add_child(_label("YOU & YOUR LANTERN", 12, Color("#ffe39a")))
    _floor_label = _label("Floor 1 — Sunlit Roots", 20, Color("#ffe8a0"))
    left.add_child(_floor_label)
    left.add_child(_spacer(5))
    _health_label = _label("♥ Warmth  100 / 100", 15, Color("#fff2d0"))
    _health_label.tooltip_text = "Warmth is your health. Bumps make it lower. Hearts and rest make it higher."
    left.add_child(_health_label)
    _health_bar = _bar(Color("#f19a8f"), 15)
    left.add_child(_health_bar)
    _level_label = _label("Level 1  ·  0 / 14 soul to next gift", 14, Color("#f7e7b6"))
    _level_label.tooltip_text = "Soul is experience. Soothe wisps and the lantern grows kinder."
    left.add_child(_level_label)
    _xp_bar = _bar(Color("#ffe06f"), 8)
    left.add_child(_xp_bar)
    left.add_child(_spacer(3))
    _stats_label = _label("Song power 10  ·  Dash ready", 14, Color("#dbe8c4"))
    _stats_label.tooltip_text = "Song power is your automatic lullaby strength. No button needed — the lantern sings alone."
    left.add_child(_stats_label)
    _sparkle_label = _label("✦ 0 sparkles to spend", 16, Color("#ffe58c"))
    _sparkle_label.tooltip_text = "Sparkles are gifts from soothed wisps. Spend them at Peddle's cart."
    left.add_child(_sparkle_label)
    _charm_label = _label("Charms 0/3: none yet", 12, Color("#d3e4ba"))
    _charm_label.tooltip_text = "Charms help automatically. Buy them from Peddle, wear up to three."
    _charm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    left.add_child(_charm_label)

    var right_card := _card(Color(0.08, 0.17, 0.12, 0.80), Color("#cfe2a2"), 18)
    _right_card = right_card
    right_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    right_card.position = Vector2(-368, 18)
    right_card.custom_minimum_size = Vector2(350, 0)
    _hud.add_child(right_card)
    var right_margin := _margin(15, 12, 15, 12)
    right_card.add_child(right_margin)
    var right := VBoxContainer.new()
    right.add_theme_constant_override("separation", 5)
    right_margin.add_child(right)
    right.add_child(_label("MOTE SAYS ♥", 13, Color("#ffe59a")))
    _mote_label = _label("“Rest whenever you like. The forest keeps your spot warm.”", 15, Color("#fff1c8"))
    _mote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _mote_label.custom_minimum_size = Vector2(320, 48)
    right.add_child(_mote_label)
    right.add_child(_separator())

    _minimap = CozyMinimap.new()
    _minimap.position = Vector2(-190, -202)
    _minimap.size = Vector2(172, 184)
    _minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud.add_child(_minimap)

    _hint_label = _label("WASD wander  ·  Shift dash  ·  J journal  ·  C cozy options", 14, Color("#fff0bd"))
    _hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _hint_label.position = Vector2(-280, -48)
    _hint_label.custom_minimum_size = Vector2(560, 30)
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hud.add_child(_hint_label)

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
    _build_touch_controls()

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
    var use_button := _touch_button("SING ♥", Color("#ffe29a"), Vector2(-280, -180))
    use_button.tooltip_text = "Hug, sing, and go down stairs. Same as E."
    use_button.pressed.connect(func(): touch_interact_requested.emit())
    touch_root.add_child(use_button)
    var dash_button := _touch_button("DASH", Color("#a9d9ff"), Vector2(-170, -180))
    dash_button.tooltip_text = "A quick cozy hop. Same as Shift."
    dash_button.pressed.connect(func(): touch_dash_requested.emit())
    touch_root.add_child(dash_button)
    var shop_button := _touch_button("CART ♥", Color("#f5b58c"), Vector2(-280, -118))
    shop_button.tooltip_text = "Browse Peddle's cart. Same as F."
    shop_button.pressed.connect(func(): touch_shop_requested.emit())
    touch_root.add_child(shop_button)
    var journal_button := _touch_button("BOOK ♥", Color("#c9e7a6"), Vector2(-170, -118))
    journal_button.tooltip_text = "Your memories and stickers. Same as J."
    journal_button.pressed.connect(func(): touch_journal_requested.emit())
    touch_root.add_child(journal_button)
    var options_button := _touch_button("COZY", Color("#d7c8ff"), Vector2(-280, -56))
    options_button.tooltip_text = "Make things gentler. Same as C."
    options_button.pressed.connect(func(): touch_settings_requested.emit())
    touch_root.add_child(options_button)

    # A touchscreen has no Escape key and this project maps no back gesture,
    # so without this the five buttons above are the whole control set: the
    # player could sing, dash, shop, read and soften the forest but never
    # reach the pause card, the journal summary or the way home.
    var pause_button := _touch_button("PAUSE", Color("#cfd8e8"), Vector2(-170, -56))
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
