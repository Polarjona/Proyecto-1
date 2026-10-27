class_name CharacterCatalog
extends RefCounted

## Catálogo único de personajes. Lo usan el jugador, los bots y el menú, así
## que añadir un modelo nuevo es una sola entrada aquí.
##
## Todos los cuerpos son GLB **animados** (con esqueleto y clips) y con licencia
## libre: *Kenney Mini Characters* (CC0) y las mascotas de Quaternius (CC0).
## `build_model` escala cada cuerpo a su altura objetivo y renombra los clips
## que esperan jugador y bots.
##
## `price` es lo que cuesta desbloquearlo en el menú Personaje. Coco es gratis:
## todo el mundo empieza jugando con él.

const CHARACTERS := [
	{
		"id": "coco",
		"name": "Coco",
		"scene": "res://assets/characters/mini/character-male-f.glb",
		"target_height": 1.7,
		"color": Color(0.96, 0.6, 0.36),
		"price": 0,
	},
	{
		"id": "menta",
		"name": "Menta",
		"scene": "res://assets/characters/mini/character-female-d.glb",
		"target_height": 1.7,
		"color": Color(0.46, 0.9, 0.74),
		"price": 400,
	},
	{
		"id": "nube",
		"name": "Nube",
		"scene": "res://assets/characters/mini/character-female-b.glb",
		"target_height": 1.7,
		"color": Color(0.62, 0.76, 1.0),
		"price": 800,
	},
	{
		"id": "mochi",
		"name": "Mochi",
		"scene": "res://assets/characters/mascots/bunny.glb",
		"target_height": 1.7,
		"color": Color(0.4, 0.72, 1.0),
		"price": 1200,
	},
	{
		"id": "turbo",
		"name": "Turbo",
		"scene": "res://assets/characters/mascots/robot.glb",
		"target_height": 1.7,
		"color": Color(1.0, 0.82, 0.32),
		"price": 1600,
	},
]

static func default_id() -> String:
	return String(CHARACTERS[0]["id"])


static func ids() -> Array[String]:
	var result: Array[String] = []
	for entry in CHARACTERS:
		result.append(String(entry["id"]))
	return result


static func by_id(id: String) -> Dictionary:
	for entry in CHARACTERS:
		if String(entry["id"]) == id:
			return entry
	return CHARACTERS[0]


static func index_of(id: String) -> int:
	for i in CHARACTERS.size():
		if String(CHARACTERS[i]["id"]) == id:
			return i
	return 0


static func at(index: int) -> Dictionary:
	if CHARACTERS.is_empty():
		return {}
	return CHARACTERS[posmod(index, CHARACTERS.size())]


static func random_id() -> String:
	if CHARACTERS.is_empty():
		return ""
	return String(CHARACTERS[randi() % CHARACTERS.size()]["id"])


static func display_name(id: String) -> String:
	return String(by_id(id).get("name", id))


## Monedas necesarias para desbloquearlo (0 = gratis).
static func price(id: String) -> int:
	return int(by_id(id).get("price", 0))


## Solo los personajes gratis vienen desbloqueados de fábrica.
static func free_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in CHARACTERS:
		if price(String(entry["id"])) <= 0:
			result.append(String(entry["id"]))
	if result.is_empty():
		result.append(default_id())
	return result


## Clips que esperan el jugador y los bots, con los nombres que usan los
## distintos packs. El primero que exista en el modelo gana; la búsqueda
## también acepta el último tramo del nombre ("CharacterArmature|Run").
const CLIP_ALIASES := {
	"Idle": ["Idle", "idle"],
	"Walking_A": ["Walking_A", "walk", "Walk", "Walking"],
	"Running_A": ["Running_A", "sprint", "Sprint", "Run", "Running"],
	"Jump_Idle": ["Jump_Idle", "jump", "Jump", "idle"],
	"Jump_Land": ["Jump_Land", "fall", "Fall", "idle"],
	"Lie_Idle": ["Lie_Idle", "sit", "Sit", "Sitting", "Duck"],
	"Hit_A": ["Hit_A", "emote-no", "No", "HitReact"],
	"Cheer": ["Cheer", "emote-yes", "Yes", "Dance", "ThumbsUp"],
}


## Instancia el modelo pedido y lo escala a su altura objetivo. Devuelve
## null si el .glb no está importado (el juego sigue funcionando sin personaje).
static func build_model(id: String, node_name: String = "Model") -> Node3D:
	var entry := by_id(id)
	var path := String(entry.get("scene", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("CharacterCatalog: missing model '%s'" % path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	model.name = node_name
	var target_height := float(entry.get("target_height", 0.0))
	if target_height > 0.0:
		var bounds := _model_bounds(model)
		var factor := target_height / maxf(bounds.size.y, 0.01)
		model.scale = Vector3.ONE * factor
		model.position.y = -bounds.position.y * factor
	else:
		model.scale = Vector3.ONE * float(entry.get("scale", 0.55))
	_prepare_animations(model)
	return model


## AABB del modelo en su espacio local (sin depender de estar en el árbol).
static func _model_bounds(node: Node3D, base: Transform3D = Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mesh_transform: Transform3D = base * (child as MeshInstance3D).transform
			var mesh_box: AABB = mesh_transform * (child as MeshInstance3D).get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
		if child is Node3D:
			var child_box := _model_bounds(child as Node3D, base * (child as Node3D).transform)
			if child_box.size != Vector3.ZERO:
				box = child_box if first else box.merge(child_box)
				first = false
	return box


## Añade los alias de animación que faltan duplicando el clip original.
static func _prepare_animations(model: Node3D) -> void:
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	for alias: String in CLIP_ALIASES:
		if anim.has_animation(alias):
			continue
		var source := _find_clip(anim, CLIP_ALIASES[alias])
		if source.is_empty():
			continue
		var clip := anim.get_animation(source).duplicate() as Animation
		if clip == null:
			continue
		clip.resource_name = alias
		var library := anim.get_animation_library("")
		if library == null:
			library = AnimationLibrary.new()
			anim.add_animation_library("", library)
		library.add_animation(alias, clip)


## Nombre real del clip que corresponde a un alias. Acepta el nombre exacto,
## el último tramo tras "|" o ":" y el sufijo tras un guion bajo
## ("Robot_Walking" para "Walking").
static func _find_clip(anim: AnimationPlayer, candidates: Array) -> String:
	for candidate in candidates:
		var exact := String(candidate)
		if anim.has_animation(exact):
			return exact
	var clips := anim.get_animation_list()
	for candidate in candidates:
		var wanted := String(candidate).to_lower()
		for clip_name: StringName in clips:
			var name := String(clip_name)
			var parts := name.split("|")
			var last := String(parts[parts.size() - 1])
			parts = last.split(":")
			last = String(parts[parts.size() - 1]).to_lower()
			if last == wanted or last.ends_with("_" + wanted):
				return name
	return ""
