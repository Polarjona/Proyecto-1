extends Area3D

## Remolino de ceniza: exclusivo de Lava Vortex. No es sólido, se nota como una
## fuerza que gira y tira hacia el ojo del remolino. Se pasa corriendo en contra
## o saltando de lado, y los anillos giran en sentidos alternos para leerlo.

@export var radius: float = 3.4
@export var height: float = 3.0
## Velocidad tangencial que impone (m/s): más alto, más cuesta mantener la línea.
@export var spin_force: float = 4.6
## Tirón hacia el centro del remolino (m/s).
@export var pull_force: float = 1.1
@export var ring_speed: float = 1.7

var _bodies: Array[Node3D] = []
var _rings: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("ash_vortices")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collider := CollisionShape3D.new()
	collider.name = "Shape"
	collider.shape = shape
	collider.position.y = height * 0.5
	add_child(collider)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()


func _physics_process(delta: float) -> void:
	for i in _rings.size():
		var direction := 1.0 if i % 2 == 0 else -1.0
		_rings[i].rotate_y(direction * ring_speed * (1.0 + float(i) * 0.35) * delta)
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if not body.has_method("add_external_velocity"):
			continue
		var offset: Vector3 = body.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() < 0.09:
			offset = Vector3.RIGHT
		var outward := offset.normalized()
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		body.add_external_velocity(tangent * spin_force - outward * pull_force)


func _build_visual() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.62
	ring_mesh.outer_radius = radius * 0.7
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.42, 0.1)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.3, 0.05)
	ring_material.emission_energy_multiplier = 2.2
	for i in 3:
		var ring := MeshInstance3D.new()
		ring.name = "Ring%d" % i
		ring.mesh = ring_mesh
		ring.material_override = ring_material
		ring.position.y = 0.25 + float(i) * 0.55
		ring.scale = Vector3.ONE * (1.0 - float(i) * 0.18)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)

	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.07
	ember_mesh.height = 0.14
	ember_mesh.radial_segments = 6
	ember_mesh.rings = 3
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(1.0, 0.7, 0.25)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.45, 0.08)
	ember_material.emission_energy_multiplier = 2.6
	ember_mesh.material = ember_material

	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 54
	embers.lifetime = 1.6
	embers.preprocess = 1.2
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	embers.emission_ring_axis = Vector3.UP
	embers.emission_ring_radius = radius * 0.95
	embers.emission_ring_inner_radius = radius * 0.35
	embers.emission_ring_height = 0.5
	embers.direction = Vector3(0.0, 1.0, 0.0)
	embers.spread = 24.0
	embers.gravity = Vector3(0.0, 2.0, 0.0)
	embers.initial_velocity_min = 0.7
	embers.initial_velocity_max = 2.2
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.5
	embers.mesh = ember_mesh
	embers.position.y = 0.4
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(embers)

	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position.y = 1.2
	light.light_color = Color(1.0, 0.4, 0.12)
	light.light_energy = 2.4
	light.omni_range = radius * 3.0
	light.shadow_enabled = false
	add_child(light)


func _on_body_entered(body: Node3D) -> void:
	if body not in _bodies:
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)


## Cuerpos atrapados ahora mismo; lo usan los tests.
func active_body_count() -> int:
	return _bodies.size()
