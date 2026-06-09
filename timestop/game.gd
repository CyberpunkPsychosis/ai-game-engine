extends Node2D
## 刹那 TimeStop —— 主场景 / 时间系统 / 导演 / 战斗结算 / 表现
##
## 统一时间架构(核心技术点):
##   每个实体每帧用  sdt = delta * scale_for(自身frozen_t)  推进。
##   scale_for() = 0(命中顿帧) / 0(单体冻结) / world_scale(全场定格时平滑→0)。
##   于是"冻一个 / 全场定格 / 命中顿帧 / 将来的慢镜处决"全是同一套底层。
##   玩家永远用真实 delta，所以时停时只有敌人/子弹凝固，你照常动。

const VW := 1280.0
const VH := 720.0
var GROUND := 1000.0              # 主地面顶 y(由房间数据填;玩家/敌人/Boss 仍读 game.GROUND)

const ENERGY_MAX := 100.0
const SINGLE_COST := 18.0
const SINGLE_DUR := 2.6
const FULL_DUR := 3.0

# 场景节点
var world: Node2D
var canvas_mod: CanvasModulate
var overlay_mat: ShaderMaterial
var player: TSPlayer
var enemies: Array = []
var bullets: Array = []
var boss = null                  # 悬龙 Boss(spawn_boss() 召唤;平时不召唤,不影响现有波次)

# 房间 / 关卡(阶段2:读 scenes/*.json)
var room_w := 2880.0
var room_h := 1080.0
var solids: Array[Rect2] = []    # 实体地形(AABB, world 坐标);玩家/敌人按它碰撞
var exits: Array = []            # 出口触发区 [{rect, to, entry}]
var benches: Array = []          # 长椅休息区 [Rect2]
var _spawn := Vector2(180, 940)  # 本房间出生点(掉坑回到这)
var cam: Camera2D
var current_room := "room_a"
var respawn_room := "room_a"     # 存档点房间(长椅设定)
var respawn_pos := Vector2(180, 940)
var endless := false             # false=房间模式(刷完即清);true=旧竞技场无限波
var _exit_lock := true           # 进房瞬间不触发出口, 直到玩家离开出口区一次
var _transitioning := false
var rested_t := 0.0              # 长椅"已休息"提示
var _fade: ColorRect
var _tile_ground: Texture2D       # 地形瓦片(AI 出, 神社街青冷石)
var _tile_top: Texture2D          # 顶面苔层
var decor_nodes: Array = []       # 房间装饰(鸟居/灯笼/草等), 换房清掉

# 时间状态
var world_scale := 1.0
var freeze_t := 0.0
var hitstop_t := 0.0
var flash := 0.0
var shake := 0.0

# 玩法状态
var energy := 50.0
var kills := 0
var wave := 0
var gameover := false
var bar_flash := 0.0

# 连击 / 打击反馈(死亡细胞手感)
var combo_step := 0          # 三段连击当前段(0/1/2)
var combo_t := 0.0           # 继续连击的时间窗(过期归零)
var atk_buf_t := 0.0         # 攻击输入缓冲(后摇中预按 → 出后摇自动接下一段)
var _dmgnums: Array = []     # 跳伤害数字 [{p,v,t,crit}]
var _dmg_font: Font          # 伤害数字字体(zpix 像素中文)
var _look := Vector2.ZERO    # 相机前瞻(朝移动方向多看一截)
const COMBO_WINDOW := 0.46

# 凝界氛围:半空悬停、永不下落的雨丝/尘(时间停了)。纯表现, 不参与玩法。
var _motes: Array = []
var _amb_t := 0.0

# 触屏输入(全屏面板统一接管, 手动命中判定;视觉由 TSTouchUI 圆形键绘制)
var touch_mode := false
var touch_panel: Control
var touch_ui: TSTouchUI
var joy_center := Vector2.ZERO
var joy_radius := 96.0           # 摇杆底盘半径(手指落在这范围内即抓摇杆)
var joy_vec := Vector2.ZERO
var joy_id := -999
var _jump_touch_id := -999       # 按住"跳"键的那根手指(变量跳:按住=高跳)
var btn_defs: Array = []         # 圆形动作键 [{act, center, radius, label, col, enabled}]
var _btn_flash: Dictionary = {}  # act → 剩余高亮时间(点按反馈)

# HUD 引用
var energy_bg: ColorRect
var energy_fill: ColorRect
var hp_fill: ColorRect
var info_label: Label
var center_label: Label

# ---------------------------------------------------------------- 时间系统
func scale_for(entity_frozen_t: float) -> float:
	if hitstop_t > 0.0:
		return 0.0
	if entity_frozen_t > 0.0:
		return 0.0
	return world_scale

# ---------------------------------------------------------------- 初始化
func _ready() -> void:
	randomize()
	_dmg_font = load("res://fonts/zpix.ttf")             # 伤害数字字体(缺失则跳字不画)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # draw_texture_rect 平铺需要
	_tile_ground = load("res://art/timestop/tiles/shrine_ground.png")
	_tile_top = load("res://art/timestop/tiles/shrine_top.png")
	world = Node2D.new()
	add_child(world)
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = Color.WHITE
	add_child(canvas_mod)
	player = TSPlayer.new()
	player.game = self
	player.z_index = 5               # 在背景装饰(z 1~2)之上, 又不挡前景
	world.add_child(player)
	_load_hero_sprites()
	_build_camera()
	_build_overlay()
	_build_hud()
	_build_fade()
	load_room(current_room, "")          # 填房间 + 落位玩家 + 刷怪 + 相机边界
	respawn_room = current_room
	respawn_pos = player.position

## 读 scenes/<id>.json 并应用为当前房间。entry=进入用的门名("" 用 spawn)。
func load_room(room_id: String, entry: String) -> void:
	var data := RoomLoader.load_data(room_id)
	if data.is_empty():
		push_error("[game] 房间加载失败: " + room_id)
		return
	_apply_room(room_id, data, entry)

func _apply_room(room_id: String, data: Dictionary, entry: String) -> void:
	current_room = room_id
	# 清旧房怪/弹
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for b in bullets:
		if is_instance_valid(b):
			b.queue_free()
	bullets.clear()
	for nd in decor_nodes:
		if is_instance_valid(nd):
			nd.queue_free()
	decor_nodes.clear()
	# 尺寸 / 地面
	var wd: Dictionary = data.get("world", {})
	room_w = float(wd.get("width", 2880))
	room_h = float(wd.get("height", 1080))
	GROUND = float(data.get("groundY", room_h - 80.0))
	# 实体地形
	solids.clear()
	for s in data.get("solids", []):
		solids.append(Rect2(float(s[0]), float(s[1]), float(s[2]), float(s[3])))
	# 出口
	exits = []
	for ex in data.get("exits", []):
		exits.append({
			"rect": Rect2(float(ex["x"]), float(ex["y"]), float(ex.get("w", 60)), float(ex.get("h", 180))),
			"to": String(ex.get("to", "")),
			"entry": String(ex.get("entry", "")),
		})
	# 长椅(以坐标为中心的休息区)
	benches = []
	for bc in data.get("benches", []):
		benches.append(Rect2(float(bc["x"]) - 36.0, GROUND - 90.0, 72.0, 96.0))
	# 出生点(掉坑回这)
	_spawn = _door_pos(data, "")
	# 玩家落位:指定门 → 否则 spawn
	player.position = _door_pos(data, entry)
	player.vx = 0.0
	player.vy = 0.0
	player.dodging = false
	# 相机:更新边界并立即吸附(避免跨房平移)
	if cam:
		cam.limit_right = int(room_w)
		cam.limit_bottom = int(room_h)
		cam.position = player.position
		cam.reset_smoothing()
	_gen_motes()
	# 刷本房怪
	for en in data.get("enemies", []):
		spawn_enemy_at(String(en.get("kind", "charger")), float(en["x"]), float(en["y"]))
	# 摆本房装饰(鸟居/灯笼/草...)
	for dc in data.get("decor", []):
		_spawn_decor(dc)
	_exit_lock = true

## 摆一个装饰:img=静态贴图(Sprite2D), anim=动画序列表(AnimatedSprite2D)。
## x,y=底部中心(贴地), z=层(负=玩家身后)。装饰在 world 里, 渲染于地形瓦片之上。
func _spawn_decor(dc: Dictionary) -> void:
	var x := float(dc.get("x", 0.0))
	var y := float(dc.get("y", GROUND))
	var z := int(dc.get("z", -1))
	if dc.has("anim"):
		var tex: Texture2D = load("res://art/timestop/decor/%s_sheet.png" % String(dc["anim"]))
		if tex == null:
			return
		var fw := int(dc.get("fw", 64))
		var sf := SpriteSheet.build_from_strips({"a": {"tex": tex, "fps": float(dc.get("fps", 8.0)), "loop": true}}, Vector2i(fw, tex.get_height()))
		var a := AnimatedSprite2D.new()
		a.sprite_frames = sf
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		a.position = Vector2(x, y - tex.get_height() * 0.5)
		a.z_index = z
		a.play("a")
		world.add_child(a)
		decor_nodes.append(a)
	else:
		var tex2: Texture2D = load("res://art/timestop/decor/%s.png" % String(dc.get("img", "")))
		if tex2 == null:
			return
		var spr := Sprite2D.new()
		spr.texture = tex2
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(x, y - tex2.get_height() * 0.5)
		spr.z_index = z
		world.add_child(spr)
		decor_nodes.append(spr)

## 取门坐标:entry 命中 doors 里的门则用之, 否则用 spawn。
func _door_pos(data: Dictionary, entry: String) -> Vector2:
	var doors: Dictionary = data.get("doors", {})
	if entry != "" and doors.has(entry):
		var d: Dictionary = doors[entry]
		return Vector2(float(d.get("x", 180)), float(d.get("y", 940)))
	var sp: Dictionary = data.get("spawn", {})
	return Vector2(float(sp.get("x", 180)), float(sp.get("y", GROUND - 44.0)))

func spawn_enemy_at(kind: String, x: float, y: float) -> void:
	var e := TSEnemy.new()
	e.game = self
	e.type = kind
	e.setup()
	e.position = Vector2(x, y)
	world.add_child(e)
	enemies.append(e)

## 出口/长椅检测(每帧, 非过场/非死亡时)
func _check_transitions(delta: float) -> void:
	var pp: Vector2 = player.position
	var in_exit := false
	for ex in exits:
		if (ex.rect as Rect2).has_point(pp):
			in_exit = true
			if not _exit_lock and String(ex.to) != "":
				_go_to_room(String(ex.to), String(ex.entry))
				return
	if not in_exit:
		_exit_lock = false
	# 长椅:站上去回血回能 + 设为存档点
	var on_bench := false
	for bz in benches:
		if (bz as Rect2).has_point(pp):
			on_bench = true
	if on_bench:
		respawn_room = current_room
		respawn_pos = pp
		player.hp = minf(player.maxhp, player.hp + 36.0 * delta)
		energy = minf(ENERGY_MAX, energy + 18.0 * delta)
		rested_t = 0.6
	else:
		rested_t = maxf(0.0, rested_t - delta)

func _go_to_room(room_id: String, entry: String) -> void:
	_transitioning = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.20)
	await t.finished
	load_room(room_id, entry)
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.20)
	await t2.finished
	_transitioning = false

## 死亡/重开:回最近存档点(长椅)所在房间, 满血。
func _restart() -> void:
	gameover = false
	kills = 0
	energy = 50.0
	load_room(respawn_room, "")
	player.hp = player.maxhp
	player.position = respawn_pos
	player.vx = 0.0
	player.vy = 0.0
	if cam:
		cam.position = player.position
		cam.reset_smoothing()

func _build_fade() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 70
	add_child(cl)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.05, 0.0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)

func _build_camera() -> void:
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 20.0   # 跟手(原 9 太慢, 画面追不上=像有惯性)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(room_w)
	cam.limit_bottom = int(room_h)
	world.add_child(cam)
	cam.make_current()

## AABB 对静态 solids 的轴分离碰撞解算。pos=中心, half=半尺寸, motion=本帧位移。
## 返回 {pos, floor, ceil, wall}。玩家/敌人共用,免各写一套地面判定。
func collide_move(pos: Vector2, half: Vector2, motion: Vector2) -> Dictionary:
	var on_floor := false
	var on_ceil := false
	var on_wall := false
	pos.x += motion.x
	for s in solids:
		if absf(pos.x - (s.position.x + s.size.x * 0.5)) < half.x + s.size.x * 0.5 \
		and absf(pos.y - (s.position.y + s.size.y * 0.5)) < half.y + s.size.y * 0.5:
			if motion.x > 0.0:
				pos.x = s.position.x - half.x
			elif motion.x < 0.0:
				pos.x = s.position.x + s.size.x + half.x
			on_wall = true
	pos.y += motion.y
	for s in solids:
		if absf(pos.x - (s.position.x + s.size.x * 0.5)) < half.x + s.size.x * 0.5 \
		and absf(pos.y - (s.position.y + s.size.y * 0.5)) < half.y + s.size.y * 0.5:
			if motion.y > 0.0:
				pos.y = s.position.y - half.y
				on_floor = true
			elif motion.y < 0.0:
				pos.y = s.position.y + s.size.y + half.y
				on_ceil = true
	return {"pos": pos, "floor": on_floor, "ceil": on_ceil, "wall": on_wall}

func _build_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	var rect := ColorRect.new()
	rect.size = Vector2(VW, VH)
	rect.position = Vector2.ZERO
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://timestop/postprocess.gdshader")
	rect.material = m
	overlay_mat = m
	cl.add_child(rect)

func _hud_rect(cl: CanvasLayer, col: Color, pos: Vector2, sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)
	return r

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 60
	add_child(cl)
	energy_bg = _hud_rect(cl, Color(0, 0, 0, 0.5), Vector2(16, 16), Vector2(260, 20))
	energy_fill = _hud_rect(cl, Color(0.36, 0.56, 0.8), Vector2(16, 16), Vector2(260, 20))
	_hud_rect(cl, Color(0, 0, 0, 0.5), Vector2(16, 42), Vector2(260, 14))
	hp_fill = _hud_rect(cl, Color(0.88, 0.39, 0.25), Vector2(16, 42), Vector2(260, 14))
	info_label = Label.new()
	info_label.position = Vector2(16, 60)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(info_label)
	center_label = Label.new()
	center_label.position = Vector2(VW * 0.5 - 160.0, 22)
	center_label.size = Vector2(320, 40)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 22)
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(center_label)
	_build_touch(cl)

## 圆形动作键(错落弧形排布, 贴合右手拇指, 大号)+ 圆形摇杆。视觉全由 TSTouchUI 画。
func _build_touch(cl: CanvasLayer) -> void:
	joy_center = Vector2(180.0, VH - 155.0)         # 摇杆底盘中心(左下)
	# act / 屏幕中心 / 半径 / 文字 / 颜色(冷暖按设定:砍=暖, 冻/定=亮蓝, 闪=青)
	# 错落弧形排布;每对圆心间距 > 半径和 + 余量, 互不重叠
	# (砍↔跳、再 定↔砍 换位后 → 砍在中上、跳在右下、定在中)
	btn_defs = [
		{"act": "atk",  "center": Vector2(VW - 270.0, VH - 120.0), "radius": 84.0, "label": "砍",  "col": Color(0.91, 0.47, 0.33), "enabled": true},
		{"act": "jump", "center": Vector2(VW - 90.0,  VH - 140.0), "radius": 84.0, "label": "跳",  "col": Color(0.58, 0.66, 0.78), "enabled": true},
		{"act": "dash", "center": Vector2(VW - 90.0,  VH - 320.0), "radius": 84.0, "label": "闪",  "col": Color(0.55, 0.86, 1.00), "enabled": true},
		{"act": "frz",  "center": Vector2(VW - 460.0, VH - 240.0), "radius": 84.0, "label": "冻",  "col": Color(0.36, 0.72, 0.96), "enabled": true},
		{"act": "full", "center": Vector2(VW - 270.0, VH - 310.0), "radius": 84.0, "label": "定",  "col": Color(0.28, 0.86, 1.00), "enabled": true},
	]
	# 触摸视觉层(圆形键 + 摇杆), 放在触摸面板之下, 只画不吃输入
	touch_ui = TSTouchUI.new()
	touch_ui.game = self
	touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(touch_ui)
	# 全屏触摸面板(最上层, 统一接管所有触摸/点击 → 手动命中判定)
	touch_panel = Control.new()
	touch_panel.position = Vector2.ZERO
	touch_panel.size = Vector2(VW, VH)
	touch_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(touch_panel)
	touch_panel.gui_input.connect(_on_touch)

func _on_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_press(event.index, event.position)
		else:
			_touch_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == joy_id:
			_joy_update(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			_touch_press(-1, event.position)
		else:
			_touch_release(-1)
	elif event is InputEventMouseMotion:
		if joy_id == -1:
			_joy_update(event.position)

func _touch_press(idx: int, pos: Vector2) -> void:
	touch_mode = true
	# 先判动作键(圆形, 按距离)
	for bd in btn_defs:
		if bool(bd.get("enabled", true)) and pos.distance_to(bd.center) <= float(bd.radius) + 6.0:
			if String(bd.act) == "jump":
				_jump_touch_id = idx          # 记住这根手指, 按住 = 高跳
			_do_action(String(bd.act))
			return
	# 否则:落在摇杆区域 → 抓摇杆(左半屏更宽容)
	if joy_id == -999 and (pos.distance_to(joy_center) < joy_radius or pos.x < VW * 0.42):
		joy_id = idx
		_joy_update(pos)

func _touch_release(idx: int) -> void:
	if idx == joy_id:
		joy_id = -999
		joy_vec = Vector2.ZERO
	if idx == _jump_touch_id:
		_jump_touch_id = -999            # 松开跳键 → 变量跳截断

func _joy_update(pos: Vector2) -> void:
	var d: Vector2 = (pos - joy_center).limit_length(82.0)
	joy_vec = d / 82.0

func _do_action(act: String) -> void:
	_btn_flash[act] = 0.16                          # 点按高亮反馈
	match act:
		"jump":
			player.want_jump = true
		"atk":
			do_attack()
		"frz":
			freeze_single(player.position, 360.0)
		"dash":
			do_dodge()
		"full":
			do_full_freeze()

func do_dodge() -> void:
	if gameover:
		return
	player.try_dodge()

# ---------------------------------------------------------------- 主循环
func _process(delta: float) -> void:
	_handle_keys()
	freeze_t = maxf(0.0, freeze_t - delta)
	hitstop_t = maxf(0.0, hitstop_t - delta)
	flash = maxf(0.0, flash - delta * 3.0)
	shake = maxf(0.0, shake - delta * 40.0)
	bar_flash = maxf(0.0, bar_flash - delta)
	_amb_t += delta
	for k in _btn_flash.keys():                      # 触摸键点按高亮衰减
		_btn_flash[k] = maxf(0.0, float(_btn_flash[k]) - delta)
	var target := 0.0 if freeze_t > 0.0 else 1.0
	world_scale = lerpf(world_scale, target, 1.0 - pow(0.0009, delta))   # 平滑刹停/恢复

	# 连击窗口 / 攻击输入缓冲 / 跳伤害数字
	combo_t = maxf(0.0, combo_t - delta)
	if combo_t <= 0.0:
		combo_step = 0
	atk_buf_t = maxf(0.0, atk_buf_t - delta)
	if atk_buf_t > 0.0 and player.atkcd <= 0.0 and not gameover:
		atk_buf_t = 0.0
		do_attack()
	for dn in _dmgnums:
		dn.t -= delta
		dn.p.y -= 36.0 * delta
	if _dmgnums.size() > 0:
		_dmgnums = _dmgnums.filter(func(x): return x.t > 0.0)

	if not gameover and not _transitioning:
		player.tick(delta)
		_combat()
		_check_transitions(delta)

	if cam:                              # 相机跟随玩家(房间内, limit 自动夹边), 前瞻+震屏走 offset
		cam.position = player.position
		var lx := 0.0
		if absf(player.vx) > 40.0:
			lx = float(player.facing) * 56.0   # 朝移动方向多看一截(死亡细胞前瞻)
		_look = _look.lerp(Vector2(lx, 0.0), 1.0 - pow(0.0025, delta))
		var sh := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
		cam.offset = _look + sh
	var cold := 1.0 - world_scale
	canvas_mod.color = Color.WHITE.lerp(Color(0.55, 0.62, 0.88), cold)
	overlay_mat.set_shader_parameter("freeze", cold)
	overlay_mat.set_shader_parameter("flash", flash)
	_update_hud()
	queue_redraw()

func _handle_keys() -> void:
	var mv := 0.0
	if Input.is_action_pressed("move_left"): mv -= 1.0
	if Input.is_action_pressed("move_right"): mv += 1.0
	if absf(joy_vec.x) > 0.15: mv = joy_vec.x
	player.move_dir = clampf(mv, -1.0, 1.0)
	player.want_down = Input.is_action_pressed("move_down") or joy_vec.y > 0.45     # 按下/下推摇杆=快速下落
	player.jump_held = Input.is_action_pressed("jump") or _jump_touch_id != -999  # 变量跳:按住跳更高
	if Input.is_action_just_pressed("jump"):
		player.want_jump = true
	if Input.is_action_just_pressed("attack"):
		do_attack()
	if Input.is_action_just_pressed("block"):                 # K = 冻单体(瞄准鼠标)
		freeze_single(_mouse_world(), 260.0)
	if Input.is_action_just_pressed("special"):               # L = 全场定格
		do_full_freeze()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		freeze_single(_mouse_world(), 260.0)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		do_dodge()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_restart()

func _mouse_world() -> Vector2:
	return world.to_local(get_global_mouse_position())

# ---------------------------------------------------------------- 战斗
func do_attack() -> void:
	if gameover:
		_restart()
		return
	# 后摇中再按 → 缓冲, 出后摇自动接下一段(攻击输入缓冲, 不吞输入)
	if player.atkcd > 0.0:
		atk_buf_t = 0.18
		return
	# 翻滚中砍 → 取消翻滚(滚 → 砍, 死亡细胞核心手感)
	if player.dodging:
		player.dodging = false
		player.dodge_t = 0.0
	if not touch_mode:
		player.facing = 1 if _mouse_world().x >= player.position.x else -1
	_auto_face()                                          # 近身微转向最近敌人(让"该中的砍中")
	# 三段连击:终结段(第3下)更重 —— 高伤/大击退/长顿帧/大震屏/更大判定
	var step := combo_step
	combo_step = (combo_step + 1) % 3
	combo_t = COMBO_WINDOW
	var finisher := step == 2
	var dmg := 20.0 if finisher else 11.0
	var reach := 40.0 if finisher else 34.0
	var box := 28.0 if finisher else 23.0
	var knock := 520.0 if finisher else 300.0
	var hs := 0.10 if finisher else 0.05
	var shk := 9.0 if finisher else 3.5
	player.atk_t = 0.14 if finisher else 0.11
	player.atkcd = 0.40 if finisher else 0.25
	player.atk_finisher = finisher
	var ax := player.position.x + player.facing * reach
	var ay := player.position.y
	var hit_any := false
	for e in enemies.duplicate():
		if absf(e.position.x - ax) < box + e.w * 0.5 and absf(e.position.y - ay) < box + e.h * 0.5:
			_hit_enemy(e, dmg, knock, hs, shk, finisher)
			hit_any = true
	for b in bullets:
		if not b.dead and absf(b.position.x - ax) < box + b.r and absf(b.position.y - ay) < box + b.r:
			b.dead = true
			spark(b.position, Color(1.0, 0.82, 0.35))
			hit_any = true
	if not hit_any:
		shake = maxf(shake, 1.5)                          # 挥空给一点点轻反馈

## 近身自动微转向最近敌人(死亡细胞:静默修正朝向, 让玩家"想砍的"砍中)
func _auto_face() -> void:
	var best = null
	var bd := 92.0
	for e in enemies:
		if e.frozen_t > 0.0:
			continue
		var ed: float = absf(e.position.x - player.position.x)
		if ed < bd and absf(e.position.y - player.position.y) < 60.0:
			bd = ed
			best = e
	if best != null and absf(best.position.x - player.position.x) > 6.0:
		player.facing = 1 if best.position.x > player.position.x else -1

func _hit_enemy(e, dmg: float, knock := 300.0, hs := 0.05, shk := 3.5, crit := false) -> void:
	var pos: Vector2 = e.position
	e.hp -= dmg
	e.stagger(player.facing, knock)   # 击退(按力度) + 打断它当前动作/扑击(hitstun, 无内置冷却→可压制)
	hitstop_t = maxf(hitstop_t, hs)   # 命中顿帧(轻/重不同 → 打击感)
	shake = maxf(shake, shk)          # 每下命中都震屏(原来只有挨打才震)
	add_energy(8.0)
	spark(pos, e.color)
	_pop_dmg(pos + Vector2(0.0, -e.h * 0.5 - 6.0), int(round(dmg)), crit)
	if e.hp <= 0.0:
		kills += 1
		add_energy(28.0)
		shake = maxf(shake, 12.0)
		hitstop_t = maxf(hitstop_t, 0.12)
		for i in 8:
			spark(pos, e.color)
		enemies.erase(e)
		e.queue_free()

## 跳一个伤害数字(白=普通, 金=终结/重击)
func _pop_dmg(p: Vector2, v: int, crit: bool) -> void:
	_dmgnums.append({ "p": p + Vector2(randf_range(-6.0, 6.0), 0.0), "v": v, "t": 0.7, "crit": crit })

func add_energy(v: float) -> void:
	energy = minf(ENERGY_MAX, energy + v)

func freeze_single(point: Vector2, range_px: float) -> void:
	if energy < SINGLE_COST:
		bar_flash = 0.35
		return
	var best = null
	var bd := range_px
	for e in enemies:
		var de: float = e.position.distance_to(point)
		if de < bd:
			bd = de
			best = e
	for b in bullets:
		if b.dead:
			continue
		var db: float = b.position.distance_to(point)
		if db < bd:
			bd = db
			best = b
	if best != null:
		energy -= SINGLE_COST
		best.frozen_t = SINGLE_DUR
		spark(best.position, Color(0.6, 0.85, 1.0))

func do_full_freeze() -> void:
	if gameover:
		return
	if energy < ENERGY_MAX:
		bar_flash = 0.35
		return
	energy = 0.0
	freeze_t = FULL_DUR
	flash = 1.0
	shake = 16.0

func _combat() -> void:
	var pp: Vector2 = player.position
	for e in enemies:
		var se := scale_for(e.frozen_t)
		# 扑影只在"扑杀(lunge)"那一下碰到才伤人 → 平时贴着也不掉血, 能躲能反击
		if se > 0.0 and e.type == "charger" and e.attacking:
			if absf(e.position.x - pp.x) < 24.0 + e.w * 0.5 and absf(e.position.y - pp.y) < 24.0 + e.h * 0.5:
				hurt_player(12.0, e.position.x)
	for b in bullets:
		if b.dead:
			continue
		var sb := scale_for(b.frozen_t)
		if sb > 0.0 and absf(b.position.x - pp.x) < 16.0 and absf(b.position.y - pp.y) < 24.0:
			b.dead = true
			hurt_player(8.0, b.position.x)
	for b in bullets:
		if b.dead:
			b.queue_free()
	bullets = bullets.filter(func(x): return not x.dead)
	if enemies.is_empty() and endless:
		spawn_wave()
	if player.hp <= 0.0:
		gameover = true

func hurt_player(d: float, from_x := NAN) -> void:
	if player.iframe > 0.0:
		return
	player.hp -= d
	player.iframe = 0.6
	shake = maxf(shake, 8.0)
	hitstop_t = maxf(hitstop_t, 0.06)         # 挨打也顿帧(收到打击的反馈)
	if not is_nan(from_x):                     # 被弹/被扑:朝远离来源方向击退+小跳(挨打有反应)
		var dir := 1.0 if player.position.x >= from_x else -1.0
		player.knock_vx = dir * 260.0
		player.knock_t = 0.12
		if player.vy > -120.0:
			player.vy = -200.0

# ---------------------------------------------------------------- 导演 / 生成
func spawn_wave() -> void:
	wave += 1
	var n := 2 + mini(3, wave)
	for i in n:
		var rr := randf()
		var t := "charger"
		if rr < 0.62:
			t = "charger"
		elif rr < 0.85:
			t = "shooter"
		else:
			t = "healer"
		# 在房间内、玩家两侧一定距离的实地上刷(避开断坑 1120~1440)
		var side := -1.0 if randf() < 0.5 else 1.0
		var x := player.position.x + side * randf_range(360.0, 760.0)
		x = clampf(x, 80.0, room_w - 80.0)
		if x > 1080.0 and x < 1480.0:
			x = 1560.0 if side > 0.0 else 1040.0
		spawn_enemy(t, x)

func spawn_enemy(t: String, x: float) -> void:
	var e := TSEnemy.new()
	e.game = self
	e.type = t
	e.setup()
	e.position = Vector2(x, GROUND - e.h * 0.5)   # 落在主地面上
	world.add_child(e)
	enemies.append(e)

## 主角精灵:AI 出图路线测试后仍需大量人工修,暂搁置 → 回退色块占位
## (player.gd 的 _draw() 自带方块+朝向标+闪避拖影)。后续改用现成素材时,在此
## 用 SpriteSheet 切出 SpriteFrames, 再 player.set_sprite_frames(sf, 帧高, player.h*0.5)。
## 备注:AI 流程(去影子→Seedance首=尾循环→洪水填充抠图→统一画框)在 git 历史里可找回。
func _load_hero_sprites() -> void:
	return

## 召唤悬龙 Boss(飞行残响)。其 _process 自动接时间系统(可被全场定格冻住)。
## 真龙立绘就位后:boss.set_texture(load("res://.../dragon.png"))。
func spawn_boss() -> void:
	if boss != null and is_instance_valid(boss):
		return
	boss = TSBoss.new()
	boss.game = self
	world.add_child(boss)

func spawn_bullet(from: Vector2, target: Vector2) -> void:
	var b := TSBullet.new()
	b.game = self
	b.position = from
	var ang := (target - from).angle()
	b.vel = Vector2(cos(ang), sin(ang)) * 240.0
	world.add_child(b)
	bullets.append(b)

func heal_allies(healer) -> void:
	for o in enemies:
		if o != healer and o.hp < o.maxhp:
			o.hp = minf(o.maxhp, o.hp + 4.0)
			spark(o.position, Color(0.6, 0.95, 0.7))

func spark(pos: Vector2, col: Color) -> void:
	for i in 5:
		var s := TSSpark.new()
		s.position = pos
		s.vel = Vector2(randf_range(-1.0, 1.0), randf_range(-1.4, -0.2)) * 220.0
		s.col = col
		world.add_child(s)

# ---------------------------------------------------------------- HUD
func _update_hud() -> void:
	energy_fill.size.x = 260.0 * clampf(energy / ENERGY_MAX, 0.0, 1.0)
	energy_fill.color = Color(0.56, 0.82, 1.0) if energy >= ENERGY_MAX else Color(0.36, 0.56, 0.8)
	energy_bg.color = Color(0.7, 0.25, 0.25, 0.7) if bar_flash > 0.0 else Color(0, 0, 0, 0.5)
	hp_fill.size.x = 260.0 * clampf(player.hp / player.maxhp, 0.0, 1.0)
	info_label.text = "KILL %d   %s" % [kills, current_room]
	for bd in btn_defs:                              # 能量不足时圆键变暗
		if bd.act == "frz":
			bd.enabled = energy >= SINGLE_COST
		elif bd.act == "full":
			bd.enabled = energy >= ENERGY_MAX
	if gameover:
		center_label.text = "DEAD - tap HIT / press R"
	elif rested_t > 0.0:
		center_label.text = "RESTED"
	elif freeze_t > 0.0:
		center_label.text = "TIME STOP %.1f" % freeze_t
	elif energy >= ENERGY_MAX:
		center_label.text = "FULL! tap STOP / press F"
	else:
		center_label.text = ""

# ---------------------------------------------------------------- 凝界氛围
## 半空悬停的雨丝/尘:位置固定(时间停了→不落), 只做微脉动闪烁。
func _gen_motes() -> void:
	_motes.clear()
	var n := int(room_w * room_h / 36000.0)        # 按房间面积铺密度
	for i in n:
		var streak := randf() < 0.4
		_motes.append({
			"p": Vector2(randf() * room_w, randf() * (room_h - 20.0)),
			"ph": randf() * TAU,
			"len": randf_range(5.0, 13.0) if streak else 0.0,
			"s": randf_range(0.7, 1.7),
		})

# ---------------------------------------------------------------- 房间渲染(world 坐标, 随相机滚动)
func _draw() -> void:
	draw_rect(Rect2(0, 0, room_w, room_h), Color(0.05, 0.066, 0.09))
	for x in range(0, int(room_w), 48):
		draw_line(Vector2(x, 0), Vector2(x, room_h), Color(0.082, 0.10, 0.13))
	# 凝界悬停粒子(冷白雨丝/尘, 定格时更亮更蓝, 强化"时间停了")
	var cold := 1.0 - world_scale
	for m in _motes:
		var tw: float = 0.5 + 0.5 * sin(_amb_t * 1.3 + m.ph)
		var base: Color = Color(0.62, 0.78, 0.92).lerp(Color(0.21, 0.88, 1.0), cold)
		base.a = clampf((0.10 + 0.15 * tw) * (1.0 + cold * 1.6), 0.0, 0.62)
		var p: Vector2 = m.p
		if m.len > 0.0:
			draw_line(p, p + Vector2(0.0, m.len), base, m.s)
		else:
			draw_rect(Rect2(p.x, p.y, m.s, m.s), base)
	# 实体地形:AI 瓦片(神社街青冷石)平铺 + 顶面苔层 + 顶边冷高亮(碰撞仍走 solids)
	for s in solids:
		if _tile_ground:
			draw_texture_rect(_tile_ground, s, true)
			if _tile_top:
				draw_texture_rect(_tile_top, Rect2(s.position.x, s.position.y, s.size.x, 12.0), true)
		else:
			draw_rect(s, Color(0.10, 0.14, 0.17))
		draw_line(s.position, s.position + Vector2(s.size.x, 0.0), Color(0.36, 0.7, 0.85, 0.6), 2.0)
	# 长椅(存档点:暖色, 站上去回血回能)
	for bz in benches:
		var r: Rect2 = bz
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 16.0, r.size.x, 12.0), Color(0.86, 0.55, 0.22))
		draw_rect(Rect2(r.position.x + 6.0, r.position.y + r.size.y - 40.0, 8.0, 26.0), Color(0.62, 0.40, 0.18))
		draw_rect(Rect2(r.position.x + r.size.x - 14.0, r.position.y + r.size.y - 40.0, 8.0, 26.0), Color(0.62, 0.40, 0.18))
	# 出口(通往相邻房间, 亮蓝门光)
	for e in exits:
		draw_rect(e.rect, Color(0.21, 0.78, 0.92, 0.16))
		var er: Rect2 = e.rect
		draw_rect(Rect2(er.position.x, er.position.y, 3.0, er.size.y), Color(0.36, 0.88, 1.0, 0.5))
		draw_rect(Rect2(er.position.x + er.size.x - 3.0, er.position.y, 3.0, er.size.y), Color(0.36, 0.88, 1.0, 0.5))
	# 跳伤害数字(白=普通, 金=终结/重击; 上飘淡出)
	if _dmg_font:
		for dn in _dmgnums:
			var a: float = clampf(dn.t / 0.7, 0.0, 1.0)
			var col: Color = Color(1.0, 0.84, 0.3, a) if dn.crit else Color(1.0, 1.0, 1.0, a)
			var sz: int = 26 if dn.crit else 19
			draw_string(_dmg_font, dn.p, str(dn.v), HORIZONTAL_ALIGNMENT_CENTER, -1, sz, col)
