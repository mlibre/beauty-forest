extends "res://tests/support/test_case.gd"
## What the shelves and sockets DRAW, as opposed to what the screens say.
##
## The cart's card ink, the vitals strip's socket keys, and the tier pips that
## keep two copies of one charm distinguishable. Each of these was once a lie
## the shelves told: song wares painted as charms, a worn Moss Pillow wearing
## the verse's note, and a second copy of a charm invisible exactly when it
## was earned.
##
## Split out of regression_screens.gd, which carries the pause/menu truth
## checks; this file hit the 500-line ceiling, and the shelf family is a
## cohesive responsibility of its own.
##
## The bodies moved verbatim from regression_screens.gd; only the helper names
## changed, to the ones on TestCase.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const CozyVitals := preload("res://scripts/cozy_vitals.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_SHELVES"
    TestProfile.begin("shelves")
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)
    game._start_run(1)
    await frames(4)

    if not await _check_stanza_cards_paint_song_glyphs(game):
        return
    if not await _check_colliding_sockets_keep_their_own_art(game):
        return
    if not await _check_every_worn_ware_gets_a_socket(game):
        return

    await frames(30)
    game.free()
    await frames(1)
    finish(null, "BEAUTY_FOREST_SHELVES")

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
