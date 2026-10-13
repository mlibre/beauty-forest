class_name RunFlow
extends "res://scripts/run_world.gd"

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.

## What a walk IS, as opposed to how it is driven: the story the Play button
## tells (and the camera that glides with it), the one pause state machine
## the Escape key and the touch button share, how a run starts and deepens,
## and every way the screens hand the player to each other -- cart, memory
## book, comfort options, title, nap, ending. The storytelling and the
## transitions reference each other in both directions (finishing the story
## starts a walk; leaving the menu ends one), so they are one layer. The
## director above it only boots, reads input, ticks frames and quits.

## The story the Play button tells before the first floor loads: five pages
## over the menu forest while the camera glides down from the canopy. Each
## page carries its own tint — the glow behind the picture, the picture itself
## and the page dot all wear it, so the story reads as five small scenes (the
## dragon's rumor, the lantern's song, the lost souls, the promise, the
## descent) rather than one flat card. Any key or tap turns a page; Esc or
## Skip goes straight to the walk.
const INTRO_PAGES: Array = [
    {"glyph": "dragon", "title": "The rumor", "tint": Color("#ffd9a8"),
        "body": "Far beneath the moss, a whole dragon family has forgotten how to sleep. Their dreams went missing first."},
    {"glyph": "lantern", "title": "The lantern", "tint": Color("#ffe9a0"),
        "body": "Your lantern hums a song all by itself — an old tune every lost soul still remembers."},
    {"glyph": "wisp", "title": "The lost ones", "tint": Color("#bfe8ff"),
        "body": "Sad little wisps drift through the roots, dim and lonely, waiting for someone kind to wander by."},
    {"glyph": "heart", "title": "The promise", "tint": Color("#ffd9e0"),
        "body": "Sit with them. Hum until they glow. No hurry, no losing — kindness is the whole game."},
    {"glyph": "stairs", "title": "The descent", "tint": Color("#bdf0bd"),
        "body": "Thirty floors below, a whole family of dragons waits for the softest lullaby ever hummed. Ready? Let's wander."},
]
const INTRO_PAGE_SECONDS := 4.6
const INTRO_GLIDE_SECONDS := 3.0
## The camera starts high in the canopy and settles to its walk offset.
const CAMERA_INTRO_OFFSET := Vector3(0.0, 26.0, 19.0)

var _intro_active := false
var _intro_page := -1
var _intro_timer := 0.0
var _intro_cam_t := 1.0

## The story intro glides the camera down from the canopy while its pages
## play, then holds rock-steady at the walk offset — the same "glides and
## settles" contract as the walk camera, just with a longer approach. The
## state and the override live together here on the director, because the
## base-class camera has no idea the intro exists.
func _update_camera(delta: float) -> void:
    if _intro_active and player != null and is_instance_valid(player):
        _intro_cam_t = minf(1.0, _intro_cam_t + delta / INTRO_GLIDE_SECONDS)
        var eased := _intro_cam_t * _intro_cam_t * (3.0 - 2.0 * _intro_cam_t)
        camera.global_position = player.global_position + CAMERA_INTRO_OFFSET.lerp(CAMERA_OFFSET, eased)
        camera.look_at(player.global_position + Vector3.UP * 0.78, Vector3.UP)
        return
    super(delta)

## The menu's Play button: tell the story first, then start the fresh walk.
## start_requested bypasses this on purpose — it IS the walk, wherever it
## comes from (tests, keys, a returning save); the story is a menu courtesy.
func _begin_intro() -> void:
    if mode != Mode.MENU or _intro_active:
        return
    _intro_active = true
    _intro_page = 0
    _intro_timer = INTRO_PAGE_SECONDS
    _intro_cam_t = 0.0
    ui.close_panels()
    # The interface learns how long the telling is before the first page: the
    # progress dots are grown from this, and the story owns its own length.
    ui.set_intro_page_count(INTRO_PAGES.size())
    ui.show_intro_page(INTRO_PAGES[0], 0)

func _advance_intro() -> void:
    if not _intro_active:
        return
    _intro_page += 1
    if _intro_page >= INTRO_PAGES.size():
        _finish_intro()
        return
    _intro_timer = INTRO_PAGE_SECONDS
    ui.show_intro_page(INTRO_PAGES[_intro_page], _intro_page)

func _finish_intro() -> void:
    if not _intro_active:
        return
    _intro_active = false
    _intro_page = -1
    _intro_cam_t = 1.0
    ui.hide_intro()
    _on_start_requested(selected_style)

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
        _mote_line = "Here we go! Thirty floors of forest between us and one very sleepy dragon family."
    _mote_line_timer = 28.0
    _load_floor(maxi(1, start_floor), false)
    ui.add_log("Mote: “%s”" % _mote_line)
    if not keep_progress and int(meta.get("runs", 0)) > 1:
        # A returning visit, never a nudge: no counts, no pressure, just the
        # forest remembering you fondly.
        ui.show_toast("Welcome back ♥ The forest kept your spot warm.")

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
        music.play_region(MusicScores.floor_song(String(region.get("ambient", region["key"])), floor_number))

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
    # starts over on purpose. Going deeper turns the book's page: one wash of
    # light crosses the screen while the next floor builds underneath it.
    if continue_deeper:
        ui.play_page_wipe()
    _start_run(next_floor, continue_deeper)

func _open_shop() -> void:
    if mode != Mode.PLAYING or not merchant_exists or not _near_merchant():
        return
    mode = Mode.SHOP
    _set_world_processing(false)
    player.set_control_enabled(false)
    ui.show_shop(_shop_state())

## E beside Peddle opens the cart now: this is the director's half of the
## hook RunState declares and RunWorld's _try_interact asks. The guards are
## _open_shop's own, and _near_merchant() has already vouched for proximity,
## so a true return always means the stall actually opened.
func _try_open_nearby_shop() -> bool:
    if mode != Mode.PLAYING or not _near_merchant():
        return false
    _open_shop()
    return mode == Mode.SHOP

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
    # so pressing it has to work. Whatever screen sits underneath goes down
    # first -- a panel opening owns the whole screen -- because the pause
    # card, the menu and the nap card each keep their own scrim lit, and
    # raising the settings panel over one stacked a second darkening rect on
    # top of it. The close handlers below re-raise every card this hides, so
    # the player is handed back to the screen they came from either way.
    var return_to := mode
    if mode in [Mode.SHOP, Mode.JOURNAL, Mode.DRAFT]:
        # The cart and the memory book have no close handler that re-raises
        # them (their card is emptied on the way out), so they land on the
        # walk, which is where both genuinely came from.
        return_to = Mode.PLAYING
    ui.close_panels()
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
    # A menu requested from anywhere (settings close, pause card, boot) ends a
    # running story telling; the menu owns the screen the moment it is asked
    # for, and a half-told intro must never survive underneath it.
    if _intro_active:
        _intro_active = false
        _intro_page = -1
        _intro_cam_t = 1.0
        ui.hide_intro()
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
