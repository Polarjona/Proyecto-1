extends CharacterBody3D

## Bot racer: follows a hand-tuned waypoint path over the real course,
## jumps the gaps, stumbles sometimes and always finishes thanks to a
## watchdog that rescues it when it gets stuck or falls.

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
	Vector3(0.0, 0.14, -101.0),
	Vector3(0.0, 0.7, -112.0),
	Vector3(0.0, 0.7, -119.0),
	Vector3(0.0, 0.7, -126.0),
	Vector3(0.0, 0.7, -139.5),
	Vector3(0.0, 1.1, -152.0),
	Vector3(0.0, 1.1, -160.0),
	Vector3(0.0, 1.1, -168.0),
	Vector3(0.0, 1.1, -177.0),
	Vector3(0.0, 1.1, -186.0),
	Vector3(0.0, 1.1, -194.0),
	Vector3(0.0, 4.2, -206.0),
	Vector3(0.0, 4.2, -209.0),
]

## Jump velocity to use when a waypoint is reached (key = waypoint index).
## Only the gaps of the course need one; everything else is a plain walk.
const JUMPS := {
	1: 6.0,
	4: 6.0,
	6: 6.5,
	9: 6.5,
	10: 6.0,
	13: 5.5,
	14: 5.5,
	15: 5.5,
	16: 5.5,
	17: 5.5,
	20: 5.0,
	23: 5.5,
}

@export var speed_min: float = 4.8
@export var speed_max: float = 6.4
@export var speed_scale: float = 1.0
@export var finish_z: float = -209.0
@export var respawn_below_y: float = -5.0
@export var body_color: Color = Color(0.95, 0.4, 0.55)

var _index: int = 0
var _speed: float = 5.5
var _finished: bool = false
var _stumble_time: float = 0.0
var _stumble_cooldown: float = 0.0
var _start_ms: int = 0
var _pending_jump: float = 0.0
var _jump_cooldown: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _external: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0
var _watch_position: Vector3 = Vector3.ZERO
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
	_stumble_cooldown = randf_range(1.5, 4.0)
	_watch_position = global_position
	_setup_model()


## Picks one of the downloaded adventurers, hides its weapons and starts the
## idle clip. Bots keep their own AnimationPlayer, independent of the player.
func _setup_model() -> void:
	var knight := body.get_node_or_null("Knight") as Node3D
	var mage := body.get_node_or_null("Mage") as Node3D
	var use_knight := randf() < 0.5
	if knight:
		knight.visible = use_knight
	if mage:
		mage.visible = not use_knight
	var model: Node3D = knight if use_knight else mage
	if model == null:
		return
	for part in ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable", "Knight_Cape", "Mage_Cape", "2H_Staff", "1H_Wand", "Spellbook", "Spellbook_open"]:
		var accessory := model.find_child(part, true, false)
		if accessory is Node3D:
			(accessory as Node3D).visible = false
	model.scale *= randf_range(0.96, 1.04)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for clip_name in ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Cheer"]:
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
	_stumble_cooldown -= delta
	if _stumble_cooldown <= 0.0:
		_stumble_cooldown = randf_range(2.5, 5.5)
		_stumble_time = randf_range(0.25, 0.7)

	_tick_stuck(delta)

	var walking := _stumble_time <= 0.0
	if _stumble_time > 0.0:
		_stumble_time -= delta

	var target: Vector3 = WAYPOINTS[_index]
	var to_target := target - global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)

	if flat.length() < 1.25:
		_index += 1
		if _index >= WAYPOINTS.size():
			_finish()
			return
		_on_new_waypoint()
		target = WAYPOINTS[_index]
		to_target = target - global_position
		flat = Vector3(to_target.x, 0.0, to_target.z)

	var direction := flat.normalized() if flat.length_squared() > 0.001 else Vector3.ZERO
	var walk_speed := _speed
	if not walking:
		walk_speed = 0.0

	velocity.x = direction.x * walk_speed + _knockback.x + _external.x
	velocity.z = direction.z * walk_speed + _knockback.z + _external.z
	velocity.y += _external.y
	_external = Vector3.ZERO
	_knockback = _knockback.move_toward(Vector3.ZERO, 10.0 * delta)

	if not is_on_floor():
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		velocity.y -= gravity * 1.15 * delta
	elif _pending_jump > 0.0 and _jump_cooldown <= 0.0:
		velocity.y = _pending_jump
		_pending_jump = 0.0
		_jump_cooldown = 0.4

	move_and_slide()
	_face(direction, delta)
	_update_animation(walk_speed > 0.0)
	if global_position.z <= finish_z:
		_finish()


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
		_watch_position = global_position
		return true
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		velocity.y -= gravity * 1.15 * delta
	move_and_slide()
	return false


func _on_new_waypoint() -> void:
	# The course gaps are listed in JUMPS so the path stays data, not code.
	if JUMPS.has(_index):
		_pending_jump = float(JUMPS[_index])


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)
	var wobble := sin(Time.get_ticks_msec() * 0.02) * 0.18 if _stumble_time > 0.0 else 0.0
	rotation.z = lerp_angle(rotation.z, wobble, 8.0 * delta)


func _tick_stuck(delta: float) -> void:
	_stuck_time += delta
	if _stuck_time < 3.0:
		return
	_stuck_time = 0.0
	if global_position.distance_to(_watch_position) < 0.8:
		_rescue()
	_watch_position = global_position


func _rescue() -> void:
	var target := WAYPOINTS[mini(_index, WAYPOINTS.size() - 1)]
	global_position = target + Vector3(randf_range(-0.8, 0.8), 0.6, 0.0)
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_external = Vector3.ZERO
	_watch_position = global_position


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
	_knockback += Vector3(force.x, 0.0, force.z)
	velocity.y = maxf(velocity.y, force.y)
	_stumble_time = maxf(_stumble_time, 0.35)


func launch(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)
	_stumble_time = maxf(_stumble_time, 0.2)


## Light shove used by the first sweeper: no stumble, just knockback.
func apply_push_soft(force: Vector3) -> void:
	_knockback += Vector3(force.x, 0.0, force.z)
	velocity.y = maxf(velocity.y, force.y)


func add_external_velocity(velocity_delta: Vector3) -> void:
	# Bots resist wind and belts a little so their path stays viable, and they
	# ignore lateral wind completely: they have no steering to correct it and
	# would be blown off the narrow bridge every single time.
	_external += Vector3(0.0, velocity_delta.y, velocity_delta.z) * 0.4


func add_belt_velocity(belt: Vector3) -> void:
	# Same resistance as wind, so a reverse belt never traps them forever.
	_external += belt * 0.4


func is_stunned() -> bool:
	return _stumble_time > 0.0


func is_prone() -> bool:
	return false
