class_name Wisp
extends CharacterBody3D

var type_key := "Shambler"
var type_data: Dictionary = {}
var display_name := "Lost Wisp"
var max_health := 1.0
var health := 1.0
var move_speed := 2.0
var contact_damage := 1.0
var soul_value := 1.0
var visual_scale := 1.0
var is_big := false
var is_feeling := false
var feeling_name := ""
var feeling_farewell := ""
var curious := false
var shielded := false
var alive := true
var soothed := false
var damage_claimed := false
var reduced_motion := false
var _boss_window := 0.0
var _slow_time := 0.0
var _slow_multiplier := 1.0
var _hurt_time := 0.0
var _seed := 0.0
var _orbit_approach := true
var _visual: Node3D
var _spawn_pop := 1.0
var _body_material: ShaderMaterial
var _halo_material: StandardMaterial3D
var _halo: MeshInstance3D
var _aura_material: StandardMaterial3D
var _big_light: OmniLight3D

func setup(p_type_key: String, p_floor_number: int, p_is_big: bool = false, p_feeling: Dictionary = {}) -> void:
    type_key = p_type_key
    type_data = BeautyContent.WISP_TYPES[type_key]
    is_big = p_is_big
    is_feeling = not p_feeling.is_empty()
    _seed = randf() * TAU
    var hp_scale := 1.0 + float(p_floor_number - 1) * 0.18
    var base_scale := float(type_data.get("scale", 1.0))
    visual_scale = base_scale * (3.5 if is_big else 1.0)
    max_health = round(float(type_data["hp"]) * hp_scale * (6.0 if is_big else 1.0))
    health = max_health
    move_speed = float(type_data["speed"]) * (1.0 + float(p_floor_number - 1) * 0.03) * (0.55 if is_big else 1.0)
    if is_feeling:
        move_speed *= 0.8
    contact_damage = round(float(type_data["damage"]) * hp_scale)
    soul_value = round(float(type_data["soul"]) * (1.0 + float(p_floor_number - 1) * 0.25))
    var nickname: String = BeautyContent.random_choice(BeautyContent.NICKNAMES)
    if not p_feeling.is_empty():
        feeling_name = String(p_feeling["name"])
        feeling_farewell = String(p_feeling["farewell"])
        display_name = "%s \"%s\"" % [feeling_name, nickname]
    elif is_big:
        display_name = "The Very Big Wisp \"Chad\""
    else:
        display_name = "%s \"%s\"" % [type_key, nickname]
    curious = randf() < 0.07
    _boss_window = 1.0 if is_big else 0.0
    _spawn_pop = 0.0
    _build()

func _build() -> void:
    collision_layer = 4
    collision_mask = 1
    floor_max_angle = deg_to_rad(60)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = maxf(0.18, 0.34 * visual_scale)
    capsule.height = maxf(0.55, 1.28 * visual_scale)
    shape.shape = capsule
    shape.position = Vector3(0, capsule.height * 0.5, 0)
    add_child(shape)

    _visual = Node3D.new()
    _visual.name = "Visual"
    add_child(_visual)

    var color := Color(type_data["color"])
    _body_material = _toon(color, 0.22 if is_big else 0.10, 0.62)
    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.36 * visual_scale
    body_mesh.height = 1.14 * visual_scale
    body.mesh = body_mesh
    body.material_override = _body_material
    body.position = Vector3(0, 0.72 * visual_scale, 0)
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    _visual.add_child(body)

    var core := MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.23 * visual_scale
    core_mesh.height = 0.46 * visual_scale
    core.mesh = core_mesh
    core.material_override = _emissive(color.lerp(Color.WHITE, 0.30), 1.05)
    core.position = Vector3(0, 0.70 * visual_scale, 0)
    _visual.add_child(core)

    var aura := MeshInstance3D.new()
    var aura_mesh := SphereMesh.new()
    aura_mesh.radius = 0.58 * visual_scale
    aura_mesh.height = 1.16 * visual_scale
    aura.mesh = aura_mesh
    _aura_material = StandardMaterial3D.new()
    _aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _aura_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _aura_material.albedo_color = Color(color.r, color.g, color.b, 0.10 if not is_big else 0.15)
    _aura_material.emission_enabled = true
    _aura_material.emission = color
    _aura_material.emission_energy_multiplier = 1.8
    _aura_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    aura.mesh.material = _aura_material
    aura.position = Vector3(0, 0.68 * visual_scale, 0)
    _visual.add_child(aura)

    for side in [-1.0, 1.0]:
        var eye_white := _sphere(0.078 * visual_scale, Color("#fffaf0"))
        eye_white.position = Vector3(side * 0.135 * visual_scale, 0.91 * visual_scale, -0.315 * visual_scale)
        _visual.add_child(eye_white)
        var pupil := _sphere(0.050 * visual_scale, Color("#5c482f"))
        pupil.material_override = _emissive(Color("#6b5131"), 0.8)
        pupil.position = Vector3(side * 0.135 * visual_scale, 0.91 * visual_scale, -0.378 * visual_scale)
        _visual.add_child(pupil)
    for point_index in range(3):
        var smile := _sphere(0.020 * visual_scale, Color("#493029"))
        smile.position = Vector3((point_index - 1) * 0.055 * visual_scale, (0.79 - abs(point_index - 1) * -0.018) * visual_scale, -0.39 * visual_scale)
        _visual.add_child(smile)

    _halo = MeshInstance3D.new()
    var halo_mesh := TorusMesh.new()
    halo_mesh.inner_radius = maxf(0.12, 0.34 * visual_scale)
    halo_mesh.outer_radius = maxf(0.16, 0.40 * visual_scale)
    halo_mesh.rings = 32
    halo_mesh.ring_segments = 8
    _halo.mesh = halo_mesh
    _halo_material = StandardMaterial3D.new()
    _halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _halo_material.albedo_color = Color("#d6efff")
    _halo_material.emission_enabled = true
    _halo_material.emission = Color("#d6efff")
    _halo_material.emission_energy_multiplier = 1.7
    _halo.mesh.material = _halo_material
    _halo.position = Vector3(0, 1.36 * visual_scale, 0)
    _visual.add_child(_halo)

    _add_type_prop(color)
    if is_big:
        _big_light = OmniLight3D.new()
        _big_light.light_color = color
        _big_light.light_energy = 2.2 if not is_feeling else 1.7
        _big_light.omni_range = 9.0 if not is_feeling else 7.0
        _big_light.shadow_enabled = false
        _big_light.position = Vector3(0, 1.2 * visual_scale, 0)
        add_child(_big_light)
    if curious:
        var star := _sphere(0.11 * visual_scale, Color("#fff3a0"))
        star.material_override = _emissive(Color("#fff09a"), 3.0)
        star.position = Vector3(0.42 * visual_scale, 1.34 * visual_scale, 0)
        _visual.add_child(star)

func _add_type_prop(base_color: Color) -> void:
    var prop_color := base_color.lerp(Color("#7b593c"), 0.48)
    match type_key:
        "Shambler":
            for side in [-1.0, 1.0]:
                var brow := _box(Vector3(0.12, 0.028, 0.03) * visual_scale, prop_color)
                brow.position = Vector3(side * 0.14 * visual_scale, 1.03 * visual_scale, -0.35 * visual_scale)
                brow.rotation.z = side * -0.16
                _visual.add_child(brow)
        "Crawler":
            for side in [-1.0, 1.0]:
                var stalk := _cylinder(0.014 * visual_scale, 0.28 * visual_scale, prop_color)
                stalk.position = Vector3(side * 0.13 * visual_scale, 1.28 * visual_scale, 0)
                stalk.rotation.z = side * -0.30
                _visual.add_child(stalk)
                var tip := _sphere(0.038 * visual_scale, Color("#ffe99b"))
                tip.position = Vector3(side * 0.18 * visual_scale, 1.43 * visual_scale, 0)
                _visual.add_child(tip)
        "Warden":
            var sash := MeshInstance3D.new()
            var torus := TorusMesh.new()
            torus.inner_radius = 0.38 * visual_scale
            torus.outer_radius = 0.47 * visual_scale
            sash.mesh = torus
            sash.material_override = _toot(Color("#f2dfb8"))
            sash.position = Vector3(0, 0.46 * visual_scale, 0)
            _visual.add_child(sash)
        "Hummingbird", "Lantern Moth":
            for side in [-1.0, 1.0]:
                var wing := _sphere(0.25 * visual_scale, Color("#fff0b8"))
                wing.scale = Vector3(1.25, 0.18, 0.70)
                wing.position = Vector3(side * 0.48 * visual_scale, 0.90 * visual_scale, 0)
                wing.rotation.z = side * -0.28
                _visual.add_child(wing)
        "Dandelion":
            for offset in [-0.10, 0.0, 0.10]:
                var tuft := _cylinder(0.015 * visual_scale, 0.24 * visual_scale, Color("#fff6d8"))
                tuft.position = Vector3(offset * visual_scale, 1.35 * visual_scale, 0)
                tuft.rotation.z = offset * 2.4
                _visual.add_child(tuft)
        "Pebble":
            var cap := _sphere(0.19 * visual_scale, Color("#d7b17d"))
            cap.scale = Vector3(1.0, 0.48, 1.0)
            cap.position = Vector3(0, 1.28 * visual_scale, 0)
            cap.rotation.z = 0.22
            _visual.add_child(cap)
        "Teacup":
            var handle := MeshInstance3D.new()
            var handle_mesh := TorusMesh.new()
            handle_mesh.inner_radius = 0.10 * visual_scale
            handle_mesh.outer_radius = 0.15 * visual_scale
            handle.mesh = handle_mesh
            handle.material_override = _toot(Color("#e8c878"))
            handle.position = Vector3(0.37 * visual_scale, 0.72 * visual_scale, 0)
            handle.rotation.y = PI * 0.5
            _visual.add_child(handle)
        "Mossbell":
            var hat := _cone(0.28 * visual_scale, 0.22 * visual_scale, Color("#e6ca82"))
            hat.position = Vector3(0, 1.35 * visual_scale, 0)
            _visual.add_child(hat)
        "Giggle Puff":
            for side in [-1.0, 1.0]:
                var pom := _sphere(0.105 * visual_scale, Color("#ffd1dc"))
                pom.position = Vector3(side * 0.16 * visual_scale, 1.34 * visual_scale, 0)
                _visual.add_child(pom)

func tick_behavior(delta: float, player_position: Vector3, aggro_range: float, speed_multiplier: float, kindness_speed: float) -> void:
    if not alive:
        velocity = Vector3.ZERO
        return
    if _slow_time > 0.0:
        _slow_time = maxf(0.0, _slow_time - delta)
        if _slow_time == 0.0:
            _slow_multiplier = 1.0
    if _hurt_time > 0.0:
        _hurt_time = maxf(0.0, _hurt_time - delta)
    if is_big:
        _boss_window -= delta
        if _boss_window < -2.2:
            _boss_window = 1.4
        set_gold_window(is_boss_vulnerable())

    var distance := global_position.distance_to(player_position)
    var direction := Vector3.ZERO
    if distance < aggro_range:
        direction = player_position - global_position
        direction.y = 0.0
        if direction.length_squared() > 0.001:
            direction = direction.normalized()
        if bool(type_data.get("flighty", false)):
            var far_radius := 5.5 if bool(type_data.get("lingers", false)) else 6.5
            var near_radius := 4.5 if bool(type_data.get("lingers", false)) else 5.5
            if distance > far_radius:
                _orbit_approach = true
            elif distance < near_radius:
                _orbit_approach = false
            if not _orbit_approach:
                direction = -direction
            direction = direction.rotated(Vector3.UP, sin(_seed + Time.get_ticks_msec() * 0.002) * 0.18)
        velocity = direction * move_speed * speed_multiplier * kindness_speed * _slow_multiplier
        if direction.length_squared() > 0.01:
            look_at(global_position + direction, Vector3.UP)
    else:
        velocity = Vector3.ZERO
    move_and_slide()

    if _visual:
        var bob := 0.0 if reduced_motion else sin(Time.get_ticks_msec() * 0.004 + _seed) * 0.08
        _visual.position.y = bob + (0.42 if bool(type_data.get("flighty", false)) else 0.0)
        var bob_scale := 1.0
        if _hurt_time > 0.0:
            bob_scale += _hurt_time * 0.17
        # New arrivals pop in like a bubble finding its shape: purely visual,
        # movement and contact grace are untouched.
        if _spawn_pop < 1.0:
            _spawn_pop = minf(1.0, _spawn_pop + delta * 2.8)
            var eased := 1.0 - pow(1.0 - _spawn_pop, 3.0)
            bob_scale *= lerpf(0.25, 1.0, eased)
        _visual.scale = Vector3(bob_scale, bob_scale, bob_scale)
    if _halo and not is_big and not reduced_motion:
        _halo.rotation.y += delta * 0.9
    if _body_material:
        _body_material.set_shader_parameter("glow", (0.34 if shielded else 0.10) + _hurt_time * 0.20)
    if _aura_material:
        var aura_alpha := 0.09 + (0.06 if shielded else 0.0) + (0.03 if is_feeling else 0.0)
        if curious and not reduced_motion:
            # A curious wisp's glow twinkles faintly, like it is already
            # excited about the fact it cannot wait to share.
            aura_alpha += 0.025 + 0.025 * sin(Time.get_ticks_msec() * 0.006 + _seed)
        _aura_material.albedo_color.a = aura_alpha
    if _big_light:
        # Still Forest must still the boss light too: a breathing light is the
        # most conspicuous motion on the floor, and it is the only animated
        # channel here that a player who asked for stillness would still see.
        var breathe := 0.0 if reduced_motion else sin(Time.get_ticks_msec() * 0.002 + _seed) * 0.06
        _big_light.light_energy = (2.2 if not is_feeling else 1.7) * (0.94 + breathe)

func is_boss_vulnerable() -> bool:
    return is_big and _boss_window > 0.0

func set_gold_window(gold: bool) -> void:
    if not _halo_material:
        return
    var color := Color("#ffd34f") if gold else Color("#d6efff")
    _halo_material.albedo_color = color
    _halo_material.emission = color
    _halo_material.emission_energy_multiplier = 2.7 if gold else 1.5
    if _halo:
        var target_scale := 1.10 + sin(Time.get_ticks_msec() * 0.012) * 0.10 if gold else 1.0
        _halo.scale = _halo.scale.lerp(Vector3(target_scale, target_scale, target_scale), 0.25)

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value

func set_shielded(value: bool) -> void:
    shielded = value

func apply_slow(multiplier: float, duration: float) -> void:
    _slow_multiplier = clampf(multiplier, 0.2, 1.0)
    _slow_time = maxf(_slow_time, duration)

func take_damage(amount: float) -> void:
    if not alive:
        return
    health = maxf(0.0, health - maxf(0.0, amount))
    _hurt_time = 0.35
    if health <= 0.0:
        alive = false

func _toon(color: Color, glow: float, roughness: float) -> ShaderMaterial:
    return CozyMaterials.toon(color, glow, roughness, 0.38)

func _toot(color: Color) -> StandardMaterial3D:
    return CozyMaterials.pbr(color, 0.82)

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    return CozyMaterials.emissive(color, energy)

func _sphere(radius: float, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    visual.mesh = mesh
    visual.material_override = _toot(color)
    return visual

func _box(size: Vector3, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.material_override = _toot(color)
    return visual

func _cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    visual.mesh = mesh
    visual.material_override = _toot(color)
    return visual

func _cone(radius: float, height: float, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.01
    mesh.bottom_radius = radius
    mesh.height = height
    visual.mesh = mesh
    visual.material_override = _toot(color)
    return visual
