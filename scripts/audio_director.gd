class_name AudioDirector
extends Node

## Procedural WebAudio-like synthesis for Godot. No external audio files are
## required: chimes, pads, footsteps, and soft impact sounds are generated as
## PCM at runtime and mixed through a small polyphonic pool. The region
## lullabies live one file over, in MusicDirector — this file only speaks when
## something happens.

const SILENCE_DB := -80.0
const MIN_AUDIBLE_VOLUME := 0.001
const MAX_SFX_DURATION := 8.0
const SFX_POOL_SIZE := 10

var master_volume := 0.80
var muted := false
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_voice := 0
var _last_footstep := 0.0
var _cache: Dictionary = {}
var _shut_down := false

func _ready() -> void:
    for index in range(SFX_POOL_SIZE):
        var player := AudioStreamPlayer.new()
        player.name = "Sfx%d" % index
        player.bus = &"Master"
        player.tree_exiting.connect(_on_player_tree_exiting.bind(player))
        add_child(player)
        _sfx_players.append(player)
    _apply_output_state()

func _on_player_tree_exiting(player: AudioStreamPlayer) -> void:
    # Child nodes leave the tree before their parent's _exit_tree callback. Do
    # the stop/detach here as well so the audio server can release each playback
    # before the node and its generated stream are destroyed.
    if is_instance_valid(player):
        player.stop()
        player.stream = null

func _silence_voices() -> void:
    # Hush every SFX voice without touching state that belongs to teardown or
    # shutdown specifically.
    for player: AudioStreamPlayer in _sfx_players:
        if is_instance_valid(player):
            player.stop()
            player.stream = null

func _exit_tree() -> void:
    _silence_voices()
    _sfx_players.clear()
    _next_sfx_voice = 0
    _cache.clear()

func set_volume(value: float) -> void:
    if not is_finite(value):
        value = 0.0
    master_volume = clampf(value, 0.0, 1.0)
    _apply_output_state()

func set_muted(value: bool) -> void:
    muted = value
    _apply_output_state()

func _is_silent() -> bool:
    return muted or master_volume <= MIN_AUDIBLE_VOLUME

func _sfx_volume_db() -> float:
    return linear_to_db(maxf(0.0001, master_volume))

func _apply_output_state() -> void:
    if not is_inside_tree():
        return
    for player: AudioStreamPlayer in _sfx_players:
        if not is_instance_valid(player):
            continue
        if _is_silent():
            player.stop()
            player.volume_db = SILENCE_DB
        else:
            player.volume_db = _sfx_volume_db()

func _can_play_sfx() -> bool:
    return is_inside_tree() and not _shut_down and not _is_silent() and not _sfx_players.is_empty()

func shutdown() -> void:
    ## Hush every voice and drop cached PCM so the audio server can release
    ## its playbacks before the process exits. Quitting mid-playback leaves
    ## AudioStreamPlayback refs behind and leaks ObjectDB entries at exit.
    ## Idempotent: call once from the graceful quit path, then quit only
    ## after a short drain window so no new voice can start in between.
    if _shut_down:
        return
    _shut_down = true
    _silence_voices()
    _cache.clear()

func _valid_sfx_params(duration: float, volume: float, bright: float) -> bool:
    return is_finite(duration) and duration > 0.0 and duration <= MAX_SFX_DURATION \
        and is_finite(volume) and volume > 0.0 and is_finite(bright)

func play_chord(frequencies: Array, duration: float = 0.55, volume: float = 0.10, bright: float = 0.55, pitch: float = 1.0) -> void:
    if not _can_play_sfx() or frequencies.is_empty() or not _valid_sfx_params(duration, volume, bright):
        return
    var normalized: Array[float] = []
    for frequency: Variant in frequencies:
        if typeof(frequency) != TYPE_INT and typeof(frequency) != TYPE_FLOAT:
            continue
        var value := float(frequency)
        if is_finite(value) and value > 0.0 and value <= 11025.0:
            normalized.append(value)
    if normalized.is_empty():
        return
    var safe_volume := clampf(volume, 0.0, 1.0)
    var safe_bright := clampf(bright, 0.0, 1.0)
    var key := "chord_%s_%.2f_%.2f_%.2f" % [str(normalized), duration, safe_volume, safe_bright]
    if not _cache.has(key):
        _cache[key] = _make_tone(normalized, duration, safe_volume, safe_bright, false)
    _play_cached(key, pitch)

func play_tone(frequency: float, duration: float = 0.30, volume: float = 0.08, wave: int = 0, pitch: float = 1.0) -> void:
    if not _can_play_sfx() or not is_finite(frequency) or frequency <= 0.0 or frequency > 11025.0 \
        or not _valid_sfx_params(duration, volume, 0.35) or wave < 0 or wave > 2:
        return
    var safe_volume := clampf(volume, 0.0, 1.0)
    var key := "tone_%.2f_%.2f_%.2f_%d" % [frequency, duration, safe_volume, wave]
    if not _cache.has(key):
        _cache[key] = _make_tone([frequency], duration, safe_volume, 0.35, true, wave)
    _play_cached(key, pitch)

func play_pickup(index: int = 0) -> void:
    var tones: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0]
    play_tone(tones[posmod(index, tones.size())], 0.38, 0.085, 1)

func play_soothe(index: int = 0, big: bool = false) -> void:
    ## Each guided wisp sings the next step of a never-ending pentatonic
    ## melody, so soothing a trail of wisps hums a little song by itself.
    ## Very Big Wisps get a warm low harmony underneath, like the forest
    ## humming along an octave down.
    var melody: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33]
    var tone := melody[posmod(index, melody.size())]
    play_tone(tone, 0.42, 0.075, 1)
    play_tone(tone * 2.0, 0.30, 0.030, 1)
    if big:
        play_tone(tone * 0.5, 0.60, 0.050, 1)

func play_hit() -> void:
    play_chord([220.0, 329.63], 0.20, 0.055, 0.28)

func play_soft_hit() -> void:
    play_chord([164.81, 196.0], 0.28, 0.060, 0.22)

func play_song_launch() -> void:
    var frequency := 740.0 + randf_range(-20, 20)
    play_tone(740.0, 0.16, 0.045, 2, frequency / 740.0)

func play_footstep() -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if now - _last_footstep < 0.10:
        return
    _last_footstep = now
    play_chord([105.0, 151.0], 0.10, 0.022, 0.12, randf_range(0.96, 1.04))

func play_dash() -> void:
    play_chord([440.0, 659.25, 880.0], 0.24, 0.070, 0.85)

func play_level() -> void:
    play_chord([392.0, 493.88, 587.33, 783.99], 1.05, 0.12, 0.90)

func play_gold_beat() -> void:
    play_tone(987.77, 0.16, 0.060, 1)

func play_miss() -> void:
    play_tone(220.0, 0.16, 0.040, 0)

func play_win() -> void:
    play_chord([261.63, 329.63, 392.0, 523.25, 659.25], 1.45, 0.12, 0.82)

func play_sleep() -> void:
    play_chord([196.0, 246.94, 293.66, 392.0], 1.8, 0.085, 0.18)

func _play_cached(key: String, pitch: float) -> void:
    if not _can_play_sfx() or not _cache.has(key):
        return
    var stream: AudioStream = _cache[key]
    if stream == null:
        return
    var safe_pitch := 1.0
    if is_finite(pitch) and pitch > 0.0:
        safe_pitch = clampf(pitch, 0.25, 3.0)
    var chosen := -1
    for offset in range(_sfx_players.size()):
        var index := (_next_sfx_voice + offset) % _sfx_players.size()
        var candidate := _sfx_players[index]
        if not is_instance_valid(candidate):
            continue
        if not candidate.playing:
            chosen = index
            break
    if chosen < 0:
        for offset in range(_sfx_players.size()):
            var index := (_next_sfx_voice + offset) % _sfx_players.size()
            if is_instance_valid(_sfx_players[index]):
                chosen = index
                break
    if chosen < 0:
        return
    _next_sfx_voice = (chosen + 1) % _sfx_players.size()
    var player := _sfx_players[chosen]
    player.stream = stream
    player.pitch_scale = safe_pitch
    player.volume_db = _sfx_volume_db()
    player.play()

func _make_tone(frequencies: Array[float], duration: float, volume: float, bright: float, decaying: bool, wave: int = 0) -> AudioStreamWAV:
    var sample_rate := 22050
    var safe_duration := 0.01
    if is_finite(duration):
        safe_duration = clampf(duration, 0.01, MAX_SFX_DURATION)
    var safe_volume := 0.0
    if is_finite(volume):
        safe_volume = clampf(volume, 0.0, 1.0)
    var safe_bright := 0.0
    if is_finite(bright):
        safe_bright = clampf(bright, 0.0, 1.0)
    var valid_frequencies: Array[float] = []
    for frequency: float in frequencies:
        if is_finite(frequency) and frequency > 0.0 and frequency <= float(sample_rate) * 0.5:
            valid_frequencies.append(frequency)
    var sample_count := maxi(1, int(safe_duration * float(sample_rate)))
    var bytes := PackedByteArray()
    bytes.resize(sample_count * 2)
    for sample in range(sample_count):
        var t := float(sample) / float(sample_rate)
        var envelope := 1.0
        if decaying:
            envelope = exp(-t * 4.4) * minf(1.0, t * 28.0)
        else:
            # Chords hold their sustain, but the stream still has to land on
            # zero: stopping mid-waveform at full amplitude is an audible click,
            # and footsteps fire on a 0.10s throttle so it repeats constantly.
            # A short linear release at the tail costs nothing and removes it.
            var release_samples := maxi(2, int(sample_rate * 0.012))
            var remaining := sample_count - sample
            if remaining < release_samples:
                envelope = float(remaining) / float(release_samples)
        var sample_value := 0.0
        for frequency: float in valid_frequencies:
            var phase := t * frequency * TAU
            var voice := sin(phase)
            match wave:
                1:
                    voice = sin(phase) * 0.72 + sin(phase * 2.0) * 0.20
                2:
                    voice = signf(sin(phase)) * 0.36 + sin(phase) * 0.64
                _:
                    voice = sin(phase) * 0.84 + sin(phase * 2.0) * safe_bright * 0.12
            sample_value += voice
        sample_value /= maxf(1.0, float(valid_frequencies.size()))
        sample_value = tanh(sample_value * 1.25) * envelope * safe_volume
        bytes.encode_s16(sample * 2, int(clampf(sample_value, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = bytes
    return stream
