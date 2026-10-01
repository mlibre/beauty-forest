class_name GameUI
extends GameUIScreens

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
    _walker_charms = ", ".join(names)

func set_map(dungeon: Dictionary, player_position: Vector3) -> void:
    # Deliberately does not force `_minimap.visible`: every floor load calls
    # this, and forcing the flag true here re-showed a map that the responsive
    # layout had just yielded (hidden) because the on-screen touch buttons own
    # the corner it would land in. GameUILayout owns the map's visibility.
    _minimap.set_map(dungeon, player_position)

func update_map_player(player_position: Vector3, markers: Array[Dictionary]) -> void:
    _minimap.player_position = player_position
    _minimap.set_markers(markers)

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

func show_story(title: String, body: String, duration: float = 3.8) -> void:
    _cancel_story()
    var generation := _story_generation
    _story_title.text = title
    _story_body.text = body
    _story_card.visible = true
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
