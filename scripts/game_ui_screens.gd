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
    var title := _label("Beauty Forest", 46, Color("#ffe6a0"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_content.add_child(title)
    var subtitle := _label("a gentle walk — no hurry, no losing ♥", 20, Color("#dcebbd"))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_content.add_child(subtitle)
    _overlay_content.add_child(_spacer(4))
    # The three things a new player has to know are SHOWN, not described: the
    # title promises a gentle walk, the style shelf says how gentle, and the
    # first floor's lantern sings by itself with no attack button to find. The
    # paragraph that used to sit here ("Your lantern sings all by itself. You
    # just wander, cuddle lost wisps home, and pick kind gifts. There is no
    # attack button. Leaving anytime is always okay.") and the numbered "How it
    # feels: 1 wander 2 lantern sings 3 choose a kind gift" line explained all
    # of that in 37 words -- a wall of prose on the first screen, for mechanics
    # the player discovers in the first ten seconds anyway. The one thing prose
    # carried that pictures do not -- that leaving is always okay -- is a hover.
    #
    # Instead: a picture of how it plays. Three glyphs in a row, each saying one
    # thing, so the menu shows its own promise rather than describing it.
    var promises := HBoxContainer.new()
    promises.alignment = BoxContainer.ALIGNMENT_CENTER
    promises.add_theme_constant_override("separation", 26)
    for promise: Array in [
        ["lantern", "it sings itself"],
        ["boots", "you just wander"],
        ["heart", "gifts, never fights"],
    ]:
        var picture := VBoxContainer.new()
        picture.add_theme_constant_override("separation", 4)
        var mark := _icon(String(promise[0]), 42, Color("#ffe497"))
        mark.tooltip_text = String(promise[1])
        var word := _centered_label(String(promise[1]), 13, Color("#d8e9bd"))
        picture.add_child(mark)
        picture.add_child(word)
        promises.add_child(picture)
    _overlay_content.add_child(promises)
    _overlay_content.add_child(_spacer(6))
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
    # Short second lines only, and they are captions under a picture rather
    # than a sentence beside it: the longer copy ("Extra cozy · bumps hurt
    # less") pushed each button past 280px wide, so the flow container wrapped
    # the three style choices onto three separate rows and the menu needed 798px
    # of height inside a 564px panel -- which put the "Wander into the forest"
    # button, the single most important thing on the screen, below the fold on a
    # default 1280x720 window. The full description is one hover away.
    #
    # Each choice leads with a glyph so the shelf reads as three pictures you
    # pick between, not three sentences you read. The heart marks the picked
    # one, which is what the old "♥ " prefix was doing with a character.
    var menu_style_descriptions := {
        "gentle": "bumps hurt less",
        "standard": "just right",
        "bold": "more soul-light",
    }
    var menu_style_marks := {
        "gentle": GardenGlyphs.SOUL,
        "standard": GardenGlyphs.LANTERN,
        "bold": GardenGlyphs.CHIME,
    }
    for key in ["gentle", "standard", "bold"]:
        var style: Dictionary = BeautyContent.STYLE_DATA[key]
        var picked: bool = key == _selected_style
        var button := _button("%s%s\n%s" % [("♥ " if picked else ""), style["name"], String(menu_style_descriptions[key])], picked)
        button.custom_minimum_size = Vector2(212, 66)
        button.icon = GardenGlyphs.get_glyph(String(menu_style_marks[key]))
        button.expand_icon = true
        # A picked choice is not just tinted: the heart rides on the picture so
        # "which one is mine" is answerable without reading three names.
        if picked:
            var seal := _icon(GardenGlyphs.HEART, 16, Color("#ffd9e0"))
            seal.position = Vector2(button.custom_minimum_size.x - 20.0, 2.0)
            button.add_child(seal)
        button.tooltip_text = "%s — %s. Then press Wander below." % [String(style["name"]), String(style["description"])]
        button.pressed.connect(func():
            _selected_style = key
            style_picked.emit(key)
            show_menu(meta)
        )
        styles.add_child(button)
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
    # The record line was "Visits N · Deepest floor N · Wisps guided home N" with
    # the whole control scheme welded onto its second line -- 148 characters,
    # the single largest block of text on the menu, and a sentence the pause card
    # was already painting in _keys_reference(). The same controls, said twice in
    # one game, in the one place a player most likely to read only half of it.
    #
    # It lives on the pause card now, which is also where it belongs: those are
    # walk-screen controls, the player opens that card deliberately, and AGENTS.md
    # keeps full run state there rather than on the title screen.
    var record := "Visits %d  ·  Deepest floor %d  ·  Wisps guided home %d" % [
        int(meta.get("runs", 0)), int(meta.get("best_floor", 0)), int(meta.get("wisps_soothed", 0))]
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
    # The menu's own key line advertises "Comfort options: C", but nothing here
    # emitted settings_open_requested, so C (and any player who reads the line)
    # had no way to reach the gentler-forest panel before starting: zero entry
    # points on this screen. Offer it here, next to the leave button it pairs
    # with, and let the director hand the menu back on close.
    var comfort := _button("Comfort options ♥", false)
    comfort.custom_minimum_size = Vector2(300, 44)
    comfort.tooltip_text = "Reduce hits, calm the wobble, and turn up the contrast before you begin."
    comfort.pressed.connect(func(): settings_open_requested.emit())
    var comfort_center := CenterContainer.new()
    comfort_center.add_child(comfort)
    _overlay_content.add_child(comfort_center)
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
    _overlay_content.add_child(_centered_label("Level %d — Mote offers three gifts" % level, 34, Color("#ffe6a0")))
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
    _overlay_content.add_child(_centered_label("The forest waits — tap a card, or press 1 · 2 · 3.", 15, Color("#cbdcb7")))
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
    _overlay_content.add_child(_centered_label("Take a breath ♥", 38, Color("#ffe6a0")))
    _overlay_content.add_child(_centered_label("Paused — the forest waits for you. Nothing hurries here.", 17, Color("#dce9c2")))
    _overlay_content.add_child(_spacer(10))
    _overlay_content.add_child(_walker_summary())
    _overlay_content.add_child(_spacer(14))
    _overlay_content.add_child(_centered_button("♥  Keep wandering", true, func(): resume_requested.emit()))
    _overlay_content.add_child(_centered_button("Comfort options ♥", false, func(): settings_open_requested.emit()))
    _overlay_content.add_child(_centered_button("Start a fresh walk", false, func(): restart_requested.emit(false)))
    # The title used to be a one-visit room: nothing anywhere returned to it,
    # so the style trails and the front door were reachable exactly once per
    # app launch. This is the way back.
    _overlay_content.add_child(_centered_button("Rest at the title ♥", false, func(): menu_requested.emit()))
    _overlay_content.add_child(_centered_button("Leave for now ♥", false, func(): quit_requested.emit()))
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
    var keys := _label("Wander: WASD / arrows / stick  ·  Dash: Shift  ·  Hug, sing, wish & descend: E  ·  Cart: F  ·  Memories: J  ·  Comfort options: C  ·  Pause: Esc", 13, Color("#cbdcb7"))
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
    _overlay_content.add_child(_centered_label("You took a soft nap ♥", 42, Color("#ffe6a0")))
    # "Mote tucked your lantern into a mossy pocket. No one is cross. The forest
    # will be here when you wake." was 95 characters of reassurance. It is also
    # the only thing on this screen saying the run is not a failure -- so it
    # stays, but it says it in one sentence instead of three.
    _overlay_content.add_child(_centered_label("Mote tucked your lantern away. Nobody is cross, and the forest waits.", 18, Color("#e9f0d4")))
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
    _overlay_content.add_child(_centered_button("♥  Wake up & wander again", true, func(): restart_requested.emit(false)))
    _overlay_content.add_child(_centered_button("Rest a little longer", false, func(): quit_requested.emit()))
    _overlay_content.add_child(_centered_label("Visits %d" % int(meta.get("runs", 0)), 14, Color("#bdcea9")))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

func show_ending(dragons: int, meta: Dictionary) -> void:
    _clear(_overlay_content)
    _hud.visible = false
    _beat_ring.visible = false
    _show_overlay()
    _overlay_content.add_child(_centered_label("The dragons are snuggled ♥", 42, Color("#ffe6a0")))
    # Snoozle's cousin yawning "more lullabies when you're ready" is the moment,
    # and it is one sentence rather than a paragraph. The follow-up line about
    # the forest growing a floor deeper was a second promise on top of it; it is
    # now the hover on the button that makes it.
    _overlay_content.add_child(_centered_label("Snoozle’s family sleeps in a warm heap. Far below, one enormous cousin yawns: ‘More lullabies when you’re ready.’", 18, Color("#e9f0d4")))
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
    var deeper := _centered_button("♥  Wander deeper", true, func(): restart_requested.emit(true))
    deeper.tooltip_text = "The forest grew one floor deeper, just for you."
    _overlay_content.add_child(deeper)
    _overlay_content.add_child(_centered_button("Until next time ♥", false, func(): quit_requested.emit()))
    _fit_layout()
    _focus_first_enabled(_overlay_content)

func show_journal(meta: Dictionary, facts_learned: Array, stickers: Array) -> void:
    _present_panel()
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
            list.add_child(_label("✦ " + BeautyContent.sticker_name(sticker), 16, Color("#ffe8a2")))
    list.add_child(_section_label("YOUR KINDNESS SO FAR ♥"))
    list.add_child(_label("Walks: %d    Deepest floor: %d    Wisps hugged home: %d    Dragons tucked in: %d" % [int(meta.get("runs", 0)), int(meta.get("best_floor", 0)), int(meta.get("wisps_soothed", 0)), int(meta.get("dragons_sung", 0))], 16, Color("#dce9c4")))
    _shop_frame.add_child(_centered_button("♥  Close my book", true, func(): close_journal()))
    _fit_layout()
    _focus_first_enabled(_shop_frame)
