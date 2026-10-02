extends Node3D

## Oscillating hammer using sine rotation on Z.

@export var max_angle: float = 1.1
@export var swing_speed: float = 0.002
@export var push_force: float = 14.0
@export var phase_offset: float = 0.0

@onready var hammer: AnimatableBody3D = $Hammer
@onready var push_area: Area3D = $Hammer/PushArea


func _ready() -> void:
	push_area.body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * swing_speed + phase_offset
	hammer.rotation.z = sin(t) * max_angle


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("apply_push"):
		# Push roughly in the swing tangent direction.
		var tangent := Vector3(-cos(hammer.rotation.z), 0.0, 0.0).normalized()
		if tangent.length_squared() < 0.01:
			tangent = Vector3.RIGHT
		var dir := (body.global_position - hammer.global_position)
		dir.y = 0.2
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
		else:
			dir = tangent
		body.apply_push(dir * push_force + Vector3.UP * 3.0)
