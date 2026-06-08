extends Area2D
class_name SurvivorPickup
## 材料掉落(灰盒:绿色小宝石)。在拾取范围内吸向玩家,接触即收集。
## 材料同时是「钱(商店用)」和「经验(升级用)」——与土豆兄弟一致。
## 碰撞:layer8=pickups,mask=layer2=player。

var value := 1
var _target: Node2D
var _speed := 0.0
var _r := 5.0
var _spin := 0.0

func setup(target: Node2D, v: int) -> void:
	_target = target
	value = v
	_r = 5.0 + minf(float(v), 4.0)

func _ready() -> void:
	collision_layer = 1 << 7        # layer 8: pickups
	collision_mask = 1 << 1         # layer 2: player
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = _r
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_spin += delta * 4.0
	queue_redraw()
	if not is_instance_valid(_target):
		return
	var to := _target.global_position - global_position
	var rng: float = _target.get_pickup_range() if _target.has_method("get_pickup_range") else 70.0
	if to.length() < rng:
		_speed = lerpf(_speed, 360.0, 8.0 * delta)
		position += to.normalized() * _speed * delta

func _on_body(body: Node) -> void:
	if body.is_in_group("survivor_player") and body.has_method("on_pickup"):
		body.on_pickup(value)
		queue_free()

func _draw() -> void:
	var s := _r * (1.0 + 0.12 * sin(_spin))
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
	draw_colored_polygon(pts, Color(0.4, 0.92, 0.5))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.4, 0.2, 0.8), 1.0)
