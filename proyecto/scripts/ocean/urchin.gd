@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var radius: float = 0.85
var spin: float = 0.7

func _ready() -> void:
	touch_kind = "kill"
	# Esfera de 1,25 por el radio: la caja de 2,4 golpeaba en las esquinas
	# casi un metro fuera de las púas.
	_setup_sphere(radius * 1.25, 7.5, 0.45)
	_add_sphere(self, radius, OceanStyle.matte(OceanStyle.CORAL, 0.4), Vector3.ZERO)
	_add_sphere(self, radius * 1.75, OceanStyle.additive(OceanStyle.CORAL, 0.08), Vector3.ZERO)
	for i in 14:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / 14.0
		var ring := sqrt(maxf(0.0, 1.0 - y * y))
		var angle := float(i) * 2.39996
		var dir := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		var spike := _add_cylinder(self, 0.0, 0.11, 0.58,
			OceanStyle.glow(OceanStyle.CORAL_ALT, 1.1), dir * (radius + 0.27))
		spike.quaternion = Quaternion(Vector3.UP, dir)

func _process(delta: float) -> void:
	rotation.y += delta * spin


## Alga látigo: una columna de hojas que barre el paso de lado a lado.
