extends Node2D
class_name TSPlayer
## 玩家(永远实时, 不受时停影响)。移动/跳由 game 填 move_dir/want_jump。

var game
var w := 28.0
var h := 46.0
var vx := 0.0
var vy := 0.0
var onground := false
var facing := 1
var hp := 100.0
var maxhp := 100.0
var iframe := 0.0

var move_dir := 0.0
var want_jump := false
var atk_t := 0.0
var atkcd := 0.0
# 闪避(冲刺 + 无敌帧)
var dodging := false
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := 1

# 平台手感:土狼时间 / 跳跃缓冲 / 变量跳 / 非对称重力 / 挤压拉伸
var coyote_t := 0.0        # 离开地面后仍可跳的余裕
var jump_buf_t := 0.0      # 落地前提前按跳的缓冲
var jumping := false       # 处于跳跃上升中(变量跳截断用)
var jump_held := false     # 跳键是否按住(game 每帧填, 决定跳多高)
var _squash := 0.0         # 起跳(负=拉伸)/落地(正=压扁)的形变, 纯表现
const COYOTE := 0.10
const JUMP_BUF := 0.12
const JUMP_V := -640.0
const JUMP_CUT := 0.45     # 松手时上升速度保留比例(越小跳得越矮)
const GRAV := 1700.0

# 视觉:精灵帧就位前用色块 _draw;set_sprite_frames() 后切 AnimatedSprite2D
var _anim: AnimatedSprite2D = null
var _use_sprite := false

## 当前动画态(贴图就位后驱动 AnimatedSprite2D)
func current_anim() -> String:
	if dodging:
		return "dash"
	if atk_t > 0.0:
		return "attack"
	if not onground:
		return "jump" if vy < 0.0 else "fall"
	if absf(vx) > 12.0:
		return "run"
	return "idle"

## 主角精灵帧就位后调它,自动从色块切到精灵(走/跳/攻/闪按 current_anim 播放)
## target_h=想要的屏上帧高(px),foot_y=脚底在玩家局部坐标的 y(对齐站位)
func set_sprite_frames(sf: SpriteFrames, target_h := 0.0, foot_y := 0.0) -> void:
	if _anim == null:
		_anim = AnimatedSprite2D.new()
		_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_anim)
	_anim.sprite_frames = sf
	_use_sprite = true
	var first := sf.get_animation_names()[0] if sf.get_animation_names().size() > 0 else ""
	if target_h > 0.0 and first != "":
		var tex := sf.get_frame_texture(first, 0)
		if tex:
			var sc := target_h / float(tex.get_height())
			_anim.scale = Vector2(sc, sc)
			_anim.position.y = foot_y - target_h * 0.5   # 帧底=脚底 → 对齐站位
	if first != "":
		_anim.play(first)

## 踏被冻物:凝固之物即立足之地。冻住的敌人/子弹变实体平台,可落脚+再起跳。
## 只认真正被冻的(单体冻结 frozen_t>0 或 全场定格 freeze_t>0),命中顿帧不算。
func _stand_on_frozen() -> void:
	if vy < 0.0 or dodging:
		return                              # 上升中 / 闪避中不落脚
	var feet := position.y + h * 0.5
	var full: bool = game.freeze_t > 0.0
	for e in game.enemies:
		if not (full or e.frozen_t > 0.0):
			continue
		var top: float = e.position.y - e.h * 0.5
		if absf(position.x - e.position.x) < (w + e.w) * 0.5 and feet >= top - 4.0 and feet <= top + 22.0:
			position.y = top - h * 0.5
			vy = 0.0
			onground = true
			return
	for b in game.bullets:
		if b.dead or not (full or b.frozen_t > 0.0):
			continue
		var bt: float = b.position.y - b.r
		if absf(position.x - b.position.x) < (w * 0.5 + b.r) and feet >= bt - 4.0 and feet <= bt + 16.0:
			position.y = bt - h * 0.5
			vy = 0.0
			onground = true
			return

func try_dodge() -> void:
	if dodging or dodge_cd > 0.0:
		return
	dodging = true
	dodge_t = 0.22
	dodge_cd = 0.75
	iframe = maxf(iframe, 0.30)        # 闪避全程无敌(可穿怪/穿弹)
	dodge_dir = facing
	if absf(move_dir) > 0.2:
		dodge_dir = 1 if move_dir > 0.0 else -1
		facing = dodge_dir

func tick(delta: float) -> void:
	dodge_t = maxf(0.0, dodge_t - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	if dodging:
		vx = float(dodge_dir) * 720.0      # 冲刺速度
		if dodge_t <= 0.0:
			dodging = false
	else:
		vx = move_dir * 320.0
		if absf(move_dir) > 0.2:
			facing = 1 if move_dir > 0.0 else -1
	# ---- 跳跃:土狼时间(离台仍可跳) + 缓冲(提前按落地即跳) ----
	coyote_t = maxf(0.0, coyote_t - delta)
	jump_buf_t = maxf(0.0, jump_buf_t - delta)
	if want_jump:
		jump_buf_t = JUMP_BUF
		want_jump = false
	if jump_buf_t > 0.0 and coyote_t > 0.0 and not dodging:
		vy = JUMP_V
		coyote_t = 0.0
		jump_buf_t = 0.0
		onground = false
		jumping = true
		_squash = -0.5                       # 起跳:纵向拉伸
	# 变量跳:松开跳键且还在上升 → 截断上升(轻点矮跳, 按住高跳)
	if jumping and vy < 0.0 and not jump_held:
		vy *= JUMP_CUT
		jumping = false
	# ---- 非对称重力:接近顶点减重(留空感) + 下落加重(利落不飘) ----
	var g := GRAV
	if vy < 0.0:
		if absf(vy) < 150.0:
			g = GRAV * 0.72
	else:
		g = GRAV * 1.35
		jumping = false
	vy += g * delta
	iframe = maxf(0.0, iframe - delta)
	atk_t = maxf(0.0, atk_t - delta)
	atkcd = maxf(0.0, atkcd - delta)
	_squash = lerpf(_squash, 0.0, minf(1.0, delta * 12.0))
	var was_air := not onground
	# 对房间实体地形做 AABB 碰撞(取代单一 GROUND 判定)
	var r: Dictionary = game.collide_move(position, Vector2(w * 0.5, h * 0.5), Vector2(vx, vy) * delta)
	position = r.pos
	onground = r.floor
	if r.floor and vy > 0.0:
		if was_air and vy > 360.0:
			_squash = minf(0.6, vy / 1400.0)  # 落地:按下落速度纵向压扁
		vy = 0.0
	if r.ceil and vy < 0.0:
		vy = 0.0
	_stand_on_frozen()
	if onground:
		coyote_t = COYOTE                     # 站地上持续刷新土狼时间
		jumping = false
	# 掉出房间(断坑)→ 受伤并送回出生点
	if position.y > game.room_h + 60.0:
		position = game._spawn
		vx = 0.0
		vy = 0.0
		game.hurt_player(10.0)
	if _use_sprite and _anim and _anim.sprite_frames:
		var a := current_anim()
		if _anim.sprite_frames.has_animation(a) and _anim.animation != a:
			_anim.play(a)
		_anim.flip_h = facing < 0
	queue_redraw()

func _draw() -> void:
	if not _use_sprite:
		# 闪避拖影
		if dodging:
			for k in 3:
				var a := 0.20 * (1.0 - float(k) / 3.0)
				draw_rect(Rect2(-w * 0.5 - float(dodge_dir) * float(k + 1) * 13.0, -h * 0.5, w, h), Color(0.5, 0.9, 1.0, a))
		var col := Color(0.36, 0.75, 0.80)
		if dodging:
			col = Color(0.72, 0.95, 1.0)
		elif iframe > 0.0 and int(iframe * 20.0) % 2 == 0:
			col = Color(0.62, 0.90, 1.0)
		# 挤压拉伸(脚底对齐:跳起拉高、落地压扁), 纯表现
		var sx := w * (1.0 + _squash * 0.6)
		var sy := h * (1.0 - _squash * 0.6)
		draw_rect(Rect2(-sx * 0.5, h * 0.5 - sy, sx, sy), col)
		# 朝向小标
		draw_rect(Rect2(facing * 8.0 - 2.0, h * 0.5 - sy + 6.0, 4, 6), Color(0.9, 0.97, 1.0))
	# 攻击挥砍框(始终画,做打击反馈)
	if atk_t > 0.0:
		var ax := facing * 34.0
		draw_rect(Rect2(ax - 23.0, -23.0, 46, 46), Color(1, 1, 1, 0.45))
