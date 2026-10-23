extends Area3D

## Trampoline pad: launches the player straight up when they land on it.
## The pad squashes down and springs back for visual feedback.

@export var bounce_strength: float = 10.5
@export var cooldown: float = 0.35

@onready var pad: Node3D = $Pad

var _cooldown_timer: float = 0.0


func _ready() -> void:
	add_to_group("bounce_pads")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func _on_body_entered(body: Node3D) -> void:
	if _cooldown_timer > 0.0 or not body.is_in_group("player"):
		return
	_cooldown_timer = cooldown
	if body.has_method("bounce"):
		body.bounce(bounce_strength)
	elif body is CharacterBody3D:
		(body as CharacterBody3D).velocity.y = bounce_strength
	_squash()


## Quick squash then elastic spring back to rest size.
func _squash() -> void:
	if pad == null:
		return
	var tween := create_tween()
	tween.tween_property(pad, "scale", Vector3(1.25, 0.35, 1.25), 0.08)
	tween.tween_property(pad, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
