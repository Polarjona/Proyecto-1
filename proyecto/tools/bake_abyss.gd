extends SceneTree

## Hornea Abyss Run. La escena solo contiene el generador (`level_builder.gd`
## con `level_kind = "ocean"`), así que el mapa se construía en cada arranque y
## no se podía editar en el editor. Este script instancia la escena, marca los
## nodos del generador con `owner` y guarda el resultado sobre el `.tscn`:
## desde entonces el circuito carga como cualquier otro mapa y el generador no
## reconstruye nada (su `_ready` detecta contenido y sale).
##
## Uso:
##   godot --headless --path . -s res://tools/bake_abyss.gd

const SCENE_PATH := "res://scenes/levels/abyss_run.tscn"
const BAKED_PATH := "res://scenes/levels/abyss_run.baked.tscn"


func _initialize() -> void:
	_run()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("no se pudo cargar %s" % SCENE_PATH)
		return
	var level := packed.instantiate() as Node3D
	if level == null:
		_fail("la escena no es un Node3D")
		return
	root.add_child(level)
	current_scene = level
	# El generador corre en `_ready`; tres frames bastan para que termine.
	for i in 3:
		await process_frame
	if level.get_child_count() < 10:
		_fail("el generador no creó el mapa (%d hijos)" % level.get_child_count())
		return
	print("Generado: %d hijos directos" % level.get_child_count())

	level.call("_own_generated", level)
	var scene := PackedScene.new()
	var err := scene.pack(level)
	if err != OK:
		_fail("no se pudo empaquetar (error %d)" % err)
		return
	err = ResourceSaver.save(scene, BAKED_PATH)
	if err != OK:
		_fail("no se pudo guardar %s (error %d)" % [BAKED_PATH, err])
		return

	# Verificación antes de pisar la escena buena: el horneado tiene que cargar,
	# traer su LevelInfo y seguir guardando al jugador como escena instanciada
	# (su modelo 3D se crea en runtime y se duplicaría si se horneara).
	current_scene = null
	root.remove_child(level)
	level.free()
	await process_frame
	var text := FileAccess.get_file_as_string(BAKED_PATH)
	var ok := true
	if text.contains("name=\"Model\""):
		_fail("el horneado incluye el modelo del jugador")
		ok = false
	var baked := load(BAKED_PATH) as PackedScene
	if baked == null:
		_fail("el horneado no carga")
		return
	var check := baked.instantiate() as Node3D
	root.add_child(check)
	await process_frame
	if check.get_child_count() < 10:
		_fail("el horneado sale vacío")
		ok = false
	if check.find_child("LevelInfo", true, false) == null:
		_fail("el horneado no trae LevelInfo")
		ok = false
	var player_node := check.get_node_or_null("Player") as Node3D
	if player_node == null or player_node.scene_file_path.is_empty():
		_fail("el jugador debería quedar como escena instanciada")
		ok = false
	root.remove_child(check)
	check.free()
	await process_frame
	if not ok:
		return

	# Sustituye la escena original con una copia de seguridad por si el
	# reemplazo fallara a mitad.
	var backup := SCENE_PATH + ".prebake"
	DirAccess.copy_absolute(SCENE_PATH, backup)
	DirAccess.remove_absolute(SCENE_PATH)
	err = DirAccess.rename_absolute(BAKED_PATH, SCENE_PATH)
	if err != OK:
		DirAccess.rename_absolute(backup, SCENE_PATH)
		_fail("no se pudo reemplazar la escena (error %d)" % err)
		return
	DirAccess.remove_absolute(backup)
	print("ABYSS HORNEADO OK: %s" % SCENE_PATH)
	quit(0)


func _fail(message: String) -> void:
	print("FAIL: %s" % message)
	quit(1)
