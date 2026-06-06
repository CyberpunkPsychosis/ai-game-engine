extends Actor2D
class_name Player
## 主角（Gothicvania Cemetery hero 皮，ansimuz）。只负责两件事：
##  ① 提供精灵表（每个动画一张 160x90 横条）
##  ② 读玩家输入填意图
## 所有移动/跳跃/闪避/攻击手感都在通用基类 Actor2D（换皮只改这里）。

const CELL := Vector2i(160, 90)
const IDLE   := preload("res://art/hero/idle.png")
const RUN    := preload("res://art/hero/run.png")
const ATTACK := preload("res://art/hero/attack.png")
const JUMP   := preload("res://art/hero/jump.png")
const CROUCH := preload("res://art/hero/crouch.png")
const HURT   := preload("res://art/hero/hurt.png")
const DEATH  := preload("res://art/hero/death.png")

func _setup() -> void:
	if sprite:
		sprite.sprite_frames = SpriteSheet.build_from_strips({
			"idle":   {"tex": IDLE,   "fps": 8.0,  "loop": true},
			"run":    {"tex": RUN,    "fps": 11.0, "loop": true},
			"attack": {"tex": ATTACK, "fps": 14.0, "loop": false},
			"jump":   {"tex": JUMP,   "fps": 10.0, "loop": false},
			"crouch": {"tex": CROUCH, "fps": 1.0,  "loop": false},
			"hurt":   {"tex": HURT,   "fps": 8.0,  "loop": false},
			"death":  {"tex": DEATH,  "fps": 10.0, "loop": false},
		}, CELL)
	anim_fall = "jump"     # 没有独立下落帧，下落复用 jump
	can_parry = true       # 主角能弹反（点 K 那一下踩窗口）
	can_block = true       # 主角能格挡（按住 K，剑挡身前，少量掉血）
	can_dodge = true       # 主角能闪避（L / Shift）
	parry_window = 0.10    # 弹反窗口很紧(~6帧)：要算准箭尖到身前那一刻
	# 主角是长突刺，攻击框要够长够远（之前太短砍空）
	body_size = Vector2(17, 50)   # 受击框(调参定)
	attack_reach = 20.0
	attack_size = Vector2(64, 40)
	attack_active_from = 1
	attack_active_to = 3
	add_to_group("player")

func tunables() -> Array:
	return [
		{"name": "parry_window", "label": "弹反窗口s", "min": 0.04, "max": 0.5,  "step": 0.01},
		{"name": "dodge_time",   "label": "闪避无敌s", "min": 0.1,  "max": 0.5,  "step": 0.01},
		{"name": "attack_reach", "label": "主角刀长",  "min": 20.0, "max": 80.0, "step": 1.0},
	]

func _gather_intent(_delta: float) -> void:
	move_dir = Input.get_axis("move_left", "move_right")
	want_jump = Input.is_action_just_pressed("jump")
	want_jump_release = Input.is_action_just_released("jump")
	want_attack = Input.is_action_just_pressed("attack")
	want_parry = Input.is_action_just_pressed("block")    # 点格挡键那一下 = 完美弹反
	guarding = Input.is_action_pressed("block") and not attacking and not dodging  # 按住 = 格挡
	want_dodge = Input.is_action_just_pressed("special")  # L / Shift = 闪避（无敌帧）
