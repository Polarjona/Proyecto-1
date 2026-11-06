extends SceneTree

## Feature check for the map + character iteration: verifies the new
## interactive obstacles (bounce pad, moving platform, sweeper, ball
## dropper) and the player physics/graphics upgrades (variable jump,
## stun, limbs, shadow). Headless integration test.

var _failures := 0


func _initialize() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


## Respawns the player at a clean transform and waits until they stand on a floor.
func _place_player(player: CharacterBody3D, at: Vector3) -> void:
	player.respawn_at(Transform3D(Basis.IDENTITY, at))
	# `physics_frame` is emitted before `_physics_process`, so wait two frames
	# or the stale `is_on_floor()` from the previous spot reads as a landing.
	await physics_frame
	await physics_frame
	for i in 120:
		await physics_frame
		if player.is_on_floor():
			return


## Respawns the player and only runs a fixed number of frames (no floor wait).
func _place_player_briefly(player: CharacterBody3D, at: Vector3, frames: int) -> void:
	player.respawn_at(Transform3D(Basis.IDENTITY, at))
	for i in frames:
		await physics_frame


## Jumps while holding the button `hold_frames` physics frames and returns
## the apex height gained above the starting floor level.
func _measure_jump_apex(player: CharacterBody3D, hold_frames: int) -> float:
	await _place_player(player, Vector3(0.0, 0.6, 0.0))
	var base_y := player.global_position.y
	var apex := 0.0
	Input.action_press("jump")
	for i in hold_frames:
		await physics_frame
		apex = maxf(apex, player.global_position.y - base_y)
	Input.action_release("jump")
	for i in 100:
		await physics_frame
		apex = maxf(apex, player.global_position.y - base_y)
	return apex


func _run() -> void:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame

	var player: CharacterBody3D = get_first_node_in_group("player")
	_check(player != null, "Jugador presente")

	# --- Determinismo de la carrera -------------------------------------
	var checkpoints: Array = get_nodes_in_group("checkpoints")
	_check(checkpoints.size() == 11, "Siguen existiendo 11 checkpoints (encontrados: %d)" % checkpoints.size())

	# --- 1. Nuevos obstaculos presentes en el mapa ----------------------
	var pad: Area3D = game.get_node_or_null("Course/BouncePadFinal")
	var sweeper: Node3D = game.get_node_or_null("Course/Sweeper")
	var mover: AnimatableBody3D = game.get_node_or_null("Course/MovingPlatform")
	var dropper: Node3D = game.get_node_or_null("Course/BallDropper")
	_check(pad != null, "Solo queda el trampolín obligatorio final")
	_check(game.get_node_or_null("Course/BouncePad") == null
		and game.get_node_or_null("Course/BouncePadWind") == null
		and game.get_node_or_null("Course/BouncePadFinish") == null,
		"Se quitaron los trampolines opcionales")
	_check(sweeper != null, "Barra giratoria presente en el mapa")
	_check(mover != null, "Plataforma móvil presente en el mapa")
	_check(dropper != null, "Dispensador de pelotas presente en el mapa")
	_check(game.get_node_or_null("Course/FinalConveyor") != null, "Combo final: cinta bajo el sweeper")
	_check(game.get_node_or_null("Course/ConveyorC") != null,
		"La plataforma del cañón tiene una cinta lateral adicional")
	_check(game.get_node_or_null("Course/MovingPlatform/BallDropperMoving") != null,
		"Combo: pelotas sobre la plataforma móvil, montadas en ella")
	_check(get_nodes_in_group("bounce_pads").size() == 1,
		"Solo queda un trampolín en todo el mapa (%d)" % get_nodes_in_group("bounce_pads").size())
	_check(get_nodes_in_group("crowns").is_empty()
		and game.get_node_or_null("Course/CrownA") == null
		and game.get_node_or_null("Course/CrownB") == null
		and game.get_node_or_null("Course/CrownC") == null
		and game.get_node_or_null("Course/CrownLedgeB") == null,
		"El sistema de coronas y las repisas CrownLedge ya no existen")
	if pad == null or sweeper == null or mover == null or dropper == null:
		print("RESULT: %d fallos (faltan obstáculos)" % _failures)
		quit(1)
		return

	# --- 2. Decoracion del mapa -----------------------------------------
	_check(game.get_node_or_null("Decor/StartGateBeam") != null, "Decoración: arco de salida")
	_check(game.get_node_or_null("Decor/DistantPillarLeftA") != null, "Decoración: pilares de fondo")
	_check(game.get_node_or_null("Decor/SweeperColumnLeft") == null
		and game.get_node_or_null("Decor/BridgeColumnRight") == null,
		"Se quitaron las columnas decorativas que no sostenían nada")

	# --- 1b. Los soportes de los dispensadores llegan al suelo ------------
	await physics_frame
	var support_space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for path in ["Course/BallDropper", "Course/BallDropper2", "Course/MovingPlatform/BallDropperMoving"]:
		var machine: Node3D = game.get_node_or_null(path)
		var leg: MeshInstance3D = machine.get_node_or_null("ColumnLeft") if machine else null
		if leg == null:
			_check(false, "%s tiene patas de soporte" % path)
			continue
		var leg_top: Vector3 = leg.global_position + Vector3.UP * 3.0 * leg.scale.y
		var leg_bottom: Vector3 = leg.global_position - Vector3.UP * 3.0 * leg.scale.y
		var support_query := PhysicsRayQueryParameters3D.create(
			leg_top, leg_top + Vector3.DOWN * 30.0, 1)
		var support_hit := support_space.intersect_ray(support_query)
		var floor_y := -99.0
		if not support_hit.is_empty():
			floor_y = (support_hit["position"] as Vector3).y
		_check(absf(leg_bottom.y - floor_y) < 0.15,
			"%s no flota: pata a %.2f m y suelo a %.2f m" % [path, leg_bottom.y, floor_y])

	# --- 2b. El balancín coincide con su eje real -------------------------
	var saw: Node3D = game.get_node("Course/SeeSaw")
	var plank_mesh: BoxMesh = (saw.get_node("Mesh") as MeshInstance3D).mesh as BoxMesh
	var plank_size: Vector3 = plank_mesh.size
	_check(plank_size.x > plank_size.z and absf(plank_size.z - 10.0) < 0.1,
		"El tablero del balancín gira 90° (%.1f × %.1f m)" % [plank_size.x, plank_size.z])
	var hub_axis: Vector3 = (saw.get_node("Hub") as Node3D).global_transform.basis.y.normalized()
	_check(absf(hub_axis.x) > 0.9, "El eje visible del balancín coincide con el eje de giro")
	_check((game.get_node("WorldEnvironment").environment as Environment).sky != null,
		"El entorno usa un cielo procedural")

	# --- 4. El trampolín final lanza al jugador -------------------------
	# Se deja caer desde arriba para no quedarse rebotando durante el asentado.
	await _place_player_briefly(player, pad.global_position + Vector3(0.0, 3.0, 0.0), 5)
	var max_up := 0.0
	for i in 90:
		await physics_frame
		max_up = maxf(max_up, player.velocity.y)
	_check(max_up >= pad.bounce_strength - 1.0,
		"El trampolín lanza al jugador (vel.y máx = %.1f)" % max_up)

	# --- 5. La barra giratoria rota -------------------------------------
	var angle_before: float = sweeper.get_angle()
	for i in 30:
		await physics_frame
	_check(absf(sweeper.get_angle() - angle_before) > 0.1,
		"La barra giratoria rota (%.2f rad)" % absf(sweeper.get_angle() - angle_before))
	var sweeper3: Node3D = game.get_node("Course/Sweeper3")
	_check(signf(sweeper.get_angle()) != signf(sweeper3.get_angle()),
		"Las dos barras de la sala giran en sentidos opuestos")
	var sweeper4: Node3D = game.get_node("Course/Sweeper4")
	_check(sweeper.get("stuns") == true and sweeper3.get("stuns") == true
		and sweeper4.get("stuns") == true,
		"Los tres sweepers están configurados para aturdir")
	for path in ["Course/Sweeper", "Course/Sweeper3", "Course/Sweeper4"]:
		var sw: Node3D = game.get_node(path)
		player.respawn_at(Transform3D(Basis.IDENTITY, sw.global_position + Vector3(0.0, 1.4, 2.0)))
		sw.call("_on_body_entered", player)
		_check(player.is_stunned(), "%s aturde al jugador" % path)
	await _place_player(player, Vector3(0.0, 0.6, 0.0))
	var sweeper_bar: AnimatableBody3D = sweeper.get_node("Bar")
	_check(sweeper_bar.collision_layer == 0,
		"La barra no bloquea físicamente al jugador (solo empuja)")

	# --- 6. La plataforma móvil se desplaza -----------------------------
	await _place_player(player, Vector3(0.0, 0.6, 0.0))
	var mover_start: Vector3 = mover.global_position
	for i in 70:
		await physics_frame
	var travelled: float = (mover.global_position - mover_start).length()
	_check(travelled > 0.5, "La plataforma móvil se desplaza (%.2f m)" % travelled)

	# --- 7. El dispensador suelta pelotas -------------------------------
	for i in 200:
		await physics_frame
	_check(dropper.active_ball_count() > 0,
		"El dispensador suelta pelotas (%d activas)" % dropper.active_ball_count())

	# --- 8. Una pelota que cae aturde al jugador ------------------------
	await _place_player(player, Vector3(0.0, 0.6, 0.0))
	var ball: RigidBody3D = (load("res://scenes/obstacles/ball.tscn") as PackedScene).instantiate()
	game.add_child(ball)
	ball.global_position = player.global_position + Vector3(0.4, 2.6, -0.4)
	ball.linear_velocity = Vector3(0.0, -6.0, 0.0)
	var got_stunned := false
	for i in 90:
		await physics_frame
		if player.is_stunned():
			got_stunned = true
	_check(got_stunned, "Una pelota que cae empuja y aturde al jugador")
	# La pelota de prueba no debe seguir por la plataforma y aturdir al
	# jugador en las comprobaciones siguientes.
	ball.queue_free()

	# --- 9. Aturdimiento manual -----------------------------------------
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, 0.0)))
	for i in 40:
		await physics_frame
	_check(not player.is_stunned(), "El jugador se recupera del aturdimiento")
	player.apply_push(Vector3(9.0, 2.0, 0.0))
	_check(player.is_stunned(), "Un golpe fuerte vuelve a aturdir al jugador")

	# --- 10. Altura de salto variable -----------------------------------
	var full_apex: float = await _measure_jump_apex(player, 40)
	var short_apex: float = await _measure_jump_apex(player, 2)
	_check(full_apex > short_apex + 0.3,
		"Salto de altura variable (mantener %.2f m vs soltar %.2f m)" % [full_apex, short_apex])

	# --- 11. Modelo y animaciones del personaje -------------------------
	var model: Node3D = player.get_node_or_null("MeshInstance3D/Model")
	var anim: AnimationPlayer = player.get_node_or_null("MeshInstance3D/Model/AnimationPlayer")
	_check(model != null, "El personaje usa el modelo 3D descargado")
	_check(anim != null, "El modelo trae AnimationPlayer")
	if anim == null:
		print("RESULT: %d fallos (el modelo no tiene animaciones)" % _failures)
		quit(1)
		return

	await _place_player(player, Vector3(0.0, 0.6, 5.0))
	Input.action_press("move_forward")
	# Give the landing squash time to end without running off the start slab.
	for i in 45:
		await physics_frame
	var clip: String = anim.current_animation
	_check(clip == "Walking_A" or clip == "Running_A",
		"El personaje reproduce animación al correr (%s)" % clip)
	Input.action_release("move_forward")

	# --- 12. Sombra proyectada ------------------------------------------
	await _place_player(player, Vector3(0.0, 0.6, 0.0))
	var shadow: MeshInstance3D = player.get_node("Shadow")
	_check(shadow.visible, "La sombra se proyecta sobre el suelo")
	await _place_player_briefly(player, Vector3(0.0, 8.0, -144.0), 5)
	_check(not shadow.visible, "La sombra desaparece sobre el vacío")

	# --- 13. Superficies nuevas del curso --------------------------------
	# Se deja caer al jugador sobre cada zona y se comprueba dónde aterriza:
	# valida que la geometría del mapa está donde debe.
	# Se apaga el dispensador para que las pelotas no empujen al jugador fuera
	# del punto de aterrizaje y falseen la medición.
	var dropper2: Node3D = game.get_node_or_null("Course/BallDropper2")
	var dropper_moving: Node3D = game.get_node_or_null("Course/MovingPlatform/BallDropperMoving")
	dropper.set_physics_process(false)
	for child in dropper.get_children():
		if child is RigidBody3D:
			child.queue_free()
	if dropper2 != null:
		dropper2.set_physics_process(false)
		for child in dropper2.get_children():
			if child is RigidBody3D:
				child.queue_free()
	if dropper_moving != null:
		dropper_moving.set_physics_process(false)
		for child in dropper_moving.get_children():
			if child is RigidBody3D:
				child.queue_free()
	await physics_frame

	await _place_player(player, Vector3(0.0, 2.0, 0.0))
	_check(absf(player.global_position.y) < 0.15,
		"Aterriza en la plataforma inicial (y=%.2f)" % player.global_position.y)

	await _place_player(player, Vector3(0.1, 2.5, -94.0))
	_check(absf(player.global_position.y) < 0.15,
		"Aterriza en la plataforma giratoria (y=%.2f)" % player.global_position.y)

	await _place_player(player, Vector3(0.0, 5.5, -176.0))
	_check(absf(player.global_position.y - 3.8) < 0.3,
		"Aterriza en la cima de la rampa larga (y=%.2f)" % player.global_position.y)

	# La bajada empalma con la plataforma de meta del tramo de bolas.
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var descent_query := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 5.0, -179.0), Vector3(0.0, -2.0, -179.0), 1)
	var descent_hit := space.intersect_ray(descent_query)
	var descent_y := -99.0
	if not descent_hit.is_empty():
		descent_y = (descent_hit["position"] as Vector3).y
	_check(descent_y > 1.8 and descent_y < 2.8,
		"La rampa baja con fuerza hacia la plataforma (y=%.2f)" % descent_y)
	var landing_query := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 4.0, -181.0), Vector3(0.0, -2.0, -181.0), 1)
	var landing_hit := space.intersect_ray(landing_query)
	var landing_y := -99.0
	if not landing_hit.is_empty():
		landing_y = (landing_hit["position"] as Vector3).y
	_check(absf(landing_y - 1.0) < 0.12,
		"La bajada termina en la plataforma de aterrizaje (y=%.2f)" % landing_y)

	# Una bola suelta en la meseta debe rodar fuera, no quedarse dormida.
	var top_ball: RigidBody3D = (load("res://scenes/obstacles/ball.tscn") as PackedScene).instantiate()
	game.add_child(top_ball)
	top_ball.global_position = Vector3(2.5, 4.6, -175.75)
	top_ball.linear_velocity = Vector3.ZERO
	var ball_start_x := top_ball.global_position.x
	for i in 100:
		await physics_frame
	var ball_moved := absf(top_ball.global_position.x - ball_start_x)
	_check(ball_moved > 0.4 or top_ball.global_position.y < 3.0,
		"Las bolas ruedan fuera de BallRampTop (desvío %.2f m, y %.2f)" % [ball_moved, top_ball.global_position.y])
	top_ball.queue_free()
	await physics_frame

	# Los muros del tramo de bolas deben quedar apoyados en la rampa, no flotando.
	for path in ["Course/WallBallLeftA", "Course/WallBallRightA", "Course/WallBallLeftB"]:
		var wall: Node3D = game.get_node(path)
		# Centro de la cara inferior del muro, ya inclinado con la rampa.
		var wall_bottom_point: Vector3 = wall.global_position - wall.global_transform.basis.y * 0.75
		var probe: Vector3 = wall_bottom_point + Vector3(0.8, 0.0, 0.0)
		var wall_query := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, wall_bottom_point.y + 4.0, probe.z),
			Vector3(probe.x, wall_bottom_point.y - 4.0, probe.z), 1)
		var wall_hit := space.intersect_ray(wall_query)
		var ramp_y := -99.0
		if not wall_hit.is_empty():
			ramp_y = (wall_hit["position"] as Vector3).y
		_check(absf(wall_bottom_point.y - ramp_y) < 0.08,
			"%s queda a ras de la rampa (base %.2f m, suelo %.2f m)" % [path, wall_bottom_point.y, ramp_y])

	# --- 13b. Checkpoint sin arco, marca en el suelo ----------------------
	var cp1: Node3D = checkpoints[0]
	_check(cp1.get_node_or_null("Bar") == null and cp1.get_node_or_null("PostLeft") == null,
		"El checkpoint ya no tiene arco")
	_check(cp1.get_node_or_null("FloorBand") != null and cp1.get_node_or_null("FloorStripe") != null,
		"El checkpoint se marca con una banda luminosa en el suelo")

	# --- 13c. Plataforma giratoria decorada --------------------------------
	var spinner: Node3D = game.get_node("Course/SpinningPlatform")
	var spinner_details: Node3D = spinner.get_node_or_null("Details")
	_check(spinner_details != null and spinner_details.get_node_or_null("Rim") != null,
		"La plataforma giratoria tiene rayos, borde y eje visible")

	# --- 13d. El trampolín final es parte del recorrido -------------------
	_check(pad != null, "Hay un trampolín obligatorio antes de la meta")
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, -193.5)))
	Input.action_press("move_forward")
	var final_bounce := 0.0
	for i in 24:
		await physics_frame
		final_bounce = maxf(final_bounce, player.velocity.y)
	Input.action_release("move_forward")
	_check(final_bounce >= 9.5,
		"El trampolín final lanza al jugador hacia la meta elevada (vel.y máx = %.1f)" % final_bounce)
	var finish_query := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 8.0, -203.0), Vector3(0.0, 0.0, -203.0), 1)
	var finish_hit := space.intersect_ray(finish_query)
	var finish_y := -99.0
	if not finish_hit.is_empty():
		finish_y = (finish_hit["position"] as Vector3).y
	_check(absf(finish_y - 4.0) < 0.15,
		"La meta está elevada y solo se alcanza con el trampolín (y=%.2f)" % finish_y)

	await _place_player(player, Vector3(0.0, 2.0, -112.0))
	_check(absf(player.global_position.y - 0.6) < 0.2,
		"Aterriza en la plataforma tras las plataformas móviles (y=%.2f)" % player.global_position.y)

	await _place_player(player, Vector3(0.0, 5.0, -203.0))
	_check(absf(player.global_position.y - 4.0) < 0.2,
		"Aterriza en la plataforma de meta elevada (y=%.2f)" % player.global_position.y)

	# --- 14. La plataforma móvil se puede cabalgar -----------------------
	# La plataforma hace pausas en los extremos, así que se mide el recorrido
	# acumulado del jugador (no el desplazamiento final, que un día u otro
	# podría coincidir con la posición inicial).
	await _place_player(player, mover.global_position + Vector3(0.0, 0.5, 0.0))
	var carried := 0.0
	var last_pos: Vector3 = player.global_position
	for i in 150:
		await physics_frame
		carried += (player.global_position - last_pos).length()
		last_pos = player.global_position
	var offset_z: float = absf(player.global_position.z - mover.global_position.z)
	_check(player.is_on_floor() and carried > 2.0 and offset_z < 2.5,
		"El jugador cabalga la plataforma móvil (recorrido %.2f m, desvío %.2f m)" % [carried, offset_z])

	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
