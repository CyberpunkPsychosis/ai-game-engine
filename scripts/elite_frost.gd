extends Enemy
class_name EliteFrost
## 精英·冰霜守卫（chierit Frost Guardian FREE）。
## 【基线版】行为只有：走过来 → 打一拳 → 歇一下 → 再来。
## 之后按 boss 设计逐步加招。

const SHEET := preload("res://art/frost/frost_guardian.png")
const FCELL := Vector2i(192, 128)

@export var rest_time := 1.6   # 打完歇多久

func _setup() -> void:
	team = 1
	max_hp = 95.0
	posture_max = 100.0
	body_size = Vector2(34, 72)
	speed = 150.0               # 跑速：远处冲过来
	aggro_range = 600.0         # 这么远就开始冲
	engage_range = 72.0         # 跑到这么近(你面前)才出拳
	sprite_faces_left = true    # Frost Guardian 素材默认朝左
	if sprite:
		sprite.sprite_frames = SpriteSheet.build(SHEET, FCELL, {
			"idle":   [0, 6,  7.0,  true],
			"walk":   [1, 10, 9.0,  true],
			"attack": [2, 14, 10.0, false],   # 1_atk 前冲重拳(放慢=前摇可读)
			"hurt":   [3, 7,  12.0, false],
			"death":  [4, 16, 11.0, false],
		})
	anim_run = "walk"
	add_to_group("enemy")

# 基线 AI：走过来 → 打一拳 → 歇 rest_time → 再来
func _gather_intent(_delta: float) -> void:
	_cd = maxf(_cd - _delta, 0.0)
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var dx := pl.global_position.x - global_position.x
	var dist := absf(dx)
	if attacking:
		return                      # 出拳中锁朝向
	facing = 1 if dx >= 0.0 else -1
	if dist > aggro_range:
		return                      # 太远 → 待机
	if dist > engage_range:
		move_dir = signf(dx)        # 跑到你面前
		return
	if _cd <= 0.0:                  # 歇好了 → 打一拳
		start_attack({"anim": "attack", "reach": 72.0, "size": Vector2(116, 70),
			"from": 6, "to": 9, "dmg": 13.0, "posture": 16.0})
		_cd = rest_time

# 基线版：被弹反只踉跄一下，不后撤反冲
func flinch(push_dir: float) -> void:
	super.flinch(push_dir)
	_retreat_t = 0.0
	_charging = false
