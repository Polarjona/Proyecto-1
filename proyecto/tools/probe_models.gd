extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	for c in ["a", "c", "e", "g", "m"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var scene := load("res://assets/characters/blocky/character-%s.glb" % c) as PackedScene
		var model := scene.instantiate() as Node3D
		holder.add_child(model)
		await process_frame
		var box := AABB()
		var first := true
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var inst := mesh as MeshInstance3D
			if inst.mesh == null:
				continue
			var b: AABB = inst.global_transform * inst.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		print("character-%s  aabb=%s  anim=%s" % [c, box, ap.get_animation_list() if ap else []])
		holder.queue_free()
		await process_frame
	quit(0)
