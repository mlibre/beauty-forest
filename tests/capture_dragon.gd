extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    game._start_run(1)
    game._load_floor(13, false)
    game.mode = game.Mode.PLAYING
    game.ui.close_panels()
    game.ui.set_hud_visible(true)
    var dragon_room: Dictionary = game.dungeon["rooms"][0]
    game.player.global_position = Vector3(dragon_room["cx"] - 3.2, 0.05, dragon_room["cy"] + 2.8)
    for _frame in range(45):
        await process_frame
    root.remove_child(game)
    game.free()
    await process_frame
    quit(0)
