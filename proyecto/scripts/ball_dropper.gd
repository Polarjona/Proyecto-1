extends Node3D

## Drops rigid hazard balls over a corridor to knock players back.
## Balls spawn inside a small radius and are recycled when they fall out.

@export var ball_scene: PackedScene
@export var interval: float = 1.8
@export var interval_variance: float = 0.5
@export var drop_radius: float = 2.2
@export var max_balls: int = 6
@export var despawn_below_y: float = -4.0
## Delay before the first drop, so the corridor is not already full on spawn.
@export var start_delay: float = 1.0

var _timer: float = 0.0
var _balls: Array[RigidBody3D] = []


func _ready() -> void:
	add_to_group("ball_droppers")
	_timer = start_delay


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval + randf_range(-interval_variance, interval_variance)
		_drop_ball()
	_cleanup()


func _drop_ball() -> void:
	if ball_scene == null:
		return
	if _balls.size() >= max_balls:
		_remove_ball(0)
	var ball := ball_scene.instantiate() as RigidBody3D
	if ball == null:
		return
	ball.position = Vector3(
		randf_range(-drop_radius, drop_radius),
		0.0,
		randf_range(-drop_radius, drop_radius)
	)
	add_child(ball)
	_balls.append(ball)


func _cleanup() -> void:
	var i := _balls.size() - 1
	while i >= 0:
		var ball := _balls[i]
		if not is_instance_valid(ball) or ball.global_position.y < despawn_below_y:
			_remove_ball(i)
		i -= 1


func _remove_ball(index: int) -> void:
	if index < 0 or index >= _balls.size():
		return
	var ball := _balls[index]
	_balls.remove_at(index)
	if is_instance_valid(ball):
		ball.queue_free()


## Number of balls currently alive; used by the automated tests.
func active_ball_count() -> int:
	return _balls.size()
