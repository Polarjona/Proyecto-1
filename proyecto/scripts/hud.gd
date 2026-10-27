extends CanvasLayer

## HUD: cronómetro, récord, medalla, progreso, cuenta atrás, ranking de
## bots, pantalla de resultados y tutorial de primera vez.

const START_Z := 5.0
const FINISH_Z := -205.0

@onready var time_label: Label = $Root/TimeLabel
@onready var message_label: Label = $Root/MessageLabel
@onready var checkpoints_label: Label = $Root/CheckpointsLabel
@onready var best_time_label: Label = $Root/BestTimeLabel
@onready var medal_label: Label = $Root/MedalLabel
@onready var dive_label: Label = $Root/DiveLabel
@onready var rank_label: Label = $Root/RankLabel
@onready var progress_bar: ProgressBar = $Root/ProgressBar
@onready var countdown_label: Label = $Root/CountdownLabel
@onready var results_panel: PanelContainer = $Root/ResultsPanel
@onready var results_title: Label = $Root/ResultsPanel/VBox/Title
@onready var results_time: Label = $Root/ResultsPanel/VBox/ResultsTime
@onready var results_best: Label = $Root/ResultsPanel/VBox/ResultsBest
@onready var results_medal: Label = $Root/ResultsPanel/VBox/ResultsMedal
@onready var results_rank: Label = $Root/ResultsPanel/VBox/ResultsRank
@onready var results_coins: Label = $Root/ResultsPanel/VBox/ResultsCoins
@onready var results_coin_breakdown: Label = $Root/ResultsPanel/VBox/ResultsCoinBreakdown
@onready var retry_button: Button = $Root/ResultsPanel/VBox/Buttons/RetryButton
@onready var next_round_button: Button = $Root/ResultsPanel/VBox/Buttons/NextRoundButton
@onready var menu_button: Button = $Root/ResultsPanel/VBox/Buttons/MenuButton
@onready var tutorial_panel: PanelContainer = $Root/TutorialPanel
@onready var tutorial_button: Button = $Root/TutorialPanel/VBox/TutorialButton

var _manager: Node
var _director: Node
var _player: Node3D
var _level_info: LevelInfo
var _start_z: float = START_Z
var _finish_z: float = FINISH_Z
var _results_shown: bool = false
var _qualified: bool = true
var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	message_label.text = ""
	checkpoints_label.text = "0/0"
	best_time_label.text = "Récord: --"
	medal_label.text = "Oro ≤ %.1f s" % SaveManager.medal_target("gold")
	rank_label.text = ""
	results_panel.hide()
	countdown_label.hide()
	tutorial_panel.hide()
	progress_bar.value = 0.0
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	next_round_button.pressed.connect(_on_next_round_pressed)
	tutorial_button.pressed.connect(_on_tutorial_closed)

	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group("race_manager")
	_director = get_tree().get_first_node_in_group("race_director")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_level_info = get_tree().get_first_node_in_group("level_info") as LevelInfo
	if _level_info != null:
		_start_z = _level_info.start_z
		_finish_z = _level_info.finish_z
		medal_label.text = "Oro ≤ %.1f s" % _level_info.gold_time
	_connect_manager()
	_connect_director()
	if not _headless and not SaveManager.has_seen_tutorial():
		tutorial_panel.show()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var span := maxf(_start_z - _finish_z, 0.01)
	var progress := clampf((_start_z - _player.global_position.z) / span, 0.0, 1.0)
	progress_bar.value = progress * 100.0
	_update_dive()


## Shows the dive cooldown so the player knows when the slide is ready again.
func _update_dive() -> void:
	if not _player.has_method("dive_cooldown_remaining"):
		return
	var remaining := float(_player.call("dive_cooldown_remaining"))
	if remaining > 0.05:
		dive_label.text = "Deslizar en %.1f s" % remaining
		dive_label.modulate = Color(1.0, 1.0, 1.0, 0.5)
	else:
		dive_label.text = "Deslizar listo"
		dive_label.modulate = Color(0.7, 1.0, 0.75, 0.95)


func _connect_manager() -> void:
	if _manager == null:
		return
	if _manager.has_signal("time_updated"):
		_manager.time_updated.connect(_on_time_updated)
	if _manager.has_signal("finished"):
		_manager.finished.connect(_on_finished)
	if _manager.has_signal("respawned"):
		_manager.respawned.connect(_on_respawned)
	if _manager.has_signal("checkpoint_reached"):
		_manager.checkpoint_reached.connect(_on_checkpoint)
	if _manager.has_signal("checkpoints_updated"):
		_manager.checkpoints_updated.connect(_on_checkpoints_updated)
	if _manager.has_signal("best_time_updated"):
		_manager.best_time_updated.connect(_on_best_time_updated)
	if _manager.has_signal("split_reached"):
		_manager.split_reached.connect(_on_split)
	if _manager.has_signal("countdown_tick"):
		_manager.countdown_tick.connect(_on_countdown_tick)
	if _manager.has_signal("results_ready"):
		_manager.results_ready.connect(_on_results_ready)
	# Sync state emitted before the HUD connected.
	if "best_time" in _manager and _manager.best_time > 0.0:
		_on_best_time_updated(_manager.best_time)
	if "checkpoints_total" in _manager and _manager.checkpoints_total > 0:
		_on_checkpoints_updated(_manager.checkpoints_completed, _manager.checkpoints_total)


func _connect_director() -> void:
	if _director == null:
		return
	if _director.has_signal("rank_updated"):
		_director.rank_updated.connect(_on_rank_updated)
	if _director.has_signal("qualification_result"):
		_director.qualification_result.connect(_on_qualification_result)


func _on_time_updated(elapsed: float) -> void:
	time_label.text = "%.2f s" % elapsed


func _on_finished(final_time: float) -> void:
	time_label.text = "%.2f s" % final_time


func _on_respawned(penalty: float) -> void:
	message_label.text = "+%.1f s  (caída)" % penalty
	message_label.modulate = Color(1.0, 0.45, 0.55)
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree():
		return
	if message_label.text.begins_with("+"):
		message_label.text = ""


func _on_checkpoint(checkpoint_name: String) -> void:
	message_label.text = checkpoint_name
	message_label.modulate = Color(0.4, 1.0, 0.55)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if message_label.text == checkpoint_name:
		message_label.text = ""


func _on_split(checkpoint_name: String, split_time: float, delta: float) -> void:
	var suffix := ""
	if not is_zero_approx(delta):
		suffix = "  (%+.2f)" % delta
	message_label.text = "%s  %.2f s%s" % [checkpoint_name, split_time, suffix]
	message_label.modulate = Color(0.55, 1.0, 0.65) if delta <= 0.0 else Color(1.0, 0.75, 0.4)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	if message_label.text.begins_with(checkpoint_name):
		message_label.text = ""


func _on_checkpoints_updated(completed: int, total: int) -> void:
	checkpoints_label.text = "%d/%d" % [completed, total]


func _on_best_time_updated(time: float) -> void:
	if time <= 0.0:
		best_time_label.text = "Récord: --"
	else:
		best_time_label.text = "Récord: %.2f s" % time


func _on_countdown_tick(value: int) -> void:
	countdown_label.show()
	if value > 0:
		countdown_label.text = str(value)
	else:
		countdown_label.text = "¡YA!"
	countdown_label.pivot_offset = countdown_label.size * 0.5
	countdown_label.scale = Vector2(1.6, 1.6)
	countdown_label.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if value == 0:
		tween.tween_property(countdown_label, "modulate:a", 0.0, 0.25).set_delay(0.3)
		tween.tween_callback(countdown_label.hide)


func _on_rank_updated(rank: int, total: int) -> void:
	if GameSession.is_tournament():
		rank_label.text = "Ronda %d/%d · Puesto %d/%d" % [
			GameSession.round, GameSession.total_rounds(), rank, total]
	else:
		rank_label.text = "Puesto %d/%d" % [rank, total]


func _on_qualification_result(qualified: bool, rank: int, qualifiers: int) -> void:
	_qualified = qualified
	var total := int(_director.total_racers if _director else 0)
	if GameSession.is_tournament():
		rank_label.text = "Ronda %d/%d · Puesto %d/%d  ·  %s" % [
			GameSession.round, GameSession.total_rounds(), rank, total,
			"CLASIFICADO" if qualified else "ELIMINADO"]
	else:
		rank_label.text = "Puesto %d/%d  ·  %s" % [rank, total, "CLASIFICADO" if qualified else "ELIMINADO"]
	if results_rank:
		results_rank.text = "Puesto %d de %d · clasifican %d" % [rank, total, qualifiers]


func _on_results_ready(data: Dictionary) -> void:
	if _results_shown:
		return
	_results_shown = true
	message_label.text = ""
	var time := float(data.get("time", 0.0))
	var best := float(data.get("best", 0.0))
	var medal := String(data.get("medal", "none"))
	var new_best := bool(data.get("new_best", false))

	results_time.text = "Tiempo: %.2f s" % time
	if new_best:
		results_best.text = "Récord: %.2f s  ·  ¡NUEVO!" % best
	else:
		results_best.text = "Récord: %.2f s" % best
	results_medal.text = "Medalla: %s" % SaveManager.medal_label(medal)
	results_medal.modulate = _medal_color(medal)

	var falls := int(data.get("falls", 0))
	results_coins.text = "+%d monedas (total %d)   ·   %d caída(s)" % [
		int(data.get("coins", 0)), int(data.get("coins_total", 0)), falls
	]
	if results_coin_breakdown != null:
		var breakdown: Dictionary = data.get("coins_breakdown", {})
		results_coin_breakdown.text = _coin_breakdown_text(breakdown)
		results_coin_breakdown.visible = not results_coin_breakdown.text.is_empty()

	var is_bot_race := GameSession.is_bot_race()
	var final_round := bool(data.get("final_round", false))
	var round_number := int(data.get("round", GameSession.round))
	var total_rounds := int(data.get("total_rounds", GameSession.total_rounds()))
	if is_bot_race:
		var rank := 0
		var total := 0
		if _director:
			rank = int(_director.get("player_rank"))
			total = int(_director.get("total_racers"))
		if final_round and _qualified:
			results_title.text = "¡CAMPEÓN!"
			results_title.modulate = Color(1, 0.9, 0.3)
		elif _qualified:
			results_title.text = "¡META!"
			results_title.modulate = Color(1, 0.92, 0.4)
		else:
			results_title.text = "¡ELIMINADO!"
			results_title.modulate = Color(1, 0.45, 0.45)
		var state := "CLASIFICADO" if _qualified else "ELIMINADO"
		if final_round and _qualified:
			state = "CAMPEÓN DEL TORNEO"
		if rank > 0 and total > 0:
			results_rank.text = "Ronda %d/%d · Puesto %d de %d · %s" % [round_number, total_rounds, rank, total, state]
		else:
			results_rank.text = "Ronda %d/%d · %s" % [round_number, total_rounds, state]
		next_round_button.visible = GameSession.is_tournament() and _qualified and not final_round
	else:
		results_title.text = "¡META!"
		results_title.modulate = Color(1, 0.92, 0.4)
		results_rank.text = ""
		next_round_button.visible = false

	# La carrera termina: suena la fanfarria de meta mientras se lee el
	# resultado. Cambiar de escena o reintentar la corta.
	AudioManager.play_victory()
	results_panel.show()
	results_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(results_panel, "modulate:a", 1.0, 0.3)


## Desglose de la recompensa: "Base 10 · Tiempo 24 · Puesto 1º 40 · Medalla 40".
func _coin_breakdown_text(breakdown: Dictionary) -> String:
	if breakdown.is_empty():
		return ""
	var parts: Array[String] = ["Base %d" % int(breakdown.get("base", 0))]
	var time_coins := int(breakdown.get("time", 0))
	if time_coins > 0:
		parts.append("Tiempo %d" % time_coins)
	var place := int(breakdown.get("place", 0))
	var place_coins := int(breakdown.get("position", 0))
	if place > 0 and place_coins > 0:
		parts.append("Puesto %dº %d" % [place, place_coins])
	var medal_coins := int(breakdown.get("medal", 0))
	if medal_coins > 0:
		parts.append("Medalla %d" % medal_coins)
	return "  ·  ".join(parts)


func _medal_color(medal: String) -> Color:
	match medal:
		"gold":
			return Color(1.0, 0.85, 0.25)
		"silver":
			return Color(0.82, 0.88, 1.0)
		"bronze":
			return Color(0.95, 0.62, 0.35)
		_:
			return Color(0.75, 0.78, 0.85)


func _on_tutorial_closed() -> void:
	SaveManager.mark_tutorial_seen()
	AudioManager.play_sfx("ui", 0.05)
	tutorial_panel.hide()


func _on_retry_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	get_tree().paused = false
	TransitionManager.change_scene(get_tree().current_scene.scene_file_path)


func _on_next_round_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	get_tree().paused = false
	GameSession.advance_round()
	TransitionManager.change_scene(GameSession.level_path)


func _on_menu_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	get_tree().paused = false
	GameSession.reset()
	TransitionManager.change_scene("res://scenes/menu/main_menu.tscn")
