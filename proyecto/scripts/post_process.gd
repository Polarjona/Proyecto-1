extends CanvasLayer

## Postproceso global: viñeta, grano, aberración, líneas de velocidad,
## aturdimiento y flash de impacto. Se dibuja por debajo del HUD.

@onready var rect: ColorRect = $Rect

var _material: ShaderMaterial
var _player: CharacterBody3D
var _stun: float = 0.0


func _ready() -> void:
	layer = 0
	_material = rect.material as ShaderMaterial


func _process(delta: float) -> void:
	if _material == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	var speed_ratio := 0.0
	var target_stun := 0.0
	if _player:
		var horizontal := Vector2(_player.velocity.x, _player.velocity.z).length()
		speed_ratio = clampf(horizontal / 10.0, 0.0, 1.0)
		if _player.has_method("is_stunned") and _player.is_stunned():
			target_stun = 1.0
	_stun = lerpf(_stun, target_stun, 6.0 * delta)

	_material.set_shader_parameter("speed", speed_ratio)
	_material.set_shader_parameter("stun", _stun)
	_material.set_shader_parameter("vignette", 0.3 + _stun * 0.28)
	_material.set_shader_parameter("grain", 0.025)
	_material.set_shader_parameter("aberration", 0.0012 + speed_ratio * 0.0035 + GameFeel.flash_amount * 0.02)
	_material.set_shader_parameter("flash_amount", GameFeel.flash_amount)
	_material.set_shader_parameter("flash_color", GameFeel.flash_color)
