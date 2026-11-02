extends Node3D

## Géiser de lava: la grieta del suelo se enciende, la luz parpadea y, un
## segundo y medio después, una columna de lava sube y baja. Durante la
## erupción quema al corredor; el aviso es largo para que siempre se pueda leer
## y esquivar.

@export var idle_time: float = 3.6
@export var warn_time: float = 1.8
@export var erupt_time: float = 1.3
@export var height: float = 7.0
@export var radius: float = 1.7
@export var phase_offset: float = 0.0

var _time: float = 0.0
var _cycle: float = 6.7
var _cooldown: float = 0.0
var _jet: MeshInstance3D
var _jet_material: StandardMaterial3D
var _area: Area3D
var _warning: OmniLight3D
var _ring: MeshInstance3D
var _sparks: CPUParticles3D


func _ready() -> void:
	add_to_group("lava_geysers")
	add_to_group("hazard_balls")
	_cycle = idle_time + warn_time + erupt_time
	_time = fposmod(phase_offset, _cycle)
	_build()


func _build() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.12, 0.06, 0.05)
	rock.roughness = 0.85
	rock.emission_enabled = true
	rock.emission = Color(0.55, 0.12, 0.02)
	rock.emission_energy_multiplier = 0.5

	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = radius * 1.35
	base_mesh.bottom_radius = radius * 1.55
	base_mesh.height = 0.35
	base_mesh.radial_segments = 16
	var base := MeshInstance3D.new()
	base.name = "Vent"
	base.mesh = base_mesh
	base.material_override = rock
	base.position.y = 0.1
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)

	var crack := MeshInstance3D.new()
	crack.name = "Crack"
	var crack_mesh := CylinderMesh.new()
	crack_mesh.top_radius = radius * 0.85
	crack_mesh.bottom_radius = radius * 1.0
	crack_mesh.height = 0.06
	crack_mesh.radial_segments = 16
	crack.mesh = crack_mesh
	var crack_material := StandardMaterial3D.new()
	crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crack_material.albedo_color = Color(1.0, 0.3, 0.04)
	crack_material.emission_enabled = true
	crack_material.emission = Color(1.0, 0.32, 0.03)
	crack_material.emission_energy_multiplier = 2.2
	crack.material_override = crack_material
	crack.position.y = 0.3
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crack)

	_jet_material = StandardMaterial3D.new()
	_jet_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_jet_material.albedo_color = Color(1.0, 0.45, 0.08)
	_jet_material.emission_enabled = true
	_jet_material.emission = Color(1.0, 0.38, 0.04)
	_jet_material.emission_energy_multiplier = 3.2
	var jet_mesh := CylinderMesh.new()
	jet_mesh.top_radius = 0.35
	jet_mesh.bottom_radius = radius
	jet_mesh.height = height
	jet_mesh.radial_segments = 14
	jet_mesh.rings = 4
	_jet = MeshInstance3D.new()
	_jet.name = "Jet"
	_jet.mesh = jet_mesh
	_jet.material_override = _jet_material
	_jet.position.y = height * 0.5
	_jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_jet.visible = false
	add_child(_jet)

	_sparks = CPUParticles3D.new()
	_sparks.name = "Sparks"
	_sparks.amount = 40
	_sparks.lifetime = 1.2
	_sparks.preprocess = 0.4
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = radius
	_sparks.direction = Vector3(0.0, 1.0, 0.0)
	_sparks.spread = 28.0
	_sparks.gravity = Vector3(0.0, -9.0, 0.0)
	_sparks.initial_velocity_min = 4.0
	_sparks.initial_velocity_max = 9.0
	_sparks.scale_amount_min = 0.4
	_sparks.scale_amount_max = 1.2
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.08
	spark_mesh.height = 0.16
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.75, 0.2)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.45, 0.04)
	spark_material.emission_energy_multiplier = 3.0
	spark_mesh.material = spark_material
	_sparks.mesh = spark_mesh
	_sparks.position.y = 0.8
	_sparks.emitting = false
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)

	_area = Area3D.new()
	_area.name = "BurnArea"
	_area.collision_layer = 0
	_area.collision_mask = 2
	_area.monitorable = false
	_area.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(radius * 2.0, height, radius * 2.0)
	shape.shape = box
	_area.add_child(shape)
	_area.position.y = height * 0.5
	add_child(_area)

	_warning = OmniLight3D.new()
	_warning.name = "Warning"
	_warning.position.y = 2.0
	_warning.light_color = Color(1.0, 0.22, 0.05)
	_warning.light_energy = 0.0
	_warning.omni_range = 9.0
	_warning.shadow_enabled = false
	add_child(_warning)

	_ring = MeshInstance3D.new()
	_ring.name = "WarningRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.75
	ring_mesh.outer_radius = radius * 0.95
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.25, 0.05)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.22, 0.03)
	ring_material.emission_energy_multiplier = 2.4
	_ring.material_override = ring_material
	_ring.position.y = 0.42
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_time = fposmod(_time + delta, _cycle)
	var shift := 0.0
	var warning_on := false
	if _time < idle_time:
		shift = 0.0
	elif _time < idle_time + warn_time:
		shift = 0.0
		warning_on = true
	else:
		var t := clampf((_time - idle_time - warn_time) / erupt_time, 0.0, 1.0)
		shift = sin(t * PI)

	var active := shift > 0.22
	_jet.visible = shift > 0.02
	_jet.scale.y = maxf(0.02, shift)
	_jet.position.y = height * 0.5 * maxf(0.02, shift)
	_jet_material.emission_energy_multiplier = 2.0 + shift * 3.0
	var pulse := 0.45 + 0.55 * absf(sin(_time * 18.0))
	_warning.light_energy = (2.6 if warning_on else shift * 1.4) * pulse
	_ring.scale = Vector3.ONE * (1.0 + (0.18 * pulse if warning_on else 0.0))
	_ring.visible = warning_on or active
	_sparks.emitting = active

	if not active or _cooldown > 0.0:
		return
	for body in _area.get_overlapping_bodies():
		_burn(body)


func _burn(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_cooldown = 1.5
	AudioManager.play_sfx("fall")
	GameFeel.flash(Color(1.0, 0.4, 0.05), 0.4)
	GameFeel.shake(3.0)
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager != null and manager.has_method("respawn_player"):
		manager.respawn_player()


func is_erupting() -> bool:
	return _time >= idle_time + warn_time
