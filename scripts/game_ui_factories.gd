class_name GameUIFactories
extends "res://scripts/game_ui_state.gd"

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.

## The interface's widget factory: the label, icon, button, card, margin and
## scrollbar builders every screen shares, plus the focus helpers. Split out
## of GameUIState so the base class stays about signals, state and settings
## while the "how a widget looks" half lives in one file. The chain reads:
## state (what the interface knows) -> factories (what a widget looks like)
## -> chrome (what gets built once) -> layout (where it goes).

func _centered_label(text: String, size: int, color: Color) -> Label:
    var label := _label(text, size, color)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if size >= 24:
        # Big headings sit over a bright, sunlit 3D forest; without a warm-dark
        # outline they wash out against the sky and the gold lantern light.
        label.add_theme_color_override("font_outline_color", Color(0.14, 0.10, 0.05, 0.85))
        label.add_theme_constant_override("outline_size", maxi(4, size / 6))
    return label

func _centered_button(text: String, primary: bool, callback: Callable) -> CenterContainer:
    var center := CenterContainer.new()
    var button := _button(text, primary)
    button.custom_minimum_size = Vector2(320, 48)
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
    if size >= 24:
        # Headings wear the storybook face; 24px is also where the warm-dark
        # outline starts, so picture and protection arrive together.
        label.theme_type_variation = "HeadingLabel"
    label.add_theme_font_size_override("font_size", int(round(float(size) * _text_scale)))
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0.08, 0.13, 0.08, 0.65))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label

## One glyph from the game's own icon language, sized in px and tinted.
##
## The building block of "show, don't tell": a heading that names a thing can
## carry that thing's picture next to the words, and a number can carry the
## picture of what it counts. An unknown key falls back to Mote's mark rather
## than a blank square, so a missing glyph is visible and worth a bug report.
func _icon(glyph_key: String, side: float, tint: Color = Color.WHITE) -> TextureRect:
    var resolved := glyph_key if GardenGlyphs.has_glyph(glyph_key) else GardenGlyphs.MOTE
    var icon := TextureRect.new()
    # Name the node after the picture it shows. The picture is the whole point
    # of an icon row, so a test asking "does this row show a lantern?" needs to
    # be able to tell one icon from another -- and an unnamed TextureRect is
    # indistinguishable from any other in a tree walk.
    icon.name = resolved
    icon.texture = GardenGlyphs.get_glyph(resolved)
    icon.custom_minimum_size = Vector2(side, side)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    icon.modulate = tint
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return icon

## An icon that centres itself inside a full-width row — the vertical-stack
## sibling of _icon, for plates that lead with a picture over a name.
func _centered_icon(glyph_key: String, side: float, tint: Color = Color.WHITE) -> TextureRect:
    var icon := _icon(glyph_key, side, tint)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    return icon

func _button(text: String, primary: bool) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(150, 46)
    var radius := 16
    button.add_theme_stylebox_override("normal", _button_style(Color(0.49, 0.34, 0.12, 0.95) if primary else Color(0.12, 0.25, 0.16, 0.94), Color("#ffe39a") if primary else Color("#9dbb80"), radius))
    button.add_theme_stylebox_override("hover", _button_style(Color(0.62, 0.44, 0.16, 1.0) if primary else Color(0.18, 0.34, 0.20, 1.0), Color("#fff1bd"), radius))
    button.add_theme_stylebox_override("pressed", _button_style(Color(0.35, 0.25, 0.10, 1.0), Color("#fff0b0"), radius))
    button.add_theme_stylebox_override("focus", _button_style(Color(0.25, 0.42, 0.24, 0.98), Color("#fff4c4"), radius))
    button.add_theme_stylebox_override("disabled", _button_style(Color(0.16, 0.24, 0.17, 0.82), Color("#8fa27c"), radius))
    button.add_theme_color_override("font_color", Color("#fff3cc"))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", Color("#c6d2b4"))
    if ui_sound.is_valid():
        button.mouse_entered.connect(func() -> void: ui_sound.call("hover"))
        button.pressed.connect(func() -> void: ui_sound.call("press"))
    return button

## A button that leads with a picture: one glyph from the game's own icon
## language beside a one-word label. The menu speaks in these — a row of
## pictures the eye picks between before the reader in the player wakes up.
func _menu_button(text: String, primary: bool, glyph_key: String) -> Button:
    var button := _button(text, primary)
    button.icon = GardenGlyphs.get_glyph(glyph_key)
    button.expand_icon = true
    button.add_theme_constant_override("icon_max_width", 26)
    return button

func _button_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    # A soft grounded shadow lifts every plate off the world without a hard
    # edge — depth by warmth, not by outline.
    style.shadow_color = Color(0.03, 0.08, 0.05, 0.30)
    style.shadow_size = 7
    style.shadow_offset = Vector2(0, 3)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    return style

func _card(fill: Color, border: Color, radius: int, border_width: int = 2) -> PanelContainer:
    var panel := PanelContainer.new()
    var style := _button_style(fill, border, radius)
    # Every card wears a heavier gold crown along its top edge: the screen's
    # one piece of jewelry, the same on the menu, the pause card, the cart,
    # the memory book and the nap card, so the whole interface reads as one
    # hand instead of five.
    style.border_width_top = border_width + 3
    panel.add_theme_stylebox_override("panel", style)
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    return panel

## The identity band every screen opens with: a glyph in a gold roundel, the
## screen's name in the storybook face, and one quiet subtitle line. One
## factory so the menu, pause, cart, book, nap and ending cards all wear the
## same face — a screen's first impression is its header, and five screens
## drawing five different headers read as five different games.
##
## The heading wraps and expands instead of demanding its full width, and the
## roundel stays a fixed small plate: at 200% text on a 640x360 window the
## settings card has ~230px of header budget, so every piece here is sized to
## fit that worst case rather than the comfortable desktop one.
func _card_header(title: String, glyph_key: String, subtitle: String = "", heading_size: int = 30) -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    row.add_child(_roundel(glyph_key, 26))
    var heading := _label(title, heading_size, Color("#ffe6a0"))
    # The heading wraps when the row cannot afford its full one-line width.
    # "One line by choice" still holds everywhere it can: autowrap only bites
    # when the row is genuinely narrower than the text, and on every
    # comfortable desktop width it never bites. The old one-line-by-force
    # version had a per-control escape hatch in the responsive clamp -- but
    # the clamp judges each control alone, and at 200% text the menu title
    # fit alone while roundel + separation + title did not fit as a row, so
    # the menu card inflated straight off both edges of a 480px window.
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(heading)
    box.add_child(row)
    if not subtitle.is_empty():
        box.add_child(_centered_label(subtitle, 14, Color("#dcebbd")))
    return box

## One glyph sitting in a small gold-rimmed disc. The identity band's picture,
## extracted so the rest of the interface can wear the same jewelry: a row
## that leads with a roundel reads as "this screen speaks in pictures" the
## same way every other one does. `side` is the glyph's px size; the disc
## breathes 7px around it.
func _roundel(glyph_key: String, side: float, tint: Color = Color("#ffe9a8")) -> PanelContainer:
    var roundel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.32, 0.22, 0.06, 0.60)
    style.border_color = Color("#ffe29a")
    style.set_border_width_all(2)
    style.set_corner_radius_all(int(side * 0.92) + 3)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    roundel.add_theme_stylebox_override("panel", style)
    roundel.add_child(_icon(glyph_key, side, tint))
    return roundel

## A soft grounded plate a group of widgets stands on. The interface's quiet
## third layer: cards hold screens, buttons hold presses, and plates hold
## ROWS — a settings control, a record medal, a sticker — so related pieces
## read as one thing without a word of explanation. Shy on purpose: half
## opacity, so a stack of them never turns the card into a brick wall.
func _plate(accent: Color = Color("#9dbb80")) -> PanelContainer:
    var plate := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.15, 0.10, 0.55)
    style.border_color = Color(accent, 0.55)
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    plate.add_theme_stylebox_override("panel", style)
    plate.mouse_filter = Control.MOUSE_FILTER_PASS
    return plate

## One figure of the record as a medal: a roundel, a number, and a hover that
## says what is being counted. Bare icons-and-digits used to float on the card
## with nothing anchoring them, so a row of three numbers read as decoration;
## on a plate they read as three facts worth keeping.
func _medal_chip(glyph_key: String, value: String, tip: String) -> Control:
    var chip := _plate(Color("#ffe29a"))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    chip.add_child(row)
    row.add_child(_icon(glyph_key, 20, Color("#ffe9a8")))
    var count := _label(value, 15, Color("#fff0c8"))
    count.tooltip_text = tip
    row.add_child(count)
    chip.tooltip_text = tip
    return chip

## A keyboard key drawn as a little cap: a rounded plate holding one or two
## characters. The draft's "press 1 · 2 · 3" line used to be a sentence; three
## caps in a row are read the way the player will press them — as keys.
func _key_cap(label_text: String) -> Control:
    var cap := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.16, 0.28, 0.18, 0.92)
    style.border_color = Color("#ffe29a")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 2
    style.content_margin_bottom = 2
    cap.add_theme_stylebox_override("panel", style)
    var key_label := _label(label_text, 13, Color("#fff0c8"))
    key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cap.add_child(key_label)
    # PASS, not IGNORE: a cap the mouse passes through cannot show its own
    # tooltip, and "Press 1" is the whole point of drawing the key at all.
    cap.mouse_filter = Control.MOUSE_FILTER_PASS
    cap.tooltip_text = "Press %s" % label_text
    return cap

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
