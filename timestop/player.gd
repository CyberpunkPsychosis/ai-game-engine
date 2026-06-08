extends Node2D
class_name TSPlayer
## 玩家(永远实时, 不受时停影响)。移动/跳由 game 填 move_dir/want_jump。

var game
var w := 28.0
var h := 46.0
var vx := 0.0
var vy := 0.0
var onground := false
var facing := 1
var hp := 100.0
var maxhp := 100.0
var iframe := 0.0

var move_dir := 0.0
var want_jump := false
var atk_t := 0.0
var atkcd := 0.0

func tick(delta: float) -> void:
	vx = move_dir * 320.0
	if absf(move_dir) > 0.2:
		facing = 1 if move_dir > 0.0 else -1
	if want_jump and onground:
		vy = -640.0
		onground = false
	want_jump = false
	vy += 1700.0 * delta
	position.x += vx * delta
	position.y += vy * delta
	iframe = maxf(0.0, iframe - delta)
	atk_t = maxf(0.0, atk_t - delta)
	atkcd = maxf(0.0, atkcd - delta)
	onground = false
	if position.y + h * 0.5 >= game.GROUND:
		position.y = game.GROUND - h * 0.5
		vy = 0.0
		onground = true
	position.x = clampf(position.x, 16.0, 1264.0)
	queue_redraw()

func _draw() -> void:
	var col := Color(0.36, 0.75, 0.80)
	if iframe > 0.0 and int(iframe * 20.0) % 2 == 0:
		col = Color(0.62, 0.90, 1.0)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), col)
	# 朝向小标
	draw_rect(Rect2(facing * 8.0 - 2.0, -h * 0.5 + 6.0, 4, 6), Color(0.9, 0.97, 1.0))
	# 攻击挥砍框
	if atk_t > 0.0:
		var ax := facing * 34.0
		draw_rect(Rect2(ax - 23.0, -23.0, 46, 46), Color(1, 1, 1, 0.45))
