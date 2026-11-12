@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var travel: float = 8.0
var speed: float = 1.15

var _base_x: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	touch_kind = "push"
	push_force = 13.0
	# El témpano visible llega a 1,5 m del centro.
	_setup(Vector3(3.2, 3.2, 3.2), 8.0, 0.45)
	_base_x = position.x
	_add_sphere(self, 1.5, OceanStyle.glass(OceanStyle.ICE, 0.75), Vector3.ZERO)
	_add_box(self, Vector3(2.4, 1.4, 2.4), OceanStyle.glass(OceanStyle.ICE, 0.55), Vector3(0.2, 0.9, 0.0))
	_add_sphere(self, 0.9, OceanStyle.glass(OceanStyle.ICE, 0.65), Vector3(-1.2, -0.7, 0.9))
	_add_light(self, OceanStyle.ICE, 0.6, 5.0)

func _process(delta: float) -> void:
	_time += delta
	position.x = _base_x + sin(_time * speed) * travel
	rotation.y += delta * 0.25


## Nube de tinta: una masa oscura que aturde más que el resto.
