extends Node

## Autoload: perfil persistente, ajustes, monedas, coronas y medallas.
##
## Todo vive en `user://profile.json`. El antiguo `user://best_time.save`
## se importa automaticamente la primera vez para no perder el record.

signal profile_saved
signal settings_changed
signal crown_collected(total: int)
signal medal_unlocked(medal: String)

const SAVE_PATH := "user://profile.json"
const LEGACY_BEST_PATH := "user://best_time.save"
const PROFILE_VERSION := 1

const MEDAL_GOLD := 70.0
const MEDAL_SILVER := 95.0
const MEDAL_BRONZE := 130.0

var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()
	apply_settings()


func load_profile() -> void:
	data = _default_data()
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				_merge_into(data, parsed as Dictionary)
	else:
		_migrate_legacy_best()
	# Asegura que una version antigua del perfil incorpora las claves nuevas
	# sin sobrescribir los valores ya guardados.
	_fill_missing(data, _default_data())
	_repair_types()


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
		"crowns": [],
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
	if not data.get("crowns") is Array:
		data["crowns"] = []
	if not data.get("medals") is Dictionary:
		data["medals"] = {"gold": 0, "silver": 0, "bronze": 0}
	if not data.get("settings") is Dictionary:
		data["settings"] = _default_data()["settings"]
	if not data.get("stats") is Dictionary:
		data["stats"] = _default_data()["stats"]


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
	_apply_bus_volume("Music", float(settings.get("music", 0.75)))
	_apply_bus_volume("SFX", float(settings.get("sfx", 0.9)))
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


## Guarda el resultado de una carrera. Devuelve un resumen para la UI.
func register_finish(time: float, falls: int, splits: Array) -> Dictionary:
	var info := {
		"time": time,
		"new_best": false,
		"medal": medal_for(time),
		"coins": 0,
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

	var coins := 20 + maxi(0, 3 - medal_rank(medal)) * 10
	data["coins"] = int(data.get("coins", 0)) + coins
	info["coins"] = coins
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


func total_crowns() -> int:
	var crowns: Variant = data.get("crowns", [])
	return (crowns as Array).size() if crowns is Array else 0


func has_crown(id: String) -> bool:
	var crowns: Variant = data.get("crowns", [])
	return crowns is Array and id in crowns


func collect_crown(id: String) -> bool:
	if has_crown(id):
		return false
	var crowns: Array = data.get("crowns", [])
	crowns.append(id)
	data["crowns"] = crowns
	save_profile()
	crown_collected.emit(crowns.size())
	return true


func has_seen_tutorial() -> bool:
	return bool(data.get("tutorial_seen", false))


func mark_tutorial_seen() -> void:
	if has_seen_tutorial():
		return
	data["tutorial_seen"] = true
	save_profile()


func coins() -> int:
	return int(data.get("coins", 0))


func medal_count(medal: String) -> int:
	var medals: Dictionary = data.get("medals", {})
	return int(medals.get(medal, 0))
