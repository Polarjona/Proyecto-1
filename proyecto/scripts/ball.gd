extends RigidBody3D

## Falling hazard ball: rolls on the course and knocks the player backwards.
## Impact force scales with the ball's falling speed, capped so it stays fair.

@export var push_force: float = 10.0
@export var push_lift: float = 2.5
@export var speed_for_max_push: float = 12.0
@export var lifetime: float = 14.0
## Color de la bola. El lanzador lo cambia para que no se confunda con el
## decorado de cada circuito (en el hielo, las bolas ya no parecen nieve).
@export var ball_color: Color = Color(0.92, 0.44, 0.16)

@onready var hit_area: Area3D = $HitArea
@onready var mesh: MeshInstance3D = $MeshInstance3D

var _age: float = 0.0


func _ready() -> void:
	add_to_group("hazard_balls")
	hit_area.body_entered.connect(_on_body_entered)
	if ball_color.a > 0.0:
		var material := StandardMaterial3D.new()
		material.albedo_color = ball_color
		material.roughness = 0.45
		mesh.material_override = material


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not body.has_method("apply_push"):
		return
	var push_dir := body.global_position - global_position
	push_dir.y = 0.0
	if push_dir.length_squared() < 0.001:
		push_dir = Vector3.BACK
	else:
		push_dir = push_dir.normalized()
	var impact := clampf(linear_velocity.length() / speed_for_max_push, 0.0, 1.0)
	var force := push_dir * push_force * (0.5 + 0.5 * impact)
	force.y = push_lift
	body.apply_push(force)
	if body.has_method("slow"):
		body.slow(0.8, 0.6)
