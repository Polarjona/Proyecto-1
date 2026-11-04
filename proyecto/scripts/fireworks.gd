extends Node3D

## Fuegos artificiales de meta: cinco explosiones de chispas de colores con su
## destello de luz y su boom. Lo lanza `finish_line.gd` al cruzar la meta, así
## que todos los circuitos los tienen sin tocar cada escena.

const COLORS := [
	Color(1.0, 0.86, 0.3), Color(1.0, 0.45, 0.65), Color(0.45, 0.85, 1.0),
	Color(0.6, 1.0, 0.55), Color(0.85, 0.6, 1.0),
]
const BURST_COUNT := 5
const BURST_DELAY := 0.42

var _bursts: Array[CPUParticles3D] = []
var _lights: Array[OmniLight3D] = []
var _time: float = 0.0
var _next_burst: float = 0.0
var _launched: int = 0


func _ready() -> void:
	set_process(false)
	_build_bursts()


## Arranca la traca. Se llama después de añadir el nodo al árbol.
func celebrate() -> void:
	_time = 0.0
	_next_burst = 0.0
	_launched = 0
	set_process(true)


func _build_bursts() -> void:
	for i in BURST_COUNT:
		var color: Color = COLORS[i % COLORS.size()]
		var spark := SphereMesh.new()
		spark.radius = 0.09
		spark.height = 0.18
		spark.radial_segments = 6
		spark.rings = 3
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
		spark.material = material

		var burst := CPUParticles3D.new()
		burst.name = "Burst%d" % i
		burst.emitting = false
		burst.amount = 120
		burst.lifetime = 1.9
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.local_coords = false
		burst.direction = Vector3(0.0, 0.15, 0.0)
		burst.spread = 180.0
		burst.gravity = Vector3(0.0, -7.5, 0.0)
		burst.initial_velocity_min = 6.0
		burst.initial_velocity_max = 13.0
		burst.damping_min = 1.1
		burst.damping_max = 2.2
		burst.scale_amount_min = 0.5
		burst.scale_amount_max = 1.6
		burst.mesh = spark
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(burst)
		_bursts.append(burst)

		var light := OmniLight3D.new()
		light.name = "BurstLight%d" % i
		light.light_color = color
		light.light_energy = 0.0
		light.omni_range = 20.0
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)


func _process(delta: float) -> void:
	_time += delta
	if _launched < _bursts.size() and _time >= _next_burst:
		_launch(_launched)
		_launched += 1
		_next_burst = _time + BURST_DELAY
	for light in _lights:
		light.light_energy = maxf(0.0, light.light_energy - delta * 11.0)
	if _launched >= _bursts.size() and _time > _next_burst + 2.4:
		set_process(false)
		queue_free()


func _launch(index: int) -> void:
	var angle := float(index) * 1.7
	var offset := Vector3(cos(angle) * 3.6, 2.4 + float(index % 3) * 1.5, sin(angle) * 2.4)
	var burst := _bursts[index]
	burst.position = offset
	burst.restart()
	var light := _lights[index]
	light.position = offset
	light.light_energy = 4.5
	AudioManager.play_sfx("cannon", 0.85 + float(index) * 0.07, -3.0)
