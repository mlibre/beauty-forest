class_name CozyWaypoint
extends Node3D

## A diegetic "go here" marker, floating in the world over the thing the player
## should walk to.
##
## This exists because the objective used to be a sentence in the corner of the
## screen. A soft glow above the stairwell / cart / dragon says the same thing
## with no reading at all, and it survives being looked at rather than read.
##
## It is NOT the map marker -- that still lives on the grove map. This is the
## one you notice from across the room, and it only draws when the target is
## actually on screen and worth walking to.

const FLOAT_HEIGHT := 2.35
const BOB_SPEED := 1.6
const BOB_AMOUNT := 0.16

var tint := Color("#bdf0bd")
## How urgently to ask. 0 = a gentle invitation, 1 = this is the floor's whole
## point (the dragon, a Big Feeling that is ready to sing).
var urgency := 0.0
var _time := 0.0
var _reduced_motion := false
var _arrived := false
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D

func _ready() -> void:
	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.17
	core_mesh.height = 0.34
	core_mesh.radial_segments = 14
	core_mesh.rings = 8
	_core.mesh = core_mesh
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = tint
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_core.material_override = core_material
	_core.position.y = FLOAT_HEIGHT
	add_child(_core)

	# A flat ring on the ground under the marker reads as "stand here" and
	# stays legible even when the orb itself is behind a tree.
	_halo = MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.62
	halo_mesh.outer_radius = 0.82
	halo_mesh.rings = 36
	halo_mesh.ring_segments = 6
	_halo.mesh = halo_mesh
	var halo_material := StandardMaterial3D.new()
	halo_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo.mesh.material = halo_material
	_halo.position.y = 0.06
	add_child(_halo)

	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 0.55
	_light.omni_range = 4.2
	_light.position.y = FLOAT_HEIGHT
	add_child(_light)

func configure(new_tint: Color, new_urgency: float) -> void:
	tint = new_tint
	urgency = clampf(new_urgency, 0.0, 1.0)
	if _core != null and is_instance_valid(_core):
		var material := _core.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = new_tint
	if _light != null and is_instance_valid(_light):
		_light.light_color = new_tint
	if _halo != null and is_instance_valid(_halo):
		var halo_material := _halo.mesh.material as StandardMaterial3D
		if halo_material != null:
			halo_material.albedo_color = Color(new_tint.r, new_tint.g, new_tint.b, 0.55)

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value

func _process(delta: float) -> void:
	_time += delta
	# The bob and the halo pulse both speed up with urgency: a stair you may
	# wander to at leisure breathes slowly, a dragon that needs tucking in
	# pulses like something awake.
	var speed := BOB_SPEED * (1.0 + urgency * 1.6)
	var drift := 0.0 if _reduced_motion else sin(_time * speed) * BOB_AMOUNT
	if _core != null and is_instance_valid(_core):
		_core.position.y = FLOAT_HEIGHT + drift
		var pulse := 1.0 if _reduced_motion else 1.0 + sin(_time * speed * 1.5) * (0.06 + urgency * 0.10)
		_core.scale = Vector3(pulse, pulse, pulse)
	if _halo != null and is_instance_valid(_halo):
		var expand := 1.0 if _reduced_motion else 1.0 + sin(_time * speed * 0.8) * (0.04 + urgency * 0.08)
		_halo.scale = Vector3(expand, 1.0, expand)
	if _light != null and is_instance_valid(_light):
		var base := 0.55 + urgency * 0.75
		var breathe := 1.0 if _reduced_motion else (0.92 + (sin(_time * speed) * 0.5 + 0.5) * 0.16)
		_light.light_energy = (base * breathe) * (0.0 if _arrived else 1.0)

## Fade the whole marker out as the player arrives, so it stops asking once it
## has been answered.
func set_arrived(arrived: bool) -> void:
	_arrived = arrived
	var target := 0.0 if arrived else 1.0
	if _core == null or not is_instance_valid(_core):
		return
	var material := _core.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color.a = target
	if _halo != null and is_instance_valid(_halo):
		var halo_material := _halo.mesh.material as StandardMaterial3D
		if halo_material != null:
			halo_material.albedo_color.a = 0.55 * target
	if _light != null and is_instance_valid(_light) and arrived:
		# The body of the marker fades, so the bulb above it must go dark too --
		# otherwise the answer glows on the floor forever after.
		_light.light_energy = 0.0
