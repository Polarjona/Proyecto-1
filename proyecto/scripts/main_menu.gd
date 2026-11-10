extends Control

## Lobby principal: escaparate 3D del corredor, tarjeta de temporada, monedas y
## un botón JUGAR que abre la elección de modo (carrera clásica o torneo con
## bots). Desde aquí también se abre el submenú Personaje, donde se compran los
## corredores bloqueados con las monedas ganadas.

@onready var classic_card: Button = $ModePanel/VBox/ClassicCard
@onready var tournament_card: Button = $ModePanel/VBox/TournamentCard
@onready var mode_panel: Control = $ModePanel
@onready var mode_back_button: Button = $ModePanel/VBox/Header/ModeBackButton
@onready var play_button: Button = $PlayButton
@onready var quit_button: Button = $TopBar/HBox/QuitButton
@onready var scrim: ColorRect = $Scrim
@onready var top_bar: Control = $TopBar
@onready var season_card: PanelContainer = $SeasonCard
@onready var player_badge: PanelContainer = $PlayerBadge
@onready var character_button: Button = $TopBar/HBox/NavRow/CharacterButton
@onready var settings_button: Button = $TopBar/HBox/NavRow/SettingsButton
@onready var controls_button: Button = $TopBar/HBox/NavRow/ControlsButton
@onready var credits_button: Button = $TopBar/HBox/NavRow/CreditsButton
@onready var controls_panel: Control = $ControlsPanel
@onready var credits_panel: Control = $CreditsPanel
@onready var character_panel: Control = $CharacterPanel
@onready var character_back_button: Button = $CharacterPanel/VBox/Header/BackButton
@onready var best_time_label: Label = $SeasonCard/VBox/BestTimeLabel
@onready var medal_label: Label = $SeasonCard/VBox/MedalLabel
@onready var season_progress: ProgressBar = $SeasonCard/VBox/LobbyProgress
@onready var season_progress_label: Label = $SeasonCard/VBox/LobbyProgressLabel
@onready var season_kicker: Label = $SeasonCard/VBox/SeasonKicker
@onready var controls_goal_label: Label = $ControlsPanel/VBoxContainer/GoalLabel
@onready var coins_label: Label = $TopBar/HBox/CoinsBadge/CoinsLabel
@onready var panel_coins_label: Label = $CharacterPanel/VBox/Header/PanelCoins
@onready var player_name_label: Label = $PlayerBadge/HBox/VBox/PlayerNameLabel
@onready var settings_menu = $SettingsMenu
@onready var lobby_stage: Node3D = $LobbyStage/SubViewport/Stage
@onready var lobby_camera: Camera3D = $LobbyStage/SubViewport/Camera3D
@onready var preview_stage: Node3D = $CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport/Stage
@onready var preview_camera: Camera3D = $CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport/Camera3D
@onready var selected_character_label: Label = $CharacterPanel/VBox/Body/PreviewBox/SelectedCharacterLabel
@onready var price_label: Label = $CharacterPanel/VBox/Body/PreviewBox/PriceLabel
@onready var buy_button: Button = $CharacterPanel/VBox/Body/PreviewBox/BuyButton
@onready var roster: GridContainer = $CharacterPanel/VBox/Body/RosterScroll/Roster

## Alto de cada tarjeta del roster, en píxeles. La cuadrícula de dos columnas
## permite que los diez personajes entren sin scroll.
const ROSTER_ROW_HEIGHT := 62.0

## Botones, avatares y etiquetas del roster, en el mismo orden que el catálogo.
var character_buttons: Array[Button] = []
var character_status: Array[Label] = []
var character_avatars: Array[PanelContainer] = []
var character_name_labels: Array[Label] = []
var _roster_group: ButtonGroup
@onready var level_buttons: Array[Button] = [
	$ModePanel/VBox/LevelPicker/LevelRow/Level1,
	$ModePanel/VBox/LevelPicker/LevelRow/Level2,
	$ModePanel/VBox/LevelPicker/LevelRow/Level3,
	$ModePanel/VBox/LevelPicker/LevelRow/Level4,
	$ModePanel/VBox/LevelPicker/LevelRow/Level5,
]

## Personaje que se está mirando en el panel (puede seguir bloqueado).
var _pending_id: String = ""
var _preview_model: Node3D
var _preview_id: String = ""
var _lobby_model: Node3D
var _lobby_id: String = ""


func _ready() -> void:
	# Un solo tema para todo el menú y para los paneles que se abren desde él.
	UITheme.apply(self)
	# Las cámaras apuntan al centro del cuerpo, no a la altura de la cabeza: el
	# escaparate del lobby y la vista previa tienen que enseñar al personaje
	# entero.
	# El encuadre incluye la peana entera: si apuntamos solo al cuerpo, la base
	# cian se corta por abajo.
	lobby_camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	preview_camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	_build_roster()
	_connect_buttons()
	_connect_character_buttons()
	mode_panel.hide()
	controls_panel.hide()
	credits_panel.hide()
	character_panel.hide()
	_refresh_lobby()
	_refresh_profile()
	_refresh_character_panel()
	_refresh_level_picker()
	play_button.grab_focus()
	# La música vive en el menú: la carrera la detiene al empezar y la fanfarria
	# de victoria la sustituye al cruzar la meta.
	AudioManager.play_music()


func _process(delta: float) -> void:
	if _lobby_model != null and is_instance_valid(_lobby_model):
		_lobby_model.rotate_y(delta * 0.42)
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.rotate_y(delta * 0.55)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if mode_panel.visible or controls_panel.visible or credits_panel.visible or character_panel.visible:
		get_viewport().set_input_as_handled()
		_close_panels()


func _connect_buttons() -> void:
	play_button.pressed.connect(_on_play_pressed)
	mode_back_button.pressed.connect(_close_panels)
	classic_card.pressed.connect(_on_classic_pressed)
	tournament_card.pressed.connect(_on_tournament_pressed)
	character_button.pressed.connect(_on_character_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	for i in level_buttons.size():
		level_buttons[i].pressed.connect(_on_level_selected.bind(i))
	character_back_button.pressed.connect(_close_panels)
	controls_panel.get_node("VBoxContainer/BackButton").pressed.connect(_close_panels)
	credits_panel.get_node("VBoxContainer/BackButton").pressed.connect(_close_panels)


## La cuadrícula de personajes se genera desde el catálogo: añadir un personaje
## es una entrada en `CharacterCatalog.CHARACTERS`, sin tocar la escena. Cada
## tarjeta lleva un avatar de color, el nombre y el estado.
func _build_roster() -> void:
	for child in roster.get_children():
		roster.remove_child(child)
		child.queue_free()
	character_buttons.clear()
	character_status.clear()
	character_avatars.clear()
	character_name_labels.clear()
	_roster_group = ButtonGroup.new()
	for entry in CharacterCatalog.CHARACTERS:
		var id := String(entry["id"])
		var stem := id.substr(0, 1).to_upper() + id.substr(1)
		var button := Button.new()
		button.name = stem + "Button"
		button.toggle_mode = true
		button.button_group = _roster_group
		button.custom_minimum_size = Vector2(0.0, ROSTER_ROW_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.clip_contents = true

		var row := HBoxContainer.new()
		row.name = stem + "Row"
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10.0
		row.offset_top = 5.0
		row.offset_right = -10.0
		row.offset_bottom = -5.0
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var avatar := PanelContainer.new()
		avatar.name = stem + "Avatar"
		avatar.custom_minimum_size = Vector2(42.0, 42.0)
		avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var avatar_style := StyleBoxFlat.new()
		avatar_style.bg_color = entry["color"]
		avatar_style.border_width_left = 3
		avatar_style.border_width_top = 3
		avatar_style.border_width_right = 3
		avatar_style.border_width_bottom = 3
		avatar_style.border_color = UITheme.CREAM
		avatar_style.corner_radius_top_left = 21
		avatar_style.corner_radius_top_right = 21
		avatar_style.corner_radius_bottom_right = 21
		avatar_style.corner_radius_bottom_left = 21
		avatar.add_theme_stylebox_override("panel", avatar_style)
		var initial := Label.new()
		initial.name = stem + "Initial"
		initial.text = String(entry["name"]).substr(0, 1).to_upper()
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.add_theme_font_size_override("font_size", 20)
		initial.add_theme_color_override("font_color", _readable_ink(entry["color"] as Color))
		initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(initial)

		var labels := VBoxContainer.new()
		labels.name = stem + "Labels"
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		labels.add_theme_constant_override("separation", 0)
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Label.new()
		name_label.name = stem + "Name"
		name_label.text = String(entry["name"])
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", UITheme.INK)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var status := Label.new()
		status.name = stem + "Status"
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color(UITheme.INK, 0.72))
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(name_label)
		labels.add_child(status)
		row.add_child(avatar)
		row.add_child(labels)
		button.add_child(row)
		roster.add_child(button)
		character_buttons.append(button)
		character_status.append(status)
		character_avatars.append(avatar)
		character_name_labels.append(name_label)


func _connect_character_buttons() -> void:
	for i in mini(character_buttons.size(), CharacterCatalog.CHARACTERS.size()):
		var id := String(CharacterCatalog.CHARACTERS[i]["id"])
		character_buttons[i].pressed.connect(_on_character_selected.bind(id))


# --- Modos ------------------------------------------------------------------

## El botón JUGAR no arranca directo: abre la elección de modo, como el lobby
## de referencia.
func _on_play_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	character_panel.hide()
	controls_panel.hide()
	credits_panel.hide()
	# El botón grande deja su sitio a las tarjetas de modo.
	_set_lobby_chrome_visible(false)
	scrim.show()
	mode_panel.show()
	classic_card.grab_focus()


func _on_classic_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	GameSession.start_classic()
	TransitionManager.change_scene(GameSession.level_path)


func _on_tournament_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	GameSession.start_bots(true)
	TransitionManager.change_scene(GameSession.level_path)


## Circuito de la carrera clásica. Se guarda en el perfil para no tener que
## elegirlo otra vez al volver al lobby.
func _on_level_selected(index: int) -> void:
	AudioManager.play_sfx("ui", 0.05)
	GameSession.set_classic_level(index)
	_refresh_level_picker()
	_refresh_profile()


func _refresh_level_picker() -> void:
	var chosen := clampi(GameSession.classic_level, 0, GameSession.level_count() - 1)
	for i in mini(level_buttons.size(), GameSession.level_count()):
		var button := level_buttons[i]
		button.text = GameSession.level_name(i)
		button.set_pressed_no_signal(i == chosen)
	var medals := GameSession.level_medals(chosen)
	controls_goal_label.text = "Objetivo: %s. Oro ≤ %.0f s · bronce ≤ %.0f s." % [
		GameSession.level_name(chosen), float(medals["gold"]), float(medals["bronze"])]


# --- Paneles ----------------------------------------------------------------

func _on_character_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	_pending_id = SaveManager.character_id()
	mode_panel.hide()
	controls_panel.hide()
	credits_panel.hide()
	_set_lobby_chrome_visible(false)
	scrim.show()
	character_panel.show()
	_refresh_character_panel()
	character_back_button.grab_focus()


func _on_controls_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	mode_panel.hide()
	character_panel.hide()
	credits_panel.hide()
	_set_lobby_chrome_visible(false)
	scrim.show()
	controls_panel.show()
	controls_panel.get_node("VBoxContainer/BackButton").grab_focus()


func _on_settings_pressed() -> void:
	settings_menu.open()


func _on_credits_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	mode_panel.hide()
	character_panel.hide()
	controls_panel.hide()
	_set_lobby_chrome_visible(false)
	scrim.show()
	credits_panel.show()
	credits_panel.get_node("VBoxContainer/BackButton").grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


## El chrome del lobby solo tiene sentido cuando no hay un panel abierto.
func _set_lobby_chrome_visible(shown: bool) -> void:
	play_button.visible = shown
	top_bar.visible = shown
	season_card.visible = shown
	player_badge.visible = shown
	quit_button.visible = shown


func _close_panels() -> void:
	AudioManager.play_sfx("ui", 0.05)
	mode_panel.hide()
	controls_panel.hide()
	credits_panel.hide()
	character_panel.hide()
	scrim.hide()
	_set_lobby_chrome_visible(true)
	play_button.grab_focus()


# --- Personajes -------------------------------------------------------------

## El personaje que muestra el panel: el último tocado, o el equipado.
func _selection() -> String:
	if not _pending_id.is_empty() and CharacterCatalog.ids().has(_pending_id):
		return _pending_id
	return SaveManager.character_id()


func _on_character_selected(id: String) -> void:
	AudioManager.play_sfx("ui", 0.05)
	_pending_id = id
	if SaveManager.is_character_unlocked(id):
		SaveManager.set_character(id)
	_refresh_character_panel()
	_refresh_profile()
	_refresh_lobby()


## Compra el personaje bloqueado (si hay monedas) o equipa el que ya se tiene.
func _on_buy_pressed() -> void:
	var id := _selection()
	if SaveManager.is_character_unlocked(id):
		if SaveManager.character_id() != id:
			SaveManager.set_character(id)
			AudioManager.play_sfx("ui", 0.05)
	elif SaveManager.buy_character(id):
		SaveManager.set_character(id)
		AudioManager.play_sfx("checkpoint", 0.2)
	else:
		AudioManager.play_sfx("ui", 0.05)
	_refresh_profile()
	_refresh_character_panel()
	_refresh_lobby()


## Recorre el catálogo: marca el equipado, el precio de los bloqueados y deja
## el botón de compra en el estado correcto.
func _refresh_character_panel() -> void:
	var coins := SaveManager.coins()
	panel_coins_label.text = "%d monedas" % coins
	var current := SaveManager.character_id()
	var shown := _selection()
	for i in mini(character_buttons.size(), CharacterCatalog.CHARACTERS.size()):
		var entry: Dictionary = CharacterCatalog.CHARACTERS[i]
		var id := String(entry["id"])
		var unlocked := SaveManager.is_character_unlocked(id)
		var button := character_buttons[i]
		var status := character_status[i]
		button.set_pressed_no_signal(id == shown)
		var accent: Color = entry.get("color", Color(0.9, 0.9, 0.9))
		var avatar := character_avatars[i]
		var avatar_style := avatar.get_theme_stylebox("panel") as StyleBoxFlat
		if avatar_style != null:
			# Los bloqueados conservan su color de identidad, solo un poco más
			# profundo; nada de convertirlos en gris.
			avatar_style.bg_color = accent if unlocked else Color.from_hsv(
				accent.h, accent.s * 0.92, accent.v * 0.68)
		var initial := avatar.get_child(0) as Label
		if initial != null:
			initial.add_theme_color_override("font_color", _readable_ink(avatar_style.bg_color))
		status.add_theme_color_override("font_color", UITheme.INK)
		if id == current:
			status.text = "ELEGIDO"
		elif unlocked:
			status.text = "LIBRE"
		else:
			status.text = "%d monedas" % SaveManager.character_price(id)

	selected_character_label.text = CharacterCatalog.display_name(shown)
	selected_character_label.add_theme_color_override("font_color", UITheme.CREAM)
	_load_preview(shown)

	if SaveManager.is_character_unlocked(shown):
		price_label.text = "Desbloqueada · lista para correr"
		if shown == current:
			buy_button.text = "ELEGIDO"
			buy_button.disabled = true
		else:
			buy_button.text = "ELEGIR PERSONAJE"
			buy_button.disabled = false
	else:
		var price := SaveManager.character_price(shown)
		if coins >= price:
			price_label.text = "Bloqueada · %d monedas" % price
			buy_button.text = "DESBLOQUEAR POR %d MONEDAS" % price
			buy_button.disabled = false
		else:
			price_label.text = "Bloqueada · te faltan %d monedas" % (price - coins)
			buy_button.text = "NECESITAS %d MONEDAS" % price
			buy_button.disabled = true


## Texto legible sobre el color de cada avatar: tinta en los tonos claros y
## crema en los profundos. Evita que un nombre desaparezca sobre azul o coral.
func _readable_ink(color: Color) -> Color:
	var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return UITheme.INK if luma > 0.56 else UITheme.CREAM


func _load_preview(id: String) -> void:
	if id == _preview_id and _preview_model != null and is_instance_valid(_preview_model):
		return
	_preview_id = id
	_preview_model = _swap_model(preview_stage, _preview_model, id, "PreviewModel")


## Escaparate del lobby: siempre el personaje equipado, girando sobre su peana.
func _refresh_lobby() -> void:
	var id := SaveManager.character_id()
	player_name_label.text = CharacterCatalog.display_name(id)
	if id == _lobby_id and _lobby_model != null and is_instance_valid(_lobby_model):
		return
	_lobby_id = id
	_lobby_model = _swap_model(lobby_stage, _lobby_model, id, "LobbyModel")


func _swap_model(stage: Node3D, previous: Node3D, id: String, model_name: String) -> Node3D:
	if previous != null and is_instance_valid(previous):
		# Fuera del árbol al instante: si el modelo viejo sigue ahí al añadir el
		# nuevo, Godot renombra el escaparate y el nodo pierde su nombre.
		stage.remove_child(previous)
		previous.free()
	var model := CharacterCatalog.build_model(id, model_name)
	if model == null:
		return null
	stage.add_child(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return model
	var idle := anim.get_animation("Idle")
	if idle != null:
		idle.loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle", 0.0)
	return model


# --- Perfil -----------------------------------------------------------------

func _refresh_profile() -> void:
	var index := clampi(GameSession.classic_level, 0, GameSession.level_count() - 1)
	var medals := GameSession.level_medals(index)
	var level_id := GameSession.level_id(index)
	var level_name := GameSession.level_name(index)
	var gold := float(medals["gold"])
	var silver := float(medals["silver"])
	var bronze := float(medals["bronze"])
	season_kicker.text = level_name.to_upper()
	if SaveManager.has_best(level_id):
		var best := SaveManager.best_time(level_id)
		best_time_label.text = "Récord %s: %.2f s" % [level_name, best]
		medal_label.text = "Mejor medalla: %s" % SaveManager.medal_label(
			SaveManager.medal_for_values(best, gold, silver, bronze))
		var span := maxf(bronze - gold, 0.01)
		var progress := clampf((bronze - best) / span, 0.0, 1.0)
		season_progress.value = progress * 100.0
		season_progress_label.text = "Oro ≤ %.0f s · bronce ≤ %.0f s" % [gold, bronze]
	else:
		best_time_label.text = "Sin récord en %s" % level_name
		medal_label.text = "Oro ≤ %.0f s · bronce ≤ %.0f s" % [gold, bronze]
		season_progress.value = 0.0
		season_progress_label.text = "Corre una carrera y persigue la medalla"
	coins_label.text = "%d monedas" % SaveManager.coins()
	panel_coins_label.text = "%d monedas" % SaveManager.coins()
	player_name_label.text = CharacterCatalog.display_name(SaveManager.character_id())
