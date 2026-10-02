class_name GameUIPanels
extends GameUILayout

## The three full-screen panels -- Peddle's cart, the gentler-forest options and
## the closers that put them away -- plus the row builders they share.
##
## Split out of GameUIScreens. These three panels are the only screens that open
## into the reusable shop card rather than the overlay card, they all close the
## same way, and their rows need the same two helpers. Keeping them together is
## what lets GameUIScreens stay a file about the story screens.
##
## Peddle's cart is a SHELF of picture cards, not a list of sentences: every
## ware gets a CozyCard that says what it is in ink (icon, lit rim, sparkle
## price) and keeps only its own name and price digits as words. That is the
## single biggest text win in the game -- the cart used to paint ~100 labels
## and now paints one name per ware.

func _clear_panel() -> void:
    ## Empty the shared modal panel (cart, memory book, gentler-forest options).
    ##
    ## The frame is cleared rather than the list so a rebuild can never leave a
    ## stale header, scroll or button behind. Callers then add their heading
    ## rows, ask for the list, fill it, and add their closing button, so the
    ## visual order is simply the order things were added.
    _clear(_shop_frame)
    _shop_content = null

## The scrolling row list, appended to the panel and handed back. Always a
## VBox: the shelves inside are GridContainers, so this holds one thing per
## section rather than the cards themselves.
##
## Header rows and the closing button go into _shop_frame, which fills the
## card; only the rows themselves go into the returned list inside this
## scroll. The scroll has to sit directly under the frame, because a
## ScrollContainer reports a ZERO minimum height on its scrolling axis, so it
## can only be given room by SIZE_EXPAND_FILL inside a parent that has spare
## height to give. _shop_scroll is rebound because the previous one was freed
## along with the frame.
func _panel_list(separation: int = 8) -> VBoxContainer:
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

## A titled shelf of wares, wrapped into as many columns as the card is wide.
##
## The section heading is an icon plus a bare count ("3") rather than a line of
## prose: the wares below it are the explanation, and a heading that spelled out
## the same rule in words was a third of the cart's text for no new information.
## `worn_of` is the count the heading shows, so "2 charms" can be read off the
## heading without a line per slot.
func _shelf(list: VBoxContainer, title: String, glyph_key: String, count: String, worn_of: String = "") -> GridContainer:
    var heading := HBoxContainer.new()
    heading.add_theme_constant_override("separation", 8)
    list.add_child(heading)
    heading.add_child(_icon(GardenGlyphs.MOTE if glyph_key.is_empty() else glyph_key, 20, Color("#ffe497")))
    var label := _label(title, 15, Color("#ffe497"))
    heading.add_child(label)
    if not count.is_empty():
    var count_label := _label(count, 15, Color("#fff0c8"))
    heading.add_child(count_label)
    if not worn_of.is_empty():
    heading.add_child(_label("· %s" % worn_of, 13, Color("#bcd2a8")))
    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("hseparation", 10)
    grid.add_theme_constant_override("vseparation", 10)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_child(grid)
    return grid

## One ware on a shelf, as a picture with a name and a price.
##
## The card paints its own state in ink -- a gold rim and a halo when you are
## wearing it, a dimmed face when you cannot afford it, a heart instead of a
## sparkle when it is a gift -- so the words that used to sit under every ware
## ("in pocket -- tap to wear", "swap it in for a verse you're humming", "take
## for sparkles 5", "free gift") are gone from the painted screen. What the
## ink cannot say lives on in the tooltip the player asks for by hovering.
func _ware_card(grid: GridContainer, item: Dictionary, sparkles: int, worn: bool, is_owned: bool, free_item: bool, slots_full: bool, pressed: Callable) -> Button:
    var price := int(item.get("price", 0))
    var affordable := is_owned or free_item or price <= sparkles
    var button := Button.new()
    var card := CozyCard.new()
    card.name = String(item.get("key", "ware"))
    card.item = item
    card.price = price
    card.selected = worn
    card.owned = is_owned
    card.free_item = free_item
    card.affordable = affordable
    card.high_contrast = _high_contrast
    button.add_child(card)
    # A Button's minimum is max(custom_minimum_size, its own text), and this row
    # paints no text at all, so without a floor the shelf would collapse into a
    # single column. The card knows its own size; the button inherits it.
    button.custom_minimum_size = card.custom_minimum_size
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.disabled = not affordable
    button.tooltip_text = _ware_tooltip(item, card, sparkles, slots_full)
    # The card is a plain child, so it has to fill the button's rect and take no
    # mouse input itself -- otherwise it swallows the press before the button
    # ever sees it.
    card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.pressed.connect(pressed)
    var border := Color("#ffe08a") if worn else Color("#8abf75")
    button.add_theme_stylebox_override("normal", _button_style(Color(0, 0, 0, 0), border, 14))
    button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.94, 0.72, 0.14), Color("#ffe69b"), 14))
    button.add_theme_stylebox_override("pressed", _button_style(Color(1.0, 0.90, 0.55, 0.22), Color("#fff0b0"), 14))
    button.add_theme_stylebox_override("disabled", _button_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.16), 14))
    grid.add_child(button)
    return button

## What the card cannot say in ink, asked for by hovering.
##
## Every state the card paints only suggestively is spelled out here: what the
## ware does, whether tapping wears or swaps, and -- for a price you cannot meet
## -- how much more is needed. A dimmed card says "not yet"; this is where the
## player learns what it is saving toward.
func _ware_tooltip(item: Dictionary, card: CozyCard, sparkles: int, slots_full: bool) -> String:
    var what := String(item.get("description", ""))
    if card.free_item:
    # Nobody owns a verse, so this one must not describe a pocket or a
    # purchase -- the swap is the whole truth.
    var swap_note := " Tap to swap it in; one of your two verses will step back." if String(item.get("kind", "verse")) == "verse" else " Tap to hum this one instead."
    return "%s — free to hum any time.%s" % [what, swap_note]
    if card.selected:
    return "%s — wearing it now. Tap to rest it." % what
    if card.owned:
    # With every slot taken the tap swaps rather than adds, and "tap to wear"
    # would be a small lie.
    var swap_note := " Tap to swap it in for a charm you are wearing." if slots_full else " Tap to wear it."
    return "%s — already yours.%s" % [what, swap_note]
    if slots_full:
    return "%s — all %d charm slots are full, so this waits in your pocket until you swap one." % [
    what, BeautyContent.MAX_CHARMS]
    if card.price > 0 and not card.affordable:
    var short := card.price - sparkles
    return "You need %d sparkles — soothe %d more wisp%s. It will keep. ♥" % [
    card.price, short, "" if short == 1 else "s"]
    return what

func show_shop(state: Dictionary) -> void:
    _dismiss_beat_ring()
    _cancel_story()
    _reset_touch_joystick()
    _shop_scrim.visible = true
    _shop_card.visible = true
    _fit_layout()
    _clear_panel()
    var sparkles := int(state.get("sparkles", 0))
    var heading := HBoxContainer.new()
    heading.add_theme_constant_override("separation", 10)
    _shop_frame.add_child(heading)
    heading.add_child(_icon(GardenGlyphs.CART, 26, Color("#ffe49b")))
    var title := _label("Peddle’s cozy cart ♥", 26, Color("#ffe49b"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title)
    # The purse is a sparkle and a number, not "12 to spend" -- the icon beside
    # the digits already says what they are.
    heading.add_child(_icon(GardenGlyphs.SPARKLE, 22, Color("#ffe987")))
    heading.add_child(_label(str(sparkles), 22, Color("#ffe987")))
    _shop_frame.add_child(_separator())
    var list := _panel_list(12)

    # Warm tea: one ware, so it gets a shelf of its own only because it is
    # bought constantly and heals. Spending sparkles on tea while already warm
    # used to be a silent no-op -- the button was live, the price was charged
    # and nothing happened -- so it is dimmed at full warmth and the hover says
    # why.
    var warmth_full := float(state.get("hp", 0.0)) >= float(state.get("hp_max", 1.0))
    var tea_shelf := _shelf(list, "WARM TEA", "tea", "")
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) != "tea":
            continue
        var tea_button := _ware_card(tea_shelf, charm, sparkles, false, false, false, false, func(): buy_requested.emit("tea"))
        tea_button.disabled = warmth_full or not tea_button.disabled
        if warmth_full:
            tea_button.tooltip_text = "You are warm as a toast already — keep these sparkles for a charm ♥"

    var owned: Dictionary = state.get("owned", {})
    var equipped: Dictionary = state.get("charms", {})
    var slots_full := equipped.size() >= BeautyContent.MAX_CHARMS
    # The heading carries the count, so it never has to be read off a sentence:
    # a gold rim on a card is "wearing", and this is how many there are.
    var charm_shelf := _shelf(list, "COZY CHARMS", "scarf", "%d/%d" % [
        equipped.size(), BeautyContent.MAX_CHARMS])
    for charm: Dictionary in BeautyContent.CHARMS:
        var key := String(charm["key"])
        if key == "tea":
            continue
        var is_owned := bool(owned.get(key, false))
        var worn := bool(equipped.get(key, false))
        # An owned charm toggles wear; an unowned one buys. Which of the two it
        # is has to be visible before the press, so the card's tooltip leads
        # with it and the rim only ever answers "am I wearing it".
        _ware_card(charm_shelf, charm, sparkles, worn, is_owned, false, slots_full,
            func():
                if is_owned:
                    charm_equip_requested.emit(key)
                else:
                    buy_requested.emit(key))

    var stanzas: Dictionary = state.get("stanzas", {})
    var stanza_shelf := _shelf(list, "LANTERN SONGS", GardenGlyphs.STANZA_PREFIX + "petals", "%d/%d" % [
        stanzas.size(), BeautyContent.MAX_STANZAS])
    for stanza: Dictionary in BeautyContent.STANZAS:
        var key := String(stanza["key"])
        var toggle := _ware_card(stanza_shelf, stanza.duplicate(), sparkles,
            bool(stanzas.get(key, false)), false, true, false, func(): stanza_equip_requested.emit(key))
        toggle.name = key

    var verse: Dictionary = state.get("mote_verse", {})
    var verse_shelf := _shelf(list, "MOTE’S HUM", GardenGlyphs.VERSE_PREFIX + "lodestar", "")
    for option: Dictionary in BeautyContent.MOTE_VERSES:
        var key := String(option["key"])
        var selected := String(verse.get("key", "")) == key
        # Exclusive and free, like the verses: nobody owns a counter-melody.
        var mote_option: Dictionary = option.duplicate()
        mote_option["kind"] = "mote"
        var toggle := _ware_card(verse_shelf, mote_option, sparkles, selected, false, true, false,
            func(): mote_verse_requested.emit(key))
        toggle.name = key if not key.is_empty() else "mote_silence"

    _shop_frame.add_child(_centered_button("♥  Done — back to the walk", true, func(): close_shop()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)

## The gentler-forest panel.
##
## `return_name` is the screen this panel will hand the player back to, supplied
## by the director, which is the only place that knows. The panel is reachable
## from the menu, from the pause card and from Peddle's cart, so a hardcoded
## "the walk" was a promise this button could not keep in two of the three.
func show_settings(settings: Dictionary, return_name: String = "the walk") -> void:
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
        show_settings(_settings, return_name)
    )
    list.add_child(reset)
    # Reopening from Reset must carry the same destination as the panel the
    # player is already looking at, or the button would silently re-point itself
    # at "the walk" after being pressed from the menu or the cart.
    _shop_frame.add_child(_centered_button("♥  Back to %s" % return_name, true, func(): close_settings()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)

## Where closing this panel will actually put the player back.
##
## The director knows exactly which screen it will return the player to, and
## passes that name in, so this label and the real route cannot disagree the way
## a hardcoded "the walk" did -- from the menu there is no walk to go back to.
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

## Hide every scrim this class owns, plus the menu's. Raising one scrim from
## three different call sites meant a forgotten `visible = false` left the
## menu's light scrim under a panel, stacking two darkening rects on top of
## each other -- so `close_panels` clears all of them by name.
func close_panels() -> void:
    _menu_scrim.visible = false
    _shop_scrim.visible = false
    _shop_card.visible = false
    _overlay_scrim.visible = false
    _overlay_card.visible = false
    _beat_ring.visible = false
    _cancel_story()
    _reset_touch_joystick()
