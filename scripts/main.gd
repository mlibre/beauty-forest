extends "res://scripts/run_flow.gd"

## Beauty Forest — native Godot game director.
## Owns run state, mode transitions, input, and all system wiring. Progression,
## combat and floor construction are inherited from RunState, RunCombat and
## RunWorld.

const InputActions := preload("res://scripts/input_actions.gd")

func _ready() -> void:
    randomize()
    _rng.randomize()
    settings = BeautyData.load_settings()
    meta = BeautyData.load_meta()
    selected_style = String(meta.get("style", "standard"))
    if not BeautyContent.STYLE_DATA.has(selected_style):
        selected_style = "standard"
    InputActions.ensure()

    camera = Camera3D.new()
    camera.name = "SteadyIsometricCamera"
    camera.fov = 42.0
    camera.near = 0.08
    camera.far = 180.0
    camera.position = CAMERA_OFFSET
    add_child(camera)
    camera.current = true

    audio = AudioDirector.new()
    audio.name = "CozyAudio"
    add_child(audio)
    music = MusicDirector.new()
    music.name = "ForestMusic"
    add_child(music)

    ui = GameUI.new()
    ui.name = "CozyInterface"
    add_child(ui)
    _connect_ui()
    # The interface's doorbell: one soft voice for hovers and presses, spoken
    # through the theme so the UI chain never needs the audio director.
    ui.ui_sound = func(kind: String) -> void:
        if kind == "hover":
            audio.play_tone(659.25, 0.05, 0.012, 1)
        else:
            audio.play_tone(493.88, 0.07, 0.020, 1)
    _apply_settings(settings)

    _load_floor(1, true)
    ui.set_selected_style(selected_style)
    _show_menu()
    # The forest hums from the title screen on: the menu is the first thing a
    # player sees, and a quiet lullaby is the promise the walk keeps.
    music.play_region("sunlit-roots")
    # Boot marker: proves the whole script graph parsed and _ready finished.
    # regression_cold_boot boots a cache-less copy of this project and waits
    # for exactly this line, so a broken parse can never pass as a quiet boot.
    print("BEAUTY_FOREST_BOOT_OK")

func _connect_ui() -> void:
    ui.start_requested.connect(_on_start_requested)
    ui.play_pressed.connect(_begin_intro)
    ui.intro_advance_requested.connect(_advance_intro)
    ui.intro_skip_requested.connect(_finish_intro)
    ui.style_picked.connect(_on_style_picked)
    ui.resume_requested.connect(_resume_game)
    ui.restart_requested.connect(_on_restart_requested)
    ui.boon_picked.connect(pick_boon)
    ui.quit_requested.connect(quit_gracefully)
    ui.menu_requested.connect(_back_to_title)
    ui.shop_closed.connect(_on_shop_closed)
    ui.journal_closed.connect(_on_journal_closed)
    ui.settings_open_requested.connect(_open_settings)
    ui.settings_closed.connect(_on_settings_closed)
    ui.buy_requested.connect(_on_buy_requested)
    ui.charm_equip_requested.connect(_on_charm_equip_requested)
    ui.stanza_equip_requested.connect(_on_stanza_equip_requested)
    ui.mote_verse_requested.connect(_on_mote_verse_requested)
    ui.touch_vector_changed.connect(func(value):
        if player and is_instance_valid(player):
            player.set_touch_vector(value)
    )
    ui.touch_dash_requested.connect(_touch_dash)
    ui.touch_interact_requested.connect(_try_interact)
    ui.touch_journal_requested.connect(_open_journal)
    ui.touch_pause_requested.connect(_touch_pause)
    ui.settings_changed.connect(_apply_settings)

func _unhandled_input(event: InputEvent) -> void:
    # The intro owns every key while it is being told: any key turns the page,
    # Escape ends the telling and starts the walk at once. Mouse taps never
    # reach here — the intro layer speaks gui_input and already advanced.
    if _intro_active:
        if event is InputEventKey and event.pressed:
            if event.keycode == KEY_ESCAPE:
                _finish_intro()
            else:
                _advance_intro()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("bf_pause"):
        _advance_pause_state()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
        var fullscreen := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
        get_viewport().set_input_as_handled()
        return
    if mode == Mode.DRAFT and event is InputEventKey and event.pressed:
        # The three cards answer to 1/2/3 as well as to a click or a focused
        # Enter, so a keyboard walker never has to leave home row mid-level.
        var digit := -1
        match event.keycode:
            KEY_1:
                digit = 0
            KEY_2:
                digit = 1
            KEY_3:
                digit = 2
        if digit >= 0:
            # _draft_offers is the draft's own pending list, inherited here.
            if digit < _draft_offers.size():
                pick_boon(String(_draft_offers[digit].get("key", "")))
            get_viewport().set_input_as_handled()
        return
    # The menu's key line promises C opens the gentler-forest options, so it has
    # to work before a run starts -- otherwise the only way in is to begin, pause,
    # and find COZY from there.
    if mode == Mode.MENU and event.is_action_pressed("bf_settings"):
        _open_settings()
        get_viewport().set_input_as_handled()
        return
    if mode == Mode.DEAD and event.is_action_pressed("ui_accept"):
        _start_run(1)
        get_viewport().set_input_as_handled()
        return
    if mode == Mode.ENDING and event.is_action_pressed("ui_accept"):
        # Same promise as the ending screen's "Wander deeper" button: the walk
        # continues with the loadout intact.
        _start_run(floor_number + 1, true)
        get_viewport().set_input_as_handled()
        return
    if mode == Mode.PAUSED and event.is_action_pressed("bf_settings"):
        # The pause card's own keys line promises "Cozy options: C", and the
        # card also carries the button -- but the key answered only on the walk
        # and the title. On the very screen that advertises it, it was dead.
        _open_settings()
        get_viewport().set_input_as_handled()
        return
    if mode != Mode.PLAYING:
        return
    if event.is_action_pressed("bf_interact"):
        _try_interact()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("bf_shop"):
        if _near_merchant():
            _open_shop()
        else:
            ui.show_toast("Peddle parks on cozy corners of every thirty-floor stretch.", 3.4)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("bf_journal"):
        _open_journal()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("bf_settings"):
        _open_settings()
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    _update_camera(delta)
    _update_mote(delta)
    if _intro_active:
        _intro_timer -= delta
        if _intro_timer <= 0.0:
            _advance_intro()
    if mode == Mode.PLAYING:
        _tick_surprise(delta)
        play_seconds += delta
        invulnerable_time = maxf(0.0, invulnerable_time - delta)
        _mote_line_timer -= delta
        if _mote_line_timer <= 0.0:
            _mote_line_timer = _rng.randf_range(24.0, 36.0)
            # Mote's idle chatter was picked on this timer for a whole
            # generation of walks and then delivered nowhere: the only reader
            # of _mote_line was the descend announcement, so her thirty lines
            # of personality never reached a single player. She speaks on the
            # story card now -- the same transient moment the floor vignettes
            # use, never a permanent sentence over the walk. The finale
            # epilogue also keeps Mode.PLAYING while its ending counts down;
            # that is the one moment the walk stays quiet, so the timer
            # re-arms and says nothing there.
            if not ending_pending:
                _mote_line = String(BeautyContent.random_choice(BeautyLore.MOTE_LINES))
                ui.show_story("Mote ✦", _mote_line, 3.4)
        if play_seconds >= _next_petal_shower:
            _next_petal_shower = play_seconds + _rng.randf_range(34.0, 58.0)
            CozyVFX.burst(world, player.global_position + Vector3(0, 3.2, 0), Color(region["flower"]), 42, 1.25, 2.4)
            ui.show_toast("A petal shower! The forest applauds, quietly, with flowers.")
    if ending_pending and mode == Mode.PLAYING:
        ending_countdown -= delta
        if ending_countdown <= 0.0:
            ending_pending = false
            _show_ending()
    _ui_refresh -= delta
    if _ui_refresh <= 0.0:
        _ui_refresh = 0.10
        _refresh_ui()
        # The hint pill and the touch action button ride the same slow tick
        # as the HUD: proximity answers change at walking speed, so a tenth
        # of a second of latency is invisible and the check costs nothing.
        _update_context_hint()

func _physics_process(delta: float) -> void:
    if mode != Mode.PLAYING and mode != Mode.MENU:
        return
    if player == null or ending_pending:
        return
    if mode == Mode.MENU:
        # The title backdrop's wisps still need their idle tick: nothing else
        # ever calls tick_behavior on the menu floor, and they were painting
        # frozen, half-popped ghosts behind the title card. No contact, no
        # combat, no chimes -- the forest just idles.
        var menu_aggro := 14.0
        var menu_kindness := float(settings.get("wisp_speed", 0.85)) / 0.85
        for wisp: Wisp in wisps:
            if not is_instance_valid(wisp) or not wisp.alive:
                continue
            wisp.tick_behavior(delta, player.global_position, menu_aggro, 1.0, menu_kindness)
        return
    pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
    note_cooldown = maxf(0.0, note_cooldown - delta)
    _refresh_wisp_shields()
    var aggro := 14.0 * float(floor_modifier.get("aggro", 1.0))
    var speed_modifier := float(floor_modifier.get("speed", 1.0))
    var kindness_speed := float(settings.get("wisp_speed", 0.85)) / 0.85
    for wisp: Wisp in wisps:
        if not is_instance_valid(wisp) or not wisp.alive:
            continue
        wisp.tick_behavior(delta, player.global_position, aggro, speed_modifier, kindness_speed)
        _update_wisp_contact(wisp, delta)
        # A contact bump can empty the last warmth, which ends the walk here.
        # Nothing queued below belongs to a run that is already over: automatic
        # combat, chime pickups and the song ceremonies used to keep running in
        # this same frame, so on a dragon floor the final Dream Chime still
        # gathered and painted "The Lullaby" on top of the nap screen.
        if mode != Mode.PLAYING:
            return
    _separate_wisps()
    _auto_combat(delta)
    _check_chime_pickups(delta)
    _tick_lullaby(delta)
    _prune_notes()

func _touch_dash() -> void:
    if mode != Mode.PLAYING or player == null or not is_instance_valid(player):
        return
    # A still double-tap hops the way the hero already faces; a moving tap
    # keeps riding the stick. The facing lives in the player beside the
    # members that steer it.
    player.trigger_dash(player.dash_direction())

func _touch_pause() -> void:
    # The very state machine the Escape key runs -- one home, in
    # _advance_pause_state(), so the touch button and the key cannot drift.
    _advance_pause_state()

func _notification(what: int) -> void:
    # The root Window propagates close requests to every node; the engine
    # only auto-quits when application/config/auto_accept_quit is true.
    # project.godot disables that so every close request hushes the audio
    # and drains the audio server first.
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        quit_gracefully()

func quit_gracefully() -> void:
    ## Hush the lantern, then quit only after the audio server had a chance
    ## to release its stopped playbacks. Quitting while voices are live
    ## leaks AudioStreamPlayback refs at exit. Idempotent: repeated leave
    ## clicks or close requests collapse into the single pending quit.
    if _quitting:
        return
    _quitting = true
    if audio:
        audio.shutdown()
    if music:
        music.shutdown()
    var tree := get_tree()
    if tree == null:
        return
    await tree.create_timer(QUIT_DRAIN_SECONDS).timeout
    tree.quit()
