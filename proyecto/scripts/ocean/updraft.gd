@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var radius: float = 3.6
## Subida mientras se está dentro, en m/s (la natación admite hasta 11).
var lift: float = 10.0
## Empuje hacia delante (−Z): deja al corredor sobre la isla, no contra ella.
var forward: float = 3.2
var column_height: float = 25.0

var _time: float = 0.0
var _rings: Array[MeshInstance3D] = []
var _light: OmniLight3D

func _ready() -> void:
	touch_kind = "boost"
	# Volumen de empuje continuo: no hay golpe, así que no lleva recuadro.
	_setup(Vector3(radius * 2.0, column_height, radius * 2.0), 0.0, 0.0,
		Vector3.ZERO, false)
	for i in 4:
		var ring := _add_torus(self, radius * (0.55 + 0.11 * float(i)),
			OceanStyle.glow(OceanStyle.GLOW, 1.7))
		ring.position = Vector3(0.0, column_height * 0.5 - 0.4 - float(i) * 1.8, 0.0)
		_rings.append(ring)
	_add_sphere(self, radius * 0.9, OceanStyle.additive(OceanStyle.GLOW, 0.05),
		Vector3(0.0, column_height * 0.5 - 0.2, 0.0))
	_light = _add_light(self, OceanStyle.GLOW, 1.2, radius * 3.6)

	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.11
	bubble_mesh.height = 0.22
	bubble_mesh.radial_segments = 6
	bubble_mesh.rings = 3
	bubble_mesh.material = OceanStyle.glass(OceanStyle.GLOW, 0.5)
	var bubbles := CPUParticles3D.new()
	bubbles.amount = 110
	bubbles.lifetime = 2.2
	bubbles.preprocess = 2.0
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = radius * 0.8
	bubbles.position = Vector3(0.0, -column_height * 0.5 + 1.0, 0.0)
	bubbles.direction = Vector3.UP
	bubbles.spread = 8.0
	bubbles.gravity = Vector3(0.0, 12.0, 0.0)
	bubbles.initial_velocity_min = 5.0
	bubbles.initial_velocity_max = 11.0
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.5
	bubbles.color = Color(0.75, 1.0, 1.0, 0.8)
	bubbles.mesh = bubble_mesh
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubbles)

func _physics_process(delta: float) -> void:
	_time += delta
	for i in _rings.size():
		var pulse := 1.0 + 0.07 * sin(_time * 2.6 + float(i) * 0.9)
		_rings[i].scale = Vector3(pulse, 1.0, pulse)
	if _light != null:
		_light.light_energy = 1.1 + 0.25 * sin(_time * 3.1)
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("add_belt_velocity"):
			body.add_belt_velocity(Vector3(0.0, lift, -forward))
		else:
			_push_body(body, Vector3(0.0, lift, -forward))
