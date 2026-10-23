extends Control

## Main menu: classic run, race vs bots, tournament, controls, settings,
## credits and a summary of the saved profile.

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var bots_button: Button = $CenterContainer/VBoxContainer/BotsButton
@onready var tournament_button: Button = $CenterContainer/VBoxContainer/TournamentButton
@onready var controls_button: Button = $CenterContainer/VBoxContainer/ControlsButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $CenterContainer/VBoxContainer/CreditsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var controls_panel: Control = $ControlsPanel
@onready var credits_panel: Control = $CreditsPanel
@onready var best_time_label: Label = $BestTimeLabel
@onready var medal_label: Label = $MedalLabel
@onready var coins_label: Label = $CoinsLabel
@onready var settings_menu = $SettingsMenu


func _ready() -> void:
	_connect_buttons()
	_refresh_profile()
	controls_panel.hide()
	credits_panel.hide()
	start_button.grab_focus()


func _connect_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	bots_button.pressed.connect(_on_bots_pressed)
	tournament_button.pressed.connect(_on_tournament_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	controls_panel.get_node("VBoxContainer/BackButton").pressed.connect(_close_panels)
	credits_panel.get_node("VBoxContainer/BackButton").pressed.connect(_close_panels)


func _on_start_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	GameSession.start_classic()
	TransitionManager.change_scene("res://scenes/main.tscn")


func _on_bots_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	GameSession.start_bots(false)
	TransitionManager.change_scene("res://scenes/main.tscn")


func _on_tournament_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	GameSession.start_bots(true)
	TransitionManager.change_scene("res://scenes/main.tscn")


func _on_controls_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	controls_panel.show()
	credits_panel.hide()


func _on_settings_pressed() -> void:
	settings_menu.open()


func _on_credits_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	credits_panel.show()
	controls_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _close_panels() -> void:
	AudioManager.play_sfx("ui", 0.05)
	controls_panel.hide()
	credits_panel.hide()


func _refresh_profile() -> void:
	if SaveManager.has_best():
		best_time_label.text = "Récord: %.2f s" % SaveManager.best_time()
		medal_label.text = "Mejor medalla: %s" % SaveManager.medal_label(SaveManager.medal_for(SaveManager.best_time()))
	else:
		best_time_label.text = "Sin récord todavía"
		medal_label.text = "Medalla de oro: %.1f s" % SaveManager.medal_target("gold")
	coins_label.text = "%d monedas   ·   %d/3 coronas" % [SaveManager.coins(), SaveManager.total_crowns()]
