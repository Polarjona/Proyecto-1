extends Node

## Autoload: modo de juego activo (clásico, carrera contra bots o torneo).
## También instala los mandos analógicos en tiempo de ejecución.

signal mode_changed(mode: String)

## Los cuatro circuitos del torneo, en orden de ronda. El torneo los recorre
## enteros; la carrera clásica corre el que se elija en el menú.
const LEVELS := [
	"res://scenes/main.tscn",
	"res://scenes/levels/spin_go_round.tscn",
	"res://scenes/levels/glacier_gallop.tscn",
	"res://scenes/levels/lava_vortex.tscn",
]
## Nombre de cada circuito para el menú. Es el `display_name` del LevelInfo de
## su escena (lo comprueba `levels_test`).
const LEVEL_NAMES := ["Pivot Push", "Spin Go Round", "Glacier Gallop", "Lava Vortex"]
const TOTAL_ROUNDS := 4

var mode: String = "classic"
var round: int = 1
var bot_count: int = 7
var qualifiers: int = 3
var level_path: String = LEVELS[0]
## Circuito elegido en el menú para la carrera clásica (índice de LEVELS).
var classic_level: int = 0


func _ready() -> void:
	_install_gamepad_bindings()
	# El circuito elegido sobrevive al cierre del juego, como el personaje.
	classic_level = clampi(int(SaveManager.get_setting("classic_level", 0)), 0, LEVELS.size() - 1)


func start_classic() -> void:
	mode = "classic"
	round = 1
	level_path = classic_level_path()
	mode_changed.emit(mode)


## Circuitos que se pueden elegir en la carrera clásica.
func level_count() -> int:
	return LEVELS.size()


func level_name(index: int) -> String:
	return String(LEVEL_NAMES[clampi(index, 0, LEVEL_NAMES.size() - 1)])


func classic_level_path() -> String:
	return String(LEVELS[clampi(classic_level, 0, LEVELS.size() - 1)])


## Guarda el circuito elegido para la carrera clásica y lo recuerda en el perfil.
func set_classic_level(index: int) -> void:
	classic_level = clampi(index, 0, LEVELS.size() - 1)
	SaveManager.set_setting("classic_level", classic_level)


func start_bots(tournament: bool = false) -> void:
	mode = "tournament" if tournament else "bots"
	round = 1
	bot_count = 7
	qualifiers = 3
	level_path = LEVELS[0]
	mode_changed.emit(mode)


func is_bot_race() -> bool:
	return mode == "bots" or mode == "tournament"


func is_tournament() -> bool:
	return mode == "tournament"


## Pasa a la siguiente ronda del torneo. No hace nada si ya estaba en la
## final: el torneo tiene cuatro circuitos y termina ahi.
func advance_round() -> void:
	if round >= TOTAL_ROUNDS:
		return
	round += 1
	bot_count = mini(bot_count + 1, 11)
	qualifiers = maxi(1, 3 - int((round - 1) / 2))
	level_path = LEVELS[clampi(round - 1, 0, LEVELS.size() - 1)]
	mode_changed.emit(mode)


func is_final_round() -> bool:
	return is_tournament() and round >= TOTAL_ROUNDS


func total_rounds() -> int:
	return TOTAL_ROUNDS


func reset() -> void:
	mode = "classic"
	round = 1
	bot_count = 7
	qualifiers = 3
	level_path = LEVELS[0]


## Velocidad relativa de los bots según la ronda del torneo.
func bot_speed_scale() -> float:
	return 1.0 + float(round - 1) * 0.05


func _install_gamepad_bindings() -> void:
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_button("jump", JOY_BUTTON_A)
	_add_button("pause", JOY_BUTTON_START)


func _add_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		return
	if _has_axis(action, axis, value):
		return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


func _add_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	if _has_button(action, button):
		return
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	InputMap.action_add_event(action, event)


func _has_axis(action: String, axis: int, value: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, value):
				return true
	return false


func _has_button(action: String, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			if (event as InputEventJoypadButton).button_index == button:
				return true
	return false
