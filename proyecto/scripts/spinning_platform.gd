extends AnimatableBody3D

## Constant Y-axis spin; CharacterBody3D rides via move_and_slide floor motion.

@export var spin_speed: float = 1.2


func _physics_process(delta: float) -> void:
	rotate_y(spin_speed * delta)
