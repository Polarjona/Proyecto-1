@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var bell_size: float = 1.1
var drift: float = 1.8
var rise_speed: float = 0.8

var _base_y: float = 0.0
var _time: float = 0.0
var _bell: Node3D
var _light: OmniLight3D

func _ready() -> void:
	# Caja pegada a la campana y a los tentáculos: 4,6 m de alto (antes 6,4)
	# y desplazada hacia abajo, que es donde cuelgan.
	_setup(Vector3(bell_size * 2.1, 4.6, bell_size * 2.1), 5.2, 0.65,
		Vector3(0.0, -1.3, 0.0))
	_base_y = position.y
	_bell = Node3D.new()
	add_child(_bell)
	var dome := _add_sphere(_bell, bell_size, OceanStyle.glass(OceanStyle.CORAL_PURPLE, 0.6), Vector3.ZERO)
	dome.scale = Vector3(1.0, 0.72, 1.0)
	_add_sphere(_bell, bell_size * 0.4, OceanStyle.glow(OceanStyle.GLOW, 2.1), Vector3(0, 0.18, 0))
	for i in 7:
		var angle := float(i) * TAU / 7.0
		_add_box(_bell, Vector3(0.08, 2.8, 0.08),
			OceanStyle.glass(OceanStyle.CORAL_PURPLE, 0.45),
			Vector3(cos(angle) * bell_size * 0.55, -1.6, sin(angle) * bell_size * 0.55))
	_light = _add_light(self, OceanStyle.CORAL_PURPLE, 1.3, 7.0)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * rise_speed) * drift
	rotation.y += delta * 0.35
	var pulse := 0.75 + 0.35 * sin(_time * 2.1)
	_light.light_energy = pulse
	if _bell != null:
		_bell.scale = Vector3(1.0, 0.85 + pulse * 0.2, 1.0)


## Señuelo de rape: un farol colgante que se balancea sobre el paso.
