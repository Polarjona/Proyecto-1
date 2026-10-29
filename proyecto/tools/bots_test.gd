extends SceneTree

## Bot AI integration test: checks that the pack spreads across lanes, keeps
## moving, uses the improved path and finishes the course without getting
## stuck. Headless and deterministic enough for CI.
##
## También comprueba que una caída cuesta el tramo: el bot vuelve a su último
## checkpoint en vez de aparecer en el que perseguía.

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
	# Fixed seed: lanes, speeds and stumbles are random by design, but the
	# rescue budget check must not depend on the run.
	seed(20261024)
	var session: Variant = root.get_node("GameSession")
	session.start_bots(false)
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3:
		await process_frame

	var bots: Array = get_nodes_in_group("bots")
	_check(bots.size() == 7, "Se crean los 7 bots (%d)" % bots.size())
	if bots.is_empty():
		print("RESULT: %d fallos (no hay bots)" % _failures)
		quit(1)
		return

	var lanes: Array[int] = []
	for bot in bots:
		lanes.append(int(round(float(bot.call("get_lane")) * 10.0)))
	var distinct_lanes := {}
	for lane in lanes:
		distinct_lanes[lane] = true
	_check(distinct_lanes.size() >= 4, "Los bots eligen carriles distintos (%d)" % distinct_lanes.size())
	# Los bots arrancan en la plataforma de salida, no repartidos por el
	# circuito. Se mira la zona y no el waypoint exacto: con la escena cargando,
	# el primer frame de física ya ha dado algún paso cuando el test mira.
	var at_start := 0
	for bot in bots:
		if bot.global_position.z > 0.0:
			at_start += 1
	_check(at_start == bots.size(),
		"Los 7 bots empiezan en la plataforma de salida (%d)" % at_start)

	var start_positions: Array[Vector3] = []
	for bot in bots:
		start_positions.append(bot.global_position)

	# 15 s: the whole pack should already be deep into the course and spread.
	for i in 900:
		await physics_frame
	var advanced := 0
	var min_z := 999.0
	var max_z := -999.0
	for bot in bots:
		if bot.global_position.z < -30.0:
			advanced += 1
		min_z = minf(min_z, bot.global_position.z)
		max_z = maxf(max_z, bot.global_position.z)
	_check(advanced == 7, "Los 7 bots superan el primer tramo a los 15 s (%d)" % advanced)
	_check(max_z - min_z > 2.0, "El pelotón se estira en vez de ir en bloque (%.1f m)" % (max_z - min_z))

	# Wait for the whole pack to finish, with a generous timeout.
	var finished_count := 0
	var frames := 0
	var finish_times: Array[float] = []
	while finished_count < bots.size() and frames < 10800:
		await physics_frame
		frames += 1
		finished_count = 0
		finish_times.clear()
		for bot in bots:
			if bool(bot.get("_finished")):
				finished_count += 1
				finish_times.append(float(frames) / 60.0)
	var max_rescues := 0
	for bot in bots:
		max_rescues = maxi(max_rescues, int(bot.call("get_rescue_count")))
		print("BOT pos=%s wp=%d lane=%.2f rescates=%d caidas=%d empujones=%d" % [
			bot.global_position, int(bot.call("get_waypoint_index")), float(bot.call("get_lane")),
			int(bot.call("get_rescue_count")), int(bot.call("get_fall_count")),
			int(bot.call("get_shortcut_count"))])
	_check(max_rescues <= 3, "Los bots apenas necesitan rescates (máx %d)" % max_rescues)
	var max_shortcuts := 0
	for bot in bots:
		max_shortcuts = maxi(max_shortcuts, int(bot.call("get_shortcut_count")))
	_check(max_shortcuts <= 1,
		"El empujón hacia delante es el último recurso (máx %d por bot)" % max_shortcuts)
	_check(finished_count == bots.size(),
		"Los 7 bots terminan el circuito (%d, %.1f s simulados)" % [finished_count, float(frames) / 60.0])
	var moved := 0
	for i in bots.size():
		if (bots[i].global_position - start_positions[i]).length() > 10.0:
			moved += 1
	_check(moved == bots.size(), "Ningún bot se queda atascado al inicio (%d)" % moved)

	# --- Una caída cuesta el tramo, no lo regala ---------------------------
	# Bot suelto con su propia ruta: se le deja pasado su último checkpoint y
	# por debajo del plano de caída. Al caer tiene que volver a ese checkpoint,
	# no aparecer en el que estaba persiguiendo.
	var fall_path := PackedVector3Array([
		Vector3(0.0, 0.2, 1.0), Vector3(0.0, 0.2, -6.0), Vector3(0.0, 0.2, -12.0),
		Vector3(0.0, 0.2, -18.0), Vector3(0.0, 0.2, -24.0), Vector3(0.0, 0.2, -30.0),
	])
	var faller := (load("res://scenes/race/bot_racer.tscn") as PackedScene).instantiate() as Node3D
	faller.set("waypoints", fall_path)
	faller.set("lane_widths", PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0]))
	faller.set("finish_z", -100.0)
	game.add_child(faller)
	faller.set("_waiting_for_start", false)
	# Ya pisó los checkpoints 0..3 (el último, z=-18) y persigue el 4 (z=-24).
	faller.set("_index", 4)
	faller.global_position = Vector3(0.0, -8.0, -32.0)
	faller.set("velocity", Vector3.ZERO)
	await physics_frame
	var checkpoint_z := float(fall_path[3].z)
	var chased_z := float(fall_path[4].z)
	_check(int(faller.call("get_fall_count")) == 1,
		"Al caer al vacío cuenta como caída (%d)" % int(faller.call("get_fall_count")))
	_check(faller.global_position.z > chased_z
		and absf(faller.global_position.z - checkpoint_z) < 0.6,
		"Al caer vuelve a su último checkpoint (z=%.2f, perseguía z=%.2f)" % [
			faller.global_position.z, chased_z])
	_check(int(faller.call("get_shortcut_count")) == 0,
		"Una caída sola no le regala el tramo")
	faller.queue_free()
	await process_frame

	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
