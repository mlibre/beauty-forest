extends "res://tests/support/test_case.gd"
## Focused audio regression checks. Run with:
## godot --headless --path . --script tests/regression_audio.gd

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const MusicScores := preload("res://scripts/music_scores.gd")
const AudioDirector := preload("res://scripts/audio_director.gd")
const MusicDirector := preload("res://scripts/music_director.gd")

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

    # --- The music box: region lullabies replaced the old noise bed. ---
    var music := MusicDirector.new()
    root.add_child(music)
    await frames(1)
    # A request must never render the whole song inside the calling frame: the
    # generator is time-sliced because building 600k samples of PCM at once
    # hitched the frame that asked for it.
    music.play_region("mushroom-lull")
    ok(music.current_stream() == null, "play_region rendered a whole song inside one frame")
    var ready_key: String = await music.song_ready
    ok(ready_key == "mushroom-lull", "song_ready carried the wrong key: %s" % ready_key)
    var song: AudioStreamWAV = music.current_stream()
    if not ok(song != null, "the finished lullaby never attached to a voice"):
        await frames(30)
        finish(null, "BEAUTY_FOREST_AUDIO")
        return
    ok(song.format == AudioStreamWAV.FORMAT_16_BITS, "lullaby stream was not 16-bit PCM")
    ok(song.mix_rate == 22050, "lullaby stream used an unexpected mix rate")
    ok(not song.stereo, "lullaby stream unexpectedly used stereo")
    ok(song.loop_mode == AudioStreamWAV.LOOP_FORWARD and song.loop_begin == 0
        and song.loop_end == song.data.size() / 2, "the lullaby does not loop its whole length")
    var expected_seconds := 60.0 * 4.0 * 8.0 / 63.0
    var actual_seconds := float(song.data.size()) / 2.0 / float(song.mix_rate)
    ok(absf(actual_seconds - expected_seconds) < 0.1,
        "the lullaby is %.1fs; eight bars at 63 bpm is %.1fs" % [actual_seconds, expected_seconds])
    # It must hold actual music, at a level that stays soft.
    var peak := 0
    for sample_index in range(0, song.data.size(), 2):
        peak = maxi(peak, absi(song.data.decode_s16(sample_index)))
    ok(peak > 8000, "the rendered lullaby is nearly silent (peak %d)" % peak)
    ok(peak <= 32767, "the rendered lullaby clipped")
    # The seam: a wrap-mixed loop keeps sounding through the boundary; a
    # faded-out tail ends in silence and clicks on every repeat.
    var seam_peak := 0
    var seam_start: int = song.data.size() - 2048
    for sample_index in range(seam_start, song.data.size(), 2):
        seam_peak = maxi(seam_peak, absi(song.data.decode_s16(sample_index)))
    ok(seam_peak > 800, "the loop seam fades to silence instead of wrapping (peak %d)" % seam_peak)
    # Re-asking for the region that is already playing must not restart it.
    var before_stream: int = music.current_stream().get_instance_id()
    music.play_region("mushroom-lull")
    await frames(2)
    ok(music.current_stream().get_instance_id() == before_stream,
        "a repeated play_region restarted the lullaby")
    # A second region must arrive as a genuinely different song.
    music.play_region("roost")
    ready_key = await music.song_ready
    ok(ready_key == "roost", "the second song never finished rendering")
    ok(music.current_stream() != null and music.current_stream().data != song.data,
        "two different regions rendered the same song")

    # A volume change while a lullaby is sounding must adjust the level in
    # place. The settings panel emits one settings_changed per slider tick, so
    # a restart here turns every volume drag into a bar-zero stutter on a
    # second voice. The voice index is the restart detector: the stream is a
    # cached resource whose instance id survives a restart.
    var playing_voice: int = music._active_voice
    var playing_stream: int = music.current_stream().get_instance_id()
    music.set_master(0.5, false)
    await frames(2)
    ok(music._active_voice == playing_voice and music.current_stream() != null
        and music.current_stream().get_instance_id() == playing_stream,
        "a volume change restarted the sounding lullaby")
    ok(is_equal_approx(music._players[music._active_voice].volume_db, linear_to_db(0.25)),
        "a volume change left the lullaby at its old level (%f)"
            % music._players[music._active_voice].volume_db)

    # The same promise mid-crossfade: a volume tick lands while two voices
    # swap songs, and the old voice must still bow out instead of freezing
    # audible forever.
    music.play_region("mushroom-lull")
    await frames(5)
    var cross_voice: int = music._active_voice
    var cross_stream: int = music.current_stream().get_instance_id()
    music.set_master(0.4, false)
    await frames(2)
    ok(music._active_voice == cross_voice and music.current_stream() != null
        and music.current_stream().get_instance_id() == cross_stream,
        "a volume change mid-crossfade restarted the incoming lullaby")
    ok(music._fade_tween != null and music._fade_tween.is_valid(),
        "a volume change mid-crossfade left no fade to retire the old voice")
    # The retire fade lasts 0.7s of tween time, and headless frames advance
    # tween time by their real delta, so the wait is a real one-second tree
    # timer -- a sequence step, not a timing budget.
    await music.get_tree().create_timer(1.0).timeout
    var stray_playing := false
    for voice_player: AudioStreamPlayer in music._players:
        if voice_player != music._players[music._active_voice] and voice_player.playing:
            stray_playing = true
    ok(not stray_playing, "a volume change mid-crossfade left the old voice audible forever")

    # The whole songbook, sung once. A melody degree out of range or a chord
    # shape a kernel cannot build only ever crashes at render time -- and
    # four of the eight songs are new enough that no other test sings them.
    # Every song must render, attach, loop its whole length, and hold actual
    # music at a level that stays soft.
    for song_key: String in MusicScores.SONGS.keys():
        # Songs the earlier checks already rendered are cached: play_region
        # starts them at once and never re-announces a finished render, so
        # awaiting song_ready there would wait forever (a green suite that
        # proves nothing, or rather none of itself).
        var cached: bool = music._songs.has(song_key)
        music.play_region(song_key)
        if not cached:
            ready_key = await music.song_ready
            if not ok(ready_key == song_key, "the songbook's %s never finished rendering (got %s)" % [song_key, ready_key]):
                break
        await frames(2)
        var rendered: AudioStreamWAV = music.current_stream()
        if not ok(rendered != null and rendered.data.size() > 0,
                "the songbook's %s rendered empty" % song_key):
            break
        var expected := 60.0 * 4.0 * 8.0 / float(MusicScores.SONGS[song_key]["tempo"])
        var actual := float(rendered.data.size()) / 2.0 / float(rendered.mix_rate)
        if not ok(absf(actual - expected) < 0.1,
                "%s is %.1fs; eight bars at %s bpm is %.1fs" % [song_key, actual, MusicScores.SONGS[song_key]["tempo"], expected]):
            break
        var book_peak := 0
        for sample_index in range(0, rendered.data.size(), 2):
            book_peak = maxi(book_peak, absi(rendered.data.decode_s16(sample_index)))
        if not ok(book_peak > 8000 and book_peak <= 32767,
                "%s rendered at peak %d -- silent or clipped" % [song_key, book_peak]):
            break
    # The music box is deterministic: the same request twice yields the very
    # same bytes, so a save/load or a replay can never reshuffle the score.
    var twin := MusicDirector.new()
    root.add_child(twin)
    await frames(1)
    twin.play_region("mushroom-lull")
    await twin.song_ready
    var twin_stream: AudioStreamWAV = twin.current_stream()
    ok(twin_stream != null and twin_stream.data == song.data,
        "the lullaby is not deterministic; something in the music box rolls dice")
    twin.shutdown()
    twin.queue_free()
    # A mute must hush the music, and an unmute must bring it back.
    music.set_master(0.8, true)
    await frames(2)
    ok(not music._players[music._active_voice].playing, "mute left the lullaby running")
    music.set_master(0.8, false)
    await frames(2)
    ok(music._players[music._active_voice].playing, "unmute did not bring the lullaby back")
    # An interrupted render must poison nothing: ask, interrupt, ask again.
    var fresh := MusicDirector.new()
    root.add_child(fresh)
    await frames(1)
    fresh.play_region("pollen-halls")
    await frames(3)
    fresh.play_region("roost")
    await fresh.song_ready
    var fresh_stream: AudioStreamWAV = fresh.current_stream()
    ok(fresh_stream != null and fresh_stream.data.size() > 0,
        "an interrupted render left a broken song behind")
    fresh.shutdown()
    fresh.queue_free()
    music.shutdown()

    # Randomized launch pitch must not create a new cached PCM stream per note.
    director.set_muted(false)
    var before_cache: int = director._cache.size()
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
    for player in music._players:
        _watch_player_exit(player)
    root.remove_child(director)
    director.free()
    root.remove_child(music)
    music.free()
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
