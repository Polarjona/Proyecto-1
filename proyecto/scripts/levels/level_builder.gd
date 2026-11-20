@tool
extends Node3D

## Genera los circuitos que no están esculpidos a mano. Elige el kit del tema y
## le pasa la escena como `host`; el kit construye la pista, el escenario y los
## actores. La geometría y los materiales compartidos viven en `level_kit.gd`:
##
##   level_kind = "glacier"  ->  Glacier Gallop (ronda 3)
##   level_kind = "volcano"  ->  Lava Vortex    (ronda 4)
##   level_kind = "ocean"    ->  Abyss Run      (carrera clásica)
##
## El script es `@tool`: al abrir la escena en el editor se genera el circuito
## completo marcando cada nodo generado con `owner`. Al guardar la escena
## (Ctrl+S), el mapa queda horneado en el `.tscn` y se edita elemento por
## elemento como pivot_push.tscn; desde entonces el generador no reconstruye nada
## (detecta el contenido guardado) y solo mantiene la cámara del volcán.

const GLACIER_KIT := preload("res://scripts/levels/glacier_kit.gd")
const VOLCANO_KIT := preload("res://scripts/levels/volcano_kit.gd")
const OCEAN_KIT := preload("res://scripts/levels/ocean_kit.gd")

@export var level_kind: String = "glacier"

## Kit activo. Se guarda porque es un `RefCounted`: sin esta referencia el
## recolector se lo llevaría por delante en cuanto `_build()` terminase.
var _kit: RefCounted
## Solo el volcán necesita seguir trabajando después de construir (cámara).
var _volcano: RefCounted


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_editor_preview()
		return
	# Escena ya horneada: el circuito está guardado y no hay que generarlo.
	if get_child_count() > 0:
		_resume_baked()
		return
	_build()


func _build_editor_preview() -> void:
	if get_child_count() > 0:
		return
	_build()
	if get_tree().edited_scene_root == self:
		_own_generated(self)


## Construye la pista del tema elegido. Todo lo que cuelga del nodo lo pone el
## kit; aquí solo se elige cuál y se recuerda para `_process`.
func _build() -> void:
	match level_kind:
		"volcano":
			_kit = VOLCANO_KIT.new()
			_volcano = _kit
		"ocean":
			_kit = OCEAN_KIT.new()
		_:
			_kit = GLACIER_KIT.new()
	_kit.host = self
	_kit.build()
	set_process(_volcano != null)


## Da `owner` a lo que crea el generador para que se guarde al salvar la escena.
## No entra en escenas instanciadas ni en nodos con script: su contenido se crea
## en `_ready` y se duplicaría si también se horneara.
func _own_generated(node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = self
		if child.scene_file_path.is_empty() and child.get_script() == null:
			_own_generated(child)


## Escena ya horneada: no se genera nada. Solo se recupera la ruta del volcán,
## que la cámara usa para seguir la espiral (la pendiente sale de las mismas
## constantes con las que se construyó la rampa).
func _resume_baked() -> void:
	LevelLod.apply(self)
	if level_kind != "volcano":
		return
	var kit := VOLCANO_KIT.new()
	kit.host = self
	kit.resume_baked()
	_volcano = kit
	set_process(true)


## La cámara sigue la espiral del volcán; el resto de circuitos no la necesitan.
func _process(delta: float) -> void:
	if _volcano != null:
		_volcano.follow_camera(delta)
