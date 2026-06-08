extends Node2D
class_name TSEnemy
## 敌人三型: charger(冲锋) / shooter(远程弹幕) / healer(治疗,逼你莽)
## 关键: 所有移动用 sdt = delta * game.scale_for(frozen_t)
##   → 单体冻结 / 全场定格 / 命中顿帧 自动让它静止, 不用各写一套。

var game
var type := "charger"
var w := 34.0
var h := 38.0
var vx := 0.0
var vy := 0.0
var hp := 30.0
var maxhp := 30.0
var frozen_t := 0.0    # 单体冻结剩余(真实时间)
var stun_t := 0.0      # 被打硬直
var flash_t := 0.0     # 受击白闪
var fire_t := 1.2
var color := Color(0.88, 0.39, 0.25)
var tilt := 0.0        # 被打倾斜
var _jit := Vector2.ZERO   # 残响卡帧抽搐(活动时小幅抖, 冻住归零)
var _jit_cd := 0.0

func setup() -> void:
	if type == "charger":
		hp = 30.0; maxhp = 30.0; w = 34.0; h = 38.0; color = Color(0.88, 0.39, 0.25)
	elif type == "shooter":
		hp = 22.0; maxhp = 22.0; w = 30.0; h = 40.0; color = Color(0.79, 0.64, 0.25)
	elif type == "healer":
		hp = 20.0; maxhp = 20.0; w = 28.0; h = 44.0; color = Color(0.48, 0.76, 0.54)
	fire_t = randf_range(1.8, 3.4)

func _process(delta: float) -> void:
	frozen_t = maxf(0.0, frozen_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	# 倾斜(真实时间回正, 纯表现)
	if stun_t > 0.0:
		var dir := 1.0 if vx >= 0.0 else -1.0
		tilt = dir * 0.45 * (stun_t / 0.3)
	else:
		tilt = lerpf(tilt, 0.0, minf(1.0, delta * 12.0))

	var s: float = game.scale_for(frozen_t)
	if s <= 0.0:
		_jit = Vector2.ZERO          # 冻住 = 残响被钉死, 抽搐停
		queue_redraw()
		return                       # 冻结 / 定格 / 顿帧 → 完全静止

	# 残响:永远重演死前一瞬 → 卡帧式抽搐(离散跳, 不平滑)
	_jit_cd -= delta
	if _jit_cd <= 0.0:
		_jit_cd = randf_range(0.06, 0.13)
		_jit = Vector2(randf_range(-1.6, 1.6), randf_range(-1.1, 1.1))

	var sdt := delta * s
	stun_t = maxf(0.0, stun_t - sdt)
	# 物理: 重力 + 击退惯性, 对房间地形做碰撞
	vy += 1700.0 * sdt
	var r: Dictionary = game.collide_move(position, Vector2(w * 0.5, h * 0.5), Vector2(vx, vy) * sdt)
	position = r.pos
	if r.floor and vy > 0.0:
		vy = 0.0
	vx = lerpf(vx, 0.0, minf(1.0, sdt * 8.0))
	if stun_t <= 0.0:
		_ai(sdt)                     # 硬直中: 被击退但不行动
	# 掉出房间(被打飞/走进断坑)→ 移除
	if position.y > game.room_h + 200.0:
		game.enemies.erase(self)
		queue_free()
		return
	queue_redraw()

func _ai(sdt: float) -> void:
	var p = game.player
	var dir := signf(p.position.x - position.x)
	if dir == 0.0:
		dir = 1.0
	if type == "charger":
		position.x += dir * 150.0 * sdt
	elif type == "shooter":
		var dist := absf(p.position.x - position.x)
		if dist < 300.0:
			position.x -= dir * 80.0 * sdt
		elif dist > 430.0:
			position.x += dir * 60.0 * sdt
		fire_t -= sdt
		if fire_t <= 0.0 and dist < 620.0:
			fire_t = 2.8
			game.spawn_bullet(position, p.position)
	elif type == "healer":
		position.x -= dir * 45.0 * sdt
		fire_t -= sdt
		if fire_t <= 0.0:
			fire_t = 1.4
			game.heal_allies(self)

func _draw() -> void:
	var frozen: bool = game.scale_for(frozen_t) <= 0.0
	var col := color
	if flash_t > 0.0:
		col = Color.WHITE
	elif frozen:
		col = Color(0.42, 0.66, 0.84)
	# 残响错位残影:活动时拖一层低透明偏移残像(卡帧错位感);冻住/受击时不画
	if not frozen and flash_t <= 0.0:
		var g := Color(color.r, color.g, color.b, 0.22)
		draw_rect(Rect2(-w * 0.5 - _jit.x * 1.7, -h * 0.5 - _jit.y * 1.7, w, h), g)
	draw_set_transform(_jit, tilt, Vector2.ONE)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), col)
	if frozen:
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.82, 0.94, 1.0), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 血条
	draw_rect(Rect2(-16, -h * 0.5 - 9, 32, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-16, -h * 0.5 - 9, 32.0 * clampf(hp / maxhp, 0.0, 1.0), 4), Color(0.88, 0.42, 0.42))
	if type == "healer":
		draw_rect(Rect2(-1.5, -7, 3, 14), Color(0.7, 1.0, 0.8))
		draw_rect(Rect2(-7, -1.5, 14, 3), Color(0.7, 1.0, 0.8))
