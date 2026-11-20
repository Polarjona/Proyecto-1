extends "res://scripts/levels/level_kit.gd"

## Abyss Run (carrera clásica): túnel inundado de 430 m con nado, islas secas y
## quince peligros marinos.

## Circuito abisal: una fosa inundada de 430 m con tres tramos de agua y dos
## islas secas (los checkpoints). El corredor nada en tres dimensiones dentro
## del agua y sale a superficie en las islas, así que el mapa mezcla natación
## con carrera a pie. Los quince obstáculos son exclusivos de este circuito.
const O_WATERLINE := 1.2

const O_FLOOR_Y := -24.0

const O_HALF_WIDTH := 12.0

## Paredes laterales del túnel: su cara interior queda exactamente en
## ±O_HALF_WIDTH, así encajan con las compuertas, las islas y el muelle. Antes
## estaban en ±12,6 y quedaba una rendija de 0,6 m pegada al muro por la que se
## cruzaba cada compuerta sin pasar por el hueco.
const O_WALL_THICKNESS := 1.8

## Las paredes suben hasta aquí: desde el muelle (2 m) no se puede saltar por
## encima y salir del túnel por el aire.
const O_WALL_TOP := 6.0

const O_WALL_HEIGHT := O_WALL_TOP - (O_FLOOR_Y - 1.0)

const O_START_Z := 12.0

const O_FINISH_Z := -416.0

## Islas secas: centro, largo y altura de la meseta (justo bajo la línea de
## agua, para poder salir nadando sin escalón).
const O_ISLANDS := [
	{"z": -117.0, "length": 14.0, "top": 0.4},
	{"z": -247.0, "length": 14.0, "top": 0.4},
]

## Tramos inundados (z inicial, z final). Entre uno y otro quedan las islas.
const O_WATER_STRETCHES := [
	Vector2(-4.0, -110.0),
	Vector2(-124.0, -240.0),
	Vector2(-254.0, -392.0),
]

var _ocean_rock: StandardMaterial3D

var _ocean_rock_dark: StandardMaterial3D

var _ocean_sand: StandardMaterial3D

var _ocean_coral: StandardMaterial3D

var _ocean_coral_alt: StandardMaterial3D

var _ocean_glow: StandardMaterial3D

var _ocean_water: StandardMaterial3D

var _ocean_ray: StandardMaterial3D


func _make_ocean_palette() -> void:
	_ocean_rock = OceanStyle.matte(OceanStyle.ROCK, 0.9)
	_ocean_rock_dark = OceanStyle.matte(OceanStyle.ROCK_DARK, 0.95)
	_ocean_sand = OceanStyle.matte(OceanStyle.SAND, 0.95)
	_ocean_coral = OceanStyle.matte(OceanStyle.CORAL, 0.55)
	_ocean_coral_alt = OceanStyle.matte(OceanStyle.CORAL_ALT, 0.55)
	_ocean_glow = OceanStyle.glow(OceanStyle.GLOW, 1.9)
	_ocean_water = OceanStyle.glass(Color(0.16, 0.68, 0.78), 0.24)
	_ocean_ray = OceanStyle.additive(Color(0.55, 0.95, 1.0), 0.07)


func _build_ocean() -> void:
	_path.clear()
	_widths.clear()
	_make_ocean_palette()
	var course := Node3D.new()
	course.name = "Course"
	host.add_child(course)

	_build_ocean_light()
	_build_ocean_trench(course)
	_build_ocean_start(course)
	_build_ocean_islands(course)
	_build_ocean_finish(course)
	_build_ocean_water(course)
	_build_ocean_path()
	_build_ocean_hazards(course)
	_build_ocean_lifts(course)
	_build_ocean_chokes(course)
	_build_ocean_decor(course)
	_build_ocean_scenery(course)

	_add_level_info(
		{
			"level_id": "abyss_run",
			"display_name": "Abyss Run",
			"round_index": 5,
			"start_z": O_START_Z,
			"finish_z": O_FINISH_Z,
			"course_length": O_START_Z - O_FINISH_Z,
			"gold_time": 112.0,
			"silver_time": 138.0,
			"bronze_time": 172.0,
			"start_position": Vector3(0.0, 2.65, 8.0),
			"path_corridor": true,
		}
	)
	_add_race_manager()
	_add_hud()
	_add_kill_plane(Vector3(0.0, -46.0, -200.0), false)
	_add_player(Vector3(0.0, 2.65, 8.0))
	_add_director(O_START_Z, O_FINISH_Z, O_START_Z - O_FINISH_Z)
	_add_pause()


## Niebla y luz de fondo marino. La niebla es lo que vende la profundidad: sin
## ella el túnel se ve plano y se pierde la sensación de estar bajo el agua.
func _build_ocean_light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.1, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.36, 0.68, 0.78)
	environment.ambient_light_energy = 1.15
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.06, 0.34, 0.42)
	environment.fog_light_energy = 1.1
	environment.fog_density = 0.011
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "OceanEnvironment"
	world.environment = environment
	host.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "OceanSun"
	sun.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	sun.light_color = Color(0.76, 0.95, 1.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	host.add_child(sun)


func _build_ocean_trench(course: Node3D) -> void:
	_slab(
		course,
		"TrenchFloor",
		Vector3(0.0, O_FLOOR_Y - 0.7, -206.0),
		Vector3(30.0, 1.4, 444.0),
		_ocean_sand
	)
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_slab(
			course,
			"TrenchWall" + suffix,
			Vector3(
				side * (O_HALF_WIDTH + O_WALL_THICKNESS * 0.5),
				O_WALL_TOP - O_WALL_HEIGHT * 0.5,
				-206.0
			),
			Vector3(O_WALL_THICKNESS, O_WALL_HEIGHT, 444.0),
			_ocean_rock
		)
		# Repisas de roca a media altura: rompen la pared lisa.
		for i in 9:
			var z := -20.0 - float(i) * 46.0
			_mesh_box(
				course,
				"WallShelf%s%d" % [suffix, i],
				Vector3(side * 12.0, -6.0 - float(i % 3) * 4.0, z),
				Vector3(2.6, 0.55, 9.0),
				_ocean_rock_dark,
				Vector3(0.0, 0.0, side * 6.0)
			)
	# Rocas redondas sobre la arena.
	for i in 26:
		var z := -6.0 - float(i) * 16.0
		var x := sin(float(i) * 2.3) * 9.0
		_ocean_rock_boulder(
			course, "FloorRock%d" % i, Vector3(x, O_FLOOR_Y + 0.2, z), 1.2 + float(i % 4) * 0.5
		)


func _build_ocean_start(course: Node3D) -> void:
	# El muelle llega hasta las paredes (antes medía 22 m y quedaba un canal
	# seco de 0,6 m a cada lado).
	_slab(course, "StartDock", Vector3(0.0, 1.35, 6.0), Vector3(25.4, 1.3, 20.0), _ocean_sand)
	_slab(
		course, "StartDockLip", Vector3(0.0, 1.9, -4.6), Vector3(25.4, 0.4, 1.6), _ocean_rock_dark
	)
	_arch(
		course,
		"StartGate",
		Vector3(0.0, 2.0, 2.0),
		15.0,
		6.4,
		_ocean_rock_dark,
		_ocean_glow,
		"ABYSS RUN"
	)
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_mesh_box(
			course,
			"DockPost" + suffix,
			Vector3(side * 8.0, 2.8, -3.2),
			Vector3(0.35, 1.6, 0.35),
			_ocean_rock_dark
		)
		_mesh_sphere(
			course, "DockLamp" + suffix, Vector3(side * 8.0, 3.75, -3.2), 0.26, _ocean_glow
		)


func _build_ocean_islands(course: Node3D) -> void:
	for i in O_ISLANDS.size():
		var island: Dictionary = O_ISLANDS[i]
		var z: float = island["z"]
		var length: float = island["length"]
		var top: float = island["top"]
		var height := top - O_FLOOR_Y
		# Un poco más anchas que el túnel: se meten en la pared y no dejan un
		# hueco de 0,6 m junto al muro en el que caerse y quedarse atrapado.
		_slab(
			course,
			"Island%d" % i,
			Vector3(0.0, O_FLOOR_Y + height * 0.5, z),
			Vector3(25.4, height, length),
			_ocean_rock
		)
		_slab(
			course,
			"IslandSand%d" % i,
			Vector3(0.0, top - 0.12, z),
			Vector3(25.8, 0.3, length + 0.6),
			_ocean_sand
		)
		for j in 6:
			var side := -1.0 if j % 2 == 0 else 1.0
			_ocean_rock_boulder(
				course,
				"IslandRock%d_%d" % [i, j],
				Vector3(
					side * (9.5 + float(j % 2) * 1.5), top + 0.1, z - length * 0.5 + float(j) * 2.4
				),
				0.9 + float(j % 3) * 0.35
			)
		_ocean_coral_cluster(course, "IslandCoral%d" % i, Vector3(-6.0, top, z + 3.0), 1.2, i + 1)
		_ocean_coral_cluster(course, "IslandCoralB%d" % i, Vector3(6.5, top, z - 2.5), 1.0, i + 3)


func _build_ocean_finish(course: Node3D) -> void:
	# La plataforma empieza detrás de la rampa: si llegaba hasta el agua, su
	# cara vertical tapaba la subida.
	_slab(course, "FinishDeck", Vector3(0.0, 0.3, -407.0), Vector3(25.4, 1.4, 22.0), _ocean_sand)
	# Rampa de ancho completo: antes medía 18 m dentro de un túnel de 24 y se
	# caía uno al fondo seco por los lados. Ahora la única salida es subirla.
	_ramp_z(course, "FinishRamp", 0.0, -391.0, -395.5, 0.5, 1.0, 25.4, _ocean_rock_dark)
	# Cierre del último tramo: pared desde el fondo hasta la base de la rampa,
	# de lado a lado. A media profundidad el túnel ya no continúa: hay que
	# salir por arriba y caminar hasta la meta.
	_slab(
		course,
		"AbyssEndWall",
		Vector3(0.0, (0.5 + O_FLOOR_Y) * 0.5, -392.0),
		Vector3(25.4, 0.5 - O_FLOOR_Y, 1.2),
		_ocean_rock_dark
	)
	_slab(course, "Podium", Vector3(0.0, 1.8, -414.0), Vector3(16.0, 1.6, 6.0), _ocean_rock)
	_obstacle(course, "FinishLine", FINISH_SCENE, Vector3(0.0, 1.0, -408.0))
	for side in [-1.0, 1.0]:
		_mesh_cylinder(
			course,
			"PodiumTorch" + ("L" if side < 0.0 else "R"),
			Vector3(side * 7.0, 3.6, -414.0),
			0.1,
			0.5,
			2.6,
			_ocean_glow,
			Vector3.ZERO,
			8
		)


func _build_ocean_water(course: Node3D) -> void:
	for i in O_WATER_STRETCHES.size():
		var stretch: Vector2 = O_WATER_STRETCHES[i]
		var length := absf(stretch.x - stretch.y)
		var zone := WATER_ZONE_SCRIPT.new() as Area3D
		zone.name = "WaterZone%d" % i
		zone.set("size", Vector3(25.0, O_WATERLINE - O_FLOOR_Y, length))
		zone.set("bubble_count", 70 + i * 20)
		# Cota de crucero de cada tramo: al entrar se baja solo y se mantiene.
		zone.set("cruise_depth", [-10.0, -9.0, -11.0][i])
		# Franja vertical del tramo: se nada entre estas dos cotas y de ahí no
		# se sale, así no se puede bucear por debajo de los obstáculos.
		zone.set("band_min_y", [-16.5, -23.0, -19.0][i])
		zone.set("band_max_y", 0.9)
		zone.position = Vector3(0.0, (O_WATERLINE + O_FLOOR_Y) * 0.5, (stretch.x + stretch.y) * 0.5)
		course.add_child(zone)


## Ruta de los bots y del `LevelInfo`. Va por el centro del túnel, sube a las
## islas y vuelve a bajar al agua en cada tramo.
func _build_ocean_path() -> void:
	_path_add(Vector3(0.0, 2.2, 12.0), Vector3(0.0, 2.2, -2.0), 20.0, 2.0)
	_path_add(Vector3(0.0, -6.0, -8.0), Vector3(0.0, -6.0, -106.0), 20.0, 4.0)
	_path_add(Vector3(0.0, 1.0, -112.0), Vector3(0.0, 1.0, -122.0), 18.0, 3.0)
	_path_add(Vector3(0.0, -6.0, -128.0), Vector3(0.0, -6.0, -236.0), 20.0, 4.0)
	_path_add(Vector3(0.0, 1.0, -242.0), Vector3(0.0, 1.0, -252.0), 18.0, 3.0)
	_path_add(Vector3(0.0, -6.0, -258.0), Vector3(0.0, -6.0, -388.0), 20.0, 4.0)
	_path_add(Vector3(0.0, 1.2, -394.0), Vector3(0.0, 1.2, -410.0), 18.0, 3.0)


## Compuerta de arrecife: cierra el túnel entero salvo un hueco al lado del
## obstáculo. Antes casi todo se podía rodear por una esquina.
func _ocean_choke(
	course: Node3D,
	node_name: String,
	z: float,
	center_x: float,
	center_y: float,
	opening_w: float = 9.0,
	opening_h: float = 9.0
) -> void:
	var thickness := 1.2
	var bottom := O_FLOOR_Y
	var top := O_WATERLINE
	var open_l := clampf(center_x - opening_w * 0.5, -O_HALF_WIDTH + 1.0, O_HALF_WIDTH - 1.0)
	var open_r := clampf(center_x + opening_w * 0.5, -O_HALF_WIDTH + 1.0, O_HALF_WIDTH - 1.0)
	var open_b := clampf(center_y - opening_h * 0.5, bottom + 1.0, top - 1.0)
	var open_t := clampf(center_y + opening_h * 0.5, bottom + 1.0, top - 1.0)
	var middle_y := (top + bottom) * 0.5
	# Los paneles laterales se meten 1,2 m dentro de la pared del túnel: aunque
	# el hueco quede pegado a un lado, la compuerta no deja rendija junto al
	# muro. El único paso posible es la abertura.
	var left_edge := -(O_HALF_WIDTH + 1.2)
	var left_w := open_l - left_edge
	if left_w > 0.2:
		_slab(
			course,
			node_name + "L",
			Vector3(left_edge + left_w * 0.5, middle_y, z),
			Vector3(left_w, top - bottom, thickness),
			_ocean_rock
		)
	var right_edge := O_HALF_WIDTH + 1.2
	var right_w := right_edge - open_r
	if right_w > 0.2:
		_slab(
			course,
			node_name + "R",
			Vector3(right_edge - right_w * 0.5, middle_y, z),
			Vector3(right_w, top - bottom, thickness),
			_ocean_rock
		)
	var low_h := open_b - bottom
	if low_h > 0.2:
		_slab(
			course,
			node_name + "B",
			Vector3((open_l + open_r) * 0.5, bottom + low_h * 0.5, z),
			Vector3(open_r - open_l, low_h, thickness),
			_ocean_rock
		)
	var high_h := top - open_t
	if high_h > 0.2:
		_slab(
			course,
			node_name + "T",
			Vector3((open_l + open_r) * 0.5, open_t + high_h * 0.5, z),
			Vector3(open_r - open_l, high_h, thickness),
			_ocean_rock
		)
	# Marco luminoso: el hueco se ve desde lejos.
	_mesh_box(
		course,
		node_name + "GlowL",
		Vector3(open_l, center_y, z),
		Vector3(0.16, opening_h, thickness + 0.12),
		_ocean_glow
	)
	_mesh_box(
		course,
		node_name + "GlowR",
		Vector3(open_r, center_y, z),
		Vector3(0.16, opening_h, thickness + 0.12),
		_ocean_glow
	)
	_mesh_box(
		course,
		node_name + "GlowB",
		Vector3(center_x, open_b, z),
		Vector3(opening_w, 0.16, thickness + 0.12),
		_ocean_glow
	)
	_mesh_box(
		course,
		node_name + "GlowT",
		Vector3(center_x, open_t, z),
		Vector3(opening_w, 0.16, thickness + 0.12),
		_ocean_glow
	)


func _build_ocean_chokes(course: Node3D) -> void:
	var gates := [
		{"z": -40.0, "x": 0.0, "y": -7.0, "w": 9.0, "h": 9.0},
		{"z": -56.0, "x": -2.0, "y": -11.0, "w": 10.0, "h": 9.0},
		{"z": -78.0, "x": -1.5, "y": -8.0, "w": 9.0, "h": 9.0},
		{"z": -97.0, "x": 2.0, "y": -10.0, "w": 12.0, "h": 10.0},
		{"z": -152.0, "x": -1.0, "y": -11.0, "w": 11.0, "h": 10.0},
		{"z": -172.0, "x": 2.0, "y": -11.0, "w": 10.0, "h": 9.0},
		{"z": -206.0, "x": 1.0, "y": -19.0, "w": 9.0, "h": 7.0},
		{"z": -222.0, "x": -2.0, "y": -9.0, "w": 10.0, "h": 9.0},
		{"z": -306.0, "x": 0.0, "y": -8.0, "w": 10.0, "h": 10.0},
		{"z": -348.0, "x": 0.0, "y": -10.0, "w": 12.0, "h": 9.0},
		{"z": -374.0, "x": 0.0, "y": -11.0, "w": 11.0, "h": 10.0},
		{"z": -388.0, "x": -1.0, "y": -13.0, "w": 11.0, "h": 10.0},
	]
	for i in gates.size():
		var gate: Dictionary = gates[i]
		_ocean_choke(
			course,
			"ReefGate%d" % i,
			float(gate["z"]),
			float(gate["x"]),
			float(gate["y"]),
			float(gate["w"]),
			float(gate["h"])
		)


## Corrientes ascendentes al final de cada tramo inundado. El agua termina en
## una pared (las islas y el cierre de la meta) a 24 m del fondo: sin este
## empujón hay que subir 20 m a ciegas y en la meta no se llega a la rampa.
func _build_ocean_lifts(course: Node3D) -> void:
	var lifts := [
		{"name": "Updraft1", "z": -106.0},
		{"name": "Updraft2", "z": -236.0},
		{"name": "Updraft3", "z": -388.5},
	]
	for entry in lifts:
		var lift := OCEAN_HAZARDS.Updraft.new()
		lift.set("lift", 10.0)
		lift.set("forward", 3.2)
		_ocean_hazard(course, String(entry["name"]), lift, Vector3(0.0, -11.5, float(entry["z"])))


func _ocean_hazard(
	course: Node3D, node_name: String, hazard: Node3D, position: Vector3, yaw: float = 0.0
) -> Node3D:
	hazard.name = node_name
	hazard.position = position
	hazard.rotation.y = yaw
	course.add_child(hazard)
	return hazard


## Coloca un obstáculo marino forzando cómo te toca: aturde y frena, empuja
## lejos o te devuelve al checkpoint. `push` es la fuerza del empujón.
func _ocean_hazard_kind(
	course: Node3D,
	node_name: String,
	hazard: Node3D,
	position: Vector3,
	kind: String,
	push: float = 0.0
) -> Node3D:
	hazard.set("touch_override", kind)
	if push > 0.0:
		hazard.set("push_override", push)
	if kind == "stun":
		hazard.set("stun_override", 1.0)
	return _ocean_hazard(course, node_name, hazard, position)


## Los quince tipos nuevos, repartidos por los tres tramos. Cada tramo tiene su
## propia mezcla para que no se repita el mismo patrón de obstáculos.
func _build_ocean_hazards(course: Node3D) -> void:
	# --- tramo 1: erizos, algas, medusas y corriente cruzada ---------------
	var lure_a := OCEAN_HAZARDS.AnglerLure.new()
	lure_a.set("swing", 2.6)
	_ocean_hazard(course, "AnglerLure1", lure_a, Vector3(2.0, -4.0, -18.0))

	var urchin_a := OCEAN_HAZARDS.Urchin.new()
	urchin_a.set("radius", 1.15)
	urchin_a.set("spin", 1.1)
	_ocean_hazard(course, "Urchin1", urchin_a, Vector3(-5.5, -19.0, -24.0))

	var kelp_a := OCEAN_HAZARDS.KelpWhip.new()
	kelp_a.set("height", 10.0)
	_ocean_hazard(course, "KelpWhip1", kelp_a, Vector3(8.0, -13.0, -32.0))

	var jelly_a := OCEAN_HAZARDS.Jellyfish.new()
	jelly_a.set("drift", 2.2)
	_ocean_hazard(course, "Jellyfish1", jelly_a, Vector3(0.0, -6.0, -40.0))

	var urchin_b := OCEAN_HAZARDS.Urchin.new()
	urchin_b.set("radius", 0.95)
	_ocean_hazard(course, "Urchin2", urchin_b, Vector3(6.0, -20.0, -46.0))

	var mine_a := OCEAN_HAZARDS.BubbleMine.new()
	_ocean_hazard(course, "BubbleMine1", mine_a, Vector3(-4.0, -13.0, -56.0))

	var current_a := OCEAN_HAZARDS.CurrentRibbon.new()
	current_a.set("force", 3.2)
	current_a.set("direction", Vector3.RIGHT)
	_ocean_hazard(course, "CurrentRibbon1", current_a, Vector3(0.0, -9.0, -62.0))

	var kelp_b := OCEAN_HAZARDS.KelpWhip.new()
	kelp_b.set("height", 12.0)
	kelp_b.set("sway", 1.3)
	_ocean_hazard(course, "KelpWhip2", kelp_b, Vector3(-8.5, -12.0, -68.0))

	var mine_b := OCEAN_HAZARDS.BubbleMine.new()
	mine_b.set("bob", 1.9)
	_ocean_hazard(course, "BubbleMine2", mine_b, Vector3(7.0, -7.0, -74.0))

	var puffer_a := OCEAN_HAZARDS.Pufferfish.new()
	_ocean_hazard(course, "Pufferfish1", puffer_a, Vector3(-3.0, -8.0, -78.0))

	var urchin_c := OCEAN_HAZARDS.Urchin.new()
	urchin_c.set("radius", 1.35)
	_ocean_hazard(course, "Urchin3", urchin_c, Vector3(-7.0, -18.0, -86.0))

	var jelly_b := OCEAN_HAZARDS.Jellyfish.new()
	jelly_b.set("bell_size", 0.9)
	jelly_b.set("drift", 1.4)
	_ocean_hazard(course, "Jellyfish2", jelly_b, Vector3(5.0, -9.0, -94.0))

	var star_a := OCEAN_HAZARDS.StarfishSpinner.new()
	_ocean_hazard(course, "Starfish1", star_a, Vector3(4.0, -11.0, -100.0))

	# --- tramo 2: remolino, almejas, abanicos, tinta y cadena de minas ----
	var lure_b := OCEAN_HAZARDS.AnglerLure.new()
	lure_b.set("swing", 3.1)
	_ocean_hazard(course, "AnglerLure2", lure_b, Vector3(6.0, -5.0, -140.0))

	var whirl_a := OCEAN_HAZARDS.Whirlpool.new()
	whirl_a.set("radius", 4.6)
	whirl_a.set("pull", 4.2)
	_ocean_hazard(course, "Whirlpool1", whirl_a, Vector3(-2.0, -11.0, -152.0))

	var clam_a := OCEAN_HAZARDS.ClamSnap.new()
	_ocean_hazard(course, "ClamSnap1", clam_a, Vector3(0.0, -20.6, -166.0))

	var mine_c := OCEAN_HAZARDS.BubbleMine.new()
	mine_c.set("radius", 1.15)
	_ocean_hazard(course, "BubbleMine3", mine_c, Vector3(5.0, -12.0, -172.0))

	var star_b := OCEAN_HAZARDS.StarfishSpinner.new()
	star_b.set("spin_speed", -2.4)
	_ocean_hazard(course, "Starfish2", star_b, Vector3(0.0, -14.0, -178.0))

	var fan_a := OCEAN_HAZARDS.CoralFan.new()
	fan_a.set("spin_speed", 1.9)
	_ocean_hazard(course, "CoralFan1", fan_a, Vector3(0.0, -9.0, -186.0))

	var mine_d := OCEAN_HAZARDS.BubbleMine.new()
	mine_d.set("bob", 2.2)
	_ocean_hazard(course, "BubbleMine4", mine_d, Vector3(-6.0, -5.0, -198.0))

	var clam_b := OCEAN_HAZARDS.ClamSnap.new()
	clam_b.set("period", 2.1)
	_ocean_hazard(course, "ClamSnap2", clam_b, Vector3(3.0, -20.6, -206.0))

	var jelly_c := OCEAN_HAZARDS.Jellyfish.new()
	jelly_c.set("drift", 2.4)
	_ocean_hazard(course, "Jellyfish3", jelly_c, Vector3(-7.0, -7.0, -214.0))

	var ink_a := OCEAN_HAZARDS.InkCloud.new()
	ink_a.set("radius", 2.8)
	_ocean_hazard(course, "InkCloud1", ink_a, Vector3(-4.0, -9.0, -222.0))

	var chain_a := OCEAN_HAZARDS.MineChain.new()
	chain_a.set("count", 7)
	chain_a.set("span", 14.0)
	_ocean_hazard(course, "MineChain1", chain_a, Vector3(0.0, -6.0, -232.0))

	# --- tramo 3: hielo, chorros térmicos, vórtice final -------------------
	var ice_a := OCEAN_HAZARDS.DriftIce.new()
	ice_a.set("travel", 8.5)
	_ocean_hazard(course, "DriftIce1", ice_a, Vector3(0.0, -7.0, -268.0))

	var vent_a := OCEAN_HAZARDS.ThermalVent.new()
	_ocean_hazard(course, "ThermalVent1", vent_a, Vector3(-6.0, -16.0, -284.0))

	var jelly_d := OCEAN_HAZARDS.Jellyfish.new()
	jelly_d.set("bell_size", 1.35)
	_ocean_hazard(course, "Jellyfish4", jelly_d, Vector3(5.0, -5.0, -292.0))

	var ice_b := OCEAN_HAZARDS.DriftIce.new()
	ice_b.set("travel", 7.0)
	ice_b.set("speed", 1.4)
	_ocean_hazard(course, "DriftIce2", ice_b, Vector3(0.0, -13.0, -300.0))

	var fan_b := OCEAN_HAZARDS.CoralFan.new()
	fan_b.set("spin_speed", -2.1)
	fan_b.set("blade_count", 5)
	_ocean_hazard(course, "CoralFan2", fan_b, Vector3(0.0, -8.0, -306.0))

	var jelly_e := OCEAN_HAZARDS.Jellyfish.new()
	_ocean_hazard(course, "Jellyfish5", jelly_e, Vector3(-4.0, -13.0, -316.0))

	var urchin_d := OCEAN_HAZARDS.Urchin.new()
	urchin_d.set("radius", 1.2)
	urchin_d.set("spin", -1.2)
	_ocean_hazard(course, "Urchin4", urchin_d, Vector3(7.0, -19.0, -326.0))

	var lure_c := OCEAN_HAZARDS.AnglerLure.new()
	lure_c.set("swing", 2.0)
	_ocean_hazard(course, "AnglerLure3", lure_c, Vector3(7.0, -4.0, -334.0))

	var urchin_e := OCEAN_HAZARDS.Urchin.new()
	urchin_e.set("radius", 0.9)
	_ocean_hazard(course, "Urchin5", urchin_e, Vector3(-8.0, -19.0, -340.0))

	var vent_b := OCEAN_HAZARDS.ThermalVent.new()
	vent_b.set("cycle", 2.8)
	_ocean_hazard(course, "ThermalVent2", vent_b, Vector3(6.0, -16.0, -344.0))

	var current_b := OCEAN_HAZARDS.CurrentRibbon.new()
	current_b.set("force", 4.0)
	current_b.set("direction", Vector3(0.0, 0.0, 1.0))
	_ocean_hazard(course, "CurrentRibbon2", current_b, Vector3(0.0, -10.0, -348.0))

	var ink_b := OCEAN_HAZARDS.InkCloud.new()
	ink_b.set("radius", 2.2)
	_ocean_hazard(course, "InkCloud2", ink_b, Vector3(3.0, -6.0, -352.0))

	var star_c := OCEAN_HAZARDS.StarfishSpinner.new()
	star_c.set("spin_speed", 2.6)
	_ocean_hazard(course, "Starfish3", star_c, Vector3(-2.0, -9.0, -360.0))

	var puffer_b := OCEAN_HAZARDS.Pufferfish.new()
	puffer_b.set("puff_speed", 1.7)
	_ocean_hazard(course, "Pufferfish2", puffer_b, Vector3(-6.0, -7.0, -368.0))

	var whirl_b := OCEAN_HAZARDS.Whirlpool.new()
	whirl_b.set("radius", 5.2)
	whirl_b.set("pull", 5.0)
	whirl_b.set("spin", 2.9)
	_ocean_hazard(course, "Whirlpool2", whirl_b, Vector3(0.0, -11.0, -374.0))

	var kelp_c := OCEAN_HAZARDS.KelpWhip.new()
	kelp_c.set("sway", 1.5)
	_ocean_hazard(course, "KelpWhip3", kelp_c, Vector3(8.0, -13.0, -384.0))

	var chain_b := OCEAN_HAZARDS.MineChain.new()
	chain_b.set("count", 5)
	chain_b.set("span", 11.0)
	_ocean_hazard(course, "MineChain2", chain_b, Vector3(-3.0, -14.0, -388.0))

	# --- refuerzos: más obstáculos para no dejar ningún claro --------------
	var extra_urchin := OCEAN_HAZARDS.Urchin.new()
	extra_urchin.set("radius", 1.0)
	_ocean_hazard(course, "Urchin6", extra_urchin, Vector3(0.0, -20.0, -30.0))

	var extra_jelly := OCEAN_HAZARDS.Jellyfish.new()
	_ocean_hazard(course, "Jellyfish6", extra_jelly, Vector3(0.0, -9.0, -64.0))

	var extra_mine := OCEAN_HAZARDS.BubbleMine.new()
	_ocean_hazard(course, "BubbleMine5", extra_mine, Vector3(0.0, -12.0, -90.0))

	var extra_star := OCEAN_HAZARDS.StarfishSpinner.new()
	_ocean_hazard(course, "Starfish4", extra_star, Vector3(-1.0, -10.0, -146.0))

	var extra_kelp := OCEAN_HAZARDS.KelpWhip.new()
	extra_kelp.set("sway", 1.2)
	_ocean_hazard(course, "KelpWhip4", extra_kelp, Vector3(2.0, -13.0, -160.0))

	var extra_chain := OCEAN_HAZARDS.MineChain.new()
	extra_chain.set("count", 6)
	extra_chain.set("span", 12.0)
	_ocean_hazard(course, "MineChain3", extra_chain, Vector3(0.0, -7.0, -184.0))

	var extra_puffer := OCEAN_HAZARDS.Pufferfish.new()
	_ocean_hazard(course, "Pufferfish3", extra_puffer, Vector3(0.0, -10.0, -218.0))

	var extra_urchin_b := OCEAN_HAZARDS.Urchin.new()
	extra_urchin_b.set("radius", 1.25)
	_ocean_hazard(course, "Urchin7", extra_urchin_b, Vector3(0.0, -20.0, -228.0))

	var extra_jelly_b := OCEAN_HAZARDS.Jellyfish.new()
	_ocean_hazard(course, "Jellyfish7", extra_jelly_b, Vector3(3.0, -9.0, -276.0))

	var extra_ice := OCEAN_HAZARDS.DriftIce.new()
	extra_ice.set("travel", 7.5)
	_ocean_hazard(course, "DriftIce3", extra_ice, Vector3(0.0, -9.0, -298.0))

	var extra_ink := OCEAN_HAZARDS.InkCloud.new()
	_ocean_hazard(course, "InkCloud3", extra_ink, Vector3(0.0, -8.0, -338.0))

	var extra_fan := OCEAN_HAZARDS.CoralFan.new()
	extra_fan.set("spin_speed", 2.3)
	_ocean_hazard(course, "CoralFan3", extra_fan, Vector3(0.0, -9.0, -364.0))

	var extra_urchin_c := OCEAN_HAZARDS.Urchin.new()
	extra_urchin_c.set("radius", 1.1)
	_ocean_hazard(course, "Urchin8", extra_urchin_c, Vector3(0.0, -20.0, -382.0))

	# --- compuertas ocupadas: no queda arcén por el que colarse ------------
	# Dos piezas dentro de la abertura de cada compuerta. Se pasa justo entre
	# ellas o comiéndoselas, y alternan aturdir, empujar lejos y matar.
	var gate_hazards := [
		{"z": -40.0, "x": 0.0, "y": -7.0, "kind": "stun"},
		{"z": -56.0, "x": -2.0, "y": -11.0, "kind": "push"},
		{"z": -78.0, "x": -1.5, "y": -8.0, "kind": "kill"},
		{"z": -97.0, "x": 2.0, "y": -10.0, "kind": "stun"},
		{"z": -152.0, "x": -1.0, "y": -11.0, "kind": "push"},
		{"z": -172.0, "x": 2.0, "y": -11.0, "kind": "kill"},
		{"z": -206.0, "x": 1.0, "y": -19.0, "kind": "stun"},
		{"z": -222.0, "x": -2.0, "y": -9.0, "kind": "push"},
		{"z": -306.0, "x": 0.0, "y": -8.0, "kind": "stun"},
		{"z": -348.0, "x": 0.0, "y": -10.0, "kind": "push"},
		{"z": -374.0, "x": 0.0, "y": -11.0, "kind": "kill"},
		{"z": -388.0, "x": -1.0, "y": -13.0, "kind": "stun"},
	]
	for i in gate_hazards.size():
		var gate: Dictionary = gate_hazards[i]
		var gate_x: float = gate["x"]
		var gate_z: float = gate["z"]
		var gate_y: float = gate["y"]
		var kind: String = gate["kind"]
		var left := OCEAN_HAZARDS.Urchin.new()
		left.set("radius", 1.2)
		left.set("spin", 0.8 + float(i % 3) * 0.2)
		_ocean_hazard_kind(
			course,
			"GateUrchin%d" % i,
			left,
			Vector3(gate_x - 2.1, gate_y, gate_z),
			"stun" if kind == "push" else kind
		)
		var right := OCEAN_HAZARDS.Jellyfish.new()
		right.set("bell_size", 1.2)
		right.set("drift", 0.5)
		_ocean_hazard_kind(
			course,
			"GateJelly%d" % i,
			right,
			Vector3(gate_x + 2.1, gate_y, gate_z + 0.7),
			kind,
			24.0 if kind == "push" else 0.0
		)
		# Rápidos: el aro de burbujas espera detrás del hueco. Cruzarlo lanza
		# al corredor hacia el tramo siguiente; no golpea, así que quien
		# prefiera ir con calma solo tiene que bordearlo.
		if gate_z - 5.5 > -390.0:
			var boost := OCEAN_HAZARDS.BoostRing.new()
			boost.set("radius", 2.8)
			boost.set("boost", 12.0)
			_ocean_hazard(course, "BoostRing%d" % i, boost, Vector3(gate_x, gate_y, gate_z - 5.5))

	# --- zigzag obligatorio: ni una recta limpia en todo el túnel ----------
	# Un obstáculo a cada lado, alternando cada pocos metros: hay que cruzar el
	# túnel de lado a lado y pasar por su lado sí o sí.
	var weave_kinds := ["stun", "push", "kill"]
	var weave_index := 0
	for step in 10:
		for offset in [0.0, -9.5]:
			var z: float = -14.0 - float(step) * 38.0 + float(offset)
			var near_island := false
			for island in O_ISLANDS:
				if absf(z - float(island["z"])) < float(island["length"]) * 0.5 + 4.0:
					near_island = true
			if near_island:
				continue
			var side := -1.0 if weave_index % 2 == 0 else 1.0
			var kind: String = weave_kinds[weave_index % 3]
			var roll := weave_index % 3
			var hazard: Node3D
			if roll == 0:
				var urchin := OCEAN_HAZARDS.Urchin.new()
				urchin.set("radius", 1.0 + float(weave_index % 3) * 0.15)
				urchin.set("spin", 0.9)
				hazard = urchin
			elif roll == 1:
				var star := OCEAN_HAZARDS.StarfishSpinner.new()
				star.set("spin_speed", 2.2 if side > 0.0 else -2.2)
				hazard = star
			else:
				var mine := OCEAN_HAZARDS.BubbleMine.new()
				mine.set("bob", 1.1)
				hazard = mine
			_ocean_hazard_kind(
				course,
				"WeaveHazard%d" % weave_index,
				hazard,
				Vector3(side * 4.8, -9.5, z),
				kind,
				26.0 if kind == "push" else 0.0
			)
			weave_index += 1

	# Checkpoints: los secos, sobre las islas; los otros, dentro del agua.
	_add_checkpoint(course, "CP1", Vector3(0.0, 2.0, -1.0))
	_add_checkpoint(course, "CP2", Vector3(0.0, 0.4, -117.0))
	_add_checkpoint(course, "CP3", Vector3(0.0, -6.0, -194.0))
	_add_checkpoint(course, "CP4", Vector3(0.0, 0.4, -247.0))
	_add_checkpoint(course, "CP5", Vector3(0.0, -8.0, -330.0))
	_add_checkpoint(course, "CP6", Vector3(0.0, 1.0, -396.0))


# --------------------------------------------------- decoración del abismo


func _ocean_rock_boulder(
	parent: Node3D, node_name: String, position: Vector3, radius: float
) -> void:
	var rock := _mesh_sphere(parent, node_name, position, radius, _ocean_rock_dark)
	rock.scale = Vector3(1.0, 0.62, 1.0)


## Racimo de coral: cinco ramas con punta luminosa. El `variant` cambia altura,
## inclinación y color para que no haya dos racimos iguales.
func _ocean_coral_cluster(
	parent: Node3D, node_name: String, position: Vector3, scale_value: float, variant: int
) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.rotation.y = float(variant) * 0.8
	parent.add_child(root)
	var branch_material: Material = _ocean_coral if variant % 2 == 0 else _ocean_coral_alt
	for i in 5:
		var height := (1.2 + float((i * 3 + variant) % 5) * 0.42) * scale_value
		var angle := float(i) * 1.7 + float(variant)
		var offset := Vector3(cos(angle) * 0.55, 0.0, sin(angle) * 0.55) * scale_value
		var branch := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.06 * scale_value
		mesh.bottom_radius = 0.2 * scale_value
		mesh.height = height
		mesh.radial_segments = 6
		branch.mesh = mesh
		branch.material_override = branch_material
		branch.position = offset + Vector3.UP * height * 0.5
		branch.rotation = Vector3(cos(angle) * 0.22, 0.0, sin(angle) * 0.22)
		branch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(branch)
		_mesh_sphere(
			root,
			"%sTip%d" % [node_name, i],
			offset + Vector3.UP * height,
			0.16 * scale_value,
			_ocean_glow
		)


func _ocean_anemone(
	parent: Node3D, node_name: String, position: Vector3, scale_value: float
) -> void:
	_mesh_sphere(parent, node_name + "Base", position, 0.55 * scale_value, _ocean_coral)
	for i in 12:
		var angle := float(i) * TAU / 12.0
		var lean := Vector3(cos(angle) * 0.45, 1.0, sin(angle) * 0.45).normalized()
		var tentacle := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.02 * scale_value
		mesh.bottom_radius = 0.08 * scale_value
		mesh.height = 1.1 * scale_value
		mesh.radial_segments = 5
		tentacle.mesh = mesh
		tentacle.material_override = _ocean_glow
		tentacle.position = position + lean * 0.55 * scale_value
		tentacle.quaternion = Quaternion(Vector3.UP, lean)
		tentacle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(tentacle)


func _ocean_kelp(parent: Node3D, node_name: String, position: Vector3, height: float) -> void:
	var stalk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.09
	mesh.bottom_radius = 0.2
	mesh.height = height
	mesh.radial_segments = 6
	stalk.mesh = mesh
	stalk.material_override = OceanStyle.matte(OceanStyle.ALGAE, 0.85)
	stalk.position = position + Vector3.UP * height * 0.5
	stalk.rotation.z = sin(position.z) * 0.08
	stalk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(stalk)
	for i in 4:
		var leaf := _mesh_box(
			parent,
			"%sLeaf%d" % [node_name, i],
			position + Vector3.UP * height * (0.3 + float(i) * 0.18),
			Vector3(0.9, 0.08, 0.3),
			OceanStyle.matte(OceanStyle.ALGAE, 0.8),
			Vector3(0.0, float(i) * 42.0, 18.0)
		)
		leaf.scale = Vector3(0.8 + float(i) * 0.12, 1.0, 1.0)


func _ocean_light_shaft(
	parent: Node3D, node_name: String, position: Vector3, width: float, length: float
) -> void:
	_mesh_box(
		parent,
		node_name,
		position,
		Vector3(width, length, 0.35),
		_ocean_ray,
		Vector3(0.0, 0.0, 16.0)
	)


func _ocean_fish_school(parent: Node3D, center: Vector3, amount: int) -> void:
	var fish_mesh := SphereMesh.new()
	fish_mesh.radius = 0.18
	fish_mesh.height = 0.26
	fish_mesh.radial_segments = 6
	fish_mesh.rings = 3
	fish_mesh.material = OceanStyle.matte(Color(0.55, 0.85, 0.95), 0.5)
	var school := CPUParticles3D.new()
	school.name = "FishSchool"
	school.amount = amount
	school.lifetime = 20.0
	school.preprocess = 10.0
	school.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	school.emission_box_extents = Vector3(10.0, 4.0, 18.0)
	school.position = center
	school.direction = Vector3(0.0, 0.0, -1.0)
	school.spread = 25.0
	school.gravity = Vector3.ZERO
	school.initial_velocity_min = 0.6
	school.initial_velocity_max = 1.8
	school.scale_amount_min = 0.5
	school.scale_amount_max = 1.3
	school.color = Color(0.6, 0.92, 1.0, 0.9)
	school.mesh = fish_mesh
	school.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(school)


func _ocean_plankton(parent: Node3D) -> void:
	var mote := SphereMesh.new()
	mote.radius = 0.035
	mote.height = 0.07
	mote.radial_segments = 6
	mote.rings = 3
	mote.material = OceanStyle.glow(OceanStyle.GLOW, 2.0)
	var plankton := CPUParticles3D.new()
	plankton.name = "Plankton"
	plankton.amount = 480
	plankton.lifetime = 16.0
	plankton.preprocess = 8.0
	plankton.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	plankton.emission_box_extents = Vector3(11.0, 12.0, 200.0)
	plankton.position = Vector3(0.0, -10.0, -200.0)
	plankton.direction = Vector3(0.0, 0.15, 0.0)
	plankton.spread = 40.0
	plankton.gravity = Vector3(0.0, 0.05, 0.0)
	plankton.initial_velocity_min = 0.05
	plankton.initial_velocity_max = 0.35
	plankton.scale_amount_min = 0.5
	plankton.scale_amount_max = 1.4
	plankton.color = Color(0.6, 1.0, 0.95, 0.75)
	plankton.mesh = mote
	plankton.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(plankton)


func _build_ocean_decor(course: Node3D) -> void:
	for i in 34:
		var z := -14.0 - float(i) * 11.5
		var side := -1.0 if i % 2 == 0 else 1.0
		_ocean_coral_cluster(
			course,
			"Coral%d" % i,
			Vector3(side * (9.6 + float(i % 3) * 0.8), O_FLOOR_Y + 0.1, z),
			0.9 + float(i % 4) * 0.22,
			i
		)
		if i % 3 == 0:
			_ocean_anemone(
				course,
				"Anemone%d" % i,
				Vector3(-side * 8.0, O_FLOOR_Y + 0.15, z - 3.5),
				0.9 + float(i % 2) * 0.3
			)
		if i % 2 == 0:
			_ocean_kelp(
				course,
				"KelpDecor%d" % i,
				Vector3(-side * 10.6, O_FLOOR_Y + 0.2, z + 4.0),
				7.0 + float(i % 4) * 1.6
			)
		if i % 5 == 0:
			_ocean_light_shaft(
				course, "Ray%d" % i, Vector3(float((i % 3) - 1) * 6.0, -8.0, z), 6.0, 30.0
			)
	_ocean_plankton(course)

	# --- tercera pasada de detalle: siempre en el suelo o en las paredes ----
	# Nada de esto entra en la trazada: piedras y anémonas en el fondo, percebes
	# en la roca y haces de luz que salen de arriba.
	for i in 22:
		var z := -10.0 - float(i) * 18.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_ocean_rock_boulder(
			course,
			"FloorPebble%d" % i,
			Vector3(side * (6.4 + float(i % 3) * 2.2), O_FLOOR_Y + 0.1, z),
			0.5 + float(i % 3) * 0.22
		)
		_ocean_anemone(
			course,
			"FloorAnemone%d" % i,
			Vector3(-side * (10.2 + float(i % 2) * 0.7), O_FLOOR_Y + 0.15, z + 6.0),
			0.8 + float(i % 3) * 0.2
		)
	for i in 14:
		var z := -16.0 - float(i) * 27.0
		var side := -1.0 if i % 2 == 0 else 1.0
		# Pegados a la cara interior del muro (que ahora está en ±12), no dentro
		# de él, para que se sigan viendo.
		_mesh_box(
			course,
			"WallBarnacle%d" % i,
			Vector3(side * (O_HALF_WIDTH - 0.12), -4.0 - float(i % 4) * 2.4, z),
			Vector3(0.55, 1.7, 2.6),
			_ocean_sand,
			Vector3(0.0, 0.0, side * 8.0)
		)
	for i in 12:
		var z := -22.0 - float(i) * 32.0
		_ocean_light_shaft(
			course, "RayB%d" % i, Vector3(float((i % 5) - 2) * 3.4, -6.0, z), 7.0, 34.0
		)
	for i in 10:
		var z := -30.0 - float(i) * 36.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_mesh_cylinder(
			course,
			"WallCoralFan%d" % i,
			Vector3(side * (O_HALF_WIDTH - 0.3), -7.0 - float(i % 3) * 3.0, z),
			1.4,
			1.4,
			0.35,
			_ocean_coral,
			Vector3(0.0, 0.0, side * 90.0),
			8
		)


## Paisaje fuera del túnel: agujas de roca, restos de un naufragio, ballena y
## bancos de peces. Se ve por encima de las paredes y no estorba al corredor.
func _build_ocean_scenery(course: Node3D) -> void:
	for i in 16:
		var z := -14.0 - float(i) * 27.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_mesh_cylinder(
			course,
			"Spire%d" % i,
			Vector3(side * (26.0 + float(i % 3) * 6.0), -8.0 + float(i % 4) * 2.0, z),
			1.1,
			6.0 + float(i % 3) * 2.4,
			32.0 + float(i % 4) * 7.0,
			_ocean_rock_dark
		)

	# Pecio: casco, mástil y columnas caídas cerca de las islas.
	_mesh_box(
		course,
		"WreckHull",
		Vector3(-24.0, 0.5, -168.0),
		Vector3(16.0, 3.0, 6.0),
		_ocean_rock_dark,
		Vector3(0.0, 24.0, 8.0)
	)
	_mesh_cylinder(
		course,
		"WreckMast",
		Vector3(-24.0, 5.0, -168.0),
		0.2,
		0.45,
		12.0,
		_ocean_rock_dark,
		Vector3(0.0, 0.0, 18.0)
	)
	for i in 4:
		_mesh_cylinder(
			course,
			"Ruin%d" % i,
			Vector3(23.0, -2.0, -96.0 - float(i) * 6.0),
			0.9,
			1.4,
			7.0 + float(i % 2) * 3.0,
			_ocean_sand,
			Vector3(0.0, 0.0, 6.0 + float(i) * 4.0)
		)

	# Ballena de fondo.
	var whale := _mesh_sphere(
		course,
		"WhaleBody",
		Vector3(42.0, 18.0, -196.0),
		6.0,
		OceanStyle.matte(OceanStyle.ROCK_DARK, 1.0)
	)
	whale.scale = Vector3(2.8, 0.9, 1.1)
	_mesh_box(
		course,
		"WhaleTail",
		Vector3(42.0, 18.0, -184.0),
		Vector3(6.0, 0.6, 5.0),
		OceanStyle.matte(OceanStyle.ROCK_DARK, 1.0),
		Vector3(18.0, 0.0, 0.0)
	)

	_ocean_fish_school(course, Vector3(-22.0, 6.0, -150.0), 90)
	_ocean_fish_school(course, Vector3(24.0, 4.0, -300.0), 70)


## Punto de entrada del kit: el builder llama aquí sin saber de qué tema se trata.
func build() -> void:
	_build_ocean()
