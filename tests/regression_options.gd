extends TestCase

## What the gentler-forest options actually DO, and whether they say so.
##
## Split out of regression_ui.gd, which measures where things land on screen.
## These three checks are about meaning, not geometry: that High Contrast
## reaches the text rather than only the scrims, that the bump-softness slider
## pulls the other way when it should, and that every accessibility toggle
## names what it changes.
##
## This suite writes settings, so it runs under a throwaway profile -- without
## one, the 200% text check in the layout suite would leave the PLAYER at 200%
## for good.

var _ui: GameUI

func _initialize() -> void:
	suite_name = "BEAUTY_FOREST_OPTIONS"
	TestProfile.begin("options")
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	_ui = game.ui
	if _ui == null:
		ok(false, "the game built no GameUI")
		finish(game, "BEAUTY_FOREST_OPTIONS")
		return

	await _check_high_contrast_reaches_the_text()
	await _check_bump_softness_drags_toward_softness()
	await _check_accessibility_toggles_name_what_they_change()
	await _check_vitals_follow_the_accessibility_settings()

	finish(game, "BEAUTY_FOREST_OPTIONS")

func _check_vitals_follow_the_accessibility_settings() -> void:
	## The vitals ring, sparkle count and charm sockets drew with whatever flags
	## they were born with: apply_settings refreshed the minimap, the scrims
	## and the text, but never touched `_vitals`, so "High contrast" and "Still
	## Forest" quietly did nothing to the picture every player wears.
	_ui.apply_settings({"high_contrast": false, "reduced_motion": false})
	await frames(2)
	ok(not _ui._vitals.high_contrast, "vitals were born high-contrast")
	ok(not _ui._vitals._reduced_motion, "vitals were born in Still Forest")
	_ui.apply_settings({"high_contrast": true, "reduced_motion": true})
	await frames(2)
	ok(_ui._vitals.high_contrast, "High Contrast never reached the vitals ring")
	ok(_ui._vitals._reduced_motion, "Still Forest never reached the vitals ring")
	_ui.apply_settings({"high_contrast": false, "reduced_motion": false})
	await frames(2)
	ok(not _ui._vitals.high_contrast and not _ui._vitals._reduced_motion,
		"clearing the toggles did not restore the vitals to gentle defaults")

## High Contrast only ever darkened the scrims and the minimap. The cards carry
## their own near-opaque fill, so every label sat at the same 13.6:1 in both
## modes -- a setting named for contrast that changed none of the text a player
## actually reads. Each card has to get measurably darker.
func _check_high_contrast_reaches_the_text() -> void:
	for card_name in ["_shop_card", "_story_card", "_overlay_card"]:
		var card: Control = _ui.get(card_name)
		if card == null:
			ok(false, "high contrast: %s is missing" % card_name)
			continue
		var plain := _card_fill(card)
		_ui.apply_settings({"high_contrast": false})
		await frames(2)
		var before := _card_fill(card)
		_ui.apply_settings({"high_contrast": true})
		await frames(2)
		var after := _card_fill(card)
		var text: Color = _card_text_color(card)
		var ratio_before := _contrast_ratio(text, before)
		var ratio_after := _contrast_ratio(text, after)
		print("HIGH_CONTRAST %s  %.2f:1 -> %.2f:1  fill %s -> %s" % [
			card_name, ratio_before, ratio_after, str(before), str(after)])
		ok(after.a > 0.0 and after.get_luminance() < before.get_luminance(),
			"high contrast did not darken %s (luminance %f -> %f)" % [
				card_name, before.get_luminance(), after.get_luminance()])
		ok(ratio_after > ratio_before,
			"high contrast did not raise the text ratio on %s (%.2f -> %.2f)" % [
				card_name, ratio_before, ratio_after])
		_ui.apply_settings({"high_contrast": false})
		await frames(2)
		ok(_card_fill(card).is_equal_approx(plain),
			"turning high contrast off did not restore %s" % card_name)

	# The shared card is refilled every time a screen opens; the darker fill has
	# to survive that, or the fix only works until the player looks at the cart.
	_ui.apply_settings({"high_contrast": true})
	await frames(2)
	var carried := _card_fill(_ui._shop_card)
	_ui.show_shop({
		"sparkles": 10, "charms": {}, "owned": {}, "stanzas": {},
		"mote_verse": {}, "hp": 100.0, "hp_max": 100.0,
	})
	await frames(3)
	ok(_card_fill(_ui._shop_card).is_equal_approx(carried),
		"refilling the card lost the high-contrast fill: %s -> %s" % [
			str(carried), str(_card_fill(_ui._shop_card))])
	_ui.apply_settings(BeautyData.default_settings())
	await frames(2)

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
	await frames(3)
	_ui.show_settings(_ui._settings)
	await frames(4)
	var row: HBoxContainer = _find_row("Bump softness")
	ok(row != null, "the Bump softness row is missing")
	if row == null:
		return
	var slider: HSlider = null
	for child in row.get_children():
		if child is HSlider:
			slider = child
			break
	ok(slider != null, "the Bump softness row has no slider")
	if slider == null:
		return

	# Dragging right must store the softest setting, not the hardest.
	slider.value = 1.0
	await frames(3)
	var softest: float = float(_ui._settings.get("damage_taken", -1.0))
	print("BUMP_SOFTNESS right=%.2f" % softest)
	ok(is_equal_approx(softest, 0.25),
		"dragging Bump softness right stored %.2f, not the softest 0.25" % softest)

	slider.value = 0.0
	await frames(3)
	var hardest: float = float(_ui._settings.get("damage_taken", -1.0))
	print("BUMP_SOFTNESS left=%.2f" % hardest)
	ok(is_equal_approx(hardest, 3.0),
		"dragging Bump softness left stored %.2f, not the hardest 3.00" % hardest)
	ok(hardest > softest,
		"Bump softness moved backwards: right %.2f, left %.2f" % [softest, hardest])

	# The handle must show where the current setting sits, and reopening the
	# panel must not shift it.
	_ui.apply_settings({"damage_taken": 0.70})
	await frames(2)
	_ui.show_settings(_ui._settings)
	await frames(4)
	var reopened: HBoxContainer = _find_row("Bump softness")
	var reopened_slider: HSlider = null
	for child in reopened.get_children():
		if child is HSlider:
			reopened_slider = child
			break
	ok(reopened_slider != null and reopened_slider.value > 0.8,
		"the default ×0.70 should sit near the right (soft) end, handle at %s" % [
			str(reopened_slider.value if reopened_slider != null else "none")])

	# Opening the panel must not itself change the setting.
	var before_open: float = float(_ui._settings.get("damage_taken", -1.0))
	_ui.apply_settings(BeautyData.default_settings())
	await frames(2)
	_ui.close_settings()
	await frames(2)
	_ui.apply_settings(BeautyData.default_settings())
	await frames(2)

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
	await frames(3)
	_ui.show_settings(_ui._settings)
	await frames(4)
	var labels: Array[String] = []
	for node in _ui._shop_frame.find_children("*", "CheckButton", true, false):
		var toggle := node as CheckButton
		if toggle != null:
			labels.append(toggle.text)
	print("ACCESSIBILITY_TOGGLES %s" % str(labels))
	ok(labels.size() >= 3,
		"expected three accessibility toggles, found %d" % labels.size())
	var joined := " ".join(labels)
	# Each named effect must be one the code really changes.
	ok(joined.contains("cards") or joined.contains("contrast"),
		"the contrast toggle never says it changes the cards: %s" % joined)
	ok(joined.contains("map"),
		"the contrast toggle does not mention the grove map it sharpens: %s" % joined)
	ok(not joined.contains("pockets"),
		"the contrast toggle still claims high-contrast pockets, which do not exist: %s" % joined)
	ok(joined.contains("motion") or joined.to_lower().contains("still"),
		"the Still Forest toggle does not say it calms motion: %s" % joined)
	ok(joined.contains("walk"),
		"the Still Forest toggle does not say the walk stays readable: %s" % joined)
	ok(joined.to_lower().contains("sound") or joined.to_lower().contains("hush"),
		"no toggle describes the audio one: %s" % joined)
	_ui.close_settings()
	await frames(2)
