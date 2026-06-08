extends Control
class_name SurvivorJoystick
## 全屏浮动虚拟摇杆(手机):按下处生成基座,拖动给出方向向量。
## 用 _unhandled_input 直接读屏幕触摸(不靠 Control 的 GUI 拾取,网页/移动端更稳)。
## mouse_filter=IGNORE:不拦 UI 按钮的点击,只负责画摇杆 + 读移动触摸。
## 自动瞄准开火,所以整屏都可作为移动区。键盘有输入时玩家会忽略它。

var _origin := Vector2.ZERO
var _vec := Vector2.ZERO
var _active := false
var _idx := -1
var _radius := 95.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_vector() -> Vector2:
	return _vec

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _active:
				_active = true; _idx = event.index
				_origin = event.position; _vec = Vector2.ZERO
		elif event.index == _idx:
			_end()
		queue_redraw()
	elif event is InputEventScreenDrag and _active and event.index == _idx:
		_update(event.position)
	elif event is InputEventMouseButton:        # 桌面鼠标兜底(未开 emulate 时)
		if event.pressed and not _active:
			_active = true; _idx = -2
			_origin = event.position; _vec = Vector2.ZERO
		elif not event.pressed and _idx == -2:
			_end()
		queue_redraw()
	elif event is InputEventMouseMotion and _active and _idx == -2:
		_update(event.position)

func _update(pos: Vector2) -> void:
	_vec = ((pos - _origin) / _radius).limit_length(1.0)
	queue_redraw()

func _end() -> void:
	_active = false; _idx = -1; _vec = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	draw_circle(_origin, _radius, Color(1, 1, 1, 0.06))
	draw_arc(_origin, _radius, 0, TAU, 32, Color(1, 1, 1, 0.15), 2.0)
	draw_circle(_origin + _vec * _radius, 30.0, Color(1, 1, 1, 0.18))
