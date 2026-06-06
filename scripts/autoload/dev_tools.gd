extends Node
## 实时调参工具（autoload: DevTools）。
##  · ⚙ 面板：拖滑块实时改主角/当前怪的手感数值（来源 = 各对象的 tunables()）。
##  · ▦ 透视：画出所有受击框/攻击框 + 怪的出手/保持距离 + 矛判定框预览。
##  · 导出：把当前数值拷到剪贴板 + 显示出来，方便记下/发我。
##  · 键盘 F1 开面板 / F3 开透视；手机用左上角两个按钮。

var _layer: CanvasLayer
var _panel: PanelContainer
var _rows: Array = []          # [{obj, name, slider, vlabel, step}]
var _readout: Label
var _debug_on := false
var _ui_enabled := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 200
	add_child(_layer)

	var args := OS.get_cmdline_user_args()
	_ui_enabled = OS.has_feature("web") or DisplayServer.is_touchscreen_available() or ("--tune" in args)

	# 版本水印（右下）
	var ver := Label.new()
	ver.text = "v%s  [F1]调参 [F3]透视" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -250
	ver.offset_top = -26
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(ver)

	# 网页/手机的开关在触控层右上角(调参/透视/锁血)；桌面用 F1/F3
	if "--tune" in args:
		_auto_open()      # 预览/截图用：自动开面板+透视

func _auto_open() -> void:
	await get_tree().create_timer(0.4).timeout
	if _panel == null:
		_build_panel()
	if not _debug_on:
		_toggle_debug()

func _make_corner_buttons() -> void:
	var gear := Button.new()
	gear.text = "⚙ 调参"
	gear.position = Vector2(8, 8)
	gear.custom_minimum_size = Vector2(96, 44)
	gear.add_theme_font_size_override("font_size", 20)
	gear.pressed.connect(_toggle_panel)
	_layer.add_child(gear)

	var boxes := Button.new()
	boxes.text = "▦ 透视"
	boxes.position = Vector2(112, 8)
	boxes.custom_minimum_size = Vector2(96, 44)
	boxes.add_theme_font_size_override("font_size", 20)
	boxes.pressed.connect(_toggle_debug)
	_layer.add_child(boxes)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_panel()
		elif event.keycode == KEY_F3:
			toggle_debug()

# 给触控层/外部调用的公开开关
func toggle_panel() -> void:
	_toggle_panel()

func toggle_debug() -> void:
	_toggle_debug()

func toggle_player_lock() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if p and "lock_hp" in p:
		p.lock_hp = not p.lock_hp
		return p.lock_hp
	return false

func _process(_delta: float) -> void:
	# 透视开着时，持续把 _dbg 铺到所有角色（新出的怪也覆盖到）
	if _debug_on:
		for a in _all_actors():
			a._dbg = true

func _all_actors() -> Array:
	var out: Array = []
	var p := get_tree().get_first_node_in_group("player")
	if p:
		out.append(p)
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			out.append(e)
	return out

func _toggle_debug() -> void:
	_debug_on = not _debug_on
	for a in _all_actors():
		if "_dbg" in a:
			a._dbg = _debug_on
			a.queue_redraw()

# ---------------------------------------------------------------- 面板
func _current_enemy() -> Node:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.get("hp") != null and e.hp > 0.0:
			return e
	return null

func _toggle_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
		_rows.clear()
		return
	_build_panel()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 60)
	_panel.custom_minimum_size = Vector2(388, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(388, _viewport_h() * 0.62)
	_panel.add_child(sc)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	sc.add_child(vbox)
	_rows.clear()

	_add_title(vbox, "实时调参 — 拖滑块即时生效")

	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("tunables"):
		_add_section(vbox, "主角", pl)

	var en := _current_enemy()
	if en:
		_add_section(vbox, _name_of(en), en)
	else:
		_add_title(vbox, "(当前没有怪，等下一波出场再开)")

	# 操作行
	var ops := HBoxContainer.new()
	var refresh := Button.new()
	refresh.text = "刷新"
	refresh.custom_minimum_size = Vector2(80, 40)
	refresh.pressed.connect(func(): _toggle_panel(); _toggle_panel())
	ops.add_child(refresh)
	var exp := Button.new()
	exp.text = "导出数值"
	exp.custom_minimum_size = Vector2(110, 40)
	exp.pressed.connect(_export_values)
	ops.add_child(exp)
	vbox.add_child(ops)

	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 14)
	_readout.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.custom_minimum_size = Vector2(370, 0)
	vbox.add_child(_readout)

	_layer.add_child(_panel)

func _add_title(vbox: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	vbox.add_child(l)

func _add_section(vbox: VBoxContainer, header: String, obj: Object) -> void:
	var h := Label.new()
	h.text = "— %s —" % header
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vbox.add_child(h)
	if obj.has_method("tunables"):
		for entry in obj.call("tunables"):
			_add_slider(vbox, obj, entry)
	# 每个角色都附带受击框三项(对齐身体用)
	if obj.has_method("body_tunables"):
		for entry in obj.call("body_tunables"):
			_add_slider(vbox, obj, entry)
	# 锁血开关
	if "lock_hp" in obj:
		var chk := CheckButton.new()
		chk.text = "锁血(不掉血)"
		chk.button_pressed = obj.get("lock_hp")
		chk.add_theme_font_size_override("font_size", 15)
		chk.toggled.connect(func(on: bool): obj.set("lock_hp", on))
		vbox.add_child(chk)

func _add_slider(vbox: VBoxContainer, obj: Object, entry: Dictionary) -> void:
	var prop: String = entry["name"]
	var step: float = float(entry.get("step", 1.0))
	var row := HBoxContainer.new()
	var lbl := Label.new()
	var cur: float = float(obj.get(prop))
	lbl.text = "%s  %s" % [entry.get("label", prop), _fmt(cur, step)]
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.custom_minimum_size = Vector2(168, 0)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = float(entry["min"])
	s.max_value = float(entry["max"])
	s.step = step
	s.value = cur
	s.custom_minimum_size = Vector2(200, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	vbox.add_child(row)
	var label_text: String = entry.get("label", prop)
	s.value_changed.connect(func(v: float):
		obj.set(prop, v)
		lbl.text = "%s  %s" % [label_text, _fmt(v, step)])
	_rows.append({"obj": obj, "name": prop, "label": label_text, "step": step})

func _export_values() -> void:
	var lines: Array = []
	for r in _rows:
		if not is_instance_valid(r["obj"]):
			continue
		lines.append("%s.%s = %s" % [_name_of(r["obj"]), r["name"], _fmt(float(r["obj"].get(r["name"])), r["step"])])
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	if _readout:
		_readout.text = "已拷到剪贴板（也发我这串就行）:\n" + text

func _name_of(o: Object) -> String:
	var scr: Variant = o.get_script()
	if scr is Script:
		var n: String = (scr as Script).get_global_name()
		if n != "":
			return n
	return "obj"

func _fmt(v: float, step: float) -> String:
	return ("%.2f" % v) if step < 1.0 else str(int(round(v)))

func _viewport_h() -> float:
	return get_viewport().get_visible_rect().size.y
