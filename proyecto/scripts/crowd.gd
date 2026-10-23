extends Node3D

## Multitud decorativa en gradas laterales. Dos MultiMesh por lado (cuerpo y
## cabeza) mantienen el coste de dibujado bajo aunque haya cientos de beans.
## Usan el shader "toy" con color por instancia para integrarse con el arte.

const TOY_SHADER: Shader = preload("res://shaders/toy.gdshader")

const PASTEL_COLORS := [
	Color(1.0, 0.45, 0.65),
	Color(1.0, 0.82, 0.3),
	Color(0.4, 0.9, 1.0),
	Color(0.6, 1.0, 0.5),
	Color(0.75, 0.55, 1.0),
	Color(1.0, 0.62, 0.35),
	Color(0.95, 0.95, 1.0),
]

@export var rows: int = 3
@export var per_row: int = 26
@export var stand_offset: float = 14.0
@export var stand_length: float = 48.0
@export var stand_center_z: float = -36.0

var _crowd_material: ShaderMaterial


func _ready() -> void:
	_crowd_material = ShaderMaterial.new()
	_crowd_material.shader = TOY_SHADER
	_crowd_material.set_shader_parameter("base_color", Color.WHITE)
	_crowd_material.set_shader_parameter("rim_strength", 0.55)
	_crowd_material.set_shader_parameter("rim_power", 3.0)
	_crowd_material.set_shader_parameter("emission_strength", 0.04)
	_crowd_material.set_shader_parameter("gradient_amount", 0.08)
	_crowd_material.set_shader_parameter("use_vertex_color", true)
	_build_stand(-1.0)
	_build_stand(1.0)
	_build_crowd(-1.0)
	_build_crowd(1.0)


func _build_stand(side: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.0, 1.4, stand_length)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.15, 0.27)
	material.roughness = 0.92
	mesh.material = material
	var stand := MeshInstance3D.new()
	stand.name = "Stand%s" % ("Left" if side < 0.0 else "Right")
	stand.mesh = mesh
	stand.position = Vector3(side * (stand_offset + 1.0), 0.7, stand_center_z)
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stand)

	# Glowing trim along the inner edge of the stand.
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(0.1, 0.1, stand_length - 0.5)
	var trim_material := StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.5, 0.95, 1.0)
	trim_material.emission_enabled = true
	trim_material.emission = Color(0.32, 0.85, 1.0)
	trim_material.emission_energy_multiplier = 2.2
	trim_mesh.material = trim_material
	var trim := MeshInstance3D.new()
	trim.name = "StandTrim%s" % ("Left" if side < 0.0 else "Right")
	trim.mesh = trim_mesh
	trim.position = Vector3(side * (stand_offset - 0.95), 1.46, stand_center_z)
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trim)


func _build_crowd(side: float) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.17
	capsule.height = 0.7
	capsule.material = _crowd_material

	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	head.radial_segments = 12
	head.rings = 6
	head.material = _crowd_material

	var bodies := _make_multimesh(capsule, "Crowd%s" % ("Left" if side < 0.0 else "Right"))
	var heads := _make_multimesh(head, "CrowdHeads%s" % ("Left" if side < 0.0 else "Right"))
	var count := rows * per_row

	var index := 0
	var step := stand_length / float(per_row)
	for row in rows:
		for i in per_row:
			var z := stand_center_z - stand_length * 0.5 + step * (i + 0.5)
			var x := side * (stand_offset - 0.6 + float(row) * 1.0) + randf_range(-0.2, 0.2)
			var y := 1.55 + float(row) * 0.55
			var basis := Basis(Vector3.UP, randf_range(-0.5, 0.5)).scaled(Vector3.ONE * randf_range(0.85, 1.15))
			var color: Color = PASTEL_COLORS[randi() % PASTEL_COLORS.size()]
			bodies.set_instance_transform(index, Transform3D(basis, Vector3(x, y, z)))
			bodies.set_instance_color(index, color)
			var head_basis := basis.scaled(Vector3(1.0, 1.05, 1.0))
			heads.set_instance_transform(index, Transform3D(head_basis, Vector3(x, y + 0.34, z)))
			heads.set_instance_color(index, color)
			index += 1


func _make_multimesh(mesh: Mesh, node_name: String) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = rows * per_row
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multimesh
