extends Area3D

## Conveyor belt: adds constant belt speed while bodies stay inside.

@export var direction: Vector3 = Vector3.FORWARD
@export var force: float = 12.0

var _bodies: Array[Node3D] = []


func _ready() -> void:
	# Run before the player so belt velocity is applied the same physics frame.
	process_physics_priority = -5
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	direction = direction.normalized()


func _physics_process(_delta: float) -> void:
	var belt := direction * force
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("add_belt_velocity"):
			body.add_belt_velocity(belt)
		elif body.has_method("apply_push"):
			body.apply_push(belt)
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity += belt


func _on_body_entered(body: Node3D) -> void:
	if body not in _bodies:
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
