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
## Horizontal separation of the two support legs. Narrow it when the dropper
## stands on a small platform.
@export var column_spread: float = 2.75
@export var support_ray_length: float = 30.0

var _timer: float = 0.0
var _balls: Array[RigidBody3D] = []

@onready var column_left: MeshInstance3D = get_node_or_null("ColumnLeft")
@onready var column_right: MeshInstance3D = get_node_or_null("ColumnRight")


func _ready() -> void:
	add_to_group("ball_droppers")
	_timer = start_delay
	# The legs are stretched down to whatever is below (floor, ramp or the
	# moving platform) so the gantry never looks like it is floating.
	_fit_supports.call_deferred()


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
	# Keep the ball as a child (tests clean them up by node type) but make it
	# top-level so a dropper mounted on a moving platform does not drag the
	# ball along with it.
	ball.top_level = true
	add_child(ball)
	ball.global_position = global_position + Vector3(
		randf_range(-drop_radius, drop_radius),
		0.0,
		randf_range(-drop_radius, drop_radius)
	)
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


## Stretches both visual legs from the beam down to the first solid surface
## below. Called deferred so physics platforms already exist.
func _fit_supports() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	for column in [column_left, column_right]:
		if column == null:
			continue
		var side: float = 1.0 if column.position.x >= 0.0 else -1.0
		column.position.x = side * column_spread
		var top_global: Vector3 = column.global_position + Vector3.UP * 3.0 * column.scale.y
		var query := PhysicsRayQueryParameters3D.create(
			top_global, top_global + Vector3.DOWN * support_ray_length, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var bottom_global: Vector3 = hit["position"]
		var height: float = maxf(top_global.y - bottom_global.y, 0.5)
		column.scale.y = height / 6.0
		column.global_position = Vector3(
			column.global_position.x,
			(top_global.y + bottom_global.y) * 0.5,
			column.global_position.z
		)


## Number of balls currently alive; used by the automated tests.
func active_ball_count() -> int:
	return _balls.size()
