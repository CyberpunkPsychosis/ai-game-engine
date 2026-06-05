extends Control
class_name TouchControls
## 手机虚拟操作层：左摇杆走位(模拟量) + 右侧菱形四键(跳/攻/弹反/闪)。
## 全自绘、支持多点触控(走位同时出招)。把触摸映射到现有 InputMap 动作，
## 玩家脚本完全不用改（player.gd 照常读 Input）。
##
## 用法：放进一个 CanvasLayer，set_anchors_preset(PRESET_FULL_RECT)。

# 菱形四键：动作名 -> 显示文字（用英文，免内置字体缺中文字形显示成方块）
const BTNS := [
	{"act": "jump",    "lab": "JUMP"},    # 上
	{"act": "special", "lab": "DODGE"},   # 左
	{"act": "attack",  "lab": "ATK"},     # 右
	{"act": "dash",    "lab": "PARRY"},   # 下(拇指常驻 = 招牌弹反)
]

var _font: Font
var _seen_touch := false            # 见过真触摸后，彻底忽略鼠标(防触屏伪鼠标重复触发)
var _active := {}                   # 触点 index -> "joy" 或 动作名
var _joy_origin := Vector2.ZERO     # 当前摇杆基座中心(按下处)
var _joy_vec := Vector2.ZERO        # 摇杆偏移(像素)
var _joy_active := false
var _move_pressed := ""             # 当前正按住的走位动作(move_left/move_right/"")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	z_index = 4096
	_fit()
	get_viewport().size_changed.connect(_fit)
	resized.connect(queue_redraw)

# CanvasLayer 下的 Control 不会自动撑满视口，手动贴成全屏并跟随分辨率变化
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	queue_redraw()

# ---- 布局(按当前 size 实时算，自适应横竖屏) ----
func _ui() -> float:
	return clampf(minf(size.x, size.y) * 0.16, 64.0, 150.0)  # 基准单元

func _joy_base() -> Vector2:
	return Vector2(_ui() * 1.4, size.y - _ui() * 1.4)

func _joy_radius() -> float:
	return _ui() * 0.9

func _btn_center() -> Vector2:
	return Vector2(size.x - _ui() * 1.9, size.y - _ui() * 1.9)

func _btn_radius() -> float:
	return _ui() * 0.5

func _btn_pos(i: int) -> Vector2:
	var c := _btn_center()
	var s := _ui() * 1.05
	match i:
		0: return c + Vector2(0, -s)   # 跳(上)
		1: return c + Vector2(-s, 0)   # 闪(左)
		2: return c + Vector2(s, 0)    # 攻(右)
		_: return c + Vector2(0, s)    # 弹反(下)

# ---------------------------------------------------------------- 输入
func _gui_input(event: InputEvent) -> void:
	# 真触摸：始终走多点逻辑（不依赖 is_touchscreen_available，手机浏览器常误报）
	if event is InputEventScreenTouch:
		_seen_touch = true
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index)
		accept_event()
	elif event is InputEventScreenDrag:
		_seen_touch = true
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position)
		accept_event()
	# 鼠标只在"从没见过触摸"时当单指用（纯桌面调试）；见过触摸后一律忽略，
	# 免得触屏的伪鼠标在手指间乱跳、误点按钮。
	elif not _seen_touch:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_press(-1, mb.position)
				else:
					_release(-1)
				accept_event()
		elif event is InputEventMouseMotion and _active.has(-1):
			_drag(-1, (event as InputEventMouseMotion).position)
			accept_event()

func _press(idx: int, pos: Vector2) -> void:
	# 命中某个按钮？
	for i in BTNS.size():
		if pos.distance_to(_btn_pos(i)) <= _btn_radius() * 1.15:
			var act: String = BTNS[i]["act"]
			_active[idx] = act
			Input.action_press(act)        # 触发 just_pressed(弹反/攻击/跳 都靠它)
			queue_redraw()
			return
	# 否则按在左半屏 → 摇杆(基座落在按下处，跟手)
	if pos.x < size.x * 0.5:
		_active[idx] = "joy"
		_joy_active = true
		_joy_origin = pos
		_joy_vec = Vector2.ZERO
		queue_redraw()

func _drag(idx: int, pos: Vector2) -> void:
	if _active.get(idx, "") != "joy":
		return
	var off := pos - _joy_origin
	var r := _joy_radius()
	if off.length() > r:
		off = off.normalized() * r
	_joy_vec = off
	_apply_move()
	queue_redraw()

func _release(idx: int) -> void:
	var role: String = _active.get(idx, "")
	if role == "":
		return
	_active.erase(idx)
	if role == "joy":
		_joy_active = false
		_joy_vec = Vector2.ZERO
		_clear_move()
	else:
		Input.action_release(role)        # 松开 → 触发 just_released(变跳高度靠它)
	queue_redraw()

# 摇杆 x 偏移 → 模拟量走位(player 用 get_axis 读 strength)
func _apply_move() -> void:
	var r := _joy_radius()
	var nx := clampf(_joy_vec.x / r, -1.0, 1.0)
	var dz := 0.22
	var want := ""
	var strength := 0.0
	if nx <= -dz:
		want = "move_left"
		strength = clampf((-nx - dz) / (1.0 - dz), 0.0, 1.0)
	elif nx >= dz:
		want = "move_right"
		strength = clampf((nx - dz) / (1.0 - dz), 0.0, 1.0)
	if want != _move_pressed and _move_pressed != "":
		Input.action_release(_move_pressed)
		_move_pressed = ""
	if want != "":
		Input.action_press(want, maxf(strength, 0.15))
		_move_pressed = want

func _clear_move() -> void:
	if _move_pressed != "":
		Input.action_release(_move_pressed)
		_move_pressed = ""

func _exit_tree() -> void:
	# 离场清掉所有按住的键，免得卡键
	_clear_move()
	for idx in _active.keys():
		var role: String = _active[idx]
		if role != "joy":
			Input.action_release(role)
	_active.clear()

# ---------------------------------------------------------------- 自绘
func _draw() -> void:
	var col_base := Color(1, 1, 1, 0.10)
	var col_ring := Color(1, 1, 1, 0.30)
	# 摇杆：基座 + 摇杆头
	var jb := _joy_base() if not _joy_active else _joy_origin
	var jr := _joy_radius()
	draw_circle(jb, jr, col_base)
	draw_arc(jb, jr, 0, TAU, 48, col_ring, 3.0, true)
	var knob := jb + (_joy_vec if _joy_active else Vector2.ZERO)
	draw_circle(knob, jr * 0.42, Color(1, 1, 1, 0.22))
	draw_arc(knob, jr * 0.42, 0, TAU, 32, Color(1, 0.95, 0.7, 0.55), 3.0, true)
	# 四键
	for i in BTNS.size():
		var p := _btn_pos(i)
		var br := _btn_radius()
		var held := false
		for v in _active.values():
			if v == BTNS[i]["act"]:
				held = true
				break
		var fill := Color(1, 0.9, 0.6, 0.28) if held else Color(1, 1, 1, 0.12)
		var ring := Color(1, 0.9, 0.6, 0.85) if held else Color(1, 1, 1, 0.34)
		# 弹反键(i==3)高亮一点：招牌机制
		if i == 3 and not held:
			ring = Color(1.0, 0.85, 0.4, 0.6)
		draw_circle(p, br, fill)
		draw_arc(p, br, 0, TAU, 40, ring, 3.0, true)
		if _font:
			var lab: String = BTNS[i]["lab"]
			var fs := int(br * 0.42)
			var tw := _font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(_font, p - Vector2(tw.x * 0.5, -fs * 0.34), lab,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
