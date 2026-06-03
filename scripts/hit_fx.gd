extends Node2D
## 命中斩击特效：白光斩弧 + 内层青光，约 0.18s 自毁。dir=朝向。

@export var dir := 1.0
var _t := 0.0
const DUR := 0.18

func _ready() -> void:
	z_index = 25
	scale.x = dir

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DUR:
		queue_free()

func _draw() -> void:
	var k: float = clampf(_t / DUR, 0.0, 1.0)
	var a: float = 1.0 - k
	var r: float = 50.0 + 70.0 * k
	draw_arc(Vector2.ZERO, r, -0.7, 0.7, 18, Color(1, 1, 1, a * 0.9), 7.0 * (1.0 - k) + 2.0, true)
	draw_arc(Vector2.ZERO, r * 0.78, -0.6, 0.6, 18, Color(0.7, 1.0, 0.85, a * 0.7), 4.0, true)
