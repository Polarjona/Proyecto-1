extends Node3D

## Roca persecutoria: rueda por el pasillo en contra de la marcha y vuelve a
## salir por la boca del tramo. Se esquiva de lado; no hay que saltarla, hay que
## dejarle sitio. La roca se esconde al salir y espera un momento antes de
## volver a aparecer, para que nadie reciba una roca encima de la cabeza.
##
## Los avisos son geométricos: la boca de salida (aro dorado) marca por dónde
## aparece, y la roca rueda con un giro real proporcional a la velocidad.

@export var travel: Vector3 = Vector3(0.0, 0.0, 18.0)
@export var speed: float = 5.4
@export var radius: float = 1.0
@export var push_force: float = 7.0
@export var push_lift: float = 1.2
@export var stuns: bool = true
@export var phase_offset: float = 0.0
@export var respawn_delay: float = 1.4
## Tiempo mínimo sin nadie en la boca antes de volver a salir.
@export var clear_radius: float = 2.4

@onready var ball: AnimatableBody3D = $Ball
@onready var push_area: Area3D = $Ball/PushArea
@onready var spawn_ring: Node3D = $SpawnRing

var _distance: float = 0.0
var _length: float = 1.0
var _speed: float = 5.4
var _rolling: bool = false
var _wait: float = 0.0
var _hit_cooldowns: Dictionary = {}
var _time: float = 0.0


func _ready() -> void:
	add_to_group("boulders")
	# El bot esquiva las bolas que caen mirando este grupo: la roca entra en él
	# para que el mismo piloto la aparte sin código nuevo.
	add_to_group("hazard_balls")
	_length = maxf(travel.length(), 0.001)
	_speed = speed
	_distance = fposmod(phase_offset * _speed, _length)
	_rolling = true
	_push_home()


func _physics_process(delta: float) -> void:
	_time += delta
	_tick_cooldowns(delta)
	if not _rolling:
		_wait -= delta
		if _wait <= 0.0 and _spawn_is_clear():
			_restart()
		return

	_distance += _speed * delta
	_push_home()
	# Rodadura: la bola gira sobre su eje local X lo que avanza sobre el suelo.
	if radius > 0.01:
		ball.rotate_x(-_speed * delta / radius)
	if _distance >= _length:
		_finish_pass()
		return
	for body in push_area.get_overlapping_bodies():
		_push(body)


## Coloca la roca en el punto que le toca del recorrido.
func _push_home() -> void:
	var direction := travel.normalized()
	ball.position = direction * _distance
	if spawn_ring != null:
		spawn_ring.position = Vector3.ZERO


## Al llegar al final se esconde, deja de ser sólida y espera para reaparecer.
func _finish_pass() -> void:
	_rolling = false
	_wait = respawn_delay
	_distance = 0.0
	ball.visible = false
	ball.collision_layer = 0
	ball.position = Vector3.ZERO
	_hit_cooldowns.clear()


func _restart() -> void:
	_rolling = true
	_distance = 0.0
	ball.visible = true
	ball.collision_layer = 1
	ball.position = Vector3.ZERO
	ball.rotation = Vector3.ZERO
	AudioManager.play_sfx_at("whoosh", global_position, 0.22, -10.0)


## Nadie debe recibir la roca encima: si hay alguien en la boca se retrasa.
func _spawn_is_clear() -> bool:
	for group in ["player", "bot"]:
		for body in get_tree().get_nodes_in_group(group):
			if not (body is Node3D) or not is_instance_valid(body):
				continue
			var delta: Vector3 = (body as Node3D).global_position - global_position
			if Vector2(delta.x, delta.z).length() < clear_radius:
				return false
	return true


func _tick_cooldowns(delta: float) -> void:
	for key in _hit_cooldowns.keys():
		var remaining: float = float(_hit_cooldowns[key]) - delta
		if remaining <= 0.0:
			_hit_cooldowns.erase(key)
		else:
			_hit_cooldowns[key] = remaining


func _push(body: Node3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("bot")):
		return
	if not body.has_method("apply_push"):
		return
	var id := body.get_instance_id()
	if _hit_cooldowns.has(id):
		return
	_hit_cooldowns[id] = 0.55
	var direction: Vector3 = body.global_position - ball.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT
	else:
		direction = direction.normalized()
	body.apply_push(direction * push_force + Vector3.UP * push_lift)
	if stuns and body.has_method("stun"):
		body.stun()
	AudioManager.play_sfx_at("impact", ball.global_position, 0.25, -4.0)
	GameFeel.shake(2.4)


## Distancia recorrida en el pasillo, para diagnóstico y pruebas.
func get_distance() -> float:
	return _distance


func is_rolling() -> bool:
	return _rolling
