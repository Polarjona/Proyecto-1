extends CharacterBody3D

## Bot racer: follows a hand-tuned waypoint path over the real course.
## Improvements over the first version:
## - every bot keeps its own lane, so the pack spreads instead of overlapping;
## - a ground probe makes it jump at real ledges instead of relying only on
##   hard-coded waypoint jumps;
## - it times the rotating sweepers and waits for the pendulums;
## - it steers away from falling balls and from other bots;
## - progress is tracked towards the next waypoint, so a bot that is shoved
##   sideways gets rescued instead of running in circles.

signal finished(bot: Node3D, time: float)

const COLORS := [
	Color(0.95, 0.4, 0.55),
	Color(0.35, 0.75, 1.0),
	Color(0.55, 0.95, 0.45),
	Color(0.95, 0.7, 0.3),
	Color(0.7, 0.5, 1.0),
	Color(0.95, 0.55, 0.9),
	Color(0.4, 0.95, 0.85),
	Color(1.0, 0.85, 0.6),
]

## Centre line of the course, matching `scenes/main.tscn` section by section.
const WAYPOINTS: Array[Vector3] = [
	Vector3(0.0, 0.2, 1.0),
	Vector3(0.0, 0.2, -4.0),
	Vector3(0.0, 0.2, -12.0),
	Vector3(0.0, 0.2, -20.0),
	Vector3(0.0, 0.2, -25.0),
	Vector3(0.0, 0.2, -33.0),
	Vector3(0.0, 0.2, -41.0),
	Vector3(0.0, 0.13, -47.0),
	Vector3(0.0, 0.13, -50.6),
	Vector3(0.0, 0.13, -55.0),
	Vector3(0.0, 0.2, -62.0),
	Vector3(0.0, 0.2, -70.0),
	Vector3(0.0, 0.2, -80.0),
	Vector3(0.0, 0.2, -88.0),
	Vector3(0.0, 0.2, -94.0),
	Vector3(0.0, 0.14, -97.5),
	Vector3(0.0, 0.14, -101.0),
	Vector3(0.0, 0.7, -112.0),
	Vector3(0.0, 0.7, -115.5),
	Vector3(0.0, 0.7, -119.0),
	Vector3(0.0, 0.7, -126.0),
	Vector3(0.0, 0.7, -139.5),
	Vector3(0.0, 1.1, -152.0),
	Vector3(0.0, 1.1, -160.0),
	Vector3(0.0, 2.2, -168.0),
	Vector3(0.0, 3.4, -177.0),
	Vector3(0.0, 1.1, -186.0),
	Vector3(0.0, 1.1, -190.0),
	Vector3(0.0, 1.1, -194.0),
	Vector3(0.0, 4.2, -206.0),
	Vector3(0.0, 4.2, -209.0),
]

## Maximum lateral distance from the centre line at each waypoint. Narrow
## bridges get almost none, open halls get room for the pack to spread.
const LANE_HALF_WIDTH: Array[float] = [
	3.2, 3.2, 2.0, 2.0, 1.5, 2.4, 2.0, 1.6, 0.4, 1.6, 2.2, 0.5, 0.4, 0.5,
	1.2, 0.4, 0.4, 2.2, 0.3, 0.3, 0.3, 0.5, 2.4, 2.0, 1.1, 0.8, 1.6, 1.6, 0.3, 2.6, 2.6,
]

@export var speed_min: float = 4.8
@export var speed_max: float = 6.4
@export var speed_scale: float = 1.0
@export var finish_z: float = -209.0
@export var respawn_below_y: float = -5.0
@export var body_color: Color = Color(0.95, 0.4, 0.55)
@export var jump_velocity: float = 6.2
@export var look_ahead: float = 1.8

var _index: int = 0
var _speed: float = 5.5
var _lane: float = 0.0
var _finished: bool = false
var _stumble_time: float = 0.0
var _stumble_cooldown: float = 0.0
var _start_ms: int = 0
var _jump_cooldown: float = 0.0
var _jump_request: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _external: Vector3 = Vector3.ZERO
var _best_distance: float = 9999.0
var _progress_time: float = 0.0
## Once a bot sees a safe gap in a sweeper/pendulum it commits to crossing.
var _sweeper_commits: Dictionary = {}
var _pendulum_commits: Dictionary = {}
var _rescue_count: int = 0
var _was_on_floor: bool = true
var _step_timer: float = 0.0
## Personaje aleatorio asignado al bot (expuesto para tests).
var character_id: String = ""
## Bots hold at the line until the countdown ends, like the player.
var _waiting_for_start: bool = true
var _wait_elapsed: float = 0.0
var _anim: AnimationPlayer

@onready var body: MeshInstance3D = $Body


func _ready() -> void:
	add_to_group("bot")
	add_to_group("bots")
	_start_ms = Time.get_ticks_msec()
	_speed = randf_range(speed_min, speed_max) * speed_scale
	# Keep bots off the exact centre line: that is where the sweeper bars and
	# pendulum heads are most dangerous. The sign gives each bot a side.
	_lane = randf_range(0.55, 1.0) * (-1.0 if randf() < 0.5 else 1.0)
	_stumble_cooldown = randf_range(6.0, 12.0)
	_setup_model()


## Elige un personaje al azar del catálogo (los cinco del pack), lo instancia
## con su escala y esconde las armas. Cada bot tiene su propio AnimationPlayer.
func _setup_model() -> void:
	# `randf()` (y no `randi()`) para no cambiar la secuencia aleatoria que ya
	# usan los carriles, las velocidades y los tropiezos de los bots.
	var index := mini(int(randf() * float(CharacterCatalog.CHARACTERS.size())), CharacterCatalog.CHARACTERS.size() - 1)
	character_id = String(CharacterCatalog.CHARACTERS[index]["id"])
	var model := CharacterCatalog.build_model(character_id, "Model")
	if model == null:
		return
	model.scale *= randf_range(0.95, 1.05)
	body.add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for clip_name in ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Cheer", "Jump_Land"]:
			var clip := _anim.get_animation(clip_name)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
		_play_anim("Idle", 0.0)


func _play_anim(clip: String, blend: float = 0.15) -> void:
	if _anim == null or _anim.current_animation == clip:
		return
	_anim.play(clip, blend)
	_anim.speed_scale = 1.2 if clip == "Running_A" else 1.0


func _update_animation(walking: bool) -> void:
	var clip := "Idle"
	if _stumble_time > 0.0:
		clip = "Hit_A"
	elif not is_on_floor():
		clip = "Jump_Idle"
	elif walking:
		clip = "Running_A"
	_play_anim(clip)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	if _waiting_for_start and not _wait_for_start(delta):
		return
	if global_position.y < respawn_below_y:
		_rescue()

	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_jump_request = maxf(0.0, _jump_request - delta)
	_tick_stumble(delta)

	var target := _target_position()
	var to_target := target - global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	if flat.length() < 1.25:
		_advance_waypoint()
		if _finished:
			return
		target = _target_position()
		to_target = target - global_position
		flat = Vector3(to_target.x, 0.0, to_target.z)

	var direction := flat.normalized() if flat.length_squared() > 0.001 else Vector3(0.0, 0.0, -1.0)
	direction = (direction + _avoidance() * 0.7).limit_length(1.0)

	var holding := _should_hold()
	if holding:
		_play_anim("Idle")

	# Real ledges get a jump even if the waypoint table missed one.
	if not holding and is_on_floor() and _jump_cooldown <= 0.0 and _jump_request <= 0.0:
		# Do not jump into the cannon: the driver must run through its trigger.
		if not _near_cannon() and not _ground_ahead(direction):
			_jump_request = 0.3

	var walk_speed := 0.0 if holding or _stumble_time > 0.0 else _speed
	velocity.x = direction.x * walk_speed + _knockback.x + _external.x
	velocity.z = direction.z * walk_speed + _knockback.z + _external.z
	velocity.y += _external.y
	_external = Vector3.ZERO
	_knockback = _knockback.move_toward(Vector3.ZERO, 10.0 * delta)

	if not is_on_floor():
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		velocity.y -= gravity * 1.15 * delta
	elif _jump_request > 0.0 and _jump_cooldown <= 0.0:
		velocity.y = jump_velocity
		_jump_request = 0.0
		_jump_cooldown = 0.45
		_play_anim("Jump_Idle", 0.08)
		AudioManager.play_sfx_at("jump", global_position, 0.14, -11.0)

	move_and_slide()
	_face(direction, delta)
	_update_animation(walk_speed > 0.0 and is_on_floor())
	_update_audio(delta)
	_tick_progress(delta, flat.length(), holding)
	if global_position.z <= finish_z:
		_finish()


## Pasos y aterrizajes de los bots: posicionales, con volumen bajo, para que
## la carrera suene viva sin tapar la música del menú ni los SFX del jugador.
func _update_audio(delta: float) -> void:
	var grounded := is_on_floor()
	if grounded and not _was_on_floor and _stumble_time <= 0.0:
		AudioManager.play_sfx_at("land", global_position, 0.18, -12.0)
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if grounded and speed > 1.0 and _stumble_time <= 0.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = clampf(0.46 - speed * 0.025, 0.22, 0.4)
			AudioManager.play_sfx_at("step", global_position, 0.22, -15.0)
	else:
		_step_timer = 0.0
	_was_on_floor = grounded


func _near_cannon() -> bool:
	for launcher in get_tree().get_nodes_in_group("launchers"):
		if not (launcher is Node3D) or not is_instance_valid(launcher):
			continue
		var delta: Vector3 = (launcher as Node3D).global_position - global_position
		if delta.z < 2.5 and delta.z > -4.5 and absf(delta.x) < 3.0:
			return true
	return false


func _target_position() -> Vector3:
	var index := mini(_index, WAYPOINTS.size() - 1)
	var width: float = LANE_HALF_WIDTH[index]
	return WAYPOINTS[index] + Vector3(_lane * width, 0.0, 0.0)


func _advance_waypoint() -> void:
	_index += 1
	if _index >= WAYPOINTS.size():
		_finish()
		return
	_best_distance = 9999.0
	_progress_time = 0.0


func _tick_stumble(delta: float) -> void:
	if _stumble_time > 0.0:
		_stumble_time = maxf(0.0, _stumble_time - delta)
	_stumble_cooldown -= delta
	if _stumble_cooldown > 0.0:
		return
	_stumble_cooldown = randf_range(8.0, 16.0)
	# Bots are allowed the occasional stumble, but no longer stop every few
	# seconds for no reason.
	if randf() < 0.35:
		_stumble_time = randf_range(0.15, 0.35)


## Returns true once the race is running. Until then the bot just stands on
## the floor (gravity still applies) and its clock has not started.
func _wait_for_start(delta: float) -> bool:
	_wait_elapsed += delta
	var manager := get_tree().get_first_node_in_group("race_manager")
	var running := false
	if manager == null:
		# Standalone scene (tests, preview): do not wait forever for a manager.
		running = _wait_elapsed > 0.5
	elif "is_running" in manager:
		running = bool(manager.get("is_running"))
	else:
		running = true
	if running:
		_waiting_for_start = false
		_start_ms = Time.get_ticks_msec()
		return true
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		velocity.y -= gravity * 1.15 * delta
	move_and_slide()
	return false


## Lateral steering away from falling balls, plus a hard correction back to
## the safe corridor if a hazard has already pushed the bot outwards.
func _avoidance() -> Vector3:
	var avoid := Vector3.ZERO

	for ball in get_tree().get_nodes_in_group("hazard_balls"):
		if not (ball is Node3D) or not is_instance_valid(ball):
			continue
		var delta: Vector3 = (ball as Node3D).global_position - global_position
		if delta.z > 1.5 or delta.z < -4.5 or absf(delta.x) > 3.0:
			continue
		var side := signf(global_position.x - (ball as Node3D).global_position.x)
		if absf(side) < 0.1:
			side = 1.0 if _lane >= 0.0 else -1.0
		var urgency := 1.0 - clampf(Vector2(delta.x, delta.z).length() / 5.0, 0.0, 1.0)
		avoid.x += side * (0.8 + urgency * 1.6)

	var corridor: float = LANE_HALF_WIDTH[mini(_index, WAYPOINTS.size() - 1)]
	if absf(global_position.x) > corridor + 0.8:
		avoid.x += -signf(global_position.x) * 2.0

	if avoid.length_squared() > 2.25:
		avoid = avoid.normalized() * 1.5
	return avoid


## Holds the bot before a sweeper bar that is currently blocking the path, or
## before a pendulum that is hanging vertically in the middle.
func _should_hold() -> bool:
	if not is_on_floor() or _jump_request > 0.0:
		return false

	# Ride moving platforms instead of running off their front edge, and wait
	# at the boarding edge until the platform is close enough.
	for platform in get_tree().get_nodes_in_group("moving_platforms"):
		if not (platform is Node3D) or not is_instance_valid(platform):
			continue
		var delta: Vector3 = (platform as Node3D).global_position - global_position
		if absf(delta.x) > 2.5 or delta.z > 0.5 or delta.z < -14.0:
			continue
		var progress := float((platform as Node3D).call("get_progress"))
		var riding := absf(delta.z) < 2.4 and absf(delta.y) < 1.3 and absf(delta.x) < 2.4
		if riding and progress < 0.85:
			return true
		# The extra edge waypoints mean the bot only has a short hop left;
		# waiting for the platform to come near is enough. It then rides it to
		# the far end instead of running off the front.
		if not riding and delta.z < -1.2 and progress > 0.15:
			return true

	# Queue before the cannon while it is on cooldown; otherwise six bots
	# would follow the first one straight into the gap.
	for launcher in get_tree().get_nodes_in_group("launchers"):
		if not (launcher is Node3D) or not is_instance_valid(launcher):
			continue
		var delta: Vector3 = (launcher as Node3D).global_position - global_position
		if delta.z > -0.5 or delta.z < -3.5:
			continue
		if not bool((launcher as Node3D).call("is_ready")):
			return true

	for sweeper in get_tree().get_nodes_in_group("sweepers"):
		if not (sweeper is Node3D) or not is_instance_valid(sweeper):
			continue
		var delta: Vector3 = (sweeper as Node3D).global_position - global_position
		var id := (sweeper as Node3D).get_instance_id()
		if delta.z > 1.5 or delta.z < -7.0 or absf(delta.x) > 5.0:
			_sweeper_commits.erase(id)
			continue
		if delta.z > -0.6:
			# Already at the bar: never stop in the middle of it.
			_sweeper_commits[id] = true
			continue
		if bool(_sweeper_commits.get(id, false)):
			continue
		var bar := (sweeper as Node3D).get_node_or_null("Bar") as Node3D
		if bar != null and absf(cos(bar.rotation.y)) > 0.3:
			return true
		_sweeper_commits[id] = true

	for pendulum in get_tree().get_nodes_in_group("pendulums"):
		if not (pendulum is Node3D) or not is_instance_valid(pendulum):
			continue
		var delta: Vector3 = (pendulum as Node3D).global_position - global_position
		var id := (pendulum as Node3D).get_instance_id()
		if delta.z > 1.5 or delta.z < -5.5:
			_pendulum_commits.erase(id)
			continue
		if delta.z > -0.5:
			_pendulum_commits[id] = true
			continue
		if bool(_pendulum_commits.get(id, false)):
			continue
		var hammer := (pendulum as Node3D).get_node_or_null("Hammer") as Node3D
		if hammer != null and absf(hammer.rotation.z) < 0.45:
			return true
		_pendulum_commits[id] = true
	return false


## True when there is still floor under the next step. If not, the bot is at
## a real ledge and should jump.
func _ground_ahead(direction: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var forward := Vector3(direction.x, 0.0, direction.z)
	if forward.length_squared() < 0.001:
		forward = Vector3(0.0, 0.0, -1.0)
	forward = forward.normalized()
	var origin := global_position + Vector3.UP * 0.45 + forward * look_ahead
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 2.6, 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)
	var wobble := sin(Time.get_ticks_msec() * 0.02) * 0.18 if _stumble_time > 0.0 else 0.0
	rotation.z = lerp_angle(rotation.z, wobble, 8.0 * delta)


## A bot that keeps moving sideways but never gets closer to its waypoint is
## just as stuck as one standing still: rescue both.
func _tick_progress(delta: float, distance: float, holding: bool) -> void:
	if holding:
		# Waiting for a platform, sweeper or pendulum is intentional; do not
		# count it as being stuck.
		_progress_time = 0.0
		_best_distance = minf(_best_distance, distance)
		return
	_progress_time += delta
	if distance < _best_distance - 0.3:
		_best_distance = distance
		_progress_time = 0.0
	elif _progress_time > 6.0:
		_rescue()
		_progress_time = 0.0


func _rescue() -> void:
	_rescue_count += 1
	print("BOT RESCUE id=%d from=%s wp=%d" % [get_instance_id(), global_position, _index])
	var target := _target_position()
	global_position = target + Vector3(randf_range(-0.5, 0.5), 0.7, 0.0)
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_external = Vector3.ZERO
	_jump_request = 0.0
	_best_distance = 9999.0
	_progress_time = 0.0
	_sweeper_commits.clear()
	_pendulum_commits.clear()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	_play_anim("Cheer", 0.2)
	var elapsed := float(Time.get_ticks_msec() - _start_ms) / 1000.0
	finished.emit(self, elapsed)


## Hazards can shove bots too (sweeper, pendulum, balls).
func apply_push(force: Vector3) -> void:
	# Bots are a little sturdier than the player: without air steering a full
	# pendulum hit throws them straight off the narrow bridge.
	_knockback += Vector3(force.x, 0.0, force.z).limit_length(6.0)
	velocity.y = maxf(velocity.y, force.y)
	_stumble_time = maxf(_stumble_time, 0.25)


## Trampoline launch. Kept explicit so the bot cancels any pending ledge
## jump instead of immediately re-requesting one.
func bounce(strength: float) -> void:
	velocity.y = strength
	_jump_request = 0.0
	_jump_cooldown = 0.6


func launch(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)
	_stumble_time = maxf(_stumble_time, 0.2)


## Light shove used by the first sweeper: no stumble, just knockback.
func apply_push_soft(force: Vector3) -> void:
	_knockback += Vector3(force.x, 0.0, force.z)
	velocity.y = maxf(velocity.y, force.y)


func add_external_velocity(velocity_delta: Vector3) -> void:
	# Bots resist wind and belts a little so their path stays viable. Lateral
	# wind is ignored: they have no dedicated wind compensation and would be
	# blown off the narrow bridge every single time.
	_external += Vector3(0.0, velocity_delta.y, velocity_delta.z) * 0.4


## Deslizamiento del balancín: se aplica entero, como al jugador, para que la
## tabla volcada no sea un obstáculo que solo sufre el humano.
func add_slide_velocity(push: Vector3) -> void:
	_external += push


func add_belt_velocity(belt: Vector3) -> void:
	# Same resistance as wind, so a reverse belt never traps them forever.
	_external += belt * 0.4


func is_stunned() -> bool:
	return _stumble_time > 0.0


func is_prone() -> bool:
	return false


## Exposed for diagnostics/tests.
func get_lane() -> float:
	return _lane


func get_waypoint_index() -> int:
	return _index


## Number of times the watchdog had to put the bot back on the course.
func get_rescue_count() -> int:
	return _rescue_count
