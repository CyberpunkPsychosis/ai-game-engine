extends CharacterBody2D
## Martial Hero —— 主角控制器：idle/run/jump/fall + 平A连段(attack1→attack2) + 受击 + 死亡。
## 用真攻击帧驱动；命中帧才出伤害。手感参数 @export 可调。

@export_group("移动")
@export var max_speed := 300.0
@export var accel := 3000.0
@export var friction := 3400.0
@export var air_accel := 2200.0
@export_group("跳跃")
@export var jump_velocity := -720.0
@export var gravity := 2050.0
@export var fall_mult := 1.5
@export var jump_cut := 0.45
@export var max_fall := 1300.0
@export var coyote := 0.1
@export var jump_buffer := 0.1
@export_group("战斗")
@export var max_hp := 5
@export var attack_lunge := 160.0
@export_group("显示")
@export var sprite_scale := 1.4
@export var sprite_y := 10.0      # 脚底对齐微调

const BASE := "res://assets/char/hero/"
const ACTIVE := {"attack1": 2, "attack2": 2}   # 出伤害的帧
var spr: AnimatedSprite2D
var _state := "idle"
var _facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _atk_buffer := false
var _struck := false
var _hp := 0
var _inv := 0.0
var _hit_cd := 0.0
var spawn_point := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_hp = max_hp
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52, 96)
	var cs := CollisionShape2D.new(); cs.shape = shape; cs.position = Vector2(0, -48)
	add_child(cs)
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = _build_frames()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素风用最近邻
	spr.scale = Vector2(sprite_scale, sprite_scale)
	spr.position = Vector2(0, sprite_y - 100 * sprite_scale + 48)  # 帧中心->脚底(127)对齐碰撞底
	spr.play("idle")
	add_child(spr)
	spr.frame_changed.connect(_on_frame)
	spr.animation_finished.connect(_on_anim_done)

func _build_frames() -> SpriteFrames:
	var man = JSON.parse_string(FileAccess.get_file_as_string(BASE + "anim.json"))
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name in man["actions"]:
		var a = man["actions"][name]
		var tex: Texture2D = load(BASE + a["file"])
		sf.add_animation(name)
		sf.set_animation_loop(name, a["loop"])
		sf.set_animation_speed(name, a["fps"])
		for i in int(a["count"]):
			var at := AtlasTexture.new(); at.atlas = tex
			at.region = Rect2(i * 200, 0, 200, 200)
			sf.add_frame(name, at)
	return sf

func _set_state(s: String) -> void:
	if _state == s: return
	_state = s
	if spr.animation != s: spr.play(s)

func _locked() -> bool:
	return _state in ["attack1", "attack2", "hurt", "dead"]

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_inv = maxf(_inv - delta, 0.0)
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_coyote = coyote if on_floor else maxf(_coyote - delta, 0.0)

	if _state == "dead":
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.y = minf(velocity.y + gravity * delta, max_fall)
		move_and_slide(); return

	# 受击/攻击锁定：保留重力与惯性，不接受普通操控
	if _locked():
		if not on_floor: velocity.y = minf(velocity.y + gravity * delta, max_fall)
		else: velocity.x = move_toward(velocity.x, 0, friction * 1.5 * delta)
		move_and_slide()
		_contact_damage()
		return

	# —— 攻击输入 ——
	if Input.is_action_just_pressed("attack") and on_floor:
		_start_attack("attack1"); return

	# —— 移动 ——
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_facing = sign(dir)
		velocity.x = move_toward(velocity.x, dir * max_speed, (accel if on_floor else air_accel) * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# —— 跳 ——
	if Input.is_action_just_pressed("jump"): _buffer = jump_buffer
	else: _buffer = maxf(_buffer - delta, 0.0)
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity; _buffer = 0.0; _coyote = 0.0; FX.sfx("jump")
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	velocity.y = minf(velocity.y + gravity * (fall_mult if velocity.y > 0 else 1.0) * delta, max_fall)
	move_and_slide()
	_contact_damage()

	# —— 运动动画 ——
	if not on_floor:
		_set_state("jump" if velocity.y < 0 else "fall")
	elif absf(velocity.x) > 12.0:
		_set_state("run")
	else:
		_set_state("idle")
	spr.flip_h = _facing < 0

func _start_attack(which: String) -> void:
	_state = which; _struck = false; _atk_buffer = false
	spr.play(which)
	velocity.x = _facing * attack_lunge
	FX.sfx("slash")

func _on_frame() -> void:
	# 命中帧才出伤害
	if _state in ACTIVE and spr.frame == ACTIVE[_state] and not _struck:
		_struck = true
		_strike(_state)

func _on_anim_done() -> void:
	match _state:
		"attack1":
			if _atk_buffer: _start_attack("attack2")
			else: _state = "idle"
		"attack2":
			_state = "idle"
		"hurt":
			_state = "idle"
		"death":
			_respawn()

func _strike(kind: String) -> void:
	_spawn_hit(Vector2(_facing * 86, -48))
	FX.screen_flash(Color(1, 1, 1), 0.06, 0.06)
	Juice.hitstop(0.06); Juice.shake(5.0)
	var kb := Vector2(_facing * 320, -160) if kind == "attack1" else Vector2(_facing * 240, -480)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("hurt"): continue
		var to: Vector2 = e.global_position - global_position
		if absf(to.y) < 110 and to.x * _facing > -30 and absf(to.x) < 150:
			e.hurt(1, kb)

func _spawn_hit(offset: Vector2) -> void:
	var f := preload("res://scenes/hit_fx.tscn").instantiate()
	f.dir = _facing; f.position = offset
	add_child(f)

func _contact_damage() -> void:
	if _inv > 0.0 or _hit_cd > 0.0: return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e): continue
		var to: Vector2 = e.global_position - global_position
		if absf(to.x) < 56 and to.y < 10 and to.y > -90:
			take_damage(1, e.global_position.x)
			return

func take_damage(amount: int, from_x: float) -> void:
	if _inv > 0.0 or _state == "dead": return
	_hp -= amount
	_inv = 0.8; _hit_cd = 0.8
	FX.flash(spr); FX.sfx("hit")
	Juice.hitstop(0.06); Juice.shake(7.0)
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(away * 320, -260)
	if _hp <= 0:
		_state = "death"; spr.play("death")
	else:
		_state = "hurt"; spr.play("hurt")

func _respawn() -> void:
	_hp = max_hp; _inv = 1.0; _state = "idle"
	velocity = Vector2.ZERO
	global_position = spawn_point
	spr.play("idle")
