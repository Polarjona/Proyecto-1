extends Control

## Lobby principal: escaparate 3D del corredor, ruta de circuitos y las dos
## tarjetas de modo (carrera clásica o torneo con bots) siempre visibles. El
## corredor y su ficha abren el submenú Personaje, donde se compran los
## corredores bloqueados con las monedas ganadas.

## Alto de cada tarjeta del roster, en píxeles. La cuadrícula de dos columnas
## permite que los diez personajes entren sin scroll.
const ROSTER_ROW_HEIGHT := 62.0

## Botones, avatares y etiquetas del roster, en el mismo orden que el catálogo.
var character_buttons: Array[Button] = []

var character_status: Array[Label] = []

var character_avatars: Array[PanelContainer] = []

var character_name_labels: Array[Label] = []

var _roster_group: ButtonGroup

## Personaje que se está mirando en el panel (puede seguir bloqueado).
var _pending_id: String = ""

## Último idioma aplicado: los textos dinámicos solo se regeneran al cambiarlo.
var _locale: String = ""

var _preview_model: Node3D

var _preview_id: String = ""

var _lobby_model: Node3D

var _lobby_id: String = ""

## Nodos de la ruta de circuitos. Se generan desde el catálogo, como el roster.
var level_buttons: Array[Button] = []

var route_medals: Array[Label] = []

var route_accents: Array[ColorRect] = []

var _route_group: ButtonGroup

@onready var classic_card: Button = $ModeCards/ClassicCard

@onready var tournament_card: Button = $ModeCards/TournamentCard

@onready var mode_cards: VBoxContainer = $ModeCards

@onready var quit_button: Button = $TopBar/HBox/QuitButton

@onready var scrim: ColorRect = $Scrim

@onready var top_bar: Control = $TopBar

@onready var season_card: PanelContainer = $SeasonCard

@onready var player_badge: PanelContainer = $PlayerBadge

@onready var stage_hint: Label = $StageHint

@onready var lobby_stage_button: Button = $LobbyStageButton

@onready var character_button: Button = $TopBar/HBox/NavRow/CharacterButton

@onready var settings_button: Button = $TopBar/HBox/NavRow/SettingsButton

@onready var controls_button: Button = $TopBar/HBox/NavRow/ControlsButton

@onready var credits_button: Button = $TopBar/HBox/NavRow/CreditsButton

@onready var controls_panel: Control = $ControlsPanel

@onready var credits_panel: Control = $CreditsPanel

@onready var character_panel: Control = $CharacterPanel

@onready var character_back_button: Button = $CharacterPanel/VBox/Header/BackButton

@onready var season_title: Label = $SeasonCard/VBox/SeasonTitle

@onready var season_kicker: Label = $SeasonCard/VBox/SeasonKicker

@onready var route_list: VBoxContainer = $SeasonCard/VBox/RouteList

@onready var controls_goal_label: Label = $ControlsPanel/VBoxContainer/GoalLabel

## La insignia de monedas es el propio botón: abre Personaje, donde se gastan.
@onready var coins_badge: Button = $TopBar/HBox/CoinsBadge

@onready var panel_coins_label: Label = $CharacterPanel/VBox/Header/PanelCoins

@onready var player_name_label: Label = $PlayerBadge/HBox/VBox/PlayerNameLabel

@onready var player_badge_change: Button = $PlayerBadge/ChangeButton

@onready var settings_menu = $SettingsMenu

@onready var lobby_stage: Node3D = $LobbyStage/SubViewport/Stage

@onready var lobby_camera: Camera3D = $LobbyStage/SubViewport/Camera3D

@onready
var preview_stage: Node3D = $CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport/Stage

@onready var preview_camera: Camera3D = (
	get_node("CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport/Camera3D")
	as Camera3D
)

@onready
var selected_character_label: Label = $CharacterPanel/VBox/Body/PreviewBox/SelectedCharacterLabel

@onready var price_label: Label = $CharacterPanel/VBox/Body/PreviewBox/PriceLabel

@onready var buy_button: Button = $CharacterPanel/VBox/Body/PreviewBox/BuyButton

@onready var roster: GridContainer = $CharacterPanel/VBox/Body/RosterScroll/Roster


func _ready() -> void:
	# Un solo tema para todo el menú y para los paneles que se abren desde él.
	UITheme.apply(self)
	# Las cámaras apuntan al centro del cuerpo, no a la altura de la cabeza: el
	# escaparate del lobby y la vista previa tienen que enseñar al personaje
	# entero.
	# El encuadre incluye la peana entera: apuntando a 0.5 la base se sale por
	# abajo (medido: 114..515 de 480 px).
	lobby_camera.look_at(Vector3(0.0, 0.03, 0.0), Vector3.UP)
	preview_camera.look_at(Vector3(0.0, 0.12, 0.0), Vector3.UP)
	_build_roster()
	_build_route()
	_connect_buttons()
	_connect_character_buttons()
	controls_panel.hide()
	credits_panel.hide()
	character_panel.hide()
	_refresh_lobby()
	_refresh_profile()
	_refresh_character_panel()
	classic_card.grab_focus()
	# La música vive en el menú: la carrera la detiene al empezar y la fanfarria
	# de victoria la sustituye al cruzar la meta.
	AudioManager.play_music()
	# Los materiales de los obstáculos se compilan aquí, con el menú delante,
	# para que no den un tirón la primera vez que aparecen en carrera.
	add_child(ShaderWarmup.new())
	_locale = TranslationServer.get_locale()
	# Los textos dinámicos (récord, precios, objetivo) se generan con `tr()`:
	# al cambiar de idioma en Ajustes hay que volver a generarlos.
	SaveManager.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	if _lobby_model != null and is_instance_valid(_lobby_model):
		_lobby_model.rotate_y(delta * 0.42)
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.rotate_y(delta * 0.55)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if controls_panel.visible or credits_panel.visible or character_panel.visible:
		get_viewport().set_input_as_handled()
		_close_panels()


func _connect_buttons() -> void:
	classic_card.pressed.connect(_on_classic_pressed)
	tournament_card.pressed.connect(_on_tournament_pressed)
	character_button.pressed.connect(_on_character_pressed)
	player_badge_change.pressed.connect(_on_character_pressed)
	coins_badge.pressed.connect(_on_character_pressed)
	lobby_stage_button.pressed.connect(_on_character_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
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


## La ruta de temporada se genera desde el catálogo: cada circuito es un nodo
## seleccionable con su medalla. El circuito elegido se guarda en el perfil.
func _build_route() -> void:
	for child in route_list.get_children():
		route_list.remove_child(child)
		child.queue_free()
	level_buttons.clear()
	route_medals.clear()
	route_accents.clear()
	_route_group = ButtonGroup.new()
	for i in GameSession.level_count():
		var button := Button.new()
		button.name = "Route%d" % (i + 1)
		button.toggle_mode = true
		button.button_group = _route_group
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.clip_contents = true
		button.theme_type_variation = &"RouteButton"

		var row := HBoxContainer.new()
		row.name = "Row"
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10.0
		row.offset_top = 5.0
		row.offset_right = -10.0
		row.offset_bottom = -5.0
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var number := Label.new()
		number.name = "Number"
		number.text = str(i + 1)
		number.custom_minimum_size = Vector2(20.0, 0.0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 13)
		number.add_theme_color_override("font_color", Color(UITheme.CREAM, 0.5))
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_label := Label.new()
		name_label.name = "Name"
		name_label.text = GameSession.level_name(i)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var medal := Label.new()
		medal.name = "Medal"
		medal.text = "—"
		medal.custom_minimum_size = Vector2(62.0, 0.0)
		medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		medal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		medal.add_theme_font_size_override("font_size", 12)
		medal.add_theme_color_override("font_color", Color(UITheme.CREAM, 0.35))
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE

		row.add_child(number)
		row.add_child(name_label)
		row.add_child(medal)

		var accent := ColorRect.new()
		accent.name = "Accent"
		accent.color = UITheme.YELLOW
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		accent.offset_left = 10.0
		accent.offset_right = -10.0
		accent.offset_top = -3.0
		accent.offset_bottom = -1.0
		accent.visible = false

		button.add_child(row)
		button.add_child(accent)
		route_list.add_child(button)
		button.pressed.connect(_on_level_selected.bind(i))
		level_buttons.append(button)
		route_medals.append(medal)
		route_accents.append(accent)


# --- Modos ------------------------------------------------------------------


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
	_refresh_profile()


## Marca el nodo elegido, pinta la medalla de cada circuito y actualiza el
## objetivo del panel de controles. La medalla se calcula con el récord real.
func _refresh_route() -> void:
	var chosen := clampi(GameSession.classic_level, 0, GameSession.level_count() - 1)
	for i in mini(level_buttons.size(), GameSession.level_count()):
		var button := level_buttons[i]
		button.set_pressed_no_signal(i == chosen)
		route_accents[i].visible = i == chosen
		(button.get_node("Row/Name") as Label).text = GameSession.level_name(i)
		var level_id := GameSession.level_id(i)
		var medal := "none"
		if SaveManager.has_best(level_id):
			var best := SaveManager.best_time(level_id)
			var thresholds := GameSession.level_medals(i)
			medal = SaveManager.medal_for_values(
				best,
				float(thresholds["gold"]),
				float(thresholds["silver"]),
				float(thresholds["bronze"])
			)
		var medal_label := route_medals[i]
		if medal == "none":
			medal_label.text = "—"
			medal_label.add_theme_color_override("font_color", Color(UITheme.CREAM, 0.35))
		else:
			medal_label.text = tr(SaveManager.medal_label(medal))
			medal_label.add_theme_color_override("font_color", _medal_color(medal))
	var chosen_medals := GameSession.level_medals(chosen)
	controls_goal_label.text = (
		tr("Objetivo: %s. Oro ≤ %s s · Bronce ≤ %s s.")
		% [
			GameSession.level_name(chosen),
			"%.0f" % float(chosen_medals["gold"]),
			"%.0f" % float(chosen_medals["bronze"]),
		]
	)


func _medal_color(medal: String) -> Color:
	match medal:
		"gold":
			return UITheme.YELLOW
		"silver":
			return Color("#C9D6E8")
		"bronze":
			return Color("#E59A5B")
	return Color(UITheme.CREAM, 0.35)


# --- Paneles ----------------------------------------------------------------


func _on_character_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	_pending_id = SaveManager.character_id()
	controls_panel.hide()
	credits_panel.hide()
	_set_lobby_chrome_visible(false)
	scrim.show()
	character_panel.show()
	_refresh_character_panel()
	character_back_button.grab_focus()


func _on_controls_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
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
	top_bar.visible = shown
	season_card.visible = shown
	player_badge.visible = shown
	quit_button.visible = shown
	mode_cards.visible = shown
	lobby_stage_button.visible = shown
	stage_hint.visible = shown


func _close_panels() -> void:
	AudioManager.play_sfx("ui", 0.05)
	controls_panel.hide()
	credits_panel.hide()
	character_panel.hide()
	scrim.hide()
	_set_lobby_chrome_visible(true)
	classic_card.grab_focus()


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
	panel_coins_label.text = _coins_text(coins)
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
			avatar_style.bg_color = (
				accent if unlocked else Color.from_hsv(accent.h, accent.s * 0.92, accent.v * 0.68)
			)
		var initial := avatar.get_child(0) as Label
		if initial != null:
			initial.add_theme_color_override("font_color", _readable_ink(avatar_style.bg_color))
		status.add_theme_color_override("font_color", UITheme.INK)
		if id == current:
			status.text = tr("ELEGIDO")
		elif unlocked:
			status.text = tr("LIBRE")
		else:
			status.text = _coins_text(SaveManager.character_price(id))

	selected_character_label.text = CharacterCatalog.display_name(shown)
	selected_character_label.add_theme_color_override("font_color", UITheme.CREAM)
	_load_preview(shown)

	if SaveManager.is_character_unlocked(shown):
		price_label.text = tr("Desbloqueada · lista para correr")
		if shown == current:
			buy_button.text = tr("ELEGIDO")
			buy_button.disabled = true
		else:
			buy_button.text = tr("ELEGIR PERSONAJE")
			buy_button.disabled = false
	else:
		var price := SaveManager.character_price(shown)
		if coins >= price:
			price_label.text = tr("Bloqueada · %s") % _coins_text(price)
			buy_button.text = tr("DESBLOQUEAR POR %d MONEDAS") % price
			buy_button.disabled = false
		else:
			price_label.text = tr("Bloqueada · te faltan %s") % _coins_text(price - coins)
			buy_button.text = tr("NECESITAS %d MONEDAS") % price
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


func _on_settings_changed() -> void:
	var locale := TranslationServer.get_locale()
	if locale == _locale:
		return
	_locale = locale
	_refresh_profile()
	_refresh_character_panel()


func _refresh_profile() -> void:
	_refresh_route()
	season_kicker.text = tr("TEMPORADA")
	season_title.text = tr("RUTA DE CIRCUITOS")
	coins_badge.text = _coins_text(SaveManager.coins())
	player_name_label.text = CharacterCatalog.display_name(SaveManager.character_id())


## "1 moneda" y "2 monedas" en los tres idiomas. Los contadores son lo más
## visible; los precios y las recompensas usan la misma plantilla cuando toca.
func _coins_text(amount: int) -> String:
	return tr("%d moneda") % amount if amount == 1 else tr("%d monedas") % amount
