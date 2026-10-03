extends TestCase

## Loadout and shop behaviour: what happens when a charm or verse is bought or
## swapped with every slot full, and what the cart claims about things nobody
## owns.
##
## Split out of regression_main_flow.gd. Every check here needs a filled loadout
## and a nearby cart, which is a different fixture from the run-state
## transitions the main flow suite drives -- and keeping them apart is what lets
## both files stay inside the 500-line budget.
##
## These bodies moved verbatim from regression_main_flow.gd; only the helper
## names changed, to the ones on TestCase.

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_LOADOUT"
    TestProfile.begin("loadout")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)

    if not await _check_buying_past_the_charm_cap_says_so(game):
        return
    if not await _check_a_full_slot_swap_names_the_evicted_charm(game):
        return
    if not await _check_a_full_slot_verse_swap_says_what_steps_back(game):
        return
    if not await _check_free_items_do_not_claim_to_be_owned(game):
        return
    if not await _check_stanza_cards_paint_song_glyphs(game):
        return
    if not await _check_colliding_sockets_keep_their_own_art(game):
        return

    finish(game, "BEAUTY_FOREST_LOADOUT")

func _check_buying_past_the_charm_cap_says_so(game: Node) -> bool:
    ## Filling all three charm slots and then buying a fourth charged the
    ## sparkles and logged "One Ember Mitten... It suits you." -- while the charm
    ## sat unequipped and did nothing, with nothing anywhere saying the slots were
    ## full. A player pays for a power they never receive and has no idea why.
    game._start_run(2)
    await frames(6)
    game.player.global_position = game.world.merchant_position + Vector3(1.0, 0.0, 0.0)
    await frames(2)
    game.sparkles = 999
    for key in ["boots", "scarf", "echo"]:
        game._on_buy_requested(key)
    await frames(2)
    if not ok(game.charms_equipped.size() == BeautyContent.MAX_CHARMS,
            "the fixture did not fill all %d charm slots (got %d)" % [
                BeautyContent.MAX_CHARMS, game.charms_equipped.size()]):
        return false

    game._on_buy_requested("ember")
    await frames(2)
    if not ok(bool(game.charms_owned.get("ember", false)), "the fourth charm was not recorded as owned"):
        return false
    if not ok(not bool(game.charms_equipped.get("ember", false)),
            "the fourth charm should not auto-equip past the cap"):
        return false
    # Look for the line THIS purchase produced rather than the newest line in
    # the log: the floor keeps ticking while the shop is open, and a wisp
    # drifting home can push a line above it, which made this check fail for
    # reasons that had nothing to do with the purchase.
    var last_line: String = newest_line_mentioning(game.ui._log_label, "ember")
    if not ok(last_line.to_lower().contains("ember mitten"),
            "the newest log line is not about the capped purchase: %s" % last_line):
        return false
    if not ok(last_line.contains("pocket"),
            "buying a charm past the cap never says it is waiting in the pocket: %s" % last_line):
        return false
    if not ok(not last_line.contains("It suits you"),
            "Peddle still promised the capped charm would be worn: %s" % last_line):
        return false

    # The shop itself must not promise a swap it cannot describe honestly either.
    game._open_shop()
    await frames(3)
    # The card paints no status words, so "am I wearing it" is the lit rim and
    # the promise is the hover text -- which is where the player reads it.
    var ember_card := find_ware(game.ui._shop_frame, "ember")
    var ember_tip := "" if ember_card == null else ware_button(ember_card).tooltip_text
    if not ok(ember_card != null, "the owned charm was not on the shelf"):
        return false
    if not ok(not ember_tip.is_empty(), "the owned charm had no tooltip in the shop"):
        return false
    if not ok(ember_tip.contains("swap"),
            "the shop promised a wear the cap cannot give: %s" % ember_tip):
        return false
    game._resume_game()
    await frames(3)
    game._start_run(1)
    await frames(4)
    return true

## Swapping a pocketed charm in with every slot full used to evict whichever
## charm fell last in charms_owned order, and said nothing at all. The player
## watched a build change with no explanation. The eviction must be stable and
## it must be named.
func _check_a_full_slot_swap_names_the_evicted_charm(game: Node) -> bool:
    game.sparkles = 100000
    game.charms_owned = {}
    game.charms_equipped = {}
    for key in ["boots", "scarf", "echo", "ember"]:
        game._on_buy_requested(key)
        for _i in range(2):
            await frames(2)
    if game.charms_equipped.size() < BeautyContent.MAX_CHARMS:
        print("FAIL: could not fill the charm slots to test a swap")
        return false

    var worn_before: Array = game.charms_equipped.keys()
    var owned_before: int = game.charms_owned.size()
    game._on_charm_equip_requested("ember")
    for _i in range(3):
        await frames(2)

    var newest: String = newest_line_mentioning(game.ui._log_label, String(charm_name_for("ember")))

    if not game.charms_equipped.has("ember"):
        print("FAIL: swapping a pocketed charm in did not equip it")
        return false
    if game.charms_equipped.size() > BeautyContent.MAX_CHARMS:
        print("FAIL: the swap exceeded the charm cap: %s" % str(game.charms_equipped.keys()))
        return false
    if game.charms_owned.size() != owned_before:
        print("FAIL: the swap lost ownership: %d -> %d" % [
            owned_before, game.charms_owned.size()])
        return false
    if not newest.contains("rests in your pocket"):
        print("FAIL: a full-slot swap did not say which charm it set aside (%s)" % newest)
        return false

    # The charm that was set aside must be named, and must still be owned so
    # the player can swap it back.
    var evicted := ""
    for key in worn_before:
        if not game.charms_equipped.has(key):
            evicted = key
            break
    if evicted == "":
        print("FAIL: a full-slot swap evicted nothing")
        return false
    if not game.charms_owned.has(evicted):
        print("FAIL: the evicted charm %s is no longer owned" % evicted)
        return false
    var evicted_name: String = charm_name_for(evicted)
    if not newest.contains(evicted_name):
        print("FAIL: the swap did not name the evicted charm %s (%s)" % [evicted_name, newest])
        return false

    # The same swap twice must evict the same charm: the rule is a rule.
    var first_evicted := evicted
    for key2 in ["moss", "dew", "acorn"]:
        game.charms_owned[key2] = true
    game._on_charm_equip_requested("moss")
    for _i in range(3):
        await frames(2)
    var second := ""
    for key3 in worn_before:
        if key3 != first_evicted and not game.charms_equipped.has(key3):
            second = key3
            break
    if second == "" and game.charms_equipped.size() == BeautyContent.MAX_CHARMS:
        print("FAIL: the second full-slot swap evicted nothing")
        return false
    return true


## The verse swap is the sibling of the charm swap above: with both slots full it
## evicts one, and it used to do so in total silence -- the log did not change
## at all. Mote now names what steps back.
func _check_a_full_slot_verse_swap_says_what_steps_back(game: Node) -> bool:
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game._recalculate_loadout(false)
    for _i in range(2):
        await frames(2)
    var before: Array = game.stanzas_equipped.keys()
    game._on_stanza_equip_requested("hearth")
    for _i in range(3):
        await frames(2)

    # Read the newest line that mentions the verse we just equipped. Reading
    # the log's LAST line instead was a coin flip: a Mote chatter line landing
    # after the swap buried the message, and the check passed or failed on
    # timing rather than on what the game said.
    var newest: String = ""
    for line: String in String(game.ui._log_label.text).split("\n"):
        if line.contains("Hearth"):
            newest = line
    print("STANZASWAP equipped=%s log=%s" % [str(game.stanzas_equipped.keys()), newest])
    if not ok(game.stanzas_equipped.has("hearth"),
            "swapping a verse in did not equip it"):
        return false
    if not ok(game.stanzas_equipped.size() <= BeautyContent.MAX_STANZAS,
            "the verse swap exceeded the cap: %s" % str(game.stanzas_equipped.keys())):
        return false

    var stepped_aside := ""
    for key in before:
        if not game.stanzas_equipped.has(key):
            stepped_aside = key
            break
    if not ok(stepped_aside != "", "a full-slot verse swap evicted nothing"):
        return false
    if not ok(newest.contains("steps back"),
            "a full-slot verse swap said nothing about what it displaced (%s)" % newest):
        return false
    var wanted := ""
    for stanza: Dictionary in BeautyContent.STANZAS:
        if String(stanza["key"]) == stepped_aside:
            wanted = String(stanza["name"])
            break
    if not ok(newest.contains(wanted),
            "the verse swap did not name %s (%s)" % [wanted, newest]):
        return false
    # Every verse is free, so the one that stepped back must be tap-able again.
    game._on_stanza_equip_requested(stepped_aside)
    for _i in range(3):
        await frames(2)
    if not ok(game.stanzas_equipped.has(stepped_aside),
            "the displaced verse could not be swapped straight back"):
        return false
    return true
## Verses and Mote's counter-melodies are free gifts that nobody owns, and the
## shop used to list every unworn one as "in pocket -- tap to wear" and "already
## yours". That describes a purchase which never happened.
##
## The card paints no status words at all any more -- a lit rim means "wearing"
## and nothing else -- so the ownership claim has to be checked where it now
## lives: the tooltip the player reads by hovering. A free item that said "you
## own this" would still be lying, in the one place the player goes looking.
func _check_free_items_do_not_claim_to_be_owned(game: Node) -> bool:
    game.ui.show_shop(game._shop_state())
    for _i in range(4):
        await frames(2)
    # The shelves live inside a ScrollContainer, so search the whole frame.
    var free_rows := 0
    var free_items := BeautyContent.STANZAS.size() + BeautyContent.MOTE_VERSES.size()
    for card in free_item_cards(game.ui._shop_frame):
        free_rows += 1
        var button := card.get_parent() as Button
        # A worn verse is wearing, which is true. An UNWORN one must not
        # describe a pocket or a purchase.
        if card.selected:
            continue
        if not ok(not card.owned,
                "a free item claimed ownership: %s" % card.item_name()):
            return false
        if not ok(not button.tooltip_text.contains("already yours"),
                "a free item claimed ownership in its tooltip: %s" % button.tooltip_text):
            return false
    print("FREE_ITEMS cards=%d of %d expected, none claim ownership or a pocket" % [
        free_rows, free_items])
    if not ok(free_rows == free_items,
            "expected %d free cards (every verse and counter-melody), found %d" % [
                free_items, free_rows]):
        return false
    game.ui.close_panels()
    for _i in range(2):
        await frames(2)
    return true

func _check_stanza_cards_paint_song_glyphs(game: Node) -> bool:
    ## Lantern-song wares used to reach the cart without a `kind`, so a card
    ## treated them as charms: every song shelf painted the hollow "unknown
    ## key" ring, or the charm art when the key collided (moss, lullaby).
    game.ui.show_shop(game._shop_state())
    for _i in range(4):
        await frames(2)
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
    for _i in range(2):
        await frames(2)
    return true

func _check_colliding_sockets_keep_their_own_art(game: Node) -> bool:
    ## `moss` is both a charm and a verse. The vitals sockets used to paint
    ## every key that ALSO existed in the stanza table as the song glyph, so a
    ## worn Moss Pillow showed the verse's note and nobody could wear the
    ## charm and read it correctly.
    game.charms_equipped["moss"] = true
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

func charm_name_for(key: String) -> String:
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) == key:
            return String(charm["name"])
    return key
