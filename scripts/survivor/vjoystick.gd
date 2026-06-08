extends Control
class_name SurvivorJoystick
## 全屏浮动虚拟摇杆(手机):按下处生成基座,拖动给出方向向量。
## 自动瞄准开火,所以整屏都可作为移动区。键盘有输入时玩家会忽略它。

var _origin := Vector2.ZERO
var _vec := Vector2.ZERO
var _active := false
var _idx := -1
var _radius := 95.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func get_vector() -> Vector2:
	return _vec

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_active = true; _idx = event.index; _origin = event.position; _vec = Vector2.ZERO
		elif not event.pressed and event.index == _idx:
			_end()
		queue_redraw()
	elif event is InputEventScreenDrag and _active and event.index == _idx:
		_update(event.position)
	elif event is InputEventMouseButton:        # 桌面用鼠标也能测
		if event.pressed:
			_active = true; _idx = -2; _origin = event.position; _vec = Vector2.ZERO
		elif _idx == -2:
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
