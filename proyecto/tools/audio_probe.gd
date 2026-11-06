extends Node

## Sonda de niveles: abre el menú real y luego termina una carrera real, y mide
## el pico que llega a cada bus (y al Master) con el mezclador del juego.
## Sirve para comprobar que la fanfarria de meta se oye por encima del menú sin
## saturar la salida.

const MENU_SECONDS := 2.0
const VICTORY_SECONDS := 4.0


func _ready() -> void:
	print("PROBE device=%s rate=%d" % [AudioServer.get_output_device(), AudioServer.get_mix_rate()])
	await get_tree().process_frame

	# --- Menú real (main_menu.gd arranca la música) -----------------------
	var menu: Node = (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	await get_tree().create_timer(1.6).timeout
	var music := await _sample(MENU_SECONDS)
	var music_player := AudioManager.get_node("MusicPlayer") as AudioStreamPlayer
	print("PROBE menu bus_peak=%.1f dBFS master=%.1f player_db=%.1f bus_db=%.1f music_setting=%.2f" % [
		music["Music"], music["Master"], music_player.volume_db, _bus_db("Music"),
		float(SaveManager.get_setting("music", 0.75))])
	menu.queue_free()
	await get_tree().process_frame

	# --- Carrera real: cruzar la meta dispara el HUD y la fanfarria -------
	GameSession.start_classic()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var race_manager: Node = get_tree().get_first_node_in_group("race_manager")
	if race_manager == null:
		print("PROBE sin RaceManager: no se puede simular la meta")
		get_tree().quit(2)
		return
	race_manager.call("finish_race")
	var victory := await _sample(VICTORY_SECONDS)
	var victory_player := AudioManager.get_node("VictoryPlayer") as AudioStreamPlayer
	print("PROBE victory bus_peak=%.1f dBFS master=%.1f player_db=%.1f bus_db=%.1f victory_muted=%s" % [
		victory["Victory"], victory["Master"], victory_player.volume_db, _bus_db("Victory"),
		str(AudioServer.is_bus_mute(AudioServer.get_bus_index("Victory")))])
	print("PROBE delta=%.1f dB headroom=%.1f dB playing=%s" % [
		victory["Victory"] - music["Music"], -1.0 - victory["Master"],
		str(AudioManager.is_victory_playing())])

	# --- Música a cero: la fanfarria no debe sonar ------------------------
	AudioManager.stop_victory()
	var music_before := float(SaveManager.get_setting("music", 0.75))
	var master_index := AudioServer.get_bus_index("Master")
	var master_peak_before := AudioServer.get_bus_peak_volume_left_db(master_index, 0)
	SaveManager.set_setting("music", 0.0)
	AudioManager.play_victory()
	var muted := await _sample(0.8)
	print("PROBE muted playing=%s victory_bus_peak=%.1f master_before=%.1f master=%.1f" % [
		str(AudioManager.is_victory_playing()), muted["Victory"], master_peak_before, muted["Master"]])
	# --- Referencia con el volumen de música por defecto (0.75) ----------
	SaveManager.set_setting("music", 0.75)
	AudioManager.play_music(false)
	await get_tree().create_timer(0.4).timeout
	var menu_default := await _sample(MENU_SECONDS)
	print("PROBE menu_default bus_peak=%.1f delta_vs_victory=%.1f dB" % [
		menu_default["Music"], victory["Victory"] - menu_default["Music"]])
	SaveManager.set_setting("music", music_before)
	get_tree().quit(0)


func _sample(seconds: float) -> Dictionary:
	var peaks := {"Master": -200.0, "Music": -200.0, "Victory": -200.0}
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		for bus_name: String in peaks:
			var index := AudioServer.get_bus_index(bus_name)
			if index < 0:
				continue
			var left: float = AudioServer.get_bus_peak_volume_left_db(index, 0)
			var right: float = AudioServer.get_bus_peak_volume_right_db(index, 0)
			peaks[bus_name] = maxf(float(peaks[bus_name]), maxf(left, right))
	return peaks


func _bus_db(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_db(index) if index >= 0 else 0.0
