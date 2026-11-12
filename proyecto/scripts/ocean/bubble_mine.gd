@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var radius: float = 0.95
var bob: float = 1.4

var _base_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	touch_kind = "push"
	push_force = 16.0
	_setup_sphere(radius * 1.45, 8.0, 0.4)
	_base_y = position.y
	_add_sphere(self, radius, OceanStyle.matte(OceanStyle.ROCK_DARK, 0.55), Vector3.ZERO)
	_add_sphere(self, radius * 1.3, OceanStyle.glass(OceanStyle.GLOW, 0.22), Vector3.ZERO)
	for i in 8:
		var angle := float(i) * TAU / 8.0
		_add_sphere(self, 0.17, OceanStyle.glass(OceanStyle.GLOW, 0.6),
			Vector3(cos(angle) * radius * 1.35, sin(angle * 2.0) * 0.3, sin(angle) * radius * 1.35))
	_add_light(self, OceanStyle.GLOW, 0.9, 6.0)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 1.3) * bob
	rotation.y += delta * 0.5


## Corriente cruzada: una franja que empuja de lado mientras se la cruza.
