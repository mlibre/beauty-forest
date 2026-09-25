class_name GameUILayout
extends GameUIChrome

## Responsive placement for every HUD and modal control, plus the helpers that
## measure the real parent rect instead of trusting pre-tree anchor offsets.

func _fit_layout() -> void:
    # Responsive pass: shrink/move the two HUD cards, minimap, log, and both
    # modal cards so small/portrait windows show controls, not clipped panels.
    if _root == null or _overlay_card == null:
        return
    var viewport_size := _parent_size()
    var narrow := viewport_size.x < 900.0
    var small_height := viewport_size.y < 600.0
    var was_compact := _compact_hud
    var compact_lines := 1 if viewport_size.y < 280.0 else 2
    _compact_hud = viewport_size.y < 320.0 or (_text_scale > 1.25 and viewport_size.y < 600.0)
    if _compact_hud and is_instance_valid(_floor_label):
        _floor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _floor_label.custom_minimum_size.x = 190.0
        if is_instance_valid(_right_card):
            for candidate in _right_card.find_children("*", "Label", true, false):
                var label := candidate as Label
                if label != null:
                    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                    label.custom_minimum_size.x = 125.0
    elif was_compact:
        if is_instance_valid(_floor_label):
            _floor_label.autowrap_mode = TextServer.AUTOWRAP_OFF
            _floor_label.custom_minimum_size.x = 0.0
        if is_instance_valid(_left_card):
            _restore_card_labels(_left_card)
        if is_instance_valid(_right_card):
            _restore_card_labels(_right_card)
        if is_instance_valid(_charm_label):
            _charm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        if is_instance_valid(_mote_label):
            _mote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            _mote_label.custom_minimum_size.y = 48.0
        if is_instance_valid(_objective_label):
            _objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if _compact_hud:
        # A landscape phone-sized window cannot show the full desktop cards
        # side by side. Keep the essential warmth/floor/objective readouts,
        # tuck the optional chatter away, and let the two remaining cards
        # share the top row instead of painting over one another.
        for optional: Control in [_region_label, _level_label, _stats_label, _sparkle_label, _charm_label, _mote_label, _log_label, _hint_label]:
            if is_instance_valid(optional):
                optional.visible = false
    else:
        for restored: Control in [_region_label, _level_label, _stats_label, _sparkle_label, _charm_label, _mote_label, _log_label, _hint_label]:
            if is_instance_valid(restored):
                restored.visible = true
        if is_instance_valid(_left_card):
            _left_card.clip_contents = false
        if is_instance_valid(_right_card):
            _right_card.clip_contents = false
    # HUD status cards. NOTE ON POSITIONING: Control.position is ABSOLUTE in
    # parent coordinates once a control is in the tree (the old "negative
    # offset from the anchor" trick only worked while the node was still
    # detached, because Godot then measures a zero-size parent). Every rect
    # below is therefore computed in real parent coordinates, which is what
    # keeps the HUD on screen when the window is resized.
    if is_instance_valid(_left_card):
        var left_width := minf(315.0, maxf(150.0, viewport_size.x * (0.42 if narrow else 0.25)))
        if _compact_hud:
            left_width = minf(265.0, maxf(180.0, viewport_size.x * 0.55))
            _left_card.clip_contents = true
            _set_compact_card_labels(_left_card, maxf(40.0, left_width - 64.0), compact_lines)
        _left_card.custom_minimum_size = Vector2(left_width, 0)
        # An autowrapped Label with no width floor reports a minimum size of
        # "longest word" wide and one word per line tall (a single short line
        # measured 33x569), which is what made these HUD cards taller than the
        # window at every resolution. Keep a floor under the card's inner width.
        if is_instance_valid(_charm_label):
            _charm_label.custom_minimum_size.x = maxf(60.0, left_width - 32.0)
        _left_card.reset_size()
        _left_card.position = Vector2(8.0, 8.0) if _compact_hud else Vector2(18.0, 16.0)
    var hide_minimap := false
    if is_instance_valid(_right_card):
        var right_width := minf(350.0, maxf(150.0, viewport_size.x * (0.42 if narrow else 0.28)))
        if _compact_hud:
            right_width = minf(185.0, maxf(150.0, viewport_size.x * 0.38))
            _right_card.clip_contents = true
        _right_card.custom_minimum_size = Vector2(right_width, 0)
        # Same width-floor rule for the right card's wrapped chatter/objective.
        var right_inner := maxf(60.0, right_width - 30.0)
        if _compact_hud:
            _set_compact_card_labels(_right_card, maxf(40.0, right_width - 60.0), compact_lines)
        else:
            if is_instance_valid(_mote_label):
                # On narrow windows let the chatter wrap a little more eagerly so
                # the card can actually fit beside (or above) the status card.
                _mote_label.custom_minimum_size.x = right_inner * (0.78 if narrow else 1.0)
                _mote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            if is_instance_valid(_objective_label):
                _objective_label.custom_minimum_size.x = right_inner * (0.78 if narrow else 1.0)
                _objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _right_card.reset_size()
        # Container sizes do not settle inside this same call, so place the
        # card from the minimums it is guaranteed to occupy.
        var right_rect := _effective_rect(_right_card)
        var left_rect := _effective_rect(_left_card)
        var right_x := viewport_size.x - right_rect.size.x - (8.0 if _compact_hud else 18.0)
        var right_y := 8.0 if _compact_hud else 18.0
        if not _compact_hud and right_x < left_rect.position.x + left_rect.size.x + 12.0:
            # Not enough width to sit beside the status card: tuck it below.
            right_x = viewport_size.x - right_rect.size.x - 18.0
            right_y = left_rect.position.y + left_rect.size.y + 12.0
            if right_y + right_rect.size.y > viewport_size.y - 8.0:
                # Too short to stack either (a tiny window). The chatter card
                # takes the bottom-right corner and the minimap yields, rather
                # than the two cards painting over each other.
                right_y = maxf(left_rect.position.y, viewport_size.y - right_rect.size.y - 8.0)
                hide_minimap = true
        right_x = maxf(8.0, minf(right_x, viewport_size.x - right_rect.size.x - 8.0))
        right_y = minf(right_y, maxf(8.0, viewport_size.y - right_rect.size.y - 8.0))
        _right_card.position = Vector2(right_x, right_y)
    if is_instance_valid(_minimap):
        _minimap.visible = not _compact_hud and not hide_minimap
        var map_side := clampf(minf(viewport_size.x, viewport_size.y) * 0.19, 96.0, 172.0 if not small_height else 132.0)
        _minimap.custom_minimum_size = Vector2(map_side, map_side + 12.0)
        _minimap.reset_size()
        # CozyMinimap enforces its own 172x184 minimum, so place it from the
        # size it ACTUALLY got (using the requested side overflowed the window
        # by the difference).
        var map_rect := _effective_rect(_minimap)
        # The bottom-right corner is the touch cluster's, and parking the GROVE
        # MAP in it meant SING/DASH/CART/BOOK/COZY painted straight over the
        # map on every touchscreen. Try the corner, then straight above the
        # cluster, then beside it; the map yields rather than hide underneath
        # the buttons.
        var corner := Vector2(
            maxf(0.0, viewport_size.x - map_rect.size.x - 14.0),
            maxf(0.0, viewport_size.y - map_rect.size.y - 14.0)
        )
        var cluster := _touch_cluster_rect()
        var map_spot := corner
        if cluster.size.x > 1.0:
            var map_blockers: Array[Rect2] = [cluster, _card_rect(_right_card)]
            var found := _place_clear(map_rect.size, [
                corner,
                Vector2(corner.x, cluster.position.y - map_rect.size.y - 10.0),
                Vector2(cluster.position.x - map_rect.size.x - 10.0, corner.y),
            ], map_blockers)
            if found.is_finite():
                map_spot = found
            else:
                # Nowhere clear for the map. Keep the corner spot so the control
                # still measures on screen for the resize pass, but stop
                # painting it under the buttons.
                _minimap.visible = false
        _minimap.position = map_spot
    if is_instance_valid(_log_label):
        var log_width := clampf(viewport_size.x * 0.42, 200.0, 470.0)
        _log_label.custom_minimum_size = Vector2(log_width, 72.0 if small_height else 126.0)
        # These three hang directly off a plain Control (not a Container), so
        # changing custom_minimum_size does NOT resize them on its own — the
        # stale width used to survive a window shrink and overflow the screen.
        _log_label.reset_size()
        # The bottom-left corner is the joystick's, so the log used to be drawn
        # underneath it and the wisps' chatter was unreadable behind the stick.
        # Lift it above the stick, slide it beside it, and let it yield rather
        # than overlap.
        var log_rect := _effective_rect(_log_label)
        var log_spot := Vector2(16.0, maxf(8.0, viewport_size.y - log_rect.size.y - 26.0))
        var joystick := _joystick_rect()
        if joystick.size.x > 1.0:
            var cluster_rect := _touch_cluster_rect()
            var log_blockers: Array[Rect2] = [joystick]
            if cluster_rect.size.x > 1.0:
                log_blockers.append(cluster_rect)
            var found := _place_clear(log_rect.size, [
                Vector2(log_spot.x, joystick.position.y - log_rect.size.y - 10.0),
                Vector2(joystick.end.x + 10.0, log_spot.y),
            ], log_blockers)
            # The compact-HUD pass already decides whether the log is wanted at
            # all, so only let the touch layout take that decision away.
            _log_label.visible = not _compact_hud and found.is_finite()
            if found.is_finite():
                log_spot = found
        _log_label.position = log_spot
    if is_instance_valid(_hint_label):
        var hint_width := clampf(viewport_size.x * 0.80, 260.0, 620.0)
        _hint_label.custom_minimum_size = Vector2(hint_width, 30.0)
        _hint_label.reset_size()
        _hint_label.position = Vector2(maxf(8.0, (viewport_size.x - _hint_label.size.x) * 0.5), viewport_size.y - _hint_label.size.y - (34.0 if small_height else 44.0))
    if is_instance_valid(_toast_label):
        var toast_width := clampf(viewport_size.x * 0.70, 260.0, 580.0)
        _toast_label.custom_minimum_size = Vector2(toast_width, 54.0)
        _toast_label.reset_size()
        _toast_label.position = Vector2(maxf(8.0, (viewport_size.x - _toast_label.size.x) * 0.5), 76.0 if small_height else 96.0)
    if is_instance_valid(_story_card):
        var story_width := clampf(viewport_size.x * 0.72, 280.0, 560.0)
        _story_card.custom_minimum_size = Vector2(story_width, 0)
        _story_card.reset_size()
        # The story card is opaque and draws after the HUD, so it has to start
        # below the toast band measured above it. Fixed offsets (96 on short
        # windows, 150 on tall ones) ignored how far the toast text actually
        # wrapped, and hid it behind the card at every size under 600px tall.
        var story_top := 150.0
        if is_instance_valid(_toast_label):
            story_top = _toast_label.position.y + _toast_label.size.y + 4.0
        # A very short window cannot stack both bands; keeping the card on screen
        # wins over keeping it clear of the toast.
        story_top = minf(story_top, maxf(8.0, viewport_size.y - _story_card.size.y - 8.0))
        _story_card.position = Vector2(maxf(8.0, (viewport_size.x - _story_card.size.x) * 0.5), story_top)
    _fit_modal_card(_overlay_card)
    _fit_modal_card(_shop_card)
    # Modal copy is authored at comfortable desktop widths (up to 820px text,
    # 360px buttons); clamp rows to what fits so small/portrait windows wrap
    # the text instead of pushing buttons off-screen.
    _refit_content(_overlay_content, _overlay_card)
    if is_instance_valid(_shop_scroll):
        _refit_content(_shop_scroll, _shop_card)
    _refit_content(_shop_content, _shop_card)
    # Refitting can release the content-driven minimum that had widened a
    # card; settle the requested frame once more so the next frame cannot push
    # it back off-screen.
    _fit_modal_card(_overlay_card)
    _fit_modal_card(_shop_card)

func _refit_content(container: Node, card: PanelContainer = null) -> void:
    if not is_instance_valid(container):
        return
    # Measure the real inner width of the fitted card (34+34 margins) and allow
    # for the vertical scrollbar, so rows can never be wider than the panel
    # that scrolls them.
    var available := 820.0
    if is_instance_valid(card):
        # Use the card's requested width, not its content-expanded size. Once a
        # long label has inflated a PanelContainer, measuring that expanded size
        # makes the available width grow with the overflow and the fit can never
        # recover.
        var fitted_width := card.custom_minimum_size.x
        if fitted_width <= 1.0:
            fitted_width = card.size.x
        available = fitted_width - 68.0 - 16.0
    else:
        available = _parent_size().x - 96.0
    available = maxf(160.0, minf(820.0, available))
    for child in container.get_children():
        var control := child as Control
        if control != null and is_instance_valid(control):
            var minimum := control.get_combined_minimum_size()
            if minimum.x > available:
                var custom := control.custom_minimum_size
                control.custom_minimum_size = Vector2(available, custom.y)
                if control is Label or control is Button:
                    control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                control.reset_size()
        if child.get_child_count() > 0:
            _refit_content(child, card)

func _set_compact_card_labels(card: Control, width_floor: float, max_lines: int) -> void:
    if not is_instance_valid(card):
        return
    for candidate in card.find_children("*", "Label", true, false):
        var label := candidate as Label
        if label == null or not is_instance_valid(label):
            continue
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var font_height := float(label.get_theme_font_size("font_size"))
        label.custom_minimum_size = Vector2(maxf(40.0, width_floor), maxf(label.custom_minimum_size.y, font_height * float(max_lines) + 4.0))
        label.max_lines_visible = max_lines
        label.clip_text = true
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _restore_card_labels(card: Control) -> void:
    if not is_instance_valid(card):
        return
    for candidate in card.find_children("*", "Label", true, false):
        var label := candidate as Label
        if label == null or not is_instance_valid(label):
            continue
        label.autowrap_mode = TextServer.AUTOWRAP_OFF
        label.custom_minimum_size = Vector2.ZERO
        label.max_lines_visible = -1
        label.clip_text = false
        label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func _effective_rect(control: Control) -> Rect2:
    ## A control's `size` can lag behind a minimum-size change within the same
    ## frame, so place neighbours from the size the control is guaranteed to
    ## occupy. This is what keeps the HUD cards from overlapping on a narrow
    ## window (and the minimap from hanging off the edge).
    if not is_instance_valid(control):
        return Rect2()
    var guaranteed := control.get_combined_minimum_size()
    return Rect2(control.position, Vector2(maxf(control.size.x, guaranteed.x), maxf(control.size.y, guaranteed.y)))

func _card_rect(panel: Control) -> Rect2:
    ## The measured rect of a HUD card, or an empty rect when it is not on
    ## screen (so an invisible card never blocks a placement).
    if not is_instance_valid(panel) or not panel.is_visible_in_tree():
        return Rect2()
    return _effective_rect(panel)

func _touch_cluster_rect() -> Rect2:
    ## The block of on-screen touch buttons in the bottom-right corner, in real
    ## parent coordinates. Measured from the live controls rather than the
    ## authored anchor offsets because several buttons are wider than their
    ## 98px minimum (BOOK ♥ measures 109px), and because Control.position is
    ## absolute once a node is in the tree.
    if not is_instance_valid(_touch_root) or not _touch_root.is_visible_in_tree():
        return Rect2()
    var cluster := Rect2()
    var found := false
    for button in _touch_buttons:
        if not is_instance_valid(button) or not button.is_visible_in_tree():
            continue
        var rect := _effective_rect(button)
        cluster = cluster.merge(rect) if found else rect
        found = true
    return cluster if found else Rect2()

func _joystick_rect() -> Rect2:
    ## The touch joystick in the bottom-left corner, or an empty rect when there
    ## is no touchscreen.
    if not is_instance_valid(_touch_joystick) or not _touch_joystick.is_visible_in_tree():
        return Rect2()
    return _effective_rect(_touch_joystick)

func _place_clear(wanted: Vector2, candidates: Array[Vector2], blockers: Array[Rect2]) -> Vector2:
    ## The first of `candidates` that keeps a `wanted`-sized rect fully on
    ## screen and clear of every blocker, or Vector2.INF when nothing fits so
    ## the caller can drop the control rather than stack it over something the
    ## player needs to read. Each candidate is clamped into the window first,
    ## so an out-of-bounds preferred corner can never win.
    var parent := _parent_size()
    if wanted.x > parent.x or wanted.y > parent.y:
        return Vector2.INF
    var limits := parent - wanted
    for candidate in candidates:
        var spot := Vector2(clampf(candidate.x, 0.0, limits.x), clampf(candidate.y, 0.0, limits.y))
        var blocked := false
        for blocker in blockers:
            if blocker.size.x < 1.0 or blocker.size.y < 1.0:
                continue
            if Rect2(spot, wanted).intersects(blocker):
                blocked = true
                break
        if not blocked:
            return spot
    return Vector2.INF

func _parent_size() -> Vector2:
    ## The live rect every HUD control is parented to. Prefer the real parent
    ## rect over the viewport so absolute positions always land in-window.
    if is_instance_valid(_root) and _root.size.x > 1.0 and _root.size.y > 1.0:
        return _root.size
    if is_inside_tree() and get_viewport() != null:
        return get_viewport().get_visible_rect().size
    return Vector2(1280, 720)

func _fit_modal_card(card: PanelContainer) -> void:
    if not is_instance_valid(card):
        return
    var parent_size := _parent_size()
    var card_size := Vector2(minf(900.0, parent_size.x * 0.94), minf(640.0, parent_size.y * 0.92))
    card.custom_minimum_size = card_size
    card.reset_size()
    # Control.position is absolute in parent coordinates: centre the card by
    # subtracting HALF its size from the parent centre. Assigning -size/2 (the
    # old detached-node trick) parked the whole panel off-screen up-left,
    # which is why every menu looked broken at every resolution.
    card.position = parent_size * 0.5 - card.size * 0.5

func _show_overlay() -> void:
    _dismiss_beat_ring()
    _cancel_story()
    _reset_touch_joystick()
    _overlay_scrim.visible = true
    _overlay_card.visible = true
    _modal_open = true
    _overlay_card.modulate.a = 1.0
    _fit_layout()

func _dismiss_beat_ring() -> void:
    ## The beat ring is a live gameplay affordance ("press E on the gold") and
    ## it draws after every panel, so any panel opening over an active lullaby
    ## left the gold ring floating on top of it. Hiding it here mirrors
    ## close_panels(); the lullaby keeps its place, so the next lullaby tick
    ## brings the ring straight back once play resumes.
    if _beat_ring != null:
        _beat_ring.visible = false
