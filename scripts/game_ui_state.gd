class_name GameUIState
extends CanvasLayer

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyData := preload("res://scripts/beauty_data.gd")
const CozyMinimap := preload("res://scripts/cozy_minimap.gd")
const CozyTheme := preload("res://scripts/cozy_theme.gd")
const CozyVitals := preload("res://scripts/cozy_vitals.gd")
const GardenGlyphs := preload("res://scripts/garden_glyphs.gd")
const TouchJoystick := preload("res://scripts/touch_joystick.gd")

## Signals, widget state and settings: what the interface KNOWS. The widgets
## are built by GameUIFactories (one link up), assembled in GameUIChrome,
## positioned in GameUILayout, filled in GameUIScreens and driven by GameUI.

signal start_requested(style_key: String)
## The menu's own Play button. Deliberately separate from start_requested:
## a fresh walk pressed from the title opens the story intro first, while a
## direct start_requested (deep links, tests, the keys) starts immediately.
signal play_pressed
signal style_picked(style_key: String)
signal resume_requested
signal restart_requested(continue_deeper: bool)
signal boon_picked(boon_key: String)
signal quit_requested
signal menu_requested
signal shop_closed
signal journal_closed
signal settings_open_requested
signal settings_closed
signal buy_requested(charm_key: String)
## Which COPY to wear: a charm can be owned twice, so a press names both the ware
## and its tier. Without the tier the panel could not say which of the two
## identical icons the player meant.
signal charm_equip_requested(charm_key: String, tier: int)
signal stanza_equip_requested(stanza_key: String)
signal mote_verse_requested(verse_key: String)
signal touch_vector_changed(value: Vector2)
signal touch_dash_requested
signal touch_interact_requested
signal touch_journal_requested
signal touch_pause_requested
signal settings_changed(settings: Dictionary)
## The story intro's two doors: tap the page (or any key) to turn it, and the
## Skip plate to end the telling and start the walk at once.
signal intro_advance_requested
signal intro_skip_requested

var _root: Control
var _hud: Control
var _log_label: Label
var _toast_label: Label
var _minimap: CozyMinimap
## The icon readout. This is the play screen's whole status display: warmth as
## a ring, sparkles and depth as glyphs, the loadout as sockets.
var _vitals: CozyVitals
var _touch_root: Control
var _touch_joystick: TouchJoystick
## The on-screen touch buttons, kept in build order so the responsive layout
## can measure the block they actually occupy in the bottom-right corner.
var _touch_buttons: Array[Button] = []
## The one CONTEXTUAL action button. It is the touch E: its face re-labels
## itself to whatever the hero is standing beside (sing, descend, wish,
## cart), so a touch player never has to know which of five fixed buttons
## is the right one -- the right button is always the same button.
var _touch_action_button: Button
## The bottom-centre hint pill: the key and the verb the key is about to
## speak ("E · Descend"), shown only while the hero stands near something
## that listens. The walk screen stays pictures-only at rest; this appears
## exactly when a press would do something, and leaves with it.
var _context_hint: PanelContainer
var _context_label: Label
var _context_hint_verb := ""
var _overlay_scrim: ColorRect
## The title menu's own scrim. Lighter than the pause card's, because the
## menu is the first thing a player sees and the brief is a BRIGHT golden
## forest: measured, the shared 0.48 scrim pulled the backdrop from a mean
## luminance of 176 down to 82 -- the menu was the darkest screen in a game
## that is otherwise 173-186 everywhere. The pause card still darkens
## properly, because there the world genuinely should step back.
var _menu_scrim: ColorRect
## The three scrim alphas, measured rather than eyeballed.
##
## A sweep of each value against a real render, reading the world still
## visible AROUND the card (gameplay there measures 177):
##
##   menu  0.20 -> 112     pause 0.32 -> 100     cart 0.64 -> 63
##
## The menu is the first thing a player sees and carries the whole bright
## golden-dusk promise, so it barely dims at all. The pause card and the cart
## deliberately let the world recede, and are kept only as dark as the panel
## needs to stay legible -- tests/regression_luminance.gd holds the floor.
const MENU_SCRIM_ALPHA := 0.20
## Pause: 0.32, not the 0.48 this used to be. Measured on a real pause frame,
## counting only forest (the HUD cards are excluded -- they are UI, and sampling
## them reported a "murk zone" that was never there): 0.48 left the visible world
## at 56% of its own brightness, 0.32 at 69%. The card face is opaque, so a
## lighter scrim costs its text nothing. Darker did not read as evening; it just
## took the light out of the forest the card is supposed to sit in front of.
## tests/regression_scrims.gd holds both the floor and the ceiling.
const PAUSE_SCRIM_ALPHA := 0.32
const SHOP_SCRIM_ALPHA := 0.64
var _overlay_card: PanelContainer
var _overlay_content: VBoxContainer
var _shop_scrim: ColorRect
var _shop_card: PanelContainer
var _shop_frame: VBoxContainer
var _shop_scroll: ScrollContainer
var _shop_content: VBoxContainer
## The purse digits in the cart's heading, kept so a rebuild can pulse them --
## the one spot on the shelf the eye should land on after a purchase lands.
var _shop_purse_label: Label
var _story_card: PanelContainer
var _story_title: Label
var _story_body: Label
## The vignette's picture, shown when a story names one.
var _story_glyph: TextureRect
## The vignette's arrival choreography — settle-scale, lamp-sweep and
## ink-ripple in one tween, killed by _cancel_story so a fast vignette never
## fights a slow one.
var _story_arrival_tween: Tween
var _story_ripple: Panel
var _story_sweep: TextureRect
var _beat_ring: Panel
var _beat_inner: Panel
var _warm_flash: ColorRect
var _settings: Dictionary = {}
## The storybook intro, built once at boot and shown only while the director
## tells it. The menu card hides underneath; the forest stays visible.
var _intro_root: Control
var _intro_glyph: TextureRect
var _intro_title: Label
var _intro_body: Label
var _intro_hint: Label
## The page's tinted scene plate and the row of progress dots. The glow is
## re-tinted and the dots re-lit by show_intro_page as the director turns
## pages, so the storybook reads as a sequence of small illustrated scenes.
var _intro_glow: Panel
## One soft ring behind the page's picture, pressed like a stamp each turn.
var _intro_ripple: Panel
var _intro_dots: HBoxContainer
## How many pages the current telling has; the director sets this when the
## telling begins, because the story's length belongs to the story.
var _intro_page_count := 0
## The current page-turn's bloom. A fast reader can turn pages faster than a
## turn finishes, and two tweens writing the same picture each frame means
## the older one wins the last word -- the next page's picture never shrinks
## in at all. One home, killed on every turn.
var _intro_turn_tween: Tween
## The ink wash that draws the prose onto the page: a shader mask on the
## body labels (intro and in-run vignette). The text is laid out in full and
## the mask only decides which rows draw, so the reveal can never make a
## label's minimum size dance the way a typewriter did.
var _ink_tween: Tween
var _ink_label: Label
## The intro's living picture: five motes drifting slow loops inside the
## page's glow plate, behind the glyph. The book's own fireflies -- the one
## place the interface is allowed to breathe, because a storybook's picture
## is a window, not a button.
var _intro_fireflies: Array[Panel] = []
var _intro_firefly_tweens: Array[Tween] = []
## The cinema: two letterbox bars that frame the song ceremonies, so the
## walk's biggest moments stage themselves instead of arriving as prose.
var _cinematic_top: ColorRect
var _cinematic_bottom: ColorRect
var _cinematic_tween: Tween
var _cinematic_on := false
## The page-turn wipe: one soft wash of light when the walk descends past a
## stair, so floors change the way a book turns its page.
var _page_wipe: ColorRect
var _page_wipe_tween: Tween
## The interface's doorbell, wired once by the director at boot: a callable
## that speaks for button hovers and presses. The UI chain never reaches the
## audio director directly; when nothing is wired, the buttons stay silent.
var ui_sound: Callable = Callable()
var _selected_style := "standard"
var _toast_queue: Array[Dictionary] = []
var _toast_active := false
var _toast_tween: Tween
var _story_tween: Tween
var _story_generation := 0
var _reduced_motion := false
var _high_contrast := false
var _text_scale := 1.0
var _compact_hud := false
var _log_chrome_wanted := true
## The walker's numbers, parked by GameUI.update_hud so the pause menu can show
## the run's full state on demand without the director building a second copy
## of every label.
var _walker_hp := 100
var _walker_hp_max := 100
var _walker_level := 1
var _walker_xp := 0
var _walker_xp_next := 10
var _walker_song := 10
var _walker_floor := 1
var _walker_region := "Sunlit Roots"
var _walker_charms := ""
## The worn charms' data keys, kept separate from the joined names so the pause
## card can draw the loadout as icons and still speak a charm's name in a hover.
var _walker_charm_keys: Array[String] = []
var _walker_sparkles := 0
var _walker_forecast := ""
## What the glowing waypoint is actually pointing at, in words. The corner card
## used to read "Wander toward the glowing stair" on every floor, including
## dragon floors where the stairwell is hidden and the marker is over Snoozle --
## so the one screen a player pauses on pointed them at nothing.
var _walker_objective := ""
var _time := 0.0

## The glyphs of the charms being worn, for the pause card's loadout row.
##
## Charms are their own key space, so an unprefixed key is correct here -- but a
## verse shares several charm keys, and drawing a verse's note in the charm row
## would put a song where a charm belongs. So the keys are checked against the
## charm table, and Mote's mark stands in for anything unresolved.
##
## Lives on the base class because GameUIScreens paints the loadout and GameUI
## only parks the keys -- a base class cannot call a method its subclass defines.
func _walker_charm_glyphs() -> Array[String]:
    var glyphs: Array[String] = []
    for key: String in _walker_charm_keys:
        glyphs.append(key if GardenGlyphs.has_glyph(key) else GardenGlyphs.MOTE)
    return glyphs

func _process(delta: float) -> void:
    if _root == null or _overlay_card == null:
        return
    _time += delta
    if _beat_ring.visible:
        _beat_ring.pivot_offset = _beat_ring.size * 0.5
    if _minimap.is_visible_in_tree():
        _minimap.queue_redraw()

## Show or hide the parts of the HUD that SPEAK.
##
## The walk screen carries pictures only -- the lantern ring, the sparkles, the
## depth, the grove map. Mote's running chatter and the control hints are words,
## so they appear only on a screen the player opened on purpose (the menu, the
## pause card) and stay out of the way otherwise.
##
## This lives on the base class, not on GameUI, because GameUIScreens calls it to
## restore the chrome when a menu opens.
func set_text_chrome_visible(visible_now: bool) -> void:
    _vitals.visible = not visible_now
    _log_label.visible = visible_now
    # The touch relayout pass re-decides the log slot every resize; without
    # the player's last explicit choice parked, it reads "compact or not" as
    # "paint it", and the hidden log creeps back onto the play screen.
    _log_chrome_wanted = visible_now

func set_hud_visible(value: bool) -> void:
    if _hud:
        _hud.visible = value

func set_selected_style(key: String) -> void:
    ## Seeds the menu's trail pick, so a returning visit finds its last trail
    ## already picked. Unknown keys fall back to the standard trail.
    _selected_style = key if BeautyContent.STYLE_DATA.has(key) else "standard"

func _cancel_story() -> void:
    _story_generation += 1
    if _story_tween != null and _story_tween.is_valid():
        _story_tween.kill()
    _story_tween = null
    if _story_arrival_tween != null and _story_arrival_tween.is_valid():
        _story_arrival_tween.kill()
    _story_arrival_tween = null
    if _ink_tween != null and _ink_tween.is_valid():
        _ink_tween.kill()
    _ink_tween = null
    _ink_label = null
    # A replaced vignette must not leave a half-poured wash on the labels:
    # both bodies return to fully drawn, whatever the cancel interrupted.
    for washed_label in [_story_body, _intro_body]:
        if washed_label != null and is_instance_valid(washed_label) and washed_label.material is ShaderMaterial:
            (washed_label.material as ShaderMaterial).set_shader_parameter("reveal", 1.0)
    if _story_card != null and is_instance_valid(_story_card):
        # A cancelled arrival leaves no half-settled transform behind: scale
        # always returns to ONE, so the next show starts from rest.
        _story_card.scale = Vector2.ONE
    if _story_card != null:
        _story_card.visible = false

func _reset_touch_joystick() -> void:
    if _touch_joystick != null and is_instance_valid(_touch_joystick):
        _touch_joystick.reset()

func apply_settings(settings: Dictionary) -> void:
    _settings = settings.duplicate(true)
    _reduced_motion = bool(_settings.get("reduced_motion", false))
    _high_contrast = bool(_settings.get("high_contrast", false))
    _text_scale = clampf(float(_settings.get("text_scale", 1.0)), 0.75, 2.0)
    _root.theme.default_font_size = int(round(18.0 * _text_scale))
    for node in get_tree().get_nodes_in_group("game_ui_scaled_labels"):
        var label := node as Label
        if label == null or not is_instance_valid(label):
            continue
        var base_size := float(label.get_meta("base_font_size", label.get_theme_font_size("font_size")))
        label.add_theme_font_size_override("font_size", int(round(base_size * _text_scale)))
    _minimap.high_contrast = _high_contrast
    _minimap.queue_redraw()
    if is_instance_valid(_vitals):
        # The ring, sparkle count and charm sockets are the most-stared-at
        # widget on the HUD: they still keep crackling and breathing unless
        # both toggles reach them.
        _vitals.high_contrast = _high_contrast
        _vitals.set_reduced_motion(bool(_settings.get("reduced_motion", false)))
        _vitals.queue_redraw()
    _overlay_scrim.color = Color(0.025, 0.05, 0.035, 0.72 if _high_contrast else PAUSE_SCRIM_ALPHA)
    if is_instance_valid(_menu_scrim):
        _menu_scrim.color = Color(0.025, 0.05, 0.035, 0.42 if _high_contrast else MENU_SCRIM_ALPHA)
    _shop_scrim.color = Color(0.015, 0.025, 0.018, 0.82 if _high_contrast else SHOP_SCRIM_ALPHA)
    # High Contrast has to reach the text, not just the scenery behind it. The
    # scrim above only darkens the world; the cards carry their own near-opaque
    # fill, so darkening the scrim left every label at the same 13.6:1 in both
    # modes -- a setting named for contrast that changed none of it. Deepen the
    # card fill and firm up the border so the ratio actually moves.
    for card in _contrast_cards():
        var style := card.get_theme_stylebox("panel") as StyleBoxFlat
        if style == null:
            continue
        if not card.has_meta("base_fill"):
            card.set_meta("base_fill", style.bg_color)
            card.set_meta("base_border", style.border_color)
            card.set_meta("base_border_width", style.border_width_top)
        var base: Color = card.get_meta("base_fill")
        var border: Color = card.get_meta("base_border")
        if _high_contrast:
            style.bg_color = Color(base.r * 0.42, base.g * 0.42, base.b * 0.42, minf(1.0, base.a + 0.02))
            style.border_color = Color("#ffe19a")
            style.set_border_width_all(3)
        else:
            style.bg_color = base
            style.border_color = border
            style.set_border_width_all(int(card.get_meta("base_border_width")))

func _contrast_cards() -> Array[PanelContainer]:
    var cards: Array[PanelContainer] = []
    for card: Control in [_shop_card, _story_card, _overlay_card]:
        if card != null and is_instance_valid(card):
            cards.append(card as PanelContainer)
    return cards

func _emit_settings() -> void:
    ## Persist the panel's answer and hand it to the director ONCE. The
    ## director applies it to the interface and the world; this used to apply
    ## here too, so every change paid the whole interface refresh twice.
    BeautyData.save_settings(_settings)
    settings_changed.emit(_settings.duplicate(true))
