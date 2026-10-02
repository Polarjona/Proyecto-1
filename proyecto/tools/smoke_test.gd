extends SceneTree

## Temporary smoke test: instantiates menu + game, runs a few frames,
## and reports success only if no errors happened.

func _initialize() -> void:
	var menu: Node = (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for i in 16:
		await process_frame
	print("SMOKE OK")
	quit(0)
