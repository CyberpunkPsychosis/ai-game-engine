extends Area2D
class_name SurvivorPickup
## 材料掉落(灰盒:绿色小宝石)。在拾取范围内吸向玩家,接触即收集。
## 材料同时是「钱(商店用)」和「经验(升级用)」——与土豆兄弟一致。
## 碰撞:layer8=pickups,mask=layer2=player。

const TEX := preload("res://assets/survivor/gem.png")

var value := 1
var _target: Node2D
var _speed := 0.0
var _r := 6.0
var _spin := 0.0
var _spr: Sprite2D

func setup(target: Node2D, v: int) -> void:
	_target = target
	value = v
	_r = 6.0 + minf(float(v), 4.0)

func _ready() -> void:
	collision_layer = 1 << 7        # layer 8: pickups
	collision_mask = 1 << 1         # layer 2: player
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = _r + 6.0            # 略大一点更好捡
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_body)
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	var sc := (_r * 2.4) / float(maxi(TEX.get_width(), TEX.get_height()))
	_spr.scale = Vector2(sc, sc)
	_spin = randf() * TAU

func _process(delta: float) -> void:
	_spin += delta * 3.0
	if _spr:
		_spr.position.y = sin(_spin) * 2.0          # 上下漂
		_spr.scale.x = absf(_spr.scale.y) * cos(_spin) # 左右翻转闪光感
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
		if FX:
			FX.spark(global_position, Color(0.5, 1.0, 0.6), 4, 7.0)
		queue_free()
