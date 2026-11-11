extends CanvasLayer

## Ajustes persistentes: volumen de música/SFX, intensidad de sacudida y
## pantalla completa. Se puede abrir desde el menú y desde la pausa.

@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var shake_slider: HSlider = $Panel/VBox/ShakeRow/ShakeSlider
@onready var sens_slider: HSlider = $Panel/VBox/SensRow/SensSlider
@onready var music_value: Label = $Panel/VBox/MusicRow/MusicValue
@onready var sfx_value: Label = $Panel/VBox/SfxRow/SfxValue
@onready var shake_value: Label = $Panel/VBox/ShakeRow/ShakeValue
@onready var sens_value: Label = $Panel/VBox/SensRow/SensValue
@onready var fullscreen_check: Button = $Panel/VBox/FullscreenCheck
@onready var back_button: Button = $Panel/VBox/BackButton

## Fila de accesibilidad, creada en codigo para no tocar la escena compartida
## por el menu y la pausa.
var motion_row: HBoxContainer
var motion_label: Label
var motion_check: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	UITheme.apply($Panel)
	hide()
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	shake_slider.value_changed.connect(_on_shake_changed)
	sens_slider.value_changed.connect(_on_sens_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(close)
	_build_motion_row()
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


func _build_motion_row() -> void:
	motion_row = HBoxContainer.new()
	motion_row.name = "MotionRow"
	motion_row.add_theme_constant_override("separation", 12)
	motion_label = Label.new()
	motion_label.name = "MotionLabel"
	motion_label.text = "REDUCIR MOVIMIENTO"
	motion_label.custom_minimum_size = Vector2(154, 0)
	motion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	motion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	motion_label.add_theme_font_size_override("font_size", 17)
	motion_check = CheckButton.new()
	motion_check.name = "MotionCheck"
	motion_check.text = "NO"
	motion_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motion_check.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	motion_check.toggled.connect(_on_motion_toggled)
	motion_row.add_child(motion_label)
	motion_row.add_child(motion_check)
	var box := $Panel/VBox
	box.add_child(motion_row)
	box.move_child(motion_row, back_button.get_index())


func _sync_from_settings() -> void:
	# no_signal evita guardar el perfil cuatro veces al abrir el panel.
	motion_check.set_pressed_no_signal(bool(SaveManager.get_setting("reduced_motion", false)))
	_update_motion_label()
	music_slider.set_value_no_signal(float(SaveManager.get_setting("music", 0.75)))
	sfx_slider.set_value_no_signal(float(SaveManager.get_setting("sfx", 0.9)))
	shake_slider.set_value_no_signal(float(SaveManager.get_setting("shake", 1.0)))
	sens_slider.set_value_no_signal(float(SaveManager.get_setting("sensitivity", 1.0)))
	fullscreen_check.set_pressed_no_signal(bool(SaveManager.get_setting("fullscreen", false)))
	_update_fullscreen_label()
	_update_labels()


func _update_labels() -> void:
	music_value.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value * 100.0))
	shake_value.text = "%d%%" % int(round(shake_slider.value * 100.0))
	sens_value.text = "%d%%" % int(round(sens_slider.value * 100.0))


func _on_music_changed(value: float) -> void:
	SaveManager.set_setting("music", value)
	_update_labels()


func _on_sfx_changed(value: float) -> void:
	SaveManager.set_setting("sfx", value)
	_update_labels()


func _on_shake_changed(value: float) -> void:
	SaveManager.set_setting("shake", value)
	_update_labels()


## Se guarda como multiplicador de la sensibilidad base del jugador, así el
## ajuste vale para cualquier cámara aunque cambie el valor de partida.
func _on_sens_changed(value: float) -> void:
	SaveManager.set_setting("sensitivity", value)
	_update_labels()


func _on_fullscreen_toggled(pressed: bool) -> void:
	SaveManager.set_setting("fullscreen", pressed)
	_update_fullscreen_label()


func _on_motion_toggled(pressed: bool) -> void:
	SaveManager.set_setting("reduced_motion", pressed)
	_update_motion_label()


func _update_motion_label() -> void:
	motion_check.text = "SÍ" if motion_check.button_pressed else "NO"


## El botón no lleva icono de check: el estado se lee en el propio texto.
func _update_fullscreen_label() -> void:
	fullscreen_check.text = "PANTALLA COMPLETA: %s" % ("SÍ" if fullscreen_check.button_pressed else "NO")
