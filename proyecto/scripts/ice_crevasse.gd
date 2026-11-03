extends Node3D

## Grieta glacial: exclusiva del glaciar. El suelo del último tramo se abre por
## carriles y vuelve a cerrarse en oleadas, así que hay que cambiar de carril al
## ritmo del aviso. Caer dentro devuelve al último checkpoint.
##
## Se distingue del muro de témpanos (que cierra carriles en vertical) en que
## aquí el peligro es el hueco: el suelo desaparece bajo los pies.

@export var lanes: int = 3
@export var lane_width: float = 3.2
@export var lane_length: float = 3.6
@export var drop: float = 7.0
@export var cycle: float = 3.4
@export var warn_time: float = 0.9
@export var travel_time: float = 0.5

var _time: float = 0.0
var _bodies: Array[AnimatableBody3D] = []
var _lamps: Array[StandardMaterial3D] = []
## Cara superior de la losa cerrada (el nodo se coloca a ras del suelo).
var _closed_y: float = -0.25


func _ready() -> void:
	add_to_group("ice_crevasses")
	_build_pit()
	var ice := _ice_material()
	for i in lanes:
		var body := AnimatableBody3D.new()
		body.name = "Lane%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = true
		body.position = Vector3(_lane_x(i), _closed_y, 0.0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(lane_width * 0.96, 0.5, lane_length)
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = box.size
		mesh.mesh = block
		mesh.material_override = ice
		body.add_child(mesh)
		add_child(body)
		_bodies.append(body)

		# Franja de aviso en el borde del carril.
		var lamp := MeshInstance3D.new()
		lamp.name = "Warn%d" % i
		var lamp_mesh := BoxMesh.new()
		lamp_mesh.size = Vector3(lane_width * 0.9, 0.05, 0.18)
		lamp.mesh = lamp_mesh
		var lamp_material := _lamp_material()
		lamp.material_override = lamp_material
		lamp.position = Vector3(_lane_x(i), 0.03, lane_length * 0.5 + 0.16)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps.append(lamp_material)


func _lane_x(index: int) -> float:
	return (float(index) - float(lanes - 1) * 0.5) * lane_width


func _physics_process(delta: float) -> void:
	_time += delta
	var slot_time := cycle / float(maxi(lanes, 1))
	var slot := int(_time / slot_time)
	var open_lane := slot % lanes
	var into_slot := fmod(_time, slot_time)
	var warning := into_slot > slot_time - warn_time
	var pulse := 0.5 + 0.5 * sin(_time * 26.0)
	var rate := drop / maxf(travel_time, 0.01)
	for i in _bodies.size():
		var open := i == open_lane
		var target_y := _closed_y - drop if open else _closed_y
		_bodies[i].position.y = move_toward(_bodies[i].position.y, target_y, rate * delta)
		var lamp := _lamps[i]
		if open:
			lamp.emission_energy_multiplier = 0.0
		elif warning:
			lamp.albedo_color = Color(1.0, 0.42, 0.2)
			lamp.emission_energy_multiplier = 3.2 * pulse
		else:
			lamp.albedo_color = Color(0.55, 0.9, 1.0)
			lamp.emission_energy_multiplier = 1.0


## Carril que sigue cerrado (0 = izquierda). Lo usan los bots y los tests.
func closed_lane() -> int:
	var slot_time := cycle / float(maxi(lanes, 1))
	return (int(_time / slot_time) + 1) % lanes


func _build_pit() -> void:
	var width := lane_width * float(lanes)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.015, 0.05, 0.09)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pit := MeshInstance3D.new()
	pit.name = "Pit"
	var pit_mesh := BoxMesh.new()
	pit_mesh.size = Vector3(width, 12.0, lane_length)
	pit.mesh = pit_mesh
	pit.material_override = dark
	pit.position = Vector3(0.0, -6.5, 0.0)
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pit)

	# Bordes luminosos: se lee el hueco desde lejos.
	var edge := _lamp_material()
	for side in [-1.0, 1.0]:
		var rim := MeshInstance3D.new()
		var rim_mesh := BoxMesh.new()
		rim_mesh.size = Vector3(width + 0.4, 0.16, 0.22)
		rim.mesh = rim_mesh
		rim.material_override = edge
		rim.position = Vector3(0.0, 0.02, side * (lane_length * 0.5 + 0.1))
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rim)

	# Estalactitas y niebla dentro de la grieta.
	var icicle_material := _ice_material()
	for i in 9:
		var x := -width * 0.45 + float(i) * width * 0.9 / 8.0
		var icicle := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18
		cone.height = 1.4 + float(i % 3) * 0.7
		cone.radial_segments = 6
		icicle.mesh = cone
		icicle.material_override = icicle_material
		icicle.position = Vector3(x, -1.0 - float(i % 3) * 0.5, lane_length * 0.45)
		add_child(icicle)

	var mist_mesh := SphereMesh.new()
	mist_mesh.radius = 0.5
	mist_mesh.height = 1.0
	mist_mesh.radial_segments = 6
	mist_mesh.rings = 3
	var mist_material := StandardMaterial3D.new()
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.albedo_color = Color(0.6, 0.85, 1.0, 0.18)
	mist_mesh.material = mist_material
	var mist := CPUParticles3D.new()
	mist.amount = 40
	mist.lifetime = 4.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(width * 0.45, 0.6, lane_length * 0.35)
	mist.position = Vector3(0.0, -2.0, 0.0)
	mist.direction = Vector3.UP
	mist.spread = 30.0
	mist.gravity = Vector3(0.0, 0.4, 0.0)
	mist.initial_velocity_min = 0.2
	mist.initial_velocity_max = 0.8
	mist.scale_amount_min = 0.6
	mist.scale_amount_max = 1.8
	mist.color = Color(0.75, 0.92, 1.0, 0.35)
	mist.mesh = mist_mesh
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mist)


func _ice_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.85, 0.95, 0.92)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.12
	material.metallic = 0.15
	material.emission_enabled = true
	material.emission = Color(0.3, 0.7, 0.9)
	material.emission_energy_multiplier = 0.32
	return material


func _lamp_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.9, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.45, 0.85, 1.0)
	material.emission_energy_multiplier = 1.0
	return material
