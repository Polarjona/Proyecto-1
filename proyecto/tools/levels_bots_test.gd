extends SceneTree

## Recorre Spin Go Round, Glacier Gallop y Lava Vortex con un bot para
## comprobar que sus rutas son completables (plataformas móviles, vendaval y la
## espiral del volcán con sus saltos incluidos).

const LEVELS := [
	"res://scenes/levels/spin_go_round.tscn",
	"res://scenes/levels/glacier_gallop.tscn",
	"res://scenes/levels/lava_vortex.tscn",
]

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	seed(20261027)
	await process_frame
	await process_frame
	var session: Variant = root.get_node("GameSession")
	for path: String in LEVELS:
		print("--- BOT ", path, " ---")
		session.call("start_bots", false)
		session.set("bot_count", 1)
		var game: Node = (load(path) as PackedScene).instantiate()
		root.add_child(game)
		current_scene = game
		for i in 3:
			await process_frame
		var bots: Array = get_nodes_in_group("bots")
		if bots.is_empty():
			print("FAIL: sin bot en ", path)
			_failures += 1
			root.remove_child(game)
			game.free()
			await process_frame
			continue
		var bot: Node3D = bots[0]
		var frames := 0
		while not bool(bot.get("_finished")) and frames < 20000:
			await physics_frame
			frames += 1
			if frames % 900 == 0:
				print("  %4.1f s  z=%7.2f  wp=%d  rescates=%d" % [
					float(frames) / 60.0, bot.global_position.z,
					int(bot.call("get_waypoint_index")),
					int(bot.call("get_rescue_count")),
				])
		var finished := bool(bot.get("_finished"))
		var rescues := int(bot.call("get_rescue_count"))
		print("RESULTADO: terminado=%s  tiempo=%.1f s  rescates=%d  z=%.2f" % [
			finished, float(frames) / 60.0, rescues, bot.global_position.z,
		])
		if not finished:
			_failures += 1
		if rescues > 14:
			_failures += 1
		root.remove_child(game)
		game.free()
		await process_frame
	session.set("bot_count", 7)
	session.call("reset")
	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
