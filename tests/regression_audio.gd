extends "res://tests/support/test_case.gd"
## Focused audio regression checks. Run with:
## godot --headless --path . --script tests/regression_audio.gd

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const AudioDirector := preload("res://scripts/audio_director.gd")

var _exit_stream_states: Array[bool] = []
var _watched_players: Array[AudioStreamPlayer] = []

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_AUDIO"
    call_deferred("_run")

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
    await frames(1)

    # Mute must silence voices that are already sounding, not just future notes.
    director.set_volume(0.8)
    director.play_tone(440.0, 2.0, 0.1, 0)
    var first_voice: AudioStreamPlayer = director._sfx_players[0]
    ok(first_voice.playing, "test setup: tone did not start")
    ok(is_equal_approx(first_voice.pitch_scale, 1.0), "default SFX pitch was not unity")
    director.set_muted(true)
    ok(not first_voice.playing, "mute left an active SFX running")
    ok(first_voice.volume_db <= -79.0, "mute left an active SFX audible")
    director.set_muted(false)
    ok(not first_voice.playing, "unmute resurrected a muted SFX")

    # Existing SFX must follow the live volume slider, not retain their old gain.
    director.play_tone(440.0, 2.0, 0.1, 0)
    director.set_volume(0.25)
    ok(is_equal_approx(first_voice.volume_db, linear_to_db(0.25)), "volume change did not update active SFX")

    # Muting during an ambient fade must cancel that fade, not let it finish
    # audibly after the hush.
    director.set_muted(false)
    director.set_volume(0.8)
    director.start_ambient("sunlit-roots")
    await create_timer(0.2).timeout
    director.set_muted(true)
    await create_timer(1.35).timeout
    ok(director._ambient_player.volume_db <= -79.0, "mute during ambient fade was overwritten")

    # A live volume change must supersede a fade targeting the old gain.
    director.set_muted(false)
    director.set_volume(0.8)
    director.start_ambient("sunlit-roots")
    await create_timer(0.2).timeout
    director.set_volume(0.25)
    await create_timer(1.35).timeout
    ok(is_equal_approx(director._ambient_player.volume_db, linear_to_db(0.25 * 0.34)), "ambient volume change was overwritten by the old fade")

    # A muted start must not fade back to an audible ambient level.
    director.set_muted(true)
    director.start_ambient("sunlit-roots")
    await create_timer(1.35).timeout
    ok(director._ambient_player.volume_db <= -79.0, "ambient start faded in while muted")

    # Muting during an ambient stop must not cancel the stop and leave a
    # silent player running after unmute.
    director.set_muted(false)
    director.set_volume(0.8)
    director.start_ambient("sunlit-roots")
    await create_timer(0.2).timeout
    director.stop_ambient()
    await create_timer(0.1).timeout
    director.set_muted(true)
    await frames(1)
    director.set_muted(false)
    ok(not director._ambient_player.playing, "mute during ambient stop left a silent player running")

    # Stopping and immediately starting must not let the old stop callback kill
    # the newly selected ambient stream.
    director.set_muted(false)
    director.start_ambient("sunlit-roots")
    await frames(1)
    director.stop_ambient()
    director.start_ambient("pollen-halls")
    await create_timer(0.4).timeout
    ok(director._ambient_player.playing, "stale ambient stop callback stopped the new ambience")

    # Hush should also avoid synthesizing/cache-growing one-off sounds.
    var before_cache: int = director._cache.size()
    director.set_muted(true)
    for _index in range(8):
        director.play_song_launch()
    director.play_footstep()
    ok(director._cache.size() == before_cache, "muted events still synthesized/cached sounds")
    # Entering an uncached region used to build its whole ambient bed inside the
    # frame that changed region: 128k samples at 16kHz, ~110ms, against a 6.9ms
    # steady-state frame -- a 15x hitch on each region's first entry, four times
    # a run. The bed holds no content above 400Hz, so the rate came down to 8kHz.
    #
    # Measure the WORK, not the wall clock. A wall-clock budget was tried first
    # and flaked under CPU contention (91ms against an 80ms budget) -- it was
    # measuring the test machine, not the generator. Sample count is the property
    # that actually determines the cost, and it is deterministic.
    var fresh := AudioDirector.new()
    root.add_child(fresh)
    await frames(1)
    var worst_samples := 0
    for region_key: String in ["sunlit-roots", "pollen-halls", "mushroom-lull", "roost"]:
        fresh.start_ambient(region_key)
        var bed_now: AudioStreamWAV = fresh._ambient_player.stream
        worst_samples = maxi(worst_samples, bed_now.data.size() / 2)
        await frames(1)
    var bed: AudioStreamWAV = fresh._ambient_player.stream
    ok(worst_samples <= 64000,
        "an ambient bed generated %d samples; at 8kHz the whole cost is 64000" % worst_samples)
    # Nyquist must stay well clear of the loudest partial (2x the 130.81Hz root).
    ok(bed != null and bed.mix_rate <= 8000,
        "the ambient bed is generated at %s Hz; every partial in it is below 400Hz" % (
            str(bed.mix_rate) if bed != null else "nothing"))
    ok(bed != null and bed.mix_rate >= 4000,
        "the ambient bed sample rate dropped too far; check the Nyquist margin over the loudest partial")
    # The bed must still be eight seconds of audio, whatever the rate.
    ok(bed != null and is_equal_approx(float(bed.data.size()) / 2.0 / float(bed.mix_rate), 8.0),
        "the ambient bed is no longer eight seconds long")
    fresh.stop_ambient()
    fresh.queue_free()

    # Randomized launch pitch must not create a new cached PCM stream per note.
    director.set_muted(false)
    before_cache = director._cache.size()
    for _index in range(20):
        director.play_song_launch()
    ok(director._cache.size() <= before_cache + 1, "randomized launches grew the PCM cache")

    # Invalid public parameters should be ignored rather than allocating an
    # invalid/empty stream and producing an engine error.
    before_cache = director._cache.size()
    director.play_tone(440.0, -1.0, 0.1, 0)
    director.play_chord([], 0.0, 0.1, 0.5)
    director.play_chord([null, "not-a-number", {}], 0.2, 0.1, 0.5)
    ok(director._cache.size() == before_cache, "invalid audio parameters entered the cache")

    director.play_tone(0.0, 0.2, 0.1, 0)
    director.play_tone(11025.1, 0.2, 0.1, 0)
    director.play_tone(440.0, AudioDirector.MAX_SFX_DURATION + 0.1, 0.1, 0)
    director.play_tone(440.0, 0.2, 0.0, 0)
    ok(director._cache.size() == before_cache, "out-of-range audio parameters entered the cache")

    # Generated PCM must remain a valid mono 16-bit stream and stay within
    # signed 16-bit sample bounds.
    var probe_tone: AudioStreamWAV = director._make_tone([440.0], 0.03, 1.0, 1.0, true, 2)
    ok(probe_tone.format == AudioStreamWAV.FORMAT_16_BITS, "tone stream format was not 16-bit PCM")
    ok(probe_tone.mix_rate == 22050, "tone stream used an unexpected mix rate")
    ok(not probe_tone.stereo, "tone stream unexpectedly used stereo")
    ok(probe_tone.data.size() > 0 and probe_tone.data.size() % 2 == 0, "tone stream had malformed PCM data")
    var max_sample := 0
    for byte_index in range(0, probe_tone.data.size(), 2):
        max_sample = maxi(max_sample, absi(probe_tone.data.decode_s16(byte_index)))
    ok(max_sample <= 32767, "tone PCM exceeded signed 16-bit bounds")
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
    ok(most_reused <= 4, "SFX pool repeatedly reused one voice")

    # Every synthesized chord must land on zero. play_chord used a flat
    # envelope, so the stream stopped mid-waveform at full amplitude: measured
    # 37-41% of peak on the last sample of every hit, footstep and dash. At a
    # 0.10s footstep throttle that is a click, repeating constantly.
    _check_chords_release_to_silence(director)

    # Child players must release their streams before the parent leaves the
    # tree; otherwise short smoke teardown leaves AudioStreamPlaybackWAV refs.
    for player in director._sfx_players:
        _watch_player_exit(player)
    _watch_player_exit(director._ambient_player)
    root.remove_child(director)
    director.free()
    ok(_exit_stream_states.size() == _watched_players.size(), "not all active players reached teardown")
    for cleared in _exit_stream_states:
        ok(cleared, "an audio player retained its stream during teardown")

    # AudioServer drains stopped playbacks asynchronously; let the final
    # playback resources drain before this focused test exits.
    await frames(30)
    finish(null, "BEAUTY_FOREST_AUDIO")

func _check_chords_release_to_silence(director: AudioDirector) -> void:
    director.play_chord([261.63, 329.63, 392.0], 0.20, 0.10)
    director.play_footstep()
    director.play_hit()
    director.play_level()
    director.play_dash()
    for key: String in director._cache.keys():
        if not key.begins_with("chord_"):
            continue
        var stream := director._cache[key] as AudioStreamWAV
        if stream == null or stream.data.size() < 4:
            continue
        var count: int = stream.data.size() / 2
        var peak := 0.0
        for index in range(count):
            peak = maxf(peak, absf(_wav_sample(stream.data, index)))
        ok(peak > 0.0, "a cached chord is silent")
        var tail: float = absf(_wav_sample(stream.data, count - 1))
        if peak > 0.0:
            ok(tail < peak * 0.02,
                "chord %s ends at %.1f%% of peak, which clicks" % [key.left(28), tail / peak * 100.0])

func _wav_sample(data: PackedByteArray, index: int) -> float:
    var raw: int = (int(data[index * 2 + 1]) << 8) | int(data[index * 2])
    if raw >= 32768:
        raw -= 65536
    return float(raw) / 32768.0
