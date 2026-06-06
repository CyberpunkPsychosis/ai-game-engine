extends Enemy
class_name SkelArcher
## 弓箭骷髅：远程风筝。玩家一逼近（不管是闪避还是跳近身）→ 向后跃开（带起跳无敌帧），
## 落地一回到射程立刻放箭（箭可被弹反）。教"处理远程 / 逼近压制"。

const A := "res://art/archer/"
const SHOT_FRAME := 9       # shot 动画第几帧放箭
const HOP_TRIGGER := 130.0  # 玩家近于此 → 向后跃开
const HOP_SPEED := 430.0    # 后跃水平速度（跃得远，一跳拉开整段距离）
const HOP_COOLDOWN := 1.6   # 跳一次就够：落地先放箭，这段时间内不再跳
const SHOOT_MAX := 340.0    # 进入此距离开始射
const BOW_Y := -48.0        # 弓口高度（相对脚底）

var arrow_speed := 560.0   # 箭速(可调)
var _shot_fired := false
var _hopping := false
var _hop_cd := 0.0

func tunables() -> Array:
	return [
		{"name": "arrow_speed", "label": "箭速",     "min": 200.0, "max": 800.0, "step": 10.0},
		{"name": "aggro_range", "label": "索敌距离", "min": 200.0, "max": 700.0, "step": 10.0},
	]

func _setup() -> void:
	team = 1
	max_hp = 45.0
	posture_max = 55.0       # 脆，好破
	parry_deaths = 2         # 反弹两箭就死
	body_size = Vector2(20, 56)
	speed = 90.0
	aggro_range = 560.0
	# 后跃手感：跳高一点、滞空久一点 → 一跳拉开整段距离
	jump_velocity = -420.0
	gravity_up = 1350.0
	gravity_down = 1700.0
	anim_jump = "evasion"    # 腾空就放闪避动作 → 后跃看着像翻身跳
	anim_fall = "evasion"
	if sprite:
		sprite.offset = Vector2(0, -62)
		sprite.sprite_frames = SpriteSheet.build_from_strips({
			"idle":   {"tex": load(A + "idle.png"),   "fps": 8.0,  "loop": true},
			"walk":   {"tex": load(A + "walk.png"),   "fps": 10.0, "loop": true},
			"run":    {"tex": load(A + "walk.png"),   "fps": 13.0, "loop": true},
			"shot":   {"tex": load(A + "shot.png"),   "fps": 18.0, "loop": false},
			"evasion":{"tex": load(A + "evasion.png"),"fps": 12.0, "loop": false},
			"hurt":   {"tex": load(A + "hurt.png"),   "fps": 10.0, "loop": false},
			"death":  {"tex": load(A + "dead.png"),   "fps": 10.0, "loop": false},
		}, CELL)
	add_to_group("enemy")

func _gather_intent(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_hop_cd = maxf(_hop_cd - delta, 0.0)
	if _base_speed < 0.0:
		_base_speed = speed
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var dx := pl.global_position.x - global_position.x
	var dist := absf(dx)

	if attacking:
		# 射击动画到放箭帧 → 生成箭（出招中锁朝向）
		if not _shot_fired and sprite and sprite.animation == "shot" and sprite.frame >= SHOT_FRAME:
			_fire_arrow()
			_shot_fired = true
		return

	# 后跃中：空中持续往后冲、始终面向玩家好接着射；落地即结束
	if _hopping:
		facing = 1 if dx >= 0.0 else -1
		lock_facing = true               # 后退也始终朝玩家
		speed = HOP_SPEED
		move_dir = -signf(dx)
		# 无敌帧只罩上升段（躲掉贴脸那一下），下落段恢复可被打
		if velocity.y >= 0.0 and invulnerable:
			invulnerable = false
			if sprite:
				sprite.modulate = Color.WHITE
		if is_on_floor() and velocity.y >= 0.0:
			_hopping = false
			lock_facing = false
			speed = _base_speed
			_cd = minf(_cd, 0.04)    # 落地几乎立刻可射
		return

	facing = 1 if dx >= 0.0 else -1

	# 玩家逼近（含闪避/跳跃贴脸）→ 向后跃开
	if dist < HOP_TRIGGER and _hop_cd <= 0.0 and is_on_floor():
		_begin_hop(dx)
		return
	if dist > aggro_range:
		return
	if dist > SHOOT_MAX:
		move_dir = signf(dx)         # 太远 → 走近进射程
		return
	# 在射程内、冷却好 → 立刻放箭
	if _cd <= 0.0 and _slot_free():
		_begin_shot()

func _begin_hop(dx: float) -> void:
	_hopping = true
	_hop_cd = HOP_COOLDOWN
	facing = 1 if dx >= 0.0 else -1  # 跃走也面向玩家
	lock_facing = true               # 后退不翻面
	want_jump = true                 # 交给基类的跳跃逻辑起跳
	move_dir = -signf(dx)            # 朝玩家反方向跃
	speed = HOP_SPEED
	invulnerable = true              # 起跳带无敌帧，吃掉贴脸那一击
	if sprite:
		sprite.modulate = Color(0.7, 0.85, 1.0, 0.7)  # 蓝调=无敌
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("evasion"):
			sprite.play("evasion")

func flinch(push_dir: float) -> void:
	super.flinch(push_dir)
	_hopping = false                 # 被弹反 → 取消后跃状态
	lock_facing = false
	invulnerable = false
	if sprite:
		sprite.modulate = Color.WHITE

func _begin_shot() -> void:
	attacking = true
	current_attack_anim = "shot"
	_shot_fired = false
	attack_active_from = 99          # 不用近战框
	attack_active_to = 99
	if sprite:
		sprite.play("shot")
	_cd = 2.6

func _fire_arrow() -> void:
	var from := global_position + Vector2(float(facing) * 14.0, BOW_Y)   # 弓口
	var target := from + Vector2(float(facing) * 120.0, 0.0)
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl:
		target = pl.global_position + Vector2(0.0, -30.0)               # 瞄准玩家躯干
	var a := Arrow.new()
	a.shooter = self
	a.setup(target - from, arrow_speed)
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(a)
	a.global_position = from
	FX.sfx("shot")
