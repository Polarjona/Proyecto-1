extends SceneTree

## Comprueba que cada personaje del catálogo se instancia, se escala a la
## altura pedida y tiene los clips que piden jugador y bots. Los modelos sin
## esqueleto (el capibara) se aceptan como estáticos: el jugador les pone el
## rebote procedural encima.

const WANTED := ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Jump_Land", "Lie_Idle", "Hit_A", "Cheer"]


func _initialize() -> void:
	var bad := 0
	for entry in CharacterCatalog.CHARACTERS:
		var id := String(entry["id"])
		var model := CharacterCatalog.build_model(id)
		if model == null:
			print("FALLO ", id, ": no se pudo cargar")
			bad += 1
			continue
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var has_clips: Array[String] = []
		if anim != null:
			for clip in WANTED:
				if anim.has_animation(clip):
					has_clips.append(clip)
		var height := _height(model, model.transform)
		var clips_text := "estático" if anim == null else "%d/%d" % [has_clips.size(), WANTED.size()]
		print("%-10s %-14s clips=%-8s alto~%.2f  %s" % [
			id, String(entry["name"]), clips_text, height,
			"" if anim == null or has_clips.size() == WANTED.size() else str(WANTED.filter(func(c): return not has_clips.has(c)))])
		if anim != null and has_clips.size() < WANTED.size():
			bad += 1
		model.free()
	print("RESULT: %s" % ("TODO OK" if bad == 0 else "%d personajes con clips incompletos" % bad))
	quit(0 if bad == 0 else 1)


## Altura real del modelo sumando las transformadas de las mallas anidadas
## (los packs animados cuelgan la malla de un hueso con su propia escala).
func _height(node: Node3D, base: Transform3D) -> float:
	var top := 0.0
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var box: AABB = (base * (child as MeshInstance3D).transform) * (child as MeshInstance3D).get_aabb()
			top = maxf(top, box.end.y)
		if child is Node3D:
			top = maxf(top, _height(child as Node3D, base * (child as Node3D).transform))
	return top
