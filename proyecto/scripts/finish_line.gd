extends Area3D

## Puerto de meta: dos torres, un dintel y un cartel de cuadros con META.
## Al cruzarlo avisa al RaceManager y dispara toda la celebración.

@onready var glow: OmniLight3D = $Arch/Glow
@onready var spot_left: SpotLight3D = $Arch/PillarLeft/Spot
@onready var spot_right: SpotLight3D = $Arch/PillarRight/Spot
@onready var confetti: Array[CPUParticles3D] = [
	$ConfettiLeft, $ConfettiRight, $ConfettiBurst,
]

var _triggered: bool = false
var _time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Los focos apuntan al centro de la meta, que es el origen de la escena.
	var target := global_position + Vector3(0.0, 1.0, 0.0)
	for light in [spot_left, spot_right]:
		if light != null:
			light.look_at(target, Vector3.UP)


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.85 + sin(_time * 2.0) * 0.15
	if glow != null:
		glow.light_energy = 1.9 * pulse
	if spot_left != null:
		spot_left.light_energy = 5.0 * pulse
	if spot_right != null:
		spot_right.light_energy = 5.0 * pulse


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager and manager.has_method("finish_race"):
		_triggered = true
		manager.finish_race()
		_play_feedback()


func _play_feedback() -> void:
	AudioManager.play_sfx("finish")
	for particles in confetti:
		if particles != null:
			particles.restart()
	GameFeel.shake(2.0)
	GameFeel.flash(Color(1.0, 0.9, 0.35), 0.2)
