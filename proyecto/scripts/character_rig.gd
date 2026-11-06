class_name CharacterRig
extends SkeletonModifier3D

## Capa procedural de animación sobre los clips del pack de Quaternius.
##
## El pack no trae clip de carrera ni de salto: `Running_A` es el andar
## acelerado y en el aire se quedaba el idle, de ahí que los corredores
## pareciesen pasear y quedasen tiesos al saltar. Esto se aplica **después**
## del AnimationPlayer (es un `SkeletonModifier3D`), así que suma poses sobre
## el clip que esté sonando:
##
## - inclina el torso hacia delante al esprintar;
## - recoge piernas y abre brazos en el aire;
## - flexiona el cuerpo en el aterrizaje.
##
## Los nombres de hueso son los del pack (`UpperLeg.L`, `Torso`…) y el hueso
## que no exista se ignora, así que un modelo nuevo sin esqueleto no rompe nada.

## Radianes por segundo con los que se mezcla cada pose.
const BLEND_SPEED := 14.0
const LAND_BLEND_SPEED := 22.0

const BONE_NAMES := [
	"Torso", "Abdomen", "Head",
	"UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R",
	"UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R",
]

## Estado que pide el corredor: "idle" | "walk" | "run" | "jump" | "land" | "stun".
var state: String = "idle"
## 0..1, expuestos para tests.
var run_blend: float = 0.0
var jump_blend: float = 0.0
var land_blend: float = 0.0

var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _cached_for: Skeleton3D


func _ready() -> void:
	_refresh_skeleton()


## Cambia el estado de locomoción. El mezclado y la pose se resuelven en
## `_process_modification_with_delta`, ya con el clip aplicado.
func set_state(new_state: String) -> void:
	state = new_state


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if skeleton != _cached_for:
		_skeleton = skeleton
		_refresh_skeleton()
	if _bones.is_empty():
		return

	var target_run := 1.0 if state == "run" else (0.45 if state == "walk" else 0.0)
	run_blend = move_toward(run_blend, target_run, BLEND_SPEED * delta)
	jump_blend = move_toward(jump_blend, 1.0 if state == "jump" else 0.0, BLEND_SPEED * delta)
	land_blend = move_toward(land_blend, 1.0 if state == "land" else 0.0, LAND_BLEND_SPEED * delta)
	if run_blend <= 0.001 and jump_blend <= 0.001 and land_blend <= 0.001:
		return

	var air := jump_blend
	var crouch := land_blend
	# Torso adelantado: el andar parece esprint, y en el aire el cuerpo va
	# lanzado hacia delante en vez de vertical.
	_rotate("Torso", Vector3.RIGHT, 0.1 * run_blend + 0.2 * air + 0.34 * crouch)
	_rotate("Abdomen", Vector3.RIGHT, 0.05 * run_blend + 0.08 * air + 0.14 * crouch)
	_rotate("Head", Vector3.RIGHT, -0.06 * run_blend - 0.12 * air - 0.16 * crouch)

	# Brazos: codos algo flexionados al correr y brazos abiertos en el aire.
	_rotate("LowerArm.L", Vector3.RIGHT, 0.35 * run_blend + 0.5 * air)
	_rotate("LowerArm.R", Vector3.RIGHT, 0.35 * run_blend + 0.5 * air)
	_rotate("UpperArm.L", Vector3.BACK, 0.55 * air)
	_rotate("UpperArm.R", Vector3.BACK, -0.55 * air)

	# Piernas: rodillas arriba en el aire y sentadilla al aterrizar.
	_rotate("UpperLeg.L", Vector3.RIGHT, 0.8 * air + 0.55 * crouch)
	_rotate("UpperLeg.R", Vector3.RIGHT, 0.65 * air + 0.55 * crouch)
	_rotate("LowerLeg.L", Vector3.LEFT, 0.75 * air + 0.55 * crouch)
	_rotate("LowerLeg.R", Vector3.LEFT, 0.65 * air + 0.55 * crouch)


## Suma una rotación local al hueso. Se multiplica sobre la pose del clip, así
## que la animación sigue moviendo los huesos y esto solo la exagera.
func _rotate(bone_name: String, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0005:
		return
	var index: int = int(_bones.get(bone_name, -1))
	if index < 0:
		return
	var current := _skeleton.get_bone_pose_rotation(index)
	_skeleton.set_bone_pose_rotation(index, current * Quaternion(axis, angle))


func _refresh_skeleton() -> void:
	_skeleton = get_skeleton()
	_bones.clear()
	_cached_for = _skeleton
	if _skeleton == null:
		return
	for bone_name: String in BONE_NAMES:
		var index := _skeleton.find_bone(bone_name)
		if index >= 0:
			_bones[bone_name] = index
