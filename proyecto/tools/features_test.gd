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
	_check(checkpoints.size() == 5, "Siguen existiendo 5 checkpoints (encontrados: %d)" % checkpoints.size())

	# --- 1. Nuevos obstaculos presentes en el mapa ----------------------
	var pad: Area3D = game.get_node_or_null("Course/BouncePad")
	var sweeper: Node3D = game.get_node_or_null("Course/Sweeper")
	var mover: AnimatableBody3D = game.get_node_or_null("Course/MovingPlatform")
	var dropper: Node3D = game.get_node_or_null("Course/BallDropper")
	_check(pad != null, "Trampolín presente en el mapa")
	_check(sweeper != null, "Barra giratoria presente en el mapa")
	_check(mover != null, "Plataforma móvil presente en el mapa")
	_check(dropper != null, "Dispensador de pelotas presente en el mapa")
	if pad == null or sweeper == null or mover == null or dropper == null:
		print("RESULT: %d fallos (faltan obstáculos)" % _failures)
		quit(1)
		return

	# --- 2. Decoracion del mapa -----------------------------------------
	_check(game.get_node_or_null("Decor/StartGateBeam") != null, "Decoración: arco de salida")
	_check(game.get_node_or_null("Decor/DistantPillarLeftA") != null, "Decoración: pilares de fondo")
	_check((game.get_node("WorldEnvironment").environment as Environment).sky != null,
		"El entorno usa un cielo procedural")

	# --- 3. El trampolín alcanza la repisa de la corona -----------------
	var crown_a: Node3D = game.get_node("Course/CrownA")
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var reach: float = pad.bounce_strength * pad.bounce_strength / (2.0 * gravity * player.gravity_scale)
	_check(reach > crown_a.global_position.y + 0.5,
		"El trampolín alcanza la corona elevada (alcance %.2f m, corona %.2f m)" % [reach, crown_a.global_position.y])

	# --- 4. El trampolín lanza al jugador -------------------------------
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

	# --- 11. Extremidades y cara del personaje --------------------------
	_check(player.get_node_or_null("MeshInstance3D/ArmPivotLeft") != null, "El personaje tiene brazo izquierdo")
	_check(player.get_node_or_null("MeshInstance3D/LegPivotRight") != null, "El personaje tiene pierna derecha")
	_check(player.get_node_or_null("MeshInstance3D/Head/EyeLeft") != null, "El personaje tiene ojos")
	_check(player.get_node_or_null("MeshInstance3D/Head/EyeRight/PupilRight") != null, "El personaje tiene pupilas")

	await _place_player(player, Vector3(0.0, 0.6, 0.0))
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	var arm: Node3D = player.get_node("MeshInstance3D/ArmPivotLeft")
	_check(absf(arm.rotation.x) > 0.01, "Las extremidades se animan al correr (%.2f rad)" % arm.rotation.x)
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
	dropper.set_physics_process(false)
	for child in dropper.get_children():
		if child is RigidBody3D:
			child.queue_free()
	if dropper2 != null:
		dropper2.set_physics_process(false)
		for child in dropper2.get_children():
			if child is RigidBody3D:
				child.queue_free()
	await physics_frame

	await _place_player(player, Vector3(0.0, 2.0, 0.0))
	_check(absf(player.global_position.y) < 0.15,
		"Aterriza en la plataforma inicial (y=%.2f)" % player.global_position.y)

	await _place_player(player, Vector3(0.1, 2.5, -94.0))
	_check(absf(player.global_position.y) < 0.15,
		"Aterriza en la plataforma giratoria (y=%.2f)" % player.global_position.y)

	await _place_player(player, Vector3(0.0, 2.0, -171.0))
	_check(absf(player.global_position.y - 1.0) < 0.2,
		"Aterriza en el corredor de pelotas (y=%.2f)" % player.global_position.y)

	await _place_player(player, Vector3(0.0, 2.0, -112.0))
	_check(absf(player.global_position.y - 0.6) < 0.2,
		"Aterriza en la plataforma tras las plataformas móviles (y=%.2f)" % player.global_position.y)

	await _place_player(player, Vector3(0.0, 2.0, -203.0))
	_check(absf(player.global_position.y - 1.0) < 0.2,
		"Aterriza en la plataforma de meta (y=%.2f)" % player.global_position.y)

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
