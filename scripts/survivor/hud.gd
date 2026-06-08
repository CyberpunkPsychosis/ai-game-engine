extends CanvasLayer
class_name SurvivorHUD
## 抬头显示 + 弹窗(升级三选一 / 商店 / 结算)。土豆兄弟式深色像素 UI。
## 弹窗在暂停时仍可点(process_mode=ALWAYS);摇杆暂停时停用。

var arena                       # SurvivorArena
var player                      # SurvivorPlayer
var joystick: SurvivorJoystick

var _hp_fg: ColorRect
var _hp_lbl: Label
var _wave_lbl: Label
var _timer_lbl: Label
var _mat_lbl: Label
var _lvl_lbl: Label
var _xp_fg: ColorRect
var _kill_lbl: Label
var _modal: Control
var _ui_theme: Theme

const HP_W := 300.0
const XP_W := 300.0

# 配色(土豆兄弟式:深底 + 暖色点缀)
const C_PANEL := Color(0.12, 0.11, 0.16, 0.92)
const C_BORDER := Color(0.45, 0.40, 0.55)
const C_GOLD := Color(1.0, 0.82, 0.32)
const C_HP := Color(0.86, 0.27, 0.30)
const C_XP := Color(0.45, 0.70, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_ui_theme = _build_theme()
	joystick = SurvivorJoystick.new()
	joystick.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(joystick)
	_build_topbar()

func get_joystick() -> SurvivorJoystick:
	return joystick

# ---------------- 顶栏 ----------------
func _build_topbar() -> void:
	# 左:血条 + 经验条
	_panel_box(Vector2(14, 12), Vector2(HP_W + 8, 58))
	_hp_fg = _bar(Vector2(20, 18), Vector2(HP_W, 24), C_HP)
	_hp_lbl = _label("", Vector2(26, 19), 20, HORIZONTAL_ALIGNMENT_LEFT, Vector2(HP_W, 24))
	_xp_fg = _bar(Vector2(20, 48), Vector2(0, 12), C_XP)
	_bar_outline(Vector2(20, 48), Vector2(XP_W, 12))
	_lvl_lbl = _label("Lv.1", Vector2(20, 44), 20, HORIZONTAL_ALIGNMENT_LEFT, Vector2(XP_W, 18))
	# 中:波次 + 计时
	_panel_box(Vector2(540, 12), Vector2(200, 58))
	_wave_lbl = _label("第 1 波", Vector2(540, 16), 28, HORIZONTAL_ALIGNMENT_CENTER, Vector2(200, 32))
	_timer_lbl = _label("", Vector2(540, 44), 24, HORIZONTAL_ALIGNMENT_CENTER, Vector2(200, 26), C_GOLD)
	# 右:材料 + 击杀
	_panel_box(Vector2(1010, 12), Vector2(256, 58))
	_mat_lbl = _label("◆ 0", Vector2(1010, 16), 26, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(246, 30), C_GOLD)
	_kill_lbl = _label("击杀 0", Vector2(1010, 46), 18, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(246, 22), Color(0.7, 0.7, 0.8))

func _process(_delta: float) -> void:
	if not (is_instance_valid(player) and is_instance_valid(arena)):
		return
	var ratio: float = clampf(player.hp / player.stats.max_hp, 0.0, 1.0)
	_hp_fg.size.x = HP_W * ratio
	_hp_lbl.text = "%d / %d" % [ceili(player.hp), int(player.stats.max_hp)]
	_xp_fg.size.x = XP_W * clampf(float(arena.xp) / maxf(1.0, float(arena.xp_to_next)), 0.0, 1.0)
	_lvl_lbl.text = "Lv.%d" % arena.level
	_wave_lbl.text = "第 %d 波" % arena.wave
	_timer_lbl.text = "%0.0f" % ceil(arena.wave_clock)
	_mat_lbl.text = "◆ %d" % arena.materials
	_kill_lbl.text = "击杀 %d" % arena.kills

# ---------------- 弹窗 ----------------
func _open_modal(title: String, subtitle := "") -> VBoxContainer:
	_close_modal()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.theme = _ui_theme
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.66)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(480, 0)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.add_theme_font_size_override("font_size", 20)
		s.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(s)
	add_child(root)
	_modal = root
	return vbox

func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null

func show_level_up(options: Array) -> void:
	var vbox := _open_modal("升级！", "选一个强化")
	for up in options:
		var b := _choice_button(String(up["name"]), "", up.get("color", Color.WHITE))
		b.pressed.connect(func() -> void:
			arena.choose_upgrade(up)
			_close_modal())
		vbox.add_child(b)

func show_shop(offers: Array) -> void:
	var vbox := _open_modal("商 店", "第 %d 波结束 · 材料 %d" % [arena.wave, arena.materials])
	for offer in offers:
		var b := _choice_button(String(offer["name"]), "◆ %d" % int(offer["price"]), offer.get("color", Color.WHITE))
		b.pressed.connect(_on_buy.bind(offer, b))
		vbox.add_child(b)
	var nxt := _choice_button("▶  进入下一波", "", Color(0.5, 1.0, 0.6))
	nxt.pressed.connect(func() -> void:
		_close_modal()
		arena.start_next_wave())
	vbox.add_child(nxt)

func _on_buy(offer: Dictionary, btn: Button) -> void:
	if arena.buy_offer(offer):
		btn.text = "✓  " + String(offer["name"])
		btn.disabled = true

func show_game_over() -> void:
	var vbox := _open_modal("阵 亡", "撑到第 %d 波 · 击杀 %d · 材料 %d" % [arena.wave, arena.kills, arena.materials])
	var b := _choice_button("重新开始", "", Color(0.6, 0.9, 1.0))
	b.pressed.connect(func() -> void: arena.restart())
	vbox.add_child(b)

# ---------------- 主题 / 控件工厂 ----------------
func _build_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("panel", "PanelContainer", _sb(Color(0.10, 0.09, 0.14, 0.98), C_BORDER, 3, 10, 22))
	t.set_stylebox("normal", "Button", _sb(Color(0.18, 0.17, 0.24), C_BORDER, 2, 8, 14))
	t.set_stylebox("hover", "Button", _sb(Color(0.26, 0.24, 0.34), C_GOLD, 2, 8, 14))
	t.set_stylebox("pressed", "Button", _sb(Color(0.32, 0.30, 0.42), C_GOLD, 2, 8, 14))
	t.set_stylebox("disabled", "Button", _sb(Color(0.13, 0.13, 0.16), Color(0.3, 0.3, 0.35), 2, 8, 14))
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", Color(0.95, 0.95, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.5))
	return t

func _sb(bg: Color, border: Color, bw: int, radius: int, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

func _choice_button(text: String, right: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = "  " + text + ("      " + right if right != "" else "")
	b.custom_minimum_size = Vector2(440, 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", accent)
	return b

func _label(text: String, pos: Vector2, fsize: int, align: int, sz: Vector2, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func _bar(pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	add_child(r)
	return r

func _bar_outline(pos: Vector2, sz: Vector2) -> void:
	var p := Panel.new()
	p.position = pos - Vector2(2, 2)
	p.size = sz + Vector2(4, 4)
	p.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.0), C_BORDER, 1, 2, 0))
	add_child(p)
	move_child(p, 0)

func _panel_box(pos: Vector2, sz: Vector2) -> void:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", _sb(C_PANEL, C_BORDER, 2, 8, 0))
	add_child(p)
	move_child(p, 1)
