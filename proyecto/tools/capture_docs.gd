extends SceneTree

## Genera las capturas de documentación con el render real del juego.
##
## Uso, desde `proyecto/` y con ventana (no `--headless`):
##   ../.tools/Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/capture_docs.gd
##
## Escribe en `documentacion/capturas/` y usa un perfil aislado para no tocar
## el progreso del jugador. Las imágenes se guardan en WebP a la resolución del
## proyecto.

const OUT_DIR := "documentacion/capturas"
const PROFILE := "user://profile.docs_capture.json"

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

const LEVELS := [
	"pivot_push",
	"spin_go_round",
	"glacier_gallop",
	"lava_vortex",
	"abyss_run",
]

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var save: Node = root.get_node("SaveManager")
	save.call("use_profile_path", PROFILE)
	for path in [PROFILE, PROFILE + ".bak", PROFILE + ".tmp", PROFILE + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.call("load_profile")
	await process_frame
	save.call("set_setting", "language", "es")
	save.call("mark_tutorial_seen")
	await process_frame

	var out_dir := _output_dir()
	print("CAPTURAS -> ", out_dir)
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		push_error("No se pudo crear " + out_dir)
		quit(1)
		return

	await _capture_menu(out_dir)
	await _capture_mode_panel(out_dir)
	for level in LEVELS:
		await _capture_level(out_dir, String(level))
	await _capture_tournament_race(out_dir)
	await _capture_results(out_dir)

	if _failures > 0:
		print("CAPTURAS CON ", _failures, " ERRORES")
		quit(1)
		return
	print("CAPTURAS OK")
	quit(0)


func _output_dir() -> String:
	var project := ProjectSettings.globalize_path("res://").trim_suffix("/")
	return project.get_base_dir().path_join(OUT_DIR)


func _capture_menu(out_dir: String) -> void:
	if not await _show_scene(MENU_SCENE):
		return
	await _wait(0.8)
	await _save(out_dir, "menu_principal")


func _capture_mode_panel(out_dir: String) -> void:
	var menu := current_scene
	if menu == null:
		push_error("No hay menú para la captura del panel de modos")
		_failures += 1
		return
	var tournament := menu.get_node_or_null("ModeCards/TournamentCard") as Button
	if tournament == null:
		push_error("No hay TournamentCard para la captura del lobby")
		_failures += 1
		return
	# El modo ya no vive en un modal: la captura enfoca la tarjeta de torneo
	# dentro del propio lobby.
	tournament.grab_focus()
	await _wait(0.2)
	await _save(out_dir, "menu_torneo")


func _capture_level(out_dir: String, level_id: String) -> void:
	if not await _show_scene("res://scenes/levels/%s.tscn" % level_id):
		return
	(root.get_node("GameSession") as Node).call("start_classic")
	await _wait(3.0)
	await _save(out_dir, level_id)


func _capture_results(out_dir: String) -> void:
	(root.get_node("GameSession") as Node).call("start_classic")
	if not await _show_scene("res://scenes/levels/pivot_push.tscn"):
		return
	await _wait(2.6)
	var manager := get_first_node_in_group("race_manager")
	if manager == null:
		push_error("No hay RaceManager para la captura de resultados")
		_failures += 1
		return
	manager.set("elapsed_time", 64.2)
	manager.set("fall_count", 1)
	manager.call("finish_race")
	await _wait(1.1)
	await _save(out_dir, "resultados")


func _capture_tournament_race(out_dir: String) -> void:
	(root.get_node("GameSession") as Node).call("start_bots", true)
	if not await _show_scene("res://scenes/levels/pivot_push.tscn"):
		return
	await _wait(3.0)
	await _save(out_dir, "torneo_carrera")


func _show_scene(path: String) -> bool:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("No se pudo cargar " + path)
		_failures += 1
		return false
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	return true


func _save(out_dir: String, stem: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var file_name := stem + ".webp"
	var path := out_dir.path_join(file_name)
	var error := image.save_webp(path, true, 0.9)
	print("  ", file_name, " ", image.get_size(), " err=", error)
	if error != OK:
		push_error("No se pudo guardar " + path)
		_failures += 1


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
