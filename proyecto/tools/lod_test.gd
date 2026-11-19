extends SceneTree

## Verifica lo que `LevelLod` hace con los actos ya separados: recorta el atrezo
## a distancia, pone occluders en las losas grandes y no toca ni la pista ni los
## obstáculos. Se aplica sobre los actos cargados sueltos, sin arrancar la
## carrera, así que no necesita autoloads.

const LEVELS := [
	"res://scenes/levels/glacier_gallop.tscn",
	"res://scenes/levels/lava_vortex.tscn",
	"res://scenes/levels/abyss_run.tscn",
]

var _failures := 0


func _initialize() -> void:
	for path in LEVELS:
		_check_level(path)
	print("")
	if _failures == 0:
		print("RESULT: TODO OK (0 fallos)")
	else:
		print("RESULT: %d fallos" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK:   ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _check_level(path: String) -> void:
	print("\n== ", path.get_file())
	var packed := load(path) as PackedScene
	_check(packed != null, "carga la escena")
	if packed == null:
		return
	var level := packed.instantiate()
	var acts := _acts_of(level)
	_check(acts.size() == 3, "tiene 3 actos (encontrados %d)" % acts.size())
	var lod := 0
	var occluders := 0
	for act in acts:
		var host := Node3D.new()
		var course := Node3D.new()
		course.name = "Course"
		host.add_child(course)
		act.get_parent().remove_child(act)
		course.add_child(act)
		LevelLod.apply(host)
		lod += _count_lod(act)
		occluders += _count_occluders(act)
		_check(_track_untouched(act), "%s no oculta la pista" % act.name)
		_check(_obstacles_untouched(act), "%s no toca los obstáculos" % act.name)
		var before := _count_nodes(act)
		LevelLod.apply(host)
		_check(_count_nodes(act) == before,
			"%s no duplica occluders al aplicarlo dos veces" % act.name)
		host.free()
	level.free()
	_check(lod > 0, "%s recorta atrezo a distancia (%d mallas)" % [path.get_file(), lod])
	_check(occluders > 0, "%s tiene occluders (%d)" % [path.get_file(), occluders])
	print("      LOD %d · occluders %d" % [lod, occluders])


func _acts_of(level: Node) -> Array[Node]:
	var acts: Array[Node] = []
	var course := level.get_node_or_null("Course")
	if course == null:
		return acts
	for child in course.get_children():
		if String(child.name).begins_with("Act"):
			acts.append(child)
	return acts


func _count_lod(root: Node) -> int:
	var count := 0
	for node in _meshes(root):
		if node.visibility_range_end > 0.0:
			count += 1
	return count


func _count_occluders(root: Node) -> int:
	var count := 0
	for node in _all(root):
		if node is OccluderInstance3D:
			var mesh := (node as OccluderInstance3D).occluder as ArrayOccluder3D
			if mesh == null or mesh.vertices.size() != 8 or mesh.indices.size() != 36:
				continue
			count += 1
	return count


## Las mallas de la pista (hijas de su `StaticBody3D`) no pueden tener rango de
## visión: si se recortaran, el suelo desaparecería a lo lejos.
func _track_untouched(root: Node) -> bool:
	for node in _meshes(root):
		if node.get_parent() is StaticBody3D and node.visibility_range_end > 0.0:
			return false
	return true


## Los obstáculos son escenas instanciadas: ni rango de visión ni occluder dentro.
func _obstacles_untouched(root: Node) -> bool:
	for child in root.get_children():
		if child.scene_file_path.is_empty():
			continue
		for node in _meshes(child):
			if node.visibility_range_end > 0.0:
				return false
		for node in _all(child):
			if node is OccluderInstance3D:
				return false
	return true


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node in _all(root):
		if node is MeshInstance3D:
			meshes.append(node)
	return meshes


func _all(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	for child in root.get_children():
		nodes.append(child)
		nodes.append_array(_all(child))
	return nodes


func _count_nodes(root: Node) -> int:
	return _all(root).size()
