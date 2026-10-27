extends AnimatableBody3D

## Deliberately unstable seesaw bridge: a wide board balanced on a central
## axle. The board's long side runs along the axle (local X) so the visual
## design and the real pitch axis match.
##
## The board is balanced on a knife edge at the exact centre: only the 10 cm
## strip in the middle is safe. Any rider beyond that tips the deck instantly to
## its stop. Once the deck gets steep, the board stops gripping and riders slide
## downhill into the gaps at either end of the table.
##
## The biggest edges are a full 5 m out from the centre — past the end of the
## board itself — so they launch riders into open air. A rider there falls into
## the void instead of onto the landing.
##
## The board uses `sync_to_physics = false` because the physics server discards
## root rotations while that flag is enabled.

@export var max_tilt: float = 0.5
@export var max_roll: float = 0.16
@export var responsiveness: float = 6.0
@export var idle_sway: float = 0.0
## Normalised offset (0..1) beyond which the board commits to a full tip.
## 0.02 over the 5 m half-board is a 10 cm safe strip.
@export var tip_threshold: float = 0.02
## Lateral offset is amplified so stepping off the centre line also rolls it.
@export var roll_gain: float = 2.5
## Small constant shiver while somebody is riding, so it never feels stable.
@export var instability: float = 0.02
## Half-length of the board along the travel direction (local Z).
@export var rider_range: float = 5.0
## Half-width of the board across the path (local X).
@export var rider_width: float = 6.5
## How far above the board a body still counts as riding it (local Y).
@export var rider_height: float = 2.2
## Tilt beyond which the deck stops gripping and starts sliding riders.
@export var slide_threshold: float = 0.35
## Downhill speed applied to riders past the slide threshold (m/s).
@export var slide_speed: float = 4.0
## When a rider reaches this local Z on the down-side of the board, their end
## of the deck has already dropped past the edge and they are past the point of
## no return. Pushing them off here drops them into the void — not onto the
## landing — matching the visual table edges.
@export var edge_cutoff: float = -4.7

var _tilt: float = 0.0
var _roll: float = 0.0
var _time: float = 0.0
var _rider_count: int = 0
var _creak_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("see_saws")
	sync_to_physics = false


func _physics_process(delta: float) -> void:
	_time += delta
	var riders := _rider_bodies()
	var weight := _rider_weight(riders)
	# Any weight outside the tiny centre strip commits the board to a full
	# tip; it does not hover at a gentle angle.
	var target_tilt := sin(_time * 0.9) * idle_sway
	if absf(weight.y) > tip_threshold:
		target_tilt = signf(weight.y) * max_tilt
	if _rider_count > 0:
		target_tilt += sin(_time * 17.0) * instability
	var target_roll := -clampf(weight.x * roll_gain, -1.0, 1.0) * max_roll
	var smoothing := clampf(responsiveness * delta, 0.0, 1.0)
	_tilt = lerpf(_tilt, target_tilt, smoothing)
	_roll = lerpf(_roll, target_roll, smoothing)
	rotation.x = _tilt
	rotation.z = _roll
	_apply_slide(riders)
	_tick_creak(delta)


## Crujido de madera cuando la tabla se inclina o vuelve a su sitio.
func _tick_creak(delta: float) -> void:
	_creak_cooldown = maxf(0.0, _creak_cooldown - delta)
	if _creak_cooldown > 0.0:
		return
	if absf(_tilt) < 0.12:
		return
	_creak_cooldown = 0.65
	AudioManager.play_sfx_at("creak", global_position, 0.14, -11.0)


## Riders on a steep deck lose their grip: constant downhill speed towards the
## low edge. Running across still beats it, but standing on a tipped board
## slides you into the gap. Bots are pushed exactly like the player.
##
## When a body has slid past the board's edge (local Z past the edge cutoff),
## it is no longer supported by anything and falls into the void. This is what
## makes the far edges of the table actually drop riders into the gap on that
## side rather than leaving them standing on thin air.
func _apply_slide(riders: Array[Node3D]) -> void:
	if riders.is_empty():
		return
	var normal := global_transform.basis.y.normalized()
	var downhill := Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
	# Only the horizontal part: gravity already supplies the fall, and adding a
	# downward push would make riders clip through the deck instead of sliding.
	downhill.y = 0.0
	if downhill.length_squared() < 0.0001:
		downhill = Vector3.DOWN
	else:
		downhill = downhill.normalized()
	for body in riders:
		var local := to_local((body as Node3D).global_position)
		# Once a rider has gone past the off-side edge of the board, drop them.
		if local.z < edge_cutoff and signf(_tilt) == signf(-local.z):
			_push_rider(body, downhill * slide_speed * 2.0)
			continue
		if absf(_tilt) >= slide_threshold:
			_push_rider(body, downhill * slide_speed)


## Player and bots alike lose their grip on the steep deck. Bots get the same
## push as the player, so the seesaw is a real obstacle for the whole pack.
func _push_rider(body: Node3D, push: Vector3) -> void:
	if body.has_method("add_slide_velocity"):
		body.call("add_slide_velocity", push)
	elif body.has_method("add_external_velocity"):
		body.call("add_external_velocity", push)


## Player/bot bodies currently standing on or just above the board.
func _rider_bodies() -> Array[Node3D]:
	var riders: Array[Node3D] = []
	for group in ["player", "bot"]:
		for body in get_tree().get_nodes_in_group(group):
			if not (body is Node3D) or not is_instance_valid(body):
				continue
			# Only grounded riders tip the deck: a body still jumping towards the
			# board would otherwise make it drop before it can land on the edge.
			if body is CharacterBody3D and not (body as CharacterBody3D).is_on_floor():
				continue
			var local := to_local((body as Node3D).global_position)
			if absf(local.x) > rider_width or absf(local.z) > rider_range:
				continue
			# Local Y follows the board as it tips; a global-height check would
			# stop detecting the rider once their end of the board went down.
			if local.y < -1.0 or local.y > rider_height:
				continue
			riders.append(body as Node3D)
	return riders


## Average position of every rider, normalised to [-1, 1] on each axis. X is
## the roll axis, Y (from local Z) the pitch axis.
func _rider_weight(riders: Array[Node3D]) -> Vector2:
	var total := Vector2.ZERO
	_rider_count = riders.size()
	if riders.is_empty():
		return Vector2.ZERO
	for body in riders:
		var local := to_local(body.global_position)
		total += Vector2(
			clampf(local.x / rider_width, -1.0, 1.0),
			clampf(local.z / rider_range, -1.0, 1.0))
	return total / float(riders.size())


## Current pitch in radians (used by tests and diagnostics).
func get_tilt() -> float:
	return _tilt


## Current roll in radians (used by diagnostics).
func get_roll() -> float:
	return _roll
