extends SceneTree

## Integration check: drives the real game loop headless (menu -> start ->
## race -> movement -> checkpoint -> finish) and reports what works.
## Needs the export/import cache built, so run it from the project folder.

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
	# --- 1. Menú principal -> botón INICIAR -------------------------------
	var menu: Node = (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var start_button: Button = menu.get_node("CenterContainer/VBoxContainer/StartButton")
	start_button.pressed.emit()
	await create_timer(1.5).timeout  # el fade dura 0.4 s

	var race: Node = current_scene
	var race_path := ""
	if race != null:
		race_path = race.scene_file_path
	_check(race_path.ends_with("scenes/main.tscn"), "INICIAR carga la escena de carrera (%s)" % race_path)
	if not race_path.ends_with("scenes/main.tscn"):
		print("RESULT: %d fallos (no se puede seguir sin escena de carrera)" % _failures)
		quit(1)
		return

	# --- 2. La carrera arranca con 3 checkpoints --------------------------
	var manager: Node = get_first_node_in_group("race_manager")
	var checkpoints: Array = get_nodes_in_group("checkpoints")
	_check(manager != null, "RaceManager presente y en su grupo")
	_check(checkpoints.size() == 3, "Se detectan los 3 checkpoints (encontrados: %d)" % checkpoints.size())
	_check(manager.checkpoints_total == 3, "El contador total del HUD es 3 (leído: %d)" % manager.checkpoints_total)
	_check(manager.is_running and not manager.is_finished, "El cronómetro está en marcha")

	# --- 3. El jugador se mueve al pulsar avanzar -------------------------
	var player: CharacterBody3D = get_first_node_in_group("player")
	_check(player != null, "Jugador presente y en su grupo")
	var time_before: float = manager.elapsed_time
	var origin: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i in 45:
		await physics_frame
	Input.action_release("move_forward")
	var travelled := (player.global_position - origin).length()
	_check(travelled > 0.5, "El jugador avanza al pulsar W (%.2f m)" % travelled)
	_check(manager.elapsed_time > time_before, "El cronómetro avanza (%.2f s)" % manager.elapsed_time)

	# --- 4. Saltar deja al jugador en el aire -----------------------------
	# OJO: `physics_frame` se emite ANTES de los `_physics_process`, así que hay
	# que esperar dos frames para leer el resultado del salto.
	_check(player.is_on_floor(), "El jugador está apoyado antes de saltar")
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	_check(not player.is_on_floor() and player.velocity.y > 0.0,
		"Saltar impulsa al jugador hacia arriba (vel.y=%+.2f m/s)" % player.velocity.y)
	for i in 45:
		await physics_frame  # dejarlo aterrizar de nuevo

	# --- 5. Cruzar un checkpoint ------------------------------------------
	var completed_before: int = manager.checkpoints_completed
	var checkpoint: Area3D = checkpoints[0]
	player.global_position = checkpoint.global_position + Vector3.UP * 1.0
	for i in 25:
		await physics_frame
	_check(manager.checkpoints_completed == completed_before + 1,
		"Cruzar un checkpoint incrementa el contador (%d -> %d)" % [completed_before, manager.checkpoints_completed])
	var hud: Node = race.get_node_or_null("HUD")
	_check(hud != null and hud.get_node("Root/CheckpointsLabel").text.begins_with("1/"),
		"El HUD refleja el checkpoint (%s)" % (hud.get_node("Root/CheckpointsLabel").text if hud else "sin HUD"))

	# --- 6. Cruzar la meta -------------------------------------------------
	var finish: Area3D = race.get_node("Course/FinishLine")
	player.global_position = finish.global_position + Vector3.UP * 1.0
	for i in 25:
		await physics_frame
	_check(manager.is_finished, "Cruzar la meta termina la carrera")

	# --- 7. Caer al vacío penaliza y respawnea ----------------------------
	manager.is_finished = false
	manager.is_running = true
	var penalty_before: float = manager.elapsed_time
	var kill_plane: Area3D = race.get_node("KillPlane")
	player.global_position = kill_plane.global_position
	for i in 25:
		await physics_frame
	_check(manager.elapsed_time >= penalty_before + manager.time_penalty - 0.5,
		"La caída aplica la penalización de +%.1f s" % manager.time_penalty)

	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
