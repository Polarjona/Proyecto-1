extends Area3D

## Puerto de meta: dos torres, un dintel y un cartel de cuadros con META.
## Al cruzarlo avisa al RaceManager y dispara toda la celebración.

@onready var glow: OmniLight3D = $Arch/Glow
@onready var spot_left: SpotLight3D = $Arch/PillarLeft/Spot
@onready var spot_right: SpotLight3D = $Arch/PillarRight/Spot
@onready var confetti: Array[CPUParticles3D] = [
	$ConfettiLeft, $ConfettiRight, $ConfettiBurst,
]

const FIREWORKS := preload("res://scripts/fireworks.gd")

const PARTY_COLORS := [
	Color(0.93, 0.4, 0.45), Color(0.4, 0.72, 0.95), Color(0.96, 0.8, 0.4),
	Color(0.55, 0.85, 0.55), Color(0.8, 0.55, 0.9),
]

var _triggered: bool = false
var _time: float = 0.0
var _balloons: Array[Node3D] = []
var _balloon_base: Array[float] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Los focos apuntan al centro de la meta, que es el origen de la escena.
	var target := global_position + Vector3(0.0, 1.0, 0.0)
	for light in [spot_left, spot_right]:
		if light != null:
			light.look_at(target, Vector3.UP)
	_build_celebration()


## Globos y banderines alrededor del arco: la celebración llega a todas las
## metas del juego sin tener que decorar cada circuito por separado.
func _build_celebration() -> void:
	for i in 12:
		var side := -1.0 if i % 2 == 0 else 1.0
		var balloon := Node3D.new()
		balloon.name = "Balloon%d" % i
		balloon.position = Vector3(side * (6.1 + float(i % 3) * 0.85),
			4.2 + float(i % 4) * 0.75, -1.7 + float(i % 3) * 1.5)
		var balloon_material := StandardMaterial3D.new()
		balloon_material.albedo_color = PARTY_COLORS[i % PARTY_COLORS.size()]
		balloon_material.roughness = 0.35
		var sphere := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.3
		sphere_mesh.height = 0.75
		sphere_mesh.radial_segments = 12
		sphere_mesh.rings = 6
		sphere.mesh = sphere_mesh
		sphere.material_override = balloon_material
		sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		balloon.add_child(sphere)
		var string := MeshInstance3D.new()
		var string_mesh := BoxMesh.new()
		string_mesh.size = Vector3(0.02, 1.4, 0.02)
		string.mesh = string_mesh
		string.position = Vector3(0.0, -0.95, 0.0)
		string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		balloon.add_child(string)
		add_child(balloon)
		_balloons.append(balloon)
		_balloon_base.append(balloon.position.y)

	for i in 16:
		var flag := MeshInstance3D.new()
		flag.name = "Pennant%d" % i
		var flag_mesh := BoxMesh.new()
		flag_mesh.size = Vector3(0.42, 0.28, 0.03)
		flag.mesh = flag_mesh
		var flag_material := StandardMaterial3D.new()
		flag_material.albedo_color = PARTY_COLORS[i % PARTY_COLORS.size()]
		flag_material.roughness = 0.5
		flag.material_override = flag_material
		var t := float(i) / 15.0
		flag.position = Vector3(lerpf(-6.4, 6.4, t),
			5.85 - absf(t - 0.5) * 0.7, 0.5)
		flag.rotation_degrees = Vector3(0.0, 0.0, 45.0 if i % 2 == 0 else -45.0)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flag)


func _process(delta: float) -> void:
	_time += delta
	for i in _balloons.size():
		if is_instance_valid(_balloons[i]):
			_balloons[i].position.y = _balloon_base[i] + sin(_time * 1.3 + float(i)) * 0.14
	var pulse := 0.85 + sin(_time * 2.0) * 0.15
	if glow != null:
		glow.light_energy = 1.2 * pulse
	if spot_left != null:
		spot_left.light_energy = 2.2 * pulse
	if spot_right != null:
		spot_right.light_energy = 2.2 * pulse


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
	_launch_fireworks()


## Fuegos artificiales sobre la meta. Se crean aquí para que los tenga cualquier
## circuito, incluidos los que genera `level_builder.gd`.
func _launch_fireworks() -> void:
	var fireworks := FIREWORKS.new() as Node3D
	if fireworks == null:
		return
	fireworks.name = "Fireworks"
	get_parent().add_child(fireworks)
	fireworks.global_position = global_position + Vector3(0.0, 1.5, 0.0)
	fireworks.call("celebrate")
