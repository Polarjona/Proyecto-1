@tool
extends Node3D

## Grieta glacial: exclusiva del glaciar. El suelo del último tramo se abre por
## carriles y vuelve a cerrarse en oleadas, así que hay que cambiar de carril al
## ritmo del aviso. Caer dentro devuelve al último checkpoint.
##
## Se distingue del muro de témpanos (que cierra carriles en vertical) en que
## aquí el peligro es el hueco: el suelo desaparece bajo los pies.
##
## Las losas se crean una sola vez: si la escena ya las tiene guardadas se
## reutilizan, y al abrirla en el editor pasan a ser nodos de la escena para
## poder seleccionarlas y moverlas como cualquier otro bloque.

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
	if not has_node("Pit"):
		_build_pit()
	var ice := _ice_material()
	_bodies.clear()
	_lamps.clear()
	for i in lanes:
		var body := get_node_or_null(NodePath("Lane%d" % i)) as AnimatableBody3D
		if body == null:
			body = _make_lane(i, ice)
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = true
		# Las losas arrancan siempre cerradas y a ras del hielo: si la escena se
		# guardó a mitad de una oleada, no empiezan hundidas bajo el suelo.
		body.position.y = _closed_y
		# Y con el hielo claro, no translúcido: así se leen como tres losas
		# encima del hueco en vez de como un parche oscuro debajo de él.
		for child in body.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = ice
		_bodies.append(body)

		var lamp := get_node_or_null(NodePath("Warn%d" % i)) as MeshInstance3D
		if lamp == null:
			lamp = _make_lamp(i)
		var lamp_material := lamp.material_override as StandardMaterial3D
		if lamp_material == null:
			lamp_material = _lamp_material()
			lamp.material_override = lamp_material
		_lamps.append(lamp_material)

	if Engine.is_editor_hint():
		# Diferido: en `_ready` el padre aún está montando los hijos.
		call_deferred("_own_generated", self)


## Crea una losa de carril y la devuelve.
func _make_lane(index: int, ice: Material) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "Lane%d" % index
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	body.position = Vector3(_lane_x(index), _closed_y, 0.0)
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
	return body


## Franja luminosa que avisa antes de que el carril se cierre.
func _make_lamp(index: int) -> MeshInstance3D:
	var lamp := MeshInstance3D.new()
	lamp.name = "Warn%d" % index
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(lane_width * 0.9, 0.05, 0.18)
	lamp.mesh = lamp_mesh
	lamp.material_override = _lamp_material()
	lamp.position = Vector3(_lane_x(index), 0.03, lane_length * 0.5 + 0.16)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	return lamp


## Da `owner` a lo generado para que el editor pueda seleccionarlo y guardarlo
## dentro de la escena, como el resto del mapa.
func _own_generated(node: Node) -> void:
	var root := get_tree().edited_scene_root
	if root == null:
		return
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
		_own_generated(child)


func _lane_x(index: int) -> float:
	return (float(index) - float(lanes - 1) * 0.5) * lane_width


func _physics_process(delta: float) -> void:
	# En el editor no se abre ninguna grieta: el mapa se edita quieto.
	if Engine.is_editor_hint():
		return
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
	# Hondo de sobra: el hueco abierto tiene que leerse como un pozo, no como
	# una franja oscura de medio metro.
	pit.position = Vector3(0.0, -8.0, 0.0)
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
	# Hielo opaco y luminoso: las losas cerradas tienen que leerse por encima del
	# hueco, no como una sombra bajo el suelo.
	material.albedo_color = Color(0.8, 0.94, 1.0)
	material.roughness = 0.16
	material.metallic = 0.1
	material.emission_enabled = true
	material.emission = Color(0.42, 0.78, 0.95)
	material.emission_energy_multiplier = 0.5
	return material


func _lamp_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.9, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.45, 0.85, 1.0)
	material.emission_energy_multiplier = 1.0
	return material
