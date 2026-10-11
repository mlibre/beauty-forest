class_name SongNote
extends Area3D

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const CozyMaterials := preload("res://scripts/cozy_materials.gd")
const CozyVFX := preload("res://scripts/cozy_vfx.gd")
const Wisp := preload("res://scripts/wisp.gd")

signal connected_wisp(wisp: Wisp, note: SongNote)
signal note_expired(world_position: Vector3, blocked: bool)

var target: Wisp
var speed := 11.0
var life := 1.35
var damage := 8.0
var note_color := Color("#ffe6a0")
var _velocity := Vector3.ZERO
var _retarget_time := 0.0
var _trail_tick := 0.0
var _core: MeshInstance3D
var _trail: MeshInstance3D

func setup(initial_target: Wisp, attack: float, speed_multiplier: float, life_bonus: float, color: Color = Color("#ffe6a0")) -> void:
    target = initial_target
    damage = attack
    speed = 11.0 * speed_multiplier
    life = 1.35 + life_bonus
    note_color = color
    _build()

func _ready() -> void:
    monitoring = true
    monitorable = false
    collision_layer = 0
    collision_mask = 1

func _build() -> void:
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.16
    shape.shape = sphere
    add_child(shape)

    _core = MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.14
    core_mesh.height = 0.28
    core_mesh.radial_segments = 12
    core_mesh.rings = 8
    _core.mesh = core_mesh
    _core.material_override = _emissive(note_color, 3.4)
    add_child(_core)
    _trail = MeshInstance3D.new()
    var trail_mesh := SphereMesh.new()
    trail_mesh.radius = 0.085
    trail_mesh.height = 0.17
    _trail.mesh = trail_mesh
    _trail.material_override = _emissive(Color("#bfe8ff"), 2.2)
    _trail.position = Vector3(0, 0, 0.24)
    add_child(_trail)

func launch(direction: Vector3) -> void:
    _velocity = direction.normalized() * speed

func _physics_process(delta: float) -> void:
    life -= delta
    if life <= 0.0:
        note_expired.emit(global_position, false)
        queue_free()
        return
    if target == null or not is_instance_valid(target) or not target.alive or target.soothed:
        target = null
    _retarget_time -= delta
    if target == null and _retarget_time <= 0.0:
        _retarget_time = 0.12
        # The owner may provide a replacement target through metadata.
        if has_meta("target_provider"):
            var provider: Callable = get_meta("target_provider")
            if provider.is_valid():
                target = provider.call(global_position, speed * maxf(0.0, life))
    if is_instance_valid(target) and target.alive:
        var target_center := _aim_center(target)
        var desired := target_center - global_position
        if desired.length_squared() > 0.001:
            desired = desired.normalized() * speed
            _velocity = _velocity.lerp(desired, clampf(delta * 5.2, 0.0, 1.0))
            look_at(global_position + _velocity, Vector3.UP)
    var previous := global_position
    var next := previous + _velocity * delta

    var query := PhysicsRayQueryParameters3D.create(previous, next)
    query.collision_mask = 1
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        note_expired.emit(hit.get("position", next), true)
        queue_free()
        return

    global_position = next
    # A sprinkle of crumbs behind each note so long flights read clearly
    # across the grove. Tinted to match the note itself, so each step of the
    # lantern's melody leaves its own color behind. Tiny, additive, and freed
    # by CozyVFX itself.
    _trail_tick -= delta
    if _trail_tick <= 0.0:
        _trail_tick = 0.12
        var trail_parent := get_parent()
        if trail_parent != null and trail_parent.is_inside_tree():
            CozyVFX.trail_tick(trail_parent, global_position, note_color)
    if _core:
        _core.rotation.y += delta * 7.0
        _core.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.08)
    if is_instance_valid(target) and target.alive:
        if global_position.distance_squared_to(_aim_center(target)) < 0.90 * 0.90:
            connected_wisp.emit(target, self)
            queue_free()
            return

func _aim_center(wisp: Wisp) -> Vector3:
    # The aim point and the connect test must agree, or the note converges on
    # empty air and expires. A Big Feeling renders at 3.5x scale, so it has a
    # much taller body to reach: aim at the same height we test against.
    return wisp.global_position + Vector3.UP * (0.70 * wisp.visual_scale)

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    return CozyMaterials.emissive(color, energy, true)
