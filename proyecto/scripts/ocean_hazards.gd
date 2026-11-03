extends Node3D

## Los quince obstáculos exclusivos del circuito abisal (Abyss Run).
##
## Todos son `Area3D` (nada de muros fijos): empujan, aturden o arrastran al
## corredor mientras nada. Ningún otro mapa del juego usa ninguno de estos
## tipos, así que el fondo marino se juega distinto al hielo o al volcán.
##
## Se instancian como `OCEAN_HAZARDS.Urchin.new()` desde `level_builder.gd`.

## Clase base: caja de detección, empuje con enfriamiento y utilidades de malla
## para que cada obstáculo solo tenga que describir su forma y su ritmo.
class OceanHazard:
	extends Area3D

	var push_force: float = 6.0
	var stun_seconds: float = 0.0
	## "stun" aturde, "push" empuja fuerte hacia atrás y "kill" manda al
	## último checkpoint. Cada obstáculo elige el suyo.
	var touch_kind: String = "stun"
	## Ajustes que el generador del mapa aplica antes de añadir el obstáculo:
	## así el mismo tipo puede aturdir en un tramo y matar en otro.
	var touch_override: String = ""
	var push_override: float = 0.0
	var stun_override: float = 0.0

	var _bodies: Array[Node3D] = []
	var _cooldown_until: int = 0
	var _collision_shape: CollisionShape3D

	func _setup(box: Vector3, push: float = 6.0, stun_time: float = 0.0,
			offset: Vector3 = Vector3.ZERO) -> void:
		push_force = push
		stun_seconds = stun_time
		collision_layer = 0
		collision_mask = 2
		monitoring = true
		monitorable = false
		_collision_shape = CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box
		_collision_shape.shape = box_shape
		_collision_shape.position = offset
		add_child(_collision_shape)
		body_entered.connect(_on_enter)
		body_exited.connect(_on_exit)

	func _on_enter(body: Node3D) -> void:
		if not body.is_in_group("player"):
			return
		if not _bodies.has(body):
			_bodies.append(body)
		_touch(body)

	func _on_exit(body: Node3D) -> void:
		_bodies.erase(body)

	func _touch(body: Node3D) -> void:
		if Time.get_ticks_msec() < _cooldown_until:
			return
		_cooldown_until = Time.get_ticks_msec() + 850
		var away := body.global_position - global_position
		if away.length_squared() < 0.02:
			away = -global_transform.basis.z
		away = away.normalized()
		var kind := touch_override if touch_override != "" else touch_kind
		var force := push_override if push_override > 0.0 else push_force
		var stun_time := stun_override if stun_override > 0.0 else stun_seconds
		match kind:
			"kill":
				_kill(body)
			"push":
				_push_body(body, (away + Vector3.UP * 0.18).normalized() * force)
				if body.has_method("stun"):
					body.stun(0.22)
			_:
				_push_body(body, (away + Vector3.UP * 0.22).normalized() * force)
				if stun_time > 0.0 and body.has_method("stun"):
					body.stun(stun_time)

	## Un obstáculo letal devuelve al corredor al checkpoint anterior.
	func _kill(body: Node3D) -> void:
		var manager := get_tree().get_first_node_in_group("race_manager")
		if manager == null or not manager.has_method("respawn_player"):
			return
		AudioManager.play_sfx("fall")
		if body.has_method("stun"):
			body.stun(0.2)
		manager.respawn_player()

	func _push_body(body: Node3D, vector: Vector3) -> void:
		if body.has_method("apply_push"):
			body.apply_push(vector)

	## Empuje continuo (corrientes, vórtices, chorros). Usa `add_belt_velocity`
	## cuando existe para que no aturda en cada fotograma.
	func _push_field(vector: Vector3) -> void:
		for body in _bodies:
			if not is_instance_valid(body):
				continue
			if body.has_method("add_belt_velocity"):
				body.add_belt_velocity(vector)
			else:
				_push_body(body, vector)

	func _add_sphere(parent: Node3D, radius: float, material: Material,
			at: Vector3) -> MeshInstance3D:
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 14
		mesh.rings = 7
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.position = at
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		return instance

	func _add_box(parent: Node3D, box: Vector3, material: Material, at: Vector3,
			rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
		var mesh := BoxMesh.new()
		mesh.size = box
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.position = at
		instance.rotation_degrees = rot_deg
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		return instance

	func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float,
			height_value: float, material: Material, at: Vector3,
			rot_deg: Vector3 = Vector3.ZERO, segments: int = 10) -> MeshInstance3D:
		var mesh := CylinderMesh.new()
		mesh.top_radius = top_radius
		mesh.bottom_radius = bottom_radius
		mesh.height = height_value
		mesh.radial_segments = segments
		mesh.rings = 2
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.position = at
		instance.rotation_degrees = rot_deg
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		return instance

	func _add_light(parent: Node3D, color: Color, energy: float,
			reach: float) -> OmniLight3D:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = energy
		light.omni_range = reach
		parent.add_child(light)
		return light


## Erizo de mar: bola de púas que gira y no deja pasar por el centro.
class Urchin extends OceanHazard:
	var radius: float = 0.85
	var spin: float = 0.7

	func _ready() -> void:
		touch_kind = "kill"
		_setup(Vector3.ONE * radius * 2.4, 7.5, 0.45)
		_add_sphere(self, radius, OceanStyle.matte(OceanStyle.CORAL, 0.4), Vector3.ZERO)
		_add_sphere(self, radius * 1.75, OceanStyle.additive(OceanStyle.CORAL, 0.08), Vector3.ZERO)
		for i in 14:
			var y := 1.0 - 2.0 * (float(i) + 0.5) / 14.0
			var ring := sqrt(maxf(0.0, 1.0 - y * y))
			var angle := float(i) * 2.39996
			var dir := Vector3(cos(angle) * ring, y, sin(angle) * ring)
			var spike := _add_cylinder(self, 0.0, 0.11, 0.58,
				OceanStyle.glow(OceanStyle.CORAL_ALT, 1.1), dir * (radius + 0.27))
			spike.quaternion = Quaternion(Vector3.UP, dir)

	func _process(delta: float) -> void:
		rotation.y += delta * spin


## Alga látigo: una columna de hojas que barre el paso de lado a lado.
class KelpWhip extends OceanHazard:
	var height: float = 12.0
	var sway: float = 1.0
	var blades: int = 9

	var _blade_root: Node3D
	var _phase: float = 0.0

	func _ready() -> void:
		touch_kind = "push"
		push_force = 10.5
		_setup(Vector3(2.8, height * 0.8, 2.8), 6.0, 0.3)
		_blade_root = Node3D.new()
		_blade_root.name = "Blades"
		add_child(_blade_root)
		for i in blades:
			var t := float(i) / float(blades - 1)
			var segment := _add_box(_blade_root, Vector3(0.34, height / float(blades) + 0.12, 0.16),
				OceanStyle.matte(OceanStyle.ALGAE.lerp(OceanStyle.ROCK_DARK, t), 0.8),
				Vector3(0.0, -height * 0.5 + t * height, 0.0))
			segment.rotation.z = sin(t * 3.0) * 0.12
		_add_sphere(self, 0.34, OceanStyle.glow(OceanStyle.ALGAE, 1.6),
			Vector3(0.0, height * 0.5, 0.0))

	func _process(delta: float) -> void:
		_phase += delta * 1.7 * sway
		var index := 0
		for child in _blade_root.get_children():
			var segment := child as Node3D
			var t := float(index) / float(maxi(blades - 1, 1))
			segment.position.x = sin(_phase + t * 3.2) * 1.15 * t * sway
			segment.rotation.z = sin(_phase + t * 3.2) * 0.16 * t
			index += 1


## Mina de burbujas: flota, sube y baja, y al tocarla estalla en un empujón.
class BubbleMine extends OceanHazard:
	var radius: float = 0.95
	var bob: float = 1.4

	var _base_y: float = 0.0
	var _time: float = 0.0

	func _ready() -> void:
		touch_kind = "push"
		push_force = 16.0
		_setup(Vector3.ONE * radius * 2.9, 8.0, 0.4)
		_base_y = position.y
		_add_sphere(self, radius, OceanStyle.matte(OceanStyle.ROCK_DARK, 0.55), Vector3.ZERO)
		_add_sphere(self, radius * 1.3, OceanStyle.glass(OceanStyle.GLOW, 0.22), Vector3.ZERO)
		for i in 8:
			var angle := float(i) * TAU / 8.0
			_add_sphere(self, 0.17, OceanStyle.glass(OceanStyle.GLOW, 0.6),
				Vector3(cos(angle) * radius * 1.35, sin(angle * 2.0) * 0.3, sin(angle) * radius * 1.35))
		_add_light(self, OceanStyle.GLOW, 0.9, 6.0)

	func _process(delta: float) -> void:
		_time += delta
		position.y = _base_y + sin(_time * 1.3) * bob
		rotation.y += delta * 0.5


## Corriente cruzada: una franja que empuja de lado mientras se la cruza.
class CurrentRibbon extends OceanHazard:
	var force: float = 3.4
	var direction: Vector3 = Vector3.RIGHT

	var _time: float = 0.0
	var _arrows: Array[MeshInstance3D] = []

	func _ready() -> void:
		_setup(Vector3(25.0, 9.0, 3.6))
		for i in 7:
			var ribbon := _add_box(self, Vector3(23.0, 0.12, 0.5),
				OceanStyle.additive(OceanStyle.GLOW, 0.14),
				Vector3(0.0, -3.6 + float(i) * 1.2, 0.0))
			_arrows.append(ribbon)
		for i in 9:
			var fin := _add_box(self, Vector3(0.3, 0.9, 1.6),
				OceanStyle.glass(OceanStyle.GLOW, 0.22),
				Vector3(-10.0 + float(i) * 2.5, 0.0, 0.0), Vector3(0.0, 0.0, 24.0))
			fin.rotation.z = deg_to_rad(28.0)
		_add_light(self, OceanStyle.GLOW, 0.7, 12.0)

	func _physics_process(delta: float) -> void:
		_time += delta
		_push_field(direction.normalized() * force)
		for i in _arrows.size():
			_arrows[i].position.z = sin(_time * 2.6 + float(i) * 0.6) * 0.5


## Medusa: campana translúcida que sube y baja, con tentáculos que aturden.
class Jellyfish extends OceanHazard:
	var bell_size: float = 1.1
	var drift: float = 1.8
	var rise_speed: float = 0.8

	var _base_y: float = 0.0
	var _time: float = 0.0
	var _bell: Node3D
	var _light: OmniLight3D

	func _ready() -> void:
		_setup(Vector3(4.2, 6.4, 4.2), 5.2, 0.65)
		_base_y = position.y
		_bell = Node3D.new()
		add_child(_bell)
		var dome := _add_sphere(_bell, bell_size, OceanStyle.glass(OceanStyle.CORAL_PURPLE, 0.6), Vector3.ZERO)
		dome.scale = Vector3(1.0, 0.72, 1.0)
		_add_sphere(_bell, bell_size * 0.4, OceanStyle.glow(OceanStyle.GLOW, 2.1), Vector3(0, 0.18, 0))
		for i in 7:
			var angle := float(i) * TAU / 7.0
			_add_box(_bell, Vector3(0.08, 2.8, 0.08),
				OceanStyle.glass(OceanStyle.CORAL_PURPLE, 0.45),
				Vector3(cos(angle) * bell_size * 0.55, -1.6, sin(angle) * bell_size * 0.55))
		_light = _add_light(self, OceanStyle.CORAL_PURPLE, 1.3, 7.0)

	func _process(delta: float) -> void:
		_time += delta
		position.y = _base_y + sin(_time * rise_speed) * drift
		rotation.y += delta * 0.35
		var pulse := 0.75 + 0.35 * sin(_time * 2.1)
		_light.light_energy = pulse
		if _bell != null:
			_bell.scale = Vector3(1.0, 0.85 + pulse * 0.2, 1.0)


## Señuelo de rape: un farol colgante que se balancea sobre el paso.
class AnglerLure extends OceanHazard:
	var swing: float = 2.4
	var phase: float = 0.0

	var _hook: Node3D

	func _ready() -> void:
		_setup(Vector3(5.4, 7.0, 5.4), 6.0, 0.55)
		_add_box(self, Vector3(0.06, 6.0, 0.06), OceanStyle.matte(OceanStyle.ROCK_DARK),
			Vector3(0.0, 3.0, 0.0))
		_hook = Node3D.new()
		_hook.position = Vector3(0.0, 0.4, 0.0)
		add_child(_hook)
		_add_sphere(_hook, 0.5, OceanStyle.glow(OceanStyle.CORAL_ALT, 2.4), Vector3.ZERO)
		_add_sphere(_hook, 0.95, OceanStyle.additive(OceanStyle.CORAL_ALT, 0.12), Vector3.ZERO)
		_add_light(_hook, OceanStyle.CORAL_ALT, 1.6, 8.0)

	func _process(delta: float) -> void:
		phase += delta * 1.1
		_hook.position.x = sin(phase) * swing
		_hook.position.y = 0.4 - cos(phase) * 0.12


## Remolino: succiona hacia el ojo y hace girar al corredor.
class Whirlpool extends OceanHazard:
	var radius: float = 4.0
	var pull: float = 4.4
	var spin: float = 2.4

	var _rings: Array[Node3D] = []
	var _time: float = 0.0

	func _ready() -> void:
		_setup(Vector3(radius * 2.0, radius * 2.8, radius * 2.0))
		for i in 4:
			var ring := Node3D.new()
			add_child(ring)
			for j in 10:
				var angle := float(j) * TAU / 10.0
				var arm := _add_box(ring, Vector3(0.18, 0.18, radius * 0.9),
					OceanStyle.additive(OceanStyle.GLOW, 0.18),
					Vector3(cos(angle) * radius * 0.55, sin(angle) * radius * 0.55, 0.0))
				arm.rotation.z = angle
			ring.rotation.x = deg_to_rad(24.0 + float(i) * 12.0)
			_rings.append(ring)
		_add_sphere(self, radius * 0.35, OceanStyle.glass(OceanStyle.GLOW, 0.35), Vector3.ZERO)
		_add_light(self, OceanStyle.GLOW, 1.2, radius * 3.2)

	func _physics_process(delta: float) -> void:
		_time += delta
		for i in _rings.size():
			_rings[i].rotate_y(delta * (0.9 + float(i) * 0.4))
		for body in _bodies:
			if not is_instance_valid(body):
				continue
			var offset := body.global_position - global_position
			offset.y *= 0.3
			if offset.length_squared() < 0.4:
				continue
			var inward := -offset.normalized()
			var tangent := Vector3(-offset.z, 0.0, offset.x).normalized()
			_push_field((inward * pull + tangent * spin) * delta * 4.0)


## Pez globo: se hincha y deshincha, y bloquea el paso solo cuando está lleno.
class Pufferfish extends OceanHazard:
	var puff_speed: float = 2.2

	var _time: float = 0.0
	var _body: Node3D

	func _ready() -> void:
		touch_kind = "push"
		push_force = 14.0
		_setup(Vector3(2.6, 2.6, 2.6), 8.5, 0.5)
		_body = Node3D.new()
		add_child(_body)
		_add_sphere(_body, 0.9, OceanStyle.matte(OceanStyle.SAND, 0.55), Vector3.ZERO)
		for i in 12:
			var y := 1.0 - 2.0 * (float(i) + 0.5) / 12.0
			var ring := sqrt(maxf(0.0, 1.0 - y * y))
			var angle := float(i) * 2.39996
			var dir := Vector3(cos(angle) * ring, y, sin(angle) * ring)
			_add_cylinder(_body, 0.0, 0.09, 0.42, OceanStyle.matte(OceanStyle.CORAL_ALT, 0.5),
				dir * 0.95)
			var spike := _body.get_child(_body.get_child_count() - 1) as MeshInstance3D
			spike.quaternion = Quaternion(Vector3.UP, dir)
		_add_light(_body, OceanStyle.CORAL_ALT, 0.7, 4.5)

	func _process(delta: float) -> void:
		_time += delta
		var puff := 0.55 + 0.75 * (0.5 + 0.5 * sin(_time * puff_speed))
		_body.scale = Vector3.ONE * puff
		if _collision_shape != null:
			_collision_shape.scale = Vector3.ONE * (0.55 + puff * 0.55)
		rotation.y += delta * 0.4


## Almeja gigante: dos valvas que se cierran y empujan al que esté en medio.
class ClamSnap extends OceanHazard:
	var period: float = 2.6

	var _time: float = 0.0
	var _top: Node3D
	var _bottom: Node3D

	func _ready() -> void:
		touch_kind = "kill"
		_setup(Vector3(5.6, 4.6, 3.4), 9.5, 0.6)
		_top = Node3D.new()
		_top.position = Vector3(0.0, 0.35, -1.7)
		add_child(_top)
		var top_shell := _add_sphere(_top, 1.7, OceanStyle.matte(OceanStyle.CORAL_PURPLE, 0.45),
			Vector3(0.0, 0.0, 1.7))
		top_shell.scale = Vector3(1.3, 0.5, 1.0)
		_bottom = Node3D.new()
		_bottom.position = Vector3(0.0, -0.35, -1.7)
		add_child(_bottom)
		var bottom_shell := _add_sphere(_bottom, 1.7, OceanStyle.matte(OceanStyle.ROCK_DARK, 0.5),
			Vector3(0.0, 0.0, 1.7))
		bottom_shell.scale = Vector3(1.3, 0.45, 1.0)
		_add_sphere(self, 0.5, OceanStyle.glow(OceanStyle.GLOW, 2.0), Vector3(0.0, 0.6, 1.5))
		_add_light(self, OceanStyle.GLOW, 0.8, 5.0)

	func _process(delta: float) -> void:
		_time += delta
		var openness := 0.5 + 0.5 * sin(_time * TAU / period)
		_top.rotation.x = deg_to_rad(-8.0 - openness * 30.0)
		_bottom.rotation.x = deg_to_rad(8.0 + openness * 6.0)


## Abanico de coral: aspas vivas que giran y empujan al rozarlas.
class CoralFan extends OceanHazard:
	var spin_speed: float = 1.7
	var blade_count: int = 6

	var _rotor: Node3D

	func _ready() -> void:
		touch_kind = "kill"
		_setup(Vector3(7.4, 7.4, 1.8), 7.0, 0.4)
		_rotor = Node3D.new()
		add_child(_rotor)
		for i in blade_count:
			var pivot := Node3D.new()
			pivot.rotation.z = TAU * float(i) / float(blade_count)
			_rotor.add_child(pivot)
			_add_box(pivot, Vector3(0.5, 3.2, 0.34),
				OceanStyle.matte(OceanStyle.CORAL, 0.5), Vector3(0.0, 1.55, 0.0))
			_add_sphere(pivot, 0.2, OceanStyle.glow(OceanStyle.CORAL_ALT, 1.5),
				Vector3(0.0, 3.1, 0.0))
		_add_sphere(self, 0.62, OceanStyle.glow(OceanStyle.GLOW, 1.9), Vector3.ZERO)
		_add_light(self, OceanStyle.CORAL_ALT, 0.8, 6.0)

	func _process(delta: float) -> void:
		_rotor.rotate_z(delta * spin_speed)


## Chimenea térmica: sopla una columna de agua caliente que sube de golpe.
class ThermalVent extends OceanHazard:
	var cycle: float = 3.4

	var _time: float = 0.0
	var _jet: Node3D
	var _light: OmniLight3D
	var _bubbles: CPUParticles3D

	func _ready() -> void:
		_setup(Vector3(3.4, 16.0, 3.4))
		_add_box(self, Vector3(2.0, 1.2, 2.0), OceanStyle.matte(OceanStyle.ROCK_DARK),
			Vector3(0.0, -7.4, 0.0))
		_jet = Node3D.new()
		add_child(_jet)
		for i in 6:
			_add_sphere(_jet, 0.5 - float(i) * 0.05,
				OceanStyle.additive(OceanStyle.CORAL_ALT, 0.16),
				Vector3(sin(float(i) * 1.7) * 0.4, -6.0 + float(i) * 2.4, cos(float(i) * 2.1) * 0.4))
		_light = _add_light(self, OceanStyle.CORAL_ALT, 1.4, 9.0)

		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = 0.14
		bubble_mesh.height = 0.28
		bubble_mesh.radial_segments = 6
		bubble_mesh.rings = 3
		bubble_mesh.material = OceanStyle.glass(OceanStyle.CORAL_ALT, 0.5)
		_bubbles = CPUParticles3D.new()
		_bubbles.amount = 60
		_bubbles.lifetime = 2.4
		_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_bubbles.emission_sphere_radius = 1.0
		_bubbles.position = Vector3(0.0, -7.0, 0.0)
		_bubbles.direction = Vector3.UP
		_bubbles.spread = 18.0
		_bubbles.gravity = Vector3(0.0, 7.0, 0.0)
		_bubbles.initial_velocity_min = 3.0
		_bubbles.initial_velocity_max = 7.0
		_bubbles.scale_amount_min = 0.5
		_bubbles.scale_amount_max = 1.6
		_bubbles.color = Color(1.0, 0.75, 0.45, 0.8)
		_bubbles.mesh = bubble_mesh
		_bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_bubbles)

	func _physics_process(delta: float) -> void:
		_time += delta
		var active := fmod(_time, cycle) < cycle * 0.45
		_jet.visible = active
		_bubbles.emitting = active
		_light.light_energy = 1.6 if active else 0.3
		if active:
			_push_field(Vector3.UP * 8.5)


## Témpano a la deriva: un bloque de hielo que cruza el pasillo de lado a lado.
class DriftIce extends OceanHazard:
	var travel: float = 8.0
	var speed: float = 1.15

	var _base_x: float = 0.0
	var _time: float = 0.0

	func _ready() -> void:
		touch_kind = "push"
		push_force = 13.0
		_setup(Vector3(4.4, 3.4, 4.4), 8.0, 0.45)
		_base_x = position.x
		_add_sphere(self, 1.5, OceanStyle.glass(OceanStyle.ICE, 0.75), Vector3.ZERO)
		_add_box(self, Vector3(2.4, 1.4, 2.4), OceanStyle.glass(OceanStyle.ICE, 0.55), Vector3(0.2, 0.9, 0.0))
		_add_sphere(self, 0.9, OceanStyle.glass(OceanStyle.ICE, 0.65), Vector3(-1.2, -0.7, 0.9))
		_add_light(self, OceanStyle.ICE, 0.6, 5.0)

	func _process(delta: float) -> void:
		_time += delta
		position.x = _base_x + sin(_time * speed) * travel
		rotation.y += delta * 0.25


## Nube de tinta: una masa oscura que aturde más que el resto.
class InkCloud extends OceanHazard:
	var radius: float = 2.4

	var _time: float = 0.0
	var _puffs: Array[MeshInstance3D] = []

	func _ready() -> void:
		touch_kind = "kill"
		_setup(Vector3(5.6, 5.6, 5.6), 3.4, 0.9)
		for i in 7:
			var angle := float(i) * TAU / 7.0
			var puff := _add_sphere(self, 1.05 + float(i % 3) * 0.22,
				OceanStyle.glass(OceanStyle.INK, 0.55),
				Vector3(cos(angle) * 0.75, sin(angle * 1.7) * 0.65, sin(angle) * 0.75))
			_puffs.append(puff)
		_add_light(self, OceanStyle.CORAL_PURPLE, 0.5, 5.0)

	func _process(delta: float) -> void:
		_time += delta
		for i in _puffs.size():
			var puff := _puffs[i]
			puff.position.x = cos(float(i) * 0.9 + _time * 0.7) * 0.8
			puff.position.y = sin(float(i) * 1.3 + _time * 0.5) * 0.7
			var scale_value := 0.9 + 0.2 * sin(_time * 1.6 + float(i))
			puff.scale = Vector3.ONE * scale_value


## Cadena de minas: una fila de esferas brillantes que hay que esquivar.
class MineChain extends OceanHazard:
	var count: int = 6
	var span: float = 13.0

	var _time: float = 0.0
	var _mines: Array[Node3D] = []

	func _ready() -> void:
		touch_kind = "kill"
		_setup(Vector3(span, 2.8, 2.8), 7.5, 0.5)
		for i in count:
			var mine := Node3D.new()
			mine.position = Vector3(-span * 0.5 + float(i) * span / float(maxi(count - 1, 1)), 0.0, 0.0)
			add_child(mine)
			_add_sphere(mine, 0.28, OceanStyle.glow(OceanStyle.CORAL_ALT, 2.0), Vector3.ZERO)
			_add_sphere(mine, 0.5, OceanStyle.additive(OceanStyle.CORAL_ALT, 0.14), Vector3.ZERO)
			_mines.append(mine)

	func _process(delta: float) -> void:
		_time += delta
		for i in _mines.size():
			_mines[i].position.y = sin(_time * 1.4 + float(i) * 0.7) * 0.55


## Estrella de mar giratoria: cinco brazos que barren el carril.
class StarfishSpinner extends OceanHazard:
	var spin_speed: float = 2.0

	var _star: Node3D

	func _ready() -> void:
		touch_kind = "push"
		push_force = 12.0
		_setup(Vector3(6.6, 6.6, 2.0), 8.0, 0.45)
		_star = Node3D.new()
		add_child(_star)
		for i in 5:
			var arm := Node3D.new()
			arm.rotation.z = TAU * float(i) / 5.0
			_star.add_child(arm)
			_add_box(arm, Vector3(0.6, 2.9, 0.45), OceanStyle.matte(OceanStyle.CORAL_ALT, 0.5),
				Vector3(0.0, 1.5, 0.0))
			_add_sphere(arm, 0.24, OceanStyle.glow(OceanStyle.CORAL, 1.5), Vector3(0.0, 2.9, 0.0))
		_add_sphere(self, 0.7, OceanStyle.glow(OceanStyle.CORAL, 1.9), Vector3.ZERO)
		_add_light(self, OceanStyle.CORAL_ALT, 0.9, 6.5)

	func _process(delta: float) -> void:
		_star.rotate_z(delta * spin_speed)
