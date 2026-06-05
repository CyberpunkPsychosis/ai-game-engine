extends Area2D
class_name Hitbox
## 攻击判定框。放在攻击者（玩家武器 / 敌人）上。
## 通过碰撞层与对方的 Hurtbox 配对：玩家攻击框 监听 敌人受击框，反之亦然。

@export var damage := 10.0
@export var posture_damage := 16.0      ## 架势伤害（弹反/格挡/中招都按它算）
@export var perilous := false           ## 危攻击（红光）：不可弹，必须闪/跳
@export var consumable := false          ## 命中/被弹后销毁（弹道/箭矢用）
@export var knockback := 220.0          ## 击退力度（像素/秒）
@export var hitstop := 0.07             ## 命中顿帧时长（秒）
@export var shake := 6.0                ## 命中镜头震动强度

## 击退方向（从攻击者指向目标的水平方向），由拥有者设置或按相对位置计算
func knockback_dir_to(target: Node2D) -> Vector2:
	var owner_2d := get_parent() as Node2D
	if owner_2d == null or target == null:
		return Vector2.RIGHT
	return (target.global_position - owner_2d.global_position).normalized()
