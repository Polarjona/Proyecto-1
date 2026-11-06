extends MeshInstance3D

## Placa de hazard pintada en el suelo: mientras el corredor la pisa va más
## lento, y al salir recupera la velocidad en `refresh` segundos. Las placas ya
## vienen horneadas en main.tscn y spin_go_round.tscn; los generadores también
## enganchan este script para los mapas nuevos.

## Velocidad a la que se corre sobre la placa (1.0 = sin freno).
@export var factor: float = 0.6
## Refresco del frenazo: al salir de la placa se recupera en este tiempo. La
## franja se cruza en décimas, así que el frenazo dura algo más para notarse.
@export var refresh: float = 0.5
## Altura del volumen que detecta a quien pisa la placa.
@export var height: float = 2.4

var _bodies: Array[Node3D] = []


func _ready() -> void:
	var size := Vector3(6.0, 0.5, 1.0)
	if mesh is BoxMesh:
		size = (mesh as BoxMesh).size
	var node_scale := global_transform.basis.get_scale()
	var area := Area3D.new()
	area.name = "SlowArea"
	area.collision_layer = 0
	# Solo cuerpos de corredor/bot (capa 2).
	area.collision_mask = 2
	area.monitoring = true
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(absf(size.x * node_scale.x), height, absf(size.z * node_scale.z))
	collider.shape = box
	collider.position.y = height * 0.5
	area.add_child(collider)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body.has_method("slow"):
			body.call("slow", refresh, factor)


func _on_body_entered(body: Node3D) -> void:
	if body not in _bodies:
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
