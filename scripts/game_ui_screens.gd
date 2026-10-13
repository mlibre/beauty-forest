class_name GameUIScreens
extends "res://scripts/game_ui_panels.gd"
## The animated, joyful screens: menu, pause, nap, ending, the memory book --
## the ones that open into the overlay card. The full-screen panels (Peddle's
## cart, the gentler-forest options) live one file down, in GameUIPanels.

func show_menu(meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    set_text_chrome_visible(true)
    _show_menu_overlay()
    _overlay_content.add_child(_card_header("Beauty Forest", GardenGlyphs.LANTERN, "a gentle walk · thirty floors of forest below", 40))
    _overlay_content.add_child(_spacer(4))
    # The menu shows, never tells. One row of three pictures stands where a
    # paragraph of promises used to be; what each picture means is one hover
    # away, and the first ten seconds of play teach it better than words did.
    var promises := HBoxContainer.new()
    promises.alignment = BoxContainer.ALIGNMENT_CENTER
    promises.add_theme_constant_override("separation", 30)
    for promise: Array in [
        ["lantern", "The lantern sings all by itself — there is no attack button."],
        ["boots", "You just wander. No hurry, no losing."],
        ["heart", "Gifts, never fights. Leaving is always okay."],
    ]:
        var mark := _icon(String(promise[0]), 38, Color("#ffe497"))
        mark.tooltip_text = String(promise[1])
        promises.add_child(mark)
    _overlay_content.add_child(promises)
    _overlay_content.add_child(_spacer(8))
    # PLAY. One word, one picture, the biggest plate on the card.
    var start_button := _menu_button("Play", true, GardenGlyphs.LANTERN)
    start_button.custom_minimum_size = Vector2(320, 58)
    start_button.tooltip_text = "Start a gentle walk. You can leave anytime."
    start_button.pressed.connect(func(): play_pressed.emit())
    var start_center := CenterContainer.new()
    start_center.add_child(start_button)
    _overlay_content.add_child(start_center)
    _overlay_content.add_child(_spacer(4))
    # Flow (not HBox): on narrow windows the three style buttons wrap onto a
    # second row instead of overflowing the card. Each style is ONE picture
    # and its name — the old two-line buttons ("gentle / bumps hurt less")
    # made the shelf read like a form. The full description is a hover.
    var styles := HFlowContainer.new()
    styles.alignment = FlowContainer.ALIGNMENT_CENTER
    styles.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
    styles.add_theme_constant_override("hseparation", 10)
    styles.add_theme_constant_override("vseparation", 10)
    _overlay_content.add_child(_section_label("PICK A TRAIL"))
    _overlay_content.add_child(styles)
    var menu_style_marks := {
        "gentle": GardenGlyphs.SOUL,
        "standard": GardenGlyphs.LANTERN,
        "bold": GardenGlyphs.CHIME,
    }
    for key in ["gentle", "standard", "bold"]:
        var style: Dictionary = BeautyContent.STYLE_DATA[key]
        var picked: bool = key == _selected_style
        var button := _menu_button(String(style["name"]), picked, String(menu_style_marks[key]))
        button.custom_minimum_size = Vector2(158, 50)
        # A picked choice is not just tinted: the heart rides on the picture so
        # "which one is mine" is answerable without reading three names.
        if picked:
            var seal := _icon(GardenGlyphs.HEART, 16, Color("#ffd9e0"))
            seal.position = Vector2(button.custom_minimum_size.x - 22.0, 2.0)
            button.add_child(seal)
        button.tooltip_text = "%s — %s" % [String(style["name"]), String(style["description"])]
        button.pressed.connect(func():
            _selected_style = key
            style_picked.emit(key)
            show_menu(meta)
        )
        styles.add_child(button)
    _overlay_content.add_child(_spacer(4))
    # Options and Leave share a row of two half-width plates. "Leave" is the
    # honest word; the old caption ("Not now — keep my spot warm ♥") hid a
    # quit button inside a sentence, and a quit button that reads as a poem is
    # neither of those things. Flow, not HBox: on a 480px window the pair
    # wraps into two centred rows instead of inflating the card past the wall.
    var doors := HFlowContainer.new()
    doors.alignment = FlowContainer.ALIGNMENT_CENTER
    doors.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
    doors.add_theme_constant_override("hseparation", 10)
    doors.add_theme_constant_override("vseparation", 10)
    var comfort := _menu_button("Comfort options", false, GardenGlyphs.HEART)
    comfort.custom_minimum_size = Vector2(236, 46)
    comfort.tooltip_text = "Reduce hits, calm motion, and turn up the contrast — anytime."
    comfort.pressed.connect(func(): settings_open_requested.emit())
    doors.add_child(comfort)
    var leave := _menu_button("Leave", false, GardenGlyphs.CAMP)
    leave.custom_minimum_size = Vector2(146, 46)
    leave.tooltip_text = "No pressure. The forest keeps your spot warm."
    leave.pressed.connect(func(): quit_requested.emit())
    doors.add_child(leave)
    _overlay_content.add_child(doors)
    _overlay_content.add_child(_spacer(6))
    # The record: three pictures and their numbers, no words. What a number
    # counts is one hover away; on the screen, the shape of the walk reads at
    # a glance — boots walked, stairs reached, wisps hugged home.
    var record := HBoxContainer.new()
    record.alignment = BoxContainer.ALIGNMENT_CENTER
    record.add_theme_constant_override("separation", 18)
    for chip: Array in [
        ["boots", int(meta.get("runs", 0)), "Visits — walks begun"],
        [GardenGlyphs.STAIRS, int(meta.get("best_floor", 0)), "Deepest floor reached"],
        [GardenGlyphs.WISP, int(meta.get("wisps_soothed", 0)), "Wisps guided home"],
    ]:
        var chip_box := HBoxContainer.new()
        chip_box.add_theme_constant_override("separation", 6)
        chip_box.add_child(_icon(String(chip[0]), 20, Color("#cbdcb7")))
        var count := _label(str(int(chip[1])), 15, Color("#cbdcb7"))
        chip_box.add_child(count)
        var chip_tip := String(chip[2])
        count.tooltip_text = chip_tip
        (chip_box.get_child(0) as Control).tooltip_text = chip_tip
        record.add_child(chip_box)
    _overlay_content.add_child(_section_label("THE RECORD SO FAR"))
    _overlay_content.add_child(record)
    _fit_layout()
    # Refit AFTER building: the panels are authored at comfortable desktop
    # widths, and _refit_content can only clamp children that already exist.
    _focus_control(start_button)

## The level-up draft: Mote offers three gifts as three big glyph cards.
## A card is a picture AND its meaning at once: the glyph, the gift's name,
## and one line saying exactly what it does, all on the face. The figure used
## to live on a desktop-only hover, which made the whole choice unreadable on
## a phone; now nothing important needs a hover. The walk waits; nothing here
## hurries.
func show_draft(offers: Array, level: int, fact: String = "") -> void:
    _dismiss_beat_ring()
    _cancel_story()
    _reset_touch_joystick()
    _clear(_overlay_content)
    _hud.visible = true
    set_text_chrome_visible(true)
    _show_overlay()
    _overlay_content.add_child(_centered_label("Level %d — pick a gift" % level, 34, Color("#ffe6a0")))
    if not fact.is_empty():
        _overlay_content.add_child(_centered_label("Mote learned: “%s”" % fact, 15, Color("#cbdcb7")))
    _overlay_content.add_child(_spacer(8))
    var cards := HBoxContainer.new()
    cards.alignment = BoxContainer.ALIGNMENT_CENTER
    cards.add_theme_constant_override("separation", 16)
    for index in range(offers.size()):
        var offer: Dictionary = offers[index]
        var column := VBoxContainer.new()
        column.add_theme_constant_override("separation", 4)
        var card := _button(String(offer.get("word", "a gift")), index == 0)
        card.custom_minimum_size = Vector2(176, 118)
        card.icon = GardenGlyphs.get_glyph(String(offer.get("glyph", GardenGlyphs.HEART)))
        card.expand_icon = true
        card.add_theme_constant_override("icon_max_width", 56)
        card.tooltip_text = "%s  ·  press %d" % [String(offer.get("sub", "")), index + 1]
        var pick := func(): boon_picked.emit(String(offer.get("key", "")))
        card.pressed.connect(pick)
        column.add_child(card)
        var effect_label := _label(String(offer.get("sub", "")), 14, Color("#d8e6c0"))
        effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        effect_label.custom_minimum_size = Vector2(176, 0)
        column.add_child(effect_label)
        cards.add_child(column)
        # Each gift arrives a breath after the last, so the draft reads as
        # Mote dealing three cards rather than three things popping at once.
        if not _reduced_motion:
            column.modulate.a = 0.0
            var arrive := column.create_tween()
            arrive.tween_property(column, "modulate:a", 1.0, 0.24).set_delay(0.08 + index * 0.07) \
                .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _overlay_content.add_child(cards)
    _overlay_content.add_child(_centered_label("tap a card  ·  or press 1 · 2 · 3", 14, Color("#cbdcb7")))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

func show_pause(meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = true
    # Pausing is the ONE moment the player asks for information, so this is
    # where everything the icon HUD dropped comes back: level, song power, the
    # charm list and the control keys. Read on purpose, not while walking.
    set_text_chrome_visible(true)
    _show_overlay()
    _overlay_content.add_child(_card_header("Paused ♥", GardenGlyphs.HEART, "The forest waits for you."))
    _overlay_content.add_child(_spacer(10))
    _overlay_content.add_child(_walker_summary())
    _overlay_content.add_child(_spacer(14))
    _overlay_content.add_child(_centered_button("Keep wandering", true, func(): resume_requested.emit()))
    _overlay_content.add_child(_centered_button("Comfort options", false, func(): settings_open_requested.emit()))
    _overlay_content.add_child(_centered_button("Fresh walk", false, func(): restart_requested.emit(false)))
    # The title used to be a one-visit room: nothing anywhere returned to it,
    # so the style trails and the front door were reachable exactly once per
    # app launch. This is the way back.
    _overlay_content.add_child(_centered_button("Title screen", false, func(): menu_requested.emit()))
    _overlay_content.add_child(_centered_button("Leave", false, func(): quit_requested.emit()))
    _overlay_content.add_child(_spacer(10))
    _overlay_content.add_child(_keys_reference())
    _overlay_content.add_child(_centered_label("Deepest floor %d  ·  Wisps hugged home %d  ·  Fun facts %d" % [int(meta.get("best_floor", 0)), int(meta.get("wisps_soothed", 0)), int(meta.get("facts", 0))], 14, Color("#bdcea9")))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

## The stats the icon HUD dropped, as one block of pictures and numbers.
##
## The pause screen used to open into this summary AND into the two legacy word
## cards in the corners, so every figure was on screen twice: the card said
## "♥ Warmth 100 / 100" and the summary said "Warmth  100 / 100", side by side.
## The rows here now lead with the game's own glyph -- a lantern for warmth, a
## star for soul, a chime for song power, a stair for depth -- so a row is
## read as "this picture, this many" and the name is not repeated. What remains
## in words is the one thing no icon can say: the sentence naming what the
## glowing waypoint is pointing at.
##
## No fixed width: the block used to ask for 560px, which is wider than a 480px
## window, so the pause card grew to 533px and hung 26px off the left edge. The
## rows autowrap and the responsive pass clamps them to the card instead.
func _walker_summary() -> Control:
    # Every row NAMES its figure now. The glyphs carry the shape, but a glyph
    # alone taught the vocabulary only to players who already knew it: "warmth"
    # and "song" are this game's own nouns for health and damage, and the pause
    # card is the one place a player reads on purpose, so the words live here.
    var rows: Array = [
                [GardenGlyphs.LANTERN, "Warmth %d / %d" % [_walker_hp, _walker_hp_max]],
                [GardenGlyphs.SOUL, "Level %d  ·  %d / %d soul to next" % [_walker_level, _walker_xp, _walker_xp_next]],
                [GardenGlyphs.CHIME, "Song power %d" % _walker_song],
                # Sparkles live here now because this is their only home. They used to
                # be spoken only by the corner card this block replaced, and deleting
                # that card without adding the row took the player's spending money off
                # every screen that could show it.
                [GardenGlyphs.SPARKLE, "Sparkles %d" % _walker_sparkles],
        ]
    # Depth: a stair glyph and the floor, because the floor's name is the only
    # part no picture carries. The forecast that used to sit in the corner card
    # as a sentence nothing ever updated lives here instead, once.
    if not _walker_region.is_empty():
        rows.append([GardenGlyphs.STAIRS, "Floor %d  ·  %s" % [_walker_floor, _walker_region]])
        if not _walker_forecast.is_empty():
            rows.append([GardenGlyphs.MOTE, _walker_forecast])
    if not _walker_objective.is_empty():
        rows.append([GardenGlyphs.SHIELD, _walker_objective])
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for row: Array in rows:
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 10)
        line.add_child(_icon(String(row[0]), 24, Color("#ffe497")))
        var value_label := _label(String(row[1]), 15, Color("#fff0c8"))
        value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        line.add_child(value_label)
        box.add_child(line)
    # The worn charms are pictures already: the same icons the play screen shows
    # in its sockets, so the pause card confirms a loadout at a glance instead of
    # listing it as a sentence.
    if not _walker_charms.is_empty():
        var charm_row := HBoxContainer.new()
        charm_row.add_theme_constant_override("separation", 6)
        for glyph_key: String in _walker_charm_glyphs():
            charm_row.add_child(_icon(glyph_key, 26))
        box.add_child(charm_row)
    return box

## The control keys, which the play screen no longer shows.
func _keys_reference() -> Control:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # One action key: E answers whatever the hero stands beside — hug, sing,
    # wish, descend, and Peddle's cart too (the walk itself says so with a
    # little "E · Descend" hint at the bottom of the screen, and F still
    # opens the cart for hands that learned it first). On a touchscreen the
    # same hint lights the action button, and the dash is a double-tap on
    # the stick — the thumb never has to leave home to hop.
    var keys := _label("Wander: WASD / arrows / stick  ·  Dash: Shift (touch: double-tap the stick)  ·  Everything nearby: E (cart: F too)  ·  Memories: J  ·  Comfort options: C  ·  Pause: Esc", 13, Color("#cbdcb7"))
    keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(keys)
    return box

## A run's tally as glyphs and digits, the same shape as the pause card's
## summary. Shared by the nap card and the ending so neither invents its own.
##
## A row is `[glyph, value]` or `[label, glyph, value]`. The three-part form
## exists for figures where the glyph is honest but ambiguous: both floor rows
## carry a stair, because a stair means depth, but "4" beside a stair does not
## say whether it is the floor you reached or the deepest you ever found. Naming
## the figure in three characters is cheaper than making a player remember which
## row they are on.
##
## The ending used to say "Dragons tucked in: N · Wisps hugged home: N · Fun
## facts: N" and the nap "You reached floor N. Every wisp you hugged home is
## still warm." -- the same three figures, in sentences, on the two screens a
## player looks at most carefully in a whole run. They are now rows: a glyph,
## then the number. What the pictures cannot carry stays in words, and stays
## short.
func _tally_rows(rows: Array) -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for row: Array in rows:
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 10)
        line.alignment = BoxContainer.ALIGNMENT_CENTER
        var offset := 0
        if row.size() == 3:
            var caption := _label(String(row[0]), 15, Color("#cbdcb7"))
            caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            line.add_child(caption)
            offset = 1
        line.add_child(_icon(String(row[offset]), 26, Color("#ffe497")))
        var value_label := _label(String(row[offset + 1]), 17, Color("#fff0c8"))
        value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        line.add_child(value_label)
        box.add_child(line)
    return box

func show_death(floor_number: int, meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    _beat_ring.visible = false
    _show_overlay()
    _overlay_content.add_child(_card_header("You took a soft nap ♥", GardenGlyphs.MOTE, "Mote tucked your lantern away. Nobody is cross, and the forest waits."))
    _overlay_content.add_child(_spacer(12))
    # Both rows are floors, so they carry the same glyph rather than a stair beside
    # a lantern -- a lantern is warmth, and printing one next to a depth number
    # would say the wrong thing in a picture. The words "Reached" and "Deepest"
    # are the one part no glyph pair carries, so they stay, as labels rather than
    # a sentence: which figure is which.
    _overlay_content.add_child(_tally_rows([
        ["Reached", GardenGlyphs.STAIRS, "%d" % floor_number],
        ["Deepest", GardenGlyphs.STAIRS, "%d" % int(meta.get("best_floor", 0))],
    ]))
    _overlay_content.add_child(_spacer(4))
    _overlay_content.add_child(_centered_label("Every wisp you hugged home is still warm.", 16, Color("#fff0c8")))
    _overlay_content.add_child(_spacer(18))
    _overlay_content.add_child(_centered_button("Wander again", true, func(): restart_requested.emit(false)))
    _overlay_content.add_child(_centered_button("Leave", false, func(): quit_requested.emit()))
    _overlay_content.add_child(_centered_label("Visits %d" % int(meta.get("runs", 0)), 14, Color("#bdcea9")))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

func show_ending(dragons: int, meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    _beat_ring.visible = false
    _show_overlay()
    _overlay_content.add_child(_card_header("The dragons are snuggled ♥", GardenGlyphs.DRAGON, "Snoozle’s family sleeps in a warm heap."))
    _overlay_content.add_child(_centered_label("Far below, one enormous cousin yawns: ‘More lullabies when you’re ready.’", 18, Color("#e9f0d4")))
    _overlay_content.add_child(_spacer(12))
    _overlay_content.add_child(_tally_rows([
        [GardenGlyphs.DRAGON, "%d" % dragons],
        [GardenGlyphs.HEART, "%d" % int(meta.get("wisps_soothed", 0))],
        # The facts row carried the CHIME, the icon every other screen uses
        # for song power; facts live in Mote's memory book, so the book is
        # the honest mark here too.
        [GardenGlyphs.BOOK, "%d" % int(meta.get("facts", 0))],
    ]))
    _overlay_content.add_child(_spacer(18))
    var deeper := _centered_button("Wander deeper", true, func(): restart_requested.emit(true))
    deeper.tooltip_text = "The forest grew one floor deeper, just for you."
    _overlay_content.add_child(deeper)
    _overlay_content.add_child(_centered_button("Until next time", false, func(): quit_requested.emit()))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

func show_journal(meta: Dictionary, facts_learned: Array, stickers: Array) -> void:
    _present_panel()
    _shop_frame.add_child(_card_header("Mote’s memory book ♥", GardenGlyphs.BOOK, "Fun facts and stickers you collected. Just for smiles — never a test."))
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
            list.add_child(_label("✦ " + BeautyContent.sticker_name(sticker), 16, Color("#ffe8a2")))
    list.add_child(_section_label("YOUR KINDNESS SO FAR ♥"))
    list.add_child(_label("Walks: %d    Deepest floor: %d    Wisps hugged home: %d    Dragons tucked in: %d" % [int(meta.get("runs", 0)), int(meta.get("best_floor", 0)), int(meta.get("wisps_soothed", 0)), int(meta.get("dragons_sung", 0))], 16, Color("#dce9c4")))
    _shop_frame.add_child(_centered_button("Close the book", true, func(): close_journal()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)
