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

var _manager: RaceManager

var _player: Node3D

var _rank_timer: float = 0.0

var _level_info: LevelInfo

var _spawn_origin: Vector3 = Vector3.ZERO

## La carrera terminó: los bots se quedan quietos y el puesto del panel deja de
## moverse aunque el jugador tarde en cerrarlo.
var _frozen: bool = false


func _ready() -> void:
	add_to_group("race_director")
	# Igual que RaceManager: dentro del editor solo se hornea la escena.
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return
	if not GameSession.is_bot_race():
		set_process(false)
		set_physics_process(false)
		return
	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group("race_manager") as RaceManager
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_level_info = get_tree().get_first_node_in_group("level_info") as LevelInfo
	if _level_info != null:
		start_z = _level_info.start_z
		finish_z = _level_info.finish_z
		course_length = _level_info.course_length
		_spawn_origin = _level_info.start_position
	bot_count = GameSession.bot_count
	qualifiers = GameSession.qualifiers
	total_racers = bot_count + 1
	_spawn_bots()
	if _manager != null:
		_manager.finished.connect(_on_player_finished)


func _spawn_bots() -> void:
	if bot_scene == null:
		return
	for i in bot_count:
		var bot := bot_scene.instantiate() as Node3D
		if bot == null:
			continue
		var bot_scale := GameSession.bot_speed_scale()
		# La dificultad asistida afloja a los bots un 10 % sin tocar el jugador.
		if bool(SaveManager.get_setting("assisted", false)):
			bot_scale *= 0.9
		bot.set("speed_scale", bot_scale)
		# El mismo bot recorre todos los circuitos: la ruta y la meta viven en
		# LevelInfo. Sin ruta (pivot_push.tscn) conserva su tabla por defecto.
		if _level_info != null:
			bot.set("finish_z", finish_z)
			bot.set("path_corridor", _level_info.path_corridor)
			if _level_info.has_bot_path():
				bot.set("waypoints", _level_info.waypoints)
				bot.set("lane_widths", _level_info.lane_widths)
		add_child(bot)
		# Parrilla de salida ancha: cuatro columnas de 3 m y filas cada 2,2 m.
		# Con ocho corredores la piña del pistoletazo ya no se ve apelmazada.
		var column := i % 4
		var row := floori(float(i) / 4.0)
		var x := -4.5 + float(column) * 3.0
		var z := 0.8 + float(row) * 2.2
		bot.global_position = _spawn_origin + Vector3(x, 1.0, z)
		if bot.has_signal("finished"):
			bot.connect("finished", Callable(self, "_on_bot_finished"))
		_bots.append(bot)


func _process(delta: float) -> void:
	if _frozen:
		return
	_rank_timer -= delta
	if _rank_timer > 0.0:
		return
	_rank_timer = 0.25
	var rank := _live_rank()
	if rank > 0:
		rank_updated.emit(rank, total_racers)


## Puesto que consigue el jugador si cruza la meta ahora mismo. Lo consulta el
## RaceManager antes de repartir las monedas.
func player_position_now() -> int:
	return _finish_order.size() + 1


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
	# El que ya ha cruzado no puede perder el puesto a manos de quien sigue en
	# pista, por muy cerca que esté del último punto.
	if racer in _finish_order:
		return 2.0
	# La medida del avance vive en LevelInfo (por waypoint cuando el circuito
	# no es una línea recta); el HUD usa exactamente la misma.
	if _level_info != null:
		return _level_info.progress_at(racer.global_position)
	if racer.global_position.z <= finish_z:
		return 2.0
	return clampf((start_z - racer.global_position.z) / maxf(course_length, 1.0), 0.0, 1.0)


## Congela la carrera cuando el jugador llega a meta o pierde. Sin esto el
## mundo seguía corriendo detrás del panel de resultados y el puesto que se
## leía podía cambiar después de mostrarse.
func freeze_race() -> void:
	if _frozen:
		return
	_frozen = true
	set_process(false)
	for bot in _bots:
		if is_instance_valid(bot):
			bot.set_physics_process(false)
			bot.set_process(false)


func is_frozen() -> bool:
	return _frozen


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
