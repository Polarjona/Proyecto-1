extends Area3D

## Trampoline pad: launches players and bots straight up when they land on it.
## The pad squashes down and springs back for visual feedback.

@export var bounce_strength: float = 10.5
@export var cooldown: float = 0.35

@onready var pad: Node3D = $Pad

var _cooldowns: Dictionary = {}


func _ready() -> void:
	add_to_group("bounce_pads")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	for key in _cooldowns.keys():
		var remaining: float = float(_cooldowns[key]) - delta
		if remaining <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = remaining


func _on_body_entered(body: Node3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("bot")):
		return
	var id := body.get_instance_id()
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		return
	_cooldowns[id] = cooldown
	if body.has_method("bounce"):
		body.bounce(bounce_strength)
	elif body is CharacterBody3D:
		(body as CharacterBody3D).velocity.y = bounce_strength
	AudioManager.play_sfx_at("boing", pad.global_position, 0.08, -4.0)
	_squash()


## Quick squash then elastic spring back to rest size.
func _squash() -> void:
	if pad == null:
		return
	var tween := create_tween()
	tween.tween_property(pad, "scale", Vector3(1.25, 0.35, 1.25), 0.08)
	tween.tween_property(pad, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
