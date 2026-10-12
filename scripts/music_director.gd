class_name MusicDirector
extends Node

## The forest's own music box. Every region hums a real composed lullaby —
## soft chord pads, a warm bass, and a sparse pentatonic bell melody —
## synthesized here as PCM and looped seamlessly. No audio files ship with the
## game; four hand-tuned songs (one per region mood) are built from note
## kernels so the whole library costs a few megabytes, not a download.
##
## Generation is time-sliced: a full song renders across many frames inside a
## ~6ms/frame budget, because building 600k samples of PCM in one frame was
## exactly the kind of hitch the old ambient bed was trimmed to avoid. While a
## song renders, whatever is already playing keeps playing; the new lullaby
## crossfades in only when it is complete.

signal song_ready(song_key: String)

const SAMPLE_RATE := 22050
const BARS := 8
const BEATS_PER_BAR := 4
const LOOP_PEAK := 0.80
const MUSIC_LEVEL := 0.5
const SILENCE_DB := -80.0
const MIN_AUDIBLE_VOLUME := 0.001
const FADE_IN_SECONDS := 1.6
const FADE_OUT_SECONDS := 0.7
const FRAME_BUDGET_USEC := 6000
## Semitone tables for the two moods the forest sings in.
const MAJOR_PENTATONIC := [0, 2, 4, 7, 9]
const MINOR_PENTATONIC := [0, 3, 5, 7, 10]

## One song per region mood, all in the family of the old ambient roots
## (sunlit-roots 110Hz, pollen-halls 123.47, mushroom-lull 98, roost 130.81)
## so the walk's regions keep their own colors. Unknown keys fall back to the
## sunlit song. Each song: a key root, a tempo, four triads as semitones over
## the root (two bars each), the pentatonic scale the bells play, a
## hand-written melody — scale degrees 0-4, +10 for an octave lift, -1 for a
## rest, two slots per bar — and the octave the bells ring in.
const SONGS := {
    "sunlit-roots": {
        "root": 220.0, "tempo": 72.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        "melody": [2, 4, 3, 2, 1, 3, 2, -1, 1, 2, 3, 4, 12, 11, 0, -1],
    },
    "pollen-halls": {
        "root": 146.83, "tempo": 78.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        "melody": [4, 1, 2, 3, 4, 2, 1, -1, 0, 2, 3, 4, 2, 0, 2, -1],
    },
    "mushroom-lull": {
        "root": 164.81, "tempo": 63.0, "melody_octave": 2,
        "scale": MINOR_PENTATONIC,
        "chords": [[0, 3, 7], [8, 12, 15], [3, 7, 10], [10, 14, 17]],
        "melody": [2, 3, 2, 1, 0, 2, 1, -1, 3, 4, 3, 2, 1, 0, 2, -1],
    },
    "roost": {
        "root": 130.81, "tempo": 66.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        "melody": [4, -1, 3, -1, 2, -1, 1, 0, 3, -1, 2, -1, 1, -1, 0, -1],
    },
}

var master_volume := 0.80
var muted := false
var _players: Array[AudioStreamPlayer] = []
var _active_voice := 0
var _songs: Dictionary = {}
var _want_key := ""
var _current_key := ""
var _serial := 0
var _fade_tween: Tween
var _queue: Array = []
var _buffer := PackedFloat32Array()
var _pcm := PackedByteArray()
var _kernels: Dictionary = {}
var _gain := 1.0
var _shut_down := false

func _ready() -> void:
    for index in range(2):
        var player := AudioStreamPlayer.new()
        player.name = "MusicVoice%d" % index
        player.bus = &"Master"
        player.tree_exiting.connect(_on_player_tree_exiting.bind(player))
        add_child(player)
        _players.append(player)

func _on_player_tree_exiting(player: AudioStreamPlayer) -> void:
    # Children leave the tree before the parent's _exit_tree runs; release each
    # playback here as well so the audio server can drop its refs.
    if is_instance_valid(player):
        player.stop()
        player.stream = null

func _exit_tree() -> void:
    _cancel_fade()
    for player: AudioStreamPlayer in _players:
        if is_instance_valid(player):
            player.stop()
            player.stream = null
    _want_key = ""
    _current_key = ""
    _queue.clear()
    _buffer = PackedFloat32Array()
    _pcm = PackedByteArray()
    _kernels.clear()
    _songs.clear()

func set_master(volume: float, now_muted: bool) -> void:
    if not is_finite(volume):
        volume = 0.0
    master_volume = clampf(volume, 0.0, 1.0)
    muted = now_muted
    _apply_output()

## The one audible level: the player's own volume, scaled down because a
## lullaby sits under the lantern's chimes, never over them.
func _music_db() -> float:
    return linear_to_db(maxf(MIN_AUDIBLE_VOLUME, master_volume * MUSIC_LEVEL))

func _is_silent() -> bool:
    return muted or master_volume <= MIN_AUDIBLE_VOLUME

func play_region(key: String) -> void:
    ## Ask for a region's lullaby. Calling again with the region already
    ## playing (or already rendering) is a no-op, so floor loads and resumes
    ## can call this freely. The song crossfades in when its render finishes.
    if _shut_down:
        return
    var song_key := key if SONGS.has(key) else "sunlit-roots"
    if _want_key == song_key and (_current_key == song_key or not _queue.is_empty()):
        return
    if _current_key == song_key and _queue.is_empty():
        # Already sounding; make sure it is audible, and never restart it — a
        # resume must not jump the lullaby back to its first bar.
        if _is_silent():
            return
        var player := _players[_active_voice]
        if not player.playing:
            _begin_voice(song_key)
        elif _fade_tween == null or not _fade_tween.is_valid():
            player.volume_db = _music_db()
        return
    _want_key = song_key
    if _songs.has(song_key):
        _begin_voice(song_key)
        return
    _schedule_render(song_key)

func stop_music() -> void:
    ## The nap card, the ending and the dragon's sleep are moments of quiet;
    ## the lullaby bows out instead of talking over them.
    if _shut_down:
        return
    _want_key = ""
    _current_key = ""
    _queue.clear()
    _serial += 1
    _cancel_fade()
    var serial := _serial
    var stopping := _active_voice
    if not is_instance_valid(_players[stopping]) or not _players[stopping].playing:
        return
    if _is_silent():
        _players[stopping].stop()
        return
    _fade_tween = create_tween()
    _fade_tween.tween_property(_players[stopping], "volume_db", SILENCE_DB, FADE_OUT_SECONDS)
    _fade_tween.tween_callback(func() -> void:
        if serial == _serial and is_instance_valid(_players[stopping]):
            _players[stopping].stop()
    )

func shutdown() -> void:
    ## Hush every voice and drop the cached PCM so the audio server can release
    ## its playbacks before the process exits. Idempotent, like the SFX side.
    if _shut_down:
        return
    _shut_down = true
    _want_key = ""
    _current_key = ""
    _queue.clear()
    _cancel_fade()
    for player: AudioStreamPlayer in _players:
        if is_instance_valid(player):
            player.stop()
            player.stream = null
    _songs.clear()
    _buffer = PackedFloat32Array()
    _pcm = PackedByteArray()
    _kernels.clear()

func current_stream() -> AudioStreamWAV:
    var player := _players[_active_voice] if _active_voice < _players.size() else null
    if player == null or not is_instance_valid(player):
        return null
    return player.stream as AudioStreamWAV

func _process(_delta: float) -> void:
    if _queue.is_empty() or _shut_down:
        return
    var deadline := Time.get_ticks_usec() + FRAME_BUDGET_USEC
    while not _queue.is_empty():
        var job: Dictionary = _queue[0]
        _queue.remove_at(0)
        _run_job(job)
        if Time.get_ticks_usec() >= deadline:
            break

func _schedule_render(song_key: String) -> void:
    _serial += 1
    _queue.clear()
    _buffer = PackedFloat32Array()
    _buffer.resize(_loop_samples(song_key))
    # The encode jobs write into a script member, not into a finished stream's
    # `data` property — a property write on a packed array mutates a
    # copy-on-write temporary and silently lands nowhere. The finished bytes
    # are handed to the stream in one assignment at the finish step.
    _pcm = PackedByteArray()
    _pcm.resize(_buffer.size() * 2)
    _kernels.clear()
    _gain = 1.0
    var spec: Dictionary = SONGS[song_key]
    var chords: Array = spec["chords"]
    for chord_index in range(chords.size()):
        _queue.append({"step": "pad", "chord": chord_index, "key": song_key})
        _queue.append({"step": "bass", "chord": chord_index, "key": song_key})
    var melody: Array = spec["melody"]
    for slot in range(melody.size()):
        if int(melody[slot]) >= 0:
            _queue.append({"step": "bell", "slot": slot, "key": song_key})
    for bar in range(BARS):
        _queue.append({"step": "mix", "bar": bar, "key": song_key})
    _queue.append({"step": "scan", "key": song_key})
    var chunk := 131072
    var total := _buffer.size()
    for start in range(0, total, chunk):
        _queue.append({"step": "encode", "start": start, "end": mini(start + chunk, total), "key": song_key})
    _queue.append({"step": "finish", "key": song_key})

func _run_job(job: Dictionary) -> void:
    var song_key := String(job["key"])
    # A newer request superseded this render: every stale job is dropped,
    # including its finish — its half-encoded stream is erased by the next
    # _schedule_render instead of ever being played.
    if _want_key != song_key:
        return
    match String(job["step"]):
        "pad":
            _kernels["pad_%d" % int(job["chord"])] = _pad_kernel(song_key, int(job["chord"]))
        "bass":
            _kernels["bass_%d" % int(job["chord"])] = _bass_kernel(song_key, int(job["chord"]))
        "bell":
            _kernels["bell_%d" % int(job["slot"])] = _bell_kernel(song_key, int(job["slot"]))
        "mix":
            _mix_bar(song_key, int(job["bar"]))
        "scan":
            var peak := 0.0
            for value in _buffer:
                peak = maxf(peak, absf(value))
            _gain = LOOP_PEAK / peak if peak > 0.0001 else 1.0
        "encode":
            _encode_range(int(job["start"]), int(job["end"]))
        "finish":
            _finish_render(song_key)

func _loop_samples(song_key: String) -> int:
    return int(round(_bar_seconds(SONGS[song_key]) * float(BARS) * float(SAMPLE_RATE)))

func _bar_seconds(spec: Dictionary) -> float:
    ## Four beats at the song's tempo — one chord-holding bar.
    return 60.0 * float(BEATS_PER_BAR) / float(spec["tempo"])

func _note_frequency(song_key: String, semitones: int, octave: int) -> float:
    var spec: Dictionary = SONGS[song_key]
    return float(spec["root"]) * pow(2.0, float(semitones) / 12.0) * pow(2.0, float(octave))

func _pad_kernel(song_key: String, chord_index: int) -> PackedFloat32Array:
    ## A chord held for two bars with a raised-cosine attack and a long release
    ## that wraps past the loop boundary into the next chord's attack — that
    ## overlap is what makes the loop seamless and the harmony dreamy.
    var spec: Dictionary = SONGS[song_key]
    var seconds := _bar_seconds(spec) * 2.0
    var attack := 0.9
    var release := 1.1
    var length := int(round((seconds + release) * float(SAMPLE_RATE)))
    var kernel := PackedFloat32Array()
    kernel.resize(length)
    var chord: Array = spec["chords"][chord_index]
    for semitone: int in chord:
        var frequency := _note_frequency(song_key, semitone, 0)
        for sample in range(length):
            var t := float(sample) / float(SAMPLE_RATE)
            var envelope := _pad_envelope(t, seconds, attack, release)
            if envelope <= 0.0:
                continue
            var phase := t * frequency * TAU
            # A slightly detuned twin under each note: the slow beat between
            # them is the "two hands on one piano" warmth.
            var voice := sin(phase) + sin(phase * 1.0035 + 0.4) * 0.6
            kernel[sample] += voice * envelope
    var normalize := 1.0 / float(maxi(1, chord.size()))
    for sample in range(length):
        kernel[sample] *= normalize * 0.5
    return kernel

func _pad_envelope(t: float, hold: float, attack: float, release: float) -> float:
    if t < 0.0 or t > hold + release:
        return 0.0
    if t < attack:
        return 0.5 - 0.5 * cos(t / attack * PI)
    if t > hold:
        var into_release := (t - hold) / release
        return 0.5 + 0.5 * cos(into_release * PI)
    return 1.0

func _bass_kernel(song_key: String, chord_index: int) -> PackedFloat32Array:
    var spec: Dictionary = SONGS[song_key]
    var seconds := _bar_seconds(spec) * 2.0
    var release := 0.8
    var length := int(round((seconds + release) * float(SAMPLE_RATE)))
    var kernel := PackedFloat32Array()
    kernel.resize(length)
    var chord: Array = spec["chords"][chord_index]
    var frequency := _note_frequency(song_key, int(chord[0]), -1)
    for sample in range(length):
        var t := float(sample) / float(SAMPLE_RATE)
        var envelope := _pad_envelope(t, seconds, 0.15, release)
        if envelope <= 0.0:
            continue
        var phase := t * frequency * TAU
        kernel[sample] = (sin(phase) + sin(phase * 2.0) * 0.12) * envelope * 0.34
    return kernel

func _bell_kernel(song_key: String, slot: int) -> PackedFloat32Array:
    ## A music-box note: a soft strike, a fast bloom, then a long exponential
    ## ring with two quiet upper partials. Bars overlap the loop seam through
    ## the same wrapped placement the pads use, so a note rung on the last bar
    ## decays into the first one.
    var spec: Dictionary = SONGS[song_key]
    var seconds := 1.9
    var length := int(round(seconds * float(SAMPLE_RATE)))
    var kernel := PackedFloat32Array()
    kernel.resize(length)
    var degree := int(spec["melody"][slot])
    var octave := int(spec["melody_octave"])
    if degree >= 10:
        degree -= 10
        octave += 1
    var scale: Array = spec["scale"]
    var frequency := _note_frequency(song_key, int(scale[degree]), octave)
    for sample in range(length):
        var t := float(sample) / float(SAMPLE_RATE)
        var envelope := exp(-t * 2.6) * minf(1.0, t * 90.0)
        var phase := t * frequency * TAU
        kernel[sample] = (sin(phase) + sin(phase * 2.0) * 0.30 + sin(phase * 3.0) * 0.10) * envelope * 0.6
    return kernel

func _mix_bar(song_key: String, bar: int) -> void:
    var spec: Dictionary = SONGS[song_key]
    var bar_samples := int(round(_bar_seconds(spec) * float(SAMPLE_RATE)))
    var chord_index := mini(bar / 2, 3)
    var at := bar * bar_samples
    _add_wrapped(_kernels.get("pad_%d" % chord_index, PackedFloat32Array()), at)
    _add_wrapped(_kernels.get("bass_%d" % chord_index, PackedFloat32Array()), at)
    var melody: Array = spec["melody"]
    var beat_samples := int(round(60.0 / float(spec["tempo"]) * float(SAMPLE_RATE)))
    for half in range(2):
        var slot := bar * 2 + half
        if slot >= melody.size() or int(melody[slot]) < 0:
            continue
        var cached: Variant = _kernels.get("bell_%d" % slot)
        if cached is PackedFloat32Array:
            _add_wrapped(cached, at + half * beat_samples)

func _add_wrapped(kernel: PackedFloat32Array, at: int) -> void:
    var loop_length := _buffer.size()
    if kernel.is_empty() or loop_length == 0:
        return
    var start := posmod(at, loop_length)
    var count := kernel.size()
    var head := mini(count, loop_length - start)
    for k in range(head):
        _buffer[start + k] += kernel[k]
    for k in range(count - head):
        _buffer[k] += kernel[head + k]

func _encode_range(start: int, end: int) -> void:
    for sample in range(start, end):
        _pcm.encode_s16(sample * 2, int(clampf(_buffer[sample] * _gain, -1.0, 1.0) * 32767.0))

func _finish_render(song_key: String) -> void:
    if _pcm.is_empty():
        return
    var song := AudioStreamWAV.new()
    song.format = AudioStreamWAV.FORMAT_16_BITS
    song.mix_rate = SAMPLE_RATE
    song.stereo = false
    song.data = _pcm
    song.loop_mode = AudioStreamWAV.LOOP_FORWARD
    song.loop_begin = 0
    song.loop_end = _pcm.size() / 2
    _buffer = PackedFloat32Array()
    _pcm = PackedByteArray()
    _kernels.clear()
    _songs[song_key] = song
    # The voice starts before the announcement: when a listener hears "song
    # ready", the lullaby is already attached and sounding, not about to be.
    if _want_key == song_key and not _is_silent():
        _begin_voice(song_key)
    song_ready.emit(song_key)

func _begin_voice(song_key: String) -> void:
    var song: AudioStreamWAV = _songs.get(song_key)
    if song == null or _players.size() < 2:
        return
    _serial += 1
    _cancel_fade()
    var outgoing := _active_voice
    _active_voice = (_active_voice + 1) % _players.size()
    var incoming := _active_voice
    _current_key = song_key
    var incoming_player := _players[incoming]
    incoming_player.stream = song
    incoming_player.volume_db = SILENCE_DB
    if not incoming_player.playing:
        incoming_player.play()
    if _is_silent():
        return
    var serial := _serial
    _fade_tween = create_tween()
    _fade_tween.set_parallel(true)
    _fade_tween.tween_property(incoming_player, "volume_db", _music_db(), FADE_IN_SECONDS)
    if _players[outgoing] != incoming_player and _players[outgoing].playing:
        var leaving := _players[outgoing]
        _fade_tween.tween_property(leaving, "volume_db", SILENCE_DB, FADE_IN_SECONDS)
        _fade_tween.chain().tween_callback(func() -> void:
            if serial == _serial and is_instance_valid(leaving):
                leaving.stop()
        )

func _fade(voice: int, target_db: float, seconds: float) -> void:
    if voice < 0 or voice >= _players.size() or not is_instance_valid(_players[voice]):
        return
    var serial := _serial
    _fade_tween = create_tween()
    _fade_tween.tween_property(_players[voice], "volume_db", target_db, seconds)
    _fade_tween.tween_callback(func() -> void:
        if serial == _serial and is_instance_valid(_players[voice]) and target_db <= SILENCE_DB + 1.0:
            _players[voice].stop()
    )

func _apply_output() -> void:
    if _shut_down or not is_inside_tree():
        return
    _cancel_fade()
    if _is_silent():
        for player: AudioStreamPlayer in _players:
            if is_instance_valid(player):
                player.stop()
                player.volume_db = SILENCE_DB
        _current_key = ""
        return
    # Audible again: whatever the forest was asked for, hum it.
    if not _want_key.is_empty():
        if _songs.has(_want_key):
            _begin_voice(_want_key)
        elif _queue.is_empty():
            _schedule_render(_want_key)
    elif not _current_key.is_empty() and _songs.has(_current_key):
        _begin_voice(_current_key)

func _cancel_fade() -> void:
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    _fade_tween = null
