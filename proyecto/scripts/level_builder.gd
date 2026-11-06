@tool
extends Node3D

## Construye en runtime los tres circuitos nuevos:
##   level_kind = "glacier"  ->  Glacier Gallop (ronda 3)
##   level_kind = "volcano"  ->  Lava Vortex   (ronda 4)
##   level_kind = "ocean"    ->  Abyss Run     (carrera clásica)
##
## Los tres comparten el mismo esqueleto que las escenas antiguas (LevelInfo,
## RaceManager, HUD, KillPlane, RaceDirector, Player y pausa), pero la pista se
## genera aquí: el glaciar es un recorrido helado con saltos, placas frágiles y
## vendavales; el volcán es una espiral de seis vueltas alrededor de una montaña,
## con lava que sube, géiseres y lluvia de meteoros.
##
## La cámara del volcán gira con la espiral: sin eso, correr en línea recta con
## el stick dejaría al jugador mirando a la pared de la montaña.
##
## El script es `@tool`: al abrir la escena en el editor se genera el circuito
## completo marcando cada nodo generado con `owner`. Al guardar la escena
## (Ctrl+S), el mapa queda horneado en el `.tscn` y se edita elemento por
## elemento como main.tscn; desde entonces el generador no reconstruye nada
## (detecta el contenido guardado) y solo mantiene la cámara del volcán.

@export var level_kind: String = "glacier"

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/race/hud.tscn")
const KILL_SCENE := preload("res://scenes/race/kill_plane.tscn")
const PAUSE_SCENE := preload("res://scenes/menu/pause_menu.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/race/checkpoint.tscn")
const FINISH_SCENE := preload("res://scenes/race/finish_line.tscn")
const BOT_SCENE := preload("res://scenes/race/bot_racer.tscn")

const SWEEPER_SCENE := preload("res://scenes/obstacles/sweeper.tscn")
const ICE_ARENA_DRESSING := preload("res://scripts/ice_arena_dressing.gd")
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
const ICE_RAMPART_SCRIPT := preload("res://scripts/ice_rampart.gd")
const ASH_VORTEX_SCRIPT := preload("res://scripts/ash_vortex.gd")
const ICE_CREVASSE_SCRIPT := preload("res://scripts/ice_crevasse.gd")
const MAGMA_CURTAIN_SCRIPT := preload("res://scripts/magma_curtain.gd")
const WATER_ZONE_SCRIPT := preload("res://scripts/water_zone.gd")
const OCEAN_HAZARDS := preload("res://scripts/ocean_hazards.gd")

const PLATFORM_SHADER := preload("res://shaders/platform.gdshader")
const POST_SHADER := preload("res://shaders/post_process.gdshader")
const SKY_SHADER := preload("res://shaders/sky_clouds.gdshader")
const SEA_SHADER := preload("res://shaders/void_sea.gdshader")

## Volcán: círculo, vueltas y subida por segmento.
const V_CENTER := Vector3(0.0, 0.0, -90.0)
const V_RADIUS := 18.0
## La espiral se acortó al 80 % (144 -> 116 tramos): sigue teniendo cuatro
## vueltas y pico, pero se hace bastante más corta.
const V_SEGMENTS := 116
const V_PER_TURN := 28
const V_RISE := 0.7
const V_START_TOP := 1.05
const V_HALF_WIDTH := 4.0
const V_DECK_THICKNESS := 0.45
## Cortes de la espiral en tramos continuos. Los huecos 36, 72 y 108 son los
## tres saltos; cada tramo se construye como una sola malla, sin escalones.
const V_DECK_SECTIONS := [[0, 36], [37, 72], [73, 108], [109, 116]]
## Segmentos que se dejan sin plataforma: tres saltos sobre la lava.
const V_GAPS := [36, 72, 108]

## Muelle de la cámara del volcán. Amortiguación crítica (sin rebote): el giro
## arranca y frena solo, así pasa de una recta a la curva siguiente sin tirones.
const YAW_SPRING := 42.0
const YAW_DAMPING := 13.0
const PITCH_SPRING := 34.0
const PITCH_DAMPING := 11.7
const ROLL_SPRING := 26.0
const ROLL_DAMPING := 10.2

var _path: Array[Vector3] = []
var _widths: Array[float] = []
var _camera_spring: SpringArm3D
var _camera_base_pitch: float = 0.0
## Inclinación de la rampa del volcán y subida por metro. Sirven para apoyar
## los obstáculos planos en la cuesta en vez de dejarlos medio flotando.
var _ramp_slope: float = 0.0
var _ramp_rise_per_meter: float = 0.0
var _yaw_velocity: float = 0.0
var _pitch_velocity: float = 0.0
var _roll: float = 0.0
var _roll_velocity: float = 0.0

var _ice: ShaderMaterial
var _ice_alt: ShaderMaterial
var _ice_dark: ShaderMaterial
var _ice_white: ShaderMaterial
var _ice_glow: StandardMaterial3D
var _ice_spike: StandardMaterial3D
var _ice_rock: StandardMaterial3D

var _basalt: ShaderMaterial
var _basalt_hot: ShaderMaterial
var _volcano_rock: StandardMaterial3D
var _volcano_glow: StandardMaterial3D
var _volcano_spike: StandardMaterial3D
var _volcano_red: StandardMaterial3D
var _spiral_deck: StandardMaterial3D
var _spiral_rail: StandardMaterial3D

var _ocean_rock: StandardMaterial3D
var _ocean_rock_dark: StandardMaterial3D
var _ocean_sand: StandardMaterial3D
var _ocean_coral: StandardMaterial3D
var _ocean_coral_alt: StandardMaterial3D
var _ocean_glow: StandardMaterial3D
var _ocean_water: StandardMaterial3D
var _ocean_ray: StandardMaterial3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_editor_preview()
		return
	# Escena ya horneada: el circuito está guardado y no hay que generarlo.
	if get_child_count() > 0:
		_resume_baked()
		return
	if level_kind == "volcano":
		_build_volcano()
		set_process(true)
	elif level_kind == "ocean":
		_build_ocean()
	else:
		_build_glacier()


## Al abrir la escena en el editor se construye el circuito completo y se marca
## cada nodo generado con `owner`, para que Ctrl+S lo guarde en el `.tscn`. A
## partir de ahí la escena es un mapa normal (editable como main.tscn) y este
## método no vuelve a tocar nada.
func _build_editor_preview() -> void:
	if get_child_count() > 0:
		return
	if level_kind == "volcano":
		_build_volcano()
		set_process(false)
	elif level_kind == "ocean":
		_build_ocean()
	else:
		_build_glacier()
	if get_tree().edited_scene_root == self:
		_own_generated(self)


## Da `owner` a lo que crea el generador para que se guarde al salvar la escena.
## No entra en escenas instanciadas ni en nodos con script: su contenido se crea
## en `_ready` y se duplicaría si también se horneara.
func _own_generated(node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = self
		if child.scene_file_path.is_empty() and child.get_script() == null:
			_own_generated(child)


## Escena ya horneada: no se genera nada. Solo se recupera la ruta del volcán,
## que la cámara usa para seguir la espiral (la pendiente sale de las mismas
## constantes con las que se construyó la rampa).
func _resume_baked() -> void:
	if level_kind != "volcano":
		return
	set_process(true)
	var ramp_chord := (TAU / float(V_PER_TURN)) * V_RADIUS
	_ramp_slope = atan2(V_RISE, ramp_chord)
	var info := get_node_or_null("LevelInfo") as LevelInfo
	if info == null:
		return
	_path.clear()
	_widths.clear()
	for point in info.waypoints:
		_path.append(point)
	for width in info.lane_widths:
		_widths.append(width)


## Giro automático de cámara en Lava Vortex. Desactivado: ahora el ratón manda
## sobre el encuadre (ver `player.gd`). Se conserva el código por si se quiere
## recuperar el seguimiento de la espiral.
const CAMERA_FOLLOW_TRACK := false


## La cámara del jugador sigue la pista por delante de la espiral. Es una ayuda
## de control: el stick hacia delante sigue la cuesta en vez de salirse por
## fuera, y el encuadre queda centrado en el tramo que sube.
func _process(delta: float) -> void:
	if not CAMERA_FOLLOW_TRACK or Engine.is_editor_hint() or level_kind != "volcano":
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
	# al entrar en la espiral sigue la tangente. El muelle llega antes que un
	# lerp lento y no corta el giro: siempre se ve la pista recta delante.
	var inside := player.global_position.z <= V_CENTER.z + 0.5
	var target_yaw := _path_yaw_at(player.global_position)
	var yaw_error := wrapf(target_yaw - pivot.rotation.y, -PI, PI)
	_yaw_velocity += yaw_error * YAW_SPRING * delta
	_yaw_velocity *= exp(-YAW_DAMPING * delta)
	pivot.rotation.y = wrapf(pivot.rotation.y + _yaw_velocity * delta, -PI, PI)
	if _camera_spring != null:
		# La pista sube: la cámara inclina el encuadre con la cuesta. Antes
		# compensaba solo el 40 %, así que en las rampas parecía ir recta.
		var target_pitch := _camera_base_pitch + _ramp_slope if inside else _camera_base_pitch
		_pitch_velocity += (target_pitch - _camera_spring.rotation.x) * PITCH_SPRING * delta
		_pitch_velocity *= exp(-PITCH_DAMPING * delta)
		_camera_spring.rotation.x += _pitch_velocity * delta
		# Sin alabeo: el horizonte se queda plano y la cuesta se ve de frente en
		# vez de inclinada hacia un lado al trazar la curva.
		_roll_velocity += (0.0 - _roll) * ROLL_SPRING * delta
		_roll_velocity *= exp(-ROLL_DAMPING * delta)
		_roll = clampf(_roll + _roll_velocity * delta, -0.1, 0.1)
		_camera_spring.rotation.z = _roll


## Metros de pista que la cámara mira por delante del corredor.
const CAMERA_LOOK_AHEAD := 9.0


## Rumbo de la cámara tomado de la propia ruta, no del ángulo polar. Apunta a
## un punto unos metros por delante: así el tramo que sube queda centrado en
## pantalla en vez de escorarse hacia un lado al entrar en la curva. En la
## cumbre el jugador ya no está sobre el círculo y la tangente del último tramo
## mantiene el encuadre hasta la meta.
func _path_yaw_at(position: Vector3) -> float:
	if _path.size() < 2:
		return 0.0
	var best := 0
	var best_distance := INF
	for i in _path.size():
		var dx := _path[i].x - position.x
		var dy := _path[i].y - position.y
		var dz := _path[i].z - position.z
		# La espiral pasa varias veces por el mismo sitio: sin la altura se
		# elegiría un punto de otra vuelta.
		var d := dx * dx + dz * dz + dy * dy * 2.0
		if d < best_distance:
			best_distance = d
			best = i
	var aim := _path[best]
	var travelled := 0.0
	var index := best
	while index < _path.size() - 1 and travelled < CAMERA_LOOK_AHEAD:
		travelled += _path[index].distance_to(_path[index + 1])
		index += 1
		aim = _path[index]
	var dir := Vector2(aim.x - position.x, aim.z - position.z)
	if dir.length_squared() < 0.25:
		# Ya no queda pista por delante: se usa la tangente final.
		var a := _path[maxi(best - 1, 0)]
		var b := _path[mini(best + 1, _path.size() - 1)]
		dir = Vector2(b.x - a.x, b.z - a.z)
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
	# Pinchos de hielo: blancos y poco emisivos, para que no sean el único
	# dorado de un mapa azul (era lo que más cantaba del circuito).
	_ice_spike = _glow_mat(Color(0.74, 0.9, 0.95), 0.3, 0.24)
	_ice_rock = _rock_mat(Color(0.2, 0.3, 0.36), Color(0.06, 0.14, 0.18), 0.1)


func _make_volcano_palette() -> void:
	_basalt = _platform_mat(Color(0.16, 0.07, 0.06), Color(1.0, 0.5, 0.12),
		Color(0.03, 0.015, 0.015), 0.5)
	_basalt_hot = _platform_mat(Color(0.24, 0.09, 0.04), Color(1.0, 0.68, 0.22),
		Color(0.05, 0.02, 0.01), 0.62)
	_volcano_rock = _rock_mat(Color(0.09, 0.05, 0.045), Color(0.8, 0.18, 0.03), 0.55)
	_volcano_glow = _glow_mat(Color(1.0, 0.38, 0.06), 3.0)
	# Pinchos de basalto incandescente: encajan con la roca volcánica.
	_volcano_spike = _glow_mat(Color(0.5, 0.18, 0.08), 0.6, 0.32)
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


func _add_kill_plane(position: Vector3, fail_run: bool = false) -> void:
	var kill := KILL_SCENE.instantiate() as Node3D
	kill.name = "KillPlane"
	kill.position = position
	# Bien largo en Z: cubre el circuito entero, no solo el tramo del centro.
	kill.scale = Vector3(1.7, 1.0, 2.2)
	if fail_run:
		kill.set("fail_run", true)
	add_child(kill)


func _add_player(start: Vector3, jump_velocity: float = 0.0) -> void:
	var player := PLAYER_SCENE.instantiate() as Node3D
	player.name = "Player"
	player.position = start
	# Salto a medida del nivel: si se pasa un impulso se ajusta también el
	# salto corto en la misma proporción para no romper el tacto.
	if jump_velocity > 0.0:
		player.set("jump_velocity", jump_velocity)
		player.set("min_jump_velocity", jump_velocity * 0.3665)
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


## Pared de hielo con colisión: cierra una arena para que los obstáculos se
## crucen por el centro en vez de rodearlos por los bordes de la plataforma.
func _ice_wall(parent: Node3D, node_name: String, center: Vector3,
		size: Vector3) -> StaticBody3D:
	return _slab(parent, node_name, center, size, _ice_dark)


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
		position: Vector3, values: Dictionary = {}, yaw: float = 0.0,
		pitch: float = 0.0) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.position = position
	node.rotation = Vector3(pitch, yaw, 0.0)
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
	# (Los aros flotantes del arco se han quitado: no pegaban con ningún mapa.)
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


## ¿Cabe el atrezo aquí? Falso si un adorno de radio `radius` caería sobre (o
## pegado a) una plataforma y quedaría dentro de la vista del corredor.
func _ice_clear(x: float, z: float, radius: float) -> bool:
	for i in ICE_SLABS.size():
		var slab: Vector4 = ICE_SLABS[i]
		if absf(x - slab.x) <= slab.y + radius + 0.6 \
				and absf(z - slab.z) <= slab.w + radius + 0.6:
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
	add_child(course)

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

	var ice_lift :=	_obstacle(course, "IceLift", MOVING_SCENE, Vector3(0.0, 2.8, -66.0), {
		"travel": Vector3(0.0, 0.0, -6.5), "speed": 2.6, "pause_time": 0.4,
	})
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
		"3_0": true, "4_2": true, "6_0": true, "8_2": true,
		"10_0": true, "11_2": true, "13_0": true,
	}
	var tile_materials := [_ice, _ice_alt, _ice_white]
	for row in 14:
		for col in 3:
			if holes.has("%d_%d" % [row, col]):
				continue
			_obstacle(course, "Crumble%d_%d" % [row, col], CRUMBLE_SCENE,
				Vector3(-3.4 + float(col) * 3.4, 7.0, -168.0 - float(row) * 3.0),
				{"tile_material": tile_materials[(row + col) % tile_materials.size()],
				"warn_time": 0.5})
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
	_obstacle(course, "SweeperA", SWEEPER_SCENE, Vector3(0.0, 0.35, -30.0), {
		"spin_speed": 2.1, "push_force": 6.4, "stuns": true, "arm_length": 15.9,
	})
	_obstacle(course, "SweeperB", SWEEPER_SCENE, Vector3(0.0, 0.35, -38.0), {
		"spin_speed": 2.5, "spin_direction": -1.0, "push_force": 6.8, "stuns": true,
		"arm_length": 15.9,
	})
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
			var disc := _obstacle(course, disc_name, SPIN_SCENE,
				Vector3(x, 2.845, z), {
					"spin_speed": 1.1 + float(disc_index % 3) * 0.25,
					"glow": false,
				})
			if disc_index % 2 == 1:
				disc.set("spin_speed", -float(disc.get("spin_speed")))
			_obstacle(course, "BallRain%d" % disc_index, DROPPER_SCENE,
				Vector3(x, 9.5, z), {
					"interval": 1.0, "interval_variance": 0.2,
					"drop_radius": 2.2, "max_balls": 3,
					"start_delay": 1.0 + float(disc_index) * 0.1,
					"column_spread": 2.0, "ball_color": ball_color,
				})
			disc_index += 1
		# Corriente de aire entre discos: empuja de lado y obliga a corregir la
		# trazada. Sin ventilador ni peana: la máquina de colores se veía fuera
		# de lugar dentro de la arena, así que solo queda el aire.
		if r > 0 and r != 3:
			_obstacle(course, "SpinGust%d" % r, WIND_SCENE, Vector3(0.0, 5.6, z), {
				"wind_direction": Vector3(1.0 if r % 4 == 1 else -1.0, 0.0, 0.0),
				"strength": 4.2 + float(r % 3) * 0.4,
				"gust_amplitude": 1.8,
				"show_fan": false,
			})
	# Palos largos en las costuras entre discos: el hueco de cinco centímetros
	# deja de ser una línea segura y hay que zigzaguear también por las juntas.
	for px in [-4.0, 4.0]:
		for pz in [-92.0, -100.0, -108.0, -116.0, -124.0]:
			var pole_name := "SeamPole%s%s" % [("L" if px < 0.0 else "R"), str(int(-pz))]
			_slab(course, pole_name, Vector3(px, 5.1, pz),
				Vector3(0.34, 4.2, 0.34), _ice_rock)
			_mesh_sphere(course, pole_name + "Cap", Vector3(px, 7.25, pz),
				0.24, _ice_glow)
	# Galería estrecha con todo el suelo en marcha atrás: hay que avanzar contra
	# la cinta mientras se esquivan los cubos que salen de las paredes.
	_obstacle(course, "GalleryConveyor", CONVEYOR_SCENE, Vector3(0.0, 6.87, -156.0), {
		"direction": Vector3(0.0, 0.0, 1.0), "force": 3.4,
		"belt_length": 12.0, "belt_width": 26.0,
		"arrow_count": 3, "arrow_span": 5.0,
	})
	# Galería estrecha: cinco pistones por pared, alternando lados, barren casi
	# todo el ancho del carril.
	for i in 5:
		var piston_z := -146.0 - float(i) * 4.5
		var phase := float(i) * 0.7
		_obstacle(course, "PistonL" if i == 0 else "PistonL%d" % (i + 1), PISTON_SCENE,
			Vector3(-5.2, 8.2, piston_z), {
				"travel": Vector3(5.4, 0.0, 0.0), "push_force": 7.2,
				"phase_offset": phase,
			})
		_obstacle(course, "PistonR" if i == 0 else "PistonR%d" % (i + 1), PISTON_SCENE,
			Vector3(5.2, 8.2, piston_z), {
				"travel": Vector3(-5.4, 0.0, 0.0), "push_force": 7.2,
				"phase_offset": phase + 1.73,
			})
	_obstacle(course, "WindA", WIND_SCENE, Vector3(0.0, 11.4, -235.0), {
		"wind_direction": Vector3(1.0, 0.0, 0.0), "strength": 4.8, "gust_amplitude": 1.7,
		"show_fan": false,
	})
	_obstacle(course, "WindB", WIND_SCENE, Vector3(0.0, 11.4, -246.0), {
		"wind_direction": Vector3(-1.0, 0.0, 0.0), "strength": 4.8, "gust_amplitude": 1.7,
		"show_fan": false,
	})
	_obstacle(course, "RotorA", ROTOR_SCENE, Vector3(0.0, 11.9, -238.0), {
		"spin_speed": 1.0, "phase_offset": 0.0,
	})
	_obstacle(course, "RotorB", ROTOR_SCENE, Vector3(0.0, 11.9, -243.5), {
		"spin_speed": 1.15, "spin_direction": -1.0, "phase_offset": 1.8,
	})
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
		var rock := _obstacle(course, "Boulder%s" % String.chr(65 + i),
			BOULDER_SCENE, Vector3(float(data["x"]), 11.0 + size, -278.5), {
				"travel": data["travel"], "speed": data["speed"],
				"phase_offset": data["phase"], "radius": size,
			})
		# La bola crece de verdad: malla, choque, área de empuje y aro de salida.
		var rock_ball := rock.get_node_or_null("Ball") as Node3D
		if rock_ball != null:
			rock_ball.scale = Vector3.ONE * size
		var rock_ring := rock.get_node_or_null("SpawnRing") as Node3D
		if rock_ring != null:
			rock_ring.scale = Vector3.ONE * size
	# Barrido lento en mitad del pasillo: la roca te empuja a un lado y el brazo
	# al otro, así que el tramo deja de ser una recta con tres bolas.
	_obstacle(course, "BoulderSweeper", SWEEPER_SCENE, Vector3(0.0, 11.35, -272.5), {
		"spin_speed": 1.15, "push_force": 4.6, "stuns": false,
	})
	# Lluvia de bolas sobre el pasillo: obliga a mirar arriba entre roca y roca.
	_obstacle(course, "BoulderRain", DROPPER_SCENE, Vector3(0.0, 17.6, -272.5), {
		"interval": 1.3, "drop_radius": 2.4, "max_balls": 3,
		"start_delay": 1.0, "column_spread": 2.6, "chute_count": 3,
		"ball_color": ball_color,
	})
	# Terraza de pinchos el doble de larga: seis filas alternas.
	for row in 6:
		for col in 4:
			_obstacle(course, "Spike%d_%d" % [row, col], SPIKE_SCENE,
				Vector3(-4.4 + float(col) * 2.9, 7.0, -295.0 - float(row) * 4.0),
				{"phase_offset": float(row) * 1.7 + float(col) * 0.6})
	_obstacle(course, "FinalBelt", CONVEYOR_SCENE, Vector3(0.0, 6.87, -330.0), {
		"direction": Vector3(0.0, 0.0, 1.0), "force": 3.8, "arrow_span": 2.2,
	})
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
	add_child(decor)
	_arch(decor, "StartGate", Vector3(0.0, 0.0, -4.0), 18.0, 7.0, _ice_rock,
		_ice_glow, "GLACIER GALLOP")
	_arch(decor, "SummitGate", Vector3(0.0, 10.0, -351.0), 13.0, 6.0, _ice_rock,
		_ice_glow, "CUMBRE HELADA")
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (21.0 + float(i % 3) * 5.5)
		var z := -20.0 - float(i) * 28.0
		var height := 9.0 + float(i % 4) * 4.5
		_mesh_cylinder(decor, "IceSpire%d" % i, Vector3(x, -14.0 + height * 0.5, z),
			0.0, 2.0 + float(i % 3) * 0.7, height, _ice_glow, Vector3(0.0, 0.0, float(i) * 7.0))

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

	# Sierra lejana: cierra el horizonte helado sin acercarse a la pista.
	for i in 10:
		var ring_angle := TAU * float(i) / 10.0 + 0.4
		var ring_distance := 190.0 + float(i % 3) * 35.0
		var ring_height := 55.0 + float(i % 4) * 22.0
		_mesh_cylinder(decor, "DistantPeak%d" % i,
			Vector3(cos(ring_angle) * ring_distance, -18.0 + ring_height * 0.5,
				-140.0 + sin(ring_angle) * ring_distance),
			0.0, 30.0 + float(i % 3) * 8.0, ring_height, _ice_white,
			Vector3(0.0, float(i) * 31.0, 0.0))

	# Cristales de hielo en los bordes de las plataformas anchas: dan el toque
	# helado sin meterse en la trazada.
	var crystal_spots := [
		Vector3(-7.2, 0.0, -31.0), Vector3(7.2, 0.0, -37.0),
		Vector3(-12.4, 5.7, -88.0), Vector3(12.4, 5.7, -104.0),
		Vector3(-12.4, 5.7, -126.0), Vector3(12.4, 5.7, -134.0),
		Vector3(-5.4, 7.0, -148.0), Vector3(5.4, 7.0, -164.0),
		Vector3(-8.1, 11.0, -234.0), Vector3(8.1, 11.0, -244.0),
		Vector3(-5.9, 7.0, -272.5), Vector3(5.9, 7.0, -288.0),
		Vector3(-5.9, 7.0, -302.0), Vector3(5.9, 7.0, -314.0),
		Vector3(-4.6, 7.0, -322.0), Vector3(4.6, 7.0, -338.0),
	]
	for i in crystal_spots.size():
		var spot: Vector3 = crystal_spots[i]
		var tall := 1.8 + float(i % 3) * 0.9
		_mesh_cylinder(decor, "IceCrystal%d" % i,
			spot + Vector3(0.0, tall * 0.5 - 0.2, 0.0), 0.0, 0.5, tall,
			_ice_spike, Vector3(float(i) * 9.0, float(i) * 23.0, 0.0), 6)
		_mesh_cylinder(decor, "IceCrystalSmall%d" % i,
			spot + Vector3(0.9 if i % 2 == 0 else -0.9, 0.55, 0.5),
			0.0, 0.3, 1.1, _ice_glow, Vector3(0.0, 0.0, 18.0), 6)

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
			_mesh_box(decor, "ArchPillar%d_%d" % [i, int(side)],
				Vector3(x, spot.y + tall * 0.5, spot.z),
				Vector3(0.7, tall, 0.7), _ice_rock, Vector3(0.0, float(i) * 7.0, 0.0))
		_mesh_box(decor, "ArchBeam%d" % i,
			Vector3(spot.x, spot.y + tall + 0.25, spot.z),
			Vector3(span + 0.7, 0.5, 0.55), _ice_rock)
		_mesh_box(decor, "ArchGlow%d" % i,
			Vector3(spot.x, spot.y + tall - 0.05, spot.z + 0.3),
			Vector3(span - 0.6, 0.09, 0.12), _ice_glow)

	# Cataratas congeladas y témpanos flotando: fondo, fuera de la trazada.
	for i in 7:
		var fall_angle := TAU * float(i) / 7.0 + 0.2
		var fall_distance := 120.0 + float(i % 3) * 22.0
		var fall_height := 46.0 + float(i % 4) * 12.0
		_mesh_box(decor, "FrozenFall%d" % i,
			Vector3(cos(fall_angle) * fall_distance, fall_height * 0.5 - 16.0,
				-185.0 + sin(fall_angle) * fall_distance),
			Vector3(1.6, fall_height, 1.6), _ice_glow, Vector3(0.0, 0.0, 8.0))
	for i in 6:
		var floe_angle := TAU * float(i) / 6.0 + 0.9
		var floe_distance := 62.0 + float(i % 2) * 30.0
		var floe_y := 26.0 + float(i % 3) * 9.0
		_mesh_sphere(decor, "FloatingFloe%d" % i,
			Vector3(cos(floe_angle) * floe_distance, floe_y,
				-190.0 + sin(floe_angle) * floe_distance),
			5.5 + float(i % 3), _ice_white)

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
		_mesh_box(decor, "GlacierWall%d" % i,
			Vector3(float(i - 1) * 190.0, 19.0, -560.0 - float(i) * 34.0),
			Vector3(230.0, 58.0, 6.0), _ice_white,
			Vector3(0.0, float(i - 1) * 9.0, 0.0))
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var height := 30.0 + float(i % 4) * 14.0
		var cathedral_x := cos(angle) * 95.0
		var cathedral_z := -300.0 + sin(angle) * 70.0
		# Dos de estas torres caían justo sobre las repisas del vendaval y
		# sobre la cumbre: eran las «montañas» que se veían dentro del hielo.
		if not _ice_clear(cathedral_x, cathedral_z, 7.5):
			continue
		_mesh_cylinder(decor, "IceCathedral%d" % i,
			Vector3(cathedral_x, -18.0 + height * 0.5, cathedral_z),
			0.0, 7.5, height, _ice_white, Vector3(0.0, float(i) * 22.0, 0.0), 6)
	# Banderines: solo en el borde de las plataformas anchas, nunca dentro de la
	# trazada (antes salían en mitad del hielo y sobre los discos del teclado).
	var banner_spots := [
		Vector3(-8.6, 0.0, -6.0), Vector3(8.6, 0.0, -16.0),
		Vector3(-8.6, 0.0, -26.0), Vector3(8.6, 0.0, -38.0),
		Vector3(-4.6, 3.0, -53.5), Vector3(4.6, 3.0, -61.0),
		Vector3(-12.4, 5.7, -86.0), Vector3(12.4, 5.7, -118.0),
		Vector3(-5.4, 7.0, -146.0), Vector3(5.4, 7.0, -166.0),
		Vector3(-5.4, 7.0, -210.0), Vector3(5.4, 7.0, -218.0),
		Vector3(-7.8, 11.0, -231.5), Vector3(7.8, 11.0, -246.5),
		Vector3(-5.4, 11.0, -253.0), Vector3(5.4, 11.0, -258.0),
		Vector3(-4.9, 11.0, -268.0), Vector3(4.9, 11.0, -278.0),
		Vector3(-6.0, 7.0, -294.0), Vector3(6.0, 7.0, -312.0),
		Vector3(-4.4, 7.0, -324.0), Vector3(4.4, 7.0, -335.0),
		Vector3(-7.6, 10.0, -349.0), Vector3(7.6, 10.0, -361.0),
	]
	for i in banner_spots.size():
		var spot: Vector3 = banner_spots[i]
		var side := -1.0 if spot.x < 0.0 else 1.0
		_mesh_box(decor, "BannerPost%d" % i,
			spot + Vector3(0.0, 2.4, 0.0), Vector3(0.16, 4.8, 0.16), _ice_rock)
		_mesh_box(decor, "BannerCloth%d" % i,
			spot + Vector3(-side * 0.7, 3.9, 0.0), Vector3(1.3, 1.7, 0.06), _ice_glow,
			Vector3(0.0, 0.0, side * 8.0))
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var drift_x := cos(angle) * (30.0 + float(i % 4) * 6.0)
		var drift_z := -150.0 + sin(angle) * (70.0 + float(i % 3) * 12.0)
		var drift_radius := 3.4 + float(i % 3)
		# Ningún montículo asoma por encima de una losa: antes uno de estos
		# sobresalía del hielo de aterrizaje y parecía una montaña en la pista.
		if not _ice_clear(drift_x, drift_z, drift_radius):
			continue
		_mesh_sphere(decor, "SnowDrift%d" % i, Vector3(drift_x, -1.6, drift_z),
			drift_radius, _ice_white)
	# --- segunda pasada de atrezo: hielo por todas partes -------------------
	for i in 18:
		var z := -20.0 - float(i) * 19.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var lip_x := side * (6.5 + float(i % 3) * 2.0)
		for k in 3:
			var tall := 1.2 + float((i + k) % 3) * 0.6
			_mesh_cylinder(decor, "Icicle%d_%d" % [i, k],
				Vector3(lip_x + float(k) * 0.5, -tall * 0.5, z + float(k) * 0.6),
				0.0, 0.16, tall, _ice_glow, Vector3(180.0, 0.0, 0.0), 6)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var distance := 40.0 + float(i % 4) * 12.0
		_mesh_box(decor, "Shard%d" % i,
			Vector3(cos(angle) * distance, 18.0 + float(i % 5) * 7.0,
				-170.0 + sin(angle) * (80.0 + float(i % 3) * 20.0)),
			Vector3(2.2, 7.5, 2.2), _ice_white,
			Vector3(float(i) * 14.0, float(i) * 27.0, float(i) * 9.0))
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.5
		_mesh_box(decor, "FarArch%d" % i,
			Vector3(cos(angle) * 55.0, 26.0, -200.0 + sin(angle) * 55.0),
			Vector3(26.0, 2.2, 4.0), _ice_white,
			Vector3(0.0, rad_to_deg(-angle), 0.0))
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
		_mesh_cylinder(decor, "FrozenGeyser%d" % i,
			Vector3(geyser_x, -18.0 + tall * 0.5, geyser_z),
			0.4, 2.6, tall, _ice_glow, Vector3.ZERO, 8)

	# Pilonos bajo las dos repisas del vendaval: dejan de parecer que flotan y
	# añaden detalle debajo de la pista, sin tapar la línea de visión.
	var gale_pylons := [
		Vector2(-7.4, -230.5), Vector2(-2.6, -238.0),
		Vector2(2.6, -238.5), Vector2(7.4, -247.5),
	]
	for i in gale_pylons.size():
		var spot: Vector2 = gale_pylons[i]
		_mesh_cylinder(decor, "GalePylon%d" % i, Vector3(spot.x, 3.0, spot.y),
			0.7, 1.1, 16.0, _ice_dark, Vector3.ZERO, 8)
		_mesh_sphere(decor, "GalePylonBase%d" % i, Vector3(spot.x, -4.7, spot.y),
			1.6, _ice_rock)
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		_mesh_cylinder(decor, "GaleIcicle%d" % i,
			Vector3(side * (3.2 + float(i % 3) * 1.5), 10.4, -229.5 - float(i) * 2.6),
			0.0, 0.2, 1.5, _ice_glow, Vector3(180.0, 0.0, 0.0), 6)

	_ice_mist(decor, Vector3(0.0, -6.0, -160.0), 240)
	_ice_mist(decor, Vector3(0.0, -12.0, -300.0), 160)
	_ice_stars(decor, Vector3(0.0, 70.0, -220.0))

	_snow_particles(decor, Vector3(0.0, 0.0, -176.0))
	var lights := [Vector3(0.0, 4.5, -34.0), Vector3(0.0, 7.5, -96.0),
		Vector3(-18.0, 7.5, -111.0), Vector3(18.0, 7.5, -111.0),
		Vector3(0.0, 7.5, -131.0), Vector3(0.0, 11.5, -156.0),
		Vector3(0.0, 15.5, -239.0), Vector3(0.0, 15.5, -272.5),
		Vector3(0.0, 11.5, -305.0), Vector3(0.0, 11.5, -330.0),
		Vector3(0.0, 14.5, -355.0)]
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
		"finish_z": -357.0,
		"course_length": 367.0,
		"gold_time": 145.0,
		"silver_time": 180.0,
		"bronze_time": 225.0,
		"start_position": Vector3(0.0, 0.0, 6.0),
		"path_corridor": false,
	})
	_add_race_manager()
	_add_hud()
	_add_kill_plane(Vector3(0.0, -12.0, -180.0))
	# Salto flojo del glaciar: 5.02 de impulso deja el salto en el 70 % de la
	# altura que da el salto por defecto (6.0) sin cambiar el resto del control.
	_add_player(Vector3(0.0, 0.6, 5.0), 5.02)
	_add_director(5.0, -357.0, 367.0)
	_add_pause()


# ---------------------------------------------------------- ronda 4: volcán

## ¿Está libre ese adorno del volcán? Ni sobre la plataforma de salida ni sobre
## el ancho de la espiral a la altura que le toca: eran las «montañas» que
## salían dentro de la losa de salida y tapaban la vista de la pista.
func _volcano_clear(x: float, z: float, radius: float, y0: float, y1: float) -> bool:
	# Plataforma de salida: centrada en x = -18, 12 x 40.
	if absf(x + 18.0) < 6.0 + radius + 0.8 \
			and absf(z + 75.0) < 20.0 + radius + 0.8 \
			and y1 > V_START_TOP - 0.8 and y0 < V_START_TOP + 4.5:
		return false
	# Anillo de la espiral, con un cinturón de aire a cada lado.
	var planar := Vector2(x - V_CENTER.x, z - V_CENTER.z)
	var distance := planar.length()
	if distance + radius < V_RADIUS - V_HALF_WIDTH - 0.8 \
			or distance - radius > V_RADIUS + V_HALF_WIDTH + 0.8:
		return true
	var step_angle := TAU / float(V_PER_TURN)
	var base_seg := (atan2(planar.y, planar.x) - PI) / step_angle
	var turns := ceili(float(V_SEGMENTS) / float(V_PER_TURN)) + 1
	for turn in turns:
		var index := base_seg + float(turn * V_PER_TURN)
		if index < 0.0 or index > float(V_SEGMENTS):
			continue
		var deck_top := V_START_TOP + index * V_RISE
		if y1 > deck_top - 0.6 and y0 < deck_top + 3.6:
			return false
	return true


func _build_volcano() -> void:
	_path.clear()
	_widths.clear()
	_make_volcano_palette()
	# Pendiente de la rampa: con ella se tumban los obstáculos y las luces de
	# la pista para que queden apoyados, no de pie sobre una cuesta.
	var ramp_chord := (TAU / float(V_PER_TURN)) * V_RADIUS
	_ramp_slope = atan2(V_RISE, ramp_chord)
	_ramp_rise_per_meter = V_RISE / ramp_chord
	var cfg := {
		"sky_top": Color(0.05, 0.025, 0.025),
		"sky_horizon": Color(0.6, 0.17, 0.04),
		"sky_ground": Color(0.16, 0.02, 0.0),
		"cloud_color": Color(0.28, 0.08, 0.04),
		"sun_color": Color(1.0, 0.52, 0.2),
		"ambient": Color(0.95, 0.4, 0.18),
		"ambient_energy": 0.6,
		"fog": Color(0.45, 0.1, 0.03),
		"fog_density": 0.0032,
		"exposure": 0.95,
		"saturation": 1.05,
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
	# La plataforma va centrada con la entrada de la espiral (x = -18): antes
	# estaba corrida a la izquierda y se salía por un lado de la pista.
	_slab_top(course, "StartPlatform", -18.0, -75.0, 12.0, 40.0, V_START_TOP, _basalt)
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
	# Sin cono central: el volcán arrancaba pegado a la salida y tapaba la
	# primera recta con su ladera. El hueco del centro lo llena el mar de lava,
	# así que el vórtice se lee mejor y la vista queda despejada.
	for i in 16:
		var angle := TAU * float(i) / 16.0 + 0.19
		var distance := 32.0 + float(i % 4) * 6.0
		var height := 12.0 + float(i % 5) * 6.0
		var spire_x := cos(angle) * distance
		var spire_z := V_CENTER.z + sin(angle) * distance
		if not _volcano_clear(spire_x, spire_z, 2.2 + float(i % 3),
				-16.0, -16.0 + height):
			continue
		_mesh_cylinder(decor, "ObsidianSpire%d" % i,
			Vector3(spire_x, -16.0 + height * 0.5, spire_z),
			0.0, 2.2 + float(i % 3), height, _volcano_rock,
			Vector3(0.0, float(i) * 11.0, 0.0))
	for i in 12:
		var angle := PI + float(i) * (TAU * 1.15 / 12.0)
		var height := V_START_TOP + float(i) * 8.0
		var light := OmniLight3D.new()
		light.name = "SpiralLight%d" % i
		light.position = Vector3(V_CENTER.x + cos(angle) * V_RADIUS,
			height + 3.0, V_CENTER.z + sin(angle) * V_RADIUS)
		# Cada vuelta tiene su propia temperatura de luz (naranja, ámbar, rojo),
		# así no se ve la misma espiral repetida seis veces.
		light.light_color = Color(1.0, 0.34 + float(i % 3) * 0.1, 0.1)
		light.light_energy = 1.6 + float(i % 4) * 0.22
		light.omni_range = 16.0 + float(i % 3) * 2.5
		light.shadow_enabled = false
		decor.add_child(light)

	# Esquirlas de obsidiana flotando alrededor de la montaña: más vida al fondo
	# de cada vuelta, siempre fuera de la trazada.
	for i in 6:
		var shard_angle := PI + float(i) * (TAU * 1.05 / 6.0) + 0.4
		var shard_distance := 26.0 + float(i % 3) * 7.0
		var shard_height := 22.0 + float(i) * 9.0
		var shard := _spiral_sample(6 + i * 20)
		var shard_top: float = shard["top"]
		_mesh_cylinder(decor, "ObsidianShard%d" % i,
			Vector3(V_CENTER.x + cos(shard_angle) * shard_distance,
				shard_top + shard_height, V_CENTER.z + sin(shard_angle) * shard_distance),
			0.0, 1.6 + float(i % 3) * 0.7, 7.0 + float(i % 4) * 2.5,
			_volcano_rock, Vector3(float(i % 5) * 12.0, float(i) * 31.0, 0.0), 6)

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

	# --- decoración extra: basalto, cascadas y antorchas ------------------
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var radius := 27.0 + float(i % 3) * 6.0
		var height := 14.0 + float(i % 4) * 7.0
		var column_x := V_CENTER.x + cos(angle) * radius
		var column_z := V_CENTER.z + sin(angle) * radius
		if not _volcano_clear(column_x, column_z, 2.4 + float(i % 3) * 0.8,
				-6.0, height - 6.0):
			continue
		_mesh_cylinder(decor, "BasaltColumn%d" % i,
			Vector3(column_x, height * 0.5 - 6.0, column_z),
			0.9, 2.4 + float(i % 3) * 0.8, height, _volcano_rock,
			Vector3(0.0, float(i) * 17.0, 0.0), 6)
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.4
		_mesh_box(decor, "LavaFall%d" % i,
			Vector3(V_CENTER.x + cos(angle) * 24.0, 30.0 + float(i % 3) * 12.0,
				V_CENTER.z + sin(angle) * 24.0),
			Vector3(2.2, 26.0, 0.5), _volcano_glow,
			Vector3(0.0, rad_to_deg(-angle), 6.0))
	for i in range(6, V_SEGMENTS, 9):
		# Antorchas colgadas de la cara exterior, por debajo de la losa: alumbran
		# la vuelta sin meterse delante de la cámara.
		var rail := _spiral_ring(i, V_HALF_WIDTH + 0.35, -0.5)
		_mesh_cylinder(decor, "TorchPost%d" % i, rail + Vector3.DOWN * 0.7,
			0.22, 0.08, 1.3, _volcano_rock, Vector3.ZERO, 6)
		_mesh_sphere(decor, "TorchFlame%d" % i, rail + Vector3.DOWN * 1.3,
			0.24, _volcano_glow)
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var height := 6.0 + float(i % 5) * 14.0
		var shard_x := V_CENTER.x + cos(angle) * (34.0 + float(i % 4) * 5.0)
		var shard_z := V_CENTER.z + sin(angle) * (34.0 + float(i % 4) * 5.0)
		if not _volcano_clear(shard_x, shard_z, 0.6, height - 1.8, height + 1.8):
			continue
		_mesh_box(decor, "ObsidianShard%d" % i,
			Vector3(shard_x, height, shard_z),
			Vector3(1.2, 3.6, 0.8), _volcano_rock,
			Vector3(float(i) * 23.0, float(i) * 31.0, 12.0))

	# --- atrezo de detalle: arcos, islas, braseros, humo y colosos ---------
	for i in 8:
		var seg := 8 + i * 13
		var arch_sample := _spiral_sample(seg)
		var arch_pos: Vector3 = arch_sample["position"]
		var arch_angle: float = arch_sample["angle"]
		var arch_basis := Basis(Vector3.UP, -arch_angle)
		for side in [-1.0, 1.0]:
			_mesh_box(decor, "BasaltArchPost%d_%d" % [i, int(side)],
				arch_pos + arch_basis * Vector3(side * 6.2, 3.8, 0.0),
				Vector3(0.9, 7.6, 0.9), _volcano_rock,
				Vector3(0.0, rad_to_deg(-arch_angle), 0.0))
		_mesh_box(decor, "BasaltArchBeam%d" % i, arch_pos + Vector3.UP * 7.7,
			Vector3(13.4, 0.6, 0.8), _volcano_rock,
			Vector3(0.0, rad_to_deg(-arch_angle), 0.0))
		_mesh_box(decor, "BasaltArchGlow%d" % i, arch_pos + Vector3.UP * 7.35,
			Vector3(12.6, 0.12, 0.14), _volcano_glow,
			Vector3(0.0, rad_to_deg(-arch_angle), 0.0))
	for i in range(4, V_SEGMENTS, 6):
		# Braseros colgados del borde interior: antes flotaban metro y medio
		# sobre la pista y tapaban la vista al ir por dentro.
		var rail_pos := _spiral_ring(i, -V_HALF_WIDTH - 0.25, -0.5)
		_mesh_cylinder(decor, "Brazier%d" % i, rail_pos + Vector3.DOWN * 0.55,
			0.34, 0.06, 0.95, _volcano_rock, Vector3.ZERO, 6)
		_mesh_sphere(decor, "BrazierFire%d" % i, rail_pos + Vector3.DOWN * 1.05,
			0.3, _volcano_glow)
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.3
		var radius := 40.0 + float(i % 3) * 9.0
		var height := 12.0 + float(i % 4) * 14.0
		var island_pos := Vector3(V_CENTER.x + cos(angle) * radius, height,
			V_CENTER.z + sin(angle) * radius)
		if not _volcano_clear(island_pos.x, island_pos.z, 4.4,
				height - 0.8, height + 0.8):
			continue
		_mesh_cylinder(decor, "FloatIsland%d" % i, island_pos,
			2.6, 4.4, 1.6, _volcano_rock, Vector3.ZERO, 7)
		_mesh_cylinder(decor, "FloatIslandLava%d" % i, island_pos + Vector3.UP * 0.9,
			2.2, 2.8, 0.2, _volcano_glow, Vector3.ZERO, 7)
	for i in 40:
		var angle := float(i) * 2.39996
		var radius := 8.0 + float(i % 11) * 4.5
		_mesh_sphere(decor, "LavaBubble%d" % i,
			Vector3(V_CENTER.x + cos(angle) * radius, -7.6,
				V_CENTER.z + sin(angle) * radius),
			0.4 + float(i % 3) * 0.2, _volcano_glow)
	for i in 2:
		var angle := PI * 0.5 + float(i) * PI
		var base := Vector3(V_CENTER.x + cos(angle) * 30.0, 0.0,
			V_CENTER.z + sin(angle) * 30.0)
		_mesh_cylinder(decor, "ColossusLegs%d" % i, base + Vector3.UP * 6.0,
			1.2, 2.0, 12.0, _volcano_rock, Vector3.ZERO, 7)
		_mesh_sphere(decor, "ColossusTorso%d" % i, base + Vector3.UP * 14.0,
			3.0, _volcano_rock)
		_mesh_sphere(decor, "ColossusHead%d" % i, base + Vector3.UP * 18.0,
			1.8, _volcano_rock)
		_mesh_sphere(decor, "ColossusEye%d" % i, base + Vector3.UP * 18.3,
			0.35, _volcano_glow)

	# --- tercera pasada: detalles pegados a toda la espiral ----------------
	for i in range(9, V_SEGMENTS, 7):
		var edge := _spiral_ring(i, V_HALF_WIDTH - 0.2, 0.02)
		_mesh_box(decor, "DeckCrack%d" % i, edge,
			Vector3(0.5, 0.03, 2.2), _volcano_glow, Vector3(0.0, 0.0, 12.0))
	for i in range(5, V_SEGMENTS, 11):
		# Banderines colgando de la cara exterior de la losa, no sobre la pista.
		var banner_pos := _spiral_ring(i, V_HALF_WIDTH + 0.3, -0.5)
		_mesh_cylinder(decor, "BannerRod%d" % i, banner_pos + Vector3.DOWN * 1.2,
			0.05, 0.05, 2.4, _volcano_rock, Vector3.ZERO, 5)
		_mesh_box(decor, "BannerFlag%d" % i, banner_pos + Vector3.DOWN * 1.6,
			Vector3(1.0, 1.1, 0.05), _volcano_glow, Vector3(0.0, float(i) * 23.0, 9.0))
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.7
		var dist := 34.0 + float(i % 3) * 7.0
		var cage_pos := Vector3(V_CENTER.x + cos(angle) * dist,
			6.0 + float(i % 4) * 8.0, V_CENTER.z + sin(angle) * dist)
		if not _volcano_clear(cage_pos.x, cage_pos.z, 0.9,
				cage_pos.y - 1.2, cage_pos.y + 1.2):
			continue
		_mesh_box(decor, "FireCage%d" % i, cage_pos,
			Vector3(1.2, 2.4, 1.2), _volcano_rock, Vector3(0.0, float(i) * 23.0, 0.0))
		_mesh_sphere(decor, "FireCageCore%d" % i, cage_pos + Vector3.UP * 0.2,
			0.5, _volcano_glow)
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var dist := 55.0 + float(i % 4) * 9.0
		var tall := 30.0 + float(i % 5) * 16.0
		_mesh_cylinder(decor, "FarVolcano%d" % i,
			Vector3(V_CENTER.x + cos(angle) * dist, tall * 0.5 - 10.0,
				V_CENTER.z + sin(angle) * dist),
			0.0, 9.0 + float(i % 3) * 3.0, tall, _volcano_rock,
			Vector3(0.0, float(i) * 37.0, 0.0), 7)
		_mesh_sphere(decor, "FarVolcanoGlow%d" % i,
			Vector3(V_CENTER.x + cos(angle) * dist, tall - 10.0,
				V_CENTER.z + sin(angle) * dist), 1.4, _volcano_glow)

	# --- trampas de la espiral -------------------------------------------
	# Pinchos variados: un sitio lleva 1, otro 2, otro 3 y otro 4, alternando
	# formaciones a lo ancho de la rampa y a lo largo de la subida (en vertical).
	var spike_rng := RandomNumberGenerator.new()
	spike_rng.seed = 20261103
	var spike_segment := 5
	var spike_group := 0
	while spike_segment < V_SEGMENTS - 7:
		var sample := _spiral_sample(spike_segment)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		var tangent := Vector3(-sin(sample_angle), 0.0, cos(sample_angle))
		var radial := Vector3(cos(sample_angle), 0.0, sin(sample_angle))
		# 1, 2, 3 o 4 pinchos en cada punto, distinto en cada tramo.
		var group_size := 1 + (spike_group * 3 + spike_segment) % 4
		# Dos de cada tres formaciones van a lo ancho; la otra, en vertical
		# (a lo largo de la subida).
		var across := spike_group % 3 != 2
		for k in group_size:
			var t := 0.0
			if group_size > 1:
				t = float(k) / float(group_size - 1)
			var along := 0.0
			var lateral := 0.0
			if across:
				lateral = lerpf(-2.7, 2.7, t)
				along = spike_rng.randf_range(-0.6, 0.6)
			else:
				lateral = spike_rng.randf_range(-1.1, 1.1)
				along = lerpf(-2.8, 2.8, t)
			var placement: Vector3 = sample_position + tangent * along + radial * lateral
			placement.y += _ramp_rise_per_meter * along + 0.02
			_obstacle(course, "Spike%d_%d" % [spike_segment, k], SPIKE_SCENE,
				placement,
				{"phase_offset": spike_rng.randf_range(0.0, 6.0), "spike_count": 1},
				-sample_angle, -_ramp_slope)
		spike_group += 1
		spike_segment += spike_rng.randi_range(3, 5)

	for i in [12, 30, 46, 58, 70, 86, 98]:
		var sample := _spiral_sample(i)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		# Cada barrido gira y empuja distinto: ni dos vueltas se sienten iguales.
		_obstacle(course, "Sweeper%d" % i, SWEEPER_SCENE,
			sample_position + Vector3.UP * 0.35, {
				"spin_speed": 2.0 + float(i % 3) * 0.4,
				"spin_direction": -1.0 if i % 2 == 0 else 1.0,
				"push_force": 6.2 + float(i % 2) * 0.9, "stuns": true,
			}, -sample_angle, -_ramp_slope)

	for i in [6, 20, 34, 41, 50, 56, 62, 68, 75, 82, 94, 106, 112]:
		var sample := _spiral_sample(i)
		var sample_position: Vector3 = sample["position"]
		var geyser := GEYSER_SCRIPT.new() as Node3D
		geyser.name = "Geyser%d" % i
		# Alturas distintas por géiser: no todos escupen igual, y así cada vuelta
		# se lee diferente.
		geyser.set("height", 7.0 + float(i % 3) * 1.4)
		geyser.set("radius", 1.3 + float(i % 2) * 0.4)
		geyser.set("phase_offset", float(i) * 0.31)
		geyser.position = sample_position
		course.add_child(geyser)

	# Aspas extra: añaden ritmo sin bloquear el paso, y el bot las espera
	# igual que en el resto de circuitos.
	for i in [24, 40, 68, 92, 108]:
		var rotor_sample := _spiral_sample(i)
		var rotor_position: Vector3 = rotor_sample["position"]
		var rotor_angle: float = rotor_sample["angle"]
		_obstacle(course, "Rotor%d" % i, ROTOR_SCENE,
			rotor_position + Vector3.UP * 0.35, {
				"spin_speed": 1.05 + float(i % 3) * 0.12,
				"spin_direction": -1.0 if i % 2 == 0 else 1.0,
				"phase_offset": float(i) * 0.37,
			}, -rotor_angle, -_ramp_slope)

	# La final no tiene checkpoints: si la lava te toca, pierdes la carrera. Por
	# eso la espiral añade trampas nuevas. Un pistón en cada pared lateral: salen
	# del borde derecho o del izquierdo y barren el carril de lado, no de frente.
	# Alternan el golpe para dejar paso por el otro lado.
	for i in [54, 74, 88, 101]:
		var piston_sample := _spiral_sample(i)
		var piston_position: Vector3 = piston_sample["position"]
		var piston_angle: float = piston_sample["angle"]
		var radial := Vector3(cos(piston_angle), 0.0, sin(piston_angle))
		for side in [-1.0, 1.0]:
			_obstacle(course, "SpiralPiston%d_%d" % [i, int(side)], PISTON_SCENE,
				piston_position + radial * side * 4.55 + Vector3.UP * 1.2, {
					"travel": -radial * side * 4.8, "push_force": 6.8,
					"phase_offset": float(i) * 0.23 + (0.0 if side < 0.0 else 1.7),
				})
	# La viga cruza la rampa: las dos patas quedan una a cada lado del carril (a
	# 3,55 m, sobre el borde) y las bolas caen desde tres caños distintos.
	for i in [37, 76, 97, 110]:
		var rain_sample := _spiral_sample(i)
		var rain_position: Vector3 = rain_sample["position"]
		var rain_angle: float = rain_sample["angle"]
		_obstacle(course, "SpiralRain%d" % i, DROPPER_SCENE,
			rain_position + Vector3.UP * 7.0, {
				"interval": 1.6 + float(i % 3) * 0.4,
				"drop_radius": 1.0, "max_balls": 6,
				"start_delay": 1.6, "column_spread": 3.55, "chute_count": 3,
				"despawn_below_y": rain_position.y - 14.0,
			}, -rain_angle, -_ramp_slope)

	# Arco de basalto con veta de lava en cada vuelta: un hito propio en vez de
	# repetir el mismo paisaje en cada giro.
	for i in [14, 48, 88]:
		var gate_sample := _spiral_sample(i)
		var gate_position: Vector3 = gate_sample["position"]
		var gate_angle: float = gate_sample["angle"]
		var gate_yaw := -rad_to_deg(gate_angle)
		var gate_basis := Basis(Vector3.UP, -gate_angle)
		for side in [-1.0, 1.0]:
			var offset: Vector3 = gate_basis * Vector3(side * 5.8, 0.0, 0.0)
			_mesh_box(course, "GatePillar%d_%d" % [i, int(side)],
				gate_position + offset + Vector3.UP * 3.6,
				Vector3(0.9, 7.2, 0.9), _volcano_rock, Vector3(0.0, gate_yaw, 0.0))
		_mesh_box(course, "GateBeam%d" % i, gate_position + Vector3.UP * 7.3,
			Vector3(12.4, 0.7, 0.8), _volcano_rock, Vector3(0.0, gate_yaw, 0.0))
		_mesh_box(course, "GateGlow%d" % i, gate_position + Vector3.UP * 6.95,
			Vector3(11.2, 0.09, 0.12), _volcano_glow, Vector3(0.0, gate_yaw, 0.0))

	# Estreno exclusivo del volcán: remolinos de ceniza que arrastran al corredor
	# en espiral. Se pasan corriendo en contra o saltándolos de lado.
	for i in [18, 52, 84]:
		var vortex_sample := _spiral_sample(i)
		var vortex_position: Vector3 = vortex_sample["position"]
		var vortex := ASH_VORTEX_SCRIPT.new() as Node3D
		vortex.name = "AshVortex%d" % i
		# El de la última vuelta tira más fuerte: hay que cruzarlo corriendo.
		vortex.set("radius", 4.2 + float(i % 2) * 0.9)
		# Mucho más suave: antes (9,5 de giro y 3,6 de tirón) te sacaba de la
		# trazada de golpe. Ahora molesta y desvía, pero se puede pelear.
		vortex.set("spin_force", 2.6 + float(i % 3) * 0.35)
		vortex.set("pull_force", 1.1 + float(i % 2) * 0.35)
		vortex.set("ring_speed", 1.6)
		vortex.position = vortex_position + Vector3.UP * 0.15
		course.add_child(vortex)

	# Estreno exclusivo: cortinas de magma que erupcionan en oleada de lado a
	# lado. Hay que leer el pulso y cruzar por los chorros apagados.
	for i in [22, 60, 95]:
		var curtain_sample := _spiral_sample(i)
		var curtain_position: Vector3 = curtain_sample["position"]
		var curtain_angle: float = curtain_sample["angle"]
		var curtain := MAGMA_CURTAIN_SCRIPT.new() as Node3D
		curtain.name = "MagmaCurtain%d" % i
		curtain.set("jets", 7)
		curtain.set("spacing", 1.15)
		curtain.set("height", 4.6)
		curtain.set("cycle_speed", 2.0 + float(i % 3) * 0.25)
		curtain.set("push_up", 10.0)
		curtain.set("phase_offset", float(i) * 0.17)
		curtain.position = curtain_position + Vector3.UP * 0.05
		curtain.rotation = Vector3(-_ramp_slope, -curtain_angle, 0.0)
		course.add_child(curtain)

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
		"gold_time": 84.0,
		"silver_time": 100.0,
		"bronze_time": 116.0,
		"start_position": Vector3(-18.0, V_START_TOP, -64.0),
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
	# En la final caer al vacío también es perder la carrera, igual que la lava.
	_add_kill_plane(Vector3(0.0, -34.0, -90.0), true)
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


# ----------------------------------------------------------- ronda 5: abismo

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
	add_child(course)

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

	_add_level_info({
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
	})
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
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "OceanSun"
	sun.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	sun.light_color = Color(0.76, 0.95, 1.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)


func _build_ocean_trench(course: Node3D) -> void:
	_slab(course, "TrenchFloor", Vector3(0.0, O_FLOOR_Y - 0.7, -206.0),
		Vector3(30.0, 1.4, 444.0), _ocean_sand)
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_slab(course, "TrenchWall" + suffix,
			Vector3(side * (O_HALF_WIDTH + O_WALL_THICKNESS * 0.5),
				O_WALL_TOP - O_WALL_HEIGHT * 0.5, -206.0),
			Vector3(O_WALL_THICKNESS, O_WALL_HEIGHT, 444.0), _ocean_rock)
		# Repisas de roca a media altura: rompen la pared lisa.
		for i in 9:
			var z := -20.0 - float(i) * 46.0
			_mesh_box(course, "WallShelf%s%d" % [suffix, i],
				Vector3(side * 12.0, -6.0 - float(i % 3) * 4.0, z),
				Vector3(2.6, 0.55, 9.0), _ocean_rock_dark,
				Vector3(0.0, 0.0, side * 6.0))
	# Rocas redondas sobre la arena.
	for i in 26:
		var z := -6.0 - float(i) * 16.0
		var x := sin(float(i) * 2.3) * 9.0
		_ocean_rock_boulder(course, "FloorRock%d" % i,
			Vector3(x, O_FLOOR_Y + 0.2, z), 1.2 + float(i % 4) * 0.5)


func _build_ocean_start(course: Node3D) -> void:
	# El muelle llega hasta las paredes (antes medía 22 m y quedaba un canal
	# seco de 0,6 m a cada lado).
	_slab(course, "StartDock", Vector3(0.0, 1.35, 6.0),
		Vector3(25.4, 1.3, 20.0), _ocean_sand)
	_slab(course, "StartDockLip", Vector3(0.0, 1.9, -4.6),
		Vector3(25.4, 0.4, 1.6), _ocean_rock_dark)
	_arch(course, "StartGate", Vector3(0.0, 2.0, 2.0), 15.0, 6.4,
		_ocean_rock_dark, _ocean_glow, "ABYSS RUN")
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_mesh_box(course, "DockPost" + suffix,
			Vector3(side * 8.0, 2.8, -3.2), Vector3(0.35, 1.6, 0.35), _ocean_rock_dark)
		_mesh_sphere(course, "DockLamp" + suffix,
			Vector3(side * 8.0, 3.75, -3.2), 0.26, _ocean_glow)


func _build_ocean_islands(course: Node3D) -> void:
	for i in O_ISLANDS.size():
		var island: Dictionary = O_ISLANDS[i]
		var z: float = island["z"]
		var length: float = island["length"]
		var top: float = island["top"]
		var height := top - O_FLOOR_Y
		# Un poco más anchas que el túnel: se meten en la pared y no dejan un
		# hueco de 0,6 m junto al muro en el que caerse y quedarse atrapado.
		_slab(course, "Island%d" % i,
			Vector3(0.0, O_FLOOR_Y + height * 0.5, z),
			Vector3(25.4, height, length), _ocean_rock)
		_slab(course, "IslandSand%d" % i, Vector3(0.0, top - 0.12, z),
			Vector3(25.8, 0.3, length + 0.6), _ocean_sand)
		for j in 6:
			var side := -1.0 if j % 2 == 0 else 1.0
			_ocean_rock_boulder(course, "IslandRock%d_%d" % [i, j],
				Vector3(side * (9.5 + float(j % 2) * 1.5), top + 0.1,
					z - length * 0.5 + float(j) * 2.4),
				0.9 + float(j % 3) * 0.35)
		_ocean_coral_cluster(course, "IslandCoral%d" % i,
			Vector3(-6.0, top, z + 3.0), 1.2, i + 1)
		_ocean_coral_cluster(course, "IslandCoralB%d" % i,
			Vector3(6.5, top, z - 2.5), 1.0, i + 3)


func _build_ocean_finish(course: Node3D) -> void:
	# La plataforma empieza detrás de la rampa: si llegaba hasta el agua, su
	# cara vertical tapaba la subida.
	_slab(course, "FinishDeck", Vector3(0.0, 0.3, -407.0),
		Vector3(25.4, 1.4, 22.0), _ocean_sand)
	# Rampa de ancho completo: antes medía 18 m dentro de un túnel de 24 y se
	# caía uno al fondo seco por los lados. Ahora la única salida es subirla.
	_ramp_z(course, "FinishRamp", 0.0, -391.0, -395.5, 0.5, 1.0, 25.4,
		_ocean_rock_dark)
	# Cierre del último tramo: pared desde el fondo hasta la base de la rampa,
	# de lado a lado. A media profundidad el túnel ya no continúa: hay que
	# salir por arriba y caminar hasta la meta.
	_slab(course, "AbyssEndWall", Vector3(0.0, (0.5 + O_FLOOR_Y) * 0.5, -392.0),
		Vector3(25.4, 0.5 - O_FLOOR_Y, 1.2), _ocean_rock_dark)
	_slab(course, "Podium", Vector3(0.0, 1.8, -414.0),
		Vector3(16.0, 1.6, 6.0), _ocean_rock)
	_obstacle(course, "FinishLine", FINISH_SCENE, Vector3(0.0, 1.0, -408.0))
	for side in [-1.0, 1.0]:
		_mesh_cylinder(course, "PodiumTorch" + ("L" if side < 0.0 else "R"),
			Vector3(side * 7.0, 3.6, -414.0), 0.1, 0.5, 2.6, _ocean_glow,
			Vector3.ZERO, 8)


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
		zone.position = Vector3(0.0, (O_WATERLINE + O_FLOOR_Y) * 0.5,
			(stretch.x + stretch.y) * 0.5)
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
func _ocean_choke(course: Node3D, node_name: String, z: float, center_x: float,
		center_y: float, opening_w: float = 9.0, opening_h: float = 9.0) -> void:
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
		_slab(course, node_name + "L",
			Vector3(left_edge + left_w * 0.5, middle_y, z),
			Vector3(left_w, top - bottom, thickness), _ocean_rock)
	var right_edge := O_HALF_WIDTH + 1.2
	var right_w := right_edge - open_r
	if right_w > 0.2:
		_slab(course, node_name + "R",
			Vector3(right_edge - right_w * 0.5, middle_y, z),
			Vector3(right_w, top - bottom, thickness), _ocean_rock)
	var low_h := open_b - bottom
	if low_h > 0.2:
		_slab(course, node_name + "B",
			Vector3((open_l + open_r) * 0.5, bottom + low_h * 0.5, z),
			Vector3(open_r - open_l, low_h, thickness), _ocean_rock)
	var high_h := top - open_t
	if high_h > 0.2:
		_slab(course, node_name + "T",
			Vector3((open_l + open_r) * 0.5, open_t + high_h * 0.5, z),
			Vector3(open_r - open_l, high_h, thickness), _ocean_rock)
	# Marco luminoso: el hueco se ve desde lejos.
	_mesh_box(course, node_name + "GlowL", Vector3(open_l, center_y, z),
		Vector3(0.16, opening_h, thickness + 0.12), _ocean_glow)
	_mesh_box(course, node_name + "GlowR", Vector3(open_r, center_y, z),
		Vector3(0.16, opening_h, thickness + 0.12), _ocean_glow)
	_mesh_box(course, node_name + "GlowB", Vector3(center_x, open_b, z),
		Vector3(opening_w, 0.16, thickness + 0.12), _ocean_glow)
	_mesh_box(course, node_name + "GlowT", Vector3(center_x, open_t, z),
		Vector3(opening_w, 0.16, thickness + 0.12), _ocean_glow)


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
		_ocean_choke(course, "ReefGate%d" % i, float(gate["z"]), float(gate["x"]),
			float(gate["y"]), float(gate["w"]), float(gate["h"]))


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
		_ocean_hazard(course, String(entry["name"]), lift,
			Vector3(0.0, -11.5, float(entry["z"])))


func _ocean_hazard(course: Node3D, node_name: String, hazard: Node3D,
		position: Vector3, yaw: float = 0.0) -> Node3D:
	hazard.name = node_name
	hazard.position = position
	hazard.rotation.y = yaw
	course.add_child(hazard)
	return hazard


## Coloca un obstáculo marino forzando cómo te toca: aturde y frena, empuja
## lejos o te devuelve al checkpoint. `push` es la fuerza del empujón.
func _ocean_hazard_kind(course: Node3D, node_name: String, hazard: Node3D,
		position: Vector3, kind: String, push: float = 0.0) -> Node3D:
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
		_ocean_hazard_kind(course, "GateUrchin%d" % i, left,
			Vector3(gate_x - 2.1, gate_y, gate_z),
			"stun" if kind == "push" else kind)
		var right := OCEAN_HAZARDS.Jellyfish.new()
		right.set("bell_size", 1.2)
		right.set("drift", 0.5)
		_ocean_hazard_kind(course, "GateJelly%d" % i, right,
			Vector3(gate_x + 2.1, gate_y, gate_z + 0.7), kind,
			24.0 if kind == "push" else 0.0)
		# Rápidos: el aro de burbujas espera detrás del hueco. Cruzarlo lanza
		# al corredor hacia el tramo siguiente; no golpea, así que quien
		# prefiera ir con calma solo tiene que bordearlo.
		if gate_z - 5.5 > -390.0:
			var boost := OCEAN_HAZARDS.BoostRing.new()
			boost.set("radius", 2.8)
			boost.set("boost", 12.0)
			_ocean_hazard(course, "BoostRing%d" % i, boost,
				Vector3(gate_x, gate_y, gate_z - 5.5))

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
			_ocean_hazard_kind(course, "WeaveHazard%d" % weave_index, hazard,
				Vector3(side * 4.8, -9.5, z), kind,
				26.0 if kind == "push" else 0.0)
			weave_index += 1

	# Checkpoints: los secos, sobre las islas; los otros, dentro del agua.
	_add_checkpoint(course, "CP1", Vector3(0.0, 2.0, -1.0))
	_add_checkpoint(course, "CP2", Vector3(0.0, 0.4, -117.0))
	_add_checkpoint(course, "CP3", Vector3(0.0, -6.0, -194.0))
	_add_checkpoint(course, "CP4", Vector3(0.0, 0.4, -247.0))
	_add_checkpoint(course, "CP5", Vector3(0.0, -8.0, -330.0))
	_add_checkpoint(course, "CP6", Vector3(0.0, 1.0, -396.0))


# --------------------------------------------------- decoración del abismo

func _ocean_rock_boulder(parent: Node3D, node_name: String, position: Vector3,
		radius: float) -> void:
	var rock := _mesh_sphere(parent, node_name, position, radius, _ocean_rock_dark)
	rock.scale = Vector3(1.0, 0.62, 1.0)


## Racimo de coral: cinco ramas con punta luminosa. El `variant` cambia altura,
## inclinación y color para que no haya dos racimos iguales.
func _ocean_coral_cluster(parent: Node3D, node_name: String, position: Vector3,
		scale_value: float, variant: int) -> void:
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
		_mesh_sphere(root, "%sTip%d" % [node_name, i],
			offset + Vector3.UP * height, 0.16 * scale_value, _ocean_glow)


func _ocean_anemone(parent: Node3D, node_name: String, position: Vector3,
		scale_value: float) -> void:
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


func _ocean_kelp(parent: Node3D, node_name: String, position: Vector3,
		height: float) -> void:
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
		var leaf := _mesh_box(parent, "%sLeaf%d" % [node_name, i],
			position + Vector3.UP * height * (0.3 + float(i) * 0.18),
			Vector3(0.9, 0.08, 0.3), OceanStyle.matte(OceanStyle.ALGAE, 0.8),
			Vector3(0.0, float(i) * 42.0, 18.0))
		leaf.scale = Vector3(0.8 + float(i) * 0.12, 1.0, 1.0)


func _ocean_light_shaft(parent: Node3D, node_name: String, position: Vector3,
		width: float, length: float) -> void:
	_mesh_box(parent, node_name, position, Vector3(width, length, 0.35),
		_ocean_ray, Vector3(0.0, 0.0, 16.0))


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
		_ocean_coral_cluster(course, "Coral%d" % i,
			Vector3(side * (9.6 + float(i % 3) * 0.8), O_FLOOR_Y + 0.1, z),
			0.9 + float(i % 4) * 0.22, i)
		if i % 3 == 0:
			_ocean_anemone(course, "Anemone%d" % i,
				Vector3(-side * 8.0, O_FLOOR_Y + 0.15, z - 3.5),
				0.9 + float(i % 2) * 0.3)
		if i % 2 == 0:
			_ocean_kelp(course, "KelpDecor%d" % i,
				Vector3(-side * 10.6, O_FLOOR_Y + 0.2, z + 4.0),
				7.0 + float(i % 4) * 1.6)
		if i % 5 == 0:
			_ocean_light_shaft(course, "Ray%d" % i,
				Vector3(float((i % 3) - 1) * 6.0, -8.0, z), 6.0, 30.0)
	_ocean_plankton(course)

	# --- tercera pasada de detalle: siempre en el suelo o en las paredes ----
	# Nada de esto entra en la trazada: piedras y anémonas en el fondo, percebes
	# en la roca y haces de luz que salen de arriba.
	for i in 22:
		var z := -10.0 - float(i) * 18.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_ocean_rock_boulder(course, "FloorPebble%d" % i,
			Vector3(side * (6.4 + float(i % 3) * 2.2), O_FLOOR_Y + 0.1, z),
			0.5 + float(i % 3) * 0.22)
		_ocean_anemone(course, "FloorAnemone%d" % i,
			Vector3(-side * (10.2 + float(i % 2) * 0.7), O_FLOOR_Y + 0.15, z + 6.0),
			0.8 + float(i % 3) * 0.2)
	for i in 14:
		var z := -16.0 - float(i) * 27.0
		var side := -1.0 if i % 2 == 0 else 1.0
		# Pegados a la cara interior del muro (que ahora está en ±12), no dentro
		# de él, para que se sigan viendo.
		_mesh_box(course, "WallBarnacle%d" % i,
			Vector3(side * (O_HALF_WIDTH - 0.12), -4.0 - float(i % 4) * 2.4, z),
			Vector3(0.55, 1.7, 2.6), _ocean_sand, Vector3(0.0, 0.0, side * 8.0))
	for i in 12:
		var z := -22.0 - float(i) * 32.0
		_ocean_light_shaft(course, "RayB%d" % i,
			Vector3(float((i % 5) - 2) * 3.4, -6.0, z), 7.0, 34.0)
	for i in 10:
		var z := -30.0 - float(i) * 36.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_mesh_cylinder(course, "WallCoralFan%d" % i,
			Vector3(side * (O_HALF_WIDTH - 0.3), -7.0 - float(i % 3) * 3.0, z),
			1.4, 1.4, 0.35, _ocean_coral,
			Vector3(0.0, 0.0, side * 90.0), 8)


## Paisaje fuera del túnel: agujas de roca, restos de un naufragio, ballena y
## bancos de peces. Se ve por encima de las paredes y no estorba al corredor.
func _build_ocean_scenery(course: Node3D) -> void:
	for i in 16:
		var z := -14.0 - float(i) * 27.0
		var side := -1.0 if i % 2 == 0 else 1.0
		_mesh_cylinder(course, "Spire%d" % i,
			Vector3(side * (26.0 + float(i % 3) * 6.0), -8.0 + float(i % 4) * 2.0, z),
			1.1, 6.0 + float(i % 3) * 2.4, 32.0 + float(i % 4) * 7.0,
			_ocean_rock_dark)

	# Pecio: casco, mástil y columnas caídas cerca de las islas.
	_mesh_box(course, "WreckHull", Vector3(-24.0, 0.5, -168.0),
		Vector3(16.0, 3.0, 6.0), _ocean_rock_dark, Vector3(0.0, 24.0, 8.0))
	_mesh_cylinder(course, "WreckMast", Vector3(-24.0, 5.0, -168.0),
		0.2, 0.45, 12.0, _ocean_rock_dark, Vector3(0.0, 0.0, 18.0))
	for i in 4:
		_mesh_cylinder(course, "Ruin%d" % i,
			Vector3(23.0, -2.0, -96.0 - float(i) * 6.0),
			0.9, 1.4, 7.0 + float(i % 2) * 3.0, _ocean_sand,
			Vector3(0.0, 0.0, 6.0 + float(i) * 4.0))

	# Ballena de fondo.
	var whale := _mesh_sphere(course, "WhaleBody", Vector3(42.0, 18.0, -196.0),
		6.0, OceanStyle.matte(OceanStyle.ROCK_DARK, 1.0))
	whale.scale = Vector3(2.8, 0.9, 1.1)
	_mesh_box(course, "WhaleTail", Vector3(42.0, 18.0, -184.0),
		Vector3(6.0, 0.6, 5.0), OceanStyle.matte(OceanStyle.ROCK_DARK, 1.0),
		Vector3(18.0, 0.0, 0.0))

	_ocean_fish_school(course, Vector3(-22.0, 6.0, -150.0), 90)
	_ocean_fish_school(course, Vector3(24.0, 4.0, -300.0), 70)
