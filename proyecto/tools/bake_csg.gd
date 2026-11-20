extends Node

## Hornea los `CSGBox3D` de los mapas hechos a mano a malla + colisión estática.
##
## CSG recalcula su geometría en cada arranque y provoca tirones al aparecer; una
## `BoxMesh` con su `BoxShape3D` se carga ya hecha. Se conservan nombre,
## transformación, material y capas de colisión, así que el mapa se juega igual.
##
## Corre como escena (`tools/csg_runner.tscn`) para que los autoloads existan:
## las escenas cargan scripts que los usan.
##
## Uso: godot --headless --path . res://tools/csg_runner.tscn

const TARGETS := [
	LevelPaths.PIVOT_PUSH,
	"res://scenes/levels/spin_go_round.tscn",
]


func _ready() -> void:
	var failed := 0
	for path in TARGETS:
		if not _convert_scene(path):
			failed += 1
	print("CSG: %d escenas, %d fallos" % [TARGETS.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _convert_scene(path: String) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		print("FAIL: no carga ", path)
		return false
	var root := packed.instantiate() as Node3D
	if root == null:
		print("FAIL: la escena no es Node3D ", path)
		return false
	var stats := {"replaced": 0, "collision": 0, "children_lost": 0}
	_convert(root, root, stats)
	print(
		(
			"%s: %d CSG a malla (%d con colisión), %d con hijos"
			% [path, stats["replaced"], stats["collision"], stats["children_lost"]]
		)
	)
	if stats["replaced"] == 0:
		print("NOTA: no había CSG en ", path)
		root.free()
		return true

	var out_path := path.get_basename() + ".csgbaked.tscn"
	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		print("FAIL: no se pudo empaquetar ", path)
		root.free()
		return false
	root.free()
	if ResourceSaver.save(scene, out_path) != OK:
		print("FAIL: no se pudo guardar ", out_path)
		return false

	if not _verify(out_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))
		return false

	# Sustituye el original dejando copia por si el reemplazo fallara.
	var backup := path + ".precsg"
	DirAccess.copy_absolute(
		ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup)
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if (
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(out_path), ProjectSettings.globalize_path(path)
		)
		!= OK
	):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(path)
		)
		print("FAIL: no se pudo reemplazar ", path)
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	print("HORNEADO OK: ", path)
	return true


## Recorre el árbol y cambia cada `CSGBox3D` por su equivalente en malla.
func _convert(parent: Node, scene_root: Node, stats: Dictionary) -> void:
	for child in parent.get_children():
		# Las escenas instanciadas traen su propio contenido: no se tocan.
		if not child.scene_file_path.is_empty():
			continue
		if child is CSGBox3D:
			var target := _replace(child as CSGBox3D, parent, scene_root, stats)
			# Un CSG puede contener otro CSG: el nuevo nodo se recorre también.
			if target != null:
				_convert(target, scene_root, stats)
			continue
		_convert(child, scene_root, stats)


func _replace(csg: CSGBox3D, parent: Node, scene_root: Node, stats: Dictionary) -> Node3D:
	var index := csg.get_index()
	var node_name := String(csg.name)
	var node_transform := csg.transform
	var material := csg.material
	var size := csg.size
	if csg.get_child_count() > 0:
		stats["children_lost"] += 1
		print("AVISO: ", node_name, " tenía hijos; se conservan bajo el nodo nuevo")

	var target: Node3D
	var body: StaticBody3D = null
	if csg.use_collision:
		body = StaticBody3D.new()
		body.collision_layer = csg.collision_layer
		body.collision_mask = csg.collision_mask
		body.collision_priority = csg.collision_priority
		target = body
		stats["collision"] += 1
	else:
		target = MeshInstance3D.new()
	target.name = node_name
	target.transform = node_transform
	target.unique_name_in_owner = csg.unique_name_in_owner

	var mesh_node: MeshInstance3D
	if body != null:
		mesh_node = MeshInstance3D.new()
		mesh_node.name = "Mesh"
		body.add_child(mesh_node)
	else:
		mesh_node = target as MeshInstance3D
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	mesh_node.material_override = material

	if body != null:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)

	# Los hijos del CSG (si los hubiera) pasan al nodo nuevo.
	for child in csg.get_children():
		csg.remove_child(child)
		target.add_child(child)

	parent.remove_child(csg)
	parent.add_child(target)
	parent.move_child(target, index)
	target.owner = scene_root
	_own(target, scene_root)
	csg.free()
	stats["replaced"] += 1
	return target


## El `owner` solo se puede fijar cuando el nodo ya cuelga del árbol empaquetado.
func _own(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_own(child, scene_root)


## El horneado tiene que cargar, no traer CSG y conservar los nodos con colisión.
func _verify(path: String) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		print("FAIL: el horneado no carga ", path)
		return false
	var root := packed.instantiate()
	var csg := _count(root, func(node: Node) -> bool: return node is CSGShape3D)
	var bodies := _count(root, func(node: Node) -> bool: return node is StaticBody3D)
	var shapes := _count(root, func(node: Node) -> bool: return node is CollisionShape3D)
	var ok := csg == 0 and bodies > 0 and shapes > 0
	if not ok:
		print(
			"FAIL: verificación de %s (csg=%d, cuerpos=%d, formas=%d)" % [path, csg, bodies, shapes]
		)
	root.free()
	return ok


func _count(node: Node, predicate: Callable) -> int:
	var total := 1 if predicate.call(node) else 0
	for child in node.get_children():
		total += _count(child, predicate)
	return total
