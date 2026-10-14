class_name GameUIChrome
extends "res://scripts/game_ui_intro.gd"
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
    # The page-turn light: a soft band that crosses the card once as it
    # arrives, the way a turned page catches the lamp. It rides above the
    # card as a sibling (a container would fight the motion) and settles
    # hidden -- one-shot, never a loop.
    _story_sweep = TextureRect.new()
    var sweep_gradient := Gradient.new()
    sweep_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
    sweep_gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1.0, 0.97, 0.86, 0.13), Color(1, 1, 1, 0.0)])
    var sweep_texture := GradientTexture2D.new()
    sweep_texture.gradient = sweep_gradient
    sweep_texture.fill_from = Vector2(0, 0)
    sweep_texture.fill_to = Vector2(1, 0)
    _story_sweep.texture = sweep_texture
    _story_sweep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _story_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _story_sweep.visible = false
    _root.add_child(_story_sweep)
    var story_margin := _margin(24, 18, 24, 18)
    _story_card.add_child(story_margin)
    var story_box := VBoxContainer.new()
    story_margin.add_child(story_box)
    # The vignette's picture: the region's own mark, shown when the story
    # carries one. A floor's opening line lands with its picture, the same
    # way the intro's pages do. The glyph sits on a small stage so the
    # ink-ripple can ring behind it without fighting the card's layout.
    var glyph_stage := Control.new()
    glyph_stage.custom_minimum_size = Vector2(30, 30)
    glyph_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    glyph_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    story_box.add_child(glyph_stage)
    _story_ripple = Panel.new()
    _story_ripple.set_anchors_preset(Control.PRESET_FULL_RECT)
    _story_ripple.offset_left = -10
    _story_ripple.offset_top = -10
    _story_ripple.offset_right = 10
    _story_ripple.offset_bottom = 10
    _story_ripple.pivot_offset = Vector2(25, 25)
    _story_ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _story_ripple.visible = false
    var story_ripple_style := StyleBoxFlat.new()
    story_ripple_style.bg_color = Color(1.0, 0.89, 0.55, 0.10)
    story_ripple_style.border_color = Color("#ffe29a")
    story_ripple_style.set_border_width_all(2)
    story_ripple_style.set_corner_radius_all(25)
    _story_ripple.add_theme_stylebox_override("panel", story_ripple_style)
    glyph_stage.add_child(_story_ripple)
    _story_glyph = TextureRect.new()
    _story_glyph.custom_minimum_size = Vector2(30, 30)
    _story_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _story_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _story_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
    _story_glyph.visible = false
    _story_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glyph_stage.add_child(_story_glyph)
    _story_title = _label("", 22, Color("#ffe69d"))
    _story_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    story_box.add_child(_story_title)
    _story_body = _label("", 15, Color("#fff0c8"))
    _story_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # The body is drawn behind an ink wash: the label lays out its full text
    # every frame (so the card's height never moves) and the shader decides
    # which rows draw. show_story pours the wash; the reveal is draw-space,
    # not layout-space, so the typewriter bug can never return.
    var story_ink := ShaderMaterial.new()
    story_ink.shader = load("res://shaders/ink_reveal.gdshader")
    story_ink.set_shader_parameter("reveal", 1.0)
    _story_body.material = story_ink
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
    _build_cinema()
    _build_context_hint()
    _build_intro()
    _build_touch_controls()

## The cinema: letterbox bars for the walk's staged moments, and the page-turn
## wipe for a descent. Both live above the HUD but below the modal screens;
## both are drawn quiet (no borders, no gloss) so they frame instead of shout.
func _build_cinema() -> void:
    var bar_color := Color(0.05, 0.08, 0.06, 0.88)
    _cinematic_top = ColorRect.new()
    _cinematic_top.name = "CinemaTop"
    _cinematic_top.color = bar_color
    _cinematic_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _cinematic_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _cinematic_top.visible = false
    _root.add_child(_cinematic_top)
    _cinematic_bottom = ColorRect.new()
    _cinematic_bottom.name = "CinemaBottom"
    _cinematic_bottom.color = bar_color
    _cinematic_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _cinematic_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _cinematic_bottom.visible = false
    _root.add_child(_cinematic_bottom)
    _page_wipe = ColorRect.new()
    _page_wipe.name = "PageWipe"
    _page_wipe.color = Color("#fff3cf")
    _page_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _page_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _page_wipe.modulate.a = 0.0
    _root.add_child(_page_wipe)

## The bottom-centre hint pill: the one piece of prose the walk screen is
## allowed to paint, and only while a press would actually do something.
## "E · Descend" appears when the hero reaches the stair, "E · Peddle's cart"
## at the cart, and so on -- the hint offers itself at the moment of use,
## instead of a permanent control line the eye learns to ignore.
##
## The pill is a real button, not a painting: on a touchscreen it IS the
## action (there is no E key there, and the walk screen carries no SING or
## DESCEND plate -- the hint beside the object is the whole control), and on
## the desktop a click on it plays the same move, a small courtesy to the
## mouse. Pressing it speaks through touch_interact_requested, the very
## signal the E key's neighbours already listen to, so the hint and the key
## can never disagree about what happens next.
func _build_context_hint() -> void:
    _context_hint = Button.new()
    _context_hint.name = "ContextHint"
    # A touchscreen makes the pill the action button; on the desktop it stays
    # a hint that happens to answer a click. Either way the press lands in
    # the same place the E key does.
    _hint_tappable = DisplayServer.is_touchscreen_available()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.14, 0.09, 0.88)
    style.border_color = Color("#ffe29a")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    var hover_style := style.duplicate()
    hover_style.bg_color = Color(0.10, 0.19, 0.12, 0.92)
    hover_style.border_color = Color("#fff0b8")
    var pressed_style := style.duplicate()
    pressed_style.bg_color = Color(0.05, 0.10, 0.07, 0.95)
    var focus_style := StyleBoxEmpty.new()
    _context_hint.add_theme_stylebox_override("normal", style)
    _context_hint.add_theme_stylebox_override("hover", hover_style)
    _context_hint.add_theme_stylebox_override("pressed", pressed_style)
    _context_hint.add_theme_stylebox_override("focus", focus_style)
    _context_hint.focus_mode = Control.FOCUS_NONE
    _context_hint.tooltip_text = "Whatever is near you: hug, sing, wish, or go down. Same as E."
    _context_hint.pressed.connect(func(): touch_interact_requested.emit())
    # The pill's face rides the button's own text, so the pill always measures
    # exactly the verb it is speaking — the button sizes to its text, the way
    # the old PanelContainer sized to its label, without a second node to
    # keep fed.
    _context_hint.add_theme_font_size_override("font_size", 15)
    _context_hint.add_theme_color_override("font_color", Color("#fff2c4"))
    _context_hint.add_theme_color_override("font_hover_color", Color("#fff8d8"))
    _context_hint.add_theme_color_override("font_pressed_color", Color("#ffe9a8"))
    _context_hint.add_theme_color_override("font_focus_color", Color("#fff2c4"))
    _context_hint.add_theme_color_override("font_outline_color", Color(0.06, 0.11, 0.07, 0.9))
    _context_hint.add_theme_constant_override("outline_size", 4)
    _context_hint.add_theme_constant_override("h_separation", 0)
    _context_hint.visible = false
    _root.add_child(_context_hint)

## The storybook intro: one page at a time over the still-bright menu forest.
## A tap turns the page, the Skip plate ends the telling; the world behind it
## never stops being the forest the pages are describing.
