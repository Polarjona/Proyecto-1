extends SceneTree

## Iteration 4 checks: selector de personaje, modelos extra, flecha sobre el
## jugador, bots con skins aleatorios, audio nuevo, música solo en el menú y
## el arco de meta nuevo. Todo headless.

## Fila del roster del personaje gratis con el que arranca un perfil nuevo y
## carpeta de la que sale su modelo.
const STARTER_ROW := "Coco"
const STARTER_DIR := "res://assets/characters/mini/"

var _failures := 0
var _audio: Node
var _save: Node
var _session: Node


func _initialize() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _run() -> void:
	_audio = root.get_node("AudioManager")
	_save = root.get_node("SaveManager")
	_session = root.get_node("GameSession")
	# Deja que los autoloads ejecuten su _ready (carga de buses y SFX).
	await process_frame
	await process_frame

	# --- Catálogo de personajes ------------------------------------------
	_check(CharacterCatalog.CHARACTERS.size() >= 5,
		"El catálogo tiene al menos 5 personajes (%d)" % CharacterCatalog.CHARACTERS.size())
	var models_ok := true
	var unique_ids := {}
	for entry in CharacterCatalog.CHARACTERS:
		var path := String(entry.get("scene", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			models_ok = false
		unique_ids[String(entry.get("id", ""))] = true
	_check(models_ok, "Todos los modelos del catálogo existen")
	_check(unique_ids.size() == CharacterCatalog.CHARACTERS.size(), "Los ids de personaje son únicos")

	# --- Audio nuevo -------------------------------------------------------
	for key in ["step", "wind", "cannon", "creak", "boing", "whoosh"]:
		_check(_audio.call("get_sfx_stream", key) != null, "SFX '%s' cargado" % key)
	_check(ResourceLoader.exists("res://audio/music/menu_theme.wav"), "Existe el tema nuevo del menú")
	var wind: AudioStream = _audio.call("get_sfx_stream", "wind")
	_check(wind is AudioStreamWAV
		and (wind as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"El viento está preparado para sonar en bucle")
	_check(not bool(_audio.call("is_music_playing")), "La música no arranca sola antes del menú")
	_check(String(ProjectSettings.get_setting("application/config/icon")) == "res://icon.svg",
		"El icono del proyecto apunta al SVG nuevo")

	# --- Menú: selector y vista previa ------------------------------------
	var previous_character := String(_save.call("character_id"))
	var menu: Node = (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_check(menu.get_node_or_null("CharacterPanel/VBox/Body/RosterScroll/Roster/%sRow/%sButton" % [STARTER_ROW, STARTER_ROW]) != null,
		"El submenú de personaje incluye el selector")
	_check(menu.get_node_or_null(
		"CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport/Stage") != null,
		"El submenú de personaje incluye la vista previa 3D")
	_check(bool(_audio.call("is_music_playing")), "La música suena en el menú")
	var music_stream: AudioStream = _audio.get("_music_stream")
	_check(music_stream is AudioStreamWAV
		and (music_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"El tema del menú está en bucle")

	var starter_button: Button = menu.get_node(
		"CharacterPanel/VBox/Body/RosterScroll/Roster/%sRow/%sButton" % [STARTER_ROW, STARTER_ROW])
	starter_button.pressed.emit()
	await process_frame
	_check(String(_save.call("character_id")) == CharacterCatalog.default_id(),
		"Elegir personaje se guarda en el perfil")
	var stage: Node3D = menu.get_node(
		"CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport/Stage")
	var preview_model: Node3D = stage.get_node_or_null("PreviewModel")
	_check(preview_model != null
		and preview_model.find_child("AnimationPlayer", true, false) != null,
		"La vista previa carga el modelo elegido")
	menu.queue_free()
	await process_frame

	# --- Carrera clásica: sin música, personaje y flecha -------------------
	_session.call("start_classic")
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for i in 4:
		await process_frame
	_check(not bool(_audio.call("is_music_playing")), "La música se detiene durante la partida")
	var player: CharacterBody3D = get_first_node_in_group("player")
	_check(player != null, "Jugador presente en la carrera")
	if player != null:
		_check(String(player.get("character_id")) == CharacterCatalog.default_id(),
			"El jugador usa el personaje elegido (%s)" % String(player.get("character_id")))
		var model: Node3D = player.get_node_or_null("MeshInstance3D/Model")
		_check(model != null
			and String(CharacterCatalog.by_id(CharacterCatalog.default_id())["scene"]).begins_with(STARTER_DIR)
			and model.find_child("AnimationPlayer", true, false) != null,
			"El modelo cargado es el del personaje elegido")
		_check(player.get_node_or_null("MeshInstance3D/Model/AnimationPlayer") != null,
			"El personaje elegido trae AnimationPlayer")
		var marker: Node3D = player.get_node_or_null("Marker")
		_check(marker != null and marker.visible,
			"El jugador lleva la flecha FIFA sobre la cabeza")
		_check(marker != null and marker.get_child_count() == 1
			and marker.get_node_or_null("ArrowTop") == null,
			"La flecha sobre la cabeza no está duplicada")
		# El túnel de viento tiene su propio bucle 3D.
		var wind_tunnel: Node3D = game.get_node_or_null("Course/WindTunnel")
		_check(wind_tunnel != null and wind_tunnel.get_node_or_null("WindAudio") != null,
			"El túnel de viento tiene audio de viento")
		# La base del balancín queda por debajo de la tabla incluso al volcar.
		var saw: Node3D = game.get_node_or_null("Course/SeeSaw")
		var base: CSGBox3D = game.get_node_or_null("Course/SeeSawBase")
		if saw != null and base != null:
			saw.set_physics_process(false)
			saw.rotation = Vector3(0.5, 0.0, 0.16)
			var base_top := base.global_position.y + base.size.y * 0.5
			var lowest := 999.0
			for x in [-0.7, 0.0, 0.7]:
				for z in [-0.7, 0.0, 0.7]:
					lowest = minf(lowest, (saw.global_transform * Vector3(x, -0.175, z)).y)
			_check(lowest > base_top,
				"La base no atraviesa la tabla volcada (holgura %.2f m)" % (lowest - base_top))

	# --- Arco de meta nuevo ------------------------------------------------
	var finish: Area3D = game.get_node_or_null("Course/FinishLine")
	_check(finish != null, "El arco de meta está en el circuito")
	if finish != null:
		_check(finish.get_node_or_null("Arch") != null, "El arco tiene estructura propia")
		_check(finish.get_node_or_null("Arch/Banner") != null, "El arco tiene cartel a cuadros")
		var meta: Label3D = finish.get_node_or_null("Arch/MetaLabel")
		_check(meta != null and meta.text == "META", "El cartel muestra META")
		_check(finish.get_node_or_null("Arch/Beam") != null
			and finish.get_node_or_null("Arch/PillarLeft") != null
			and finish.get_node_or_null("Arch/PillarRight") != null,
			"La meta es un pórtico con dintel y dos torres")
		_check(finish.get_node_or_null("Arch/Flag1") == null
			and finish.get_node_or_null("Arch/Crown") == null
			and finish.get_node_or_null("Arch/Neon1") == null,
			"La meta ya no acumula banderas, corona ni neones sueltos")
		_check(finish.get_node_or_null("ConfettiLeft") != null
			and finish.get_node_or_null("ConfettiRight") != null
			and finish.get_node_or_null("ConfettiBurst") != null,
			"El arco tiene confeti de meta")
	game.queue_free()
	await process_frame

	# --- Bots con personajes aleatorios ------------------------------------
	_session.call("start_bots", false)
	var race: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	current_scene = race
	for i in 4:
		await process_frame
	var bots: Array = get_nodes_in_group("bots")
	_check(bots.size() == 7, "Se crean los 7 bots (%d)" % bots.size())
	var distinct := {}
	var with_model := 0
	var with_marker := 0
	for bot in bots:
		distinct[String(bot.get("character_id"))] = true
		if bot.get_node_or_null("Body/Model") != null:
			with_model += 1
		if bot.get_node_or_null("Marker") != null:
			with_marker += 1
	_check(with_model == bots.size(), "Cada bot tiene un modelo de personaje")
	_check(distinct.size() >= 2, "Los bots usan personajes variados (%d distintos)" % distinct.size())
	_check(with_marker == 0, "Los bots no llevan la flecha del jugador")
	_check(not bool(_audio.call("is_music_playing")), "La carrera contra bots tampoco tiene música")

	_save.call("set_character", previous_character)
	_session.call("reset")
	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
