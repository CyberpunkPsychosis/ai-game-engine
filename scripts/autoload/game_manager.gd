extends Node
## 全局游戏状态 / 暂停管理。autoload 名: GameManager

signal paused_changed(is_paused: bool)

var is_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	# Esc 暂停/继续（不依赖 InputMap，避免维护按键绑定）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()

func toggle_pause() -> void:
	set_paused(not is_paused)

func set_paused(value: bool) -> void:
	is_paused = value
	get_tree().paused = value
	paused_changed.emit(is_paused)
