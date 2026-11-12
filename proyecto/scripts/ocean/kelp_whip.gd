@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var height: float = 12.0
var sway: float = 1.0
var blades: int = 9

var _blade_root: Node3D
var _phase: float = 0.0

func _ready() -> void:
	touch_kind = "push"
	push_force = 10.5
	_setup(Vector3(2.8, height * 0.8, 2.8), 6.0, 0.3)
	_blade_root = Node3D.new()
	_blade_root.name = "Blades"
	add_child(_blade_root)
	for i in blades:
		var t := float(i) / float(blades - 1)
		var segment := _add_box(_blade_root, Vector3(0.34, height / float(blades) + 0.12, 0.16),
			OceanStyle.matte(OceanStyle.ALGAE.lerp(OceanStyle.ROCK_DARK, t), 0.8),
			Vector3(0.0, -height * 0.5 + t * height, 0.0))
		segment.rotation.z = sin(t * 3.0) * 0.12
	_add_sphere(self, 0.34, OceanStyle.glow(OceanStyle.ALGAE, 1.6),
		Vector3(0.0, height * 0.5, 0.0))

func _process(delta: float) -> void:
	_phase += delta * 1.7 * sway
	var index := 0
	for child in _blade_root.get_children():
		var segment := child as Node3D
		var t := float(index) / float(maxi(blades - 1, 1))
		segment.position.x = sin(_phase + t * 3.2) * 1.15 * t * sway
		segment.rotation.z = sin(_phase + t * 3.2) * 0.16 * t
		index += 1


## Mina de burbujas: flota, sube y baja, y al tocarla estalla en un empujón.
