extends Area3D

@onready var particles: CPUParticles3D = $Particles

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager and manager.has_method("finish_race"):
		_triggered = true
		manager.finish_race()
		_play_feedback()


func _play_feedback() -> void:
	AudioManager.play_sfx("finish")
	if particles:
		particles.restart()
