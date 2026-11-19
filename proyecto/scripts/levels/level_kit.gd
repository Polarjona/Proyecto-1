extends RefCounted

## Piezas compartidas por los tres circuitos generados: materiales, escenario,
## actores de la carrera y geometría (losas, rampas, arcos, rocas…).
##
## Cada circuito es un kit que hereda de aquí y solo describe su pista: así el
## generador deja de ser un archivo de tres mil líneas con cuatro mapas dentro.
## El kit no es un nodo: recibe `host` (el `level_builder` dueño de la escena) y
## le cuelga todo lo que construye.

var host: Node3D
var _path: Array[Vector3] = []
var _widths: Array[float] = []


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


const ASH_VORTEX_SCRIPT := preload("res://scripts/ash_vortex.gd")


const MAGMA_CURTAIN_SCRIPT := preload("res://scripts/magma_curtain.gd")


const WATER_ZONE_SCRIPT := preload("res://scripts/water_zone.gd")


const OCEAN_HAZARDS := preload("res://scripts/ocean_hazards.gd")


const PLATFORM_SHADER := preload("res://shaders/platform.gdshader")


const POST_SHADER := preload("res://shaders/post_process.gdshader")


const SKY_SHADER := preload("res://shaders/sky_clouds.gdshader")


const SEA_SHADER := preload("res://shaders/void_sea.gdshader")


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
	host.add_child(node)


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
	host.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-28.0, cfg["sun_yaw"] + 165.0, 0.0)
	fill.light_color = cfg["fill"]
	fill.light_energy = cfg["fill_energy"]
	fill.shadow_enabled = false
	host.add_child(fill)


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
	host.add_child(dome)


func _add_post(cfg: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.name = "PostProcess"
	layer.layer = 1
	host.add_child(layer)
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
	host.add_child(info)


func _add_race_manager() -> void:
	var manager := load("res://scripts/race_manager.gd").new() as Node
	manager.name = "RaceManager"
	host.add_child(manager)


func _add_hud() -> void:
	host.add_child(HUD_SCENE.instantiate())


func _add_kill_plane(position: Vector3, fail_run: bool = false) -> void:
	var kill := KILL_SCENE.instantiate() as Node3D
	kill.name = "KillPlane"
	kill.position = position
	# Bien largo en Z: cubre el circuito entero, no solo el tramo del centro.
	kill.scale = Vector3(1.7, 1.0, 2.2)
	if fail_run:
		kill.set("fail_run", true)
	host.add_child(kill)


func _add_player(start: Vector3, jump_velocity: float = 0.0) -> void:
	var player := PLAYER_SCENE.instantiate() as Node3D
	player.name = "Player"
	player.position = start
	# Salto a medida del nivel: si se pasa un impulso se ajusta también el
	# salto corto en la misma proporción para no romper el tacto.
	if jump_velocity > 0.0:
		player.set("jump_velocity", jump_velocity)
		player.set("min_jump_velocity", jump_velocity * 0.3665)
	host.add_child(player)


func _add_director(start_z: float, finish_z: float, course_length: float) -> void:
	var director := load("res://scripts/race_director.gd").new() as Node
	director.name = "RaceDirector"
	director.set("bot_scene", BOT_SCENE)
	director.set("start_z", start_z)
	director.set("finish_z", finish_z)
	director.set("course_length", course_length)
	host.add_child(director)


func _add_pause() -> void:
	host.add_child(PAUSE_SCENE.instantiate())


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
