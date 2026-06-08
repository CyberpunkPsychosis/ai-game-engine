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
# 行为状态机(charger 用:approach→windup→lunge→recover, 让玩家有预警和破绽可躲/可反击)
var state := "approach"
var state_t := 0.0
var _lunge_dir := 1.0
var attacking := false      # 仅 lunge 命中窗口为 true → 只有这下碰到才伤人

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
	if stun_t > 0.0:
		attacking = false            # 被打断 → 取消扑击命中窗口
	else:
		_ai(sdt)                     # 硬直中: 被击退但不行动
	# 掉出房间(被打飞/走进断坑)→ 移除
	if position.y > game.room_h + 200.0:
		game.enemies.erase(self)
		queue_free()
		return
	queue_redraw()

func _ai(sdt: float) -> void:
	var p = game.player
	var dx: float = p.position.x - position.x
	var dir := signf(dx)
	if dir == 0.0:
		dir = 1.0
	var dist := absf(dx)
	if type == "charger":
		_charger_ai(sdt, dir, dist)
	elif type == "shooter":
		# 远程:保持中距, 太近后撤、太远逼近, 在射程内开火(不贴脸)
		if dist < 320.0:
			vx = -dir * 110.0
		elif dist > 480.0:
			vx = dir * 90.0
		else:
			vx = 0.0
		fire_t -= sdt
		if fire_t <= 0.0 and dist < 640.0:
			fire_t = randf_range(2.4, 3.2)
			game.spawn_bullet(position, p.position)
	elif type == "healer":
		# 治疗:边奶边躲, 永远跟你拉开
		vx = -dir * 70.0
		fire_t -= sdt
		if fire_t <= 0.0:
			fire_t = 1.4
			game.heal_allies(self)

## 扑影:逼近→预警蓄力→直线扑杀(冲过头)→露破绽。给玩家预警和反击窗口。
func _charger_ai(sdt: float, dir: float, dist: float) -> void:
	state_t -= sdt
	attacking = false
	match state:
		"approach":
			# 慢速逼近(玩家移速 320 > 这个 → 能甩开/绕后)
			vx = dir * 130.0 if dist > 165.0 else 0.0
			if dist <= 165.0:
				state = "windup"
				state_t = 0.42
		"windup":
			vx = -dir * 26.0            # 微后仰蓄力(配合 _draw 红框预警)
			if state_t <= 0.0:
				_lunge_dir = dir         # 锁定扑击方向(扑出后不再追踪 → 可侧身躲)
				state = "lunge"
				state_t = 0.32
		"lunge":
			vx = _lunge_dir * 560.0     # 直线扑杀(会冲过头)
			attacking = true
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.55
		"recover":
			vx = 0.0                    # 露破绽:站定可被反击
			if state_t <= 0.0:
				state = "approach"

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
	# 扑影预警/扑击表现:蓄力闪红框(可躲信号), 扑出拖影(冲过头)
	if type == "charger" and not frozen:
		if state == "windup":
			var pulse := 0.4 + 0.6 * absf(sin(state_t * 26.0))
			draw_rect(Rect2(-w * 0.5 - 3.0, -h * 0.5 - 3.0, w + 6.0, h + 6.0), Color(1.0, 0.40, 0.34, pulse), false, 2.5)
		elif state == "lunge":
			for k in 3:
				var a := 0.28 * (1.0 - float(k) / 3.0)
				draw_rect(Rect2(-w * 0.5 - _lunge_dir * float(k + 1) * 12.0, -h * 0.5, w, h), Color(1.0, 0.6, 0.42, a))
	# 血条
	draw_rect(Rect2(-16, -h * 0.5 - 9, 32, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-16, -h * 0.5 - 9, 32.0 * clampf(hp / maxhp, 0.0, 1.0), 4), Color(0.88, 0.42, 0.42))
	if type == "healer":
		draw_rect(Rect2(-1.5, -7, 3, 14), Color(0.7, 1.0, 0.8))
		draw_rect(Rect2(-7, -1.5, 14, 3), Color(0.7, 1.0, 0.8))
