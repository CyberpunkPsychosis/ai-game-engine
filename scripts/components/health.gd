extends Node
class_name Health
## 可复用血量组件。挂到任意角色/敌人上。

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal health_changed(current: float, maximum: float)
signal died

@export var max_health := 100.0
@export var invincible := false

var current := 0.0
var is_dead := false

func _ready() -> void:
	current = max_health

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead or invincible or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current, max_health)

func get_ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0
