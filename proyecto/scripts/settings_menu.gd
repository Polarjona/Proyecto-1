extends CanvasLayer

## Ajustes persistentes: volumen de música/SFX, intensidad de sacudida y
## pantalla completa. Se puede abrir desde el menú y desde la pausa.

## Fila de accesibilidad, creada en codigo para no tocar la escena compartida
## por el menu y la pausa.
var motion_row: HBoxContainer

var motion_label: Label

var motion_check: CheckButton

## Fila maestra y botón de borrado: también se crean en código para no tocar
## la escena compartida por el menú y la pausa.
var master_row: HBoxContainer

var master_slider: HSlider

var master_value: Label

var reset_button: Button

var reset_dialog: ConfirmationDialog

var quality_row: HBoxContainer

var quality_button: Button

var fov_row: HBoxContainer

var fov_slider: HSlider

var fov_value: Label

var extras_row: HBoxContainer

var vsync_button: Button

var assisted_button: Button

var language_button: Button

@onready var music_slider: HSlider = $Panel/VBox/Scroll/Content/AudioGroup/MusicRow/MusicSlider

@onready var sfx_slider: HSlider = $Panel/VBox/Scroll/Content/AudioGroup/SfxRow/SfxSlider

@onready
var shake_slider: HSlider = $Panel/VBox/Scroll/Content/ControlsGroup/ShakeRow/ShakeSlider

@onready
var sens_slider: HSlider = $Panel/VBox/Scroll/Content/ControlsGroup/SensRow/SensSlider

@onready var music_value: Label = $Panel/VBox/Scroll/Content/AudioGroup/MusicRow/MusicValue

@onready var sfx_value: Label = $Panel/VBox/Scroll/Content/AudioGroup/SfxRow/SfxValue

@onready var shake_value: Label = $Panel/VBox/Scroll/Content/ControlsGroup/ShakeRow/ShakeValue

@onready var sens_value: Label = $Panel/VBox/Scroll/Content/ControlsGroup/SensRow/SensValue

@onready
var fullscreen_check: CheckButton = $Panel/VBox/Scroll/Content/VideoGroup/FullscreenCheck

@onready var back_button: Button = $Panel/VBox/Footer/BackButton


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
	_build_master_row()
	_build_quality_row()
	_build_fov_row()
	_build_extras_row()
	_build_motion_row()
	_build_reset_button()
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


func _build_master_row() -> void:
	master_row = HBoxContainer.new()
	master_row.name = "MasterRow"
	master_row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.name = "MasterLabel"
	label.text = "General"
	label.custom_minimum_size = Vector2(154, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	master_slider = HSlider.new()
	master_slider.name = "MasterSlider"
	master_slider.custom_minimum_size = Vector2(0, 28)
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	master_slider.max_value = 1.0
	master_slider.step = 0.01
	master_slider.value = 1.0
	master_slider.value_changed.connect(_on_master_changed)
	master_value = Label.new()
	master_value.name = "MasterValue"
	master_value.custom_minimum_size = Vector2(54, 0)
	master_value.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	master_value.add_theme_font_size_override("font_size", 16)
	master_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	master_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	master_row.add_child(label)
	master_row.add_child(master_slider)
	master_row.add_child(master_value)
	var group := $Panel/VBox/Scroll/Content/AudioGroup
	group.add_child(master_row)
	# General es la primera fila de Audio, por encima de Música y Efectos.
	group.move_child(master_row, 0)


func _build_quality_row() -> void:
	quality_row = HBoxContainer.new()
	quality_row.name = "QualityRow"
	quality_row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.name = "QualityLabel"
	label.text = "Calidad"
	label.custom_minimum_size = Vector2(154, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	quality_button = Button.new()
	quality_button.name = "QualityButton"
	quality_button.custom_minimum_size = Vector2(150, 38)
	quality_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	quality_button.pressed.connect(_on_quality_pressed)
	quality_row.add_child(label)
	quality_row.add_child(quality_button)
	var group := $Panel/VBox/Scroll/Content/VideoGroup
	group.add_child(quality_row)
	group.move_child(quality_row, 0)


func _build_fov_row() -> void:
	fov_row = HBoxContainer.new()
	fov_row.name = "FovRow"
	fov_row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.name = "FovLabel"
	label.text = "FOV"
	label.custom_minimum_size = Vector2(154, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	fov_slider = HSlider.new()
	fov_slider.name = "FovSlider"
	fov_slider.custom_minimum_size = Vector2(0, 28)
	fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fov_slider.min_value = 45.0
	fov_slider.max_value = 85.0
	fov_slider.step = 1.0
	fov_slider.value = 55.0
	fov_slider.value_changed.connect(_on_fov_changed)
	fov_value = Label.new()
	fov_value.name = "FovValue"
	fov_value.custom_minimum_size = Vector2(54, 0)
	fov_value.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	fov_value.add_theme_font_size_override("font_size", 16)
	fov_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fov_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fov_row.add_child(label)
	fov_row.add_child(fov_slider)
	fov_row.add_child(fov_value)
	var group := $Panel/VBox/Scroll/Content/VideoGroup
	group.add_child(fov_row)
	group.move_child(fov_row, quality_row.get_index() + 1)


func _build_extras_row() -> void:
	extras_row = HBoxContainer.new()
	extras_row.name = "ExtrasRow"
	extras_row.add_theme_constant_override("separation", 8)
	vsync_button = _extras_button("VsyncButton")
	vsync_button.pressed.connect(_on_vsync_pressed)
	assisted_button = _extras_button("AssistedButton")
	assisted_button.pressed.connect(_on_assisted_pressed)
	language_button = _extras_button("LanguageButton")
	language_button.pressed.connect(_on_language_pressed)
	extras_row.add_child(vsync_button)
	extras_row.add_child(assisted_button)
	extras_row.add_child(language_button)
	var group := $Panel/VBox/Scroll/Content/SystemGroup
	group.add_child(extras_row)


func _extras_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	return button


func _build_reset_button() -> void:
	reset_button = Button.new()
	reset_button.name = "ResetProgressButton"
	reset_button.theme_type_variation = &"DangerButton"
	reset_button.text = "BORRAR PROGRESO"
	reset_button.pressed.connect(_on_reset_pressed)
	var content := $Panel/VBox/Scroll/Content
	content.add_child(reset_button)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.name = "ResetProgressDialog"
	reset_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(reset_dialog)


func _build_motion_row() -> void:
	motion_row = HBoxContainer.new()
	motion_row.name = "MotionRow"
	motion_row.add_theme_constant_override("separation", 12)
	motion_label = Label.new()
	motion_label.name = "MotionLabel"
	motion_label.text = "Reducir movimiento"
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
	var group := $Panel/VBox/Scroll/Content/AccessibilityGroup
	group.add_child(motion_row)


func _sync_from_settings() -> void:
	# no_signal evita guardar el perfil con cada fila al abrir el panel.
	motion_check.set_pressed_no_signal(bool(SaveManager.get_setting("reduced_motion", false)))
	_update_motion_label()
	master_slider.set_value_no_signal(float(SaveManager.get_setting("master", 1.0)))
	_update_quality_label()
	fov_slider.set_value_no_signal(float(SaveManager.get_setting("fov", 55.0)))
	_update_extras_labels()
	music_slider.set_value_no_signal(float(SaveManager.get_setting("music", 0.75)))
	sfx_slider.set_value_no_signal(float(SaveManager.get_setting("sfx", 0.9)))
	shake_slider.set_value_no_signal(float(SaveManager.get_setting("shake", 1.0)))
	sens_slider.set_value_no_signal(float(SaveManager.get_setting("sensitivity", 1.0)))
	fullscreen_check.set_pressed_no_signal(bool(SaveManager.get_setting("fullscreen", false)))
	_update_fullscreen_label()
	_update_labels()


func _update_labels() -> void:
	master_value.text = "%d%%" % int(round(master_slider.value * 100.0))
	fov_value.text = "%d°" % int(round(fov_slider.value))
	music_value.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value * 100.0))
	shake_value.text = "%d%%" % int(round(shake_slider.value * 100.0))
	sens_value.text = "%d%%" % int(round(sens_slider.value * 100.0))


func _on_quality_pressed() -> void:
	# Alto -> medio -> bajo -> alto: un solo botón para las tres opciones.
	var next := (int(SaveManager.get_setting("quality", 2)) + 2) % 3
	SaveManager.set_setting("quality", next)
	_update_quality_label()


func _update_quality_label() -> void:
	var names := ["BAJO", "MEDIO", "ALTO"]
	var quality := clampi(int(SaveManager.get_setting("quality", 2)), 0, 2)
	quality_button.text = names[quality]


func _on_master_changed(value: float) -> void:
	SaveManager.set_setting("master", value)
	_update_labels()


func _on_fov_changed(value: float) -> void:
	SaveManager.set_setting("fov", value)
	_update_labels()


func _on_vsync_pressed() -> void:
	SaveManager.set_setting("vsync", not bool(SaveManager.get_setting("vsync", true)))
	_update_extras_labels()


func _on_assisted_pressed() -> void:
	SaveManager.set_setting("assisted", not bool(SaveManager.get_setting("assisted", false)))
	_update_extras_labels()


func _on_language_pressed() -> void:
	var languages := ["es", "ca", "en"]
	var current := String(SaveManager.get_setting("language", "es"))
	var index := languages.find(current)
	if index < 0:
		index = 0
	SaveManager.set_setting("language", languages[(index + 1) % languages.size()])
	_sync_from_settings()


func _update_extras_labels() -> void:
	vsync_button.text = (
		"V-SYNC: %s" % ("SÍ" if bool(SaveManager.get_setting("vsync", true)) else "NO")
	)
	assisted_button.text = (
		"ASISTIDO: %s" % ("SÍ" if bool(SaveManager.get_setting("assisted", false)) else "NO")
	)
	language_button.text = (
		"IDIOMA: %s" % String(SaveManager.get_setting("language", "es")).to_upper()
	)


func _on_reset_pressed() -> void:
	AudioManager.play_sfx("ui", 0.05)
	reset_dialog.title = tr("Borrar progreso")
	reset_dialog.dialog_text = tr(
		(
			"Se borran récord, monedas, medallas, desbloqueos y el tutorial.\n"
			+ "Los ajustes de audio y pantalla se conservan."
		)
	)
	reset_dialog.ok_button_text = tr("SÍ")
	reset_dialog.cancel_button_text = tr("NO")
	reset_dialog.popup_centered()


func _on_reset_confirmed() -> void:
	SaveManager.reset_profile()
	_sync_from_settings()
	AudioManager.play_sfx("ui", 0.05)
	# El menú que abrió el panel refresca monedas y récord en el acto.
	var menu := get_parent()
	if menu != null and menu.has_method("_refresh_profile"):
		menu.call("_refresh_profile")


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


## El CheckButton muestra el estado en el interruptor; el texto es fijo.
func _update_fullscreen_label() -> void:
	fullscreen_check.text = tr("PANTALLA COMPLETA")
