extends AnimatableBody3D

## Constant Y-axis spin; CharacterBody3D rides via move_and_slide floor motion.
## The base cylinder is dressed up procedurally with radial chevrons, a lit rim
## and a visible central axle, so the obstacle reads clearly while it turns.

const YELLOW := preload("res://materials/yellow.tres")
const PINK := preload("res://materials/pink.tres")
const PURPLE := preload("res://materials/purple.tres")

@export var spin_speed: float = 1.2


func _ready() -> void:
	_build_details()


func _physics_process(delta: float) -> void:
	rotate_y(spin_speed * delta)


func _build_details() -> void:
	if get_node_or_null("Details") != null:
		return
	var details := Node3D.new()
	details.name = "Details"
	add_child(details)

	# Eight radial chevrons alternating warm colours.
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.24, 0.05, 3.2)
	var stripes := [YELLOW, PINK, PURPLE]
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var stripe := MeshInstance3D.new()
		stripe.mesh = stripe_mesh
		stripe.material_override = stripes[i % stripes.size()]
		stripe.position = Vector3(sin(angle) * 2.35, 0.23, cos(angle) * 2.35)
		stripe.rotation.y = angle
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		details.add_child(stripe)

	# Bright rim that follows the spinning edge.
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 3.72
	rim_mesh.outer_radius = 4.02
	rim_mesh.rings = 32
	rim_mesh.ring_segments = 8
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = rim_mesh
	rim.material_override = YELLOW
	rim.position.y = 0.22
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	details.add_child(rim)

	# Central axle: the mechanism that turns the disc, visible underneath.
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.5
	hub_mesh.bottom_radius = 0.6
	hub_mesh.height = 1.4
	hub_mesh.radial_segments = 20
	var hub := MeshInstance3D.new()
	hub.name = "Hub"
	hub.mesh = hub_mesh
	hub.material_override = PURPLE
	hub.position.y = -0.6
	details.add_child(hub)

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.62
	cap_mesh.bottom_radius = 0.62
	cap_mesh.height = 0.04
	var cap := MeshInstance3D.new()
	cap.name = "HubCap"
	cap.mesh = cap_mesh
	cap.material_override = YELLOW
	cap.position.y = 0.21
	details.add_child(cap)

	# Soft cyan glow so the platform pops against the dark arena.
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position.y = 1.2
	light.light_color = Color(0.35, 0.95, 1.0)
	light.light_energy = 1.1
	light.omni_range = 7.0
	light.shadow_enabled = false
	details.add_child(light)

	# A handful of sparks circling the rim.
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.06
	spark_mesh.height = 0.12
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.95, 0.55)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.85, 0.35)
	spark_material.emission_energy_multiplier = 2.0
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 24
	sparks.lifetime = 1.3
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 3.9
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 180.0
	sparks.gravity = Vector3.ZERO
	sparks.initial_velocity_min = 0.1
	sparks.initial_velocity_max = 0.5
	sparks.scale_amount_min = 0.4
	sparks.scale_amount_max = 1.2
	sparks.mesh = spark_mesh
	sparks.material_override = spark_material
	sparks.position.y = 0.35
	sparks.emitting = true
	details.add_child(sparks)
