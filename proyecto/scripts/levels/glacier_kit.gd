extends "res://scripts/levels/level_kit.gd"

## Glacier Gallop (ronda 3): hielo, saltos, placas frágiles y vendavales.

const ICE_ARENA_DRESSING := preload("res://scripts/ice_arena_dressing.gd")

const ICE_RAMPART_SCRIPT := preload("res://scripts/ice_rampart.gd")

const ICE_CREVASSE_SCRIPT := preload("res://scripts/ice_crevasse.gd")

## Huellas de las plataformas del glaciar: centro x, media anchura, centro z
## y media longitud. El atrezo de alrededor consulta esta lista para no plantar
## torres, géiseres ni montículos sobre la pista.
const ICE_SLABS := [
	Vector4(0.0, 9.0, -14.75, 28.75),
	Vector4(0.0, 6.0, -57.5, 6.5),
	Vector4(0.0, 6.0, -80.0, 5.5),
	Vector4(0.0, 12.0, -111.0, 30.0),
	Vector4(0.0, 6.0, -156.0, 13.0),
	Vector4(0.0, 6.0, -214.5, 6.0),
	Vector4(-5.0, 3.0, -234.0, 6.0),
	Vector4(5.0, 3.0, -243.0, 6.0),
	Vector4(0.0, 6.0, -256.0, 6.5),
	Vector4(0.0, 5.5, -272.5, 10.0),
	Vector4(0.0, 6.5, -305.0, 15.0),
	Vector4(0.0, 5.0, -330.0, 10.0),
	Vector4(0.0, 8.0, -355.0, 8.0),
]

var _ice: ShaderMaterial

var _ice_alt: ShaderMaterial

var _ice_dark: ShaderMaterial

var _ice_white: ShaderMaterial

var _ice_glow: StandardMaterial3D

var _ice_spike: StandardMaterial3D

var _ice_rock: StandardMaterial3D


func _make_ice_palette() -> void:
	# Paleta de amanecer ártico: azules desaturados, verdín suave y un sol
	# cálido. La versión anterior era cian eléctrico con bloom y cansaba la
	# vista en cuanto se encadenaban varias curvas.
	_ice = _platform_mat(
		Color(0.19, 0.33, 0.4), Color(0.72, 0.88, 0.9), Color(0.06, 0.12, 0.16), 0.12
	)
	_ice_alt = _platform_mat(
		Color(0.27, 0.43, 0.5), Color(0.85, 0.95, 0.95), Color(0.08, 0.15, 0.19), 0.1
	)
	_ice_dark = _platform_mat(
		Color(0.12, 0.22, 0.29), Color(0.5, 0.7, 0.75), Color(0.03, 0.07, 0.1), 0.1
	)
	_ice_white = _platform_mat(
		Color(0.55, 0.67, 0.7), Color(0.9, 0.96, 0.95), Color(0.25, 0.35, 0.4), 0.05
	)
	_ice_glow = _glow_mat(Color(0.58, 0.8, 0.82), 0.7, 0.5)
	# Pinchos de hielo: blancos y poco emisivos, para que no sean el único
	# dorado de un mapa azul (era lo que más cantaba del circuito).
	_ice_spike = _glow_mat(Color(0.74, 0.9, 0.95), 0.3, 0.24)
	_ice_rock = _rock_mat(Color(0.2, 0.3, 0.36), Color(0.06, 0.14, 0.18), 0.1)


## Pared de hielo con colisión: cierra una arena para que los obstáculos se
## crucen por el centro en vez de rodearlos por los bordes de la plataforma.
func _ice_wall(parent: Node3D, node_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	return _slab(parent, node_name, center, size, _ice_dark)


func _snow_particles(parent: Node3D, center: Vector3) -> void:
	var flake_mesh := SphereMesh.new()
	flake_mesh.radius = 0.045
	flake_mesh.height = 0.09
	flake_mesh.radial_segments = 6
	flake_mesh.rings = 3
	var flake_material := StandardMaterial3D.new()
	flake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_material.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
	flake_mesh.material = flake_material
	var snow := CPUParticles3D.new()
	snow.name = "Snowfall"
	# Nieve fina y constante en todo el recorrido. La caja es pequeña porque el
	# emisor viaja con la cámara (snowfall.gd): así nieva igual en la salida, en
	# la subida y en la meta, en vez de quedar solo donde está el nodo.
	snow.set_script(load("res://scripts/snowfall.gd"))
	snow.local_coords = false
	snow.position = center + Vector3(0.0, 24.0, 0.0)
	snow.amount = 2024
	snow.lifetime = 18.0
	snow.preprocess = 8.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(50.0, 28.0, 70.0)
	snow.direction = Vector3(0.22, -1.0, 0.08)
	snow.spread = 14.0
	snow.gravity = Vector3(0.0, -0.9, 0.0)
	snow.initial_velocity_min = 0.4
	snow.initial_velocity_max = 1.5
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.25
	snow.color = Color(1.0, 1.0, 1.0, 0.7)
	snow.mesh = flake_mesh
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(snow)


## Niebla de nieve a ras de suelo: copos grandes, lentos y translúcidos.
func _ice_mist(parent: Node3D, center: Vector3, amount: int) -> void:
	var mote := SphereMesh.new()
	mote.radius = 0.09
	mote.height = 0.18
	mote.radial_segments = 6
	mote.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.93, 1.0, 0.16)
	mote.material = material
	var mist := CPUParticles3D.new()
	mist.name = "IceMist"
	mist.amount = amount
	mist.lifetime = 26.0
	mist.preprocess = 12.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(55.0, 3.0, 105.0)
	mist.position = center
	mist.direction = Vector3(0.3, 0.1, 0.0)
	mist.spread = 40.0
	mist.gravity = Vector3(0.0, 0.02, 0.0)
	mist.initial_velocity_min = 0.2
	mist.initial_velocity_max = 1.0
	mist.scale_amount_min = 1.0
	mist.scale_amount_max = 3.2
	mist.color = Color(0.9, 0.96, 1.0, 0.3)
	mist.mesh = mote
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mist)


## Estrellas fijas en lo alto: cierran la noche polar.
func _ice_stars(parent: Node3D, center: Vector3) -> void:
	var star := SphereMesh.new()
	star.radius = 0.3
	star.height = 0.6
	star.radial_segments = 4
	star.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.97, 1.0, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.75, 0.85, 1.0)
	material.emission_energy_multiplier = 1.4
	star.material = material
	var sky := CPUParticles3D.new()
	sky.name = "Stars"
	sky.amount = 220
	sky.lifetime = 400.0
	sky.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sky.emission_box_extents = Vector3(360.0, 60.0, 420.0)
	sky.position = center
	sky.direction = Vector3.UP
	sky.spread = 180.0
	sky.gravity = Vector3.ZERO
	sky.initial_velocity_min = 0.0
	sky.initial_velocity_max = 0.0
	sky.scale_amount_min = 0.4
	sky.scale_amount_max = 1.4
	sky.color = Color(1, 1, 1, 1)
	sky.mesh = star
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sky)


# --------------------------------------------------------- ronda 3: glaciar


## ¿Cabe el atrezo aquí? Falso si un adorno de radio `radius` caería sobre (o
## pegado a) una plataforma y quedaría dentro de la vista del corredor.
func _ice_clear(x: float, z: float, radius: float) -> bool:
	for i in ICE_SLABS.size():
		var slab: Vector4 = ICE_SLABS[i]
		if absf(x - slab.x) <= slab.y + radius + 0.6 and absf(z - slab.z) <= slab.w + radius + 0.6:
			return false
	return true


func _build_glacier() -> void:
	_path.clear()
	_widths.clear()
	_make_ice_palette()
	var cfg := {
		"sky_top": Color(0.06, 0.15, 0.27),
		"sky_horizon": Color(0.79, 0.84, 0.86),
		"sky_ground": Color(0.12, 0.22, 0.29),
		"cloud_color": Color(0.95, 0.96, 0.94),
		"sun_color": Color(1.0, 0.95, 0.86),
		"ambient": Color(0.55, 0.68, 0.74),
		"ambient_energy": 0.65,
		"fog": Color(0.65, 0.76, 0.8),
		"fog_density": 0.0015,
		"exposure": 1.0,
		"saturation": 1.0,
		"sun_pitch": -32.0,
		"sun_yaw": 34.0,
		"sun_energy": 1.0,
		"fill": Color(0.35, 0.55, 0.65),
		"fill_energy": 0.35,
		"cloud_opacity": 0.48,
		"cloud_scale": 2.6,
		"dome_z": -130.0,
	}
	_add_environment(cfg)
	_add_lights(cfg)
	_add_sky(cfg)

	var course := Node3D.new()
	course.name = "Course"
	host.add_child(course)

	# --- primera mitad: hielo, barridos y arena giratoria ------------------
	# Plataforma de salida profunda: la parrilla de la ronda 3 puede traer
	# nueve bots y las últimas filas no deben nacer fuera del hielo.
	# Una sola pieza desde la salida hasta la rampa (z=14 a z=-43,5). Al no
	# existir una segunda plataforma, no puede quedar metida dentro de la primera.
	_slab_top(course, "StartPlatform", 0.0, -14.75, 18.0, 57.5, 0.0, _ice)
	_path_add(Vector3(0.0, 0.0, 7.0), Vector3(0.0, 0.0, -6.0), 3.4)
	_path_add(Vector3(0.0, 0.0, -7.0), Vector3(0.0, 0.0, -24.5), 2.2)

	# Arena de los barridos: las paredes van sobre la plataforma de salida, así
	# que no hay una segunda losa que se solape con ella.

	_ice_wall(course, "ArenaWallL", Vector3(-8.425, 1.5, -34.013), Vector3(1.2, 3.0, 19.0))
	_ice_wall(course, "ArenaWallR", Vector3(8.365, 1.5, -34.0), Vector3(1.2, 3.0, 19.0))
	_path_add(Vector3(0.0, 0.0, -25.0), Vector3(0.0, 0.0, -43.0), 3.2)

	_ramp_z(course, "ClimbA", 0.0, -43.0, -51.0, 0.0, 3.0, 10.0, _ice_alt)
	_path_add(Vector3(0.0, 0.0, -43.0), Vector3(0.0, 3.0, -51.0), 2.6)

	_slab_top(course, "TerraceA", 0.0, -57.5, 12.0, 13.0, 3.0, _ice)
	_path_add(Vector3(0.0, 3.0, -51.5), Vector3(0.0, 3.0, -63.5), 2.6)

	var ice_lift := _obstacle(
		course,
		"IceLift",
		MOVING_SCENE,
		Vector3(0.0, 2.8, -66.0),
		{
			"travel": Vector3(0.0, 0.0, -6.5),
			"speed": 2.6,
			"pause_time": 0.4,
		}
	)
	ice_lift.scale = Vector3(2.0, 1.0, 1.0)
	# Sin morado ni cian: la plataforma es de hielo, como el resto del circuito.
	# Material propio (no el shader de placas) porque la rejilla de ese shader va
	# anclada al mundo y vibraría al moverse la plataforma.
	var lift_material := StandardMaterial3D.new()
	lift_material.albedo_color = Color(0.62, 0.77, 0.82)
	lift_material.roughness = 0.5
	lift_material.metallic = 0.1
	for piece in ice_lift.find_children("*", "MeshInstance3D", true, false):
		(piece as MeshInstance3D).material_override = lift_material
	_path_add(Vector3(0.0, 3.0, -64.0), Vector3(0.0, 3.0, -74.5), 2.8)

	_slab_top(course, "MovingLanding", 0.0, -80.0, 12.0, 11.0, 3.0, _ice_alt)
	_path_add(Vector3(0.0, 3.0, -75.0), Vector3(0.0, 3.0, -84.8), 2.6)

	# Arena giratoria (checkpoint 4): el doble de larga (60 m), cerrada y con el
	# suelo partido en dieciocho discos que giran. Se entra y se sale por el centro.
	# Arena de 24 m: exactamente 3 discos nativos de 8 m, de pared a pared.
	_slab_top(course, "SpinArena", 0.0, -111.0, 24.0, 60.0, 3.0, _ice)
	_ice_wall(course, "SpinWallL", Vector3(-12.4, 4.3, -111.0), Vector3(0.8, 2.8, 60.0))
	_ice_wall(course, "SpinWallR", Vector3(12.4, 4.3, -111.0), Vector3(0.8, 2.8, 60.0))
	_ice_wall(course, "SpinGateN_L", Vector3(-7.75, 4.3, -81.0), Vector3(8.5, 2.8, 0.8))
	_ice_wall(course, "SpinGateN_R", Vector3(7.75, 4.3, -81.0), Vector3(8.5, 2.8, 0.8))
	# La salida es la rampa interior: sin muro sur, que cortaría la subida.
	_path_add(Vector3(0.0, 3.0, -85.0), Vector3(0.0, 3.0, -136.0), 3.4)

	_ramp_z(course, "ClimbB", 0.0, -136.0, -144.0, 3.0, 7.0, 10.0, _ice_alt)
	_path_add(Vector3(0.0, 3.0, -136.0), Vector3(0.0, 7.0, -144.0), 2.6)

	# --- galería de pistones y puente de placas frágiles -------------------
	_slab_top(course, "IceGallery", 0.0, -156.0, 12.0, 26.0, 7.0, _ice)
	_path_add(Vector3(0.0, 7.0, -144.0), Vector3(0.0, 7.0, -167.0), 2.8)

	# Puente del doble de largo (catorce filas), con placas que se hunden medio
	# segundo después de pisarlas y algunos huecos en los lados.
	var holes := {
		"3_0": true,
		"4_2": true,
		"6_0": true,
		"8_2": true,
		"10_0": true,
		"11_2": true,
		"13_0": true,
	}
	var tile_materials := [_ice, _ice_alt, _ice_white]
	for row in 14:
		for col in 3:
			if holes.has("%d_%d" % [row, col]):
				continue
			_obstacle(
				course,
				"Crumble%d_%d" % [row, col],
				CRUMBLE_SCENE,
				Vector3(-3.4 + float(col) * 3.4, 7.0, -168.0 - float(row) * 3.0),
				{
					"tile_material": tile_materials[(row + col) % tile_materials.size()],
					"warn_time": 0.5
				}
			)
	_path_add(Vector3(0.0, 7.0, -167.0), Vector3(0.0, 7.0, -208.0), 3.2)

	_slab_top(course, "GalleryLanding", 0.0, -214.5, 12.0, 12.0, 7.0, _ice_alt)
	_path_add(Vector3(0.0, 7.0, -208.5), Vector3(0.0, 7.0, -220.0), 2.6)

	_ramp_z(course, "ClimbC", 0.0, -220.0, -228.0, 7.0, 11.0, 10.0, _ice)
	_path_add(Vector3(0.0, 7.0, -220.0), Vector3(0.0, 11.0, -228.0), 2.6)

	# --- puente del vendaval ----------------------------------------------
	# Dos repisas pegadas a los extremos (una a la izquierda y otra a la
	# derecha) en lugar de una pasarela central: se cruza en diagonal contra el
	# viento y el centro es aire puro.
	_slab_top(course, "GaleLedgeL", -5.0, -234.0, 6.0, 12.0, 11.0, _ice_dark)
	_slab_top(course, "GaleLedgeR", 5.0, -243.0, 6.0, 12.0, 11.0, _ice_dark)
	_path_add(Vector3(0.0, 11.0, -228.0), Vector3(-5.0, 11.0, -230.5), 1.6)
	_path_add(Vector3(-5.0, 11.0, -230.5), Vector3(-5.0, 11.0, -236.5), 1.6)
	_path_add(Vector3(-5.0, 11.0, -236.5), Vector3(5.0, 11.0, -239.5), 1.6)
	_path_add(Vector3(5.0, 11.0, -239.5), Vector3(5.0, 11.0, -246.0), 1.6)
	_path_add(Vector3(5.0, 11.0, -246.0), Vector3(0.0, 11.0, -249.5), 1.6)

	_slab_top(course, "GaleLanding", 0.0, -256.0, 12.0, 13.0, 11.0, _ice)
	_path_add(Vector3(0.0, 11.0, -249.5), Vector3(0.0, 11.0, -262.0), 2.8)

	# --- pasillo de rocas -------------------------------------------------
	_slab_top(course, "BoulderDeck", 0.0, -272.5, 11.0, 20.0, 11.0, _ice_alt)
	_path_add(Vector3(0.0, 11.0, -262.0), Vector3(0.0, 11.0, -281.5), 2.6)

	_ramp_z(course, "DropA", 0.0, -281.5, -289.5, 11.0, 7.0, 10.0, _ice)
	_path_add(Vector3(0.0, 11.0, -281.5), Vector3(0.0, 7.0, -289.5), 2.6)

	# --- terraza de pinchos y recta final ---------------------------------
	_slab_top(course, "SpikeTerrace", 0.0, -305.0, 13.0, 30.0, 7.0, _ice_alt)
	_path_add(Vector3(0.0, 7.0, -289.5), Vector3(0.0, 7.0, -319.5), 3.2)

	# La recta final se parte en dos losas para que la grieta tenga un hueco de
	# verdad: antes el suelo sólido seguía debajo, sus tres placas quedaban
	# enterradas en la losa y no se veían subir ni bajar.
	_slab_top(course, "FinalRunN", 0.0, -326.05, 10.0, 12.3, 7.0, _ice)
	_slab_top(course, "FinalRunS", 0.0, -337.9, 10.0, 4.2, 7.0, _ice)
	# El cierre del glaciar vuelve a ser un muro de témpanos, así que la recta
	# final lleva el suelo entero: sin hueco no hay nada bajo el hielo.
	_slab_top(course, "FinalRunGap", 0.0, -334.0, 10.0, 3.6, 7.0, _ice)
	_path_add(Vector3(0.0, 7.0, -319.5), Vector3(0.0, 7.0, -339.5), 2.8)

	_ramp_z(course, "ClimbD", 0.0, -339.5, -346.5, 7.0, 10.0, 10.0, _ice_alt)
	_path_add(Vector3(0.0, 7.0, -339.5), Vector3(0.0, 10.0, -346.5), 2.8)

	_slab_top(course, "SummitPlatform", 0.0, -355.0, 16.0, 16.0, 10.0, _ice)
	_path_add(Vector3(0.0, 10.0, -346.5), Vector3(0.0, 10.0, -358.0), 3.4)

	# --- obstáculos -------------------------------------------------------
	# Los brazos se alargan hasta las paredes del arena: el pasillo mide 15,6 m
	# de ancho y la barra de fábrica no llega a los extremos.
	_obstacle(
		course,
		"SweeperA",
		SWEEPER_SCENE,
		Vector3(0.0, 0.35, -30.0),
		{
			"spin_speed": 2.1,
			"push_force": 6.4,
			"stuns": true,
			"arm_length": 15.9,
		}
	)
	_obstacle(
		course,
		"SweeperB",
		SWEEPER_SCENE,
		Vector3(0.0, 0.35, -38.0),
		{
			"spin_speed": 2.5,
			"spin_direction": -1.0,
			"push_force": 6.8,
			"stuns": true,
			"arm_length": 15.9,
		}
	)
	# Teclado de calculadora: 3 discos por fila y 6 filas, todos del tamaño
	# nativo (8 m) y tocándose de borde a borde. 3 x 8 = 24 m de ancho total.
	var disc_pitch := 8.0
	var spin_row_z := [-88.0, -96.0, -104.0, -112.0, -120.0, -128.0]
	var ball_color := Color(0.8, 0.2, 0.26)
	var disc_index := 0
	for r in spin_row_z.size():
		var z: float = spin_row_z[r]
		for c in 3:
			var x := (float(c) - 1.0) * disc_pitch
			var disc_name := "SpinTile%d" % disc_index
			if disc_index == 12:
				disc_name = "Centrifuge"
			var disc := _obstacle(
				course,
				disc_name,
				SPIN_SCENE,
				Vector3(x, 2.845, z),
				{
					"spin_speed": 1.1 + float(disc_index % 3) * 0.25,
					"glow": false,
				}
			)
			if disc_index % 2 == 1:
				disc.set("spin_speed", -float(disc.get("spin_speed")))
			_obstacle(
				course,
				"BallRain%d" % disc_index,
				DROPPER_SCENE,
				Vector3(x, 9.5, z),
				{
					"interval": 1.0,
					"interval_variance": 0.2,
					"drop_radius": 2.2,
					"max_balls": 3,
					"start_delay": 1.0 + float(disc_index) * 0.1,
					"column_spread": 2.0,
					"ball_color": ball_color,
				}
			)
			disc_index += 1
		# Corriente de aire entre discos: empuja de lado y obliga a corregir la
		# trazada. Sin ventilador ni peana: la máquina de colores se veía fuera
		# de lugar dentro de la arena, así que solo queda el aire.
		if r > 0 and r != 3:
			_obstacle(
				course,
				"SpinGust%d" % r,
				WIND_SCENE,
				Vector3(0.0, 5.6, z),
				{
					"wind_direction": Vector3(1.0 if r % 4 == 1 else -1.0, 0.0, 0.0),
					"strength": 4.2 + float(r % 3) * 0.4,
					"gust_amplitude": 1.8,
					"show_fan": false,
				}
			)
	# Palos largos en las costuras entre discos: el hueco de cinco centímetros
	# deja de ser una línea segura y hay que zigzaguear también por las juntas.
	for px in [-4.0, 4.0]:
		for pz in [-92.0, -100.0, -108.0, -116.0, -124.0]:
			var pole_name := "SeamPole%s%s" % ["L" if px < 0.0 else "R", str(int(-pz))]
			_slab(course, pole_name, Vector3(px, 5.1, pz), Vector3(0.34, 4.2, 0.34), _ice_rock)
			_mesh_sphere(course, pole_name + "Cap", Vector3(px, 7.25, pz), 0.24, _ice_glow)
	# Galería estrecha con todo el suelo en marcha atrás: hay que avanzar contra
	# la cinta mientras se esquivan los cubos que salen de las paredes.
	_obstacle(
		course,
		"GalleryConveyor",
		CONVEYOR_SCENE,
		Vector3(0.0, 6.87, -156.0),
		{
			"direction": Vector3(0.0, 0.0, 1.0),
			"force": 3.4,
			"belt_length": 12.0,
			"belt_width": 26.0,
			"arrow_count": 3,
			"arrow_span": 5.0,
		}
	)
	# Galería estrecha: cinco pistones por pared, alternando lados, barren casi
	# todo el ancho del carril.
	for i in 5:
		var piston_z := -146.0 - float(i) * 4.5
		var phase := float(i) * 0.7
		_obstacle(
			course,
			"PistonL" if i == 0 else "PistonL%d" % (i + 1),
			PISTON_SCENE,
			Vector3(-5.2, 8.2, piston_z),
			{
				"travel": Vector3(5.4, 0.0, 0.0),
				"push_force": 7.2,
				"phase_offset": phase,
			}
		)
		_obstacle(
			course,
			"PistonR" if i == 0 else "PistonR%d" % (i + 1),
			PISTON_SCENE,
			Vector3(5.2, 8.2, piston_z),
			{
				"travel": Vector3(-5.4, 0.0, 0.0),
				"push_force": 7.2,
				"phase_offset": phase + 1.73,
			}
		)
	_obstacle(
		course,
		"WindA",
		WIND_SCENE,
		Vector3(0.0, 11.4, -235.0),
		{
			"wind_direction": Vector3(1.0, 0.0, 0.0),
			"strength": 4.8,
			"gust_amplitude": 1.7,
			"show_fan": false,
		}
	)
	_obstacle(
		course,
		"WindB",
		WIND_SCENE,
		Vector3(0.0, 11.4, -246.0),
		{
			"wind_direction": Vector3(-1.0, 0.0, 0.0),
			"strength": 4.8,
			"gust_amplitude": 1.7,
			"show_fan": false,
		}
	)
	_obstacle(
		course,
		"RotorA",
		ROTOR_SCENE,
		Vector3(0.0, 11.9, -238.0),
		{
			"spin_speed": 1.0,
			"phase_offset": 0.0,
		}
	)
	_obstacle(
		course,
		"RotorB",
		ROTOR_SCENE,
		Vector3(0.0, 11.9, -243.5),
		{
			"spin_speed": 1.15,
			"spin_direction": -1.0,
			"phase_offset": 1.8,
		}
	)
	# Pasillo de rocas: cinco bolas de tamaños y trazadas distintas. Dos cruzan
	# en diagonal, así que apartarse a un lado ya no basta: hay que cambiar de
	# lado mientras ruedan, y la grande obliga a rodearla por el borde.
	var boulder_data := [
		{"x": -3.4, "travel": Vector3(0.0, 0.0, 15.0), "speed": 5.2, "phase": 0.0, "size": 1.0},
		{"x": 3.4, "travel": Vector3(0.0, 0.0, 15.0), "speed": 6.4, "phase": 4.0, "size": 0.85},
		{"x": -1.2, "travel": Vector3(4.5, 0.0, 15.0), "speed": 5.8, "phase": 2.0, "size": 1.3},
		{"x": 1.6, "travel": Vector3(-4.5, 0.0, 15.0), "speed": 6.0, "phase": 6.5, "size": 1.15},
		{"x": 0.0, "travel": Vector3(0.0, 0.0, 15.0), "speed": 4.4, "phase": 9.0, "size": 1.7},
	]
	for i in boulder_data.size():
		var data: Dictionary = boulder_data[i]
		var size: float = data["size"]
		var rock := _obstacle(
			course,
			"Boulder%s" % String.chr(65 + i),
			BOULDER_SCENE,
			Vector3(float(data["x"]), 11.0 + size, -278.5),
			{
				"travel": data["travel"],
				"speed": data["speed"],
				"phase_offset": data["phase"],
				"radius": size,
			}
		)
		# La bola crece de verdad: malla, choque, área de empuje y aro de salida.
		var rock_ball := rock.get_node_or_null("Ball") as Node3D
		if rock_ball != null:
			rock_ball.scale = Vector3.ONE * size
		var rock_ring := rock.get_node_or_null("SpawnRing") as Node3D
		if rock_ring != null:
			rock_ring.scale = Vector3.ONE * size
	# Barrido lento en mitad del pasillo: la roca te empuja a un lado y el brazo
	# al otro, así que el tramo deja de ser una recta con tres bolas.
	_obstacle(
		course,
		"BoulderSweeper",
		SWEEPER_SCENE,
		Vector3(0.0, 11.35, -272.5),
		{
			"spin_speed": 1.15,
			"push_force": 4.6,
			"stuns": false,
		}
	)
	# Lluvia de bolas sobre el pasillo: obliga a mirar arriba entre roca y roca.
	_obstacle(
		course,
		"BoulderRain",
		DROPPER_SCENE,
		Vector3(0.0, 17.6, -272.5),
		{
			"interval": 1.3,
			"drop_radius": 2.4,
			"max_balls": 3,
			"start_delay": 1.0,
			"column_spread": 2.6,
			"chute_count": 3,
			"ball_color": ball_color,
		}
	)
	# Terraza de pinchos el doble de larga: seis filas alternas.
	for row in 6:
		for col in 4:
			_obstacle(
				course,
				"Spike%d_%d" % [row, col],
				SPIKE_SCENE,
				Vector3(-4.4 + float(col) * 2.9, 7.0, -295.0 - float(row) * 4.0),
				{"phase_offset": float(row) * 1.7 + float(col) * 0.6}
			)
	_obstacle(
		course,
		"FinalBelt",
		CONVEYOR_SCENE,
		Vector3(0.0, 6.87, -330.0),
		{
			"direction": Vector3(0.0, 0.0, 1.0),
			"force": 3.8,
			"arrow_span": 2.2,
		}
	)
	# Estreno exclusivo del glaciar: muros de témpanos que emergen del hielo por
	# carriles. Siempre queda uno abierto, así que se pasa leyendo el ritmo.
	var rampart_z := [-325.0]
	for i in rampart_z.size():
		var rampart := ICE_RAMPART_SCRIPT.new() as Node3D
		rampart.name = "IceRampart%d" % i
		rampart.set("lanes", 3)
		rampart.set("lane_width", 3.2)
		rampart.set("block_height", 3.0)
		rampart.set("block_depth", 1.8)
		rampart.set("cycle", 3.2 if i == 0 else 2.7)
		rampart.set("warn_time", 0.7)
		rampart.position = Vector3(0.0, 7.0, float(rampart_z[i]))
		course.add_child(rampart)

	# Cierre del glaciar: segundo muro de témpanos con la misma mecánica que el
	# primero (bloques que suben y bajan por carriles). Antes era una grieta de
	# losas y en partida los tres bloques no se veían ni se movían.
	var rampart2 := ICE_RAMPART_SCRIPT.new() as Node3D
	rampart2.name = "IceRampart1"
	rampart2.set("lanes", 3)
	rampart2.set("lane_width", 3.2)
	rampart2.set("block_height", 3.0)
	rampart2.set("block_depth", 1.8)
	rampart2.set("cycle", 2.7)
	rampart2.set("warn_time", 0.7)
	rampart2.position = Vector3(0.0, 7.0, -334.0)
	course.add_child(rampart2)

	# --- checkpoints y meta ----------------------------------------------
	_add_checkpoint(course, "CP1", Vector3(0.0, 0.0, -24.0))
	_add_checkpoint(course, "CP2", Vector3(0.0, 3.0, -62.0))
	_add_checkpoint(course, "CP3", Vector3(0.0, 3.0, -84.0))
	_add_checkpoint(course, "CP4", Vector3(0.0, 3.0, -135.0))
	_add_checkpoint(course, "CP5", Vector3(0.0, 7.0, -166.0))
	_add_checkpoint(course, "CP6", Vector3(0.0, 7.0, -214.0))
	_add_checkpoint(course, "CP7", Vector3(0.0, 11.0, -256.0))
	_add_checkpoint(course, "CP8", Vector3(0.0, 7.0, -288.0))
	# CP9 va antes del muro de témpanos y de la grieta: si caes en el hueco
	# vuelves al principio del tramo y hay que volver a pasarlo de verdad.
	_add_checkpoint(course, "CP9", Vector3(0.0, 7.0, -321.0))
	_obstacle(course, "FinishLine", FINISH_SCENE, Vector3(0.0, 10.0, -355.5))

	# --- atrezo -----------------------------------------------------------
	var decor := Node3D.new()
	decor.name = "Decor"
	host.add_child(decor)
	_arch(
		decor,
		"StartGate",
		Vector3(0.0, 0.0, -4.0),
		18.0,
		7.0,
		_ice_rock,
		_ice_glow,
		"GLACIER GALLOP"
	)
	_arch(
		decor,
		"SummitGate",
		Vector3(0.0, 10.0, -351.0),
		13.0,
		6.0,
		_ice_rock,
		_ice_glow,
		"CUMBRE HELADA"
	)
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (21.0 + float(i % 3) * 5.5)
		var z := -20.0 - float(i) * 28.0
		var height := 9.0 + float(i % 4) * 4.5
		_mesh_cylinder(
			decor,
			"IceSpire%d" % i,
			Vector3(x, -14.0 + height * 0.5, z),
			0.0,
			2.0 + float(i % 3) * 0.7,
			height,
			_ice_glow,
			Vector3(0.0, 0.0, float(i) * 7.0)
		)

	# Arena de los barridos: nieve en el lomo de las paredes, carámbanos, runas,
	# cascadas heladas, lámparas y cristales. Mismo vestido que la escena
	# horneada, así reconstruir el mapa no deja el tramo pelado.
	var arena_dressing := ICE_ARENA_DRESSING.new() as Node3D
	arena_dressing.name = "ArenaDressing"
	decor.add_child(arena_dressing)

	# Mar helado bajo el circuito.
	var sea := MeshInstance3D.new()
	sea.name = "FrozenSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(760.0, 760.0)
	plane.subdivide_width = 46
	plane.subdivide_depth = 46
	var sea_material := ShaderMaterial.new()
	sea_material.shader = SEA_SHADER
	sea_material.set_shader_parameter("deep_color", Color(0.05, 0.15, 0.2))
	sea_material.set_shader_parameter("mid_color", Color(0.16, 0.4, 0.45))
	sea_material.set_shader_parameter("foam_color", Color(0.7, 0.85, 0.85))
	sea_material.set_shader_parameter("wave_height", 0.45)
	sea_material.set_shader_parameter("wave_scale", 0.045)
	sea_material.set_shader_parameter("flow_speed", 0.18)
	plane.material = sea_material
	sea.mesh = plane
	sea.position = Vector3(0.0, -18.0, -140.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(sea)

	for i in 8:
		var angle := TAU * float(i) / 8.0
		var x := cos(angle) * (34.0 + float(i % 3) * 8.0)
		var z := -120.0 + sin(angle) * (110.0 + float(i % 2) * 25.0)
		_mesh_cylinder(
			decor, "Iceberg%d" % i, Vector3(x, -13.0, z), 1.2, 4.5 + float(i % 3), 12.0, _ice_white
		)
		_mesh_sphere(decor, "IcebergCap%d" % i, Vector3(x, -7.2, z), 4.1 + float(i % 3), _ice_white)

	# Auroras: cintas emisivas muy altas, fuera del recorrido.
	for i in 3:
		var aurora_material := StandardMaterial3D.new()
		aurora_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		aurora_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		aurora_material.albedo_color = Color(0.55, 0.92, 0.78, 0.09)
		aurora_material.emission_enabled = true
		aurora_material.emission = Color(0.3, 0.8, 0.65)
		aurora_material.emission_energy_multiplier = 0.75
		aurora_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_box(
			decor,
			"Aurora%d" % i,
			Vector3(float(i - 1) * 55.0, 52.0 + float(i) * 9.0, -150.0),
			Vector3(120.0, 0.35, 16.0),
			aurora_material,
			Vector3(-8.0, float(i) * 24.0, 6.0)
		)

	# Sierra lejana: cierra el horizonte helado sin acercarse a la pista.
	for i in 10:
		var ring_angle := TAU * float(i) / 10.0 + 0.4
		var ring_distance := 190.0 + float(i % 3) * 35.0
		var ring_height := 55.0 + float(i % 4) * 22.0
		_mesh_cylinder(
			decor,
			"DistantPeak%d" % i,
			Vector3(
				cos(ring_angle) * ring_distance,
				-18.0 + ring_height * 0.5,
				-140.0 + sin(ring_angle) * ring_distance
			),
			0.0,
			30.0 + float(i % 3) * 8.0,
			ring_height,
			_ice_white,
			Vector3(0.0, float(i) * 31.0, 0.0)
		)

	# Cristales de hielo en los bordes de las plataformas anchas: dan el toque
	# helado sin meterse en la trazada.
	var crystal_spots := [
		Vector3(-7.2, 0.0, -31.0),
		Vector3(7.2, 0.0, -37.0),
		Vector3(-12.4, 5.7, -88.0),
		Vector3(12.4, 5.7, -104.0),
		Vector3(-12.4, 5.7, -126.0),
		Vector3(12.4, 5.7, -134.0),
		Vector3(-5.4, 7.0, -148.0),
		Vector3(5.4, 7.0, -164.0),
		Vector3(-8.1, 11.0, -234.0),
		Vector3(8.1, 11.0, -244.0),
		Vector3(-5.9, 7.0, -272.5),
		Vector3(5.9, 7.0, -288.0),
		Vector3(-5.9, 7.0, -302.0),
		Vector3(5.9, 7.0, -314.0),
		Vector3(-4.6, 7.0, -322.0),
		Vector3(4.6, 7.0, -338.0),
	]
	for i in crystal_spots.size():
		var spot: Vector3 = crystal_spots[i]
		var tall := 1.8 + float(i % 3) * 0.9
		_mesh_cylinder(
			decor,
			"IceCrystal%d" % i,
			spot + Vector3(0.0, tall * 0.5 - 0.2, 0.0),
			0.0,
			0.5,
			tall,
			_ice_spike,
			Vector3(float(i) * 9.0, float(i) * 23.0, 0.0),
			6
		)
		_mesh_cylinder(
			decor,
			"IceCrystalSmall%d" % i,
			spot + Vector3(0.9 if i % 2 == 0 else -0.9, 0.55, 0.5),
			0.0,
			0.3,
			1.1,
			_ice_glow,
			Vector3(0.0, 0.0, 18.0),
			6
		)

	# Arcos de hielo sobre la pista: marcan cada tramo del circuito.
	# Un ancho por arco: en los tramos estrechos los pilares quedaban dentro de
	# la trazada o colgando fuera del hielo.
	var arch_spots := [
		{"p": Vector3(0.0, 7.0, -148.0), "s": 13.0},
		{"p": Vector3(0.0, 7.0, -200.0), "s": 11.5},
		{"p": Vector3(0.0, 11.0, -250.5), "s": 13.5},
		{"p": Vector3(0.0, 11.0, -270.0), "s": 12.5},
		{"p": Vector3(0.0, 7.0, -302.0), "s": 14.0},
		{"p": Vector3(0.0, 7.0, -330.0), "s": 11.5},
	]
	for i in arch_spots.size():
		var spot: Vector3 = arch_spots[i]["p"]
		var span: float = arch_spots[i]["s"]
		var tall := 4.6 + float(i % 3) * 0.5
		for side in [-1.0, 1.0]:
			var x: float = spot.x + side * span * 0.5
			_mesh_box(
				decor,
				"ArchPillar%d_%d" % [i, int(side)],
				Vector3(x, spot.y + tall * 0.5, spot.z),
				Vector3(0.7, tall, 0.7),
				_ice_rock,
				Vector3(0.0, float(i) * 7.0, 0.0)
			)
		_mesh_box(
			decor,
			"ArchBeam%d" % i,
			Vector3(spot.x, spot.y + tall + 0.25, spot.z),
			Vector3(span + 0.7, 0.5, 0.55),
			_ice_rock
		)
		_mesh_box(
			decor,
			"ArchGlow%d" % i,
			Vector3(spot.x, spot.y + tall - 0.05, spot.z + 0.3),
			Vector3(span - 0.6, 0.09, 0.12),
			_ice_glow
		)

	# Cataratas congeladas y témpanos flotando: fondo, fuera de la trazada.
	for i in 7:
		var fall_angle := TAU * float(i) / 7.0 + 0.2
		var fall_distance := 120.0 + float(i % 3) * 22.0
		var fall_height := 46.0 + float(i % 4) * 12.0
		_mesh_box(
			decor,
			"FrozenFall%d" % i,
			Vector3(
				cos(fall_angle) * fall_distance,
				fall_height * 0.5 - 16.0,
				-185.0 + sin(fall_angle) * fall_distance
			),
			Vector3(1.6, fall_height, 1.6),
			_ice_glow,
			Vector3(0.0, 0.0, 8.0)
		)
	for i in 6:
		var floe_angle := TAU * float(i) / 6.0 + 0.9
		var floe_distance := 62.0 + float(i % 2) * 30.0
		var floe_y := 26.0 + float(i % 3) * 9.0
		_mesh_sphere(
			decor,
			"FloatingFloe%d" % i,
			Vector3(
				cos(floe_angle) * floe_distance, floe_y, -190.0 + sin(floe_angle) * floe_distance
			),
			5.5 + float(i % 3),
			_ice_white
		)

	# Luna de escarcha al fondo: cierra el paisaje de noche polar.
	var moon_material := StandardMaterial3D.new()
	moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_material.albedo_color = Color(0.86, 0.94, 1.0)
	moon_material.emission_enabled = true
	moon_material.emission = Color(0.55, 0.75, 1.0)
	moon_material.emission_energy_multiplier = 0.9
	_mesh_sphere(decor, "FrostMoon", Vector3(-95.0, 78.0, -315.0), 15.0, moon_material)

	# --- fondo ampliado: catedral de hielo, banderines y niebla -------------
	# Detrás de la meta, no encima de la pista: antes el bloque central caía
	# justo sobre la recta final y se veía una montaña dentro de la plataforma.
	# La pared de fondo se alejó de la meta: caía a setenta metros de la llegada
	# y su mole blanca tapaba toda la cumbre desde la última rampa.
	for i in 3:
		_mesh_box(
			decor,
			"GlacierWall%d" % i,
			Vector3(float(i - 1) * 190.0, 19.0, -560.0 - float(i) * 34.0),
			Vector3(230.0, 58.0, 6.0),
			_ice_white,
			Vector3(0.0, float(i - 1) * 9.0, 0.0)
		)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var height := 30.0 + float(i % 4) * 14.0
		var cathedral_x := cos(angle) * 95.0
		var cathedral_z := -300.0 + sin(angle) * 70.0
		# Dos de estas torres caían justo sobre las repisas del vendaval y
		# sobre la cumbre: eran las «montañas» que se veían dentro del hielo.
		if not _ice_clear(cathedral_x, cathedral_z, 7.5):
			continue
		_mesh_cylinder(
			decor,
			"IceCathedral%d" % i,
			Vector3(cathedral_x, -18.0 + height * 0.5, cathedral_z),
			0.0,
			7.5,
			height,
			_ice_white,
			Vector3(0.0, float(i) * 22.0, 0.0),
			6
		)
	# Banderines: solo en el borde de las plataformas anchas, nunca dentro de la
	# trazada (antes salían en mitad del hielo y sobre los discos del teclado).
	var banner_spots := [
		Vector3(-8.6, 0.0, -6.0),
		Vector3(8.6, 0.0, -16.0),
		Vector3(-8.6, 0.0, -26.0),
		Vector3(8.6, 0.0, -38.0),
		Vector3(-4.6, 3.0, -53.5),
		Vector3(4.6, 3.0, -61.0),
		Vector3(-12.4, 5.7, -86.0),
		Vector3(12.4, 5.7, -118.0),
		Vector3(-5.4, 7.0, -146.0),
		Vector3(5.4, 7.0, -166.0),
		Vector3(-5.4, 7.0, -210.0),
		Vector3(5.4, 7.0, -218.0),
		Vector3(-7.8, 11.0, -231.5),
		Vector3(7.8, 11.0, -246.5),
		Vector3(-5.4, 11.0, -253.0),
		Vector3(5.4, 11.0, -258.0),
		Vector3(-4.9, 11.0, -268.0),
		Vector3(4.9, 11.0, -278.0),
		Vector3(-6.0, 7.0, -294.0),
		Vector3(6.0, 7.0, -312.0),
		Vector3(-4.4, 7.0, -324.0),
		Vector3(4.4, 7.0, -335.0),
		Vector3(-7.6, 10.0, -349.0),
		Vector3(7.6, 10.0, -361.0),
	]
	for i in banner_spots.size():
		var spot: Vector3 = banner_spots[i]
		var side := -1.0 if spot.x < 0.0 else 1.0
		_mesh_box(
			decor,
			"BannerPost%d" % i,
			spot + Vector3(0.0, 2.4, 0.0),
			Vector3(0.16, 4.8, 0.16),
			_ice_rock
		)
		_mesh_box(
			decor,
			"BannerCloth%d" % i,
			spot + Vector3(-side * 0.7, 3.9, 0.0),
			Vector3(1.3, 1.7, 0.06),
			_ice_glow,
			Vector3(0.0, 0.0, side * 8.0)
		)
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var drift_x := cos(angle) * (30.0 + float(i % 4) * 6.0)
		var drift_z := -150.0 + sin(angle) * (70.0 + float(i % 3) * 12.0)
		var drift_radius := 3.4 + float(i % 3)
		# Ningún montículo asoma por encima de una losa: antes uno de estos
		# sobresalía del hielo de aterrizaje y parecía una montaña en la pista.
		if not _ice_clear(drift_x, drift_z, drift_radius):
			continue
		_mesh_sphere(
			decor, "SnowDrift%d" % i, Vector3(drift_x, -1.6, drift_z), drift_radius, _ice_white
		)
	# --- segunda pasada de atrezo: hielo por todas partes -------------------
	for i in 18:
		var z := -20.0 - float(i) * 19.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var lip_x := side * (6.5 + float(i % 3) * 2.0)
		for k in 3:
			var tall := 1.2 + float((i + k) % 3) * 0.6
			_mesh_cylinder(
				decor,
				"Icicle%d_%d" % [i, k],
				Vector3(lip_x + float(k) * 0.5, -tall * 0.5, z + float(k) * 0.6),
				0.0,
				0.16,
				tall,
				_ice_glow,
				Vector3(180.0, 0.0, 0.0),
				6
			)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var distance := 40.0 + float(i % 4) * 12.0
		_mesh_box(
			decor,
			"Shard%d" % i,
			Vector3(
				cos(angle) * distance,
				18.0 + float(i % 5) * 7.0,
				-170.0 + sin(angle) * (80.0 + float(i % 3) * 20.0)
			),
			Vector3(2.2, 7.5, 2.2),
			_ice_white,
			Vector3(float(i) * 14.0, float(i) * 27.0, float(i) * 9.0)
		)
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.5
		_mesh_box(
			decor,
			"FarArch%d" % i,
			Vector3(cos(angle) * 55.0, 26.0, -200.0 + sin(angle) * 55.0),
			Vector3(26.0, 2.2, 4.0),
			_ice_white,
			Vector3(0.0, rad_to_deg(-angle), 0.0)
		)
	# Dos de estos géiseres salían en mitad de la arena giratoria y de la terraza
	# de pinchos: se descartan y el resto sigue rodeando el circuito.
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var distance := 70.0 + float(i % 3) * 18.0
		var tall := 20.0 + float(i % 4) * 9.0
		var geyser_x := cos(angle) * distance
		var geyser_z := -240.0 + sin(angle) * distance
		if not _ice_clear(geyser_x, geyser_z, 2.6):
			continue
		_mesh_cylinder(
			decor,
			"FrozenGeyser%d" % i,
			Vector3(geyser_x, -18.0 + tall * 0.5, geyser_z),
			0.4,
			2.6,
			tall,
			_ice_glow,
			Vector3.ZERO,
			8
		)

	# Pilonos bajo las dos repisas del vendaval: dejan de parecer que flotan y
	# añaden detalle debajo de la pista, sin tapar la línea de visión.
	var gale_pylons := [
		Vector2(-7.4, -230.5),
		Vector2(-2.6, -238.0),
		Vector2(2.6, -238.5),
		Vector2(7.4, -247.5),
	]
	for i in gale_pylons.size():
		var spot: Vector2 = gale_pylons[i]
		_mesh_cylinder(
			decor,
			"GalePylon%d" % i,
			Vector3(spot.x, 3.0, spot.y),
			0.7,
			1.1,
			16.0,
			_ice_dark,
			Vector3.ZERO,
			8
		)
		_mesh_sphere(decor, "GalePylonBase%d" % i, Vector3(spot.x, -4.7, spot.y), 1.6, _ice_rock)
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		_mesh_cylinder(
			decor,
			"GaleIcicle%d" % i,
			Vector3(side * (3.2 + float(i % 3) * 1.5), 10.4, -229.5 - float(i) * 2.6),
			0.0,
			0.2,
			1.5,
			_ice_glow,
			Vector3(180.0, 0.0, 0.0),
			6
		)

	_ice_mist(decor, Vector3(0.0, -6.0, -160.0), 240)
	_ice_mist(decor, Vector3(0.0, -12.0, -300.0), 160)
	_ice_stars(decor, Vector3(0.0, 70.0, -220.0))

	_snow_particles(decor, Vector3(0.0, 0.0, -176.0))
	var lights := [
		Vector3(0.0, 4.5, -34.0),
		Vector3(0.0, 7.5, -96.0),
		Vector3(-18.0, 7.5, -111.0),
		Vector3(18.0, 7.5, -111.0),
		Vector3(0.0, 7.5, -131.0),
		Vector3(0.0, 11.5, -156.0),
		Vector3(0.0, 15.5, -239.0),
		Vector3(0.0, 15.5, -272.5),
		Vector3(0.0, 11.5, -305.0),
		Vector3(0.0, 11.5, -330.0),
		Vector3(0.0, 14.5, -355.0)
	]
	for i in lights.size():
		var light := OmniLight3D.new()
		light.name = "CourseLight%d" % i
		light.position = lights[i]
		light.light_color = Color(1.0, 0.88, 0.74)
		light.light_energy = 1.0
		light.omni_range = 16.0
		light.shadow_enabled = false
		decor.add_child(light)

	# --- esqueleto de la carrera -----------------------------------------
	_add_level_info(
		{
			"level_id": "glacier_gallop",
			"display_name": "Glacier Gallop",
			"round_index": 3,
			"start_z": 5.0,
			"finish_z": -357.0,
			"course_length": 367.0,
			"gold_time": 145.0,
			"silver_time": 180.0,
			"bronze_time": 225.0,
			"start_position": Vector3(0.0, 0.0, 6.0),
			"path_corridor": false,
		}
	)
	_add_race_manager()
	_add_hud()
	_add_kill_plane(Vector3(0.0, -12.0, -180.0))
	# Salto flojo del glaciar: 5.02 de impulso deja el salto en el 70 % de la
	# altura que da el salto por defecto (6.0) sin cambiar el resto del control.
	_add_player(Vector3(0.0, 0.6, 5.0), 5.02)
	_add_director(5.0, -357.0, 367.0)
	_add_pause()


# ---------------------------------------------------------- ronda 4: volcán


## Punto de entrada del kit: el builder llama aquí sin saber de qué tema se trata.
func build() -> void:
	_build_glacier()
