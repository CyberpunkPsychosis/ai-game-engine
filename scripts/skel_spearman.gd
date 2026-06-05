extends Enemy
class_name SkelSpearman
## 长矛骷髅（新机制 · 弹反拼刀进阶）：
##  · 出矛前有「预警」读招点（黄闪）。
##  · 单刺：可弹反；打完有「停顿」(惩罚窗口)。弹反成功 → 怪硬直，且激怒。
##  · 激怒后下一次变「连续三刺」：想全躲只能闪避；格挡只挡当下那一刺，后面照刺；
##    手稳可连按三次全挡。三刺有霸体——被弹不硬直、不涨架势。放完同样进「停顿」。

const A := "res://art/spearman/"

# 状态机
const ST_IDLE := 0      # 站位
const ST_TELE := 1      # 出矛预警(读招点)
const ST_THRUST := 2    # 刺击中 / 等动画收尾(连段在此推进)
const ST_PAUSE := 3     # 收招停顿 = 惩罚窗口

const STRIKE := 96.0    # 进入此距离才出手
const KEEP := 54.0      # 近于此 → 后撤拉开(怕贴身)
const TELE_T := 0.5     # 单刺预警时长
const TELE_COMBO_T := 0.55  # 三连预警时长
const PAUSE_T := 1.2    # 收招停顿(给你打的窗口)
const GAP_T := 0.16     # 三连里两刺之间的间隔

# 一记突刺(细长框，可弹)
const THRUST := {
	"anim": "attack", "reach": 66.0, "size": Vector2(92, 24), "from": 2, "to": 3,
	"dmg": 11.0, "posture": 16.0,
}

var _st := ST_IDLE
var _tele_t := 0.0
var _pause_t := 0.0
var _gap_t := 0.0
var _pending := 0          # 当前这次出手还剩几刺(单刺=1，三连=3)
var _in_combo := false     # 正在三连(霸体：弹反不打断/不涨架势)
var _enrage := false       # 弹反过单刺 → 下次出三连

func _setup() -> void:
	team = 1
	max_hp = 70.0
	posture_max = 95.0
	body_size = Vector2(22, 58)
	speed = 80.0
	aggro_range = 460.0
	engage_range = 84.0
	if sprite:
		sprite.offset = Vector2(0, -62)
		sprite.sprite_frames = SpriteSheet.build_from_strips({
			"idle":    {"tex": load(A + "idle.png"),    "fps": 8.0,  "loop": true},
			"walk":    {"tex": load(A + "walk.png"),    "fps": 9.0,  "loop": true},
			"run":     {"tex": load(A + "run.png"),     "fps": 11.0, "loop": true},
			"attack":  {"tex": load(A + "attack1.png"), "fps": 11.0, "loop": false},
			"hurt":    {"tex": load(A + "hurt.png"),    "fps": 10.0, "loop": false},
			"death":   {"tex": load(A + "dead.png"),    "fps": 10.0, "loop": false},
		}, CELL)
	add_to_group("enemy")

func _gather_intent(delta: float) -> void:
	if _base_speed < 0.0:
		_base_speed = speed
	_cd = maxf(_cd - delta, 0.0)
	_tele_t = maxf(_tele_t - delta, 0.0)
	_pause_t = maxf(_pause_t - delta, 0.0)
	_gap_t = maxf(_gap_t - delta, 0.0)

	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var dx := pl.global_position.x - global_position.x
	var dist := absf(dx)

	if attacking:
		return                       # 出矛中：锁住，等动画收尾
	facing = 1 if dx >= 0.0 else -1
	move_dir = 0.0

	match _st:
		ST_IDLE:
			if dist > STRIKE:
				move_dir = signf(dx)         # 太远 → 逼近
			elif dist < KEEP:
				move_dir = -signf(dx)        # 太近 → 后撤(怕贴身)
			elif _cd <= 0.0 and _slot_free():
				_begin_windup()
		ST_TELE:
			if _tele_t <= 0.0:
				_fire_thrust()
				_st = ST_THRUST
		ST_THRUST:
			# 走到这=上一刺动画已收尾
			if _pending > 0:
				if _gap_t <= 0.0:
					_fire_thrust()           # 连段：补下一刺
			else:
				_in_combo = false
				_st = ST_PAUSE
				_pause_t = PAUSE_T
		ST_PAUSE:
			# 站定挨打的惩罚窗口
			if _pause_t <= 0.0:
				_st = ST_IDLE
				_cd = 0.3

func _begin_windup() -> void:
	_st = ST_TELE
	if _enrage:
		_enrage = false
		_pending = 3
		_in_combo = true
		_tele_t = TELE_COMBO_T
		if sprite:
			FX.flash(sprite, TELE_COMBO_T, Color(1.0, 0.55, 0.2))  # 橙=三连预警
	else:
		_pending = 1
		_in_combo = false
		_tele_t = TELE_T
		if sprite:
			FX.flash(sprite, TELE_T, Color(1.0, 0.95, 0.5))        # 黄=单刺预警

func _fire_thrust() -> void:
	start_attack(THRUST)
	_pending -= 1
	_gap_t = GAP_T

## 被弹反：单刺 → 硬直+激怒(下次三连)；三连 → 霸体，不硬直、不被打断
func flinch(push_dir: float) -> void:
	if _in_combo:
		return
	super.flinch(push_dir)
	_enrage = true
	_pending = 0
	_st = ST_IDLE

## 三连霸体期间：弹反/格挡不给它涨架势(=不会破防硬直)
func _add_posture(amount: float) -> void:
	if _in_combo and amount > 0.0:
		return
	super._add_posture(amount)
