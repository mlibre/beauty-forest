class_name GameUISettings
extends "res://scripts/game_ui_panels.gd"
## The gentler-forest panel: every comfort control, on its own plate,
## wearing its own picture. Split out of GameUIPanels when the settings
## rows grew their plates and their one-line "what this changes" notes --
## the cart/book file stays about the shelves and the closers, and this
## file stays about the controls. It sits in the GameUI chain between
## GameUIPanels (whose scaffolding it uses) and GameUIScreens, so every
## screen above it inherits the panel.

## `return_name` is the screen this panel will hand the player back to, supplied
## by the director, which is the only place that knows. The panel is reachable
## from the menu, from the pause card and from Peddle's cart, so a hardcoded
## "the walk" was a promise this button could not keep in two of the three.
func show_settings(settings: Dictionary, return_name: String = "the walk") -> void:
    _settings = settings.duplicate(true)
    _present_panel()
    var list := _panel_list(8)
    # The header rides inside the scroll like every panel's: a 200% text
    # header pinned above the list once pushed this whole card off the top of
    # a short window. Scrolled-to titles beat off-screen cards.
    list.add_child(_card_header("Make it yours ♥", GardenGlyphs.MOTE, "Change anything, anytime. Leaving is always okay."))
    list.add_child(_separator())

    # Every control stands on its own plate and leads with its own picture —
    # the same icon-led rows the pause summary taught, so the options panel
    # reads as the rest of the game does instead of a settings form. A bare
    # CheckButton-and-slider column was the one screen in the game that had
    # not learned the interface's own language.
    var motion := CheckButton.new()
    motion.text = "Still forest — calm decorative motion (walk stays readable)"
    motion.button_pressed = bool(_settings.get("reduced_motion", false))
    motion.toggled.connect(func(value):
        _settings["reduced_motion"] = value
        _emit_settings()
    )
    list.add_child(_settings_plate(GardenGlyphs.SOUL, _toggle_row(GardenGlyphs.SOUL, motion), ""))
    list.add_child(_settings_plate(GardenGlyphs.BOOK,
        _slider_row("Text size", "text_scale", 0.75, 2.0, 0.05, "%d%%", 100.0, GardenGlyphs.BOOK),
        "Everything grows with it — the cards, the walk's words, all of it."))
    var contrast := CheckButton.new()
    contrast.text = "High contrast — deeper cards and a sharper grove map"
    contrast.button_pressed = bool(_settings.get("high_contrast", false))
    contrast.toggled.connect(func(value):
        _settings["high_contrast"] = value
        _emit_settings()
    )
    list.add_child(_settings_plate(GardenGlyphs.LANTERN, _toggle_row(GardenGlyphs.LANTERN, contrast), ""))
    list.add_child(_section_label("SOFTNESS ♥"))
    # "Bump softness" reads as a quantity of softness, so dragging right should
    # add softness. The stored value is a damage multiplier, so it did the exact
    # opposite: a player reaching for gentler bumps dragged right and set
    # themselves to ×3.00, four times the damage they were trying to avoid. The
    # slider now runs 3.0 (left, hardest) to 0.25 (right, softest) and displays
    # the reciprocal, so right always means more of what the label names.
    list.add_child(_settings_plate("moss",
        _inverted_slider_row("Bump softness", "damage_taken", 0.25, 3.0, "×%.2f", 1.0, "moss"),
        "Drag right for gentler bumps; the number is how hard they land."))
    list.add_child(_settings_plate(GardenGlyphs.CHIME,
        _slider_row("Extra song time", "rhythm_window", 0.25, 3.0, 0.05, "×%.2f", 1.0, GardenGlyphs.CHIME),
        "How roomy the gold beat window feels."))
    list.add_child(_settings_plate(GardenGlyphs.WISP,
        _slider_row("Wisp speed", "wisp_speed", 0.25, 3.0, 0.05, "×%.2f", 1.0, GardenGlyphs.WISP),
        "How briskly the wisps drift around you."))
    list.add_child(_section_label("SOUND ♥"))
    list.add_child(_settings_plate("lullaby",
        _slider_row("Volume", "volume", 0.0, 1.0, 0.05, "%d%%", 100.0, "lullaby"),
        "The whole forest, louder or quieter."))
    var mute := CheckButton.new()
    mute.text = "Hush all sound"
    mute.button_pressed = bool(_settings.get("muted", false))
    mute.toggled.connect(func(value):
        _settings["muted"] = value
        _emit_settings()
    )
    list.add_child(_settings_plate(GardenGlyphs.CAMP, _toggle_row(GardenGlyphs.CAMP, mute), ""))
    var reset_center := CenterContainer.new()
    var reset := _menu_button("Restore gentle defaults", false, GardenGlyphs.MOTE)
    reset.pressed.connect(func():
        _settings = BeautyData.default_settings()
        _emit_settings()
        show_settings(_settings, return_name)
    )
    reset_center.add_child(reset)
    list.add_child(reset_center)
    # Reopening from Reset must carry the same destination as the panel the
    # player is already looking at, or the button would silently re-point itself
    # at "the walk" after being pressed from the menu or the cart.
    _shop_frame.add_child(_centered_button("Back to %s" % return_name, true, func(): close_settings()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)

## Where closing this panel will actually put the player back.
##
## The director knows exactly which screen it will return the player to, and
## passes that name in, so this label and the real route cannot disagree the way
## a hardcoded "the walk" did -- from the menu there is no walk to go back to.
## The scaffolding every settings row shares: an icon roundel leading the row
## (when one is given), the title at 180px, the slider stretching to fill, the
## amber value at 70px right-aligned. Callers wire their own range, initial
## value and connection.
##
## The roundel rides INSIDE this row on purpose: a suite finds a slider row by
## the exact title it paints and then reads the slider off that row's direct
## children, so any wrapping HBox above the row would be found first and read
## as "no slider". One row, one home for title, picture and control.
func _slider_parts(title: String, icon_key: String = "") -> Array:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    if not icon_key.is_empty():
        row.add_child(_roundel(icon_key, 18))
    var label := _label(title, 15, Color("#e8efd0"))
    label.custom_minimum_size = Vector2(180, 0)
    row.add_child(label)
    var slider := HSlider.new()
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    var value_label := _label("", 14, Color("#ffe69a"))
    value_label.custom_minimum_size = Vector2(70, 0)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(value_label)
    return [row, slider, value_label]

func _slider_row(title: String, key: String, minimum: float, maximum: float, step: float, format: String, display_scale: float = 1.0, icon_key: String = "") -> HBoxContainer:
    var parts := _slider_parts(title, icon_key)
    var row: HBoxContainer = parts[0]
    var slider: HSlider = parts[1]
    var value_label: Label = parts[2]
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = step
    slider.value = float(_settings.get(key, minimum))
    value_label.text = format % (float(_settings.get(key, minimum)) * display_scale)
    slider.value_changed.connect(func(value):
        _settings[key] = value
        if format == "%d%%":
            value_label.text = format % int(value * display_scale)
        else:
            value_label.text = format % value
        _emit_settings()
    )
    return row

func _inverted_slider_row(title: String, key: String, minimum: float, maximum: float, format: String, display_scale: float = 1.0, icon_key: String = "") -> HBoxContainer:
    ## A row whose label names a QUALITY of comfort rather than a raw amount.
    ## The handle travels the usual way, left to right, but the value it stores
    ## is the reciprocal of what the player reads: dragging right gives more of
    ## what the label says. HSlider refuses an inverted range outright -- it
    ## clamps min_value to max_value and then never emits value_changed again --
    ## so the mapping has to happen here.
    var parts := _slider_parts(title, icon_key)
    var row: HBoxContainer = parts[0]
    var slider: HSlider = parts[1]
    var value_label: Label = parts[2]
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.0
    value_label.text = format % (float(_settings.get(key, maximum)) * display_scale)

    var span: float = maximum - minimum
    var to_stored := func(t: float) -> float:
        return minimum + (1.0 - clampf(t, 0.0, 1.0)) * span
    slider.value_changed.connect(func(t: float):
        var stored: float = to_stored.call(t)
        _settings[key] = stored
        if format == "%d%%":
            value_label.text = format % int(stored * display_scale)
        else:
            value_label.text = format % stored
        _emit_settings()
    )
    # Place the handle where the stored value belongs, without firing the
    # callback for a move the player did not make.
    var current: float = float(_settings.get(key, maximum))
    slider.value = clampf(1.0 - (current - minimum) / span, 0.0, 1.0) if span > 0.0 else 0.0
    return row

## A toggle wearing its picture: the roundel leads, the CheckButton fills.
## The toggle keeps its own full sentence — the row adds the picture, never
## taking words away from a control whose whole description lives in them.
func _toggle_row(icon_key: String, toggle: CheckButton) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.add_child(_roundel(icon_key, 18))
    toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    row.add_child(toggle)
    return row

## One settings control on its plate: the control row, then a quiet line under
## it saying what the number changes (for rows whose control does not already
## carry its own description). Empty `note` rows — the toggles — skip the line.
func _settings_plate(icon_key: String, control: Control, note: String) -> PanelContainer:
    var plate := _plate(Color("#ffe29a"))
    plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    plate.add_child(box)
    box.add_child(control)
    if not note.is_empty():
        var note_label := _label(note, 12, Color("#bcd2a8"))
        note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(note_label)
    return plate

