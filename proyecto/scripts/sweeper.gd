extends Node3D

## Rotating sweeper bar: spins around Y and knocks the player sideways.
## The bar itself is solid, the push area adds the knockback on contact.

@export var spin_speed: float = 1.6
@export var push_force: float = 4.8
## Small hop so the hit reads, without launching the player across the hall.
@export var push_lift: float = 1.2
## When false the bar only shoves: no stun, no red flash, no hit-stop.
@export var stuns: bool = true
## Flip to -1.0 to make the bar spin the other way.
@export var spin_direction: float = 1.0
## Largo total de la barra medido en el mundo, en metros (la escena de fábrica
## mide 9,6). El arena del Glacier la alarga para que barra de pared a pared;
## el resto de circuitos se queda con el valor de fábrica. Se reparte entre la
## escala del propio nodo para que el número sea siempre el ancho real barrido.
@export var arm_length: float = 9.6

@onready var bar: AnimatableBody3D = $Bar
@onready var push_area: Area3D = $Bar/PushArea

var _angle: float = 0.0
var _whoosh_timer: float = 0.0


func _ready() -> void:
	add_to_group("sweepers")
	push_area.body_entered.connect(_on_body_entered)
	_apply_arm_length()


## Estira la barra a `arm_length` sin tocar la escena compartida: la malla y la
## forma se copian antes de cambiarles el tamaño, así los demás barridos del
## juego (el del peñasco, los de Spin Go Round) siguen igual.
func _apply_arm_length() -> void:
	# `arm_length` viene en metros de mundo; la barra se mide en local.
	var stretch := maxf(absf(scale.x), 0.001)
	var local_length := arm_length / stretch
	if absf(local_length - 9.6) < 0.01:
		return
	var half := local_length * 0.5
	_resize_shape($Bar/ArmShape, Vector3(local_length, 0.35, 0.35))
	_resize_mesh($Bar/ArmMesh, Vector3(local_length, 0.35, 0.35))
	_resize_shape($Bar/PushArea/PushShape,
		Vector3(local_length + 0.4 / stretch, 1.0, 1.0))
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0.0 else "Right"
		var cap_shape := $Bar.get_node_or_null("CapShape" + suffix) as Node3D
		var cap_mesh := $Bar.get_node_or_null("CapMesh" + suffix) as Node3D
		if cap_shape != null:
			cap_shape.position.x = side * half
		if cap_mesh != null:
			cap_mesh.position.x = side * half


func _resize_shape(node: Node, size: Vector3) -> void:
	var collision := node as CollisionShape3D
	if collision == null:
		return
	var source = collision.shape
	if source == null:
		return
	var copy = source.duplicate()
	copy.size = size
	collision.shape = copy


func _resize_mesh(node: Node, size: Vector3) -> void:
	var instance := node as MeshInstance3D
	if instance == null:
		return
	var source = instance.mesh
	if source == null:
		return
	var copy = source.duplicate()
	copy.size = size
	instance.mesh = copy


# Moved in `_process` (sync_to_physics = false), same as the pendulum hammer.
func _process(delta: float) -> void:
	_angle += spin_speed * spin_direction * delta
	bar.rotation.y = _angle
	_whoosh_timer -= delta
	if _whoosh_timer <= 0.0:
		_whoosh_timer = 1.25
		AudioManager.play_sfx_at("whoosh", bar.global_position, 0.2, -16.0)


func get_angle() -> float:
	return _angle


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("apply_push"):
		return
	var push_dir := body.global_position - bar.global_position
	push_dir.y = 0.0
	if push_dir.length_squared() < 0.001:
		push_dir = Vector3.RIGHT
	else:
		push_dir = push_dir.normalized()
	var impulse := push_dir * push_force + Vector3.UP * push_lift
	if stuns:
		if body.has_method("apply_push"):
			body.apply_push(impulse)
		# Sweepers must all stagger the same way, even the weakest bar whose
		# knockback alone stays under the player's stun threshold.
		if body.has_method("stun"):
			body.stun()
	elif body.has_method("apply_push_soft"):
		body.apply_push_soft(impulse)
	else:
		body.apply_push(impulse)
	# Además del empujón, la barrida deja al corredor algo más lento.
	if body.has_method("slow"):
		body.slow(0.85, 0.55)
