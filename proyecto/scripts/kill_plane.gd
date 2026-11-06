extends Area3D

## En la final del volcán caer al vacío también pierde la carrera; en el resto
## de circuitos solo penaliza y devuelve al último checkpoint.
@export var fail_run: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	AudioManager.play_sfx("fall")
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager == null:
		return
	if fail_run and manager.has_method("fail_race"):
		manager.fail_race("void")
	elif manager.has_method("respawn_player"):
		manager.respawn_player()
