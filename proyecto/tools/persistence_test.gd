extends SceneTree

## Prueba del perfil: escritura atomica, respaldo y recuperacion cuando el JSON
## principal se corrompe. Trabaja sobre el perfil headless, asi que no toca el
## guardado del jugador, y lo deja como estaba al terminar.

## Perfil propio del test: nunca el del jugador.
const SAVE := "user://profile.persistence_test.json"
const BACKUP := "user://profile.persistence_test.json.bak"
const TMP := "user://profile.persistence_test.json.tmp"
const CORRUPT := "user://profile.persistence_test.json.corrupt"

var _failures := 0
var _original := ""
var _had_original := false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var save: Node = root.get_node("SaveManager")
	save.call("use_profile_path", SAVE)
	if String(save.get("_save_path")) != SAVE:
		print("FAIL: no se pudo aislar el perfil; el test no toca nada")
		quit(1)
		return
	_had_original = FileAccess.file_exists(SAVE)
	if _had_original:
		var file := FileAccess.open(SAVE, FileAccess.READ)
		if file != null:
			_original = file.get_as_text()
			file.close()
	# El primer test necesita un estado conocido: se parte de un perfil vacio.
	_remove(SAVE)
	_remove(BACKUP)
	_remove(TMP)
	_remove(CORRUPT)

	var data: Dictionary = save.call("_default_data")
	save.set("data", data)
	data["coins"] = 123
	save.call("save_profile")
	_check(FileAccess.file_exists(SAVE), "El perfil se escribe")
	_check(not FileAccess.file_exists(TMP), "No queda temporal suelto")
	_check(not FileAccess.file_exists(BACKUP), "La primera escritura no crea respaldo")

	# Segunda escritura: ahora si hay original que copiar al respaldo.
	data["coins"] = 456
	save.call("save_profile")
	_check(FileAccess.file_exists(BACKUP), "El respaldo existe tras la segunda escritura")

	# Se corrompe el principal: debe apartarse y recuperarse el respaldo (123).
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{ esto no es json")
	file.close()
	save.call("load_profile")
	var coins := int(save.call("coins"))
	_check(coins == 123, "Un perfil corrupto recupera el respaldo (monedas %d)" % coins)
	_check(FileAccess.file_exists(CORRUPT), "El perfil ilegible se aparta, no se pisa")

	# Cierre entre borrar el principal y renombrar el temporal: sin fichero
	# principal, el respaldo sigue siendo la ultima copia buena.
	_remove(SAVE)
	save.call("load_profile")
	coins = int(save.call("coins"))
	_check(coins == 123, "Sin perfil principal recupera el respaldo (monedas %d)" % coins)

	# Los ajustes no escriben en disco en cada cambio: se difieren.
	data = save.get("data")
	var settings: Dictionary = data.get("settings", {})
	settings["music"] = 0.42
	data["settings"] = settings
	save.set("data", data)
	save.call("set_setting", "music", 0.42)
	_check(not FileAccess.file_exists(TMP), "Un ajuste no abre el temporal al instante")
	save.call("_on_save_timer")
	_check(FileAccess.file_exists(SAVE), "El guardado diferido acaba escribiendo")

	_restore()
	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _restore() -> void:
	_remove(CORRUPT)
	_remove(BACKUP)
	_remove(TMP)
	_remove(SAVE)
	if not _had_original:
		return
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	if file != null:
		file.store_string(_original)
		file.close()
