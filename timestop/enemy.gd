extends Node2D
class_name TSEnemy
## 敌人三型: charger(近战扑影) / shooter(远程悬铳) / healer(治疗缚生)
## 标准 2D 平台怪 AI(参考死亡细胞/通用 FSM):
##   patrol(巡逻:撞墙或到崖边自动掉头, 固定来回线路, 不主动追)
##   → alert(进入察觉范围短暂一顿, 转向你)
##   → chase(追, 但崖边会停住不跳崖)
##   → windup(预警蓄力, 闪红框) → lunge(锁向直线扑杀, 冲过头) → recover(露破绽)
##   被打 → stagger(击退 + 取消当前动作/攻击, 短暂硬直)→ 重新评估
## 移动统一用 sdt = delta * game.scale_for(frozen_t),被冻/定格/顿帧自动静止。

var game
var type := "charger"
var w := 34.0
var h := 38.0
var vx := 0.0
var vy := 0.0
var hp := 30.0
var maxhp := 30.0
var frozen_t := 0.0    # 单体冻结剩余(真实时间)
var stun_t := 0.0      # 被打硬直(hitstun:期间不行动、不攻击)
var flash_t := 0.0     # 受击白闪
var fire_t := 1.2
var color := Color(0.88, 0.39, 0.25)
var tilt := 0.0        # 被打倾斜
var _jit := Vector2.ZERO   # 残响卡帧抽搐(活动时小幅抖, 冻住归零)
var _jit_cd := 0.0
# 行为状态机
var state := "patrol"
var state_t := 0.0
var patrol_dir := 1.0      # 巡逻方向(撞墙/崖边/到边界翻转)
var home_x := 0.0          # 出生点 x(巡逻以它为中心来回)
var _home_set := false
var lost_t := 0.0          # 脱离视野计时(超时回巡逻)
var _lunge_dir := 1.0
var attacking := false     # 仅 lunge 命中窗口为 true → 只有这下碰到才伤人

const PATROL_SPD := 64.0
const CHASE_SPD := 150.0
const AGGRO_X := 360.0      # 横向察觉范围
const AGGRO_Y := 130.0      # 纵向察觉范围(差不多同层才追)
const DEAGGRO := 1.6        # 脱离视野多久回巡逻
const ATK_RANGE := 72.0
const PATROL_RANGE := 220.0 # 巡逻以出生点为中心来回的半幅(固定短线路)

func setup() -> void:
	if type == "charger":
		hp = 30.0; maxhp = 30.0; w = 34.0; h = 38.0; color = Color(0.88, 0.39, 0.25)
	elif type == "shooter":
		hp = 22.0; maxhp = 22.0; w = 30.0; h = 40.0; color = Color(0.79, 0.64, 0.25)
	elif type == "healer":
		hp = 20.0; maxhp = 20.0; w = 28.0; h = 44.0; color = Color(0.48, 0.76, 0.54)
	fire_t = randf_range(1.8, 3.4)
	patrol_dir = 1.0 if randf() < 0.5 else -1.0
	state = "patrol"

## 被玩家命中:击退 + 取消当前动作/攻击 + 短硬直(hitstun)。game._hit_enemy 调它。
func stagger(from_dir: float) -> void:
	flash_t = 0.10
	stun_t = 0.26
	vx = from_dir * 320.0
	attacking = false
	state = "recover"          # 打断扑击/攻击 → 进短暂破绽
	state_t = 0.34

func _process(delta: float) -> void:
	frozen_t = maxf(0.0, frozen_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	if stun_t > 0.0:
		var d := 1.0 if vx >= 0.0 else -1.0
		tilt = d * 0.45 * clampf(stun_t / 0.26, 0.0, 1.0)
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
		attacking = false            # hitstun 期间:不行动、不攻击
	else:
		_ai(sdt)
	# 掉出房间(被打飞/走进断坑)→ 移除
	if position.y > game.room_h + 200.0:
		game.enemies.erase(self)
		queue_free()
		return
	queue_redraw()

# ---------------------------------------------------------------- 地形感知(巡逻/追击用)
func _solid_at(x: float, y: float) -> bool:
	for sd in game.solids:
		if (sd as Rect2).has_point(Vector2(x, y)):
			return true
	return false

## 前方下面有没有地(没地=崖边)
func _floor_ahead(dir: float) -> bool:
	return _solid_at(position.x + dir * (w * 0.5 + 4.0), position.y + h * 0.5 + 10.0)

## 正前方有没有墙
func _wall_ahead(dir: float) -> bool:
	return _solid_at(position.x + dir * (w * 0.5 + 5.0), position.y)

## 巡逻:撞墙/到崖边/越出出生点 ±PATROL_RANGE 自动掉头 → 固定短线路, 不掉崖
func _patrol_move() -> void:
	if not _home_set:
		home_x = position.x
		_home_set = true
	var out_bound := (patrol_dir > 0.0 and position.x > home_x + PATROL_RANGE) \
		or (patrol_dir < 0.0 and position.x < home_x - PATROL_RANGE)
	if _wall_ahead(patrol_dir) or not _floor_ahead(patrol_dir) or out_bound:
		patrol_dir = -patrol_dir
	vx = patrol_dir * PATROL_SPD

# ---------------------------------------------------------------- AI 分发
func _ai(sdt: float) -> void:
	var p = game.player
	var dx: float = p.position.x - position.x
	var dy: float = p.position.y - position.y
	var pdir := 1.0 if dx >= 0.0 else -1.0
	var adist := absf(dx)
	var sees := adist < AGGRO_X and absf(dy) < AGGRO_Y
	if type == "charger":
		_charger(sdt, pdir, adist, sees)
	elif type == "shooter":
		_shooter(sdt, p, pdir, adist, sees)
	elif type == "healer":
		_healer(sdt, pdir, sees)

## 扑影:巡逻→察觉→追(崖边停)→预警→扑杀→破绽
func _charger(sdt: float, pdir: float, adist: float, sees: bool) -> void:
	state_t -= sdt
	attacking = false
	match state:
		"patrol":
			_patrol_move()
			if sees:
				state = "alert"
				state_t = 0.22
		"alert":
			vx = 0.0
			patrol_dir = pdir                 # 转向玩家
			if state_t <= 0.0:
				state = "chase"
				lost_t = 0.0
		"chase":
			if sees:
				lost_t = 0.0
			else:
				lost_t += sdt
				if lost_t > DEAGGRO:
					state = "patrol"
					return
			patrol_dir = pdir
			if adist <= ATK_RANGE:
				vx = 0.0
				state = "windup"
				state_t = 0.40
			elif _floor_ahead(pdir):          # 崖边停住, 不跳崖自杀
				vx = pdir * CHASE_SPD
			else:
				vx = 0.0
		"windup":
			vx = -pdir * 24.0                 # 微后仰蓄力(配合红框预警)
			if state_t <= 0.0:
				_lunge_dir = pdir              # 锁定方向(扑出后不再追踪 → 可侧身躲)
				state = "lunge"
				state_t = 0.30
		"lunge":
			vx = _lunge_dir * 540.0           # 直线扑杀(冲过头)
			attacking = true
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.48
		"recover":
			vx = 0.0                          # 露破绽:可被反击
			if state_t <= 0.0:
				state = "chase" if sees else "patrol"

## 悬铳:不在战斗范围就巡逻;进范围保持中距、不贴脸、开火
func _shooter(sdt: float, p, pdir: float, adist: float, sees: bool) -> void:
	if not sees and adist > AGGRO_X * 1.15:
		_patrol_move()
		return
	if adist < 300.0:
		vx = -pdir * 110.0 if _floor_ahead(-pdir) else 0.0   # 后撤(别掉崖)
	elif adist > 480.0:
		vx = pdir * 90.0 if _floor_ahead(pdir) else 0.0
	else:
		vx = 0.0
	fire_t -= sdt
	if fire_t <= 0.0 and adist < 640.0:
		fire_t = randf_range(2.4, 3.2)
		game.spawn_bullet(position, p.position)

## 缚生:见你就逃(别掉崖), 否则巡逻;定时奶活同伴
func _healer(sdt: float, pdir: float, sees: bool) -> void:
	if sees:
		vx = -pdir * 92.0 if _floor_ahead(-pdir) else 0.0
	else:
		_patrol_move()
	fire_t -= sdt
	if fire_t <= 0.0:
		fire_t = 1.4
		game.heal_allies(self)

# ---------------------------------------------------------------- 渲染
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
