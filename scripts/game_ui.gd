class_name GameUI
extends "res://scripts/game_ui_screens.gd"
## Beauty Forest's code-built interface. Owns the public surface the game
## director drives: HUD values, map, toasts, log lines, story cards, the lullaby
## beat ring and settings application. The base class chain assembles the
## interface, positions it responsively and fills the modal screens.

func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    _settings = BeautyData.default_settings()
    _build_interface()
    get_viewport().size_changed.connect(_fit_layout)
    show_menu({"runs": 0, "best_floor": 0, "wisps_soothed": 0})
    call_deferred("_fit_layout")

func update_hud(state: Dictionary) -> void:
    # The icon readout is the whole status display now. Warmth is the lantern
    # ring, sparkles and depth are glyphs carrying the one number each
    # genuinely needs, and the loadout is a row of sockets -- so none of the
    # old stat-card text ("Warmth 100 / 100", "0 / 10 kindness to next gift",
    # "Charms 0/3: none yet") is painted during play. Those facts live in the
    # pause menu now, which is the one screen a player opens on purpose.
    _vitals.set_values({
        "hp": float(state.get("hp", 100)),
        "hp_max": maxf(1.0, float(state.get("hp_max", 100))),
        "sparkles": int(state.get("sparkles", 0)),
        "floor": int(state.get("floor", 1)),
        "charm_keys": state.get("charm_keys", []),
        # How many wares the hero COULD wear here. The strip draws one empty
        # socket per one, so room a deeper walk opens is visible while playing.
        # This dict is rebuilt here rather than passed through, so a key left out
        # is a field the strip silently loses -- which is what happened to this
        # one: the strip fell back to "one socket per worn ware" and a full
        # loadout looked identical at floor 1 and floor 13.
        "capacity": int(state.get("capacity", 1)),
    })
    # Park the rest of the run's state for the pause menu, which is where the
    # player goes when they DO want the numbers spelled out.
    _walker_hp = roundi(float(state.get("hp", 100)))
    _walker_hp_max = roundi(maxf(1.0, float(state.get("hp_max", 100))))
    _walker_level = int(state.get("level", 1))
    _walker_xp = int(state.get("xp", 0))
    _walker_xp_next = maxi(1, int(state.get("xp_next", 10)))
    _walker_song = roundi(float(state.get("attack", 10)))
    _walker_floor = int(state.get("floor", 1))
    _walker_region = String(state.get("region_name", "Sunlit Roots"))
    _walker_forecast = String(state.get("forecast", ""))
    var names: Array = state.get("charm_names", [])
    # The pause card shows the loadout as the same icons the play screen wears,
    # so the KEYS are what it needs. Names are still parked, because the pause
    # card's hover copy names a charm in words.
    _walker_charms = ", ".join(names)
    # charm_keys carries the worn stanzas too -- they share one key namespace so
    # the vitals sockets can draw both -- so the charm row has to pick its keys
    # against the charm table rather than trust the list.
    _walker_charm_keys = _charm_keys_only(state.get("charm_keys", []))
    _walker_sparkles = int(state.get("sparkles", 0))

## The subset of `keys` that names a CHARM.
##
## Charms, verses and counter-melodies share one key namespace -- `moss` and
## `lullaby` each appear in two tables -- so the loadout row resolves every key
## against the charm table and drops the songs. Without this, a worn verse would
## be painted in the charm row and the player would read it as a charm.
func _charm_keys_only(keys: Array) -> Array[String]:
    var out: Array[String] = []
    for key: String in keys:
        for charm: Dictionary in BeautyContent.CHARMS:
            if String(charm["key"]) == key:
                out.append(key)
                break
    return out

func set_map(dungeon: Dictionary, player_position: Vector3) -> void:
    # Deliberately does not force `_minimap.visible`: every floor load calls
    # this, and forcing the flag true here re-showed a map that the responsive
    # layout had just yielded (hidden) because the on-screen touch buttons own
    # the corner it would land in. GameUILayout owns the map's visibility.
    _minimap.set_map(dungeon, player_position)

func update_map_player(player_position: Vector3, markers: Array[Dictionary]) -> void:
    _minimap.player_position = player_position
    _minimap.set_markers(markers)

func clear_toast() -> void:
    # A toast queued before a restart is a cue about a run that no longer
    # exists; let the fresh one speak alone.
    _toast_queue.clear()
    if _toast_tween != null and _toast_tween.is_valid():
        _toast_tween.kill()
    _toast_tween = null
    _toast_active = false
    if is_instance_valid(_toast_label):
        _toast_label.modulate.a = 0.0
        _toast_label.text = ""

func show_toast(message: String, duration: float = 2.6) -> void:
    _toast_queue.append({"message": message, "duration": maxf(0.0, duration)})
    if not _toast_active:
        _show_next_toast()

func _show_next_toast() -> void:
    if _toast_queue.is_empty():
        _toast_active = false
        _toast_tween = null
        return
    _toast_active = true
    var entry: Dictionary = _toast_queue.pop_front()
    _toast_label.text = String(entry.get("message", ""))
    var duration := maxf(0.0, float(entry.get("duration", 2.6)))
    _toast_label.modulate.a = 0.0
    _toast_label.scale = Vector2(0.96, 0.96)
    _toast_label.pivot_offset = _toast_label.size * 0.5
    if _toast_tween != null and _toast_tween.is_valid():
        _toast_tween.kill()
    _toast_tween = create_tween()
    _toast_tween.set_parallel(true)
    _toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.14)
    _toast_tween.tween_property(_toast_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _toast_tween.chain().tween_interval(duration)
    _toast_tween.chain().tween_property(_toast_label, "modulate:a", 0.0, 0.35)
    _toast_tween.chain().tween_callback(_show_next_toast)

func add_log(message: String) -> void:
    var lines: Array[String] = []
    if not _log_label.text.is_empty():
        lines.append_array(_log_label.text.split("\n"))
    lines.append(message)
    while lines.size() > 4:
        lines.pop_front()
    _log_label.text = "\n".join(lines)

## Mote saying something the player has to ACT on, during a walk.
##
## `add_log` is Mote's running chatter, and the walk screen deliberately shows
## no sentences, so the log is hidden for the whole of a run. That is right for
## "A Big Feeling. Not a monster -- just one feeling wearing a very big coat",
## which is personality and costs nothing to miss. It was not right for the lines
## that explain a miss: "Almost! Wait for the GOLD halo." fired the instant a
## song-note struck a wisp whose halo had not gone gold yet, into a label nobody
## sees until they pause. So the game's single most useful piece of timing
## advice was invisible during the entire fight it was advising, and a player
## missing the beat had nothing on screen telling them why.
##
## This is the one voice that speaks during a walk, so a cue goes here instead.
## Cues are kept to a few words -- they have to be readable at a glance while
## moving, which is the whole point -- and the picture carries the rest: the gold
## halo Mote is pointing at is already drawn on the wisp itself.
func add_cue(message: String, duration: float = 2.2) -> void:
    show_toast(message, duration)

## The bottom-centre hint pill, driven by the director's own proximity sense:
## pass the verb the next press will speak ("Descend", "Peddle's cart"), or
## "" to put the pill away. The walk screen is pictures-only at rest; this is
## the one moment prose is allowed on it, and it leaves with the moment.
func show_context_hint(verb: String) -> void:
    if _context_hint == null or not is_instance_valid(_context_hint):
        return
    var wanted := verb.strip_edges()
    if wanted.is_empty():
        if _context_hint.visible:
            _context_hint.visible = false
            _context_hint_verb = ""
        return
    if _context_hint.visible and _context_hint_verb == wanted:
        return
    _context_hint_verb = wanted
    _context_label.text = "E · %s" % wanted
    _context_hint.visible = true
    _fit_layout()

## The touch action button's face follows the same context: the button IS the
## E key on a touchscreen, so it re-labels itself to whatever the hero stands
## beside — and when the hero stands beside nothing, it disappears. A
## permanent SING plate over the walk was one more icon to parse; a button
## that only exists when something is near teaches itself.
func set_action_label(verb: String) -> void:
    if _touch_action_button == null or not is_instance_valid(_touch_action_button):
        return
    var wanted := verb.strip_edges()
    if wanted.is_empty():
        _touch_action_button.visible = false
        return
    var label := "%s ♥" % wanted.to_upper()
    _touch_action_button.visible = true
    if _touch_action_button.text == label:
        return
    _touch_action_button.text = label

func show_story(title: String, body: String, duration: float = 3.8, glyph: String = "") -> void:
    _cancel_story()
    var generation := _story_generation
    _story_title.text = title
    _story_body.text = body
    # The vignette's picture, when the story carries one: the region's mark
    # rides above the words, the way the intro's pages are illustrated.
    if _story_glyph != null and is_instance_valid(_story_glyph):
        var has_glyph := not glyph.is_empty()
        _story_glyph.visible = has_glyph
        if has_glyph:
            _story_glyph.texture = GardenGlyphs.get_glyph(glyph)
    _story_card.visible = true
    # The picture changes the card's height, and re-fitting here is a trap
    # the gate already sprung once: a fit that runs before the container's
    # own layout pass measures the words at a stale (or never-laid-out)
    # width and grows the card to 1911px on a 720p window. The next layout
    # pass (resize, panel open, window settle) absorbs the glyph's ~44px;
    # a card briefly 44px proud on a very short window beats one that
    # balloons past the whole screen.
    _story_card.modulate.a = 0.0
    _story_tween = create_tween()
    _story_tween.tween_property(_story_card, "modulate:a", 1.0, 0.35)
    _story_tween.tween_interval(maxf(0.0, duration))
    _story_tween.tween_property(_story_card, "modulate:a", 0.0, 0.55)
    _story_tween.tween_callback(func():
        if generation != _story_generation or not is_instance_valid(_story_card):
            return
        _story_card.visible = false
        _story_tween = null
    )
    _begin_story_arrival(duration)

## The vignette's arrival, staged like a book plate: the card settles the last
## few pixels into place and breathes a 1.5% scale into rest, a band of
## lamplight crosses it once, and the picture's mark rings like pressed ink
## while the title and body land on a short stagger. Every part is one-shot
## and settles -- nothing on the card loops, breathes or drifts, so the
## interface's stillness rules hold. Reduced motion keeps only the plain
## fade.
##
## Deliberately NO typewriter: animating visible_ratio on an autowrap label
## makes its minimum size dance while it types (zero visible glyphs report a
## zero-width longest word, and the card's height follows it up to 1945px --
## the battery caught exactly that). Scale, position and alpha never touch
## layout, so those are the only channels the arrival animates.
func _begin_story_arrival(duration: float) -> void:
    if _story_arrival_tween != null and _story_arrival_tween.is_valid():
        _story_arrival_tween.kill()
    _story_arrival_tween = null
    var ripple := _story_ripple
    var ripple_shown := ripple != null and is_instance_valid(ripple) and \
        _story_glyph != null and is_instance_valid(_story_glyph) and _story_glyph.visible
    if ripple != null and is_instance_valid(ripple):
        ripple.visible = ripple_shown
        if ripple_shown:
            ripple.modulate.a = 0.9
            ripple.scale = Vector2(0.55, 0.55)
    var sweep := _story_sweep
    if sweep != null and is_instance_valid(sweep):
        sweep.visible = false
    if _reduced_motion:
        if _story_card != null and is_instance_valid(_story_card):
            _story_card.scale = Vector2.ONE
            _story_card.pivot_offset = _story_card.size * 0.5
        if ripple != null and is_instance_valid(ripple):
            ripple.visible = false
        return
    var tween := create_tween()
    tween.set_parallel(true)
    # The rise: the card lies down flat the way a turned page does, settling
    # scale and height together from a breath under rest.
    var rest_y := _story_card.position.y
    _story_card.pivot_offset = _story_card.size * Vector2(0.5, 0.0)
    _story_card.scale = Vector2(0.985, 0.985)
    # The rise never pre-assigns the card's position: a container-housed
    # panel moved before its first sort shapes its autowrap body at width 1
    # and stays there (1911px, the battery caught it twice). The tween's
    # .from() starts the card 16px below REST on the tween's first step,
    # after the card's own layout has run -- same motion, zero pre-sort
    # writes.
    tween.tween_property(_story_card, "position:y", rest_y, 0.42).from(rest_y + 16.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(_story_card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if ripple_shown:
        tween.tween_property(ripple, "scale", Vector2.ONE, 0.50).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(ripple, "modulate:a", 0.0, 0.50).set_delay(0.08)
    # The lamp band crosses once, then the card is still.
    if sweep != null and is_instance_valid(sweep):
        sweep.size = Vector2(_story_card.size.x * 0.42, maxf(0.0, _story_card.size.y - 8.0))
        sweep.position = Vector2(_story_card.position.x - sweep.size.x, _story_card.position.y + 4.0)
        sweep.visible = true
        sweep.modulate.a = 0.0
        tween.tween_property(sweep, "modulate:a", 1.0, 0.12).set_delay(0.12)
        tween.tween_property(sweep, "position:x", _story_card.position.x + _story_card.size.x, 0.62).set_delay(0.12)
        tween.tween_property(sweep, "modulate:a", 0.0, 0.20).set_delay(0.54)
        tween.chain().tween_callback(func():
            if is_instance_valid(sweep):
                sweep.visible = false
        )
    _story_arrival_tween = tween

## The storybook intro, one page at a time. The director owns the pacing and
## the pages; the interface only draws what it is handed — and draws it as a
## little scene: the page's tint re-lights the glow plate and the picture,
## the progress dots mark where the telling is, and the words arrive on a
## short rise so a page turn feels like a page TURN. `close_panels`
## deliberately does NOT touch the intro — the intro lives above the menu
## card, and closing panels is a menu-world operation the director calls
## around it.
func set_intro_page_count(count: int) -> void:
    _intro_page_count = maxi(0, count)
    if _intro_dots == null or not is_instance_valid(_intro_dots):
        return
    while _intro_dots.get_child_count() < _intro_page_count:
        var dot := Panel.new()
        dot.custom_minimum_size = Vector2(9, 9)
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var dot_style := StyleBoxFlat.new()
        dot_style.bg_color = Color(1, 1, 1, 0.22)
        dot_style.set_corner_radius_all(5)
        dot.add_theme_stylebox_override("panel", dot_style)
        _intro_dots.add_child(dot)
    while _intro_dots.get_child_count() > _intro_page_count:
        var child := _intro_dots.get_child(_intro_dots.get_child_count() - 1)
        _intro_dots.remove_child(child)
        child.queue_free()

func show_intro_page(page: Dictionary, page_index: int = 0) -> void:
    if _intro_root == null or not is_instance_valid(_intro_root):
        return
    _menu_scrim.visible = false
    _overlay_card.visible = false
    _overlay_scrim.visible = false
    _hud.visible = false
    _intro_root.visible = true
    var tint := page.get("tint") as Color if page.get("tint") is Color else Color("#ffe9a0")
    _intro_glyph.texture = GardenGlyphs.get_glyph(String(page.get("glyph", GardenGlyphs.MOTE)))
    _intro_title.text = String(page.get("title", ""))
    _intro_body.text = String(page.get("body", ""))
    # The page's light: glow plate, picture and the lit dot all wear this
    # page's color, so each spread of the book reads as its own place.
    if _intro_glow != null and is_instance_valid(_intro_glow):
        var glow_style := _intro_glow.get_theme_stylebox("panel") as StyleBoxFlat
        if glow_style != null:
            glow_style.bg_color = Color(tint.r, tint.g, tint.b, 0.22)
        _intro_glow.queue_redraw()
    _intro_glyph.modulate = tint.lerp(Color.WHITE, 0.35)
    if _intro_dots != null and is_instance_valid(_intro_dots):
        for index in range(_intro_dots.get_child_count()):
            var dot := _intro_dots.get_child(index) as Panel
            if dot == null:
                continue
            var dot_style := dot.get_theme_stylebox("panel") as StyleBoxFlat
            if dot_style == null:
                continue
            var told := _intro_page_count > 0 and index <= page_index
            dot_style.bg_color = Color(tint.r, tint.g, tint.b, 0.95 if index == page_index else 0.40) if told else Color(1, 1, 1, 0.22)
            dot.custom_minimum_size = Vector2(13 if index == page_index else 9, 9)
            dot.queue_redraw()
        _intro_dots.reset_size()
    # The page arrives: the picture blooms, the words rise into place. A
    # page turn is one motion, not three popping parts -- and never two at
    # once, because a fast reader turns pages faster than a bloom finishes.
    if _intro_turn_tween != null and _intro_turn_tween.is_valid():
        _intro_turn_tween.kill()
    _intro_turn_tween = null
    if not _reduced_motion:
        _intro_glyph.pivot_offset = _intro_glyph.custom_minimum_size * 0.5
        _intro_glyph.scale = Vector2(0.82, 0.82)
        _intro_glyph.modulate.a = 0.0
        _intro_title.modulate.a = 0.0
        _intro_body.modulate.a = 0.0
        _intro_turn_tween = create_tween()
        var turn := _intro_turn_tween
        turn.set_parallel(true)
        # The ink-ripple rings once behind the picture, a stamp pressed into
        # the page as it turns.
        if _intro_ripple != null and is_instance_valid(_intro_ripple):
            _intro_ripple.visible = true
            _intro_ripple.modulate.a = 0.8
            _intro_ripple.scale = Vector2(0.62, 0.62)
            turn.tween_property(_intro_ripple, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            turn.tween_property(_intro_ripple, "modulate:a", 0.0, 0.55).set_delay(0.10)
        turn.tween_property(_intro_glyph, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        turn.tween_property(_intro_glyph, "modulate:a", 1.0, 0.24)
        turn.tween_property(_intro_title, "modulate:a", 1.0, 0.26).set_delay(0.08)
        turn.tween_property(_intro_body, "modulate:a", 1.0, 0.26).set_delay(0.16)
    _settle_in(_intro_root)

func hide_intro() -> void:
    if _intro_root != null and is_instance_valid(_intro_root):
        _intro_root.visible = false
        if _intro_ripple != null and is_instance_valid(_intro_ripple):
            _intro_ripple.visible = false

func set_beat(active: bool, gold: bool) -> void:
    _beat_ring.visible = active
    if not active:
        return
    var color := Color("#ffe064") if gold else Color("#9ab7a2")
    var style := StyleBoxFlat.new()
    style.bg_color = Color(color.r, color.g, color.b, 0.18 if gold else 0.05)
    style.border_color = color
    style.set_border_width_all(7 if gold else 4)
    style.set_corner_radius_all(69)
    _beat_ring.add_theme_stylebox_override("panel", style)
    if gold and not _reduced_motion:
        _beat_ring.scale = Vector2(1.20, 1.20)
        var tween := create_tween()
        tween.tween_property(_beat_ring, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func flash_warmth() -> void:
    _warm_flash.color.a = 0.0
    _warm_flash.color = Color(1.0, 0.72, 0.42, 0.0)
    var tween := create_tween()
    tween.tween_property(_warm_flash, "color:a", 0.20, 0.05)
    tween.tween_property(_warm_flash, "color:a", 0.0, 0.35)
