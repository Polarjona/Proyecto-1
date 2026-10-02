extends CanvasLayer

## Autoload singleton: fade-to-black transitions between scenes.
## Usage: TransitionManager.change_scene("res://scenes/main.tscn")

signal fade_out_finished
signal fade_in_finished

const FADE_DURATION := 0.4

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "FadeRect"
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


## Fade to black, change scene, then fade back in.
## The tree is paused during the fade so gameplay freezes mid-transition.
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = true
	await fade_out()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await fade_in()
	_busy = false


func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, FADE_DURATION)
	await tween.finished
	fade_out_finished.emit()


func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, FADE_DURATION)
	await tween.finished
	fade_in_finished.emit()
