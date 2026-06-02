extends Area2D
class_name Hurtbox
## 受击判定框。放在会被打的角色上，指向它的 Health。
## 当有 Hitbox 进入时，自动扣血并广播命中信息（用于击退 / 顿帧 / 震动）。

signal hit_by(hitbox: Hitbox)

@export var health_path: NodePath

var _health: Health

func _ready() -> void:
	_health = get_node_or_null(health_path) as Health
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	var hitbox := area as Hitbox
	if hitbox == null:
		return
	if _health != null:
		_health.take_damage(hitbox.damage, hitbox)
	hit_by.emit(hitbox)
