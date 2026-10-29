class_name CharacterCatalog
extends RefCounted

## Catálogo único de personajes. Lo usan el jugador, los bots y el menú, así
## que añadir un modelo nuevo es una sola entrada aquí.
##
## Todos los cuerpos son GLB **animados** (con esqueleto y clips) y con licencia
## libre: *Ultimate Animated Character Pack* de Quaternius (CC0).
## `build_model` escala cada cuerpo a su altura objetivo (`CHARACTER_HEIGHT`) y
## renombra los clips que esperan jugador y bots.
##
## Cada personaje trae **dos cuerpos** (masculino y femenino) que cuentan como
## uno solo: se desbloquea una vez, se elige una vez y ocupa una fila del menú.
## El jugador corre siempre con el mismo cuerpo durante la sesión
## (`session_variant`) y los bots se reparten entre los dos, así que la parrilla
## de salida enseña las dos versiones del mismo personaje.
##
## `price` es lo que cuesta desbloquearlo en el menú Personaje. El primero es
## gratis: todo el mundo empieza jugando con él.
##
## Los corredores son deliberadamente pequeños (un metro de alto, escala de
## juguete) para que las plataformas de los circuitos parezcan grandes. Al
## cambiar `CHARACTER_HEIGHT` hay que ajustar en la misma proporción la cápsula
## del jugador y de los bots (`player.tscn`, `bot_racer.tscn`) y la cámara
## (valores por defecto de `player.gd`).

## Altura, en metros, a la que se escala cualquier cuerpo del catálogo.
const CHARACTER_HEIGHT := 1.05

## Carpeta de los cuerpos del pack.
const MODEL_DIR := "res://assets/characters/ultimate/"

const CHARACTERS := [
	{
		"id": "chef",
		"name": "Chef",
		"variants": [MODEL_DIR + "chef_male.glb", MODEL_DIR + "chef_female.glb"],
		"color": Color(0.98, 0.93, 0.88),
		"price": 0,
	},
	{
		"id": "worker",
		"name": "Obrero",
		"variants": [MODEL_DIR + "worker_male.glb", MODEL_DIR + "worker_female.glb"],
		"color": Color(1.0, 0.78, 0.36),
		"price": 200,
	},
	{
		"id": "cowboy",
		"name": "Cowboy",
		"variants": [MODEL_DIR + "cowboy_male.glb", MODEL_DIR + "cowboy_female.glb"],
		"color": Color(0.93, 0.66, 0.42),
		"price": 300,
	},
	{
		"id": "ninja",
		"name": "Ninja",
		"variants": [MODEL_DIR + "ninja_male.glb", MODEL_DIR + "ninja_female.glb"],
		"color": Color(0.55, 0.62, 0.72),
		"price": 400,
	},
	{
		"id": "pirate",
		"name": "Pirata",
		"variants": [MODEL_DIR + "pirate_male.glb", MODEL_DIR + "pirate_female.glb"],
		"color": Color(0.86, 0.32, 0.32),
		"price": 500,
	},
	{
		"id": "vikingo",
		"name": "Vikingo",
		"variants": [MODEL_DIR + "viking_male.glb", MODEL_DIR + "viking_female.glb"],
		"color": Color(0.62, 0.78, 1.0),
		"price": 600,
	},
	{
		"id": "kimono",
		"name": "Kimono",
		"variants": [MODEL_DIR + "kimono_male.glb", MODEL_DIR + "kimono_female.glb"],
		"color": Color(0.96, 0.55, 0.78),
		"price": 700,
	},
	{
		"id": "soldado",
		"name": "Soldado",
		"variants": [MODEL_DIR + "soldier_male.glb", MODEL_DIR + "soldier_female.glb"],
		"color": Color(0.58, 0.74, 0.45),
		"price": 800,
	},
	{
		"id": "ejecutivo",
		"name": "Ejecutivo",
		"variants": [MODEL_DIR + "suit_male.glb", MODEL_DIR + "suit_female.glb"],
		"color": Color(0.72, 0.74, 0.86),
		"price": 900,
	},
	{
		"id": "caballero",
		"name": "Caballero",
		"variants": [MODEL_DIR + "knight_golden_male.glb", MODEL_DIR + "knight_golden_female.glb"],
		"color": Color(1.0, 0.84, 0.35),
		"price": 1000,
	},
]

## Cuerpo que se le ha asignado al jugador en esta sesión, por personaje. El
## índice se sortea la primera vez que se pide y se queda fijo hasta cerrar el
## juego: el cuerpo del corredor no cambia a mitad de carrera.
static var _session_variants: Dictionary = {}

## Generador propio para elegir cuerpo. Va aparte del global (`randi()`) para no
## mover la secuencia aleatoria de los bots, que está calibrada con una semilla
## fija en las pruebas.
static var _variant_rng: RandomNumberGenerator = null

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


## Rutas de los cuerpos del personaje (masculino y femenino).
static func variant_paths(id: String) -> Array:
	var paths: Array = by_id(id).get("variants", [])
	if paths.is_empty():
		var single := String(by_id(id).get("scene", ""))
		if not single.is_empty():
			paths = [single]
	return paths


static func variant_count(id: String) -> int:
	return maxi(variant_paths(id).size(), 1)


## Cuerpo con el que corre el jugador en esta sesión. Se sortea una sola vez
## por personaje para que el escaparate del menú y la carrera enseñen el mismo.
static func session_variant(id: String) -> int:
	if _session_variants.has(id):
		return int(_session_variants[id])
	if _variant_rng == null:
		_variant_rng = RandomNumberGenerator.new()
		_variant_rng.randomize()
	var picked := _variant_rng.randi_range(0, variant_count(id) - 1)
	_session_variants[id] = picked
	return picked


## Instancia el modelo pedido y lo escala a su altura objetivo. `variant` es el
## índice del cuerpo (-1 = el del jugador en esta sesión). Devuelve null si el
## .glb no está importado (el juego sigue funcionando sin personaje).
static func build_model(id: String, node_name: String = "Model", variant: int = -1) -> Node3D:
	var entry := by_id(id)
	var paths := variant_paths(id)
	if paths.is_empty():
		push_warning("CharacterCatalog: '%s' no tiene modelos" % id)
		return null
	var index := posmod(session_variant(id) if variant < 0 else variant, paths.size())
	var path := String(paths[index])
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
	var target_height := float(entry.get("target_height", CHARACTER_HEIGHT))
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


## Clips que esperan el jugador y los bots, con los nombres que usa el pack. El
## primero que exista en el modelo gana; la búsqueda también acepta el último
## tramo del nombre ("CharacterArmature|Walk").
##
## El pack no trae clip de carrera ni de salto: la carrera reutiliza el andar
## acelerado y el salto se queda con el idle, que es lo que mejor lee en el aire.
const CLIP_ALIASES := {
	"Idle": ["Idle"],
	"Walking_A": ["Walk", "Walking"],
	"Running_A": ["Run", "Running", "Walk"],
	"Jump_Idle": ["Jump", "Jump_Idle", "Idle"],
	"Jump_Land": ["Land", "Jump_Land", "Idle"],
	"Lie_Idle": ["Defeat", "Lie_Idle", "SitDown"],
	"Hit_A": ["RecieveHit", "Hit_A"],
	"Cheer": ["Victory", "Cheer"],
}


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
