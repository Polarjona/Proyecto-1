extends CanvasLayer

## Pause menu with resume, restart, and main menu options.

@onready var resume_button: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $PanelContainer/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $PanelContainer/VBoxContainer/MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_connect_buttons()
	hide()


func _connect_buttons() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	# PROCESS_MODE_ALWAYS: receives input even while the tree is paused,
	# so this is the single place that toggles the pause menu.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if visible:
			hide_menu()
		else:
			show_menu()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	TransitionManager.change_scene(get_tree().current_scene.scene_file_path)


func _on_main_menu_pressed() -> void:
	TransitionManager.change_scene("res://scenes/menu/main_menu.tscn")


func show_menu() -> void:
	if visible:
		return
	show()
	get_tree().paused = true
	resume_button.grab_focus()


func hide_menu() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
