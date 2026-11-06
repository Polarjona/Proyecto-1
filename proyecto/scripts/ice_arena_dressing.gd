extends Node3D

## Set-dressing de la arena de los barridos del Glacier Gallop.
##
## Todo son `MeshInstance3D` sueltos: ni cuerpos, ni colisión, ni cambios en el
## recorrido. Se coloca fuera del disco que barren los brazos o por encima de
## ellos (los brazos llegan a 7,95 m y el área de golpe sube a 1,1 m), así que
## el detalle no estorba ni se atraviesa con la barra.
##
## Se construye una vez al cargar la escena. Se cuelga de `Decor`, el mismo nodo
## donde vive el resto de la decoración del mapa.

## Cada pared del arena: eje, cara interior y cara exterior.
const WALLS := [
	{"center": -8.425, "inner": -7.82, "outer": -9.03},
	{"center": 8.365, "inner": 7.76, "outer": 8.97},
]
const WALL_TOP := 3.0
const ARENA_Z := -34.0
const ARENA_HALF_LENGTH := 9.6

var _ice: StandardMaterial3D
var _ice_dark: StandardMaterial3D
var _snow: StandardMaterial3D
var _glow: StandardMaterial3D
var _crack: StandardMaterial3D
var _cloth: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_wall_snow()
	_build_icicles()
	_build_runes()
	_build_wall_banners()
	_build_lamps()
	_build_gate_markers()
	_build_floor_cracks()
	_build_crystal_clusters()
	_build_distant_spires()


# ----------------------------------------------------------------- materials
func _make_materials() -> void:
	_ice = StandardMaterial3D.new()
	_ice.albedo_color = Color(0.72, 0.86, 0.94)
	_ice.roughness = 0.5
	_ice.metallic = 0.05

	_ice_dark = StandardMaterial3D.new()
	_ice_dark.albedo_color = Color(0.19, 0.38, 0.48)
	_ice_dark.roughness = 0.82

	_snow = StandardMaterial3D.new()
	_snow.albedo_color = Color(0.95, 0.97, 1.0)
	_snow.roughness = 0.95

	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.55, 0.93, 1.0)
	_glow.emission_enabled = true
	_glow.emission = Color(0.42, 0.88, 1.0)
	_glow.emission_energy_multiplier = 1.7
	_glow.roughness = 0.3

	_crack = StandardMaterial3D.new()
	_crack.albedo_color = Color(0.4, 0.82, 0.96)
	_crack.emission_enabled = true
	_crack.emission = Color(0.36, 0.78, 0.95)
	_crack.emission_energy_multiplier = 0.9
	_crack.roughness = 0.4

	_cloth = StandardMaterial3D.new()
	_cloth.albedo_color = Color(0.16, 0.36, 0.62)
	_cloth.roughness = 0.9


# ------------------------------------------------------------------- helpers
func _mesh(mesh: Mesh, material: Material, at: Vector3, node_name: String,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rot_deg
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _box(size: Vector3, at: Vector3, material: Material, node_name: String,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, material, at, node_name, rot_deg)


## Cono de punta arriba (cristales y agujas) o de punta abajo (carámbanos).
func _cone(radius: float, height: float, at: Vector3, material: Material,
		node_name: String, points_down: bool = false,
		rot_deg: Vector3 = Vector3.ZERO, segments: int = 7) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if points_down else 0.0
	mesh.bottom_radius = 0.0 if points_down else radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	return _mesh(mesh, material, at, node_name, rot_deg)


func _sphere(radius: float, at: Vector3, material: Material,
		node_name: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _mesh(mesh, material, at, node_name)


# -------------------------------------------------------------------- piezas
## Cresta de nieve sobre el lomo de las dos paredes: remata el borde del arena.
func _build_wall_snow() -> void:
	for wall in WALLS:
		var center: float = wall["center"]
		var side_name := "L" if center < 0.0 else "R"
		_box(Vector3(1.06, 0.2, ARENA_HALF_LENGTH * 2.0 + 0.3),
			Vector3(center, WALL_TOP + 0.08, ARENA_Z), _snow,
			"ArenaSnowRidge" + side_name)
		# Ondulación: tres montículos por pared, para que la cresta no sea un
		# listón recto.
		for i in 3:
			var mound_z := ARENA_Z + (float(i) - 1.0) * 6.2
			var mound := _sphere(0.62, Vector3(center, WALL_TOP + 0.02, mound_z),
				_snow, "ArenaSnowMound%s%d" % [side_name, i])
			mound.scale = Vector3(0.9, 0.42, 2.4)


## Carámbanos colgando de la cara interior de las paredes.
func _build_icicles() -> void:
	for wall in WALLS:
		var inner: float = wall["inner"]
		var side_name := "L" if float(wall["center"]) < 0.0 else "R"
		var lean := -1.0 if side_name == "L" else 1.0
		for i in 10:
			var t := float(i) / 9.0
			var z := ARENA_Z - ARENA_HALF_LENGTH + 1.1 + t * (ARENA_HALF_LENGTH * 2.0 - 2.2)
			var wobble := sin(float(i) * 2.7)
			var length := 0.6 + absf(wobble) * 0.62
			var radius := 0.1 + absf(cos(float(i) * 1.9)) * 0.08
			_cone(radius, length,
				Vector3(inner - lean * 0.05, WALL_TOP - 0.06 - length * 0.5, z),
				_ice, "ArenaIcicle%s%d" % [side_name, i], true,
				Vector3(0.0, 0.0, lean * (4.0 + wobble * 5.0)))


## Runas encendidas sobre la cara interior: el arena se lee desde el hielo.
func _build_runes() -> void:
	var rune_z := [-27.4, -31.2, -36.8, -40.6]
	for wall in WALLS:
		var inner: float = wall["inner"]
		var side_name := "L" if float(wall["center"]) < 0.0 else "R"
		var lean := -1.0 if side_name == "L" else 1.0
		for i in rune_z.size():
			var z: float = rune_z[i]
			var frame := _box(Vector3(0.06, 0.66, 1.86),
				Vector3(inner - lean * 0.03, 1.95, z), _ice_dark,
				"ArenaRuneFrame%s%d" % [side_name, i])
			frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_box(Vector3(0.04, 0.2, 1.5),
				Vector3(inner - lean * 0.06, 1.95, z), _glow,
				"ArenaRuneGlow%s%d" % [side_name, i])
			# Dos muescas a los lados de la runa.
			for notch in 2:
				var notch_x := -0.72 if notch == 0 else 0.72
				_box(Vector3(0.04, 0.5, 0.12),
					Vector3(inner - lean * 0.06, 1.95, z + notch_x),
					_glow, "ArenaRuneNotch%s%d_%d" % [side_name, i, notch])


## Estandartes colgados por fuera: se ven al llegar desde el aire.
func _build_wall_banners() -> void:
	for wall in WALLS:
		var outer: float = wall["outer"]
		var side_name := "L" if float(wall["center"]) < 0.0 else "R"
		var lean := -1.0 if side_name == "L" else 1.0
		for i in 2:
			var z := ARENA_Z + (float(i) - 0.5) * 8.0
			_box(Vector3(0.09, 1.5, 0.72),
				Vector3(outer + lean * 0.06, 2.05, z), _cloth,
				"ArenaBanner%s%d" % [side_name, i])
			_box(Vector3(0.11, 0.1, 0.86),
				Vector3(outer + lean * 0.06, 2.86, z), _ice_dark,
				"ArenaBannerBar%s%d" % [side_name, i])
			_box(Vector3(0.12, 0.16, 0.16),
				Vector3(outer + lean * 0.06, 1.28, z), _glow,
				"ArenaBannerTip%s%d" % [side_name, i])


## Lámparas de hielo en el lomo de las paredes. Solo la pieza: sin `OmniLight`
## dentro del arena, que alumbraba la pared por la parte interior.
func _build_lamps() -> void:
	for wall in WALLS:
		var center: float = wall["center"]
		var side_name := "L" if center < 0.0 else "R"
		for i in 2:
			var z := -28.0 - float(i) * 12.0
			_cone(0.3, 0.44, Vector3(center, WALL_TOP + 0.28, z), _ice_dark,
				"ArenaLampBase%s%d" % [side_name, i])
			_sphere(0.22, Vector3(center, WALL_TOP + 0.6, z), _glow,
				"ArenaLampGlobe%s%d" % [side_name, i])


## Postes de las dos puertas del arena. Van sobre el lomo de las paredes, por
## encima de la zona de golpe: se ven desde lejos y no estorban en el carril.
func _build_gate_markers() -> void:
	for wall in WALLS:
		var center: float = wall["center"]
		var side_name := "L" if center < 0.0 else "R"
		for i in 2:
			var z := -25.6 - float(i) * 16.8
			_box(Vector3(1.0, 0.32, 1.0), Vector3(center, WALL_TOP + 0.34, z),
				_ice_dark, "ArenaGateBase%s%d" % [side_name, i])
			_cone(0.34, 2.4, Vector3(center, WALL_TOP + 1.76, z), _ice,
				"ArenaGatePost%s%d" % [side_name, i])
			_sphere(0.2, Vector3(center, WALL_TOP + 3.02, z), _glow,
				"ArenaGateGlow%s%d" % [side_name, i])


## Grietas luminosas en el suelo, por debajo de la barra (que gira a 0,35 m).
func _build_floor_cracks() -> void:
	var spots := [
		Vector3(-3.4, 0.0, -27.0), Vector3(4.2, 0.0, -30.4),
		Vector3(-5.6, 0.0, -33.6), Vector3(2.8, 0.0, -36.6),
		Vector3(-2.2, 0.0, -39.8), Vector3(5.4, 0.0, -42.2),
	]
	for i in spots.size():
		var spot: Vector3 = spots[i]
		var crack := _box(Vector3(0.06, 0.02, 1.7),
			Vector3(spot.x, 0.03, spot.z), _crack, "ArenaFloorCrack%d" % i,
			Vector3(0.0, 24.0 + float(i) * 21.0, 0.0))
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(0.05, 0.02, 0.8),
			Vector3(spot.x + 0.55, 0.03, spot.z + 0.5), _crack,
			"ArenaFloorBranch%d" % i, Vector3(0.0, 70.0 + float(i) * 13.0, 0.0))


## Racimos de cristal pegados a la cara interior de las paredes, fuera del
## disco de los brazos. Crecen hacia dentro del muro, así que no dejan un
## cristal fantasma en mitad del carril.
func _build_crystal_clusters() -> void:
	var clusters := [
		Vector3(-7.55, 0.0, -22.2), Vector3(7.5, 0.0, -22.6),
		Vector3(-7.5, 0.0, -45.2), Vector3(7.55, 0.0, -45.6),
	]
	for i in clusters.size():
		var center: Vector3 = clusters[i]
		var into_wall := 1.0 if center.x > 0.0 else -1.0
		for c in 3:
			var height := 0.5 + absf(sin(float(i) * 1.7 + float(c) * 2.1)) * 0.55
			var spread := 0.28 + float(c) * 0.18
			_cone(0.16 + float(c) * 0.05, height,
				Vector3(center.x + into_wall * spread, height * 0.5,
					center.z + spread * (0.6 if c != 2 else -0.8)),
				_ice, "ArenaCrystal%d_%d" % [i, c], false,
				Vector3(sin(float(c) * 2.0) * 14.0, float(c) * 40.0,
					cos(float(i + c) * 1.4) * 12.0))


## Agujas de hielo al otro lado de las paredes: dan fondo al arena.
func _build_distant_spires() -> void:
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (11.6 + float(i % 4) * 1.9)
		var z := -16.0 - float(i) * 5.4
		var height := 7.0 + float(i % 3) * 2.6
		_cone(1.2 + float(i % 3) * 0.5, height,
			Vector3(x, -9.0 + height * 0.5, z), _ice_dark,
			"ArenaSpire%d" % i, false,
			Vector3(0.0, float(i) * 37.0, side * (3.0 + float(i % 2) * 4.0)))
		_cone(0.5, height * 0.35, Vector3(x, -9.0 + height + height * 0.14, z),
			_ice, "ArenaSpireTip%d" % i, false,
			Vector3(0.0, float(i) * 37.0, 0.0))
