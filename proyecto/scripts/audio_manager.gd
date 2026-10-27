extends Node

## Autoload singleton: música del menú + SFX 2D y 3D con buses separados.
## La música NO arranca sola: la pide el menú principal, y la carrera la para,
## para que durante la partida solo se oigan los efectos y el viento.
## Los archivos ausentes se ignoran para que el juego nunca se rompa.

const MUSIC_PATH := "res://audio/music/menu_theme.wav"
## Tema que suena al cruzar la meta, encima de la pantalla de resultados.
const VICTORY_PATH := "res://audio/music/victory.mp3"
## La fanfarria tiene su propio bus: se oye siempre, aunque la música del
## menú esté baja, pero el volumen maestro la sigue controlando.
## El archivo viene masterizado a tope (-7.8 LUFS, picos a 0 dBFS), así que el
## reproductor lo baja 9 dB: queda ~12 dB por encima del menú y con aire de
## sobra para que el Master no recorte.
const VICTORY_BUS := "Victory"
const VICTORY_VOLUME_DB := -9.0
const SFX_PATHS := {
	"jump": "res://audio/sfx/jump.wav",
	"step": "res://audio/sfx/step.wav",
	"checkpoint": "res://audio/sfx/checkpoint.wav",
	"finish": "res://audio/sfx/finish.wav",
	"fall": "res://audio/sfx/fall.wav",
	"dive": "res://audio/sfx/dive.wav",
	"land": "res://audio/sfx/land.wav",
	"impact": "res://audio/sfx/impact.wav",
	"coin": "res://audio/sfx/coin.wav",
	"ui": "res://audio/sfx/ui.wav",
	"countdown": "res://audio/sfx/countdown.wav",
	"wind": "res://audio/sfx/wind.wav",
	"cannon": "res://audio/sfx/cannon.wav",
	"creak": "res://audio/sfx/creak.wav",
	"boing": "res://audio/sfx/boing.wav",
	"whoosh": "res://audio/sfx/whoosh.wav",
}

## Claves que deben reproducirse en bucle (viento, ambiente...).
const LOOPING_SFX := ["wind"]

const SFX_POOL_SIZE := 10
const SFX_3D_POOL_SIZE := 14
const MUSIC_VOLUME_DB := -6.0
const MUSIC_SILENT_DB := -40.0

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []
var _sfx_streams: Dictionary = {}
var _music_stream: AudioStream
var _music_tween: Tween
var _victory_player: AudioStreamPlayer
var _victory_stream: AudioStream
## RNG propio: el pitch aleatorio de los SFX no debe alterar la secuencia
## aleatoria del gameplay (carriles y velocidades de los bots).
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus(VICTORY_BUS)
	_setup_music()
	_setup_victory()
	_setup_sfx_pool()
	_setup_sfx_3d_pool()
	_load_sfx_streams()
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
	_music_player.volume_db = MUSIC_SILENT_DB
	add_child(_music_player)


## Reproductor aparte: la fanfarria de victoria no comparte estado con el
## tema del menú, así que puede sonar sola sin cortar la música de fondo.
func _setup_victory() -> void:
	_victory_player = AudioStreamPlayer.new()
	_victory_player.name = "VictoryPlayer"
	_victory_player.bus = VICTORY_BUS
	_victory_player.volume_db = VICTORY_VOLUME_DB
	add_child(_victory_player)


func _setup_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)


## Pool posicional: pasos de bots, cañones, balancín y martillos se atenúan
## con la distancia, así que solo suenan cuando importan.
func _setup_sfx_3d_pool() -> void:
	for i in SFX_3D_POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.name = "SFX3DPlayer%d" % i
		player.bus = "SFX"
		player.unit_size = 6.0
		player.max_distance = 30.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_sfx_3d_pool.append(player)


func _load_sfx_streams() -> void:
	for key: String in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if not ResourceLoader.exists(path):
			print("AudioManager: missing SFX '%s' (skipped)" % path)
			continue
		var stream: AudioStream = load(path)
		if key in LOOPING_SFX:
			_enable_loop(stream)
		_sfx_streams[key] = stream


func _load_victory_stream() -> bool:
	if _victory_stream != null:
		return true
	if not ResourceLoader.exists(VICTORY_PATH):
		print("AudioManager: missing victory theme '%s' (skipped)" % VICTORY_PATH)
		return false
	_victory_stream = load(VICTORY_PATH)
	return _victory_stream != null


func _load_music_stream() -> bool:
	if _music_stream != null:
		return true
	if not ResourceLoader.exists(MUSIC_PATH):
		print("AudioManager: missing music '%s' (skipped)" % MUSIC_PATH)
		return false
	_music_stream = load(MUSIC_PATH)
	_enable_loop(_music_stream)
	return _music_stream != null


## Fuerza el bucle en runtime: .wav por `loop_mode`, .ogg por `loop`.
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


# --- Música ---------------------------------------------------------------

## Arranca el tema del menú. La carrera llama a `stop_music()`.
func play_music(fade_in: bool = true) -> void:
	if _music_player == null or not _load_music_stream():
		return
	stop_victory()
	if _music_player.playing:
		return
	_music_player.stream = _music_stream
	_music_player.volume_db = MUSIC_SILENT_DB if fade_in else MUSIC_VOLUME_DB
	_music_player.play()
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if fade_in:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", MUSIC_VOLUME_DB, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Para la música con un fundido corto (o en seco, para los tests).
func stop_music(fade_out: bool = true) -> void:
	stop_victory()
	if _music_player == null or not _music_player.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not fade_out:
		_music_player.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", MUSIC_SILENT_DB, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_music_tween.tween_callback(_music_player.stop)


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


## Fanfarria de meta. Suena una sola vez. Tiene bus propio para oírse aunque
## la música esté baja, pero respeta el silencio: con la música a cero no suena.
func play_victory() -> void:
	if _victory_player == null or not _load_victory_stream():
		return
	var music_index := AudioServer.get_bus_index("Music")
	if music_index >= 0 and AudioServer.is_bus_mute(music_index):
		return
	stop_music(false)
	_victory_player.stream = _victory_stream
	_victory_player.volume_db = VICTORY_VOLUME_DB
	_victory_player.play()


func stop_victory() -> void:
	if _victory_player != null and _victory_player.playing:
		_victory_player.stop()


func is_victory_playing() -> bool:
	return _victory_player != null and _victory_player.playing


# --- Efectos ---------------------------------------------------------------

## Reproduce un SFX por clave. `pitch_variance` evita el efecto "metralleta".
func play_sfx(key: String, pitch_variance: float = 0.05, volume_db: float = 0.0) -> void:
	if not _sfx_streams.has(key):
		return
	for player in _sfx_pool:
		if not player.playing:
			_play_on(player, key, pitch_variance, volume_db)
			return
	_play_on(_sfx_pool[0], key, pitch_variance, volume_db)


## SFX posicional: útil para bots y obstáculos, con atenuación por distancia.
func play_sfx_at(key: String, position: Vector3, pitch_variance: float = 0.1, volume_db: float = 0.0) -> void:
	if not _sfx_streams.has(key):
		return
	for player in _sfx_3d_pool:
		if not player.playing:
			player.global_position = position
			player.stream = _sfx_streams[key]
			player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variance, pitch_variance)
			player.volume_db = volume_db
			player.play()
			return
	var fallback := _sfx_3d_pool[0]
	fallback.global_position = position
	fallback.stream = _sfx_streams[key]
	fallback.pitch_scale = 1.0 + _rng.randf_range(-pitch_variance, pitch_variance)
	fallback.volume_db = volume_db
	fallback.play()


## Devuelve el stream de una clave (el viento lo usa para su bucle 3D).
func get_sfx_stream(key: String) -> AudioStream:
	return _sfx_streams.get(key) as AudioStream


func _play_on(player: AudioStreamPlayer, key: String, pitch_variance: float, volume_db: float) -> void:
	player.stream = _sfx_streams[key]
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variance, pitch_variance)
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
