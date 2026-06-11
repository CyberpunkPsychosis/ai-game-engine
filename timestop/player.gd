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
const COYOTE := 0.14
const JUMP_BUF := 0.12
const JUMP_V := -640.0
const JUMP_CUT := 0.35     # 松手时上升速度保留比例(越小跳得越矮)
const GRAV := 1700.0
# 二段跳(死亡细胞:土狼跳后仍保留二段跳) + 快速下落
var want_down := false      # 按住下:加速下落(利落落地)
var air_jumps := 0          # 剩余空中跳次数
const MAX_AIR_JUMPS := 1
const AIR_JUMP_V := -560.0  # 二段跳初速(略弱于地面跳)
# 受击击退(短暂夺控, 做"挨打有反应"; knock_t 内由 knock_vx 接管横移)
var knock_t := 0.0
var knock_vx := 0.0
var haste_t := 0.0          # 击杀加速(死亡细胞:连杀越打越快, 奖励进攻)
# 连击表现(由 game 填; 终结段画更大更亮的挥砍)
var atk_finisher := false
var atk_stage := 0          # 连击段(0/1/2), game.try_attack 填, 选 attack1/2/3 动画
var _flip_t := 0.0          # 二段跳空翻动画计时(>0 播 flip)
var _climb_t := 0.0         # 攀爬补间计时(>0 位置沿弧线补间 + 播 climb)
var _climb_from := Vector2.ZERO
var _climb_to := Vector2.ZERO
const CLIMB_DUR := 0.22

# 跑步动画的"蹬地速度"(屏幕px/s, speed_scale=1 时):贴地脚每帧后滑的速度。
# 步频基准:死亡细胞的做法是动画固定中速、容忍轻微滑步, 保证腿部动作可读,
# 而不是和移速完全咬合(咬合=全速 4 步/秒, 腿快成风火轮)。
# 160 → 全速(224)步频 1.4x ≈ 0.48s/圈(贴近死亡细胞), 3x镜头下更耐看;
# 滑步率 1.48 在可接受带内(完全咬合的快步频在大镜头下视觉超载)。
const RUN_TREAD := 160.0
const RUN_ENTRY_FRAME := 13  # run 循环里身姿最挺拔的一帧(30px, 量过): idle 切 run 由它进场过渡最顺

# 抓沿/攀爬(ledge grab):跳到平台边缘抓住沿口, 跳上去 / 往外推松手
var ledge_grab := false
var ledge_cd := 0.0        # 松手后短暂禁抓(防立刻又抓住)
var ledge_hang_t := 0.0    # 已挂时长(挂够久自动翻上)
var _ledge_top := 0.0      # 抓住的那道沿的顶 y
const LEDGE_AUTO := 0.16   # 不操作时挂多久自动爬上

# 视觉:精灵帧就位前用色块 _draw;set_sprite_frames() 后切 AnimatedSprite2D
var _anim: AnimatedSprite2D = null
var _use_sprite := false

## 当前动画态(贴图就位后驱动 AnimatedSprite2D)
func current_anim() -> String:
	if dodging:
		return "dash"
	if _climb_t > 0.0:
		return "climb"
	if ledge_grab:
		return "hang"
	if atk_t > 0.0:
		return "attack"
	if not onground:
		if _flip_t > 0.0:
			return "flip"                  # 空翻窗口=动画整圈时长, 转完再切落下
		return "jump" if vy < 0.0 else "fall"
	# (地面蹲走已删: 武士包无蹲姿动画, 下推摇杆曾导致 idle 姿势滑行"平移")
	# (走路档已删: 摇杆数字化=过死区即全速, 移动只有 run 一档)
	if absf(vx) > 12.0:
		return "run"
	return "idle"

## 动画缺表时的回退链(素材渐进式补齐, 缺哪个都不会卡)
func _resolve_anim(a: String) -> String:
	if _anim == null or _anim.sprite_frames == null:
		return a
	var fb := {
		"walk": "run", "crouchwalk": "crouch", "crouch": "idle",
		"flip": "jump", "hang": "idle", "climb": "idle",
		"attack1": "attack", "attack2": "attack", "attack3": "attack",
		"attack": "idle", "jump": "run", "fall": "run", "dash": "run",
	}
	var guard := 0
	while not _anim.sprite_frames.has_animation(a) and fb.has(a) and guard < 6:
		a = fb[a]
		guard += 1
	return a

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

## 挂在沿上时每帧:跳/上=翻身爬上, 往沿外推=松手掉下, 挂够久自动爬上
func _tick_ledge(delta: float) -> void:
	vx = 0.0
	vy = 0.0
	onground = false
	ledge_hang_t += delta
	# 往沿外侧(背朝墙)推 → 松手
	if absf(move_dir) > 0.35 and signf(move_dir) != float(facing):
		ledge_grab = false
		ledge_cd = 0.35
		want_jump = false
		return
	# 按跳 / 顶着朝向推 / 挂够久 → 翻身爬上去(死亡细胞: 跑向台沿顺势就上)
	if want_jump or ledge_hang_t > LEDGE_AUTO \
	or (absf(move_dir) > 0.35 and signf(move_dir) == float(facing)):
		# 翻上沿口: 不再瞬移, 位置在 tick 里沿"先上后前"弧线补间(死亡细胞 mantle)
		_climb_t = CLIMB_DUR
		_climb_from = position
		_climb_to = Vector2(position.x + float(facing) * (w * 0.5 + 8.0), _ledge_top - h * 0.5 - 1.0)
		ledge_grab = false
		ledge_cd = 0.20
	want_jump = false

func _point_solid(x: float, y: float) -> bool:
	for sd in game.solids:
		if (sd as Rect2).has_point(Vector2(x, y)):
			return true
	return false

## 面朝方向是否够到一道可抓的沿;是→返回沿顶 y, 否→返回 NAN。
## 判据:前方某实体的水平范围罩住手前方点, 其顶沿落在头部上下一段"够得到"的带里,
## 且沿口正下方是墙、正上方是空(确认是"沿"而非整面墙/天花板)。
func _ledge_in_front() -> float:
	var dir := float(facing)
	var fx := position.x + dir * (w * 0.5 + 7.0)
	var head := position.y - h * 0.5
	for sd in game.solids:
		var rr: Rect2 = sd
		if fx < rr.position.x or fx > rr.position.x + rr.size.x:
			continue
		var top := rr.position.y
		if top < head - 10.0 or top > head + 24.0:
			continue                             # 沿顶不在"手能够到"的带里
		if _point_solid(fx, top + 6.0) and not _point_solid(fx, top - 8.0):
			return top                           # 下面是墙、上面是空 → 是沿, 可抓
	return NAN

func try_dodge() -> void:
	if dodging or dodge_cd > 0.0:
		return
	dodging = true
	dodge_t = 0.22
	dodge_cd = 0.55                     # HK 冲刺节奏: 短促有力, CD 略长不无脑连发
	iframe = maxf(iframe, 0.34)         # 无敌覆盖翻滚大部分(留一点点收尾破绽)
	knock_t = 0.0                       # 翻滚立刻夺回控制(可滚出受击硬直)
	atk_t = 0.0                         # 滚 → 取消攻击挥砍
	atkcd = minf(atkcd, 0.06)          # 取消攻击后摇(滚完即可再砍)
	dodge_dir = facing
	if absf(move_dir) > 0.2:
		dodge_dir = 1 if move_dir > 0.0 else -1
		facing = dodge_dir

func tick(delta: float) -> void:
	dodge_t = maxf(0.0, dodge_t - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	_flip_t = maxf(0.0, _flip_t - delta)
	knock_t = maxf(0.0, knock_t - delta)
	haste_t = maxf(0.0, haste_t - delta)
	if knock_t > 0.0:
		vx = knock_vx                      # 受击击退期:夺控横移(可被翻滚打断)
	elif dodging:
		vx = float(dodge_dir) * 700.0      # HK 冲刺: 0.22s × 700 ≈ 154px(3身位) 水平瞬移
		if dodge_t <= 0.0:
			dodging = false
	elif atk_t > 0.0 and onground:
		# 死亡细胞: 地面攻击站桩, 但随挥击小幅前送(不能跑砍, 转向也锁定)
		vx = float(facing) * 85.0 * (atk_t / 0.35)   # 0.35 = 攻击动画全长(7帧@20fps)
	else:
		vx = move_dir * (208.0 if haste_t > 0.0 else 173.0)   # 连杀加速 +20%
		# 速度对标空洞骑士: HK 横穿一屏≈3.7s → 640px 屏宽 ÷ 3.7 ≈ 173px/s(≈3.4身位/s)。
		# (旧死亡细胞档 224; 房间已无大间隙, 降速无通行问题)
		if absf(move_dir) > 0.2:
			facing = 1 if move_dir > 0.0 else -1
	# ---- 抓沿状态:挂在沿上时接管本帧(跳=爬上 / 外推=松手 / 挂久自动爬) ----
	ledge_cd = maxf(0.0, ledge_cd - delta)
	if ledge_grab:
		_tick_ledge(delta)
		queue_redraw()
		return
	# ---- 攀爬补间: 先拉上去再越过沿口, 期间锁操作(0.22s) ----
	if _climb_t > 0.0:
		var p := 1.0 - _climb_t / CLIMB_DUR
		position.y = lerpf(_climb_from.y, _climb_to.y, clampf(p * 1.7, 0.0, 1.0))
		position.x = lerpf(_climb_from.x, _climb_to.x, clampf((p - 0.35) / 0.65, 0.0, 1.0))
		vx = 0.0
		vy = 0.0
		want_jump = false
		_climb_t = maxf(0.0, _climb_t - delta)
		if _climb_t <= 0.0:                    # 落定站稳
			position = _climb_to
			onground = true
			coyote_t = COYOTE
			air_jumps = MAX_AIR_JUMPS
			_squash = 0.30
		if _use_sprite and _anim and _anim.sprite_frames:
			var ca := _resolve_anim("climb")
			if _anim.sprite_frames.has_animation(ca) and _anim.animation != ca:
				_anim.play(ca)
			_anim.flip_h = facing < 0
		queue_redraw()
		return
	# ---- 跳跃:土狼时间(离台仍可跳) + 缓冲(提前按落地即跳) ----
	# 关键:只在空中流逝 coyote(用上一帧的 onground 判定)→ 离台当帧保住满窗口,
	# 不会"一离开就先被扣掉一帧"。
	if not onground:
		coyote_t = maxf(0.0, coyote_t - delta)
	jump_buf_t = maxf(0.0, jump_buf_t - delta)
	if want_jump:
		jump_buf_t = JUMP_BUF
		want_jump = false
	if jump_buf_t > 0.0 and not dodging:
		if coyote_t > 0.0:
			vy = JUMP_V                       # 地面/土狼跳(不消耗二段跳)
			coyote_t = 0.0
			jump_buf_t = 0.0
			onground = false
			jumping = true
			_squash = -0.5                    # 起跳:纵向拉伸
		elif air_jumps > 0:
			vy = AIR_JUMP_V                   # 二段跳
			air_jumps -= 1
			jump_buf_t = 0.0
			jumping = true
			_squash = -0.42
			_flip_t = 0.38                    # 二段跳 → 空翻窗口(=6帧@16fps整圈)
	# 变量跳:松开跳键且还在上升 → 截断上升(轻点矮跳, 按住高跳)
	if jumping and vy < 0.0 and not jump_held:
		vy *= JUMP_CUT
		jumping = false
	# ---- 非对称重力:接近顶点减重(留空感) + 下落加重(利落不飘) ----
	var g := GRAV
	if dodging:
		g = 0.0
		vy = 0.0                             # HK 冲刺: 纯水平位移, 重力挂起
	elif vy < 0.0:
		if absf(vy) < 240.0:
			g = GRAV * 0.55                  # HK 式顶点滞空(窗口宽+减重狠 → 浮一下再落)
	else:
		g = GRAV * 1.35
		jumping = false
		if want_down:
			g *= 1.55                        # 按下:快速下落(利落)
	vy += g * delta
	vy = minf(vy, 820.0 if want_down else 620.0)   # 终端速度(HK: 下落≈起跳初速, 从不失控; 下推稍快)
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
		air_jumps = MAX_AIR_JUMPS             # 落地补满二段跳
		_flip_t = 0.0
	# ---- 抓沿检测:空中、不在猛冲段、面朝墙且够到沿 → 抓住(上升/下落段都可)----
	# 武士包无 hang/climb 动画(挂墙=僵直站姿), 先关; 换全动作包后把 false 改回
	elif false and ledge_cd <= 0.0 and not dodging and vy > -380.0:
		var lt := _ledge_in_front()
		if not is_nan(lt):
			ledge_grab = true
			_ledge_top = lt
			ledge_hang_t = 0.0
			position.y = lt + h * 0.5 - 10.0  # 手挂在沿口
			vx = 0.0
			vy = 0.0
	# 掉出房间(断坑)→ 受伤并送回出生点
	if position.y > game.room_h + 60.0:
		position = game._spawn
		vx = 0.0
		vy = 0.0
		game.hurt_player(10.0)
	if _use_sprite and _anim and _anim.sprite_frames:
		var a := _resolve_anim(current_anim())
		if _anim.sprite_frames.has_animation(a) and _anim.animation != a:
			var from_idle := _anim.animation == "idle"
			_anim.play(a)
			if a == "run" and from_idle:
				_anim.frame = RUN_ENTRY_FRAME   # idle→run 从最挺拔帧切入, 身姿顺势压低不突兀
		_anim.flip_h = facing < 0
		# 步频跟随移速(消除脚底打滑):跑得越快腿迈越快, 加减速/连杀加速自然跟随
		_anim.speed_scale = clampf(absf(vx) / RUN_TREAD, 0.6, 2.0) if a == "run" else 1.0
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
	# 攻击挥砍框: 仅色块占位模式画(精灵模式刀光已烤在动画里)
	if atk_t > 0.0 and not _use_sprite:
		var rad := 28.0 if atk_finisher else 23.0
		var off := 40.0 if atk_finisher else 34.0
		var col := Color(1.0, 0.86, 0.42, 0.52) if atk_finisher else Color(1, 1, 1, 0.42)
		var ax := facing * off
		draw_rect(Rect2(ax - rad, -rad, rad * 2.0, rad * 2.0), col)
