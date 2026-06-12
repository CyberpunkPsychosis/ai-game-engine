extends Node2D
class_name TSSpark
## 命中火花(走真实时间, 不受时停影响, 纯表现)

var vel := Vector2.ZERO
var life := 0.4
var col := Color.WHITE

func _process(delta: float) -> void:
	position += vel * delta
	vel.y += 600.0 * delta
	life -= delta
	modulate.a = clampf(life * 2.2, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-2, -2, 4, 4), col)
