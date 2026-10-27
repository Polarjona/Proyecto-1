extends Node

## Autoload: modo de juego activo (clásico, carrera contra bots o torneo).
## También instala los mandos analógicos en tiempo de ejecución.

signal mode_changed(mode: String)

## Los tres circuitos del torneo, en orden de ronda. El primero es tambien el
## circuito de la carrera clasica y del modo de practica con bots.
const LEVELS := [
	"res://scenes/main.tscn",
	"res://scenes/levels/spin_go_round.tscn",
	"res://scenes/levels/pivot_panic.tscn",
]
const TOTAL_ROUNDS := 3

var mode: String = "classic"
var round: int = 1
var bot_count: int = 7
var qualifiers: int = 3
var level_path: String = LEVELS[0]


func _ready() -> void:
	_install_gamepad_bindings()


func start_classic() -> void:
	mode = "classic"
	round = 1
	level_path = LEVELS[0]
	mode_changed.emit(mode)


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
## final: el torneo tiene tres circuitos y termina ahi.
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
	_add_button("dive", JOY_BUTTON_X)
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
