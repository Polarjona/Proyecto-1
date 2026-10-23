extends CanvasLayer

## HUD: cronómetro, récord, medalla, coronas, progreso, cuenta atrás,
## ranking de bots, pantalla de resultados y tutorial de primera vez.

const START_Z := 5.0
const FINISH_Z := -205.0

@onready var time_label: Label = $Root/TimeLabel
@onready var message_label: Label = $Root/MessageLabel
@onready var checkpoints_label: Label = $Root/CheckpointsLabel
@onready var best_time_label: Label = $Root/BestTimeLabel
@onready var medal_label: Label = $Root/MedalLabel
@onready var crowns_label: Label = $Root/CrownsLabel
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
@onready var retry_button: Button = $Root/ResultsPanel/VBox/Buttons/RetryButton
@onready var next_round_button: Button = $Root/ResultsPanel/VBox/Buttons/NextRoundButton
@onready var menu_button: Button = $Root/ResultsPanel/VBox/Buttons/MenuButton
@onready var tutorial_panel: PanelContainer = $Root/TutorialPanel
@onready var tutorial_button: Button = $Root/TutorialPanel/VBox/TutorialButton

var _manager: Node
var _director: Node
var _player: Node3D
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
	SaveManager.crown_collected.connect(_on_crown_collected)

	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group("race_manager")
	_director = get_tree().get_first_node_in_group("race_director")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_connect_manager()
	_connect_director()
	_update_crowns(SaveManager.total_crowns())
	if not _headless and not SaveManager.has_seen_tutorial():
		tutorial_panel.show()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var progress := clampf((START_Z - _player.global_position.z) / (START_Z - FINISH_Z), 0.0, 1.0)
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
	rank_label.text = "Puesto %d/%d" % [rank, total]


func _on_qualification_result(qualified: bool, rank: int, qualifiers: int) -> void:
	_qualified = qualified
	if _director and "total_racers" in _director:
		_on_rank_updated(rank, int(_director.total_racers))
	rank_label.text = "Puesto %d/%d  ·  %s" % [rank, int(_director.total_racers if _director else 0), "CLASIFICADO" if qualified else "ELIMINADO"]
	if results_rank:
		results_rank.text = "Puesto %d de %d · clasifican %d" % [rank, int(_director.total_racers if _director else 0), qualifiers]


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

	var is_bot_race := GameSession.is_bot_race()
	if is_bot_race:
		var rank := 0
		var total := 0
		if _director:
			rank = int(_director.get("player_rank"))
			total = int(_director.get("total_racers"))
		results_title.text = "¡META!" if _qualified else "¡ELIMINADO!"
		results_title.modulate = Color(1, 0.92, 0.4) if _qualified else Color(1, 0.45, 0.45)
		if rank > 0 and total > 0:
			results_rank.text = "Puesto %d de %d · %s" % [rank, total, "CLASIFICADO" if _qualified else "ELIMINADO"]
		else:
			results_rank.text = "Clasificado" if _qualified else "Eliminado"
		next_round_button.visible = GameSession.is_tournament() and _qualified
	else:
		results_title.text = "¡META!"
		results_title.modulate = Color(1, 0.92, 0.4)
		results_rank.text = ""
		next_round_button.visible = false

	results_panel.show()
	results_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(results_panel, "modulate:a", 1.0, 0.3)


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


func _update_crowns(_total: int) -> void:
	var crowns := get_tree().get_nodes_in_group("crowns")
	var total := crowns.size()
	if total == 0:
		total = 3
	crowns_label.text = "Coronas %d/%d" % [SaveManager.total_crowns(), total]


func _on_crown_collected(_total: int) -> void:
	_update_crowns(_total)
	message_label.text = "¡Corona!"
	message_label.modulate = Color(1.0, 0.9, 0.35)


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
	TransitionManager.change_scene("res://scenes/main.tscn")


func _on_menu_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	get_tree().paused = false
	GameSession.reset()
	TransitionManager.change_scene("res://scenes/menu/main_menu.tscn")
