extends Node2D
class_name SurvivorWeapon
## 自动武器:每帧锁定射程内最近的敌人,冷却到了就朝它开火。
## 伤害/攻速/射程 全部吃 player.stats(玩家属性成长后武器自动变强)。

@export var display_name := "手枪"
@export var base_cooldown := 0.85   ## 秒/发(被攻速除)
@export var base_damage := 9.0
@export var bullet_speed := 560.0
@export var pierce := 0
@export var range_bonus := 0.0      ## 该武器额外射程(叠加在玩家射程上)

var player                          # SurvivorPlayer
var _cd := 0.0

func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	if _cd > 0.0 or player == null or not is_instance_valid(player):
		return
	var rng: float = player.stats.range + range_bonus
	var target := _nearest_enemy(rng)
	if target == null:
		return
	_fire(target, rng)

func _fire(target: Node2D, _rng: float) -> void:
	var dir := (target.global_position - player.global_position).normalized()
	var crit := randf() < player.stats.crit
	var dmg: float = base_damage * player.stats.damage * (2.0 if crit else 1.0)
	player.arena.spawn_projectile(player.global_position, dir, bullet_speed, dmg, pierce, crit)
	player.notify_fire(dir)
	_cd = base_cooldown / maxf(0.1, player.stats.atk_speed)
	if FX:
		FX.sfx("shoot", -6.0, randf_range(0.95, 1.08))

func _nearest_enemy(rng: float) -> Node2D:
	var best: Node2D = null
	var best_d := rng * rng
	var origin := player.global_position
	for e in get_tree().get_nodes_in_group("survivor_enemy"):
		if not is_instance_valid(e):
			continue
		var d := origin.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
