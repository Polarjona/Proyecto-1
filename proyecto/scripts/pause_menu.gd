extends CanvasLayer

## Pause menu with resume, restart checkpoint, restart run, settings and menu.

var confirm_dialog: ConfirmationDialog

var _pending_action: String = ""

@onready var resume_button: Button = $PanelContainer/VBoxContainer/ResumeButton

@onready var checkpoint_button: Button = $PanelContainer/VBoxContainer/CheckpointButton

@onready var restart_button: Button = $PanelContainer/VBoxContainer/RestartButton

@onready var settings_button: Button = $PanelContainer/VBoxContainer/SettingsButton

@onready var main_menu_button: Button = $PanelContainer/VBoxContainer/MainMenuButton

@onready var settings_menu: CanvasLayer = $SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply($PanelContainer)
	add_to_group("pause_menu")
	_connect_buttons()
	_ensure_restart_action()
	_build_confirm_dialog()
	hide()


func _connect_buttons() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	checkpoint_button.pressed.connect(_on_checkpoint_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	# PROCESS_MODE_ALWAYS: receives input even while the tree is paused.
	if event.is_action_pressed("restart"):
		if visible or get_tree().paused or settings_menu.visible:
			return
		if _tutorial_is_open():
			return
		var manager := get_tree().get_first_node_in_group("race_manager")
		if manager != null and bool(manager.get("is_finished")):
			return
		get_viewport().set_input_as_handled()
		_restart_run()
		return
	if event.is_action_pressed("pause"):
		if confirm_dialog != null and confirm_dialog.visible:
			return
		if _tutorial_is_open():
			return
		get_viewport().set_input_as_handled()
		if visible:
			hide_menu()
		else:
			show_menu()


func _on_resume_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	hide_menu()


func _on_checkpoint_pressed() -> void:
	var manager := get_tree().get_first_node_in_group("race_manager")
	if not _checkpoint_available(manager):
		return
	AudioManager.play_sfx("ui", 0.05)
	hide_menu()
	if manager.has_method("respawn_player"):
		manager.respawn_player()


func _on_restart_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	_ask_confirm("restart", "Reiniciar carrera", "Se perderá el progreso de esta carrera.")


func _on_settings_pressed() -> void:
	settings_menu.open()


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	_ask_confirm("menu", "Volver al menú", "Se perderá la carrera actual.")


func show_menu() -> void:
	if visible:
		return
	# Sin checkpoints (Lava Vortex) el botón no puede hacer nada: se oculta en
	# vez de dejar un botón muerto.
	var manager := get_tree().get_first_node_in_group("race_manager")
	var can_checkpoint := _checkpoint_available(manager)
	checkpoint_button.visible = can_checkpoint
	checkpoint_button.disabled = not can_checkpoint
	show()
	get_tree().paused = true
	# Con la pausa el cursor vuelve a verse para poder pulsar los botones.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func hide_menu() -> void:
	if not visible:
		return
	if confirm_dialog != null:
		confirm_dialog.hide()
	_pending_action = ""
	settings_menu.hide()
	hide()
	get_tree().paused = false
	# Al volver a la carrera el ratón queda bloqueado otra vez para la cámara.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Atajo R: reinicia la carrera en el sitio sin abrir la pausa. La pausa y
## los resultados siguen usando las confirmaciones de los botones.
func _restart_run() -> void:
	get_tree().paused = false
	TransitionManager.change_scene(get_tree().current_scene.scene_file_path)


func _go_to_menu() -> void:
	# El menú se maneja con el cursor: se suelta antes de cambiar de escena.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSession.reset()
	TransitionManager.change_scene("res://scenes/menu/main_menu.tscn")


func _ask_confirm(action: String, title: String, text: String) -> void:
	_pending_action = action
	confirm_dialog.title = tr(title)
	confirm_dialog.dialog_text = tr(text)
	confirm_dialog.ok_button_text = tr("SÍ")
	confirm_dialog.cancel_button_text = tr("NO")
	confirm_dialog.popup_centered()


func _on_confirm_accepted() -> void:
	var action := _pending_action
	_pending_action = ""
	match action:
		"restart":
			_restart_run()
		"menu":
			_go_to_menu()


func _on_confirm_canceled() -> void:
	_pending_action = ""


func _build_confirm_dialog() -> void:
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.name = "ConfirmDialog"
	confirm_dialog.confirmed.connect(_on_confirm_accepted)
	confirm_dialog.canceled.connect(_on_confirm_canceled)
	add_child(confirm_dialog)


## R se instala aquí para que el atajo funcione sin tocar el mapa de entrada.
func _ensure_restart_action() -> void:
	if not InputMap.has_action("restart"):
		InputMap.add_action("restart")
	for existing in InputMap.action_get_events("restart"):
		if existing is InputEventKey and existing.physical_keycode == KEY_R:
			return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	InputMap.action_add_event("restart", event)


func _tutorial_is_open() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.has_method("is_tutorial_open") and hud.is_tutorial_open()


func _checkpoint_available(manager: Node) -> bool:
	return (
		manager != null
		and int(manager.get("checkpoints_total")) > 0
		and bool(manager.get("has_checkpoint"))
	)
