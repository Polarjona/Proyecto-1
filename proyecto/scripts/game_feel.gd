extends Node

## Autoload: "juice" global. Hitstop, slow motion, sacudida y flash.
## Usa el reloj real (Time.get_ticks_msec) para no depender de time_scale.

var shake_strength: float = 0.0
var flash_amount: float = 0.0
var flash_color: Color = Color.WHITE

var _hitstop_until_ms: int = 0
var _slowmo_until_ms: int = 0
var _slowmo_scale: float = 1.0
var _last_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	_last_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_delta := clampf(float(now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now

	if now < _hitstop_until_ms:
		Engine.time_scale = 0.05
	elif now < _slowmo_until_ms:
		Engine.time_scale = _slowmo_scale
	else:
		Engine.time_scale = 1.0

	shake_strength = move_toward(shake_strength, 0.0, real_delta * (12.0 + shake_strength * 5.0))
	flash_amount = move_toward(flash_amount, 0.0, real_delta * 3.2)


## Sacudida en unidades arbitrarias (4 = golpe notable, 10 = brutal).
func shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


## Congela el juego unos milisegundos para dar peso al impacto.
func hit_stop(seconds: float) -> void:
	_hitstop_until_ms = maxi(_hitstop_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))


func slow_motion(seconds: float, scale: float = 0.35) -> void:
	_slowmo_until_ms = maxi(_slowmo_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))
	_slowmo_scale = clampf(scale, 0.05, 1.0)


func flash(color: Color, amount: float = 0.4) -> void:
	flash_color = color
	flash_amount = maxf(flash_amount, amount)


## Desplazamiento local de cámara (en metros) para el frame actual.
func camera_offset() -> Vector2:
	var strength := shake_strength * float(SaveManager.get_setting("shake", 1.0))
	if strength <= 0.001:
		return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * 0.012


func reset() -> void:
	Engine.time_scale = 1.0
	_hitstop_until_ms = 0
	_slowmo_until_ms = 0
	_slowmo_scale = 1.0
	_last_ms = Time.get_ticks_msec()
	shake_strength = 0.0
	flash_amount = 0.0
