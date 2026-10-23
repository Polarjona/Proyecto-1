extends SceneTree

## Iteration 3 checks: new movement (dive), wind tunnel, launcher, see-saw,
## profile/settings, crowns, new scenes and results UI. Headless integration.

var _failures := 0


func _initialize() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _place(player: CharacterBody3D, at: Vector3) -> void:
	player.respawn_at(Transform3D(Basis.IDENTITY, at))
	for i in 90:
		await physics_frame
		if player.is_on_floor():
			return


func _run() -> void:
	# Los autoloads no existen como identificadores al compilar un script
	# lanzado con -s, pero sí como nodos del árbol: se resuelven en runtime.
	var session: Variant = root.get_node("GameSession")
	var save: Variant = root.get_node("SaveManager")
	session.start_classic()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame

	var player: CharacterBody3D = get_first_node_in_group("player")
	_check(player != null, "Jugador presente")

	# --- Escenas y nodos nuevos ------------------------------------------
	_check(game.get_node_or_null("Course/WindTunnel") != null, "Túnel de viento en el mapa")
	_check(game.get_node_or_null("Course/SeeSaw") != null, "Balancín en el mapa")
	_check(game.get_node_or_null("Course/Launcher") != null, "Cañón en el mapa")
	_check(game.get_node_or_null("SkyDome") != null, "Cúpula de nubes procedural")
	_check(game.get_node_or_null("Crowd") != null, "Multitud en gradas")
	_check(game.get_node_or_null("PostProcess") != null, "Capa de postproceso")
	_check(game.get_node_or_null("RaceDirector") != null, "Director de carrera")
	_check(get_nodes_in_group("crowns").size() == 3, "Tres coronas en el mapa")

	# --- Cámara y cara ----------------------------------------------------
	_check(player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") != null,
		"La cámara usa SpringArm3D")
	_check(player.get_node_or_null("MeshInstance3D/Head/Mouth") != null,
		"El personaje tiene boca animable")

	# --- Perfil y ajustes -------------------------------------------------
	var previous_shake: float = float(save.get_setting("shake", 1.0))
	save.set_setting("shake", 0.6)
	_check(is_equal_approx(float(save.get_setting("shake", 0.6)), 0.6),
		"Los ajustes se guardan y se releen")
	save.set_setting("shake", previous_shake)
	_check(save.medal_for(60.0) == "gold", "60 s da medalla de oro en el circuito largo")
	_check(save.medal_for(85.0) == "silver", "85 s da medalla de plata")
	_check(save.medal_for(120.0) == "bronze", "120 s da medalla de bronce")

	# --- Dive -------------------------------------------------------------
	await _place(player, Vector3(0.0, 0.6, 0.0))
	Input.action_press("dive")
	await physics_frame
	await physics_frame
	Input.action_release("dive")
	_check(player.is_prone(), "El dive deja al jugador tumbado y deslizando")
	_check(not player.can_dive(), "El dive entra en cooldown al usarse")
	for i in 40:
		await physics_frame
	_check(not player.can_dive(), "El cooldown sobrevive al final del deslizamiento")
	for i in 90:
		await physics_frame
	_check(player.can_dive(), "El dive vuelve a estar disponible tras el cooldown")

	# --- Túnel de viento --------------------------------------------------
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.9, -126.0)))
	for i in 15:
		await physics_frame
	_check(player.global_position.x > 0.05,
		"El viento empuja lateralmente al jugador (x=%.2f)" % player.global_position.x)

	# --- Cañón ------------------------------------------------------------
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.9, -139.2)))
	var launched := false
	for i in 8:
		await physics_frame
		if player.velocity.y > 2.0:
			launched = true
	_check(launched, "El cañón lanza al jugador por los aires")

	# --- Balancín ---------------------------------------------------------
	# Fuera del centro del balancín: justo en el pivote no se inclina.
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -48.0)))
	for i in 24:
		await physics_frame
	var saw: AnimatableBody3D = game.get_node("Course/SeeSaw")
	_check(absf(saw.get_tilt()) > 0.02,
		"El balancín se inclina hacia el jugador (%.2f rad)" % saw.get_tilt())

	# --- HUD y resultados -------------------------------------------------
	var hud: Node = game.get_node_or_null("HUD")
	_check(hud != null and hud.get_node_or_null("Root/ResultsPanel") != null,
		"El HUD incluye panel de resultados")
	_check(hud != null and hud.get_node_or_null("Root/TutorialPanel") != null,
		"El HUD incluye tutorial de primera vez")
	_check(hud != null and hud.get_node_or_null("Root/ProgressBar") != null,
		"El HUD incluye barra de progreso")

	# --- Modos ------------------------------------------------------------
	session.start_bots(false)
	_check(session.is_bot_race(), "El modo bots se activa")
	session.start_bots(true)
	_check(session.is_tournament() and session.round == 1,
		"El modo torneo arranca en la ronda 1")
	session.reset()

	_check(load("res://scenes/race/bot_racer.tscn") != null, "La escena del bot carga")
	_check(load("res://scenes/menu/settings_menu.tscn") != null, "La escena de ajustes carga")
	_check((load("res://scenes/race/hud.tscn") as PackedScene).instantiate() != null,
		"El HUD se instancia")

	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
