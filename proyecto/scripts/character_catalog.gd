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
## Los corredores son compactos (~1,25 m, escala de juguete) para que las
## plataformas de los circuitos parezcan grandes y se lean bien de un vistazo.
## Al cambiar `CHARACTER_HEIGHT` hay que ajustar en la misma proporción la
## cápsula del jugador y de los bots (`player.tscn`, `bot_racer.tscn`) y la
## cámara (valores por defecto de `player.gd`).

## Altura, en metros, a la que se escala cualquier cuerpo del catálogo.
const CHARACTER_HEIGHT := 1.25

## Acabado de plástico de juguete compartido por todos los cuerpos. El shader
## toma el color plano de cada superficie y le añade brillo y borde cartoon,
## para que los personajes casen con los circuitos.
const CHARACTER_SHADER := preload("res://shaders/character.gdshader")

## Piel, cara y pelo comunes a todos los cuerpos. El pack viene del FBX con la
## piel a 0.01 y casi toda la ropa por debajo de 0.05 (casi negro), así que
## pintar cada superficie con el color del .glb dejaba muñecos grises.
const TOY_SKIN := Color(0.9, 0.7, 0.56)
const TOY_FACE := Color(0.94, 0.77, 0.63)
const TOY_HAIR := Color(0.3, 0.2, 0.13)

## Paleta de juguete de cada personaje, por nombre de material del pack. Los
## nombres son los que traen los `.glb` (`Skin`, `Clothes`, `Hood`…); lo que no
## esté en la tabla cae en piel/pelo o en un realce del color original.
const PALETTES := {
	"chef": {
		"Clothes": Color(0.98, 0.96, 0.92),
		"DarkClothes": Color(0.66, 0.68, 0.75),
		"Band": Color(0.94, 0.31, 0.28),
		"Hair": Color(0.28, 0.18, 0.12),
	},
	"worker": {
		"Vest": Color(1.0, 0.55, 0.18),
		"Shirt": Color(0.93, 0.91, 0.84),
		"Pants": Color(0.24, 0.42, 0.66),
		"Hat": Color(1.0, 0.82, 0.24),
		"Hair": Color(0.36, 0.22, 0.12),
	},
	"cowboy": {
		"Pants": Color(0.22, 0.32, 0.5),
		"Scarf": Color(0.92, 0.28, 0.26),
		"Jacket": Color(0.78, 0.46, 0.24),
		"Top": Color(0.97, 0.9, 0.74),
		"HatBrown": Color(0.55, 0.33, 0.17),
		"HatLightBrown": Color(0.84, 0.62, 0.35),
		"Hair": Color(0.42, 0.28, 0.14),
	},
	"ninja": {
		"Main": Color(0.2, 0.3, 0.55),
		"Details": Color(0.92, 0.25, 0.3),
		"Grey": Color(0.5, 0.54, 0.6),
		"Hair": Color(0.17, 0.17, 0.21),
	},
	"pirate": {
		"Clothes": Color(0.18, 0.28, 0.48),
		"Beige": Color(0.86, 0.78, 0.6),
		"Gold": Color(1.0, 0.78, 0.3),
		"Brown": Color(0.42, 0.26, 0.15),
		"Black": Color(0.24, 0.21, 0.23),
		"Red": Color(0.9, 0.28, 0.26),
		"Hair": Color(0.4, 0.26, 0.13),
	},
	"vikingo": {
		"Pants": Color(0.35, 0.26, 0.2),
		"Main": Color(0.36, 0.48, 0.66),
		"Light": Color(0.86, 0.74, 0.56),
		"Hair": Color(0.85, 0.5, 0.24),
	},
	"kimono": {
		"Clothes": Color(0.97, 0.6, 0.78),
		"Band": Color(0.78, 0.15, 0.3),
		"Hair": Color(0.18, 0.14, 0.18),
	},
	"soldado": {
		"DarkGreen": Color(0.32, 0.42, 0.24),
		"Black": Color(0.22, 0.24, 0.22),
		"Main": Color(0.44, 0.56, 0.32),
		"Helmet": Color(0.36, 0.46, 0.28),
		"Hair": Color(0.3, 0.2, 0.12),
	},
	"ejecutivo": {
		"Black": Color(0.22, 0.25, 0.36),
		"Shirt": Color(0.97, 0.97, 0.98),
		"Belt": Color(0.3, 0.24, 0.18),
		"Details": Color(0.55, 0.6, 0.72),
		"Hair": Color(0.28, 0.2, 0.16),
	},
	"caballero": {
		"Armor": Color(1.0, 0.78, 0.28),
		"Armor_Dark": Color(0.5, 0.36, 0.16),
		"Detail": Color(0.85, 0.22, 0.26),
		"Red": Color(0.85, 0.25, 0.25),
		"Hair": Color(0.3, 0.2, 0.12),
	},
}

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
	_apply_plastic_look(model, entry)
	_add_rig(model)
	return model


## Sustituye el material plano del GLB por el plástico del juego, por instancia
## (las mallas se comparten entre cuerpos, así que no se toca el recurso). El
## color no se copia del .glb: se pinta con la paleta del personaje (ver
## `_toy_color`), porque los materiales del pack son casi negros.
static func _apply_plastic_look(model: Node3D, entry: Dictionary) -> void:
	var palette: Dictionary = PALETTES.get(String(entry.get("id", "")), {})
	var accent: Color = entry.get("color", Color.WHITE)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			var color := Color.WHITE
			var material_name := ""
			if source is BaseMaterial3D:
				var base := source as BaseMaterial3D
				color = base.albedo_color
				material_name = String(base.resource_name)
			elif source is ShaderMaterial:
				continue
			var material := ShaderMaterial.new()
			material.shader = CHARACTER_SHADER
			material.set_shader_parameter("albedo_color", _toy_color(material_name, color, accent, palette))
			mesh_instance.set_surface_override_material(surface, material)


## Color de juguete de una superficie: manda la paleta del personaje, luego los
## materiales comunes (piel, cara, pelo) y, si el nombre no aparece, se conserva
## el tono del .glb con el valor y la saturación de un juguete.
static func _toy_color(material_name: String, source: Color, accent: Color, palette: Dictionary) -> Color:
	var key := material_name.strip_edges()
	var lower := key.to_lower()
	var toy := Color.WHITE
	var found := false
	if palette.has(key):
		toy = palette[key]
		found = true
	if not found:
		for candidate in palette:
			if String(candidate).to_lower() == lower:
				toy = palette[candidate]
				found = true
				break
	if not found:
		if lower == "skin":
			toy = TOY_SKIN
		elif lower == "face":
			toy = TOY_FACE
		elif lower == "hair":
			toy = TOY_HAIR
		elif source.s < 0.12:
			# El gris casi negro del pack es la piel; el gris de prenda se viste
			# con el color del personaje.
			toy = TOY_SKIN if source.v < 0.12 else accent.lightened(0.15)
		else:
			# Tono propio pero oscuro: se sube el valor y la saturación sin
			# cambiar la familia de color, así cada prenda conserva su intención.
			toy = Color.from_hsv(source.h, clampf(0.2 + source.s * 1.05, 0.0, 0.7), clampf(0.5 + source.v * 0.4, 0.5, 0.85))
	return _calm(toy)


## Apaga la paleta: saturada al 100 % y con el brillo a tope cansaba la vista en
## cuanto había varios corredores en pantalla. Con ropa y piel de tonos medios
## los cuerpos se leen como personajes normales.
static func _calm(color: Color) -> Color:
	return Color.from_hsv(color.h, color.s * 0.7, minf(color.v, 0.9) * 0.8)


## Capa de animación procedural (carrera inclinada, salto recogido, aterrizaje).
static func _add_rig(model: Node3D) -> void:
	for node in model.find_children("*", "Skeleton3D", true, false):
		var rig := CharacterRig.new()
		rig.name = "Rig"
		(node as Skeleton3D).add_child(rig)
		return


## Rig del modelo (o null si el cuerpo no trae esqueleto).
static func rig_of(model: Node3D) -> CharacterRig:
	if model == null:
		return null
	return model.find_child("Rig", true, false) as CharacterRig


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
## acelerado y el aire congela una zancada de la carrera. El rig procedural
## (`character_rig.gd`) añade la inclinación de esprint y la pose de salto.
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
