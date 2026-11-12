@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var spin_speed: float = 1.7
var blade_count: int = 6

var _rotor: Node3D

func _ready() -> void:
	touch_kind = "kill"
	# Aspas de 3,2 m: el volumen es el disco que barren, no un cuadrado de 7.
	_setup_cylinder(3.2, 1.2, 7.0, 0.4)
	_rotor = Node3D.new()
	add_child(_rotor)
	for i in blade_count:
		var pivot := Node3D.new()
		pivot.rotation.z = TAU * float(i) / float(blade_count)
		_rotor.add_child(pivot)
		_add_box(pivot, Vector3(0.5, 3.2, 0.34),
			OceanStyle.matte(OceanStyle.CORAL, 0.5), Vector3(0.0, 1.55, 0.0))
		_add_sphere(pivot, 0.2, OceanStyle.glow(OceanStyle.CORAL_ALT, 1.5),
			Vector3(0.0, 3.1, 0.0))
	_add_sphere(self, 0.62, OceanStyle.glow(OceanStyle.GLOW, 1.9), Vector3.ZERO)
	_add_light(self, OceanStyle.CORAL_ALT, 0.8, 6.0)

func _process(delta: float) -> void:
	_rotor.rotate_z(delta * spin_speed)


## Chimenea térmica: sopla una columna de agua caliente que sube de golpe.
