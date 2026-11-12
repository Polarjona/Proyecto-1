@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var radius: float = 4.0
var pull: float = 4.4
var spin: float = 2.4

var _rings: Array[Node3D] = []
var _time: float = 0.0

func _ready() -> void:
	_setup(Vector3(radius * 2.0, radius * 2.8, radius * 2.0), 6.0, 0.0, Vector3.ZERO, false)
	for i in 4:
		var ring := Node3D.new()
		add_child(ring)
		for j in 10:
			var angle := float(j) * TAU / 10.0
			var arm := _add_box(ring, Vector3(0.18, 0.18, radius * 0.9),
				OceanStyle.additive(OceanStyle.GLOW, 0.18),
				Vector3(cos(angle) * radius * 0.55, sin(angle) * radius * 0.55, 0.0))
			arm.rotation.z = angle
		ring.rotation.x = deg_to_rad(24.0 + float(i) * 12.0)
		_rings.append(ring)
	_add_sphere(self, radius * 0.35, OceanStyle.glass(OceanStyle.GLOW, 0.35), Vector3.ZERO)
	_add_light(self, OceanStyle.GLOW, 1.2, radius * 3.2)

func _physics_process(delta: float) -> void:
	_time += delta
	for i in _rings.size():
		_rings[i].rotate_y(delta * (0.9 + float(i) * 0.4))
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		var offset := body.global_position - global_position
		offset.y *= 0.3
		if offset.length_squared() < 0.4:
			continue
		var inward := -offset.normalized()
		var tangent := Vector3(-offset.z, 0.0, offset.x).normalized()
		_push_field((inward * pull + tangent * spin) * delta * 4.0)


## Pez globo: se hincha y deshincha, y bloquea el paso solo cuando está lleno.
