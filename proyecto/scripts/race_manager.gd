extends Node

## Tracks race time, checkpoints, splits, medal and finish state.
## Persists results through SaveManager (user://profile.json).

signal checkpoint_reached(checkpoint_name: String)
signal split_reached(checkpoint_name: String, split_time: float, delta: float)
signal finished(final_time: float)
signal respawned(penalty: float)
signal time_updated(elapsed: float)
signal best_time_updated(time: float)
signal checkpoints_updated(completed: int, total: int)
signal countdown_tick(value: int)
signal race_started
signal results_ready(data: Dictionary)

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
var splits: Array[float] = []
var fall_count: int = 0

var _headless: bool = false


func _ready() -> void:
	add_to_group("race_manager")
	_headless = DisplayServer.get_name() == "headless"
	# Durante la partida solo suenan los efectos y el viento.
	AudioManager.stop_music(false)
	best_time = SaveManager.best_time()
	has_best_time = SaveManager.has_best()
	# Wait one frame so checkpoints/player have entered their groups.
	await get_tree().process_frame
	_count_checkpoints()
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and player.has_method("get_spawn_transform"):
		last_checkpoint = player.get_spawn_transform()
		has_checkpoint = true
	SaveManager.register_start()
	best_time_updated.emit(best_time)
	if not _headless:
		_run_intro()


func _process(delta: float) -> void:
	if not is_running or is_finished:
		return
	elapsed_time += delta
	time_updated.emit(elapsed_time)


## Countdown: the clock stays at zero and the player cannot move until the
## light turns green, so a run never starts three seconds late.
func _run_intro() -> void:
	is_running = false
	_set_player_locked(true)
	# Give the HUD one beat to connect before the first number.
	await get_tree().create_timer(0.2).timeout
	if not is_inside_tree():
		return
	for value in [3, 2, 1]:
		countdown_tick.emit(value)
		AudioManager.play_sfx("countdown", 0.0)
		await get_tree().create_timer(0.65).timeout
		if not is_inside_tree():
			return
	elapsed_time = 0.0
	is_running = true
	_set_player_locked(false)
	time_updated.emit(elapsed_time)
	countdown_tick.emit(0)
	race_started.emit()


func _set_player_locked(locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("set_input_locked"):
		player.call("set_input_locked", locked)


func register_checkpoint(checkpoint_transform: Transform3D, checkpoint_name: String = "") -> void:
	if is_finished:
		return
	last_checkpoint = checkpoint_transform
	has_checkpoint = true
	var split_time := elapsed_time
	var reference := SaveManager.best_splits()
	var delta := 0.0
	if checkpoints_completed < reference.size():
		delta = split_time - float(reference[checkpoints_completed])
	splits.append(split_time)
	checkpoints_completed = mini(checkpoints_completed + 1, checkpoints_total)
	checkpoints_updated.emit(checkpoints_completed, checkpoints_total)
	checkpoint_reached.emit(checkpoint_name)
	split_reached.emit(checkpoint_name, split_time, delta)


func respawn_player() -> void:
	if player == null or not has_checkpoint:
		return
	if player.has_method("respawn_at"):
		player.respawn_at(last_checkpoint)
	fall_count += 1
	SaveManager.register_fall()
	elapsed_time += time_penalty
	respawned.emit(time_penalty)
	time_updated.emit(elapsed_time)
	GameFeel.flash(Color(1.0, 0.35, 0.4), 0.35)
	GameFeel.shake(2.5)


## Puesto del jugador en la carrera con bots (1 = primero). 0 en clásico.
func player_position() -> int:
	if not GameSession.is_bot_race():
		return 0
	var director := get_tree().get_first_node_in_group("race_director")
	if director == null or not director.has_method("player_position_now"):
		return 0
	return int(director.call("player_position_now"))


func finish_race() -> void:
	if is_finished:
		return
	is_finished = true
	is_running = false
	var medal := SaveManager.medal_for(elapsed_time)
	var position := player_position()
	var info := SaveManager.register_finish(elapsed_time, fall_count, splits.duplicate(), position)
	best_time = SaveManager.best_time()
	has_best_time = SaveManager.has_best()
	best_time_updated.emit(best_time)
	finished.emit(elapsed_time)

	if not _headless:
		GameFeel.slow_motion(0.6, 0.45)
		GameFeel.flash(Color(1.0, 0.9, 0.35), 0.25)

	var data := {
		"time": elapsed_time,
		"best": best_time,
		"new_best": bool(info.get("new_best", false)),
		"medal": medal,
		"medal_label": SaveManager.medal_label(medal),
		"coins": int(info.get("coins", 0)),
		"coins_breakdown": info.get("coins_breakdown", {}),
		"coins_total": SaveManager.coins(),
		"position": int(info.get("position", 0)),
		"splits": splits.duplicate(),
		"falls": fall_count,
		"checkpoints": checkpoints_completed,
		"total_checkpoints": checkpoints_total,
		"mode": GameSession.mode,
		"round": GameSession.round,
	}
	results_ready.emit(data)


func _count_checkpoints() -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("checkpoints"):
		count += 1
	checkpoints_total = count
	checkpoints_updated.emit(checkpoints_completed, checkpoints_total)
