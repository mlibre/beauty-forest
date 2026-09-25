extends SceneTree

## Focused audio regression checks. Run with:
## godot --headless --path . --script tests/regression_audio.gd

var _failures: Array[String] = []
var _exit_stream_states: Array[bool] = []
var _watched_players: Array[AudioStreamPlayer] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures.append(message)

func _stream_id(player: AudioStreamPlayer) -> int:
    return player.stream.get_instance_id() if player.stream != null else 0

func _record_tree_exit(player: AudioStreamPlayer) -> void:
    _exit_stream_states.append(player.stream == null)

func _watch_player_exit(player: AudioStreamPlayer) -> void:
    if player.playing:
        _watched_players.append(player)
        player.tree_exiting.connect(_record_tree_exit.bind(player))

func _run() -> void:
    var director := AudioDirector.new()
    root.add_child(director)
    await process_frame

    # Mute must silence voices that are already sounding, not just future notes.
    director.set_volume(0.8)
    director.play_tone(440.0, 2.0, 0.1, 0)
    var first_voice: AudioStreamPlayer = director._sfx_players[0]
    _check(first_voice.playing, "test setup: tone did not start")
    _check(is_equal_approx(first_voice.pitch_scale, 1.0), "default SFX pitch was not unity")
    director.set_muted(true)
    _check(not first_voice.playing, "mute left an active SFX running")
    _check(first_voice.volume_db <= -79.0, "mute left an active SFX audible")
    director.set_muted(false)
    _check(not first_voice.playing, "unmute resurrected a muted SFX")

    # Existing SFX must follow the live volume slider, not retain their old gain.
    director.play_tone(440.0, 2.0, 0.1, 0)
    director.set_volume(0.25)
    _check(is_equal_approx(first_voice.volume_db, linear_to_db(0.25)), "volume change did not update active SFX")

    # Muting during an ambient fade must cancel that fade, not let it finish
    # audibly after the hush.
    director.set_muted(false)
    director.set_volume(0.8)
    director.start_ambient("sunlit-roots")
    await create_timer(0.2).timeout
    director.set_muted(true)
    await create_timer(1.35).timeout
    _check(director._ambient_player.volume_db <= -79.0, "mute during ambient fade was overwritten")

    # A live volume change must supersede a fade targeting the old gain.
    director.set_muted(false)
    director.set_volume(0.8)
    director.start_ambient("sunlit-roots")
    await create_timer(0.2).timeout
    director.set_volume(0.25)
    await create_timer(1.35).timeout
    _check(is_equal_approx(director._ambient_player.volume_db, linear_to_db(0.25 * 0.34)), "ambient volume change was overwritten by the old fade")

    # A muted start must not fade back to an audible ambient level.
    director.set_muted(true)
    director.start_ambient("sunlit-roots")
    await create_timer(1.35).timeout
    _check(director._ambient_player.volume_db <= -79.0, "ambient start faded in while muted")

    # Muting during an ambient stop must not cancel the stop and leave a
    # silent player running after unmute.
    director.set_muted(false)
    director.set_volume(0.8)
    director.start_ambient("sunlit-roots")
    await create_timer(0.2).timeout
    director.stop_ambient()
    await create_timer(0.1).timeout
    director.set_muted(true)
    await process_frame
    director.set_muted(false)
    _check(not director._ambient_player.playing, "mute during ambient stop left a silent player running")

    # Stopping and immediately starting must not let the old stop callback kill
    # the newly selected ambient stream.
    director.set_muted(false)
    director.start_ambient("sunlit-roots")
    await process_frame
    director.stop_ambient()
    director.start_ambient("pollen-halls")
    await create_timer(0.4).timeout
    _check(director._ambient_player.playing, "stale ambient stop callback stopped the new ambience")

    # Hush should also avoid synthesizing/cache-growing one-off sounds.
    var before_cache: int = director._cache.size()
    director.set_muted(true)
    for _index in range(8):
        director.play_song_launch()
    director.play_footstep()
    _check(director._cache.size() == before_cache, "muted events still synthesized/cached sounds")

    # Randomized launch pitch must not create a new cached PCM stream per note.
    director.set_muted(false)
    before_cache = director._cache.size()
    for _index in range(20):
        director.play_song_launch()
    _check(director._cache.size() <= before_cache + 1, "randomized launches grew the PCM cache")

    # Invalid public parameters should be ignored rather than allocating an
    # invalid/empty stream and producing an engine error.
    before_cache = director._cache.size()
    director.play_tone(440.0, -1.0, 0.1, 0)
    director.play_chord([], 0.0, 0.1, 0.5)
    director.play_chord([null, "not-a-number", {}], 0.2, 0.1, 0.5)
    _check(director._cache.size() == before_cache, "invalid audio parameters entered the cache")

    director.play_tone(0.0, 0.2, 0.1, 0)
    director.play_tone(11025.1, 0.2, 0.1, 0)
    director.play_tone(440.0, AudioDirector.MAX_SFX_DURATION + 0.1, 0.1, 0)
    director.play_tone(440.0, 0.2, 0.0, 0)
    _check(director._cache.size() == before_cache, "out-of-range audio parameters entered the cache")

    # Generated PCM must remain a valid mono 16-bit stream and stay within
    # signed 16-bit sample bounds.
    var probe_tone: AudioStreamWAV = director._make_tone([440.0], 0.03, 1.0, 1.0, true, 2)
    _check(probe_tone.format == AudioStreamWAV.FORMAT_16_BITS, "tone stream format was not 16-bit PCM")
    _check(probe_tone.mix_rate == 22050, "tone stream used an unexpected mix rate")
    _check(not probe_tone.stereo, "tone stream unexpectedly used stereo")
    _check(probe_tone.data.size() > 0 and probe_tone.data.size() % 2 == 0, "tone stream had malformed PCM data")
    var max_sample := 0
    for byte_index in range(0, probe_tone.data.size(), 2):
        max_sample = maxi(max_sample, absi(probe_tone.data.decode_s16(byte_index)))
    _check(max_sample <= 32767, "tone PCM exceeded signed 16-bit bounds")
    probe_tone = null

    # The bounded pool should rotate reuse instead of repeatedly cutting Sfx0.
    for player in director._sfx_players:
        player.stop()
        player.stream = null
    var changes: Array[int] = []
    changes.resize(director._sfx_players.size())
    changes.fill(0)
    for index in range(22):
        var old_ids: Array[int] = []
        for player in director._sfx_players:
            old_ids.append(_stream_id(player))
        director.play_tone(300.0 + float(index), 1.0, 0.1, 0)
        for player_index in director._sfx_players.size():
            if _stream_id(director._sfx_players[player_index]) != old_ids[player_index]:
                changes[player_index] += 1
    var most_reused := 0
    for count in changes:
        most_reused = maxi(most_reused, count)
    _check(most_reused <= 4, "SFX pool repeatedly reused one voice")

    # Child players must release their streams before the parent leaves the
    # tree; otherwise short smoke teardown leaves AudioStreamPlaybackWAV refs.
    for player in director._sfx_players:
        _watch_player_exit(player)
    _watch_player_exit(director._ambient_player)
    root.remove_child(director)
    director.free()
    _check(_exit_stream_states.size() == _watched_players.size(), "not all active players reached teardown")
    for cleared in _exit_stream_states:
        _check(cleared, "an audio player retained its stream during teardown")

    # AudioServer drains stopped playbacks asynchronously; let the final
    # playback resources drain before this focused test exits.
    await _frames(30)
    if _failures.is_empty():
        print("BEAUTY_FOREST_AUDIO_OK")
        quit(0)
    else:
        for failure in _failures:
            printerr("AUDIO_REGRESSION_FAIL: " + failure)
        quit(1)

func _frames(count: int) -> void:
    for _frame in range(count):
        await process_frame
