extends Node

## Race director: spawns bots, keeps live standings and decides whether the
## player qualifies. Only active in "bots" and "tournament" modes.

signal rank_updated(rank: int, total: int)
signal qualification_result(qualified: bool, rank: int, qualifiers: int)
signal bot_finished(bot_name: String, rank: int)

@export var bot_scene: PackedScene
@export var finish_z: float = -205.0
## Z of the starting line and total length of the course, for live ranking.
@export var start_z: float = 5.0
@export var course_length: float = 210.0

var total_racers: int = 0
var player_rank: int = 0
var player_qualified: bool = true
var qualifiers: int = 3
var bot_count: int = 7

var _bots: Array[Node3D] = []
var _finish_order: Array[Node] = []
var _player_finished: bool = false
var _manager: Node
var _player: Node3D
var _rank_timer: float = 0.0


func _ready() -> void:
	add_to_group("race_director")
	if not GameSession.is_bot_race():
		set_process(false)
		set_physics_process(false)
		return
	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group("race_manager")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	bot_count = GameSession.bot_count
	qualifiers = GameSession.qualifiers
	total_racers = bot_count + 1
	_spawn_bots()
	if _manager and _manager.has_signal("finished"):
		_manager.finished.connect(_on_player_finished)


func _spawn_bots() -> void:
	if bot_scene == null:
		return
	for i in bot_count:
		var bot := bot_scene.instantiate() as Node3D
		if bot == null:
			continue
		bot.set("speed_scale", GameSession.bot_speed_scale())
		add_child(bot)
		var x := -4.0 + fmod(float(i) * 2.2, 8.0)
		var z := 1.4 + float(i % 3) * 1.1
		bot.global_position = Vector3(x, 1.0, z)
		if bot.has_signal("finished"):
			bot.connect("finished", Callable(self, "_on_bot_finished"))
		_bots.append(bot)


func _process(delta: float) -> void:
	_rank_timer -= delta
	if _rank_timer > 0.0:
		return
	_rank_timer = 0.25
	var rank := _live_rank()
	if rank > 0:
		rank_updated.emit(rank, total_racers)


func _live_rank() -> int:
	if _player_finished:
		return player_rank
	var progress := _progress_of(_player)
	var rank := 1
	for bot in _bots:
		if is_instance_valid(bot) and _progress_of(bot) > progress:
			rank += 1
	return rank


func _progress_of(racer: Node3D) -> float:
	if racer == null or not is_instance_valid(racer):
		return -1.0
	if racer.global_position.z <= finish_z:
		return 2.0
	return clampf((start_z - racer.global_position.z) / maxf(course_length, 1.0), 0.0, 1.0)


func _on_bot_finished(bot: Node3D, _time: float) -> void:
	if bot in _finish_order:
		return
	_finish_order.append(bot)
	bot_finished.emit(String(bot.name), _finish_order.size())
	if not _player_finished:
		player_rank = _finish_order.size() + 1
		rank_updated.emit(player_rank, total_racers)


func _on_player_finished(_time: float) -> void:
	if _player_finished:
		return
	_player_finished = true
	player_rank = _finish_order.size() + 1
	player_qualified = player_rank <= qualifiers
	qualification_result.emit(player_qualified, player_rank, qualifiers)
