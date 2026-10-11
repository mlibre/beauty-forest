extends RefCounted
## The walk's input map, built in code. The project ships no input assets --
## everything the player can press is registered here once at boot, the same
## way every visual is drawn at runtime. One action, one stick axis at most,
## optional pad buttons; the 0.25 deadzone is InputMap's default ask and
## matches an analog stick's resting drift.

static func ensure() -> void:
	add("bf_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	add("bf_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	add("bf_forward", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	add("bf_back", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	add("bf_dash", [KEY_SHIFT], -1, 0.0, [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER])
	add("bf_interact", [KEY_E], -1, 0.0, [JOY_BUTTON_A])
	add("bf_shop", [KEY_F], -1, 0.0, [JOY_BUTTON_Y])
	add("bf_journal", [KEY_J], -1, 0.0, [JOY_BUTTON_LEFT_STICK])
	add("bf_settings", [KEY_C], -1, 0.0, [JOY_BUTTON_BACK])
	add("bf_pause", [KEY_ESCAPE], -1, 0.0, [JOY_BUTTON_START])

static func add(action: StringName, keys: Array, axis: int = -1, axis_value: float = 0.0, buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for key: Variant in keys:
		var event := InputEventKey.new()
		event.physical_keycode = int(key)
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = axis_value
		InputMap.action_add_event(action, motion)
	for button: Variant in buttons:
		var joy := InputEventJoypadButton.new()
		joy.button_index = int(button)
		InputMap.action_add_event(action, joy)
