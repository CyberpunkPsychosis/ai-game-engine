extends Node2D
class_name TSBullet
## 敌人子弹。受统一时间系统控制: sdt = delta * game.scale_for(frozen_t)

var game
var vel := Vector2.ZERO
var r := 7.0
var frozen_t := 0.0
var life := 4.0
var dead := false

func _process(delta: float) -> void:
	frozen_t = maxf(0.0, frozen_t - delta)        # 解冻按真实时间
	var s: float = game.scale_for(frozen_t)
	var sdt := delta * s
	if s > 0.0:
		position += vel * sdt
		life -= sdt
		if life <= 0.0 or position.x < -40.0 or position.x > game.room_w + 40.0 or position.y < -40.0 or position.y > game.room_h + 40.0:
			dead = true
	queue_redraw()

func _draw() -> void:
	var frozen: bool = game.scale_for(frozen_t) <= 0.0
	var c := Color(0.56, 0.83, 1.0) if frozen else Color(1.0, 0.81, 0.35)
	draw_circle(Vector2.ZERO, r, c)
	if frozen:
		draw_arc(Vector2.ZERO, r + 1.0, 0.0, TAU, 16, Color(0.85, 0.95, 1.0), 1.5)
