extends Control
class_name TSTouchUI
## 手机触摸视觉:左下圆形摇杆 + 右下错落弧形大圆键。只画, 不吃输入(输入走 game 的
## touch_panel 统一命中)。按键定义/状态读 game.btn_defs / game._btn_flash / game.joy_*。

var game
var _font: Font = load("res://fonts/zpix.ttf")   # 像素中文(单字标签)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	_draw_joystick()
	for bd in game.btn_defs:
		_draw_button(bd)

func _draw_joystick() -> void:
	var c: Vector2 = game.joy_center
	# 底盘:虚环 + 淡填充
	draw_circle(c, 92.0, Color(0.55, 0.7, 0.9, 0.07))
	draw_arc(c, 92.0, 0.0, TAU, 40, Color(0.6, 0.78, 0.95, 0.22), 2.0, true)
	# 摇杆头:跟手移动, 按下/推动时更亮
	var active: bool = game.joy_id != -999
	var knob: Vector2 = c + game.joy_vec * 82.0
	var a := 0.5 if active else 0.30
	draw_circle(knob, 46.0, Color(0.45, 0.78, 1.0, a))
	draw_arc(knob, 46.0, 0.0, TAU, 32, Color(0.7, 0.92, 1.0, a + 0.25), 2.5, true)

func _draw_button(bd: Dictionary) -> void:
	var c: Vector2 = bd["center"]
	var r: float = bd["radius"]
	var col: Color = bd["col"]
	var enabled: bool = bd.get("enabled", true)
	var fl: float = 0.0
	if game._btn_flash.has(bd["act"]):
		fl = clampf(float(game._btn_flash[bd["act"]]) / 0.16, 0.0, 1.0)
	var dim := 1.0 if enabled else 0.34
	var rr := r * (1.0 + 0.07 * fl)                 # 点按微胀
	# 填充(暗) + 内辉(按下变亮)
	draw_circle(c, rr - 3.0, Color(col.r * 0.42, col.g * 0.42, col.b * 0.42, (0.34 + 0.40 * fl) * dim))
	draw_circle(c, rr - 3.0, Color(col.r, col.g, col.b, (0.06 + 0.55 * fl) * dim))
	# 外环
	draw_arc(c, rr, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.92 * dim), 3.5, true)
	# 标签(像素中文, 居中)
	var fs := 38
	var ts: Vector2 = _font.get_string_size(bd["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var p := c - ts * 0.5 + Vector2(0.0, ts.y * 0.5 - _font.get_descent(fs) * 0.4)
	draw_string(_font, p, bd["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.98, 1.0, dim))
