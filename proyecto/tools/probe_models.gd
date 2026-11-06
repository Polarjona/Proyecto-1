extends SceneTree

## Vuelca los clips y el tamaño de los modelos nuevos para saber cómo
## renombrarlos antes de meterlos en el catálogo.

const PATHS := [
	"res://assets/characters/ultimate/chef_male.glb",
	"res://assets/characters/ultimate/chef_female.glb",
]


func _initialize() -> void:
	for path: String in PATHS:
		print("=== ", path)
		if not ResourceLoader.exists(path):
			print("   MISSING")
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			print("   NO SCENE")
			continue
		var node := scene.instantiate() as Node3D
		var anim := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim == null:
			print("   sin AnimationPlayer")
		else:
			var names := anim.get_animation_list()
			print("   clips (%d): %s" % [names.size(), str(names)])
		print("   nodes: %s" % str(node.find_children("*", "MeshInstance3D", true, false).map(func(n): return n.name)))
		node.free()
	quit(0)
