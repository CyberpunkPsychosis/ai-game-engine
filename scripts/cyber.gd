extends CharacterBody2D
## 赛博忍者 —— 用 Ludo 生成的 16 帧奔跑做主角(走/跑/跳/落 + 突进斩)。
## 没有专门攻击帧，攻击=前冲+斩光特效(以后有攻击帧再升级)。

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
@export_group("战斗/显示")
@export var max_hp := 5
@export var attack_lunge := 360.0
@export var sprite_scale := 0.55

const BASE := "res://assets/char/cyber/"
var spr: AnimatedSprite2D
var _facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _atk_t := 0.0
var _struck := false
var _hp := 0
var _inv := 0.0
var spawn_point := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_hp = max_hp
	var man = JSON.parse_string(FileAccess.get_file_as_string(BASE + "anim.json"))
	var shape := RectangleShape2D.new()
	shape.size = Vector2(46, 104)
	var cs := CollisionShape2D.new(); cs.shape = shape; cs.position = Vector2(0, -52)
	add_child(cs)
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = _build_frames(man)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.scale = Vector2(sprite_scale, sprite_scale)
	spr.position = Vector2(0, (man["frame_h"] / 2.0 - man["foot_y"]) * sprite_scale)
	spr.play("idle")
	add_child(spr)

func _build_frames(man: Dictionary) -> SpriteFrames:
	var tex: Texture2D = load(BASE + man["sheet"])
	var fw := int(man["frame_w"]); var fh := int(man["frame_h"])
	var sf := SpriteFrames.new(); sf.remove_animation("default")
	for name in man["actions"]:
		var a = man["actions"][name]
		sf.add_animation(name)
		sf.set_animation_loop(name, a["loop"])
		sf.set_animation_speed(name, a["fps"])
		for idx in a["frames"]:
			var at := AtlasTexture.new(); at.atlas = tex
			at.region = Rect2(int(idx) * fw, 0, fw, fh)
			sf.add_frame(name, at)
	return sf

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_inv = maxf(_inv - delta, 0.0)
	_coyote = coyote if on_floor else maxf(_coyote - delta, 0.0)
	_atk_t = maxf(_atk_t - delta, 0.0)

	# 突进斩
	if Input.is_action_just_pressed("attack") and _atk_t <= 0.0:
		_atk_t = 0.28; _struck = false
		velocity.x = _facing * attack_lunge
		FX.sfx("slash"); Juice.shake(4.0)
	if _atk_t > 0.18 and not _struck:    # 出招稍后命中
		_struck = true
		_slash()

	# 水平移动(突进时不夺取控制,让前冲生效)
	var dir := Input.get_axis("move_left", "move_right")
	if _atk_t <= 0.0:
		if dir != 0.0:
			_facing = sign(dir)
			velocity.x = move_toward(velocity.x, dir * max_speed, (accel if on_floor else air_accel) * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# 跳
	if Input.is_action_just_pressed("jump"): _buffer = jump_buffer
	else: _buffer = maxf(_buffer - delta, 0.0)
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity; _buffer = 0.0; _coyote = 0.0; FX.sfx("jump")
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	velocity.y = minf(velocity.y + gravity * (fall_mult if velocity.y > 0 else 1.0) * delta, max_fall)
	move_and_slide()
	_contact_damage()

	# 动画
	if not on_floor: spr.play("jump" if velocity.y < 0 else "fall")
	elif absf(velocity.x) > 14.0: spr.play("run")
	else: spr.play("idle")
	spr.flip_h = _facing < 0

func _slash() -> void:
	var f := preload("res://scenes/hit_fx.tscn").instantiate()
	f.dir = _facing; f.position = Vector2(_facing * 90, -55); add_child(f)
	FX.screen_flash(Color(0.6, 1, 1), 0.05, 0.06); Juice.hitstop(0.05)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("hurt"): continue
		var to: Vector2 = e.global_position - global_position
		if absf(to.y) < 110 and to.x * _facing > -30 and absf(to.x) < 150:
			e.hurt(1, Vector2(_facing * 320, -260))

func _contact_damage() -> void:
	if _inv > 0.0: return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e): continue
		var to: Vector2 = e.global_position - global_position
		if absf(to.x) < 54 and to.y < 10 and to.y > -90:
			take_damage(1, e.global_position.x); return

func take_damage(amount: int, from_x: float) -> void:
	if _inv > 0.0: return
	_hp -= amount; _inv = 0.9
	FX.flash(spr); FX.sfx("hit"); Juice.shake(7.0); Juice.hitstop(0.06)
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(away * 320, -260)
	if _hp <= 0: respawn()

func respawn() -> void:
	_hp = max_hp; _inv = 1.0; velocity = Vector2.ZERO
	global_position = spawn_point
