@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var puff_speed: float = 2.2

var _time: float = 0.0
var _body: Node3D

func _ready() -> void:
	touch_kind = "push"
	push_force = 14.0
	# El recuadro va dentro del cuerpo: al hincharse crecen a la vez.
	_setup(Vector3.ONE * 2.4, 8.5, 0.5, Vector3.ZERO, false)
	_body = Node3D.new()
	add_child(_body)
	var ghost := _add_hitbox_ghost(Vector3.ONE * 2.4)
	if ghost != null:
		remove_child(ghost)
		ghost.position = Vector3.ZERO
		_body.add_child(ghost)
	_add_sphere(_body, 0.9, OceanStyle.matte(OceanStyle.SAND, 0.55), Vector3.ZERO)
	for i in 12:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / 12.0
		var ring := sqrt(maxf(0.0, 1.0 - y * y))
		var angle := float(i) * 2.39996
		var dir := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		_add_cylinder(_body, 0.0, 0.09, 0.42, OceanStyle.matte(OceanStyle.CORAL_ALT, 0.5),
			dir * 0.95)
		var spike := _body.get_child(_body.get_child_count() - 1) as MeshInstance3D
		spike.quaternion = Quaternion(Vector3.UP, dir)
	_add_light(_body, OceanStyle.CORAL_ALT, 0.7, 4.5)

func _process(delta: float) -> void:
	_time += delta
	var puff := 0.55 + 0.75 * (0.5 + 0.5 * sin(_time * puff_speed))
	_body.scale = Vector3.ONE * puff
	if _collision_shape != null:
		_collision_shape.scale = Vector3.ONE * (puff * 0.95)
	rotation.y += delta * 0.4


## Almeja gigante: dos valvas que se cierran y empujan al que esté en medio.
