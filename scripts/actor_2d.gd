extends CharacterBody2D
class_name Actor2D
## 通用 2D 横版动作角色控制器（主角 / 敌人 / Boss 共用骨架）。
##
## 逻辑与「具体角色 / 素材 / 控制方式」解耦：
##  - 手感参数全在 @export。
##  - 移动「意图」由子类每帧通过 _gather_intent() 填写（玩家读 Input；敌人走 AI）。
##  - 动画用可配置动画名驱动，缺帧自动回退。SpriteFrames 由子类在 _setup() 提供。
##  - 战斗：自带 血量(hp) + 架势(posture) + 格挡/完美弹反 + 受击结算(on_hit)。
##    Hurtbox/AttackHitbox 在代码里按 team 建好，免手搓场景。
##
## 防御哲学（恶魔城美术 + Sekiro 弹反）：稳重不翻滚，防御=弹反。

signal attack_started
signal parried(attacker: Node)        ## 完美弹反成功（弹开了 attacker）
signal dodge_started
signal took_hit(amount: float)
signal posture_changed(cur: float, max: float)
signal guard_break                    ## 架势被打满=破防硬直（可被处决）
signal hp_changed(cur: float, max: float)
signal died

@export_group("阵营")
@export var team := 0                  ## 0=玩家方  1=敌方（决定攻击框/受击框配对）

@export_group("手感 · 移动")
@export var speed := 200.0
@export var accel := 1800.0
@export var friction := 2200.0
@export_group("手感 · 跳跃")
@export var jump_velocity := -430.0
@export var gravity_up := 1300.0
@export var gravity_down := 1800.0
@export var jump_cut := 0.45
@export var coyote_time := 0.10
@export var jump_buffer := 0.10

@export_group("战斗 · 数值")
@export var max_hp := 100.0
@export var posture_max := 100.0
@export var posture_regen := 26.0     ## 每秒架势回复
@export var posture_regen_delay := 0.9 ## 多久没受击/格挡后开始回复
@export var stagger_time := 1.8        ## 破防硬直时长（处决窗口）

@export_group("战斗 · 弹反")
@export var can_parry := false         ## 是否能弹反（玩家开）
@export var parry_window := 0.18       ## 按下弹反后多少秒内算「完美弹反」
@export var parry_posture_to_attacker := 34.0  ## 完美弹反给对方加的架势
@export var parry_flinch := 0.35       ## 被弹反者的硬直时长（打断出招+击退）
@export_group("战斗 · 闪避")
@export var can_dodge := false         ## 是否能闪避
@export var dodge_speed := 460.0
@export var dodge_time := 0.22         ## 闪避持续（无敌帧）
@export var dodge_cooldown := 0.45

@export_group("战斗 · 攻击框")
@export var attack_damage := 12.0
@export var attack_posture := 16.0
@export var attack_reach := 26.0       ## 攻击框相对身体的前伸距离
@export var attack_size := Vector2(34, 36)
@export var attack_active_from := 1    ## 命中帧起（攻击动画第几帧开始判定）
@export var attack_active_to := 2      ## 命中帧止
@export var execute_multiplier := 6.0  ## 对破防目标的处决倍率

@export_group("动画名（缺帧自动回退）")
@export var anim_idle := "idle"
@export var anim_run := "run"
@export var anim_jump := "jump"
@export var anim_fall := "fall"
@export var anim_attack := "attack"
@export var anim_dodge := "dodge"
@export var anim_hurt := "hurt"
@export var anim_death := "death"
@export var sprite_path: NodePath = ^"Sprite"
@export var sprite_faces_left := false   ## 素材默认朝向：false=朝右(多数)，true=朝左
@export var body_size := Vector2(18, 48)  ## 受击/碰撞体大致尺寸（建受击框用）

# --- 意图 ---
var move_dir := 0.0
var want_jump := false
var want_jump_release := false
var want_attack := false
var want_parry := false               ## 本帧刚按下弹反（开启弹反窗口）
var want_dodge := false               ## 本帧刚按下闪避

# --- 对外可读状态 ---
var facing := 1
var attacking := false
var dodging := false
var invulnerable := false             ## 无敌帧（闪避中开启）
var guard_broken := false
var hp := 100.0
var posture := 0.0
var hit_active := false               ## 当前攻击是否处于命中帧

var sprite: AnimatedSprite2D
var _coyote := 0.0
var _buffer := 0.0
var _parry_timer := 0.0
var _posture_delay := 0.0
var _stagger_t := 0.0
var _flinch_t := 0.0
var _parry_pose_t := 0.0   # 弹反瞬间亮出持刀姿势的时长
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := 1
var _attack_hitbox: Hitbox
var _attack_shape: RectangleShape2D
var _hurtbox: Hurtbox
var _hurt_cs: CollisionShape2D
var _hurt_rect: RectangleShape2D
var lock_hp := false            ## 锁血：受击有反馈但不掉血（测试用）
var hurt_dx := 0.0              ## 受击框水平偏移（对齐身体用，可在调参工具拖）
var current_attack_anim := ""   # 当前这一刀用的动画名（用于判断收招）
var _dbg := false   # 调试：画攻击/受击框（--boxes 开启）

# 碰撞层位：3=玩家攻击 4=敌人攻击
const L_PLAYER_HIT := 1 << 2
const L_ENEMY_HIT := 1 << 3

func _ready() -> void:
	collision_layer = 1 << 1   # 角色身体在层2：彼此互不推挤
	collision_mask = 1         # 只和世界(地面,层1)碰
	_dbg = "--boxes" in OS.get_cmdline_user_args()
	sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not sprite.animation_finished.is_connected(_on_anim_finished):
		sprite.animation_finished.connect(_on_anim_finished)
	_setup()                  # 先让子类配置 team / body_size / 攻击数值 / max_hp
	_align_feet()             # 自动对齐脚底(扫 idle 帧最低不透明像素)，免手调 offset
	hp = max_hp
	_build_combat_boxes()     # 再按这些建攻击/受击框
	_ensure_body_collision()  # 没有物理碰撞体就补一个（代码生成的角色用）
	if sprite and sprite.sprite_frames:
		sprite.play(anim_idle)
	hp_changed.emit(hp, max_hp)
	posture_changed.emit(posture, posture_max)

## 子类重写：建 SpriteFrames、加分组等。
func _setup() -> void:
	pass

## 自动对齐脚底：扫 idle 第一帧最底部不透明像素行 → 设 sprite.offset.y 让脚落在原点。
## 任何素材通用，不用再逐角色手调 offset。
func _align_feet() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var sf := sprite.sprite_frames
	var anim := anim_idle
	if not sf.has_animation(anim):
		var names := sf.get_animation_names()
		if names.is_empty():
			return
		anim = names[0]
	if sf.get_frame_count(anim) == 0:
		return
	var tex := sf.get_frame_texture(anim, 0)
	if tex == null:
		return
	var img: Image
	var ox := 0
	var oy := 0
	var fw := 0
	var fh := 0
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		if at.atlas == null:
			return
		img = at.atlas.get_image()
		ox = int(at.region.position.x)
		oy = int(at.region.position.y)
		fw = int(at.region.size.x)
		fh = int(at.region.size.y)
	else:
		img = tex.get_image()
		fw = img.get_width()
		fh = img.get_height()
	if img == null:
		return
	var feet := -1
	for y in range(fh - 1, -1, -1):
		var op := false
		for x in range(fw):
			if img.get_pixel(ox + x, oy + y).a > 0.15:
				op = true
				break
		if op:
			feet = y
			break
	if feet < 0:
		return
	sprite.offset.y = float(fh) * 0.5 - float(feet) - 1.0

## 子类重写：填写本帧意图。
func _gather_intent(_delta: float) -> void:
	pass

# ---------------------------------------------------------------- 战斗框
## 没有物理碰撞体就按 body_size 补一个（代码生成的角色，如木桩）。
func _ensure_body_collision() -> void:
	for c in get_children():
		if c is CollisionShape2D:
			return
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = body_size
	cs.shape = r
	cs.position = Vector2(0, -body_size.y * 0.5)
	add_child(cs)

func _build_combat_boxes() -> void:
	var my_hit := L_PLAYER_HIT if team == 0 else L_ENEMY_HIT
	var their_hit := L_ENEMY_HIT if team == 0 else L_PLAYER_HIT

	# 受击框：监听对方攻击框
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = their_hit
	_hurtbox.monitorable = false
	_hurt_cs = CollisionShape2D.new()
	_hurt_rect = RectangleShape2D.new()
	_hurt_rect.size = body_size
	_hurt_cs.shape = _hurt_rect
	_hurt_cs.position = Vector2(hurt_dx, -body_size.y * 0.5)
	_hurtbox.add_child(_hurt_cs)
	add_child(_hurtbox)

	# 攻击框：自己的攻击层，默认关闭（命中帧才开）
	_attack_hitbox = Hitbox.new()
	_attack_hitbox.collision_layer = my_hit
	_attack_hitbox.collision_mask = 0
	_attack_hitbox.monitoring = false
	_attack_hitbox.monitorable = false
	_attack_hitbox.damage = attack_damage
	_attack_hitbox.posture_damage = attack_posture
	var acs := CollisionShape2D.new()
	_attack_shape = RectangleShape2D.new()
	_attack_shape.size = attack_size
	acs.shape = _attack_shape
	_attack_hitbox.add_child(acs)
	add_child(_attack_hitbox)

## 实时调整受击框（调参工具用）：宽 / 高 / 水平偏移
func set_hurt(w: float, h: float, dx: float) -> void:
	body_size = Vector2(w, h)
	hurt_dx = dx
	if _hurt_rect:
		_hurt_rect.size = body_size
	if _hurt_cs:
		_hurt_cs.position = Vector2(hurt_dx, -body_size.y * 0.5)
	queue_redraw()

## 受击框三个可调项（每个角色都有；调参工具统一加这一组）
func body_tunables() -> Array:
	return [
		{"name": "_hw", "label": "受击框宽", "min": 8.0,  "max": 90.0, "step": 1.0},
		{"name": "_hh", "label": "受击框高", "min": 20.0, "max": 120.0, "step": 1.0},
		{"name": "_hdx","label": "受击框横移","min": -40.0,"max": 40.0, "step": 1.0},
	]

# 给调参工具用的标量读写（body_size 是 Vector2，拆成可拖的标量）
var _hw: float:
	get: return body_size.x
	set(v): set_hurt(v, body_size.y, hurt_dx)
var _hh: float:
	get: return body_size.y
	set(v): set_hurt(body_size.x, v, hurt_dx)
var _hdx: float:
	get: return hurt_dx
	set(v): set_hurt(body_size.x, body_size.y, v)

# ---------------------------------------------------------------- 主循环
func _physics_process(delta: float) -> void:
	# 破防硬直：不能行动，等待
	if guard_broken:
		_stagger_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y += gravity_down * delta
		move_and_slide()
		if _stagger_t <= 0.0:
			_recover_from_break()
		return

	# 被弹反硬直：不能行动，被击退后僵一下（给对方打身体的空档）
	if _flinch_t > 0.0:
		_flinch_t -= delta
		if not is_on_floor():
			velocity.y += gravity_down * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		return

	move_dir = 0.0
	want_jump = false
	want_jump_release = false
	want_attack = false
	want_parry = false
	want_dodge = false
	_gather_intent(delta)

	# 计时器
	_parry_timer = maxf(_parry_timer - delta, 0.0)
	_posture_delay = maxf(_posture_delay - delta, 0.0)
	_parry_pose_t = maxf(_parry_pose_t - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	if _posture_delay <= 0.0 and posture > 0.0:
		_set_posture(posture - posture_regen * delta)

	# 弹反（点一下：开窗口 + 亮持刀迎击姿势，无常驻格挡）
	if can_parry and want_parry and is_on_floor() and not attacking and not dodging:
		_parry_timer = parry_window
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_attack):
			sprite.play(anim_attack)
			_parry_pose_t = parry_window

	# 闪避（仅地面，带无敌帧）
	if can_dodge and want_dodge and is_on_floor() and _dodge_cd <= 0.0 and not dodging and not attacking:
		_start_dodge()

	# 重力
	if not is_on_floor():
		velocity.y += (gravity_up if velocity.y < 0.0 else gravity_down) * delta
		_coyote -= delta
	else:
		_coyote = coyote_time

	# 跳跃缓冲（攻击/格挡中不能跳）
	if want_jump:
		_buffer = jump_buffer
	else:
		_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0 and not attacking and not dodging:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
	if want_jump_release and velocity.y < 0.0:
		velocity.y *= jump_cut

	# 攻击（闪避中不可）
	if want_attack and not attacking and not dodging:
		_begin_attack(anim_attack)

	# 水平移动
	if dodging:
		_dodge_t -= delta
		velocity.x = float(_dodge_dir) * dodge_speed
		if _dodge_t <= 0.0:
			_end_dodge()
	elif attacking and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)  # 地面攻击定身
	elif move_dir != 0.0:
		velocity.x = move_toward(velocity.x, move_dir * speed, accel * delta)
		facing = 1 if move_dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if sprite:
		sprite.flip_h = (facing < 0) != sprite_faces_left

	# 受击框随朝向镜像（身体偏后/偏前，翻面要跟着翻）
	if _hurt_cs:
		_hurt_cs.position.x = hurt_dx * float(facing)

	# 攻击命中帧 → 开关攻击框（位置/尺寸按当前这一刀动态变）
	hit_active = _compute_hit_active()
	if _attack_hitbox:
		_attack_hitbox.position = Vector2(facing * attack_reach, -body_size.y * 0.5)
		_attack_shape.size = attack_size
		_attack_hitbox.monitorable = hit_active

	move_and_slide()
	_update_anim()

## 攻击命中帧判定（子类可重写自定义时间线）。
func _compute_hit_active() -> bool:
	if not attacking or sprite == null:
		return false
	return sprite.frame >= attack_active_from and sprite.frame <= attack_active_to

# ---------------------------------------------------------------- 受击结算
## 被对方 Hitbox 命中时调用（Hurtbox 委托）。返回 true=已自行处理(不再走默认扣血)。
func on_hit(hitbox: Hitbox) -> bool:
	if invulnerable or guard_broken:
		# 破防时被打 → 处决（大伤害）
		if guard_broken:
			_take_hp(hitbox.damage * execute_multiplier)
		return true

	var attacker := _owner_actor_of(hitbox)
	var contact := global_position + Vector2(0, -body_size.y * 0.5)

	# 危攻击：不可弹/不可挡，硬吃（除非无敌帧）
	if hitbox.perilous:
		_take_hp(hitbox.damage)
		_add_posture(hitbox.posture_damage * 1.4)
		_hit_feedback(hitbox, contact, Color(1, 0.3, 0.2))
		return true

	# 完美弹反（弹反窗口内）
	if _parry_timer > 0.0:
		_parry_timer = 0.0
		_add_posture(-12.0)  # 弹反减自己一点架势=奖励
		# 火花画在「刀尖与敌刃相交处」= 敌人靠我这侧的边缘、刀刃高度
		var clash_y := global_position.y - body_size.y * 0.65
		var clash: Vector2
		if attacker:
			var adir := signf(attacker.global_position.x - global_position.x)
			if adir == 0.0:
				adir = float(facing)
			clash = Vector2(attacker.global_position.x - adir * (attacker.body_size.x * 0.5 + 4.0), clash_y)
		else:
			clash = Vector2(global_position.x + float(facing) * attack_reach, clash_y)
		if hitbox.has_method("reflect"):
			hitbox.reflect(facing)   # 弹道（箭）→ 反弹回去打敌人
		if attacker:
			attacker._add_posture(parry_posture_to_attacker)
			attacker.flinch(signf((attacker as Node2D).global_position.x - global_position.x))
		# 亮出持刀挥击姿势（刀伸出去迎敌刃）
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_attack):
			sprite.play(anim_attack)
			_parry_pose_t = 0.30
		_parry_feedback(clash)
		parried.emit(attacker)
		return true

	# 中招
	_take_hp(hitbox.damage)
	_add_posture(hitbox.posture_damage * 0.5)
	if attacker is Node2D:
		velocity = (global_position - (attacker as Node2D).global_position).normalized() * hitbox.knockback
	_hit_feedback(hitbox, contact, Color(1, 1, 1))
	return true

## 闪避：冲刺 + 无敌帧
func _start_dodge() -> void:
	dodging = true
	_dodge_t = dodge_time
	_dodge_cd = dodge_cooldown
	invulnerable = true
	if move_dir != 0.0:
		facing = 1 if move_dir > 0.0 else -1
	_dodge_dir = facing
	if sprite:
		sprite.modulate = Color(0.65, 0.8, 1.0, 0.6)  # 蓝色半透明=无敌帧
	dodge_started.emit()

func _end_dodge() -> void:
	dodging = false
	invulnerable = false
	if sprite:
		sprite.modulate = Color.WHITE

## 被弹反 → 打断当前出招 + 击退 + 短硬直（给对方打身体的窗口）。
func flinch(push_dir: float) -> void:
	_flinch_t = parry_flinch
	attacking = false
	hit_active = false
	if _attack_hitbox:
		_attack_hitbox.monitorable = false
	velocity.x = push_dir * 150.0
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_hurt):
		sprite.play(anim_hurt)

func _take_hp(amount: float) -> void:
	if amount <= 0.0 or lock_hp:
		return
	hp = maxf(hp - amount, 0.0)
	took_hit.emit(amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()

func _add_posture(amount: float) -> void:
	_posture_delay = posture_regen_delay
	_set_posture(posture + amount)
	if posture >= posture_max and not guard_broken:
		_break_guard()

func _set_posture(v: float) -> void:
	posture = clampf(v, 0.0, posture_max)
	posture_changed.emit(posture, posture_max)

func _break_guard() -> void:
	guard_broken = true
	_stagger_t = stagger_time
	posture = posture_max
	dodging = false
	attacking = false
	if sprite:
		sprite.modulate = Color(1.0, 0.6, 0.6)
	FX.screen_flash(Color(1, 0.9, 0.6), 0.25, 0.2)
	guard_break.emit()

func _recover_from_break() -> void:
	guard_broken = false
	posture = 0.0
	_set_posture(0.0)
	if sprite:
		sprite.modulate = Color.WHITE

var _dead := false

func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit()
	set_physics_process(false)
	if _hurtbox:
		_hurtbox.set_deferred("monitoring", false)  # 信号回调中不能直接改，延迟设置
	if sprite:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_death):
			sprite.play(anim_death)
		else:
			FX.dissolve(sprite)

# ---------------------------------------------------------------- 反馈
func _parry_feedback(at: Vector2) -> void:
	FX.nova(at, 0.9)                                # 金色圆形新星（拼刀火花）
	FX.screen_flash(Color(1, 1, 0.85), 0.4, 0.14)
	FX.flash(sprite, 0.12, Color(1, 1, 0.7))
	FX.sfx("parry")
	Juice.clash()                                   # 极短定格 → 慢动作，看清两刀相交
	Juice.shake(9.0)

func _hit_feedback(_hitbox: Hitbox, _at: Vector2, col: Color) -> void:
	FX.flash(sprite, 0.12, col)
	FX.sfx("hit")
	Juice.hitstop(_hitbox.hitstop)
	Juice.shake(_hitbox.shake)

func _owner_actor_of(n: Node) -> Actor2D:
	var p := n.get_parent()
	while p != null and not (p is Actor2D):
		p = p.get_parent()
	return p as Actor2D

# ---------------------------------------------------------------- 动画
func _update_anim() -> void:
	if sprite == null:
		return
	if _parry_pose_t > 0.0:
		return  # 保持弹反持刀姿势
	if attacking:
		return
	if dodging:
		_play(anim_dodge, anim_run)
		return
	if not is_on_floor():
		_play(anim_jump if velocity.y < 0.0 else anim_fall, anim_idle)
	elif absf(velocity.x) > 10.0:
		_play(anim_run, anim_idle)
	else:
		_play(anim_idle, anim_idle)

func _play(name: String, fallback: String) -> void:
	var sf := sprite.sprite_frames
	if sf == null:
		return
	if sf.has_animation(name):
		sprite.play(name)
	elif sf.has_animation(fallback):
		sprite.play(fallback)

func _on_anim_finished() -> void:
	if sprite == null:
		return
	if attacking and sprite.animation == current_attack_anim:
		attacking = false

func _begin_attack(anim: String) -> void:
	attacking = true
	current_attack_anim = anim
	if sprite:
		sprite.play(anim)
	attack_started.emit()

## 敌人用：按一招的配置发动攻击（动态攻击框 reach/size/危/伤害）。
## cfg 键：anim, reach, size:Vector2, from, to, dmg, posture, perilous
func start_attack(cfg: Dictionary) -> void:
	if attacking or dodging or guard_broken or _flinch_t > 0.0:
		return
	attack_reach = float(cfg.get("reach", attack_reach))
	attack_size = cfg.get("size", attack_size)
	attack_active_from = int(cfg.get("from", attack_active_from))
	attack_active_to = int(cfg.get("to", attack_active_to))
	if _attack_hitbox:
		_attack_hitbox.damage = float(cfg.get("dmg", attack_damage))
		_attack_hitbox.posture_damage = float(cfg.get("posture", attack_posture))
		_attack_hitbox.perilous = bool(cfg.get("perilous", false))
	_begin_attack(String(cfg.get("anim", anim_attack)))

# ---------------------------------------------------------------- 调试框
func _process(_delta: float) -> void:
	if _dbg:
		queue_redraw()

func _draw() -> void:
	if not _dbg:
		return
	# 受击框（绿）：身体范围（含随朝向镜像的水平偏移）
	draw_rect(Rect2(hurt_dx * float(facing) - body_size.x * 0.5, -body_size.y, body_size.x, body_size.y), Color(0, 1, 0, 0.22))
	# 攻击框（红）：命中帧才显示
	if hit_active:
		var cx := float(facing) * attack_reach
		var cy := -body_size.y * 0.5
		var col := Color(1, 0, 0, 0.45) if not _attack_hitbox.perilous else Color(1, 0.5, 0, 0.55)
		draw_rect(Rect2(cx - attack_size.x * 0.5, cy - attack_size.y * 0.5, attack_size.x, attack_size.y), col)
