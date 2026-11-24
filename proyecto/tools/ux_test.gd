extends SceneTree

## Comprueba lo que se nota jugando: cámara con el stick derecho, confirmaciones
## de la pausa, atajo R, guía del tutorial y dificultad asistida. Carga la
## escena real de Pivot Push y escribe en un perfil aislado.

const SAVE := "user://profile.ux_test.json"

const LEVEL := "res://scenes/levels/pivot_push.tscn"

var _failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var save: Node = root.get_node("SaveManager")
	save.call("use_profile_path", SAVE)
	if String(save.get("_save_path")) != SAVE:
		print("FAIL: no se pudo aislar el perfil; el test no toca nada")
		quit(1)
		return
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.call("load_profile")
	await process_frame
	save.call("set_setting", "language", "es")
	save.call("set_setting", "assisted", false)
	await process_frame

	# --- C1. El stick derecho está mapeado a la cámara ----------------------
	var expectations := {
		"camera_left": [JOY_AXIS_RIGHT_X, -1.0],
		"camera_right": [JOY_AXIS_RIGHT_X, 1.0],
		"camera_up": [JOY_AXIS_RIGHT_Y, -1.0],
		"camera_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	for action: String in expectations:
		var expected: Array = expectations[action]
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				found = (
					motion.axis == int(expected[0])
					and is_equal_approx(motion.axis_value, float(expected[1]))
				)
				if found:
					break
		_check(found, "Mando: %s usa el eje derecho %s" % [action, expected])
		if InputMap.has_action(action):
			_check(
				is_equal_approx(InputMap.action_get_deadzone(action), 0.2),
				"Mando: %s tiene zona muerta 0.2" % action
			)

	var game: Node = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i in 3:
		await process_frame

	var player: CharacterBody3D = get_first_node_in_group("player")
	var hud: CanvasLayer = get_first_node_in_group("hud")
	var manager: Node = get_first_node_in_group("race_manager")
	var pause: CanvasLayer = get_first_node_in_group("pause_menu")
	var message: Label = hud.get_node("Root/MessageLabel")
	_check(player != null, "Jugador presente en la carrera")
	_check(hud != null and pause != null, "HUD y pausa presentes")
	_check(manager != null, "RaceManager presente")
	if player == null or hud == null or pause == null or manager == null:
		print("RESULT: %d fallos (falta la escena base)" % _failures)
		quit(1)
		return

	# --- C1. El stick mueve la cámara del jugador ---------------------------
	var yaw_before := float(player.get("_orbit_yaw"))
	Input.action_press("camera_right", 1.0)
	player.call("_update_camera", 0.5)
	Input.action_release("camera_right")
	var yaw_after := float(player.get("_orbit_yaw"))
	_check(
		absf(wrapf(yaw_after - yaw_before, -PI, PI)) > 0.5,
		"El stick derecho gira la cámara (%.2f rad)" % (yaw_after - yaw_before)
	)
	var pitch_before := float(player.get("_orbit_pitch"))
	Input.action_press("camera_down", 1.0)
	player.call("_update_camera", 0.25)
	Input.action_release("camera_down")
	var pitch_after := float(player.get("_orbit_pitch"))
	_check(
		pitch_after < pitch_before - 0.1,
		"El stick derecho inclina la cámara (%.2f -> %.2f)" % [pitch_before, pitch_after]
	)
	player.set("_orbit_yaw", yaw_before)
	player.set("_orbit_pitch", pitch_before)

	# --- C8/C9. FOV y dificultad asistida en el jugador ---------------------
	save.call("set_setting", "fov", 68.0)
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	_check(is_equal_approx(camera.fov, 68.0), "El ajuste FOV llega a la cámara del jugador")
	var stick_base := float(player.get("_stick_sensitivity_base"))
	save.call("set_setting", "sensitivity", 2.0)
	_check(
		is_equal_approx(float(player.get("stick_sensitivity")), stick_base * 2.0),
		"La sensibilidad también afecta al stick derecho"
	)
	save.call("set_setting", "sensitivity", 1.0)
	var coyote_base := float(player.get("_coyote_time_base"))
	save.call("set_setting", "assisted", true)
	_check(
		is_equal_approx(float(player.get("coyote_time")), coyote_base * 1.5),
		"La asistencia alarga el coyote time"
	)
	save.call("set_setting", "assisted", false)
	_check(
		is_equal_approx(float(player.get("coyote_time")), coyote_base),
		"Sin asistencia vuelve el coyote time normal"
	)

	manager.set("has_checkpoint", true)
	manager.set("last_checkpoint", player.global_transform)
	save.call("set_setting", "assisted", true)
	manager.set("elapsed_time", 10.0)
	manager.call("respawn_player")
	_check(
		is_equal_approx(float(manager.get("elapsed_time")), 11.0),
		"Con asistencia la caída penaliza 1.0 s"
	)
	save.call("set_setting", "assisted", false)
	manager.set("elapsed_time", 10.0)
	manager.call("respawn_player")
	_check(
		is_equal_approx(float(manager.get("elapsed_time")), 12.5),
		"Sin asistencia la caída penaliza 2.5 s"
	)

	# --- C2. Confirmación antes de tirar la partida -------------------------
	pause.call("show_menu")
	_check(paused, "La pausa congela el árbol")
	var restart_button: Button = pause.get_node("PanelContainer/VBoxContainer/RestartButton")
	restart_button.pressed.emit()
	await process_frame
	var dialog: ConfirmationDialog = pause.get("confirm_dialog")
	_check(dialog != null and dialog.visible, "Reiniciar carrera pide confirmación")
	_check(String(dialog.title) == "Reiniciar carrera", "La confirmación nombra la acción")
	_check(
		String(dialog.dialog_text) == "Se perderá el progreso de esta carrera.",
		"La confirmación explica qué se pierde"
	)
	_check(dialog.confirmed.get_connections().size() > 0, "La confirmación está conectada")
	dialog.get_cancel_button().pressed.emit()
	await process_frame
	_check(not dialog.visible, "Cancelar cierra la confirmación")
	_check(String(pause.get("_pending_action")) == "", "Cancelar limpia la acción pendiente")
	var menu_button: Button = pause.get_node("PanelContainer/VBoxContainer/MainMenuButton")
	menu_button.pressed.emit()
	await process_frame
	_check(dialog.visible, "Volver al menú también pide confirmación")
	_check(String(dialog.title) == "Volver al menú", "La confirmación del menú es distinta")
	dialog.get_cancel_button().pressed.emit()
	await process_frame
	pause.call("hide_menu")
	_check(not paused, "Cerrar la pausa reanuda el árbol")

	# --- C6. Los avisos traducidos también se retiran solos -----------------
	save.call("set_setting", "language", "en")
	await process_frame
	var medal: Label = hud.get_node("Root/TopRightChip/HBox/MedalLabel")
	_check(medal.text.begins_with("Gold"), "El HUD cambia de idioma en caliente")
	hud.call("_on_split", "Checkpoint 1", 12.0, -1.0)
	await process_frame
	_check(message.text.begins_with("Checkpoint 1"), "El aviso de split se traduce")
	await create_timer(1.3).timeout
	_check(message.text == "", "El aviso de split se retira aunque esté traducido")
	save.call("set_setting", "language", "es")
	await process_frame

	# --- C3. El atajo R existe y reinicia la carrera ------------------------
	var restart_key := -1
	for event in InputMap.action_get_events("restart"):
		if event is InputEventKey:
			restart_key = (event as InputEventKey).physical_keycode
	_check(restart_key == KEY_R, "El atajo R está mapeado")
	_check(pause.has_method("_restart_run"), "La pausa sabe reiniciar en el sitio")

	# --- C7. Guía de tres flechas del primer tramo --------------------------
	var info: LevelInfo = get_first_node_in_group("level_info") as LevelInfo
	var guide: Node3D = load("res://scripts/tutorial_guide.gd").new()
	game.add_child(guide)
	guide.call("setup", player, info)
	guide.call("start")
	var arrows := guide.get_children()
	_check(arrows.size() == 3, "La guía crea tres flechas (creadas: %d)" % arrows.size())
	if arrows.size() == 3:
		var first: Node3D = arrows[0] as Node3D
		var second: Node3D = arrows[1] as Node3D
		var third: Node3D = arrows[2] as Node3D
		var texts := ["CORRE", "SALTA", "SIGUE"]
		for i in 3:
			var arrow: Node3D = arrows[i] as Node3D
			_check(
				arrow.global_position.z < player.global_position.z,
				"La flecha %d está delante del jugador" % (i + 1)
			)
			var label: Label3D = null
			for child in arrow.get_children():
				if child is Label3D:
					label = child as Label3D
			_check(
				label != null and label.text == texts[i], "La flecha %d dice %s" % [i + 1, texts[i]]
			)
		_check(message.text == "Corre hacia la flecha", "La guía arranca con un aviso")
		player.global_position.z = first.global_position.z - 3.0
		guide.call("_process", 0.016)
		_check(not first.visible, "La primera flecha se apaga al pasarla")
		_check(
			message.text == "Salta para superar el obstáculo",
			"La guía pide saltar en el segundo tramo"
		)
		player.global_position.z = second.global_position.z - 3.0
		guide.call("_process", 0.016)
		_check(not second.visible, "La segunda flecha se apaga al pasarla")
		_check(
			message.text == "Sigue el circuito hasta la meta", "La guía pide seguir hasta la meta"
		)
		player.global_position.z = third.global_position.z - 3.0
		guide.call("_process", 0.016)
		_check(not third.visible, "La tercera flecha se apaga al pasarla")
		_check(message.text == "", "La guía retira su aviso al terminar")
		_check(int(guide.get("_step")) == 3, "La guía completa sus tres pasos")
	if is_instance_valid(guide):
		guide.free()

	# --- C3. R recarga la carrera ------------------------------------------
	pause.call("hide_menu")
	var old_id := game.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	pause.call("_unhandled_input", restart_event)
	await create_timer(1.5).timeout
	var reloaded: Node = current_scene
	_check(
		reloaded != null and reloaded.get_instance_id() != old_id, "Pulsar R reinicia la carrera"
	)
	_check(
		reloaded != null and String(reloaded.scene_file_path) == LEVEL,
		"R vuelve a cargar el mismo circuito"
	)

	# Restaura los ajustes usados por el test sin tocar el perfil real.
	save.call("set_setting", "fov", 55.0)
	save.call("set_setting", "assisted", false)
	await process_frame
	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
