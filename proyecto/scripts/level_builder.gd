extends Node3D

## Construye en runtime los dos circuitos nuevos:
##   level_kind = "glacier"  ->  Glacier Gallop (ronda 3)
##   level_kind = "volcano"  ->  Lava Vortex   (ronda 4)
##
## Los dos comparten el mismo esqueleto que las escenas antiguas (LevelInfo,
## RaceManager, HUD, KillPlane, RaceDirector, Player y pausa), pero la pista se
## genera aquí: el glaciar es un recorrido helado con saltos, placas frágiles y
## vendavales; el volcán es una espiral de seis vueltas alrededor de una montaña,
## con lava que sube, géiseres y lluvia de meteoros.
##
## La cámara del volcán gira con la espiral: sin eso, correr en línea recta con
## el stick dejaría al jugador mirando a la pared de la montaña.

@export var level_kind: String = "glacier"

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/race/hud.tscn")
const KILL_SCENE := preload("res://scenes/race/kill_plane.tscn")
const PAUSE_SCENE := preload("res://scenes/menu/pause_menu.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/race/checkpoint.tscn")
const FINISH_SCENE := preload("res://scenes/race/finish_line.tscn")
const BOT_SCENE := preload("res://scenes/race/bot_racer.tscn")

const SWEEPER_SCENE := preload("res://scenes/obstacles/sweeper.tscn")
const SPIN_SCENE := preload("res://scenes/obstacles/spinning_platform.tscn")
const MOVING_SCENE := preload("res://scenes/obstacles/moving_platform.tscn")
const DROPPER_SCENE := preload("res://scenes/obstacles/ball_dropper.tscn")
const PISTON_SCENE := preload("res://scenes/obstacles/piston.tscn")
const CRUMBLE_SCENE := preload("res://scenes/obstacles/crumble_tile.tscn")
const WIND_SCENE := preload("res://scenes/obstacles/wind_tunnel.tscn")
const ROTOR_SCENE := preload("res://scenes/obstacles/rotor_gate.tscn")
const BOULDER_SCENE := preload("res://scenes/obstacles/boulder.tscn")
const SPIKE_SCENE := preload("res://scenes/obstacles/spike_trap.tscn")
const CONVEYOR_SCENE := preload("res://scenes/obstacles/conveyor.tscn")

const LAVA_RISE_SCRIPT := preload("res://scripts/lava_rise.gd")
const GEYSER_SCRIPT := preload("res://scripts/lava_geyser.gd")
const METEOR_RAIN_SCRIPT := preload("res://scripts/meteor_rain.gd")

const PLATFORM_SHADER := preload("res://shaders/platform.gdshader")
const POST_SHADER := preload("res://shaders/post_process.gdshader")
const SKY_SHADER := preload("res://shaders/sky_clouds.gdshader")
const SEA_SHADER := preload("res://shaders/void_sea.gdshader")

## Volcán: círculo, vueltas y subida por segmento.
const V_CENTER := Vector3(0.0, 0.0, -90.0)
const V_RADIUS := 18.0
const V_SEGMENTS := 144
const V_PER_TURN := 28
const V_RISE := 0.7
const V_START_TOP := 1.05
const V_HALF_WIDTH := 4.0
const V_DECK_THICKNESS := 0.45
## Cortes de la espiral en tramos continuos. Los huecos 36, 72 y 108 son los
## tres saltos; cada tramo se construye como una sola malla, sin escalones.
const V_DECK_SECTIONS := [[0, 36], [37, 72], [73, 108], [109, 144]]
## Segmentos que se dejan sin plataforma: tres saltos sobre la lava.
const V_GAPS := [36, 72, 108]

var _path: Array[Vector3] = []
var _widths: Array[float] = []
var _camera_spring: SpringArm3D
var _camera_base_pitch: float = 0.0

var _ice: ShaderMaterial
var _ice_alt: ShaderMaterial
var _ice_dark: ShaderMaterial
var _ice_white: ShaderMaterial
var _ice_glow: StandardMaterial3D
var _ice_rock: StandardMaterial3D

var _basalt: ShaderMaterial
var _basalt_hot: ShaderMaterial
var _volcano_rock: StandardMaterial3D
var _volcano_glow: StandardMaterial3D
var _volcano_red: StandardMaterial3D
var _spiral_deck: StandardMaterial3D
var _spiral_rail: StandardMaterial3D


func _ready() -> void:
	if level_kind == "volcano":
		_build_volcano()
		set_process(true)
	else:
		_build_glacier()


## La cámara del jugador sigue la tangente de la espiral. Es una ayuda de
## control: el stick hacia delante sigue la cuesta en vez de salirse por fuera.
func _process(delta: float) -> void:
	if level_kind != "volcano":
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot == null:
		return
	if _camera_spring == null:
		_camera_spring = player.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
		if _camera_spring != null:
			_camera_base_pitch = _camera_spring.rotation.x
	# En la recta de salida (aún fuera del círculo) la cámara mira al frente;
	# al entrar en la espiral sigue la tangente con una corrección rápida: si
	# va con retraso, la pared del volcán aparece a la derecha como si fueran
	# plataformas y el jugador necesita corregir el rumbo constantemente.
	var inside := player.global_position.z <= V_CENTER.z + 0.5
	var target_yaw := _path_yaw_at(player.global_position)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw,
		clampf(delta * 9.0, 0.0, 1.0))
	# La cámara también acompaña la pendiente: al subir deja de mirar tanto
	# al suelo y encuadra la cuesta. Es un gesto suave, no un volantazo.
	if _camera_spring != null:
		var slope := atan2(V_RISE, (TAU / float(V_PER_TURN)) * V_RADIUS)
		var target_pitch := _camera_base_pitch + slope * 0.4 if inside else _camera_base_pitch
		_camera_spring.rotation.x = lerp_angle(_camera_spring.rotation.x,
			target_pitch, clampf(delta * 3.5, 0.0, 1.0))


## Rumbo de la cámara tomado de la propia ruta, no del ángulo polar. En la
## cumbre el jugador ya no está sobre el círculo y el ángulo polar apuntaría a
## otro sitio; la tangente del último tramo mantiene el encuadre hasta la meta.
func _path_yaw_at(position: Vector3) -> float:
	if _path.size() < 2:
		return 0.0
	var best := 0
	var best_distance := INF
	for i in _path.size():
		var dx := _path[i].x - position.x
		var dz := _path[i].z - position.z
		var d := dx * dx + dz * dz
		if d < best_distance:
			best_distance = d
			best = i
	var a := _path[maxi(best - 1, 0)]
	var b := _path[mini(best + 1, _path.size() - 1)]
	var dir := Vector2(b.x - a.x, b.z - a.z)
	if dir.length_squared() < 0.0001:
		return 0.0
	return atan2(-dir.x, -dir.y)


# --------------------------------------------------------------- materiales

func _platform_mat(base: Color, accent: Color, grout: Color, glow: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLATFORM_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("accent_color", accent)
	material.set_shader_parameter("grout_color", grout)
	material.set_shader_parameter("glow_strength", glow)
	material.set_shader_parameter("sweep_strength", 0.18)
	material.set_shader_parameter("tile_scale", 0.62)
	return material


func _glow_mat(color: Color, energy: float, roughness: float = 0.32) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _rock_mat(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _make_ice_palette() -> void:
	# Paleta de amanecer ártico: azules desaturados, verdín suave y un sol
	# cálido. La versión anterior era cian eléctrico con bloom y cansaba la
	# vista en cuanto se encadenaban varias curvas.
	_ice = _platform_mat(Color(0.19, 0.33, 0.4), Color(0.72, 0.88, 0.9),
		Color(0.06, 0.12, 0.16), 0.12)
	_ice_alt = _platform_mat(Color(0.27, 0.43, 0.5), Color(0.85, 0.95, 0.95),
		Color(0.08, 0.15, 0.19), 0.1)
	_ice_dark = _platform_mat(Color(0.12, 0.22, 0.29), Color(0.5, 0.7, 0.75),
		Color(0.03, 0.07, 0.1), 0.1)
	_ice_white = _platform_mat(Color(0.55, 0.67, 0.7), Color(0.9, 0.96, 0.95),
		Color(0.25, 0.35, 0.4), 0.05)
	_ice_glow = _glow_mat(Color(0.58, 0.8, 0.82), 0.7, 0.5)
	_ice_rock = _rock_mat(Color(0.2, 0.3, 0.36), Color(0.06, 0.14, 0.18), 0.1)


func _make_volcano_palette() -> void:
	_basalt = _platform_mat(Color(0.16, 0.07, 0.06), Color(1.0, 0.5, 0.12),
		Color(0.03, 0.015, 0.015), 0.5)
	_basalt_hot = _platform_mat(Color(0.24, 0.09, 0.04), Color(1.0, 0.68, 0.22),
		Color(0.05, 0.02, 0.01), 0.62)
	_volcano_rock = _rock_mat(Color(0.09, 0.05, 0.045), Color(0.8, 0.18, 0.03), 0.55)
	_volcano_glow = _glow_mat(Color(1.0, 0.38, 0.06), 3.0)
	_spiral_deck = StandardMaterial3D.new()
	_spiral_deck.vertex_color_use_as_albedo = true
	_spiral_deck.albedo_color = Color.WHITE
	_spiral_deck.roughness = 0.84
	_spiral_deck.metallic = 0.18
	_spiral_deck.cull_mode = BaseMaterial3D.CULL_DISABLED
	_spiral_deck.emission_enabled = true
	_spiral_deck.emission = Color(0.32, 0.075, 0.02)
	_spiral_deck.emission_energy_multiplier = 0.35
	_spiral_rail = _glow_mat(Color(1.0, 0.4, 0.07), 3.2, 0.4)
	_spiral_rail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spiral_rail.cull_mode = BaseMaterial3D.CULL_DISABLED


# ---------------------------------------------------------------- escenario

func _add_environment(cfg: Dictionary) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = cfg["sky_top"]
	sky_material.sky_horizon_color = cfg["sky_horizon"]
	sky_material.sky_curve = 0.17
	sky_material.ground_bottom_color = cfg["sky_ground"]
	sky_material.ground_horizon_color = cfg["sky_horizon"]
	sky_material.ground_curve = 0.12
	sky_material.sun_angle_max = 22.0
	sky_material.sun_curve = 0.1
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = cfg["ambient"]
	environment.ambient_light_energy = cfg["ambient_energy"]
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = cfg["exposure"]
	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.7
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.fog_enabled = true
	environment.fog_light_color = cfg["fog"]
	environment.fog_density = cfg["fog_density"]
	environment.fog_sky_affect = 0.35
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.07
	environment.adjustment_saturation = cfg["saturation"]

	var node := WorldEnvironment.new()
	node.name = "WorldEnvironment"
	node.environment = environment
	add_child(node)


func _add_lights(cfg: Dictionary) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation_degrees = Vector3(cfg["sun_pitch"], cfg["sun_yaw"], 0.0)
	sun.light_color = cfg["sun_color"]
	sun.light_energy = cfg["sun_energy"]
	sun.light_angular_distance = 0.7
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 260.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-28.0, cfg["sun_yaw"] + 165.0, 0.0)
	fill.light_color = cfg["fill"]
	fill.light_energy = cfg["fill_energy"]
	fill.shadow_enabled = false
	add_child(fill)


func _add_sky(cfg: Dictionary) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 420.0
	mesh.height = 840.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var dome := MeshInstance3D.new()
	dome.name = "SkyDome"
	dome.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("top_color", cfg["sky_top"])
	material.set_shader_parameter("horizon_color", cfg["sky_horizon"])
	material.set_shader_parameter("ground_color", cfg["sky_ground"])
	material.set_shader_parameter("cloud_color", cfg["cloud_color"])
	material.set_shader_parameter("sun_color", cfg["sun_color"])
	material.set_shader_parameter("sun_direction", Vector3(0.4, 0.55, -0.7).normalized())
	material.set_shader_parameter("cloud_opacity", cfg["cloud_opacity"])
	material.set_shader_parameter("cloud_scale", cfg["cloud_scale"])
	material.set_shader_parameter("sun_glow", 1.0)
	dome.material_override = material
	dome.position = Vector3(0.0, 0.0, cfg["dome_z"])
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)


func _add_post(cfg: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.name = "PostProcess"
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.name = "Rect"
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = POST_SHADER
	material.set_shader_parameter("saturation", cfg["saturation"])
	material.set_shader_parameter("contrast", 1.08)
	material.set_shader_parameter("vignette", 0.34)
	material.set_shader_parameter("flash_amount", 0.0)
	rect.material = material
	layer.add_child(rect)


func _add_level_info(values: Dictionary) -> void:
	var info := load("res://scripts/level_info.gd").new() as Node
	info.name = "LevelInfo"
	for key in values.keys():
		info.set(key, values[key])
	var points := PackedVector3Array()
	for point in _path:
		points.append(point)
	var widths := PackedFloat32Array()
	for width in _widths:
		widths.append(width)
	info.set("waypoints", points)
	info.set("lane_widths", widths)
	add_child(info)


func _add_race_manager() -> void:
	var manager := load("res://scripts/race_manager.gd").new() as Node
	manager.name = "RaceManager"
	add_child(manager)


func _add_hud() -> void:
	add_child(HUD_SCENE.instantiate())


func _add_kill_plane(position: Vector3) -> void:
	var kill := KILL_SCENE.instantiate() as Node3D
	kill.name = "KillPlane"
	kill.position = position
	kill.scale = Vector3(1.7, 1.0, 1.7)
	add_child(kill)


func _add_player(start: Vector3) -> void:
	var player := PLAYER_SCENE.instantiate() as Node3D
	player.name = "Player"
	player.position = start
	add_child(player)


func _add_director(start_z: float, finish_z: float, course_length: float) -> void:
	var director := load("res://scripts/race_director.gd").new() as Node
	director.name = "RaceDirector"
	director.set("bot_scene", BOT_SCENE)
	director.set("start_z", start_z)
	director.set("finish_z", finish_z)
	director.set("course_length", course_length)
	add_child(director)


func _add_pause() -> void:
	add_child(PAUSE_SCENE.instantiate())


# ------------------------------------------------------------------ helpers

func _slab(parent: Node3D, node_name: String, center: Vector3, size: Vector3,
		material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)
	parent.add_child(body)
	return body


func _slab_top(parent: Node3D, node_name: String, x: float, z: float,
		sx: float, sz: float, top: float, material: Material) -> StaticBody3D:
	return _slab(parent, node_name, Vector3(x, top - 0.25, z),
		Vector3(sx, 0.5, sz), material)


func _ramp_z(parent: Node3D, node_name: String, x: float, z_from: float,
		z_to: float, y_from: float, y_to: float, width: float,
		material: Material) -> StaticBody3D:
	var run := z_from - z_to
	var rise := y_to - y_from
	var length := sqrt(run * run + rise * rise)
	var pitch := atan2(rise, run)
	var body := _slab(parent, node_name, Vector3(x,
		(y_from + y_to) * 0.5 - 0.25 * cos(pitch),
		(z_from + z_to) * 0.5 - 0.25 * sin(pitch)),
		Vector3(width, 0.5, length), material)
	body.rotation.x = pitch
	return body


func _arc_segment(parent: Node3D, node_name: String, center: Vector3,
		size: Vector3, pitch: float, yaw: float, material: Material) -> StaticBody3D:
	var body := _slab(parent, node_name, center, size, material)
	body.rotation = Vector3(pitch, yaw, 0.0)
	return body


## Punto del borde de la espiral. `radial` va de -V_HALF_WIDTH (interior)
## a +V_HALF_WIDTH (exterior) y la altura sigue la subida lineal del circuito.
func _spiral_ring(seg: int, radial: float, y_offset: float = 0.0) -> Vector3:
	var angle := PI + float(seg) * (TAU / float(V_PER_TURN))
	var radius := V_RADIUS + radial
	return Vector3(V_CENTER.x + cos(angle) * radius,
		V_START_TOP + float(seg) * V_RISE + y_offset,
		V_CENTER.z + sin(angle) * radius)


func _deck_tri(st: SurfaceTool, faces: Array, a: Vector3, b: Vector3,
		c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
	faces.append(a)
	faces.append(b)
	faces.append(c)


func _deck_quad(st: SurfaceTool, faces: Array, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, color: Color) -> void:
	_deck_tri(st, faces, a, b, c, color)
	_deck_tri(st, faces, a, c, d, color)


## Una sección de la espiral como una única malla continua. Antes cada tramo
## era una caja girada: en el borde interior las cajas se cruzaban y formaban
## rebordes que parecían plataformas y obligaban a saltar cada pocos metros.
func _spiral_deck_section(parent: Node3D, node_name: String, start_seg: int,
		end_seg: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = []
	var top_in: Array[Vector3] = []
	var top_out: Array[Vector3] = []
	var bot_in: Array[Vector3] = []
	var bot_out: Array[Vector3] = []
	var colors: Array[Color] = []
	var rings := end_seg - start_seg + 1
	for j in rings:
		var seg := start_seg + j
		top_in.append(_spiral_ring(seg, -V_HALF_WIDTH))
		top_out.append(_spiral_ring(seg, V_HALF_WIDTH))
		bot_in.append(_spiral_ring(seg, -V_HALF_WIDTH, -V_DECK_THICKNESS))
		bot_out.append(_spiral_ring(seg, V_HALF_WIDTH, -V_DECK_THICKNESS))
		var heat := 0.5 + 0.5 * sin(float(seg) * 0.61)
		colors.append(Color(0.07, 0.042, 0.036).lerp(
			Color(0.2, 0.075, 0.035), heat * 0.6))

	for j in rings - 1:
		var k := j + 1
		var top_color := colors[j]
		var side_color := colors[j].darkened(0.35)
		_deck_quad(st, faces, top_in[j], top_out[j], top_out[k], top_in[k], top_color)
		_deck_quad(st, faces, bot_in[k], bot_out[k], bot_out[j], bot_in[j], side_color)
		_deck_quad(st, faces, top_out[j], bot_out[j], bot_out[k], top_out[k], side_color)
		_deck_quad(st, faces, top_in[k], bot_in[k], bot_in[j], top_in[j], side_color)

	# Tapas de los extremos: los tres huecos quedan limpios y fáciles de leer.
	var last := rings - 1
	_deck_quad(st, faces, top_in[0], bot_in[0], bot_out[0], top_out[0],
		colors[0].darkened(0.25))
	_deck_quad(st, faces, top_in[last], top_out[last], bot_out[last], bot_in[last],
		colors[last].darkened(0.25))

	st.generate_normals()
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	instance.material_override = _spiral_deck
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(instance)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(PackedVector3Array(faces))
	# La malla es de doble cara: así ninguna cara de la rampa deja huecos al
	# personaje aunque caiga justo en un borde.
	concave.backface_collision = true
	shape_node.shape = concave
	body.add_child(shape_node)
	parent.add_child(body)


## Borde luminoso de la pista. No tiene colisión: solo marca el límite y hace
## que la espiral se lea de un vistazo. Se corta en los tres saltos.
func _spiral_ribbon(parent: Node3D, node_name: String, radial: float,
		width: float, y_offset: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in V_SEGMENTS:
		if seg in V_GAPS:
			continue
		var a0 := _spiral_ring(seg, radial - width * 0.5, y_offset)
		var a1 := _spiral_ring(seg, radial + width * 0.5, y_offset)
		var b0 := _spiral_ring(seg + 1, radial - width * 0.5, y_offset)
		var b1 := _spiral_ring(seg + 1, radial + width * 0.5, y_offset)
		st.add_vertex(a0)
		st.add_vertex(a1)
		st.add_vertex(b1)
		st.add_vertex(a0)
		st.add_vertex(b1)
		st.add_vertex(b0)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = st.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _build_spiral_deck(course: Node3D) -> void:
	for i in V_DECK_SECTIONS.size():
		var section: Array = V_DECK_SECTIONS[i]
		_spiral_deck_section(course, "SpiralDeck%d" % i, int(section[0]), int(section[1]))
	_spiral_ribbon(course, "InnerRail", -V_HALF_WIDTH + 0.12, 0.24, 0.045,
		_spiral_rail)
	_spiral_ribbon(course, "OuterRail", V_HALF_WIDTH - 0.12, 0.24, 0.045,
		_spiral_rail)


func _obstacle(parent: Node3D, node_name: String, scene: PackedScene,
		position: Vector3, values: Dictionary = {}, yaw: float = 0.0) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.position = position
	node.rotation.y = yaw
	for key in values.keys():
		node.set(key, values[key])
	parent.add_child(node)
	return node


func _mesh_box(parent: Node3D, node_name: String, position: Vector3,
		size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _mesh_cylinder(parent: Node3D, node_name: String, position: Vector3,
		top_radius: float, bottom_radius: float, height: float,
		material: Material, rot: Vector3 = Vector3.ZERO,
		segments: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _mesh_sphere(parent: Node3D, node_name: String, position: Vector3,
		radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 9
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _mesh_torus(parent: Node3D, node_name: String, position: Vector3,
		inner_radius: float, outer_radius: float, material: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 28
	mesh.ring_segments = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _arch(parent: Node3D, node_name: String, position: Vector3, width: float,
		height: float, post_material: Material, glow_material: Material,
		label: String) -> void:
	_mesh_box(parent, node_name + "PostL", position + Vector3(-width * 0.5, height * 0.5, 0.0),
		Vector3(0.7, height, 0.9), post_material)
	_mesh_box(parent, node_name + "PostR", position + Vector3(width * 0.5, height * 0.5, 0.0),
		Vector3(0.7, height, 0.9), post_material)
	_mesh_box(parent, node_name + "Beam", position + Vector3(0.0, height, 0.0),
		Vector3(width + 0.8, 0.6, 1.0), glow_material)
	_mesh_torus(parent, node_name + "Ring", position + Vector3(0.0, height * 0.62, 0.0),
		width * 0.17, width * 0.21, glow_material, Vector3(90.0, 0.0, 0.0))
	var text := Label3D.new()
	text.name = node_name + "Label"
	text.text = label
	text.font_size = 230
	text.pixel_size = 0.0045
	text.outline_size = 34
	text.modulate = Color(1.0, 0.92, 0.55)
	text.outline_modulate = Color(0.04, 0.05, 0.12)
	text.position = position + Vector3(0.0, height + 0.85, 0.0)
	parent.add_child(text)


func _path_add(start: Vector3, end: Vector3, width: float, step: float = 3.0) -> void:
	var distance := start.distance_to(end)
	var steps := maxi(1, int(ceil(distance / step)))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var point := start.lerp(end, t) + Vector3.UP * 0.35
		if not _path.is_empty() and _path[_path.size() - 1].distance_to(point) < 0.06:
			continue
		_path.append(point)
		_widths.append(width)


func _add_checkpoint(course: Node3D, node_name: String, position: Vector3,
		yaw: float = 0.0) -> void:
	_obstacle(course, node_name, CHECKPOINT_SCENE, position,
		{"checkpoint_name": node_name.replace("CP", "Checkpoint ")}, yaw)


func _snow_particles(parent: Node3D, center: Vector3) -> void:
	var flake_mesh := SphereMesh.new()
	flake_mesh.radius = 0.055
	flake_mesh.height = 0.11
	flake_mesh.radial_segments = 6
	flake_mesh.rings = 3
	var flake_material := StandardMaterial3D.new()
	flake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_material.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	flake_mesh.material = flake_material
	var snow := CPUParticles3D.new()
	snow.name = "Snowfall"
	snow.amount = 300
	snow.lifetime = 18.0
	snow.preprocess = 10.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(70.0, 26.0, 150.0)
	snow.position = center + Vector3(0.0, 30.0, 0.0)
	snow.direction = Vector3(0.25, -1.0, 0.1)
	snow.spread = 18.0
	snow.gravity = Vector3(0.0, -0.9, 0.0)
	snow.initial_velocity_min = 0.4
	snow.initial_velocity_max = 1.5
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.4
	snow.color = Color(1.0, 1.0, 1.0, 0.8)
	snow.mesh = flake_mesh
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(snow)


# --------------------------------------------------------- ronda 3: glaciar

func _build_glacier() -> void:
	_path.clear()
	_widths.clear()
	_make_ice_palette()
	var cfg := {
		"sky_top": Color(0.08, 0.2, 0.32),
		"sky_horizon": Color(0.72, 0.82, 0.85),
		"sky_ground": Color(0.12, 0.22, 0.29),
		"cloud_color": Color(0.9, 0.93, 0.92),
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
		"cloud_opacity": 0.38,
		"cloud_scale": 2.1,
		"dome_z": -130.0,
	}
	_add_environment(cfg)
	_add_lights(cfg)
	_add_sky(cfg)

	var course := Node3D.new()
	course.name = "Course"
	add_child(course)

	# --- primera mitad: hielo, barridos y arena giratoria ------------------
	# Plataforma de salida profunda: la parrilla de la ronda 3 puede traer
	# nueve bots y las últimas filas no deben nacer fuera del hielo.
	_slab_top(course, "StartPlatform", 0.0, 1.0, 18.0, 24.0, 0.0, _ice)
	_path_add(Vector3(0.0, 0.0, 7.0), Vector3(0.0, 0.0, -6.0), 3.4)

	_slab_top(course, "IceBridge", 0.0, -16.0, 7.0, 18.0, 0.0, _ice_alt)
	_path_add(Vector3(0.0, 0.0, -7.0), Vector3(0.0, 0.0, -24.5), 2.2)

	_slab_top(course, "SweeperArena", 0.0, -34.0, 22.0, 19.0, 0.0, _ice)
	_path_add(Vector3(0.0, 0.0, -25.0), Vector3(0.0, 0.0, -43.0), 3.2)

	_ramp_z(course, "ClimbA", 0.0, -43.0, -51.0, 0.0, 3.0, 10.0, _ice_alt)
	_path_add(Vector3(0.0, 0.0, -43.0), Vector3(0.0, 3.0, -51.0), 2.6)

	_slab_top(course, "TerraceA", 0.0, -57.5, 12.0, 13.0, 3.0, _ice)
	_path_add(Vector3(0.0, 3.0, -51.5), Vector3(0.0, 3.0, -63.5), 2.6)

	var ice_lift :=	_obstacle(course, "IceLift", MOVING_SCENE, Vector3(0.0, 2.8, -64.0), {
		"travel": Vector3(0.0, 0.0, -9.2), "speed": 2.6, "pause_time": 0.4,
	})
	ice_lift.scale = Vector3(2.0, 1.0, 1.0)
	_path_add(Vector3(0.0, 3.0, -64.0), Vector3(0.0, 3.0, -74.5), 2.8)

	_slab_top(course, "MovingLanding", 0.0, -80.0, 12.0, 11.0, 3.0, _ice_alt)
	_path_add(Vector3(0.0, 3.0, -75.0), Vector3(0.0, 3.0, -84.8), 2.6)

	_slab_top(course, "SpinArena", 0.0, -96.0, 24.0, 21.0, 3.0, _ice)
	_path_add(Vector3(0.0, 3.0, -85.0), Vector3(0.0, 3.0, -106.0), 3.4)

	_ramp_z(course, "ClimbB", 0.0, -106.0, -114.0, 3.0, 7.0, 10.0, _ice_alt)
	_path_add(Vector3(0.0, 3.0, -106.0), Vector3(0.0, 7.0, -114.0), 2.6)

	# --- galería de pistones y puente de placas frágiles -------------------
	_slab_top(course, "IceGallery", 0.0, -124.0, 12.0, 20.0, 7.0, _ice)
	_path_add(Vector3(0.0, 7.0, -114.5), Vector3(0.0, 7.0, -133.0), 2.8)

	var tile_materials := [_ice, _ice_alt, _ice_white]
	for row in 4:
		for col in 3:
			_obstacle(course, "Crumble%d_%d" % [row, col], CRUMBLE_SCENE,
				Vector3(-3.4 + float(col) * 3.4, 7.0, -134.0 - float(row) * 3.0),
				{"tile_material": tile_materials[(row + col) % tile_materials.size()]})
	_path_add(Vector3(0.0, 7.0, -133.0), Vector3(0.0, 7.0, -144.5), 3.2)

	_slab_top(course, "GalleryLanding", 0.0, -149.5, 12.0, 10.0, 7.0, _ice_alt)
	_path_add(Vector3(0.0, 7.0, -145.0), Vector3(0.0, 7.0, -153.0), 2.6)

	_ramp_z(course, "ClimbC", 0.0, -153.0, -161.0, 7.0, 11.0, 10.0, _ice)
	_path_add(Vector3(0.0, 7.0, -153.0), Vector3(0.0, 11.0, -161.0), 2.6)

	# --- puente del vendaval ----------------------------------------------
	_slab_top(course, "GaleBridge", 0.0, -172.0, 5.5, 22.0, 11.0, _ice_dark)
	_path_add(Vector3(0.0, 11.0, -161.0), Vector3(0.0, 11.0, -183.0), 1.4)

	_slab_top(course, "GaleLanding", 0.0, -189.0, 12.0, 13.0, 11.0, _ice)
	_path_add(Vector3(0.0, 11.0, -184.0), Vector3(0.0, 11.0, -195.0), 2.8)

	# --- pasillo de rocas -------------------------------------------------
	_slab_top(course, "BoulderDeck", 0.0, -204.5, 11.0, 20.0, 11.0, _ice_alt)
	_path_add(Vector3(0.0, 11.0, -196.0), Vector3(0.0, 11.0, -214.0), 2.6)

	_ramp_z(course, "DropA", 0.0, -214.0, -222.0, 11.0, 7.0, 10.0, _ice)
	_path_add(Vector3(0.0, 11.0, -214.0), Vector3(0.0, 7.0, -222.0), 2.6)

	# --- terraza de pinchos y recta final ---------------------------------
	_slab_top(course, "SpikeTerrace", 0.0, -231.0, 13.0, 18.0, 7.0, _ice_alt)
	_path_add(Vector3(0.0, 7.0, -222.0), Vector3(0.0, 7.0, -240.0), 3.2)

	_slab_top(course, "FinalRun", 0.0, -250.0, 10.0, 20.0, 7.0, _ice)
	_path_add(Vector3(0.0, 7.0, -240.0), Vector3(0.0, 7.0, -260.0), 2.8)

	_ramp_z(course, "ClimbD", 0.0, -260.0, -267.0, 7.0, 10.0, 10.0, _ice_alt)
	_path_add(Vector3(0.0, 7.0, -260.0), Vector3(0.0, 10.0, -267.5), 2.8)

	_slab_top(course, "SummitPlatform", 0.0, -275.0, 16.0, 16.0, 10.0, _ice)
	_path_add(Vector3(0.0, 10.0, -267.5), Vector3(0.0, 10.0, -279.0), 3.4)

	# --- obstáculos -------------------------------------------------------
	_obstacle(course, "SweeperA", SWEEPER_SCENE, Vector3(0.0, 0.35, -30.0), {
		"spin_speed": 2.1, "push_force": 6.4, "stuns": true,
	})
	_obstacle(course, "SweeperB", SWEEPER_SCENE, Vector3(0.0, 0.35, -38.0), {
		"spin_speed": 2.5, "spin_direction": -1.0, "push_force": 6.8, "stuns": true,
	})
	_obstacle(course, "Centrifuge", SPIN_SCENE, Vector3(0.0, 2.845, -96.0), {
		"spin_speed": 2.0,
	})
	_obstacle(course, "BallRain", DROPPER_SCENE, Vector3(0.0, 9.5, -99.0), {
		"interval": 2.4, "drop_radius": 4.2, "max_balls": 5,
		"start_delay": 2.0, "column_spread": 2.0,
	})
	_obstacle(course, "PistonL", PISTON_SCENE, Vector3(-6.0, 7.0, -120.0), {
		"travel": Vector3(4.6, 0.0, 0.0), "push_force": 7.5, "phase_offset": 0.0,
	})
	_obstacle(course, "PistonR", PISTON_SCENE, Vector3(6.0, 7.0, -127.0), {
		"travel": Vector3(-4.6, 0.0, 0.0), "push_force": 7.5, "phase_offset": 2.2,
	})
	_obstacle(course, "WindA", WIND_SCENE, Vector3(0.0, 11.4, -168.0), {
		"wind_direction": Vector3(1.0, 0.0, 0.0), "strength": 4.8, "gust_amplitude": 1.7,
	})
	_obstacle(course, "WindB", WIND_SCENE, Vector3(0.0, 11.4, -178.0), {
		"wind_direction": Vector3(-1.0, 0.0, 0.0), "strength": 4.8, "gust_amplitude": 1.7,
	})
	_obstacle(course, "RotorA", ROTOR_SCENE, Vector3(0.0, 11.9, -171.0), {
		"spin_speed": 1.0, "phase_offset": 0.0,
	})
	_obstacle(course, "RotorB", ROTOR_SCENE, Vector3(0.0, 11.9, -175.5), {
		"spin_speed": 1.15, "spin_direction": -1.0, "phase_offset": 1.8,
	})
	_obstacle(course, "BoulderA", BOULDER_SCENE, Vector3(-3.0, 12.0, -211.0), {
		"travel": Vector3(0.0, 0.0, 15.0), "speed": 5.2, "phase_offset": 0.0,
	})
	_obstacle(course, "BoulderB", BOULDER_SCENE, Vector3(0.0, 12.0, -211.0), {
		"travel": Vector3(0.0, 0.0, 15.0), "speed": 5.8, "phase_offset": 2.0,
	})
	_obstacle(course, "BoulderC", BOULDER_SCENE, Vector3(3.0, 12.0, -211.0), {
		"travel": Vector3(0.0, 0.0, 15.0), "speed": 6.4, "phase_offset": 4.0,
	})
	for row in 3:
		for col in 4:
			_obstacle(course, "Spike%d_%d" % [row, col], SPIKE_SCENE,
				Vector3(-4.4 + float(col) * 2.9, 7.0, -226.5 - float(row) * 4.0),
				{"phase_offset": float(row) * 1.7 + float(col) * 0.6})
	_obstacle(course, "FinalBelt", CONVEYOR_SCENE, Vector3(0.0, 6.87, -250.0), {
		"direction": Vector3(0.0, 0.0, 1.0), "force": 3.8, "arrow_span": 2.2,
	})
	_obstacle(course, "SweeperFinalA", SWEEPER_SCENE, Vector3(0.0, 7.35, -245.0), {
		"spin_speed": 2.7, "push_force": 7.0, "stuns": true,
	})
	_obstacle(course, "SweeperFinalB", SWEEPER_SCENE, Vector3(0.0, 7.35, -255.0), {
		"spin_speed": 3.0, "spin_direction": -1.0, "push_force": 7.2, "stuns": true,
	})

	# --- checkpoints y meta ----------------------------------------------
	_add_checkpoint(course, "CP1", Vector3(0.0, 0.0, -24.0))
	_add_checkpoint(course, "CP2", Vector3(0.0, 3.0, -62.0))
	_add_checkpoint(course, "CP3", Vector3(0.0, 3.0, -84.0))
	_add_checkpoint(course, "CP4", Vector3(0.0, 3.0, -105.0))
	_add_checkpoint(course, "CP5", Vector3(0.0, 7.0, -124.0))
	_add_checkpoint(course, "CP6", Vector3(0.0, 7.0, -149.0))
	_add_checkpoint(course, "CP7", Vector3(0.0, 11.0, -189.0))
	_add_checkpoint(course, "CP8", Vector3(0.0, 7.0, -231.0))
	_add_checkpoint(course, "CP9", Vector3(0.0, 7.0, -258.0))
	_obstacle(course, "FinishLine", FINISH_SCENE, Vector3(0.0, 10.0, -276.0))

	# --- atrezo -----------------------------------------------------------
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	_arch(decor, "StartGate", Vector3(0.0, 0.0, -4.0), 18.0, 7.0, _ice_rock,
		_ice_glow, "GLACIER GALLOP")
	_arch(decor, "SummitGate", Vector3(0.0, 10.0, -271.0), 13.0, 6.0, _ice_rock,
		_ice_glow, "CUMBRE HELADA")
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (14.0 + float(i % 3) * 5.5)
		var z := -20.0 - float(i) * 28.0
		var height := 9.0 + float(i % 4) * 4.5
		_mesh_cylinder(decor, "IceSpire%d" % i, Vector3(x, -14.0 + height * 0.5, z),
			0.0, 2.0 + float(i % 3) * 0.7, height, _ice_glow, Vector3(0.0, 0.0, float(i) * 7.0))

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
		_mesh_cylinder(decor, "Iceberg%d" % i, Vector3(x, -13.0, z),
			1.2, 4.5 + float(i % 3), 12.0, _ice_white)
		_mesh_sphere(decor, "IcebergCap%d" % i, Vector3(x, -7.2, z),
			4.1 + float(i % 3), _ice_white)

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
		_mesh_box(decor, "Aurora%d" % i,
			Vector3(float(i - 1) * 55.0, 52.0 + float(i) * 9.0, -150.0),
			Vector3(120.0, 0.35, 16.0), aurora_material,
			Vector3(-8.0, float(i) * 24.0, 6.0))

	_snow_particles(decor, Vector3(0.0, 0.0, -130.0))
	var lights := [Vector3(0.0, 4.5, -34.0), Vector3(0.0, 7.5, -96.0),
		Vector3(0.0, 11.5, -124.0), Vector3(0.0, 15.5, -172.0),
		Vector3(0.0, 15.5, -205.0), Vector3(0.0, 11.5, -231.0),
		Vector3(0.0, 11.5, -250.0), Vector3(0.0, 14.5, -275.0)]
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
	_add_level_info({
		"level_id": "glacier_gallop",
		"display_name": "Glacier Gallop",
		"round_index": 3,
		"start_z": 5.0,
		"finish_z": -276.0,
		"course_length": 286.0,
		"gold_time": 135.0,
		"silver_time": 170.0,
		"bronze_time": 215.0,
		"start_position": Vector3(0.0, 0.0, 6.0),
		"path_corridor": false,
	})
	_add_race_manager()
	_add_hud()
	_add_kill_plane(Vector3(0.0, -12.0, -140.0))
	_add_player(Vector3(0.0, 0.6, 5.0))
	_add_director(5.0, -276.0, 286.0)
	_add_pause()


# ---------------------------------------------------------- ronda 4: volcán

func _build_volcano() -> void:
	_path.clear()
	_widths.clear()
	_make_volcano_palette()
	var cfg := {
		"sky_top": Color(0.025, 0.008, 0.035),
		"sky_horizon": Color(0.52, 0.12, 0.03),
		"sky_ground": Color(0.16, 0.02, 0.0),
		"cloud_color": Color(0.28, 0.08, 0.04),
		"sun_color": Color(1.0, 0.52, 0.2),
		"ambient": Color(0.95, 0.4, 0.18),
		"ambient_energy": 0.6,
		"fog": Color(0.45, 0.1, 0.03),
		"fog_density": 0.0032,
		"exposure": 0.95,
		"saturation": 1.22,
		"sun_pitch": -24.0,
		"sun_yaw": -62.0,
		"sun_energy": 1.25,
		"fill": Color(0.65, 0.16, 0.25),
		"fill_energy": 0.55,
		"cloud_opacity": 0.6,
		"cloud_scale": 3.2,
		"dome_z": -90.0,
	}
	_add_environment(cfg)
	_add_lights(cfg)
	_add_sky(cfg)

	var course := Node3D.new()
	course.name = "Course"
	add_child(course)

	# Salida recta: alinea al corredor con la cámara antes de entrar al círculo.
	# Plataforma de salida ancha: cubre la parrilla de bots y enlaza con la
	# primera rampa de la espiral sin dejar un hueco sobre la lava.
	_slab_top(course, "StartPlatform", -20.5, -75.0, 12.0, 40.0, V_START_TOP, _basalt)
	_path_add(Vector3(-18.0, V_START_TOP, -66.0),
		Vector3(-18.0, V_START_TOP, -91.0), 3.2)

	var step_angle := TAU / float(V_PER_TURN)
	var spiral_length := 0.0
	for i in V_SEGMENTS:
		var a0 := PI + float(i) * step_angle
		var a1 := a0 + step_angle
		var p0 := Vector3(V_CENTER.x + cos(a0) * V_RADIUS, 0.0,
			V_CENTER.z + sin(a0) * V_RADIUS)
		var p1 := Vector3(V_CENTER.x + cos(a1) * V_RADIUS, 0.0,
			V_CENTER.z + sin(a1) * V_RADIUS)
		var chord := p0.distance_to(p1)
		spiral_length += chord
		var top_mid := V_START_TOP + (float(i) + 0.5) * V_RISE
		var point := Vector3((p0.x + p1.x) * 0.5, top_mid,
			(p0.z + p1.z) * 0.5)
		_path.append(point + Vector3.UP * 0.35)
		_widths.append(2.4)

	var end_angle := PI + float(V_SEGMENTS) * step_angle
	var end_top := V_START_TOP + float(V_SEGMENTS) * V_RISE
	var end_position := Vector3(V_CENTER.x + cos(end_angle) * V_RADIUS, end_top,
		V_CENTER.z + sin(end_angle) * V_RADIUS)
	# La cumbre sigue la tangente de la espiral: la cámara ya apunta ahí, así
	# que la recta final no obliga a girar 90 grados de golpe.
	var end_tangent := Vector3(-sin(end_angle), 0.0, cos(end_angle))
	var summit := end_position + end_tangent * 7.0
	_path_add(end_position, summit + end_tangent * 3.0, 3.4)

	_slab_top(course, "SummitPlatform", summit.x, summit.z,
		18.0, 18.0, end_top, _basalt_hot)
	_build_spiral_deck(course)

	# Marcas de peligro en los tres saltos.
	for gap in V_GAPS:
		var sample := _spiral_sample(gap)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		var tangent := Vector3(-sin(sample_angle), 0.0, cos(sample_angle))
		for side in [-1.0, 1.0]:
			_mesh_box(course, "GapWarning%d_%d" % [gap, int(side)],
				sample_position + tangent * side * 1.9 + Vector3.UP * 0.03,
				Vector3(8.0, 0.06, 0.4), _volcano_glow,
				Vector3(0.0, -rad_to_deg(sample_angle), 0.0))

	# --- montaña, vetas y pináculos --------------------------------------
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	_arch(decor, "StartGate", Vector3(-18.0, V_START_TOP, -80.0), 12.0, 6.0,
		_volcano_rock, _volcano_glow, "LAVA VORTEX")
	# Un cono suave en vez de diez discos apilados: los discos parecían
	# plataformas gigantes en el borde derecho de la pista.
	_mesh_cylinder(decor, "Mountain",
		Vector3(V_CENTER.x, 52.0, V_CENTER.z), 4.6, 13.2, 108.0,
		_volcano_rock, Vector3.ZERO, 64)
	_mesh_cylinder(decor, "CraterGlow",
		Vector3(V_CENTER.x, 105.0, V_CENTER.z), 3.4, 3.4, 0.35,
		_volcano_glow, Vector3.ZERO, 40)
	for i in 7:
		var t := float(i + 1) / 8.0
		var radius := lerpf(12.4, 4.8, t)
		_mesh_torus(decor, "LavaVein%d" % i,
			Vector3(V_CENTER.x, 4.0 + t * 100.0, V_CENTER.z),
			radius * 0.94, radius * 1.02, _volcano_glow)
	for i in 16:
		var angle := TAU * float(i) / 16.0 + 0.19
		var distance := 32.0 + float(i % 4) * 6.0
		var height := 12.0 + float(i % 5) * 6.0
		_mesh_cylinder(decor, "ObsidianSpire%d" % i,
			Vector3(cos(angle) * distance, -16.0 + height * 0.5,
				V_CENTER.z + sin(angle) * distance),
			0.0, 2.2 + float(i % 3), height, _volcano_rock,
			Vector3(0.0, float(i) * 11.0, 0.0))
	for i in 6:
		var angle := PI * 0.35 + float(i) * 0.62
		var fall_y := 34.0 + float(i) * 10.0
		# Radio del cono a esa altura: las cascadas quedan pegadas a la
		# ladera en vez de flotar en el aire.
		var cone_t := clampf((fall_y + 2.0) / 108.0, 0.0, 1.0)
		var cone_radius := lerpf(13.2, 4.6, cone_t)
		var x := V_CENTER.x + cos(angle) * (cone_radius + 0.15)
		var z := V_CENTER.z + sin(angle) * (cone_radius + 0.15)
		var lava_fall := _volcano_glow
		_mesh_box(decor, "LavaFall%d" % i, Vector3(x, fall_y, z),
			Vector3(0.55, 16.0, 0.55), lava_fall)

	for i in 12:
		var angle := PI + float(i) * (TAU * 1.15 / 12.0)
		var height := V_START_TOP + float(i) * 8.0
		var light := OmniLight3D.new()
		light.name = "SpiralLight%d" % i
		light.position = Vector3(V_CENTER.x + cos(angle) * V_RADIUS,
			height + 3.0, V_CENTER.z + sin(angle) * V_RADIUS)
		light.light_color = Color(1.0, 0.42, 0.12)
		light.light_energy = 1.9
		light.omni_range = 16.0
		light.shadow_enabled = false
		decor.add_child(light)

	# Volcanes lejanos: dan profundidad al horizonte sin tocar la pista.
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.33
		var distance := 175.0 + float(i % 3) * 32.0
		var height := 42.0 + float(i % 4) * 16.0
		_mesh_cylinder(decor, "DistantPeak%d" % i,
			Vector3(cos(angle) * distance, -18.0 + height * 0.5,
				V_CENTER.z + sin(angle) * distance),
			0.0, 26.0 + float(i % 3) * 5.0, height, _volcano_rock,
			Vector3(0.0, float(i) * 37.0, 0.0))

	# Ceniza y chispas flotando alrededor de la montaña.
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.08
	ember_mesh.height = 0.16
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(1.0, 0.58, 0.12)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.3, 0.02)
	ember_material.emission_energy_multiplier = 2.6
	ember_mesh.material = ember_material
	var embers := CPUParticles3D.new()
	embers.name = "VolcanoEmbers"
	embers.amount = 260
	embers.lifetime = 10.0
	embers.preprocess = 5.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(42.0, 55.0, 42.0)
	embers.position = Vector3(V_CENTER.x, 55.0, V_CENTER.z)
	embers.direction = Vector3(0.0, 1.0, 0.0)
	embers.spread = 60.0
	embers.gravity = Vector3(0.0, 1.4, 0.0)
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 3.4
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 1.6
	embers.color = Color(1.0, 0.85, 0.6, 0.9)
	embers.mesh = ember_mesh
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(embers)

	# --- trampas de la espiral -------------------------------------------
	for i in [4, 8, 18, 28, 45, 52, 58, 82, 86, 96, 118, 122, 132]:
		var sample := _spiral_sample(i)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		var tangent := Vector3(-sin(sample_angle), 0.0, cos(sample_angle))
		for side in [-1.0, 1.0]:
			_obstacle(course, "Spike%d_%d" % [i, int(side)], SPIKE_SCENE,
				sample_position + tangent * side * 1.8 + Vector3.UP * 0.02,
				{"phase_offset": float(i) * 0.37 + side * 0.8},
				-sample_angle)

	for i in [10, 24, 54, 64, 90, 112, 126]:
		var sample := _spiral_sample(i)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		_obstacle(course, "Sweeper%d" % i, SWEEPER_SCENE,
			sample_position + Vector3.UP * 0.35, {
				"spin_speed": 2.4, "spin_direction": -1.0 if i % 2 == 0 else 1.0,
				"push_force": 7.0, "stuns": true,
			}, -sample_angle)

	for i in [6, 14, 30, 40, 56, 66, 84, 94, 116, 120, 134, 138]:
		var sample := _spiral_sample(i)
		var sample_position: Vector3 = sample["position"]
		var geyser := GEYSER_SCRIPT.new() as Node3D
		geyser.name = "Geyser%d" % i
		geyser.set("height", 7.0)
		geyser.set("radius", 1.5)
		geyser.set("phase_offset", float(i) * 0.31)
		geyser.position = sample_position
		course.add_child(geyser)

	# Aspas extra: añaden ritmo sin bloquear el paso, y el bot las espera
	# igual que en el resto de circuitos.
	for i in [16, 44, 62, 98]:
		var rotor_sample := _spiral_sample(i)
		var rotor_position: Vector3 = rotor_sample["position"]
		var rotor_angle: float = rotor_sample["angle"]
		_obstacle(course, "Rotor%d" % i, ROTOR_SCENE,
			rotor_position + Vector3.UP * 0.35, {
				"spin_speed": 1.05 + float(i % 3) * 0.12,
				"spin_direction": -1.0 if i % 2 == 0 else 1.0,
				"phase_offset": float(i) * 0.37,
			}, -rotor_angle)

	var checkpoints := [20, 48, 76, 104, 128, 140]
	for index in checkpoints.size():
		var sample := _spiral_sample(checkpoints[index])
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		_add_checkpoint(course, "CP%d" % (index + 1), sample_position,
			-sample_angle)

	_obstacle(course, "FinishLine", FINISH_SCENE,
		Vector3(summit.x, end_top, summit.z), {}, -end_angle)

	# --- esqueleto de la carrera -----------------------------------------
	var length := 32.0 + spiral_length + 10.0
	_add_level_info({
		"level_id": "lava_vortex",
		"display_name": "Lava Vortex",
		"round_index": 4,
		"start_z": -72.0,
		"finish_z": summit.z,
		"course_length": length,
		"gold_time": 105.0,
		"silver_time": 125.0,
		"bronze_time": 145.0,
		"start_position": Vector3(-20.5, V_START_TOP, -64.0),
		"path_corridor": true,
	})
	_add_race_manager()

	var lava := LAVA_RISE_SCRIPT.new() as Area3D
	lava.name = "LavaSea"
	lava.set("center_xz", V_CENTER)
	lava.set("surface_y", -8.0)
	lava.set("max_surface_y", 118.0)
	lava.set("radius", 62.0)
	lava.set("rise_speed", 0.75)
	add_child(lava)

	# En el origen: sus meteoros y avisos se colocan en coordenadas de mundo.
	var rain := METEOR_RAIN_SCRIPT.new() as Node3D
	rain.name = "MeteorRain"
	rain.set("interval", 3.2)
	rain.set("warn_time", 1.35)
	rain.set("spread", 4.5)
	add_child(rain)

	_add_hud()
	_add_kill_plane(Vector3(0.0, -34.0, -90.0))
	_add_player(Vector3(-18.0, V_START_TOP + 0.65, -64.0))
	# La espiral es la final: un poco más de punta de velocidad para que el
	# ritmo acompañe a una pista continua y a la lava que sube.
	var racer := get_node_or_null("Player") as Node3D
	if racer != null:
		racer.set("max_speed", float(racer.get("max_speed")) * 1.08)
	_add_director(-66.0, summit.z, length)
	_add_pause()


func _spiral_sample(index: int) -> Dictionary:
	var step_angle := TAU / float(V_PER_TURN)
	var angle := PI + (float(index) + 0.5) * step_angle
	var top := V_START_TOP + (float(index) + 0.5) * V_RISE
	var position := Vector3(V_CENTER.x + cos(angle) * V_RADIUS, top,
		V_CENTER.z + sin(angle) * V_RADIUS)
	return {"position": position, "top": top, "angle": angle}
