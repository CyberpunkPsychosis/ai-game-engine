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
func set_sprite_frames(sf: SpriteFrames) -> void:
	if _anim == null:
		_anim = AnimatedSprite2D.new()
		_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_anim)
	_anim.sprite_frames = sf
	_use_sprite = true

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
	if want_jump and onground and not dodging:
		vy = -640.0
		onground = false
	want_jump = false
	vy += 1700.0 * delta
	position.x += vx * delta
	position.y += vy * delta
	iframe = maxf(0.0, iframe - delta)
	atk_t = maxf(0.0, atk_t - delta)
	atkcd = maxf(0.0, atkcd - delta)
	onground = false
	if position.y + h * 0.5 >= game.GROUND:
		position.y = game.GROUND - h * 0.5
		vy = 0.0
		onground = true
	position.x = clampf(position.x, 16.0, 1264.0)
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
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), col)
		# 朝向小标
		draw_rect(Rect2(facing * 8.0 - 2.0, -h * 0.5 + 6.0, 4, 6), Color(0.9, 0.97, 1.0))
	# 攻击挥砍框(始终画,做打击反馈)
	if atk_t > 0.0:
		var ax := facing * 34.0
		draw_rect(Rect2(ax - 23.0, -23.0, 46, 46), Color(1, 1, 1, 0.45))
