extends Node3D

## Primer tramo guiado: tres flechas 3D delante de la salida y un aviso en el
## HUD. Solo se usa en Pivot Push, el circuito de la primera partida; el panel
## de texto sigue explicando los controles y esto enseña hacia dónde correr.

const FIRST_DISTANCE := 8.0

const STEP_GAP := 9.0

const PASS_MARGIN := 2.0

var player: Node3D

var _arrows: Array[Node3D] = []

var _step: int = 0

var _forward: float = -1.0


func setup(target: Node3D, info: LevelInfo) -> void:
	player = target
	if info != null:
		_forward = -1.0 if info.finish_z < info.start_z else 1.0


func start() -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	global_position = player.global_position
	var words := [tr("CORRE"), tr("SALTA"), tr("SIGUE")]
	for i in words.size():
		var arrow := _make_arrow(words[i])
		arrow.position = Vector3(0.0, 2.2, _forward * (FIRST_DISTANCE + STEP_GAP * i))
		add_child(arrow)
		_arrows.append(arrow)
	_show_prompt("Corre hacia la flecha")


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_clear_prompt()
		queue_free()
		return
	for i in _arrows.size():
		var arrow := _arrows[i]
		if arrow.visible:
			arrow.position.y = 2.2 + sin(Time.get_ticks_msec() * 0.004 + i) * 0.12
	if _step >= _arrows.size():
		_clear_prompt()
		queue_free()
		return
	var arrow := _arrows[_step]
	var passed := (player.global_position.z - arrow.global_position.z) * _forward
	if passed < PASS_MARGIN:
		return
	arrow.hide()
	_step += 1
	match _step:
		1:
			_show_prompt("Salta para superar el obstáculo")
		2:
			_show_prompt("Sigue el circuito hasta la meta")
		_:
			_clear_prompt()
			queue_free()


func _make_arrow(text: String) -> Node3D:
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.38
	cone.height = 1.2
	cone.radial_segments = 12
	mesh_instance.mesh = cone
	mesh_instance.rotation.x = PI / 2.0 * _forward
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.88, 0.18)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.72, 0.08)
	material.emission_energy_multiplier = 1.3
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.outline_size = 12
	label.modulate = Color(1.0, 0.95, 0.45)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 1.15
	root.add_child(label)
	return root


func _show_prompt(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_tutorial_prompt"):
		hud.call("show_tutorial_prompt", text)


func _clear_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("clear_tutorial_prompt"):
		hud.call("clear_tutorial_prompt")
