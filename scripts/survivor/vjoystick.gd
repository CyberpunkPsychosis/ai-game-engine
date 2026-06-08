extends Control
class_name SurvivorJoystick
## 浮动虚拟摇杆(手机)。用 _input 直接读屏幕触摸,最大化可靠性。
## - 常驻可见:空闲时在左下画一个"home"提示圈(确认新版已加载)。
## - 触摸任意处:摇杆基座跳到触点,拖动给方向。
## - 屏幕左下打调试信息(触摸次数/向量),便于远程排查触摸是否进来。
## mouse_filter=IGNORE,只画+读移动触摸,不拦 UI 按钮。

var _origin := Vector2.ZERO
var _vec := Vector2.ZERO
var _active := false
var _idx := -1
var _radius := 95.0
var _dbg_touches := 0          # 收到过多少次按下(触摸或鼠标)
var _dbg_last := "none"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_vector() -> Vector2:
	return _vec

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dbg_last = "touch"
		if event.pressed:
			if not _active:
				_dbg_touches += 1
				_active = true; _idx = event.index
				_origin = event.position; _vec = Vector2.ZERO
		elif event.index == _idx:
			_end()
		queue_redraw()
	elif event is InputEventScreenDrag and _active and event.index == _idx:
		_dbg_last = "drag"
		_update(event.position)
	elif event is InputEventMouseButton:
		_dbg_last = "mouse"
		if event.pressed and not _active:
			_dbg_touches += 1
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

func _home() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(150.0, vp.y - 150.0)

func _draw() -> void:
	var base := _origin if _active else _home()
	var a := 0.22 if _active else 0.10
	draw_circle(base, _radius, Color(1, 1, 1, 0.05))
	draw_arc(base, _radius, 0.0, TAU, 32, Color(1, 1, 1, a + 0.06), 2.0)
	draw_circle(base + _vec * _radius, 30.0, Color(1, 1, 1, a))
