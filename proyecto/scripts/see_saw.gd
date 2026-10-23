extends AnimatableBody3D

## See-saw bridge: tilts towards the player's position along its local Z axis.
## The pivot is the node origin, so the ends rise/dip over the gap.

@export var max_tilt: float = 0.38
@export var responsiveness: float = 2.6
@export var idle_sway: float = 0.04
@export var rider_range: float = 1.6
@export var rider_width: float = 1.2
@export var rider_height: float = 1.8

var _tilt: float = 0.0
var _time: float = 0.0
var _player: Node3D


func _ready() -> void:
	add_to_group("see_saws")
	sync_to_physics = true
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	var target := sin(_time * 0.9) * idle_sway
	if _player:
		var local := to_local(_player.global_position)
		var above := _player.global_position.y - global_position.y
		if absf(local.x) < rider_width and absf(local.z) < rider_range and above < rider_height:
			target = clampf(local.z / maxf(rider_range, 0.01), -1.0, 1.0) * max_tilt
	_tilt = lerpf(_tilt, target, clampf(responsiveness * delta, 0.0, 1.0))
	rotation.x = _tilt


## Current tilt in radians (used by tests and diagnostics).
func get_tilt() -> float:
	return _tilt
