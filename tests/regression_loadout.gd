extends "res://tests/support/test_case.gd"
## Loadout and shop behaviour: what happens when a charm or verse is bought, and
## what the cart claims about things nobody owns.
##
## Split out of regression_main_flow.gd. Every check here needs a filled loadout
## and a nearby cart, which is a different fixture from the run-state
## transitions the main flow suite drives -- and keeping them apart is what lets
## both files stay inside the 500-line budget.
##
## The suite's spine used to be the cap: buying a fourth charm, swapping into a
## full loadout, and the verse swap that displaced something. All three are gone,
## because there is no longer a fixed number of sockets to fill. What replaced
## them is the same question asked of a world without a ceiling: does the
## loadout keep GROWING, at every depth, with nothing left behind?

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const CozyVitals := preload("res://scripts/cozy_vitals.gd")
const RunBoons := preload("res://scripts/run_boons.gd")

func _initialize() -> void:
        suite_name = "BEAUTY_FOREST_LOADOUT"
        TestProfile.begin("loadout")
        call_deferred("_run")

func _run() -> void:
        var packed: PackedScene = load("res://scenes/main.tscn")
        var game: Node = packed.instantiate()
        root.add_child(game)
        await frames(2)

        if not await _check_capacity_has_no_ceiling(game):
                return
        if not _check_the_boon_pool_never_empties():
                return
        if not await _check_a_charm_can_be_bought_twice(game):
                return
        if not await _check_a_deeper_walk_opens_more_sockets(game):
                return
        if not await _check_a_full_loadout_is_never_emptied(game):
                return
        if not await _check_a_full_lantern_sells_honest_words(game):
                return
        if not await _check_free_items_do_not_claim_to_be_owned(game):
                return

        finish(game, "BEAUTY_FOREST_LOADOUT")

func _check_capacity_has_no_ceiling(game: Node) -> bool:
        ## The loadout was capped at three wares and two songs. Three was a constant
        ## a player learns once and then designs around: every ward past the third
        ## was dead content, and the creatures kept scaling past a hero whose loadout
        ## could not. So the invariant this suite now guards is the opposite -- every
        ## depth must offer strictly more room than the last, forever.
        var previous := -1
        for depth in [1, 4, 13, 30, 100, 400, 5000, 100000]:
                var capacity := BeautyContent.loadout_capacity(depth)
                if not ok(capacity > previous,
                                "capacity stopped growing at depth %d (%d, was %d) -- the loadout has a ceiling again" % [
                                        depth, capacity, previous]):
                        return false
                previous = capacity
        # A walk this game can actually reach must hold the whole shelf, so the
        # campaign never asks the player to choose between wares they paid for.
        # Tea is a consumable, so the shelf that matters is the charms you WEAR.
        var shelf := BeautyContent.wearable_charms()
        if not ok(BeautyContent.loadout_capacity(BeautyContent.CAMPAIGN_LENGTH) >= shelf,
                        "a full campaign walk (floor %d, capacity %d) cannot wear all %d charms" % [
                                BeautyContent.CAMPAIGN_LENGTH,
                                BeautyContent.loadout_capacity(BeautyContent.CAMPAIGN_LENGTH),
                                shelf]):
                return false
        print("LOADOUT capacity: floor 1 -> %d, floor %d -> %d, floor 100000 -> %d" % [
                BeautyContent.loadout_capacity(1), BeautyContent.CAMPAIGN_LENGTH,
                BeautyContent.loadout_capacity(BeautyContent.CAMPAIGN_LENGTH),
                BeautyContent.loadout_capacity(100000)])
        if not _check_shop_song_lines_say_stronger_not_warmer():
                return false
        return true

func _check_shop_song_lines_say_stronger_not_warmer() -> bool:
        ## The shelf's song wares described themselves as "glowing warmer" -- the
        ## very word the level-up draft uses for LANTERN WARMTH, the health stat.
        ## One word carrying two opposite meanings across the two screens a player
        ## sees most is exactly the confusion a new player cannot unpack. Song
        ## strength says "stronger" now, everywhere the shelf speaks; "warmer"
        ## belongs to hearts and hearths alone.
        for entry: Dictionary in BeautyContent.CHARMS:
                if not entry.has("song_damage"):
                        continue
                var key := String(entry["key"])
                for tier in [1, 2, 3]:
                        var blurb := BeautyContent.charm_blurb(key, tier)
                        if not ok("warmer" not in blurb and "stronger" in blurb,
                                        "the shelf line for %s tier %d still borrows the draft's warmth word: %s" % [key, tier, blurb]):
                                return false
        return true

func _check_a_charm_can_be_bought_twice(game: Node) -> bool:
        ## A charm used to be bought once and then never again, which meant the
        ## shelf ran out of things to do for a hero whose socket count had already
        ## caught up with it. The second copy is the same ware made stronger, so a
        ## deep walk keeps paying out on wares the player already loves.
        game._start_run(2)
        await frames(6)
        game.player.global_position = game.world.merchant_position + Vector3(1.0, 0.0, 0.0)
        await frames(2)
        game.sparkles = 999
        game._on_buy_requested("boots")
        await frames(2)

        if not ok(wears(game.charms_equipped, "boots", 1),
                        "the first copy of the charm was not bought at tier 1: %s" % str(game.charms_equipped)):
                return false
        if not ok(game.sparkles == 999 - BeautyContent.charm_price("boots", 1),
                        "the first copy charged the wrong price: %d left" % game.sparkles):
                return false

        game._on_buy_requested("boots")
        await frames(2)
        if not ok(wears(game.charms_equipped, "boots", 2),
                        "buying the same charm again did not give a second, stronger copy: %s" % str(game.charms_equipped)):
                return false
        if not ok(game.sparkles == 999 - BeautyContent.charm_price("boots", 1) - BeautyContent.charm_price("boots", 2),
                        "the second copy charged the wrong price: %d left" % game.sparkles):
                return false
        if not ok(BeautyContent.charm_price("boots", 2) > BeautyContent.charm_price("boots", 1),
                        "the deeper copy is not more expensive, so there is no reason to earn it"):
                return false

        # Both copies must be WORN when both are bought, because capacity now
        # outruns the shelf -- a second purchase that sat in a pocket would be the
        # old bug wearing a new hat.
        if not ok(wears(game.charms_equipped, "boots", 1) and wears(game.charms_equipped, "boots", 2),
                        "both copies of a charm should be on together: %s" % str(game.charms_equipped)):
                return false

        # The shelf now deepens to tier III, so a THIRD purchase is legal and worn
        # with the others -- capacity grows with depth, so nothing needs evicting.
        game._on_buy_requested("boots")
        await frames(2)
        if not ok(wears(game.charms_equipped, "boots", 3),
                        "the third copy of a charm should wear beside the others: %s" % str(game.charms_equipped)):
                return false

        # A FOURTH purchase must be refused by the cart, loudly and without
        # charging: the deepest tier is the end of that ware, not a silent no-op.
        var purse: int = game.sparkles
        var before: int = game.charms_owned.size()
        game._on_buy_requested("boots")
        await frames(2)
        if not ok(game.sparkles == purse,
                        "buying past the deepest tier charged anyway: %d -> %d" % [purse, game.sparkles]):
                return false
        if not ok(game.charms_owned.size() == before,
                        "buying past the deepest tier added an unbacked copy: %s" % str(game.charms_owned)):
                return false
        if not ok(newest_line_mentioning(game.ui._log_label, "Swift Boots").length() > 0,
                        "buying past the deepest tier said nothing at all"):
                return false

        # And the copies must actually differ in strength, which is the whole
        # reason deeper ones exist.
        var base := float(BeautyContent.charm_effects_at("boots", 1).get("speed", 1.0))
        var deep := float(BeautyContent.charm_effects_at("boots", 3).get("speed", 1.0))
        if not ok(deep > base,
                        "the deeper copy is no stronger (speed %f vs %f)" % [deep, base]):
                return false
        # ...and the blurb it sells itself with must tell the truth about that.
        var blurb := BeautyContent.charm_blurb("boots", 3)
        if not ok(blurb.contains("%d%%" % roundi((deep - 1.0) * 100.0)),
                        "the deeper copy's description does not match its numbers: %s" % blurb):
                return false
        print("TIERS boots: tier1 %s / tier3 %s at %d and %d sparkles" % [
                base, deep, BeautyContent.charm_price("boots", 1), BeautyContent.charm_price("boots", 3)])
        return true

func _check_a_deeper_walk_opens_more_sockets(game: Node) -> bool:
        ## The play screen has to SHOW the room, not just the wares. A full loadout
        ## used to be a dead end with nothing on the HUD to say otherwise; now the
        ## strip draws an empty socket per one a deeper walk would open, so
        ## "everything is full" reads as "go further down" instead.
        game._start_run(1)
        await frames(6)
        game.sparkles = 9999
        for key in ["boots", "scarf", "echo"]:
                game._on_buy_requested(key)
        game._refresh_ui()
        await frames(2)
        var worn_shallow: int = game.charms_equipped.size() + game.stanzas_equipped.size()
        var shallow: int = game.ui._vitals.slot_capacity
        # Floor 1 has three sockets, so buying three charms fills it exactly -- and
        # the strip must show that honestly rather than padding itself with
        # pretend room. The songs sit beside the charms, not inside their budget.
        if not ok(shallow == game.loadout_capacity() + game.stanzas_equipped.size(),
                        "the strip shows %d sockets for %d charm sockets plus %d worn songs" % [
                                shallow, game.loadout_capacity(), game.stanzas_equipped.size()]):
                return false
        if not ok(game.ui._vitals.equipped.size() == worn_shallow,
                        "a filled strip dropped a worn ware: %s" % str(game.ui._vitals.equipped)):
                return false

        # Descending is what opens room, and the strip has to show it immediately --
        # growth the player can never see is not growth. `keep_progress` is the
        # "wander deeper" path, so the loadout survives it -- which is exactly the
        # path whose growth this check is about.
        game._start_run(BeautyContent.CAMPAIGN_LENGTH, true)
        await frames(6)
        game._refresh_ui()
        await frames(2)
        var deep: int = game.ui._vitals.slot_capacity
        if not ok(deep > shallow,
                        "the strip did not grow on a deeper floor (%d -> %d sockets): growth the player can never see is not growth" % [
                                shallow, deep]):
                return false
        if not ok(game.charms_equipped.size() == worn_shallow - game.stanzas_equipped.size(),
                        "going deeper took wares off the hero (%d -> %d)" % [worn_shallow, game.charms_equipped.size()]):
                return false
        # Everything worn must still be on screen at the widest loadout.
        if not ok(game.ui._vitals.equipped.size() == game.charms_equipped.size() + game.stanzas_equipped.size(),
                        "a deeper floor's strip dropped a worn ware: %s" % str(game.ui._vitals.equipped)):
                return false
        print("LOADOUT sockets: floor 1 -> %d, asked for floor %d -> %d (floor_number now %d, capacity() says %d)" % [
                shallow, BeautyContent.CAMPAIGN_LENGTH, deep, game.floor_number, game.loadout_capacity()])
        return true

func _check_a_full_loadout_is_never_emptied(game: Node) -> bool:
        ## Buying used to evict: with every slot full, a fourth purchase silently
        ## dropped the oldest worn charm and said nothing, so the player watched a
        ## build change with no explanation. Capacity now outruns the shelf, so the
        ## loadout only ever grows -- nothing the hero paid for is ever taken away.
        game.sparkles = 100000
        # Buy five wares twice over, so the check covers both ways a loadout grows:
        # new icons, and deeper copies of icons the hero already loves. Buying is
        # synchronous -- no await, because a per-purchase frame wait made this
        # fixture alone blow the suite's runtime budget. The five are charms no
        # earlier check in this suite touches, so the arithmetic below counts THIS
        # check's purchases and nothing else's -- the shelf order says which.
        var owned_before: int = game.charms_owned.size()
        for _pass in 2:
                for key in ["ember", "moss", "honey", "pebble", "firefly"]:
                        game._on_buy_requested(key)
        var after_buys := worn_keys(game.charms_equipped)
        # Five wares bought twice is ten purchases, and with capacity this deep every
        # one of them is on: the old cap would have thrown seven away silently.
        if not ok(game.charms_owned.size() == owned_before + 10,
                        "ten wares were bought and the shelf holds %d (was %d): %s" % [
                                game.charms_owned.size(), owned_before, str(game.charms_owned)]):
                return false
        if not ok(after_buys.size() == game.charms_owned.size(),
                        "the shelf grew but the hero is not wearing all of it: %s" % str(after_buys)):
                return false
        if not ok(wears(game.charms_equipped, "ember", 1) and wears(game.charms_equipped, "ember", 2) \
                        and wears(game.charms_equipped, "firefly", 2),
                        "a bought copy is missing from the hero: %s" % str(after_buys)):
                return false

        # Toggling one OFF and back ON must not disturb any of the others.
        game._on_charm_equip_requested("moss", 1)
        game._on_charm_equip_requested("moss", 1)
        var after_toggle := worn_keys(game.charms_equipped)
        if not ok(after_toggle == after_buys,
                        "resting a ware and wearing it again changed the rest of the loadout: %s -> %s" % [
                                str(after_buys), str(after_toggle)]):
                return false
        if not ok(game.charms_owned.size() >= 5,
                        "toggling wear lost ownership: %s" % str(game.charms_owned)):
                return false
        print("LOADOUT all %d bought wares stay worn through a toggle" % after_buys.size())
        return true

func _check_a_full_lantern_sells_honest_words(game: Node) -> bool:
        ## Buying while the CURRENT floor's lantern is full used to charge the hero,
        ## drop the ware it had just sold (the truncation keeps the first N worn),
        ## and log "%s is on" about a charm the effects table never saw. The equip
        ## shelf refuses the same overfill with honest words; the buy shelf now
        ## sells the same truth: charged, owned, wrapped for later -- worn the
        ## moment a deeper floor opens the room.
        game._start_run(1)
        await frames(6)
        game.sparkles = 99999
        for key in ["boots", "scarf", "echo"]:
                game._on_buy_requested(key)
        await frames(2)
        if not ok(game.charms_equipped.size() == game.loadout_capacity(),
                        "fixture: three buys should fill the floor-1 lantern (%d worn of %d sockets)" % [
                                        game.charms_equipped.size(), game.loadout_capacity()]):
                return false
        var purse: int = game.sparkles
        var owned_before: int = game.charms_owned.size()
        game._on_buy_requested("socks")
        await frames(2)
        # The sale itself must stay honest: charged the real price, ware on the shelf.
        if not ok(game.sparkles == purse - BeautyContent.charm_price("socks", 1),
                        "a full-lantern sale should still charge the real price: %d -> %d (price %d)" % [
                                        purse, game.sparkles, BeautyContent.charm_price("socks", 1)]):
                return false
        if not ok(game.charms_owned.size() == owned_before + 1,
                        "the paid-for ware must still reach the shelf: %s" % str(game.charms_owned)):
                return false
        # The worn loadout may not read overfull -- the strip cannot draw sockets
        # it does not have -- and nothing already worn may be evicted.
        if not ok(game.charms_equipped.size() == game.loadout_capacity(),
                        "the worn loadout must stay exactly at capacity: %d worn of %d sockets" % [
                                        game.charms_equipped.size(), game.loadout_capacity()]):
                return false
        var worn := worn_keys(game.charms_equipped)
        if not ok(worn.has("boots") and worn.has("scarf") and worn.has("echo"),
                        "the sale disturbed the wares already worn: %s" % str(worn)):
                return false
        # The words are the defect: "is on" about a ware the effects table never
        # saw. A full lantern sells it as wrapped for later.
        var line := newest_line_mentioning(game.ui._log_label, "Wool Socks")
        if not ok(line.contains("wrapped for later"),
                        "buying with a full lantern claimed the ware was worn: %s" % line):
                return false
        print("LOADOUT full-lantern sale: charged %d, owned, wrapped for later (%d worn of %d sockets)" % [
                        purse - game.sparkles, game.charms_equipped.size(), game.loadout_capacity()])
        # Restore the depth the later fixtures assume: their loadouts count on
        # the wider floor-13 lantern.
        game._start_run(BeautyContent.CAMPAIGN_LENGTH, true)
        await frames(6)
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
        await frames(4)
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
        # The verse shelf must not print a ceiling: "2/2" taught the player that
        # songs were finished, and sent them looking elsewhere for upgrades. The
        # CHARM shelf legitimately prints worn/room (that is the room to grow
        # into), so this looks at the songs heading and nothing else -- found by
        # its title, not by walking the whole frame: a full lantern makes the
        # charm heading read 3/3, which is honest, not a ceiling.
        var songs_row := _shelf_heading(game.ui._shop_frame, "LANTERN SONGS")
        if not ok(songs_row != null,
                        "the songs shelf heading is missing from the cart entirely"):
                return false
        var songs_texts: Array[String] = []
        var songs_ceiling := false
        for child in songs_row.get_children():
                var label := child as Label
                if label == null:
                        continue
                var text := String(label.text)
                if not text.is_empty():
                        songs_texts.append(text)
                if text.is_empty() or not text.contains("/"):
                        continue
                var number := text.get_slice("/", 0).strip_edges()
                var denominator := text.get_slice("/", 1).strip_edges()
                # A ceiling is n/n -- reached and immovable. n/m with room left is not.
                if number.is_valid_int() and denominator.is_valid_int() and number == denominator:
                        songs_ceiling = true
        if not ok(not songs_ceiling,
                        "the cart's LANTERN SONGS heading prints a reached x/x ceiling; nothing in this game has one: %s" % [songs_texts]):
                return false
        game.ui.close_panels()
        await frames(2)
        return true

## The draft's promise is three distinct gifts at every depth a walk can
## reach, and the empty-pool fallback in _open_draft is a guard for content
## bugs, not a path a player ever meets. Both readings die if the pool thins:
## a floor whose available boons drop under three deals two cards and calls
## it a level, and a floor with none left walks into the fallback -- which
## then has to survive the wedged state it guards against. Pin the pool's
## own floor: everywhere the campaign and the endless walk go, at least
## three deep.
func _check_the_boon_pool_never_empties() -> bool:
        var depths: Array[int] = []
        for floor_number in range(1, BeautyContent.CAMPAIGN_LENGTH + 1):
                depths.append(floor_number)
        for depth in [BeautyContent.CAMPAIGN_LENGTH + 1, BeautyContent.CAMPAIGN_LENGTH + 61, 287, 10000]:
                depths.append(depth)
        for depth in depths:
                var available := 0
                for boon: Dictionary in RunBoons.BOON_POOL:
                        if depth >= int(boon.get("min_floor", 1)):
                                available += 1
                if not ok(available >= 3,
                                "floor %d's draft can only offer %d gifts -- the pool thinned under the three the draft promises" % [depth, available]):
                        return false
        print("LOADOUT boon pool: %d boons, at least %d offered at every probed depth" % [RunBoons.BOON_POOL.size(), 3])
        return true

func _all_labels(node: Node) -> Array:
        var out: Array = []
        for child in node.get_children():
                if child is Label:
                        out.append(child)
                out.append_array(_all_labels(child))
        return out

## The heading HBox whose title Label paints exactly `title`, or null. Shelf
## headings are icon + title + count rows, so a count can be judged by the
## shelf it belongs to rather than by walking the whole frame -- the charm
## heading's honest worn/room reads 3/3 whenever the lantern is full.
func _shelf_heading(node: Node, title: String) -> HBoxContainer:
        for child in node.get_children():
                if child is HBoxContainer:
                        for sub in child.get_children():
                                if sub is Label and String(sub.text) == title:
                                        return child
                var deeper := _shelf_heading(child, title)
                if deeper != null:
                        return deeper
        return null
