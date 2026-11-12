@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var cycle: float = 3.4

var _time: float = 0.0
var _jet: Node3D
var _light: OmniLight3D
var _bubbles: CPUParticles3D

func _ready() -> void:
	_setup(Vector3(2.6, 14.0, 2.6), 6.0, 0.0, Vector3.ZERO, false)
	_add_box(self, Vector3(2.0, 1.2, 2.0), OceanStyle.matte(OceanStyle.ROCK_DARK),
		Vector3(0.0, -7.4, 0.0))
	_jet = Node3D.new()
	add_child(_jet)
	for i in 6:
		_add_sphere(_jet, 0.5 - float(i) * 0.05,
			OceanStyle.additive(OceanStyle.CORAL_ALT, 0.16),
			Vector3(sin(float(i) * 1.7) * 0.4, -6.0 + float(i) * 2.4, cos(float(i) * 2.1) * 0.4))
	_light = _add_light(self, OceanStyle.CORAL_ALT, 1.4, 9.0)

	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.14
	bubble_mesh.height = 0.28
	bubble_mesh.radial_segments = 6
	bubble_mesh.rings = 3
	bubble_mesh.material = OceanStyle.glass(OceanStyle.CORAL_ALT, 0.5)
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 60
	_bubbles.lifetime = 2.4
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 1.0
	_bubbles.position = Vector3(0.0, -7.0, 0.0)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 18.0
	_bubbles.gravity = Vector3(0.0, 7.0, 0.0)
	_bubbles.initial_velocity_min = 3.0
	_bubbles.initial_velocity_max = 7.0
	_bubbles.scale_amount_min = 0.5
	_bubbles.scale_amount_max = 1.6
	_bubbles.color = Color(1.0, 0.75, 0.45, 0.8)
	_bubbles.mesh = bubble_mesh
	_bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubbles)

func _physics_process(delta: float) -> void:
	_time += delta
	var active := fmod(_time, cycle) < cycle * 0.45
	_jet.visible = active
	_bubbles.emitting = active
	_light.light_energy = 1.6 if active else 0.3
	if active:
		_push_field(Vector3.UP * 8.5)


## Témpano a la deriva: un bloque de hielo que cruza el pasillo de lado a lado.
