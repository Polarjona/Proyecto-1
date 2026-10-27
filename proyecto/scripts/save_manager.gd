extends Node

## Autoload: perfil persistente, ajustes, monedas y medallas.
##
## Todo vive en `user://profile.json`. El antiguo `user://best_time.save`
## se importa automaticamente la primera vez para no perder el record.

signal profile_saved
signal settings_changed
signal medal_unlocked(medal: String)

const SAVE_PATH := "user://profile.json"
const LEGACY_BEST_PATH := "user://best_time.save"
## Carpetas de datos que usaba el juego antes de llamarse Tumble Rush.
## Se prueban en orden: primero el nombre inmediatamente anterior.
const LEGACY_APP_DIRS := ["Trompicón", "Stumble Guys"]
const PROFILE_VERSION := 1

const MEDAL_GOLD := 70.0
const MEDAL_SILVER := 95.0
const MEDAL_BRONZE := 130.0

# Recompensa en monedas: una parte fija, otra por medalla, otra por tiempo y,
# en los modos con bots, otra por puesto en la clasificación.
const COIN_BASE := 10
const COIN_MEDAL_GOLD := 40
const COIN_MEDAL_SILVER := 25
const COIN_MEDAL_BRONZE := 10
const COIN_TIME_CAP := 40
## Cada 2,5 s por debajo del tiempo de bronce suma una moneda.
const COIN_TIME_STEP := 2.5
const COIN_PLACE := {1: 40, 2: 25, 3: 15}
const COIN_PLACE_OTHER := 5

var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()
	apply_settings()


func load_profile() -> void:
	_migrate_legacy_app_dir()
	data = _default_data()
	# Perfiles anteriores al sistema de desbloqueo: el personaje que tuvieran
	# elegido se conserva como desbloqueado en vez de perderse.
	var had_unlocks := false
	var legacy_character := CharacterCatalog.default_id()
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				had_unlocks = (parsed as Dictionary).has("unlocked_characters")
				legacy_character = String((parsed as Dictionary).get("character", legacy_character))
				_merge_into(data, parsed as Dictionary)
	else:
		_migrate_legacy_best()
	# Asegura que una version antigua del perfil incorpora las claves nuevas
	# sin sobrescribir los valores ya guardados.
	_fill_missing(data, _default_data())
	if not had_unlocks and CharacterCatalog.ids().has(legacy_character):
		var unlocks: Array = data["unlocked_characters"]
		if not unlocks.has(legacy_character):
			unlocks.append(legacy_character)
	_repair_types()


## Renombrar el proyecto cambia la carpeta de `user://`. La primera vez se
## copia el perfil de la carpeta anterior para conservar récord, monedas y
## personajes desbloqueados.
func _migrate_legacy_app_dir() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		return
	var current := OS.get_user_data_dir()
	for legacy_name: String in LEGACY_APP_DIRS:
		var legacy := current.get_base_dir().path_join(legacy_name).path_join("profile.json")
		if not FileAccess.file_exists(legacy):
			continue
		var source := FileAccess.open(legacy, FileAccess.READ)
		if source == null:
			continue
		var text := source.get_as_text()
		source.close()
		DirAccess.make_dir_recursive_absolute(current)
		var target := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if target == null:
			return
		target.store_string(text)
		target.close()
		return


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: no se pudo escribir %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	profile_saved.emit()


func _default_data() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"best_time": 0.0,
		"has_best": false,
		"best_splits": [],
		"races": 0,
		"finishes": 0,
		"falls": 0,
		"coins": 0,
		"character": CharacterCatalog.default_id(),
		"unlocked_characters": CharacterCatalog.free_ids(),
		"medals": {"gold": 0, "silver": 0, "bronze": 0},
		"tutorial_seen": false,
		"settings": {
			"music": 0.75,
			"sfx": 0.9,
			"shake": 1.0,
			"fullscreen": false,
		},
		"stats": {
			"best_falls": 0,
			"runs": 0,
		},
	}


## Aplica `incoming` sobre `base` (el perfil guardado manda).
func _merge_into(base: Dictionary, incoming: Dictionary) -> void:
	for key: Variant in incoming.keys():
		if base.has(key) and base[key] is Dictionary and incoming[key] is Dictionary:
			_merge_into(base[key], incoming[key])
		else:
			base[key] = incoming[key]


## Rellena solo las claves ausentes, sin tocar los valores guardados.
func _fill_missing(base: Dictionary, defaults: Dictionary) -> void:
	for key: Variant in defaults.keys():
		if not base.has(key):
			base[key] = defaults[key]
		elif base[key] is Dictionary and defaults[key] is Dictionary:
			_fill_missing(base[key], defaults[key])


## JSON puede devolver numeros como float: normaliza los contadores.
func _repair_types() -> void:
	data["best_time"] = float(data.get("best_time", 0.0))
	data["has_best"] = bool(data.get("has_best", false))
	data["races"] = int(data.get("races", 0))
	data["finishes"] = int(data.get("finishes", 0))
	data["falls"] = int(data.get("falls", 0))
	data["coins"] = int(data.get("coins", 0))
	data["version"] = PROFILE_VERSION
	if not data.get("best_splits") is Array:
		data["best_splits"] = []
	if not data.get("medals") is Dictionary:
		data["medals"] = {"gold": 0, "silver": 0, "bronze": 0}
	if not data.get("settings") is Dictionary:
		data["settings"] = _default_data()["settings"]
	if not data.get("stats") is Dictionary:
		data["stats"] = _default_data()["stats"]
	data["character"] = String(data.get("character", CharacterCatalog.default_id()))
	var unlocks: Variant = data.get("unlocked_characters", [])
	var clean: Array = []
	if unlocks is Array:
		for id: Variant in unlocks:
			if CharacterCatalog.ids().has(String(id)) and not clean.has(String(id)):
				clean.append(String(id))
	for id in CharacterCatalog.free_ids():
		if not clean.has(id):
			clean.append(id)
	data["unlocked_characters"] = clean
	# Un personaje bloqueado no puede quedarse como equipado en el perfil.
	if not clean.has(String(data["character"])):
		data["character"] = CharacterCatalog.default_id()


func _migrate_legacy_best() -> void:
	if not FileAccess.file_exists(LEGACY_BEST_PATH):
		return
	var file := FileAccess.open(LEGACY_BEST_PATH, FileAccess.READ)
	if file == null:
		return
	var line := file.get_line().strip_edges()
	file.close()
	if line.is_valid_float():
		var time := float(line)
		if time > 0.0:
			data["best_time"] = time
			data["has_best"] = true
			save_profile()


# --- Ajustes ---------------------------------------------------------------

func get_setting(key: String, fallback: Variant = null) -> Variant:
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings
	apply_settings()
	save_profile()
	settings_changed.emit()


func apply_settings() -> void:
	var settings: Dictionary = data.get("settings", _default_data()["settings"])
	var music_linear := float(settings.get("music", 0.75))
	_apply_bus_volume("Music", music_linear)
	_apply_bus_volume("SFX", float(settings.get("sfx", 0.9)))
	# La fanfarria de meta tiene bus propio, pero el ajuste de música decide si
	# suena música o no: a cero, también se silencia.
	var victory_index := AudioServer.get_bus_index("Victory")
	if victory_index >= 0:
		AudioServer.set_bus_mute(victory_index, music_linear <= 0.001)
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen := bool(settings.get("fullscreen", false))
	var mode := DisplayServer.window_get_mode()
	if fullscreen and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0001, 1.0)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


# --- Progreso --------------------------------------------------------------

func best_time() -> float:
	return float(data.get("best_time", 0.0))


func has_best() -> bool:
	return bool(data.get("has_best", false))


func is_better(time: float) -> bool:
	return not has_best() or time < best_time()


func best_splits() -> Array:
	var splits: Variant = data.get("best_splits", [])
	return splits if splits is Array else []


func medal_for(time: float) -> String:
	if time <= 0.0:
		return "none"
	if time <= MEDAL_GOLD:
		return "gold"
	if time <= MEDAL_SILVER:
		return "silver"
	if time <= MEDAL_BRONZE:
		return "bronze"
	return "none"


func medal_label(medal: String) -> String:
	match medal:
		"gold":
			return "ORO"
		"silver":
			return "PLATA"
		"bronze":
			return "BRONCE"
		_:
			return "SIN MEDALLA"


func medal_target(medal: String) -> float:
	match medal:
		"gold":
			return MEDAL_GOLD
		"silver":
			return MEDAL_SILVER
		"bronze":
			return MEDAL_BRONZE
		_:
			return MEDAL_BRONZE


func register_start() -> void:
	data["races"] = int(data.get("races", 0)) + 1


func register_fall() -> void:
	data["falls"] = int(data.get("falls", 0)) + 1


## Monedas de una carrera: tiempo (cuanto mejor que el bronce, más), medalla
## y puesto en la clasificación (0 = sin bots, no paga puesto).
func coin_reward(time: float, medal: String, position: int = 0) -> Dictionary:
	var medal_coins := 0
	match medal:
		"gold":
			medal_coins = COIN_MEDAL_GOLD
		"silver":
			medal_coins = COIN_MEDAL_SILVER
		"bronze":
			medal_coins = COIN_MEDAL_BRONZE
	var time_coins := 0
	if time > 0.0:
		time_coins = clampi(int(floor((MEDAL_BRONZE - time) / COIN_TIME_STEP)), 0, COIN_TIME_CAP)
	var place_coins := 0
	if position > 0:
		place_coins = int(COIN_PLACE.get(position, COIN_PLACE_OTHER))
	return {
		"base": COIN_BASE,
		"medal": medal_coins,
		"time": time_coins,
		"position": place_coins,
		"place": position,
		"total": COIN_BASE + medal_coins + time_coins + place_coins,
	}


## Guarda el resultado de una carrera. Devuelve un resumen para la UI.
func register_finish(time: float, falls: int, splits: Array, position: int = 0) -> Dictionary:
	var info := {
		"time": time,
		"new_best": false,
		"medal": medal_for(time),
		"coins": 0,
		"coins_breakdown": {},
	}
	if is_better(time):
		data["best_time"] = time
		data["has_best"] = true
		data["best_splits"] = splits.duplicate()
		info["new_best"] = true

	var medals: Dictionary = data.get("medals", {})
	var medal := String(info["medal"])
	if medal != "none":
		medals[medal] = int(medals.get(medal, 0)) + 1
		if int(medals[medal]) == 1:
			medal_unlocked.emit(medal)
	data["medals"] = medals

	var reward := coin_reward(time, medal, position)
	data["coins"] = int(data.get("coins", 0)) + int(reward["total"])
	info["coins"] = int(reward["total"])
	info["coins_breakdown"] = reward
	info["position"] = position
	data["finishes"] = int(data.get("finishes", 0)) + 1
	if falls == 0:
		data["stats"]["best_falls"] = int(data.get("stats", {}).get("best_falls", 0)) + 1
	save_profile()
	return info


func medal_rank(medal: String) -> int:
	match medal:
		"gold":
			return 0
		"silver":
			return 1
		"bronze":
			return 2
		_:
			return 3


func has_seen_tutorial() -> bool:
	return bool(data.get("tutorial_seen", false))


func mark_tutorial_seen() -> void:
	if has_seen_tutorial():
		return
	data["tutorial_seen"] = true
	save_profile()


func coins() -> int:
	return int(data.get("coins", 0))


# --- Personaje -------------------------------------------------------------

## Id del personaje elegido en el menú (si el guardado apunta a uno que ya no
## existe, se cae al primero del catálogo).
func character_id() -> String:
	var id := String(data.get("character", CharacterCatalog.default_id()))
	if not CharacterCatalog.ids().has(id) or not is_character_unlocked(id):
		return CharacterCatalog.default_id()
	return id


## Solo se puede equipar un personaje desbloqueado.
func set_character(id: String) -> void:
	if not CharacterCatalog.ids().has(id) or not is_character_unlocked(id):
		return
	if id == character_id():
		return
	data["character"] = id
	save_profile()


func unlocked_characters() -> Array:
	var list: Variant = data.get("unlocked_characters", [])
	var result: Array = []
	if list is Array:
		for id: Variant in list:
			result.append(String(id))
	return result


func is_character_unlocked(id: String) -> bool:
	if CharacterCatalog.price(id) <= 0:
		return true
	return unlocked_characters().has(id)


func character_price(id: String) -> int:
	return CharacterCatalog.price(id)


func can_buy_character(id: String) -> bool:
	return CharacterCatalog.ids().has(id) \
		and not is_character_unlocked(id) \
		and coins() >= CharacterCatalog.price(id)


## Compra un personaje con monedas. Devuelve true solo si se ha desbloqueado.
func buy_character(id: String) -> bool:
	if not can_buy_character(id):
		return false
	var price := CharacterCatalog.price(id)
	data["coins"] = coins() - price
	var unlocks := unlocked_characters()
	unlocks.append(id)
	data["unlocked_characters"] = unlocks
	save_profile()
	return true


func medal_count(medal: String) -> int:
	var medals: Dictionary = data.get("medals", {})
	return int(medals.get(medal, 0))
