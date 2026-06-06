extends Hitbox
class_name Arrow
## 弓箭弹道：朝目标方向飞、箭头随飞行方向旋转。命中/被弹后销毁。
## 可被玩家弹反（点 K）→ 沿原路反弹回去打射手。

var _vel := Vector2.ZERO
var _life := 3.0
var _sprite: Sprite2D
var _reflected := false
var _rearm := 0.0
var shooter: Actor2D            ## 谁射的（反弹回去打它，按它的"弹反几次死"算伤害）

## dir：飞行方向（向量，会归一化）。
func setup(dir: Vector2, speed := 330.0) -> void:
	_vel = dir.normalized() * speed
	rotation = _vel.angle()        # 箭头朝飞行方向
	damage = 8.0
	posture_damage = 10.0
	consumable = true
	collision_layer = 1 << 3       # 敌人攻击层（玩家受击框监听）
	collision_mask = 0
	monitoring = false
	monitorable = true
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/archer/arrow.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 8)
	cs.shape = r
	cs.position = Vector2(12, 0)   # 判定前移到箭尖：箭尖一到就触发(弹反/命中)，不用等箭身压上
	add_child(cs)
	add_to_group("arrow")

## 被弹反 → 沿原路反向加速飞回去，改成玩家方（打敌人），更痛。
func reflect(_dir := 0) -> void:
	_reflected = true
	_vel = -_vel * 1.35
	rotation = _vel.angle()
	collision_layer = 1 << 2       # 玩家攻击层（敌人受击框监听）
	damage = 16.0
	posture_damage = 22.0
	# 射手设了"弹反几次死" → 反弹这一箭打它一下就掉那么多血
	if is_instance_valid(shooter) and shooter.parry_deaths > 0:
		damage = shooter.max_hp / float(shooter.parry_deaths)
	consumable = false             # 本帧先别被玩家受击框销毁
	_rearm = 0.06
	_life = 3.0
	if _sprite:
		_sprite.modulate = Color(1.0, 1.0, 0.5)   # 金色=已弹反

func _physics_process(delta: float) -> void:
	position += _vel * delta
	if _rearm > 0.0:
		_rearm -= delta
		if _rearm <= 0.0:
			consumable = true
	_life -= delta
	if _life <= 0.0:
		queue_free()
