extends Node
## 场景切换（带淡入淡出）。autoload 名: SceneManager
## 用法: SceneManager.change_scene("res://scenes/main.tscn")

@export var fade_duration := 0.3

var _layer: CanvasLayer
var _fade: ColorRect
var _is_transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _tween_alpha(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _tween_alpha(0.0)
	_is_transitioning = false

func _tween_alpha(target: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", target, fade_duration)
	await t.finished
