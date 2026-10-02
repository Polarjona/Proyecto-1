extends Area3D

@export var checkpoint_name: String = "Checkpoint"
@export var spawn_height_offset: float = 0.5

@onready var spawn_marker: Marker3D = $SpawnMarker
@onready var bar: MeshInstance3D = $Bar
@onready var particles: CPUParticles3D = $Particles

var _activated: bool = false


func _ready() -> void:
	add_to_group("checkpoints")
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false


func _on_body_entered(body: Node3D) -> void:
	if _activated or not body.is_in_group("player"):
		return
	var manager := _get_race_manager()
	if manager == null:
		return
	_activated = true
	var spawn := spawn_marker.global_transform if spawn_marker else global_transform
	spawn.origin.y += spawn_height_offset
	manager.register_checkpoint(spawn, checkpoint_name)
	_play_feedback()


func _play_feedback() -> void:
	AudioManager.play_sfx("checkpoint")
	if particles:
		particles.restart()
	if bar:
		var tween := create_tween()
		tween.tween_property(bar, "scale", Vector3(1.15, 1.7, 1.15), 0.12)
		tween.tween_property(bar, "scale", Vector3.ONE, 0.2)


func _get_race_manager() -> Node:
	return get_tree().get_first_node_in_group("race_manager")
