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
## The cart/shelf/socket art checks later split again into regression_shelves.gd
## when this file outgrew the 500-line ceiling; the bodies moved verbatim, only
## the helper names changed, to the ones on TestCase.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyData := preload("res://scripts/beauty_data.gd")
const BeautyLore := preload("res://scripts/beauty_lore.gd")
const CozyWaypoint := preload("res://scripts/cozy_waypoint.gd")

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

    if not await _check_the_ending_facts_row_uses_the_book_glyph(game):
        return
    if not await _check_the_menu_wears_its_medals(game):
        return
    if not await _check_the_pause_doors_read_as_a_shelf(game):
        return
    if not await _check_the_memory_book_shelves_its_stickers(game):
        return
    finish(game, "BEAUTY_FOREST_SCREENS")

func _check_the_menu_wears_its_medals(game: Node) -> bool:
    ## The record row used to be three bare icons and three bare numbers
    ## floating on the card — readable, but with nothing anchoring them, they
    ## read as decoration. Each figure now sits on its own medal plate, and
    ## the three promises lead with named pictures. If a refactor drops the
    ## plates or swaps a medal's glyph for an unknown key (which _icon would
    ## silently replace with Mote), this catches it.
    game.ui.close_panels()
    game.ui.show_menu({"runs": 3, "best_floor": 7, "wisps_soothed": 12})
    await frames(4)
    var icons: Array[String] = glyph_keys_in(game.ui._overlay_content)
    for medal: String in ["boots", "stairs", "wisp"]:
        if not ok(icons.has(medal),
                "the menu's record lost its %s medal picture: %s" % [medal, str(icons)]):
            return false
    var plates := 0
    for node in game.ui._overlay_content.find_children("*", "PanelContainer", true, false):
        plates += 1
    return ok(plates >= 6,
            "the menu's promises and medals lost their plates (found %d PanelContainers)" % plates)

func _check_the_pause_doors_read_as_a_shelf(game: Node) -> bool:
    ## The pause card's four secondary doors used to be four stacked
    ## full-width rows. They are a two-by-two shelf of half-width picture
    ## plates now; the shelf must hold all four, each with its own picture,
    ## and the settings door must still be singularly named (regression_options
    ## pins the words, this pins the shape).
    game.ui.close_panels()
    game.ui.show_pause(game.meta)
    await frames(4)
    var flows: Array = game.ui._overlay_content.find_children("*", "HFlowContainer", true, false)
    if not ok(flows.size() == 1,
            "the pause card's door shelf is missing or duplicated (%d flows)" % flows.size()):
        return false
    var doors := 0
    var pictured := 0
    for node in (flows[0] as Node).get_children():
        var button := node as Button
        if button == null:
            continue
        doors += 1
        if button.icon != null:
            pictured += 1
    return ok(doors == 4 and pictured == 4,
            "the pause door shelf holds %d doors, %d with pictures (want 4/4)" % [doors, pictured])

func _check_the_memory_book_shelves_its_stickers(game: Node) -> bool:
    ## The memory book's stickers used to be a list of names — an inventory.
    ## They are a shelf of picture plates now, each wearing the glyph of the
    ## memory that earned it, and every fact row leads with the book's own
    ## mark. The shelf must paint each sticker's own picture (not the
    ## everything-looks-the-same heart) for the stickers that own a glyph.
    game.ui.close_panels()
    game.ui.show_journal(game.meta, ["Mote hums when it is thinking."], ["dragon_friend", "shopper", "mystery_key"])
    await frames(4)
    var icons: Array[String] = glyph_keys_in(game.ui._shop_frame)
    if not ok(icons.has("dragon") and icons.has("cart"),
            "the sticker shelf did not paint each sticker's own picture: %s" % str(icons)):
        return false
    var fact_bullets := 0
    for node in game.ui._shop_frame.find_children("*", "TextureRect", true, false):
        var icon := node as TextureRect
        if icon != null and icon.name == "book":
            fact_bullets += 1
    return ok(fact_bullets >= 2,
            "the memory book's fact rows lost their book-mark bullets (found %d)" % fact_bullets)

func _check_the_ending_facts_row_uses_the_book_glyph(game: Node) -> bool:
    ## The ending's third tally row counts fun facts. It carried the CHIME --
    ## the icon every other screen uses for song power -- so the picture said
    ## the opposite of what the number beside it counts. Facts live in Mote's
    ## memory book, whose glyph is already the memory-book mark on the touch
    ## bar; the ending borrows it now.
    game.ui.close_panels()
    game.ui.show_ending(2, {"runs": 7, "best_floor": 6, "wisps_soothed": 19, "facts": 5})
    await frames(4)
    var book_seen := false
    var chime_seen := false
    for node in game.ui._overlay_content.find_children("*", "TextureRect", true, false):
        var icon := node as TextureRect
        if icon == null:
            continue
        if icon.texture == GardenGlyphs.get_glyph(GardenGlyphs.BOOK):
            book_seen = true
        if icon.texture == GardenGlyphs.get_glyph(GardenGlyphs.CHIME):
            chime_seen = true
    return ok(book_seen and not chime_seen,
            "the ending's facts row still showed the chime glyph: book_seen=%s chime_seen=%s" % [str(book_seen), str(chime_seen)])

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
