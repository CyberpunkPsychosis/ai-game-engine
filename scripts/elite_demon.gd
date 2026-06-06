extends Enemy
class_name EliteDemon
## 精英·恶魔史莱姆：血厚。平时一记大劈。
##  · 你老是闪避 / 一直跑远风筝它 → 它「生气」(全身红光一直闪)。
##  · 生气时：连劈三刀；靠近它有时会向后大跳脱离；砍完消气。
##  · 弹反/挡好了 → 它硬直；生气时被弹反 → 硬直更久(更好处决)且当场消气。
## 素材默认朝左。手感数值是 var(调参工具可拖)。

const SHEET := preload("res://art/boss/demon_slime.png")
const DCELL := Vector2i(288, 160)

const ST_IDLE := 0
const ST_ATTACK := 1
const ST_PAUSE := 2

# ── 可调参数 ──
var strike_range := 96.0     # 进入此距离才劈(爪尖≈120，框够到)
var keep_range := 0.0
var cleave_reach := 64.0     # 大劈判定前伸
var cleave_width := 112.0    # 大劈判定长度
var pause_dur := 1.6         # 砍完休息
var combo_gap := 0.12        # 连劈之间的间隔(连段要快)
var rage_per_dodge := 0.34   # 你每闪避一次涨的怒气
var rage_far_rate := 0.12    # 你跑远时每秒涨的怒气
var backjump_chance := 0.5   # 生气时靠近，向后大跳的概率

var _st := ST_IDLE
var _pause_t := 0.0
var _gap_t := 0.0
var _pending := 0
var _rage := 0.0
var _angry := false
var _combo := false          # 当前这串是不是"生气三连"
var _was_dodging := false
var _hop_cd := 0.0
var _hopping := false

func _setup() -> void:
	team = 1
	max_hp = 220.0               # 血厚很多
	posture_max = 140.0
	body_size = Vector2(50, 92)
	speed = 70.0
	aggro_range = 560.0
	engage_range = 96.0
	# 向后大跳手感
	jump_velocity = -420.0
	gravity_up = 1300.0
	gravity_down = 1800.0
	if sprite:
		sprite.sprite_frames = SpriteSheet.build(SHEET, DCELL, {
			"idle":   [0, 6,  7.0,  true],
			"walk":   [1, 12, 9.0,  true],
			"cleave": [2, 15, 11.0, false],
			"hurt":   [3, 5,  12.0, false],
			"death":  [4, 22, 12.0, false],
		})
	anim_run = "walk"
	anim_attack = "cleave"
	anim_jump = "walk"           # 没有跳跃帧，腾空借走路帧
	anim_fall = "walk"
	sprite_faces_left = true
	add_to_group("enemy")

func tunables() -> Array:
	return [
		{"name": "strike_range",    "label": "出手距离",   "min": 40.0, "max": 200.0, "step": 1.0},
		{"name": "speed",           "label": "移动速度",   "min": 30.0, "max": 200.0, "step": 5.0},
		{"name": "cleave_reach",    "label": "大劈框前伸", "min": 20.0, "max": 140.0, "step": 1.0},
		{"name": "cleave_width",    "label": "大劈框宽",   "min": 40.0, "max": 200.0, "step": 1.0},
		{"name": "pause_dur",       "label": "砍后休息s",  "min": 0.5,  "max": 3.0,   "step": 0.05},
		{"name": "combo_gap",       "label": "连劈间隔s",  "min": 0.1,  "max": 0.8,   "step": 0.02},
		{"name": "rage_per_dodge",  "label": "闪避涨怒",   "min": 0.1,  "max": 1.0,   "step": 0.02},
		{"name": "rage_far_rate",   "label": "跑远涨怒/s", "min": 0.0,  "max": 0.6,   "step": 0.02},
		{"name": "backjump_chance", "label": "大跳概率",   "min": 0.0,  "max": 1.0,   "step": 0.05},
		{"name": "parry_flinch",    "label": "被弹硬直s",  "min": 0.2,  "max": 1.5,   "step": 0.05},
	]

func _gather_intent(delta: float) -> void:
	if _base_speed < 0.0:
		_base_speed = speed
	_cd = maxf(_cd - delta, 0.0)
	_pause_t = maxf(_pause_t - delta, 0.0)
	_gap_t = maxf(_gap_t - delta, 0.0)
	_hop_cd = maxf(_hop_cd - delta, 0.0)

	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var dx := pl.global_position.x - global_position.x
	var dist := absf(dx)

	# ── 怒气：你老闪避 / 跑远风筝 → 涨怒 → 生气 ──
	if not _angry:
		var pd := false
		if pl is Actor2D:
			pd = (pl as Actor2D).dodging
		if pd and not _was_dodging and dist < aggro_range:
			_rage += rage_per_dodge          # 闪避一次涨一截
		if dist > engage_range * 2.2:
			_rage += rage_far_rate * delta   # 跑远了慢慢涨
		_was_dodging = pd
		if _rage >= 1.0:
			_angry = true
			_combo = true                    # 下一串=三连
			# 暴怒瞬间：震一下 + 身体爆亮(不闪屏幕，免得晃眼)
			Juice.shake(10.0)
			FX.flash(sprite, 0.2, Color(2.2, 1.5, 0.7))
	# 生气：怪物身上一直泛红光(不碰屏幕)
	if sprite:
		if _angry:
			var p := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.022)
			sprite.modulate = Color(1.5, 0.85, 0.4).lerp(Color(1.95, 1.3, 0.6), p)
		elif sprite.modulate != Color.WHITE and _flinch_t <= 0.0 and not guard_broken:
			sprite.modulate = Color.WHITE

	# 向后大跳脱离(腾空中持续，头一直盯着玩家)
	if _hopping:
		facing = 1 if dx >= 0.0 else -1
		lock_facing = true               # 后退也不翻面，始终朝玩家
		speed = _base_speed * 3.0
		move_dir = -signf(dx)
		if is_on_floor() and velocity.y >= 0.0:
			_hopping = false
			lock_facing = false
			speed = _base_speed
		return

	if attacking:
		return
	facing = 1 if dx >= 0.0 else -1
	move_dir = 0.0
	speed = _base_speed

	match _st:
		ST_IDLE:
			# 生气时靠近 → 有时向后大跳
			if _angry and dist < 130.0 and _hop_cd <= 0.0 and is_on_floor() and randf() < backjump_chance * delta * 8.0:
				_begin_hop(dx)
				return
			if dist > strike_range:
				move_dir = signf(dx)
			elif keep_range > 0.0 and dist < keep_range:
				move_dir = -signf(dx)
			elif _cd <= 0.0 and _slot_free():
				_begin_attack_seq()
		ST_ATTACK:
			if _pending > 0:
				if _gap_t <= 0.0:
					_fire_cleave()
			else:
				if _combo:                    # 三连放完 → 消气
					_angry = false
					_combo = false
					_rage = 0.0
				if sprite:
					sprite.speed_scale = 1.0
				_st = ST_PAUSE
				_pause_t = pause_dur
		ST_PAUSE:
			if _pause_t <= 0.0:
				_st = ST_IDLE
				_cd = 0.4

func _begin_attack_seq() -> void:
	_st = ST_ATTACK
	_pending = 3 if (_angry and _combo) else 1
	_fire_cleave()

func _fire_cleave() -> void:
	if sprite:
		sprite.speed_scale = 1.8 if _combo else 1.0   # 三连时劈得快
	start_attack({
		"anim": "cleave", "reach": cleave_reach, "size": Vector2(cleave_width, 84),
		"from": 9, "to": 11, "dmg": 16.0, "posture": 20.0,
	})
	_pending -= 1
	_gap_t = combo_gap

func _begin_hop(dx: float) -> void:
	_hopping = true
	_hop_cd = 1.4
	facing = 1 if dx >= 0.0 else -1
	lock_facing = true
	want_jump = true
	move_dir = -signf(dx)
	speed = _base_speed * 3.0

# 弹反/挡好 → 硬直；生气时被弹 → 硬直更久 + 当场消气
func flinch(push_dir: float) -> void:
	super.flinch(push_dir)
	_hopping = false
	lock_facing = false
	if _angry:
		_flinch_t = parry_flinch * 1.8   # 生气时被弹反 → 硬直更久(好处决)
	_calm()
	_st = ST_IDLE

func _calm() -> void:
	_angry = false
	_combo = false
	_rage = 0.0
	_pending = 0
	_hopping = false
	lock_facing = false
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.speed_scale = 1.0

# 调参可视化
func _draw() -> void:
	super._draw()
	if not _dbg:
		return
	for s in [1.0, -1.0]:
		draw_line(Vector2(strike_range * s, 4), Vector2(strike_range * s, -110), Color(1.0, 0.8, 0.2, 0.5), 1.5)
	var cx := float(facing) * cleave_reach
	draw_rect(Rect2(cx - cleave_width * 0.5, -body_size.y * 0.5 - 42, cleave_width, 84), Color(1.0, 0.3, 0.3, 0.2))
