extends Enemy
class_name SkelSpearman
## 长矛骷髅（弹反拼刀进阶）：
##  · 出矛前有「预警」(持矛后拉+染色)。单刺可弹反，打完有「停顿」(惩罚窗口)。
##  · 弹反单刺成功 → 怪硬直且激怒 → 下一次「连续三刺」(霸体：弹不打断/不破防；
##    想全躲只能闪避，或连按三次弹)。三刺放完同样进停顿。
## 所有手感数值是 var（可被调参工具实时拖动）。

const A := "res://art/spearman/"

# 状态机
const ST_IDLE := 0
const ST_TELE := 1
const ST_THRUST := 2
const ST_PAUSE := 3

# ── 可调参数(调参工具拖动) ──
var strike_range := 58.0    # 只在矛够得到的距离才出手
var keep_range := 36.0      # 近于此 → 后撤(怕贴身)
var thrust_reach := 35.0    # 矛判定框前伸(矛尖≈52)
var thrust_width := 50.0    # 矛判定框长度
var tele_dur := 0.8         # 单刺预警时长
var tele_combo_dur := 0.62  # 三连预警时长
var pause_dur := 1.2        # 收招停顿(惩罚窗口)
var gap_dur := 0.16         # 三连里两刺间隔

var _st := ST_IDLE
var _tele_t := 0.0
var _pause_t := 0.0
var _gap_t := 0.0
var _pending := 0
var _in_combo := false
var _enrage := false

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
			"attack":  {"tex": load(A + "attack1.png"), "fps": 10.0, "loop": false},
			"hurt":    {"tex": load(A + "hurt.png"),    "fps": 10.0, "loop": false},
			"death":   {"tex": load(A + "dead.png"),    "fps": 10.0, "loop": false},
		}, CELL)
	add_to_group("enemy")

# 调参工具读这个：每项 = 一个可拖动的属性
func tunables() -> Array:
	return [
		{"name": "strike_range",  "label": "出手距离",   "min": 30.0, "max": 140.0, "step": 1.0},
		{"name": "keep_range",    "label": "保持距离",   "min": 0.0,  "max": 80.0,  "step": 1.0},
		{"name": "thrust_reach",  "label": "矛框前伸",   "min": 10.0, "max": 90.0,  "step": 1.0},
		{"name": "thrust_width",  "label": "矛框长度",   "min": 20.0, "max": 120.0, "step": 1.0},
		{"name": "tele_dur",      "label": "单刺预警s",  "min": 0.2,  "max": 1.5,   "step": 0.02},
		{"name": "tele_combo_dur","label": "三连预警s",  "min": 0.2,  "max": 1.5,   "step": 0.02},
		{"name": "pause_dur",     "label": "收招停顿s",  "min": 0.3,  "max": 2.5,   "step": 0.05},
		{"name": "gap_dur",       "label": "三连间隔s",  "min": 0.05, "max": 0.5,   "step": 0.01},
	]

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
		return
	facing = 1 if dx >= 0.0 else -1
	move_dir = 0.0

	match _st:
		ST_IDLE:
			if dist > strike_range:
				move_dir = signf(dx)
			elif dist < keep_range:
				move_dir = -signf(dx)
			elif _cd <= 0.0 and _slot_free():
				_begin_windup()
		ST_TELE:
			if _tele_t <= 0.0:
				if sprite:
					sprite.modulate = Color.WHITE
				_fire_thrust()
				_st = ST_THRUST
		ST_THRUST:
			if _pending > 0:
				if _gap_t <= 0.0:
					_fire_thrust()
			else:
				_in_combo = false
				_st = ST_PAUSE
				_pause_t = pause_dur
		ST_PAUSE:
			if _pause_t <= 0.0:
				_st = ST_IDLE
				_cd = 0.3

func _begin_windup() -> void:
	_st = ST_TELE
	if _enrage:
		_enrage = false
		_pending = 3
		_in_combo = true
		_tele_t = tele_combo_dur
		if sprite:
			sprite.modulate = Color(1.0, 0.5, 0.2)
	else:
		_pending = 1
		_in_combo = false
		_tele_t = tele_dur
		if sprite:
			sprite.modulate = Color(1.0, 0.85, 0.35)

func _update_anim() -> void:
	if _st == ST_TELE and sprite and sprite.sprite_frames:
		if sprite.animation != "attack":
			sprite.play("attack")
		sprite.pause()
		sprite.frame = 0
		return
	super._update_anim()

func _fire_thrust() -> void:
	start_attack({
		"anim": "attack", "reach": thrust_reach, "size": Vector2(thrust_width, 22),
		"from": 2, "to": 3, "dmg": 11.0, "posture": 16.0,
	})
	_pending -= 1
	_gap_t = gap_dur

func flinch(push_dir: float) -> void:
	if _in_combo:
		return
	super.flinch(push_dir)
	if sprite:
		sprite.modulate = Color.WHITE
	_enrage = true
	_pending = 0
	_st = ST_IDLE

func _add_posture(amount: float) -> void:
	if _in_combo and amount > 0.0:
		return
	super._add_posture(amount)

# 调参可视化：画出手/保持距离线 + 矛判定框预览
func _draw() -> void:
	super._draw()
	if not _dbg:
		return
	var c_strike := Color(1.0, 0.8, 0.2, 0.55)
	var c_keep := Color(0.4, 0.7, 1.0, 0.5)
	for s in [1.0, -1.0]:
		draw_line(Vector2(strike_range * s, 4), Vector2(strike_range * s, -80), c_strike, 1.5)
		draw_line(Vector2(keep_range * s, 4), Vector2(keep_range * s, -66), c_keep, 1.5)
	var cx := float(facing) * thrust_reach
	var cy := -body_size.y * 0.5
	draw_rect(Rect2(cx - thrust_width * 0.5, cy - 11, thrust_width, 22), Color(1.0, 0.3, 0.3, 0.22))
