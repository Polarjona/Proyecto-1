extends Node3D

## Lluvia de meteoros del volcán: cada pocos segundos marca un círculo en el
## suelo cerca del corredor, deja pasar el aviso y deja caer una roca en llamas.
## Solo dispara mientras la carrera está en marcha, así que la salida y la
## cuenta atrás quedan limpias.

const METEOR_SCRIPT := preload("res://scripts/meteor.gd")

@export var interval: float = 4.2
@export var warn_time: float = 1.5
@export var fall_height: float = 18.0
@export var spread: float = 3.6

var _timer: float = 5.0


func _ready() -> void:
	add_to_group("meteor_rain")


func _physics_process(delta: float) -> void:
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager != null and "is_running" in manager and not bool(manager.get("is_running")):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval + randf_range(-0.5, 0.5)
	_spawn_marker()


func _spawn_marker() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	# Sondea justo debajo del jugador, no desde muy arriba: en la espiral el
	# primer suelo que aparece 50 m más arriba es otra vuelta de la rampa.
	var target := player.global_position + Vector3(
		randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := target + Vector3.UP * 2.5
	var query := PhysicsRayQueryParameters3D.create(from, target + Vector3.DOWN * 7.0, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	_telegraph(hit["position"])


func _telegraph(impact: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "MeteorWarning"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.85
	ring_mesh.outer_radius = 3.3
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 8
	marker.mesh = ring_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.25, 0.04)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.3, 0.02)
	material.emission_energy_multiplier = 2.8
	marker.material_override = material
	marker.position = impact + Vector3.UP * 0.12
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.28, 0.04)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.shadow_enabled = false
	marker.add_child(light)

	await get_tree().create_timer(warn_time).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(marker):
		marker.queue_free()
	var meteor := METEOR_SCRIPT.new() as Node3D
	meteor.name = "Meteor"
	meteor.set("target_y", impact.y)
	meteor.position = impact + Vector3.UP * fall_height
	add_child(meteor)
