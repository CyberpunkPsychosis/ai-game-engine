extends Node
## 开发者工具：调试信息 overlay(F3) + 运行时手感调参面板(F1) + 版本水印。
## autoload 名: DevTools。每个场景自动可用，按 F1/F3 切换。

# 可在运行时拖动的手感参数（属性名 / 最小 / 最大 / 步进）
const TUNABLES := [
	{"prop": "max_speed", "min": 50.0, "max": 700.0, "step": 5.0},
	{"prop": "acceleration", "min": 200.0, "max": 6000.0, "step": 50.0},
	{"prop": "friction", "min": 200.0, "max": 6000.0, "step": 50.0},
	{"prop": "air_acceleration", "min": 200.0, "max": 5000.0, "step": 50.0},
	{"prop": "jump_velocity", "min": -1400.0, "max": -200.0, "step": 10.0},
	{"prop": "gravity", "min": 400.0, "max": 5000.0, "step": 50.0},
	{"prop": "fall_gravity_mult", "min": 1.0, "max": 3.0, "step": 0.05},
	{"prop": "jump_cut_mult", "min": 0.0, "max": 1.0, "step": 0.05},
	{"prop": "coyote_time", "min": 0.0, "max": 0.3, "step": 0.01},
	{"prop": "jump_buffer_time", "min": 0.0, "max": 0.3, "step": 0.01},
]

var _layer: CanvasLayer
var _debug_label: Label
var _panel: PanelContainer
var _panel_built := false
var _value_labels := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	# 调试信息（左上）
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 70)
	_debug_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_debug_label.visible = false
	_layer.add_child(_debug_label)

	# 版本水印（右下，常驻）
	var ver := Label.new()
	ver.text = "v%s  [F1]调参 [F3]调试" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	ver.anchor_left = 1.0
	ver.anchor_top = 1.0
	ver.anchor_right = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -260
	ver.offset_top = -28
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(ver)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_debug_label.visible = not _debug_label.visible
		elif event.keycode == KEY_F1:
			_toggle_panel()

func _process(_delta: float) -> void:
	if not _debug_label.visible:
		return
	var lines := ["FPS: %d" % Engine.get_frames_per_second()]
	var p := _get_player()
	if p is CharacterBody2D:
		lines.append("pos: (%d, %d)" % [p.global_position.x, p.global_position.y])
		lines.append("vel: (%d, %d)" % [p.velocity.x, p.velocity.y])
		lines.append("on_floor: %s" % str(p.is_on_floor()))
	lines.append("paused: %s" % str(get_tree().paused))
	_debug_label.text = "\n".join(lines)

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _toggle_panel() -> void:
	if not _panel_built:
		_build_panel()
	if _panel:
		_panel.visible = not _panel.visible
		_refresh_panel_values()

func _build_panel() -> void:
	var p := _get_player()
	if p == null:
		return
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -340
	_panel.offset_top = 12
	_panel.offset_right = -12
	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)
	var title := Label.new()
	title.text = "手感调参 (F1)"
	vbox.add_child(title)

	for entry in TUNABLES:
		var prop: String = entry["prop"]
		if not (prop in p):
			continue
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = prop
		name_label.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = entry["min"]
		slider.max_value = entry["max"]
		slider.step = entry["step"]
		slider.value = p.get(prop)
		slider.custom_minimum_size = Vector2(110, 0)
		row.add_child(slider)
		var val_label := Label.new()
		val_label.text = str(p.get(prop))
		val_label.custom_minimum_size = Vector2(50, 0)
		row.add_child(val_label)
		_value_labels[prop] = val_label
		slider.value_changed.connect(_on_slider_changed.bind(prop, val_label))
		vbox.add_child(row)

	_layer.add_child(_panel)
	_panel_built = true

func _on_slider_changed(value: float, prop: String, val_label: Label) -> void:
	var p := _get_player()
	if p != null:
		p.set(prop, value)
	val_label.text = "%.2f" % value

func _refresh_panel_values() -> void:
	var p := _get_player()
	if p == null:
		return
	for prop in _value_labels.keys():
		_value_labels[prop].text = "%.2f" % float(p.get(prop))
