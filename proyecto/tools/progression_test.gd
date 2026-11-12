extends SceneTree

## Progresion: compra de personajes, rondas del torneo y el tutorial de la
## primera partida. Usa un perfil propio para no tocar el del jugador.

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
	var test_profile := "user://profile.progression_test.json"
	save.call("use_profile_path", test_profile)
	# Tambien el respaldo: si queda uno viejo, `load_profile` lo recupera.
	for path in [test_profile, test_profile + ".bak", test_profile + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.call("load_profile")
	await process_frame
	await process_frame

	# --- Compra de personaje ------------------------------------------------
	var target := ""
	var price := 0
	for entry in CharacterCatalog.CHARACTERS:
		var id := String(entry["id"])
		var cost := CharacterCatalog.price(id)
		if cost > 0:
			target = id
			price = cost
			break
	_check(not target.is_empty(), "Hay al menos un personaje de pago")
	if not target.is_empty():
		var data: Dictionary = save.get("data")
		data["coins"] = 0
		save.set("data", data)
		_check(not bool(save.call("buy_character", target)), "Sin monedas no se compra")
		data["coins"] = price
		save.set("data", data)
		_check(bool(save.call("buy_character", target)), "Con monedas se compra")
		_check(bool(save.call("is_character_unlocked", target)), "La compra desbloquea")
		_check(int(save.call("coins")) == 0, "La compra descuenta el precio")
		_check(not bool(save.call("buy_character", target)), "No se paga dos veces")

	# --- Torneo -------------------------------------------------------------
	var session: Node = root.get_node("GameSession")
	session.call("start_bots", true)
	_check(int(session.get("round")) == 1 and int(session.get("qualifiers")) == 3,
		"El torneo empieza en la ronda 1 con 3 plazas")
	for _i in [2, 3, 4]:
		session.call("advance_round")
	_check(int(session.get("round")) == 4, "El torneo llega a la ronda 4")
	_check(int(session.get("qualifiers")) == 1, "La final clasifica a uno")
	_check(bool(session.call("is_final_round")), "La ronda 4 es la final")
	_check(int(session.get("bot_count")) <= 11, "Los bots no pasan de 11")
	session.call("advance_round")
	_check(int(session.get("round")) == 4, "El torneo no pasa de la final")
	session.call("reset")

	# --- Tutorial y cuenta atras -------------------------------------------
	# El HUD solo muestra el tutorial cuando no es headless; aqui se abre a mano
	# para comprobar que la cuenta atras queda congelada detras del panel.
	var level: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame
	# Sin anotar el tipo: compilar `RaceManager` aqui ocurre antes de que existan
	# los autoloads y el script no compila.
	var manager := get_first_node_in_group("race_manager") as Node
	var hud: Node = level.get_node_or_null("HUD")
	_check(manager != null and hud != null, "Carrera y HUD disponibles para el tutorial")
	if manager != null and hud != null:
		manager.call("_run_intro")
		await create_timer(0.1).timeout
		hud.call("_show_tutorial")
		await create_timer(3.0).timeout
		_check(paused, "El tutorial congela el arbol")
		_check(not bool(manager.get("is_running")), "La cuenta atras no se consume tras el tutorial")
		hud.call("_on_tutorial_closed")
		await create_timer(2.6).timeout
		_check(not paused, "Cerrar el tutorial reanuda el juego")
		_check(bool(manager.get("is_running")), "La cuenta atras termina y la carrera arranca")

	root.remove_child(level)
	level.free()
	await process_frame
	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
