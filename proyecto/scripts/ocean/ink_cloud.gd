@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var radius: float = 2.4

var _time: float = 0.0
var _puffs: Array[MeshInstance3D] = []

func _ready() -> void:
	touch_kind = "kill"
	# La nube es redonda: esfera de 0,85 por el radio. Antes la caja medía
	# siempre 4,8 m aunque el generador cambiara el radio.
	_setup_sphere(radius * 0.85, 3.4, 0.9)
	for i in 7:
		var angle := float(i) * TAU / 7.0
		var puff := _add_sphere(self, 1.05 + float(i % 3) * 0.22,
			OceanStyle.glass(OceanStyle.INK, 0.55),
			Vector3(cos(angle) * 0.75, sin(angle * 1.7) * 0.65, sin(angle) * 0.75))
		_puffs.append(puff)
	_add_light(self, OceanStyle.CORAL_PURPLE, 0.5, 5.0)

func _process(delta: float) -> void:
	_time += delta
	for i in _puffs.size():
		var puff := _puffs[i]
		puff.position.x = cos(float(i) * 0.9 + _time * 0.7) * 0.8
		puff.position.y = sin(float(i) * 1.3 + _time * 0.5) * 0.7
		var scale_value := 0.9 + 0.2 * sin(_time * 1.6 + float(i))
		puff.scale = Vector3.ONE * scale_value


## Cadena de minas: una fila de esferas brillantes que hay que esquivar.
