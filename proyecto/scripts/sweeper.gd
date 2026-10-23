extends Node3D

## Rotating sweeper bar: spins around Y and knocks the player sideways.
## The bar itself is solid, the push area adds the knockback on contact.

@export var spin_speed: float = 1.6
@export var push_force: float = 11.0
@export var push_lift: float = 2.5
## Flip to -1.0 to make the bar spin the other way.
@export var spin_direction: float = 1.0

@onready var bar: AnimatableBody3D = $Bar
@onready var push_area: Area3D = $Bar/PushArea

var _angle: float = 0.0


func _ready() -> void:
	add_to_group("sweepers")
	push_area.body_entered.connect(_on_body_entered)


# Moved in `_process` (sync_to_physics = false), same as the pendulum hammer.
func _process(delta: float) -> void:
	_angle += spin_speed * spin_direction * delta
	bar.rotation.y = _angle


func get_angle() -> float:
	return _angle


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("apply_push"):
		return
	var push_dir := body.global_position - bar.global_position
	push_dir.y = 0.0
	if push_dir.length_squared() < 0.001:
		push_dir = Vector3.RIGHT
	else:
		push_dir = push_dir.normalized()
	body.apply_push(push_dir * push_force + Vector3.UP * push_lift)
