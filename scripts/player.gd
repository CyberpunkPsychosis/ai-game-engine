extends CharacterBody2D
## 横版动作角色控制器 —— 所有手感参数都暴露在 Inspector，可在游戏里按 F1 实时调。
## 已内置：可变跳跃高度、土狼时间(coyote time)、跳跃缓冲(jump buffer)、上升/下落分离重力。
## 已接入战斗框架：受击 -> 击退 + 顿帧 + 镜头震动 + 闪红（按 K 可自伤测试手感）。

@export_group("水平移动")
@export var max_speed: float = 320.0          ## 最大水平速度 (px/s)
@export var acceleration: float = 2600.0      ## 地面加速度
@export var friction: float = 2800.0          ## 地面摩擦(松手减速)
@export var air_acceleration: float = 1800.0  ## 空中操控力
@export var air_friction: float = 800.0       ## 空中阻力

@export_group("跳跃")
@export var jump_velocity: float = -700.0     ## 起跳初速度(负=向上)
@export var gravity: float = 2000.0           ## 上升重力
@export var fall_gravity_mult: float = 1.5    ## 下落重力倍率(>1 下落更快，手感更利落)
@export var jump_cut_mult: float = 0.45       ## 上升中松开跳跃键的速度截断(可变跳跃高度)
@export var max_fall_speed: float = 1200.0    ## 终端下落速度上限
@export var coyote_time: float = 0.10         ## 离开平台后仍可跳的宽限时间
@export var jump_buffer_time: float = 0.10    ## 落地前提前按跳的缓冲时间

var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0

@onready var _visual: ColorRect = $Visual
@onready var _camera: Camera2D = $Camera2D
@onready var _health: Health = $Health
@onready var _hurtbox: Hurtbox = $Hurtbox

func _ready() -> void:
	add_to_group("player")
	Juice.register_camera(_camera)
	if _health:
		_health.damaged.connect(_on_damaged)
		_health.died.connect(_on_died)
	if _hurtbox:
		_hurtbox.hit_by.connect(_on_hit_by)

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# --- 计时器：土狼时间 & 跳跃缓冲 ---
	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer = maxf(_buffer_timer - delta, 0.0)

	# --- 水平移动 ---
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.01:
		var accel := acceleration if on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
	else:
		var fric := friction if on_floor else air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	# --- 重力(上升/下落分离) ---
	if not on_floor:
		var g := gravity
		if velocity.y > 0.0:
			g *= fall_gravity_mult
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# --- 跳跃(缓冲 + 土狼) ---
	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_buffer_timer = 0.0
		_coyote_timer = 0.0

	# --- 可变跳跃高度：上升途中松开 -> 截断上升速度 ---
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# 调试：K 键自伤，用来测试打击感（顿帧/震动/闪红）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		if _health:
			_health.take_damage(10.0)

# --- 战斗反馈 ---
func _on_hit_by(hitbox: Hitbox) -> void:
	var dir := hitbox.knockback_dir_to(self)
	velocity.x = dir.x * hitbox.knockback
	velocity.y = -150.0
	Juice.hitstop(hitbox.hitstop)
	Juice.shake(hitbox.shake)

func _on_damaged(_amount: float, _source: Node) -> void:
	_flash()
	# 自伤测试时也给点反馈（hitbox 命中时已在 _on_hit_by 处理震动/顿帧）
	Juice.shake(7.0)

func _flash() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.0, 0.35, 0.35)
	var t := create_tween()
	t.tween_property(_visual, "modulate", Color.WHITE, 0.25)

func _on_died() -> void:
	# 占位：原地复活回起点（之后接入真正的死亡/重生流程）
	_health.current = _health.max_health
	_health.is_dead = false
	global_position = Vector2(200, 600)
	velocity = Vector2.ZERO
