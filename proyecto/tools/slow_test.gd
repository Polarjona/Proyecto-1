extends SceneTree

## Diagnóstico del frenazo de los hazards. Mide la velocidad real del corredor
## en el suelo antes y durante slow(), comprueba el solapamiento y la vuelta a
## la normalidad, hace lo mismo con un bot y deja una tabla de lo que cuesta
## cada hazard. Los valores se leen de los propios scripts, así que si se
## ajustan allí la tabla los refleja solos.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const BOT_SCENE := "res://scenes/race/bot_racer.tscn"

## Todo script de hazard que golpea o roza al corredor debe frenarlo. Los que
## matan (lava, géiser, vacío) o bloquean (hielo) no están aquí a propósito:
## su castigo es el respawn o la pared, no la lentitud.
const TOUCH_HAZARDS := [
	"piston.gd", "spike_trap.gd", "boulder.gd", "rotor_gate.gd", "ball.gd",
	"pendulum.gd", "sweeper.gd", "meteor.gd", "ash_vortex.gd",
	"magma_curtain.gd", "ocean_hazards.gd", "wind_tunnel.gd",
]

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
	await process_frame
	await process_frame

	_report_values()
	_report_coverage()

	var world := Node3D.new()
	root.add_child(world)
	_build_floor(world)
	await process_frame

	var player: CharacterBody3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = Vector3(0.0, 0.7, 0.0)
	player.is_bot = true
	world.add_child(player)
	await process_frame
	await process_frame

	# Velocidad de crucero en llano: la referencia contra la que se mide todo.
	player.set_bot_drive(Vector3(0.0, 0.0, -1.0))
	for i in 120:
		await physics_frame
	var base_speed := _speed(player)
	print("Velocidad de crucero: %.2f m/s" % base_speed)
	_check(base_speed > 5.0, "El corredor alcanza su velocidad de crucero")

	# Golpe fuerte: el factor debe notarse en la velocidad real, no solo en la
	# variable interna.
	player.slow(0.8, 0.6)
	for i in 24:
		await physics_frame
	var hit_speed := _speed(player)
	var hit_ratio := hit_speed / maxf(base_speed, 0.01)
	print("Golpe fuerte: %.2f m/s (%.0f%% de crucero)" % [hit_speed, hit_ratio * 100.0])
	_check(absf(hit_ratio - 0.6) <= 0.1, "El golpe fuerte deja al corredor al ~60%")

	# Una zona suave que entra después no debe anular el golpe.
	player.slow(0.25, 0.8)
	_check(absf(player.slow_ratio() - 0.6) <= 0.02,
		"El factor más fuerte sobrevive al solapamiento")

	# Y al acabarse el frenazo vuelve entero.
	for i in 70:
		await physics_frame
	_check(not player.is_slowed(), "El frenazo caduca solo")
	_check(_speed(player) / maxf(base_speed, 0.01) > 0.9,
		"Al caducar se recupera la velocidad de crucero")

	# Bots: misma regla, para que la carrera siga siendo justa.
	var bot: CharacterBody3D = (load(BOT_SCENE) as PackedScene).instantiate()
	bot.position = Vector3(4.0, 0.7, 0.0)
	world.add_child(bot)
	await process_frame
	# En este árbol no hay carrera que arrancar: se salta la espera para que el
	# reloj del frenazo corra como en partida.
	bot.set("_waiting_for_start", false)
	bot.slow(0.8, 0.6)
	_check(bot.is_slowed() and absf(bot.slow_ratio() - 0.6) <= 0.02,
		"El bot también queda ralentizado al 60%")
	bot.slow(0.25, 0.85)
	_check(absf(bot.slow_ratio() - 0.6) <= 0.02,
		"El bot conserva el factor más fuerte al solaparse")
	bot.slow(0.05, 0.3)
	_check(absf(bot.slow_ratio() - 0.3) <= 0.02,
		"Un golpe más fuerte sí reemplaza el frenazo del bot")
	for i in 70:
		await physics_frame
	_check(not bot.is_slowed(), "El frenazo del bot caduca solo")

	# Placa de hazard del suelo: pisarla debe frenar de verdad.
	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(10.0, 0.02, 1.4)
	pad.mesh = pad_mesh
	pad.set_script(load("res://scripts/hazard_pad.gd"))
	pad.position = Vector3(0.0, 0.03, -10.0)
	world.add_child(pad)
	await physics_frame
	await physics_frame
	player.global_position = Vector3(0.0, 0.8, -10.0)
	player.velocity = Vector3.ZERO
	for i in 12:
		await physics_frame
	_check(player.is_slowed(), "Pisar una placa Hazard frena al corredor")
	_check(absf(player.slow_ratio() - 0.6) <= 0.05,
		"La placa deja al corredor al ~60%")

	print("RESULTADO: %d fallo(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## Imprime, para cada hazard, el factor y la duración declarados en su script,
## y cuánta velocidad y cuánta distancia cuesta cada golpe.
func _report_values() -> void:
	var regex := RegEx.new()
	regex.compile("\\bslow\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)")
	print("--- Frenazo por hazard (velocidad de crucero %.1f m/s) ---" % 6.5)
	for file_name in TOUCH_HAZARDS:
		var text := _read_script(file_name)
		var found := false
		for match_result in regex.search_all(text):
			# La llamada es slow(duración, factor).
			var duration := float(match_result.get_string(1))
			var factor := float(match_result.get_string(2))
			_print_hazard(file_name, factor, duration)
			found = true
		if not found and text.contains("apply_push"):
			print("%-20s vía apply_push (0.8 s al 60%%)" % file_name)
			found = true
		if not found:
			print("%-20s SIN frenazo" % file_name)


func _print_hazard(file_name: String, factor: float, duration: float) -> void:
	var speed := 6.5 * factor
	var lost := (6.5 - speed) * duration
	print("%-20s factor %.2f · %.2f s · %.1f m/s · pierde %.2f m" % [
		file_name, factor, duration, speed, lost])


## Ningún hazard que toca al corredor puede quedarse sin slow().
func _report_coverage() -> void:
	for file_name in TOUCH_HAZARDS:
		var text := _read_script(file_name)
		var slows := text.contains(".slow(") or text.contains("slow(0")
		_check(slows or text.contains("apply_push"),
			"%s ralentiza al corredor" % file_name)


func _read_script(file_name: String) -> String:
	var file := FileAccess.open("res://scripts/" + file_name, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func _build_floor(world: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	world.add_child(floor_body)
