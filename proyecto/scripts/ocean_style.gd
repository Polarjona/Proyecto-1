class_name OceanStyle
extends RefCounted

## Paleta del circuito abisal. Se centraliza aquí para que el generador del
## mapa y los quince obstáculos marinos usen exactamente los mismos colores.

const ROCK := Color(0.13, 0.35, 0.38)
const ROCK_DARK := Color(0.06, 0.19, 0.23)
const SAND := Color(0.52, 0.66, 0.54)
const CORAL := Color(1.0, 0.42, 0.48)
const CORAL_ALT := Color(1.0, 0.68, 0.3)
const CORAL_PURPLE := Color(0.62, 0.42, 0.95)
const ALGAE := Color(0.28, 0.86, 0.58)
const GLOW := Color(0.5, 0.96, 1.0)
const ICE := Color(0.68, 0.9, 1.0)
const INK := Color(0.08, 0.05, 0.2)


static func matte(color: Color, roughness_value: float = 0.75) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	return material


static func glow(color: Color, energy: float = 1.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.35
	return material


static func glass(color: Color, alpha: float = 0.3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.18
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func additive(color: Color, alpha: float = 0.12) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
