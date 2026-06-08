extends CharacterBody2D
class_name SurvivorEnemy
## 幸存者敌人(精灵:小怪/肉怪)。朝玩家移动,贴身造成接触伤害,死亡掉材料。
## 数值随波次成长。碰撞:layer3=enemy。

signal died(enemy)

const TEX_SMALL := preload("res://assets/survivor/enemy_small.png")
const TEX_BIG := preload("res://assets/survivor/enemy_big.png")

var max_hp := 24.0
var hp := 24.0
var speed := 62.0
var touch_damage := 8.0
var material_value := 1
var _radius := 13.0
var _is_big := false
var _target: Node2D
var _touch_cd := 0.0
var _knockback := Vector2.ZERO
var _spr: Sprite2D
var _bob := 0.0

func setup(target: Node2D, wave: int) -> void:
	_target = target
	var w := float(wave - 1)
	max_hp = 24.0 + w * 8.0
	hp = max_hp
	touch_damage = 8.0 + w * 1.5
	speed = 58.0 + w * 2.0
	material_value = 1 + int(w / 4.0)
	# 偶尔来个更大更肉的(肉怪变体)
	if randf() < 0.12 + w * 0.01:
		_is_big = true
		max_hp *= 2.2; hp = max_hp; _radius = 19.0
		speed *= 0.8; touch_damage *= 1.4; material_value += 2

func _ready() -> void:
	collision_layer = 1 << 2        # layer 3: enemy
	collision_mask = 0              # 纯追逐,不做物理碰撞
	add_to_group("survivor_enemy")
	_bob = randf() * TAU
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = _radius
	cs.shape = sh
	add_child(cs)
	_spr = Sprite2D.new()
	_spr.texture = TEX_BIG if _is_big else TEX_SMALL
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	var target := _radius * 2.0 + 14.0
	var sc := target / float(maxi(_spr.texture.get_width(), _spr.texture.get_height()))
	_spr.scale = Vector2(sc, sc)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var to := _target.global_position - global_position
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else Vector2.ZERO
	velocity = dir * speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	_touch_cd = maxf(0.0, _touch_cd - delta)
	if dist < _radius + 13.0 and _touch_cd <= 0.0 and _target.has_method("hurt"):
		_target.hurt(touch_damage)
		_touch_cd = 0.55
	# 视觉:朝玩家翻面 + 浮动
	if _spr:
		if absf(velocity.x) > 1.0:
			_spr.flip_h = velocity.x < 0.0
		_bob += delta * 7.0
		_spr.position.y = sin(_bob) * 1.6

func take_hit(dmg: float, _crit: bool, from_pos: Vector2) -> void:
	hp -= dmg
	_knockback = (global_position - from_pos).normalized() * 150.0
	queue_redraw()                  # 刷新血条
	if FX:
		FX.spark(global_position, Color(1, 0.85, 0.5), 5, 8.0)
		if _spr:
			FX.flash(_spr, 0.08, Color(1, 1, 1))
	if hp <= 0.0:
		if FX:
			FX.spark(global_position, Color(1, 0.6, 0.4), 8, 14.0)
		died.emit(self)
		queue_free()

func _draw() -> void:
	# 落地软阴影(精灵之下)
	draw_circle(Vector2(0, _radius * 0.85), _radius * 0.8, Color(0, 0, 0, 0.20))
	# 血条(受伤后显示,位于精灵上方)
	if hp < max_hp:
		var w := _radius * 2.0
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		var y := -_radius - 16.0
		draw_rect(Rect2(-w / 2.0, y, w, 3.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, y, w * ratio, 3.0), Color(0.4, 0.95, 0.4))
