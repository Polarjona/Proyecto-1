extends SceneTree

## Verifica los tres circuitos del torneo: escena cargable, LevelInfo, meta,
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
		"res://scenes/levels/pivot_panic.tscn",
	]
	var ids := ["pivot_push", "spin_go_round", "pivot_panic"]
	var names := ["Pivot Push", "Spin Go Round", "Pivot Panic"]
	var finishes := [-206.0, -334.0, -145.0]
	var round_counts := [5, 12, 5]

	var session: Node = root.get_node("GameSession")
	_check(session.get("LEVELS").size() == 3, "GameSession registra tres circuitos")
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
			_check(is_equal_approx(float(info.get("finish_z")), finishes[i]),
				"%s termina en z=%.1f" % [names[i], finishes[i]])
			var waypoints: PackedVector3Array = info.get("waypoints")
			var lanes: PackedFloat32Array = info.get("lane_widths")
			_check(waypoints.size() >= 15, "%s tiene ruta de bots (%d puntos)" % [names[i], waypoints.size()])
			_check(lanes.size() == waypoints.size(),
				"%s tiene un ancho de carril por punto" % names[i])
			_check(float(info.get("finish_z")) < float(info.get("start_z")),
				"%s avanza hacia delante" % names[i])

		var manager := get_first_node_in_group("race_manager") as Node
		_check(manager != null, "%s tiene RaceManager" % names[i])
		if manager != null:
			_check(String(manager.get("level_id")) == ids[i],
				"%s carga el récord de su circuito" % names[i])
			var checkpoints := get_nodes_in_group("checkpoints")
			_check(checkpoints.size() == round_counts[i],
				"%s tiene %d checkpoints (encontrados %d)" % [names[i], round_counts[i], checkpoints.size()])
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
			_check(platforms >= 6, "%s tiene %d plataformas" % [names[i], platforms])
			_check(bad_material == 0, "%s tiene todas las plataformas con material" % names[i])

		if i == 0:
			_check(course.get_node_or_null("SeeSaw") != null,
				"Pivot Push conserva el balancín editado")
			_check(course.get_node_or_null("Sweeper") != null,
				"Pivot Push conserva los barridos")
		elif i == 1:
			_check(course.get_node_or_null("SweeperA") != null,
				"Spin Go Round tiene barridos")
			_check(course.get_node_or_null("Centrifuge") != null,
				"Spin Go Round tiene plataforma giratoria")
			_check(course.get_node_or_null("MovingPlatform") != null,
				"Spin Go Round tiene plataforma móvil")
			_check(course.get_node_or_null("BallRain") != null,
				"Spin Go Round tiene lluvia de bolas")
			_check(course.get_node_or_null("FinishApproach") != null,
				"Spin Go Round conecta el último tramo con la meta")
			_check(course.get_node_or_null("SpinClimb") != null
				and course.get_node_or_null("SpinDrop") != null,
				"Spin Go Round tiene subida y bajada")
			_check(course.get_node_or_null("PressDeck") != null
				and course.get_node_or_null("PistonLeft") != null
				and course.get_node_or_null("PistonRight") != null,
				"Spin Go Round tiene la plataforma de los pistones")
			_check(get_nodes_in_group("crumble_tiles").size() == 12,
				"Spin Go Round tiene el puente de 12 losas frágiles")
			_check(course.get_node_or_null("FinalClimb") != null,
				"Spin Go Round sube hasta la meta")
			_check(course.get_node_or_null("BoulderDeck") != null,
				"Spin Go Round tiene el descenso de rocas")
			_check(get_nodes_in_group("boulders").size() == 3,
				"Spin Go Round tiene las tres rocas del pasillo")
			_check(course.get_node_or_null("SpikeDeck") != null
				and get_nodes_in_group("spike_traps").size() == 16,
				"Spin Go Round tiene la galería de 16 pinchos")
			_check(course.get_node_or_null("GateBridge") != null
				and get_nodes_in_group("rotors").size() == 3,
				"Spin Go Round tiene el puente de las tres aspas")
			_check(course.get_node_or_null("SummitClimb") != null
				and course.get_node_or_null("SummitDeck") != null,
				"Spin Go Round sube al mirador")
			_check(course.get_node_or_null("SummitDrop") != null
				and course.get_node_or_null("FinalDeck") != null
				and course.get_node_or_null("FinishPlaza") != null,
				"Spin Go Round baja a la recta final")
		else:
			_check(course.get_node_or_null("SeeSaw") != null,
				"Pivot Panic tiene el balancín central")
			_check(course.get_node_or_null("PendulumA") != null,
				"Pivot Panic tiene péndulos")
			_check(course.get_node_or_null("WindTunnelA") != null,
				"Pivot Panic tiene túneles de viento")
			_check(course.get_node_or_null("Launcher") != null,
				"Pivot Panic tiene cañón")
			_check(course.get_node_or_null("BouncePadFinal") != null,
				"Pivot Panic tiene trampolín final")

		var decor := level.get_node_or_null("ArenaDecor") as Node3D
		_check(decor != null, "%s tiene decoración de estadio" % names[i])
		if decor != null:
			var centers: PackedVector3Array = decor.get("section_centers")
			var sizes: PackedVector2Array = decor.get("section_sizes")
			if i == 0:
				_check(centers.is_empty() and decor.get("build_arches") == true,
					"Pivot Push conserva la decoración original")
			else:
				_check(centers.size() >= 6 and centers.size() == sizes.size(),
					"%s decora sus %d tramos" % [names[i], centers.size()])
				_check(decor.get("build_arches") == false,
					"%s no hereda arcos del mapa original" % names[i])

		var kill := level.get_node_or_null("KillPlane") as Node3D
		_check(kill != null and kill.position.y < 0.0,
			"%s tiene plano de caída" % names[i])
		var player := get_first_node_in_group("player") as Node3D
		_check(player != null, "%s coloca al jugador" % names[i])

		root.remove_child(level)
		level.free()
		await process_frame

	# Flujo de tres rondas del torneo.
	session.call("start_bots", true)
	_check(String(session.get("level_path")) == paths[0], "El torneo empieza en Pivot Push")
	session.call("advance_round")
	_check(int(session.get("round")) == 2, "La segunda ronda es la ronda 2")
	_check(String(session.get("level_path")) == paths[1], "La segunda ronda carga Spin Go Round")
	session.call("advance_round")
	_check(int(session.get("round")) == 3, "La tercera ronda es la ronda 3")
	_check(String(session.get("level_path")) == paths[2], "La final carga Pivot Panic")
	session.call("advance_round")
	_check(int(session.get("round")) == 3, "El torneo se detiene en la final")
	session.call("reset")

	print("RESULT: %s (%d fallos)" % ["TODO OK" if _failures == 0 else "HAY FALLOS", _failures])
	quit(1 if _failures > 0 else 0)
