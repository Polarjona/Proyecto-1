extends Node3D

## Pistón hidráulico: un bloque sólido que sale de la pared, barre el carril y
## vuelve a recogerse. Antes de cada golpe enciende una luz de aviso para que
## el golpe se pueda leer y esquivar; el empujón es lateral, así que nunca deja
## a nadie atrapado contra el suelo como una prensa vertical.
##
## El empujón se comprueba con los cuerpos que solapan el área: si alguien ya
## está pegado a la pared cuando arranca el golpe, `body_entered` no vuelve a
## dispararse y el golpe no contaría.

@export var travel: Vector3 = Vector3(4.6, 0.0, 0.0)
@export var idle_time: float = 1.2
@export var warn_time: float = 0.7
@export var punch_time: float = 0.22
@export var hold_time: float = 0.35
@export var return_time: float = 1.0
@export var push_force: float = 7.5
@export var stuns: bool = true
## Desfase del ciclo, para que dos pistones seguidos no golpeen a la vez.
@export var phase_offset: float = 0.0

@onready var head: AnimatableBody3D = $Head
@onready var push_area: Area3D = $Head/PushArea
@onready var warning: OmniLight3D = $Warning
@onready var lamp: MeshInstance3D = $Lamp

var _time: float = 0.0
var _cycle: float = 1.0
var _pushing: bool = false
## Cuerpos ya golpeados en el golpe actual, para no repetir el empujón.
var _hit_ids: Dictionary = {}


func _ready() -> void:
	add_to_group("pistons")
	_cycle = idle_time + warn_time + punch_time + hold_time + return_time
	_time = fmod(phase_offset, _cycle)
	# La lámpara se colecciona en la ranura de la pared, del lado del carril.
	var slot := travel.normalized()
	lamp.position = slot * 0.95 + Vector3(0.0, 1.35, 0.0)
	warning.position = slot * 0.95 + Vector3(0.0, 1.9, 0.0)
	if lamp.material_override is StandardMaterial3D:
		lamp.material_override = (lamp.material_override as StandardMaterial3D).duplicate()
	_set_shift(0.0)


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta, _cycle)
	var shift := 0.0
	var warning_on := false
	if _time < idle_time:
		shift = 0.0
	elif _time < idle_time + warn_time:
		shift = 0.0
		warning_on = true
	elif _time < idle_time + warn_time + punch_time:
		var punch := (_time - idle_time - warn_time) / punch_time
		shift = smoothstep(0.0, 1.0, punch)
	elif _time < idle_time + warn_time + punch_time + hold_time:
		shift = 1.0
	else:
		var back := (_time - idle_time - warn_time - punch_time - hold_time) / return_time
		shift = 1.0 - smoothstep(0.0, 1.0, back)
	_set_shift(shift)
	_pushing = shift > 0.05
	if not _pushing:
		_hit_ids.clear()

	var pulse := 0.6 + 0.4 * sin(_time * 26.0)
	warning.light_energy = 2.6 * pulse if warning_on else 0.0
	if lamp.material_override is StandardMaterial3D:
		var mat := lamp.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 2.2 * pulse if warning_on else 0.3

	if not _pushing:
		return
	for body in push_area.get_overlapping_bodies():
		_push(body)


func _set_shift(value: float) -> void:
	head.position = travel * value


func _push(body: Node3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("bot")):
		return
	if not body.has_method("apply_push"):
		return
	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true
	var direction := (global_transform.basis * travel).normalized()
	body.apply_push(direction * push_force + Vector3.UP * 1.1)
	if stuns and body.has_method("stun"):
		body.stun()
	AudioManager.play_sfx_at("impact", head.global_position, 0.18, -3.0)
	GameFeel.shake(2.0)
