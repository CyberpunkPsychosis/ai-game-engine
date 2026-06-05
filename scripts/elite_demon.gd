extends Enemy
class_name EliteDemon
## 精英·恶魔史莱姆（chierit Demon Slime FREE）。只有一个大劈 cleave，
## 用基类灵活 AI（后撤反冲/蓄势/红光预警）。素材默认朝左。

const SHEET := preload("res://art/boss/demon_slime.png")
const DCELL := Vector2i(288, 160)

func _setup() -> void:
	team = 1
	max_hp = 110.0
	posture_max = 110.0
	body_size = Vector2(44, 92)
	speed = 66.0
	aggro_range = 520.0
	engage_range = 92.0
	feint_chance = 0.25
	if sprite:
		sprite.sprite_frames = SpriteSheet.build(SHEET, DCELL, {
			"idle":   [0, 6,  7.0,  true],
			"walk":   [1, 12, 9.0,  true],
			"cleave": [2, 15, 11.0, false],   # 放慢=前摇可读
			"hurt":   [3, 5,  12.0, false],
			"death":  [4, 22, 12.0, false],
		})
	anim_run = "walk"
	anim_attack = "cleave"
	sprite_faces_left = true   # Demon Slime 默认朝左
	moves = [
		{"anim": "cleave", "reach": 80.0, "size": Vector2(150, 88), "from": 8, "to": 11,
		 "dmg": 15.0, "posture": 18.0, "recover": 2.2, "weight": 2.5, "range": 86.0, "backoff": 0.45},
		{"anim": "cleave", "reach": 78.0, "size": Vector2(160, 96), "from": 8, "to": 11,
		 "dmg": 22.0, "posture": 26.0, "perilous": true, "recover": 2.8, "weight": 1.0, "range": 82.0, "backoff": 0.55},
	]
	add_to_group("enemy")
