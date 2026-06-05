extends Enemy
class_name SkelSpearman
## 长矛骷髅：超长突刺（细长攻击框，逼你远距离读招）+ 偶尔红光「危」横扫（要闪/跳）。
## 怕贴身：保持中距离戳你。

const A := "res://art/spearman/"

func _setup() -> void:
	team = 1
	max_hp = 70.0
	posture_max = 95.0       # 更耐打，破防慢
	body_size = Vector2(22, 58)
	speed = 80.0
	aggro_range = 460.0
	engage_range = 84.0      # 长矛够得远
	keep_distance = 58.0     # 保持中距，怕贴脸
	if sprite:
		sprite.offset = Vector2(0, -62)
		sprite.sprite_frames = SpriteSheet.build_from_strips({
			"idle":    {"tex": load(A + "idle.png"),    "fps": 8.0,  "loop": true},
			"walk":    {"tex": load(A + "walk.png"),    "fps": 9.0,  "loop": true},
			"run":     {"tex": load(A + "run.png"),     "fps": 11.0, "loop": true},
			"attack":  {"tex": load(A + "attack1.png"), "fps": 9.0,  "loop": false},
			"attack2": {"tex": load(A + "attack2.png"), "fps": 9.0,  "loop": false},
			"hurt":    {"tex": load(A + "hurt.png"),    "fps": 10.0, "loop": false},
			"death":   {"tex": load(A + "dead.png"),    "fps": 10.0, "loop": false},
		}, CELL)
	moves = [
		# 长突刺（细长，可弹）
		{"anim": "attack", "reach": 66.0, "size": Vector2(92, 24), "from": 2, "to": 3,
		 "dmg": 11.0, "posture": 18.0, "recover": 1.8, "weight": 2.0, "range": 88.0},
		# 红光「危」横扫（不可弹，要闪/跳）
		{"anim": "attack2", "reach": 52.0, "size": Vector2(74, 44), "from": 2, "to": 3,
		 "dmg": 14.0, "posture": 24.0, "perilous": true, "recover": 2.3, "weight": 1.0, "range": 70.0, "backoff": 0.6},
	]
	add_to_group("enemy")
