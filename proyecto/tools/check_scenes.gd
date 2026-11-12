extends SceneTree

## Comprueba que todas las escenas de `res://scenes` cargan como PackedScene.
## La lista se descubre del sistema de ficheros: una escena nueva entra sola en
## la prueba, sin tener que apuntarla a mano.

const SCENES_ROOT := "res://scenes"


func _initialize() -> void:
	var scenes := _collect_scenes(SCENES_ROOT)
	if scenes.is_empty():
		print("FAIL: no se encontró ninguna escena en ", SCENES_ROOT)
		quit(1)
		return
	var failed := 0
	for path in scenes:
		if load(path) == null:
			print("FAIL: ", path)
			failed += 1
		else:
			print("OK:   ", path)
	print("RESULT: %d/%d scenes OK" % [scenes.size() - failed, scenes.size()])
	quit(1 if failed > 0 else 0)


func _collect_scenes(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_collect_scenes(full))
		elif entry.ends_with(".tscn"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found
