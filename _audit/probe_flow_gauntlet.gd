extends SceneTree
## Asserting dev probe — Not shipped. Exits non-zero on any violated invariant.
##
## Interleaves every mode transition over several floors and asserts the two
## invariants the suites check one at a time: the visible panel always matches
## the mode, and floor-scoped state (lullaby, beat ring, pending boons) never
## survives a floor load or a restart that should have ended it. Runs the real
## scene: pause/resume, journal, drafts, settings over draft/shop/pause, the
## cart, a dragon lullaby (started, killed by a restart, won for real), the
## nap card, back-to-title and the story intro.
##
## godot --headless --path . --script res://_audit/probe_flow_gauntlet.gd
func frames(n: int) -> void:
        for i in range(n):
                await process_frame

var failures := 0

func check(condition: bool, label: String) -> void:
        if not condition:
                failures += 1
                printerr("PROBE_FAIL: " + label)

func panel_state(game: Node) -> Array:
        # [overlay_visible, shop_visible, beat_visible]
        return [
                game.ui._overlay_card.visible,
                game.ui._shop_card.visible,
                game.ui._beat_ring.visible,
        ]

func check_panels(game: Node, context: String) -> void:
        await frames(2)
        var state := panel_state(game)
        var mode: int = game.mode
        var want_overlay: bool = mode in [
                game.Mode.MENU, game.Mode.PAUSED, game.Mode.DRAFT, game.Mode.DEAD, game.Mode.ENDING]
        var want_shop: bool = mode in [
                game.Mode.SHOP, game.Mode.JOURNAL, game.Mode.SETTINGS]
        check(state[0] == want_overlay,
                "%s: overlay=%s but mode=%s" % [context, state[0], mode])
        check(state[1] == want_shop,
                "%s: shopcard=%s but mode=%s" % [context, state[1], mode])
        if game.mode != game.Mode.PLAYING or not game._lullaby_active:
                check(state[2] == false,
                        "%s: beat ring visible outside an active lullaby" % context)

func settle_drafts(game: Node) -> void:
        var guard := 0
        while game.pending_boons > 0 and guard < 40:
                guard += 1
                if game.mode == game.Mode.DRAFT and not game._draft_offers.is_empty():
                        game.pick_boon(String(game._draft_offers[0].get("key", "")))
                await frames(2)
        check(game.pending_boons == 0, "drafts never settled (pending=%d)" % game.pending_boons)

func _initialize() -> void:
        call_deferred("_run")

func _run() -> void:
        var packed: PackedScene = load("res://scenes/main.tscn")
        var game: Node = packed.instantiate()
        root.add_child(game)
        await frames(3)

        # --- Fresh walk, then the modal gauntlet on floor 1. ---
        game._start_run(1)
        await frames(4)
        check(game.mode == game.Mode.PLAYING, "start did not reach PLAYING")
        await check_panels(game, "floor1 walk")

        # Pause/resume twice.
        game._advance_pause_state()
        await check_panels(game, "paused")
        game._advance_pause_state()
        await check_panels(game, "resumed")
        game._advance_pause_state()
        await check_panels(game, "paused 2")
        # Settings from the pause card, close, and the pause card must return.
        game._open_settings()
        await check_panels(game, "settings from pause")
        game._close_modal()
        await frames(2)
        check(game.mode == game.Mode.PAUSED, "settings close did not return to pause (mode=%d)" % game.mode)
        await check_panels(game, "back on pause card")
        game._resume_game()
        await check_panels(game, "resumed 2")

        # Journal mid-walk.
        game._open_journal()
        await check_panels(game, "journal")
        game._close_modal()
        await check_panels(game, "journal closed")

        # A level-up draft answered by digit-free direct pick.
        game._gain_xp(200)
        await frames(2)
        await settle_drafts(game)
        await check_panels(game, "after draft")

        # Settings DURING the draft: the pick must survive as a pending boon and
        # the draft must come back once the panel closes.
        game._gain_xp(200)
        await frames(2)
        if game.mode == game.Mode.DRAFT:
                game._open_settings()
                await check_panels(game, "settings over draft")
                game._close_modal()
                await frames(2)
                check(game.pending_boons > 0, "settings swallowed a pending draft boon")
                # The 0.1s HUD tick re-opens the draft.
                await frames(10)
                await settle_drafts(game)
                await check_panels(game, "draft returned after settings")
        else:
                check(false, "xp did not open a draft; cannot probe the settings-over-draft path")

        # --- Floor 2: Peddle's cart, buy, wear, rest; settings collapses it. ---
        game._start_run(2)
        await frames(4)
        check(game.merchant_exists, "floor 2 has no merchant")
        game.player.global_position = Vector3(game.world.merchant_position.x, 0.05, game.world.merchant_position.z)
        await frames(2)
        game._open_shop()
        await check_panels(game, "shop")
        game.sparkles = 500
        game._on_buy_requested("boots")
        await frames(2)
        await check_panels(game, "shop after buy")
        # Settings over the shop collapses the shop to the walk (documented route).
        game._open_settings()
        await check_panels(game, "settings over shop")
        check(game.mode == game.Mode.SETTINGS, "settings over shop did not open")
        game._close_modal()
        await frames(2)
        check(game.mode == game.Mode.PLAYING, "settings close from shop did not land on the walk (mode=%d)" % game.mode)
        await check_panels(game, "walk after shop collapse")

        # --- Dragon floor: lullaby, restart mid-lullaby, then win it. ---
        game._start_run(5)
        await frames(4)
        check(game.dragon_exists, "floor 5 has no dragon")
        game._begin_dragon_lullaby()
        await frames(2)
        check(game._lullaby_active, "dragon lullaby did not start")
        # A restart must end the lullaby and its ring.
        game._start_run(4)
        await frames(4)
        check(not game._lullaby_active, "a fresh walk kept the old lullaby alive")
        check(not game.ui._beat_ring.visible, "a fresh walk left the beat ring up")

        # Back to 5 and finish the lullaby for real. Beats land on the physics
        # clock (0.8s apart, gold every other beat), so the loop waits real
        # frames and only presses on a gold window.
        game._start_run(5)
        await frames(4)
        game._begin_dragon_lullaby()
        var swings := 0
        while game._lullaby_active and swings < 4000:
                swings += 1
                if game._lullaby_gold:
                        game._judge_lullaby_beat()
                await frames(1)
        check(not game._lullaby_active, "lullaby never finished after %d swings" % swings)
        check(not game.dragon_exists, "the dragon stayed after its lullaby")
        check(game.stair_visible, "the stair never came back after the lullaby")
        await check_panels(game, "after dragon win")

        # --- The nap: damage to zero, then a fresh walk from the nap card. ---
        game._start_run(1)
        await frames(4)
        game.invulnerable_time = 0.0
        game.player.invulnerable_time = 0.0
        game._damage_player(9999, "probe")
        await frames(2)
        check(game.mode == game.Mode.DEAD, "a lethal bump did not nap the walk (mode=%d, hp=%f)" % [game.mode, game.hp])
        await check_panels(game, "nap card")
        game._on_restart_requested(false)
        await frames(4)
        check(game.mode == game.Mode.PLAYING, "restart from the nap card did not start a walk")
        check(game.hp == game.hp_max, "a fresh walk did not rest to full")
        await check_panels(game, "walk after nap restart")

        # --- Back to title from the pause card; menu rebuilds. ---
        game._pause_game()
        game._back_to_title()
        await frames(4)
        check(game.mode == game.Mode.MENU, "back to title did not reach MENU (mode=%d)" % game.mode)
        await check_panels(game, "title")
        # The story intro from Play, skipped, straight into the walk.
        game._begin_intro()
        await frames(2)
        check(game._intro_active, "play did not begin the story")
        game._finish_intro()
        await frames(4)
        check(game.mode == game.Mode.PLAYING, "skipping the story did not start the walk")

        if failures == 0:
                print("PROBE_OK")
        else:
                print("PROBE_FAILED with %d invariant violations" % failures)
        quit(1 if failures > 0 else 0)
