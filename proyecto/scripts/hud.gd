extends CanvasLayer

@onready var time_label: Label = $Root/TimeLabel
@onready var message_label: Label = $Root/MessageLabel
@onready var checkpoints_label: Label = $Root/CheckpointsLabel
@onready var best_time_label: Label = $Root/BestTimeLabel


func _ready() -> void:
	message_label.text = ""
	checkpoints_label.text = "0/0"
	best_time_label.text = "Récord: --"
	await get_tree().process_frame
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager == null:
		return
	if manager.has_signal("time_updated"):
		manager.time_updated.connect(_on_time_updated)
	if manager.has_signal("finished"):
		manager.finished.connect(_on_finished)
	if manager.has_signal("respawned"):
		manager.respawned.connect(_on_respawned)
	if manager.has_signal("checkpoint_reached"):
		manager.checkpoint_reached.connect(_on_checkpoint)
	if manager.has_signal("checkpoints_updated"):
		manager.checkpoints_updated.connect(_on_checkpoints_updated)
	if manager.has_signal("best_time_updated"):
		manager.best_time_updated.connect(_on_best_time_updated)
	# Sync state emitted before this HUD connected (initial totals/record).
	if "best_time" in manager and manager.best_time > 0.0:
		_on_best_time_updated(manager.best_time)
	if "checkpoints_total" in manager and manager.checkpoints_total > 0:
		_on_checkpoints_updated(manager.checkpoints_completed, manager.checkpoints_total)


func _on_time_updated(elapsed: float) -> void:
	time_label.text = "Tiempo: %.2f s" % elapsed


func _on_finished(final_time: float) -> void:
	message_label.text = "¡Meta!  %.2f s" % final_time
	message_label.modulate = Color(1.0, 0.9, 0.2)


func _on_respawned(penalty: float) -> void:
	message_label.text = "+%.1f s  (caída)" % penalty
	message_label.modulate = Color(1.0, 0.45, 0.55)
	await get_tree().create_timer(1.4).timeout
	if message_label.text.begins_with("+"):
		message_label.text = ""


func _on_checkpoint(checkpoint_name: String) -> void:
	message_label.text = checkpoint_name
	message_label.modulate = Color(0.4, 1.0, 0.55)
	await get_tree().create_timer(1.0).timeout
	if message_label.text == checkpoint_name:
		message_label.text = ""


func _on_checkpoints_updated(completed: int, total: int) -> void:
	checkpoints_label.text = "%d/%d" % [completed, total]


func _on_best_time_updated(time: float) -> void:
	best_time_label.text = "Récord: %.2f s" % time
