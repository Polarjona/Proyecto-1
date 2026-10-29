extends SceneTree

## Comprueba que cada personaje del catálogo se instancia, se escala exactamente
## a `CharacterCatalog.CHARACTER_HEIGHT` (los corredores son pequeños: el mapa
## tiene que parecer grande) y tiene los clips que piden jugador y bots.
## Pasa por los dos cuerpos de cada personaje: el masculino y el femenino.

const WANTED := ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Jump_Land", "Lie_Idle", "Hit_A", "Cheer"]


func _initialize() -> void:
	var bad := 0
	var bodies := 0
	for entry in CharacterCatalog.CHARACTERS:
		var id := String(entry["id"])
		var count := CharacterCatalog.variant_count(id)
		if count < 2:
			print("FALLO ", id, ": el personaje no trae los dos cuerpos")
			bad += 1
		for variant in count:
			bodies += 1
			var model := CharacterCatalog.build_model(id, "Model", variant)
			if model == null:
				print("FALLO ", id, ": no se pudo cargar el cuerpo %d" % variant)
				bad += 1
				continue
			var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var has_clips: Array[String] = []
			if anim != null:
				for clip in WANTED:
					if anim.has_animation(clip):
						has_clips.append(clip)
			var height := _height(model, model.transform)
			var clips_text := "sin esqueleto" if anim == null else "%d/%d" % [has_clips.size(), WANTED.size()]
			print("%-10s %-14s c%d  clips=%-8s alto~%.2f (objetivo %.2f)  %s" % [
				id, String(entry["name"]), variant, clips_text, height, CharacterCatalog.CHARACTER_HEIGHT,
				"" if anim == null or has_clips.size() == WANTED.size() else str(WANTED.filter(func(c): return not has_clips.has(c)))])
			if absf(height - CharacterCatalog.CHARACTER_HEIGHT) > 0.05:
				print("      ^ FALLO: no mide lo que pide el catálogo")
				bad += 1
			if anim != null and has_clips.size() < WANTED.size():
				bad += 1
			model.free()
	print("RESULT: %s (%d personajes, %d cuerpos)" % [
		"TODO OK" if bad == 0 else "%d cuerpos con problemas" % bad,
		CharacterCatalog.CHARACTERS.size(), bodies])
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
