@tool
extends "res://scripts/ocean/ocean_hazard.gd"
var count: int = 6
var span: float = 13.0
var hit_radius: float = 0.7

var _time: float = 0.0
var _mines: Array[Node3D] = []
var _mine_shapes: Array[CollisionShape3D] = []
var _mine_ghosts: Array = []

func _ready() -> void:
	touch_kind = "kill"
	# Una bola de detección por mina en vez de una barra sólida de 14 m:
	# antes se moría en el hueco vacío que hay entre dos esferas.
	_setup(Vector3.ZERO, 7.5, 0.5)
	for i in count:
		var at := Vector3(-span * 0.5 + float(i) * span / float(maxi(count - 1, 1)), 0.0, 0.0)
		var mine := Node3D.new()
		mine.position = at
		add_child(mine)
		_add_sphere(mine, 0.28, OceanStyle.glow(OceanStyle.CORAL_ALT, 2.0), Vector3.ZERO)
		_add_sphere(mine, 0.5, OceanStyle.additive(OceanStyle.CORAL_ALT, 0.14), Vector3.ZERO)
		_mines.append(mine)
		var shape := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = hit_radius
		shape.shape = ball
		shape.position = at
		add_child(shape)
		_mine_shapes.append(shape)
		_mine_ghosts.append(_add_hitbox_ghost(Vector3.ONE * hit_radius * 2.0, at))

func _process(delta: float) -> void:
	_time += delta
	for i in _mines.size():
		var bob := sin(_time * 1.4 + float(i) * 0.7) * 0.55
		_mines[i].position.y = bob
		_mine_shapes[i].position.y = bob
		# Sin `:=`: el array guarda nodos o `null`, así que el tipo no se
		# puede inferir (y el `null` hay que descartarlo igual).
		var ghost = _mine_ghosts[i]
		if ghost != null:
			ghost.position.y = bob


## Estrella de mar giratoria: cinco brazos que barren el carril.
