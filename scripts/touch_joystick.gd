class_name TouchJoystick
extends Control

signal vector_changed(value: Vector2)

var _touch_index := -1
var _value := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(154, 154)
    size = Vector2(154, 154)
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _touch_index < 0:
            _touch_index = touch.index
            _set_from_position(touch.position)
            accept_event()
        elif not touch.pressed and touch.index == _touch_index:
            _touch_index = -1
            _value = Vector2.ZERO
            vector_changed.emit(_value)
            queue_redraw()
            accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_index:
            _set_from_position(drag.position)
            accept_event()

func _input(event: InputEvent) -> void:
    # A release outside the stick never reaches _gui_input, which would leave
    # the captured index set and the hero walking forever. The tree-wide tap
    # catches that release by index; an inside release is already cleared by
    # _gui_input, whose index check then simply stops matching.
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if not touch.pressed and touch.index == _touch_index:
            reset()

func _set_from_position(local_position: Vector2) -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.34
    var offset := local_position - center
    if offset.length() > radius:
        offset = offset.normalized() * radius
    _value = Vector2(offset.x / radius, offset.y / radius).limit_length(1.0)
    vector_changed.emit(_value)
    queue_redraw()

func reset() -> void:
    _touch_index = -1
    _value = Vector2.ZERO
    vector_changed.emit(_value)
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.38
    draw_circle(center, radius, Color(0.08, 0.18, 0.11, 0.52))
    draw_arc(center, radius, 0.0, TAU, 48, Color("#ffe49a"), 3.0, true)
    draw_arc(center, radius * 0.62, 0.0, TAU, 40, Color(1, 1, 1, 0.14), 2.0, true)
    var knob := center + Vector2(_value.x, _value.y) * radius * 0.64
    draw_circle(knob, radius * 0.34, Color(0.96, 0.73, 0.31, 0.88))
    draw_circle(knob, radius * 0.22, Color("#fff1b6"))
