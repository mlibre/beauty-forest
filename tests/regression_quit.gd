extends SceneTree

## Verifies the production shutdown path: a window close request must hush
## the audio (blocking new voices), then quit only after the AudioServer can
## release its stopped playbacks. Quitting mid-playback leaks
## AudioStreamPlayback refs at exit (see the note in regression_audio.gd).
##
## Success looks like the process exiting on its own via quit_gracefully():
## exit code 0 with no BEAUTY_FOREST_QUIT_FAILED output. If the graceful
## quit never fires, the fallback below fails loudly instead of hanging a
## suite. Run with:
## godot --headless --path . --script tests/regression_quit.gd
##
## This suite stays standalone on purpose: it asserts that the process exits
## by itself through the production quit path, and a harness finish() call
## would quit first and preempt the graceful quit it is testing.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # This suite starts a run (which saves meta); keep it off the real profile.
    TestProfile.begin("quit")
    var packed: PackedScene = load("res://scenes/main.tscn")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await _frames(2)

    game._start_run(1)
    await _frames(4)
    if not _check(game.audio != null, "game booted without an audio director"):
        return
    game.audio.play_tone(440.0, 2.0, 0.1, 0)
    var voice: AudioStreamPlayer = game.audio._sfx_players[0]
    if not _check(voice.playing, "test setup: tone did not start"):
        return

    game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
    if not _check(game._quitting, "close request did not enter the graceful quit path"):
        return
    if not _check(game.audio._shut_down, "close request did not shut the audio down"):
        return
    if not _check(not voice.playing, "close request left a voice sounding"):
        return
    if not _check(voice.stream == null, "close request left a player holding its stream"):
        return
    if not _check(game.audio._ambient_player.stream == null, "close request left the ambience attached"):
        return

    # Repeated close requests must collapse into the single pending quit.
    game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
    # New voices must stay hushed while the drain window is open.
    game.audio.play_tone(440.0, 0.5, 0.1, 0)
    game.audio.start_ambient("sunlit-roots")
    for player in game.audio._sfx_players:
        if not _check(not player.playing, "a new voice started during shutdown"):
            return

    # The graceful path quits the process here by itself.
    await create_timer(3.0).timeout
    push_error("BEAUTY_FOREST_QUIT_FAILED: graceful quit never fired")
    quit(1)

func _frames(count: int) -> void:
    for _frame in range(count):
        await process_frame

func _check(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("BEAUTY_FOREST_QUIT_FAILED: %s" % message)
    quit(1)
    return false
