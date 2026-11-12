@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var swing: float = 2.4
var phase: float = 0.0

var _hook: Node3D

func _ready() -> void:
	# El área es del tamaño del farol, no del arco que describe: antes
	# cubría toda la oscilación y se golpeaba con el aire del balanceo.
	_setup(Vector3.ONE * 1.8, 6.0, 0.55)
	_add_box(self, Vector3(0.06, 6.0, 0.06), OceanStyle.matte(OceanStyle.ROCK_DARK),
		Vector3(0.0, 3.0, 0.0))
	_hook = Node3D.new()
	_hook.position = Vector3(0.0, 0.4, 0.0)
	add_child(_hook)
	# El recuadro cuelga del farol; el área lo sigue cada fotograma (una
	# `CollisionShape3D` solo puede ser hija directa del `Area3D`).
	if _hitbox_ghost != null:
		remove_child(_hitbox_ghost)
		_hitbox_ghost.position = Vector3.ZERO
		_hook.add_child(_hitbox_ghost)
	_add_sphere(_hook, 0.5, OceanStyle.glow(OceanStyle.CORAL_ALT, 2.4), Vector3.ZERO)
	_add_sphere(_hook, 0.95, OceanStyle.additive(OceanStyle.CORAL_ALT, 0.12), Vector3.ZERO)
	_add_light(_hook, OceanStyle.CORAL_ALT, 1.6, 8.0)

func _process(delta: float) -> void:
	phase += delta * 1.1
	_hook.position.x = sin(phase) * swing
	_hook.position.y = 0.4 - cos(phase) * 0.12
	if _collision_shape != null:
		_collision_shape.position = _hook.position


## Remolino: succiona hacia el ojo y hace girar al corredor.
