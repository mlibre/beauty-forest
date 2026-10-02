class_name GameUILayout
extends GameUIChrome

## Shared modal-panel metrics. The overlay card uses 34px side margins and the
## shop card 26px; 68 is the wider of the two, so a row clamped for one panel
## still fits the other.
const MODAL_MARGIN_X := 68.0
## Slightly wider than the engine's slim VScrollBar, so reserving it can only
## ever leave slack and never make a row overflow.
const MODAL_SCROLLBAR_ALLOWANCE := 14.0

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
        _minimap.custom_minimum_size = Vector2(map_side, map_side)
        _minimap.reset_size()
        # CozyMinimap sets no floor of its own, so the size it was built with is
        # only an initial size — measure the size it actually got rather than the
        # one that was requested.
        var map_rect := _effective_rect(_minimap)
        # The bottom-right corner is the touch cluster's, and parking the map
        # there meant SING/DASH/CART/BOOK/COZY painted straight over it on every
        # touchscreen. Try the corner, then straight above the cluster, then
        # beside it; the map yields rather than hide underneath the buttons.
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
        # The story card is opaque and draws after the HUD, so it has to start
        # below the toast band measured above it. Fixed offsets (96 on short
        # windows, 150 on tall ones) ignored how far the toast text actually
        # wrapped, and hid it behind the card at every size under 600px tall.
        var story_top := 150.0
        if is_instance_valid(_toast_label):
            story_top = _toast_label.position.y + _toast_label.size.y + 4.0
        # It also has to live in the GAP between the two HUD cards. Centring it
        # on the viewport alone let a 560px card run 36px under "MOTE SAYS" and
        # 12px under the status card, and its lower edge landed on the hero's
        # head right where the camera keeps them.
        var story_width := clampf(viewport_size.x * 0.72, 280.0, 560.0)
        var gap_left := 8.0
        var gap_right := viewport_size.x - 8.0
        if not _compact_hud:
            if is_instance_valid(_left_card):
                gap_left = _effective_rect(_left_card).end.x + 10.0
            if is_instance_valid(_right_card):
                gap_right = _effective_rect(_right_card).position.x - 10.0
        var gap := gap_right - gap_left
        if gap < 240.0:
            # On a narrow window the two HUD cards meet or overlap, so there is
            # no gap to sit in. Centring on a minimum-width gap that does not
            # exist pushed the card 120px off the right edge at 480px wide.
            # Fall back to a plain centred band and let it overlap the cards.
            gap_left = 8.0
            gap_right = viewport_size.x - 8.0
            gap = gap_right - gap_left
        story_width = minf(story_width, gap)
        _story_card.custom_minimum_size = Vector2(story_width, 0)
        _story_card.reset_size()
        # A very short window cannot stack both bands; keeping the card on screen
        # wins over keeping it clear of the toast.
        story_top = minf(story_top, maxf(8.0, viewport_size.y - _story_card.size.y - 8.0))
        # The card's own text sets a minimum width no custom_minimum_size can
        # beat, so clamp the final x too and keep it in the window regardless.
        var story_x := gap_left + (gap - _story_card.size.x) * 0.5
        story_x = clampf(story_x, 8.0, maxf(8.0, viewport_size.x - _story_card.size.x - 8.0))
        _story_card.position = Vector2(story_x, story_top)
    _fit_modal_card(_overlay_card)
    _fit_modal_card(_shop_card)
    # Modal copy is authored at comfortable desktop widths (up to 820px text,
    # 360px buttons); clamp rows to what fits so small/portrait windows wrap
    # the text instead of pushing buttons off-screen.
    _refit_content(_overlay_content, _overlay_card)
    # The panel frame owns the heading rows and the closing button directly —
    # only the scrolling list lives deeper — so the frame itself must be refit
    # too, or an unwrapped heading (the settings subtitle at 200% text) forces
    # the whole card wider than the window. Recursion reaches the list inside.
    _refit_content(_shop_frame, _shop_card)
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
    # Measure the real inner width of the fitted card and allow for the vertical
    # scrollbar, so rows can never be wider than the panel that scrolls them.
    var available := 820.0
    if is_instance_valid(card):
        # Two independent width sources, and the tighter one wins.
        #
        # The card's REQUESTED width is the only source that is correct in the
        # same frame the card was just re-fitted, because the ScrollContainer
        # inside it has not re-laid-out yet and still reports the previous
        # frame's width. Using that stale value alone let a 480px window clamp
        # its rows to 794px and inflate the menu card to 922px, straight off the
        # left edge of the screen.
        #
        # The scroll viewport's own live width is the accurate source, and it
        # is the one that includes the vertical scrollbar. Deriving the width
        # from the card alone (card - margins - a guessed scrollbar) came out
        # 12px too generous at 1280x720, which is exactly the overflow that put
        # a horizontal scrollbar under the menu.
        #
        # Note the card's content-expanded size must never be used here: once a
        # long label has inflated a PanelContainer, measuring that expanded size
        # makes the available width grow with the overflow and the fit can never
        # recover.
        var fitted_width := card.custom_minimum_size.x
        if fitted_width <= 1.0:
            fitted_width = card.size.x
        available = fitted_width - MODAL_MARGIN_X - 8.0
        var scroll := _scroll_ancestor(container)
        if scroll != null and scroll.size.x > 1.0:
            available = minf(available, scroll.size.x - 10.0)
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

func _scroll_ancestor(node: Node) -> ScrollContainer:
    var current := node
    while current != null:
        if current is ScrollContainer:
            return current as ScrollContainer
        current = current.get_parent()
    return null

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
    ## screen (so a hidden card never blocks a placement). Reads the card's own
    ## `visible` rather than `is_visible_in_tree()`: the menu and ending screens
    # hide the whole HUD, and a fit that runs underneath them must reserve the
    # same space a fit that runs during play does, or the map jumps the moment
    # the HUD comes back.
    if not is_instance_valid(panel) or not panel.visible:
        return Rect2()
    return _effective_rect(panel)

func _touch_cluster_rect() -> Rect2:
    ## The block of on-screen touch buttons in the bottom-right corner, in real
    ## parent coordinates. Measured from the live controls rather than the
    ## authored anchor offsets because several buttons are wider than their
    ## 98px minimum (BOOK ♥ measures 109px), and because Control.position is
    ## absolute once a node is in the tree.
    #
    ## This deliberately reads `_touch_root.visible` and not
    ## `is_visible_in_tree()`: the menu and the ending screens hide the whole
    ## HUD, and a fit that runs underneath them (every resize, every panel
    ## open) must still know the buttons own the corner, or it would put the
    ## grove map straight back under them.
    if not is_instance_valid(_touch_root) or not _touch_root.visible:
        return Rect2()
    var cluster := Rect2()
    var found := false
    for button in _touch_buttons:
        if not is_instance_valid(button):
            continue
        var rect := _effective_rect(button)
        cluster = cluster.merge(rect) if found else rect
        found = true
    return cluster if found else Rect2()

func _joystick_rect() -> Rect2:
    ## The touch joystick in the bottom-left corner, or an empty rect when this
    ## device has no on-screen controls (see _touch_cluster_rect for why this
    ## is not an is_visible_in_tree() check).
    if not is_instance_valid(_touch_root) or not _touch_root.visible:
        return Rect2()
    if not is_instance_valid(_touch_joystick):
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
    # Reserve the vertical scrollbar by NARROWING the requested card, so the
    # card's size is the same whether or not the list happens to overflow.
    #
    # A ScrollContainer's vertical bar is a real child that only joins the tree
    # once the content overflows, and then it is added to the card's total
    # width. Measuring a 480x900 window, the menu card requested 451.2px, the
    # list overflowed, the ~15px bar appeared, and the card became 466px — a
    # late +15px size change that left it 4px off-centre (the suite's 2px
    # centring check). Requesting `cap - allowance` keeps the settled card
    # inside `cap` in both cases, so the position computed below stays exact.
    var cap := minf(900.0, parent_size.x * 0.94)
    var card_size := Vector2(
        maxf(220.0, cap - MODAL_SCROLLBAR_ALLOWANCE),
        minf(640.0, parent_size.y * 0.92)
    )
    card.custom_minimum_size = card_size
    card.reset_size()
    # Centre the card by ANCHOR and never write its position.
    #
    # The card's anchors all sit at the parent centre with
    # GROW_DIRECTION_BOTH, so the engine re-derives the offsets from that
    # anchor point on every size change and the card stays centred whatever
    # size it settles at. Computing an absolute `position` from `card.size`
    # here could only ever read a stale size: the ScrollContainer's vertical
    # bar joins the tree a layout pass later and widens the card under a
    # position that was already written, which left 1024x640 and 480x900
    # windows several pixels off-centre.
    card.anchor_left = 0.5
    card.anchor_top = 0.5
    card.anchor_right = 0.5
    card.anchor_bottom = 0.5
    card.offset_left = 0.0
    card.offset_top = 0.0
    card.offset_right = 0.0
    card.offset_bottom = 0.0
    card.grow_horizontal = Control.GROW_DIRECTION_BOTH
    card.grow_vertical = Control.GROW_DIRECTION_BOTH
    card.reset_size()
    # Safety net for a card that content forced wider than the window (200%
    # text on a small window used to push it 152px off the left edge): with
    # anchor centring there is no position to clamp, but the requested size
    # above already caps the card to the window, so only content minimums
    # larger than the window itself can still overflow — symmetrically.

func _show_overlay() -> void:
    _dismiss_beat_ring()
    _cancel_story()
    _reset_touch_joystick()
    _overlay_scrim.visible = true
    _overlay_card.visible = true
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
