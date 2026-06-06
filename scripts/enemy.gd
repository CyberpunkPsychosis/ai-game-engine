extends Actor2D
class_name Enemy
## 敌人基类：多招组合 + 走位 + 攻击 slot（同时只 1 个敌人出手）。
## 子类在 _setup() 里设：精灵表(SpriteFrames) + moves[] + 数值 + sprite.offset。
##
## 每招 move 是一个字典：
##   anim     动画名
##   reach    攻击框前伸（武器越长越大：剑44 / 矛64 …）
##   size     攻击框尺寸 Vector2（矛=细长，剑=方）
##   from,to  命中帧区间（动画第几帧开判定）
##   dmg,posture  伤害 / 架势伤害
##   perilous 是否红光「危」(不可弹，要闪/跳)
##   recover  这招后的冷却(秒)
##   weight   被随机选中的权重
##   range    这招能打到的最大距离（AI 选招用）
##   backoff  打完后撤的概率(0~1)

const CELL := Vector2i(128, 128)
const MAX_ATTACKERS := 1

@export var aggro_range := 400.0
@export var engage_range := 60.0     # 进入此距离才考虑出手
@export var keep_distance := 0.0     # >0：尽量保持的距离（长矛/远程）

@export var feint_chance := 0.25     # 出手前"蓄势假动作"的概率

var moves: Array = []
var _cd := 0.6
var _backoff_t := 0.0
var _retreat_t := 0.0   # 被弹反后后撤
var _charging := false  # 后撤完冲回来
var _feint_t := 0.0
var _just_feinted := false
var _base_speed := -1.0

# 通用可调项（调参工具用）。子类可重写/追加。
func tunables() -> Array:
	return [
		{"name": "engage_range",  "label": "出手距离", "min": 20.0,  "max": 160.0, "step": 1.0},
		{"name": "keep_distance", "label": "保持距离", "min": 0.0,   "max": 120.0, "step": 1.0},
		{"name": "speed",         "label": "移动速度", "min": 30.0,  "max": 260.0, "step": 5.0},
		{"name": "feint_chance",  "label": "假动作率", "min": 0.0,   "max": 1.0,   "step": 0.05},
		{"name": "aggro_range",   "label": "索敌距离", "min": 150.0, "max": 700.0, "step": 10.0},
		{"name": "parry_flinch",  "label": "被弹硬直s","min": 0.2,   "max": 1.5,   "step": 0.05},
	]

func _gather_intent(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	if _base_speed < 0.0:
		_base_speed = speed
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var dx := pl.global_position.x - global_position.x
	var dist := absf(dx)
	if attacking:
		return                       # 出招中锁定朝向（修打拳方向反复横跳）
	facing = 1 if dx >= 0.0 else -1
	speed = _base_speed

	# 被弹反后：快速后撤拉开 → 再冲回来打
	if _retreat_t > 0.0:
		_retreat_t -= delta
		speed = _base_speed * 2.4    # 急退
		move_dir = -signf(dx)
		if _retreat_t <= 0.0:
			_charging = true
			_cd = 0.0
		return
	if _charging:
		speed = _base_speed * 1.9    # 冲回来
		if dist > engage_range:
			move_dir = signf(dx)
		else:
			_charging = false
			speed = _base_speed
			if _slot_free():
				_do_attack(dist)
		return
	# 蓄势假动作：站定一下再出手
	if _feint_t > 0.0:
		_feint_t -= delta
		return

	# 保持距离：太近就后撤（长矛/远程怕贴身）
	if keep_distance > 0.0 and dist < keep_distance - 10.0:
		move_dir = -signf(dx)
		return
	# 打完拉开节奏
	if _backoff_t > 0.0:
		_backoff_t -= delta
		move_dir = -signf(dx) * 0.85
		return
	if dist > aggro_range:
		return
	if dist > engage_range:
		move_dir = signf(dx)        # 接近
		return
	# 出手距离内：冷却好 + slot 空 → 假动作 or 出招
	if _cd <= 0.0 and _slot_free():
		if not _just_feinted and randf() < feint_chance:
			_feint_t = 0.28
			_just_feinted = true
			return
		_just_feinted = false
		_do_attack(dist)

func flinch(push_dir: float) -> void:
	super.flinch(push_dir)
	_retreat_t = 0.55         # 被弹反 → 急退一段再冲回来
	_charging = false
	_feint_t = 0.0
	_just_feinted = false

func _slot_free() -> bool:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e is Actor2D and (e as Actor2D).attacking:
			n += 1
	return n < MAX_ATTACKERS

func _do_attack(dist: float) -> void:
	if moves.is_empty():
		return
	# 选能打到的招（按权重随机）
	var pool: Array = []
	for m in moves:
		if dist <= float(m.get("range", engage_range)) + 8.0:
			pool.append(m)
	if pool.is_empty():
		pool = moves
	var total := 0.0
	for m in pool:
		total += float(m.get("weight", 1.0))
	var r := randf() * total
	var chosen: Dictionary = pool[0]
	for m in pool:
		r -= float(m.get("weight", 1.0))
		if r <= 0.0:
			chosen = m
			break
	if bool(chosen.get("perilous", false)) and sprite:
		FX.flash(sprite, 0.5, Color(1.0, 0.25, 0.2))   # 红光预警(危攻击)
	start_attack(chosen)
	_cd = float(chosen.get("recover", 1.0))
	if randf() < float(chosen.get("backoff", 0.3)):
		_backoff_t = 0.35
