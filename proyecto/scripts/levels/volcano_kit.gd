extends "res://scripts/levels/level_kit.gd"

## Lava Vortex (ronda 4): espiral alrededor de una montaña, lava que sube,
## géiseres y lluvia de meteoros. También controla la cámara del circuito.

## Volcán: círculo, vueltas y subida por segmento.

const V_CENTER := Vector3(0.0, 0.0, -90.0)

const V_RADIUS := 18.0

## La espiral se acortó al 80 % (144 -> 116 tramos): sigue teniendo cuatro
## vueltas y pico, pero se hace bastante más corta.
const V_SEGMENTS := 116

const V_PER_TURN := 28

const V_RISE := 0.7

const V_START_TOP := 1.05

const V_HALF_WIDTH := 4.0

const V_DECK_THICKNESS := 0.45

## Cortes de la espiral en tramos continuos. Los huecos 36, 72 y 108 son los
## tres saltos; cada tramo se construye como una sola malla, sin escalones.
const V_DECK_SECTIONS := [[0, 36], [37, 72], [73, 108], [109, 116]]

## Segmentos que se dejan sin plataforma: tres saltos sobre la lava.
const V_GAPS := [36, 72, 108]

## Muelle de la cámara del volcán. Amortiguación crítica (sin rebote): el giro
## arranca y frena solo, así pasa de una recta a la curva siguiente sin tirones.
const YAW_SPRING := 42.0

const YAW_DAMPING := 13.0

const PITCH_SPRING := 34.0

const PITCH_DAMPING := 11.7

const ROLL_SPRING := 26.0

const ROLL_DAMPING := 10.2

## Giro automático de cámara en Lava Vortex. Desactivado: ahora el ratón manda
## sobre el encuadre (ver `player.gd`). Se conserva el código por si se quiere
## recuperar el seguimiento de la espiral.
const CAMERA_FOLLOW_TRACK := false

## Metros de pista que la cámara mira por delante del corredor.
const CAMERA_LOOK_AHEAD := 9.0

var _camera_spring: SpringArm3D

var _camera_base_pitch: float = 0.0

## Inclinación de la rampa del volcán y subida por metro. Sirven para apoyar
## los obstáculos planos en la cuesta en vez de dejarlos medio flotando.
var _ramp_slope: float = 0.0

var _ramp_rise_per_meter: float = 0.0

var _yaw_velocity: float = 0.0

var _pitch_velocity: float = 0.0

var _roll: float = 0.0

var _roll_velocity: float = 0.0

var _basalt: ShaderMaterial

var _basalt_hot: ShaderMaterial

var _volcano_rock: StandardMaterial3D

var _volcano_glow: StandardMaterial3D

var _volcano_spike: StandardMaterial3D

var _volcano_red: StandardMaterial3D

var _spiral_deck: StandardMaterial3D

var _spiral_rail: StandardMaterial3D


## La cámara del jugador sigue la pista por delante de la espiral. Es una ayuda
## de control: el stick hacia delante sigue la cuesta en vez de salirse por
## fuera, y el encuadre queda centrado en el tramo que sube.
func follow_camera(delta: float) -> void:
	if not CAMERA_FOLLOW_TRACK or Engine.is_editor_hint():
		return
	var player := host.get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot == null:
		return
	if _camera_spring == null:
		_camera_spring = player.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
		if _camera_spring != null:
			_camera_base_pitch = _camera_spring.rotation.x
	# En la recta de salida (aún fuera del círculo) la cámara mira al frente;
	# al entrar en la espiral sigue la tangente. El muelle llega antes que un
	# lerp lento y no corta el giro: siempre se ve la pista recta delante.
	var inside := player.global_position.z <= V_CENTER.z + 0.5
	var target_yaw := _path_yaw_at(player.global_position)
	var yaw_error := wrapf(target_yaw - pivot.rotation.y, -PI, PI)
	_yaw_velocity += yaw_error * YAW_SPRING * delta
	_yaw_velocity *= exp(-YAW_DAMPING * delta)
	pivot.rotation.y = wrapf(pivot.rotation.y + _yaw_velocity * delta, -PI, PI)
	if _camera_spring != null:
		# La pista sube: la cámara inclina el encuadre con la cuesta. Antes
		# compensaba solo el 40 %, así que en las rampas parecía ir recta.
		var target_pitch := _camera_base_pitch + _ramp_slope if inside else _camera_base_pitch
		_pitch_velocity += (target_pitch - _camera_spring.rotation.x) * PITCH_SPRING * delta
		_pitch_velocity *= exp(-PITCH_DAMPING * delta)
		_camera_spring.rotation.x += _pitch_velocity * delta
		# Sin alabeo: el horizonte se queda plano y la cuesta se ve de frente en
		# vez de inclinada hacia un lado al trazar la curva.
		_roll_velocity += (0.0 - _roll) * ROLL_SPRING * delta
		_roll_velocity *= exp(-ROLL_DAMPING * delta)
		_roll = clampf(_roll + _roll_velocity * delta, -0.1, 0.1)
		_camera_spring.rotation.z = _roll


## Rumbo de la cámara tomado de la propia ruta, no del ángulo polar. Apunta a
## un punto unos metros por delante: así el tramo que sube queda centrado en
## pantalla en vez de escorarse hacia un lado al entrar en la curva. En la
## cumbre el jugador ya no está sobre el círculo y la tangente del último tramo
## mantiene el encuadre hasta la meta.
func _path_yaw_at(position: Vector3) -> float:
	if _path.size() < 2:
		return 0.0
	var best := 0
	var best_distance := INF
	for i in _path.size():
		var dx := _path[i].x - position.x
		var dy := _path[i].y - position.y
		var dz := _path[i].z - position.z
		# La espiral pasa varias veces por el mismo sitio: sin la altura se
		# elegiría un punto de otra vuelta.
		var d := dx * dx + dz * dz + dy * dy * 2.0
		if d < best_distance:
			best_distance = d
			best = i
	var aim := _path[best]
	var travelled := 0.0
	var index := best
	while index < _path.size() - 1 and travelled < CAMERA_LOOK_AHEAD:
		travelled += _path[index].distance_to(_path[index + 1])
		index += 1
		aim = _path[index]
	var dir := Vector2(aim.x - position.x, aim.z - position.z)
	if dir.length_squared() < 0.25:
		# Ya no queda pista por delante: se usa la tangente final.
		var a := _path[maxi(best - 1, 0)]
		var b := _path[mini(best + 1, _path.size() - 1)]
		dir = Vector2(b.x - a.x, b.z - a.z)
	if dir.length_squared() < 0.0001:
		return 0.0
	return atan2(-dir.x, -dir.y)


# --------------------------------------------------------------- materiales


func _make_volcano_palette() -> void:
	_basalt = _platform_mat(
		Color(0.16, 0.07, 0.06), Color(1.0, 0.5, 0.12), Color(0.03, 0.015, 0.015), 0.5
	)
	_basalt_hot = _platform_mat(
		Color(0.24, 0.09, 0.04), Color(1.0, 0.68, 0.22), Color(0.05, 0.02, 0.01), 0.62
	)
	_volcano_rock = _rock_mat(Color(0.09, 0.05, 0.045), Color(0.8, 0.18, 0.03), 0.55)
	_volcano_glow = _glow_mat(Color(1.0, 0.38, 0.06), 3.0)
	# Pinchos de basalto incandescente: encajan con la roca volcánica.
	_volcano_spike = _glow_mat(Color(0.5, 0.18, 0.08), 0.6, 0.32)
	_spiral_deck = StandardMaterial3D.new()
	_spiral_deck.vertex_color_use_as_albedo = true
	_spiral_deck.albedo_color = Color.WHITE
	_spiral_deck.roughness = 0.84
	_spiral_deck.metallic = 0.18
	_spiral_deck.cull_mode = BaseMaterial3D.CULL_DISABLED
	_spiral_deck.emission_enabled = true
	_spiral_deck.emission = Color(0.32, 0.075, 0.02)
	_spiral_deck.emission_energy_multiplier = 0.35
	_spiral_rail = _glow_mat(Color(1.0, 0.4, 0.07), 3.2, 0.4)
	_spiral_rail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spiral_rail.cull_mode = BaseMaterial3D.CULL_DISABLED


# ---------------------------------------------------------------- escenario


## Punto del borde de la espiral. `radial` va de -V_HALF_WIDTH (interior)
## a +V_HALF_WIDTH (exterior) y la altura sigue la subida lineal del circuito.
func _spiral_ring(seg: int, radial: float, y_offset: float = 0.0) -> Vector3:
	var angle := PI + float(seg) * (TAU / float(V_PER_TURN))
	var radius := V_RADIUS + radial
	return Vector3(
		V_CENTER.x + cos(angle) * radius,
		V_START_TOP + float(seg) * V_RISE + y_offset,
		V_CENTER.z + sin(angle) * radius
	)


func _deck_tri(
	st: SurfaceTool, faces: Array, a: Vector3, b: Vector3, c: Vector3, color: Color
) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
	faces.append(a)
	faces.append(b)
	faces.append(c)


func _deck_quad(
	st: SurfaceTool, faces: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color
) -> void:
	_deck_tri(st, faces, a, b, c, color)
	_deck_tri(st, faces, a, c, d, color)


## Una sección de la espiral como una única malla continua. Antes cada tramo
## era una caja girada: en el borde interior las cajas se cruzaban y formaban
## rebordes que parecían plataformas y obligaban a saltar cada pocos metros.
func _spiral_deck_section(parent: Node3D, node_name: String, start_seg: int, end_seg: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = []
	var top_in: Array[Vector3] = []
	var top_out: Array[Vector3] = []
	var bot_in: Array[Vector3] = []
	var bot_out: Array[Vector3] = []
	var colors: Array[Color] = []
	var rings := end_seg - start_seg + 1
	for j in rings:
		var seg := start_seg + j
		top_in.append(_spiral_ring(seg, -V_HALF_WIDTH))
		top_out.append(_spiral_ring(seg, V_HALF_WIDTH))
		bot_in.append(_spiral_ring(seg, -V_HALF_WIDTH, -V_DECK_THICKNESS))
		bot_out.append(_spiral_ring(seg, V_HALF_WIDTH, -V_DECK_THICKNESS))
		var heat := 0.5 + 0.5 * sin(float(seg) * 0.61)
		colors.append(Color(0.07, 0.042, 0.036).lerp(Color(0.2, 0.075, 0.035), heat * 0.6))

	for j in rings - 1:
		var k := j + 1
		var top_color := colors[j]
		var side_color := colors[j].darkened(0.35)
		_deck_quad(st, faces, top_in[j], top_out[j], top_out[k], top_in[k], top_color)
		_deck_quad(st, faces, bot_in[k], bot_out[k], bot_out[j], bot_in[j], side_color)
		_deck_quad(st, faces, top_out[j], bot_out[j], bot_out[k], top_out[k], side_color)
		_deck_quad(st, faces, top_in[k], bot_in[k], bot_in[j], top_in[j], side_color)

	# Tapas de los extremos: los tres huecos quedan limpios y fáciles de leer.
	var last := rings - 1
	_deck_quad(st, faces, top_in[0], bot_in[0], bot_out[0], top_out[0], colors[0].darkened(0.25))
	_deck_quad(
		st,
		faces,
		top_in[last],
		top_out[last],
		bot_out[last],
		bot_in[last],
		colors[last].darkened(0.25)
	)

	st.generate_normals()
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	instance.material_override = _spiral_deck
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(instance)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(PackedVector3Array(faces))
	# La malla es de doble cara: así ninguna cara de la rampa deja huecos al
	# personaje aunque caiga justo en un borde.
	concave.backface_collision = true
	shape_node.shape = concave
	body.add_child(shape_node)
	parent.add_child(body)


## Borde luminoso de la pista. No tiene colisión: solo marca el límite y hace
## que la espiral se lea de un vistazo. Se corta en los tres saltos.
func _spiral_ribbon(
	parent: Node3D,
	node_name: String,
	radial: float,
	width: float,
	y_offset: float,
	material: Material
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in V_SEGMENTS:
		if seg in V_GAPS:
			continue
		var a0 := _spiral_ring(seg, radial - width * 0.5, y_offset)
		var a1 := _spiral_ring(seg, radial + width * 0.5, y_offset)
		var b0 := _spiral_ring(seg + 1, radial - width * 0.5, y_offset)
		var b1 := _spiral_ring(seg + 1, radial + width * 0.5, y_offset)
		st.add_vertex(a0)
		st.add_vertex(a1)
		st.add_vertex(b1)
		st.add_vertex(a0)
		st.add_vertex(b1)
		st.add_vertex(b0)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = st.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _build_spiral_deck(course: Node3D) -> void:
	for i in V_DECK_SECTIONS.size():
		var section: Array = V_DECK_SECTIONS[i]
		_spiral_deck_section(course, "SpiralDeck%d" % i, int(section[0]), int(section[1]))
	_spiral_ribbon(course, "InnerRail", -V_HALF_WIDTH + 0.12, 0.24, 0.045, _spiral_rail)
	_spiral_ribbon(course, "OuterRail", V_HALF_WIDTH - 0.12, 0.24, 0.045, _spiral_rail)


## ¿Está libre ese adorno del volcán? Ni sobre la plataforma de salida ni sobre
## el ancho de la espiral a la altura que le toca: eran las «montañas» que
## salían dentro de la losa de salida y tapaban la vista de la pista.
func _volcano_clear(x: float, z: float, radius: float, y0: float, y1: float) -> bool:
	# Plataforma de salida: centrada en x = -18, 12 x 40.
	if (
		absf(x + 18.0) < 6.0 + radius + 0.8
		and absf(z + 75.0) < 20.0 + radius + 0.8
		and y1 > V_START_TOP - 0.8
		and y0 < V_START_TOP + 4.5
	):
		return false
	# Anillo de la espiral, con un cinturón de aire a cada lado.
	var planar := Vector2(x - V_CENTER.x, z - V_CENTER.z)
	var distance := planar.length()
	if (
		distance + radius < V_RADIUS - V_HALF_WIDTH - 0.8
		or distance - radius > V_RADIUS + V_HALF_WIDTH + 0.8
	):
		return true
	var step_angle := TAU / float(V_PER_TURN)
	var base_seg := (atan2(planar.y, planar.x) - PI) / step_angle
	var turns := ceili(float(V_SEGMENTS) / float(V_PER_TURN)) + 1
	for turn in turns:
		var index := base_seg + float(turn * V_PER_TURN)
		if index < 0.0 or index > float(V_SEGMENTS):
			continue
		var deck_top := V_START_TOP + index * V_RISE
		if y1 > deck_top - 0.6 and y0 < deck_top + 3.6:
			return false
	return true


func _build_volcano() -> void:
	_path.clear()
	_widths.clear()
	_make_volcano_palette()
	# Pendiente de la rampa: con ella se tumban los obstáculos y las luces de
	# la pista para que queden apoyados, no de pie sobre una cuesta.
	var ramp_chord := (TAU / float(V_PER_TURN)) * V_RADIUS
	_ramp_slope = atan2(V_RISE, ramp_chord)
	_ramp_rise_per_meter = V_RISE / ramp_chord
	var cfg := {
		"sky_top": Color(0.05, 0.025, 0.025),
		"sky_horizon": Color(0.6, 0.17, 0.04),
		"sky_ground": Color(0.16, 0.02, 0.0),
		"cloud_color": Color(0.28, 0.08, 0.04),
		"sun_color": Color(1.0, 0.52, 0.2),
		"ambient": Color(0.95, 0.4, 0.18),
		"ambient_energy": 0.6,
		"fog": Color(0.45, 0.1, 0.03),
		"fog_density": 0.0032,
		"exposure": 0.95,
		"saturation": 1.05,
		"sun_pitch": -24.0,
		"sun_yaw": -62.0,
		"sun_energy": 1.25,
		"fill": Color(0.65, 0.16, 0.25),
		"fill_energy": 0.55,
		"cloud_opacity": 0.6,
		"cloud_scale": 3.2,
		"dome_z": -90.0,
	}
	_add_environment(cfg)
	_add_lights(cfg)
	_add_sky(cfg)

	var course := Node3D.new()
	course.name = "Course"
	host.add_child(course)

	# Salida recta: alinea al corredor con la cámara antes de entrar al círculo.
	# La plataforma va centrada con la entrada de la espiral (x = -18): antes
	# estaba corrida a la izquierda y se salía por un lado de la pista.
	_slab_top(course, "StartPlatform", -18.0, -75.0, 12.0, 40.0, V_START_TOP, _basalt)
	_path_add(Vector3(-18.0, V_START_TOP, -66.0), Vector3(-18.0, V_START_TOP, -91.0), 3.2)

	var step_angle := TAU / float(V_PER_TURN)
	var spiral_length := 0.0
	for i in V_SEGMENTS:
		var a0 := PI + float(i) * step_angle
		var a1 := a0 + step_angle
		var p0 := Vector3(V_CENTER.x + cos(a0) * V_RADIUS, 0.0, V_CENTER.z + sin(a0) * V_RADIUS)
		var p1 := Vector3(V_CENTER.x + cos(a1) * V_RADIUS, 0.0, V_CENTER.z + sin(a1) * V_RADIUS)
		var chord := p0.distance_to(p1)
		spiral_length += chord
		var top_mid := V_START_TOP + (float(i) + 0.5) * V_RISE
		var point := Vector3((p0.x + p1.x) * 0.5, top_mid, (p0.z + p1.z) * 0.5)
		_path.append(point + Vector3.UP * 0.35)
		_widths.append(2.4)

	var end_angle := PI + float(V_SEGMENTS) * step_angle
	var end_top := V_START_TOP + float(V_SEGMENTS) * V_RISE
	var end_position := Vector3(
		V_CENTER.x + cos(end_angle) * V_RADIUS, end_top, V_CENTER.z + sin(end_angle) * V_RADIUS
	)
	# La cumbre sigue la tangente de la espiral: la cámara ya apunta ahí, así
	# que la recta final no obliga a girar 90 grados de golpe.
	var end_tangent := Vector3(-sin(end_angle), 0.0, cos(end_angle))
	var summit := end_position + end_tangent * 7.0
	_path_add(end_position, summit + end_tangent * 3.0, 3.4)

	_slab_top(course, "SummitPlatform", summit.x, summit.z, 18.0, 18.0, end_top, _basalt_hot)
	_build_spiral_deck(course)

	# Marcas de peligro en los tres saltos.
	for gap in V_GAPS:
		var sample := _spiral_sample(gap)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		var tangent := Vector3(-sin(sample_angle), 0.0, cos(sample_angle))
		for side in [-1.0, 1.0]:
			_mesh_box(
				course,
				"GapWarning%d_%d" % [gap, int(side)],
				sample_position + tangent * side * 1.9 + Vector3.UP * 0.03,
				Vector3(8.0, 0.06, 0.4),
				_volcano_glow,
				Vector3(0.0, -rad_to_deg(sample_angle), 0.0)
			)

	# --- montaña, vetas y pináculos --------------------------------------
	var decor := Node3D.new()
	decor.name = "Decor"
	host.add_child(decor)
	_arch(
		decor,
		"StartGate",
		Vector3(-18.0, V_START_TOP, -80.0),
		12.0,
		6.0,
		_volcano_rock,
		_volcano_glow,
		"LAVA VORTEX"
	)
	# Sin cono central: el volcán arrancaba pegado a la salida y tapaba la
	# primera recta con su ladera. El hueco del centro lo llena el mar de lava,
	# así que el vórtice se lee mejor y la vista queda despejada.
	for i in 16:
		var angle := TAU * float(i) / 16.0 + 0.19
		var distance := 32.0 + float(i % 4) * 6.0
		var height := 12.0 + float(i % 5) * 6.0
		var spire_x := cos(angle) * distance
		var spire_z := V_CENTER.z + sin(angle) * distance
		if not _volcano_clear(spire_x, spire_z, 2.2 + float(i % 3), -16.0, -16.0 + height):
			continue
		_mesh_cylinder(
			decor,
			"ObsidianSpire%d" % i,
			Vector3(spire_x, -16.0 + height * 0.5, spire_z),
			0.0,
			2.2 + float(i % 3),
			height,
			_volcano_rock,
			Vector3(0.0, float(i) * 11.0, 0.0)
		)
	for i in 12:
		var angle := PI + float(i) * (TAU * 1.15 / 12.0)
		var height := V_START_TOP + float(i) * 8.0
		var light := OmniLight3D.new()
		light.name = "SpiralLight%d" % i
		light.position = Vector3(
			V_CENTER.x + cos(angle) * V_RADIUS, height + 3.0, V_CENTER.z + sin(angle) * V_RADIUS
		)
		# Cada vuelta tiene su propia temperatura de luz (naranja, ámbar, rojo),
		# así no se ve la misma espiral repetida seis veces.
		light.light_color = Color(1.0, 0.34 + float(i % 3) * 0.1, 0.1)
		light.light_energy = 1.6 + float(i % 4) * 0.22
		light.omni_range = 16.0 + float(i % 3) * 2.5
		light.shadow_enabled = false
		decor.add_child(light)

	# Esquirlas de obsidiana flotando alrededor de la montaña: más vida al fondo
	# de cada vuelta, siempre fuera de la trazada.
	for i in 6:
		var shard_angle := PI + float(i) * (TAU * 1.05 / 6.0) + 0.4
		var shard_distance := 26.0 + float(i % 3) * 7.0
		var shard_height := 22.0 + float(i) * 9.0
		var shard := _spiral_sample(6 + i * 20)
		var shard_top: float = shard["top"]
		_mesh_cylinder(
			decor,
			"ObsidianShard%d" % i,
			Vector3(
				V_CENTER.x + cos(shard_angle) * shard_distance,
				shard_top + shard_height,
				V_CENTER.z + sin(shard_angle) * shard_distance
			),
			0.0,
			1.6 + float(i % 3) * 0.7,
			7.0 + float(i % 4) * 2.5,
			_volcano_rock,
			Vector3(float(i % 5) * 12.0, float(i) * 31.0, 0.0),
			6
		)

	# Volcanes lejanos: dan profundidad al horizonte sin tocar la pista.
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.33
		var distance := 175.0 + float(i % 3) * 32.0
		var height := 42.0 + float(i % 4) * 16.0
		_mesh_cylinder(
			decor,
			"DistantPeak%d" % i,
			Vector3(
				cos(angle) * distance, -18.0 + height * 0.5, V_CENTER.z + sin(angle) * distance
			),
			0.0,
			26.0 + float(i % 3) * 5.0,
			height,
			_volcano_rock,
			Vector3(0.0, float(i) * 37.0, 0.0)
		)

	# Ceniza y chispas flotando alrededor de la montaña.
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.08
	ember_mesh.height = 0.16
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color(1.0, 0.58, 0.12)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.3, 0.02)
	ember_material.emission_energy_multiplier = 2.6
	ember_mesh.material = ember_material
	var embers := CPUParticles3D.new()
	embers.name = "VolcanoEmbers"
	embers.amount = 260
	embers.lifetime = 10.0
	embers.preprocess = 5.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(42.0, 55.0, 42.0)
	embers.position = Vector3(V_CENTER.x, 55.0, V_CENTER.z)
	embers.direction = Vector3(0.0, 1.0, 0.0)
	embers.spread = 60.0
	embers.gravity = Vector3(0.0, 1.4, 0.0)
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 3.4
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 1.6
	embers.color = Color(1.0, 0.85, 0.6, 0.9)
	embers.mesh = ember_mesh
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(embers)

	# --- decoración extra: basalto, cascadas y antorchas ------------------
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var radius := 27.0 + float(i % 3) * 6.0
		var height := 14.0 + float(i % 4) * 7.0
		var column_x := V_CENTER.x + cos(angle) * radius
		var column_z := V_CENTER.z + sin(angle) * radius
		if not _volcano_clear(column_x, column_z, 2.4 + float(i % 3) * 0.8, -6.0, height - 6.0):
			continue
		_mesh_cylinder(
			decor,
			"BasaltColumn%d" % i,
			Vector3(column_x, height * 0.5 - 6.0, column_z),
			0.9,
			2.4 + float(i % 3) * 0.8,
			height,
			_volcano_rock,
			Vector3(0.0, float(i) * 17.0, 0.0),
			6
		)
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.4
		_mesh_box(
			decor,
			"LavaFall%d" % i,
			Vector3(
				V_CENTER.x + cos(angle) * 24.0,
				30.0 + float(i % 3) * 12.0,
				V_CENTER.z + sin(angle) * 24.0
			),
			Vector3(2.2, 26.0, 0.5),
			_volcano_glow,
			Vector3(0.0, rad_to_deg(-angle), 6.0)
		)
	for i in range(6, V_SEGMENTS, 9):
		# Antorchas colgadas de la cara exterior, por debajo de la losa: alumbran
		# la vuelta sin meterse delante de la cámara.
		var rail := _spiral_ring(i, V_HALF_WIDTH + 0.35, -0.5)
		_mesh_cylinder(
			decor,
			"TorchPost%d" % i,
			rail + Vector3.DOWN * 0.7,
			0.22,
			0.08,
			1.3,
			_volcano_rock,
			Vector3.ZERO,
			6
		)
		_mesh_sphere(decor, "TorchFlame%d" % i, rail + Vector3.DOWN * 1.3, 0.24, _volcano_glow)
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var height := 6.0 + float(i % 5) * 14.0
		var shard_x := V_CENTER.x + cos(angle) * (34.0 + float(i % 4) * 5.0)
		var shard_z := V_CENTER.z + sin(angle) * (34.0 + float(i % 4) * 5.0)
		if not _volcano_clear(shard_x, shard_z, 0.6, height - 1.8, height + 1.8):
			continue
		_mesh_box(
			decor,
			"ObsidianShard%d" % i,
			Vector3(shard_x, height, shard_z),
			Vector3(1.2, 3.6, 0.8),
			_volcano_rock,
			Vector3(float(i) * 23.0, float(i) * 31.0, 12.0)
		)

	# --- atrezo de detalle: arcos, islas, braseros, humo y colosos ---------
	for i in 8:
		var seg := 8 + i * 13
		var arch_sample := _spiral_sample(seg)
		var arch_pos: Vector3 = arch_sample["position"]
		var arch_angle: float = arch_sample["angle"]
		var arch_basis := Basis(Vector3.UP, -arch_angle)
		for side in [-1.0, 1.0]:
			_mesh_box(
				decor,
				"BasaltArchPost%d_%d" % [i, int(side)],
				arch_pos + arch_basis * Vector3(side * 6.2, 3.8, 0.0),
				Vector3(0.9, 7.6, 0.9),
				_volcano_rock,
				Vector3(0.0, rad_to_deg(-arch_angle), 0.0)
			)
		_mesh_box(
			decor,
			"BasaltArchBeam%d" % i,
			arch_pos + Vector3.UP * 7.7,
			Vector3(13.4, 0.6, 0.8),
			_volcano_rock,
			Vector3(0.0, rad_to_deg(-arch_angle), 0.0)
		)
		_mesh_box(
			decor,
			"BasaltArchGlow%d" % i,
			arch_pos + Vector3.UP * 7.35,
			Vector3(12.6, 0.12, 0.14),
			_volcano_glow,
			Vector3(0.0, rad_to_deg(-arch_angle), 0.0)
		)
	for i in range(4, V_SEGMENTS, 6):
		# Braseros colgados del borde interior: antes flotaban metro y medio
		# sobre la pista y tapaban la vista al ir por dentro.
		var rail_pos := _spiral_ring(i, -V_HALF_WIDTH - 0.25, -0.5)
		_mesh_cylinder(
			decor,
			"Brazier%d" % i,
			rail_pos + Vector3.DOWN * 0.55,
			0.34,
			0.06,
			0.95,
			_volcano_rock,
			Vector3.ZERO,
			6
		)
		_mesh_sphere(decor, "BrazierFire%d" % i, rail_pos + Vector3.DOWN * 1.05, 0.3, _volcano_glow)
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.3
		var radius := 40.0 + float(i % 3) * 9.0
		var height := 12.0 + float(i % 4) * 14.0
		var island_pos := Vector3(
			V_CENTER.x + cos(angle) * radius, height, V_CENTER.z + sin(angle) * radius
		)
		if not _volcano_clear(island_pos.x, island_pos.z, 4.4, height - 0.8, height + 0.8):
			continue
		_mesh_cylinder(
			decor, "FloatIsland%d" % i, island_pos, 2.6, 4.4, 1.6, _volcano_rock, Vector3.ZERO, 7
		)
		_mesh_cylinder(
			decor,
			"FloatIslandLava%d" % i,
			island_pos + Vector3.UP * 0.9,
			2.2,
			2.8,
			0.2,
			_volcano_glow,
			Vector3.ZERO,
			7
		)
	for i in 40:
		var angle := float(i) * 2.39996
		var radius := 8.0 + float(i % 11) * 4.5
		_mesh_sphere(
			decor,
			"LavaBubble%d" % i,
			Vector3(V_CENTER.x + cos(angle) * radius, -7.6, V_CENTER.z + sin(angle) * radius),
			0.4 + float(i % 3) * 0.2,
			_volcano_glow
		)
	for i in 2:
		var angle := PI * 0.5 + float(i) * PI
		var base := Vector3(V_CENTER.x + cos(angle) * 30.0, 0.0, V_CENTER.z + sin(angle) * 30.0)
		_mesh_cylinder(
			decor,
			"ColossusLegs%d" % i,
			base + Vector3.UP * 6.0,
			1.2,
			2.0,
			12.0,
			_volcano_rock,
			Vector3.ZERO,
			7
		)
		_mesh_sphere(decor, "ColossusTorso%d" % i, base + Vector3.UP * 14.0, 3.0, _volcano_rock)
		_mesh_sphere(decor, "ColossusHead%d" % i, base + Vector3.UP * 18.0, 1.8, _volcano_rock)
		_mesh_sphere(decor, "ColossusEye%d" % i, base + Vector3.UP * 18.3, 0.35, _volcano_glow)

	# --- tercera pasada: detalles pegados a toda la espiral ----------------
	for i in range(9, V_SEGMENTS, 7):
		var edge := _spiral_ring(i, V_HALF_WIDTH - 0.2, 0.02)
		_mesh_box(
			decor,
			"DeckCrack%d" % i,
			edge,
			Vector3(0.5, 0.03, 2.2),
			_volcano_glow,
			Vector3(0.0, 0.0, 12.0)
		)
	for i in range(5, V_SEGMENTS, 11):
		# Banderines colgando de la cara exterior de la losa, no sobre la pista.
		var banner_pos := _spiral_ring(i, V_HALF_WIDTH + 0.3, -0.5)
		_mesh_cylinder(
			decor,
			"BannerRod%d" % i,
			banner_pos + Vector3.DOWN * 1.2,
			0.05,
			0.05,
			2.4,
			_volcano_rock,
			Vector3.ZERO,
			5
		)
		_mesh_box(
			decor,
			"BannerFlag%d" % i,
			banner_pos + Vector3.DOWN * 1.6,
			Vector3(1.0, 1.1, 0.05),
			_volcano_glow,
			Vector3(0.0, float(i) * 23.0, 9.0)
		)
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.7
		var dist := 34.0 + float(i % 3) * 7.0
		var cage_pos := Vector3(
			V_CENTER.x + cos(angle) * dist, 6.0 + float(i % 4) * 8.0, V_CENTER.z + sin(angle) * dist
		)
		if not _volcano_clear(cage_pos.x, cage_pos.z, 0.9, cage_pos.y - 1.2, cage_pos.y + 1.2):
			continue
		_mesh_box(
			decor,
			"FireCage%d" % i,
			cage_pos,
			Vector3(1.2, 2.4, 1.2),
			_volcano_rock,
			Vector3(0.0, float(i) * 23.0, 0.0)
		)
		_mesh_sphere(decor, "FireCageCore%d" % i, cage_pos + Vector3.UP * 0.2, 0.5, _volcano_glow)
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var dist := 55.0 + float(i % 4) * 9.0
		var tall := 30.0 + float(i % 5) * 16.0
		_mesh_cylinder(
			decor,
			"FarVolcano%d" % i,
			Vector3(
				V_CENTER.x + cos(angle) * dist, tall * 0.5 - 10.0, V_CENTER.z + sin(angle) * dist
			),
			0.0,
			9.0 + float(i % 3) * 3.0,
			tall,
			_volcano_rock,
			Vector3(0.0, float(i) * 37.0, 0.0),
			7
		)
		_mesh_sphere(
			decor,
			"FarVolcanoGlow%d" % i,
			Vector3(V_CENTER.x + cos(angle) * dist, tall - 10.0, V_CENTER.z + sin(angle) * dist),
			1.4,
			_volcano_glow
		)

	# --- trampas de la espiral -------------------------------------------
	# Pinchos variados: un sitio lleva 1, otro 2, otro 3 y otro 4, alternando
	# formaciones a lo ancho de la rampa y a lo largo de la subida (en vertical).
	var spike_rng := RandomNumberGenerator.new()
	spike_rng.seed = 20261103
	var spike_segment := 5
	var spike_group := 0
	while spike_segment < V_SEGMENTS - 7:
		var sample := _spiral_sample(spike_segment)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		var tangent := Vector3(-sin(sample_angle), 0.0, cos(sample_angle))
		var radial := Vector3(cos(sample_angle), 0.0, sin(sample_angle))
		# 1, 2, 3 o 4 pinchos en cada punto, distinto en cada tramo.
		var group_size := 1 + (spike_group * 3 + spike_segment) % 4
		# Dos de cada tres formaciones van a lo ancho; la otra, en vertical
		# (a lo largo de la subida).
		var across := spike_group % 3 != 2
		for k in group_size:
			var t := 0.0
			if group_size > 1:
				t = float(k) / float(group_size - 1)
			var along := 0.0
			var lateral := 0.0
			if across:
				lateral = lerpf(-2.7, 2.7, t)
				along = spike_rng.randf_range(-0.6, 0.6)
			else:
				lateral = spike_rng.randf_range(-1.1, 1.1)
				along = lerpf(-2.8, 2.8, t)
			var placement: Vector3 = sample_position + tangent * along + radial * lateral
			placement.y += _ramp_rise_per_meter * along + 0.02
			_obstacle(
				course,
				"Spike%d_%d" % [spike_segment, k],
				SPIKE_SCENE,
				placement,
				{"phase_offset": spike_rng.randf_range(0.0, 6.0), "spike_count": 1},
				-sample_angle,
				-_ramp_slope
			)
		spike_group += 1
		spike_segment += spike_rng.randi_range(3, 5)

	for i in [12, 30, 46, 58, 70, 86, 98]:
		var sample := _spiral_sample(i)
		var sample_position: Vector3 = sample["position"]
		var sample_angle: float = sample["angle"]
		# Cada barrido gira y empuja distinto: ni dos vueltas se sienten iguales.
		_obstacle(
			course,
			"Sweeper%d" % i,
			SWEEPER_SCENE,
			sample_position + Vector3.UP * 0.35,
			{
				"spin_speed": 2.0 + float(i % 3) * 0.4,
				"spin_direction": -1.0 if i % 2 == 0 else 1.0,
				"push_force": 6.2 + float(i % 2) * 0.9,
				"stuns": true,
			},
			-sample_angle,
			-_ramp_slope
		)

	for i in [6, 20, 34, 41, 50, 56, 62, 68, 75, 82, 94, 106, 112]:
		var sample := _spiral_sample(i)
		var sample_position: Vector3 = sample["position"]
		var geyser := GEYSER_SCRIPT.new() as Node3D
		geyser.name = "Geyser%d" % i
		# Alturas distintas por géiser: no todos escupen igual, y así cada vuelta
		# se lee diferente.
		geyser.set("height", 7.0 + float(i % 3) * 1.4)
		geyser.set("radius", 1.3 + float(i % 2) * 0.4)
		geyser.set("phase_offset", float(i) * 0.31)
		geyser.position = sample_position
		course.add_child(geyser)

	# Aspas extra: añaden ritmo sin bloquear el paso, y el bot las espera
	# igual que en el resto de circuitos.
	for i in [24, 40, 68, 92, 108]:
		var rotor_sample := _spiral_sample(i)
		var rotor_position: Vector3 = rotor_sample["position"]
		var rotor_angle: float = rotor_sample["angle"]
		_obstacle(
			course,
			"Rotor%d" % i,
			ROTOR_SCENE,
			rotor_position + Vector3.UP * 0.35,
			{
				"spin_speed": 1.05 + float(i % 3) * 0.12,
				"spin_direction": -1.0 if i % 2 == 0 else 1.0,
				"phase_offset": float(i) * 0.37,
			},
			-rotor_angle,
			-_ramp_slope
		)

	# La final no tiene checkpoints: si la lava te toca, pierdes la carrera. Por
	# eso la espiral añade trampas nuevas. Un pistón en cada pared lateral: salen
	# del borde derecho o del izquierdo y barren el carril de lado, no de frente.
	# Alternan el golpe para dejar paso por el otro lado.
	for i in [54, 74, 88, 101]:
		var piston_sample := _spiral_sample(i)
		var piston_position: Vector3 = piston_sample["position"]
		var piston_angle: float = piston_sample["angle"]
		var radial := Vector3(cos(piston_angle), 0.0, sin(piston_angle))
		for side in [-1.0, 1.0]:
			_obstacle(
				course,
				"SpiralPiston%d_%d" % [i, int(side)],
				PISTON_SCENE,
				piston_position + radial * side * 4.55 + Vector3.UP * 1.2,
				{
					"travel": -radial * side * 4.8,
					"push_force": 6.8,
					"phase_offset": float(i) * 0.23 + (0.0 if side < 0.0 else 1.7),
				}
			)
	# La viga cruza la rampa: las dos patas quedan una a cada lado del carril (a
	# 3,55 m, sobre el borde) y las bolas caen desde tres caños distintos.
	for i in [37, 76, 97, 110]:
		var rain_sample := _spiral_sample(i)
		var rain_position: Vector3 = rain_sample["position"]
		var rain_angle: float = rain_sample["angle"]
		_obstacle(
			course,
			"SpiralRain%d" % i,
			DROPPER_SCENE,
			rain_position + Vector3.UP * 7.0,
			{
				"interval": 1.6 + float(i % 3) * 0.4,
				"drop_radius": 1.0,
				"max_balls": 6,
				"start_delay": 1.6,
				"column_spread": 3.55,
				"chute_count": 3,
				"despawn_below_y": rain_position.y - 14.0,
			},
			-rain_angle,
			-_ramp_slope
		)

	# Arco de basalto con veta de lava en cada vuelta: un hito propio en vez de
	# repetir el mismo paisaje en cada giro.
	for i in [14, 48, 88]:
		var gate_sample := _spiral_sample(i)
		var gate_position: Vector3 = gate_sample["position"]
		var gate_angle: float = gate_sample["angle"]
		var gate_yaw := -rad_to_deg(gate_angle)
		var gate_basis := Basis(Vector3.UP, -gate_angle)
		for side in [-1.0, 1.0]:
			var offset: Vector3 = gate_basis * Vector3(side * 5.8, 0.0, 0.0)
			_mesh_box(
				course,
				"GatePillar%d_%d" % [i, int(side)],
				gate_position + offset + Vector3.UP * 3.6,
				Vector3(0.9, 7.2, 0.9),
				_volcano_rock,
				Vector3(0.0, gate_yaw, 0.0)
			)
		_mesh_box(
			course,
			"GateBeam%d" % i,
			gate_position + Vector3.UP * 7.3,
			Vector3(12.4, 0.7, 0.8),
			_volcano_rock,
			Vector3(0.0, gate_yaw, 0.0)
		)
		_mesh_box(
			course,
			"GateGlow%d" % i,
			gate_position + Vector3.UP * 6.95,
			Vector3(11.2, 0.09, 0.12),
			_volcano_glow,
			Vector3(0.0, gate_yaw, 0.0)
		)

	# Estreno exclusivo del volcán: remolinos de ceniza que arrastran al corredor
	# en espiral. Se pasan corriendo en contra o saltándolos de lado.
	for i in [18, 52, 84]:
		var vortex_sample := _spiral_sample(i)
		var vortex_position: Vector3 = vortex_sample["position"]
		var vortex := ASH_VORTEX_SCRIPT.new() as Node3D
		vortex.name = "AshVortex%d" % i
		# El de la última vuelta tira más fuerte: hay que cruzarlo corriendo.
		vortex.set("radius", 4.2 + float(i % 2) * 0.9)
		# Mucho más suave: antes (9,5 de giro y 3,6 de tirón) te sacaba de la
		# trazada de golpe. Ahora molesta y desvía, pero se puede pelear.
		vortex.set("spin_force", 2.6 + float(i % 3) * 0.35)
		vortex.set("pull_force", 1.1 + float(i % 2) * 0.35)
		vortex.set("ring_speed", 1.6)
		vortex.position = vortex_position + Vector3.UP * 0.15
		course.add_child(vortex)

	# Estreno exclusivo: cortinas de magma que erupcionan en oleada de lado a
	# lado. Hay que leer el pulso y cruzar por los chorros apagados.
	for i in [22, 60, 95]:
		var curtain_sample := _spiral_sample(i)
		var curtain_position: Vector3 = curtain_sample["position"]
		var curtain_angle: float = curtain_sample["angle"]
		var curtain := MAGMA_CURTAIN_SCRIPT.new() as Node3D
		curtain.name = "MagmaCurtain%d" % i
		curtain.set("jets", 7)
		curtain.set("spacing", 1.15)
		curtain.set("height", 4.6)
		curtain.set("cycle_speed", 2.0 + float(i % 3) * 0.25)
		curtain.set("push_up", 10.0)
		curtain.set("phase_offset", float(i) * 0.17)
		curtain.position = curtain_position + Vector3.UP * 0.05
		curtain.rotation = Vector3(-_ramp_slope, -curtain_angle, 0.0)
		course.add_child(curtain)

	_obstacle(
		course, "FinishLine", FINISH_SCENE, Vector3(summit.x, end_top, summit.z), {}, -end_angle
	)

	# --- esqueleto de la carrera -----------------------------------------
	var length := 32.0 + spiral_length + 10.0
	_add_level_info(
		{
			"level_id": "lava_vortex",
			"display_name": "Lava Vortex",
			"round_index": 4,
			"start_z": -72.0,
			"finish_z": summit.z,
			"course_length": length,
			"gold_time": 84.0,
			"silver_time": 100.0,
			"bronze_time": 116.0,
			"start_position": Vector3(-18.0, V_START_TOP, -64.0),
			"path_corridor": true,
		}
	)
	_add_race_manager()

	var lava := LAVA_RISE_SCRIPT.new() as Area3D
	lava.name = "LavaSea"
	lava.set("center_xz", V_CENTER)
	lava.set("surface_y", -8.0)
	lava.set("max_surface_y", 118.0)
	lava.set("radius", 62.0)
	lava.set("rise_speed", 0.75)
	host.add_child(lava)

	# En el origen: sus meteoros y avisos se colocan en coordenadas de mundo.
	var rain := METEOR_RAIN_SCRIPT.new() as Node3D
	rain.name = "MeteorRain"
	rain.set("interval", 3.2)
	rain.set("warn_time", 1.35)
	rain.set("spread", 4.5)
	host.add_child(rain)

	_add_hud()
	# En la final caer al vacío también es perder la carrera, igual que la lava.
	_add_kill_plane(Vector3(0.0, -34.0, -90.0), true)
	_add_player(Vector3(-18.0, V_START_TOP + 0.65, -64.0))
	# La espiral es la final: un poco más de punta de velocidad para que el
	# ritmo acompañe a una pista continua y a la lava que sube.
	var racer := host.get_node_or_null("Player") as Node3D
	if racer != null:
		racer.set("max_speed", float(racer.get("max_speed")) * 1.08)
	_add_director(-66.0, summit.z, length)
	_add_pause()


func _spiral_sample(index: int) -> Dictionary:
	var step_angle := TAU / float(V_PER_TURN)
	var angle := PI + (float(index) + 0.5) * step_angle
	var top := V_START_TOP + (float(index) + 0.5) * V_RISE
	var position := Vector3(
		V_CENTER.x + cos(angle) * V_RADIUS, top, V_CENTER.z + sin(angle) * V_RADIUS
	)
	return {"position": position, "top": top, "angle": angle}


# ----------------------------------------------------------- ronda 5: abismo


## Punto de entrada del kit: el builder llama aquí sin saber de qué tema se trata.
func build() -> void:
	_build_volcano()


## Escena ya horneada: recupera la ruta de la espiral para que la cámara del
## circuito siga funcionando sin reconstruir nada.
func resume_baked() -> void:
	var ramp_chord := (TAU / float(V_PER_TURN)) * V_RADIUS
	_ramp_slope = atan2(V_RISE, ramp_chord)
	var info := host.get_node_or_null("LevelInfo") as LevelInfo
	if info == null:
		return
	_path.clear()
	_widths.clear()
	for point in info.waypoints:
		_path.append(point)
	for width in info.lane_widths:
		_widths.append(width)
