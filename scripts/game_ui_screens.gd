class_name GameUIScreens
extends GameUILayout

## The animated, joyful screens: menu, pause, nap, ending, Peddle's cart, the
## memory book and the gentler-forest options panel.

func show_menu(meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    set_text_chrome_visible(true)
    _show_overlay()
    var title := _label("Beauty Forest", 46, Color("#ffe6a0"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_content.add_child(title)
    var subtitle := _label("a cozy walk — no hurry, no losing ♥", 20, Color("#dcebbd"))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_content.add_child(subtitle)
    _overlay_content.add_child(_spacer(4))
    var intro := _label("Your lantern sings all by itself. You just wander, cuddle lost wisps home, and pick kind gifts. There is no attack button. Leaving anytime is always okay.", 17, Color("#fff0c8"))
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.custom_minimum_size = Vector2(820, 0)
    _overlay_content.add_child(intro)
    var how := _label("How it feels:  ① wander  ② lantern sings  ③ choose a cozy gift  ♥", 14, Color("#d8e9bd"))
    how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    how.custom_minimum_size = Vector2(820, 0)
    _overlay_content.add_child(how)
    _overlay_content.add_child(_label("STEP 1 — PICK HOW GENTLE ♥", 14, Color("#ffe39a")))
    # Flow (not HBox): on narrow windows the three style buttons wrap onto a
    # second row instead of overflowing the card.
    #
    # It must EXPAND to the card width, not shrink to its minimum. Sized to its
    # minimum (SIZE_SHRINK_CENTER) the container is exactly as wide as the
    # widest button, so three of them can never share a row: it wrapped one per
    # row, and the menu needed 798px of height in a 564px panel, hiding the
    # "Wander into the forest" button below the fold on a default window.
    var styles := HFlowContainer.new()
    styles.alignment = FlowContainer.ALIGNMENT_CENTER
    styles.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
    styles.add_theme_constant_override("hseparation", 10)
    styles.add_theme_constant_override("vseparation", 10)
    _overlay_content.add_child(styles)
    # Short second lines only. The longer copy ("Extra cozy · bumps hurt
    # less") pushed each button past 280px wide, so the flow container wrapped
    # the three style choices onto three separate rows and the menu needed 798px
    # of height inside a 564px panel — which put the "Wander into the forest"
    # button, the single most important thing on the screen, below the fold on a
    # default 1280x720 window. The full description is one hover away.
    var menu_style_descriptions := {
        "gentle": "bumps hurt less",
        "standard": "just right",
        "bold": "more soul-light",
    }
    for key in ["gentle", "standard", "bold"]:
        var style: Dictionary = BeautyContent.STYLE_DATA[key]
        var picked: bool = key == _selected_style
        var button := _button("%s%s\n%s" % [("♥ " if picked else ""), style["name"], String(menu_style_descriptions[key])], picked)
        button.custom_minimum_size = Vector2(212, 66)
        button.tooltip_text = "%s — %s. Then press Wander below." % [String(style["name"]), String(style["description"])]
        button.pressed.connect(func():
            _selected_style = key
            show_menu(meta)
        )
        styles.add_child(button)
    var step2 := _label("STEP 2 — BEGIN ♥", 14, Color("#ffe39a"))
    step2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_content.add_child(step2)
    var start_button := _button("♥  Wander into the forest", true)
    # 300, not 340: a Button's minimum is max(custom_minimum_size, its text),
    # and the floor can never be shrunk by the reflow pass. At 340 the start
    # button alone demanded 368px of a 361px column on a 480px-wide window, so
    # the menu card grew past the window and could no longer be centred.
    start_button.custom_minimum_size = Vector2(300, 54)
    start_button.tooltip_text = "Start a gentle walk. You can leave anytime."
    start_button.pressed.connect(func(): start_requested.emit(_selected_style))
    var start_center := CenterContainer.new()
    start_center.add_child(start_button)
    _overlay_content.add_child(start_center)
    var record := "Visits %d  ·  Deepest floor %d  ·  Wisps guided home %d\nWalk: WASD / stick · Dash: Shift · Hug & sing: E · Shop: F · Memories: J · Cozy options: C · Rest: Esc" % [int(meta.get("runs", 0)), int(meta.get("best_floor", 0)), int(meta.get("wisps_soothed", 0))]
    var record_label := _label(record, 13, Color("#cbdcb7"))
    record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    record_label.custom_minimum_size = Vector2(820, 0)
    record_label.add_theme_constant_override("line_spacing", 5)
    _overlay_content.add_child(record_label)
    var leave := _button("Not now — keep my spot warm ♥", false)
    leave.custom_minimum_size = Vector2(300, 44)
    leave.tooltip_text = "No pressure. The forest waits for you."
    leave.pressed.connect(func(): quit_requested.emit())
    var leave_center := CenterContainer.new()
    leave_center.add_child(leave)
    _overlay_content.add_child(leave_center)
    # The menu's own key line advertises "Cozy options: C", but nothing here
    # emitted settings_open_requested, so C (and any player who reads the line)
    # had no way to reach the gentler-forest panel before starting: zero entry
    # points on this screen. Offer it here, next to the leave button it pairs
    # with, and let the director hand the menu back on close.
    var cozy := _button("Make it gentler", false)
    cozy.custom_minimum_size = Vector2(300, 44)
    cozy.tooltip_text = "Reduce hits, calm the wobble, and turn up the contrast before you begin."
    cozy.pressed.connect(func(): settings_open_requested.emit())
    var cozy_center := CenterContainer.new()
    cozy_center.add_child(cozy)
    _overlay_content.add_child(cozy_center)
    _fit_layout()
	# Refit AFTER building: the panels are authored at comfortable desktop
	# widths, and _refit_content can only clamp children that already exist.
    _focus_control(start_button)

func show_pause(meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = true
    # Pausing is the ONE moment the player asks for information, so this is
    # where everything the icon HUD dropped comes back: level, song power, the
    # charm list and the control keys. Read on purpose, not while walking.
    set_text_chrome_visible(true)
    _show_overlay()
    _overlay_content.add_child(_centered_label("Take a breath ♥", 38, Color("#ffe6a0")))
    _overlay_content.add_child(_centered_label("Paused — the forest waits for you. Nothing hurries here.", 17, Color("#dce9c2")))
    _overlay_content.add_child(_spacer(10))
    _overlay_content.add_child(_walker_summary())
    _overlay_content.add_child(_spacer(14))
    _overlay_content.add_child(_centered_button("♥  Keep wandering", true, func(): resume_requested.emit()))
    _overlay_content.add_child(_centered_button("Make it gentler", false, func(): settings_open_requested.emit()))
    _overlay_content.add_child(_centered_button("Start a fresh walk", false, func(): restart_requested.emit(false)))
    _overlay_content.add_child(_centered_button("Leave for now ♥", false, func(): quit_requested.emit()))
    _overlay_content.add_child(_spacer(10))
    _overlay_content.add_child(_keys_reference())
    _overlay_content.add_child(_centered_label("Deepest floor %d  ·  Wisps hugged home %d  ·  Fun facts %d" % [int(meta.get("best_floor", 0)), int(meta.get("wisps_soothed", 0)), int(meta.get("facts", 0))], 14, Color("#bdcea9")))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

## The stats the icon HUD no longer paints, as one compact two-column block.
## Kept short on purpose: a pause screen is a breather, not a spreadsheet.
##
## No fixed width: the block used to ask for 560px, which is wider than a 480px
## window, so the pause card grew to 533px and hung 26px off the left edge. The
## rows autowrap and the responsive pass clamps them to the card instead.
func _walker_summary() -> Control:
    var rows: Array = [
        ["Warmth", "%d / %d" % [_walker_hp, _walker_hp_max]],
        ["Level", "%d  ·  %d / %d soul to next gift" % [_walker_level, _walker_xp, _walker_xp_next]],
        ["Song power", "%d" % _walker_song],
        ["Charms", "%s" % ("none worn — Peddle's cart has charms ♥" if _walker_charms.is_empty() else _walker_charms)],
        ["Depth", "Floor %d — %s" % [_walker_floor, _walker_region]],
    ]
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for row: Array in rows:
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 10)
        var name_label := _label(String(row[0]), 15, Color("#dce9bd"))
        name_label.custom_minimum_size = Vector2(110, 0)
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        line.add_child(name_label)
        var value_label := _label(String(row[1]), 15, Color("#fff0c8"))
        value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(value_label)
        box.add_child(line)
    return box

## The control keys, which the play screen no longer shows.
func _keys_reference() -> Control:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var keys := _label("Wander: WASD / arrows / stick  ·  Dash: Shift  ·  Hug, sing & descend: E  ·  Cart: F  ·  Memories: J  ·  Cozy options: C  ·  Pause: Esc", 13, Color("#cbdcb7"))
    keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(keys)
    return box

func show_death(floor_number: int, meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    _beat_ring.visible = false
    _show_overlay()
    _overlay_content.add_child(_centered_label("You took a cozy nap ♥", 42, Color("#ffe6a0")))
    _overlay_content.add_child(_centered_label("Mote tucked your lantern into a mossy pocket. No one is cross. The forest will be here when you wake.", 18, Color("#e9f0d4")))
    _overlay_content.add_child(_spacer(12))
    _overlay_content.add_child(_centered_label("You reached floor %d. Every wisp you hugged home is still warm." % floor_number, 16, Color("#fff0c8")))
    _overlay_content.add_child(_spacer(18))
    _overlay_content.add_child(_centered_button("♥  Wake up & wander again", true, func(): restart_requested.emit(false)))
    _overlay_content.add_child(_centered_button("Rest a little longer", false, func(): quit_requested.emit()))
    _overlay_content.add_child(_centered_label("Visits %d  ·  Deepest floor %d" % [int(meta.get("runs", 0)), int(meta.get("best_floor", 0))], 14, Color("#bdcea9")))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

func show_ending(dragons: int, meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    _beat_ring.visible = false
    _show_overlay()
    _overlay_content.add_child(_centered_label("The dragons are snuggled ♥", 42, Color("#ffe6a0")))
    _overlay_content.add_child(_centered_label("Snoozle’s family sleeps in a warm heap of happy dreams. Somewhere far below, one enormous cousin yawns: ‘More lullabies when you’re ready.’", 18, Color("#e9f0d4")))
    _overlay_content.add_child(_spacer(10))
    _overlay_content.add_child(_centered_label("The forest grew one floor deeper, just for you. Come back for another gentle walk whenever you like.", 16, Color("#fff0c8")))
    _overlay_content.add_child(_centered_label("Dragons tucked in: %d  ·  Wisps hugged home: %d  ·  Fun facts: %d" % [dragons, int(meta.get("wisps_soothed", 0)), int(meta.get("facts", 0))], 15, Color("#cbdcaf")))
    _overlay_content.add_child(_spacer(16))
    _overlay_content.add_child(_centered_button("♥  Wander deeper", true, func(): restart_requested.emit(true)))
    _overlay_content.add_child(_centered_button("Until next time ♥", false, func(): quit_requested.emit()))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

func _clear_panel() -> void:
    ## Empty the shared modal panel (cart, memory book, gentler-forest options).
    ##
    ## The frame is cleared rather than the list so a rebuild can never leave a
    ## stale header, scroll or button behind. Callers then add their heading
    ## rows, ask for the list, fill it, and add their closing button, so the
    ## visual order is simply the order things were added.
    _clear(_shop_frame)
    _shop_content = null

func _panel_list(separation: int = 8) -> VBoxContainer:
    ## Append the scrolling row list to the panel and hand it back.
    ##
    ## Header rows and the closing button go into _shop_frame, which fills the
    ## card; only the rows themselves go into the returned list inside this
    ## scroll. The scroll has to sit directly under the frame, because a
    ## ScrollContainer reports a ZERO minimum height on its scrolling axis, so
    ## it can only be given room by SIZE_EXPAND_FILL inside a parent that has
    ## spare height to give. _shop_scroll is rebound because the previous one
    ## was freed along with the frame.
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _style_scrollbars(scroll)
    _shop_frame.add_child(scroll)
    _shop_scroll = scroll
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", separation)
    scroll.add_child(list)
    _shop_content = list
    return list

func show_shop(state: Dictionary) -> void:
    _dismiss_beat_ring()
    _cancel_story()
    _reset_touch_joystick()
    _shop_scrim.visible = true
    _shop_card.visible = true
    _fit_layout()
    _clear_panel()
    var heading := HBoxContainer.new()
    _shop_frame.add_child(heading)
    var title := _label("Peddle’s cozy cart ♥", 28, Color("#ffe49b"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title)
    heading.add_child(_label("✦ %d to spend" % int(state.get("sparkles", 0)), 22, Color("#ffe987")))
    _shop_frame.add_child(_label("Everything helps all by itself. Warm tea heals you now. Pick up to %d charms + %d lantern songs." % [BeautyContent.MAX_CHARMS, BeautyContent.MAX_STANZAS], 14, Color("#dce9c4")))
    _shop_frame.add_child(_separator())
    var list := _panel_list(7)

    list.add_child(_section_label("1 · WARM TEA — DRINK NOW ♥"))
    # Spending sparkles on tea while already warm used to be a silent no-op
    # purchase: the button was live, the price was charged, and nothing
    # happened. Offer it only when it can actually do something, and say why.
    var warmth_full := float(state.get("hp", 0.0)) >= float(state.get("hp_max", 1.0))
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) != "tea":
            continue
        var tea_button := _shop_item(charm, int(state.get("sparkles", 0)), false, not warmth_full, false)
        if warmth_full:
            tea_button.tooltip_text = "You are warm as a toast already — keep these sparkles for a charm ♥"
        tea_button.pressed.connect(func(): buy_requested.emit("tea"))
        list.add_child(tea_button)

    list.add_child(_section_label("2 · COZY CHARMS — PICK UP TO %d ♥" % BeautyContent.MAX_CHARMS))
    var owned: Dictionary = state.get("owned", {})
    var equipped: Dictionary = state.get("charms", {})
    var slots_full := equipped.size() >= BeautyContent.MAX_CHARMS
    for charm: Dictionary in BeautyContent.CHARMS:
        var key := String(charm["key"])
        if key == "tea":
            continue
        if bool(owned.get(key, false)):
            var toggle := _shop_item(charm, int(state.get("sparkles", 0)), bool(equipped.get(key, false)), true, true, slots_full)
            toggle.pressed.connect(func(): charm_equip_requested.emit(key))
            list.add_child(toggle)
        else:
            var buy := _shop_item(charm, int(state.get("sparkles", 0)), false, true, false, slots_full)
            if slots_full:
                buy.tooltip_text = "%s — all %d charm slots are full, so this waits in your pocket until you swap one." % [
                    String(charm.get("description", "")), BeautyContent.MAX_CHARMS]
            buy.pressed.connect(func(): buy_requested.emit(key))
            list.add_child(buy)

    list.add_child(_section_label("3 · LANTERN SONGS — PICK UP TO %d ♥" % BeautyContent.MAX_STANZAS))
    var stanzas: Dictionary = state.get("stanzas", {})
    for stanza: Dictionary in BeautyContent.STANZAS:
        var key := String(stanza["key"])
        var toggle := _shop_item(stanza, 0, bool(stanzas.get(key, false)), true, true, false, true)
        toggle.pressed.connect(func(): stanza_equip_requested.emit(key))
        list.add_child(toggle)

    list.add_child(_section_label("4 · MOTE’S HUM — PICK ONE ♥"))
    var verse: Dictionary = state.get("mote_verse", {})
    for option: Dictionary in BeautyContent.MOTE_VERSES:
        var key := String(option["key"])
        var selected := String(verse.get("key", "")) == key
        # Exclusive and free, like the verses: nobody owns a counter-melody.
        var mote_option: Dictionary = option.duplicate()
        mote_option["kind"] = "mote"
        var toggle := _shop_item(mote_option, 0, selected, true, true, false, true)
        toggle.pressed.connect(func(): mote_verse_requested.emit(key))
        list.add_child(toggle)

    _shop_frame.add_child(_centered_button("♥  Done — back to the walk", true, func(): close_shop()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)

func show_journal(meta: Dictionary, facts_learned: Array, stickers: Array) -> void:
    _dismiss_beat_ring()
    _cancel_story()
    _reset_touch_joystick()
    _shop_scrim.visible = true
    _shop_card.visible = true
    _fit_layout()
    _clear_panel()
    _shop_frame.add_child(_label("Mote’s memory book ♥", 30, Color("#ffe49b")))
    _shop_frame.add_child(_label("Fun facts and stickers you collected. Just for smiles — never a test.", 14, Color("#dce9c4")))
    _shop_frame.add_child(_separator())
    var list := _panel_list(9)
    list.add_child(_section_label("FUN FACTS YOU FOUND · %d ♥" % facts_learned.size()))
    if facts_learned.is_empty():
        list.add_child(_label("No facts yet. Level up gently or soothe a curious wisp; Mote will share one.", 16, Color("#eee8c8")))
    else:
        for index in range(facts_learned.size()):
            list.add_child(_label("%02d  ·  %s" % [index + 1, facts_learned[index]], 16, Color("#fff0c8")))
    list.add_child(_section_label("YOUR STICKERS ♥"))
    if stickers.is_empty():
        list.add_child(_label("First Nap is waiting somewhere ahead. It is not a prize cup; it is simply a little proof you wandered kindly.", 16, Color("#eee8c8")))
    else:
        for sticker in stickers:
            list.add_child(_label("✦ " + String(BeautyContent.STICKERS.get(sticker, sticker)), 16, Color("#ffe8a2")))
    list.add_child(_section_label("YOUR KINDNESS SO FAR ♥"))
    list.add_child(_label("Walks: %d    Deepest floor: %d    Wisps hugged home: %d    Dragons tucked in: %d" % [int(meta.get("runs", 0)), int(meta.get("best_floor", 0)), int(meta.get("wisps_soothed", 0)), int(meta.get("dragons_sung", 0))], 16, Color("#dce9c4")))
    _shop_frame.add_child(_centered_button("♥  Close my book", true, func(): close_journal()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)

func show_settings(settings: Dictionary) -> void:
    _dismiss_beat_ring()
    _settings = settings.duplicate(true)
    _cancel_story()
    _reset_touch_joystick()
    _shop_scrim.visible = true
    _shop_card.visible = true
    _fit_layout()
    _clear_panel()
    _shop_frame.add_child(_label("Make it yours ♥", 30, Color("#ffe49b")))
    _shop_frame.add_child(_label("Cozy choices. Change anything, anytime. Leaving is always okay.", 14, Color("#dce9c4")))
    _shop_frame.add_child(_separator())
    var list := _panel_list(8)

    var motion := CheckButton.new()
    motion.text = "Still forest — calm decorative motion (walk stays readable)"
    motion.button_pressed = bool(_settings.get("reduced_motion", false))
    motion.toggled.connect(func(value):
        _settings["reduced_motion"] = value
        _emit_settings()
    )
    list.add_child(motion)
    list.add_child(_slider_row("Text size", "text_scale", 0.75, 2.0, 0.05, "%d%%", 100.0))
    var contrast := CheckButton.new()
    contrast.text = "High contrast — deeper cards and a sharper grove map"
    contrast.button_pressed = bool(_settings.get("high_contrast", false))
    contrast.toggled.connect(func(value):
        _settings["high_contrast"] = value
        _emit_settings()
    )
    list.add_child(contrast)
    list.add_child(_section_label("COZY COMFORT ♥"))
    # "Bump softness" reads as a quantity of softness, so dragging right should
    # add softness. The stored value is a damage multiplier, so it did the exact
    # opposite: a player reaching for gentler bumps dragged right and set
    # themselves to ×3.00, four times the damage they were trying to avoid. The
    # slider now runs 3.0 (left, hardest) to 0.25 (right, softest) and displays
    # the reciprocal, so right always means more of what the label names.
    list.add_child(_inverted_slider_row("Bump softness", "damage_taken", 0.25, 3.0, "×%.2f"))
    list.add_child(_slider_row("Extra song time", "rhythm_window", 0.25, 3.0, 0.05, "×%.2f"))
    list.add_child(_slider_row("Wisp speed", "wisp_speed", 0.25, 3.0, 0.05, "×%.2f"))
    list.add_child(_section_label("COZY SOUNDS ♥"))
    list.add_child(_slider_row("Volume", "volume", 0.0, 1.0, 0.05, "%d%%", 100.0))
    var mute := CheckButton.new()
    mute.text = "Hush all sound"
    mute.button_pressed = bool(_settings.get("muted", false))
    mute.toggled.connect(func(value):
        _settings["muted"] = value
        _emit_settings()
    )
    list.add_child(mute)
    var reset := _button("Restore gentle defaults", false)
    reset.pressed.connect(func():
        _settings = BeautyData.default_settings()
        _emit_settings()
        show_settings(_settings)
    )
    list.add_child(reset)
    _shop_frame.add_child(_centered_button("♥  Back to the walk", true, func(): close_settings()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)

func _slider_row(title: String, key: String, minimum: float, maximum: float, step: float, format: String, display_scale: float = 1.0) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    var label := _label(title, 15, Color("#e8efd0"))
    label.custom_minimum_size = Vector2(180, 0)
    row.add_child(label)
    var slider := HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = step
    slider.value = float(_settings.get(key, minimum))
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    var value_label := _label(format % (float(_settings.get(key, minimum)) * display_scale), 14, Color("#ffe69a"))
    value_label.custom_minimum_size = Vector2(70, 0)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(value_label)
    slider.value_changed.connect(func(value):
        _settings[key] = value
        if format == "%d%%":
            value_label.text = format % int(value * display_scale)
        else:
            value_label.text = format % value
        _emit_settings()
    )
    return row

func _inverted_slider_row(title: String, key: String, minimum: float, maximum: float, format: String, display_scale: float = 1.0) -> HBoxContainer:
    ## A row whose label names a QUALITY of comfort rather than a raw amount.
    ## The handle travels the usual way, left to right, but the value it stores
    ## is the reciprocal of what the player reads: dragging right gives more of
    ## what the label says. HSlider refuses an inverted range outright -- it
    ## clamps min_value to max_value and then never emits value_changed again --
    ## so the mapping has to happen here.
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    var label := _label(title, 15, Color("#e8efd0"))
    label.custom_minimum_size = Vector2(180, 0)
    row.add_child(label)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.0
    slider.value = 0.0
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    var value_label := _label(format % (float(_settings.get(key, maximum)) * display_scale), 14, Color("#ffe69a"))
    value_label.custom_minimum_size = Vector2(70, 0)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(value_label)

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

func close_shop() -> void:
    _shop_scrim.visible = false
    _shop_card.visible = false
    shop_closed.emit()

func close_journal() -> void:
    _shop_scrim.visible = false
    _shop_card.visible = false
    journal_closed.emit()

func close_settings() -> void:
    _shop_scrim.visible = false
    _shop_card.visible = false
    settings_closed.emit()

func close_panels() -> void:
    _shop_scrim.visible = false
    _shop_card.visible = false
    _overlay_scrim.visible = false
    _overlay_card.visible = false
    _beat_ring.visible = false
    _cancel_story()
    _reset_touch_joystick()

## The little picture at the left of a shop row.
##
## The three wares live in three different tables that share a key namespace --
## `moss` is both a charm and a stanza -- so each row asks for its glyph by
## kind. A row for a key with no glyph yet gets a neutral Mote mark rather than
## a hole, so the gap is visible and worth a bug report.
func _wore_icon(item: Dictionary, selected: bool) -> TextureRect:
    var kind := String(item.get("kind", "charm"))
    var key := String(item.get("key", ""))
    var glyph_key := key
    if kind == "verse":
        glyph_key = GardenGlyphs.STANZA_PREFIX + key
    elif kind == "mote":
        glyph_key = GardenGlyphs.VERSE_PREFIX + key
    if not GardenGlyphs.has_glyph(glyph_key):
        glyph_key = GardenGlyphs.MOTE
    var icon := TextureRect.new()
    icon.texture = GardenGlyphs.get_glyph(glyph_key)
    icon.custom_minimum_size = Vector2(34, 34)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Worn things get a lit rim so the eye finds the equipped row instantly.
    icon.modulate = Color(1.0, 1.0, 1.0) if not selected else Color(1.12, 1.08, 0.95)
    return icon

func _shop_item(item: Dictionary, sparkles: int, selected: bool, enabled: bool, is_owned: bool, slots_full: bool = false, free_item: bool = false) -> Button:
    var key := String(item.get("key", ""))
    var price := int(item.get("price", 0))
    # A verse is nobody's to own -- the shop listed every unworn one as "in
    # pocket -- tap to wear" and "already yours", which describes a purchase
    # that never happened. Verses now say what they are: a swap.
    var status := "♥ WEARING" if selected else (("hum this instead" if String(item.get("kind", "verse")) == "mote" else "swap it in for a verse you're humming") if free_item else ("in pocket — tap to wear" if is_owned else ("take for ✦ %d" % price if price > 0 else "try it on")))
    var price_text := "✦ %d" % price if price > 0 else "free gift"
    # A row is a PICTURE of the thing, its name, and what it costs. The full
    # description and the tap-consequence live in the tooltip, which the player
    # asks for by hovering -- so browsing the cart is scanning icons, not
    # reading 41 paragraphs.
    var button := Button.new()
    button.custom_minimum_size = Vector2(0, 52)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.offset_left = 12
    row.offset_right = -12
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(_wore_icon(item, selected))
    var words := VBoxContainer.new()
    words.add_theme_constant_override("separation", 0)
    words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    words.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var title := _label(String(item.get("name", key)), 17, Color("#fff0c8"))
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    words.add_child(title)
    var sub := _label(status, 12, Color("#bcd2a8"))
    sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
    words.add_child(sub)
    row.add_child(words)
    var tag := _label(price_text, 15, Color("#ffd257"))
    tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(tag)
    button.add_child(row)
    if free_item and not selected:
        # Nothing here was ever bought, so "already yours" is the wrong story.
        # The swap is the whole truth, and the log now names what steps aside.
        var swap_note := " Tap to swap it in; one of your two verses will step back." if String(item.get("kind", "verse")) == "verse" else " Tap to hum this one instead."
        button.tooltip_text = "%s — free to hum any time.%s" % [String(item.get("description", "")), swap_note]
    elif is_owned and not selected:
        # Say what tapping will actually do. With all three slots taken the tap
        # swaps rather than adds, and "tap to wear" would be a small lie.
        var swap_note := " Tap to swap it in for a charm you are wearing." if slots_full else " Tap to wear it."
        button.tooltip_text = "%s — already yours.%s" % [String(item.get("description", "")), swap_note]
    elif selected:
        button.tooltip_text = "%s — wearing it now. Tap to rest it." % String(item.get("description", ""))
    elif price > 0 and sparkles < price:
        button.tooltip_text = "You need %d sparkles — soothe %d more wisp%s. It will keep. ♥" % [price, price - sparkles, "" if price - sparkles == 1 else "s"]
    else:
        button.tooltip_text = String(item.get("description", ""))
    button.disabled = not enabled or (not is_owned and price > 0 and sparkles < price)
    button.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.28, 0.18, 0.92), Color("#8abf75") if selected else Color("#d8c27c"), 12))
    button.add_theme_stylebox_override("hover", _button_style(Color(0.22, 0.39, 0.23, 0.98), Color("#ffe69b"), 12))
    button.add_theme_stylebox_override("pressed", _button_style(Color(0.10, 0.21, 0.13, 1.0), Color("#fff0b0"), 12))
    button.add_theme_stylebox_override("disabled", _button_style(Color(0.12, 0.18, 0.13, 0.55), Color("#75836d"), 12))
    return button
