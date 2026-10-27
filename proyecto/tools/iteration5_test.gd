extends SceneTree

## Iteration 5 checks: menú de dos modos, submenú Personaje con desbloqueos por
## monedas, vista previa entera, flecha única, recompensas según tiempo y
## puesto, respawns sobre suelo firme y salida del balancín conectada con la
## plataforma de llegada. También comprueba que el balancín empuja a los bots
## igual que al jugador.

var _failures := 0
var _last_results: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _run() -> void:
	var save: Node = root.get_node("SaveManager")
	var session: Node = root.get_node("GameSession")
	await process_frame
	await process_frame
	var original_profile: Dictionary = (save.get("data") as Dictionary).duplicate(true)

	# --- Menú: dos modos y submenú Personaje ------------------------------
	var menu := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_check(menu.get_node_or_null("ModePanel/VBox/ClassicCard") != null,
		"El menú ofrece la carrera clásica")
	_check(menu.get_node_or_null("ModePanel/VBox/TournamentCard") != null,
		"El menú ofrece el torneo con bots")
	_check(menu.get_node_or_null("ModePanel/VBox/BotsButton") == null,
		"Ya no hay un tercer modo de juego")
	_check(String(ProjectSettings.get_setting("application/config/name")) == "Tumble Rush",
		"El juego tiene nombre propio: %s" % ProjectSettings.get_setting("application/config/name"))
	_check((menu.get_node("TopBar/HBox/Logo/Title") as Label).text == "TUMBLE RUSH",
		"El lobby muestra el nombre nuevo")

	# --- Lobby: fondo y estilo cartoon ------------------------------------
	var background := menu.get_node_or_null("Background") as TextureRect
	_check(background != null and background.texture is GradientTexture2D
		and menu.get_node_or_null("Rings") == null,
		"El fondo del lobby es un degradado, sin líneas")
	if background != null and background.texture is GradientTexture2D:
		var stops := (background.texture as GradientTexture2D).gradient.colors
		var vivid := maxf(stops[0].s, stops[stops.size() - 1].s) if not stops.is_empty() else 0.0
		_check(stops.size() >= 3 and vivid > 0.4,
			"El degradado es neón y vivo (%d paradas, saturación %.2f)" % [stops.size(), vivid])

	# --- Lobby: puesta en escena ------------------------------------------
	var mode_panel: Control = menu.get_node("ModePanel")
	var play_button: Button = menu.get_node("PlayButton")
	var play_style := play_button.get_theme_stylebox("normal") as StyleBoxFlat
	var play_pressed := play_button.get_theme_stylebox("pressed") as StyleBoxFlat
	_check(play_style != null and play_style.corner_radius_top_left >= 26
		and play_style.border_width_top >= 6 and play_style.shadow_size == 0
		and play_style.shadow_offset.y >= 10,
		"JUGAR es una pegatina 3D (radio %d, borde %d, sombra sólida %d px)" % [
			play_style.corner_radius_top_left if play_style else 0,
			play_style.border_width_top if play_style else 0,
			play_style.shadow_offset.y if play_style else 0])
	_check(play_style != null and play_pressed != null
		and play_pressed.shadow_offset.y < play_style.shadow_offset.y
		and play_pressed.content_margin_top > play_style.content_margin_top,
		"Al pulsar JUGAR se hunde (sombra %d -> %d px, texto %d -> %d px)" % [
			play_style.shadow_offset.y if play_style else 0,
			play_pressed.shadow_offset.y if play_pressed else 0,
			play_style.content_margin_top if play_style else 0,
			play_pressed.content_margin_top if play_pressed else 0])
	var nav_button: Button = menu.get_node("TopBar/HBox/NavRow/CharacterButton")
	var nav_style := nav_button.get_theme_stylebox("normal") as StyleBoxFlat
	_check(nav_style != null and not is_zero_approx(nav_style.skew.x)
		and nav_style.border_width_top >= 4 and nav_style.shadow_size == 0
		and nav_style.shadow_offset.y >= 5,
		"Los botones del lobby están inclinados y tienen sombra sólida (skew %.2f)" % [
			nav_style.skew.x if nav_style else 0.0])
	var panel_style := (menu.get_node("SeasonCard") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	_check(panel_style != null and panel_style.border_width_top >= 5
		and panel_style.shadow_size == 0 and panel_style.shadow_offset.y >= 8,
		"Las tarjetas son pegatinas con borde grueso y sombra sólida")
	_check(menu.theme != null and menu.theme.default_font != null,
		"El lobby usa una tipografía redondeada propia")
	_check(not mode_panel.visible, "El lobby empieza con la lista de modos cerrada")
	_check(play_button.get_global_rect().size.x >= 280.0
		and play_button.get_global_rect().size.y >= 80.0,
		"El botón JUGAR es el protagonista (%.0fx%.0f)" % [
			play_button.get_global_rect().size.x, play_button.get_global_rect().size.y])
	play_button.pressed.emit()
	await process_frame
	_check(mode_panel.visible, "JUGAR abre la elección de modo")
	_check(mode_panel.get_global_rect().encloses(
		(menu.get_node("ModePanel/VBox/TournamentCard") as Control).get_global_rect()),
		"Los dos modos caben dentro del panel del lobby")

	var lobby_stage: Node3D = menu.get_node("LobbyStage/SubViewport/Stage")
	var lobby_viewport := menu.get_node("LobbyStage/SubViewport") as SubViewport
	var lobby_camera := menu.get_node("LobbyStage/SubViewport/Camera3D") as Camera3D
	var lobby_model := lobby_stage.get_node_or_null("LobbyModel") as Node3D
	_check(lobby_model != null, "El lobby enseña al corredor equipado en 3D")
	if lobby_model != null:
		var bounds := _screen_bounds(lobby_stage, lobby_camera)
		_check(int(bounds["in_frustum"]) == 8
			and float(bounds["top"]) > 6.0
			and float(bounds["bottom"]) < float(lobby_viewport.size.y) - 6.0
			and float(bounds["left"]) > 6.0
			and float(bounds["right"]) < float(lobby_viewport.size.x) - 6.0,
			"El lobby encuadra al personaje y su peana enteros (%.0f..%.0f de %d px)" % [
				float(bounds["top"]), float(bounds["bottom"]), lobby_viewport.size.y])
	var player_name: Label = menu.get_node("PlayerBadge/HBox/VBox/PlayerNameLabel")
	_check(player_name.text == CharacterCatalog.display_name(save.call("character_id")),
		"El lobby muestra el nombre del corredor equipado (%s)" % player_name.text)
	var season_progress: ProgressBar = menu.get_node("SeasonCard/VBox/LobbyProgress")
	_check(season_progress.value >= 0.0 and season_progress.value <= 100.0,
		"La tarjeta de temporada muestra un progreso válido (%.0f%%)" % season_progress.value)
	var pieces: Array[Rect2] = [
		(menu.get_node("SeasonCard") as Control).get_global_rect(),
		(menu.get_node("PlayerBadge") as Control).get_global_rect(),
		play_button.get_global_rect(),
		(menu.get_node("LobbyStage") as Control).get_global_rect(),
		(menu.get_node("TopBar") as Control).get_global_rect(),
	]
	var overlapping := 0
	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			if pieces[i].intersects(pieces[j]):
				overlapping += 1
	_check(overlapping == 0, "Las piezas del lobby no se solapan (%d cruces)" % overlapping)

	var character_panel: Control = menu.get_node("CharacterPanel")
	_check(character_panel != null and not character_panel.visible,
		"El submenú Personaje empieza cerrado")
	var character_button: Button = menu.get_node("TopBar/HBox/NavRow/CharacterButton")
	character_button.pressed.emit()
	await process_frame
	_check(character_panel.visible, "El botón PERSONAJE abre su submenú")
	var panel_rect := character_panel.get_global_rect()
	var last_row: Control = menu.get_node(
		"CharacterPanel/VBox/Body/Roster/BarbarianRow/BarbarianStatus")
	_check(panel_rect.size.x <= menu.size.x and panel_rect.size.y <= menu.size.y
		and panel_rect.encloses(last_row.get_global_rect()),
		"El submenú y su lista de personajes caben en el panel")

	var roster := 0
	var names := ["RogueRow/RogueButton", "HoodedRow/HoodedButton", "KnightRow/KnightButton",
		"MageRow/MageButton", "BarbarianRow/BarbarianButton"]
	for row_name in names:
		if menu.get_node_or_null("CharacterPanel/VBox/Body/Roster/%s" % row_name) != null:
			roster += 1
	_check(roster == CharacterCatalog.CHARACTERS.size(),
		"El submenú lista los %d personajes (%d)" % [CharacterCatalog.CHARACTERS.size(), roster])
	var preview_stage: Node3D = menu.get_node(
		"CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport/Stage")
	var preview_viewport := menu.get_node(
		"CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport") as SubViewport
	await process_frame
	var framed_model := preview_stage.get_node_or_null("PreviewModel") as Node3D
	_check(framed_model != null, "El submenú muestra una vista previa 3D")
	if framed_model != null:
		var preview_camera := preview_viewport.get_node("Camera3D") as Camera3D
		var bounds := _screen_bounds(preview_stage, preview_camera)
		_check(int(bounds["in_frustum"]) == 8
			and float(bounds["top"]) > 6.0
			and float(bounds["bottom"]) < float(preview_viewport.size.y) - 6.0,
			"La vista previa encuadra al personaje y su peana enteros (%.0f..%.0f de %d px)" % [
				float(bounds["top"]), float(bounds["bottom"]), preview_viewport.size.y])

	# --- Desbloqueos con monedas ------------------------------------------
	var profile: Dictionary = save.get("data")
	var old_coins: int = int(profile.get("coins", 0))
	var old_unlocks: Array = (profile.get("unlocked_characters", []) as Array).duplicate()
	var old_character := String(save.call("character_id"))
	profile["coins"] = 50
	profile["unlocked_characters"] = [CharacterCatalog.default_id()]
	profile["character"] = CharacterCatalog.default_id()
	save.call("save_profile")

	_check(bool(save.call("is_character_unlocked", "rogue")),
		"Chispa viene desbloqueada de fábrica")
	_check(not bool(save.call("is_character_unlocked", "mage")),
		"Tornillo empieza bloqueado")
	save.call("set_character", "mage")
	_check(String(save.call("character_id")) == "rogue",
		"No se puede equipar un personaje bloqueado")
	_check(not bool(save.call("buy_character", "mage")),
		"Sin monedas suficientes no se desbloquea Tornillo")

	menu.call("_refresh_character_panel")
	var mage_button: Button = menu.get_node(
		"CharacterPanel/VBox/Body/Roster/MageRow/MageButton")
	mage_button.pressed.emit()
	await process_frame
	var buy_button: Button = menu.get_node("CharacterPanel/VBox/Body/PreviewBox/BuyButton")
	_check(buy_button.disabled and buy_button.text.begins_with("NECESITAS"),
		"El botón de compra avisa de las monedas que faltan (%s)" % buy_button.text)

	profile["coins"] = 1000
	save.call("save_profile")
	menu.call("_refresh_character_panel")
	_check(not buy_button.disabled and buy_button.text.begins_with("DESBLOQUEAR"),
		"Con monedas suficientes se puede comprar (%s)" % buy_button.text)
	buy_button.pressed.emit()
	await process_frame
	_check(bool(save.call("is_character_unlocked", "mage")), "Tornillo queda desbloqueado al comprarlo")
	_check(int(save.call("coins")) == 1000 - int(save.call("character_price", "mage")),
		"La compra descuenta su precio (%d monedas)" % int(save.call("coins")))
	_check(String(save.call("character_id")) == "mage", "El personaje comprado queda equipado")
	var mage_status: Label = menu.get_node(
		"CharacterPanel/VBox/Body/Roster/MageRow/MageStatus")
	_check(mage_status.text == "ELEGIDO", "El submenú marca el personaje elegido (%s)" % mage_status.text)
	var preview_model: Node3D = preview_stage.get_node_or_null("PreviewModel")
	_check(preview_model != null and String(menu.get("_preview_id")) == "mage",
		"La vista previa muestra el personaje comprado (%s)" % String(menu.get("_preview_id")))

	# El elegido se guarda en el perfil y sobrevive a una recarga.
	save.call("load_profile")
	_check(String(save.call("character_id")) == "mage"
		and bool(save.call("is_character_unlocked", "mage")),
		"El desbloqueo y el personaje se conservan en el perfil")

	# Restaura el perfil de quien ejecuta el test.
	profile = save.get("data")
	profile["coins"] = old_coins
	profile["unlocked_characters"] = old_unlocks
	profile["character"] = old_character
	save.call("save_profile")
	menu.queue_free()
	await process_frame

	# --- Monedas según tiempo y puesto ------------------------------------
	var fast_win: Dictionary = save.call("coin_reward", 70.0, "gold", 1)
	var slow_last: Dictionary = save.call("coin_reward", 150.0, "none", 8)
	var slow_win: Dictionary = save.call("coin_reward", 125.0, "bronze", 1)
	var no_bonus: Dictionary = save.call("coin_reward", 400.0, "none", 0)
	_check(int(fast_win["total"]) > int(slow_last["total"]),
		"Una carrera rápida y ganada paga más que una lenta y última (%d vs %d)" % [
			int(fast_win["total"]), int(slow_last["total"])])
	_check(int(fast_win["time"]) > int(slow_win["time"]),
		"Mejor tiempo paga más monedas de tiempo (%d vs %d)" % [
			int(fast_win["time"]), int(slow_win["time"])])
	_check(int(slow_win["position"]) > int(no_bonus["position"]),
		"Mejor puesto paga más monedas de clasificación")
	_check(int(no_bonus["total"]) == int(no_bonus["base"]),
		"Sin tiempo ni puesto solo queda la base (%d)" % int(no_bonus["total"]))

	# --- Carrera: arranque del modo correcto ------------------------------
	session.call("start_classic")
	_check(not bool(session.call("is_bot_race")), "El modo clásico no tiene bots")
	_check(bool(session.call("is_tournament")) == false, "El modo clásico no es torneo")

	# --- Repaso geométrico del circuito ----------------------------------
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for i in 3:
		await process_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state

	for node in get_nodes_in_group("checkpoints"):
		var checkpoint := node as Node3D
		var marker := checkpoint.get_node("SpawnMarker") as Node3D
		var spawn: Vector3 = marker.global_position + Vector3.UP * 0.5
		var floor_y := _floor_y(space, Vector3(spawn.x, spawn.y + 0.05, spawn.z))
		_check(floor_y > -50.0 and floor_y < spawn.y,
			"%s respawnea sobre suelo firme (suelo %.2f, spawn %.2f)" % [
				String(checkpoint.get("checkpoint_name")), floor_y, spawn.y])

	# Respawn real en el checkpoint del pasillo de cintas: el jugador debe
	# quedarse sobre la plataforma, no caer al vacío.
	var player := get_first_node_in_group("player") as CharacterBody3D
	var conveyor_cp: Node3D = null
	for node in get_nodes_in_group("checkpoints"):
		if String(node.get("checkpoint_name")) == "Checkpoint 2":
			conveyor_cp = node as Node3D
	if conveyor_cp != null:
		var spawn: Transform3D = (conveyor_cp.get_node("SpawnMarker") as Node3D).global_transform
		spawn.origin.y += 0.5
		player.call("respawn_at", spawn)
		for i in 60:
			await physics_frame
		_check(player.is_on_floor() and player.global_position.y > -1.0,
			"Tras el respawn del pasillo de cintas el jugador sigue en la plataforma (y=%.2f)" % player.global_position.y)

	# El jugador real cruza el balancín y llega andando a su plataforma.
	player.call("respawn_at", Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -45.5)))
	await physics_frame
	Input.action_press("move_forward")
	for i in 360:
		await physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.z < -62.0 and player.is_on_floor() and player.global_position.y > -3.5,
		"Se puede cruzar del balancín a su landing (z=%.2f, y=%.2f)" % [
			player.global_position.z, player.global_position.y])

	# La salida del balancín tiene que ser continua hasta la plataforma.
	var max_step := 0.0
	var void_gaps := 0
	var previous := 0.0
	var first := true
	for i in 21:
		var z := -56.5 - float(i) * 0.5
		var floor_y := _floor_y(space, Vector3(0, 20, z))
		if floor_y <= -50.0:
			void_gaps += 1
			continue
		if not first:
			max_step = maxf(max_step, absf(floor_y - previous))
		previous = floor_y
		first = false
	_check(void_gaps == 0, "No hay huecos entre el balancín y su landing (%d)" % void_gaps)
	_check(max_step <= 0.65, "La salida del balancín es pisable (escalón máx %.2f m)" % max_step)
	_check(_floor_y(space, Vector3(0, 20, -58)) < -1.0,
		"Hay rampa descendente tras la tabla")
	_check(absf(_floor_y(space, Vector3(0, 20, -65))) < 0.3,
		"La rampa termina al nivel de la plataforma de llegada")

	# La punta volcada de la tabla cae sobre la rampa, no al vacío.
	var board := game.get_node("Course/SeeSaw") as Node3D
	var tip: Vector3 = board.global_position + Basis(Vector3.RIGHT, -0.5) * Vector3(0.0, 0.175, -5.0)
	var landing_under_tip := _floor_y(space, Vector3(tip.x, tip.y + 2.0, tip.z))
	_check(landing_under_tip > -50.0 and absf(landing_under_tip - tip.y) < 1.2,
		"La punta volcada del balancín tiene rampa debajo (punta %.2f, suelo %.2f)" % [
			tip.y, landing_under_tip])

	# --- El balancín empuja a los bots igual que al jugador ---------------
	var saw := (load("res://scenes/obstacles/see_saw.tscn") as PackedScene).instantiate() as Node3D
	saw.set_physics_process(false)
	game.add_child(saw)
	saw.global_position = Vector3(0, 0, -51)
	saw.rotation = Vector3(-0.5, 0, 0)
	saw.set("_tilt", -0.5)
	var bot := (load("res://scenes/race/bot_racer.tscn") as PackedScene).instantiate() as Node3D
	bot.set_physics_process(false)
	game.add_child(bot)
	bot.global_position = saw.global_position + Vector3(0, 0.6, -3.0)
	var riders: Array[Node3D] = [bot]
	saw.call("_apply_slide", riders)
	var external: Vector3 = bot.get("_external")
	_check(external.z < -1.0,
		"La tabla volcada desliza al bot cuesta abajo (empuje z=%.2f)" % external.z)
	_check(absf(external.z) >= float(saw.get("slide_speed")) * 0.95,
		"El bot recibe el mismo deslizamiento que el jugador")

	# --- La tarjeta de torneo arranca el modo con bots --------------------
	game.queue_free()
	await process_frame
	await process_frame
	var menu2 := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu2)
	current_scene = menu2
	await process_frame
	var play2: Button = menu2.get_node("PlayButton")
	play2.pressed.emit()
	await process_frame
	var tournament_card: Button = menu2.get_node("ModePanel/VBox/TournamentCard")
	tournament_card.pressed.emit()
	await process_frame
	_check(bool(session.call("is_tournament")) and bool(session.call("is_bot_race")),
		"La tarjeta de torneo activa el modo con bots")
	await create_timer(1.2).timeout
	_check(current_scene != null
		and current_scene.scene_file_path.ends_with("scenes/main.tscn"),
		"El torneo carga la escena de carrera")

	# --- Resultado de una carrera con bots ---------------------------------
	var race_manager: Node = get_first_node_in_group("race_manager")
	_check(race_manager != null, "El torneo arranca su RaceManager")
	if race_manager != null:
		race_manager.results_ready.connect(_on_results)
		race_manager.call("finish_race")
		await process_frame
	_check(int(_last_results.get("position", 0)) >= 1,
		"La carrera con bots registra el puesto (%d)" % int(_last_results.get("position", 0)))
	_check(int(_last_results.get("coins", 0)) > 0
		and not (_last_results.get("coins_breakdown", {}) as Dictionary).is_empty(),
		"El resultado trae monedas y su desglose (%d)" % int(_last_results.get("coins", 0)))
	var hud := current_scene.get_node_or_null("HUD")
	var breakdown_label: Label = null
	if hud != null:
		breakdown_label = hud.get_node_or_null("Root/ResultsPanel/VBox/ResultsCoinBreakdown") as Label
	_check(breakdown_label != null and not breakdown_label.text.is_empty(),
		"El HUD enseña el desglose de monedas (%s)" % (breakdown_label.text if breakdown_label else "sin HUD"))

	# --- Canción de victoria ----------------------------------------------
	var audio: Node = root.get_node("AudioManager")
	_check(bool(audio.call("is_victory_playing")),
		"Al acabar la partida suena la canción de victoria")
	var victory_stream := audio.get("_victory_stream") as AudioStream
	var victory_length := victory_stream.get_length() if victory_stream else 0.0
	_check(victory_stream != null and victory_length > 20.0 and victory_length < 24.0,
		"La fanfarria está recortada a ~22 s (%.1f s)" % victory_length)
	_check(audio.get_node("VictoryPlayer").bus == "Victory",
		"La fanfarria suena en su propio bus, sin depender del volumen de música")
	audio.call("play_music", false)
	_check(not bool(audio.call("is_victory_playing")) and bool(audio.call("is_music_playing")),
		"Volver al lobby corta la fanfarria y recupera la música")

	# Deja el perfil como estaba antes de ejecutar el test.
	save.set("data", original_profile)
	save.call("save_profile")

	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _on_results(data: Dictionary) -> void:
	_last_results = data


## Caja en pantalla que ocupa el modelo: sirve para comprobar que la cámara lo
## enseña entero (las 8 esquinas dentro del frustum y con margen arriba/abajo).
func _screen_bounds(model: Node3D, camera: Camera3D) -> Dictionary:
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if not instance.visible or instance.mesh == null:
			continue
		var mesh_box := instance.global_transform * instance.get_aabb()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	var bounds := {
		"in_frustum": 0, "top": 9999.0, "bottom": -9999.0,
		"left": 9999.0, "right": -9999.0,
	}
	if first:
		return bounds
	for i in 8:
		var point: Vector3 = box.get_endpoint(i)
		if camera.is_position_in_frustum(point):
			bounds["in_frustum"] = int(bounds["in_frustum"]) + 1
		var pixel := camera.unproject_position(point)
		bounds["top"] = minf(float(bounds["top"]), pixel.y)
		bounds["bottom"] = maxf(float(bounds["bottom"]), pixel.y)
		bounds["left"] = minf(float(bounds["left"]), pixel.x)
		bounds["right"] = maxf(float(bounds["right"]), pixel.x)
	return bounds


func _floor_y(space: PhysicsDirectSpaceState3D, from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -999.0
	var point: Vector3 = hit["position"]
	return point.y
