extends SceneTree

## Verifica los cuatro circuitos del torneo: escena cargable, LevelInfo, meta,
## checkpoints, ruta de bots, decoración y obstáculos propios de cada ronda.

var _failures := 0


func _initialize() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _run() -> void:
	# Espera a que los autoloads existan antes de cargar escenas con scripts
	# que usan AudioManager, SaveManager, etc.
	await process_frame
	await process_frame

	var paths := [
		"res://scenes/main.tscn",
		"res://scenes/levels/spin_go_round.tscn",
		"res://scenes/levels/glacier_gallop.tscn",
		"res://scenes/levels/lava_vortex.tscn",
	]
	var ids := ["pivot_push", "spin_go_round", "glacier_gallop", "lava_vortex"]
	var names := ["Pivot Push", "Spin Go Round", "Glacier Gallop", "Lava Vortex"]
	var round_counts := [11, 12, 9, 6]

	var session: Node = root.get_node("GameSession")
	_check(session.get("LEVELS").size() == 4, "GameSession registra cuatro circuitos")
	_check(int(session.call("level_count")) == 4, "El menú ofrece cuatro circuitos")
	for i in paths.size():
		_check(String(session.get("LEVELS")[i]) == paths[i],
			"Ronda %d apunta a %s" % [i + 1, paths[i]])
		_check(ResourceLoader.exists(paths[i]), "Existe %s" % paths[i])

	for i in paths.size():
		print("--- ", names[i], " ---")
		session.call("reset")
		var packed := load(paths[i]) as PackedScene
		_check(packed != null, "%s carga como PackedScene" % names[i])
		if packed == null:
			continue
		var level := packed.instantiate() as Node3D
		root.add_child(level)
		await process_frame
		await process_frame
		await process_frame

		var info := get_first_node_in_group("level_info") as Node
		_check(info != null, "%s tiene LevelInfo en su grupo" % names[i])
		if info != null:
			_check(String(info.get("level_id")) == ids[i],
				"%s guarda el id %s" % [names[i], ids[i]])
			_check(String(info.get("display_name")) == names[i],
				"%s muestra su nombre de ronda" % names[i])
			_check(int(info.get("round_index")) == i + 1,
				"%s es la ronda %d" % [names[i], i + 1])
			var waypoints: PackedVector3Array = info.get("waypoints")
			var lanes: PackedFloat32Array = info.get("lane_widths")
			_check(waypoints.size() >= 15,
				"%s tiene ruta de bots (%d puntos)" % [names[i], waypoints.size()])
			_check(lanes.size() == waypoints.size(),
				"%s tiene un ancho de carril por punto" % names[i])
			_check(float(info.get("finish_z")) < float(info.get("start_z")),
				"%s avanza hacia delante" % names[i])
			if i == 3:
				_check(bool(info.get("path_corridor")),
					"Lava Vortex corrige el rumbo del bot contra la ruta")

		var manager := get_first_node_in_group("race_manager") as Node
		_check(manager != null, "%s tiene RaceManager" % names[i])
		if manager != null:
			_check(String(manager.get("level_id")) == ids[i],
				"%s carga el récord de su circuito" % names[i])
			var checkpoints := get_nodes_in_group("checkpoints")
			_check(checkpoints.size() == round_counts[i],
				"%s tiene %d checkpoints (encontrados %d)"
					% [names[i], round_counts[i], checkpoints.size()])
			_check(int(manager.get("checkpoints_total")) == round_counts[i],
				"%s cuenta los checkpoints en el HUD" % names[i])

		var course := level.get_node_or_null("Course") as Node3D
		_check(course != null, "%s tiene Course" % names[i])
		if course != null:
			_check(course.get_node_or_null("FinishLine") != null,
				"%s tiene meta" % names[i])
			_check(course.get_node_or_null("StartPlatform") != null,
				"%s tiene salida" % names[i])
			var platforms := 0
			var bad_material := 0
			for child in course.get_children():
				if child is CSGBox3D:
					platforms += 1
					var box := child as CSGBox3D
					if box.material == null or box.size.y <= 0.0:
						bad_material += 1
				elif child is StaticBody3D:
					platforms += 1
			_check(platforms >= 6, "%s tiene %d plataformas" % [names[i], platforms])
			_check(bad_material == 0,
				"%s tiene todas las plataformas CSG con material" % names[i])

		if i == 0:
			_check(course.get_node_or_null("SeeSaw") != null,
				"Pivot Push conserva el balancín editado")
			_check(course.get_node_or_null("Sweeper") != null,
				"Pivot Push conserva los barridos")
			_check(course.get_node_or_null("ForgeDeck") != null
				and get_nodes_in_group("boulders").size() == 2,
				"Pivot Push tiene el pasillo de las rocas")
			_check(course.get_node_or_null("ChimneyBridge") != null
				and get_nodes_in_group("rotors").size() == 3,
				"Pivot Push tiene el puente de las aspas")
			_check(get_nodes_in_group("spike_traps").size() == 14,
				"Pivot Push tiene sus catorce trampas de pinchos")
			_check(course.get_node_or_null("ForgeSummit") != null
				and course.get_node_or_null("ForgeDrop") != null
				and course.get_node_or_null("ForgePlaza") != null,
				"Pivot Push sube a la cima y baja a la meta")
		elif i == 1:
			_check(course.get_node_or_null("SweeperA") != null,
				"Spin Go Round tiene barridos")
			_check(course.get_node_or_null("Centrifuge") != null,
				"Spin Go Round tiene plataforma giratoria")
			_check(course.get_node_or_null("MovingPlatform") != null,
				"Spin Go Round tiene plataforma móvil")
			_check(course.get_node_or_null("BallRain") != null,
				"Spin Go Round tiene lluvia de bolas")
			_check(course.get_node_or_null("SpinClimb") != null
				and course.get_node_or_null("SpinDrop") != null,
				"Spin Go Round tiene subida y bajada")
			_check(course.get_node_or_null("PressDeck") != null
				and course.get_node_or_null("PistonLeft") != null
				and course.get_node_or_null("PistonRight") != null,
				"Spin Go Round tiene la plataforma de los pistones")
			_check(get_nodes_in_group("crumble_tiles").size() == 12,
				"Spin Go Round tiene el puente de 12 losas frágiles")
			_check(course.get_node_or_null("BoulderDeck") != null
				and get_nodes_in_group("boulders").size() == 3,
				"Spin Go Round tiene el descenso de rocas")
			_check(course.get_node_or_null("SpikeDeck") != null
				and get_nodes_in_group("spike_traps").size() == 16,
				"Spin Go Round tiene la galería de 16 pinchos")
			_check(course.get_node_or_null("GateBridge") != null
				and get_nodes_in_group("rotors").size() == 3,
				"Spin Go Round tiene el puente de las tres aspas")
			_check(course.get_node_or_null("SummitClimb") != null
				and course.get_node_or_null("SummitDeck") != null,
				"Spin Go Round sube al mirador")
		elif i == 2:
			_check(course.get_node_or_null("IceLift") != null,
				"Glacier Gallop tiene la plataforma móvil del lago")
			_check(course.get_node_or_null("Centrifuge") != null
				and course.get_node_or_null("BallRain") != null,
				"Glacier Gallop tiene la arena giratoria con lluvia de bolas")
			_check(course.get_node_or_null("IceGallery") != null
				and course.get_node_or_null("PistonL") != null
				and course.get_node_or_null("PistonR") != null,
				"Glacier Gallop tiene la galería de pistones")
			_check(get_nodes_in_group("crumble_tiles").size() == 12,
				"Glacier Gallop tiene el puente de 12 placas frágiles")
			_check(course.get_node_or_null("GaleBridge") != null
				and get_nodes_in_group("rotors").size() == 2,
				"Glacier Gallop tiene el puente del vendaval")
			_check(course.get_node_or_null("BoulderDeck") != null
				and get_nodes_in_group("boulders").size() == 3,
				"Glacier Gallop tiene el pasillo de las rocas")
			_check(get_nodes_in_group("spike_traps").size() == 12,
				"Glacier Gallop tiene la terraza de 12 pinchos")
			_check(course.get_node_or_null("SummitPlatform") != null,
				"Glacier Gallop acaba en la cumbre helada")
		else:
			_check(course.get_node_or_null("SpiralDeck0") != null
				and course.get_node_or_null("SpiralDeck3") != null,
				"Lava Vortex construye la espiral completa")
			_check(level.get_node_or_null("LavaSea") != null,
				"Lava Vortex tiene el mar de lava")
			_check(level.get_node_or_null("MeteorRain") != null,
				"Lava Vortex tiene la lluvia de meteoros")
			_check(get_nodes_in_group("lava_geysers").size() >= 6,
				"Lava Vortex tiene al menos seis géiseres de lava")
			_check(get_nodes_in_group("sweepers").size() >= 4,
				"Lava Vortex tiene al menos cuatro barridos en la espiral")
			_check(get_nodes_in_group("spike_traps").size() >= 18,
				"Lava Vortex tiene al menos dieciocho trampas de pinchos")
			_check(course.get_node_or_null("SummitPlatform") != null,
				"Lava Vortex termina en la plataforma de la cumbre")

		if i < 2:
			var arena := level.get_node_or_null("ArenaDecor") as Node3D
			_check(arena != null, "%s tiene decoración de estadio" % names[i])
		else:
			var decor := level.get_node_or_null("Decor") as Node3D
			_check(decor != null and decor.get_child_count() >= 5,
				"%s tiene atrezo propio (%d piezas)" % [names[i],
					decor.get_child_count() if decor != null else 0])

		var kill := level.get_node_or_null("KillPlane") as Node3D
		_check(kill != null and kill.position.y < 0.0,
			"%s tiene plano de caída" % names[i])
		var player := get_first_node_in_group("player") as Node3D
		_check(player != null, "%s coloca al jugador" % names[i])

		root.remove_child(level)
		level.free()
		await process_frame

	# Flujo de cuatro rondas del torneo.
	session.call("start_bots", true)
	_check(String(session.get("level_path")) == paths[0], "El torneo empieza en Pivot Push")
	for round_number in [2, 3, 4]:
		session.call("advance_round")
		_check(int(session.get("round")) == round_number,
			"La ronda %d es la ronda %d" % [round_number, round_number])
		_check(String(session.get("level_path")) == paths[round_number - 1],
			"La ronda %d carga %s" % [round_number, names[round_number - 1]])
	session.call("advance_round")
	_check(int(session.get("round")) == 4, "El torneo se detiene en la final")
	_check(int(session.call("total_rounds")) == 4, "El torneo anuncia cuatro rondas")
	session.call("reset")

	print("RESULT: %s (%d fallos)" % ["TODO OK" if _failures == 0 else "HAY FALLOS", _failures])
	quit(1 if _failures > 0 else 0)
