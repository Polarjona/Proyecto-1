class_name WaterZone
extends Area3D

## Volumen de agua del circuito abisal.
##
## No es un cuerpo sólido: es un `Area3D` que le dice al corredor «estás dentro
## del agua» para que cambie a natación. Al salir del volumen vuelve a la
## gravedad normal, y por eso el mapa alterna tramos inundados con islas secas
## donde están los checkpoints.

## Tamaño de la caja de agua, en metros (ancho, alto, largo).
@export var size: Vector3 = Vector3(25.0, 25.0, 100.0)
## Dibuja la lámina de agua en la cara superior (se ve desde abajo).
@export var draw_surface: bool = true
## Burbujas ascendentes. A 0 se apagan.
@export var bubble_count: int = 90
## Altura de crucero, en coordenadas de mundo. Al entrar en el volumen el
## corredor baja solo hasta aquí; Space/Shift lo siguen mandando.
@export var cruise_depth: float = -9.0
@export var auto_cruise: bool = true
## Franja de profundidad del tramo, en coordenadas de mundo. Mientras se nada
## no se sale por arriba ni por abajo: el corredor se queda dentro del pasillo
## de obstáculos en vez de colarse buceando por debajo.
@export var band_min_y: float = -1.0e9
@export var band_max_y: float = 1.0e9

var _surface_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("water_zones")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if draw_surface:
		_build_surface()
	if bubble_count > 0:
		_build_bubbles()


## Punto dentro del volumen, en coordenadas de mundo. El jugador lo usa al
## reaparecer en un checkpoint para saber si debe seguir nadando.
func contains_point(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= size.x * 0.5 \
		and absf(local.y) <= size.y * 0.5 \
		and absf(local.z) <= size.z * 0.5


func _on_body_entered(body: Node3D) -> void:
	apply_to(body)


func _on_body_exited(body: Node3D) -> void:
	if not body.has_method("set_swimming"):
		return
	# Si el cuerpo sigue dentro de la caja (p. ej. el área de un salto), no se
	# corta la natación.
	if contains_point(body.global_position):
		return
	release_from(body)


## Activa la natación y fija la cota de crucero del tramo.
func apply_to(body: Node3D) -> void:
	if body.has_method("set_swimming"):
		body.set_swimming(true)
	if auto_cruise and body.has_method("set_swim_depth"):
		body.set_swim_depth(cruise_depth)
	if band_max_y > band_min_y and body.has_method("set_swim_band"):
		body.set_swim_band(band_min_y, band_max_y)


func release_from(body: Node3D) -> void:
	if body.has_method("clear_swim_depth"):
		body.clear_swim_depth()
	if body.has_method("clear_swim_band"):
		body.clear_swim_band()
	if body.has_method("set_swimming"):
		body.set_swimming(false)


func _build_surface() -> void:
	_surface_material = StandardMaterial3D.new()
	_surface_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_surface_material.albedo_color = Color(0.24, 0.78, 0.86, 0.26)
	_surface_material.roughness = 0.12
	_surface_material.metallic = 0.25
	_surface_material.emission_enabled = true
	_surface_material.emission = Color(0.3, 0.85, 0.95)
	_surface_material.emission_energy_multiplier = 0.35
	_surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	var sheet := MeshInstance3D.new()
	sheet.name = "WaterSurface"
	sheet.mesh = plane
	sheet.material_override = _surface_material
	sheet.position.y = size.y * 0.5
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)

	# Segunda lámina aditiva: da el brillo de la superficie al mirar desde abajo.
	var shimmer := StandardMaterial3D.new()
	shimmer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shimmer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shimmer.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shimmer.albedo_color = Color(0.55, 0.95, 1.0, 0.06)
	shimmer.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow_sheet := MeshInstance3D.new()
	glow_sheet.name = "WaterShimmer"
	glow_sheet.mesh = plane
	glow_sheet.material_override = shimmer
	glow_sheet.position.y = size.y * 0.5 - 0.05
	glow_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow_sheet)


func _build_bubbles() -> void:
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.055
	bubble_mesh.height = 0.11
	bubble_mesh.radial_segments = 6
	bubble_mesh.rings = 3
	var bubble_material := StandardMaterial3D.new()
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.albedo_color = Color(0.8, 0.98, 1.0, 0.35)
	bubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bubble_mesh.material = bubble_material

	var bubbles := CPUParticles3D.new()
	bubbles.name = "Bubbles"
	bubbles.amount = bubble_count
	bubbles.lifetime = 11.0
	bubbles.preprocess = 6.0
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(size.x * 0.45, 0.5, size.z * 0.45)
	bubbles.position = Vector3(0.0, -size.y * 0.5 + 0.6, 0.0)
	bubbles.direction = Vector3.UP
	bubbles.spread = 12.0
	bubbles.gravity = Vector3(0.12, 1.35, 0.0)
	bubbles.initial_velocity_min = 0.25
	bubbles.initial_velocity_max = 1.1
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.6
	bubbles.color = Color(0.85, 1.0, 1.0, 0.55)
	bubbles.mesh = bubble_mesh
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubbles)
