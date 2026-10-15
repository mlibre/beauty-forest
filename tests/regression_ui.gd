extends "res://tests/support/test_case.gd"
## Layout regression for the code-built GameUI at real window sizes.
##
## Three real defects are pinned here:
##  1. Autowrapped labels with no width floor collapse their card to the width
##     of the longest word and wrap everything else one word per line, which
##     made the HUD cards ~980px/~1550px TALL — taller than the window.
##  2. Control.position is absolute once a control is in the tree, so the old
##     "negative offset from the anchor" placement put the right card, minimap,
##     hint, toast, log, story card and BOTH modal cards off-screen (the menu
##     card sat at (-450, -320) on a 1280x720 window). Every panel must now be
##     measured in real parent coordinates and land inside the window.
##  3. The 200% text-size setting widened the HUD and modal cards past the live
##     viewport, and tall modal content expanded a tiny card off-screen.
##  4. The on-screen touch controls own the bottom corners, but the layout
##     parked the grove map in the bottom-right corner *under* the SING/DASH/
##     CART/BOOK/COZY cluster and the log under the joystick, so on a
##     touchscreen both readouts were painted over by opaque buttons.
##  5. Autowrapped labels inside shrink-wrap rows (the draft's key-row hint,
##     the menu's promise plates) collapse to ~1px wide -- one letter per
##     line -- and stretch their row siblings to match (key caps once stood
##     388px tall beside the crushed hint). And _ware_card read the ware
##     card's minimum before the card's _ready had run, so it inherited
##     (0, 0): every ware button bottomed out at its 18px stylebox floor and
##     each card overflowed its button straight over the row beneath it.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyData := preload("res://scripts/beauty_data.gd")
const GameUI := preload("res://scripts/game_ui.gd")

var _ui: GameUI
var _root_rect := Rect2()

func _initialize() -> void:
        # This suite writes settings, so without a throwaway profile a run would
        # leave the PLAYER at 200% text for good -- the 200% check below saves that
        # value straight to user://.
        suite_name = "BEAUTY_FOREST_UI"
        TestProfile.begin("ui")
        call_deferred("_run")

func _settle(size: Vector2i) -> bool:
        ## Drive the window and wait for the real parent rect to adopt it, which is
        ## how the game reaches the layout (viewport resize, then fit).
        root.size = size
        root.content_scale_size = size
        for _attempt in range(40):
                await frames(2)
                if _ui._root.size.is_equal_approx(Vector2(size)):
                        return true
        return false

func _check_touch_layout(size: Vector2i) -> void:
        ## Force the on-screen touch controls on — CI and most desktop players have
        ## no touchscreen, so the default path can never see this — and assert the
        ## bottom-corner HUD is placed *around* them instead of underneath.
        if not await _settle(size):
                print("note: headless viewport did not adopt %dx%d; skipping the touch layout" % [size.x, size.y])
                return
        var was_visible := _ui._touch_root.visible
        _ui._touch_root.visible = true
        _ui._fit_layout()
        await frames(3)
        var tag := "with touch controls at %dx%d" % [size.x, size.y]
        var parent := Rect2(Vector2.ZERO, _ui._root.size)
        var cluster := _ui._touch_cluster_rect()
        var joystick := _ui._joystick_rect()
        ok(not _touch_controls_off_screen(_ui), "a touch control hangs off the screen %s" % tag)
        var map_rect := Rect2(_ui._minimap.position, _ui._minimap.size)
        var log_rect := Rect2(_ui._log_label.position, _ui._log_label.size)
        # A control that yielded (nothing on screen fits clear of the buttons) is
        # allowed to sit anywhere in the window; only what is actually painted has
        # to stay readable.
        ok(not _ui._minimap.visible or not map_rect.intersects(cluster), "the touch buttons cover the grove map %s: map=%s cluster=%s" % [tag, str(map_rect), str(cluster)])
        ok(not _ui._log_label.visible or not log_rect.intersects(joystick), "the touch joystick covers the log %s: log=%s joystick=%s" % [tag, str(log_rect), str(joystick)])
        ok(not _ui._log_label.visible or not log_rect.intersects(cluster), "the touch buttons cover the log %s: log=%s cluster=%s" % [tag, str(log_rect), str(cluster)])
        ok(parent.encloses(map_rect), "the grove map left the window %s: %s" % [tag, str(map_rect)])
        ok(parent.encloses(log_rect), "the log left the window %s: %s" % [tag, str(log_rect)])
        _ui._touch_root.visible = was_visible
        _ui._fit_layout()

func _touch_controls_off_screen(ui: GameUI) -> bool:
        var parent := ui._root.size
        for control: Control in ui._touch_buttons:
                var rect := Rect2(control.position, control.size)
                if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > parent.x or rect.end.y > parent.y:
                        return true
        var stick := Rect2(ui._touch_joystick.position, ui._touch_joystick.size)
        return stick.position.x < 0.0 or stick.position.y < 0.0 or stick.end.x > parent.x or stick.end.y > parent.y

## Find the Button behind one ware on Peddle's shelf.
##
## A ware paints its name as ink rather than a Label, so it is looked up by the
## game's own key -- `find_ware` -- and this hands back the Button that a click
## would actually hit. The old version scraped painted words for the name, which
## is exactly the coupling the picture cards exist to remove.
func _find_shop_button(key: String) -> Button:
        var card := find_ware(_ui._shop_content, key)
        return null if card == null else ware_button(card)

func _run() -> void:
        var game: Node = load("res://scenes/main.tscn").instantiate()
        root.add_child(game)
        await frames(3)
        _ui = game.ui
        if _ui == null:
                ok(false, "the game built no GameUI")
                finish(game, suite_name)
                return

        for size: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 640), Vector2i(640, 360), Vector2i(480, 900), Vector2i(480, 240)]:
                # The root Control follows the viewport rect, so drive the window and
                # wait for the parent rect to actually settle before measuring.
                root.size = size
                root.content_scale_size = size
                var settled := false
                for _attempt in range(40):
                        await frames(2)
                        if _ui._root.size.is_equal_approx(Vector2(size)):
                                settled = true
                                break
                if not settled:
                        print("note: headless viewport did not adopt %dx%d (got %s); skipping that size" % [size.x, size.y, str(_ui._root.size)])
                        continue
                _ui._fit_layout()
                await frames(3)
                var parent: Control = _ui._root
                _root_rect = Rect2(Vector2.ZERO, parent.size)
                var tag := "at %dx%d" % [size.x, size.y]

                # The vitals ring is the play screen's whole readout, so it has to stay
                # on screen and shorter than the window at every size. It is the only
                # top-left HUD element now that the word-cards are gone.
                var vitals: Control = _ui._vitals
                ok(vitals.size.y < _root_rect.size.y, "the vitals ring is %fpx tall, taller than the window %s" % [vitals.size.y, tag])
                for pair: Array in [[vitals, "vitals ring"], [_ui._minimap, "minimap"], [_ui._toast_label, "toast"], [_ui._log_label, "log"]]:
                        var control: Control = pair[0]
                        var label := String(pair[1])
                        var rect := Rect2(control.position, control.size)
                        ok(_root_rect.encloses(rect), "%s %s is outside the window: %s" % [label, tag, rect])

                # A story card and a toast can be on screen at the same time (every floor
                # load opens both on merchant and Big Feeling floors). The story card is
                # opaque and draws after the HUD, so overlapping meant the toast's text
                # was simply hidden. Measured after the layout has settled, which is how
                # the game reaches it: the viewport resize settles, then the card shows.
                _ui.show_story("The Descent Begins", "Mote heard a rumor: far below sleeps a dragon who has not napped properly in centuries.")
                _ui.show_toast("A Big Feeling wanders this floor. Wait for its GOLD halo, then press E nearby and sing with it.")
                await frames(4)
                var toast_rect := Rect2(_ui._toast_label.position, _ui._toast_label.size)
                var story_rect := Rect2(_ui._story_card.position, _ui._story_card.size)
                # Both bands must stay on screen at every size. Clearing the toast only
                # has to hold where the two can actually be stacked: a 240px-tall window
                # has no room for an 84px toast plus a 168px card, and there staying
                # on screen is the better trade.
                if toast_rect.size.y + story_rect.size.y + 4.0 + 16.0 <= _root_rect.size.y:
                        ok(not toast_rect.intersects(story_rect), "the story card covers the toast %s: toast=%s story=%s" % [tag, toast_rect, story_rect])
                ok(_root_rect.encloses(story_rect), "the story card is outside the window %s: %s" % [tag, story_rect])
                ok(_root_rect.encloses(toast_rect), "the toast is outside the window %s: %s" % [tag, toast_rect])
                _ui.close_panels()
                await frames(1)

                # Two tellings can overlap (a floor vignette under a ceremony
                # line): the second show cancels the first mid-arrival. A
                # cancelled rise must settle back to the SAME rest the layout
                # chose -- baking the half-risen y as the new rest walks the
                # card up the screen one rapid vignette at a time.
                _ui.show_story("First telling", "Mote heard a rumor: far below sleeps a dragon who has not napped properly in centuries.")
                await frames(3)
                var rest_first := _ui._story_card.position.y
                _ui.show_story("Second telling", "Mote heard the same rumor again, closer now.")
                await frames(40)
                var rest_second := _ui._story_card.position.y
                _ui.show_story("Third telling", "Mote is tired of rumors and goes to bed.")
                await frames(40)
                var rest_third := _ui._story_card.position.y
                ok(absf(rest_second - rest_first) < 1.0,
                    "a telling cancelled mid-rise moved the card's rest from %.2f to %.2f -- the half-risen y became the new rest" % [rest_first, rest_second])
                ok(absf(rest_third - rest_first) < 1.0,
                    "the card's rest kept drifting after repeated tellings: %.2f then %.2f" % [rest_second, rest_third])
                _ui.close_panels()
                await frames(1)

                # Menus must be on screen and scroll their own content, not spill out.
                _ui.show_menu(game.meta)
                await frames(4)
                var card: Control = _ui._overlay_card
                var card_rect := Rect2(card.position, card.size)
                ok(_root_rect.encloses(card_rect), "the menu card %s is outside the window: %s" % [tag, card_rect])
                ok(absf(card_rect.get_center().x - _root_rect.size.x * 0.5) < 2.0, "the menu card %s is not horizontally centered" % tag)
                ok(absf(card_rect.get_center().y - _root_rect.size.y * 0.5) < 2.0, "the menu card %s is not vertically centered" % tag)
                var content: Control = _ui._overlay_content
                ok(content.size.x <= card.size.x, "menu copy is %fpx wide inside a %fpx card %s" % [content.size.x, card.size.x, tag])

                # The menu's three promise plates: an autowrapped caption inside a
                # shrink-wrap row once squeezed each plate into a ~50px-wide,
                # 100px-tall pill with the caption broken mid-word down its length
                # ("Sin gs by itse lf"). The plates wear a width floor now, and it
                # has to hold at every window this suite walks.
                var promises: Control = _ui._overlay_content.get_node("Promises")
                for plate in promises.get_children():
                        var plate_rect: Rect2 = Rect2(plate.position, plate.size)
                        ok(plate_rect.size.x >= 100.0 and plate_rect.size.y <= 150.0,
                                "a promise plate collapsed to %s (a tall thin word-pill) %s" % [plate_rect.size, tag])

                # Rebuilding a panel must re-fit the freshly built children, not the
                # stale ones from the previous build.
                _ui.show_pause(game.meta)
                await frames(4)
                var pause_rect := Rect2(_ui._overlay_card.position, _ui._overlay_card.size)
                ok(_root_rect.encloses(pause_rect), "the pause card %s is outside the window: %s" % [tag, pause_rect])
                ok(_ui._overlay_content.size.x <= _ui._overlay_card.size.x, "pause copy is wider than its card %s" % tag)

                # The level-up draft's key row, the screen where the crash of the
                # hint was most visible: an autowrapped label in a shrink-wrap row
                # reported a ~1px minimum width, so the row squeezed the hint to
                # one letter per line (388px tall) and stretched every key cap to
                # match. The hint is a fixed one-liner and the caps shrink to
                # their own size now, at every window.
                _ui.show_draft([
                        {"key": "warmth", "glyph": "heart", "word": "More Warmth", "sub": "+20 lantern warmth, fills now"},
                        {"key": "song", "glyph": "chime", "word": "Stronger Song", "sub": "+4 song power"},
                        {"key": "both", "glyph": "soul", "word": "A Bit of Both", "sub": "+10 warmth and +2 song"},
                ], 2, "")
                await frames(4)
                for cap in _ui._overlay_content.find_children("KeyCap*", "PanelContainer", true, false):
                        var cap_rect: Rect2 = Rect2(cap.position, cap.size)
                        ok(cap_rect.size.y <= 44.0, "a draft key cap grew to %s tall (the crushed-hint stretch) %s" % [cap_rect.size, tag])
                for label in _ui._overlay_content.find_children("*", "Label", true, false):
                        if not String((label as Label).text).begins_with("tap a card"):
                                continue
                        var hint_rect: Rect2 = Rect2(label.position, label.size)
                        ok(hint_rect.size.y <= 40.0 and hint_rect.size.x >= 80.0,
                                "the draft hint collapsed to %s (one letter per line) %s" % [hint_rect.size, tag])
                _ui.close_panels()
                await frames(1)

        # The touch controls sit in the same bottom corners as the map and the log,
        # so they get their own pass at every size: without a touchscreen the
        # assertions above cannot see that collision at all.
        for touch_size: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 640), Vector2i(640, 360), Vector2i(480, 900), Vector2i(480, 240)]:
                await _check_touch_layout(touch_size)

        if failures > 0:
                finish(game, suite_name)
                return

        # Accessibility text scaling must compose with the responsive layout rather
        # than widening the HUD or modal past the live viewport. This is a separate
        # path from ordinary resize: the 200% setting changes label minimums after
        # the cards have already been laid out.
        root.size = Vector2i(640, 360)
        root.content_scale_size = Vector2i(640, 360)
        for _frame in range(6):
                await frames(2)
        _ui.apply_settings({
                "reduced_motion": false,
                "text_scale": 2.0,
                "high_contrast": false,
                "damage_taken": 0.70,
                "rhythm_window": 1.40,
                "wisp_speed": 0.85,
                "volume": 0.80,
                "muted": false,
        })
        _ui._fit_layout()
        await frames(4)
        _root_rect = Rect2(Vector2.ZERO, _ui._root.size)
        # 200% text must not push anything off screen. The vitals ring is the only
        # top-left HUD element now, but the story card and toast are the wide bands
        # that text size actually widens.
        _ui.show_story("The Descent Begins", "Mote heard a rumor: far below sleeps a dragon who has not napped properly in centuries.")
        _ui.show_toast("A Big Feeling wanders this floor. Wait for its GOLD halo, then press E nearby and sing with it.")
        await frames(4)
        var big_story := Rect2(_ui._story_card.position, _ui._story_card.size)
        var big_toast := Rect2(_ui._toast_label.position, _ui._toast_label.size)
        # At 200% on a 640x360 window the two bands cannot both fit stacked -- a
        # card that needs 294px of height has nowhere to go in 360 minus the toast.
        # What the layout guarantees either way is that each band is INSIDE the
        # window: clipped at the edge is bad, pushed off it is worse.
        ok(big_story.position.x >= 0.0 and big_story.end.x <= _root_rect.size.x + 0.5,
                "200%% text pushed the story card outside the window: %s" % str(big_story))
        ok(big_toast.position.x >= 0.0 and big_toast.end.x <= _root_rect.size.x + 0.5,
                "200%% text pushed the toast outside the window: %s" % str(big_toast))
        _ui.close_panels()
        _ui.show_settings(_ui._settings)
        await frames(4)
        var settings_card := Rect2(_ui._shop_card.position, _ui._shop_card.size)
        ok(_root_rect.encloses(settings_card), "200%% text pushed the settings card outside the window: %s" % str(settings_card))
        ok(_ui._shop_content.size.x <= _ui._shop_card.size.x, "200%% text made settings copy wider than its card")
        # The menu gets the same 200% pass as the settings panel. Its title is
        # the game's largest heading, authored one line by choice -- and a
        # one-line heading at 80px font beside a fixed roundel used to demand
        # more width than the window had, inflating the card straight off both
        # edges. The clamp that was supposed to catch this works per control,
        # and each piece fit alone; only the ROW was too wide.
        _ui.show_menu(game.meta)
        await frames(4)
        var big_menu := Rect2(_ui._overlay_card.position, _ui._overlay_card.size)
        ok(_root_rect.encloses(big_menu), "200%% text pushed the menu card outside the window: %s" % str(big_menu))
        ok(_ui._overlay_content.size.x <= _ui._overlay_card.size.x, "200%% text made menu copy wider than its card")
        _ui.apply_settings(BeautyData.default_settings())
        _ui._fit_layout()

        # The check above had to call _fit_layout() by hand, which hid the real bug:
        # the game never does that for you. Raising the text size has to reflow the
        # HUD on its own, because the panel emits settings_changed and the director
        # applies it — a player never resizes anything. Reproduce the player path
        # only: set the size, emit, and look.
        root.size = Vector2i(1280, 520)
        root.content_scale_size = Vector2i(1280, 520)
        for _frame in range(6):
                await frames(2)
        _ui.apply_settings(BeautyData.default_settings())
        _ui._fit_layout()
        await frames(4)
        # Raising the text size on a short window has to collapse the HUD: the
        # ring tucks into the corner, and the map and the chatter -- the two widest
        # things left -- both yield.
        _ui._settings["text_scale"] = 2.0
        _ui.settings_changed.emit(_ui._settings.duplicate(true))
        await frames(4)
        ok(_ui._compact_hud,
                "raising the text size on a short window left the wide HUD in place")
        ok(not _ui._minimap.visible, "the minimap stayed drawn on a collapsed HUD")
        ok(not _ui._log_label.visible, "the chatter stayed drawn on a collapsed HUD")
        var collapsed_ring := Rect2(_ui._vitals.position, _ui._vitals.size)
        var window_rect := Rect2(Vector2.ZERO, _ui._root.size)
        ok(window_rect.encloses(collapsed_ring), "the collapsed vitals ring fell outside the window: %s" % str(collapsed_ring))
        ok(not collapsed_ring.intersects(Rect2(_ui._toast_label.position, _ui._toast_label.size)),
                "the collapsed vitals ring overlaps the toast band")

        # And a window with room to spare must NOT collapse, or the fix is just
        # "always use the small HUD".
        root.size = Vector2i(1280, 900)
        root.content_scale_size = Vector2i(1280, 900)
        for _frame in range(6):
                await frames(2)
        _ui.settings_changed.emit(_ui._settings.duplicate(true))
        await frames(4)
        ok(not _ui._compact_hud, "a tall window collapsed the HUD anyway")
        ok(_ui._minimap.visible, "the minimap was dropped from a window with room for it")

        _ui.apply_settings(BeautyData.default_settings())
        _ui._fit_layout()

        if failures > 0:
                finish(game, suite_name)
                return

        # The shop must not sell a heal that cannot do anything: a live Warm Tea
        # button at full warmth used to charge 3 sparkles for a silent no-op.
        var full_state := {"sparkles": 9, "charms": loadout([]), "owned": loadout([]), "stanzas": {}, "mote_verse": {}, "hp": 100.0, "hp_max": 100.0}
        _ui.show_shop(full_state)
        await frames(3)
        var cold_button := _find_shop_button("tea")
        ok(cold_button != null, "the shop did not show the Warm Tea item")
        if cold_button != null:
                ok(cold_button.disabled, "Warm Tea was buyable at full warmth (a silent no-op purchase)")
                # The shelf floor: _ware_card once read the ware card's minimum
                # before the card's _ready had run and inherited (0, 0), so every
                # ware button bottomed out at its 18px stylebox and each card
                # overflowed its button straight over the row beneath it.
                ok(cold_button.size.y >= 120.0,
                        "the Warm Tea button is only %fpx tall -- the ware shelf collapsed again" % cold_button.size.y)

        var hungry_state := full_state.duplicate()
        hungry_state["hp"] = 40.0
        _ui.show_shop(hungry_state)
        await frames(3)
        var hungry_button := _find_shop_button("tea")
        ok(hungry_button != null, "the shop lost the Warm Tea item when the hero was hurt")
        if hungry_button != null:
                ok(not hungry_button.disabled, "Warm Tea was unavailable while the hero was hurt")

        # The lullaby beat ring is a gameplay affordance ("press E on the gold") and
        # it draws after every panel, so it must be dismissed whenever a panel opens.
        # Pausing mid-lullaby used to leave the gold ring floating on the pause menu,
        # over controls the player could not use.
        for panel: Callable in [func(): _ui.show_pause(game.meta), func(): _ui.show_menu(game.meta),
                        func(): _ui.show_death(4, game.meta), func(): _ui.show_ending(2, game.meta),
                        func(): _ui.show_shop(full_state), func(): _ui.show_journal(game.meta, [], []),
                        func(): _ui.show_settings(BeautyData.default_settings())]:
                _ui.set_beat(true, true)
                await frames(1)
                ok(_ui._beat_ring.visible, "the lullaby beat ring was not visible before opening a panel")
                panel.call()
                await frames(2)
                ok(not _ui._beat_ring.visible, "a panel opened with the lullaby beat ring still on screen")
                _ui.close_panels()
                await frames(1)
                ok(not _ui._beat_ring.visible, "closing the panels left the beat ring on screen")

        # Wearing and resting a charm you already own is free, so the sparkle
        # balance must never disable it. The affordability check used to apply to
        # owned wares too, so once the player spent their last sparkles every
        # owned charm became a dead button whose own tooltip still said "tap to
        # wear it" / "tap to rest it" — the loadout could no longer be changed.
        var broke_state := {
                "sparkles": 0,
                # Charms are `{key, tier}` entries now -- a charm can be owned twice, so
                # a flag dictionary cannot say which copy this is.
                "charms": loadout(["boots"]),
                "owned": loadout(["boots"]),
                "stanzas": {"petals": true, "echoes": true},
                "mote_verse": {},
                "hp": 100.0, "hp_max": 100.0,
                "capacity": 3,
        }
        _ui.show_shop(broke_state)
        await frames(3)
        var worn_boots := _find_shop_button("boots")
        ok(worn_boots != null, "the shop lost an owned charm")
        if worn_boots != null:
                ok(not worn_boots.disabled, "a worn charm could not be rested with 0 sparkles")
        broke_state["charms"] = loadout([])
        _ui.show_shop(broke_state)
        await frames(3)
        var pocket_boots := _find_shop_button("boots")
        ok(pocket_boots != null, "the shop lost a pocketed charm")
        if pocket_boots != null:
                ok(not pocket_boots.disabled, "a pocketed charm could not be worn with 0 sparkles")
        # An unowned charm is still gated on the price it costs.
        _ui.show_shop({
                "sparkles": 0, "charms": loadout([]), "owned": loadout([]), "stanzas": {},
                "mote_verse": {}, "hp": 100.0, "hp_max": 100.0,
        })
        await frames(3)
        var unaffordable := _find_shop_button("scarf")
        if unaffordable != null:
                ok(unaffordable.disabled, "an unowned charm was offered with 0 sparkles")

        if not await _check_the_floor_opens_like_a_film(game):
                return

        finish(game, suite_name)


## The floor's opening scene is a film now: letterbox in, the page, two more
## shots, letterbox out -- and the walk never stops. The checks pin the
## staging (bars up, card up), the supersede (a newer floor's prologue takes
## over without waiting for the old one's timers) and the ownership rule
## (a ceremony that claims the cinema keeps its bars after the story leaves).
func _check_the_floor_opens_like_a_film(game: Node) -> bool:
        _ui.apply_settings({
                "reduced_motion": false,
                "text_scale": 1.0,
                "high_contrast": false,
                "damage_taken": 1.0,
                "rhythm_window": 1.0,
                "wisp_speed": 1.0,
                "volume": 0.8,
                "muted": true,
        })
        _ui.play_floor_prologue(
                ["The Test Floor", "A page for the prologue to speak."],
                ["First shot continues the scene.", "Second shot lands the cut."],
                "mote")
        await frames(3)
        if not ok(_ui._cinematic_on and _ui._cinematic_owner == "prologue",
                        "the prologue did not raise the letterbox in its own name"):
                return false
        if not ok(_ui._story_card.visible, "the prologue's page never arrived"):
                return false
        # A newer floor supersedes: the second call bumps the generation, so
        # the first sequence's timers become noise and the second owns the
        # stage -- no double-bars, no queue of stale cards.
        var first_generation: int = _ui._prologue_generation
        _ui.play_floor_prologue(
                ["The Next Floor", "The scene moves on."],
                ["One more shot."],
                "mote")
        await frames(3)
        if not ok(_ui._prologue_generation == first_generation + 1,
                        "a second prologue did not supersede the first"):
                return false
        if not ok(_ui._story_card.visible and _ui._story_title.text == "The Next Floor",
                        "the superseding prologue did not own the card"):
                return false
        # A modal takes the stage mid-scene: opening the shop must dismiss the
        # film -- bars down, card away, generation bumped so the pending cuts
        # die quietly behind the scrim instead of painting over the wares.
        var generation_before_shop: int = _ui._prologue_generation
        _ui.show_shop({
                "sparkles": 4, "charms": [], "owned": [], "stanzas": {"petals": true},
                "mote_verse": {}, "hp": 60.0, "hp_max": 100.0, "capacity": 2,
        })
        await frames(3)
        if not ok(not _ui._cinematic_on and not _ui._story_card.visible
                        and _ui._prologue_generation == generation_before_shop + 1,
                        "opening a panel mid-film left the letterbox, the card or the cuts alive"):
                return false
        _ui.close_shop()
        await frames(2)
        if not ok(not _ui._cinematic_on, "the film came back after the panel closed"):
                return false

        # An outside voice speaks on the card mid-film -- an encounter's
        # entrance, the lantern's warning, Mote's chatter. The film's turns
        # must end at the voice: the pending cuts die (generation bumped) and
        # the bars leave with the card, so the next shot can neither
        # overwrite what was just said nor leave the letterbox standing over
        # a card the film no longer owns.
        _ui.play_floor_prologue(
                ["The Third Floor", "The scene is mid-film when a wobbly guest arrives."],
                ["First shot continues.", "Second shot lands."],
                "mote")
        await frames(3)
        var generation_before_voice: int = _ui._prologue_generation
        _ui.show_story("A Big Feeling", "Not a monster — just one feeling wearing a very big coat.", 3.6)
        await frames(3)
        if not ok(_ui._prologue_generation == generation_before_voice + 1
                        and _ui._story_title.text == "A Big Feeling",
                        "an outside voice did not take the card away from the film"):
                return false
        if not ok(not _ui._cinematic_on,
                        "the outside voice left the letterbox standing over a non-film card"):
                return false

        # A ceremony claims the cinema mid-scene. The prologue's own exit rule
        # reads the ownership before touching the bars: it no longer owns
        # them, so when its timers run out the bars STAY UP for the ceremony.
        # (The prologue also stops cutting cards -- enforced by the same
        # ownership check in play_floor_prologue.)
        _ui.set_cinematic(true)
        await frames(2)
        if not ok(_ui._cinematic_on and _ui._cinematic_owner == "",
                        "the ceremony could not claim the cinema from the prologue"):
                return false
        _ui.set_cinematic(false)
        await frames(2)
        if not ok(not _ui._cinematic_on and _ui._cinematic_owner == "",
                        "the ceremony's exit left the letterbox hanging"):
                return false
        # A fresh prologue still raises its own cinema afterwards, and the
        # story card is back on stage.
        _ui.play_floor_prologue(["A Later Floor", "The film plays again."], [], "mote")
        await frames(3)
        var bars_back: bool = _ui._cinematic_on and _ui._cinematic_owner == "prologue"
        var card_back: bool = _ui._story_card.visible
        _ui.play_floor_prologue([], [], "")  # supersede: bumps the generation
        await frames(2)
        return ok(bars_back and card_back and _ui._prologue_generation >= 2,
                        "a later prologue could not raise the cinema again")
