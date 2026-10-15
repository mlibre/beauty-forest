extends "res://tests/support/test_case.gd"
## Regression coverage for central run-state transitions. In particular, an
## automatic song-note already in flight must not grant combat rewards while
## the game is paused or behind another modal.
##
## Loadout and shop behaviour lives in regression_loadout.gd; this suite is
## about what the run state and the screens do with it.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const ForestWorld := preload("res://scripts/forest_world.gd")
const HeartPickup := preload("res://scripts/heart_pickup.gd")
const SongNote := preload("res://scripts/song_note.gd")
const Wisp := preload("res://scripts/wisp.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_MAIN_FLOW"
    TestProfile.begin("main_flow")
    call_deferred("_run")

## Answer every pending level-up draft. The draft pauses the walk on purpose,
## so a suite that granted XP hands the pick back to Mote before driving the
## mode machine -- otherwise the pause/resume checks below would be testing
## Mote's card table instead of the game.
func settle_drafts(game: Node) -> void:
    var guard := 0
    while game.pending_boons > 0 and guard < 40:
        guard += 1
        if game.mode == game.Mode.DRAFT and not game._draft_offers.is_empty():
            game.pick_boon(String(game._draft_offers[0].get("key", "")))
        await frames(2)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await frames(2)

    game._start_run(1)
    await frames(4)
    if not ok(game.mode == game.Mode.PLAYING, "run did not enter PLAYING"):
        return
    if not ok(not game.wisps.is_empty(), "floor spawned no wisps"):
        return

    # A heart's warmth is fixed when it drops. Changing charms before walking
    # over it must not silently recalculate the reward the player already
    # earned (the old callback rebuilt the amount from current loadout).
    var stored_heart := HeartPickup.new()
    stored_heart.heal_amount = 30.0
    game.hp = 40.0
    game.charms_equipped.clear()
    game.charm_effects = {"heart_heal": 10.0}
    game._on_heart_collected(stored_heart)
    if not ok(is_equal_approx(game.hp, 70.0), "a heart used the current charm loadout instead of its stored warmth (%f, expected 70.0)" % game.hp):
        stored_heart.free()
        return
    stored_heart.free()

    # Loading a charm must not erase max warmth earned by earlier level-ups.
    # Recomputing the loadout used to reset hp_max to the base style + scarf
    # only, so the first shop/stanza interaction silently discarded progress.
    game.hp_max = 140.0
    game.hp = 140.0
    game.level_hp_bonus = 40.0
    game.charms_owned = loadout(["boots"])
    game._on_charm_equip_requested("boots", 1)
    if not ok(is_equal_approx(game.hp_max, 140.0), "wearing a charm erased level-up max warmth (%f, expected 140.0)" % game.hp_max):
        return

    # Buying the Wool Scarf grants +30 max warmth exactly once, and only while
    # it is actually worn. Max warmth is recomputed from the equipped loadout on
    # every shop change, so a direct bump here was overwritten a few lines later
    # (and would have been double-counted if it had not been).
    game._pause_game()
    game.selected_style = "standard"
    game.level_hp_bonus = 0.0
    game.charms_owned.clear()
    game.charms_equipped.clear()
    game.stanzas_equipped = {"petals": true, "echoes": true}
    game.mote_verse_key = ""
    game._recalculate_loadout(false)
    if not ok(is_equal_approx(game.hp_max, 100.0), "the scarf fixture did not start from 100 max warmth (%f)" % game.hp_max):
        return
    game.sparkles = 40
    game._on_buy_requested("scarf")
    if not ok(is_equal_approx(game.hp_max, 130.0), "a worn Wool Scarf gave %f max warmth, expected 130.0" % game.hp_max):
        return
    # A ware that is owned but NOT worn must not inflate max warmth behind the
    # player's back: max warmth is rebuilt from the WORN loadout, so a pocketed
    # scarf is worth exactly nothing. The old check here forced this with a full
    # loadout of three, back when three was the cap; now the honest way to reach
    # the same state is to own the scarf and rest it by hand.
    game.charms_equipped = loadout(["boots", "moss", "honey"])
    game.charms_owned = loadout(["boots", "moss", "honey"])
    game._recalculate_loadout(false)
    var pocketed_before: float = game.hp_max
    game.charms_equipped = loadout([["scarf", 1], ["boots", 1], ["moss", 1], ["honey", 1]])
    game.charms_owned = loadout([["scarf", 1], ["boots", 1], ["moss", 1], ["honey", 1]])
    game._recalculate_loadout(false)
    var resting_before: float = game.hp_max
    if not ok(is_equal_approx(resting_before, pocketed_before + 30.0),
            "wearing a Wool Scarf did not add its 30 max warmth (%f -> %f)" % [pocketed_before, resting_before]):
        return
    game._on_charm_equip_requested("scarf", 1)
    if not ok(is_equal_approx(game.hp_max, pocketed_before),
            "a RESTED Wool Scarf still counted toward max warmth (%f)" % game.hp_max):
        return
    game._on_charm_equip_requested("scarf", 1)
    game._resume_game()
    await frames(2)

    # Escape must close a modal through the same path as its visible button.
    # The direct state callback used to resume gameplay while leaving Peddle's
    # shop card and scrim on screen, so the next input landed behind a dead
    # modal instead of the walk.
    game.merchant_exists = true
    game.player.global_position = game.world.merchant_position
    game._open_shop()
    await frames(2)
    if not ok(game.mode == game.Mode.SHOP, "shop did not open for modal-dismiss regression"):
        return
    game._close_modal()
    await frames(2)
    if not ok(game.mode == game.Mode.PLAYING, "Escape did not close the shop"):
        return
    if not ok(not game.ui._shop_card.visible and not game.ui._shop_scrim.visible, "Escape left the shop card and scrim visible"):
        return
    if not ok(game.player.control_enabled, "Escape left the player disabled after closing the shop"):
        return

    # Mote's not-near-the-cart hint used to promise absolute floors
    # ("2, 4, 7, and 10"), which in the endless chapters is a lie: the cart
    # parks on those STORY positions of every thirty-floor stretch, so
    # floor 32 is a cart floor too and the old line hid it. The hint must
    # describe the cycle the schedule actually runs on.
    game.player.global_position += Vector3(6.0, 0.0, 0.0)
    # The hint moved from the hidden log strip to the toast, the one voice a
    # walk actually hears. Clear any queued toast first so the hint is the one
    # thing on the label when it is read. The press arrives through the F
    # alias -- the cart's own touch button is gone (E answers near the cart
    # now), and F far from Peddle is exactly the "not near the cart" path.
    game.ui.clear_toast()
    var f_key := InputEventKey.new()
    f_key.pressed = true
    f_key.keycode = KEY_F
    f_key.physical_keycode = KEY_F
    game._unhandled_input(f_key)
    await frames(2)
    # The toast label is the witness, and the hint must be ON it: a toast that
    # is still queued behind an earlier one would leave the old message up and
    # the assertion would judge the wrong words.
    var shop_strip: String = game.ui._toast_label.text
    if not ok("every thirty-floor stretch" in shop_strip,
            "the not-near-cart hint does not describe the story cycle; Mote's strip said: %s" % shop_strip):
        return
    if not ok(not ("floors 2, 4, 7, and 10" in shop_strip),
            "the not-near-cart hint still names absolute floors; Mote's strip said: %s" % shop_strip):
        return

    # Turning on reduced motion snaps the world, the wisps and the hero to
    # their calm state; the mote's scale branch had no rest-state reset, so
    # it stayed frozen at whatever the wobble sine held at that instant --
    # the one companion visibly left mid-motion (or mid-joy) forever.
    game.settings["reduced_motion"] = false
    game._mote_seed = TAU / 8.0
    game._mote_joy = 0.0
    game._update_mote(0.016)
    var wobbling: float = game.mote.scale.x
    if not ok(wobbling > 1.0,
            "fixture expected a mid-wobble mote scale, got %f" % wobbling):
        return
    game.settings["reduced_motion"] = true
    game._update_mote(0.016)
    if not ok(game.mote.scale.is_equal_approx(Vector3.ONE),
            "reduced motion left the mote frozen at scale %f instead of its rest shape" % game.mote.scale.x):
        return
    game.settings["reduced_motion"] = false
    game._update_mote(0.016)

    # A Big Feeling is meant to be soothed by SITTING with it (two gentle
    # rounds of E-on-gold). The automatic lantern must never wear it down
    # instead: that skipped the whole designed moment and still handed out
    # the "sat with a Big Feeling" sticker.
    var feeling: Wisp = null
    game._spawn_feeling(BeautyContent.feeling_for_floor(8), 8)
    for wisp: Wisp in game.wisps:
        if wisp.is_feeling:
            feeling = wisp
    if not ok(feeling != null, "the feeling floor spawned no Big Feeling"):
        return
    feeling.global_position = game.player.global_position + Vector3(1.2, 0.0, 0.0)
    feeling._boss_window = 1.0  # the gold window is open
    var feeling_health: float = feeling.health
    game._do_pulse(feeling, 2.2)
    if not ok(is_equal_approx(feeling.health, feeling_health), "the automatic pulse damaged a Big Feeling (%f -> %f)" % [feeling_health, feeling.health]):
        return
    game._do_pulse(feeling, 2.2)
    if not ok(is_equal_approx(feeling.health, feeling_health), "repeated automatic pulses damaged a Big Feeling (%f -> %f)" % [feeling_health, feeling.health]):
        return
    if not ok(feeling.alive and not feeling.soothed, "the automatic pulse soothed a Big Feeling on its own"):
        return

    # The intended path must still work: sit with it and hum on the gold.
    game._begin_feeling_lullaby(feeling)
    for _hit in range(6):
        if game._feeling_rest > 0:
            game._feeling_rest = 0  # the breathing beats have elapsed
        game._lullaby_gold = true
        game._judge_feeling_beat()
    if not ok(feeling.soothed or not is_instance_valid(feeling), "the Big Feeling could not be soothed by sitting with it"):
        return

    # A heal that cannot happen must never be charged for. Pause the live
    # floor while checking the accounting so automatic combat cannot add
    # sparkles between the direct purchase and its assertion.
    game._pause_game()
    game.hp = game.hp_max
    game.sparkles = 9
    game._on_buy_requested("tea")
    await frames(2)
    if not ok(game.sparkles == 9, "buying Warm Tea at full warmth charged %d sparkles for nothing" % (9 - game.sparkles)):
        return
    game.hp = game.hp_max - 40.0
    game._on_buy_requested("tea")
    await frames(2)
    if not ok(game.sparkles == 6, "a needed Warm Tea did not cost 3 sparkles (%d left)" % game.sparkles):
        return
    if not ok(game.hp == game.hp_max, "Warm Tea did not restore the warmth it promised"):
        return
    game._resume_game()
    await frames(2)

    # Start a REAL run before reaching for a wisp. This check inherited whatever
    # the previous one left behind, which used to be the live floor's spawn; now
    # that the title backdrop has its own drifting wisps, `wisps[0]` would be one
    # of those and it would never resolve.
    game._start_run(1)
    await frames(6)
    var target: Wisp = game.wisps[0]
    var retained: Array[Wisp] = [target]
    for wisp: Wisp in game.wisps:
        if wisp != target:
            wisp.queue_free()
    game.wisps.assign(retained)
    target.global_position = game.player.global_position + Vector3(1.0, 0.0, 0.0)
    target.health = 1000.0
    target.max_health = 1000.0
    target.set_shielded(false)
    for old_note: SongNote in game.notes:
        old_note.queue_free()
    game.notes.clear()

    # The checks above leave three charms worn, so a soothed wisp's payout
    # depends on their soul multipliers. This check is about whether an
    # in-flight note is HELD while paused, not about what a wisp is worth, so
    # start from a clean loadout rather than inheriting whatever the earlier
    # checks happened to leave equipped.
    game.charms_equipped.clear()
    game.charms_owned.clear()
    game.stanzas_equipped = {}
    game._recalculate_loadout(false)
    game.xp = 0
    game.sparkles = 0
    game._fire_song_note(target)
    var note: SongNote = game.notes.back()
    target.health = note.damage
    game.pulse_cooldown = 9999.0
    game.note_cooldown = 9999.0

    await settle_drafts(game)
    game._pause_game()
    note.global_position = target.global_position + Vector3.UP * (0.70 * target.visual_scale)
    note.launch(Vector3.ZERO)
    await physics_frame
    await physics_frame

    if not ok(game.mode == game.Mode.PAUSED, "pause did not retain PAUSED mode"):
        return
    if not ok(is_instance_valid(target) and not target.soothed, "an in-flight song-note progressed combat while paused"):
        return
    if not ok(game.xp == 0, "combat XP was granted while paused"):
        return
    if not ok(game.sparkles == 0, "combat sparkles were granted while paused"):
        return

    game._resume_game()
    await frames(8)
    if not ok(not is_instance_valid(target) or target.soothed, "the automatic note did not resolve after resuming"):
        return
    if not ok(game.xp > 0, "combat XP was lost after resuming"):
        return
    if not ok(game.sparkles > 0, "combat sparkles were lost after resuming"):
        return
    await settle_drafts(game)

    # Touch callbacks must obey the same gameplay boundary as keyboard input.
    var stair: Node3D = game.world.get_node("Stairwell") as Node3D
    if not ok(stair != null, "floor stairwell was unavailable for touch regression"):
        return
    game.stair_visible = true
    stair.visible = true
    game.player.global_position = stair.global_position
    game._pause_game()
    var paused_floor: int = game.floor_number
    var paused_world: ForestWorld = game.world
    game.ui.touch_interact_requested.emit()
    await frames(4)
    if not ok(game.mode == game.Mode.PAUSED, "touch interaction changed paused mode"):
        return
    if not ok(game.floor_number == paused_floor, "touch interaction descended while paused"):
        return
    if not ok(game.world == paused_world, "touch interaction replaced the paused world"):
        return
    if not ok(not game.player.control_enabled, "paused player regained control after touch interaction"):
        return

    game._resume_game()
    game.ui.touch_interact_requested.emit()
    await frames(4)
    if not ok(game.mode == game.Mode.PLAYING, "playing touch interaction left PLAYING mode"):
        return
    if not ok(game.floor_number == paused_floor + 1, "playing touch interaction did not descend"):
        return
    if not ok(game.world != paused_world, "playing touch interaction did not replace the floor"):
        return
    if not ok(game.player.control_enabled, "playing interaction left the player disabled"):
        return

    # The pause card gained the way back to the title. The menu was a one-visit
    # room before this: reachable at boot, then gone until the app restarted.
    game._pause_game()
    await frames(2)
    game.ui.menu_requested.emit()
    await frames(4)
    if not ok(game.mode == game.Mode.MENU, "the title request left the game in mode %d" % int(game.mode)):
        return
    if not ok(game.ui._overlay_card.visible, "returning to the title left the menu card hidden"):
        return
    if not ok(not game.player.control_enabled, "returning to the title left the walk's controls live"):
        return
    # And the front door still opens: starting from the returned-to menu is the
    # same fresh walk the boot menu offers.
    game.ui.start_requested.emit("standard")
    await frames(4)
    if not ok(game.mode == game.Mode.PLAYING and game.floor_number == 1,
            "starting from the returned-to title did not begin a fresh floor-1 walk (mode %d, floor %d)" % [int(game.mode), int(game.floor_number)]):
        return

    # Mote's idle chatter must wait for a song ceremony: her timer fires on
    # the same walk the ceremony stages, and a line of weather chatter queuing
    # over "press E when the ring glows GOLD" would bury the one instruction
    # the song runs on. While the letterbox stands she stays quiet; the moment
    # the stage clears she speaks again -- on the toast, never a card.
    if not _check_mote_waits_for_the_ceremony(game):
        return
    finish(game, "BEAUTY_FOREST_MAIN_FLOW")

func _check_mote_waits_for_the_ceremony(game: Node) -> bool:
    game.ui.clear_toast()
    game.ui._cinematic_on = true
    game._mote_line_timer = 0.0
    game._process(0.02)
    if not ok(not game.ui._toast_active and game.ui._toast_queue.is_empty(),
            "Mote chattered over a song ceremony's stage"):
        return false
    game.ui._cinematic_on = false
    game._mote_line_timer = 0.0
    game._process(0.02)
    if not ok(game.ui._toast_active and game.ui._toast_label.text.begins_with("Mote:"),
            "Mote never spoke once the stage had cleared (toast says %s)" % game.ui._toast_label.text):
        return false
    game.ui.clear_toast()
    return true
