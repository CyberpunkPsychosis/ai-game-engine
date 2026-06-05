extends Enemy
class_name SkelArcher
## 弓箭骷髅：远程风筝。保持距离射箭（箭可被弹反），玩家逼近就后撤。
## 教"处理远程 / 拉近距离"。

const A := "res://art/archer/"
const SHOT_FRAME := 9     # shot 动画第几帧放箭
const FLEE_RANGE := 110.0 # 玩家近于此 → 后撤
const SHOOT_MAX := 340.0  # 进入此距离开始射
const BOW_Y := -48.0      # 弓口高度（相对脚底）

var _shot_fired := false

func _setup() -> void:
	team = 1
	max_hp = 45.0
	posture_max = 55.0       # 脆，好破
	body_size = Vector2(20, 56)
	speed = 90.0
	aggro_range = 560.0
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
	facing = 1 if dx >= 0.0 else -1

	if dist < FLEE_RANGE:
		move_dir = -signf(dx)        # 太近 → 后撤
		return
	if dist > aggro_range:
		return
	if dist > SHOOT_MAX:
		move_dir = signf(dx)         # 进入射程
		return
	if _cd <= 0.0 and _slot_free():
		_begin_shot()

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
	a.setup(target - from, 560.0)   # 箭提速(330->560)，更利落
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(a)
	a.global_position = from
	FX.sfx("shot")
