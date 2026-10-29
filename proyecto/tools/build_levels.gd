extends Node

## Genera los dos circuitos nuevos del torneo:
##   res://scenes/levels/spin_go_round.tscn   (ronda 2)
##   res://scenes/levels/pivot_panic.tscn     (ronda 3)
##
## Se ejecuta una sola vez con:
##   godot --headless --path . --script tools/build_levels.gd
##
## El script empaqueta las escenas con los mismos nodos que main.tscn
## (WorldEnvironment, RaceManager, HUD, Course, KillPlane, RaceDirector...),
## así que el flujo de carrera, los bots y el torneo funcionan sin cambios.

const OUT_DIR := "res://scenes/levels"
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
const PENDULUM_SCENE := preload("res://scenes/obstacles/pendulum.tscn")
const SEESAW_SCENE := preload("res://scenes/obstacles/see_saw.tscn")
const WIND_SCENE := preload("res://scenes/obstacles/wind_tunnel.tscn")
const LAUNCHER_SCENE := preload("res://scenes/obstacles/launcher.tscn")
const BOUNCE_SCENE := preload("res://scenes/obstacles/bounce_pad.tscn")

const MAT_SPIN_FLOOR := preload("res://materials/spin_floor.tres")
const MAT_SPIN_BLUE := preload("res://materials/spin_blue.tres")
const MAT_SPIN_ORANGE := preload("res://materials/spin_orange.tres")
const MAT_SPIN_MAGENTA := preload("res://materials/spin_magenta.tres")
const MAT_SPIN_LIME := preload("res://materials/spin_lime.tres")
const MAT_SPIN_GOLD := preload("res://materials/spin_gold.tres")
const MAT_SPIN_WALL := preload("res://materials/spin_wall.tres")
const MAT_SPIN_HAZARD := preload("res://materials/spin_hazard.tres")

const MAT_PIVOT_FLOOR := preload("res://materials/pivot_floor.tres")
const MAT_PIVOT_FLOOR_ALT := preload("res://materials/pivot_floor_alt.tres")
const MAT_PIVOT_BLUE := preload("res://materials/pivot_blue.tres")
const MAT_PIVOT_GOLD := preload("res://materials/pivot_gold.tres")
const MAT_PIVOT_WALL := preload("res://materials/pivot_wall.tres")
const MAT_PIVOT_RAIL := preload("res://materials/pivot_rail.tres")
const MAT_PIVOT_CREAM := preload("res://materials/pivot_cream.tres")

const SKY_SHADER := preload("res://shaders/sky_clouds.gdshader")
const POST_SHADER := preload("res://shaders/post_process.gdshader")

const SPIN_ENV := {
	"sky_top": Color(0.02, 0.3, 0.9),
	"sky_horizon": Color(0.35, 0.72, 0.98),
	"sky_ground": Color(0.05, 0.25, 0.55),
	"cloud_color": Color(0.95, 1.0, 1.0),
	"sun_color": Color(1.0, 0.95, 0.78),
	"sun_glow": 0.9,
	"cloud_opacity": 0.45,
	"cloud_scale": 2.2,
	"ambient": Color(0.68, 0.88, 1.0),
	"ambient_energy": 0.62,
	"fog": Color(0.62, 0.88, 1.0),
	"fog_density": 0.0016,
	"exposure": 0.9,
	"saturation": 1.28,
	"glow": 0.3,
	"glow_bloom": 0.02,
	"glow_threshold": 1.3,
	"sun_pitch": -46.0,
	"sun_yaw": -28.0,
	"sun_energy": 1.0,
	"fill": Color(0.45, 0.75, 1.0),
	"fill_energy": 0.45,
}

const PIVOT_ENV := {
	"sky_top": Color(0.18, 0.24, 0.84),
	"sky_horizon": Color(0.98, 0.84, 0.72),
	"sky_ground": Color(0.45, 0.2, 0.48),
	"cloud_color": Color(1.0, 0.94, 0.9),
	"sun_color": Color(1.0, 0.88, 0.64),
	"sun_glow": 1.0,
	"cloud_opacity": 0.5,
	"cloud_scale": 2.8,
	"ambient": Color(1.0, 0.82, 0.9),
	"ambient_energy": 0.66,
	"fog": Color(0.95, 0.68, 0.8),
	"fog_density": 0.0014,
	"exposure": 0.92,
	"saturation": 1.14,
	"glow": 0.3,
	"glow_bloom": 0.02,
	"glow_threshold": 1.3,
	"sun_pitch": -44.0,
	"sun_yaw": 24.0,
	"sun_energy": 0.98,
	"fill": Color(0.65, 0.6, 1.0),
	"fill_energy": 0.45,
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_spin_go_round()
	_build_pivot_panic()
	print("Niveles generados en ", OUT_DIR)
	get_tree().quit()


# ---------------------------------------------------------------- utilidades

func _add(parent: Node, child: Node, owner_node: Node) -> Node:
	parent.add_child(child)
	child.owner = owner_node
	return child


func _group(root: Node3D, node_name: String, script_path: String = "") -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	if not script_path.is_empty():
		node.set_script(load(script_path))
	_add(root, node, root)
	return node


func _set_all(node: Object, values: Dictionary) -> void:
	for key: String in values.keys():
		node.set(key, values[key])


func _platform(course: Node3D, root: Node3D, node_name: String, center: Vector3,
		size: Vector3, material: Material, rot_x: float = 0.0) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = size
	box.position = center
	box.rotation_degrees = Vector3(rot_x, 0.0, 0.0)
	box.material = material
	box.use_collision = true
	_add(course, box, root)
	return box


func _slab(course: Node3D, root: Node3D, node_name: String, x: float, z: float,
		sx: float, sz: float, top: float, material: Material) -> CSGBox3D:
	return _platform(course, root, node_name, Vector3(x, top - 0.25, z),
		Vector3(sx, 0.5, sz), material)


func _obstacle(course: Node3D, root: Node3D, node_name: String, scene: PackedScene,
		position: Vector3, values: Dictionary = {}) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.position = position
	_set_all(node, values)
	_add(course, node, root)
	return node


func _mesh_box(parent: Node3D, root: Node3D, node_name: String, position: Vector3,
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
	_add(parent, instance, root)
	return instance


func _mesh_torus(parent: Node3D, root: Node3D, node_name: String, position: Vector3,
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
	_add(parent, instance, root)
	return instance


func _mesh_cylinder(parent: Node3D, root: Node3D, node_name: String, position: Vector3,
		top_radius: float, bottom_radius: float, height: float, material: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 2
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, instance, root)
	return instance


func _mesh_sphere(parent: Node3D, root: Node3D, node_name: String, position: Vector3,
		radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, instance, root)
	return instance


func _rail(parent: Node3D, root: Node3D, node_name: String, x: float, z: float,
		length: float, top: float, material: Material, sideways: bool = false) -> void:
	var size := Vector3(0.18, 0.18, length) if sideways else Vector3(length, 0.18, 0.18)
	_mesh_box(parent, root, node_name, Vector3(x, top + 0.55, z), size, material)


func _arch(parent: Node3D, root: Node3D, node_name: String, z: float, top: float,
		width: float, height: float, post_material: Material, gold_material: Material,
		label: String = "") -> void:
	var half := width * 0.5
	_mesh_box(parent, root, node_name + "PostLeft",
		Vector3(-half, top + height * 0.5, z), Vector3(0.7, height, 0.9), post_material)
	_mesh_box(parent, root, node_name + "PostRight",
		Vector3(half, top + height * 0.5, z), Vector3(0.7, height, 0.9), post_material)
	_mesh_box(parent, root, node_name + "Beam",
		Vector3(0.0, top + height, z), Vector3(width + 0.8, 0.6, 1.0), gold_material)
	_mesh_torus(parent, root, node_name + "Ring", Vector3(0.0, top + height * 0.62, z),
		width * 0.18, width * 0.22, gold_material, Vector3(90.0, 0.0, 0.0))
	if not label.is_empty():
		var text := Label3D.new()
		text.name = node_name + "Label"
		text.text = label
		text.font_size = 230
		text.pixel_size = 0.0045
		text.outline_size = 34
		text.modulate = Color(1.0, 0.92, 0.55)
		text.outline_modulate = Color(0.06, 0.05, 0.14)
		text.position = Vector3(0.0, top + height + 0.8, z)
		_add(parent, text, root)


func _hazard(parent: Node3D, root: Node3D, node_name: String, x: float, z: float,
		top: float, width: float) -> void:
	_mesh_box(parent, root, node_name, Vector3(x, top + 0.01, z),
		Vector3(width, 0.02, 0.55), MAT_SPIN_HAZARD)


func _prop(parent: Node3D, root: Node3D, node_name: String, path: String,
		position: Vector3, scale: float, rotation_degrees_y: float = 0.0) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = node_name
	node.position = position
	node.scale = Vector3.ONE * scale
	node.rotation_degrees.y = rotation_degrees_y
	_add(parent, node, root)
	return node


func _decor_top(parent: Node3D, root: Node3D, node_name: String, position: Vector3,
		scale: float, color_a: Material, color_b: Material) -> void:
	# Peonza decorativa: cono, aro y bola, sin colisión.
	_mesh_cylinder(parent, root, node_name + "Cone", position + Vector3(0, 0.9 * scale, 0),
		0.08 * scale, 1.25 * scale, 1.8 * scale, color_a)
	_mesh_torus(parent, root, node_name + "Ring", position + Vector3(0, 0.55 * scale, 0),
		1.15 * scale, 1.42 * scale, color_b)
	_mesh_sphere(parent, root, node_name + "Bola", position + Vector3(0, 2.0 * scale, 0),
		0.52 * scale, color_b)


func _lights(parent: Node3D, root: Node3D, positions: Array, color: Color,
		energy: float = 1.2, light_range: float = 16.0) -> void:
	var index := 0
	for position: Vector3 in positions:
		index += 1
		var light := OmniLight3D.new()
		light.name = "CourseLight%d" % index
		light.position = position
		light.light_color = color
		light.light_energy = energy
		light.omni_range = light_range
		light.shadow_enabled = false
		_add(parent, light, root)


func _sky_material(cfg: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("top_color", cfg["sky_top"])
	material.set_shader_parameter("horizon_color", cfg["sky_horizon"])
	material.set_shader_parameter("ground_color", cfg["sky_ground"])
	material.set_shader_parameter("cloud_color", cfg["cloud_color"])
	material.set_shader_parameter("sun_color", cfg["sun_color"])
	material.set_shader_parameter("sun_glow", cfg["sun_glow"])
	material.set_shader_parameter("cloud_opacity", cfg["cloud_opacity"])
	material.set_shader_parameter("cloud_scale", cfg["cloud_scale"])
	material.set_shader_parameter("sun_direction", Vector3(0.5, 0.62, -0.6).normalized())
	return material


func _post_material(cfg: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = POST_SHADER
	material.set_shader_parameter("saturation", cfg["saturation"])
	material.set_shader_parameter("contrast", 1.06)
	material.set_shader_parameter("vignette", 0.3)
	return material


func _add_environment(root: Node3D, cfg: Dictionary) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = cfg["sky_top"]
	sky_material.sky_horizon_color = cfg["sky_horizon"]
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = cfg["sky_ground"]
	sky_material.ground_horizon_color = cfg["sky_horizon"]
	sky_material.ground_curve = 0.12
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = cfg["ambient"]
	environment.ambient_light_energy = cfg["ambient_energy"]
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = cfg["exposure"]
	environment.tonemap_white = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.8
	environment.glow_enabled = true
	environment.glow_intensity = cfg["glow"]
	environment.glow_strength = 1.0
	environment.glow_bloom = cfg["glow_bloom"]
	environment.glow_hdr_threshold = cfg["glow_threshold"]
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.fog_enabled = true
	environment.fog_light_color = cfg["fog"]
	environment.fog_density = cfg["fog_density"]
	environment.fog_sky_affect = 0.25
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.04
	environment.adjustment_saturation = cfg["saturation"]

	var node := WorldEnvironment.new()
	node.name = "WorldEnvironment"
	node.environment = environment
	_add(root, node, root)


func _add_lights(root: Node3D, cfg: Dictionary) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation_degrees = Vector3(cfg["sun_pitch"], cfg["sun_yaw"], 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = cfg["sun_energy"]
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_max_distance = 220.0
	_add(root, sun, root)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-30.0, cfg["sun_yaw"] + 170.0, 0.0)
	fill.light_color = cfg["fill"]
	fill.light_energy = cfg["fill_energy"]
	fill.shadow_enabled = false
	_add(root, fill, root)


func _add_sky(root: Node3D, cfg: Dictionary) -> void:
	var sky_mesh := SphereMesh.new()
	sky_mesh.radius = 380.0
	sky_mesh.height = 760.0
	sky_mesh.radial_segments = 48
	sky_mesh.rings = 24
	var dome := MeshInstance3D.new()
	dome.name = "SkyDome"
	dome.mesh = sky_mesh
	dome.material_override = _sky_material(cfg)
	dome.position = Vector3(0.0, 0.0, -70.0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, dome, root)


func _add_level_info(root: Node3D, values: Dictionary) -> void:
	var info := load("res://scripts/level_info.gd").new() as Node
	info.name = "LevelInfo"
	_set_all(info, values)
	_add(root, info, root)
	info.add_to_group("level_info")


func _add_race_manager(root: Node3D) -> void:
	var manager := load("res://scripts/race_manager.gd").new() as Node
	manager.name = "RaceManager"
	_add(root, manager, root)
	manager.add_to_group("race_manager")


func _add_hud(root: Node3D) -> void:
	_add(root, HUD_SCENE.instantiate(), root)


func _add_kill_plane(root: Node3D, z: float) -> void:
	var kill := KILL_SCENE.instantiate() as Node3D
	kill.name = "KillPlane"
	kill.position = Vector3(0.0, -10.0, z)
	kill.scale = Vector3(1.6, 1.0, 1.6)
	_add(root, kill, root)


func _add_post(root: Node3D, cfg: Dictionary) -> void:
	var layer := load("res://scripts/post_process.gd").new() as CanvasLayer
	layer.name = "PostProcess"
	_add(root, layer, root)
	var rect := ColorRect.new()
	rect.name = "Rect"
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _post_material(cfg)
	_add(layer, rect, root)


func _add_director(root: Node3D, start_z: float, finish_z: float, course_length: float) -> void:
	var director := load("res://scripts/race_director.gd").new() as Node
	director.name = "RaceDirector"
	director.set("bot_scene", BOT_SCENE)
	director.set("start_z", start_z)
	director.set("finish_z", finish_z)
	director.set("course_length", course_length)
	_add(root, director, root)


func _add_player(root: Node3D) -> void:
	var player := PLAYER_SCENE.instantiate() as Node3D
	player.name = "Player"
	player.position = Vector3(0.0, 0.6, 4.0)
	_add(root, player, root)


func _add_pause(root: Node3D) -> void:
	_add(root, PAUSE_SCENE.instantiate(), root)


func _save(root: Node3D, path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error != OK:
		push_error("No se pudo empaquetar %s: %s" % [path, error_string(error)])
		return
	error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("No se pudo guardar %s: %s" % [path, error_string(error)])
	else:
		print("Guardado ", path)
	root.free()


func _crowd(root: Node3D, cfg: Dictionary) -> void:
	var crowd := load("res://scripts/crowd.gd").new() as Node3D
	crowd.name = "Crowd"
	_set_all(crowd, cfg)
	_add(root, crowd, root)


func _arena_decor(root: Node3D, cfg: Dictionary) -> void:
	var decor := load("res://scripts/arena_decor.gd").new() as Node3D
	decor.name = "ArenaDecor"
	_set_all(decor, cfg)
	_add(root, decor, root)


# ------------------------------------------------------------ ronda 2: Spin

func _build_spin_go_round() -> void:
	var root := Node3D.new()
	root.name = "SpinGoRound"
	var cfg: Dictionary = SPIN_ENV
	_add_environment(root, cfg)
	_add_lights(root, cfg)
	_add_sky(root, cfg)

	_add_level_info(root, {
		"level_id": "spin_go_round",
		"display_name": "Spin Go Round",
		"round_index": 2,
		"start_z": 5.0,
		"finish_z": -80.0,
		"course_length": 85.0,
		"gold_time": 42.0,
		"silver_time": 58.0,
		"bronze_time": 78.0,
		"waypoints": _spin_waypoints(),
		"lane_widths": _spin_lanes(),
	})
	_add_race_manager(root)
	_add_hud(root)
	_add_kill_plane(root, -42.0)

	var course := _group(root, "Course")
	_slab(course, root, "StartPlatform", 0.0, 1.5, 19.0, 13.0, 0.0, MAT_SPIN_FLOOR)
	_slab(course, root, "SpinArena", 0.0, -16.0, 24.0, 22.0, 0.0, MAT_SPIN_FLOOR)
	_slab(course, root, "SpinBridge", 0.0, -31.0, 8.0, 8.0, 0.0, MAT_SPIN_FLOOR)
	_slab(course, root, "SpinLanding", 0.0, -49.0, 10.0, 8.0, 0.0, MAT_SPIN_FLOOR)
	_slab(course, root, "SpinRow", 0.0, -61.0, 14.0, 14.0, 0.0, MAT_SPIN_FLOOR)
	_slab(course, root, "SpinSafe", 0.0, -72.0, 10.0, 6.0, 0.0, MAT_SPIN_FLOOR)
	_slab(course, root, "FinishApproach", 0.0, -71.0, 8.0, 4.2, 0.0, MAT_SPIN_FLOOR)
	_slab(course, root, "FinishPlatform", 0.0, -80.0, 16.0, 14.0, 0.0, MAT_SPIN_FLOOR)

	_obstacle(course, root, "SweeperA", SWEEPER_SCENE, Vector3(0.0, 0.35, -11.0), {
		"spin_speed": 2.0, "push_force": 6.0, "stuns": true,
	})
	_obstacle(course, root, "SweeperB", SWEEPER_SCENE, Vector3(0.0, 0.35, -21.0), {
		"spin_speed": 2.5, "spin_direction": -1.0, "push_force": 6.4, "stuns": true,
	})
	_obstacle(course, root, "Checkpoint1", CHECKPOINT_SCENE, Vector3(0.0, 0.0, -28.0), {
		"checkpoint_name": "Checkpoint 1",
	})
	_obstacle(course, root, "MovingPlatform", MOVING_SCENE, Vector3(0.0, -0.2, -38.0), {
		"travel": Vector3(0.0, 0.0, -6.0), "speed": 2.2, "pause_time": 0.4,
	})
	_obstacle(course, root, "Checkpoint2", CHECKPOINT_SCENE, Vector3(0.0, 0.0, -49.0), {
		"checkpoint_name": "Checkpoint 2",
	})
	_obstacle(course, root, "SweeperC", SWEEPER_SCENE, Vector3(0.0, 0.35, -57.0), {
		"spin_speed": 2.8, "push_force": 6.8, "stuns": true,
	})
	_obstacle(course, root, "Centrifuge", SPIN_SCENE, Vector3(0.0, -0.2, -63.0), {
		"spin_speed": 1.8,
	})
	_obstacle(course, root, "BallRain", DROPPER_SCENE, Vector3(0.0, 8.5, -61.0), {
		"interval": 2.3, "drop_radius": 3.6, "max_balls": 5,
		"start_delay": 2.0, "column_spread": 1.8,
	})
	_obstacle(course, root, "Checkpoint3", CHECKPOINT_SCENE, Vector3(0.0, 0.0, -72.0), {
		"checkpoint_name": "Checkpoint 3",
	})
	_obstacle(course, root, "FinishLine", FINISH_SCENE, Vector3(0.0, 0.0, -80.0))

	var decor := _group(root, "Decor")
	_arch(decor, root, "StartGate", -2.5, 0.0, 21.0, 6.4, MAT_SPIN_BLUE,
		MAT_SPIN_GOLD, "SPIN GO ROUND")
	# Muros azules del estadio y pasamanos dorados.
	_mesh_box(decor, root, "ArenaWallLeft", Vector3(-12.2, 1.3, -16.0),
		Vector3(1.2, 2.6, 22.0), MAT_SPIN_WALL)
	_mesh_box(decor, root, "ArenaWallRight", Vector3(12.2, 1.3, -16.0),
		Vector3(1.2, 2.6, 22.0), MAT_SPIN_WALL)
	_mesh_box(decor, root, "ArenaTrimLeft", Vector3(-12.2, 2.65, -16.0),
		Vector3(1.4, 0.2, 22.0), MAT_SPIN_GOLD)
	_mesh_box(decor, root, "ArenaTrimRight", Vector3(12.2, 2.65, -16.0),
		Vector3(1.4, 0.2, 22.0), MAT_SPIN_GOLD)
	_mesh_box(decor, root, "StartWallLeft", Vector3(-9.6, 1.0, 2.0),
		Vector3(1.0, 2.0, 12.0), MAT_SPIN_WALL)
	_mesh_box(decor, root, "StartWallRight", Vector3(9.6, 1.0, 2.0),
		Vector3(1.0, 2.0, 12.0), MAT_SPIN_WALL)
	_rail(decor, root, "StartRailLeft", -9.0, 2.0, 11.0, 0.0, MAT_SPIN_GOLD, true)
	_rail(decor, root, "StartRailRight", 9.0, 2.0, 11.0, 0.0, MAT_SPIN_GOLD, true)
	_rail(decor, root, "BridgeRailLeft", -4.1, -31.0, 8.0, 0.0, MAT_SPIN_GOLD, true)
	_rail(decor, root, "BridgeRailRight", 4.1, -31.0, 8.0, 0.0, MAT_SPIN_GOLD, true)
	_rail(decor, root, "LandingRailLeft", -5.1, -49.0, 8.0, 0.0, MAT_SPIN_GOLD, true)
	_rail(decor, root, "LandingRailRight", 5.1, -49.0, 8.0, 0.0, MAT_SPIN_GOLD, true)
	_mesh_box(decor, root, "SpinRowWallLeft", Vector3(-7.2, 1.0, -61.0),
		Vector3(0.9, 2.0, 14.0), MAT_SPIN_WALL)
	_mesh_box(decor, root, "SpinRowWallRight", Vector3(7.2, 1.0, -61.0),
		Vector3(0.9, 2.0, 14.0), MAT_SPIN_WALL)
	_rail(decor, root, "FinishRailLeft", -8.1, -80.0, 14.0, 0.0, MAT_SPIN_GOLD, true)
	_rail(decor, root, "FinishRailRight", 8.1, -80.0, 14.0, 0.0, MAT_SPIN_GOLD, true)
	for i in 5:
		_hazard(decor, root, "HazardA%d" % i, 0.0, -55.0 - float(i) * 3.0, 0.0, 12.5)
	# Peonzas y bolas fuera del recorrido.
	_decor_top(decor, root, "TopLeft", Vector3(-9.6, 0.0, -12.0), 1.2,
		MAT_SPIN_MAGENTA, MAT_SPIN_GOLD)
	_decor_top(decor, root, "TopRight", Vector3(9.6, 0.0, -20.0), 1.0,
		MAT_SPIN_LIME, MAT_SPIN_ORANGE)
	_decor_top(decor, root, "TopSpinLeft", Vector3(-9.2, 0.0, -61.0), 0.9,
		MAT_SPIN_ORANGE, MAT_SPIN_GOLD)
	_decor_top(decor, root, "TopSpinRight", Vector3(9.2, 0.0, -66.0), 0.8,
		MAT_SPIN_MAGENTA, MAT_SPIN_LIME)
	_mesh_sphere(decor, root, "BallLeftA", Vector3(-9.2, 1.0, -7.0), 1.0, MAT_SPIN_MAGENTA)
	_mesh_sphere(decor, root, "BallLeftB", Vector3(-9.2, 2.8, -7.0), 0.85, MAT_SPIN_LIME)
	_mesh_sphere(decor, root, "BallRightA", Vector3(9.2, 1.0, -24.0), 1.0, MAT_SPIN_ORANGE)
	_mesh_sphere(decor, root, "BallRightB", Vector3(9.2, 2.8, -24.0), 0.85, MAT_SPIN_BLUE)
	_mesh_torus(decor, root, "FinishRing", Vector3(0.0, 5.2, -88.0),
		3.2, 3.65, MAT_SPIN_GOLD, Vector3(90.0, 0.0, 0.0))
	# Pelota de playa CC-BY de Poly Pizza (the_ normalgamer), integrada como
	# atrezo del circuito de las bolas.
	_prop(decor, root, "BeachBallA", "res://assets/props/beach_ball.glb",
		Vector3(-9.2, 1.0, -9.0), 2.0, 18.0)
	_prop(decor, root, "BeachBallB", "res://assets/props/beach_ball.glb",
		Vector3(9.4, 1.0, -23.0), 1.5, -35.0)
	_prop(decor, root, "BeachBallC", "res://assets/props/beach_ball.glb",
		Vector3(8.8, 1.0, -78.0), 1.6, 55.0)
	_prop(decor, root, "BeachBallD", "res://assets/props/beach_ball.glb",
		Vector3(-20.0, -5.0, -45.0), 4.0, 10.0)
	_lights(decor, root, [Vector3(0.0, 4.5, -16.0), Vector3(0.0, 4.5, -61.0),
		Vector3(0.0, 4.5, -80.0)], Color(0.55, 0.95, 1.0), 1.4, 18.0)

	_arena_decor(root, {
		"section_centers": PackedVector3Array([
			Vector3(0.0, 0.0, 1.5), Vector3(0.0, 0.0, -16.0),
			Vector3(0.0, 0.0, -31.0), Vector3(0.0, 0.0, -49.0),
			Vector3(0.0, 0.0, -61.0), Vector3(0.0, 0.0, -72.0),
			Vector3(0.0, 0.0, -80.0),
		]),
		"section_sizes": PackedVector2Array([
			Vector2(19.0, 13.0), Vector2(24.0, 22.0), Vector2(8.0, 8.0),
			Vector2(10.0, 8.0), Vector2(14.0, 14.0), Vector2(10.0, 6.0),
			Vector2(16.0, 14.0),
		]),
		"section_colors": PackedColorArray([
			Color(1.0, 0.8, 0.2), Color(0.2, 0.9, 1.0), Color(1.0, 0.6, 0.2),
			Color(0.2, 0.9, 1.0), Color(1.0, 0.45, 0.8), Color(1.0, 0.8, 0.2),
			Color(1.0, 0.86, 0.3),
		]),
		"sea_deep": Color(0.02, 0.14, 0.4),
		"sea_mid": Color(0.1, 0.5, 0.8),
		"sea_foam": Color(0.72, 0.95, 1.0),
		"island_palette": PackedColorArray([
			Color(0.15, 0.7, 1.0), Color(1.0, 0.6, 0.2),
			Color(1.0, 0.36, 0.68), Color(0.55, 1.0, 0.4),
			Color(0.2, 0.9, 0.9),
		]),
		"rock_color": Color(0.08, 0.18, 0.42),
		"distant_color": Color(0.42, 0.72, 0.96),
		"build_arches": false,
		"build_pendulum_frames": false,
		"build_light_towers": false,
	})
	_crowd(root, {
		"per_row": 50, "stand_offset": 18.0, "stand_length": 110.0,
		"stand_center_z": -40.0,
	})
	_add_post(root, cfg)
	_add_director(root, 5.0, -80.0, 85.0)
	_add_player(root)
	_add_pause(root)
	_save(root, OUT_DIR + "/spin_go_round.tscn")


func _spin_waypoints() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0.0, 0.2, 1.0),
		Vector3(0.0, 0.2, -5.0),
		Vector3(0.0, 0.2, -9.0),
		Vector3(0.0, 0.2, -14.0),
		Vector3(0.0, 0.2, -20.0),
		Vector3(0.0, 0.2, -25.0),
		Vector3(0.0, 0.2, -28.0),
		Vector3(0.0, 0.2, -31.0),
		Vector3(0.0, 0.2, -34.5),
		Vector3(0.0, 0.2, -37.0),
		Vector3(0.0, 0.2, -40.0),
		Vector3(0.0, 0.2, -44.0),
		Vector3(0.0, 0.2, -47.0),
		Vector3(0.0, 0.2, -50.0),
		Vector3(0.0, 0.2, -54.0),
		Vector3(0.0, 0.2, -59.0),
		Vector3(0.0, 0.2, -63.0),
		Vector3(0.0, 0.2, -67.0),
		Vector3(0.0, 0.2, -70.0),
		Vector3(0.0, 0.2, -73.0),
		Vector3(0.0, 0.2, -77.0),
		Vector3(0.0, 0.2, -80.0),
		Vector3(0.0, 0.2, -84.0),
	])


func _spin_lanes() -> PackedFloat32Array:
	return PackedFloat32Array([
		3.5, 3.0, 2.4, 2.6, 2.6, 2.2, 1.8, 2.0, 1.4, 1.2, 1.2, 1.4, 1.8,
		2.2, 2.2, 1.8, 1.6, 1.8, 2.0, 2.0, 2.2, 2.6, 2.6,
	])


# ------------------------------------------------------------ ronda 3: Pivot

func _build_pivot_panic() -> void:
	var root := Node3D.new()
	root.name = "PivotPanic"
	var cfg: Dictionary = PIVOT_ENV
	_add_environment(root, cfg)
	_add_lights(root, cfg)
	_add_sky(root, cfg)

	_add_level_info(root, {
		"level_id": "pivot_panic",
		"display_name": "Pivot Panic",
		"round_index": 3,
		"start_z": 5.0,
		"finish_z": -145.0,
		"course_length": 150.0,
		"gold_time": 62.0,
		"silver_time": 84.0,
		"bronze_time": 112.0,
		"waypoints": _pivot_waypoints(),
		"lane_widths": _pivot_lanes(),
	})
	_add_race_manager(root)
	_add_hud(root)
	_add_kill_plane(root, -70.0)

	var course := _group(root, "Course")
	_slab(course, root, "StartPlatform", 0.0, 1.5, 17.0, 13.0, 0.0, MAT_PIVOT_FLOOR)
	_slab(course, root, "SweeperBridge", 0.0, -10.0, 6.0, 10.0, 0.0, MAT_PIVOT_FLOOR)
	_slab(course, root, "SafeOne", 0.0, -19.0, 10.0, 6.0, 0.0, MAT_PIVOT_FLOOR_ALT)
	_platform(course, root, "SeeSawBase", Vector3(0.0, -2.15, -30.0),
		Vector3(1.4, 2.4, 1.4), MAT_PIVOT_BLUE)
	_obstacle(course, root, "SeeSaw", SEESAW_SCENE, Vector3(0.0, -0.175, -30.0), {
		"max_tilt": 0.5, "max_roll": 0.16, "responsiveness": 6.0,
		"idle_sway": 0.0, "tip_threshold": 0.02, "roll_gain": 2.5,
		"instability": 0.02, "rider_range": 5.0, "slide_threshold": 0.35,
		"slide_speed": 4.2, "edge_cutoff": -4.7,
	})
	_platform(course, root, "SeeSawRamp", Vector3(0.0, -1.5275, -37.25),
		Vector3(10.0, 0.5, 6.264), MAT_PIVOT_FLOOR_ALT, 24.53)
	_slab(course, root, "SeeSawLanding", 0.0, -42.95, 10.0, 5.9, 0.0,
		MAT_PIVOT_FLOOR)
	_obstacle(course, root, "Checkpoint2", CHECKPOINT_SCENE, Vector3(0.0, 0.0, -43.5), {
		"checkpoint_name": "Checkpoint 2",
	})
	_slab(course, root, "PendulumBridge", 0.0, -55.0, 5.0, 20.0, 0.0,
		MAT_PIVOT_FLOOR_ALT)
	_obstacle(course, root, "PendulumA", PENDULUM_SCENE, Vector3(0.0, 5.2, -49.0), {
		"max_angle": 1.05, "swing_speed": 0.0021, "push_force": 12.0,
		"phase_offset": 0.0,
	})
	_obstacle(course, root, "PendulumB", PENDULUM_SCENE, Vector3(0.0, 5.2, -54.0), {
		"max_angle": 1.05, "swing_speed": 0.0021, "push_force": 12.0,
		"phase_offset": 1.57,
	})
	_obstacle(course, root, "PendulumC", PENDULUM_SCENE, Vector3(0.0, 5.2, -59.0), {
		"max_angle": 1.1, "swing_speed": 0.0024, "push_force": 12.0,
		"phase_offset": 0.8,
	})
	_obstacle(course, root, "PendulumD", PENDULUM_SCENE, Vector3(0.0, 5.2, -64.0), {
		"max_angle": 1.1, "swing_speed": 0.0024, "push_force": 12.0,
		"phase_offset": 2.4,
	})
	_slab(course, root, "SafeTwo", 0.0, -70.0, 10.0, 6.0, 0.0, MAT_PIVOT_FLOOR)
	_obstacle(course, root, "Checkpoint3", CHECKPOINT_SCENE, Vector3(0.0, 0.0, -70.0), {
		"checkpoint_name": "Checkpoint 3",
	})
	_obstacle(course, root, "MovingPlatform", MOVING_SCENE, Vector3(0.0, -0.2, -75.0), {
		"travel": Vector3(0.0, 0.0, -6.0), "speed": 2.2, "pause_time": 0.4,
	})
	_slab(course, root, "MovingLanding", 0.0, -86.0, 10.0, 8.0, 0.0,
		MAT_PIVOT_FLOOR_ALT)
	_obstacle(course, root, "Checkpoint4", CHECKPOINT_SCENE, Vector3(0.0, 0.0, -86.0), {
		"checkpoint_name": "Checkpoint 4",
	})
	_slab(course, root, "WindBridge", 0.0, -98.0, 4.0, 16.0, 0.2, MAT_PIVOT_FLOOR)
	_obstacle(course, root, "WindTunnelA", WIND_SCENE, Vector3(0.0, 0.4, -94.0), {
		"wind_direction": Vector3(1.0, 0.0, 0.0), "strength": 5.4,
		"gust_amplitude": 1.9,
	})
	_obstacle(course, root, "WindTunnelB", WIND_SCENE, Vector3(0.0, 0.4, -102.0), {
		"wind_direction": Vector3(-1.0, 0.0, 0.0), "strength": 5.4,
		"gust_amplitude": 1.9,
	})
	_obstacle(course, root, "Launcher", LAUNCHER_SCENE, Vector3(0.0, 0.4, -105.0), {
		"launch_force": 10.0, "launch_up": 7.8, "cooldown": 2.0,
		"launch_direction": Vector3(0.0, 0.0, -1.0),
	})
	_slab(course, root, "CannonLanding", 0.0, -118.0, 12.0, 12.0, 1.0,
		MAT_PIVOT_FLOOR_ALT)
	_obstacle(course, root, "Checkpoint5", CHECKPOINT_SCENE, Vector3(0.0, 1.0, -120.0), {
		"checkpoint_name": "Checkpoint 5",
	})
	_slab(course, root, "FinalRun", 0.0, -130.0, 10.0, 14.0, 1.0, MAT_PIVOT_FLOOR)
	_obstacle(course, root, "SweeperFinal", SWEEPER_SCENE, Vector3(0.0, 1.35, -127.0), {
		"spin_speed": 2.6, "push_force": 7.0, "stuns": true,
	})
	_obstacle(course, root, "PendulumFinal", PENDULUM_SCENE, Vector3(0.0, 6.2, -133.0), {
		"max_angle": 1.0, "swing_speed": 0.0025, "push_force": 12.0,
		"phase_offset": 0.4,
	})
	_obstacle(course, root, "BouncePadFinal", BOUNCE_SCENE, Vector3(0.0, 1.0, -137.0), {
		"bounce_strength": 10.5,
	})
	_slab(course, root, "FinishPlatform", 0.0, -145.0, 14.0, 14.0, 4.0,
		MAT_PIVOT_FLOOR_ALT)
	_obstacle(course, root, "FinishLine", FINISH_SCENE, Vector3(0.0, 4.0, -145.0))

	# La salida y el pivote central.
	_obstacle(course, root, "Checkpoint1", CHECKPOINT_SCENE, Vector3(0.0, 0.0, -19.0), {
		"checkpoint_name": "Checkpoint 1",
	})
	_obstacle(course, root, "SweeperStart", SWEEPER_SCENE, Vector3(0.0, 0.35, -10.0), {
		"spin_speed": 2.2, "push_force": 6.5, "stuns": true,
	})

	var decor := _group(root, "Decor")
	_arch(decor, root, "StartGate", -2.5, 0.0, 19.0, 6.8, MAT_PIVOT_BLUE,
		MAT_PIVOT_GOLD, "PIVOT PANIC")
	_mesh_box(decor, root, "StartWallLeft", Vector3(-8.6, 1.2, 2.0),
		Vector3(1.1, 2.4, 12.0), MAT_PIVOT_WALL)
	_mesh_box(decor, root, "StartWallRight", Vector3(8.6, 1.2, 2.0),
		Vector3(1.1, 2.4, 12.0), MAT_PIVOT_WALL)
	_rail(decor, root, "StartRailLeft", -8.0, 2.0, 11.0, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "StartRailRight", 8.0, 2.0, 11.0, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "BridgeRailLeft", -3.1, -10.0, 10.0, 0.0, MAT_PIVOT_RAIL, true)
	_rail(decor, root, "BridgeRailRight", 3.1, -10.0, 10.0, 0.0, MAT_PIVOT_RAIL, true)
	_rail(decor, root, "SafeOneRailLeft", -5.1, -19.0, 6.0, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "SafeOneRailRight", 5.1, -19.0, 6.0, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "LandingRailLeft", -5.1, -43.0, 5.9, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "LandingRailRight", 5.1, -43.0, 5.9, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "PendulumRailLeft", -2.6, -55.0, 20.0, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "PendulumRailRight", 2.6, -55.0, 20.0, 0.0, MAT_PIVOT_GOLD, true)
	_mesh_box(decor, root, "SafeTwoWallLeft", Vector3(-5.2, 0.9, -70.0),
		Vector3(0.9, 1.8, 6.0), MAT_PIVOT_WALL)
	_mesh_box(decor, root, "SafeTwoWallRight", Vector3(5.2, 0.9, -70.0),
		Vector3(0.9, 1.8, 6.0), MAT_PIVOT_WALL)
	_rail(decor, root, "LandingRailLeftB", -5.1, -86.0, 8.0, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "LandingRailRightB", 5.1, -86.0, 8.0, 0.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "WindRailLeft", -2.1, -98.0, 16.0, 0.2, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "WindRailRight", 2.1, -98.0, 16.0, 0.2, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "FinalRailLeft", -5.1, -130.0, 14.0, 1.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "FinalRailRight", 5.1, -130.0, 14.0, 1.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "FinishRailLeft", -7.1, -145.0, 14.0, 4.0, MAT_PIVOT_GOLD, true)
	_rail(decor, root, "FinishRailRight", 7.1, -145.0, 14.0, 4.0, MAT_PIVOT_GOLD, true)
	for i in 4:
		_hazard(decor, root, "HazardFinal%d" % i, 0.0, -125.0 - float(i) * 3.0, 1.0, 9.0)
	# Gran bastidor dorado alrededor del balancín, como el pivote de referencia.
	_mesh_box(decor, root, "PivotPostLeft", Vector3(-6.1, 3.5, -30.0),
		Vector3(0.6, 7.0, 0.8), MAT_PIVOT_GOLD)
	_mesh_box(decor, root, "PivotPostRight", Vector3(6.1, 3.5, -30.0),
		Vector3(0.6, 7.0, 0.8), MAT_PIVOT_GOLD)
	_mesh_box(decor, root, "PivotBeam", Vector3(0.0, 7.0, -30.0),
		Vector3(12.8, 0.55, 0.8), MAT_PIVOT_GOLD)
	_mesh_torus(decor, root, "PivotRing", Vector3(0.0, 3.6, -30.0),
		3.1, 3.55, MAT_PIVOT_GOLD, Vector3(90.0, 0.0, 0.0))
	_mesh_sphere(decor, root, "PivotBall", Vector3(0.0, 7.8, -30.0), 0.7, MAT_PIVOT_CREAM)
	# Marcos de los péndulos.
	for i in 4:
		var z := -49.0 - float(i) * 5.0
		_mesh_box(decor, root, "PendFramePostLeft%d" % i, Vector3(-3.3, 3.2, z),
			Vector3(0.35, 6.4, 0.45), MAT_PIVOT_GOLD)
		_mesh_box(decor, root, "PendFramePostRight%d" % i, Vector3(3.3, 3.2, z),
			Vector3(0.35, 6.4, 0.45), MAT_PIVOT_GOLD)
		_mesh_box(decor, root, "PendFrameBeam%d" % i, Vector3(0.0, 6.4, z),
			Vector3(7.0, 0.4, 0.45), MAT_PIVOT_GOLD)
	_mesh_torus(decor, root, "PendFrameRing", Vector3(0.0, 6.5, -55.0),
		2.1, 2.4, MAT_PIVOT_GOLD, Vector3(90.0, 0.0, 0.0))
	# Aros y bolas de color alrededor del circuito.
	_mesh_sphere(decor, root, "PinkBallA", Vector3(-8.0, 1.0, -18.0), 1.1, MAT_PIVOT_RAIL)
	_mesh_sphere(decor, root, "PinkBallB", Vector3(8.0, 1.0, -43.0), 1.0, MAT_PIVOT_BLUE)
	_mesh_sphere(decor, root, "PinkBallC", Vector3(-8.4, 1.0, -86.0), 0.9, MAT_PIVOT_CREAM)
	_mesh_torus(decor, root, "LandingRing", Vector3(0.0, 4.6, -43.0),
		2.5, 2.85, MAT_PIVOT_GOLD, Vector3(90.0, 0.0, 0.0))
	_mesh_torus(decor, root, "LauncherRing", Vector3(0.0, 2.1, -105.0),
		2.2, 2.55, MAT_PIVOT_GOLD, Vector3(90.0, 0.0, 0.0))
	_mesh_torus(decor, root, "FinishRing", Vector3(0.0, 8.4, -145.0),
		3.3, 3.8, MAT_PIVOT_GOLD, Vector3(90.0, 0.0, 0.0))
	_prop(decor, root, "BeachBallA", "res://assets/props/beach_ball.glb",
		Vector3(-7.8, 1.0, -19.0), 1.5, 20.0)
	_prop(decor, root, "BeachBallB", "res://assets/props/beach_ball.glb",
		Vector3(7.6, 1.0, -86.0), 1.2, -42.0)
	_prop(decor, root, "BeachBallC", "res://assets/props/beach_ball.glb",
		Vector3(-10.0, -4.0, -62.0), 3.2, 5.0)
	_lights(decor, root, [Vector3(0.0, 4.5, -30.0), Vector3(0.0, 4.5, -55.0),
		Vector3(0.0, 4.5, -98.0), Vector3(0.0, 6.0, -145.0)],
		Color(1.0, 0.72, 0.45), 1.35, 18.0)

	_arena_decor(root, {
		"section_centers": PackedVector3Array([
			Vector3(0.0, 0.0, 1.5), Vector3(0.0, 0.0, -10.0),
			Vector3(0.0, 0.0, -19.0), Vector3(0.0, 0.0, -43.0),
			Vector3(0.0, 0.0, -55.0), Vector3(0.0, 0.0, -70.0),
			Vector3(0.0, 0.0, -86.0), Vector3(0.0, 0.2, -98.0),
			Vector3(0.0, 1.0, -118.0), Vector3(0.0, 1.0, -130.0),
			Vector3(0.0, 4.0, -145.0),
		]),
		"section_sizes": PackedVector2Array([
			Vector2(17.0, 13.0), Vector2(6.0, 10.0), Vector2(10.0, 6.0),
			Vector2(10.0, 5.9), Vector2(5.0, 20.0), Vector2(10.0, 6.0),
			Vector2(10.0, 8.0), Vector2(4.0, 16.0), Vector2(12.0, 12.0),
			Vector2(10.0, 14.0), Vector2(14.0, 14.0),
		]),
		"section_colors": PackedColorArray([
			Color(1.0, 0.8, 0.2), Color(1.0, 0.45, 0.75), Color(1.0, 0.6, 0.3),
			Color(1.0, 0.45, 0.75), Color(1.0, 0.8, 0.2), Color(1.0, 0.6, 0.3),
			Color(1.0, 0.45, 0.75), Color(1.0, 0.8, 0.2), Color(1.0, 0.6, 0.3),
			Color(1.0, 0.8, 0.2), Color(1.0, 0.86, 0.3),
		]),
		"sea_deep": Color(0.22, 0.03, 0.3),
		"sea_mid": Color(0.68, 0.18, 0.52),
		"sea_foam": Color(1.0, 0.78, 0.92),
		"island_palette": PackedColorArray([
			Color(1.0, 0.4, 0.7), Color(1.0, 0.8, 0.25),
			Color(0.36, 0.55, 1.0), Color(0.55, 1.0, 0.45),
			Color(0.85, 0.45, 1.0),
		]),
		"rock_color": Color(0.28, 0.1, 0.38),
		"distant_color": Color(0.78, 0.46, 0.86),
		"build_arches": false,
		"build_pendulum_frames": false,
		"build_light_towers": false,
	})
	_crowd(root, {
		"per_row": 50, "stand_offset": 17.0, "stand_length": 120.0,
		"stand_center_z": -72.0,
	})
	_add_post(root, cfg)
	_add_director(root, 5.0, -145.0, 150.0)
	_add_player(root)
	_add_pause(root)
	_save(root, OUT_DIR + "/pivot_panic.tscn")


func _pivot_waypoints() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0.0, 0.2, 1.0),
		Vector3(0.0, 0.2, -5.0),
		Vector3(0.0, 0.2, -10.0),
		Vector3(0.0, 0.2, -14.0),
		Vector3(0.0, 0.2, -19.0),
		Vector3(0.0, 0.2, -24.0),
		Vector3(0.0, 0.2, -27.0),
		Vector3(0.0, 0.2, -30.0),
		Vector3(0.0, 0.2, -34.0),
		Vector3(0.0, 0.2, -37.0),
		Vector3(0.0, 0.2, -40.0),
		Vector3(0.0, 0.2, -43.0),
		Vector3(0.0, 0.2, -46.0),
		Vector3(0.0, 0.2, -50.0),
		Vector3(0.0, 0.2, -55.0),
		Vector3(0.0, 0.2, -60.0),
		Vector3(0.0, 0.2, -64.0),
		Vector3(0.0, 0.2, -68.0),
		Vector3(0.0, 0.2, -72.0),
		Vector3(0.0, 0.2, -75.0),
		Vector3(0.0, 0.2, -78.0),
		Vector3(0.0, 0.2, -81.0),
		Vector3(0.0, 0.2, -84.0),
		Vector3(0.0, 0.2, -87.0),
		Vector3(0.0, 0.2, -91.0),
		Vector3(0.0, 0.2, -97.0),
		Vector3(0.0, 0.2, -103.0),
		Vector3(0.0, 0.2, -106.0),
		Vector3(0.0, 0.2, -115.0),
		Vector3(0.0, 0.2, -120.0),
		Vector3(0.0, 0.2, -126.0),
		Vector3(0.0, 0.2, -130.0),
		Vector3(0.0, 0.2, -134.0),
		Vector3(0.0, 0.2, -137.0),
		Vector3(0.0, 4.2, -141.0),
		Vector3(0.0, 4.2, -145.0),
		Vector3(0.0, 4.2, -148.0),
	])


func _pivot_lanes() -> PackedFloat32Array:
	return PackedFloat32Array([
		3.0, 2.0, 1.4, 1.4, 2.2, 1.6, 1.2, 1.2, 1.2, 1.0, 1.0, 2.0,
		1.8, 1.2, 1.0, 1.0, 1.0, 1.6, 2.0, 1.6, 1.2, 1.2, 1.2, 1.6,
		1.0, 0.8, 0.8, 1.0, 2.0, 2.0, 1.4, 1.2, 1.0, 1.2, 1.5, 1.8, 2.0,
	])
