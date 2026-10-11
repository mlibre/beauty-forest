class_name CozyMaterials
extends RefCounted

## The one home for the shared material factories: soft-toon shader materials,
## plain PBR surfaces, and unshaded emissive glows. Every generator in the
## forest paints through these, so a lighting tweak lands everywhere at once.

## The warm lantern rim shared by every toon-painted creature.
const TOON_RIM_COLOR := Color("#ffe9a8")

static func toon(color: Color, glow: float, roughness: float, rim_strength: float = 0.30) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/soft_toon.gdshader")
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("rim_color", TOON_RIM_COLOR)
	material.set_shader_parameter("rim_strength", rim_strength)
	material.set_shader_parameter("glow", glow)
	material.set_shader_parameter("roughness_value", roughness)
	return material

static func pbr(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

## An unshaded glow. `additive` lifts the surface into the light around it,
## for things that ARE light (song notes, sun motes) rather than things lit.
static func emissive(color: Color, energy: float, additive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
