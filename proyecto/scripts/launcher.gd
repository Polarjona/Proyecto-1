extends Area3D

## Cannon: launches the player (and bots) along its local direction.
## Optional shortcut on the mid platform.

@export var launch_force: float = 8.0
@export var launch_up: float = 8.0
@export var cooldown: float = 1.2
@export var launch_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
@export var affects_bots: bool = true

@onready var tube: Node3D = $Tube
@onready var ring: MeshInstance3D = $Ring

var _cooldown_timer: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("launchers")
	launch_direction = launch_direction.normalized()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	_time += delta
	if ring:
		var pulse := 1.0 + sin(_time * 4.0) * 0.07
		ring.scale = Vector3(pulse, 1.0, pulse)

	# A racer can be standing inside the trigger when the cooldown ends
	# (bots queue here). `body_entered` will not fire again in that case, so
	# check the overlapping bodies once the cannon is ready.
	if _cooldown_timer <= 0.0:
		for body in get_overlapping_bodies():
			if _can_launch(body):
				_launch(body)
				break


## True when the cannon can fire again; bots use it to queue instead of
## running into the gap while the cooldown is active.
func is_ready() -> bool:
	return _cooldown_timer <= 0.0


func _on_body_entered(body: Node3D) -> void:
	if _cooldown_timer > 0.0:
		return
	if _can_launch(body):
		_launch(body)


func _can_launch(body: Node3D) -> bool:
	return body.is_in_group("player") or (affects_bots and body.is_in_group("bot"))


func _launch(body: Node3D) -> void:
	_cooldown_timer = cooldown
	var impulse := global_transform.basis * (launch_direction * launch_force + Vector3.UP * launch_up)
	if body.has_method("launch"):
		body.launch(impulse)
	elif body is CharacterBody3D:
		(body as CharacterBody3D).velocity += impulse
	AudioManager.play_sfx_at("cannon", global_position, 0.05, -2.0)
	GameFeel.shake(2.2)
	_squash()


func _squash() -> void:
	if tube == null:
		return
	var tween := create_tween()
	tween.tween_property(tube, "scale", Vector3(1.15, 0.75, 1.15), 0.07)
	tween.tween_property(tube, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC)
