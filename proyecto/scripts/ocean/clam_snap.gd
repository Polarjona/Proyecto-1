@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var period: float = 2.6

var _time: float = 0.0
var _top: Node3D
var _bottom: Node3D

func _ready() -> void:
	touch_kind = "kill"
	# Solo las valvas: 2,2 m de alto y 3,4 de fondo, que es lo que ocupan.
	_setup(Vector3(4.6, 2.2, 3.4), 9.5, 0.6)
	_top = Node3D.new()
	_top.position = Vector3(0.0, 0.35, -1.7)
	add_child(_top)
	var top_shell := _add_sphere(_top, 1.7, OceanStyle.matte(OceanStyle.CORAL_PURPLE, 0.45),
		Vector3(0.0, 0.0, 1.7))
	top_shell.scale = Vector3(1.3, 0.5, 1.0)
	_bottom = Node3D.new()
	_bottom.position = Vector3(0.0, -0.35, -1.7)
	add_child(_bottom)
	var bottom_shell := _add_sphere(_bottom, 1.7, OceanStyle.matte(OceanStyle.ROCK_DARK, 0.5),
		Vector3(0.0, 0.0, 1.7))
	bottom_shell.scale = Vector3(1.3, 0.45, 1.0)
	_add_sphere(self, 0.5, OceanStyle.glow(OceanStyle.GLOW, 2.0), Vector3(0.0, 0.6, 1.5))
	_add_light(self, OceanStyle.GLOW, 0.8, 5.0)

func _process(delta: float) -> void:
	_time += delta
	var openness := 0.5 + 0.5 * sin(_time * TAU / period)
	_top.rotation.x = deg_to_rad(-8.0 - openness * 30.0)
	_bottom.rotation.x = deg_to_rad(8.0 + openness * 6.0)


## Abanico de coral: aspas vivas que giran y empujan al rozarlas.
