extends Node3D

## Set-dressing del circuito construido en runtime: mar de nubes bajo el mapa,
## islas flotantes, arcos de neón, torres de luz, bordes luminosos en cada
## plataforma, montañas lejanas, anillos de estadio y chispas ambientales.
## Todo es decorativo: no añade colisión ni altera el recorrido.

const TOY_SHADER: Shader = preload("res://shaders/toy.gdshader")
const SEA_SHADER: Shader = preload("res://shaders/void_sea.gdshader")

## Top surface of every walkable slab in `main.tscn` (center + size).
const SECTIONS := [
	{"name": "Start", "center": Vector3(0.0, 0.0, 2.0), "size": Vector2(14.0, 12.0), "color": Color(0.62, 0.9, 1.0)},
	{"name": "SweeperHall", "center": Vector3(0.0, 0.0, -15.5), "size": Vector2(9.0, 18.0), "color": Color(0.7, 1.0, 1.0)},
	{"name": "ConveyorHall", "center": Vector3(0.0, 0.0, -34.75), "size": Vector2(12.0, 14.5), "color": Color(1.0, 0.82, 0.95)},
	{"name": "SeeSawLanding", "center": Vector3(0.0, 0.0, -62.5), "size": Vector2(10.0, 5.0), "color": Color(0.85, 1.0, 0.6)},
	{"name": "PendulumBridge", "center": Vector3(0.0, 0.0, -78.0), "size": Vector2(5.0, 22.0), "color": Color(1.0, 0.9, 0.5)},
	{"name": "LandingA", "center": Vector3(0.0, 0.6, -112.5), "size": Vector2(10.0, 7.0), "color": Color(0.62, 0.9, 1.0)},
	{"name": "WindBridge", "center": Vector3(0.0, 0.6, -131.5), "size": Vector2(4.0, 17.0), "color": Color(0.88, 0.76, 1.0)},
	{"name": "CannonLanding", "center": Vector3(0.0, 1.0, -154.0), "size": Vector2(12.0, 14.0), "color": Color(0.7, 1.0, 1.0)},
	{"name": "BallCorridor", "center": Vector3(0.0, 1.0, -171.0), "size": Vector2(7.0, 18.0), "color": Color(0.88, 0.76, 1.0)},
	{"name": "FinalRun", "center": Vector3(0.0, 1.0, -189.0), "size": Vector2(9.0, 14.0), "color": Color(1.0, 0.9, 0.5)},
	{"name": "Finish", "center": Vector3(0.0, 1.0, -206.0), "size": Vector2(14.0, 16.0), "color": Color(0.85, 1.0, 0.6)},
]

const ISLAND_COLORS := [
	Color(0.58, 0.95, 0.55),
	Color(1.0, 0.8, 0.45),
	Color(0.6, 0.9, 1.0),
	Color(1.0, 0.66, 0.82),
	Color(0.76, 0.68, 1.0),
]

const ROCK_COLOR := Color(0.24, 0.26, 0.48)
const DISTANT_COLOR := Color(0.6, 0.72, 0.92)

var _rng := RandomNumberGenerator.new()
var _toy_cache: Dictionary = {}


func _ready() -> void:
	_rng.seed = 20261023
	_build_cloud_sea()
	_build_platform_edges()
	_build_islands()
	_build_distant_mountains()
	_build_arches()
	_build_light_towers()
	_build_stadium_rings()
	_build_ambient_sparks()


# ---------------------------------------------------------------- materials
func _toy_material(color: Color, rim: float = 0.9, emission: float = 0.08) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f" % [color.to_html(), rim, emission]
	if _toy_cache.has(key):
		return _toy_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOY_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("rim_color", color.lightened(0.4))
	mat.set_shader_parameter("rim_strength", rim)
	mat.set_shader_parameter("emission_strength", emission)
	_toy_cache[key] = mat
	return mat


func _glow_material(color: Color, energy: float = 2.4) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _flat_material(color: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.emission_enabled = emission_energy > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = emission_energy
	return mat


# ------------------------------------------------------------------ helpers
func _box(size: Vector3, position: Vector3, material: Material, node_name: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _cylinder(top_radius: float, bottom_radius: float, height: float, position: Vector3, material: Material, node_name: String, segments: int = 12, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
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
	add_child(instance)
	return instance


func _sphere(radius: float, height: float, position: Vector3, material: Material, node_name: String, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.scale = scale
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _torus(inner_radius: float, outer_radius: float, position: Vector3, material: Material, node_name: String, rot: Vector3 = Vector3.ZERO, rings: int = 24) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = rings
	mesh.ring_segments = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _omni_light(position: Vector3, color: Color, energy: float, light_range: float, node_name: String) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	add_child(light)
	return light


# ------------------------------------------------------------------- pieces
func _build_cloud_sea() -> void:
	var material := ShaderMaterial.new()
	material.shader = SEA_SHADER
	material.set_shader_parameter("deep_color", Color(0.24, 0.38, 0.72))
	material.set_shader_parameter("mid_color", Color(0.64, 0.84, 1.0))
	material.set_shader_parameter("foam_color", Color(1.0, 0.98, 1.0))
	material.set_shader_parameter("wave_height", 1.3)
	material.set_shader_parameter("wave_scale", 0.065)
	material.set_shader_parameter("flow_speed", 0.4)

	var plane := PlaneMesh.new()
	plane.size = Vector2(620.0, 780.0)
	plane.subdivide_width = 72
	plane.subdivide_depth = 90
	plane.material = material

	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	sea.mesh = plane
	sea.position = Vector3(0.0, -16.0, -100.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


func _build_platform_edges() -> void:
	var support_material := _toy_material(ROCK_COLOR, 0.6, 0.02)
	var cloud_material := _toy_material(Color(0.94, 0.97, 1.0), 0.5, 0.15)

	for section in SECTIONS:
		var section_name: String = section["name"]
		var center: Vector3 = section["center"]
		var size: Vector2 = section["size"]
		var color: Color = section["color"]
		var glow := _glow_material(color, 2.6)
		var top_y: float = center.y

		# Neon trim along both long edges.
		var rail_x: float = size.x * 0.5 - 0.12
		var rail_length: float = size.y - 0.25
		_box(Vector3(0.16, 0.1, rail_length), Vector3(center.x - rail_x, top_y + 0.05, center.z), glow, "RailL_%s" % section_name)
		_box(Vector3(0.16, 0.1, rail_length), Vector3(center.x + rail_x, top_y + 0.05, center.z), glow, "RailR_%s" % section_name)

		# Soft glow on the underside, visible while falling.
		_box(Vector3(minf(size.x * 0.7, 4.0), 0.08, rail_length * 0.85), Vector3(center.x, top_y - 0.58, center.z), _glow_material(color, 1.4), "UnderGlow_%s" % section_name)

		# Hanging supports.
		var pylon_count := 2
		for i in pylon_count:
			var side := -1.0 if i == 0 else 1.0
			var px: float = center.x + side * minf(size.x * 0.32, 2.6)
			var pz: float = center.z + (1.0 if i == 0 else -1.0) * size.y * 0.32
			var pylon_height := 11.0
			_cylinder(0.16, 0.38, pylon_height, Vector3(px, top_y - pylon_height * 0.5 - 0.45, pz), support_material, "Pylon_%s_%d" % [section_name, i], 8)
			_torus(0.42, 0.58, Vector3(px, top_y - 0.62, pz), _glow_material(color, 1.8), "PylonRing_%s_%d" % [section_name, i], Vector3.ZERO, 16)

		# A couple of cloud puffs so the slab does not look like it is glued to air.
		for i in 2:
			var cx: float = center.x + (-1.0 if i == 0 else 1.0) * size.x * 0.62
			var cz: float = center.z + (-1.0 if i == 0 else 1.0) * size.y * 0.3
			_sphere(1.6, 1.0, Vector3(cx, top_y - 3.6 - float(i) * 0.7, cz), cloud_material, "Cloud_%s_%d" % [section_name, i], Vector3(1.6, 0.7, 1.2))


func _build_islands() -> void:
	for i in 16:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := side * _rng.randf_range(24.0, 44.0)
		var z := _rng.randf_range(-235.0, 18.0)
		var top_y := _rng.randf_range(-9.0, -2.0)
		var radius := _rng.randf_range(3.0, 6.5)
		var rock_height := _rng.randf_range(2.5, 4.5)
		var color: Color = ISLAND_COLORS[_rng.randi() % ISLAND_COLORS.size()]

		_cylinder(radius * 0.92, radius * 0.42, rock_height, Vector3(x, top_y - rock_height * 0.5, z), _toy_material(ROCK_COLOR, 0.55, 0.02), "IslandRock_%d" % i, 9)
		_sphere(radius, radius * 0.5, Vector3(x, top_y + 0.05, z), _toy_material(color, 0.7, 0.09), "IslandTop_%d" % i, Vector3(1.0, 1.0, 1.0))

		# Crystal garden: small glowing cones.
		for c in _rng.randi_range(1, 3):
			var cx := x + _rng.randf_range(-radius * 0.45, radius * 0.45)
			var cz := z + _rng.randf_range(-radius * 0.45, radius * 0.45)
			var crystal_height := _rng.randf_range(1.0, 2.4)
			_cylinder(0.0, _rng.randf_range(0.18, 0.32), crystal_height, Vector3(cx, top_y + crystal_height * 0.5, cz), _glow_material(color.lightened(0.25), 1.9), "Crystal_%d_%d" % [i, c], 6, Vector3(_rng.randf_range(-16.0, 16.0), 0.0, _rng.randf_range(-16.0, 16.0)))

		if radius > 4.4:
			var tx := x + _rng.randf_range(-radius * 0.4, radius * 0.4)
			var tz := z + _rng.randf_range(-radius * 0.4, radius * 0.4)
			_cylinder(0.16, 0.24, 1.4, Vector3(tx, top_y + 0.7, tz), _toy_material(Color(0.42, 0.3, 0.26), 0.4), "Trunk_%d" % i, 6)
			_cylinder(0.0, 1.15, 2.4, Vector3(tx, top_y + 2.4, tz), _toy_material(Color(0.42, 0.88, 0.52), 0.6, 0.05), "Tree_%d" % i, 8)


func _build_distant_mountains() -> void:
	for i in 14:
		var angle := TAU * float(i) / 14.0 + _rng.randf_range(-0.12, 0.12)
		var distance := _rng.randf_range(190.0, 280.0)
		var x := cos(angle) * distance
		var z := -100.0 + sin(angle) * distance
		var height := _rng.randf_range(55.0, 120.0)
		var bottom := _rng.randf_range(28.0, 62.0)
		var shade := DISTANT_COLOR.lerp(Color(0.86, 0.9, 1.0), _rng.randf_range(0.0, 0.55))
		_cylinder(0.0, bottom, height, Vector3(x, -38.0 + height * 0.5, z), _flat_material(shade, 0.03), "Mountain_%d" % i, 7, Vector3(0.0, _rng.randf_range(0.0, 360.0), 0.0))


func _build_arches() -> void:
	var arches := [
		{"z": -59.5, "width": 12.0, "height": 6.5, "y": 0.0, "color": Color(0.6, 1.0, 1.0)},
		{"z": -107.5, "width": 10.0, "height": 6.0, "y": 0.6, "color": Color(0.85, 0.75, 1.0)},
		{"z": -148.5, "width": 10.0, "height": 6.0, "y": 0.8, "color": Color(1.0, 0.82, 0.35)},
		{"z": -197.0, "width": 13.0, "height": 7.0, "y": 1.0, "color": Color(0.8, 1.0, 0.55)},
	]
	for i in arches.size():
		var arch: Dictionary = arches[i]
		var z: float = arch["z"]
		var width: float = arch["width"]
		var height: float = arch["height"]
		var base_y: float = arch["y"]
		var color: Color = arch["color"]
		var solid := _toy_material(color.darkened(0.2), 0.9, 0.15)
		var glow := _glow_material(color, 2.8)
		_box(Vector3(0.45, height, 0.45), Vector3(-width * 0.5, base_y + height * 0.5, z), solid, "ArchPillarL_%d" % i)
		_box(Vector3(0.45, height, 0.45), Vector3(width * 0.5, base_y + height * 0.5, z), solid, "ArchPillarR_%d" % i)
		_box(Vector3(width + 0.45, 0.5, 0.55), Vector3(0.0, base_y + height, z), solid, "ArchBeam_%d" % i)
		_box(Vector3(width - 0.9, 0.12, 0.14), Vector3(0.0, base_y + height - 0.55, z), glow, "ArchGlow_%d" % i)
		_box(Vector3(0.12, height - 0.9, 0.14), Vector3(-width * 0.5, base_y + height * 0.5 - 0.2, z), glow, "ArchStripL_%d" % i)
		_box(Vector3(0.12, height - 0.9, 0.14), Vector3(width * 0.5, base_y + height * 0.5 - 0.2, z), glow, "ArchStripR_%d" % i)


func _build_light_towers() -> void:
	var towers := [
		{"x": -21.5, "z": -32.0, "color": Color(0.65, 0.95, 1.0)},
		{"x": 21.5, "z": -32.0, "color": Color(1.0, 0.75, 0.9)},
		{"x": -21.5, "z": -104.0, "color": Color(1.0, 0.9, 0.55)},
		{"x": 21.5, "z": -104.0, "color": Color(0.65, 0.95, 1.0)},
		{"x": -21.5, "z": -176.0, "color": Color(0.85, 0.75, 1.0)},
		{"x": 21.5, "z": -176.0, "color": Color(0.75, 1.0, 0.65)},
	]
	var metal := _toy_material(Color(0.28, 0.3, 0.52), 0.55, 0.02)
	for i in towers.size():
		var tower: Dictionary = towers[i]
		var x: float = tower["x"]
		var z: float = tower["z"]
		var color: Color = tower["color"]
		_cylinder(0.16, 0.42, 12.0, Vector3(x, 6.0, z), metal, "TowerPole_%d" % i, 8)
		_box(Vector3(1.4, 0.85, 2.4), Vector3(x, 12.3, z), _glow_material(color, 3.0), "TowerLamp_%d" % i)
		_omni_light(Vector3(x * 0.82, 11.4, z), color, 1.5, 20.0, "TowerLight_%d" % i)


func _build_stadium_rings() -> void:
	_torus(28.0, 30.0, Vector3(0.0, 24.0, -272.0), _glow_material(Color(0.7, 0.85, 1.0), 2.0), "HaloRingBack", Vector3(90.0, 0.0, 0.0), 48)
	_torus(20.0, 21.4, Vector3(0.0, 18.0, 62.0), _glow_material(Color(1.0, 0.7, 0.88), 1.8), "HaloRingFront", Vector3(90.0, 0.0, 0.0), 40)


func _build_ambient_sparks() -> void:
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.045
	spark_mesh.height = 0.09
	spark_mesh.radial_segments = 8
	spark_mesh.rings = 4
	var spark_material := _glow_material(Color(1.0, 0.97, 0.8), 2.2)
	spark_mesh.material = spark_material

	var particles := CPUParticles3D.new()
	particles.name = "AmbientSparks"
	particles.amount = 110
	particles.lifetime = 12.0
	particles.preprocess = 8.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(24.0, 7.0, 118.0)
	particles.position = Vector3(0.0, 3.0, -100.0)
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 180.0
	particles.gravity = Vector3(0.0, 0.12, 0.0)
	particles.initial_velocity_min = 0.15
	particles.initial_velocity_max = 0.7
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.4
	particles.color = Color(1.0, 1.0, 1.0, 0.8)
	particles.mesh = spark_mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)

	var motes := CPUParticles3D.new()
	motes.name = "AmbientMotes"
	motes.amount = 70
	motes.lifetime = 14.0
	motes.preprocess = 8.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(18.0, 10.0, 110.0)
	motes.position = Vector3(0.0, 6.0, -100.0)
	motes.direction = Vector3(0.0, 1.0, 0.0)
	motes.spread = 180.0
	motes.gravity = Vector3(0.05, 0.05, 0.0)
	motes.initial_velocity_min = 0.1
	motes.initial_velocity_max = 0.45
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.8
	motes.color = Color(0.7, 0.9, 1.0, 0.65)
	motes.mesh = spark_mesh
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)
