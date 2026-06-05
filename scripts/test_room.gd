extends Node2D
## 弹反训练场：主角 + 灰盒木桩 + 头顶血/架势条。
## 截图：godot --path . -- --shot=<abs>/shot.png --frames=40
## 逻辑自检：godot --headless --path . -- --probe

const PLAYER := preload("res://scenes/player.tscn")
const BAR := preload("res://scripts/status_bar.gd")

const GROUND_Y := 220.0

var _shot_path := ""
var _shot_frames := 40
var _frame := 0
var _hold := ""
var _demo := false
var _archer_only := false
var _boss_only := false
var _boss_show := false
var _demo_frames := 0
var _dead_count := 0
var _parry_count := 0
var player: Player
var enemy: Enemy
var _cam: Camera2D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.09, 0.09, 0.12))

	# 先解析参数（_archer_only 等会影响下面怎么出怪）
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frames = int(a.substr(9))
		elif a.begins_with("--hold="):
			_hold = a.substr(7)
		elif a == "--demo":
			_demo = true
		elif a == "--archerdemo":
			_demo = true
			_archer_only = true
		elif a == "--boss":
			_boss_only = true
		elif a == "--bossdemo":
			_demo = true
			_boss_only = true
		elif a == "--bossshow":
			_boss_only = true     # 主角站桩锁血，纯看 boss 出招
			_boss_show = true

	_make_ground()

	player = PLAYER.instantiate()
	player.position = Vector2(-40, GROUND_Y - 2)
	add_child(player)
	_attach_bar(player, 62.0)

	if _boss_only:
		enemy = _spawn_enemy(EliteFrost.new(), 240.0)   # 精英展示(冰霜守卫)
	elif _archer_only:
		player.facing = 1                              # 面向右边的弓箭手
		enemy = _spawn_enemy(SkelArcher.new(), 300.0)
	else:
		enemy = _spawn_enemy(SkelWarrior.new(), 120.0) # enemy=第一个，给 probe 用
		_spawn_enemy(SkelSpearman.new(), 280.0)
		_spawn_enemy(SkelArcher.new(), 440.0)
	player.parried.connect(func(_a): _parry_count += 1)
	if _boss_show:
		player.invulnerable = true   # 主角锁血当沙包

	_cam = Camera2D.new()
	if _boss_show:
		_cam.position = Vector2(20.0, 150.0)    # 固定，框住 boss
		_cam.zoom = Vector2(1.8, 1.8)
	elif _archer_only:
		_cam.position = Vector2(130.0, 150.0)   # 固定宽视角，看全箭的来回
		_cam.zoom = Vector2(1.9, 1.9)
	else:
		_cam.position = Vector2(player.position.x, 150.0)
		_cam.zoom = Vector2(2.4, 2.4)
	add_child(_cam)
	_cam.make_current()
	Juice.register_camera(_cam)

	if "--probe" in args:
		call_deferred("_run_probe")
	if "--pose" in args:
		call_deferred("_force_pose")

# 摆拍：把双方拉到交战距离，同时亮出攻击框，看刀有没有重叠
func _force_pose() -> void:
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	player.position = Vector2(-26, GROUND_Y - 2)
	enemy.position = Vector2(26, GROUND_Y - 2)
	player.facing = 1
	player.hit_active = true
	if player.sprite:
		player.sprite.play("attack")
	enemy.facing = -1
	enemy.hit_active = true
	if enemy.sprite:
		enemy.sprite.play("attack")
	# 在刀尖与敌刃相交处放 nova，确认圆心位置
	var tip := Vector2(enemy.global_position.x - (enemy.body_size.x * 0.5 + 4.0), player.global_position.y - player.body_size.y * 0.65)
	FX.nova(tip, 0.9)

func _make_ground() -> void:
	var ground := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 80)
	cs.shape = rect
	ground.add_child(cs)
	ground.position = Vector2(0, GROUND_Y + 40)
	add_child(ground)
	var vis := ColorRect.new()
	vis.color = Color(0.18, 0.17, 0.24)
	vis.size = Vector2(2000, 80)
	vis.position = Vector2(-1000, -40)
	ground.add_child(vis)

func _spawn_enemy(e: Enemy, x: float) -> Enemy:
	e.position = Vector2(x, GROUND_Y - 2)
	add_child(e)
	_attach_bar(e, 70.0)
	return e

func _attach_bar(a: Actor2D, y: float) -> void:
	var bar: StatusBar = BAR.new()
	bar.actor = a
	bar.position = Vector2(0, -y)
	a.add_child(bar)

func _physics_process(delta: float) -> void:
	if _demo:
		_demo_tick(delta)

# 演示 bot：自动走近 → 盯挥刀弹反 → 趁硬直/破防砍身体 → 处决
func _demo_set(action: String, want: bool) -> void:
	# 只在状态变化时按/松，保住 just_pressed 语义（弹反窗口靠它开启）
	if want and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not want and Input.is_action_pressed(action):
		Input.action_release(action)

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and is_instance_valid(e):
			var d: float = absf((e as Node2D).global_position.x - player.global_position.x)
			if d < bd:
				bd = d
				best = e
	return best

func _incoming_arrow() -> Node2D:
	for a in get_tree().get_nodes_in_group("arrow"):
		if a is Arrow and is_instance_valid(a):
			var ar := a as Arrow
			var to_player := player.global_position.x - ar.global_position.x
			if signf(ar._vel.x) == signf(to_player) and absf(to_player) < 130.0:
				return ar
	return null

func _demo_tick(_delta: float) -> void:
	# 弓箭手 1v1：站桩弹反飞来的箭 → 反弹回去
	if _archer_only:
		_demo_frames += 1
		if _demo_frames > 1500 or enemy == null or not is_instance_valid(enemy) or enemy.hp <= 0.0:
			print("DEMO parries=%d" % _parry_count)
			get_tree().quit()
			return
		var arr := _incoming_arrow()
		var parry_now := arr != null and absf(arr.global_position.x - player.global_position.x) < 42.0
		_demo_set("dash", parry_now)
		return

	_demo_frames += 1
	var tgt := _nearest_enemy()
	if player == null or tgt == null:
		print("DEMO parries=%d" % _parry_count)
		get_tree().quit()
		return
	if _demo_frames > 2400:
		print("DEMO parries=%d" % _parry_count)
		get_tree().quit()
		return

	var dx := tgt.global_position.x - player.global_position.x
	var dist := absf(dx)
	var go_left := false
	var go_right := false
	var do_attack := false
	var do_parry := false
	var do_dodge := false

	if tgt.guard_broken or tgt._flinch_t > 0.0:
		# 抓硬直/破防：贴近砍身体（处决）
		if dist > 50.0:
			go_right = dx > 0.0
			go_left = dx < 0.0
		else:
			do_attack = true
	elif tgt.attacking and tgt.sprite:
		# 按这一招的命中帧来掐时机（不同敌人前摇长短不同）
		var peril: bool = tgt._attack_hitbox != null and tgt._attack_hitbox.perilous
		var fr := tgt.sprite.frame
		if peril:
			if fr >= maxi(1, tgt.attack_active_from - 2):
				do_dodge = true       # 红光危 → 临近命中帧闪(i-frame 盖住)
		elif fr >= maxi(1, tgt.attack_active_from - 3):
			do_parry = true           # 普通 → 命中帧前点弹反(窗口 0.32 兜)
	elif dist > 56.0:
		go_right = dx > 0.0
		go_left = dx < 0.0
	elif _demo_frames % 90 < 3:
		do_attack = true

	_demo_set("move_left", go_left)
	_demo_set("move_right", go_right)
	_demo_set("attack", do_attack)
	_demo_set("dash", do_parry)      # K = 弹反
	_demo_set("special", do_dodge)   # L = 闪避

func _process(delta: float) -> void:
	# 主角站桩看 boss 出招：中途强制暴怒展示二阶段，到点退出
	if _boss_show:
		_demo_frames += 1
		player.invulnerable = true
		if _shot_path != "" and _demo_frames >= _shot_frames:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()
		if _demo_frames > 1560:
			get_tree().quit()
		return
	# 相机跟随玩家（水平）；弓箭手 demo 用固定宽视角
	if _cam and is_instance_valid(player) and not _archer_only:
		_cam.position.x = lerpf(_cam.position.x, player.global_position.x, clampf(delta * 6.0, 0.0, 1.0))
	if _shot_path == "":
		return
	if _hold != "":
		Input.action_press(_hold)
	_frame += 1
	if _frame >= _shot_frames:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		get_tree().quit()

# ----- 逻辑自检：弹反/闪避/中招/危 四种结算 -----
func _run_probe() -> void:
	var hb: Hitbox = enemy._attack_hitbox
	hb.damage = 10.0
	hb.posture_damage = 20.0
	hb.perilous = false

	# 1) 完美弹反：窗口内 → 玩家不掉血，敌人涨架势
	player._parry_timer = 0.2
	player.invulnerable = false
	var d0 := enemy.posture
	var h0 := player.hp
	player.on_hit(hb)
	var parry_ok := enemy.posture > d0 and is_equal_approx(player.hp, h0)

	# 2) 闪避无敌帧：玩家不掉血
	player._parry_timer = 0.0
	player.invulnerable = true
	var h1 := player.hp
	player.on_hit(hb)
	var dodge_ok := is_equal_approx(player.hp, h1)

	# 3) 中招：没弹反没无敌 → 掉血
	player._parry_timer = 0.0
	player.invulnerable = false
	var h2 := player.hp
	player.on_hit(hb)
	var hit_ok := player.hp < h2

	# 4) 危攻击：弹反也吃伤害
	player._parry_timer = 0.2
	player.invulnerable = false
	hb.perilous = true
	var h3 := player.hp
	player.on_hit(hb)
	var peril_ok := player.hp < h3

	# 5) 弹反箭矢 → 反弹成玩家方 + 伤害提高
	var arr := Arrow.new()
	arr.setup(Vector2.LEFT, 300.0)
	add_child(arr)
	player._parry_timer = 0.2
	player.invulnerable = false
	player.facing = 1
	player.on_hit(arr)
	var reflect_ok := arr.collision_layer == (1 << 2) and arr.damage > 10.0
	arr.queue_free()

	print("PROBE parry=%s dodge=%s hit=%s perilous=%s reflect=%s" % [parry_ok, dodge_ok, hit_ok, peril_ok, reflect_ok])
	get_tree().quit()
