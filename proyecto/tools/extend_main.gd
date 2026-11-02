extends SceneTree

## Herramienta de una sola pasada: añade el acto 3 de Pivot Push (la forja) a
## la escena original `main.tscn` sin rehacer el circuito a mano. Trabaja sobre
## la escena ya cargada y la vuelve a empaquetar.

const PATH := "res://scenes/main.tscn"

var scene_root: Node3D
var course: Node3D
var mat_floor: Material
var mat_alt: Material
var mat_wall: Material
var mat_gold: Material
var mat_hazard: Material


func _initialize() -> void:
	mat_floor = load("res://materials/platform_purple.tres")
	mat_alt = load("res://materials/platform_pink.tres")
	mat_wall = load("res://materials/purple.tres")
	mat_gold = load("res://materials/yellow.tres")
	mat_hazard = load("res://materials/spin_hazard.tres")

	var packed := load(PATH) as PackedScene
	scene_root = packed.instantiate() as Node3D
	course = scene_root.get_node("Course") as Node3D
	_clear_previous()

	_tune_original()
	_build_course()
	_build_obstacles()
	_build_decor()
	_update_level_info()

	var out := PackedScene.new()
	var error := out.pack(scene_root)
	if error != OK:
		push_error("No se pudo empaquetar: %s" % error_string(error))
		quit(1)
		return
	error = ResourceSaver.save(out, PATH)
	if error != OK:
		push_error("No se pudo guardar: %s" % error_string(error))
		quit(1)
		return
	print("Pivot Push extendido: %s" % PATH)
	scene_root.free()
	quit()


# ------------------------------------------------------------------ helpers
## La herramienta se puede relanzar: borra el acto 3 anterior (solo sus nodos,
## por nombre) para no duplicar plataformas ni obstáculos.
const PREVIOUS := [
	"ForgeRampDown", "ForgeDeck", "ForgeRampUp", "ChimneyBridge",
	"ChimneyLanding", "ForgeClimb", "ForgeSummit", "ForgeDrop",
	"ForgeFinal", "ForgePlaza", "ForgeWallLeft", "ForgeWallRight",
	"FinalWallLeft", "FinalWallRight", "BoulderA", "BoulderB",
	"BoulderC", "ForgeBelt", "FinalBelt", "RotorA", "RotorB", "RotorC",
	"SweeperSummit", "SweeperFinalA", "SweeperFinalB",
	"PendulumSummitA", "PendulumSummitB", "ForgeRailLeft",
	"ForgeRailRight", "ChimneyRailLeft", "ChimneyRailRight",
	"ChimneyCurbLeft", "ChimneyCurbRight", "GaleCurbLeft", "GaleCurbRight",
	"ChimneyLandingRailLeft", "ChimneyLandingRailRight", "SummitRailLeft",
	"SummitRailRight", "FinalRailLeftB", "FinalRailRightB", "PlazaRailLeft",
	"PlazaRailRight",
]


func _clear_previous() -> void:
	for parent in [course, scene_root.get_node("Decor")]:
		for child in parent.get_children():
			var node_name := String(child.name)
			var drop := node_name in PREVIOUS or node_name in [
				"Checkpoint6", "Checkpoint7", "Checkpoint8", "Checkpoint9",
				"Checkpoint10", "Checkpoint11",
			]
			if not drop:
				drop = node_name.begins_with("Spike")
			if not drop:
				drop = node_name.begins_with("HazardForge")
			if not drop:
				drop = node_name.begins_with("HazardPlaza")
			if drop:
				parent.remove_child(child)
				child.free()


func _add(node: Node) -> void:
	node.owner = scene_root


func _slab(node_name: String, z: float, sx: float, sz: float, top: float,
		material: Material) -> void:
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = Vector3(sx, 0.5, sz)
	box.position = Vector3(0.0, top - 0.25, z)
	box.material = material
	box.use_collision = true
	course.add_child(box)
	_add(box)


func _ramp(node_name: String, z_from: float, z_to: float, y_from: float,
		y_to: float, width: float, material: Material) -> void:
	var run := z_from - z_to
	var rise := y_to - y_from
	var length := sqrt(run * run + rise * rise)
	var pitch := atan2(rise, run)
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = Vector3(width, 0.5, length)
	box.position = Vector3(0.0, (y_from + y_to) * 0.5 - 0.25 * cos(pitch),
		(z_from + z_to) * 0.5 - 0.25 * sin(pitch))
	box.rotation = Vector3(pitch, 0.0, 0.0)
	box.material = material
	box.use_collision = true
	course.add_child(box)
	_add(box)


func _wall(node_name: String, x: float, y: float, z: float, size: Vector3) -> void:
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = size
	box.position = Vector3(x, y, z)
	box.material = mat_wall
	box.use_collision = true
	course.add_child(box)
	_add(box)


func _obstacle(node_name: String, path: String, position: Vector3,
		values: Dictionary = {}) -> void:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = node_name
	node.position = position
	for key in values.keys():
		node.set(key, values[key])
	course.add_child(node)
	_add(node)


func _rail(node_name: String, x: float, z: float, length: float, top: float) -> void:
	var decor := scene_root.get_node("Decor") as Node3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, length)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat_gold
	instance.position = Vector3(x, top + 0.55, z)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(instance)
	_add(instance)


func _hazard(node_name: String, z: float, top: float, width: float) -> void:
	var decor := scene_root.get_node("Decor") as Node3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.02, 0.55)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat_hazard
	instance.position = Vector3(0.0, top + 0.01, z)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(instance)
	_add(instance)


## Ajustes de justicia en el tramo original: el puente del viento era tan
## estrecho que una ráfaga normal tiraba al que lo cruzaba. Se ensancha un
## poco y se suaviza la ráfaga, sin quitar el obstáculo.
func _tune_original() -> void:
	var bridge := course.get_node_or_null("WindBridge") as CSGBox3D
	if bridge != null and bridge.size.x < 5.0:
		bridge.size.x = 5.2
	for tunnel_name in ["WindTunnel", "WindTunnel2"]:
		var tunnel := course.get_node_or_null(tunnel_name)
		if tunnel != null:
			tunnel.set("strength", 4.6)
			tunnel.set("gust_amplitude", 1.4)


# ------------------------------------------------------------------- course
func _build_course() -> void:
	# Plaza de meta antigua = plaza intermedia del acto 3 (y = 4,0).
	_ramp("ForgeRampDown", -214.0, -220.0, 4.0, 2.0, 9.4, mat_floor)
	_slab("ForgeDeck", -232.0, 13.0, 24.0, 2.0, mat_alt)
	_ramp("ForgeRampUp", -244.0, -250.0, 2.0, 4.8, 9.4, mat_floor)
	_slab("ChimneyBridge", -260.0, 4.6, 20.0, 4.8, mat_alt)
	_slab("ChimneyLanding", -275.0, 9.0, 10.0, 4.8, mat_floor)
	_ramp("ForgeClimb", -280.0, -298.0, 4.8, 9.2, 9.4, mat_alt)
	_slab("ForgeSummit", -305.0, 13.0, 14.0, 9.2, mat_floor)
	_ramp("ForgeDrop", -312.0, -330.0, 9.2, 3.6, 9.4, mat_alt)
	_slab("ForgeFinal", -342.0, 13.0, 24.0, 3.6, mat_floor)
	_slab("ForgePlaza", -363.0, 16.0, 18.0, 3.6, mat_alt)

	# Muros: cierran la cornisa de los tramos anchos del acto 3.
	_wall("ForgeWallLeft", -7.2, 3.4, -232.0, Vector3(0.9, 2.8, 24.0))
	_wall("ForgeWallRight", 7.2, 3.4, -232.0, Vector3(0.9, 2.8, 24.0))
	# Brocal bajo en el puente de las aspas: un golpe cuesta tiempo, no la
	# carrera, y nadie cae al vacío por un empujón lateral.
	_wall("ChimneyCurbLeft", -3.05, 5.05, -260.0, Vector3(0.2, 0.5, 20.0))
	_wall("ChimneyCurbRight", 3.05, 5.05, -260.0, Vector3(0.2, 0.5, 20.0))
	_wall("FinalWallLeft", -7.0, 4.9, -342.0, Vector3(0.9, 2.6, 24.0))
	_wall("FinalWallRight", 7.0, 4.9, -342.0, Vector3(0.9, 2.6, 24.0))


func _build_obstacles() -> void:
	var checkpoint := "res://scenes/race/checkpoint.tscn"
	var boulder := "res://scenes/obstacles/boulder.tscn"
	var rotor := "res://scenes/obstacles/rotor_gate.tscn"
	var spike := "res://scenes/obstacles/spike_trap.tscn"
	var sweeper := "res://scenes/obstacles/sweeper.tscn"
	var pendulum := "res://scenes/obstacles/pendulum.tscn"
	var conveyor := "res://scenes/obstacles/conveyor.tscn"

	_obstacle("Checkpoint6", checkpoint, Vector3(0.0, 4.0, -209.0),
		{"checkpoint_name": "Checkpoint 6"})

	# Pasillo de las rocas: dos rocas por los carriles de fuera. El centro
	# queda libre para cruzar y los bordes son los que hay que esquivar.
	_obstacle("BoulderA", boulder, Vector3(-3.8, 3.0, -241.0),
		{"travel": Vector3(0.0, 0.0, 19.0), "speed": 5.2, "phase_offset": 0.0})
	_obstacle("BoulderB", boulder, Vector3(3.8, 3.0, -241.0),
		{"travel": Vector3(0.0, 0.0, 19.0), "speed": 5.8, "phase_offset": 2.6})
	for i in 2:
		_obstacle("SpikeDeck%d" % i, spike, Vector3(0.0, 2.0, -227.0 - float(i) * 8.0),
			{"phase_offset": float(i) * 1.3})
	_obstacle("ForgeBelt", conveyor, Vector3(0.0, 1.875, -232.0),
		{"direction": Vector3(0.0, 0.0, 1.0), "force": 3.2, "arrow_span": 2.0})
	_obstacle("Checkpoint7", checkpoint, Vector3(0.0, 2.0, -221.5),
		{"checkpoint_name": "Checkpoint 7"})
	_obstacle("Checkpoint8", checkpoint, Vector3(0.0, 4.8, -251.5),
		{"checkpoint_name": "Checkpoint 8"})

	# Puente de la chimenea: tres aspas giratorias.
	_obstacle("RotorA", rotor, Vector3(0.0, 5.7, -254.0), {"spin_speed": 0.95})
	_obstacle("RotorB", rotor, Vector3(0.0, 5.7, -260.0),
		{"spin_speed": 1.05, "spin_direction": -1.0, "phase_offset": 2.1})
	_obstacle("RotorC", rotor, Vector3(0.0, 5.7, -266.0),
		{"spin_speed": 1.15, "phase_offset": 0.7})
	_obstacle("Checkpoint9", checkpoint, Vector3(0.0, 4.8, -271.5),
		{"checkpoint_name": "Checkpoint 9"})

	# Terraza de pinchos: ocho trampas en 4 x 2.
	for row in 2:
		for col in 4:
			_obstacle("Spike%d_%d" % [row, col], spike,
				Vector3(-4.5 + float(col) * 3.0, 4.8, -274.0 - float(row) * 4.0),
				{"phase_offset": float(row) * 1.6 + float(col) * 0.55})
	_obstacle("Checkpoint10", checkpoint, Vector3(0.0, 9.2, -299.5),
		{"checkpoint_name": "Checkpoint 10"})

	# Cima de la forja: barrido y dos péndulos.
	_obstacle("SweeperSummit", sweeper, Vector3(0.0, 9.55, -302.0),
		{"spin_speed": 2.5, "push_force": 6.8, "stuns": true})
	_obstacle("PendulumSummitA", pendulum, Vector3(0.0, 13.4, -305.5),
		{"max_angle": 1.05, "swing_speed": 0.0024, "push_force": 12.0,
		"phase_offset": 0.2})
	_obstacle("PendulumSummitB", pendulum, Vector3(0.0, 13.4, -310.0),
		{"max_angle": 1.05, "swing_speed": 0.0027, "push_force": 12.0,
		"phase_offset": 1.8})

	# Recta final de la forja.
	_obstacle("Checkpoint11", checkpoint, Vector3(0.0, 3.6, -331.5),
		{"checkpoint_name": "Checkpoint 11"})
	_obstacle("SweeperFinalA", sweeper, Vector3(0.0, 3.95, -336.0),
		{"spin_speed": 2.7, "push_force": 7.0, "stuns": true})
	_obstacle("SweeperFinalB", sweeper, Vector3(0.0, 3.95, -348.0),
		{"spin_speed": 3.0, "spin_direction": -1.0, "push_force": 7.4,
		"stuns": true})
	_obstacle("FinalBelt", conveyor, Vector3(0.0, 3.475, -342.0),
		{"direction": Vector3(0.0, 0.0, 1.0), "force": 3.8, "arrow_span": 2.2})
	for row in 2:
		for col in 2:
			_obstacle("SpikeFinal%d_%d" % [row, col], spike,
				Vector3(-3.0 + float(col) * 6.0, 3.6, -339.0 - float(row) * 6.0),
				{"phase_offset": float(row) * 1.4 + float(col) * 0.9})

	# La meta se traslada al final del acto nuevo.
	var finish := course.get_node_or_null("FinishLine") as Node3D
	if finish != null:
		finish.position = Vector3(0.0, 3.6, -363.0)


func _build_decor() -> void:
	_rail("ForgeRailLeft", -7.2, -232.0, 24.0, 2.0)
	_rail("ForgeRailRight", 7.2, -232.0, 24.0, 2.0)
	_rail("ChimneyRailLeft", -2.4, -260.0, 20.0, 4.8)
	_rail("ChimneyRailRight", 2.4, -260.0, 20.0, 4.8)
	_rail("ChimneyLandingRailLeft", -4.6, -275.0, 10.0, 4.8)
	_rail("ChimneyLandingRailRight", 4.6, -275.0, 10.0, 4.8)
	_rail("SummitRailLeft", -6.6, -305.0, 14.0, 9.2)
	_rail("SummitRailRight", 6.6, -305.0, 14.0, 9.2)
	_rail("FinalRailLeftB", -7.0, -342.0, 24.0, 3.6)
	_rail("FinalRailRightB", 7.0, -342.0, 24.0, 3.6)
	_rail("PlazaRailLeft", -8.1, -363.0, 18.0, 3.6)
	_rail("PlazaRailRight", 8.1, -363.0, 18.0, 3.6)
	for i in 3:
		_hazard("HazardForge%d" % i, -226.0 - float(i) * 6.0, 2.0, 10.8)
	for i in 2:
		_hazard("HazardPlaza%d" % i, -358.0 - float(i) * 3.0, 3.6, 13.6)

	var crowd := scene_root.get_node_or_null("Crowd")
	if crowd != null:
		crowd.set("per_row", 50)
		crowd.set("stand_length", 400.0)
		crowd.set("stand_center_z", -175.0)
	var director := scene_root.get_node_or_null("RaceDirector")
	if director != null:
		director.set("finish_z", -363.0)
		director.set("course_length", 368.0)


func _update_level_info() -> void:
	var info := scene_root.get_node_or_null("LevelInfo")
	if info == null:
		return
	info.set("finish_z", -363.0)
	info.set("course_length", 368.0)
	info.set("gold_time", 130.0)
	info.set("silver_time", 170.0)
	info.set("bronze_time", 215.0)

	var points: PackedVector3Array = info.get("waypoints")
	var lanes: PackedFloat32Array = info.get("lane_widths")
	# La herramienta se puede relanzar: se queda con la ruta original (31
	# puntos) y vuelve a añadir el acto 3, sin duplicar el tramo.
	while points.size() > 31:
		points.remove_at(points.size() - 1)
	while lanes.size() > 31:
		lanes.remove_at(lanes.size() - 1)
	var extra := [
		[Vector3(0.0, 4.2, -212.0), 2.8], [Vector3(0.0, 4.2, -214.0), 2.8],
		[Vector3(0.0, 3.0, -217.0), 2.4], [Vector3(0.0, 2.2, -220.0), 2.8],
		[Vector3(0.0, 2.2, -224.0), 2.6], [Vector3(0.0, 2.2, -229.0), 2.6],
		[Vector3(0.0, 2.2, -234.0), 2.6], [Vector3(0.0, 2.2, -239.0), 2.6],
		[Vector3(0.0, 2.2, -244.0), 2.8], [Vector3(0.0, 3.5, -247.0), 2.2],
		[Vector3(0.0, 5.0, -250.0), 2.4], [Vector3(0.0, 5.0, -254.0), 2.4],
		[Vector3(0.0, 5.0, -258.0), 2.4], [Vector3(0.0, 5.0, -262.0), 2.4],
		[Vector3(0.0, 5.0, -266.0), 2.4], [Vector3(0.0, 5.0, -270.0), 2.4],
		[Vector3(0.0, 5.0, -274.0), 2.4], [Vector3(0.0, 5.0, -278.0), 2.4],
		[Vector3(0.0, 5.0, -280.0), 1.0], [Vector3(0.0, 6.2, -285.0), 2.2],
		[Vector3(0.0, 7.45, -290.0), 2.2], [Vector3(0.0, 8.65, -295.0), 2.2],
		[Vector3(0.0, 9.4, -298.0), 2.8], [Vector3(0.0, 9.4, -302.0), 2.8],
		[Vector3(0.0, 9.4, -306.0), 2.8], [Vector3(0.0, 9.4, -310.0), 2.8],
		[Vector3(0.0, 8.45, -315.0), 2.4], [Vector3(0.0, 6.9, -320.0), 2.2],
		[Vector3(0.0, 5.35, -325.0), 2.2], [Vector3(0.0, 3.8, -330.0), 2.2],
		[Vector3(0.0, 3.8, -334.0), 2.8], [Vector3(0.0, 3.8, -338.0), 2.8],
		[Vector3(0.0, 3.8, -343.0), 2.8], [Vector3(0.0, 3.8, -348.0), 2.8],
		[Vector3(0.0, 3.8, -354.0), 2.8], [Vector3(0.0, 3.8, -358.0), 3.0],
		[Vector3(0.0, 3.8, -363.0), 3.0], [Vector3(0.0, 3.8, -368.0), 3.0],
	]
	for entry in extra:
		points.append(entry[0] as Vector3)
		lanes.append(float(entry[1]))
	info.set("waypoints", points)
	info.set("lane_widths", lanes)
	print("Waypoints: %d  carriles: %d" % [points.size(), lanes.size()])
