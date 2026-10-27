extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var menu := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_report("lobby", menu.get_node("LobbyStage/SubViewport") as SubViewport)
	(menu.get_node("TopBar/HBox/NavRow/CharacterButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	_report("preview", menu.get_node("CharacterPanel/VBox/Body/PreviewBox/CharacterPreview/SubViewport") as SubViewport)
	var stage := menu.get_node("LobbyStage/SubViewport/Stage") as Node3D
	for ch in stage.get_children():
		print("  stage child ", ch.name, " scale ", (ch as Node3D).scale, " pos ", (ch as Node3D).position)
	print("roster buttons: ", (menu.get_node("CharacterPanel/VBox/Body/RosterScroll/Roster") as Control).get_child_count())
	for row in menu.get_node("CharacterPanel/VBox/Body/RosterScroll/Roster").get_children():
		if row is HBoxContainer:
			print("  ", row.name, " -> ", (row.get_child(0) as Button).text)
	quit(0)

func _report(label: String, viewport: SubViewport) -> void:
	var camera := viewport.get_node("Camera3D") as Camera3D
	var stage := viewport.get_node("Stage") as Node3D
	var box := AABB()
	var first := true
	for mesh in stage.find_children("*", "MeshInstance3D", true, false):
		var inst := mesh as MeshInstance3D
		if inst.mesh == null:
			continue
		var b: AABB = inst.global_transform * inst.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var inside := 0
	var top := 9999.0
	var bottom := -9999.0
	var left := 9999.0
	var right := -9999.0
	for i in 8:
		var p: Vector3 = box.get_endpoint(i)
		if camera.is_position_in_frustum(p):
			inside += 1
		var s := camera.unproject_position(p)
		top = minf(top, s.y)
		bottom = maxf(bottom, s.y)
		left = minf(left, s.x)
		right = maxf(right, s.x)
	print("%s: box=%s inside=%d screen y %.0f..%.0f x %.0f..%.0f of %s" % [
		label, box, inside, top, bottom, left, right, viewport.size])
