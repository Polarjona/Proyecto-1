extends SceneTree

## Ajustes: la fila REDUCIR MOVIMIENTO cabe dentro del panel y de su columna,
## no se solapa con las filas vecinas, la preferencia persiste y de verdad apaga
## la sacudida y los destellos. Mide rects reales, no estimaciones.

const SAVE := "user://profile.settings_test.json"

var _failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _initialize() -> void:
	_run()


func _rect_text(r: Rect2) -> String:
	return "(%.1f,%.1f %.1fx%.1f)" % [r.position.x, r.position.y, r.size.x, r.size.y]


func _run() -> void:
	var save: Node = root.get_node("SaveManager")
	save.call("use_profile_path", SAVE)
	# Tambien el respaldo: si queda uno viejo, `load_profile` lo recupera.
	for path in [SAVE, SAVE + ".bak", SAVE + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.call("load_profile")
	await process_frame
	await process_frame

	var menu: CanvasLayer = (load("res://scenes/menu/settings_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	menu.call("open")
	for _i in 3:
		await process_frame

	var panel: Control = menu.get_node("Panel")
	var box: Control = menu.get_node("Panel/VBox")
	var row: Control = menu.get_node_or_null("Panel/VBox/MotionRow")
	var label: Label = menu.get_node_or_null("Panel/VBox/MotionRow/MotionLabel")
	var check: CheckButton = menu.get_node_or_null("Panel/VBox/MotionRow/MotionCheck")
	var previous: Control = menu.get_node("Panel/VBox/FullscreenCheck")
	var following: Control = menu.get_node("Panel/VBox/BackButton")

	_check(row != null and label != null and check != null, "Existe la fila REDUCIR MOVIMIENTO con etiqueta y control")
	if row == null or label == null or check == null:
		print("RESULT: %d FALLOS" % _failures)
		quit(1)
		return

	var rect_panel := panel.get_global_rect()
	var rect_box := box.get_global_rect()
	var rect_row := row.get_global_rect()
	var rect_label := label.get_global_rect()
	var rect_check := check.get_global_rect()
	var rect_previous := previous.get_global_rect()
	var rect_following := following.get_global_rect()
	print("MEDIDAS panel=%s box=%s row=%s label=%s check=%s anterior=%s siguiente=%s" % [
		_rect_text(rect_panel), _rect_text(rect_box), _rect_text(rect_row),
		_rect_text(rect_label), _rect_text(rect_check),
		_rect_text(rect_previous), _rect_text(rect_following),
	])

	_check(row.is_visible_in_tree(), "La fila se ve")
	_check(rect_panel.encloses(rect_row), "La fila cae entera dentro del panel")
	_check(rect_box.encloses(rect_row), "La fila cae entera dentro de la columna")
	_check(rect_row.encloses(rect_label), "La etiqueta cae entera dentro de la fila")
	_check(rect_row.encloses(rect_check), "El control cae entero dentro de la fila")
	_check(rect_box.encloses(rect_label) and rect_box.encloses(rect_check),
		"Etiqueta y control caen dentro de la columna")
	_check(rect_row.position.y >= rect_previous.end.y - 0.5,
		"La fila empieza despues de la anterior")
	_check(rect_following.position.y >= rect_row.end.y - 0.5,
		"VOLVER empieza despues de la fila")
	_check(not rect_row.intersects(rect_previous), "La fila no se solapa con la anterior")
	_check(not rect_row.intersects(rect_following), "La fila no se solapa con VOLVER")
	_check(label.text == "REDUCIR MOVIMIENTO", "La etiqueta dice REDUCIR MOVIMIENTO")

	# --- Persistencia -------------------------------------------------------
	check.button_pressed = true
	_check(bool(save.call("get_setting", "reduced_motion", false)),
		"Marcar la opcion guarda la preferencia")
	save.call("save_profile")
	save.call("load_profile")
	_check(bool(save.call("get_setting", "reduced_motion", false)),
		"La preferencia se relee del disco")
	_check(check.text == "SÍ", "El control muestra el estado activo")

	# --- Efecto real --------------------------------------------------------
	var feel: Node = root.get_node("GameFeel")
	feel.call("shake", 5.0)
	feel.call("flash", Color(1, 0, 0), 0.5)
	_check(is_zero_approx(float(feel.get("shake_strength"))),
		"Con movimiento reducido no hay sacudida")
	_check(is_zero_approx(float(feel.get("flash_amount"))),
		"Con movimiento reducido no hay destello")
	var offset: Vector2 = feel.call("camera_offset")
	_check(offset.is_equal_approx(Vector2.ZERO), "La camara no se desplaza")

	check.button_pressed = false
	feel.call("shake", 5.0)
	feel.call("flash", Color(1, 0, 0), 0.5)
	_check(float(feel.get("shake_strength")) > 0.0, "Sin la opcion la sacudida vuelve")
	_check(float(feel.get("flash_amount")) > 0.0, "Sin la opcion el destello vuelve")

	menu.free()
	await process_frame
	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
