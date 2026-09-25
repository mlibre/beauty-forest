class_name HeartPickup
extends Area3D

signal heart_collected(pickup: HeartPickup)
signal heart_expired(pickup: HeartPickup)

const BASE_MAGNET_RADIUS := 3.5

var lifetime := 60.0
var heal_amount := 15.0
var pickup_multiplier := 1.0
var magnet := false
var _player: Player
var _seed := 0.0
var _visual: Node3D
var _light: OmniLight3D
var _collected := false
var _expired := false

func setup(world_position: Vector3, amount: float, pickup_mult: float, should_magnet: bool) -> void:
    position = world_position
    heal_amount = amount
    pickup_multiplier = pickup_mult
    magnet = should_magnet
    _seed = randf() * TAU
    collision_layer = 8
    collision_mask = 2
    monitoring = true
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.9 * pickup_mult
    shape.shape = sphere
    add_child(shape)
    _build_visual()
    body_entered.connect(_on_body_entered)
    if magnet:
        var magnet_area := Area3D.new()
        magnet_area.name = "MagnetRange"
        magnet_area.collision_layer = 0
        magnet_area.collision_mask = 2
        magnet_area.monitoring = true
        magnet_area.monitorable = false
        var magnet_shape := CollisionShape3D.new()
        var magnet_sphere := SphereShape3D.new()
        magnet_sphere.radius = _magnet_radius()
        magnet_shape.shape = magnet_sphere
        magnet_area.add_child(magnet_shape)
        magnet_area.body_entered.connect(_on_magnet_body_entered)
        add_child(magnet_area)

func _build_visual() -> void:
    _visual = Node3D.new()
    add_child(_visual)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#ff9fb4")
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.emission_enabled = true
    material.emission = Color("#ff8fac")
    material.emission_energy_multiplier = 2.5
    for side in [-1.0, 1.0]:
        var lobe := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.12
        sphere.height = 0.24
        sphere.radial_segments = 10
        sphere.rings = 6
        lobe.mesh = sphere
        lobe.material_override = material
        lobe.position = Vector3(side * 0.085, 0.06, 0)
        lobe.scale = Vector3(1.0, 0.9, 0.72)
        _visual.add_child(lobe)
    var point := MeshInstance3D.new()
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = 0.18
    cone.height = 0.30
    point.mesh = cone
    point.material_override = material
    point.position = Vector3(0, -0.11, 0)
    point.rotation.z = PI
    _visual.add_child(point)
    _light = OmniLight3D.new()
    _light.light_color = Color("#ff9eae")
    _light.light_energy = 0.42
    _light.omni_range = 2.2
    add_child(_light)

func _magnet_radius() -> float:
    return BASE_MAGNET_RADIUS * maxf(0.0, pickup_multiplier)

func _process(delta: float) -> void:
    if _collected or _expired:
        return
    lifetime -= delta
    if lifetime <= 0.0:
        # A thank-you heart that times out used to vanish with no word at all:
        # the player just never got the warmth and had no idea why. Announce
        # the drift-off so the loss is visible (and kind) instead of silent.
        _expired = true
        heart_expired.emit(self)
        queue_free()
        return
    _visual.rotation.y += delta * 1.8
    _visual.position.y = 0.62 + sin(Time.get_ticks_msec() * 0.003 + _seed) * 0.12
    if lifetime < 3.0:
        _visual.scale = Vector3.ONE * maxf(0.05, lifetime / 3.0)
    if magnet and is_instance_valid(_player):
        var to_player := _player.global_position + Vector3.UP * 0.55 - global_position
        var distance := to_player.length()
        if distance < _magnet_radius() and distance > 0.01:
            global_position += to_player.normalized() * minf(distance, 3.0 * delta)

func _on_magnet_body_entered(body: Node3D) -> void:
    if body is Player:
        _player = body

func _on_body_entered(body: Node3D) -> void:
    # queue_free() is deferred, so a second overlap report in the same frame
    # used to emit a second heart_collected and heal the hero twice.
    if _collected or _expired:
        return
    if body is Player:
        _collected = true
        _player = body
        heart_collected.emit(self)
        CozyVFX.heart_burst(get_parent(), global_position)
        queue_free()
