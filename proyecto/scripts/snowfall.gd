@tool
extends CPUParticles3D

## Nevada del glaciar: el emisor viaja con la cámara y los copos se quedan
## quietos en el mundo (`local_coords = false`). Así nieva igual en la salida,
## en el pasillo de rocas y en la cumbre, sin depender de dónde quedó el nodo.

## Metros por delante de la cámara donde se centra la caja de emisión.
@export var ahead: float = 30.0
## Altura de la caja respecto a la cámara.
@export var above: float = 14.0


func _ready() -> void:
	# Los copos viven en el mundo: si no, viajarían pegados a la cámara.
	local_coords = false


func _process(_delta: float) -> void:
	# En el editor la nieve se queda donde está: el mapa se edita quieto.
	if Engine.is_editor_hint():
		return
	var camera := get_viewport().get_camera_3d()
	var target: Node3D = camera
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D
	if target == null:
		return
	var offset := Vector3(0.0, above, 0.0)
	if camera != null:
		var forward := -camera.global_transform.basis.z
		forward.y = 0.0
		offset += forward.normalized() * ahead
	global_position = target.global_position + offset
