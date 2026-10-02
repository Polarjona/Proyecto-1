extends Node

## Autoload singleton: background music + SFX playback.
## Missing audio files are skipped gracefully so the game never breaks.

const MUSIC_PATH := "res://audio/music/background.ogg"
const SFX_PATHS := {
	"jump": "res://audio/sfx/jump.wav",
	"checkpoint": "res://audio/sfx/checkpoint.wav",
	"finish": "res://audio/sfx/finish.wav",
	"fall": "res://audio/sfx/fall.wav",
}

const SFX_POOL_SIZE := 6

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_music()
	_setup_sfx_pool()
	_load_sfx_streams()
	_play_music()


func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	_music_player.volume_db = -8.0
	add_child(_music_player)


func _setup_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		player.bus = "Master"
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


## Force looping at runtime so it works regardless of the import settings:
## .ogg through `loop`, .wav through `loop_mode`.
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


## Play a sound effect by key: "jump", "checkpoint", "finish" or "fall".
func play_sfx(key: String) -> void:
	if not _sfx_streams.has(key):
		return
	for player in _sfx_pool:
		if not player.playing:
			player.stream = _sfx_streams[key]
			player.play()
			return
	# All busy: steal the first player.
	_sfx_pool[0].stream = _sfx_streams[key]
	_sfx_pool[0].play()
