extends Node

## Tracks race time, last checkpoint, finish state.
## Persists the best time to user://best_time.save.

signal checkpoint_reached(checkpoint_name: String)
signal finished(final_time: float)
signal respawned(penalty: float)
signal time_updated(elapsed: float)
signal best_time_updated(time: float)
signal checkpoints_updated(completed: int, total: int)

const SAVE_PATH := "user://best_time.save"

@export var time_penalty: float = 2.5

var elapsed_time: float = 0.0
var is_running: bool = true
var is_finished: bool = false
var last_checkpoint: Transform3D = Transform3D.IDENTITY
var has_checkpoint: bool = false
var player: CharacterBody3D
var best_time: float = 0.0
var has_best_time: bool = false
var checkpoints_completed: int = 0
var checkpoints_total: int = 0


func _ready() -> void:
	add_to_group("race_manager")
	_load_best_time()
	# Wait one frame so checkpoints/player have entered their groups.
	await get_tree().process_frame
	_count_checkpoints()
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and player.has_method("get_spawn_transform"):
		last_checkpoint = player.get_spawn_transform()
		has_checkpoint = true
	best_time_updated.emit(best_time)


func _process(delta: float) -> void:
	if not is_running or is_finished:
		return
	elapsed_time += delta
	time_updated.emit(elapsed_time)


func register_checkpoint(checkpoint_transform: Transform3D, checkpoint_name: String = "") -> void:
	if is_finished:
		return
	last_checkpoint = checkpoint_transform
	has_checkpoint = true
	checkpoints_completed = mini(checkpoints_completed + 1, checkpoints_total)
	checkpoints_updated.emit(checkpoints_completed, checkpoints_total)
	checkpoint_reached.emit(checkpoint_name)


func respawn_player() -> void:
	if player == null or not has_checkpoint:
		return
	if player.has_method("respawn_at"):
		player.respawn_at(last_checkpoint)
	elapsed_time += time_penalty
	respawned.emit(time_penalty)
	time_updated.emit(elapsed_time)


func finish_race() -> void:
	if is_finished:
		return
	is_finished = true
	is_running = false
	finished.emit(elapsed_time)
	_save_best_time()


func _load_best_time() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var line := file.get_line().strip_edges()
	file.close()
	if line.is_valid_float():
		best_time = float(line)
		has_best_time = true
		best_time_updated.emit(best_time)


func _save_best_time() -> void:
	if has_best_time and elapsed_time >= best_time:
		return
	best_time = elapsed_time
	has_best_time = true
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_line(String.num(best_time, 3))
		file.close()
	best_time_updated.emit(best_time)


func _count_checkpoints() -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("checkpoints"):
		count += 1
	checkpoints_total = count
	checkpoints_updated.emit(checkpoints_completed, checkpoints_total)
