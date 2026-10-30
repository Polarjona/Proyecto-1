extends Node3D

## Trampa de pinchos: la placa de rayas de peligro parpadea en rojo, los pinchos
## salen del suelo durante medio segundo y vuelven a esconderse. El aviso dura
## más que el golpe, así que la trampa siempre se puede leer antes de pisarla.
##
## Los pinchos no son un cuerpo sólido: empujan hacia arriba y hacia fuera al
## que esté encima. Así nadie queda atrapado dentro de la geometría, y el golpe
## se nota igual (salto forzado, aturdimiento y sacudida de cámara).

@export var idle_time: float = 1.1
@export var warn_time: float = 0.55
@export var rise_time: float = 0.14
@export var hold_time: float = 0.55
@export var hide_time: float = 0.5
@export var push_force: float = 7.5
@export var push_lift: float = 6.5
@export var stuns: bool = true
@export var phase_offset: float = 0.0
@export var spike_height: float = 0.8

@onready var spikes: Node3D = $Spikes
@onready var plate: MeshInstance3D = $Plate
@onready var push_area: Area3D = $PushArea
@onready var warning: OmniLight3D = $Warning

var _time: float = 0.0
var _cycle: float = 1.0
var _armed: bool = false
var _hit_ids: Dictionary = {}


func _ready() -> void:
	add_to_group("spike_traps")
	_cycle = idle_time + warn_time + rise_time + hold_time + hide_time
	_time = fposmod(phase_offset, _cycle)
	spikes.position.y = -spike_height
	_build_spikes()


## Los pinchos se construyen en runtime con una sola malla compartida: la
## escena queda corta y las 16 trampas del tramo pesan lo mismo que una.
func _build_spikes() -> void:
	if spikes.get_child_count() > 0:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.17
	mesh.height = 0.9
	mesh.radial_segments = 8
	mesh.rings = 1
	var material := load("res://materials/spin_gold.tres") as Material
	var offsets := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(-0.85, 0.0, -0.85), Vector3(0.85, 0.0, -0.85),
		Vector3(-0.85, 0.0, 0.85), Vector3(0.85, 0.0, 0.85),
	]
	for i in offsets.size():
		var spike := MeshInstance3D.new()
		spike.name = "Spike%d" % i
		spike.mesh = mesh
		spike.material_override = material
		spike.position = offsets[i] + Vector3(0.0, 0.45, 0.0)
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spikes.add_child(spike)


func _physics_process(delta: float) -> void:
	_time = fposmod(_time + delta, _cycle)
	var shift := 0.0
	var warning_on := false
	if _time < idle_time:
		shift = 0.0
	elif _time < idle_time + warn_time:
		shift = 0.0
		warning_on = true
	elif _time < idle_time + warn_time + rise_time:
		var rise := (_time - idle_time - warn_time) / rise_time
		shift = smoothstep(0.0, 1.0, rise)
	elif _time < idle_time + warn_time + rise_time + hold_time:
		shift = 1.0
	else:
		var back := (_time - idle_time - warn_time - rise_time - hold_time) / hide_time
		shift = 1.0 - smoothstep(0.0, 1.0, back)
	_apply_shift(shift)

	var was_armed := _armed
	_armed = shift > 0.55
	if _armed and not was_armed:
		AudioManager.play_sfx_at("impact", global_position, 0.14, -6.0)
		GameFeel.shake(1.4)
	if not _armed:
		_hit_ids.clear()

	var pulse := 0.45 + 0.55 * sin(_time * 30.0)
	warning.light_energy = 2.4 * pulse if warning_on else 0.0
	if plate != null:
		plate.scale = Vector3(1.0, 1.0, 1.0)

	if not _armed:
		return
	for body in push_area.get_overlapping_bodies():
		_push(body)


func _apply_shift(value: float) -> void:
	spikes.position.y = -spike_height * (1.0 - value)


func _push(body: Node3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("bot")):
		return
	if not body.has_method("apply_push"):
		return
	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true
	var direction: Vector3 = body.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT
	else:
		direction = direction.normalized()
	body.apply_push(direction * push_force + Vector3.UP * push_lift)
	if stuns and body.has_method("stun"):
		body.stun()
	AudioManager.play_sfx_at("impact", global_position, 0.2, -5.0)
	GameFeel.shake(2.0)


## Estado actual, para las pruebas automáticas ("idle", "warn", "up", "hide").
func get_state() -> String:
	if _time < idle_time:
		return "idle"
	if _time < idle_time + warn_time:
		return "warn"
	if _time < idle_time + warn_time + rise_time + hold_time:
		return "up"
	return "hide"


func is_armed() -> bool:
	return _armed
