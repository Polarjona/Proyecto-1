extends SceneTree

## Ajustes: las filas REDUCIR MOVIMIENTO, GENERAL, CALIDAD y BORRAR PROGRESO
## caben dentro del panel y de su columna, no se solapan con las vecinas y sus
## ajustes persisten. La Calidad se comprueba sobre un WorldEnvironment real y
## el borrado devuelve el perfil al personaje por defecto. Todo corre sobre un
## perfil aislado: nunca se toca el perfil real del jugador.

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


func _check_quality_effect(quality: int, environment: Environment) -> void:
	var label: String = String(["BAJO", "MEDIO", "ALTO"][quality])
	var expected_msaa := Viewport.MSAA_2X if quality >= 2 else Viewport.MSAA_DISABLED
	_check(
		root.msaa_3d == expected_msaa,
		"Calidad %s: MSAA %s" % [label, "2x" if quality >= 2 else "off"]
	)
	_check(
		environment.ssao_enabled == (quality >= 2),
		"Calidad %s: SSAO %s" % [label, "on" if quality >= 2 else "off"]
	)
	_check(
		environment.ssil_enabled == (quality >= 2),
		"Calidad %s: SSIL %s" % [label, "on" if quality >= 2 else "off"]
	)
	_check(
		environment.glow_enabled == (quality >= 1),
		"Calidad %s: bloom %s" % [label, "on" if quality >= 1 else "off"]
	)


func _run() -> void:
	var save: Node = root.get_node("SaveManager")
	save.call("use_profile_path", SAVE)
	if String(save.get("_save_path")) != SAVE:
		print("FAIL: no se pudo aislar el perfil; el test no toca nada")
		quit(1)
		return
	# Tambien el respaldo: si queda uno viejo, `load_profile` lo recupera.
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.call("load_profile")
	await process_frame
	await process_frame

	# Entorno real para medir el efecto de Calidad, no solo su etiqueta.
	var world := WorldEnvironment.new()
	world.name = "QualityProbe"
	world.environment = Environment.new()
	root.add_child(world)
	save.call("apply_settings")
	await process_frame
	var environment: Environment = world.environment

	var menu: CanvasLayer = (
		(load("res://scenes/menu/settings_menu.tscn") as PackedScene).instantiate()
	)
	root.add_child(menu)
	menu.call("open")
	for _i in 3:
		await process_frame

	var panel: Control = menu.get_node("Panel")
	var box: Control = menu.get_node("Panel/VBox")
	var title: Label = menu.get_node("Panel/VBox/Title")
	var separator: Control = menu.get_node("Panel/VBox/HSeparator")
	var music_row: Control = menu.get_node("Panel/VBox/MusicRow")
	var row: Control = menu.get_node_or_null("Panel/VBox/MotionRow")
	var label: Label = menu.get_node_or_null("Panel/VBox/MotionRow/MotionLabel")
	var check: CheckButton = menu.get_node_or_null("Panel/VBox/MotionRow/MotionCheck")
	var master_row: Control = menu.get_node_or_null("Panel/VBox/MasterRow")
	var master_label: Label = menu.get_node_or_null("Panel/VBox/MasterRow/MasterLabel")
	var master_slider: HSlider = menu.get_node_or_null("Panel/VBox/MasterRow/MasterSlider")
	var master_value: Label = menu.get_node_or_null("Panel/VBox/MasterRow/MasterValue")
	var quality_row: Control = menu.get_node_or_null("Panel/VBox/QualityRow")
	var quality_label: Label = menu.get_node_or_null("Panel/VBox/QualityRow/QualityLabel")
	var quality_button: Button = menu.get_node_or_null("Panel/VBox/QualityRow/QualityButton")
	var fov_row: Control = menu.get_node_or_null("Panel/VBox/FovRow")
	var fov_label: Label = menu.get_node_or_null("Panel/VBox/FovRow/FovLabel")
	var fov_slider: HSlider = menu.get_node_or_null("Panel/VBox/FovRow/FovSlider")
	var fov_value: Label = menu.get_node_or_null("Panel/VBox/FovRow/FovValue")
	var extras_row: Control = menu.get_node_or_null("Panel/VBox/ExtrasRow")
	var vsync_button: Button = menu.get_node_or_null("Panel/VBox/ExtrasRow/VsyncButton")
	var assisted_button: Button = menu.get_node_or_null("Panel/VBox/ExtrasRow/AssistedButton")
	var language_button: Button = menu.get_node_or_null("Panel/VBox/ExtrasRow/LanguageButton")
	var reset_button: Button = menu.get_node_or_null("Panel/VBox/ResetProgressButton")
	var reset_dialog: ConfirmationDialog = menu.get_node_or_null("ResetProgressDialog")
	var previous: Control = menu.get_node("Panel/VBox/FullscreenCheck")
	var following: Control = menu.get_node("Panel/VBox/BackButton")

	_check(
		row != null and label != null and check != null,
		"Existe la fila REDUCIR MOVIMIENTO con etiqueta y control"
	)
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
	var rect_title := title.get_global_rect()
	var rect_separator := separator.get_global_rect()
	var rect_music := music_row.get_global_rect()
	var rect_master := master_row.get_global_rect() if master_row != null else Rect2()
	var rect_quality := quality_row.get_global_rect() if quality_row != null else Rect2()
	var rect_fov := fov_row.get_global_rect() if fov_row != null else Rect2()
	var rect_extras := extras_row.get_global_rect() if extras_row != null else Rect2()
	print(
		(
			"MEDIDAS panel=%s box=%s row=%s label=%s check=%s anterior=%s siguiente=%s"
			% [
				_rect_text(rect_panel),
				_rect_text(rect_box),
				_rect_text(rect_row),
				_rect_text(rect_label),
				_rect_text(rect_check),
				_rect_text(rect_previous),
				_rect_text(rect_following),
			]
		)
	)

	_check(row.is_visible_in_tree(), "La fila se ve")
	_check(root.get_visible_rect().encloses(rect_panel), "El panel de ajustes cabe en la ventana")
	_check(rect_panel.encloses(rect_row), "La fila cae entera dentro del panel")
	_check(rect_box.encloses(rect_row), "La fila cae entera dentro de la columna")
	_check(rect_row.encloses(rect_label), "La etiqueta cae entera dentro de la fila")
	_check(rect_row.encloses(rect_check), "El control cae entero dentro de la fila")
	_check(
		rect_box.encloses(rect_label) and rect_box.encloses(rect_check),
		"Etiqueta y control caen dentro de la columna"
	)
	_check(
		rect_row.position.y >= rect_previous.end.y - 0.5, "La fila empieza despues de la anterior"
	)
	_check(rect_following.position.y >= rect_row.end.y - 0.5, "VOLVER empieza despues de la fila")
	_check(not rect_row.intersects(rect_previous), "La fila no se solapa con la anterior")
	_check(not rect_row.intersects(rect_following), "La fila no se solapa con VOLVER")
	_check(label.text == "REDUCIR MOVIMIENTO", "La etiqueta dice REDUCIR MOVIMIENTO")
	_check(title.text == "AJUSTES", "El titulo dice AJUSTES")
	_check(
		rect_title.end.y <= rect_separator.position.y + 0.5,
		"El titulo AJUSTES va antes de su separador"
	)

	# --- Persistencia -------------------------------------------------------
	check.button_pressed = true
	_check(
		bool(save.call("get_setting", "reduced_motion", false)),
		"Marcar la opcion guarda la preferencia"
	)
	save.call("save_profile")
	save.call("load_profile")
	_check(
		bool(save.call("get_setting", "reduced_motion", false)), "La preferencia se relee del disco"
	)
	_check(check.text == "SÍ", "El control muestra el estado activo")

	# --- Efecto real --------------------------------------------------------
	var feel: Node = root.get_node("GameFeel")
	feel.call("shake", 5.0)
	feel.call("flash", Color(1, 0, 0), 0.5)
	_check(
		is_zero_approx(float(feel.get("shake_strength"))), "Con movimiento reducido no hay sacudida"
	)
	_check(
		is_zero_approx(float(feel.get("flash_amount"))), "Con movimiento reducido no hay destello"
	)
	var offset: Vector2 = feel.call("camera_offset")
	_check(offset.is_equal_approx(Vector2.ZERO), "La camara no se desplaza")

	check.button_pressed = false
	feel.call("shake", 5.0)
	feel.call("flash", Color(1, 0, 0), 0.5)
	_check(float(feel.get("shake_strength")) > 0.0, "Sin la opcion la sacudida vuelve")
	_check(float(feel.get("flash_amount")) > 0.0, "Sin la opcion el destello vuelve")

	# --- Fila GENERAL -------------------------------------------------------
	_check(
		(
			master_row != null
			and master_label != null
			and master_slider != null
			and master_value != null
		),
		"Existe la fila GENERAL con etiqueta, slider y valor"
	)
	if master_row == null or master_label == null or master_slider == null or master_value == null:
		_check(false, "No se puede medir GENERAL sin sus nodos")
	else:
		_check(master_row.is_visible_in_tree(), "La fila GENERAL se ve")
		_check(
			rect_separator.end.y <= rect_master.position.y + 0.5,
			"GENERAL va debajo del titulo AJUSTES"
		)
		_check(rect_panel.encloses(rect_master), "La fila GENERAL cae dentro del panel")
		_check(rect_box.encloses(rect_master), "La fila GENERAL cae dentro de la columna")
		_check(
			rect_master.encloses(master_label.get_global_rect()),
			"La etiqueta de GENERAL cae en su fila"
		)
		_check(
			rect_master.encloses(master_slider.get_global_rect()),
			"El slider de GENERAL cae en su fila"
		)
		_check(
			rect_master.encloses(master_value.get_global_rect()),
			"El valor de GENERAL cae en su fila"
		)
		_check(master_label.text == "General", "La etiqueta dice General")
		_check(
			is_equal_approx(master_slider.value, 1.0), "El slider GENERAL parte del ajuste guardado"
		)
		master_slider.value = 0.42
		_check(
			is_equal_approx(float(save.call("get_setting", "master", -1.0)), 0.42),
			"Mover GENERAL guarda el ajuste"
		)
		_check(master_value.text == "42%", "El valor de GENERAL muestra el porcentaje")
		var master_bus := AudioServer.get_bus_index("Master")
		_check(
			master_bus >= 0 and not AudioServer.is_bus_mute(master_bus),
			"General al 42 % no silencia el bus Master"
		)
		master_slider.value = 0.0
		_check(
			master_bus >= 0 and AudioServer.is_bus_mute(master_bus),
			"General a cero silencia el bus Master"
		)
		master_slider.value = 0.42
		save.call("save_profile")
		save.call("load_profile")
		_check(
			is_equal_approx(float(save.call("get_setting", "master", -1.0)), 0.42),
			"General persiste en el disco"
		)

	# --- Fila CALIDAD -------------------------------------------------------
	_check(
		quality_row != null and quality_label != null and quality_button != null,
		"Existe la fila CALIDAD con etiqueta y boton"
	)
	if quality_row == null or quality_label == null or quality_button == null:
		_check(false, "No se puede recorrer CALIDAD sin sus nodos")
	else:
		_check(quality_row.is_visible_in_tree(), "La fila CALIDAD se ve")
		_check(rect_master.end.y <= rect_quality.position.y + 0.5, "CALIDAD va debajo de GENERAL")
		_check(rect_quality.end.y <= rect_music.position.y + 0.5, "MUSICA va debajo de CALIDAD")
		_check(rect_panel.encloses(rect_quality), "La fila CALIDAD cae dentro del panel")
		_check(rect_box.encloses(rect_quality), "La fila CALIDAD cae dentro de la columna")
		_check(
			rect_quality.encloses(quality_label.get_global_rect()),
			"La etiqueta de CALIDAD cae en su fila"
		)
		_check(
			rect_quality.encloses(quality_button.get_global_rect()),
			"El boton de CALIDAD cae en su fila"
		)
		_check(quality_label.text == "Calidad", "La etiqueta dice Calidad")
		var names := ["BAJO", "MEDIO", "ALTO"]
		var quality := clampi(int(save.call("get_setting", "quality", 2)), 0, 2)
		_check(quality_button.text == names[quality], "El boton de CALIDAD muestra el ajuste")
		_check_quality_effect(quality, environment)
		for _step in 3:
			var before := quality
			quality_button.pressed.emit()
			quality = clampi(int(save.call("get_setting", "quality", 2)), 0, 2)
			_check(
				quality == (before + 2) % 3,
				"Pulsar CALIDAD pasa de %s a %s" % [names[before], names[quality]]
			)
			_check(quality_button.text == names[quality], "La etiqueta de CALIDAD sigue al ajuste")
			_check_quality_effect(quality, environment)
		var elegida := (quality + 2) % 3
		quality_button.pressed.emit()
		quality = clampi(int(save.call("get_setting", "quality", 2)), 0, 2)
		_check(quality == elegida, "Una pulsacion mas deja la calidad elegida")
		save.call("save_profile")
		save.call("load_profile")
		_check(
			int(save.call("get_setting", "quality", -1)) == elegida, "Calidad persiste en el disco"
		)

	# --- Fila FOV -----------------------------------------------------------
	_check(
		fov_row != null and fov_label != null and fov_slider != null and fov_value != null,
		"Existe la fila FOV con etiqueta, slider y valor"
	)
	if fov_row == null or fov_label == null or fov_slider == null or fov_value == null:
		_check(false, "No se puede medir FOV sin sus nodos")
	else:
		_check(fov_row.is_visible_in_tree(), "La fila FOV se ve")
		_check(rect_quality.end.y <= rect_fov.position.y + 0.5, "FOV va debajo de CALIDAD")
		_check(rect_fov.end.y <= rect_extras.position.y + 0.5, "EXTRAS va debajo de FOV")
		_check(rect_panel.encloses(rect_fov), "La fila FOV cae dentro del panel")
		_check(rect_box.encloses(rect_fov), "La fila FOV cae dentro de la columna")
		_check(rect_fov.encloses(fov_label.get_global_rect()), "La etiqueta de FOV cae en su fila")
		_check(rect_fov.encloses(fov_slider.get_global_rect()), "El slider de FOV cae en su fila")
		_check(rect_fov.encloses(fov_value.get_global_rect()), "El valor de FOV cae en su fila")
		_check(fov_label.text == "FOV", "La etiqueta dice FOV")
		_check(
			(
				is_equal_approx(fov_slider.min_value, 45.0)
				and is_equal_approx(fov_slider.max_value, 85.0)
			),
			"El FOV se mueve entre 45 y 85 grados"
		)
		_check(is_equal_approx(fov_slider.value, 55.0), "El slider FOV parte del valor por defecto")
		fov_slider.value = 70.0
		_check(
			is_equal_approx(float(save.call("get_setting", "fov", -1.0)), 70.0),
			"Mover FOV guarda el ajuste"
		)
		_check(fov_value.text == "70°", "El valor de FOV muestra los grados")
		save.call("save_profile")
		save.call("load_profile")
		_check(
			is_equal_approx(float(save.call("get_setting", "fov", -1.0)), 70.0),
			"FOV persiste en el disco"
		)

	# --- Fila EXTRAS (V-Sync, asistencia e idioma) --------------------------
	_check(
		(
			extras_row != null
			and vsync_button != null
			and assisted_button != null
			and language_button != null
		),
		"Existe la fila EXTRAS con V-Sync, asistencia e idioma"
	)
	if (
		extras_row == null
		or vsync_button == null
		or assisted_button == null
		or language_button == null
	):
		_check(false, "No se puede recorrer EXTRAS sin sus nodos")
	else:
		_check(extras_row.is_visible_in_tree(), "La fila EXTRAS se ve")
		_check(rect_fov.end.y <= rect_extras.position.y + 0.5, "EXTRAS va debajo de FOV")
		_check(rect_extras.end.y <= rect_music.position.y + 0.5, "MUSICA va debajo de EXTRAS")
		_check(rect_panel.encloses(rect_extras), "La fila EXTRAS cae dentro del panel")
		_check(rect_box.encloses(rect_extras), "La fila EXTRAS cae dentro de la columna")
		for button: Button in [vsync_button, assisted_button, language_button]:
			_check(
				rect_extras.encloses(button.get_global_rect()),
				"El boton %s cae dentro de EXTRAS" % button.name
			)
		_check(bool(save.call("get_setting", "vsync", false)), "V-Sync viene activado")
		_check(vsync_button.text == "V-SYNC: SÍ", "El boton muestra V-Sync activado")
		vsync_button.pressed.emit()
		_check(not bool(save.call("get_setting", "vsync", true)), "Pulsar V-Sync lo desactiva")
		_check(vsync_button.text == "V-SYNC: NO", "El boton muestra V-Sync desactivado")
		_check(
			not bool(save.call("get_setting", "assisted", true)), "La asistencia viene desactivada"
		)
		_check(assisted_button.text == "ASISTIDO: NO", "El boton muestra la ayuda apagada")
		assisted_button.pressed.emit()
		_check(bool(save.call("get_setting", "assisted", false)), "Pulsar ASISTIDO activa la ayuda")
		_check(assisted_button.text == "ASISTIDO: SÍ", "El boton muestra la ayuda encendida")
		_check(
			String(save.call("get_setting", "language", "")) == "es", "El idioma por defecto es ES"
		)
		_check(language_button.text == "IDIOMA: ES", "El boton muestra IDIOMA: ES")
		language_button.pressed.emit()
		_check(String(save.call("get_setting", "language", "")) == "ca", "IDIOMA pasa de ES a CA")
		_check(TranslationServer.get_locale() == "ca", "El locale activo pasa a catalan")
		_check(
			TranslationServer.translate("VOLVER") == "TORNA",
			"El catalan traduce las etiquetas fijas"
		)
		_check(
			TranslationServer.translate("%d monedas") == "%d monedes",
			"El catalan traduce los textos con formato"
		)
		_check(
			(
				TranslationServer.translate("Obrero") == "Obrer"
				and TranslationServer.translate("Caballero") == "Cavaller"
			),
			"El catalan traduce los nombres de personajes"
		)
		language_button.pressed.emit()
		_check(String(save.call("get_setting", "language", "")) == "en", "IDIOMA pasa de CA a EN")
		_check(TranslationServer.get_locale() == "en", "El locale activo pasa a ingles")
		_check(
			TranslationServer.translate("VOLVER") == "BACK", "El ingles traduce las etiquetas fijas"
		)
		_check(
			TranslationServer.translate("ASISTIDO: SÍ") == "ASSISTED: YES",
			"El ingles traduce los estados de los botones"
		)
		_check(
			(
				TranslationServer.translate("Obrero") == "Worker"
				and TranslationServer.translate("Caballero") == "Knight"
			),
			"El ingles traduce los nombres de personajes"
		)
		_check(
			(
				(
					TranslationServer.translate("Cámara:  Ratón  o  stick derecho")
					== "Camera:  Mouse  or  right stick"
				)
				and TranslationServer.translate("Reiniciar carrera:  R") == "Restart race:  R"
			),
			"El ingles traduce los controles nuevos"
		)
		_check(TranslationServer.translate("¡YA!") == "GO!", "El ingles traduce el aviso de salida")
		save.call("save_profile")
		save.call("load_profile")
		_check(
			String(save.call("get_setting", "language", "")) == "en",
			"El idioma persiste en el disco"
		)
		_check(not bool(save.call("get_setting", "vsync", true)), "V-Sync persiste en el disco")
		_check(
			bool(save.call("get_setting", "assisted", false)), "La asistencia persiste en el disco"
		)
		language_button.pressed.emit()
		_check(String(save.call("get_setting", "language", "")) == "es", "IDIOMA vuelve de EN a ES")
		_check(TranslationServer.get_locale() == "es", "El locale vuelve a espanol")
		_check(
			TranslationServer.translate("VOLVER") == "VOLVER", "En espanol se lee el texto original"
		)
		save.call("save_profile")

	# Se conserva lo que haya quedado tras las pruebas anteriores.
	var persisted_master := float(save.call("get_setting", "master", 1.0))
	var persisted_quality := clampi(int(save.call("get_setting", "quality", 2)), 0, 2)
	var persisted_fov := float(save.call("get_setting", "fov", 55.0))
	var persisted_vsync := bool(save.call("get_setting", "vsync", true))
	var persisted_assisted := bool(save.call("get_setting", "assisted", false))
	var persisted_language := String(save.call("get_setting", "language", "es"))

	# --- Borrar progreso ----------------------------------------------------
	_check(
		reset_button != null and reset_dialog != null, "Existe BORRAR PROGRESO y su confirmacion"
	)
	if reset_button == null or reset_dialog == null:
		_check(false, "No se puede probar el borrado sin sus nodos")
	else:
		var rect_reset := reset_button.get_global_rect()
		_check(reset_button.text == "BORRAR PROGRESO", "El boton dice BORRAR PROGRESO")
		_check(rect_panel.encloses(rect_reset), "BORRAR PROGRESO cae dentro del panel")
		_check(rect_box.encloses(rect_reset), "BORRAR PROGRESO cae dentro de la columna")
		_check(
			rect_reset.position.y >= rect_row.end.y - 0.5,
			"BORRAR PROGRESO va despues de REDUCIR MOVIMIENTO"
		)
		_check(
			rect_following.position.y >= rect_reset.end.y - 0.5,
			"VOLVER va despues de BORRAR PROGRESO"
		)
		_check(not rect_reset.intersects(rect_row), "BORRAR PROGRESO no pisa la fila anterior")
		_check(not rect_reset.intersects(rect_following), "BORRAR PROGRESO no pisa VOLVER")
		_check(
			String(save.get("_save_path")) == SAVE, "El test sigue escribiendo en su perfil aislado"
		)
		# Progreso falso en el perfil del test; los ajustes quedan como estan.
		var locked_id := ""
		for character_id: String in CharacterCatalog.ids():
			if CharacterCatalog.price(character_id) > 0:
				locked_id = character_id
				break
		_check(locked_id != "", "Hay un personaje bloqueado para probar el borrado")
		var data: Dictionary = save.get("data")
		data["coins"] = 321
		data["character"] = locked_id
		var unlocks: Array = CharacterCatalog.free_ids()
		unlocks.append(locked_id)
		data["unlocked_characters"] = unlocks
		data["has_best"] = true
		data["best_time"] = 99.5
		data["best_times"] = {"pivot_push": 99.5}
		data["medals"] = {"gold": 3, "silver": 2, "bronze": 1}
		data["tutorial_seen"] = true
		save.set("data", data)
		save.call("save_profile")
		_check(
			bool(save.call("is_character_unlocked", locked_id)),
			"El progreso sembrado desbloquea el personaje comprado"
		)
		_check(
			String(save.call("character_id")) == locked_id,
			"El personaje comprado queda equipado antes de borrar"
		)
		reset_button.pressed.emit()
		await process_frame
		_check(reset_dialog.visible, "Pulsar BORRAR PROGRESO abre la confirmacion")
		_check(
			String(reset_dialog.title) == "Borrar progreso",
			"La confirmacion de borrado tiene titulo"
		)
		_check(
			String(reset_dialog.dialog_text).begins_with("Se borran"),
			"La confirmacion de borrado explica que se pierde"
		)
		reset_dialog.get_ok_button().pressed.emit()
		await process_frame
		await process_frame
		_check(not reset_dialog.visible, "Confirmar cierra la confirmacion")
		_check(
			int(save.get("data").get("coins", -1)) == 0, "Borrar progreso deja las monedas a cero"
		)
		_check(not bool(save.get("data").get("has_best", true)), "Borrar progreso quita el record")
		_check(
			is_equal_approx(float(save.get("data").get("best_time", -1.0)), 0.0),
			"Borrar progreso deja el tiempo a cero"
		)
		var best_times: Dictionary = save.get("data").get("best_times", {"x": 1})
		_check(best_times.is_empty(), "Borrar progreso vacia los records por circuito")
		_check(
			not bool(save.get("data").get("tutorial_seen", true)),
			"Borrar progreso vuelve a mostrar el tutorial"
		)
		var medals: Dictionary = save.get("data").get("medals", {})
		_check(
			(
				int(medals.get("gold", -1)) == 0
				and int(medals.get("silver", -1)) == 0
				and int(medals.get("bronze", -1)) == 0
			),
			"Borrar progreso deja las medallas a cero"
		)
		var unlocks_after: Array = save.get("data").get("unlocked_characters", [])
		var free_ids := CharacterCatalog.free_ids()
		var only_free := unlocks_after.size() == free_ids.size()
		for free_id: String in free_ids:
			only_free = only_free and unlocks_after.has(free_id)
		_check(only_free, "Borrar progreso deja solo los personajes gratis")
		_check(
			not bool(save.call("is_character_unlocked", locked_id)),
			"Borrar progreso vuelve a bloquear el personaje comprado"
		)
		_check(
			String(save.get("data").get("character", "")) == CharacterCatalog.default_id(),
			"Borrar progreso vuelve al personaje por defecto"
		)
		var settings: Dictionary = save.get("data").get("settings", {})
		_check(
			is_equal_approx(float(settings.get("master", -1.0)), persisted_master),
			"Borrar progreso conserva el volumen General"
		)
		_check(
			int(settings.get("quality", -1)) == persisted_quality,
			"Borrar progreso conserva la Calidad"
		)
		_check(
			is_equal_approx(float(settings.get("fov", -1.0)), persisted_fov),
			"Borrar progreso conserva el FOV"
		)
		_check(
			bool(settings.get("vsync", true)) == persisted_vsync,
			"Borrar progreso conserva el V-Sync"
		)
		_check(
			bool(settings.get("assisted", false)) == persisted_assisted,
			"Borrar progreso conserva la asistencia"
		)
		_check(
			String(settings.get("language", "")) == persisted_language,
			"Borrar progreso conserva el idioma"
		)
		_check(
			String(save.get("_save_path")) == SAVE,
			"El borrado se queda en el perfil aislado del test"
		)
		var file := FileAccess.open(SAVE, FileAccess.READ)
		var parsed: Variant = null
		if file != null:
			parsed = JSON.parse_string(file.get_as_text())
			file.close()
		var disk: Dictionary = parsed if parsed is Dictionary else {}
		_check(int(disk.get("coins", -1)) == 0, "El perfil borrado se escribe en el disco")
		var disk_settings: Dictionary = disk.get("settings", {})
		_check(
			is_equal_approx(float(disk_settings.get("master", -1.0)), persisted_master),
			"Los ajustes quedan en el perfil borrado"
		)

	menu.free()
	world.free()
	await process_frame
	print("RESULT: %s" % ("TODO OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)
