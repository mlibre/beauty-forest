extends SceneTree

## TEMPORARY diagnostic probe: prints real HUD rects at a few window sizes.

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func _run() -> void:
	print("touchscreen_available=", DisplayServer.is_touchscreen_available())
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(3)
	var ui: GameUI = game.ui
	game._start_run(1)
	game.mode = game.Mode.PLAYING
	ui.close_panels()
	for touch: bool in [false, true]:
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 640), Vector2i(640, 360), Vector2i(480, 900), Vector2i(480, 240)]:
			root.size = size
			root.content_scale_size = size
			for _attempt in range(40):
				await _frames(2)
				if ui._root.size.is_equal_approx(Vector2(size)):
					break
			ui._touch_root.visible = touch
			ui._fit_layout()
			await _frames(3)
			var parent: Vector2 = ui._root.size
			var mm: Control = ui._minimap
			var log: Control = ui._log_label
			var joy: Control = ui._touch_joystick
			var mmr := Rect2(mm.position, mm.size)
			var logr := Rect2(log.position, log.size)
			var joyr := Rect2(joy.position, joy.size)
			var cluster := ui._touch_cluster_rect()
			print("=== touch=%s %dx%d parent=%s" % [str(touch), size.x, size.y, str(parent)])
			print("  CLUSTER %s" % str(cluster))
			print("  map   vis=%-5s %s" % [str(mm.visible), str(mmr)])
			print("  log   vis=%-5s %s" % [str(log.visible), str(logr)])
			print("  MAP x CLUSTER   = %s" % str(mmr.intersects(cluster)))
			print("  LOG x JOYSTICK  = %s" % str(logr.intersects(joyr)))
			print("  MAP x RIGHTCARD = %s" % str(mmr.intersects(Rect2(ui._right_card.position, ui._right_card.size))))
			print("  all enclosed    = %s / %s" % [str(Rect2(Vector2.ZERO, parent).encloses(mmr)), str(Rect2(Vector2.ZERO, parent).encloses(logr))])
	root.remove_child(game)
	game.free()
	await _frames(2)
	quit(0)
