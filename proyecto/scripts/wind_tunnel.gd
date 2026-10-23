extends Area3D

## Wind tunnel: continuous lateral acceleration with gusts.
## Visual streaks scroll along the wind direction for readability.

@export var wind_direction: Vector3 = Vector3.RIGHT
@export var strength: float = 5.2
@export var gust_amplitude: float = 2.2
@export var gust_speed: float = 1.4
@export var vertical_strength: float = 0.0
@export var stream_span: float = 4.6
@export var stream_speed: float = 7.0

@onready var streams: Array = [$StreamA, $StreamB, $StreamC]

var _bodies: Array[Node3D] = []
var _base_positions: Array[Vector3] = []
var _time: float = 0.0


func _ready() -> void:
	# Runs before the player so the wind applies in the same physics frame.
	process_physics_priority = -4
	add_to_group("wind_tunnels")
	wind_direction = wind_direction.normalized()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_base_positions.resize(streams.size())
	for i in streams.size():
		var stream := streams[i] as Node3D
		if stream != null:
			_base_positions[i] = stream.position


func _physics_process(delta: float) -> void:
	_time += delta
	var gust := strength + sin(_time * TAU * gust_speed) * gust_amplitude
	var push := wind_direction * gust + Vector3.UP * vertical_strength

	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("add_external_velocity"):
			body.add_external_velocity(push)
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity += push

	_animate_streams()


func _animate_streams() -> void:
	for i in streams.size():
		var stream := streams[i] as Node3D
		if stream == null:
			continue
		var offset := fmod(_time * (stream_speed + float(i) * 1.6), stream_span)
		var base := _base_positions[i]
		stream.position = Vector3(base.x - stream_span * 0.5 + offset, base.y, base.z)
		var fade := sin((offset / stream_span) * PI)
		stream.scale = Vector3(1.0, 1.0, 0.6 + fade * 0.8)


func _on_body_entered(body: Node3D) -> void:
	if body not in _bodies:
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
