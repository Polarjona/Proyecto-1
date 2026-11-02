extends Node3D

## Losa frágil: tiembla en cuanto alguien la pisa y se desploma. Vuelve a
## aparecer unos segundos después para que el pelotón de bots pueda cruzar el
## puente sin quedarse sin camino.

@export var warn_time: float = 0.9
@export var fall_time: float = 0.45
@export var respawn_time: float = 3.2
@export var fall_distance: float = 9.0
@export var tile_material: Material

@onready var body: StaticBody3D = $Body
@onready var mesh: MeshInstance3D = $Body/Mesh
@onready var trigger: Area3D = $Trigger

var _state: String = "idle"
var _timer: float = 0.0
var _base_y: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	add_to_group("crumble_tiles")
	_base_y = body.position.y
	if tile_material != null:
		mesh.material_override = tile_material
	trigger.body_entered.connect(_on_body_entered)
	if body.collision_layer == 0:
		body.collision_layer = 1
	if not trigger.monitoring:
		trigger.monitoring = true


func _on_body_entered(toucher: Node3D) -> void:
	if _state != "idle":
		return
	if not (toucher.is_in_group("player") or toucher.is_in_group("bot")):
		return
	_state = "warn"
	_timer = warn_time
	AudioManager.play_sfx_at("creak", global_position, 0.15, -5.0)


func _process(delta: float) -> void:
	match _state:
		"warn":
			_timer -= delta
			_shake += delta * 42.0
			mesh.position.x = sin(_shake) * 0.06
			mesh.position.z = cos(_shake * 1.3) * 0.06
			if _timer <= 0.0:
				_break()
		"fall":
			_timer += delta
			var progress := clampf(_timer / fall_time, 0.0, 1.0)
			body.position.y = _base_y - fall_distance * progress * progress
			if progress >= 1.0:
				_state = "gone"
				_timer = 0.0
				mesh.visible = false
		"gone":
			_timer += delta
			if _timer >= respawn_time:
				_respawn()


func _break() -> void:
	_state = "fall"
	_timer = 0.0
	body.collision_layer = 0
	trigger.set_deferred("monitoring", false)
	mesh.position = Vector3.ZERO
	AudioManager.play_sfx_at("impact", global_position, 0.2, -6.0)
	GameFeel.shake(1.2)


func _respawn() -> void:
	_state = "idle"
	_timer = 0.0
	_shake = 0.0
	body.position.y = _base_y
	body.collision_layer = 1
	mesh.position = Vector3.ZERO
	mesh.visible = true
	trigger.set_deferred("monitoring", true)


## Estado actual, para las pruebas automáticas ("idle", "warn", "fall", "gone").
func get_state() -> String:
	return _state
