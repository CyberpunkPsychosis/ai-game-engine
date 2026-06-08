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
const GROUND := 626.0

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

# 触屏输入
var touch_mode := false
var touch_jump := false
# 虚拟摇杆
var joy_area: Control
var joy_knob: ColorRect
var joy_vec := Vector2.ZERO
var joy_id := -1
var mouse_joy := false

# HUD 引用
var energy_bg: ColorRect
var energy_fill: ColorRect
var hp_fill: ColorRect
var info_label: Label
var center_label: Label
var btn_freeze: Button
var btn_full: Button

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
	world = Node2D.new()
	add_child(world)
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = Color.WHITE
	add_child(canvas_mod)
	player = TSPlayer.new()
	player.game = self
	player.position = Vector2(300.0, GROUND - 80.0)
	world.add_child(player)
	_build_overlay()
	_build_hud()
	spawn_wave()

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

func _mk_btn(cl: CanvasLayer, txt: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = Vector2(112, 112)
	b.custom_minimum_size = Vector2(112, 112)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	cl.add_child(b)
	return b

func _build_touch(cl: CanvasLayer) -> void:
	# 虚拟摇杆(左下)
	joy_area = Control.new()
	joy_area.position = Vector2(40, VH - 270)
	joy_area.size = Vector2(220, 220)
	joy_area.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(joy_area)
	var base := ColorRect.new()
	base.color = Color(1, 1, 1, 0.06)
	base.position = joy_area.position + Vector2(35, 35)
	base.size = Vector2(150, 150)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(base)
	joy_knob = ColorRect.new()
	joy_knob.color = Color(0.45, 0.78, 1.0, 0.45)
	joy_knob.size = Vector2(72, 72)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(joy_knob)
	_reset_knob()
	joy_area.gui_input.connect(_on_joy_input)
	# 动作按钮(右下 2x2)
	btn_freeze = _mk_btn(cl, "FRZ", Vector2(VW - 254, VH - 262))
	btn_full = _mk_btn(cl, "STOP", Vector2(VW - 124, VH - 262))
	var ba := _mk_btn(cl, "HIT", Vector2(VW - 254, VH - 132))
	var bj := _mk_btn(cl, "JUMP", Vector2(VW - 124, VH - 132))
	ba.button_down.connect(_on_atk)
	bj.button_down.connect(_on_jump)
	btn_freeze.button_down.connect(_on_frz)
	btn_full.button_down.connect(_on_full)

func _reset_knob() -> void:
	joy_knob.position = joy_area.position + Vector2(110, 110) - joy_knob.size * 0.5

func _on_joy_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var active := false
	if event is InputEventScreenTouch:
		if event.pressed:
			joy_id = event.index
			pos = event.position
			active = true
		elif event.index == joy_id:
			joy_id = -1
			joy_vec = Vector2.ZERO
			_reset_knob()
			return
	elif event is InputEventScreenDrag and event.index == joy_id:
		pos = event.position
		active = true
	elif event is InputEventMouseButton:
		if event.pressed:
			mouse_joy = true
			pos = event.position
			active = true
		else:
			mouse_joy = false
			joy_vec = Vector2.ZERO
			_reset_knob()
			return
	elif event is InputEventMouseMotion and mouse_joy:
		pos = event.position
		active = true
	if active:
		touch_mode = true
		var c := Vector2(110, 110)
		var d: Vector2 = (pos - c).limit_length(85.0)
		joy_vec = d / 85.0
		joy_knob.position = joy_area.position + c + d - joy_knob.size * 0.5

func _on_jump() -> void:
	touch_jump = true
	touch_mode = true
func _on_atk() -> void:
	touch_mode = true
	do_attack()
func _on_frz() -> void:
	touch_mode = true
	freeze_single(player.position, 360.0)
func _on_full() -> void:
	touch_mode = true
	do_full_freeze()

# ---------------------------------------------------------------- 主循环
func _process(delta: float) -> void:
	_handle_keys()
	freeze_t = maxf(0.0, freeze_t - delta)
	hitstop_t = maxf(0.0, hitstop_t - delta)
	flash = maxf(0.0, flash - delta * 3.0)
	shake = maxf(0.0, shake - delta * 40.0)
	bar_flash = maxf(0.0, bar_flash - delta)
	var target := 0.0 if freeze_t > 0.0 else 1.0
	world_scale = lerpf(world_scale, target, 1.0 - pow(0.0009, delta))   # 平滑刹停/恢复

	if not gameover:
		player.tick(delta)
		_combat()

	world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
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
	if Input.is_action_just_pressed("jump") or touch_jump:
		player.want_jump = true
	touch_jump = false
	if Input.is_action_just_pressed("attack"):
		do_attack()
	if Input.is_action_just_pressed("block"):                 # K = 冻单体(瞄准鼠标)
		freeze_single(_mouse_world(), 260.0)
	if Input.is_action_just_pressed("special"):               # L = 全场定格
		do_full_freeze()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		freeze_single(_mouse_world(), 260.0)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _mouse_world() -> Vector2:
	return world.to_local(get_global_mouse_position())

# ---------------------------------------------------------------- 战斗
func do_attack() -> void:
	if gameover:
		get_tree().reload_current_scene()
		return
	if player.atkcd > 0.0:
		return
	player.atk_t = 0.12
	player.atkcd = 0.32
	if not touch_mode:
		player.facing = 1 if _mouse_world().x >= player.position.x else -1
	var ax := player.position.x + player.facing * 34.0
	var ay := player.position.y
	for e in enemies.duplicate():
		if absf(e.position.x - ax) < 23.0 + e.w * 0.5 and absf(e.position.y - ay) < 23.0 + e.h * 0.5:
			_hit_enemy(e, 12.0)
	for b in bullets:
		if not b.dead and absf(b.position.x - ax) < 23.0 + b.r and absf(b.position.y - ay) < 23.0 + b.r:
			b.dead = true
			spark(b.position, Color(1.0, 0.82, 0.35))

func _hit_enemy(e, dmg: float) -> void:
	var pos: Vector2 = e.position
	e.hp -= dmg
	e.flash_t = 0.1
	e.stun_t = 0.3
	e.vx = player.facing * 300.0
	hitstop_t = maxf(hitstop_t, 0.05)
	add_energy(8.0)
	spark(pos, e.color)
	if e.hp <= 0.0:
		kills += 1
		add_energy(28.0)
		for i in 8:
			spark(pos, e.color)
		enemies.erase(e)
		e.queue_free()

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
		if se > 0.0 and e.stun_t <= 0.0 and e.type == "charger":
			if absf(e.position.x - pp.x) < 26.0 and absf(e.position.y - pp.y) < 42.0:
				hurt_player(12.0)
	for b in bullets:
		if b.dead:
			continue
		var sb := scale_for(b.frozen_t)
		if sb > 0.0 and absf(b.position.x - pp.x) < 16.0 and absf(b.position.y - pp.y) < 24.0:
			b.dead = true
			hurt_player(8.0)
	for b in bullets:
		if b.dead:
			b.queue_free()
	bullets = bullets.filter(func(x): return not x.dead)
	if enemies.is_empty():
		spawn_wave()
	if player.hp <= 0.0:
		gameover = true

func hurt_player(d: float) -> void:
	if player.iframe > 0.0:
		return
	player.hp -= d
	player.iframe = 0.6
	shake = maxf(shake, 8.0)

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
		var side := -1.0 if randf() < 0.5 else 1.0
		var x := (-40.0 - randf() * 160.0) if side < 0.0 else (VW + 40.0 + randf() * 160.0)
		spawn_enemy(t, x)

func spawn_enemy(t: String, x: float) -> void:
	var e := TSEnemy.new()
	e.game = self
	e.type = t
	e.setup()
	e.position = Vector2(x, GROUND - e.h * 0.5)
	world.add_child(e)
	enemies.append(e)

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
	info_label.text = "KILL %d   WAVE %d" % [kills, wave]
	if btn_freeze:
		btn_freeze.modulate.a = 1.0 if energy >= SINGLE_COST else 0.4
	if btn_full:
		btn_full.modulate.a = 1.0 if energy >= ENERGY_MAX else 0.4
	if gameover:
		center_label.text = "DEAD - tap HIT / press R"
	elif freeze_t > 0.0:
		center_label.text = "TIME STOP %.1f" % freeze_t
	elif energy >= ENERGY_MAX:
		center_label.text = "FULL! tap STOP / press F"
	else:
		center_label.text = ""

# ---------------------------------------------------------------- 背景
func _draw() -> void:
	draw_rect(Rect2(0, 0, VW, VH), Color(0.05, 0.066, 0.09))
	for x in range(0, int(VW), 48):
		draw_line(Vector2(x, 0), Vector2(x, VH), Color(0.082, 0.10, 0.13))
	draw_rect(Rect2(0, GROUND, VW, VH - GROUND), Color(0.10, 0.14, 0.17))
	draw_line(Vector2(0, GROUND), Vector2(VW, GROUND), Color(0.17, 0.23, 0.27), 2.0)
