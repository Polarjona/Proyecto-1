class_name ShaderWarmup
extends Node

## Templa los shaders de los obstáculos antes de la primera carrera.
##
## Godot compila un material la primera vez que lo dibuja; si eso pasa cuando el
## obstáculo entra en cámara, el tirón se nota. Aquí se instancian una vez todos
## los obstáculos dentro de un `SubViewport` diminuto, se dejan tres frames para
## que el renderizador los dibuje y se liberan. El menú lo añade al arrancar, así
## que los materiales ya están compilados cuando empieza la cuenta atrás.
##
## No toca la carrera: vive en su propio viewport y desaparece en tres frames.

const OBSTACLES := [
	"res://scenes/obstacles/ball.tscn",
	"res://scenes/obstacles/ball_dropper.tscn",
	"res://scenes/obstacles/bounce_pad.tscn",
	"res://scenes/obstacles/boulder.tscn",
	"res://scenes/obstacles/conveyor.tscn",
	"res://scenes/obstacles/crumble_tile.tscn",
	"res://scenes/obstacles/launcher.tscn",
	"res://scenes/obstacles/moving_platform.tscn",
	"res://scenes/obstacles/pendulum.tscn",
	"res://scenes/obstacles/piston.tscn",
	"res://scenes/obstacles/rotor_gate.tscn",
	"res://scenes/obstacles/see_saw.tscn",
	"res://scenes/obstacles/spike_trap.tscn",
	"res://scenes/obstacles/spinning_platform.tscn",
	"res://scenes/obstacles/sweeper.tscn",
	"res://scenes/obstacles/wall.tscn",
	"res://scenes/obstacles/wind_tunnel.tscn",
]

const FRAMES := 3


func _ready() -> void:
	_warm_up()


func _warm_up() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 6.0)
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	viewport.add_child(light)

	var stage := Node3D.new()
	viewport.add_child(stage)
	for path in OBSTACLES:
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		stage.add_child(packed.instantiate())

	for i in FRAMES:
		await get_tree().process_frame
	queue_free()
