extends Area3D

## Conveyor belt: adds constant belt speed while bodies stay inside and draws
## animated chevrons on the belt so the direction of travel is readable.

@export var direction: Vector3 = Vector3.FORWARD
@export var force: float = 12.0
## Material used for the moving chevrons (the yellow trim material).
@export var arrow_material: Material
@export var arrow_count: int = 4
## Local X distance the arrows travel before wrapping around.
@export var arrow_span: float = 2.6
@export var arrow_speed: float = 2.4
## Tamaño del suelo de la cinta. Los chevrones no se estiran: solo crecen el
## área que empuja y la placa que la dibuja, para cubrir una sala entera.
@export var belt_length: float = 6.0
@export var belt_width: float = 4.0

var _bodies: Array[Node3D] = []
var _arrows_root: Node3D
var _arrow_scroll: float = 0.0


func _ready() -> void:
	# Run before the player so belt velocity is applied the same physics frame.
	process_physics_priority = -5
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	direction = direction.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3.RIGHT
	_apply_size()
	_build_arrows()


## Escala el área, el suelo sólido y la placa visual al tamaño pedido.
func _apply_size() -> void:
	var area_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if area_shape != null and area_shape.shape is BoxShape3D:
		var box := (area_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = Vector3(belt_length, 1.5, belt_width)
		area_shape.shape = box
	var floor_shape := get_node_or_null("StaticBody3D/FloorShape") as CollisionShape3D
	if floor_shape != null and floor_shape.shape is BoxShape3D:
		var floor_box := (floor_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		floor_box.size = Vector3(belt_length, 0.25, belt_width)
		floor_shape.shape = floor_box
	var belt := get_node_or_null("BeltMesh") as MeshInstance3D
	if belt != null and belt.mesh is BoxMesh:
		var belt_box := (belt.mesh as BoxMesh).duplicate() as BoxMesh
		belt_box.size = Vector3(belt_length, 0.05, belt_width)
		belt.mesh = belt_box


func _process(delta: float) -> void:
	if _arrows_root == null:
		return
	_arrow_scroll = fposmod(_arrow_scroll + arrow_speed * delta, arrow_span * 2.0)
	var spacing := arrow_span * 2.0 / float(arrow_count)
	for i in _arrows_root.get_child_count():
		var arrow := _arrows_root.get_child(i) as Node3D
		arrow.position.x = -arrow_span + fposmod(float(i) * spacing + _arrow_scroll, arrow_span * 2.0)


func _physics_process(_delta: float) -> void:
	var belt := direction * force
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("add_belt_velocity"):
			body.add_belt_velocity(belt)
		elif body.has_method("apply_push"):
			body.apply_push(belt)
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity += belt


## Chevrons are built at runtime so every belt instance shows the same
## readable arrows without duplicating meshes in the scene.
func _build_arrows() -> void:
	_arrows_root = Node3D.new()
	_arrows_root.name = "DirectionArrows"
	# Point the arrows along the belt direction: local +X is the belt heading.
	_arrows_root.rotation.y = atan2(-direction.z, direction.x)
	add_child(_arrows_root)

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(1.55, 0.05, 0.2)
	var spacing := arrow_span * 2.0 / float(arrow_count)
	for i in arrow_count:
		var arrow := Node3D.new()
		arrow.name = "Arrow%d" % (i + 1)
		arrow.position = Vector3(-arrow_span + float(i) * spacing, 0.0, 0.0)
		_arrows_root.add_child(arrow)

		var upper := MeshInstance3D.new()
		upper.mesh = arm_mesh
		upper.material_override = arrow_material
		upper.position = Vector3(0.0, 0.235, 0.68)
		upper.rotation.y = deg_to_rad(63.4)
		upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.add_child(upper)

		var lower := MeshInstance3D.new()
		lower.mesh = arm_mesh
		lower.material_override = arrow_material
		lower.position = Vector3(0.0, 0.235, -0.68)
		lower.rotation.y = deg_to_rad(-63.4)
		lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.add_child(lower)


func _on_body_entered(body: Node3D) -> void:
	if body not in _bodies:
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
