extends Node2D
class_name SurvivorArena
## 竞技场总控:相机/边界/刷怪/波次计时/材料经验/升级/商店/结算。
## 代码驱动:玩家、敌人、投射物、掉落、HUD 全在这里建,场景只需挂本脚本。
##
## 核心循环(土豆兄弟式):
##   移动+自动开火 → 杀怪掉材料 → 捡材料(=钱+经验) → 升级三选一
##   → 波次倒计时结束 → 商店花材料 → 下一波(数值更强)。

const ARENA_SIZE := Vector2(1700, 1000)

# --- run 状态(HUD 直接读这些公有字段) ---
var materials := 0
var xp := 0
var xp_to_next := 5
var level := 1
var kills := 0
var wave := 1
var wave_time := 22.0
var wave_clock := 22.0

var player: SurvivorPlayer
var hud: SurvivorHUD
var _cam: Camera2D
var _enemies: Node2D
var _pickups: Node2D
var _shots: Node2D
var _spawn_acc := 0.6
var _running := true

func _ready() -> void:
	_draw_ground()
	_cam = Camera2D.new()
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(ARENA_SIZE.x)
	_cam.limit_bottom = int(ARENA_SIZE.y)
	_cam.position_smoothing_enabled = false
	add_child(_cam)
	_cam.make_current()
	if Juice:
		Juice.register_camera(_cam)
	_enemies = _layer()
	_pickups = _layer()
	_shots = _layer()
	# 玩家
	player = SurvivorPlayer.new()
	player.arena = self
	add_child(player)
	player.global_position = ARENA_SIZE * 0.5
	player.died.connect(_on_player_died)
	# 起始武器
	var w := SurvivorWeapon.new()
	player.add_weapon(w)
	# HUD
	hud = SurvivorHUD.new()
	hud.arena = self
	hud.player = player
	add_child(hud)
	player.set_joystick(hud.get_joystick())
	_start_wave()

func _process(delta: float) -> void:
	if not _running:
		return
	_cam.global_position = _cam.global_position.lerp(player.global_position, 8.0 * delta)
	# 刷怪(随波次加快/加量)
	_spawn_acc -= delta
	if _spawn_acc <= 0.0:
		var burst := 1 + int(wave / 3)
		for i in range(burst):
			_spawn_enemy()
		_spawn_acc = maxf(0.28, 1.15 - wave * 0.05)
	# 波次倒计时
	wave_clock -= delta
	if wave_clock <= 0.0:
		_end_wave()

func clamp_pos(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 22.0, ARENA_SIZE.x - 22.0), clampf(p.y, 22.0, ARENA_SIZE.y - 22.0))

# ---------------- 波次 ----------------
func _start_wave() -> void:
	wave_clock = wave_time
	_spawn_acc = 0.5

func _end_wave() -> void:
	_running = false
	get_tree().paused = true
	for e in _enemies.get_children():
		e.queue_free()
	hud.show_shop(SurvivorUpgrades.shop_offers(4, wave))

func start_next_wave() -> void:
	wave += 1
	wave_time = minf(40.0, wave_time + 1.5)
	get_tree().paused = false
	_running = true
	_start_wave()

# ---------------- 刷怪 / 掉落 ----------------
func _spawn_enemy() -> void:
	var e := SurvivorEnemy.new()
	e.setup(player, wave)
	var ang := randf() * TAU
	var pos := player.global_position + Vector2.RIGHT.rotated(ang) * randf_range(480.0, 620.0)
	e.global_position = clamp_pos(pos)
	e.died.connect(_on_enemy_died)
	_enemies.add_child(e)

func _on_enemy_died(e: SurvivorEnemy) -> void:
	kills += 1
	var p := SurvivorPickup.new()
	p.setup(player, e.material_value)
	p.position = e.global_position          # _pickups 在原点,局部=世界
	_pickups.add_child.call_deferred(p)     # 延迟挂载:避开物理 flush 期改 Area2D 状态

func collect(v: int) -> void:
	materials += v
	xp += v
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()

func _level_up() -> void:
	level += 1
	xp_to_next = int(xp_to_next * 1.35) + 3
	_running = false
	get_tree().paused = true
	hud.show_level_up(SurvivorUpgrades.roll(3))

func choose_upgrade(up: Dictionary) -> void:
	player.apply_upgrade(up)
	get_tree().paused = false
	_running = true

# ---------------- 商店 ----------------
func buy_offer(offer: Dictionary) -> bool:
	if materials < int(offer["price"]):
		return false
	materials -= int(offer["price"])
	if offer.get("kind", "stat") == "weapon":
		player.add_weapon(SurvivorWeapon.new())
	else:
		player.apply_upgrade(offer)
	return true

# ---------------- 投射物(武器调用) ----------------
func spawn_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, pierce: int, crit: bool) -> void:
	var b := SurvivorProjectile.new()
	b.global_position = pos
	b.vel = dir.normalized() * spd
	b.damage = dmg
	b.pierce = pierce
	b.crit = crit
	_shots.add_child(b)

# ---------------- 结束 / 重开 ----------------
func _on_player_died() -> void:
	_running = false
	get_tree().paused = true
	if Juice:
		Juice.shake(16.0)
	hud.show_game_over()

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ---------------- 灰盒地面 ----------------
func _layer() -> Node2D:
	var n := Node2D.new()
	add_child(n)
	return n

func _draw_ground() -> void:
	# 平铺草地贴图
	var g := Sprite2D.new()
	g.texture = preload("res://assets/survivor/ground.png")
	g.centered = false
	g.region_enabled = true
	g.region_rect = Rect2(0, 0, ARENA_SIZE.x, ARENA_SIZE.y)
	g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.modulate = Color(0.78, 0.82, 0.74)        # 压暗一点让角色更跳
	g.z_index = -100
	add_child(g)
	# 竞技场边界框
	var grid := _GridLines.new()
	grid.area = ARENA_SIZE
	grid.z_index = -99
	add_child(grid)


class _GridLines extends Node2D:
	var area := Vector2(1700, 1000)
	func _draw() -> void:
		# 竞技场暗色边界(草地外围)
		draw_rect(Rect2(Vector2.ZERO, area), Color(0.08, 0.10, 0.08, 0.9), false, 8.0)
		draw_rect(Rect2(Vector2.ZERO, area), Color(0.30, 0.35, 0.28, 0.8), false, 2.0)
