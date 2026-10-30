extends Area3D

## Mar de lava del volcán. La superficie sube sola y persigue al corredor
## manteniéndose unos metros por debajo: si te quedas parado acaba alcanzándote,
## y si caes, te devuelve al último checkpoint.
##
## La superficie es una malla con el shader de olas del mar de nubes, teñido de
## naranja, y un área de colisión ancha que viaja con ella. Tras un respawn la
## lava se coloca por debajo del checkpoint para que nadie reaparezca dentro.

const SEA_SHADER := preload("res://shaders/void_sea.gdshader")

@export var center_xz: Vector3 = Vector3(0.0, 0.0, -90.0)
@export var surface_y: float = -8.0
@export var max_surface_y: float = 118.0
@export var radius: float = 58.0
## Metros por segundo que sube, sin pausas ni persecución: si te quedas
## parado, la lava acaba llegando a tus pies.
@export var rise_speed: float = 0.6

var _surface: float = -8.0
var _cooldown: float = 0.0
var _manager: Node


func _ready() -> void:
	add_to_group("lava_sea")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_surface = surface_y
	position = Vector3(center_xz.x, _surface, center_xz.z)
	_build_surface()
	body_entered.connect(_on_body_entered)
	_manager = get_tree().get_first_node_in_group("race_manager")
	if _manager != null and _manager.has_signal("respawned"):
		_manager.connect("respawned", _on_respawned)


func _build_surface() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	plane.subdivide_width = 56
	plane.subdivide_depth = 56

	var material := ShaderMaterial.new()
	material.shader = SEA_SHADER
	material.set_shader_parameter("deep_color", Color(0.28, 0.015, 0.0))
	material.set_shader_parameter("mid_color", Color(1.0, 0.26, 0.02))
	material.set_shader_parameter("foam_color", Color(1.0, 0.82, 0.24))
	material.set_shader_parameter("wave_height", 1.1)
	material.set_shader_parameter("wave_scale", 0.055)
	material.set_shader_parameter("flow_speed", 0.7)
	plane.material = material

	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = plane
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

	var shape := CollisionShape3D.new()
	shape.name = "KillShape"
	var box := BoxShape3D.new()
	box.size = Vector3(radius * 2.0, 8.0, radius * 2.0)
	shape.shape = box
	shape.position = Vector3(0.0, -4.0, 0.0)
	add_child(shape)

	var glow := OmniLight3D.new()
	glow.name = "LavaGlow"
	glow.position = Vector3(0.0, 3.0, 0.0)
	glow.light_color = Color(1.0, 0.32, 0.06)
	glow.light_energy = 3.2
	glow.omni_range = radius * 1.7
	glow.shadow_enabled = false
	add_child(glow)

	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.09
	ember_mesh.height = 0.18
	ember_mesh.radial_segments = 6
	ember_mesh.rings = 3
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(1.0, 0.72, 0.2)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.45, 0.05)
	ember_material.emission_energy_multiplier = 3.0
	ember_mesh.material = ember_material

	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 90
	embers.lifetime = 5.0
	embers.preprocess = 3.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(radius * 0.72, 0.6, radius * 0.72)
	embers.direction = Vector3(0.0, 1.0, 0.0)
	embers.spread = 32.0
	embers.gravity = Vector3(0.0, 2.2, 0.0)
	embers.initial_velocity_min = 1.0
	embers.initial_velocity_max = 4.5
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.8
	embers.color = Color(1.0, 0.85, 0.55, 0.9)
	embers.mesh = ember_mesh
	embers.position = Vector3(0.0, 1.0, 0.0)
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(embers)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	# Sube sin pausas hasta cubrir la montaña. No persigue al jugador: si se
	# queda quieto o pierde tiempo, la lava le alcanza de verdad.
	_surface = minf(_surface + rise_speed * delta, max_surface_y)
	position.y = _surface


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0:
		return
	if not body.is_in_group("player"):
		return
	_cooldown = 1.5
	AudioManager.play_sfx("fall")
	GameFeel.flash(Color(1.0, 0.3, 0.05), 0.4)
	if _manager != null and _manager.has_method("respawn_player"):
		_manager.respawn_player()


## Al reaparecer, la lava se baja por debajo del checkpoint: el castigo por
## caer ya es perder tiempo, no morir en bucle dentro de la lava.
func _on_respawned(_penalty: float) -> void:
	# El manager puede emitir la señal antes de mover al jugador: se espera
	# un frame para leer el checkpoint real y no bajar la lava a ciegas.
	call_deferred("_lower_below_player")


func _lower_below_player() -> void:
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if _surface > player.global_position.y - 5.0:
		_surface = maxf(surface_y, player.global_position.y - 12.0)
		position.y = _surface


func current_surface() -> float:
	return _surface
