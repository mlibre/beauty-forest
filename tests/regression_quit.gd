extends SceneTree

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const TestProfile := preload("res://tests/support/test_profile.gd")

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
    # The tone lands on whichever pool voice is free — while the walk is
    # PLAYING, the lantern's own song launches may already occupy voices, so
    # the test finds the voice its tone actually landed on instead of
    # assuming the pool's first seat.
    var voice: AudioStreamPlayer = null
    for candidate in game.audio._sfx_players:
        if candidate.playing:
            voice = candidate
            break
    if not _check(voice != null and voice.playing, "test setup: tone did not start"):
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
    if not _check(game.music._shut_down, "close request did not shut the music down"):
        return
    for music_voice in game.music._players:
        if not _check(music_voice.stream == null, "close request left the music attached"):
            return

    # Repeated close requests must collapse into the single pending quit.
    game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
    # New voices must stay hushed while the drain window is open.
    game.audio.play_tone(440.0, 0.5, 0.1, 0)
    game.music.play_region("sunlit-roots")
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
