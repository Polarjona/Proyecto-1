extends AnimatableBody3D

## Big seesaw bridge, Fall Guys style: a wide board balanced on a central
## axle. It pitches towards whoever is standing on it, with a small roll to
## the side, and returns level when nobody is on top.

@export var max_tilt: float = 0.3
@export var max_roll: float = 0.05
@export var responsiveness: float = 3.4
@export var idle_sway: float = 0.0
## Half-length of the board, measured from the pivot along local Z.
@export var rider_range: float = 6.2
## Half-width of the board, measured from the pivot along local X.
@export var rider_width: float = 4.2
## How far above the pivot a body still counts as riding the board.
@export var rider_height: float = 2.2

var _tilt: float = 0.0
var _roll: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("see_saws")
	sync_to_physics = true


func _physics_process(delta: float) -> void:
	_time += delta
	var weight := _rider_weight()
	var target_tilt := sin(_time * 0.9) * idle_sway + weight.y * max_tilt
	var target_roll := -weight.x * max_roll
	var smoothing := clampf(responsiveness * delta, 0.0, 1.0)
	_tilt = lerpf(_tilt, target_tilt, smoothing)
	_roll = lerpf(_roll, target_roll, smoothing)
	rotation.x = _tilt
	rotation.z = _roll


## Average position of every player/bot standing on the board, normalised to
## [-1, 1] on each axis. X is the roll axis, Y (from local Z) the pitch axis.
func _rider_weight() -> Vector2:
	var total := Vector2.ZERO
	var riders := 0
	for group in ["player", "bot"]:
		for body in get_tree().get_nodes_in_group(group):
			if not (body is Node3D) or not is_instance_valid(body):
				continue
			var local := to_local((body as Node3D).global_position)
			var above := (body as Node3D).global_position.y - global_position.y
			if absf(local.x) > rider_width or absf(local.z) > rider_range:
				continue
			if above < -0.4 or above > rider_height:
				continue
			total += Vector2(clampf(local.x / rider_width, -1.0, 1.0), clampf(local.z / rider_range, -1.0, 1.0))
			riders += 1
	if riders == 0:
		return Vector2.ZERO
	return total / float(riders)


## Current pitch in radians (used by tests and diagnostics).
func get_tilt() -> float:
	return _tilt


## Current roll in radians (used by diagnostics).
func get_roll() -> float:
	return _roll
