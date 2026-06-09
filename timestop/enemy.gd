extends Node2D
class_name TSEnemy
## 敌人角色库(参考死亡细胞:角色定位优先, 同一套 FSM 派生多种威胁)。
## 每种怪逼玩家做不同应对 → 小队伍也能打出花样:
##   charger  近战扑影  —— 直线扑杀(冲过头, 可侧身躲)
##   leaper   跳扑者    —— 蓄力后弧线起跳砸下(躲开有长破绽)
##   archer   弓手(可躲)—— 水平直射箭, 可跳过/可下穿 → 逼你动
##   bomber   投弹者    —— 朝你"当前位置"砸延迟 AoE → 逼你离开那块地
##   shield   持盾兵    —— 正面免疫! 需绕到背后或先定住 → 定位谜题
##   protector守护者    —— 不攻击, 给周围怪挂无敌光环(脆) → 逼你先拆它
##   shooter  悬铳      —— 瞄准直射(原)
##   healer   缚生      —— 奶同伴(原)
## 修饰层: elite(精英:更肉/更狠/抗控) · explode(亡爆:死亡播撒延迟炸弹)
## 标准 FSM: patrol → alert → chase → windup(预警, 头顶 !) → 攻击 → recover(破绽)
## 被打 → stagger(击退 + 取消当前动作, hitstun)。移动统一 sdt=delta*scale_for 受时停控制。

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
# 修饰层
var elite := false
var explode := false       # 亡爆:死亡时播撒延迟炸弹
var dmg_mult := 1.0        # 接触伤害倍率(精英更狠)
var cc_mult := 1.0         # 控制时长倍率(精英抗控, <1)
# 持盾兵朝向(换边有延迟 → 绕背可破)
var shield_face := 1.0
var _face_t := 0.0
# 飞行怪(bat)悬停/俯冲
var _bob := 0.0
var _home_y := 0.0
var _dive := Vector2.ZERO
# 行为状态机
var state := "patrol"
var state_t := 0.0
var patrol_dir := 1.0      # 巡逻方向(撞墙/崖边/到边界翻转)
var home_x := 0.0          # 出生点 x(巡逻以它为中心来回)
var _home_set := false
var lost_t := 0.0          # 脱离视野计时(超时回巡逻)
var _lunge_dir := 1.0
var attacking := false     # 命中窗口为 true → 只有这下碰到才伤人(近战类)

const PATROL_SPD := 64.0
const CHASE_SPD := 150.0
const AGGRO_X := 360.0      # 横向察觉范围
const AGGRO_Y := 130.0      # 纵向察觉范围(差不多同层才追)
const DEAGGRO := 1.6        # 脱离视野多久回巡逻
const ATK_RANGE := 72.0
const PATROL_RANGE := 220.0 # 巡逻以出生点为中心来回的半幅(固定短线路)

func setup() -> void:
	match type:
		"charger":
			hp = 30.0; maxhp = 30.0; w = 34.0; h = 38.0; color = Color(0.88, 0.39, 0.25)
		"leaper":
			hp = 26.0; maxhp = 26.0; w = 32.0; h = 36.0; color = Color(0.92, 0.52, 0.22)
		"archer":
			hp = 18.0; maxhp = 18.0; w = 28.0; h = 40.0; color = Color(0.82, 0.72, 0.45)
		"bomber":
			hp = 24.0; maxhp = 24.0; w = 32.0; h = 34.0; color = Color(0.52, 0.72, 0.38)
		"shield":
			hp = 46.0; maxhp = 46.0; w = 36.0; h = 44.0; color = Color(0.55, 0.62, 0.72)
		"protector":
			hp = 16.0; maxhp = 16.0; w = 28.0; h = 46.0; color = Color(0.64, 0.42, 0.80)
		"bat":
			hp = 14.0; maxhp = 14.0; w = 30.0; h = 22.0; color = Color(0.66, 0.46, 0.82)
		"shooter":
			hp = 22.0; maxhp = 22.0; w = 30.0; h = 40.0; color = Color(0.79, 0.64, 0.25)
		"healer":
			hp = 20.0; maxhp = 20.0; w = 28.0; h = 44.0; color = Color(0.48, 0.76, 0.54)
		_:
			hp = 30.0; maxhp = 30.0; w = 34.0; h = 38.0; color = Color(0.88, 0.39, 0.25)
	fire_t = randf_range(1.8, 3.4)
	patrol_dir = 1.0 if randf() < 0.5 else -1.0
	state = "patrol"
	if elite:
		make_elite()

## 精英修饰:更肉/更狠/抗控 + 体型略大(一只基础怪 → 多种遭遇)
func make_elite() -> void:
	elite = true
	hp *= 2.4; maxhp = hp
	w *= 1.18; h *= 1.18
	dmg_mult = 1.5
	cc_mult = 0.8

## 被玩家命中:击退(按力度) + 取消当前动作/攻击 + 短硬直(hitstun)。
func stagger(from_dir: float, power := 320.0) -> void:
	flash_t = 0.10
	stun_t = 0.26 * cc_mult
	vx = from_dir * power
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
	# 物理: 重力 + 击退惯性, 对房间地形做碰撞(飞行怪自主控 vy, 不受重力)
	if type != "bat":
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

## 脚下是否着地
func _on_ground() -> bool:
	return _solid_at(position.x, position.y + h * 0.5 + 6.0)

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
	match type:
		"charger":
			_charger(sdt, pdir, adist, sees)
		"leaper":
			_leaper(sdt, pdir, adist, sees)
		"archer":
			_archer(sdt, p, pdir, adist, sees)
		"bomber":
			_bomber(sdt, p, pdir, adist, sees)
		"shield":
			_shield(sdt, pdir, adist, sees)
		"shooter":
			_shooter(sdt, p, pdir, adist, sees)
		"healer":
			_healer(sdt, pdir, sees)
		"protector":
			_protector(sdt, pdir, sees)
		"bat":
			_bat(sdt, p, pdir, adist, sees)

## 飞行怪:空中悬停划弧(可被冻成踏脚石!) → 预警 → 俯冲 → 飞回。无重力。
func _bat(sdt: float, p, pdir: float, adist: float, sees: bool) -> void:
	state_t -= sdt
	attacking = false
	if not _home_set:
		home_x = position.x; _home_y = position.y; _home_set = true
	_bob += sdt
	match state:
		"patrol":
			vx = patrol_dir * 72.0
			if absf(position.x - home_x) > 190.0 or _wall_ahead(patrol_dir):
				patrol_dir = -patrol_dir
			vy = (_home_y - position.y) * 1.5 + sin(_bob * 3.2) * 36.0
			if sees and adist < 300.0 and state_t <= 0.0:
				state = "windup"; state_t = 0.40
		"windup":
			vx = 0.0; vy = sin(_bob * 9.0) * 22.0   # 抖动预警(头顶 !)
			if state_t <= 0.0:
				_dive = (p.position - position).normalized()
				state = "dive"; state_t = 0.5
		"dive":
			vx = _dive.x * 380.0; vy = _dive.y * 380.0; attacking = true
			if state_t <= 0.0:
				state = "recover"; state_t = 0.45
		"recover":
			vx = lerpf(vx, 0.0, minf(1.0, sdt * 6.0))
			vy = clampf((_home_y - position.y) * 2.0, -220.0, 220.0)
			if state_t <= 0.0:
				state = "patrol"

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

## 跳扑者:蓄力 → 弧线起跳砸向你(锁定起跳方向, 可躲), 落地长破绽
func _leaper(sdt: float, pdir: float, adist: float, sees: bool) -> void:
	state_t -= sdt
	attacking = false
	match state:
		"patrol":
			_patrol_move()
			if sees:
				state = "alert"; state_t = 0.24
		"alert":
			vx = 0.0; patrol_dir = pdir
			if state_t <= 0.0:
				state = "chase"; lost_t = 0.0
		"chase":
			if sees:
				lost_t = 0.0
			else:
				lost_t += sdt
				if lost_t > DEAGGRO:
					state = "patrol"; return
			patrol_dir = pdir
			if adist <= 170.0 and _on_ground():
				vx = 0.0; state = "windup"; state_t = 0.40
			elif _floor_ahead(pdir):
				vx = pdir * CHASE_SPD * 0.8
			else:
				vx = 0.0
		"windup":
			vx = -pdir * 16.0                 # 下蹲蓄力
			if state_t <= 0.0:
				_lunge_dir = pdir
				vy = -560.0                    # 起跳(物理接管弧线)
				state = "lunge"; state_t = 0.7
		"lunge":
			vx = _lunge_dir * 360.0           # 空中保持横速
			attacking = true
			if _on_ground() and state_t < 0.55:   # 落地 → 破绽
				vx = 0.0; state = "recover"; state_t = 0.5
			elif state_t <= 0.0:
				state = "recover"; state_t = 0.5
		"recover":
			vx = 0.0
			if state_t <= 0.0:
				state = "chase" if sees else "patrol"

## 弓手(可躲):保持中距, 太近后撤; 拉弓预警(头顶 !)后水平直射 → 可跳过/下穿
func _archer(sdt: float, p, pdir: float, adist: float, sees: bool) -> void:
	if state == "windup":
		state_t -= sdt; vx = 0.0
		if state_t <= 0.0:
			game.spawn_arrow(position + Vector2(pdir * 16.0, -4.0), pdir)
			state = "combat"
		return
	if not sees and adist > AGGRO_X * 1.2:
		state = "patrol"; _patrol_move(); return
	state = "combat"; patrol_dir = pdir
	if adist < 220.0:
		vx = (-pdir * 120.0) if _floor_ahead(-pdir) else 0.0
	elif adist > 430.0:
		vx = (pdir * 90.0) if _floor_ahead(pdir) else 0.0
	else:
		vx = 0.0
	fire_t -= sdt
	if fire_t <= 0.0 and adist < 560.0 and absf(p.position.y - position.y) < 80.0:
		fire_t = randf_range(1.5, 2.3)
		state = "windup"; state_t = 0.35

## 投弹者:朝你"当前位置"砸延迟 AoE → 逼你离开那块地(区域封锁)
func _bomber(sdt: float, p, pdir: float, adist: float, sees: bool) -> void:
	if state == "windup":
		state_t -= sdt; vx = 0.0
		if state_t <= 0.0:
			game.spawn_boom(Vector2(p.position.x, p.position.y + p.h * 0.4), 0.85, 66.0, 14.0)
			state = "combat"; fire_t = randf_range(2.2, 3.0)
		return
	if not sees and adist > AGGRO_X * 1.2:
		state = "patrol"; _patrol_move(); return
	state = "combat"; patrol_dir = pdir
	if adist < 200.0:
		vx = (-pdir * 110.0) if _floor_ahead(-pdir) else 0.0
	elif adist > 460.0:
		vx = (pdir * 80.0) if _floor_ahead(pdir) else 0.0
	else:
		vx = 0.0
	fire_t -= sdt
	if fire_t <= 0.0 and adist < 600.0:
		state = "windup"; state_t = 0.5

## 持盾兵:正面免疫(game 判定), 慢推进 → 盾冲。盾朝向换边有 0.4s 延迟 → 绕背可破。
func _shield(sdt: float, pdir: float, adist: float, sees: bool) -> void:
	state_t -= sdt
	attacking = false
	_face_t = maxf(0.0, _face_t - sdt)
	if pdir != shield_face and _face_t <= 0.0:
		_face_t = 0.40                        # 玩家换边 → 盾要 0.4s 才转过来(此间背后可破)
	if _face_t <= 0.0:
		shield_face = pdir
	match state:
		"patrol":
			_patrol_move()
			if sees:
				state = "alert"; state_t = 0.3
		"alert":
			vx = 0.0
			if state_t <= 0.0:
				state = "chase"; lost_t = 0.0
		"chase":
			if sees:
				lost_t = 0.0
			else:
				lost_t += sdt
				if lost_t > DEAGGRO:
					state = "patrol"; return
			if adist <= ATK_RANGE + 24.0:
				vx = 0.0; state = "windup"; state_t = 0.45
			elif _floor_ahead(pdir):
				vx = pdir * CHASE_SPD * 0.55  # 持盾推进慢
			else:
				vx = 0.0
		"windup":
			vx = 0.0
			if state_t <= 0.0:
				_lunge_dir = pdir; state = "bash"; state_t = 0.28
		"bash":
			vx = _lunge_dir * 380.0; attacking = true
			if state_t <= 0.0:
				attacking = false; state = "recover"; state_t = 0.55
		"recover":
			vx = 0.0
			if state_t <= 0.0:
				state = "chase" if sees else "patrol"

## 守护者:不攻击, 给周围怪挂无敌光环(game 判定)。脆 → 见你就躲, 逼你先拆它。
func _protector(sdt: float, pdir: float, sees: bool) -> void:
	if sees:
		vx = (-pdir * 100.0) if _floor_ahead(-pdir) else 0.0
	else:
		_patrol_move()

## 悬铳:不在战斗范围就巡逻;进范围保持中距、不贴脸、瞄准开火
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
	# 守护者无敌光环(脆, 罩住周围怪)
	if type == "protector" and not frozen:
		draw_arc(Vector2.ZERO, game.PROTECT_R, 0.0, TAU, 40, Color(0.66, 0.46, 0.86, 0.22), 2.0)
	# 残响错位残影:活动时拖一层低透明偏移残像;冻住/受击时不画
	if not frozen and flash_t <= 0.0:
		var g := Color(color.r, color.g, color.b, 0.22)
		draw_rect(Rect2(-w * 0.5 - _jit.x * 1.7, -h * 0.5 - _jit.y * 1.7, w, h), g)
	draw_set_transform(_jit, tilt, Vector2.ONE)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), col)
	if frozen:
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.82, 0.94, 1.0), false, 2.0)
	# 持盾兵:盾面(指示当前免疫方向 → 提示绕背)
	if type == "shield" and not frozen:
		var sxp := shield_face * (w * 0.5 + 3.0)
		draw_rect(Rect2(sxp - 2.0, -h * 0.5, 4.0, h), Color(0.80, 0.88, 0.98))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 精英:金边
	if elite and not frozen:
		draw_rect(Rect2(-w * 0.5 - 4.0, -h * 0.5 - 4.0, w + 8.0, h + 8.0), Color(1.0, 0.82, 0.32, 0.7), false, 2.0)
	# 扑影/盾冲蓄力的拖影预警(原 charger 红框)
	if not frozen:
		if type == "charger" and state == "windup":
			var pulse := 0.4 + 0.6 * absf(sin(state_t * 26.0))
			draw_rect(Rect2(-w * 0.5 - 3.0, -h * 0.5 - 3.0, w + 6.0, h + 6.0), Color(1.0, 0.40, 0.34, pulse), false, 2.5)
		elif type == "charger" and state == "lunge":
			for k in 3:
				var a := 0.28 * (1.0 - float(k) / 3.0)
				draw_rect(Rect2(-w * 0.5 - _lunge_dir * float(k + 1) * 12.0, -h * 0.5, w, h), Color(1.0, 0.6, 0.42, a))
		# 任意攻击预警:头顶感叹号 tell(死亡细胞式, 读得到就躲得开)
		if state == "windup":
			_draw_bang()
	# 血条
	draw_rect(Rect2(-16, -h * 0.5 - 9, 32, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-16, -h * 0.5 - 9, 32.0 * clampf(hp / maxhp, 0.0, 1.0), 4), Color(0.88, 0.42, 0.42))
	if type == "healer":
		draw_rect(Rect2(-1.5, -7, 3, 14), Color(0.7, 1.0, 0.8))
		draw_rect(Rect2(-7, -1.5, 14, 3), Color(0.7, 1.0, 0.8))

## 攻击预警感叹号(头顶, 黄亮)
func _draw_bang() -> void:
	var y := -h * 0.5 - 28.0
	var c := Color(1.0, 0.86, 0.2)
	draw_rect(Rect2(-2.5, y, 5.0, 13.0), c)
	draw_rect(Rect2(-2.5, y + 16.0, 5.0, 5.0), c)
