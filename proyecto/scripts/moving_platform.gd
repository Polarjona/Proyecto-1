extends AnimatableBody3D

## Platform shuttling back and forth between its origin and `travel`.
## Rides are handled by move_and_slide, so sync_to_physics keeps it solid.

@export var travel: Vector3 = Vector3(0.0, 0.0, -6.0)
@export var speed: float = 2.5
@export var pause_time: float = 0.6

var _origin: Vector3
var _progress: float = 0.0
var _direction: float = 1.0
var _pause: float = 0.0


func _ready() -> void:
	add_to_group("moving_platforms")
	_origin = position


func _physics_process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	var distance := travel.length()
	if distance <= 0.001:
		return
	_progress += (_direction * speed / distance) * delta
	if _progress >= 1.0:
		_progress = 1.0
		_direction = -1.0
		_pause = pause_time
	elif _progress <= 0.0:
		_progress = 0.0
		_direction = 1.0
		_pause = pause_time
	position = _origin + travel * _progress


## Normalised position along the path (0 = start, 1 = far end).
func get_progress() -> float:
	return _progress
