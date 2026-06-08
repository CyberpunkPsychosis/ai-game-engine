extends CanvasLayer
class_name SurvivorHUD
## 抬头显示 + 弹窗(升级三选一 / 商店 / 结算)。灰盒 UI,纯代码搭建。
## 弹窗在暂停时仍可点(process_mode=ALWAYS);摇杆暂停时停用(PAUSABLE)。

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
var _modal: Control             # 当前弹窗(空=无)

const HP_W := 260.0
const XP_W := 260.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	# 摇杆(最底层,暂停时停用)
	joystick = SurvivorJoystick.new()
	joystick.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(joystick)
	_build_topbar()

func get_joystick() -> SurvivorJoystick:
	return joystick

func _build_topbar() -> void:
	# 血条(左上)
	_panel(Vector2(16, 14), Vector2(HP_W, 26), Color(0, 0, 0, 0.55))
	_hp_fg = ColorRect.new()
	_hp_fg.color = Color(0.85, 0.27, 0.27)
	_hp_fg.position = Vector2(18, 16); _hp_fg.size = Vector2(HP_W - 4, 22)
	add_child(_hp_fg)
	_hp_lbl = _label("", Vector2(22, 16), 18, HORIZONTAL_ALIGNMENT_LEFT)
	_hp_lbl.size = Vector2(HP_W, 22)
	# 经验条(血条下面)
	_panel(Vector2(16, 44), Vector2(XP_W, 12), Color(0, 0, 0, 0.55))
	_xp_fg = ColorRect.new()
	_xp_fg.color = Color(0.4, 0.7, 1.0)
	_xp_fg.position = Vector2(18, 46); _xp_fg.size = Vector2(0, 8)
	add_child(_xp_fg)
	_lvl_lbl = _label("Lv.1", Vector2(16 + XP_W + 8, 40), 18, HORIZONTAL_ALIGNMENT_LEFT)
	# 波次 + 计时(顶部中间)
	_wave_lbl = _label("第 1 波", Vector2(540, 12), 24, HORIZONTAL_ALIGNMENT_CENTER)
	_wave_lbl.size = Vector2(200, 30)
	_timer_lbl = _label("", Vector2(540, 40), 20, HORIZONTAL_ALIGNMENT_CENTER)
	_timer_lbl.size = Vector2(200, 26)
	# 材料 + 击杀(右上)
	_mat_lbl = _label("材料 0", Vector2(1040, 16), 22, HORIZONTAL_ALIGNMENT_RIGHT)
	_mat_lbl.size = Vector2(220, 26)
	_kill_lbl = _label("击杀 0", Vector2(1040, 44), 16, HORIZONTAL_ALIGNMENT_RIGHT)
	_kill_lbl.size = Vector2(220, 22)

func _process(_delta: float) -> void:
	if not (is_instance_valid(player) and is_instance_valid(arena)):
		return
	var ratio: float = clampf(player.hp / player.stats.max_hp, 0.0, 1.0)
	_hp_fg.size.x = (HP_W - 4) * ratio
	_hp_lbl.text = "%d / %d" % [ceili(player.hp), int(player.stats.max_hp)]
	_xp_fg.size.x = XP_W * clampf(float(arena.xp) / maxf(1.0, float(arena.xp_to_next)), 0.0, 1.0)
	_lvl_lbl.text = "Lv.%d" % arena.level
	_wave_lbl.text = "第 %d 波" % arena.wave
	_timer_lbl.text = "%0.0f" % ceil(arena.wave_clock)
	_mat_lbl.text = "材料 %d" % arena.materials
	_kill_lbl.text = "击杀 %d" % arena.kills

# ---------------- 弹窗 ----------------
func _open_modal(title: String) -> VBoxContainer:
	_close_modal()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	add_child(root)
	_modal = root
	return vbox

func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null

func show_level_up(options: Array) -> void:
	var vbox := _open_modal("升级！选一个")
	for up in options:
		var b := _big_button(String(up["name"]), up.get("color", Color.WHITE))
		b.pressed.connect(func() -> void:
			arena.choose_upgrade(up)
			_close_modal())
		vbox.add_child(b)

func show_shop(offers: Array) -> void:
	var vbox := _open_modal("商店 · 第 %d 波结束" % arena.wave)
	for offer in offers:
		var b := _big_button("%s   [%d 材料]" % [offer["name"], offer["price"]], offer.get("color", Color.WHITE))
		b.pressed.connect(_on_buy.bind(offer, b))
		vbox.add_child(b)
	var nxt := _big_button("▶ 进入下一波", Color(0.5, 1.0, 0.6))
	nxt.pressed.connect(func() -> void:
		_close_modal()
		arena.start_next_wave())
	vbox.add_child(nxt)

func _on_buy(offer: Dictionary, btn: Button) -> void:
	if arena.buy_offer(offer):
		btn.text = "✓ 已购买"
		btn.disabled = true

func show_game_over() -> void:
	var vbox := _open_modal("阵亡")
	var s := Label.new()
	s.text = "撑到第 %d 波 · 击杀 %d · 材料 %d" % [arena.wave, arena.kills, arena.materials]
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(s)
	var b := _big_button("重新开始", Color(0.6, 0.9, 1.0))
	b.pressed.connect(func() -> void: arena.restart())
	vbox.add_child(b)

# ---------------- 小工具 ----------------
func _label(text: String, pos: Vector2, fsize: int, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.horizontal_alignment = align
	add_child(l)
	return l

func _panel(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos; r.size = sz; r.color = col
	add_child(r)

func _big_button(text: String, tint: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", tint)
	return b
