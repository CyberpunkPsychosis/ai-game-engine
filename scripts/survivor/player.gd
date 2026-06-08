extends CharacterBody2D
class_name SurvivorPlayer
## 俯视角玩家(灰盒:圆身 + 朝向枪管)。8 向移动(键盘 WASD/方向键 + 虚拟摇杆)。
## 持有属性表 stats 与多把自动武器。碰撞:layer2=player。

signal died
signal damaged(amount: float)

var stats := {
	"max_hp": 60.0, "speed": 230.0,
	"damage": 1.0, "atk_speed": 1.0, "range": 320.0,
	"pickup_range": 72.0, "crit": 0.05, "armor": 0.0, "regen": 0.0,
}
var hp := 60.0
var weapons: Array = []
var arena                                # SurvivorArena
var _joy                                 # 虚拟摇杆(可空)
var _aim := Vector2.RIGHT
var _radius := 12.0
var _invuln := 0.0
var _hurt_flash := 0.0

func _ready() -> void:
	collision_layer = 1 << 1            # layer 2: player
	collision_mask = 0                  # 自由移动,边界由 arena 钳制
	add_to_group("survivor_player")
	hp = stats.max_hp
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = _radius
	cs.shape = sh
	add_child(cs)

func set_joystick(j) -> void:
	_joy = j

func _physics_process(delta: float) -> void:
	var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if iv == Vector2.ZERO and _joy and _joy.has_method("get_vector"):
		iv = _joy.get_vector()
	velocity = iv.limit_length(1.0) * stats.speed
	move_and_slide()
	if arena:
		global_position = arena.clamp_pos(global_position)
	_invuln = maxf(0.0, _invuln - delta)
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if stats.regen > 0.0 and hp < stats.max_hp:
		hp = minf(stats.max_hp, hp + stats.regen * delta)
	queue_redraw()

# --- 战斗 ---
func hurt(amount: float) -> void:
	if _invuln > 0.0 or hp <= 0.0:
		return
	var reduce: float = minf(0.75, stats.armor * 0.04)   # 护甲减伤(上限75%)
	var dmg := maxf(1.0, amount * (1.0 - reduce))
	hp = maxf(0.0, hp - dmg)
	_invuln = 0.5
	_hurt_flash = 0.25
	damaged.emit(dmg)
	if Juice:
		Juice.shake(7.0)
	if FX:
		FX.flash(self, 0.12, Color(1, 0.4, 0.4))
	if hp <= 0.0:
		died.emit()

func notify_fire(dir: Vector2) -> void:
	_aim = dir

# --- 升级 / 拾取 ---
func apply_upgrade(up: Dictionary) -> void:
	var stat: String = up.get("stat", "")
	if not stats.has(stat):
		return
	if up.has("add"):
		stats[stat] += up["add"]
		if stat == "max_hp":
			hp += up["add"]                # 加最大血时同时回血
	elif up.has("mul"):
		stats[stat] += stats[stat] * up["mul"]

func add_weapon(w) -> void:
	w.player = self
	add_child(w)
	weapons.append(w)

func get_pickup_range() -> float:
	return stats.pickup_range

func on_pickup(v: int) -> void:
	if arena:
		arena.collect(v)

func _draw() -> void:
	var body := Color(0.85, 0.78, 0.45)   # 土豆黄(占位)
	if _hurt_flash > 0.0:
		body = body.lerp(Color(1, 0.3, 0.3), 0.6)
	elif _invuln > 0.0:
		body = body.lerp(Color.WHITE, 0.4)
	draw_circle(Vector2.ZERO, _radius, body)
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 20, Color(0.2, 0.15, 0.05, 0.8), 2.0)
	# 枪管朝向最近开火方向
	draw_line(Vector2.ZERO, _aim * (_radius + 8.0), Color(0.25, 0.2, 0.1), 4.0)
