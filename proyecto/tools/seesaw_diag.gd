extends SceneTree

## Standalone diagnostics for the seesaw: respawn the player at a few positions
## on and off the board, wait for the deck to settle, then check the tilt the
## script reports. Use like:
##   Godot --headless --path proyecto -s tools/seesaw_diag.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var game: Node = null
	for child in get_tree().get_root().get_children():
		if child.has_node("RaceManager") and child.get_node_or_null("RaceManager").get("is_running") == true:
			game = child
			break
	if game == null:
		assert(false, "no running game scene found in tree root")
	var manager := game.get_node_or_null("RaceManager") as Node
	assert(manager != null, "no RaceManager on game")
	var player: Node3D = game.get_first_node_in_group("player") as Node3D
	if player == null or not player.has_method("respawn_at"):
		push_error("player not found or missing respawn_at")
		return
	var saw: AnimatableBody3D = game.get_node_or_null("Course/SeeSaw") as AnimatableBody3D
	if saw == null:
		push_error("no Course/SeeSaw found")
		return

	var attempts := [
		{"name": "center",     "pos": Vector3(0.0, 1.0, -51.0),        "min": -0.5, "max": 0.5,  "desc": "horizontal with nobody on top"},
		{"name": "off-center", "pos": Vector3(0.0, 1.0, -50.4),        "min": 0.20, "max": 99.0, "desc": "0.6 m off-center makes it tip"},
		{"name": "far-side",   "pos": Vector3(0.0, 1.0, -48.0),        "min": 0.30, "max": 99.0, "desc": "weight past centre sends it to stop"},
	]
	for a in attempts:
		player.respawn_at(Transform3D(Basis.IDENTITY, a.pos))
		await physics_frame
		await physics_frame
		var tilt: float = float(saw.get_tilt())
		var ok: bool = tilt >= a.min and tilt <= a.max
		print("[SEESAW] %s @ %s  tilt=%.3f rad  expected %s  %s" % [
			a.name, a.pos, tilt, a.desc, "OK" if ok else "FAIL"])
		if not ok:
			_failures += 1
	print("[SEESAW] RESULT: %s (%d fallos)" % ["OK" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
