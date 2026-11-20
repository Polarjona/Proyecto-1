class_name LevelLod

extends RefCounted

## LOD y oclusión para los circuitos generados, aplicados una sola vez al cargar
## el nivel recorriendo sus actos (`Course/Act1..3`).
##
## Las dos reglas miran forma y tamaño, sin listas de nombres:
##
##   * Oclusión: la losa grande y plana (pared, suelo, techo) lleva un
##     `OccluderInstance3D` con la caja exacta de su malla, así que lo que queda
##     detrás deja de dibujarse y nunca se tapa algo que se vea.
##   * LOD: el atrezo suelto se deja de dibujar cuando su diagonal ocupa ~14 px
##     en pantalla, con un desvanecido dither del último 40 % de la distancia
##     para que el cambio no se lea como un corte.
##
## Nunca toca la pista ni los obstáculos: la pista es la malla de cada losa (que
## solo puede hacer de occluder) y los obstáculos son escenas instanciadas, que
## se saltan enteras.

## Ángulo que ocupa la diagonal del atrezo cuando se deja de dibujar. 0,012 rad
## son unos 14 px de alto en 1080p con el FOV de la cámara.
const CULL_ANGLE := 0.012

## Aunque el objeto sea diminuto no se corta más cerca de esto.
const MIN_DISTANCE := 70.0

## Parte de la distancia final que se dedica al desvanecido: casi la mitad, para
## que el dither avance poco a poco en vez de borrarse de golpe.
const FADE_SHARE := 0.4

## Losa que puede hacer de occluder: dos lados largos y uno fino. Las paredes y
## suelos de las pistas entran justo por debajo del grosor máximo.
const OCCLUDER_MIN_SIDE := 3.0

const OCCLUDER_MAX_THICKNESS := 3.0

const OCCLUDER_MIN_LENGTH := 8.0

const OCCLUDER_NAME := "Occluder"


static func apply(level: Node) -> void:
	var course := level.get_node_or_null("Course")
	if course == null:
		return
	for act in course.get_children():
		_walk(act)


static func _walk(root: Node) -> void:
	for child in root.get_children():
		# Obstáculos y actores: escena propia, no se toca nada de dentro.
		if not child.scene_file_path.is_empty():
			continue
		var mesh_node := child as MeshInstance3D
		if mesh_node != null:
			_dress(mesh_node)
		_walk(child)


static func _dress(mesh_node: MeshInstance3D) -> void:
	if mesh_node.mesh == null:
		return
	var bounds := mesh_node.get_aabb()
	if bounds.size == Vector3.ZERO:
		return
	var box := mesh_node.mesh as BoxMesh
	if box != null and _is_flat_slab(box.size):
		_add_occluder(mesh_node, bounds)
		return
	# Superficie de la pista: se ve siempre, no se recorta nunca.
	if mesh_node.get_parent() is StaticBody3D:
		return
	_add_lod(mesh_node, bounds.size.length())


static func _is_flat_slab(size: Vector3) -> bool:
	var sides := [size.x, size.y, size.z]
	sides.sort()
	return (
		sides[0] <= OCCLUDER_MAX_THICKNESS
		and sides[1] >= OCCLUDER_MIN_SIDE
		and sides[2] >= OCCLUDER_MIN_LENGTH
	)


static func _add_occluder(mesh_node: MeshInstance3D, bounds: AABB) -> void:
	if mesh_node.get_node_or_null(OCCLUDER_NAME) != null:
		return
	var low := bounds.position
	var high := bounds.end
	var occluder_mesh := ArrayOccluder3D.new()
	occluder_mesh.vertices = PackedVector3Array(
		[
			Vector3(low.x, low.y, low.z),
			Vector3(high.x, low.y, low.z),
			Vector3(high.x, low.y, high.z),
			Vector3(low.x, low.y, high.z),
			Vector3(low.x, high.y, low.z),
			Vector3(high.x, high.y, low.z),
			Vector3(high.x, high.y, high.z),
			Vector3(low.x, high.y, high.z),
		]
	)
	occluder_mesh.indices = PackedInt32Array(
		[
			0,
			1,
			2,
			0,
			2,
			3,
			4,
			6,
			5,
			4,
			7,
			6,
			0,
			4,
			5,
			0,
			5,
			1,
			1,
			5,
			6,
			1,
			6,
			2,
			2,
			6,
			7,
			2,
			7,
			3,
			3,
			7,
			4,
			3,
			4,
			0,
		]
	)
	var occluder := OccluderInstance3D.new()
	occluder.name = OCCLUDER_NAME
	occluder.occluder = occluder_mesh
	# Colgando de la malla, la caja comparte su transformación exacta.
	mesh_node.add_child(occluder)


static func _add_lod(mesh_node: MeshInstance3D, diagonal: float) -> void:
	if mesh_node.visibility_range_end > 0.0:
		return
	var distance := maxf(MIN_DISTANCE, diagonal / CULL_ANGLE)
	mesh_node.visibility_range_end = distance
	mesh_node.visibility_range_end_margin = distance * FADE_SHARE
	mesh_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
