extends CharacterBody3D

## Stumble-style player: inertia, coyote time, jump buffer, variable jump,
## dive/prone, platform momentum, procedural animation and a collision-aware
## third-person camera with FOV kick and shake.

@export_group("Movement")
@export var max_speed: float = 6.5
@export var acceleration: float = 28.0
@export var friction: float = 18.0
@export var jump_velocity: float = 7.5
## Upward speed kept when the jump button is released early.
@export var min_jump_velocity: float = 2.6
@export var air_control: float = 0.35
@export var gravity_scale: float = 1.15
@export var fall_gravity_scale: float = 1.4
## Grace period to still jump after walking off a ledge.
@export var coyote_time: float = 0.12
## Window in which a jump pressed just before landing still counts.
@export var jump_buffer_time: float = 0.12
## Below this vertical speed gravity is reduced, giving a floaty apex.
@export var apex_threshold: float = 2.0
@export var apex_gravity_scale: float = 0.65
## Maximum horizontal speed inherited from a moving platform on jump.
@export var platform_jump_cap: float = 6.0

@export_group("Dive")
## Short lunge: the slide is meant to dodge one hazard, not cross the map.
@export var dive_speed: float = 6.0
@export var dive_hop: float = 1.2
@export var prone_time: float = 0.35
## Time before the next dive, counted from the start of the previous one.
@export var dive_cooldown: float = 2.0
## Control left while lying on the ground.
@export var prone_control: float = 0.2

@export_group("Camera")
@export var camera_distance: float = 4.7
@export var camera_height: float = 1.5
## Downward pitch of the camera, in degrees. Negative looks down.
@export var camera_pitch: float = -15.0
@export var camera_lerp: float = 7.0
## Vertical smoothing, slower than the horizontal one so slopes do not
## drag the camera along the floor.
@export var camera_height_lerp: float = 5.0
## Minimum distance between the pivot and the ground below it.
@export var camera_min_clearance: float = 1.2
@export var camera_look_ahead: float = 0.12
@export var camera_fov_base: float = 55.0
@export var camera_fov_max: float = 70.0

@export_group("Reactions")
## How long the player staggers after a hard hit.
@export var stun_time: float = 0.55
## Control left while staggered (1.0 = full control, 0.0 = none).
@export var stun_control: float = 0.18
## Horizontal push magnitude above which a hit staggers the player.
@export var stun_push_threshold: float = 5.0
@export var shadow_max_distance: float = 8.0
@export var dust_speed_threshold: float = 3.0

## Set by a bot driver (future split-screen / network input).
@export var is_bot: bool = false
## Id del personaje que se está usando (expuesto para tests y HUD).
var character_id: String = ""

## While true the player keeps standing: no walk, jump or dive input.
var input_locked: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
## El modelo 3D se instancia en runtime según el personaje elegido en el menú.
var model: Node3D
var anim: AnimationPlayer
@onready var marker: Node3D = $Marker
@onready var dizzy: Node3D = $Dizzy
@onready var shadow: MeshInstance3D = $Shadow
@onready var dust: CPUParticles3D = $Dust
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var _spawn_transform: Transform3D
## Player-driven XZ velocity (friction/accel apply here only).
var _control_velocity: Vector3 = Vector3.ZERO
## Per-frame belt/wind contribution (not cancelled by friction).
var _external_velocity: Vector3 = Vector3.ZERO
## Animation state: "idle" | "run" | "jump" | "stun" | "prone".
var _anim_state: String = "idle"
var _anim_time: float = 0.0
var _mesh_base_y: float = 0.0
var _anim_was_on_floor: bool = true
var _land_squash_timer: float = 0.0
var _jump_cut_available: bool = false
var _stun_timer: float = 0.0
var _shadow_material: StandardMaterial3D
var _dust_burst_timer: float = 0.0
var _marker_base_y: float = 0.0
var _step_timer: float = 0.0
var _step_side: float = 1.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _prone_timer: float = 0.0
var _dive_cooldown_timer: float = 0.0
var _fall_speed: float = 0.0
var _impact_speed: float = 0.0
var _wish_dir: Vector3 = Vector3.ZERO
## After a teleport, one zero-velocity slide with platform inheritance off
## clears the floor reference from the previous spot. Otherwise a respawn
## while leaving a spinning platform can inherit a huge tangential velocity.
var _clear_platform_on_next_frame: bool = false

## Bot input mirror (world-space).
var _bot_wish: Vector3 = Vector3.ZERO
var _bot_jump_pressed: bool = false
var _bot_dive_pressed: bool = false


func _ready() -> void:
	_spawn_transform = global_transform
	if is_bot:
		add_to_group("bot")
	else:
		add_to_group("player")
	camera_pivot.top_level = true
	camera_pivot.global_position = global_position + Vector3(0.0, camera_height, 0.0)
	camera_pivot.visible = not is_bot
	spring_arm.spring_length = camera_distance
	spring_arm.rotation.x = deg_to_rad(camera_pitch)
	spring_arm.add_excluded_object(get_rid())
	camera.fov = camera_fov_base
	_mesh_base_y = mesh.position.y
	_setup_character()
	_setup_animations()
	_play_animation("idle", 0.0)
	if marker:
		_marker_base_y = marker.position.y
		# La flecha FIFA solo marca al jugador, nunca a los bots.
		marker.visible = not is_bot
	if shadow and shadow.material_override is StandardMaterial3D:
		_shadow_material = (shadow.material_override as StandardMaterial3D).duplicate()
		shadow.material_override = _shadow_material
	if dizzy:
		dizzy.visible = false


## Instancia el personaje elegido en el menú (o uno aleatorio si este cuerpo
## lo conduce un bot). El catálogo también oculta armas y capas.
func _setup_character() -> void:
	character_id = CharacterCatalog.random_id() if is_bot else SaveManager.character_id()
	model = CharacterCatalog.build_model(character_id, "Model")
	if model == null:
		push_warning("Player: no se pudo cargar el personaje '%s'" % character_id)
		return
	mesh.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer


## Locomotion clips loop; one-shots (landing, hit) play once.
func _setup_animations() -> void:
	if anim == null:
		return
	for clip_name in ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Lie_Idle"]:
		var clip := anim.get_animation(clip_name)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR


## Locks or releases player input without touching physics (used by the
## countdown so nobody can run before the race starts).
func set_input_locked(locked: bool) -> void:
	if input_locked == locked:
		return
	input_locked = locked
	if locked:
		_control_velocity = Vector3.ZERO
		_wish_dir = Vector3.ZERO
		_bot_wish = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _clear_platform_on_next_frame:
		_clear_platform_on_next_frame = false
		var saved_layers := platform_floor_layers
		platform_floor_layers = 0
		velocity = Vector3.ZERO
		move_and_slide()
		platform_floor_layers = saved_layers
	_tick_timers(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_handle_dive()
	velocity.x = _control_velocity.x + _external_velocity.x
	velocity.z = _control_velocity.z + _external_velocity.z
	velocity.y += _external_velocity.y
	_external_velocity = Vector3.ZERO
	var was_on_floor := is_on_floor()
	move_and_slide()
	if not is_on_floor():
		_fall_speed = minf(_fall_speed, velocity.y)
	else:
		if not was_on_floor:
			_impact_speed = _fall_speed
		_fall_speed = 0.0
	_update_facing(delta)
	_update_camera(delta)
	_update_shadow()
	_update_animation(delta, was_on_floor)
	_update_footsteps(delta)
	_update_marker(delta)


## Pisadas sincronizadas con la velocidad: suenan al correr, no al quedarse
## quieto ni en el aire.
func _update_footsteps(delta: float) -> void:
	if is_bot:
		return
	if not is_on_floor() or _stun_timer > 0.0 or _prone_timer > 0.0:
		_step_timer = 0.0
		return
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if speed < 0.9:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	_step_timer = clampf(0.5 - speed * 0.035, 0.24, 0.44)
	_step_side = -_step_side
	var volume := -8.5 if _step_side > 0.0 else -10.0
	AudioManager.play_sfx("step", 0.16, volume)


## Flecha sobre la cabeza, estilo FIFA: gira, flota y late un poco.
func _update_marker(delta: float) -> void:
	if marker == null or not marker.visible:
		return
	marker.rotate_y(delta * 1.9)
	var speed_ratio := clampf(Vector3(velocity.x, 0.0, velocity.z).length() / maxf(max_speed, 0.01), 0.0, 1.0)
	marker.position.y = _marker_base_y + sin(Time.get_ticks_msec() * 0.004) * 0.055 + speed_ratio * 0.06
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.06
	marker.scale = Vector3(pulse, pulse, pulse)


func _tick_timers(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer = maxf(0.0, _stun_timer - delta)
	if is_on_floor():
		_coyote_timer = coyote_time
	elif _coyote_timer > 0.0:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_prone_timer = maxf(0.0, _prone_timer - delta)
	_dive_cooldown_timer = maxf(0.0, _dive_cooldown_timer - delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var scale := fall_gravity_scale if velocity.y < 0.0 else gravity_scale
	if absf(velocity.y) < apex_threshold:
		scale *= apex_gravity_scale
	velocity.y -= g * scale * delta


## Tap-to-hop / hold-to-jump with coyote time, buffering and platform carry.
func _handle_jump() -> void:
	if input_locked:
		_jump_buffer_timer = 0.0
		return
	var pressed := Input.is_action_just_pressed("jump")
	if is_bot:
		pressed = _bot_jump_pressed
		_bot_jump_pressed = false
	if pressed:
		_jump_buffer_timer = jump_buffer_time
		if _prone_timer > 0.0:
			# Getting up is instant when jumping from the floor.
			_prone_timer = 0.0

	var can_jump := _jump_buffer_timer > 0.0 and _prone_timer <= 0.0 and (_coyote_timer > 0.0 or is_on_floor())
	if can_jump:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jump_cut_available = true
		var platform_velocity := get_platform_velocity()
		_control_velocity += Vector3(platform_velocity.x, 0.0, platform_velocity.z).limit_length(platform_jump_cap)
		AudioManager.play_sfx("jump", 0.08)
		_burst_dust()

	if not is_bot and Input.is_action_just_released("jump") and _jump_cut_available:
		_jump_cut_available = false
		if velocity.y > min_jump_velocity:
			velocity.y = min_jump_velocity


func _handle_movement(delta: float) -> void:
	if input_locked:
		_control_velocity = Vector3.ZERO
		_wish_dir = Vector3.ZERO
		return
	var wish := Vector3.ZERO
	if is_bot:
		wish = _bot_wish
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var cam_basis := camera.global_transform.basis
		var forward := -cam_basis.z
		var right := cam_basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		wish = right * input_dir.x + forward * -input_dir.y

	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	_wish_dir = wish

	var target := wish * max_speed
	var control := 1.0 if is_on_floor() else air_control
	if _stun_timer > 0.0:
		control *= stun_control
	if _prone_timer > 0.0:
		control *= prone_control

	if wish.length_squared() > 0.01:
		_control_velocity = _control_velocity.move_toward(target, acceleration * control * delta)
	else:
		var current_friction := friction * (0.7 if _prone_timer > 0.0 else 1.0)
		_control_velocity = _control_velocity.move_toward(Vector3.ZERO, current_friction * control * delta)


## Dive: forward burst + belly flop. In the air it drops fast, on the ground
## it leaves the player prone and vulnerable for a moment.
func _handle_dive() -> void:
	var pressed := Input.is_action_just_pressed("dive")
	if is_bot:
		pressed = _bot_dive_pressed
		_bot_dive_pressed = false
	if not pressed or not can_dive():
		return
	var direction := _wish_dir
	if direction.length_squared() < 0.01:
		direction = -mesh.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return
	direction = direction.normalized()

	_dive_cooldown_timer = dive_cooldown
	_prone_timer = prone_time
	# Replace the run speed instead of adding to it: the dive is a short
	# dodge, not a free boost across the map.
	_control_velocity = direction * dive_speed
	if is_on_floor():
		velocity.y = maxf(velocity.y, dive_hop)
	else:
		velocity.y = minf(velocity.y, 0.5)
	_jump_cut_available = false
	AudioManager.play_sfx("dive", 0.12)
	GameFeel.shake(1.6)
	_burst_dust()


func _update_facing(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length_squared() < 0.05:
		return
	var target_yaw := atan2(horizontal.x, horizontal.z)
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, 10.0 * delta)


## Third-person camera behind the player with spring-arm collision, FOV kick,
## look-ahead and shake. The pivot keeps a world-fixed yaw so input stays stable.
func _update_camera(delta: float) -> void:
	if is_bot:
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var look_ahead := horizontal * camera_look_ahead
	var desired := global_position + Vector3(0.0, camera_height, 0.0) + look_ahead
	# Smooth X/Z and Y separately: a single lerp makes the camera dive with
	# the player on slopes and end up scraping the floor.
	var current := camera_pivot.global_position
	var flat_weight := clampf(camera_lerp * delta, 0.0, 1.0)
	var height_weight := clampf(camera_height_lerp * delta, 0.0, 1.0)
	current.x = lerpf(current.x, desired.x, flat_weight)
	current.z = lerpf(current.z, desired.z, flat_weight)
	current.y = lerpf(current.y, desired.y, height_weight)
	camera_pivot.global_position = current
	_keep_camera_above_ground()

	var speed_ratio := clampf(horizontal.length() / maxf(max_speed, 0.01), 0.0, 1.0)
	var target_fov := camera_fov_base + speed_ratio * 9.0
	if velocity.y < -9.0:
		target_fov += 5.0
	camera.fov = lerpf(camera.fov, target_fov, 5.0 * delta)

	var shake := GameFeel.camera_offset()
	camera.h_offset = shake.x
	camera.v_offset = shake.y


## Keeps the pivot at least `camera_min_clearance` above whatever is below it,
## so the view never drags along the floor on downhill sections.
func _keep_camera_above_ground() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := camera_pivot.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var ground_point: Vector3 = hit["position"]
	var ground_y: float = ground_point.y
	var minimum := ground_y + camera_min_clearance
	if camera_pivot.global_position.y < minimum:
		camera_pivot.global_position.y = minimum


## Blob shadow: casts a ray straight down and fades/grows the disc with height.
func _update_shadow() -> void:
	if shadow == null:
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := global_position + Vector3.UP * 0.2
	var to := from + Vector3.DOWN * shadow_max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		shadow.visible = false
		return
	var ground: Vector3 = hit.position
	shadow.visible = true
	shadow.global_position = ground + Vector3.UP * 0.04
	var closeness := clampf(1.0 - (from.y - ground.y) / shadow_max_distance, 0.0, 1.0)
	var spread := lerpf(0.45, 0.85, closeness)
	shadow.scale = Vector3(spread, 1.0, spread)
	if _shadow_material:
		_shadow_material.albedo_color.a = lerpf(0.05, 0.36, closeness)


## Picks the animation clip for the state and keeps a light procedural
## squash/bounce on top, so the downloaded model still feels cartoony.
func _update_animation(delta: float, was_on_floor: bool) -> void:
	var on_floor := is_on_floor()
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()

	if on_floor and not _anim_was_on_floor:
		_land_squash_timer = 0.18
		_burst_dust()
		if _impact_speed < -7.0:
			GameFeel.shake(clampf(absf(_impact_speed) * 0.18, 1.0, 4.0))
			AudioManager.play_sfx("land", 0.12)
		_impact_speed = 0.0
	_anim_was_on_floor = on_floor
	if _land_squash_timer > 0.0:
		_land_squash_timer -= delta
	if _dust_burst_timer > 0.0:
		_dust_burst_timer -= delta

	var new_state := "idle"
	if _prone_timer > 0.0:
		new_state = "prone"
	elif _stun_timer > 0.0:
		new_state = "stun"
	elif not on_floor:
		new_state = "jump"
	elif _land_squash_timer > 0.0:
		new_state = "land"
	elif horizontal_speed > 4.8:
		new_state = "run"
	elif horizontal_speed > 0.8:
		new_state = "walk"
	if new_state != _anim_state:
		_anim_state = new_state
		_anim_time = 0.0
		_play_animation(new_state)

	_anim_time += delta
	if _anim_state != "stun" and _anim_state != "prone":
		mesh.rotation.z = lerpf(mesh.rotation.z, 0.0, 12.0 * delta)

	match _anim_state:
		"idle":
			var t := _anim_time * 2.0
			var squash := 1.0 + sin(t) * 0.012
			mesh.scale = Vector3(1.0 / squash, squash, 1.0 / squash)
			mesh.position.y = _mesh_base_y + (squash - 1.0) * 0.2
		"walk", "run":
			var t := _anim_time * (5.0 if _anim_state == "walk" else 8.0)
			var bounce := 1.0 + absf(sin(t)) * 0.035
			mesh.scale = Vector3(2.0 - bounce, bounce, 2.0 - bounce)
			mesh.position.y = _mesh_base_y + absf(sin(t)) * 0.04
		"jump":
			var rising := velocity.y > 0.0
			var stretch := 1.05 if rising else 1.03
			mesh.scale = Vector3(1.0 / stretch, stretch, 1.0 / stretch)
			mesh.position.y = _mesh_base_y
		"land":
			mesh.scale = Vector3.ONE
			mesh.position.y = _mesh_base_y
		"stun":
			var wobble := sin(_anim_time * 20.0) * (0.08 + 0.16 * (_stun_timer / maxf(stun_time, 0.01)))
			mesh.scale = Vector3.ONE
			mesh.position.y = _mesh_base_y
			mesh.rotation.z = wobble
		"prone":
			mesh.scale = Vector3.ONE
			mesh.position.y = _mesh_base_y
			mesh.rotation.z = lerpf(mesh.rotation.z, 0.0, 10.0 * delta)

	# Landing squash overrides for a few frames after touching the ground.
	if _land_squash_timer > 0.0 and _prone_timer <= 0.0:
		var strength := _land_squash_timer / 0.18
		var squash := 1.0 - 0.12 * strength
		mesh.scale = Vector3(1.0 + (1.0 - squash) * 0.5, squash, 1.0 + (1.0 - squash) * 0.5)
		mesh.position.y = _mesh_base_y

	_update_dust(horizontal_speed)

	if dizzy:
		dizzy.visible = _stun_timer > 0.0
		if dizzy.visible:
			dizzy.rotate_y(delta * 7.0)
			dizzy.position.y = 1.6 + sin(Time.get_ticks_msec() * 0.006) * 0.08


func _play_animation(state: String, blend: float = 0.15) -> void:
	if anim == null:
		return
	var clip := "Idle"
	match state:
		"walk":
			clip = "Walking_A"
		"run":
			clip = "Running_A"
		"jump":
			clip = "Jump_Idle"
		"land":
			clip = "Jump_Land"
		"prone":
			clip = "Lie_Idle"
		"stun":
			clip = "Hit_A"
	if anim.current_animation != clip:
		anim.play(clip, blend)
	anim.speed_scale = 1.3 if clip == "Running_A" else 1.0


func _update_dust(horizontal_speed: float) -> void:
	if dust == null:
		return
	var landing_puff := _dust_burst_timer > 0.0
	dust.emitting = landing_puff or (is_on_floor() and horizontal_speed > dust_speed_threshold)


func _burst_dust() -> void:
	if dust == null:
		return
	_dust_burst_timer = 0.4
	dust.emitting = true
	dust.restart()


## Continuous belt speed for this physics frame (units/s). Not cancelled by friction.
func add_belt_velocity(belt: Vector3) -> void:
	_external_velocity += belt


## Wind and other continuous environmental acceleration (units/s this frame).
func add_external_velocity(velocity_delta: Vector3) -> void:
	_external_velocity += velocity_delta


## Impulse knock from obstacles / hazards. Hard hits also stagger the player.
func apply_push(force: Vector3) -> void:
	_control_velocity.x += force.x
	_control_velocity.z += force.z
	velocity.y += force.y
	var horizontal_strength := Vector2(force.x, force.z).length()
	if horizontal_strength >= stun_push_threshold:
		stun()
		GameFeel.hit_stop(0.05)
		GameFeel.flash(Color(1.0, 0.3, 0.3), 0.35)
		GameFeel.shake(clampf(horizontal_strength * 0.35, 2.0, 6.0))
		AudioManager.play_sfx("impact", 0.15)
	elif horizontal_strength > 2.0:
		GameFeel.shake(1.2)
		AudioManager.play_sfx("impact", 0.2, -4.0)


## Light shove (sweeper bar, bumper): keeps the knockback but never stuns.
func apply_push_soft(force: Vector3) -> void:
	_control_velocity.x += force.x
	_control_velocity.z += force.z
	velocity.y += force.y
	if Vector2(force.x, force.z).length() > 2.0:
		GameFeel.shake(0.5)
		AudioManager.play_sfx("impact", 0.25, -6.0)


## Launch from a cannon/trampoline without the stun that `apply_push` adds.
func launch(impulse: Vector3) -> void:
	_control_velocity += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)
	_prone_timer = 0.0
	_jump_cut_available = false
	GameFeel.shake(2.0)


## Launch straight up from a trampoline/pad. Ignores the jump-cut rule.
func bounce(strength: float) -> void:
	velocity.y = strength
	_jump_cut_available = false
	_land_squash_timer = 0.0
	_prone_timer = 0.0


## Make the player stagger for `duration` seconds (default: stun_time).
func stun(duration: float = -1.0) -> void:
	_stun_timer = maxf(_stun_timer, stun_time if duration < 0.0 else duration)


## True when the dive can be used again: the cooldown is over, the player is
## not lying on the floor and input is not locked by the countdown.
func can_dive() -> bool:
	return not input_locked and _dive_cooldown_timer <= 0.0 and _prone_timer <= 0.0


## Seconds left on the dive cooldown (0 when ready).
func dive_cooldown_remaining() -> float:
	return _dive_cooldown_timer


func is_stunned() -> bool:
	return _stun_timer > 0.0


func is_prone() -> bool:
	return _prone_timer > 0.0


## Bot input: world-space direction + one-frame jump/dive flags.
func set_bot_drive(direction: Vector3, jump: bool = false, dive: bool = false) -> void:
	_bot_wish = direction
	if jump:
		_bot_jump_pressed = true
	if dive:
		_bot_dive_pressed = true


func respawn_at(checkpoint_transform: Transform3D) -> void:
	global_transform = checkpoint_transform
	velocity = Vector3.ZERO
	_control_velocity = Vector3.ZERO
	_external_velocity = Vector3.ZERO
	_stun_timer = 0.0
	_jump_cut_available = false
	_land_squash_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_prone_timer = 0.0
	_dive_cooldown_timer = 0.0
	_fall_speed = 0.0
	_anim_state = "idle"
	_anim_time = 0.0
	mesh.rotation = Vector3.ZERO
	mesh.position.y = _mesh_base_y
	mesh.scale = Vector3.ONE
	mesh.rotation.y = 0.0
	_play_animation("idle", 0.0)
	if dizzy:
		dizzy.visible = false
	camera_pivot.global_position = global_position + Vector3(0.0, camera_height, 0.0)
	_clear_platform_on_next_frame = true


func get_spawn_transform() -> Transform3D:
	return _spawn_transform
