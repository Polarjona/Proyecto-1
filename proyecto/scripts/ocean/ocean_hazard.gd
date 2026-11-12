@tool
extends Area3D

var push_force: float = 6.0
var stun_seconds: float = 0.0
## "stun" aturde, "push" empuja fuerte hacia atrás y "kill" manda al
## último checkpoint. Cada obstáculo elige el suyo.
var touch_kind: String = "stun"
## Ajustes que el generador del mapa aplica antes de añadir el obstáculo:
## así el mismo tipo puede aturdir en un tramo y matar en otro.
var touch_override: String = ""
var push_override: float = 0.0
var stun_override: float = 0.0

var _bodies: Array[Node3D] = []
var _cooldown_until: int = 0
var _collision_shape: CollisionShape3D
## El volumen de detección se dibuja con su tamaño real: así se ve dónde
## empieza a golpear en vez de chocar con un área invisible más grande que la
## figura. El color dice qué hace: rojo mata, naranja empuja, cian aturde.
var show_hitbox: bool = true
var _hitbox_ghost: MeshInstance3D

func _setup(box: Vector3, push: float = 6.0, stun_time: float = 0.0,
		offset: Vector3 = Vector3.ZERO, ghost: bool = true) -> void:
	push_force = push
	stun_seconds = stun_time
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	if box != Vector3.ZERO:
		_collision_shape = CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box
		_collision_shape.shape = box_shape
		_collision_shape.position = offset
		add_child(_collision_shape)
		if ghost:
			_add_hitbox_ghost(box, offset)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

## Volumen esférico. Para las figuras redondas (erizo, mina, tinta) la caja
## cuadrada golpeaba en las esquinas mucho más lejos que la figura: era lo
## que se notaba como «hitbox enorme».
func _setup_sphere(radius: float, push: float = 6.0, stun_time: float = 0.0,
		offset: Vector3 = Vector3.ZERO, ghost: bool = true) -> void:
	_setup(Vector3.ZERO, push, stun_time, offset, false)
	var shape := SphereShape3D.new()
	shape.radius = radius
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	_collision_shape.position = offset
	add_child(_collision_shape)
	if ghost:
		_add_hitbox_sphere(radius, offset)

## Volumen cilíndrico: las aspas giran en un disco, así que la esquina de un
## cuadrado siempre sobraba.
func _setup_cylinder(radius: float, height_value: float, push: float = 6.0,
		stun_time: float = 0.0, offset: Vector3 = Vector3.ZERO) -> void:
	_setup(Vector3.ZERO, push, stun_time, offset, false)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height_value
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	_collision_shape.position = offset
	add_child(_collision_shape)
	_add_hitbox_cylinder(radius, height_value, offset)

func _on_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not _bodies.has(body):
		_bodies.append(body)
	_touch(body)

func _on_exit(body: Node3D) -> void:
	_bodies.erase(body)

func _touch(body: Node3D) -> void:
	if Time.get_ticks_msec() < _cooldown_until:
		return
	_cooldown_until = Time.get_ticks_msec() + 850
	var away := body.global_position - global_position
	if away.length_squared() < 0.02:
		away = -global_transform.basis.z
	away = away.normalized()
	var kind := touch_override if touch_override != "" else touch_kind
	var force := push_override if push_override > 0.0 else push_force
	var stun_time := stun_override if stun_override > 0.0 else stun_seconds
	match kind:
		"kill":
			_kill(body)
		"push":
			_push_body(body, (away + Vector3.UP * 0.18).normalized() * force)
			if body.has_method("stun"):
				body.stun(0.22)
		"boost":
			# Los rápidos no golpean: solo aceleran mientras se está dentro.
			pass
		_:
			_push_body(body, (away + Vector3.UP * 0.22).normalized() * force)
			if stun_time > 0.0 and body.has_method("stun"):
				body.stun(stun_time)

## Un obstáculo letal devuelve al corredor al checkpoint anterior.
func _kill(body: Node3D) -> void:
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager == null or not manager.has_method("respawn_player"):
		return
	AudioManager.play_sfx("fall")
	if body.has_method("stun"):
		body.stun(0.2)
	manager.respawn_player()

func _push_body(body: Node3D, vector: Vector3) -> void:
	if body.has_method("apply_push"):
		body.apply_push(vector)

## Empuje continuo (corrientes, vórtices, chorros). Usa `add_belt_velocity`
## cuando existe para que no aturda en cada fotograma.
func _push_field(vector: Vector3) -> void:
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("add_belt_velocity"):
			body.add_belt_velocity(vector)
		else:
			_push_body(body, vector)
		# Las corrientes y chorros también frenan mientras se cruzan.
		if body.has_method("slow"):
			body.slow(0.25, 0.7)

func _add_sphere(parent: Node3D, radius: float, material: Material,
		at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _add_box(parent: Node3D, box: Vector3, material: Material, at: Vector3,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rot_deg
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float,
		height_value: float, material: Material, at: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height_value
	mesh.radial_segments = segments
	mesh.rings = 2
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rot_deg
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _add_light(parent: Node3D, color: Color, energy: float,
		reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)
	return light

## Aro que se usa como marco de los rápidos: queda mirando al eje de avance.
func _add_torus(parent: Node3D, ring_radius: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = ring_radius * 0.82
	mesh.outer_radius = ring_radius
	mesh.rings = 12
	mesh.ring_segments = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _hazard_color() -> Color:
	var kind := touch_override if touch_override != "" else touch_kind
	match kind:
		"kill":
			return Color(1.0, 0.3, 0.38)
		"push":
			return Color(1.0, 0.66, 0.24)
		"stun":
			return Color(0.42, 0.88, 1.0)
		_:
			return Color(0.55, 1.0, 0.85)

## Caja translúcida del tamaño exacto del hitbox. Un solo `MeshInstance3D`
## por obstáculo, así que no cuesta nada de dibujar.
func _add_hitbox_ghost(box: Vector3,
		at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if not show_hitbox:
		return null
	var mesh := BoxMesh.new()
	mesh.size = box
	var ghost := MeshInstance3D.new()
	ghost.name = "HitboxGhost"
	ghost.mesh = mesh
	ghost.material_override = OceanStyle.additive(_hazard_color(), 0.12)
	ghost.position = at
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	if _hitbox_ghost == null:
		_hitbox_ghost = ghost
	return ghost

func _add_hitbox_sphere(radius: float,
		at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if not show_hitbox:
		return null
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 9
	var ghost := MeshInstance3D.new()
	ghost.name = "HitboxGhost"
	ghost.mesh = mesh
	ghost.material_override = OceanStyle.additive(_hazard_color(), 0.12)
	ghost.position = at
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	if _hitbox_ghost == null:
		_hitbox_ghost = ghost
	return ghost

func _add_hitbox_cylinder(radius: float, height_value: float,
		at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if not show_hitbox:
		return null
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height_value
	mesh.radial_segments = 20
	mesh.rings = 1
	var ghost := MeshInstance3D.new()
	ghost.name = "HitboxGhost"
	ghost.mesh = mesh
	ghost.material_override = OceanStyle.additive(_hazard_color(), 0.12)
	ghost.position = at
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	if _hitbox_ghost == null:
		_hitbox_ghost = ghost
	return ghost


## Erizo de mar: bola de púas que gira y no deja pasar por el centro.
