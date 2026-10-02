class_name GameUIState
extends CanvasLayer

## Signals, widget state and the factories every screen shares. The interface is
## assembled in GameUIChrome, positioned in GameUILayout, filled in
## GameUIScreens and driven by GameUI, which extend this chain.

signal start_requested(style_key: String)
signal resume_requested
signal restart_requested(continue_deeper: bool)
signal quit_requested
signal shop_closed
signal journal_closed
signal settings_open_requested
signal settings_closed
signal buy_requested(charm_key: String)
signal charm_equip_requested(charm_key: String)
signal stanza_equip_requested(stanza_key: String)
signal mote_verse_requested(verse_key: String)
signal touch_vector_changed(value: Vector2)
signal touch_dash_requested
signal touch_interact_requested
signal touch_shop_requested
signal touch_journal_requested
signal touch_settings_requested
signal settings_changed(settings: Dictionary)

var _root: Control
var _hud: Control
var _health_bar: ProgressBar
var _xp_bar: ProgressBar
var _floor_label: Label
var _health_label: Label
var _level_label: Label
var _stats_label: Label
var _sparkle_label: Label
var _charm_label: Label
var _hint_label: Label
var _mote_label: Label
var _log_label: Label
var _toast_label: Label
var _minimap: CozyMinimap
## The icon readout. This is the play screen's whole status display: warmth as
## a ring, sparkles and depth as glyphs, the loadout as sockets.
var _vitals: CozyVitals
var _touch_root: Control
var _touch_joystick: TouchJoystick
## The on-screen touch buttons, kept in build order so the responsive layout
## can measure the block they actually occupy in the bottom-right corner.
var _touch_buttons: Array[Button] = []
## The two text cards the icon HUD replaced. They still exist so the responsive
## layout and its regression suite have something to measure, but they are hidden
## during play -- see set_text_chrome_visible().
var _left_card: PanelContainer
var _right_card: PanelContainer
var _overlay_scrim: ColorRect
var _overlay_card: PanelContainer
var _overlay_content: VBoxContainer
var _shop_scrim: ColorRect
var _shop_card: PanelContainer
var _shop_frame: VBoxContainer
var _shop_scroll: ScrollContainer
var _shop_content: VBoxContainer
var _story_card: PanelContainer
var _story_title: Label
var _story_body: Label
var _beat_ring: Panel
var _beat_inner: Panel
var _warm_flash: ColorRect
var _settings: Dictionary = {}
var _selected_style := "standard"
var _toast_queue: Array[Dictionary] = []
var _toast_active := false
var _toast_tween: Tween
var _story_tween: Tween
var _story_generation := 0
var _reduced_motion := false
var _high_contrast := false
var _text_scale := 1.0
var _compact_hud := false
## The walker's numbers, parked by GameUI.update_hud so the pause menu can show
## the run's full state on demand without the director building a second copy
## of every label.
var _walker_hp := 100
var _walker_hp_max := 100
var _walker_level := 1
var _walker_xp := 0
var _walker_xp_next := 10
var _walker_song := 10
var _walker_floor := 1
var _walker_region := "Sunlit Roots"
var _walker_charms := ""
var _walker_charm_count := 0
var _walker_sparkles := 0
var _walker_forecast := ""
## What the glowing waypoint is actually pointing at, in words. The corner card
## used to read "Wander toward the glowing stair" on every floor, including
## dragon floors where the stairwell is hidden and the marker is over Snoozle --
## so the one screen a player pauses on pointed them at nothing.
var _walker_objective := ""
var _time := 0.0
## Eased HUD bar values. Labels snap instantly so numbers stay exact; the bars
## glide toward them instead of jumping, which softens every bump and heal.
var _health_shown := -1.0
var _xp_shown := -1.0

func _process(delta: float) -> void:
    if _root == null or _overlay_card == null:
        return
    _time += delta
    if not _reduced_motion:
        _beat_ring.pivot_offset = _beat_ring.size * 0.5
        var breath := 1.0 + sin(_time * 1.8) * 0.012
        _overlay_card.scale = Vector2(breath, breath)
        _overlay_card.pivot_offset = _overlay_card.size * 0.5
        # Menus stay alive: the scrim shimmers almost imperceptibly and the
        # story card floats on its own breath. Scale/alpha only — no rect
        # moves, so the responsive layout measurements keep holding.
        if is_instance_valid(_overlay_scrim) and _overlay_scrim.visible:
            _overlay_scrim.modulate = Color(1, 1, 1) * (0.97 + sin(_time * 1.1) * 0.03)
        if is_instance_valid(_story_card) and _story_card.visible:
            var story_breath := 1.0 + sin(_time * 2.1 + 1.3) * 0.008
            _story_card.scale = Vector2(story_breath, story_breath)
            _story_card.pivot_offset = _story_card.size * 0.5
        if is_instance_valid(_shop_card) and _shop_card.visible:
            var shop_breath := 1.0 + sin(_time * 1.6 + 0.6) * 0.006
            _shop_card.scale = Vector2(shop_breath, shop_breath)
            _shop_card.pivot_offset = _shop_card.size * 0.5
    _ease_bar(_health_bar, _health_shown, delta)
    _ease_bar(_xp_bar, _xp_shown, delta)
    if _minimap.is_visible_in_tree():
        _minimap.queue_redraw()

func set_text_chrome_visible(visible_now: bool) -> void:
    # `visible_now` means "SHOW the informational text chrome" (the stat cards,
    # Mote's chatter, the control hints) -- i.e. the player is on a screen they
    # opened deliberately. During the walk this is false and only the vitals
    # ring, the grove map and the beat ring are drawn.
    #
    # This lives on the base class, not on GameUI, because GameUIScreens calls
    # it to restore the cards when a menu opens.
    _vitals.visible = not visible_now
    _left_card.visible = visible_now
    _right_card.visible = visible_now
    _hint_label.visible = visible_now
    _log_label.visible = visible_now
    for optional: Control in [_level_label, _stats_label, _sparkle_label, _charm_label, _mote_label]:
        if is_instance_valid(optional):
            optional.visible = visible_now

func _ease_bar(bar: ProgressBar, target: float, delta: float) -> void:
    if bar == null or not is_instance_valid(bar) or target < 0.0:
        return
    if _reduced_motion or is_equal_approx(bar.value, target):
        bar.value = target
        return
    bar.value = lerpf(bar.value, target, 1.0 - exp(-delta * 10.0))
    if absf(bar.value - target) < 0.05:
        bar.value = target

func set_hud_visible(value: bool) -> void:
    if _hud:
        _hud.visible = value

func set_selected_style(key: String) -> void:
    ## Seeds the menu's trail pick, so a returning visit finds its last trail
    ## already picked. Unknown keys fall back to the standard trail.
    _selected_style = key if BeautyContent.STYLE_DATA.has(key) else "standard"

func _cancel_story() -> void:
    _story_generation += 1
    if _story_tween != null and _story_tween.is_valid():
        _story_tween.kill()
    _story_tween = null
    if _story_card != null:
        _story_card.visible = false

func _reset_touch_joystick() -> void:
    if _touch_joystick != null and is_instance_valid(_touch_joystick):
        _touch_joystick.reset()

func _centered_label(text: String, size: int, color: Color) -> Label:
    var label := _label(text, size, color)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _centered_button(text: String, primary: bool, callback: Callable) -> CenterContainer:
    var center := CenterContainer.new()
    var button := _button(text, primary)
    button.custom_minimum_size = Vector2(360, 48)
    button.pressed.connect(callback)
    center.add_child(button)
    return center

func _focus_control(control: Control) -> void:
    if control == null or not is_instance_valid(control):
        return
    if control is BaseButton and (control as BaseButton).disabled:
        return
    # Deferred: the panel was just built/shown this frame, so an immediate
    # grab can fail before the tree settles. Capture the instance id, NOT the
    # Control itself: a menu rebuild (_clear) can free the old button before
    # this deferred lambda runs, and an Object capture that was freed makes
    # the engine log "Lambda capture at index 0 was freed" *before* any
    # is_instance_valid guard inside the body can run.
    var target_id := control.get_instance_id()
    var grab := func() -> void:
        var target := instance_from_id(target_id) as Control
        if target == null or not is_instance_valid(target):
            return
        if not target.is_inside_tree() or not target.is_visible_in_tree():
            return
        if target is BaseButton and (target as BaseButton).disabled:
            return
        target.grab_focus()
    grab.call_deferred()

func _focus_first_enabled(container: Node) -> void:
    for candidate in container.find_children("*", "", true, false):
        var control := candidate as Control
        if control == null or not is_instance_valid(control):
            continue
        if control.focus_mode == Control.FOCUS_NONE:
            continue
        if control is BaseButton and (control as BaseButton).disabled:
            continue
        _focus_control(control)
        return

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_to_group("game_ui_scaled_labels")
    label.set_meta("base_font_size", size)
    label.add_theme_font_size_override("font_size", int(round(float(size) * _text_scale)))
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0.08, 0.13, 0.08, 0.65))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label

func _button(text: String, primary: bool) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(150, 44)
    button.add_theme_stylebox_override("normal", _button_style(Color(0.49, 0.34, 0.12, 0.95) if primary else Color(0.12, 0.25, 0.16, 0.94), Color("#ffe39a") if primary else Color("#9dbb80"), 14))
    button.add_theme_stylebox_override("hover", _button_style(Color(0.62, 0.44, 0.16, 1.0) if primary else Color(0.18, 0.34, 0.20, 1.0), Color("#fff1bd"), 14))
    button.add_theme_stylebox_override("pressed", _button_style(Color(0.35, 0.25, 0.10, 1.0), Color("#fff0b0"), 14))
    button.add_theme_stylebox_override("focus", _button_style(Color(0.25, 0.42, 0.24, 0.98), Color("#fff4c4"), 14))
    button.add_theme_color_override("font_color", Color("#fff3cc"))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    return button

func _button_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _card(fill: Color, border: Color, radius: int, border_width: int = 2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _button_style(fill, border, radius))
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    return panel

func _scrollbar_style() -> StyleBoxFlat:
    ## A slim warm track instead of the default grey bar, so a menu that still
    ## has to scroll on a short window looks like a deliberate forest panel
    ## rather than a clipped document.
    var track := StyleBoxFlat.new()
    track.bg_color = Color(0.08, 0.16, 0.10, 0.30)
    track.set_corner_radius_all(5)
    track.content_margin_left = 3.0
    track.content_margin_right = 3.0
    return track

func _style_scrollbars(scroll: ScrollContainer) -> void:
    ## Style overrides on a Control are inherited by its children, so these
    ## reach the ScrollContainer's internal VScrollBar.
    var grabber := StyleBoxFlat.new()
    grabber.bg_color = Color("#e0c583")
    grabber.set_corner_radius_all(5)
    grabber.content_margin_left = 3.0
    grabber.content_margin_right = 3.0
    var highlighted := grabber.duplicate() as StyleBoxFlat
    highlighted.bg_color = Color("#f2d99c")
    var pressed := grabber.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#fff0bd")
    var track := _scrollbar_style()
    scroll.add_theme_stylebox_override("scroll", track)
    scroll.add_theme_stylebox_override("scroll_focus", track)
    scroll.add_theme_stylebox_override("grabber", grabber)
    scroll.add_theme_stylebox_override("grabber_highlight", highlighted)
    scroll.add_theme_stylebox_override("grabber_pressed", pressed)

func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", left)
    margin.add_theme_constant_override("margin_top", top)
    margin.add_theme_constant_override("margin_right", right)
    margin.add_theme_constant_override("margin_bottom", bottom)
    return margin

func _bar(color: Color, height: int) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, height)
    bar.max_value = 100
    bar.value = 100
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.03, 0.08, 0.05, 0.85)
    background.set_corner_radius_all(height / 2)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.set_corner_radius_all(height / 2)
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    return bar

func _section_label(text: String) -> Label:
    var label := _label(text, 14, Color("#ffe497"))
    label.add_theme_constant_override("line_spacing", 3)
    return label

func _separator() -> HSeparator:
    var separator := HSeparator.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1, 1, 1, 0.10)
    style.content_margin_top = 2
    style.content_margin_bottom = 2
    separator.add_theme_stylebox_override("separator", style)
    return separator

func _spacer(height: int) -> Control:
    var control := Control.new()
    control.custom_minimum_size = Vector2(0, height)
    return control

func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func apply_settings(settings: Dictionary) -> void:
    _settings = settings.duplicate(true)
    _reduced_motion = bool(_settings.get("reduced_motion", false))
    if _reduced_motion:
        # Freeze the menu breathing at rest so enabling Still Forest never
        # leaves a card parked mid-breath.
        if is_instance_valid(_overlay_card):
            _overlay_card.scale = Vector2.ONE
        if is_instance_valid(_story_card):
            _story_card.scale = Vector2.ONE
        if is_instance_valid(_shop_card):
            _shop_card.scale = Vector2.ONE
        if is_instance_valid(_overlay_scrim):
            _overlay_scrim.modulate = Color.WHITE
    _high_contrast = bool(_settings.get("high_contrast", false))
    _text_scale = clampf(float(_settings.get("text_scale", 1.0)), 0.75, 2.0)
    _root.theme.default_font_size = int(round(18.0 * _text_scale))
    for node in get_tree().get_nodes_in_group("game_ui_scaled_labels"):
        var label := node as Label
        if label == null or not is_instance_valid(label):
            continue
        var base_size := float(label.get_meta("base_font_size", label.get_theme_font_size("font_size")))
        label.add_theme_font_size_override("font_size", int(round(base_size * _text_scale)))
    _minimap.high_contrast = _high_contrast
    _minimap.queue_redraw()
    _overlay_scrim.color = Color(0.025, 0.05, 0.035, 0.72 if _high_contrast else 0.48)
    _shop_scrim.color = Color(0.015, 0.025, 0.018, 0.82 if _high_contrast else 0.64)
    # High Contrast has to reach the text, not just the scenery behind it. The
    # scrim above only darkens the world; the cards carry their own near-opaque
    # fill, so darkening the scrim left every label at the same 13.6:1 in both
    # modes -- a setting named for contrast that changed none of it. Deepen the
    # card fill and firm up the border so the ratio actually moves.
    for card in _contrast_cards():
        var style := card.get_theme_stylebox("panel") as StyleBoxFlat
        if style == null:
            continue
        if not card.has_meta("base_fill"):
            card.set_meta("base_fill", style.bg_color)
            card.set_meta("base_border", style.border_color)
            card.set_meta("base_border_width", style.border_width_top)
        var base: Color = card.get_meta("base_fill")
        var border: Color = card.get_meta("base_border")
        if _high_contrast:
            style.bg_color = Color(base.r * 0.42, base.g * 0.42, base.b * 0.42, minf(1.0, base.a + 0.02))
            style.border_color = Color("#ffe19a")
            style.set_border_width_all(3)
        else:
            style.bg_color = base
            style.border_color = border
            style.set_border_width_all(int(card.get_meta("base_border_width")))

func _contrast_cards() -> Array[PanelContainer]:
    var cards: Array[PanelContainer] = []
    for card: Control in [_shop_card, _story_card, _overlay_card]:
        if card != null and is_instance_valid(card):
            cards.append(card as PanelContainer)
    return cards

func _emit_settings() -> void:
    BeautyData.save_settings(_settings)
    apply_settings(_settings)
    settings_changed.emit(_settings.duplicate(true))
