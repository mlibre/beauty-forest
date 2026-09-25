class_name Player
extends CharacterBody3D

signal footstep(world_position: Vector3)
signal dashed(world_position: Vector3, direction: Vector3)

var hero: HeroRig
var dungeon: Dictionary = {}
var control_enabled := false
var move_speed := 5.0
const TOUCH_DEAD_ZONE := 0.12
var charm_effects: Dictionary = {}
var invulnerable_time := 0.0
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_cooldown_max := 2.5
var sluggish_time := 0.0
var _touch_vector := Vector2.ZERO
var _step_accumulator := 0.0
var _last_direction := Vector3.FORWARD
var move_direction := Vector3.ZERO

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    floor_max_angle = deg_to_rad(50)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.48
    shape.shape = capsule
    shape.position = Vector3(0, 0.75, 0)
    add_child(shape)
    hero = HeroRig.new()
    hero.name = "HeroRig"
    add_child(hero)

func setup(new_dungeon: Dictionary, effects: Dictionary, reduced_motion: bool = false) -> void:
    dungeon = new_dungeon
    charm_effects = effects
    move_speed = 5.0 * float(effects.get("speed", 1.0))
    dash_cooldown_max = 2.5 * float(effects.get("dash_cooldown", 1.0))
    if hero:
        hero.set_reduced_motion(reduced_motion)

func set_control_enabled(value: bool) -> void:
    control_enabled = value
    if not value:
        velocity.x = 0.0
        velocity.z = 0.0
        dash_time = 0.0
        move_direction = Vector3.ZERO
        _touch_vector = Vector2.ZERO
        if hero:
            hero.set_walk_motion(0.0)

func set_touch_vector(value: Vector2) -> void:
    var vector := value.limit_length(1.0)
    # A resting thumb's micro-wobble must not walk the hero at all. Above the
    # dead zone the magnitude is kept so a light nudge strolls and only a full
    # deflection runs (see _physics_process).
    _touch_vector = Vector2.ZERO if vector.length() < TOUCH_DEAD_ZONE else vector

func is_invulnerable() -> bool:
    return invulnerable_time > 0.0 or dash_time > 0.0

func trigger_dash(direction: Vector3) -> void:
    if not control_enabled or dash_cooldown > 0.0 or direction.length_squared() < 0.01:
        return
    dash_time = 0.28
    dash_cooldown = dash_cooldown_max
    invulnerable_time = maxf(invulnerable_time, 0.45)
    _last_direction = direction.normalized()
    dashed.emit(global_position, _last_direction)
    if hero:
        hero.trigger_swing()

func add_sluggish_time(duration: float) -> void:
    sluggish_time = maxf(sluggish_time, duration)

func _physics_process(delta: float) -> void:
    invulnerable_time = maxf(0.0, invulnerable_time - delta)
    dash_time = maxf(0.0, dash_time - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    sluggish_time = maxf(0.0, sluggish_time - delta)

    var input_vector := Vector2.ZERO
    if control_enabled:
        input_vector = Input.get_vector("bf_left", "bf_right", "bf_forward", "bf_back")
        if input_vector.length_squared() < 0.02:
            input_vector = _touch_vector
    input_vector = input_vector.limit_length(1.0)

    # Screen-relative fixed-isometric basis. The camera never rotates, so these
    # vectors remain constant and input never causes camera drift.
    var screen_forward := Vector3(-0.70710678, 0.0, -0.70710678)
    var screen_right := Vector3(0.70710678, 0.0, -0.70710678)
    # Input.get_vector() returns y = -1 when pressing forward/up (bf_forward)
    # and y = +1 for back/down, so forward needs the negated y to map
    # screen-up to world-away-from-camera.
    # Keep the raw length as analog_scale BEFORE normalizing: normalizing here
    # used to throw the magnitude away, so a light stick nudge and a full
    # pull both ran at top speed (no analog stroll, no real dead zone).
    var raw_direction := screen_right * input_vector.x - screen_forward * input_vector.y
    var direction := raw_direction.normalized()
    var analog_scale := clampf(raw_direction.length(), 0.0, 1.0)

    if control_enabled and Input.is_action_just_pressed("bf_dash") and direction.length_squared() > 0.01:
        trigger_dash(direction)
    move_direction = direction
    if direction.length_squared() > 0.01:
        _last_direction = direction
        if not is_on_floor():
            hero.look_at(global_position + direction, Vector3.UP)
        else:
            var target_yaw := hero.rotation.y
            var desired_yaw := atan2(-direction.x, -direction.z)
            hero.rotation.y = lerp_angle(target_yaw, desired_yaw, 1.0 - exp(-delta * 16.0))

    var speed := move_speed
    if sluggish_time > 0.0:
        speed *= 0.45
    if dash_time > 0.0:
        velocity.x = _last_direction.x * move_speed * 2.6
        velocity.z = _last_direction.z * move_speed * 2.6
    else:
        velocity.x = direction.x * speed * analog_scale
        velocity.z = direction.z * speed * analog_scale
    if is_on_floor():
        velocity.y = -0.8
    else:
        velocity.y -= 18.0 * delta
        if velocity.y < -12.0:
            velocity.y = -12.0
    move_and_slide()

    if direction.length_squared() > 0.01:
        var motion := clampf(velocity.length() / maxf(0.1, move_speed), 0.0, 1.0)
        hero.set_walk_motion(motion)
        _step_accumulator += delta * (1.4 + motion)
        if _step_accumulator >= 0.42 and is_on_floor():
            _step_accumulator = 0.0
            footstep.emit(global_position + Vector3(0, 0.08, 0))
    else:
        hero.set_walk_motion(0.0)
        _step_accumulator = minf(_step_accumulator, 0.3)
