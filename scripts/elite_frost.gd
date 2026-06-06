extends Enemy
class_name EliteFrost
## 精英·冰霜守卫：很灵活，面对玩家就冲过来打一拳。
##  · 弹反/格挡好了它那一拳 → 它向后逃跑 + 生气(身上泛冷光)。
##  · 生气后冲回来，飞快连出 6 拳。
##  · 连段中被弹反 → 大硬直(处决窗)并消气。素材默认朝左。数值是 var(可调)。

const SHEET := preload("res://art/frost/frost_guardian.png")
const FCELL := Vector2i(192, 128)

const ST_IDLE := 0
const ST_ATTACK := 1
const ST_PAUSE := 2

# ── 可调参数 ──
var strike_range := 100.0    # 跑到这么近才出拳(调参定)
var punch_reach := 52.0      # 拳判定前伸
var punch_width := 80.0      # 拳判定长度
var pause_dur := 1.0         # 打完歇(灵活，歇得短)
var combo_gap := 0.05        # 连拳之间的间隔(很快)
var combo_hits := 6          # 生气连几拳

var _st := ST_IDLE
var _pause_t := 0.0
var _gap_t := 0.0
var _pending := 0
var _angry := false
var _combo := false
var _combo_pending := false
var _hopping := false
var _want_hop := false

func _setup() -> void:
	team = 1
	max_hp = 150.0
	posture_max = 110.0
	parry_deaths = 5            # 弹反五次就死
	body_size = Vector2(44, 72)
	speed = 175.0               # 灵活快冲
	aggro_range = 620.0
	engage_range = 70.0
	# 被弹后向后大跳
	jump_velocity = -430.0
	gravity_up = 1300.0
	gravity_down = 1800.0
	anim_jump = "walk"
	anim_fall = "walk"
	sprite_faces_left = true
	if sprite:
		sprite.sprite_frames = SpriteSheet.build(SHEET, FCELL, {
			"idle":   [0, 6,  7.0,  true],
			"walk":   [1, 10, 12.0, true],
			"attack": [2, 14, 10.0, false],
			"hurt":   [3, 7,  12.0, false],
			"death":  [4, 16, 11.0, false],
		})
	anim_run = "walk"
	add_to_group("enemy")

func tunables() -> Array:
	return [
		{"name": "strike_range", "label": "出手距离",  "min": 30.0, "max": 160.0, "step": 1.0},
		{"name": "speed",        "label": "移动速度",  "min": 60.0, "max": 300.0, "step": 5.0},
		{"name": "punch_reach",  "label": "拳框前伸",  "min": 20.0, "max": 120.0, "step": 1.0},
		{"name": "punch_width",  "label": "拳框宽",    "min": 30.0, "max": 160.0, "step": 1.0},
		{"name": "pause_dur",    "label": "打后歇s",   "min": 0.3,  "max": 2.5,   "step": 0.05},
		{"name": "combo_gap",    "label": "连拳间隔s", "min": 0.02, "max": 0.4,   "step": 0.01},
		{"name": "parry_flinch", "label": "被弹硬直s", "min": 0.1,  "max": 1.5,   "step": 0.05},
	]

func _gather_intent(delta: float) -> void:
	if _base_speed < 0.0:
		_base_speed = speed
	_cd = maxf(_cd - delta, 0.0)
	_pause_t = maxf(_pause_t - delta, 0.0)
	_gap_t = maxf(_gap_t - delta, 0.0)

	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var dx := pl.global_position.x - global_position.x
	var dist := absf(dx)

	# 生气：身上泛冷光脉动
	if sprite:
		if _angry:
			var p := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.025)
			sprite.modulate = Color(0.7, 1.1, 1.6).lerp(Color(1.2, 1.7, 2.2), p)
		elif sprite.modulate != Color.WHITE and _flinch_t <= 0.0 and not guard_broken:
			sprite.modulate = Color.WHITE

	# 被弹 → 向后大跳脱离；腾空中持续，头一直盯着玩家
	if _want_hop and is_on_floor() and not attacking:
		_want_hop = false
		_begin_hop(dx)
		return                       # 起跳帧先返回，下一帧才走腾空(否则当帧还在地面会被当成已落地)
	if _hopping:
		facing = 1 if dx >= 0.0 else -1
		lock_facing = true
		move_dir = -signf(dx)
		speed = _base_speed * 2.0    # 跳的横向距离≈原来后跑那段
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
			if dist > strike_range:
				move_dir = signf(dx)
				if _angry:
					speed = _base_speed * 1.35    # 生气冲回来更快
			elif _cd <= 0.0 and _slot_free():
				_begin_attack_seq()
		ST_ATTACK:
			if _pending > 0:
				if _gap_t <= 0.0:
					_fire_punch()
			else:
				if _combo:
					_calm()
				if sprite:
					sprite.speed_scale = 1.0
				_st = ST_PAUSE
				_pause_t = pause_dur
		ST_PAUSE:
			if _pause_t <= 0.0:
				_st = ST_IDLE
				_cd = 0.15

func _begin_attack_seq() -> void:
	_st = ST_ATTACK
	if _angry and _combo_pending:
		_pending = combo_hits          # 生气 → 连 6 拳
		_combo_pending = false
		_combo = true
	else:
		_pending = 1
		_combo = false
	_fire_punch()

func _fire_punch() -> void:
	if sprite:
		sprite.speed_scale = 2.6 if _combo else 1.0   # 连拳很快
	start_attack({
		"anim": "attack", "reach": punch_reach, "size": Vector2(punch_width, 70),
		"from": 6, "to": 8, "dmg": 12.0, "posture": 15.0,
	})
	_pending -= 1
	_gap_t = combo_gap

# 弹反/格挡好了：普通拳被弹 → 逃跑+生气；生气连段被弹 → 大硬直处决窗+消气
func flinch(push_dir: float) -> void:
	if _dead:
		return
	super.flinch(push_dir)
	if _angry and _combo:
		_flinch_t = parry_flinch * 1.5   # 连段被弹 → 大硬直处决窗
		_calm()
		_st = ST_IDLE
	else:
		_flinch_t = 0.0                  # 不站桩 → 马上向后大跳
		_angry = true
		_combo_pending = true
		_pending = 0
		_st = ST_IDLE
		_want_hop = true

func _begin_hop(dx: float) -> void:
	_hopping = true
	facing = 1 if dx >= 0.0 else -1
	lock_facing = true
	want_jump = true
	move_dir = -signf(dx)
	speed = _base_speed * 2.0

func _calm() -> void:
	_angry = false
	_combo = false
	_combo_pending = false
	_pending = 0
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.speed_scale = 1.0

func _draw() -> void:
	super._draw()
	if not _dbg:
		return
	draw_line(Vector2(strike_range, 4), Vector2(strike_range, -90), Color(0.5, 0.9, 1.0, 0.55), 1.5)
	draw_line(Vector2(-strike_range, 4), Vector2(-strike_range, -90), Color(0.5, 0.9, 1.0, 0.55), 1.5)
	var cx := float(facing) * punch_reach
	draw_rect(Rect2(cx - punch_width * 0.5, -body_size.y * 0.5 - 35, punch_width, 70), Color(0.4, 0.7, 1.0, 0.22))
