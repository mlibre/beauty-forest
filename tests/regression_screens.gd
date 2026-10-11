extends "res://tests/support/test_case.gd"
## What the screens SAY about a run, as opposed to what the run does.
##
## The pause menu's stat cards, the sentence naming what the glowing waypoint
## points at, and the sticker a run of curious wisps is supposed to be able to
## win. Each of these was once a lie the game told: frozen placeholder numbers,
## a fixed "go to the stair" on floors with no stair, and a sticker the counter
## handed to the first ten level-ups instead.
##
## Split out of regression_main_flow.gd, which is about run-state transitions.
##
## The bodies moved verbatim from regression_main_flow.gd; only the helper names
## changed, to the ones on TestCase.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyData := preload("res://scripts/beauty_data.gd")
const BeautyLore := preload("res://scripts/beauty_lore.gd")
const CozyWaypoint := preload("res://scripts/cozy_waypoint.gd")
const CozyVitals := preload("res://scripts/cozy_vitals.gd")
const BeautyContent := preload("res://scripts/beauty_content.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_SCREENS"
    TestProfile.begin("screens")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)

    if not await _check_the_next_step_names_the_real_target(game):
        return
    if not await _check_the_pause_summary_shows_the_real_run(game):
        return
    if not await _check_curious_wisp_facts_can_win_the_sticker(game):
        return
    if not await _check_the_menu_paints_no_walk_marker(game):
        return
    if not await _check_a_menu_pick_is_the_run_that_starts(game):
        return
    if not await _check_a_restart_silences_old_toasts(game):
        return
    if not await _check_menu_backdrop_wisps_are_alive(game):
        return

    if not await _check_stanza_cards_paint_song_glyphs(game):
        return
    if not await _check_colliding_sockets_keep_their_own_art(game):
        return
    if not await _check_every_worn_ware_gets_a_socket(game):
        return
    finish(game, "BEAUTY_FOREST_SCREENS")

func _check_the_next_step_names_the_real_target(game: Node) -> bool:
    ## The pause screen's corner card read "Wander toward the glowing stair" on
    ## every floor, because nothing ever wrote _objective_label. But the game
    ## picks its waypoint target through a six-step priority -- Snoozle, a Big
    ## Feeling, a chime, Peddle's cart, then the stair -- and on a dragon floor
    ## the stairwell is deliberately hidden (stair_visible = false). So on those
    ## floors the one screen a player pauses on pointed them at a stairwell that
    ## is not in the room. The words now come from the same branch that aims the
    ## glow, so the sentence and the marker cannot disagree.
    for floor_num: int in [1, 2, 5]:
        game._start_run(floor_num)
        await frames(8)
        game._pause_game()
        await frames(4)
        var said: String = game.ui._walker_objective
        if said.is_empty():
            return ok(false, "floor %d named no next step at all" % floor_num)
        # Whichever target this floor really has, the sentence must not be the
        # stair one -- unless the stair is genuinely what the glow is over.
        if game.dragon_exists and said.contains("glowing stair"):
            return ok(false, "on dragon floor %d the pause menu sent the player to a stairwell that is hidden" % floor_num)
        if floor_num == 2 and game.merchant_exists and said.contains("glowing stair"):
            return ok(false, "on merchant floor %d the pause menu ignored Peddle's cart" % floor_num)
        if floor_num == 1 and not said.contains("glowing stair"):
            return ok(false, "on a plain floor the pause menu stopped naming the stair: '%s'" % said)
        game._resume_game()
        await frames(3)
    return true

func _check_the_menu_paints_no_walk_marker(game: Node) -> bool:
    ## The title floor promised "no wisps-turned-objectives, nothing glowing"
    ## but never cleared stair_visible, so the walk waypoint spawned and parked
    ## itself on an invisible stairwell through the whole menu.
    game.mode = game.Mode.MENU
    game._load_floor(1, true)
    await frames(8)
    # find_children's type string resolves through ClassDB, where script classes
    # exist only with a warm editor cache -- on a cold or stale boot "CozyWaypoint"
    # would match nothing and this check would pass for the wrong reason. Walk
    # everything and cast instead: `is` is decided at compile time, no cache.
    var beacons: Array = []
    for child in game.world.find_children("*", "", true, false):
        if child is CozyWaypoint:
            beacons.append(child)
    if not ok(beacons.is_empty(), "a walk marker showed during the menu"):
        return false
    if not ok(game.ui._walker_objective.is_empty(),
            "the menu parked a walk objective: %s" % game.ui._walker_objective):
        return false
    if not ok(not game.stair_visible,
            "the title floor still counts its hidden stairwell as an objective"):
        return false
    return true

    game.mode = game.Mode.MENU
    game._load_floor(1, true)
    await frames(4)
    return true

func _check_a_menu_pick_is_the_run_that_starts(game: Node) -> bool:
    ## Clicking "gentle" repainted the menu heart but said nothing to the run:
    ## Enter started the OLD selected_style, and the pick was never kept.
    game.mode = game.Mode.MENU
    await frames(2)
    game.selected_style = "standard"
    game.ui.style_picked.emit("gentle")
    await frames(2)
    if not ok(game.selected_style == "gentle",
            "picking a trail on the menu did not move the run state: %s" % game.selected_style):
        return false
    game._start_run(1)
    await frames(4)
    if not ok(is_equal_approx(game.hp_max, 115.0),
            "a gentle start should carry +15 warmth, got %.0f" % game.hp_max):
        return false
    game.mode = game.Mode.MENU
    game._load_floor(1, true)
    await frames(2)
    game.selected_style = "standard"
    game.ui.set_selected_style("standard")
    await frames(2)
    return true

func _check_a_restart_silences_old_toasts(game: Node) -> bool:
    ## Toasts queued on the old run kept trickling in over the nap card and the
    ## fresh floor, promising things that had already happened elsewhere.
    game._start_run(2)
    await frames(4)
    game.ui.show_toast("a toast from the old walk")
    game.ui.show_toast("and another one")
    game._start_run(1)
    await frames(4)
    var stale := 0
    for entry: Dictionary in game.ui._toast_queue:
        if String(entry.get("message", "")).contains("old walk") or String(entry.get("message", "")).contains("another one"):
            stale += 1
    if not ok(stale == 0,
            "old toasts survived a fresh start: %s" % [game.ui._toast_queue]):
        return false
    if not ok(not game.ui._toast_label.text.contains("old walk") and not game.ui._toast_label.text.contains("another one"),
            "a stale toast label stayed painted after the restart: %s" % game.ui._toast_label.text):
        return false
    return true

func _check_menu_backdrop_wisps_are_alive(game: Node) -> bool:
    ## The title floor spawns "wandering wisps... just drift near the spawn",
    ## but nothing ever called tick_behavior on the menu: they rendered frozen
    ## at a quarter of their pop-in scale behind the title card.
    game.mode = game.Mode.MENU
    game._load_floor(1, true)
    await frames(4)
    if game.wisps.is_empty():
        return ok(false, "no backdrop wisps spawned on the title floor")
    var awake: int = 0
    for wisp in game.wisps:
        if wisp._spawn_pop < 1.0:
            awake += 1
    if not ok(awake > 0, "menu wisps arrived fully emerged, with no pop-in"):
        return false
    for _i in range(40):
        await physics_frame
    var emerged := 0
    for wisp in game.wisps:
        if wisp._spawn_pop >= 1.0:
            emerged += 1
    if not ok(emerged == game.wisps.size(),
            "menu wisps never finished emerging: %d/%d ticked" % [emerged, game.wisps.size()]):
        return false
    return true

func _check_the_pause_summary_shows_the_real_run(game: Node) -> bool:
    ## The pause screen used to open into a summary block AND into two legacy
    ## corner cards, and the cards kept the strings they were born with --
    ## nothing in the whole project ever wrote _floor_label, _health_label,
    ## _level_label, _stats_label, _sparkle_label or _charm_label. Pausing at
    ## level 9, 42 warmth and 777 sparkles on floor 5 therefore painted
    ## "Floor 1", "Level 1", "Warmth 100/100", "Song power 10", "0 sparkles"
    ## and "Charms 0/3: none yet" right beside the correct figures. The two
    ## cards are gone now, so the summary is the only place these numbers are
    ## said -- and it says them as icon-plus-number rows.
    game._start_run(3)
    await frames(6)
    game.charms_owned = loadout(["boots"])
    game.charms_equipped = loadout(["boots"])
    game.sparkles = 777
    game.hp = 42.0
    game._refresh_ui()
    await frames(4)
    game._pause_game()
    await frames(4)

    var said := block_text(game.ui._overlay_content)
    var want := {
        "warmth": "%d / %d" % [roundi(game.hp), roundi(game.hp_max)],
        "soul": "%d" % game.level,
        "sparkles": "%d" % game.sparkles,
    }
    for what: String in want:
        if not ok(said.contains(String(want[what])),
                "the pause summary lost the %s figure '%s' (it said '%s')" % [what, String(want[what]), said]):
            return false
    if not ok(said.contains("%d" % game.floor_number),
            "the pause summary lost the depth figure (%d): '%s'" % [game.floor_number, said]):
        return false
    # The loadout is pictures now, so the worn charm is confirmed by its icon.
    if not ok(glyph_keys_in(game.ui._overlay_content).has("boots"),
            "the pause summary did not draw the worn charm's icon"):
        return false
    # The old card claimed "Charms 0/3: none yet" whatever the player wore; a
    # summary that showed nothing at all would be the same lie in the other
    # direction, so the charm name has to still be reachable on hover.
    if not ok("Swift Boots" in game.ui._walker_charms,
            "the worn charm's name is parked nowhere the pause card can name it"):
        return false
    game._resume_game()
    await frames(2)
    return true

func _check_curious_wisp_facts_can_win_the_sticker(game: Node) -> bool:
    ## The journal tells a player with no facts to "soothe a curious wisp" to
    ## earn one, and Curious Mind is earned for ten facts from Mote. Both facts
    ## arrived through the same shared counter, so the first ten LEVEL-UPS took
    ## the sticker and no amount of curious wisps ever could -- the journal
    ## pointed at a reward the game could not deliver. Level-ups still fill the
    ## Atlas; only the wisp route counts toward the sticker.
    game.meta["stickers"] = []
    game.meta["facts"] = 0
    game.meta["facts_from_wisps"] = 0

    # Ten level-up facts: the Atlas fills, and the sticker must not be awarded on
    # this route.
    for _i in 10:
        game._learn_fact("A level-up lantern fact")
    if not ok(int(game.meta.get("facts", 0)) == 10,
            "ten level-up facts put %d in the Atlas, expected 10" % int(game.meta.get("facts", 0))):
        return false
    if not ok(not (game.meta["stickers"] as Array).has("fact_finder"),
            "ten level-up facts awarded Curious Mind, which the journal offers for soothing curious wisps"):
        return false

    # Ten wisp facts: this is the route the journal names, so it must win it.
    for _i in 10:
        game._learn_fact("A curious wisp tucked a fact into its glow", true)
    if not ok((game.meta["stickers"] as Array).has("fact_finder"),
            "ten curious-wisp facts did not award Curious Mind"):
        return false
    if not ok(int(game.meta.get("facts_from_wisps", 0)) == 10,
            "the wisp tally read %d, expected 10" % int(game.meta.get("facts_from_wisps", 0))):
        return false

    # The tally has to survive a save: _clean_meta rebuilds the satchel from a
    # whitelist, so a counter missing from that list is silently dropped on
    # every write and the sticker resets on the next launch.
    var survived := BeautyData._clean_meta(game.meta)
    if not ok(int(survived.get("facts_from_wisps", 0)) == 10,
            "saving dropped the wisp tally to %d, so the sticker resets on every launch" % int(survived.get("facts_from_wisps", 0))):
        return false
    game.meta["stickers"] = []
    game.meta["facts"] = 0
    game.meta["facts_from_wisps"] = 0

    # The Atlas holds FACTS entries and _learn_fact picks by index, so it cycles.
    # It appended every time regardless, which filled the journal with duplicate
    # copies of the same facts until the 120-entry cap silently dropped the
    # player's oldest entries and renumbered the rest. Measured after 12 runs:
    # 120 entries kept of 480 learned, only 24 of them distinct -- 96
    # duplicate copies -- while the pause card counted 480.
    if not ok(BeautyLore.FACTS.size() < 120,
            "the journal cap of 120 is now reachable against a table of %d facts" % BeautyLore.FACTS.size()):
        return false
    game.meta["facts_learned"] = []
    game.meta["facts"] = 0
    # Learn far more facts than the table holds, the way many runs do.
    for _i in BeautyLore.FACTS.size() * 3:
        game._learn_fact("A level-up lantern fact")
    var journal: Array = game.meta.get("facts_learned", [])
    var distinct := {}
    for entry: String in journal:
        distinct[entry] = true
    if not ok(journal.size() == distinct.size(),
            "learning %d facts from a table of %d produced %d entries holding %d distinct ones" % [
                BeautyLore.FACTS.size() * 3, BeautyLore.FACTS.size(), journal.size(), distinct.size()]):
        return false
    if not ok(journal.size() <= BeautyLore.FACTS.size(),
            "the journal grew to %d entries, past the %d facts that actually exist" % [
                journal.size(), BeautyLore.FACTS.size()]):
        return false
    # The pause card and the memory book must not disagree: one reads the
    # lifetime counter, the other the journal's length.
    if not ok(int(game.meta.get("facts", 0)) == journal.size(),
            "the Atlas counted %d facts while the memory book would list %d" % [
                int(game.meta.get("facts", 0)), journal.size()]):
        return false
    game.meta["facts_learned"] = []
    game.meta["facts"] = 0
    return true

func _check_stanza_cards_paint_song_glyphs(game: Node) -> bool:
    ## Lantern-song wares used to reach the cart without a `kind`, so a card
    ## treated them as charms: every song shelf painted the hollow "unknown
    ## key" ring, or the charm art when the key collided (moss, lullaby).
    game.ui.show_shop(game._shop_state())
    await frames(4)
    var stanza_cards := 0
    for card in free_item_cards(game.ui._shop_frame):
        if not card.item_name().begins_with("Verse of"):
            continue
        stanza_cards += 1
        var glyph := card.glyph_key()
        if not ok(glyph == GardenGlyphs.STANZA_PREFIX + card.item_key(),
                "stanza card painted the wrong ink: %s from key %s" % [card.item_name(), glyph]):
            return false
    if not ok(stanza_cards == BeautyContent.STANZAS.size(),
            "expected %d stanza cards, found %d" % [BeautyContent.STANZAS.size(), stanza_cards]):
        return false
    game.ui.close_panels()
    await frames(2)
    return true

func _check_colliding_sockets_keep_their_own_art(game: Node) -> bool:
    ## `moss` is both a charm and a verse. The vitals sockets used to paint
    ## every key that ALSO existed in the stanza table as the song glyph, so a
    ## worn Moss Pillow showed the verse's note and nobody could wear the
    ## charm and read it correctly.
    game.charms_equipped = loadout(["moss"])
    game.stanzas_equipped["moss"] = true
    game._refresh_ui()
    await frames(2)
    var keys: Array = game.ui._vitals.equipped
    if not ok(keys.has("moss") and keys.has(GardenGlyphs.STANZA_PREFIX + "moss"),
            "the vitals sockets lost which table each worn key is for: %s" % str(keys)):
        return false
    var stanza_rows := 0
    for k: String in keys:
        if k.begins_with(GardenGlyphs.STANZA_PREFIX):
            stanza_rows += 1
    if not ok(stanza_rows == game.stanzas_equipped.size(),
            "every worn stanza should socket with its ink prefix: %s" % str(keys)):
        return false
    var leaked := false
    for k: String in game.ui._walker_charm_keys:
        if k.begins_with(GardenGlyphs.STANZA_PREFIX):
            leaked = true
    if not ok(not leaked and game.ui._walker_charm_keys.has("moss"),
            "the pause charm row should hold no song keys: %s" % str(game.ui._walker_charm_keys)):
        return false
    # A tiered copy must resolve to its own ware's ink, and only at a tier that
    # exists -- otherwise a socket could paint boots for a tier with no boots.
    if not ok(GardenGlyphs.has_glyph(GardenGlyphs.worn_key("boots", 2)),
            "a tiered charm key reported no ink"):
        return false
    if not ok(not GardenGlyphs.has_glyph(GardenGlyphs.worn_key("boots", 9)),
            "a charm key claimed a tier that does not exist"):
        return false
    if not ok(not GardenGlyphs.has_glyph(GardenGlyphs.worn_key("petals", 2)),
            "a bare verse key borrowed a charm's ink once tiered"):
        return false
    # The same collision means a BARE verse key must never report itself as
    # ink: it would paint the hollow gap-ring or the charm art of the same
    # name, and has_glyph is the gate that was supposed to catch the gap.
    if not ok(not GardenGlyphs.has_glyph("petals"),
            "a bare verse key reported ink (hollow-ring or a shared charm)"):
        return false
    if not ok(not GardenGlyphs.has_glyph("lodestar"),
            "a bare counter-melody key reported ink"):
        return false
    if not ok(GardenGlyphs.has_glyph(GardenGlyphs.STANZA_PREFIX + "petals"),
            "a prefixed verse key must report ink"):
        return false
    if not ok(GardenGlyphs.has_glyph("moss"),
            "a charm key must still report ink as itself"):
        return false
    game.charms_equipped.clear()
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._refresh_ui()
    await frames(2)
    return true

func _check_every_worn_ware_gets_a_socket(game: Node) -> bool:
    ## The vitals strip draws one socket per worn ware AND one per socket of
    ## room. With two copies of a charm on, both must appear -- the second is
    ## only distinguishable by its tier pips, so losing one of the pair would
    ## make the deeper copy invisible exactly when it was earned.
    game.charms_equipped = loadout([["boots", 1], ["boots", 2], ["scarf", 1], ["echo", 1]])
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._refresh_ui()
    await frames(2)
    var vitals: CozyVitals = game.ui._vitals
    var worn: int = game.charms_equipped.size() + game.stanzas_equipped.size()
    if not ok(vitals.slot_capacity >= worn,
            "the strip has %d sockets for %d worn wares (charms %d + songs %d), so %d of them are never painted: %s" % [
                vitals.slot_capacity, worn, game.charms_equipped.size(), game.stanzas_equipped.size(),
                worn - mini(vitals.slot_capacity, worn), str(vitals.equipped)]):
        return false
    if not ok(vitals.equipped.size() == worn,
            "every worn ware should reach the strip: %s" % str(vitals.equipped)):
        return false
    # Both copies must be on the strip under DIFFERENT keys, or the player
    # cannot tell which socket is the stronger one.
    if not ok(vitals.equipped.has("boots") and vitals.equipped.has("tier:2:boots"),
            "two copies of one charm must show as two marked sockets: %s" % str(vitals.equipped)):
        return false
    # The plate is the backing drawn behind the whole strip, so a socket that
    # hangs off it is a ware the player just bought and cannot see. Every worn
    # socket has to land inside the drawn plate, at the widest loadout.
    var row := vitals._slot_row_rect()
    if not ok(row.end.x <= vitals.size.x and row.end.y <= vitals.size.y,
            "the socket row ends at %s but the plate is only %s, so the last worn ware is painted outside it" % [
                str(row.end.round()), str(vitals.size.round())]):
        return false
    # A bare strip must still read as a card rather than collapsing to nothing.
    game.charms_equipped.clear()
    game.stanzas_equipped = {"petals": true}
    game._refresh_ui()
    await frames(2)
    if not ok(game.ui._vitals.slot_capacity >= 1,
            "a bare strip should draw at least one socket, not %d" % game.ui._vitals.slot_capacity):
        return false
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._refresh_ui()
    await frames(2)
    return true
