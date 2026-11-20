extends Node

## Autoload: modo de juego activo (clásico, carrera contra bots o torneo).
## También instala los mandos analógicos en tiempo de ejecución.

signal mode_changed(mode: String)

## Registro único de circuitos, en orden de ronda. El torneo recorre los cuatro
## primeros; la carrera clásica puede correr cualquiera, incluido el abisal.
##
## Antes había tres listas paralelas (rutas, nombres, ids y medallas) que podían
## desincronizarse entre sí. Ahora todo sale de aquí, y `levels_test` comprueba
## que cada escena declara lo mismo en su `LevelInfo`.
const LEVEL_DEFINITIONS := [
	{
		"path": LevelPaths.PIVOT_PUSH,
		"id": "pivot_push",
		"name": "Pivot Push",
		"gold": 130.0,
		"silver": 170.0,
		"bronze": 215.0
	},
	{
		"path": LevelPaths.SPIN_GO_ROUND,
		"id": "spin_go_round",
		"name": "Spin Go Round",
		"gold": 115.0,
		"silver": 145.0,
		"bronze": 185.0
	},
	{
		"path": LevelPaths.GLACIER_GALLOP,
		"id": "glacier_gallop",
		"name": "Glacier Gallop",
		"gold": 145.0,
		"silver": 180.0,
		"bronze": 225.0
	},
	{
		"path": LevelPaths.LAVA_VORTEX,
		"id": "lava_vortex",
		"name": "Lava Vortex",
		"gold": 84.0,
		"silver": 100.0,
		"bronze": 116.0
	},
	{
		"path": LevelPaths.ABYSS_RUN,
		"id": "abyss_run",
		"name": "Abyss Run",
		"gold": 112.0,
		"silver": 138.0,
		"bronze": 172.0
	},
]

const TOTAL_ROUNDS := 4

## Plazas que clasifican en cada ronda: 3 → 3 → 2 → 1.
const QUALIFIERS_BY_ROUND := [3, 3, 2, 1]

## Rutas de las escenas, derivadas del registro para no repetir la lista.
## Se rellenan al construir el autoload: `level_path` se apoya en ellas y no
## puede esperar a `_ready`.
var level_paths: Array[String] = _paths()

var mode: String = "classic"

var round: int = 1

var bot_count: int = 7

var qualifiers: int = 3

var level_path: String = level_paths[0]

## Circuito elegido en el menú para la carrera clásica (índice de `level_paths`).
var classic_level: int = 0


## Rutas del registro, en orden de ronda.
static func _paths() -> Array[String]:
	var paths: Array[String] = []
	for definition: Dictionary in LEVEL_DEFINITIONS:
		paths.append(String(definition["path"]))
	return paths


func _ready() -> void:
	_install_gamepad_bindings()
	# El circuito elegido sobrevive al cierre del juego, como el personaje.
	classic_level = clampi(
		int(SaveManager.get_setting("classic_level", 0)), 0, level_paths.size() - 1
	)


func start_classic() -> void:
	mode = "classic"
	round = 1
	level_path = classic_level_path()
	mode_changed.emit(mode)


## Circuitos que se pueden elegir en la carrera clásica.
func level_count() -> int:
	return level_paths.size()


## Ruta de la escena de un circuito del catálogo, por índice acotado.
func level_path_at(index: int) -> String:
	return level_paths[clampi(index, 0, level_paths.size() - 1)]


func level_name(index: int) -> String:
	return String(_definition(index)["name"])


func level_id(index: int) -> String:
	return String(_definition(index)["id"])


func level_medals(index: int) -> Dictionary:
	var definition := _definition(index)
	return {
		"gold": float(definition["gold"]),
		"silver": float(definition["silver"]),
		"bronze": float(definition["bronze"]),
	}


## Entrada del registro, con el índice acotado al catálogo.
func _definition(index: int) -> Dictionary:
	return LEVEL_DEFINITIONS[clampi(index, 0, LEVEL_DEFINITIONS.size() - 1)] as Dictionary


func classic_level_path() -> String:
	return String(level_paths[clampi(classic_level, 0, level_paths.size() - 1)])


## Guarda el circuito elegido para la carrera clásica y lo recuerda en el perfil.
func set_classic_level(index: int) -> void:
	classic_level = clampi(index, 0, level_paths.size() - 1)
	SaveManager.set_setting("classic_level", classic_level)


func start_bots(tournament: bool = false) -> void:
	mode = "tournament" if tournament else "bots"
	round = 1
	bot_count = 7
	qualifiers = 3
	level_path = level_paths[0]
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
	qualifiers = QUALIFIERS_BY_ROUND[clampi(round - 1, 0, QUALIFIERS_BY_ROUND.size() - 1)]
	level_path = level_paths[clampi(round - 1, 0, level_paths.size() - 1)]
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
	level_path = level_paths[0]


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
	# Gatillo derecho para bajar nadando en el circuito abisal.
	_add_axis("dive", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	# Stick derecho para girar la camara, igual que el raton.
	for action in ["camera_left", "camera_right", "camera_up", "camera_down"]:
		_ensure_action(action)
	_add_axis("camera_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("camera_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis("camera_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis("camera_down", JOY_AXIS_RIGHT_Y, 1.0)


## Las acciones de camara no vienen en project.godot: se crean aqui para no
## ensuciar el mapa de entrada con cuatro ejes que solo usa el mando.
func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


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
