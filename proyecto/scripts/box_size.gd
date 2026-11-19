class_name BoxSize
extends RefCounted

## Tamaño y material de una losa del mapa. Sirve tanto para los mapas antiguos,
## hechos con `CSGBox3D`, como para los horneados a malla (`StaticBody3D` con su
## `MeshInstance3D` dentro), para que el atrezo y los tests no sepan de cuál es.


static func of(node: Node) -> Vector3:
	var csg := node as CSGBox3D
	if csg != null:
		return csg.size
	var mesh_node := _mesh_of(node)
	if mesh_node == null:
		return Vector3.ZERO
	var box := mesh_node.mesh as BoxMesh
	return box.size if box != null else Vector3.ZERO


static func material_of(node: Node) -> Material:
	var csg := node as CSGBox3D
	if csg != null:
		return csg.material
	var mesh_node := _mesh_of(node)
	return mesh_node.material_override if mesh_node != null else null


static func _mesh_of(node: Node) -> MeshInstance3D:
	var mesh_node := node as MeshInstance3D
	if mesh_node != null:
		return mesh_node
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
	return null
