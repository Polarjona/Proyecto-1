class_name LevelInfo
extends Node

## Metadatos de un circuito: nombre, ronda, tiempos de medalla, récord por
## nivel y la ruta que siguen los bots. Cada escena de nivel lleva uno.
##
## `waypoints` y `lane_widths` son opcionales: si están vacíos, BotRacer usa su
## tabla por defecto (el circuito original de main.tscn). Los niveles nuevos
## rellenan ambos para que el mismo bot funcione en todos los mapas.

@export var level_id: String = "pivot_push"
@export var display_name: String = "Pivot Push"
@export var round_index: int = 1
@export var start_z: float = 5.0
@export var finish_z: float = -206.0
@export var course_length: float = 211.0
@export var gold_time: float = 70.0
@export var silver_time: float = 95.0
@export var bronze_time: float = 130.0
@export var waypoints: PackedVector3Array = PackedVector3Array()
@export var lane_widths: PackedFloat32Array = PackedFloat32Array()
## Origen de la parrilla de salida. Los circuitos cuya salida no está en el
## origen del mundo (la espiral del volcán) lo sobrescriben para que los bots
## no aparezcan en el vacío.
@export var start_position: Vector3 = Vector3.ZERO
## Curso que gira sobre sí mismo (espiral). El bot corrige su rumbo contra la
## línea de la ruta en vez de contra el eje X, que en una espiral no sirve.
@export var path_corridor: bool = false


func _ready() -> void:
	add_to_group("level_info")


func has_bot_path() -> bool:
	return not waypoints.is_empty()


## Avance del recorrido entre 0 y 1, para la barra del HUD y la clasificación
## en vivo. Con ruta propia se mide por el punto más cercano: la espiral del
## volcán vuelve sobre sus pasos, así que su Z sube y baja en cada vuelta y no
## sirve como medida de progreso. Sin ruta se usa la Z del circuito lineal.
func progress_at(point: Vector3) -> float:
	if has_bot_path() and waypoints.size() > 1:
		var best_distance := INF
		var best_index := 0
		for i in waypoints.size():
			var distance := waypoints[i].distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best_index = i
		return clampf(float(best_index) / float(waypoints.size() - 1), 0.0, 1.0)
	var span := maxf(start_z - finish_z, 0.01)
	return clampf((start_z - point.z) / span, 0.0, 1.0)


## Ancho de carril del waypoint `index`; si no hay tabla, un pasillo estrecho
## seguro para que los bots no se salgan en mapas sin datos.
func lane_width_at(index: int) -> float:
	if lane_widths.is_empty():
		return 1.5
	return lane_widths[clampi(index, 0, lane_widths.size() - 1)]
