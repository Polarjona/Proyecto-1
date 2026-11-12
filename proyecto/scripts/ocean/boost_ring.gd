@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var radius: float = 2.8
var boost: float = 12.0

var _time: float = 0.0
var _torus: MeshInstance3D
var _sparks: Array[MeshInstance3D] = []

func _ready() -> void:
	touch_kind = "boost"
	# El volumen es el hueco del aro: se puede bordear sin más.
	_setup(Vector3(radius * 2.0, radius * 2.0, 3.0), 0.0, 0.0, Vector3.ZERO, false)
	_torus = _add_torus(self, radius, OceanStyle.glow(OceanStyle.GLOW, 2.2))
	_add_torus(self, radius * 1.18, OceanStyle.additive(OceanStyle.GLOW, 0.16))
	for i in 8:
		var angle := float(i) * TAU / 8.0
		_sparks.append(_add_sphere(self, 0.16, OceanStyle.glow(OceanStyle.GLOW, 1.6),
			Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)))
	_add_light(self, OceanStyle.GLOW, 1.1, radius * 3.0)

func _process(delta: float) -> void:
	_time += delta
	for i in _sparks.size():
		var angle := float(i) * TAU / float(_sparks.size()) + _time * 1.6
		_sparks[i].position = Vector3(cos(angle) * radius, sin(angle) * radius,
			sin(_time * 2.0 + float(i)) * 0.25)
	if _torus != null:
		_torus.scale = Vector3.ONE * (1.0 + 0.04 * sin(_time * 3.0))

func _physics_process(_delta: float) -> void:
	var forward := -global_transform.basis.z
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("add_belt_velocity"):
			body.add_belt_velocity(forward * boost)


## Corriente ascendente: columna de burbujas al final de cada tramo inundado
## que sube al corredor hasta la superficie. Sin ella, salir del agua a la isla
## es nadar a ciegas contra 24 m de pared y en la meta no se llega a la
## plataforma. No golpea ni frena: solo empuja hacia arriba y hacia delante.
