extends SceneTree

## Iteration 3 checks: new movement (dive), wind tunnel, launcher, see-saw,
## profile/settings, new scenes and results UI. Headless integration.

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
	_check(game.get_node_or_null("Course/Sweeper2") == null, "El segundo sweeper ya no está en el mapa")
	_check(game.get_node_or_null("Course/SeeSaw") != null, "Balancín en el mapa")
	var launcher_model: Node3D = game.get_node_or_null("Course/Launcher")
	_check(launcher_model != null, "Cañón en el mapa")
	var muzzle: Node3D = launcher_model.get_node_or_null("Tube/Muzzle")
	var bore: Node3D = launcher_model.get_node_or_null("Tube/Bore")
	var muzzle_ring: Node3D = launcher_model.get_node_or_null("Ring")
	_check(muzzle != null and bore != null and launcher_model.get_node_or_null("ArrowShaft") != null,
		"El launcher tiene cañón, boca y flecha de dirección visibles")
	_check(muzzle != null and bore != null and muzzle_ring != null
		and muzzle.global_position.z < launcher_model.global_position.z
		and bore.global_position.z < muzzle.global_position.z
		and absf(muzzle_ring.global_position.z - muzzle.global_position.z) < 0.5,
		"El cañón, boca y anillo apuntan hacia delante (-Z)")
	_check(game.get_node_or_null("SkyDome") != null, "Cúpula de nubes procedural")
	_check(game.get_node_or_null("Crowd") != null, "Multitud en gradas")
	_check(game.get_node_or_null("PostProcess") != null, "Capa de postproceso")
	_check(game.get_node_or_null("RaceDirector") != null, "Director de carrera")
	_check(get_nodes_in_group("crowns").is_empty(), "El sistema de coronas ya no existe")
	var arch_pillar: MeshInstance3D = game.get_node_or_null("ArenaDecor/ArchPillarL_1")
	var arch_bottom := -99.0
	if arch_pillar != null:
		arch_bottom = arch_pillar.global_position.y - (arch_pillar.mesh as BoxMesh).size.y * 0.5
	_check(arch_pillar != null and absf(arch_bottom - 0.6) < 0.05
		and absf(arch_pillar.global_position.z + 112.5) < 0.05,
		"El arco de LandingA apoya sus pilares en la plataforma (base y=%.2f)" % arch_bottom)
	var pendulum5: Node3D = game.get_node("Course/Pendulum5")
	var beam5: Node3D = game.get_node_or_null("ArenaDecor/PendulumBeam_4")
	var post5: Node3D = game.get_node_or_null("ArenaDecor/PendulumPost_4_L")
	_check(beam5 != null and post5 != null
		and absf(pendulum5.global_position.z - beam5.global_position.z) < 0.05
		and absf(post5.global_position.x + 4.2) < 0.05,
		"El péndulo 5 cuelga de un pórtico con soportes")

	# --- Cámara y cara ----------------------------------------------------
	_check(player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") != null,
		"La cámara usa SpringArm3D")
	_check(player.get_node_or_null("MeshInstance3D/Model/AnimationPlayer") != null,
		"El personaje usa un modelo 3D animado")

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
	var dive_from: Vector3 = player.global_position
	Input.action_press("dive")
	await physics_frame
	await physics_frame
	Input.action_release("dive")
	_check(player.is_prone(), "El dive deja al jugador tumbado y deslizando")
	_check(not player.can_dive(), "El dive entra en cooldown al usarse")
	var dive_distance := 0.0
	for i in 24:
		await physics_frame
		dive_distance = (player.global_position - dive_from).length()
	_check(dive_distance < 3.0, "El dive recorre una distancia corta (%.2f m)" % dive_distance)
	for i in 40:
		await physics_frame
	_check(not player.can_dive(), "El cooldown sobrevive al final del deslizamiento")
	for i in 90:
		await physics_frame
	_check(player.can_dive(), "El dive vuelve a estar disponible tras el cooldown")

	# --- Flechas del conveyor ---------------------------------------------
	var conveyor: Area3D = game.get_node("Course/ConveyorA1")
	var arrows: Node3D = conveyor.get_node_or_null("DirectionArrows")
	_check(arrows != null and arrows.get_child_count() == 4,
		"El conveyor dibuja cuatro flechas de dirección")
	if arrows != null and arrows.get_child_count() > 0:
		var arrow: Node3D = arrows.get_child(0)
		var first_x: float = arrow.position.x
		for i in 20:
			await process_frame
		_check(absf(arrow.position.x - first_x) > 0.05,
			"Las flechas del conveyor se mueven (%.2f m)" % absf(arrow.position.x - first_x))
		var reverse: Area3D = game.get_node("Course/ConveyorB1")
		var reverse_arrows: Node3D = reverse.get_node("DirectionArrows")
		_check(absf(absf(reverse_arrows.rotation.y) - PI) < 0.01,
			"Las flechas apuntan en el sentido de la cinta inversa")
		var final_conveyor: Area3D = game.get_node("Course/FinalConveyor")
		_check(is_equal_approx(float(final_conveyor.get("arrow_span")) * 2.0, 4.0),
			"Las flechas del conveyor final cubren justo su diseño de 4 m")

	# --- Túnel de viento --------------------------------------------------
	var wind1: Node3D = game.get_node("Course/WindTunnel")
	var wind2: Node3D = game.get_node("Course/WindTunnel2")
	var fan1: Node3D = wind1.get_node("Fan")
	var fan2: Node3D = wind2.get_node("Fan")
	var platform1: Node3D = wind1.get_node("FanPlatform")
	var platform2: Node3D = wind2.get_node("FanPlatform")
	var deck1: MeshInstance3D = platform1.get_node("Deck")
	var deck2: MeshInstance3D = platform2.get_node("Deck")
	var gap1 := absf(platform1.position.x) - (deck1.mesh as BoxMesh).size.x * 0.5 - 2.0
	var gap2 := absf(platform2.position.x) - (deck2.mesh as BoxMesh).size.x * 0.5 - 2.0
	_check(wind1.get_node_or_null("Banner") == null and wind2.get_node_or_null("Banner") == null,
		"Se quitaron los banderines de viento")
	_check(fan1.position.x * wind1.wind_direction.x < 0.0
		and fan2.position.x * wind2.wind_direction.x < 0.0,
		"Cada ventilador queda del lado de donde sopla el viento")
	_check(absf(fan1.position.x - platform1.position.x) < 0.01
		and absf(fan2.position.x - platform2.position.x) < 0.01,
		"Cada ventilador se apoya en su propia plataforma")
	_check(gap1 > 0.5 and gap2 > 0.5,
		"Las plataformas de los ventiladores están separadas del puente (huecos %.2f y %.2f m)" % [gap1, gap2])
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
	var saw: AnimatableBody3D = game.get_node("Course/SeeSaw")
	_check(player.max_speed <= 7.0, "El jugador corre a una velocidad contenida (%.1f m/s)" % player.max_speed)
	_check(absf(saw.get_tilt()) < 0.02,
		"El balancín queda horizontal cuando no hay nadie encima (%.3f rad)" % saw.get_tilt())
	# En el centro de la tabla el peso queda equilibrado, como en uno real.
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -51.0)))
	for i in 90:
		await physics_frame
	_check(absf(saw.get_tilt()) < 0.08,
		"Un jugador centrado mantiene el balancín nivelado (%.2f rad)" % saw.get_tilt())
	_check(float(saw.get("tip_threshold")) <= 0.03
		and float(saw.get("responsiveness")) >= 5.0
		and float(saw.get("slide_speed")) > 0.0,
		"El balancín está configurado como super inestable y resbaladizo")
	# Un desvío mínimo ya lo vuelca casi por completo. Se deja caer desde
	# poca altura para que el peso cuente desde el primer frame.
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.4, -50.4)))
	for i in 45:
		await physics_frame
	var tilt0: float = saw.get_tilt()
	_check(absf(tilt0) > 0.2,
		"Un desvío de 0,6 m ya hace volcar el balancín (%.2f rad)" % tilt0)
	# La base del balancín queda por debajo de la tabla incluso al volcar:
	# si asomara, se vería a través de la madera.
	var base: Node3D = game.get_node_or_null("Course/SeeSawBase")
	var base_top := -99.0
	if base != null and base is CSGBox3D:
		base_top = base.global_position.y + (base as CSGBox3D).size.y * 0.5
	_check(base != null and base_top < -0.9,
		"La base del balancín no asoma por encima de la tabla (%.2f m)" % base_top)
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -50.4)))
	for i in 4:
		await physics_frame
	_check(player.velocity.length() < 2.0, "El jugador no hereda velocidad al recolocarse")

	# --- HUD y resultados -------------------------------------------------
	var hud: Node = game.get_node_or_null("HUD")
	_check(hud != null and hud.get_node_or_null("Root/ResultsPanel") != null,
		"El HUD incluye panel de resultados")
	_check(hud != null and hud.get_node_or_null("Root/TutorialPanel") != null,
		"El HUD incluye tutorial de primera vez")
	_check(hud != null and hud.get_node_or_null("Root/ProgressBar") != null,
		"El HUD incluye barra de progreso")
	var splits_label: Label = hud.get_node_or_null("Root/ResultsPanel/VBox/ResultsSplits")
	_check(splits_label != null and not splits_label.visible,
		"La pantalla de victoria no muestra los tiempos de los checkpoints")

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
