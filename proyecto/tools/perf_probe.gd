extends SceneTree

## Sonda de rendimiento: carga Pivot Push, deja que la carrera corra y mide el
## coste por frame (proceso y física) y los FPS que reporta el motor.
##
## Uso:
##   godot --path . -s res://tools/perf_probe.gd             # con ventana: FPS reales
##   godot --headless --path . -s res://tools/perf_probe.gd  # solo coste de CPU
##
## Imprime una línea `RESULT:` con los milisegundos medios y el peor frame, para
## comparar antes/después de un cambio de rendimiento.

const LEVEL := LevelPaths.PIVOT_PUSH

const WARMUP_FRAMES := 120

const SAMPLE_FRAMES := 600


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in WARMUP_FRAMES:
		await process_frame

	var process_ms := 0.0
	var process_max := 0.0
	var physics_ms := 0.0
	var fps_total := 0.0
	for i in SAMPLE_FRAMES:
		await process_frame
		var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		process_ms += frame_ms
		process_max = maxf(process_max, frame_ms)
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		fps_total += Performance.get_monitor(Performance.TIME_FPS)

	process_ms /= SAMPLE_FRAMES
	physics_ms /= SAMPLE_FRAMES
	fps_total /= SAMPLE_FRAMES
	print(
		(
			"RESULT: proceso %.2f ms (peor %.2f), fisica %.2f ms, FPS %.1f"
			% [process_ms, process_max, physics_ms, fps_total]
		)
	)
	quit()
