extends Control

## Main menu with start, controls, credits, and quit buttons.

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var controls_button: Button = $CenterContainer/VBoxContainer/ControlsButton
@onready var credits_button: Button = $CenterContainer/VBoxContainer/CreditsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var controls_panel: Control = $ControlsPanel
@onready var credits_panel: Control = $CreditsPanel
@onready var best_time_label: Label = $BestTimeLabel

const SAVE_PATH := "user://best_time.save"


func _ready() -> void:
	_connect_buttons()
	_load_best_time()
	controls_panel.hide()
	credits_panel.hide()


func _connect_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Close panels
	controls_panel.get_node("VBoxContainer/BackButton").pressed.connect(_close_panels)
	credits_panel.get_node("VBoxContainer/BackButton").pressed.connect(_close_panels)


func _on_start_pressed() -> void:
	TransitionManager.change_scene("res://scenes/main.tscn")


func _on_controls_pressed() -> void:
	controls_panel.show()
	credits_panel.hide()


func _on_credits_pressed() -> void:
	credits_panel.show()
	controls_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _close_panels() -> void:
	controls_panel.hide()
	credits_panel.hide()


func _load_best_time() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		best_time_label.text = "Sin récord"
		return

	var time_str := file.get_line().strip_edges()
	file.close()

	if time_str.is_valid_float():
		var time := float(time_str)
		best_time_label.text = "Récord: %.2f s" % time
	else:
		best_time_label.text = "Sin récord"
