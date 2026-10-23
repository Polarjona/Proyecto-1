extends Area3D

## Collectible crown. Persists in the profile and stays in the scene (hidden)
## so the HUD can always count how many crowns the course contains.

@export var crown_id: String = "crown_1"

@onready var visual: Node3D = $Visual
@onready var light: OmniLight3D = $Light
@onready var burst: CPUParticles3D = $Burst

var _base_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	add_to_group("crowns")
	_base_y = visual.position.y
	if SaveManager.has_crown(crown_id):
		_hide_collected()
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	visual.rotate_y(delta * 2.2)
	visual.position.y = _base_y + sin(_time * 2.0) * 0.12
	if light:
		light.light_energy = 0.9 + sin(_time * 4.0) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	if not SaveManager.collect_crown(crown_id):
		return
	_collected = true
	AudioManager.play_sfx("coin", 0.05)
	GameFeel.shake(1.2)
	if burst:
		burst.restart()
		burst.emitting = true
	visual.visible = false
	if light:
		light.visible = false
	set_deferred("monitoring", false)


func _hide_collected() -> void:
	_collected = true
	visual.visible = false
	if light:
		light.visible = false
	set_deferred("monitoring", false)
	set_process(false)
