extends Node2D
## 弹反训练场：主角 + 灰盒木桩 + 头顶血/架势条。
## 截图：godot --path . -- --shot=<abs>/shot.png --frames=40
## 逻辑自检：godot --headless --path . -- --probe

const PLAYER := preload("res://scenes/player.tscn")
const BAR := preload("res://scripts/status_bar.gd")

const GROUND_Y := 220.0

# 试玩(演示)模式：左右挡墙的有界场地 + 一个一个出怪
const ARENA_L := -340.0   # 左挡墙
const ARENA_R := 640.0    # 右挡墙
const PLAY_START := -180.0

var _shot_path := ""
var _shot_frames := 40
var _frame := 0
var _hold := ""
var _demo := false
var _force_touch := false
var _archer_only := false
var _spear_only := false
var _war_only := false
var _demon_only := false
var _boss_only := false
var _boss_show := false
var _playtest := false        # 试玩演示：有界场地 + 一个一个出怪(先弓骷髅)
var _wave := 0
var _wave_busy := false
var _demo_frames := 0
var _bot_block_tapped := false   # 演示bot：每次敌人出招只点一下格挡(=弹反，不是按住硬抗)
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
		elif a == "--speardemo":
			_demo = true
			_spear_only = true
		elif a == "--wardemo":
			_demo = true
			_war_only = true
		elif a == "--demondemo":
			_demo = true
			_demon_only = true
		elif a == "--boss":
			_boss_only = true
		elif a == "--bossdemo":
			_demo = true
			_boss_only = true
		elif a == "--bossshow":
			_boss_only = true     # 主角站桩锁血，纯看 boss 出招
			_boss_show = true
		elif a == "--touch":
			_force_touch = true   # 强制显示虚拟操作层（桌面预览用）
		elif a == "--playtest":
			_playtest = true

	# 网页/手机端默认走"试玩演示"模式：有界场地、一个一个出怪
	if not _demo and not _boss_only and _shot_path == "" and not ("--probe" in args):
		if _force_touch or _playtest or DisplayServer.is_touchscreen_available() or OS.has_feature("web"):
			_playtest = true

	_make_ground()
	if _playtest:
		_make_walls()                 # 左右挡墙：人和怪都掉不下去/跑不出场

	player = PLAYER.instantiate()
	player.position = Vector2(PLAY_START if _playtest else -40.0, GROUND_Y - 2)
	add_child(player)
	_attach_bar(player, 62.0)

	if _boss_only:
		enemy = _spawn_enemy(EliteFrost.new(), 240.0)   # 精英展示(冰霜守卫)
	elif _archer_only:
		player.facing = 1                              # 面向右边的弓箭手
		enemy = _spawn_enemy(SkelArcher.new(), 300.0)
	elif _spear_only:
		enemy = _spawn_enemy(SkelSpearman.new(), 200.0)
	elif _war_only:
		enemy = _spawn_enemy(SkelWarrior.new(), 220.0)
	elif _demon_only:
		enemy = _spawn_enemy(EliteDemon.new(), 240.0)
	elif _playtest:
		_spawn_wave()                  # 先出弓骷髅，打完自动换下一个
	else:
		enemy = _spawn_enemy(SkelWarrior.new(), 120.0) # enemy=第一个，给 probe 用
		_spawn_enemy(SkelSpearman.new(), 280.0)
		_spawn_enemy(SkelArcher.new(), 440.0)
	player.parried.connect(func(_a): _parry_count += 1)
	if _playtest:
		player.died.connect(_on_player_down)   # 主角倒了 → 稍后自动重开
	if _boss_show:
		player.invulnerable = true   # 主角锁血当沙包

	_cam = Camera2D.new()
	if _boss_show:
		_cam.position = Vector2(20.0, 150.0)    # 固定，框住 boss
		_cam.zoom = Vector2(1.8, 1.8)
	elif _archer_only:
		_cam.position = Vector2(130.0, 150.0)   # 跟"玩家+弓手"中点，看全追逐/后跃/箭的来回
		_cam.zoom = Vector2(1.5, 1.5)
	elif _playtest:
		_cam.position = Vector2(player.position.x + 130.0, 150.0)  # 带前瞻，框住右边来的怪
		_cam.zoom = Vector2(1.8, 1.8)           # 拉远些，开局就能看到来的怪
	else:
		_cam.position = Vector2(player.position.x, 150.0)
		_cam.zoom = Vector2(2.4, 2.4)
	add_child(_cam)
	_cam.make_current()
	Juice.register_camera(_cam)

	# 手机/网页：挂虚拟操作层（摇杆+四键）。演示/截图/看boss 模式默认不挂；--touch 可强制。
	var want_touch := _force_touch
	if not _demo and not _boss_show and _shot_path == "" and not ("--probe" in args):
		want_touch = want_touch or DisplayServer.is_touchscreen_available() or OS.has_feature("web")
	if want_touch:
		var cl := CanvasLayer.new()
		cl.layer = 100
		add_child(cl)
		cl.add_child(TouchControls.new())

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

# 试玩场地左右挡墙：玩家和怪都跑不出去/掉不下去
func _make_walls() -> void:
	for wx in [ARENA_L, ARENA_R]:
		var w := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(40, 420)
		cs.shape = r
		w.add_child(cs)
		w.position = Vector2(wx, GROUND_Y - 190)
		add_child(w)
		# 半透明立柱，给个边界提示
		var vis := ColorRect.new()
		vis.color = Color(0.30, 0.28, 0.40, 0.35)
		vis.size = Vector2(14, 200)
		vis.position = Vector2(-7, -20)
		w.add_child(vis)

# 一个一个出怪的顺序：弓骷髅(先) → 矛 → 剑 → 恶魔史莱姆 → 霜卫 → 循环
const WAVE_SEQ := ["archer", "spearman", "warrior", "demon", "frost"]

func _make_wave_enemy(kind: String) -> Enemy:
	match kind:
		"spearman": return SkelSpearman.new()
		"warrior":  return SkelWarrior.new()
		"demon":    return EliteDemon.new()
		"frost":    return EliteFrost.new()
		_:          return SkelArcher.new()

func _spawn_wave() -> void:
	var kind: String = WAVE_SEQ[_wave % WAVE_SEQ.size()]
	var e := _make_wave_enemy(kind)
	var x := clampf(player.global_position.x + 280.0, ARENA_L + 100.0, ARENA_R - 80.0)
	e.position = Vector2(x, GROUND_Y - 2)
	add_child(e)
	_attach_bar(e, 70.0)
	enemy = e
	_wave_busy = false
	e.died.connect(_on_enemy_down)

func _on_enemy_down() -> void:
	if _wave_busy:
		return
	_wave_busy = true
	var old := enemy
	await get_tree().create_timer(1.4).timeout    # 留点时间看死亡动作
	if is_instance_valid(old):
		old.queue_free()
	_wave += 1
	if is_instance_valid(player) and player.hp > 0.0:
		_spawn_wave()

func _on_player_down() -> void:
	await get_tree().create_timer(1.6).timeout    # 主角倒了 → 自动重开，方便连着演示
	get_tree().reload_current_scene()

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
		if arr != null and absf(arr.global_position.x - player.global_position.x) < 55.0:
			# 有箭飞来 → 站定接箭尖弹反
			_demo_set("move_left", false)
			_demo_set("move_right", false)
			_demo_set("block", true)        # 提前弹(箭快了)，接箭尖
			return
		_demo_set("block", false)
		# 没箭来 → 逼近弓手逼它后跃；但停在身位外(怪与怪不互相碰撞，贴太近会穿过去)
		var dx := enemy.global_position.x - player.global_position.x
		var approach := absf(dx) > 72.0
		_demo_set("move_right", approach and dx > 0.0)
		_demo_set("move_left", approach and dx < 0.0)
		return

	_demo_frames += 1
	var tgt := _nearest_enemy()
	if player == null or tgt == null or ((_war_only or _spear_only) and tgt.hp <= 0.0):
		print("DEMO parries=%d" % _parry_count)
		get_tree().quit()
		return
	if _demo_frames > (760 if (_spear_only or _war_only) else (1100 if _demon_only else 2400)):
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

	if not tgt.attacking:
		_bot_block_tapped = false      # 出招结束 → 下次再点一下
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
		elif _demon_only:
			do_dodge = true           # 演示恶魔：一直闪它，把它惹毛看生气连段
		elif fr >= maxi(1, tgt.attack_active_from - 1) and not _bot_block_tapped:
			do_parry = true           # 只点一下=弹反(按住会变成格挡硬抗)
			_bot_block_tapped = true
	elif dist > 56.0:
		go_right = dx > 0.0
		go_left = dx < 0.0
	elif _demo_frames % 90 < 3:
		do_attack = true

	_demo_set("move_left", go_left)
	_demo_set("move_right", go_right)
	_demo_set("attack", do_attack)
	_demo_set("block", do_parry)      # K = 弹反
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
	# 相机跟随：弓箭手 demo 框住"玩家+弓手"中点（追逐会跑动），其余跟玩家
	if _cam and is_instance_valid(player):
		if _archer_only and is_instance_valid(enemy):
			var mid := (player.global_position.x + enemy.global_position.x) * 0.5
			_cam.position.x = lerpf(_cam.position.x, mid, clampf(delta * 5.0, 0.0, 1.0))
		elif _playtest:
			# 朝朝向方向带点前瞻 → 正在打的怪不被右侧按钮挡住
			var tgt_x: float = player.global_position.x + 130.0 * float(player.facing)
			_cam.position.x = lerpf(_cam.position.x, tgt_x, clampf(delta * 4.0, 0.0, 1.0))
		elif not _archer_only:
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
