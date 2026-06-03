extends CharacterBody2D
## Viir —— 《苔光》主角：走 / 跳(土狼+缓冲+可变高度) / 空中冲刺 / 踩史莱姆弹起。
## 手感参数全部 @export，方便在游戏里实时调。

@export_group("移动")
@export var max_speed := 340.0
@export var accel := 3200.0
@export var friction := 3400.0
@export var air_accel := 2400.0

@export_group("跳跃")
@export var jump_velocity := -740.0
@export var gravity := 2100.0
@export var fall_mult := 1.55
@export var jump_cut := 0.45
@export var max_fall := 1300.0
@export var coyote := 0.10
@export var jump_buffer := 0.10

@export_group("冲刺")
@export var dash_speed := 920.0
@export var dash_time := 0.16
@export var dash_end_speed := 380.0
@export var bounce_velocity := -860.0

@export_group("果冻 Q弹")
@export var jelly_land := 0.42       ## 落地挤压量(越大越扁)
@export var jelly_jump := 0.30       ## 起跳拉伸量
@export var jelly_bounce := 0.55     ## 踩史莱姆弹起拉伸量
@export var jelly_dash := 0.30       ## 冲刺横向拉伸量
@export var jelly_stiffness := 240.0 ## 弹簧刚度(越大回弹越快)
@export var jelly_damping := 10.0    ## 阻尼(越小抖得越久=越Q)

@export_group("大招 · 孢爆")
@export var ult_cooldown := 2.5      ## 冷却(秒)
@export var ult_pop := -260.0        ## 放招时的上浮初速
@export var ult_jelly := 0.6         ## 放招的果冻拉伸量

const SPORE_BURST := preload("res://scenes/spore_burst.tscn")
const HIT_FX := preload("res://scenes/hit_fx.tscn")
var _ult_cd := 0.0

@export_group("连招")
@export var combo_window := 0.45     ## 接招窗口
@export var ground_lunge := 210.0    ## 地面挥击前冲
@export var launch_velocity := -820.0 ## 挑空初速
@export var air_hit_float := -220.0  ## 空中每击重新上浮(滞空连击)
@export var dive_speed := 1150.0     ## 俯冲下砸速度
@export var dive_bounce := -580.0    ## 砸地反弹
@export var air_hits_max := 3        ## 空中连击上限
var _combo := 0
var _combo_win := 0.0
var _atk := ""                       # "" / g / launch / air / dive
var _atk_lock := 0.0
var _air_hits := 0
var _ai_throttle := 0.0

const _BASE := 0.58
var _deform := 0.0       # >0 竖向拉长, <0 压扁变宽
var _deform_vel := 0.0
var _was_floor := false

var _coyote := 0.0
var _buffer := 0.0
var _dashes := 1
var _dashing := 0.0
var _dash_dir := Vector2.ZERO
var _facing := 1
var spawn_point := Vector2.ZERO

@onready var spr: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(46, 92)
	col.shape = shape
	spr.sprite_frames = _build_frames()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.scale = Vector2(0.58, 0.58)        # 256px 帧 -> ~148px 高
	spr.position = Vector2(0, -28)         # 让脚底对齐碰撞底
	spr.play("idle")

func _build_frames() -> SpriteFrames:
	var man = JSON.parse_string(FileAccess.get_file_as_string("res://assets/anim/manifest.json"))
	var by := {}
	for c in man["animations"]:
		by[c["name"]] = c
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var MAP := {"idle":"Wizard_Idle","walk":"Wizard_Walk","jump":"Wizard_Jump","dash":"Wizard_Dash2"}
	var LOOP := {"idle":true,"walk":true,"jump":false,"dash":false}
	for anim in MAP:
		var clip = by.get(MAP[anim])
		if clip == null: continue
		var tex: Texture2D = load("res://assets/anim/" + clip["file"])
		sf.add_animation(anim)
		sf.set_animation_loop(anim, LOOP[anim])
		sf.set_animation_speed(anim, clip["fps"])
		var fw := int(clip["fw"]); var fh := int(clip["fh"]); var cols := int(clip["cols"]); var cnt := int(clip["count"])
		for i in cnt:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
			sf.add_frame(anim, at)
	return sf

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote
		_dashes = 1
	else:
		_coyote = max(_coyote - delta, 0.0)

	# —— 果冻弹簧：每帧把形变弹回 0(欠阻尼 -> 回弹抖动) ——
	_deform_vel += (-jelly_stiffness * _deform - jelly_damping * _deform_vel) * delta
	_deform += _deform_vel * delta
	spr.scale = Vector2(_BASE * (1.0 - 0.6 * _deform), _BASE * (1.0 + _deform))
	if on_floor and not _was_floor:   # 刚落地 -> 啪地压扁
		_deform = -jelly_land
		_deform_vel = 0.0
	_was_floor = on_floor

	# —— 大招冷却 + 触发 ——
	_ult_cd = maxf(_ult_cd - delta, 0.0)
	if Input.is_action_just_pressed("special") and _ult_cd <= 0.0:
		_cast_ultimate()
		return

	# —— 冲刺进行中 ——
	if _dashing > 0.0:
		_dashing -= delta
		velocity = _dash_dir * dash_speed
		move_and_slide()
		if _dashing <= 0.0:
			velocity.x = sign(velocity.x) * min(abs(velocity.x), dash_end_speed)
			velocity.y *= 0.3
		_update_anim(on_floor)
		return

	# —— 冲刺触发 ——
	if Input.is_action_just_pressed("dash") and _dashes > 0:
		var ix := Input.get_axis("move_left", "move_right")
		_dash_dir = Vector2(ix if ix != 0.0 else _facing, 0).normalized()
		_dashes -= 1
		_dashing = dash_time
		velocity = _dash_dir * dash_speed
		_deform = -jelly_dash      # 横向拉伸(变宽变扁)
		spr.play("dash")
		_spawn_afterimage()
		FX.sfx("dash")
		return

	# —— 连招 ——
	_combo_win = maxf(_combo_win - delta, 0.0)
	_atk_lock = maxf(_atk_lock - delta, 0.0)
	if on_floor and _combo_win <= 0.0:
		_combo = 0
	if _atk == "dive" and on_floor:
		_dive_land()
	if Input.is_action_just_pressed("attack") and _atk_lock <= 0.0:
		if on_floor:
			_combo += 1
			if _combo >= 3: _launch()
			else: _ground_hit()
		elif Input.is_action_pressed("move_down"):
			_dive()
		elif _air_hits < air_hits_max:
			_air_hit()
		return

	# —— 水平移动(出招锁定时不接受普通操控，让前冲/滞空生效) ——
	var dir := Input.get_axis("move_left", "move_right")
	if _atk_lock <= 0.0:
		if dir != 0.0:
			_facing = sign(dir)
			var a := accel if on_floor else air_accel
			velocity.x = move_toward(velocity.x, dir * max_speed, a * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# —— 跳跃缓冲 ——
	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer
	else:
		_buffer = max(_buffer - delta, 0.0)
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_deform = jelly_jump       # 起跳竖向拉长
		FX.sfx("jump")
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	# —— 重力 / 俯冲 ——
	if _atk == "dive" and not on_floor:
		velocity.y = dive_speed
		_spawn_afterimage_throttled(delta)
		_strike("dive")
	else:
		var soft := 0.35 if (_atk == "air" and _atk_lock > 0.0) else (fall_mult if velocity.y > 0.0 else 1.0)
		velocity.y = min(velocity.y + gravity * soft * delta, max_fall)

	move_and_slide()
	_update_anim(on_floor)

func _update_anim(on_floor: bool) -> void:
	if _atk_lock > 0.0:
		spr.flip_h = _facing < 0
		return
	if _dashing > 0.0:
		if spr.animation != "dash": spr.play("dash")
	elif not on_floor:
		if spr.animation != "jump": spr.play("jump")
	elif abs(velocity.x) > 12.0:
		if spr.animation != "walk": spr.play("walk")
	else:
		if spr.animation != "idle": spr.play("idle")
	spr.flip_h = _facing < 0

func _cast_ultimate() -> void:
	_ult_cd = ult_cooldown
	_dashes = 1                          # 放招即刷新冲刺(连段起手)
	_dashing = 0.0
	_deform = ult_jelly
	velocity = Vector2(velocity.x * 0.2, ult_pop)
	spr.play("jump")
	var b := SPORE_BURST.instantiate()
	b.global_position = global_position
	get_parent().add_child(b)
	FX.sfx("cast")
	FX.screen_flash(Color(0.7, 1.0, 0.85), 0.3, 0.2)
	Juice.shake(12.0)
	Juice.hitstop(0.06)

# ============ 连招 ============
func _ground_hit() -> void:
	_atk = "g"; _atk_lock = 0.20; _combo_win = combo_window
	velocity.x = _facing * ground_lunge
	_deform = 0.16; spr.play("dash")
	_spawn_hit(Vector2(_facing * 72, -42))
	_strike("ground")
	FX.sfx("slash", 0.0, 1.0 + _combo * 0.06)
	Juice.hitstop(0.04); Juice.shake(4.0)

func _launch() -> void:
	_atk = "launch"; _atk_lock = 0.28; _combo = 0; _combo_win = 0.0
	velocity = Vector2(_facing * 150, launch_velocity)
	_dashes = 1; _air_hits = 0; _deform = 0.5; spr.play("jump")
	_spawn_hit(Vector2(_facing * 40, -96))
	_strike("launch")
	FX.sfx("slash", 0.0, 1.2)
	Juice.hitstop(0.07); Juice.shake(8.0)

func _air_hit() -> void:
	_atk = "air"; _atk_lock = 0.18; _air_hits += 1
	velocity.y = air_hit_float                 # 重新上浮制造滞空连击
	velocity.x = _facing * 130
	_deform = 0.24; spr.play("jump")
	_spawn_hit(Vector2(_facing * 74, -30))
	_strike("air")
	FX.sfx("slash", 0.0, 1.1 + _air_hits * 0.08)
	Juice.hitstop(0.04); Juice.shake(4.0)

func _strike(kind: String) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("hurt"): continue
		var to: Vector2 = e.global_position - global_position
		if kind == "dive":
			if to.y > -30.0 and to.y < 180.0 and absf(to.x) < 100.0:
				e.hurt(1, Vector2(_facing * 80.0, 560.0))
		elif absf(to.y) < 95.0 and to.x * _facing > -25.0 and absf(to.x) < 120.0:
			var kb := Vector2.ZERO
			match kind:
				"ground": kb = Vector2(_facing * 280.0, -140.0)
				"launch": kb = Vector2(_facing * 130.0, -740.0)
				"air":    kb = Vector2(_facing * 190.0, -320.0)
			e.hurt(1, kb)

func _dive() -> void:
	_atk = "dive"; _atk_lock = 0.6
	velocity = Vector2(_facing * 60, dive_speed)
	_deform = -0.3; spr.play("jump")
	Juice.shake(3.0)

func _dive_land() -> void:
	velocity.y = dive_bounce
	_atk = ""; _atk_lock = 0.0; _dashes = 1; _air_hits = 0; _deform = -0.55
	var b := SPORE_BURST.instantiate()
	b.global_position = global_position
	b.scale = Vector2(0.75, 0.75)
	get_parent().add_child(b)
	FX.sfx("slam")
	FX.screen_flash(Color(0.8, 1.0, 0.85), 0.22, 0.18)
	Juice.hitstop(0.09); Juice.shake(13.0)

func _spawn_hit(offset: Vector2) -> void:
	var f := HIT_FX.instantiate()
	f.dir = _facing
	f.position = offset
	add_child(f)

func _spawn_afterimage_throttled(delta: float) -> void:
	_ai_throttle -= delta
	if _ai_throttle <= 0.0:
		_spawn_afterimage(); _ai_throttle = 0.035

func _spawn_afterimage() -> void:
	if spr.sprite_frames == null: return
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null: return
	var a := Sprite2D.new()
	a.set_script(load("res://scripts/after_image.gd"))
	get_parent().add_child(a)
	a.setup(tex, spr.global_position, spr.scale, spr.flip_h)

func ult_ratio() -> float:
	return clampf(1.0 - _ult_cd / ult_cooldown, 0.0, 1.0)

func bounce() -> void:
	velocity.y = bounce_velocity
	_dashes = 1
	_dashing = 0.0
	_deform = jelly_bounce     # 弹起大幅拉长

func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	_dashing = 0.0
	_dashes = 1
