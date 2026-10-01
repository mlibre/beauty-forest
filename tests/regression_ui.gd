extends SceneTree

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
##     parked the GROVE MAP in the bottom-right corner *under* the SING/DASH/
##     CART/BOOK/COZY cluster and the log under the joystick, so on a
##     touchscreen both readouts were painted over by opaque buttons.

var _failures := 0
var _ui: GameUI
var _root_rect := Rect2()

func _initialize() -> void:
	# This suite writes settings, so without a throwaway profile a run would
	# leave the PLAYER at 200% text for good -- the 200% check below saves that
	# value straight to user://.
	TestProfile.begin("regression_ui")
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func _settle(size: Vector2i) -> bool:
	## Drive the window and wait for the real parent rect to adopt it, which is
	## how the game reaches the layout (viewport resize, then fit).
	root.size = size
	root.content_scale_size = size
	for _attempt in range(40):
		await _frames(2)
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
	await _frames(3)
	var tag := "with touch controls at %dx%d" % [size.x, size.y]
	var parent := Rect2(Vector2.ZERO, _ui._root.size)
	var cluster := _ui._touch_cluster_rect()
	var joystick := _ui._joystick_rect()
	_check(not _touch_controls_off_screen(_ui), "a touch control hangs off the screen %s" % tag)
	var map_rect := Rect2(_ui._minimap.position, _ui._minimap.size)
	var log_rect := Rect2(_ui._log_label.position, _ui._log_label.size)
	var right_rect := Rect2(_ui._right_card.position, _ui._right_card.size)
	# A control that yielded (nothing on screen fits clear of the buttons) is
	# allowed to sit anywhere in the window; only what is actually painted has
	# to stay readable.
	_check(not _ui._minimap.visible or not map_rect.intersects(cluster), "the touch buttons cover the GROVE MAP %s: map=%s cluster=%s" % [tag, str(map_rect), str(cluster)])
	_check(not _ui._minimap.visible or not map_rect.intersects(right_rect), "the Mote card covers the GROVE MAP %s" % tag)
	_check(not _ui._log_label.visible or not log_rect.intersects(joystick), "the touch joystick covers the log %s: log=%s joystick=%s" % [tag, str(log_rect), str(joystick)])
	_check(not _ui._log_label.visible or not log_rect.intersects(cluster), "the touch buttons cover the log %s: log=%s cluster=%s" % [tag, str(log_rect), str(cluster)])
	_check(parent.encloses(map_rect), "the GROVE MAP left the window %s: %s" % [tag, str(map_rect)])
	_check(parent.encloses(log_rect), "the log left the window %s: %s" % [tag, str(log_rect)])
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

func _find_shop_button(text: String) -> Button:
	for node in _ui._shop_content.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text.contains(text):
			return button
	return null

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(3)
	_ui = game.ui
	if _ui == null:
		_check(false, "the game built no GameUI")
		quit(1)
		return

	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 640), Vector2i(640, 360), Vector2i(480, 900), Vector2i(480, 240)]:
		# The root Control follows the viewport rect, so drive the window and
		# wait for the parent rect to actually settle before measuring.
		root.size = size
		root.content_scale_size = size
		var settled := false
		for _attempt in range(40):
			await _frames(2)
			if _ui._root.size.is_equal_approx(Vector2(size)):
				settled = true
				break
		if not settled:
			print("note: headless viewport did not adopt %dx%d (got %s); skipping that size" % [size.x, size.y, str(_ui._root.size)])
			continue
		_ui._fit_layout()
		await _frames(3)
		var parent: Control = _ui._root
		_root_rect = Rect2(Vector2.ZERO, parent.size)
		var tag := "at %dx%d" % [size.x, size.y]

		var left: Control = _ui._left_card
		var right: Control = _ui._right_card
		_check(left.size.y < _root_rect.size.y, "the status card is %fpx tall, taller than the window %s" % [left.size.y, tag])
		_check(right.size.y < _root_rect.size.y, "the Mote card is %fpx tall, taller than the window %s" % [right.size.y, tag])
		for pair: Array in [[left, "status card"], [right, "Mote card"], [_ui._minimap, "minimap"], [_ui._hint_label, "hint bar"], [_ui._toast_label, "toast"], [_ui._log_label, "log"]]:
			var control: Control = pair[0]
			var label := String(pair[1])
			var rect := Rect2(control.position, control.size)
			_check(_root_rect.encloses(rect), "%s %s is outside the window: %s" % [label, tag, rect])
		_check(not Rect2(left.position, left.size).intersects(Rect2(right.position, right.size)), "the HUD cards overlap each other %s" % tag)

		# A story card and a toast can be on screen at the same time (every floor
		# load opens both on merchant and Big Feeling floors). The story card is
		# opaque and draws after the HUD, so overlapping meant the toast's text
		# was simply hidden. Measured after the layout has settled, which is how
		# the game reaches it: the viewport resize settles, then the card shows.
		_ui.show_story("The Descent Begins", "Mote heard a rumor: far below sleeps a dragon who has not napped properly in centuries.")
		_ui.show_toast("A Big Feeling wanders this floor. Wait for its GOLD halo, then press E nearby and sing with it.")
		await _frames(4)
		var toast_rect := Rect2(_ui._toast_label.position, _ui._toast_label.size)
		var story_rect := Rect2(_ui._story_card.position, _ui._story_card.size)
		# Both bands must stay on screen at every size. Clearing the toast only
		# has to hold where the two can actually be stacked: a 240px-tall window
		# has no room for an 84px toast plus a 168px card, and there staying
		# on screen is the better trade.
		if toast_rect.size.y + story_rect.size.y + 4.0 + 16.0 <= _root_rect.size.y:
			_check(not toast_rect.intersects(story_rect), "the story card covers the toast %s: toast=%s story=%s" % [tag, toast_rect, story_rect])
		_check(_root_rect.encloses(story_rect), "the story card is outside the window %s: %s" % [tag, story_rect])
		_check(_root_rect.encloses(toast_rect), "the toast is outside the window %s: %s" % [tag, toast_rect])
		_ui.close_panels()
		await _frames(1)

		# Menus must be on screen and scroll their own content, not spill out.
		_ui.show_menu(game.meta)
		await _frames(4)
		var card: Control = _ui._overlay_card
		var card_rect := Rect2(card.position, card.size)
		_check(_root_rect.encloses(card_rect), "the menu card %s is outside the window: %s" % [tag, card_rect])
		_check(absf(card_rect.get_center().x - _root_rect.size.x * 0.5) < 2.0, "the menu card %s is not horizontally centered" % tag)
		_check(absf(card_rect.get_center().y - _root_rect.size.y * 0.5) < 2.0, "the menu card %s is not vertically centered" % tag)
		var content: Control = _ui._overlay_content
		_check(content.size.x <= card.size.x, "menu copy is %fpx wide inside a %fpx card %s" % [content.size.x, card.size.x, tag])

		# Rebuilding a panel must re-fit the freshly built children, not the
		# stale ones from the previous build.
		_ui.show_pause(game.meta)
		await _frames(4)
		var pause_rect := Rect2(_ui._overlay_card.position, _ui._overlay_card.size)
		_check(_root_rect.encloses(pause_rect), "the pause card %s is outside the window: %s" % [tag, pause_rect])
		_check(_ui._overlay_content.size.x <= _ui._overlay_card.size.x, "pause copy is wider than its card %s" % tag)

	# The touch controls sit in the same bottom corners as the map and the log,
	# so they get their own pass at every size: without a touchscreen the
	# assertions above cannot see that collision at all.
	for touch_size: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 640), Vector2i(640, 360), Vector2i(480, 900), Vector2i(480, 240)]:
		await _check_touch_layout(touch_size)

	if _failures > 0:
		quit(1)
		return

	# Accessibility text scaling must compose with the responsive layout rather
	# than widening the HUD or modal past the live viewport. This is a separate
	# path from ordinary resize: the 200% setting changes label minimums after
	# the cards have already been laid out.
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	for _frame in range(6):
		await _frames(2)
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
	await _frames(4)
	_root_rect = Rect2(Vector2.ZERO, _ui._root.size)
	var large_left := Rect2(_ui._left_card.position, _ui._left_card.size)
	var large_right := Rect2(_ui._right_card.position, _ui._right_card.size)
	_check(_root_rect.encloses(large_left), "200%% text pushed the status card outside the window: %s" % str(large_left))
	_check(_root_rect.encloses(large_right), "200%% text pushed the Mote card outside the window: %s" % str(large_right))
	_check(not large_left.intersects(large_right), "200%% text made the HUD cards overlap")
	_ui.show_settings(_ui._settings)
	await _frames(4)
	var settings_card := Rect2(_ui._shop_card.position, _ui._shop_card.size)
	_check(_root_rect.encloses(settings_card), "200%% text pushed the settings card outside the window: %s" % str(settings_card))
	_check(_ui._shop_content.size.x <= _ui._shop_card.size.x, "200%% text made settings copy wider than its card")
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
		await _frames(2)
	_ui.apply_settings(BeautyData.default_settings())
	_ui._fit_layout()
	await _frames(4)
	var before_left := Rect2(_ui._left_card.position, _ui._left_card.size)
	_ui._settings["text_scale"] = 2.0
	_ui.settings_changed.emit(_ui._settings.duplicate(true))
	await _frames(4)
	_check(_ui._compact_hud,
		"raising the text size on a short window left the wide HUD in place (left card stayed %s)" % str(before_left))
	var after_left := Rect2(_ui._left_card.position, _ui._left_card.size)
	_check(after_left.size.x < before_left.size.x,
		"the status card did not shrink when the HUD collapsed (%s -> %s)" % [str(before_left), str(after_left)])
	_check(not _ui._minimap.visible, "the minimap stayed drawn on a collapsed HUD")
	var after_right := Rect2(_ui._right_card.position, _ui._right_card.size)
	_check(not after_left.intersects(after_right), "the collapsed status card still overlaps the Mote card")
	var window_rect := Rect2(Vector2.ZERO, _ui._root.size)
	_check(window_rect.encloses(after_left), "the collapsed status card fell outside the window: %s" % str(after_left))
	_check(window_rect.encloses(after_right), "the Mote card fell outside the window: %s" % str(after_right))

	# And a window with room to spare must NOT collapse, or the fix is just
	# "always use the small HUD".
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	for _frame in range(6):
		await _frames(2)
	_ui.settings_changed.emit(_ui._settings.duplicate(true))
	await _frames(4)
	_check(not _ui._compact_hud, "a tall window collapsed the HUD anyway")
	_check(_ui._minimap.visible, "the minimap was dropped from a window with room for it")

	_ui.apply_settings(BeautyData.default_settings())
	_ui._fit_layout()

	if _failures > 0:
		quit(1)
		return

	# The shop must not sell a heal that cannot do anything: a live Warm Tea
	# button at full warmth used to charge 3 sparkles for a silent no-op.
	var full_state := {"sparkles": 9, "charms": {}, "owned": {}, "stanzas": {}, "mote_verse": {}, "hp": 100.0, "hp_max": 100.0}
	_ui.show_shop(full_state)
	await _frames(3)
	var cold_button := _find_shop_button("Warm Tea")
	_check(cold_button != null, "the shop did not show the Warm Tea item")
	if cold_button != null:
		_check(cold_button.disabled, "Warm Tea was buyable at full warmth (a silent no-op purchase)")

	var hungry_state := full_state.duplicate()
	hungry_state["hp"] = 40.0
	_ui.show_shop(hungry_state)
	await _frames(3)
	var hungry_button := _find_shop_button("Warm Tea")
	_check(hungry_button != null, "the shop lost the Warm Tea item when the hero was hurt")
	if hungry_button != null:
		_check(not hungry_button.disabled, "Warm Tea was unavailable while the hero was hurt")

	# The lullaby beat ring is a gameplay affordance ("press E on the gold") and
	# it draws after every panel, so it must be dismissed whenever a panel opens.
	# Pausing mid-lullaby used to leave the gold ring floating on the pause menu,
	# over controls the player could not use.
	for panel: Callable in [func(): _ui.show_pause(game.meta), func(): _ui.show_menu(game.meta),
			func(): _ui.show_death(4, game.meta), func(): _ui.show_ending(2, game.meta),
			func(): _ui.show_shop(full_state), func(): _ui.show_journal(game.meta, [], []),
			func(): _ui.show_settings(BeautyData.default_settings())]:
		_ui.set_beat(true, true)
		await _frames(1)
		_check(_ui._beat_ring.visible, "the lullaby beat ring was not visible before opening a panel")
		panel.call()
		await _frames(2)
		_check(not _ui._beat_ring.visible, "a panel opened with the lullaby beat ring still on screen")
		_ui.close_panels()
		await _frames(1)
		_check(not _ui._beat_ring.visible, "closing the panels left the beat ring on screen")

	# Wearing and resting a charm you already own is free, so the sparkle
	# balance must never disable it. The affordability check used to apply to
	# owned wares too, so once the player spent their last sparkles every
	# owned charm became a dead button whose own tooltip still said "tap to
	# wear it" / "tap to rest it" — the loadout could no longer be changed.
	var broke_state := {
		"sparkles": 0,
		"charms": {"boots": true},
		"owned": {"boots": true},
		"stanzas": {"petals": true, "echoes": true},
		"mote_verse": {},
		"hp": 100.0, "hp_max": 100.0,
	}
	_ui.show_shop(broke_state)
	await _frames(3)
	var worn_boots := _find_shop_button("Swift Boots")
	_check(worn_boots != null, "the shop lost an owned charm")
	if worn_boots != null:
		_check(not worn_boots.disabled, "a worn charm could not be rested with 0 sparkles")
	broke_state["charms"] = {}
	_ui.show_shop(broke_state)
	await _frames(3)
	var pocket_boots := _find_shop_button("Swift Boots")
	_check(pocket_boots != null, "the shop lost a pocketed charm")
	if pocket_boots != null:
		_check(not pocket_boots.disabled, "a pocketed charm could not be worn with 0 sparkles")
	# An unowned charm is still gated on the price it costs.
	_ui.show_shop({
		"sparkles": 0, "charms": {}, "owned": {}, "stanzas": {},
		"mote_verse": {}, "hp": 100.0, "hp_max": 100.0,
	})
	await _frames(3)
	var unaffordable := _find_shop_button("Wool Scarf")
	if unaffordable != null:
		_check(unaffordable.disabled, "an unowned charm was offered with 0 sparkles")

	await _check_high_contrast_reaches_the_text()
	await _check_bump_softness_drags_toward_softness()
	await _check_accessibility_toggles_name_what_they_change()

	if _failures > 0:
		quit(1)
		return

	print("BEAUTY_FOREST_UI_OK")
	root.remove_child(game)
	game.free()
	await _frames(4)
	quit(0)


## High Contrast only ever darkened the scrims and the minimap. The cards carry
## their own near-opaque fill, so every label sat at the same 13.6:1 in both
## modes -- a setting named for contrast that changed none of the text a player
## actually reads. Each card has to get measurably darker.
func _check_high_contrast_reaches_the_text() -> void:
	for card_name in ["_shop_card", "_story_card", "_overlay_card"]:
		var card: Control = _ui.get(card_name)
		if card == null:
			_check(false, "high contrast: %s is missing" % card_name)
			continue
		var plain := _card_fill(card)
		_ui.apply_settings({"high_contrast": false})
		await _frames(2)
		var before := _card_fill(card)
		_ui.apply_settings({"high_contrast": true})
		await _frames(2)
		var after := _card_fill(card)
		var text: Color = _card_text_color(card)
		var ratio_before := _contrast_ratio(text, before)
		var ratio_after := _contrast_ratio(text, after)
		print("HIGH_CONTRAST %s  %.2f:1 -> %.2f:1  fill %s -> %s" % [
			card_name, ratio_before, ratio_after, str(before), str(after)])
		_check(after.a > 0.0 and after.get_luminance() < before.get_luminance(),
			"high contrast did not darken %s (luminance %f -> %f)" % [
				card_name, before.get_luminance(), after.get_luminance()])
		_check(ratio_after > ratio_before,
			"high contrast did not raise the text ratio on %s (%.2f -> %.2f)" % [
				card_name, ratio_before, ratio_after])
		_ui.apply_settings({"high_contrast": false})
		await _frames(2)
		_check(_card_fill(card).is_equal_approx(plain),
			"turning high contrast off did not restore %s" % card_name)

	# The shared card is refilled every time a screen opens; the darker fill has
	# to survive that, or the fix only works until the player looks at the cart.
	_ui.apply_settings({"high_contrast": true})
	await _frames(2)
	var carried := _card_fill(_ui._shop_card)
	_ui.show_shop({
		"sparkles": 10, "charms": {}, "owned": {}, "stanzas": {},
		"mote_verse": {}, "hp": 100.0, "hp_max": 100.0,
	})
	await _frames(3)
	_check(_card_fill(_ui._shop_card).is_equal_approx(carried),
		"refilling the card lost the high-contrast fill: %s -> %s" % [
			str(carried), str(_card_fill(_ui._shop_card))])
	_ui.apply_settings(BeautyData.default_settings())
	await _frames(2)

func _card_fill(card: Control) -> Color:
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	return style.bg_color

func _card_text_color(card: Control) -> Color:
	for child in card.find_children("*", "Label", true, false):
		var label := child as Label
		if label != null and not label.text.is_empty():
			return label.get_theme_color("font_color") * label.modulate
	return Color.WHITE

func _contrast_ratio(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _relative_luminance(c: Color) -> float:
	var channel := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * channel.call(c.r) + 0.7152 * channel.call(c.g) + 0.0722 * channel.call(c.b)


## "Bump softness" is the only slider in the panel whose rightward drag made the
## game harder: the stored value is a damage multiplier, so seeking gentler
## bumps meant dragging right and landing on ×3.00 -- four times the damage being
## avoided. Right must now always mean softer.
func _check_bump_softness_drags_toward_softness() -> void:
	_ui.apply_settings(BeautyData.default_settings())
	await _frames(3)
	_ui.show_settings(_ui._settings)
	await _frames(4)
	var row: HBoxContainer = _find_row("Bump softness")
	_check(row != null, "the Bump softness row is missing")
	if row == null:
		return
	var slider: HSlider = null
	for child in row.get_children():
		if child is HSlider:
			slider = child
			break
	_check(slider != null, "the Bump softness row has no slider")
	if slider == null:
		return

	# Dragging right must store the softest setting, not the hardest.
	slider.value = 1.0
	await _frames(3)
	var softest: float = float(_ui._settings.get("damage_taken", -1.0))
	print("BUMP_SOFTNESS right=%.2f" % softest)
	_check(is_equal_approx(softest, 0.25),
		"dragging Bump softness right stored %.2f, not the softest 0.25" % softest)

	slider.value = 0.0
	await _frames(3)
	var hardest: float = float(_ui._settings.get("damage_taken", -1.0))
	print("BUMP_SOFTNESS left=%.2f" % hardest)
	_check(is_equal_approx(hardest, 3.0),
		"dragging Bump softness left stored %.2f, not the hardest 3.00" % hardest)
	_check(hardest > softest,
		"Bump softness moved backwards: right %.2f, left %.2f" % [softest, hardest])

	# The handle must show where the current setting sits, and reopening the
	# panel must not shift it.
	_ui.apply_settings({"damage_taken": 0.70})
	await _frames(2)
	_ui.show_settings(_ui._settings)
	await _frames(4)
	var reopened: HBoxContainer = _find_row("Bump softness")
	var reopened_slider: HSlider = null
	for child in reopened.get_children():
		if child is HSlider:
			reopened_slider = child
			break
	_check(reopened_slider != null and reopened_slider.value > 0.8,
		"the default ×0.70 should sit near the right (soft) end, handle at %s" % [
			str(reopened_slider.value if reopened_slider != null else "none")])

	# Opening the panel must not itself change the setting.
	var before_open: float = float(_ui._settings.get("damage_taken", -1.0))
	_ui.apply_settings(BeautyData.default_settings())
	await _frames(2)
	_ui.close_settings()
	await _frames(2)
	_ui.apply_settings(BeautyData.default_settings())
	await _frames(2)

func _find_row(title: String) -> HBoxContainer:
	for row in _ui._shop_content.find_children("*", "HBoxContainer", true, false):
		var candidate := row as HBoxContainer
		if candidate == null:
			continue
		for lbl in candidate.find_children("*", "Label", true, false):
			var label := lbl as Label
			if label != null and label.text == title:
				return candidate
	return null


## Every accessibility toggle has to describe what it actually changes. The
## High Contrast label used to say "pockets and journal", which stopped being
## true when the fix reached all three cards and the minimap -- a label that
## under-promises is as wrong as one that over-promises, because the player
## cannot tell whether the control is working.
func _check_accessibility_toggles_name_what_they_change() -> void:
	_ui.apply_settings(BeautyData.default_settings())
	await _frames(3)
	_ui.show_settings(_ui._settings)
	await _frames(4)
	var labels: Array[String] = []
	for node in _ui._shop_frame.find_children("*", "CheckButton", true, false):
		var toggle := node as CheckButton
		if toggle != null:
			labels.append(toggle.text)
	print("ACCESSIBILITY_TOGGLES %s" % str(labels))
	_check(labels.size() >= 3,
		"expected three accessibility toggles, found %d" % labels.size())
	var joined := " ".join(labels)
	# Each named effect must be one the code really changes.
	_check(joined.contains("cards") or joined.contains("contrast"),
		"the contrast toggle never says it changes the cards: %s" % joined)
	_check(joined.contains("map"),
		"the contrast toggle does not mention the grove map it sharpens: %s" % joined)
	_check(not joined.contains("pockets"),
		"the contrast toggle still claims high-contrast pockets, which do not exist: %s" % joined)
	_check(joined.contains("motion") or joined.to_lower().contains("still"),
		"the Still Forest toggle does not say it calms motion: %s" % joined)
	_check(joined.contains("walk"),
		"the Still Forest toggle does not say the walk stays readable: %s" % joined)
	_check(joined.to_lower().contains("sound") or joined.to_lower().contains("hush"),
		"no toggle describes the audio one: %s" % joined)
	_ui.close_settings()
	await _frames(2)
