extends RefCounted
class_name SurvivorUpgrades
## 升级/商店选项数据。data 驱动:每项 {name, stat, add 或 mul}。
## add=直接加;mul=按当前基准乘比例(如 0.12 = +12%)。

const STAT_UPS := [
	{"name": "生命 +20", "stat": "max_hp", "add": 20.0, "color": Color(0.9, 0.4, 0.4)},
	{"name": "移速 +12%", "stat": "speed", "mul": 0.12, "color": Color(0.5, 0.8, 1.0)},
	{"name": "伤害 +15%", "stat": "damage", "mul": 0.15, "color": Color(1.0, 0.6, 0.3)},
	{"name": "攻速 +12%", "stat": "atk_speed", "mul": 0.12, "color": Color(1.0, 0.85, 0.3)},
	{"name": "射程 +12%", "stat": "range", "mul": 0.12, "color": Color(0.7, 0.9, 0.5)},
	{"name": "拾取范围 +40", "stat": "pickup_range", "add": 40.0, "color": Color(0.5, 0.95, 0.6)},
	{"name": "暴击率 +8%", "stat": "crit", "add": 0.08, "color": Color(1.0, 0.5, 0.5)},
	{"name": "护甲 +2", "stat": "armor", "add": 2.0, "color": Color(0.7, 0.7, 0.8)},
	{"name": "生命回复 +0.6/s", "stat": "regen", "add": 0.6, "color": Color(0.6, 1.0, 0.7)},
]

## 随机抽 n 个不重复的属性升级
static func roll(n: int) -> Array:
	var pool := STAT_UPS.duplicate()
	pool.shuffle()
	return pool.slice(0, n)

## 商店报价:n 项,带价格(随波次涨)。可能混入「+1 武器」。
static func shop_offers(n: int, wave: int) -> Array:
	var offers := []
	var pool := STAT_UPS.duplicate()
	pool.shuffle()
	for i in range(n):
		var up: Dictionary = pool[i % pool.size()].duplicate()
		up["price"] = 8 + wave * 3 + i * 2
		up["kind"] = "stat"
		offers.append(up)
	# 25% 概率把最后一项换成「加一把武器」
	if randf() < 0.25 + wave * 0.03:
		offers[n - 1] = {"name": "+1 武器(手枪)", "kind": "weapon",
			"price": 22 + wave * 5, "color": Color(1.0, 0.8, 0.4)}
	return offers
