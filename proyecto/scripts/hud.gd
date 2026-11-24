extends CanvasLayer

## HUD: cronómetro, récord, medalla, progreso, cuenta atrás, ranking de
## bots, pantalla de resultados y tutorial de primera vez.

## Se precarga para que el exportador incluya la guía aunque se instancie en
## runtime después de cerrar el tutorial.
const TUTORIAL_GUIDE := preload("res://scripts/tutorial_guide.gd")

var _manager: RaceManager

var _director: Node

var _player: Node3D

var _level_info: LevelInfo

# Los rellena el `LevelInfo` del circuito en `_ready`: cada mapa mide distinto.
var _start_z: float = 0.0

var _finish_z: float = 0.0

var _results_shown: bool = false

var _qualified: bool = true

var _headless: bool = false

## Último idioma pintado: los valores con `tr()` se regeneran al cambiarlo.
var _locale: String = ""

var _tutorial_paused: bool = false

## Último aviso de la guía, para no borrar un mensaje de checkpoint encima.
var _guide_prompt: String = ""

@onready var time_label: Label = $Root/TimeLabel

@onready var message_label: Label = $Root/MessageLabel

@onready var checkpoints_label: Label = $Root/TopLeftChip/HBox/CheckpointsLabel

@onready var checkpoints_chip: PanelContainer = $Root/TopLeftChip

@onready var rank_chip: PanelContainer = $Root/RankChip

@onready var top_right_chip: PanelContainer = $Root/TopRightChip

@onready var best_time_label: Label = $Root/TopRightChip/HBox/BestTimeLabel

@onready var medal_label: Label = $Root/TopRightChip/HBox/MedalLabel

@onready var rank_label: Label = $Root/RankChip/HBox/RankLabel

@onready var progress_bar: ProgressBar = $Root/ProgressBar

@onready var progress_ticks: Control = $Root/ProgressTicks

@onready var progress_marker: Control = $Root/ProgressMarker

@onready var progress_goal: Control = $Root/ProgressGoal

@onready var countdown_label: Label = $Root/CountdownLabel

@onready var results_panel: PanelContainer = $Root/ResultsPanel

@onready var results_title: Label = $Root/ResultsPanel/VBox/Title

@onready var results_time: Label = $Root/ResultsPanel/VBox/ResultsTime

@onready var results_best: Label = $Root/ResultsPanel/VBox/ResultsBest

@onready var results_medal_chip: PanelContainer = $Root/ResultsPanel/VBox/ResultsMedalChip

@onready var results_medal: Label = $Root/ResultsPanel/VBox/ResultsMedalChip/ResultsMedal

@onready var results_reason: Label = $Root/ResultsPanel/VBox/ResultsReason

@onready var results_rank: Label = $Root/ResultsPanel/VBox/ResultsRank

@onready var results_coins: Label = $Root/ResultsPanel/VBox/ResultsCoins

@onready var results_falls: Label = $Root/ResultsPanel/VBox/ResultsFalls

@onready var results_coin_breakdown: Label = $Root/ResultsPanel/VBox/ResultsCoinBreakdown

@onready var time_caption: Label = $Root/ResultsPanel/VBox/TimeCaption

@onready var retry_button: Button = $Root/ResultsPanel/VBox/Buttons/RetryButton

@onready var next_round_button: Button = $Root/ResultsPanel/VBox/Buttons/NextRoundButton

@onready var menu_button: Button = $Root/ResultsPanel/VBox/Buttons/MenuButton

@onready var tutorial_panel: PanelContainer = $Root/TutorialPanel

@onready var tutorial_button: Button = $Root/TutorialPanel/VBox/TutorialButton

@onready var scrim: ColorRect = $Root/Scrim


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	add_to_group("hud")
	UITheme.apply($Root)
	message_label.text = ""
	checkpoints_label.text = tr("CP %d/%d") % [0, 0]
	checkpoints_label.visible = false
	checkpoints_chip.visible = false
	best_time_label.text = tr("Récord: --")
	medal_label.text = tr("Oro ≤ --")
	rank_label.text = ""
	rank_chip.visible = false
	results_medal_chip.hide()
	results_reason.hide()
	time_caption.show()
	_update_progress(0.0)
	results_panel.hide()
	scrim.hide()
	countdown_label.hide()
	tutorial_panel.hide()
	tutorial_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	progress_bar.value = 0.0
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	next_round_button.pressed.connect(_on_next_round_pressed)
	tutorial_button.pressed.connect(_on_tutorial_closed)

	await get_tree().process_frame
	_manager = get_tree().get_first_node_in_group("race_manager") as RaceManager
	_director = get_tree().get_first_node_in_group("race_director")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_level_info = get_tree().get_first_node_in_group("level_info") as LevelInfo
	if _level_info != null:
		_start_z = _level_info.start_z
		_finish_z = _level_info.finish_z
		medal_label.text = tr("Oro ≤ %s") % _format_threshold(_level_info.gold_time)
		_build_progress_ticks()
	_connect_manager()
	_connect_director()
	_locale = TranslationServer.get_locale()
	SaveManager.settings_changed.connect(_on_settings_changed)
	if not _headless and not SaveManager.has_seen_tutorial():
		_show_tutorial()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	_update_progress(_progress())


## La barra mide el avance real del recorrido. En los circuitos con ruta propia
## (la espiral del volcán vuelve sobre sus pasos) la Z no sirve: se pregunta al
## LevelInfo, que mide por waypoint, igual que la clasificación en vivo.
func _progress() -> float:
	if _level_info != null:
		return _level_info.progress_at(_player.global_position)
	var span := maxf(_start_z - _finish_z, 0.01)
	return clampf((_start_z - _player.global_position.z) / span, 0.0, 1.0)


## Un solo formato para los tiempos: dos decimales y la unidad. Los umbrales
## de medalla son segundos enteros y no deben mezclarse con los récords.
func _format_time(seconds: float) -> String:
	return "%.2f s" % seconds


func _format_threshold(seconds: float) -> String:
	return "%.0f s" % seconds


## La barra lleva la meta al final y un tick por checkpoint. Los ticks se
## colocan con `progress_at`, no con la Z: la espiral del volcán vuelve sobre
## sus pasos y una barra lineal mentiría.
func _build_progress_ticks() -> void:
	for child in progress_ticks.get_children():
		progress_ticks.remove_child(child)
		child.queue_free()
	if _level_info == null:
		return
	var width := progress_bar.size.x
	if width <= 0.0:
		width = 560.0
	var height := progress_bar.size.y
	if height <= 0.0:
		height = 18.0
	for node in get_tree().get_nodes_in_group("checkpoints"):
		var point := clampf(_level_info.progress_at((node as Node3D).global_position), 0.0, 1.0)
		var tick := ColorRect.new()
		tick.color = Color(UITheme.CREAM, 0.38)
		tick.size = Vector2(2.0, 8.0)
		tick.position = Vector2(
			clampf(point * width - 1.0, 0.0, width - 2.0), (height - 8.0) * 0.5
		)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress_ticks.add_child(tick)


func _update_progress(progress: float) -> void:
	var value := clampf(progress, 0.0, 1.0)
	progress_bar.value = value * 100.0
	var width := progress_bar.size.x
	if width <= 0.0:
		width = 560.0
	progress_marker.offset_left = -width * 0.5 + value * width - 5.0
	progress_marker.offset_right = progress_marker.offset_left + 10.0


func _connect_manager() -> void:
	if _manager == null:
		return
	_manager.time_updated.connect(_on_time_updated)
	_manager.finished.connect(_on_finished)
	_manager.respawned.connect(_on_respawned)
	_manager.checkpoint_reached.connect(_on_checkpoint)
	_manager.checkpoints_updated.connect(_on_checkpoints_updated)
	_manager.best_time_updated.connect(_on_best_time_updated)
	_manager.split_reached.connect(_on_split)
	_manager.countdown_tick.connect(_on_countdown_tick)
	_manager.results_ready.connect(_on_results_ready)
	_manager.failed.connect(_on_failed)
	# Sync state emitted before the HUD connected.
	if _manager.best_time > 0.0:
		_on_best_time_updated(_manager.best_time)
	if _manager.checkpoints_total > 0:
		_on_checkpoints_updated(_manager.checkpoints_completed, _manager.checkpoints_total)


func _connect_director() -> void:
	if _director == null:
		return
	if _director.has_signal("rank_updated"):
		_director.rank_updated.connect(_on_rank_updated)
	if _director.has_signal("qualification_result"):
		_director.qualification_result.connect(_on_qualification_result)


func _on_time_updated(elapsed: float) -> void:
	time_label.text = _format_time(elapsed)


func _on_finished(final_time: float) -> void:
	time_label.text = _format_time(final_time)


func _on_respawned(penalty: float) -> void:
	message_label.text = tr("+%s s  (caída)") % ("%.1f" % penalty)
	message_label.modulate = Color(1.0, 0.45, 0.55)
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree():
		return
	if message_label.text.begins_with("+"):
		message_label.text = ""


func _on_checkpoint(checkpoint_name: String) -> void:
	var text := tr(checkpoint_name)
	message_label.text = text
	message_label.modulate = UITheme.CYAN
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if message_label.text == text:
		message_label.text = ""


func _on_split(checkpoint_name: String, split_time: float, delta: float) -> void:
	var suffix := ""
	if not is_zero_approx(delta):
		suffix = "  (%+.2f)" % delta
	var text := tr("%s  %s s%s") % [tr(checkpoint_name), "%.2f" % split_time, suffix]
	message_label.text = text
	message_label.modulate = UITheme.CYAN if delta <= 0.0 else Color(UITheme.CREAM, 0.9)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	if message_label.text == text:
		message_label.text = ""


func _on_checkpoints_updated(completed: int, total: int) -> void:
	# La final del volcán no tiene checkpoints: se oculta el contador en vez de
	# dejar un "0/0" en pantalla.
	checkpoints_label.visible = total > 0
	checkpoints_chip.visible = total > 0
	if total > 0:
		checkpoints_label.text = tr("CP %d/%d") % [completed, total]
		if progress_ticks.get_child_count() == 0:
			_build_progress_ticks()


func _on_best_time_updated(time: float) -> void:
	if time <= 0.0:
		best_time_label.text = tr("Récord: --")
	else:
		best_time_label.text = tr("Récord: %s") % _format_time(time)


## El idioma se puede cambiar desde la pausa: los textos ya formateados no
## se traducen solos, así que se vuelven a construir.
func _on_settings_changed() -> void:
	var locale := TranslationServer.get_locale()
	if locale == _locale:
		return
	_locale = locale
	if _level_info != null:
		medal_label.text = tr("Oro ≤ %s") % _format_threshold(_level_info.gold_time)
	if _manager != null:
		_on_best_time_updated(_manager.best_time)


func _on_countdown_tick(value: int) -> void:
	countdown_label.show()
	if value > 0:
		countdown_label.text = str(value)
	else:
		countdown_label.text = tr("¡YA!")
	countdown_label.pivot_offset = countdown_label.size * 0.5
	countdown_label.scale = Vector2(1.6, 1.6)
	countdown_label.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	(
		tween
		. tween_property(countdown_label, "scale", Vector2.ONE, 0.22)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	if value == 0:
		tween.tween_property(countdown_label, "modulate:a", 0.0, 0.25).set_delay(0.3)
		tween.tween_callback(countdown_label.hide)


func _on_rank_updated(rank: int, total: int) -> void:
	# El puesto solo se retransmite en torneo; en clásico el cronómetro manda.
	if _results_shown or not GameSession.is_tournament():
		rank_chip.visible = false
		return
	rank_label.text = (
		tr("Ronda %d/%d · %d.º/%d")
		% [GameSession.round, GameSession.total_rounds(), rank, total]
	)
	rank_chip.visible = true


func _on_qualification_result(qualified: bool, rank: int, qualifiers: int) -> void:
	_qualified = qualified
	if _results_shown or not GameSession.is_tournament():
		rank_chip.visible = false
		return
	var total := int(_director.total_racers if _director else 0)
	var state := tr("CLASIFICADO") if qualified else tr("ELIMINADO")
	rank_label.text = (
		tr("Ronda %d/%d · %d.º/%d · %s")
		% [GameSession.round, GameSession.total_rounds(), rank, total, state]
	)
	if results_rank:
		results_rank.text = tr("%d.º de %d · %s") % [rank, total, state]
	rank_chip.visible = true


func _on_results_ready(data: Dictionary) -> void:
	if _results_shown:
		return
	_results_shown = true
	message_label.text = ""
	var time := float(data.get("time", 0.0))
	var best := float(data.get("best", 0.0))
	var medal := String(data.get("medal", "none"))
	var new_best := bool(data.get("new_best", false))
	var is_tournament := GameSession.is_tournament()

	# El tiempo es el héroe: 64 px, sin prefijo. El récord deja de repetirlo:
	# cuando es nuevo, se anuncia como sello y no como una segunda cifra.
	results_panel.offset_top = -310.0
	results_panel.offset_bottom = 310.0
	_hide_hud_chrome()
	time_caption.show()
	results_time.show()
	results_time.text = _format_time(time)
	results_time.modulate = Color(1, 1, 1, 1)
	results_best.show()
	results_best.modulate = Color(1, 1, 1, 1)
	results_best.text = (
		tr("NUEVO RÉCORD") if new_best else (tr("Récord: %s") % _format_time(best))
	)
	results_reason.hide()
	results_medal_chip.show()
	results_medal.text = tr(SaveManager.medal_label(medal))
	_style_medal_chip(medal)

	var falls := int(data.get("falls", 0))
	var fall_text := (
		tr("sin caídas")
		if falls == 0
		else (tr("1 caída") if falls == 1 else tr("%d caídas") % falls)
	)
	results_coins.show()
	results_coins.text = "+%s" % _coins_text(int(data.get("coins", 0)))
	results_falls.show()
	results_falls.text = (
		tr("Total %s · %s")
		% [_coins_text(int(data.get("coins_total", 0))), fall_text]
	)
	if results_coin_breakdown != null:
		var breakdown: Dictionary = data.get("coins_breakdown", {})
		results_coin_breakdown.text = _coin_breakdown_text(breakdown)
		results_coin_breakdown.visible = not results_coin_breakdown.text.is_empty()

	results_rank.remove_theme_font_size_override("font_size")
	results_rank.modulate = Color(1, 1, 1, 1)
	var final_round := bool(data.get("final_round", false))
	if is_tournament:
		var rank := 0
		var total := 0
		if _director:
			rank = int(_director.get("player_rank"))
			total = int(_director.get("total_racers"))
		if final_round and _qualified:
			results_title.text = tr("¡CAMPEÓN!")
			results_title.modulate = Color(1, 0.9, 0.3)
		elif _qualified:
			results_title.text = tr("¡META!")
			results_title.modulate = Color(1, 1, 1, 1)
		else:
			results_title.text = tr("¡ELIMINADO!")
			results_title.modulate = Color(1, 0.45, 0.45)
		var state := tr("CLASIFICADO") if _qualified else tr("ELIMINADO")
		if final_round and _qualified:
			state = tr("CAMPEÓN")
		if rank > 0 and total > 0:
			results_rank.text = tr("%d.º de %d · %s") % [rank, total, state]
			results_rank.show()
		else:
			results_rank.hide()
		next_round_button.visible = _qualified and not final_round
	else:
		results_title.text = tr("¡META!")
		results_title.modulate = Color(1, 1, 1, 1)
		results_rank.text = ""
		results_rank.hide()
		next_round_button.visible = false

	menu_button.text = tr("MENÚ")
	retry_button.visible = true
	# La carrera termina: suena la fanfarria de meta mientras se lee el
	# resultado. Cambiar de escena o reintentar la corta.
	AudioManager.play_victory()
	scrim.show()
	results_panel.show()
	results_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(results_panel, "modulate:a", 1.0, 0.3)


## Derrota en la final del volcán: la lava o el vacío acaban la carrera. El
## panel deja reintentar en el sitio o volver al lobby, sin estadísticas de meta.
func _on_failed(reason: String) -> void:
	if _results_shown:
		return
	_results_shown = true
	message_label.text = ""
	countdown_label.hide()
	results_panel.offset_top = -200.0
	results_panel.offset_bottom = 200.0
	_hide_hud_chrome()
	results_title.text = tr("¡HAS PERDIDO!")
	results_title.modulate = Color(1.0, 0.42, 0.34)
	results_reason.text = (
		"%s\n%s"
		% [
			tr("La lava te alcanzó") if reason == "lava" else tr("Caíste al vacío"),
			tr("Pulsa REINTENTAR para volver a la salida."),
		]
	)
	results_reason.show()
	var elapsed := _manager.elapsed_time if _manager != null else 0.0
	time_caption.hide()
	results_time.hide()
	results_best.show()
	results_best.text = tr("Tiempo: %s") % _format_time(elapsed)
	results_best.modulate = Color(1, 1, 1, 0.78)
	results_medal_chip.hide()
	results_rank.hide()
	results_rank.text = ""
	results_coins.hide()
	results_falls.hide()
	results_coin_breakdown.hide()
	# Perder no debe costar volver a navegar el menu: se puede reintentar en el sitio.
	retry_button.visible = true
	next_round_button.visible = false
	menu_button.text = tr("VOLVER AL LOBBY")
	scrim.show()
	results_panel.show()
	results_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(results_panel, "modulate:a", 1.0, 0.3)
	AudioManager.play_sfx("fall")
	AudioManager.stop_music()
	GameFeel.flash(Color(1.0, 0.3, 0.05), 0.45)
	GameFeel.shake(3.0)


func _coins_text(amount: int) -> String:
	return tr("%d moneda") % amount if amount == 1 else tr("%d monedas") % amount


## Recibo de la recompensa, una línea por concepto: base, tiempo, puesto y
## medalla. Se lee debajo del hairline, no como una frase de desarrollo.
## Al abrirse la segunda pantalla, el HUD se retira: el tiempo del panel es el
## único protagonista sobre el fotograma de meta.
func _hide_hud_chrome() -> void:
	time_label.hide()
	message_label.hide()
	checkpoints_chip.hide()
	top_right_chip.hide()
	rank_chip.hide()
	progress_bar.hide()
	progress_ticks.hide()
	progress_marker.hide()
	progress_goal.hide()


func _coin_breakdown_text(breakdown: Dictionary) -> String:
	if breakdown.is_empty():
		return ""
	var parts: Array[String] = [tr("Base %d") % int(breakdown.get("base", 0))]
	var time_coins := int(breakdown.get("time", 0))
	if time_coins > 0:
		parts.append(tr("Tiempo %d") % time_coins)
	var place := int(breakdown.get("place", 0))
	var place_coins := int(breakdown.get("position", 0))
	if place > 0 and place_coins > 0:
		parts.append(tr("Puesto %dº %d") % [place, place_coins])
	var medal_coins := int(breakdown.get("medal", 0))
	if medal_coins > 0:
		parts.append(tr("Medalla %d") % medal_coins)
	return "\n".join(parts)


func _style_medal_chip(medal: String) -> void:
	var color := _medal_color(medal)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.14)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(color, 0.55)
	box.corner_radius_top_left = 18
	box.corner_radius_top_right = 18
	box.corner_radius_bottom_right = 18
	box.corner_radius_bottom_left = 18
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	results_medal_chip.add_theme_stylebox_override("panel", box)
	results_medal.add_theme_color_override("font_color", color)


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


## El tutorial se lee con el juego congelado: antes corría el cronómetro y el
## panel tapaba la salida. Al cerrarlo se devuelve el control al jugador.
func _show_tutorial() -> void:
	scrim.show()
	tutorial_panel.show()
	get_tree().paused = true
	_tutorial_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tutorial_button.grab_focus()


func is_tutorial_open() -> bool:
	return tutorial_panel.visible


## Avisos del tramo guiado (las flechas 3D del tutorial).
func show_tutorial_prompt(text: String) -> void:
	_guide_prompt = tr(text)
	message_label.text = _guide_prompt
	message_label.modulate = Color(1.0, 1.0, 1.0, 0.95)


func clear_tutorial_prompt() -> void:
	if message_label.text == _guide_prompt:
		message_label.text = ""
	_guide_prompt = ""


func _on_tutorial_closed() -> void:
	SaveManager.mark_tutorial_seen()
	AudioManager.play_sfx("ui", 0.05)
	tutorial_panel.hide()
	scrim.hide()
	if _tutorial_paused:
		_tutorial_paused = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_tutorial_guide()


## Solo en la primera partida de Pivot Push: el resto de circuitos ya no son
## "el tramo de aprendizaje" y no deben llenarse de flechas.
func _start_tutorial_guide() -> void:
	if _headless or _player == null or _level_info == null:
		return
	if String(_level_info.level_id) != "pivot_push":
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var guide := TUTORIAL_GUIDE.new() as Node3D
	scene.add_child(guide)
	guide.call("setup", _player, _level_info)
	guide.call("start")


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
