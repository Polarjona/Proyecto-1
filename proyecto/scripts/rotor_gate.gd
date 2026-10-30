extends Node3D

## Aspa giratoria: un brazo pesado gira en el plano de la marcha. Cuando pasa
## abajo barre el pasillo a la altura de las piernas y hay que saltarlo; cuando
## sube, el paso queda limpio. El brazo es sólido, así que también se puede
## pisar, y empuja a quien pilla de lado.
##
## El aviso es el propio movimiento: el aspa se ve venir desde el tramo
## anterior, y su contrapeso marca siempre dónde va a caer.

@export var spin_speed: float = 1.0
## -1.0 invierte el sentido de giro (dos aspas seguidas giran al revés).
@export var spin_direction: float = 1.0
@export var push_force: float = 7.5
@export var stuns: bool = true
@export var phase_offset: float = 0.0
@export var arm_length: float = 2.5

@onready var rotor: AnimatableBody3D = $Rotor
@onready var push_area: Area3D = $Rotor/PushArea

var _whoosh_timer: float = 0.0


func _ready() -> void:
	add_to_group("rotors")
	rotor.rotation.z = phase_offset
	push_area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotor.rotation.z += spin_speed * spin_direction * delta
	_whoosh_timer -= delta
	if _whoosh_timer <= 0.0:
		_whoosh_timer = 1.4
		AudioManager.play_sfx_at("whoosh", rotor.global_position, 0.2, -12.0)


func _on_body_entered(body: Node3D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("bot")):
		return
	if not body.has_method("apply_push"):
		return
	var direction: Vector3 = body.global_position - rotor.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT
	else:
		direction = direction.normalized()
	body.apply_push(direction * push_force + Vector3.UP * 3.4)
	if stuns and body.has_method("stun"):
		body.stun()
	GameFeel.shake(1.8)


## Ángulo actual del aspa (radianes). Expuesto para pruebas y diagnóstico.
func get_angle() -> float:
	return rotor.rotation.z
