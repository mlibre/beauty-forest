extends "res://scripts/run_world.gd"

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
    _apply_settings(settings, false)

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
    ui.touch_shop_requested.connect(_touch_shop)
    ui.touch_journal_requested.connect(_open_journal)
    ui.touch_settings_requested.connect(_open_settings)
    ui.touch_pause_requested.connect(_touch_pause)
    ui.settings_changed.connect(func(value): _apply_settings(value, true))

func _advance_pause_state() -> void:
    # The one state machine both the Escape key and the touch pause button run,
    # so the two can never disagree about what PAUSE means: pause from the walk,
    # close any modal, resume from the card.
    if mode == Mode.PLAYING:
        _pause_game()
    elif mode in [Mode.SHOP, Mode.JOURNAL, Mode.SETTINGS]:
        _close_modal()
    elif mode == Mode.PAUSED:
        _resume_game()

func _unhandled_input(event: InputEvent) -> void:
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
            ui.show_toast("Peddle parks on floors 2 · 4 · 7 · 10 of every thirteen-floor stretch.", 3.4)
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
    if mode == Mode.PLAYING:
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

func _start_run(start_floor: int, keep_progress: bool = false) -> void:
    ## keep_progress = false (default) starts a FRESH walk and clears run state.
    ## keep_progress = true continues the current walk one floor deeper — the
    ## path the ending screen's "Wander deeper" button takes: sparkles, level,
    ## soul and the whole cozy loadout earned on the journey must survive it.
    ## Conflating the two used to wipe every reward the moment the player
    ## chose to keep wandering (tier-2 progression loss).
    selected_style = selected_style if BeautyContent.STYLE_DATA.has(selected_style) else "standard"
    mode = Mode.PLAYING
    ui.close_panels()
    ui.clear_toast()
    ui.set_hud_visible(true)
    # Play chrome OFF: no stat cards, no Mote chatter, no control hints. Just
    # the lantern ring, the sparkles, the depth and the grove map.
    ui.set_text_chrome_visible(false)
    if not keep_progress:
        attack = 10.0
        level = 1
        xp = 0
        xp_next = 10
        sparkles = 0
        charms_owned.clear()
        charms_equipped.clear()
        stanzas_equipped = {"petals": true, "echoes": true}
        mote_verse_key = ""
        pending_boons = 0
        _draft_offers = []
        boon_effects = {}
        fresh_facts.clear()
        _lantern_taught = false
        play_seconds = 0.0
        hp_max = 100.0 + (15.0 if selected_style == "gentle" else 0.0)
        level_hp_bonus = 0.0
        hp = hp_max
    if not keep_progress:
        meta["runs"] = int(meta.get("runs", 0)) + 1
    BeautyData.save_meta(meta)
    # Recomputes hp_max from style + worn charms and refills warmth, so a
    # continued walk starts rested but keeps everything that was earned.
    _recalculate_loadout(true)
    # A fresh walk is aimed at the Roost; a continued walk left the Roost
    # behind floors ago, so Mote announces the descent, not a dragon count
    # that no longer describes the walk.
    if keep_progress:
        _mote_line = String(BeautyContent.random_choice(BeautyLore.DESCEND_LINES))
    else:
        _mote_line = "Here we go! Thirteen floors of forest between us and one very sleepy dragon family."
    _mote_line_timer = 28.0
    _load_floor(maxi(1, start_floor), false)
    ui.add_log("Mote: “%s”" % _mote_line)
    if not keep_progress and int(meta.get("runs", 0)) > 1:
        # A returning visit, never a nudge: no counts, no pressure, just the
        # forest remembering you fondly.
        ui.show_toast("Welcome back ♥ The forest kept your spot warm.")

func _touch_dash() -> void:
    if mode != Mode.PLAYING or player == null or not is_instance_valid(player):
        return
    var direction := player.move_direction
    if direction.length_squared() < 0.01:
        direction = Vector3(-0.70710678, 0.0, -0.70710678)
    player.trigger_dash(direction)

func _touch_pause() -> void:
    # The very state machine the Escape key runs -- one home, in
    # _advance_pause_state(), so the touch button and the key cannot drift.
    _advance_pause_state()

func _touch_shop() -> void:
    if mode == Mode.PLAYING and _near_merchant():
        _open_shop()
    elif mode == Mode.PLAYING:
        ui.show_toast("Peddle parks on floors 2 · 4 · 7 · 10 of every thirteen-floor stretch.", 3.4)

func _pause_game() -> void:
    if mode != Mode.PLAYING:
        return
    mode = Mode.PAUSED
    _set_world_processing(false)
    player.set_control_enabled(false)
    ui.show_pause(meta)

## The title was a one-visit room: pause offered resume, a fresh walk or the
## exit, and nothing anywhere returned to the front door -- the style trails,
## the record line and the menu's own calm were unreachable until the app
## restarted. The walk folds back into the menu stage the boot built, and the
## next start begins a fresh walk from there.
func _back_to_title() -> void:
    ui.close_panels()
    _load_floor(1, true)
    _show_menu()

func _resume_game() -> void:
    if mode != Mode.PAUSED:
        return
    ui.close_panels()
    # show_pause() turned the text chrome on for the summary, which hides the
    # vitals strip because the two are mutually exclusive. Nothing turned it back
    # off, so one pause left the walk with no lantern ring, no sparkle count and no
    # depth -- its whole readout -- and with Mote's prose painted on top. The walk
    # screen is pictures only; give them back here, where the walk resumes.
    ui.set_text_chrome_visible(false)
    mode = Mode.PLAYING
    _set_world_processing(true)
    player.set_control_enabled(_gameplay_controls_enabled())
    if not ending_pending:
        music.play_region(String(region.get("ambient", region["key"])))

func _on_style_picked(style_key: String) -> void:
    # A trail picked on the menu must be the trail that starts, whichever way
    # the player presses. Enter used to start `selected_style` untouched by the
    # click, and skipped persisting the pick.
    if not BeautyContent.STYLE_DATA.has(style_key):
        return
    selected_style = style_key
    meta["style"] = style_key
    BeautyData.save_meta(meta)

func _on_start_requested(style_key: String) -> void:
    selected_style = style_key
    meta["style"] = style_key
    _start_run(1)

func _on_restart_requested(continue_deeper: bool = false) -> void:
    var next_floor := floor_number + 1 if continue_deeper else 1
    # "Wander deeper" keeps the walk (and its loadout) going; "a fresh walk"
    # starts over on purpose.
    _start_run(next_floor, continue_deeper)

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

func _open_shop() -> void:
    if mode != Mode.PLAYING or not merchant_exists or not _near_merchant():
        return
    mode = Mode.SHOP
    _set_world_processing(false)
    player.set_control_enabled(false)
    ui.show_shop(_shop_state())

func _on_shop_closed() -> void:
    if mode == Mode.SHOP:
        mode = Mode.PLAYING
        _set_world_processing(true)
        player.set_control_enabled(_gameplay_controls_enabled())

func _open_journal() -> void:
    if mode != Mode.PLAYING:
        return
    previous_mode = mode
    mode = Mode.JOURNAL
    _set_world_processing(false)
    player.set_control_enabled(false)
    ui.show_journal(meta, meta.get("facts_learned", []), meta.get("stickers", []))

func _on_journal_closed() -> void:
    if mode == Mode.JOURNAL:
        mode = Mode.PLAYING
        _set_world_processing(true)
        player.set_control_enabled(_gameplay_controls_enabled())

func _open_settings() -> void:
    # The COZY button stays lit while Peddle's cart or the memory book is open,
    # so pressing it has to work. Close the modal underneath, remember it, and
    # hand the player back to it on close rather than swallowing the press.
    var return_to := mode
    if mode in [Mode.SHOP, Mode.JOURNAL, Mode.DRAFT]:
        ui.close_panels()
        return_to = Mode.PLAYING
    previous_mode = return_to
    mode = Mode.SETTINGS
    _set_world_processing(false)
    player.set_control_enabled(false)
    # The panel's own Back button names where it returns, so pass the screen the
    # director will actually restore. SHOP and JOURNAL already collapse to
    # PLAYING above, so both genuinely land on the walk.
    var return_name := "the menu"
    if return_to == Mode.PLAYING:
        return_name = "the walk"
    elif return_to == Mode.PAUSED:
        return_name = "the pause card"
    elif return_to == Mode.DEAD:
        return_name = "the nap card"
    elif return_to == Mode.ENDING:
        return_name = "the ending card"
    ui.show_settings(settings, return_name)

func _on_settings_closed() -> void:
    if mode != Mode.SETTINGS:
        return
    if previous_mode == Mode.PAUSED:
        mode = Mode.PAUSED
        ui.show_pause(meta)
    elif previous_mode == Mode.MENU:
        # Came here straight from the menu's "Cozy options" button: hand the menu
        # back rather than closing every panel, which would leave the player
        # staring at an empty screen instead of the one they opened from.
        _show_menu()
    elif previous_mode == Mode.DEAD or previous_mode == Mode.ENDING:
        # The nap and ending cards live ON the overlay, and the fallback's
        # close_panels() hides exactly that card. The COZY button sits above
        # the overlay scrim, so on a touchscreen it answers from both -- and
        # closing settings there used to leave an empty frozen world nothing
        # could bring the card back to. Re-raise the card the panel came from.
        mode = previous_mode
        if previous_mode == Mode.DEAD:
            ui.show_death(floor_number, meta)
        else:
            ui.show_ending(int(meta.get("dragons_sung", 0)), meta)
    else:
        mode = previous_mode
        _set_world_processing(mode in [Mode.MENU, Mode.PLAYING])
        if mode == Mode.PLAYING:
            player.set_control_enabled(_gameplay_controls_enabled())
        else:
            ui.close_panels()

func _close_modal() -> void:
    match mode:
        Mode.SHOP:
            ui.close_shop()
        Mode.JOURNAL:
            ui.close_journal()
        Mode.SETTINGS:
            ui.close_settings()
        _:
            ui.close_panels()

## Put the title menu back up, from wherever the game is.
##
## Boot and the settings panel's way home both need this, so it lives here
## rather than at each call site: the world keeps breathing behind the menu,
## the hero loses the controls, and the menu is rebuilt from current `meta` so
## the record line reads true even after a run.
func _show_menu() -> void:
    mode = Mode.MENU
    _set_world_processing(true)
    player.set_control_enabled(false)
    ui.show_menu(meta)

func _show_ending() -> void:
    mode = Mode.ENDING
    _set_world_processing(false)
    player.set_control_enabled(false)
    audio.play_win()
    ui.show_ending(int(meta.get("dragons_sung", 0)), meta)
