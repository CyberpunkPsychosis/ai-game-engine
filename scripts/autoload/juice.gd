extends Node
## 打击感工具：顿帧(hitstop) + 镜头震动(screenshake)。autoload 名: Juice
## 相机自己注册：Juice.register_camera($Camera2D)
## 触发：Juice.shake(8.0)    Juice.hitstop(0.08)

var _camera: Camera2D = null
var _shake_amount := 0.0
var _shake_decay := 28.0   # 每秒衰减强度

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_camera(cam: Camera2D) -> void:
	_camera = cam

func shake(amount: float, decay := 28.0) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_decay = decay

## 顿帧：把时间缩放压到 scale，duration 秒后恢复（按真实时间计，不受 time_scale 影响）
func hitstop(duration := 0.08, scale := 0.0) -> void:
	Engine.time_scale = scale
	# create_timer(time, process_always, process_in_physics, ignore_time_scale)
	var t := get_tree().create_timer(duration, true, false, true)
	await t.timeout
	Engine.time_scale = 1.0

## 拼刀演出：极短定格 → 慢动作 → 恢复（按真实时间，不受 time_scale 影响）。
func clash(freeze := 0.06, slow_dur := 0.30, slow_scale := 0.18) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(freeze, true, false, true).timeout
	Engine.time_scale = slow_scale
	await get_tree().create_timer(slow_dur, true, false, true).timeout
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	if _shake_amount > 0.05:
		_camera.offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
		_shake_amount = move_toward(_shake_amount, 0.0, _shake_decay * delta)
	elif _camera.offset != Vector2.ZERO:
		_shake_amount = 0.0
		_camera.offset = Vector2.ZERO
