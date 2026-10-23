extends Node

## Autoload singleton: música de fondo + SFX con pool y buses separados.
## Los archivos ausentes se ignoran para que el juego nunca se rompa.

const MUSIC_PATH := "res://audio/music/background.ogg"
const SFX_PATHS := {
	"jump": "res://audio/sfx/jump.wav",
	"checkpoint": "res://audio/sfx/checkpoint.wav",
	"finish": "res://audio/sfx/finish.wav",
	"fall": "res://audio/sfx/fall.wav",
	"dive": "res://audio/sfx/dive.wav",
	"land": "res://audio/sfx/land.wav",
	"impact": "res://audio/sfx/impact.wav",
	"coin": "res://audio/sfx/coin.wav",
	"ui": "res://audio/sfx/ui.wav",
	"countdown": "res://audio/sfx/countdown.wav",
}

const SFX_POOL_SIZE := 8

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_setup_music()
	_setup_sfx_pool()
	_load_sfx_streams()
	_play_music()
	SaveManager.apply_settings()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.volume_db = -4.0
	add_child(_music_player)


func _setup_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)


func _load_sfx_streams() -> void:
	for key: String in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_sfx_streams[key] = load(path)
		else:
			print("AudioManager: missing SFX '%s' (skipped)" % path)


func _play_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		print("AudioManager: missing music '%s' (skipped)" % MUSIC_PATH)
		return
	var stream: AudioStream = load(MUSIC_PATH)
	_enable_loop(stream)
	_music_player.stream = stream
	_music_player.play()


## Fuerza el bucle en runtime: .ogg por `loop`, .wav por `loop_mode`.
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


## Reproduce un SFX por clave. `pitch_variance` evita el efecto "metralleta".
func play_sfx(key: String, pitch_variance: float = 0.05, volume_db: float = 0.0) -> void:
	if not _sfx_streams.has(key):
		return
	for player in _sfx_pool:
		if not player.playing:
			_play_on(player, key, pitch_variance, volume_db)
			return
	_play_on(_sfx_pool[0], key, pitch_variance, volume_db)


func _play_on(player: AudioStreamPlayer, key: String, pitch_variance: float, volume_db: float) -> void:
	player.stream = _sfx_streams[key]
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.volume_db = volume_db
	player.play()


func set_music_volume(linear: float) -> void:
	var index := AudioServer.get_bus_index("Music")
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0001, 1.0)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func set_sfx_volume(linear: float) -> void:
	var index := AudioServer.get_bus_index("SFX")
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0001, 1.0)))
	AudioServer.set_bus_mute(index, linear <= 0.001)
