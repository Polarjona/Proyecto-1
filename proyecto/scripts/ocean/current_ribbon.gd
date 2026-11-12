@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var force: float = 3.4
var direction: Vector3 = Vector3.RIGHT

var _time: float = 0.0
var _arrows: Array[MeshInstance3D] = []

func _ready() -> void:
	# Es una franja de empuje continuo: el volumen entero es el efecto y ya
	# se ve con las cintas, así que no lleva recuadro.
	_setup(Vector3(25.0, 9.0, 3.6), 6.0, 0.0, Vector3.ZERO, false)
	for i in 7:
		var ribbon := _add_box(self, Vector3(23.0, 0.12, 0.5),
			OceanStyle.additive(OceanStyle.GLOW, 0.14),
			Vector3(0.0, -3.6 + float(i) * 1.2, 0.0))
		_arrows.append(ribbon)
	for i in 9:
		var fin := _add_box(self, Vector3(0.3, 0.9, 1.6),
			OceanStyle.glass(OceanStyle.GLOW, 0.22),
			Vector3(-10.0 + float(i) * 2.5, 0.0, 0.0), Vector3(0.0, 0.0, 24.0))
		fin.rotation.z = deg_to_rad(28.0)
	_add_light(self, OceanStyle.GLOW, 0.7, 12.0)

func _physics_process(delta: float) -> void:
	_time += delta
	_push_field(direction.normalized() * force)
	for i in _arrows.size():
		_arrows[i].position.z = sin(_time * 2.6 + float(i) * 0.6) * 0.5


## Medusa: campana translúcida que sube y baja, con tentáculos que aturden.
