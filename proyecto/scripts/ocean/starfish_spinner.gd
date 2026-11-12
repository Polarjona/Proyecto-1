@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var spin_speed: float = 2.0

var _star: Node3D

func _ready() -> void:
	touch_kind = "push"
	push_force = 12.0
	# Los brazos barren un disco de 3,15 m: la caja de 6,6 tenía las
	# esquinas a 4,6 m del centro y se golpeaba en el aire.
	_setup_cylinder(3.15, 1.5, 8.0, 0.45)
	_star = Node3D.new()
	add_child(_star)
	for i in 5:
		var arm := Node3D.new()
		arm.rotation.z = TAU * float(i) / 5.0
		_star.add_child(arm)
		_add_box(arm, Vector3(0.6, 2.9, 0.45), OceanStyle.matte(OceanStyle.CORAL_ALT, 0.5),
			Vector3(0.0, 1.5, 0.0))
		_add_sphere(arm, 0.24, OceanStyle.glow(OceanStyle.CORAL, 1.5), Vector3(0.0, 2.9, 0.0))
	_add_sphere(self, 0.7, OceanStyle.glow(OceanStyle.CORAL, 1.9), Vector3.ZERO)
	_add_light(self, OceanStyle.CORAL_ALT, 0.9, 6.5)

func _process(delta: float) -> void:
	_star.rotate_z(delta * spin_speed)


## Rápidos de burbujas: un aro que acelera hacia delante al corredor que lo
## cruza por dentro. No golpea, no aturde y no frena: es el premio por salir
## limpio de una compuerta y la forma de enganchar el túnel de un tirón.
