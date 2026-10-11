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
	if not await _check_a_charm_can_be_bought_twice(game):
		return
	if not await _check_a_deeper_walk_opens_more_sockets(game):
		return
	if not await _check_a_full_loadout_is_never_emptied(game):
		return
	if not await _check_free_items_do_not_claim_to_be_owned(game):
		return
	if not await _check_stanza_cards_paint_song_glyphs(game):
		return
	if not await _check_colliding_sockets_keep_their_own_art(game):
		return
	if not await _check_every_worn_ware_gets_a_socket(game):
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
	# CHARM shelf legitimately prints worn/room (that is the room to grow into),
	# so this only looks at the songs heading, which is the one that used to lie.
	var verse_ceiling := false
	for label in _all_labels(game.ui._shop_frame):
		var text := String(label.text)
		if text.is_empty() or not text.contains("/"):
			continue
		var number := text.get_slice("/", 0).strip_edges()
		var denominator := text.get_slice("/", 1).strip_edges()
		if not number.is_valid_int() or not denominator.is_valid_int():
			continue
		# A ceiling is n/n -- reached and immovable. n/m with room left is not.
		if number == denominator:
			verse_ceiling = true
	if not ok(not verse_ceiling,
			"the cart still prints a reached x/x ceiling; nothing in this game has one"):
		return false
	game.ui.close_panels()
	await frames(2)
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

func _all_labels(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_all_labels(child))
	return out
