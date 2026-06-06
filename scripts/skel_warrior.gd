extends Enemy
class_name SkelWarrior
## 持剑骷髅：均衡的"弹反教学怪"。慢刀 + 偶尔重斩，前摇清晰、都可弹。

const A := "res://art/skeleton/"

func _setup() -> void:
	team = 1
	max_hp = 60.0
	posture_max = 80.0
	body_size = Vector2(22, 58)
	speed = 95.0
	aggro_range = 400.0
	engage_range = 56.0
	if sprite:
		sprite.offset = Vector2(0, -62)
		sprite.sprite_frames = SpriteSheet.build_from_strips({
			"idle":    {"tex": load(A + "idle.png"),    "fps": 8.0,  "loop": true},
			"walk":    {"tex": load(A + "walk.png"),    "fps": 9.0,  "loop": true},
			"run":     {"tex": load(A + "run.png"),     "fps": 12.0, "loop": true},
			"attack":  {"tex": load(A + "attack1.png"), "fps": 10.0, "loop": false},
			"attack2": {"tex": load(A + "attack2.png"), "fps": 9.0,  "loop": false},
			"hurt":    {"tex": load(A + "hurt.png"),    "fps": 10.0, "loop": false},
			"death":   {"tex": load(A + "dead.png"),    "fps": 10.0, "loop": false},
		}, CELL)
	moves = [
		# 慢刀（教学，权重高）
		{"anim": "attack", "reach": 44.0, "size": Vector2(58, 46), "from": 3, "to": 4,
		 "dmg": 9.0, "posture": 16.0, "recover": 1.6, "weight": 2.5, "range": 58.0},
		# 重斩（更痛、收招更久=破绽更大）
		{"anim": "attack2", "reach": 48.0, "size": Vector2(66, 48), "from": 3, "to": 5,
		 "dmg": 12.0, "posture": 22.0, "recover": 2.1, "weight": 1.0, "range": 62.0, "backoff": 0.45},
	]
	add_to_group("enemy")

# 调参：通用项 + 两招的攻击框前伸/宽度（直接改 moves，下一刀生效）
func tunables() -> Array:
	var t := super.tunables()
	t.append_array([
		{"name": "atk1_reach", "label": "慢刀框前伸", "min": 10.0, "max": 90.0,  "step": 1.0},
		{"name": "atk1_width", "label": "慢刀框宽",   "min": 20.0, "max": 120.0, "step": 1.0},
		{"name": "atk2_reach", "label": "重斩框前伸", "min": 10.0, "max": 90.0,  "step": 1.0},
		{"name": "atk2_width", "label": "重斩框宽",   "min": 20.0, "max": 120.0, "step": 1.0},
	])
	return t

var atk1_reach: float:
	get: return float(moves[0].get("reach", 0.0)) if moves.size() > 0 else 0.0
	set(v): if moves.size() > 0: moves[0]["reach"] = v
var atk1_width: float:
	get: return (moves[0]["size"] as Vector2).x if moves.size() > 0 else 0.0
	set(v):
		if moves.size() > 0: moves[0]["size"] = Vector2(v, (moves[0]["size"] as Vector2).y)
var atk2_reach: float:
	get: return float(moves[1].get("reach", 0.0)) if moves.size() > 1 else 0.0
	set(v): if moves.size() > 1: moves[1]["reach"] = v
var atk2_width: float:
	get: return (moves[1]["size"] as Vector2).x if moves.size() > 1 else 0.0
	set(v):
		if moves.size() > 1: moves[1]["size"] = Vector2(v, (moves[1]["size"] as Vector2).y)
