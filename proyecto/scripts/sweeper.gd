extends Node3D

## Rotating sweeper bar: spins around Y and knocks the player sideways.
## The bar itself is solid, the push area adds the knockback on contact.

@export var spin_speed: float = 1.6
@export var push_force: float = 4.8
## Small hop so the hit reads, without launching the player across the hall.
@export var push_lift: float = 1.2
## When false the bar only shoves: no stun, no red flash, no hit-stop.
@export var stuns: bool = true
## Flip to -1.0 to make the bar spin the other way.
@export var spin_direction: float = 1.0

@onready var bar: AnimatableBody3D = $Bar
@onready var push_area: Area3D = $Bar/PushArea

var _angle: float = 0.0
var _whoosh_timer: float = 0.0


func _ready() -> void:
	add_to_group("sweepers")
	push_area.body_entered.connect(_on_body_entered)


# Moved in `_process` (sync_to_physics = false), same as the pendulum hammer.
func _process(delta: float) -> void:
	_angle += spin_speed * spin_direction * delta
	bar.rotation.y = _angle
	_whoosh_timer -= delta
	if _whoosh_timer <= 0.0:
		_whoosh_timer = 1.25
		AudioManager.play_sfx_at("whoosh", bar.global_position, 0.2, -16.0)


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
	var impulse := push_dir * push_force + Vector3.UP * push_lift
	if stuns:
		if body.has_method("apply_push"):
			body.apply_push(impulse)
		# Sweepers must all stagger the same way, even the weakest bar whose
		# knockback alone stays under the player's stun threshold.
		if body.has_method("stun"):
			body.stun()
	elif body.has_method("apply_push_soft"):
		body.apply_push_soft(impulse)
	else:
		body.apply_push(impulse)
