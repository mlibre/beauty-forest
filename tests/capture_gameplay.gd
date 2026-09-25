extends SceneTree

## Developer capture helper used with Godot's --write-movie mode. It does not
## affect the game itself.

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    game._start_run(1)
    game.mode = game.Mode.PLAYING
    game.ui.close_panels()
    await _frames(45)
    if not game.wisps.is_empty():
        game.wisps[0].global_position = game.player.global_position + Vector3(2.3, 0, 0.5)
        game.wisps[1].global_position = game.player.global_position + Vector3(-2.0, 0, 1.0)
    await _frames(30)
    root.remove_child(game)
    game.free()
    await _frames(2)
    quit(0)

func _frames(count: int) -> void:
    for _frame in range(count):
        await process_frame
