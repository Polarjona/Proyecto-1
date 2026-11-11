extends SceneTree

## Smoke test: instancia menu + juego, corre unos frames y comprueba que no
## revienta. Libera las escenas antes de salir para no dejar nodos colgando.

func _initialize() -> void:
	var menu: Node = (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for i in 16:
		await process_frame
	menu.free()
	game.free()
	await process_frame
	print("SMOKE OK")
	quit(0)
