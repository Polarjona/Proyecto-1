extends CharacterBody3D

## Stumble-style player: heavy inertia, floaty jump, external pushes.
## Procedural idle/run/jump animations drive the mesh scale/offset.

@export var max_speed: float = 8.0
@export var acceleration: float = 28.0
@export var friction: float = 18.0
@export var jump_velocity: float = 7.5
@export var air_control: float = 0.35
@export var gravity_scale: float = 1.15
@export var fall_gravity_scale: float = 1.4
@export var camera_distance: float = 7.0
@export var camera_height: float = 4.0
@export var camera_lerp: float = 6.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var _spawn_transform: Transform3D
## Player-driven XZ velocity (friction/accel apply here only).
var _control_velocity: Vector3 = Vector3.ZERO
## One-frame belt contribution from conveyors (not fricted away).
var _belt_velocity: Vector3 = Vector3.ZERO
## Animation state: "idle" | "run" | "jump".
var _anim_state: String = "idle"
var _anim_time: float = 0.0
## Mesh rest position/shape height for procedural bob/squash.
var _mesh_base_y: float = 0.0
var _anim_was_on_floor: bool = true
var _land_squash_timer: float = 0.0


func _ready() -> void:
	_spawn_transform = global_transform
	add_to_group("player")
	camera_pivot.top_level = true
	camera_pivot.global_position = global_position + Vector3(0.0, camera_height, camera_distance)
	_mesh_base_y = mesh.position.y


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	velocity.x = _control_velocity.x + _belt_velocity.x
	velocity.z = _control_velocity.z + _belt_velocity.z
	_belt_velocity = Vector3.ZERO
	var was_on_floor := is_on_floor()
	move_and_slide()
	_update_facing(delta)
	_update_camera(delta)
	_update_animation(delta, was_on_floor)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var scale := fall_gravity_scale if velocity.y < 0.0 else gravity_scale
	velocity.y -= g * scale * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		AudioManager.play_sfx("jump")


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var wish := (right * input_dir.x + forward * -input_dir.y)
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var target := wish * max_speed
	var control := 1.0 if is_on_floor() else air_control

	if wish.length_squared() > 0.01:
		_control_velocity = _control_velocity.move_toward(target, acceleration * control * delta)
	else:
		_control_velocity = _control_velocity.move_toward(Vector3.ZERO, friction * control * delta)


func _update_facing(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length_squared() < 0.05:
		return
	var target_yaw := atan2(horizontal.x, horizontal.z)
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, 10.0 * delta)


func _update_camera(delta: float) -> void:
	var desired := global_position + Vector3(0.0, camera_height, camera_distance)
	camera_pivot.global_position = camera_pivot.global_position.lerp(desired, camera_lerp * delta)
	camera.look_at(global_position + Vector3.UP * 1.2, Vector3.UP)


## Procedural state machine: idle bob, run bob, jump stretch + landing squash.
func _update_animation(delta: float, was_on_floor: bool) -> void:
	var on_floor := is_on_floor()
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()

	# Landing squash trigger.
	if on_floor and not _anim_was_on_floor:
		_land_squash_timer = 0.18
	_anim_was_on_floor = on_floor
	if _land_squash_timer > 0.0:
		_land_squash_timer -= delta

	var new_state := "idle"
	if not on_floor:
		new_state = "jump"
	elif horizontal_speed > 0.8:
		new_state = "run"
	if new_state != _anim_state:
		_anim_state = new_state
		_anim_time = 0.0

	_anim_time += delta
	match _anim_state:
		"idle":
			var t := _anim_time * 2.0
			var squash := 1.0 + sin(t) * 0.025
			mesh.scale = Vector3(1.0 / squash, squash, 1.0 / squash)
			mesh.position.y = _mesh_base_y + (squash - 1.0) * 0.35
		"run":
			var t := _anim_time * (3.0 + horizontal_speed * 0.9)
			var bounce := 1.0 + absf(sin(t)) * 0.09
			# Stretch up on the hop, narrow X/Z to keep the volume plausible.
			mesh.scale = Vector3(2.0 - bounce, bounce, 2.0 - bounce)
			mesh.position.y = _mesh_base_y + absf(sin(t)) * 0.12
		"jump":
			var rising := velocity.y > 0.0
			var stretch := 1.15 if rising else 1.05
			mesh.scale = Vector3(1.0 / stretch, stretch, 1.0 / stretch)
			mesh.position.y = _mesh_base_y

	# Landing squash overrides for a few frames after touching the ground.
	if _land_squash_timer > 0.0:
		var strength := _land_squash_timer / 0.18
		var squash := 1.0 - 0.18 * strength
		mesh.scale = Vector3(1.0 + (1.0 - squash) * 0.5, squash, 1.0 + (1.0 - squash) * 0.5)
		mesh.position.y = _mesh_base_y


## Continuous belt speed for this physics frame (units/s). Not cancelled by friction.
func add_belt_velocity(belt: Vector3) -> void:
	_belt_velocity += belt


## Impulse knock from obstacles / other players.
func apply_push(force: Vector3) -> void:
	_control_velocity.x += force.x
	_control_velocity.z += force.z
	velocity.y += force.y


func respawn_at(checkpoint_transform: Transform3D) -> void:
	global_transform = checkpoint_transform
	velocity = Vector3.ZERO
	_control_velocity = Vector3.ZERO
	_belt_velocity = Vector3.ZERO


func get_spawn_transform() -> Transform3D:
	return _spawn_transform
