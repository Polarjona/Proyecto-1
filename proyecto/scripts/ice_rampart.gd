extends Node3D

## Muro de témpanos: exclusivo del glaciar. Tres bloques de hielo duermen bajo
## el suelo y salen por turnos, de modo que siempre queda un carril abierto.
## Se pasa leyendo el ritmo: el carril por el que vas avisa con una franja que
## parpadea justo antes de cerrarse.

@export var lanes: int = 3
@export var lane_width: float = 3.2
@export var block_height: float = 3.0
@export var block_depth: float = 1.8
## Segundos que tarda el patrón en abrir el siguiente carril.
@export var cycle: float = 3.2
## Tiempo que tarda un bloque en subir o bajar del todo.
@export var travel_time: float = 0.4
## Cuánto queda enterrado el bloque cuando está recogido.
@export var embed: float = 1.2
## Aviso luminoso antes de que el carril abierto se cierre.
@export var warn_time: float = 0.7

var _time: float = 0.0
var _bodies: Array[AnimatableBody3D] = []
var _lamps: Array[StandardMaterial3D] = []
var _up_y: float = 0.0
var _down_y: float = 0.0


func _ready() -> void:
	add_to_group("ice_ramparts")
	_up_y = block_height * 0.5
	_down_y = -block_height * 0.5 - embed
	var ice := _ice_material()
	for i in lanes:
		var body := AnimatableBody3D.new()
		body.name = "Block%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = true
		body.position = Vector3(_lane_x(i), _down_y, 0.0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(lane_width * 0.92, block_height, block_depth)
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var block_mesh := BoxMesh.new()
		block_mesh.size = box.size
		mesh.mesh = block_mesh
		mesh.material_override = ice
		body.add_child(mesh)
		add_child(body)
		_bodies.append(body)
		# Franja de aviso en el suelo del carril.
		var lamp := MeshInstance3D.new()
		lamp.name = "Warn%d" % i
		var lamp_mesh := BoxMesh.new()
		lamp_mesh.size = Vector3(lane_width * 0.86, 0.05, block_depth * 0.6)
		lamp.mesh = lamp_mesh
		lamp.material_override = _lamp_material()
		lamp.position = Vector3(_lane_x(i), 0.04, block_depth * 0.95)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps.append(lamp.material_override as StandardMaterial3D)


func _lane_x(index: int) -> float:
	return (float(index) - float(lanes - 1) * 0.5) * lane_width


func _physics_process(delta: float) -> void:
	_time += delta
	var slot_time := cycle / float(maxi(lanes, 1))
	var slot := int(_time / slot_time)
	var open_lane := slot % lanes
	var into_slot := fmod(_time, slot_time)
	# El carril abierto avisa con parpadeos antes de cerrarse.
	var warning := into_slot > slot_time - warn_time
	var pulse := 0.5 + 0.5 * sin(_time * 24.0)
	var rate := (block_height + embed) / maxf(travel_time, 0.01)
	for i in _bodies.size():
		var wants_up := i != open_lane
		var target_y := _up_y if wants_up else _down_y
		_bodies[i].position.y = move_toward(_bodies[i].position.y, target_y, rate * delta)
		var lamp := _lamps[i]
		if i == open_lane and warning:
			lamp.emission_energy_multiplier = 3.4 * pulse
			lamp.albedo_color = Color(1.0, 0.42, 0.16)
		elif i == open_lane:
			lamp.emission_energy_multiplier = 0.0
		else:
			lamp.emission_energy_multiplier = 1.1


## Carril libre en este instante (0 = izquierda). Lo usan los tests y los bots.
func open_lane() -> int:
	var slot_time := cycle / float(maxi(lanes, 1))
	return int(_time / slot_time) % lanes


func _ice_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.85, 0.95, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.12
	material.metallic = 0.15
	material.emission_enabled = true
	material.emission = Color(0.3, 0.7, 0.9)
	material.emission_energy_multiplier = 0.35
	return material


func _lamp_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.25)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.12)
	material.emission_energy_multiplier = 0.8
	return material
