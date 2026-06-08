extends CharacterBody2D
class_name SurvivorEnemy
## 幸存者敌人(灰盒:红色多边形)。朝玩家移动,贴身造成接触伤害,死亡掉材料。
## 数值随波次成长。碰撞:layer3=enemy。

signal died(enemy)

var max_hp := 24.0
var hp := 24.0
var speed := 62.0
var touch_damage := 8.0
var material_value := 1
var _radius := 13.0
var _color := Color(0.86, 0.28, 0.30)
var _target: Node2D
var _touch_cd := 0.0
var _flash := 0.0
var _knockback := Vector2.ZERO

func setup(target: Node2D, wave: int) -> void:
	_target = target
	# 随波次成长:血量与伤害温和上升,速度小幅上升
	var w := float(wave - 1)
	max_hp = 24.0 + w * 8.0
	hp = max_hp
	touch_damage = 8.0 + w * 1.5
	speed = 58.0 + w * 2.0
	material_value = 1 + int(w / 4.0)
	# 偶尔来个更大更肉的(灰盒变体)
	if randf() < 0.12 + w * 0.01:
		max_hp *= 2.2; hp = max_hp; _radius = 19.0
		speed *= 0.8; touch_damage *= 1.4; material_value += 2
		_color = Color(0.7, 0.2, 0.45)

func _ready() -> void:
	collision_layer = 1 << 2        # layer 3: enemy
	collision_mask = 0              # 不做物理碰撞,纯追逐(灰盒)
	add_to_group("survivor_enemy")
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = _radius
	cs.shape = sh
	add_child(cs)

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
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			queue_redraw()

func take_hit(dmg: float, _crit: bool, from_pos: Vector2) -> void:
	hp -= dmg
	_flash = 0.07
	_knockback = (global_position - from_pos).normalized() * 140.0
	queue_redraw()
	if FX:
		FX.spark(global_position, Color(1, 0.8, 0.5), 5, 8.0)
	if hp <= 0.0:
		died.emit(self)
		queue_free()

func _draw() -> void:
	var c := _color.lerp(Color.WHITE, 0.75) if _flash > 0.0 else _color
	# 菱形身体 + 深色描边
	var pts := PackedVector2Array([
		Vector2(0, -_radius), Vector2(_radius, 0),
		Vector2(0, _radius), Vector2(-_radius, 0)])
	draw_colored_polygon(pts, c)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.5), 1.5)
	# 血条(受伤后才显示)
	if hp < max_hp:
		var w := _radius * 2.0
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		var y := -_radius - 7.0
		draw_rect(Rect2(-w / 2.0, y, w, 3.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, y, w * ratio, 3.0), Color(0.4, 0.95, 0.4))
