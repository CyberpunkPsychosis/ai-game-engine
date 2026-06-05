extends Node2D
class_name StatusBar
## 头顶状态条：血量(红) + 架势(黄/破防红)。挂为 Actor2D 的子节点。

@export var width := 44.0
var actor: Actor2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var w := width
	var hpr := clampf(actor.hp / actor.max_hp, 0.0, 1.0)
	var pr := clampf(actor.posture / actor.posture_max, 0.0, 1.0)
	# 血条
	draw_rect(Rect2(-w * 0.5, 0, w, 4), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w * 0.5, 0, w * hpr, 4), Color(0.85, 0.2, 0.2))
	# 架势条
	draw_rect(Rect2(-w * 0.5, 6, w, 3), Color(0, 0, 0, 0.7))
	var pcol := Color(1.0, 0.3, 0.2) if actor.guard_broken else Color(1.0, 0.85, 0.2)
	draw_rect(Rect2(-w * 0.5, 6, w * pr, 3), pcol)
