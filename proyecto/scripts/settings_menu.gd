extends CanvasLayer

## Ajustes persistentes: volumen de música/SFX, intensidad de sacudida y
## pantalla completa. Se puede abrir desde el menú y desde la pausa.

@onready var music_slider: HSlider = $Panel/VBox/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SfxSlider
@onready var shake_slider: HSlider = $Panel/VBox/ShakeSlider
@onready var music_value: Label = $Panel/VBox/MusicValue
@onready var sfx_value: Label = $Panel/VBox/SfxValue
@onready var shake_value: Label = $Panel/VBox/ShakeValue
@onready var fullscreen_check: Button = $Panel/VBox/FullscreenCheck
@onready var back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	hide()
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	shake_slider.value_changed.connect(_on_shake_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(close)
	_sync_from_settings()


func open() -> void:
	_sync_from_settings()
	show()
	back_button.grab_focus()
	AudioManager.play_sfx("ui", 0.05)


func close() -> void:
	AudioManager.play_sfx("ui", 0.05)
	hide()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _sync_from_settings() -> void:
	# no_signal evita guardar el perfil cuatro veces al abrir el panel.
	music_slider.set_value_no_signal(float(SaveManager.get_setting("music", 0.75)))
	sfx_slider.set_value_no_signal(float(SaveManager.get_setting("sfx", 0.9)))
	shake_slider.set_value_no_signal(float(SaveManager.get_setting("shake", 1.0)))
	fullscreen_check.set_pressed_no_signal(bool(SaveManager.get_setting("fullscreen", false)))
	_update_fullscreen_label()
	_update_labels()


func _update_labels() -> void:
	music_value.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value * 100.0))
	shake_value.text = "%d%%" % int(round(shake_slider.value * 100.0))


func _on_music_changed(value: float) -> void:
	SaveManager.set_setting("music", value)
	_update_labels()


func _on_sfx_changed(value: float) -> void:
	SaveManager.set_setting("sfx", value)
	_update_labels()


func _on_shake_changed(value: float) -> void:
	SaveManager.set_setting("shake", value)
	_update_labels()


func _on_fullscreen_toggled(pressed: bool) -> void:
	SaveManager.set_setting("fullscreen", pressed)
	_update_fullscreen_label()


## El botón no lleva icono de check: el estado se lee en el propio texto.
func _update_fullscreen_label() -> void:
	fullscreen_check.text = "PANTALLA COMPLETA: %s" % ("SÍ" if fullscreen_check.button_pressed else "NO")
