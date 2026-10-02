extends TestCase

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
    if not await _check_the_pause_cards_show_the_real_run(game):
        return
    if not await _check_curious_wisp_facts_can_win_the_sticker(game):
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

func _check_the_pause_cards_show_the_real_run(game: Node) -> bool:
    ## The pause screen showed two sets of numbers. Its summary block was built
    ## from the state update_hud parks, but the corner status card kept the
    ## strings it was born with -- nothing in the whole project ever wrote
    ## _floor_label, _health_label, _level_label, _stats_label, _sparkle_label or
    ## _charm_label. Pausing at level 9, 42 warmth and 777 sparkles on floor 5
    ## therefore painted "Floor 1", "Level 1", "Warmth 100/100", "Song power
    ## 10", "0 sparkles" and "Charms 0/3: none yet" right beside the correct
    ## figures, and the two eased bars had nothing setting their targets.
    game._start_run(3)
    await frames(6)
    game.charms_owned["boots"] = true
    game.charms_equipped = {"boots": true}
    game.sparkles = 777
    game.hp = 42.0
    game._refresh_ui()
    await frames(4)
    game._pause_game()
    await frames(4)

    var expected := {
        "_floor_label": "Floor %d — %s" % [game.floor_number, String(game.region.get("name", "Sunlit Roots"))],
        "_health_label": "♥ Warmth  %d / %d" % [roundi(game.hp), roundi(game.hp_max)],
        "_sparkle_label": "✦ %d sparkles to spend" % game.sparkles,
        "_level_label": "Level %d  ·  %d / %d soul to next gift" % [game.level, game.xp, game.xp_next],
        "_charm_label": "Charms %d/%d: %s" % [game.charms_equipped.size(), BeautyContent.MAX_CHARMS, "Swift Boots"],
    }
    for field: String in expected:
        var label: Label = game.ui.get(field)
        if not ok(label != null and label.text == expected[field],
                "the pause card's %s reads '%s', expected '%s'" % [field, label.text if label != null else "nothing", expected[field]]):
            return false
    # The eased bars were inert for the same reason -- _health_shown and
    # _xp_shown were never assigned, so they had nothing to glide toward.
    if not ok(game.ui._health_bar.value > 0.0 and game.ui._health_bar.value <= 1.0,
            "the warmth bar never tracked warmth (value %f)" % game.ui._health_bar.value):
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
    return true
