extends "res://tests/support/test_case.gd"
## The infinite-growth regression: everything that promises "nothing in this
## game has a ceiling" gets a check here. The endless chapters must compose
## deterministically and never repeat the campaign; charm tiers must keep
## deepening truthfully; the level-up draft must offer real choices, apply
## them, and never leak across a fresh walk.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyData := preload("res://scripts/beauty_data.gd")
const BeautyEndless := preload("res://scripts/beauty_endless.gd")
const RunBoons := preload("res://scripts/run_boons.gd")
const Wisp := preload("res://scripts/wisp.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_GROWTH"
    TestProfile.begin("growth")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(4)

    if not await _check_endless_regions_compose(game):
        return
    if not await _check_feelings_exist_below(game):
        return
    if not await _check_endless_story_pages(game):
        return
    if not await _check_charm_tiers_deepen(game):
        return
    if not await _check_the_draft_offers_real_choices(game):
        return
    if not await _check_a_fresh_walk_forgets_the_draft(game):
        return
    if not await _check_endless_floors_build(game):
        return
    if not await _check_the_new_depth_wisps_exist(game):
        return
    if not await _check_the_draft_waits_for_the_song(game):
        return
    if not await _check_the_walk_continues_past_a_finale(game):
        return
    if not await _check_the_socket_row_stays_on_screen(game):
        return
    if not await _check_the_level_toast_names_the_real_book(game):
        return

    finish(game, "BEAUTY_FOREST_GROWTH")

func _check_the_level_toast_names_the_real_book(game: Node) -> bool:
    ## The level-up toast announced new facts "in the Atlas" -- a name no
    ## screen in this game carries. The facts live in Mote's memory book; the
    ## toast now says so, because a player sent looking for a place the game
    ## never built learns to stop trusting its signposts.
    game.ui.clear_toast()
    var xp_needed: int = game.xp_next - game.xp
    game._gain_xp(xp_needed)
    await frames(2)
    var toast: String = game.ui._toast_label.text
    return ok("Atlas" not in toast and "book" in toast,
            "the level-up toast still names a place the game never built: %s" % toast)

func _check_endless_regions_compose(game: Node) -> bool:
    ## Chapter 7 must always be chapter 7's forest: saves, waymarks and stories
    ## all agree on it. And no chapter may quietly serve the campaign's regions
    ## again -- that loop was the ceiling this system exists to remove.
    var third: Dictionary = BeautyEndless.region(3)
    var third_again: Dictionary = BeautyEndless.region(3)
    if not ok(String(third["name"]) == String(third_again["name"]) and String(third["entry"]) == String(third_again["entry"]),
            "chapter 3 composed differently twice: %s vs %s" % [third["name"], third_again["name"]]):
        return false
    for field in ["sky", "horizon", "fog", "sun", "foliage", "tip", "flower", "ground", "accent"]:
        if not ok(third.has(field) and not String(third[field]).is_empty(),
                "chapter 3's region has no %s" % field):
            return false
    if not ok(third["ambient"] in BeautyEndless.AMBIENT_MOODS,
            "chapter 3 borrows an ambient mood the score does not know: %s" % str(third.get("ambient"))):
        return false
    for chapter in range(1, 9):
        var composed: Dictionary = BeautyEndless.region(chapter)
        var first: int = BeautyContent.CAMPAIGN_LENGTH + (chapter - 1) * BeautyEndless.CHAPTER_LENGTH + 1
        if not ok(int(composed["min"]) == first and int(composed["max"]) == first + BeautyEndless.CHAPTER_LENGTH - 1,
                "chapter %d claims floors %d..%d, expected %d..%d" % [
                    chapter, int(composed["min"]), int(composed["max"]), first, first + BeautyEndless.CHAPTER_LENGTH - 1]):
            return false
    ## The name space is 14 x 14 = 196 pairings and the walk must visit every
    ## one before cycling: no two of the first 196 chapters may share a name,
    ## or a deep run meets the same forest twice and the compose promise dies.
    var bloom := {}
    var first_dupe := ""
    for chapter in range(1, 197):
        var region_name := String(BeautyEndless.region(chapter)["name"])
        if not bloom.has(region_name):
            bloom[region_name] = chapter
        elif first_dupe.is_empty():
            first_dupe = "chapters %d and %d are both \"%s\"" % [bloom[region_name], chapter, region_name]
    if not ok(bloom.size() == 196, "the 196-chapter bloom repeated a forest: %s" % first_dupe):
        return false
    for floor_number in range(1, BeautyContent.CAMPAIGN_LENGTH + 1):
        var expected := "Sunlit Roots" if floor_number <= 4 else ("Pollen Halls" if floor_number <= 8 else ("Mushroom Lull" if floor_number <= 12 else ("Snoozle’s Roost" if floor_number <= 13 else ("Dewdrop Terraces" if floor_number <= 17 else ("Honeywind Boughs" if floor_number <= 21 else ("Glowcap Meadow" if floor_number <= 25 else ("Starpetal Vale" if floor_number <= 29 else "The Grand Roost")))))))
        if not ok(String(BeautyContent.region_for_floor(floor_number)["name"]) == expected,
                "campaign floor %d lost its own region" % floor_number):
            return false
    var chapter_one: String = String(BeautyContent.region_for_floor(31)["name"])
    var deeper: String = String(BeautyContent.region_for_floor(43)["name"])
    if not ok(chapter_one == String(BeautyEndless.region(1)["name"]) and deeper == chapter_one,
            "floors 31 and 43 do not share chapter 1's region: %s / %s" % [chapter_one, deeper]):
        return false
    return true

func _check_feelings_exist_below(game: Node) -> bool:
    ## The campaign's three hand-placed Feelings stay put; every endless chapter
    ## grows its own pair at the same gentle story positions.
    if not ok(not BeautyContent.feeling_for_floor(4).is_empty() and not BeautyContent.feeling_for_floor(12).is_empty(),
            "the campaign lost a hand-placed Big Feeling"):
        return false
    if not ok(BeautyContent.feeling_for_floor(5).is_empty(), "the first dragon floor grew a Feeling beside the dragon"):
        return false
    var chapter_feeling: Dictionary = BeautyContent.feeling_for_floor(34)
    if not ok(not chapter_feeling.is_empty() and not String(chapter_feeling.get("name", "")).is_empty()
            and not String(chapter_feeling.get("farewell", "")).is_empty(),
            "endless floor 34 (chapter story 4) has no Big Feeling"):
        return false
    if not ok(not BeautyContent.feeling_for_floor(38).is_empty(), "endless floor 38 (chapter story 8) has no Big Feeling"):
        return false
    if not ok(not BeautyContent.feeling_for_floor(33).is_empty() == false,
            "endless floor 33 grew an unplanned Feeling"):
        return false
    var other_chapter: Dictionary = BeautyContent.feeling_for_floor(47)
    if not ok(not other_chapter.is_empty(), "chapter 2's first Feeling is missing (floor 47)"):
        return false
    if not ok(String(other_chapter.get("name", "")) != String(chapter_feeling.get("name", "")),
            "chapter 2 reused chapter 1's Feeling name"):
        return false
    return true

func _check_endless_story_pages(game: Node) -> bool:
    ## Below the Roost every floor still opens a page: a title and a body, never
    ## a repeat of a campaign page, and never a repeat of another chapter's.
    for floor_number in range(1, BeautyContent.CAMPAIGN_LENGTH + 1):
        var page: Array = BeautyContent.story_for_floor(floor_number)
        if not ok(page.size() == 2 and not String(page[0]).is_empty(),
                "campaign floor %d lost its hand-written story page" % floor_number):
            return false
    var first_endless: Array = BeautyContent.story_for_floor(31)
    if not ok(first_endless.size() == 2 and not String(first_endless[0]).is_empty() and not String(first_endless[1]).is_empty(),
            "endless floor 31 opened a blank page"):
        return false
    if not ok(first_endless == BeautyContent.story_for_floor(31), "endless floor 31's page changed between reads"):
        return false
    var chapter_two: Array = BeautyContent.story_for_floor(44)
    if not ok(String(chapter_two[0]) != String(first_endless[0]),
            "chapter 2 opened with chapter 1's page: %s" % String(chapter_two[0])):
        return false
    var pages := {}
    for offset in range(0, 13):
        var page: Array = BeautyContent.story_for_floor(31 + offset)
        pages[String(page[0])] = true
        if not ok(page.size() == 2, "endless floor %d's page is malformed" % (31 + offset)):
            return false
    if not ok(pages.size() >= 11, "one chapter told only %d distinct stories" % pages.size()):
        return false
    return true

func _check_charm_tiers_deepen(game: Node) -> bool:
    ## The shelf deepens past two copies, the price keeps meaning it, and the
    ## blurb tells the truth about the strength it sells.
    if not ok(BeautyContent.tier_scale(3) > BeautyContent.tier_scale(2),
            "tier III is no stronger than tier II"):
        return false
    if not ok(BeautyContent.tier_index(9) == 3, "tier_index does not clamp at the deepest tier"):
        return false
    var price_two: int = BeautyContent.charm_price("boots", 2)
    var price_three: int = BeautyContent.charm_price("boots", 3)
    if not ok(price_three > price_two, "tier III costs no more than tier II (%d vs %d)" % [price_three, price_two]):
        return false
    var speed_two := float(BeautyContent.charm_effects_at("boots", 2).get("speed", 1.0))
    var speed_three := float(BeautyContent.charm_effects_at("boots", 3).get("speed", 1.0))
    if not ok(speed_three > speed_two, "tier III boots are no swifter (%f vs %f)" % [speed_three, speed_two]):
        return false
    var blurb := BeautyContent.charm_blurb("boots", 3)
    if not ok(blurb.contains("%d%%" % roundi((speed_three - 1.0) * 100.0)),
            "tier III's blurb does not match its numbers: %s" % blurb):
        return false
    if not ok(BeautyContent.charm_label("boots", 3).ends_with("III"),
            "tier III is not named as the third copy: %s" % BeautyContent.charm_label("boots", 3)):
        return false
    return true

func _check_the_draft_offers_real_choices(game: Node) -> bool:
    ## Three distinct gifts, only ones this depth has unlocked, and a pick that
    ## actually lands in the run's numbers.
    game._start_run(1)
    await frames(6)
    if not ok(game.pending_boons == 0, "a fresh walk started with a draft pending"):
        return false
    var shallow: Array = game._roll_offers()
    if not ok(shallow.size() == 3, "the draft offered %d gifts" % shallow.size()):
        return false
    var keys := {}
    for offer: Dictionary in shallow:
        keys[String(offer["key"])] = true
        if not ok(int(offer.get("min_floor", 1)) <= game.floor_number,
                "the draft offered %s before it unlocks" % str(offer["key"])):
            return false
    if not ok(keys.size() == 3, "the draft offered the same gift twice: %s" % str(keys)):
        return false
    # The pool's growth is deterministic (the filter), while a single roll is
    # not -- so the filter is what gets asserted, and rolls are only checked
    # to stay inside it.
    var unlocked := func(depth: int) -> Array:
        var available: Array = []
        for boon: Dictionary in RunBoons.BOON_POOL:
            if depth >= int(boon.get("min_floor", 1)):
                available.append(String(boon["key"]))
        return available
    var shallow_pool: Array = unlocked.call(1)
    var deep_pool: Array = unlocked.call(9)
    if not ok(shallow_pool.size() == 3 and deep_pool.size() == RunBoons.BOON_POOL.size(),
            "the gift pool did not grow with depth: %d at floor 1, %d at floor 9" % [shallow_pool.size(), deep_pool.size()]):
        return false
    for _try in range(6):
        var rolled: Array = game._roll_offers()
        for offer: Dictionary in rolled:
            if not ok(String(offer["key"]) in deep_pool,
                    "the draft rolled %s, which floor 9 has not unlocked" % str(offer["key"])):
                return false
    game.floor_number = 1

    # A warmth pick lands in the hero's numbers.
    var warmth_before: float = game.hp_max
    game._open_draft()
    await frames(2)
    if not ok(game.mode == game.Mode.DRAFT, "opening a draft did not pause the walk into DRAFT"):
        return false
    game.pick_boon("warmth")
    await frames(2)
    if not ok(game.hp_max == warmth_before + 20.0, "the warmth gift did not warm: %f -> %f" % [warmth_before, game.hp_max]):
        return false
    if not ok(game.mode == game.Mode.PLAYING, "picking the gift did not hand the walk back"):
        return false

    # An effect boon rides in charm_effects, exactly like a worn ware would.
    # The swift gift is deterministic here -- the offered list is replaced with
    # the boon under test -- because a random roll would make this check flaky
    # by construction.
    var speed_before: float = game.player.move_speed
    game._apply_level_up_boon()
    game._open_draft()
    await frames(2)
    for boon: Dictionary in RunBoons.BOON_POOL:
        if String(boon.get("key", "")) == "swift":
            game._draft_offers = [boon]
            break
    game.pick_boon("swift")
    await frames(2)
    if not ok(game.player.move_speed > speed_before,
            "the swift gift did not quicken the walk (%f -> %f)" % [speed_before, game.player.move_speed]):
        return false
    if not ok(float(game.charm_effects.get("speed", 1.0)) > 1.0,
            "the swift gift never reached the run's effects: %s" % str(game.charm_effects)):
        return false
    return true

func _check_a_fresh_walk_forgets_the_draft(game: Node) -> bool:
    ## The gifts are the run's, not the profile's: a fresh walk must not start
    ## owed a draft or still swifter from the last one's kindness.
    game._apply_level_up_boon()
    game._apply_level_up_boon()
    if not ok(game.pending_boons == 2, "queued levels did not queue drafts: %d" % game.pending_boons):
        return false
    game._start_run(1)
    await frames(6)
    if not ok(game.pending_boons == 0 and game.boon_effects.is_empty(),
            "a fresh walk kept a draft queue or boon effects: %d %s" % [game.pending_boons, str(game.boon_effects)]):
        return false
    if not ok(game.mode != game.Mode.DRAFT, "a fresh walk opened in a draft"):
        return false
    return true

func _check_endless_floors_build(game: Node) -> bool:
    ## Floors past the Roost must actually build: region, feelings, dragon
    ## finale, merchant — the whole calendar, one chapter deep.
    game._start_run(31)
    await frames(8)
    if not ok(game.region.get("key", "") == "endless-1", "floor 31 did not enter the first endless chapter: %s" % str(game.region.get("key"))):
        return false
    if not ok(game.world != null and is_instance_valid(game.world), "endless floor 31 built no world"):
        return false
    game._load_floor(43, false)
    await frames(8)
    if not ok(game.dragon_exists, "endless chapter-final floor 43 has no dragon"):
        return false
    if not ok(game.world.chimes.size() == 5, "endless chapter-final floor 43 has %d chimes" % game.world.chimes.size()):
        return false
    if not ok(game.dragon_finale, "floor 43 (chapter 1's last floor) is not a finale"):
        return false
    game._load_floor(34, false)
    await frames(8)
    var feeling_wisps := 0
    for wisp: Wisp in game.wisps:
        if is_instance_valid(wisp) and wisp.is_feeling:
            feeling_wisps += 1
    if not ok(feeling_wisps == 1, "endless floor 34 hosts %d Big Feelings" % feeling_wisps):
        return false
    return true

func _check_the_socket_row_stays_on_screen(game: Node) -> bool:
    ## Capacity opens one socket per floor forever, and the vitals strip used
    ## to paint one empty outline per open socket: a floor-60 walk drew a
    ## 60-socket ruler that ran off the right edge of the screen. "Room to
    ## grow" is a message, not an inventory readout -- deep walks must bound
    ## the empty outlines while never hiding a worn ware.
    game._start_run(1)
    await frames(6)
    game.charms_equipped.append({"key": "ember", "tier": 1})
    game.floor_number = 60
    game._refresh_ui()
    await frames(2)
    var vitals: Control = game.ui._vitals
    var expected_worn: int = game.charms_equipped.size() + game.stanzas_equipped.size()
    if not ok(vitals.slot_capacity >= expected_worn,
            "a deep walk hid a worn ware from the strip: %d sockets for %d worn" % [vitals.slot_capacity, expected_worn]):
        return false
    if not ok(vitals.slot_capacity < game.loadout_capacity(),
            "the strip painted every open socket at depth %d (%d sockets) -- the ruler is back" % [game.floor_number, vitals.slot_capacity]):
        return false
    var width := float(vitals.custom_minimum_size.x)
    if not ok(width < 560.0,
            "the deep-walk socket plate is %.0f px wide -- wider than a portrait phone" % width):
        return false
    game.floor_number = 1
    game._refresh_ui()
    await frames(2)
    return true

func _check_the_walk_continues_past_a_finale(game: Node) -> bool:
    ## "Wander deeper" is the whole infinite promise: the Roost finale at
    ## story 13 hands the walk to the ending card, and accepting it must
    ## carry EVERYTHING earned -- level, sparkles, the loadout, queued
    ## drafts -- into the next chapter's first floor, not a fresh walk.
    game._start_run(BeautyContent.CAMPAIGN_LENGTH)
    await frames(6)
    game.level = 9
    game.attack = 44.0
    game.sparkles = 77
    game.charms_owned.append({"key": "ember", "tier": 1})
    game.charms_equipped.append({"key": "ember", "tier": 1})
    game._apply_level_up_boon()
    game._win_dragon()
    if not ok(game.ending_pending, "the Roost finale did not open the ending"):
        return false
    game._show_ending()
    if not ok(game.mode == game.Mode.ENDING, "the finale did not reach the ending card"):
        return false
    game._start_run(BeautyContent.CAMPAIGN_LENGTH + 1, true)
    await frames(8)
    if not ok(game.floor_number == BeautyContent.CAMPAIGN_LENGTH + 1 and game.region.get("key", "") == "endless-1",
            "wandering deeper did not land on the next chapter's first floor: %s" % str(game.region.get("key"))):
        return false
    if not ok(game.level == 9 and game.attack == 44.0 and game.sparkles == 77,
            "wandering deeper lost earned numbers: level %d song %f sparkles %d" % [game.level, game.attack, game.sparkles]):
        return false
    if not ok(BeautyData.wearing(game.charms_equipped, "ember", 1),
            "wandering deeper lost a worn ware: %s" % str(game.charms_equipped)):
        return false
    if not ok(game.pending_boons == 1, "wandering deeper dropped the queued gift: %d" % game.pending_boons):
        return false
    game._refresh_ui()
    await frames(2)
    if not ok(game.mode == game.Mode.DRAFT, "the gift carried deeper was never offered"):
        return false
    game.pick_boon(String(game._draft_offers[0].get("key", "")))
    await frames(2)
    if not ok(game.mode == game.Mode.PLAYING and game.pending_boons == 0,
            "settling the carried gift left the walk in %s" % str(game.mode)):
        return false
    return true

func _check_the_draft_waits_for_the_song(game: Node) -> bool:
    ## Soothing a bystander wisp during a dragon lullaby still earns XP, so a
    ## level can land MID-SONG. The draft must not seize the walk then: the
    ## ceremony owns the mode machine until its last beat. The gift is not
    ## lost -- it comes back the moment the song ends.
    game._start_run(5)
    await frames(6)
    if not ok(game.dragon_exists, "floor 5 built without its dragon"):
        return false
    game._lullaby_active = true
    game._lullaby_kind = "dragon"
    game._apply_level_up_boon()
    game._refresh_ui()
    await frames(2)
    if not ok(game.mode != game.Mode.DRAFT, "a draft stole the walk in the middle of a lullaby"):
        return false
    if not ok(game._lullaby_active and game.pending_boons == 1,
            "the queued gift was dropped instead of waiting: %d" % game.pending_boons):
        return false
    game._lullaby_active = false
    game._refresh_ui()
    await frames(2)
    if not ok(game.mode == game.Mode.DRAFT and not game._draft_offers.is_empty(),
            "the pending gift never came back after the song"):
        return false
    game.pick_boon(String(game._draft_offers[0].get("key", "")))
    await frames(2)
    if not ok(game.mode == game.Mode.PLAYING and game.pending_boons == 0,
            "settling the waited gift left the walk in %s with %d pending" % [str(game.mode), game.pending_boons]):
        return false
    return true

func _check_the_new_depth_wisps_exist(game: Node) -> bool:
    ## Puffcap, Comet and Snugbug must be real: in the tables, in the pool
    ## rotation, and buildable with a body a player can see.
    for type_key in ["Puffcap", "Comet", "Snugbug"]:
        if not ok(BeautyContent.WISP_TYPES.has(type_key), "%s is not in the wisp tables" % type_key):
            return false
        var wisp := Wisp.new()
        wisp.setup(type_key, 20)
        var parts: int = wisp._visual.get_child_count()
        if not ok(parts >= 1, "%s built no visual body" % type_key):
            wisp.free()
            return false
        wisp.free()
    var deep_pool: Array = BeautyContent.wisp_pool(40)
    var deep_types := {}
    for entry: Array in deep_pool:
        deep_types[String(entry[0])] = true
    if not ok(deep_types.has("Puffcap") or deep_types.has("Comet") or deep_types.has("Snugbug"),
            "the deep pool never rotates the new types in: %s" % str(deep_types)):
        return false
    var shallow_pool: Array = BeautyContent.wisp_pool(9)
    for entry: Array in shallow_pool:
        if not ok(not (String(entry[0]) in ["Puffcap", "Comet", "Snugbug"]),
                "the campaign pool leaked a depth type early: %s" % str(entry[0])):
            return false
    return true
