extends Area2D
class_name SurvivorProjectile
## 玩家投射物(灰盒:小色球)。命中敌人结算伤害,支持穿透/寿命。
## 碰撞:layer4=player_hitbox,mask=layer3=enemy。

var vel := Vector2.ZERO
var damage := 10.0
var pierce := 0
var crit := false
var _life := 1.4
var _radius := 5.0
var _hit := {}

func _ready() -> void:
	collision_layer = 1 << 3        # layer 4: player_hitbox
	collision_mask = 1 << 2         # layer 3: enemy
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = _radius
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	position += vel * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body(body: Node) -> void:
	var id := body.get_instance_id()
	if _hit.has(id):
		return
	if body.has_method("take_hit"):
		_hit[id] = true
		body.take_hit(damage, crit, global_position)
		if pierce <= 0:
			queue_free()
		else:
			pierce -= 1

func _draw() -> void:
	var col := Color(1, 0.85, 0.35) if not crit else Color(1, 0.45, 0.35)
	draw_circle(Vector2.ZERO, _radius, col)
	draw_circle(Vector2.ZERO, _radius, Color(1, 1, 1, 0.5), false, 1.0)
