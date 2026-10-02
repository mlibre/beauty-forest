class_name GameUIScreens
extends GameUIPanels

## The animated, joyful screens: menu, pause, nap, ending, the memory book --
## the ones that open into the overlay card. The full-screen panels (Peddle's
## cart, the gentler-forest options) live one file down, in GameUIPanels.

func show_menu(meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    set_text_chrome_visible(true)
    _show_menu_overlay()
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
## The Depth row also carries the floor's forecast. It used to have a label of
## its own in the corner status card -- "A warm path through the roots", a
## sentence nothing ever updated -- so the card showed one stale line and the
## summary showed another, and as the longest wrapped line in that card the
## duplicate also pushed the card off a 360px window at 200% text.
##
## No fixed width: the block used to ask for 560px, which is wider than a 480px
## window, so the pause card grew to 533px and hung 26px off the left edge. The
## rows autowrap and the responsive pass clamps them to the card instead.
func _walker_summary() -> Control:
    var depth := "Floor %d — %s" % [_walker_floor, _walker_region]
    if not _walker_forecast.is_empty():
        depth += " · %s" % _walker_forecast
    var rows: Array = [
        ["Warmth", "%d / %d" % [_walker_hp, _walker_hp_max]],
        ["Level", "%d  ·  %d / %d soul to next gift" % [_walker_level, _walker_xp, _walker_xp_next]],
        ["Song power", "%d" % _walker_song],
        ["Charms", "%s" % ("none worn — Peddle's cart has charms ♥" if _walker_charms.is_empty() else _walker_charms)],
        ["Depth", depth],
    ]
    if not _walker_objective.is_empty():
        rows.append(["Next", _walker_objective])
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
