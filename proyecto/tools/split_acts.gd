extends Node

## Divide los circuitos generados en tres actos instanciados.
##
## Cada escena de nivel guardaba su pista entera en un solo `.tscn` de miles de
## líneas: carga más lento y cualquier cambio en un tramo sale en el diff como
## un bloque enorme. Ahora el nivel instancia `_act1..3.tscn`, que agrupan los
## nodos del `Course` por su z (salida → meta), así que se puede abrir y editar
## un acto sin cargar los otros dos.
##
## Corre como escena para que los autoloads existan (las escenas cargan scripts
## que los usan) y es idempotente: si ya hay `Act1`, no toca nada.
##
## Uso: godot --headless --path . res://tools/acts_runner.tscn

const TARGETS := [
	"res://scenes/levels/glacier_gallop.tscn",
	"res://scenes/levels/lava_vortex.tscn",
	"res://scenes/levels/abyss_run.tscn",
]
const ACTS := 3


func _ready() -> void:
	var failed := 0
	for path in TARGETS:
		if not _split(path):
			failed += 1
	print("ACTOS: %d escenas, %d fallos" % [TARGETS.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _split(path: String) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		print("FAIL: no carga ", path)
		return false
	var root := packed.instantiate() as Node3D
	var course := root.get_node_or_null("Course") as Node3D
	if course == null:
		print("FAIL: %s no tiene Course" % path)
		root.free()
		return false
	if course.get_node_or_null("Act1") != null:
		print("NOTA: %s ya está dividido" % path)
		root.free()
		return true

	var children := course.get_children()
	var total := children.size()
	var count_before := _count(root)

	# La salida está en z positivo y la meta en negativo: ordenar así deja cada
	# acto como un tramo continuo de la pista.
	var ordered := children.duplicate()
	ordered.sort_custom(
		func(a: Node, b: Node) -> bool: return (a as Node3D).position.z > (b as Node3D).position.z
	)
	var per_act := ceili(float(total) / float(ACTS))

	var act_scenes: Array[PackedScene] = []
	for act_index in ACTS:
		var act := Node3D.new()
		act.name = "Act%d" % (act_index + 1)
		var from_index := act_index * per_act
		var to_index := mini(from_index + per_act, total)
		for i in range(from_index, to_index):
			var node: Node = ordered[i]
			course.remove_child(node)
			act.add_child(node)
		_own(act, act)
		var act_scene := PackedScene.new()
		if act_scene.pack(act) != OK:
			print("FAIL: no se pudo empaquetar el acto %d de %s" % [act_index + 1, path])
			act.free()
			root.free()
			return false
		var act_path := "%s_act%d.tscn" % [path.get_basename(), act_index + 1]
		if ResourceSaver.save(act_scene, act_path) != OK:
			print("FAIL: no se pudo guardar ", act_path)
			act.free()
			root.free()
			return false
		act_scenes.append(load(act_path) as PackedScene)
		act.free()

	for act_scene in act_scenes:
		var instance := act_scene.instantiate() as Node3D
		course.add_child(instance)
		instance.owner = root

	var out_path := path.get_basename() + ".acts.tscn"
	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		print("FAIL: no se pudo empaquetar ", path)
		root.free()
		return false
	root.free()
	if ResourceSaver.save(scene, out_path) != OK:
		print("FAIL: no se pudo guardar ", out_path)
		return false

	if not _verify(out_path, count_before):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))
		return false

	var backup := path + ".preacts"
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
	print("DIVIDIDO OK: %s (%d nodos en %d actos)" % [path, total, ACTS])
	return true


## El `owner` se propaga hasta los hijos, pero se detiene en las escenas
## instanciadas: su contenido viene de su propio `.tscn` y hornearlo lo
## duplicaría.
func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			_own(child, owner_node)


## El nivel dividido tiene que traer los mismos nodos que antes, más los actos.
func _verify(path: String, count_before: int) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		print("FAIL: el dividido no carga ", path)
		return false
	var root := packed.instantiate()
	var count_after := _count(root)
	root.free()
	if count_after != count_before + ACTS:
		print("FAIL: %s tiene %d nodos y antes %d" % [path, count_after, count_before])
		return false
	return true


func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count(child)
	return total
