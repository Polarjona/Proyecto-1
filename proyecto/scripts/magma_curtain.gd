@tool
extends Node3D

## Cortina de magma: exclusiva del volcán. Una fila de chorros verticales cruza
## la rampa y erupciona en oleada, de un extremo al otro. No bloquea de forma
## permanente: hay que leer el pulso y cruzar por los huecos.
##
## Se coloca girada con la pendiente de la espiral, así que los chorros nacen
## pegados al suelo y suben perpendiculares al tramo.

@export var jets: int = 7
@export var spacing: float = 1.15
@export var height: float = 4.6
@export var cycle_speed: float = 2.2
@export var push_up: float = 6.0
@export var phase_offset: float = 0.0

var _time: float = 0.0
var _flames: Array[Node3D] = []
var _bodies: Array = []
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("magma_curtains")
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_material.albedo_color = Color(1.0, 0.52, 0.14, 0.5)
	flame_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in jets:
		var x := (float(i) - float(jets - 1) * 0.5) * spacing
		var flame := Node3D.new()
		flame.name = "Jet%d" % i
		flame.position = Vector3(x, 0.0, 0.0)
		add_child(flame)
		var mesh_instance := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.34
		cone.height = height
		cone.radial_segments = 8
		mesh_instance.mesh = cone
		mesh_instance.material_override = flame_material
		mesh_instance.position.y = height * 0.5
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.add_child(mesh_instance)
		_flames.append(flame)

		var area := Area3D.new()
		area.name = "JetArea%d" % i
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		area.monitorable = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(spacing * 0.9, height, spacing * 0.9)
		shape.shape = box
		area.add_child(shape)
		area.position = Vector3(x, height * 0.5, 0.0)
		add_child(area)
		_bodies.append([])
		area.body_entered.connect(_on_body_entered.bind(i))
		area.body_exited.connect(_on_body_exited.bind(i))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.45, 0.12)
	_light.light_energy = 1.4
	_light.omni_range = 10.0
	_light.position.y = height * 0.6
	add_child(_light)


func _on_body_entered(body: Node3D, index: int) -> void:
	if not body.is_in_group("player"):
		return
	var list: Array = _bodies[index]
	if not list.has(body):
		list.append(body)


func _on_body_exited(body: Node3D, index: int) -> void:
	(_bodies[index] as Array).erase(body)


func _physics_process(delta: float) -> void:
	_time += delta
	for i in _flames.size():
		var wave := sin((_time + phase_offset) * cycle_speed - float(i) * 0.9)
		var active := wave > 0.15
		_flames[i].visible = active
		if not active:
			continue
		_flames[i].scale = Vector3(1.0, 0.8 + 0.35 * wave, 1.0)
		for body in _bodies[i]:
			if not is_instance_valid(body):
				continue
			if body.has_method("add_belt_velocity"):
				body.add_belt_velocity(Vector3.UP * push_up)
			elif body.has_method("apply_push"):
				body.apply_push(Vector3.UP * push_up)
			# Bajo el chorro el corredor pierde velocidad mientras lo cruza.
			if body.has_method("slow"):
				body.slow(0.25, 0.6)
	var pulse := 0.85 + 0.35 * sin(_time * 7.0)
	if _light != null:
		_light.light_energy = 1.6 * pulse
