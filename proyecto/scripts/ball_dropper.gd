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
## Color de las bolas que suelta (alpha 0 = color de la escena).
@export var ball_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Caños repartidos por la viga. Uno solo suelta las bolas por el centro; tres
## llenan el ancho del carril.
@export var chute_count: int = 1

var _timer: float = 0.0
var _balls: Array[RigidBody3D] = []
## Desplazamientos locales de los caños a lo largo de la viga.
var _chute_offsets: Array[float] = [0.0]

@onready var column_left: MeshInstance3D = get_node_or_null("ColumnLeft")
@onready var column_right: MeshInstance3D = get_node_or_null("ColumnRight")
@onready var beam: MeshInstance3D = get_node_or_null("Beam")
@onready var pipe: MeshInstance3D = get_node_or_null("Pipe")


func _ready() -> void:
	add_to_group("ball_droppers")
	_timer = start_delay
	_setup_chutes()
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
	if ball_color.a > 0.0 and "ball_color" in ball:
		ball.set("ball_color", ball_color)
	add_child(ball)
	# Cada bola sale de uno de los caños, no siempre del centro.
	var chute := _chute_offsets[randi() % _chute_offsets.size()]
	var side_offset := global_transform.basis.x * chute
	ball.global_position = global_position + side_offset + Vector3(
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


## Coloca los caños a lo largo de la viga y ensancha la viga hasta las patas.
func _setup_chutes() -> void:
	_chute_offsets.clear()
	var count := maxi(chute_count, 1)
	if pipe == null or count == 1:
		_chute_offsets.append(0.0)
		return
	var span := minf(1.75, column_spread * 0.62)
	for i in count:
		var t := float(i) / float(count - 1) * 2.0 - 1.0
		var offset := t * span
		_chute_offsets.append(offset)
		if i == 0:
			pipe.position.x = offset
			continue
		var extra := pipe.duplicate() as MeshInstance3D
		extra.name = "Pipe%d" % i
		extra.position = Vector3(offset, pipe.position.y, pipe.position.z)
		add_child(extra)


## Stretches both visual legs from the beam down to the first solid surface
## below. Called deferred so physics platforms already exist.
func _fit_supports() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	# La viga tiene que llegar de pata a pata.
	if beam != null:
		beam.scale.x = (column_spread * 2.0 + 0.5) / 5.5
	# El extremo superior de cada pata se ancla al canto inferior de la viga.
	# Antes se quedaba en la posición original de la escena, 0.7 m por debajo,
	# y la viga se veía flotando sobre los postes.
	var beam_bottom: float = 0.45 if beam == null else beam.position.y - 0.15
	for column in [column_left, column_right]:
		if column == null:
			continue
		var side: float = 1.0 if column.position.x >= 0.0 else -1.0
		column.position.x = side * column_spread
		var top_y: float = global_position.y + beam_bottom
		var leg_x: float = global_position.x + side * column_spread
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(leg_x, top_y, global_position.z),
			Vector3(leg_x, top_y - support_ray_length, global_position.z), 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var bottom_y: float = (hit["position"] as Vector3).y
		var height: float = maxf(top_y - bottom_y, 0.5)
		column.scale.y = height / 6.0
		column.global_position = Vector3(
			leg_x,
			(top_y + bottom_y) * 0.5,
			global_position.z
		)


## Number of balls currently alive; used by the automated tests.
func active_ball_count() -> int:
	return _balls.size()
