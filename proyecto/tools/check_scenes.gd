extends SceneTree

## Temporary check: verifies every .tscn in the project parses correctly.

func _initialize() -> void:
	var scenes := [
		"res://scenes/main.tscn",
		"res://scenes/menu/main_menu.tscn",
		"res://scenes/menu/pause_menu.tscn",
		"res://scenes/player/player.tscn",
		"res://scenes/obstacles/conveyor.tscn",
		"res://scenes/obstacles/pendulum.tscn",
		"res://scenes/obstacles/spinning_platform.tscn",
		"res://scenes/obstacles/wall.tscn",
		"res://scenes/race/checkpoint.tscn",
		"res://scenes/race/finish_line.tscn",
		"res://scenes/race/hud.tscn",
		"res://scenes/race/kill_plane.tscn",
	]
	var failed := 0
	for path in scenes:
		if load(path) == null:
			print("FAIL: ", path)
			failed += 1
		else:
			print("OK:   ", path)
	print("RESULT: %d/%d scenes OK" % [scenes.size() - failed, scenes.size()])
	quit(1 if failed > 0 else 0)
