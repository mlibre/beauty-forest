class_name GameUIPanels
extends "res://scripts/game_ui_layout.gd"
## The panel scaffolding and the two full-screen shelf panels -- Peddle's
## cart and the memory book -- plus the closers that put every panel away.
## The gentler-forest options live one file up, in GameUISettings, which
## builds on the scaffolding this file owns.
##
## Split out of GameUIScreens. These panels are the only screens that open
## into the reusable shop card rather than the overlay card, they all close the
## same way, and their rows need the same two helpers. Keeping them together is
## what lets GameUIScreens stay a file about the story screens.
##
## Peddle's cart is a SHELF of picture cards, not a list of sentences: every
## ware gets a CozyCard that says what it is in ink (icon, lit rim, sparkle
## price) and keeps only its own name and price digits as words. That is the
## single biggest text win in the game -- the cart used to paint ~100 labels
## and now paints one name per ware.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyCard := preload("res://scripts/cozy_card.gd")

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
    heading.add_child(_icon(glyph_key, 20, Color("#ffe497")))
    heading.add_child(_label(title, 15, Color("#ffe497")))
    if not count.is_empty():
        heading.add_child(_label(count, 15, Color("#fff0c8")))
    if not worn_of.is_empty():
        heading.add_child(_label("· %s" % worn_of, 13, Color("#bcd2a8")))
    var grid := GridContainer.new()
    # Picture-cards to a row, fitted to the window: a GridContainer never
    # wraps, so a fixed column count either wasted the shelf on wide windows
    # or clipped its last column off narrow ones -- five 138px cards plus
    # separations need 730px, and a 480px window's shelf has ~370. The
    # viewport decides, between two (the smallest shelf that still reads as
    # a shelf) and five.
    var card_pitch := 148.0
    var window := get_viewport().get_visible_rect().size.x if get_viewport() != null else 1280.0
    var shelf_width := minf(900.0, window * 0.94) - MODAL_MARGIN_X - 8.0
    grid.columns = clampi(int(shelf_width / card_pitch), 2, 5)
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
func _ware_card(grid: GridContainer, item: Dictionary, sparkles: int, worn: bool, is_owned: bool, free_item: bool, slots_full: bool, pressed: Callable, can_use: bool = true) -> CozyCard:
    var price := int(item.get("price", 0))
    # "Affordable" means the press can actually DO something right now: a price
    # the purse can meet, and -- for tea at full warmth -- a heal that is still
    # needed. A ware that fails either is dimmed rather than hidden, so the
    # player can still see what they are saving toward.
    var affordable := can_use and (is_owned or free_item or price <= sparkles)
    var key := String(item.get("key", ""))
    var button := Button.new()
    # The ware's key, on both the button and its card. A row used to be found by
    # scraping the words it painted; now the words are ink, so the node has to
    # carry the identity itself -- and so do the suites that assert on it.
    button.name = key if not key.is_empty() else "mote_silence"
    var card := CozyCard.new()
    card.name = button.name
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
    return card

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
        # With every socket taken the tap waits rather than adding, and "tap to
        # wear" would be a small lie.
        var swap_note := " Tap to wear it — wander deeper if every socket is full." if slots_full else " Tap to wear it."
        return "%s — already yours.%s" % [what, swap_note]
    if slots_full:
        return "%s — every socket is full, so this waits in your pocket until you go deeper." % what
    if card.price > 0 and not card.affordable:
        var short := card.price - sparkles
        return "You need %d sparkles — soothe %d more wisp%s. It will keep. ♥" % [
            card.price, short, "" if short == 1 else "s"]
    return what

## The next tier of `key` the hero does not own yet, or 0 when it owns them all.
func _next_tier(owned: Array, key: String) -> int:
    return BeautyData.next_tier(owned, key)

func _owns(owned: Array, key: String, tier: int) -> bool:
    return BeautyData.owns(owned, key, tier)

func _wearing(equipped: Array, key: String, tier: int) -> bool:
    return BeautyData.wearing(equipped, key, tier)

func _present_panel() -> void:
    # Every panel over the walk opens the same way: the transient effects go,
    # the card rises, it lays itself out empty. One home, so a panel can never
    # forget a step and stack a fresh shelf over a stale story. The context
    # pill is one of those transients: it draws above the scrim, so a panel
    # that left it up would float "E · Peddle's cart" over the shop itself
    # until the director's next slow tick noticed.
    _dismiss_beat_ring()
    _cancel_story()
    _reset_touch_joystick()
    if _context_hint != null and is_instance_valid(_context_hint):
        _context_hint.visible = false
    _context_hint_verb = ""
    _shop_scrim.visible = true
    _shop_card.visible = true
    _fit_layout()
    _clear_panel()

func _retire_panel() -> void:
    # The mirror of _present_panel: the card and its scrim leave together.
    _shop_scrim.visible = false
    _shop_card.visible = false

func show_shop(state: Dictionary) -> void:
    _present_panel()
    var sparkles := int(state.get("sparkles", 0))
    var list := _panel_list(12)
    # The heading rides INSIDE the scroll, not pinned above it: a pinned
    # header demands its own height from a card whose window may not have it
    # (200% text on a short window pushed the settings card straight off the
    # top edge), and a title the player can scroll to is worth more than a
    # title that shoves the close button off the glass. The close button
    # stays pinned -- that is the one thing that must always be reachable.
    var heading := HBoxContainer.new()
    heading.add_theme_constant_override("separation", 10)
    list.add_child(heading)
    heading.add_child(_icon(GardenGlyphs.CART, 26, Color("#ffe49b")))
    var title := _label("Peddle’s cart ♥", 30, Color("#ffe49b"))
    title.theme_type_variation = "HeadingLabel"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title)
    # The purse is a sparkle and a number, not "12 to spend" -- the icon beside
    # the digits already says what they are.
    heading.add_child(_icon(GardenGlyphs.SPARKLE, 22, Color("#ffe987")))
    heading.add_child(_label(str(sparkles), 22, Color("#ffe987")))
    list.add_child(_separator())

    # Warm tea: one ware, so it gets a shelf of its own only because it is
    # bought constantly and heals. Spending sparkles on tea while already warm
    # used to be a silent no-op -- the button was live, the price was charged
    # and nothing happened -- so the card dims at full warmth and the hover
    # says why.
    var warmth_full := float(state.get("hp", 0.0)) >= float(state.get("hp_max", 1.0))
    var tea_shelf := _shelf(list, "WARM TEA", "tea", "")
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) != "tea":
            continue
        var tea := _ware_card(tea_shelf, charm, sparkles, false, false, false, false,
            func(): buy_requested.emit("tea"), not warmth_full)
        if warmth_full:
            (tea.get_parent() as Button).tooltip_text = "You are warm as a toast already — keep these sparkles for a charm ♥"

    var owned: Array = state.get("owned", [])
    var equipped: Array = state.get("charms", [])
    var capacity := int(state.get("capacity", 1))
    var slots_full := equipped.size() >= capacity
    # The heading carries the count, so it never has to be read off a sentence:
    # a gold rim on a card is "wearing", and this is how many there are. The
    # second number is the ROOM -- a deeper walk opens more sockets, and saying
    # so on the cart is what turns a full shelf from a dead end into an
    # invitation to go further down.
    var charm_shelf := _shelf(list, "WORN CHARMS", "scarf", "%d/%d" % [
        equipped.size(), capacity])
    for charm: Dictionary in BeautyContent.CHARMS:
        var key := String(charm["key"])
        if key == "tea":
            continue
        # A charm can be owned twice, and the second copy is the same ware made
        # stronger. So the card offers the DEEPEST copy the hero does not own --
        # but never at the cost of being a dead button. An owned charm that the
        # purse cannot afford the deeper copy of must still offer its own copy
        # to wear or rest, because that press is free and the player has earned
        # it. Choosing the best AVAILABLE action, rather than the best possible
        # one, is what keeps a full purse from looking like a dead shelf.
        var offered_tier := _next_tier(owned, key)
        if offered_tier == 0:
            # Every copy is owned, so there is nothing left to buy: the card
            # offers the DEEPEST one, which is the ware worth wearing or
            # resting. Falling back to tier 1 here would leave a hero wearing
            # two Swift Boots looking at the weak one's card.
            offered_tier = maxi(1, BeautyContent.TIER_SCALES.size() - 1)
        if not _owns(owned, key, offered_tier) and _owns(owned, key, 1) \
                and BeautyContent.charm_price(key, offered_tier) > sparkles:
            # The deeper copy exists and is wanted, but this purse cannot reach
            # it. Offer the copy the hero DOES have, because wearing and
            # resting it is free and never a dead press.
            offered_tier = 1
        var is_owned := _owns(owned, key, offered_tier)
        var worn := is_owned and _wearing(equipped, key, offered_tier)
        var offered := charm.duplicate(true)
        offered["tier"] = offered_tier
        offered["name"] = BeautyContent.charm_label(key, offered_tier)
        offered["description"] = BeautyContent.charm_blurb(key, offered_tier)
        offered["price"] = BeautyContent.charm_price(key, offered_tier)
        # An owned charm toggles wear; an unowned one buys. Which of the two it
        # is has to be visible before the press, so the card's tooltip leads
        # with it and the rim only ever answers "am I wearing it".
        _ware_card(charm_shelf, offered, sparkles, worn, is_owned, false, slots_full,
            func():
                if is_owned:
                    charm_equip_requested.emit(key, offered_tier)
                else:
                    buy_requested.emit(key))

    var stanzas: Dictionary = state.get("stanzas", {})
    # Verses cost nothing and there is no purse to stop them, so the count is
    # simply how many are being hummed -- with no ceiling to print. A "2/2" here
    # taught the player that songs had a cap they had already reached, and sent
    # them to the rest of the cart for the upgrades they needed.
    var humming := 0
    for is_on: Variant in stanzas.values():
        if bool(is_on):
            humming += 1
    var stanza_shelf := _shelf(list, "LANTERN SONGS", GardenGlyphs.STANZA_PREFIX + "petals",
        str(humming) if humming > 0 else "")
    for stanza: Dictionary in BeautyContent.STANZAS:
        var key := String(stanza["key"])
        # Stanzas share keys with charms (`moss`, `lullaby`), so the card can
        # only paint the song glyph when it knows which table the key is for.
        var stanza_item := stanza.duplicate()
        stanza_item["kind"] = "verse"
        _ware_card(stanza_shelf, stanza_item, sparkles,
            bool(stanzas.get(key, false)), false, true, false, func(): stanza_equip_requested.emit(key))

    var verse: Dictionary = state.get("mote_verse", {})
    var verse_shelf := _shelf(list, "MOTE’S HUM", GardenGlyphs.VERSE_PREFIX + "lodestar", "")
    for option: Dictionary in BeautyContent.MOTE_VERSES:
        var key := String(option["key"])
        var selected := String(verse.get("key", "")) == key
        # Exclusive and free, like the verses: nobody owns a counter-melody.
        var mote_option: Dictionary = option.duplicate()
        mote_option["kind"] = "mote"
        _ware_card(verse_shelf, mote_option, sparkles, selected, false, true, false,
            func(): mote_verse_requested.emit(key))

    _shop_frame.add_child(_centered_button("Back to the walk", true, func(): close_shop()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)

func close_shop() -> void:
    _retire_panel()
    shop_closed.emit()

func close_journal() -> void:
    _retire_panel()
    journal_closed.emit()

func close_settings() -> void:
    _retire_panel()
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
    # A panel opening owns the whole screen; a "press E" hint about a world
    # the player cannot currently touch is a stale promise left floating.
    # The pill's vars live on the base class, so this hides it directly --
    # show_context_hint() belongs to the fullest subclass and a base cannot
    # call a method its subclass defines.
    if _context_hint != null and is_instance_valid(_context_hint):
        _context_hint.visible = false
    _context_hint_verb = ""
