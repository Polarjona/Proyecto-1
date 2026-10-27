class_name CharacterCatalog
extends RefCounted

## Catálogo único de personajes. Lo usan el jugador, los bots y el menú, así
## que añadir un modelo nuevo es una sola entrada aquí.
##
## Los cinco modelos vienen del pack CC0 *Kenney Blocky Characters 2.0*:
## cuerpos de bloque con cabeza grande, colores planos y animaciones de nodo
## (idle, walk, sprint, emote...), mucho más cerca del tono juguete del juego.
## `build_model` las renombra a los clips que esperan jugador y bots.
##
## `price` es lo que cuesta desbloquearlo en el menú Personaje. Chispa es
## gratis: todo el mundo empieza jugando con ella.

const CHARACTERS := [
	{
		"id": "rogue",
		"name": "Chispa",
		"scene": "res://assets/characters/blocky/character-a.glb",
		"target_height": 1.7,
		"color": Color(0.45, 0.95, 0.6),
		"price": 0,
	},
	{
		"id": "rogue_hooded",
		"name": "Uva",
		"scene": "res://assets/characters/blocky/character-c.glb",
		"target_height": 1.7,
		"color": Color(0.7, 0.55, 1.0),
		"price": 100,
	},
	{
		"id": "knight",
		"name": "Robot",
		"scene": "res://assets/characters/blocky/character-e.glb",
		"target_height": 1.7,
		"color": Color(0.55, 0.82, 0.92),
		"price": 200,
	},
	{
		"id": "mage",
		"name": "Tornillo",
		"scene": "res://assets/characters/blocky/character-g.glb",
		"target_height": 1.7,
		"color": Color(1.0, 0.62, 0.35),
		"price": 300,
	},
	{
		"id": "barbarian",
		"name": "Jefe",
		"scene": "res://assets/characters/blocky/character-m.glb",
		"target_height": 1.7,
		"color": Color(0.95, 0.82, 0.45),
		"price": 500,
	},
]

## Armas, escudos y capas: la carrera es sin armas, así que esos props
## se ocultan nada más instanciar el modelo.
const ACCESSORY_PARTS := [
	"2H_Staff", "1H_Wand", "Spellbook", "Spellbook_open",
	"1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield",
	"Spike_Shield", "1H_Sword", "2H_Sword", "Knife_Offhand", "1H_Crossbow",
	"2H_Crossbow", "Knife", "Throwable", "Rogue_Cape", "Mage_Cape",
	"Knight_Cape", "Barbarian_Cape", "1H_Axe_Offhand", "1H_Axe", "2H_Axe",
	"Mug", "Barbarian_Round_Shield", "Quiver", "Arrow", "Smokebomb", "Dagger",
]

const ACCESSORY_KEYWORDS := [
	"Cape", "Sword", "Shield", "Staff", "Wand", "Spellbook", "Crossbow",
	"Knife", "Throwable", "Axe", "Mug", "Quiver", "Arrow", "Smokebomb",
	"Dagger",
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


## Clips que esperan el jugador y los bots, emparejados con los del pack.
const CLIP_ALIASES := {
	"Idle": "idle",
	"Walking_A": "walk",
	"Running_A": "sprint",
	"Jump_Idle": "idle",
	"Jump_Land": "idle",
	"Lie_Idle": "sit",
	"Hit_A": "emote-no",
	"Cheer": "emote-yes",
}


## Instancia el modelo pedido, lo escala y le quita las armas. Devuelve null
## si el .glb no está importado (el juego sigue funcionando sin personaje).
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
	hide_accessories(model)
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
		var source := String(CLIP_ALIASES[alias])
		if not anim.has_animation(source):
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


static func hide_accessories(model: Node3D) -> void:
	for part in ACCESSORY_PARTS:
		var node := model.find_child(part, true, false)
		if node is Node3D:
			(node as Node3D).visible = false
	# Red de seguridad para modelos futuros del mismo pack.
	for child in model.find_children("*", "Node3D", true, false):
		var node_name := String(child.name)
		for keyword in ACCESSORY_KEYWORDS:
			if node_name.contains(keyword):
				(child as Node3D).visible = false
				break
