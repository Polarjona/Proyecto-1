extends Node3D

## Meteoro de la lluvia de ceniza. Cae en vertical, empuja al corredor que
## alcanza y estalla con una sacudida al tocar el suelo. El impacto lateral es
## lo que lo hace peligroso en la espiral: te aparta del borde.

@export var target_y: float = 0.0
@export var fall_speed: float = 38.0
@export var blast_radius: float = 3.2
@export var push_force: float = 8.0

var _exploded: bool = false
var _area: Area3D


func _ready() -> void:
	add_to_group("hazard_balls")
	_build()


func _build() -> void:
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.15, 0.07, 0.05)
	rock_material.roughness = 0.9
	rock_material.emission_enabled = true
	rock_material.emission = Color(0.9, 0.22, 0.02)
	rock_material.emission_energy_multiplier = 1.3

	var mesh := SphereMesh.new()
	mesh.radius = 1.15
	mesh.height = 2.3
	mesh.radial_segments = 14
	mesh.rings = 8
	var body := MeshInstance3D.new()
	body.name = "Rock"
	body.mesh = mesh
	body.material_override = rock_material
	add_child(body)

	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.34, 0.05)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)

	var trail := CPUParticles3D.new()
	trail.name = "Trail"
	trail.amount = 28
	trail.lifetime = 0.55
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.8
	trail.direction = Vector3(0.0, 1.0, 0.0)
	trail.spread = 180.0
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 1.4
	trail.scale_amount_min = 0.4
	trail.scale_amount_max = 1.2
	var ember := SphereMesh.new()
	ember.radius = 0.1
	ember.height = 0.2
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(1.0, 0.55, 0.1)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.3, 0.02)
	ember_material.emission_energy_multiplier = 2.4
	ember.material = ember_material
	trail.mesh = ember
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)

	_area = Area3D.new()
	_area.name = "Blast"
	_area.collision_layer = 0
	_area.collision_mask = 2
	_area.monitorable = false
	_area.monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	shape.shape = sphere
	_area.add_child(shape)
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	position.y -= fall_speed * delta
	if position.y <= target_y + 0.9:
		_explode()


func _on_body_entered(toucher: Node3D) -> void:
	if _exploded:
		return
	_push_away(toucher)


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	for body in _area.get_overlapping_bodies():
		_push_away(body)
	AudioManager.play_sfx_at("impact", global_position, 0.4, 0.0)
	GameFeel.shake(3.2)
	GameFeel.flash(Color(1.0, 0.4, 0.1), 0.22)
	queue_free()


func _push_away(body: Node3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("bot")):
		return
	if not body.has_method("apply_push"):
		return
	var direction := body.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT
	else:
		direction = direction.normalized()
	body.apply_push(direction * push_force + Vector3.UP * 4.2)
	if body.has_method("stun"):
		body.stun()
	AudioManager.play_sfx_at("impact", global_position, 0.28, -2.0)
