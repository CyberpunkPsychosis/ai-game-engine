extends Enemy
class_name SkelWarrior
## 持剑骷髅（决斗怪）：移动快、压迫强。出招前预警 → 一记劈砍 → 砍完歇很久(惩罚窗口)。
## 关键：**弹反它的劈砍 = 当场处决**（一击致命也一击致死，逼你读招拼刀）。
## 旧的慢刀/重斩组合已弃用。手感数值是 var（调参工具可拖）。

const A := "res://art/skeleton/"

const ST_IDLE := 0
const ST_TELE := 1
const ST_ATTACK := 2
const ST_PAUSE := 3

# ── 可调参数 ──
var strike_range := 62.0    # 进入此距离才出手(剑尖≈56)
var keep_range := 0.0       # 0=从不后撤，一味压上
var slash_reach := 34.0     # 劈砍判定前伸
var slash_width := 50.0     # 劈砍判定长度
var tele_dur := 0.5         # 出招预警时长(举刀)
var pause_dur := 1.9        # 砍完休息(比矛骷髅久，给你反击)

var _st := ST_IDLE
var _tele_t := 0.0
var _pause_t := 0.0

func _setup() -> void:
	team = 1
	max_hp = 55.0
	posture_max = 80.0
	body_size = Vector2(24, 56)   # 受击框(身体近中心)
	hurt_dx = 2.0
	speed = 150.0                 # 快
	aggro_range = 460.0
	engage_range = 62.0
	if sprite:
		sprite.offset = Vector2(0, -62)
		sprite.sprite_frames = SpriteSheet.build_from_strips({
			"idle":    {"tex": load(A + "idle.png"),    "fps": 8.0,  "loop": true},
			"walk":    {"tex": load(A + "walk.png"),    "fps": 9.0,  "loop": true},
			"run":     {"tex": load(A + "run.png"),     "fps": 14.0, "loop": true},
			"attack":  {"tex": load(A + "attack1.png"), "fps": 10.0, "loop": false},
			"hurt":    {"tex": load(A + "hurt.png"),    "fps": 10.0, "loop": false},
			"death":   {"tex": load(A + "dead.png"),    "fps": 10.0, "loop": false},
		}, CELL)
	add_to_group("enemy")

func tunables() -> Array:
	return [
		{"name": "strike_range", "label": "出手距离",  "min": 30.0, "max": 140.0, "step": 1.0},
		{"name": "keep_range",   "label": "保持距离",  "min": 0.0,  "max": 80.0,  "step": 1.0},
		{"name": "speed",        "label": "移动速度",  "min": 60.0, "max": 280.0, "step": 5.0},
		{"name": "slash_reach",  "label": "劈砍框前伸","min": 10.0, "max": 90.0,  "step": 1.0},
		{"name": "slash_width",  "label": "劈砍框宽",  "min": 20.0, "max": 120.0, "step": 1.0},
		{"name": "tele_dur",     "label": "预警时长s", "min": 0.2,  "max": 1.2,   "step": 0.02},
		{"name": "pause_dur",    "label": "砍后休息s", "min": 0.5,  "max": 3.0,   "step": 0.05},
	]

func _gather_intent(delta: float) -> void:
	if _base_speed < 0.0:
		_base_speed = speed
	_cd = maxf(_cd - delta, 0.0)
	_tele_t = maxf(_tele_t - delta, 0.0)
	_pause_t = maxf(_pause_t - delta, 0.0)

	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var dx := pl.global_position.x - global_position.x
	var dist := absf(dx)

	if attacking:
		return
	facing = 1 if dx >= 0.0 else -1
	move_dir = 0.0
	speed = _base_speed

	match _st:
		ST_IDLE:
			if dist > strike_range:
				move_dir = signf(dx)            # 快速压上
			elif keep_range > 0.0 and dist < keep_range:
				move_dir = -signf(dx)
			elif _cd <= 0.0 and _slot_free():
				_begin_windup()
		ST_TELE:
			if _tele_t <= 0.0:
				if sprite:
					sprite.modulate = Color.WHITE
				_fire_slash()
				_st = ST_ATTACK
		ST_ATTACK:
			_st = ST_PAUSE                       # 劈砍动画收尾 → 进休息
			_pause_t = pause_dur
		ST_PAUSE:
			if _pause_t <= 0.0:
				_st = ST_IDLE
				_cd = 0.2

func _begin_windup() -> void:
	_st = ST_TELE
	_tele_t = tele_dur
	if sprite:
		sprite.modulate = Color(1.0, 0.45, 0.3)   # 举刀预警(凶)

func _update_anim() -> void:
	if _st == ST_TELE and sprite and sprite.sprite_frames:
		if sprite.animation != "attack":
			sprite.play("attack")
		sprite.pause()
		sprite.frame = 0
		return
	super._update_anim()

func _fire_slash() -> void:
	start_attack({
		"anim": "attack", "reach": slash_reach, "size": Vector2(slash_width, 46),
		"from": 3, "to": 4, "dmg": 14.0, "posture": 22.0,
	})

# 弹反它的劈砍 = 当场处决
func flinch(_push_dir: float) -> void:
	if _dead:
		return
	hp = 0.0
	hp_changed.emit(hp, max_hp)
	FX.screen_flash(Color(1, 0.9, 0.6), 0.5, 0.22)
	Juice.shake(12.0)
	_die()

# 调参可视化：出手/保持距离线 + 劈砍框预览
func _draw() -> void:
	super._draw()
	if not _dbg:
		return
	for s in [1.0, -1.0]:
		draw_line(Vector2(strike_range * s, 4), Vector2(strike_range * s, -80), Color(1.0, 0.8, 0.2, 0.55), 1.5)
		if keep_range > 0.0:
			draw_line(Vector2(keep_range * s, 4), Vector2(keep_range * s, -66), Color(0.4, 0.7, 1.0, 0.5), 1.5)
	var cx := float(facing) * slash_reach
	draw_rect(Rect2(cx - slash_width * 0.5, -body_size.y * 0.5 - 11, slash_width, 22), Color(1.0, 0.3, 0.3, 0.22))
