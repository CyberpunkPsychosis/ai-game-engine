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
		spr.play("dash")
		return

	# —— 水平移动 ——
	var dir := Input.get_axis("move_left", "move_right")
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
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	# —— 重力 ——
	var g := gravity * (fall_mult if velocity.y > 0.0 else 1.0)
	velocity.y = min(velocity.y + g * delta, max_fall)

	move_and_slide()
	_update_anim(on_floor)

func _update_anim(on_floor: bool) -> void:
	if _dashing > 0.0:
		if spr.animation != "dash": spr.play("dash")
	elif not on_floor:
		if spr.animation != "jump": spr.play("jump")
	elif abs(velocity.x) > 12.0:
		if spr.animation != "walk": spr.play("walk")
	else:
		if spr.animation != "idle": spr.play("idle")
	spr.flip_h = _facing < 0

func bounce() -> void:
	velocity.y = bounce_velocity
	_dashes = 1
	_dashing = 0.0

func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	_dashing = 0.0
	_dashes = 1
