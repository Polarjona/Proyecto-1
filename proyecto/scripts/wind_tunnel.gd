extends Area3D

## Wind tunnel: continuous lateral acceleration with gusts.
## Each tunnel has a floor fan on its own side platform, separated from the
## narrow bridge the player crosses by a visible gap. The fan mirrors
## automatically when `wind_direction` is flipped, so the second tunnel never
## contradicts the wind it pushes.

@export var wind_direction: Vector3 = Vector3.RIGHT
@export var strength: float = 5.2
@export var gust_amplitude: float = 2.2
@export var gust_speed: float = 1.4
@export var vertical_strength: float = 0.0
@export var stream_span: float = 4.6
@export var stream_speed: float = 7.0
@export var fan_spin_speed: float = 8.0

@onready var streams: Array = [$StreamA, $StreamB, $StreamC]
@onready var fan: Node3D = $Fan
@onready var fan_platform: Node3D = $FanPlatform
@onready var rotor: Node3D = $Fan/Rotor

var _bodies: Array[Node3D] = []
var _base_positions: Array[Vector3] = []
var _time: float = 0.0
var _flow_sign: float = 1.0
var _wind_audio: AudioStreamPlayer3D


func _ready() -> void:
	# Runs before the player so the wind applies in the same physics frame.
	process_physics_priority = -4
	add_to_group("wind_tunnels")
	wind_direction = wind_direction.normalized()
	_flow_sign = signf(wind_direction.x)
	if absf(_flow_sign) < 0.1:
		_flow_sign = 1.0
	_orient_props()
	_setup_wind_audio()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_base_positions.resize(streams.size())
	for i in streams.size():
		var stream := streams[i] as Node3D
		if stream != null:
			_base_positions[i] = stream.position


func _physics_process(delta: float) -> void:
	_time += delta
	var gust := strength + sin(_time * TAU * gust_speed) * gust_amplitude
	var push := wind_direction * gust + Vector3.UP * vertical_strength

	for body in _bodies:
		if not is_instance_valid(body):
			continue
		# Los bots tienen su propio canal para poder inclinarse hacia el viento;
		# el jugador y cualquier otro cuerpo lo reciben entero.
		if body.has_method("add_wind_velocity"):
			body.call("add_wind_velocity", push)
		elif body.has_method("add_external_velocity"):
			body.add_external_velocity(push)
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity += push

	_animate_streams()
	if rotor:
		rotor.rotate_x(fan_spin_speed * _flow_sign * delta)


## Puts the fan and its own platform on the upwind side, separated from the
## bridge by a clear gap. The second tunnel is automatically mirrored.
func _orient_props() -> void:
	var upwind := -_flow_sign
	var side_x := upwind * 4.6
	if fan_platform:
		fan_platform.position = Vector3(side_x, 0.0, 0.0)
	if fan:
		fan.position = Vector3(side_x, 0.0, 0.0)
		fan.rotation.y = 0.0 if _flow_sign > 0.0 else PI


## Bucle de viento en 3D. Solo suena mientras hay alguien cruzando, así que
## se oye la ráfaga al entrar y se apaga al salir por el otro lado.
func _setup_wind_audio() -> void:
	var stream: AudioStream = AudioManager.get_sfx_stream("wind")
	if stream == null:
		return
	_wind_audio = AudioStreamPlayer3D.new()
	_wind_audio.name = "WindAudio"
	_wind_audio.stream = stream
	_wind_audio.bus = "SFX"
	_wind_audio.volume_db = -9.0
	_wind_audio.unit_size = 5.0
	_wind_audio.max_distance = 28.0
	_wind_audio.position = Vector3(0.0, 1.2, 0.0)
	add_child(_wind_audio)


func _animate_streams() -> void:
	for i in streams.size():
		var stream := streams[i] as Node3D
		if stream == null:
			continue
		var offset := fmod(_time * (stream_speed + float(i) * 1.6), stream_span)
		var base := _base_positions[i]
		stream.position = Vector3(
			base.x + _flow_sign * (-stream_span * 0.5 + offset),
			base.y,
			base.z
		)
		var fade := sin((offset / stream_span) * PI)
		stream.scale = Vector3(1.0, 1.0, 0.6 + fade * 0.8)


func _on_body_entered(body: Node3D) -> void:
	if body not in _bodies:
		_bodies.append(body)
	if _wind_audio != null and not _wind_audio.playing:
		_wind_audio.play()


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
	if _bodies.is_empty() and _wind_audio != null:
		_wind_audio.stop()
