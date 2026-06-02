extends Node2D
## 《苔光》运行时：读 scene.json → 视差层 + 装饰 + 碰撞 + 标记(出生/弹跳/机关/出口) + 玩家 + 相机 + HUD。

const LEVEL := "res://scenes/level1.json"
const VIIR := preload("res://scenes/viir.tscn")
const MOSSY_BASE := "res://assets/packs/mossy/"
const ANIM_BASE := "res://assets/anim/"
const PARALLAX := {"far":0.30, "back":0.60, "play":1.00, "fore":1.18}
const ZBASE := {"far":-30, "back":-20, "play":0, "fore":40}

var data: Dictionary
var layers := {}            # id -> Node2D
var player: CharacterBody2D
var cam: Camera2D
var kill_y := 999999.0
var _anim_cache := {}       # clip -> SpriteFrames
var _amanifest := {}        # clip -> meta
var time := 0.0
var deaths := 0
var won := false
var lbl_time: Label
var lbl_death: Label
var lbl_win: Label

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(LEVEL))
	var am = JSON.parse_string(FileAccess.get_file_as_string(ANIM_BASE + "manifest.json"))
	for c in am["animations"]:
		_amanifest[c["name"]] = c
	kill_y = float(data.get("kill_y", 999999))
	_build_sky()
	_build_layers()
	_build_instances()
	_build_colliders()
	_build_player()
	_build_markers()
	_build_camera()
	_build_hud()

# —— 天空渐变 ——
func _build_sky() -> void:
	var bg = data["background"]
	var grad := Gradient.new()
	grad.set_color(0, Color(bg["top"]))
	grad.set_color(1, Color(bg["bottom"]))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	gt.width = 16; gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new(); cl.layer = -100
	cl.add_child(tr); add_child(cl)

# —— 视差层节点 ——
func _build_layers() -> void:
	for id in ["far", "back", "play", "fore"]:
		var n := Node2D.new()
		n.name = id
		n.z_index = ZBASE[id]
		n.y_sort_enabled = false
		add_child(n)
		layers[id] = n

# —— 装饰实例(静态零件 + 动画) ——
func _build_instances() -> void:
	for ins in data["instances"]:
		var parent: Node2D = layers.get(ins.get("layer", "play"), layers["play"])
		var node: Node2D
		if ins.has("anim") and ins["anim"] != null:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = _clip_frames(ins["anim"])
			a.play("default")
			a.frame = randi() % max(1, a.sprite_frames.get_frame_count("default"))
			node = a
		else:
			var s := Sprite2D.new()
			s.texture = load(MOSSY_BASE + ins["asset"])
			node = s
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		node.position = Vector2(ins["x"], ins["y"])
		node.scale = Vector2(ins["scale"], ins["scale"])
		node.rotation_degrees = ins.get("rot", 0)
		if ins.get("flipX", false):
			node.scale.x *= -1
		node.modulate.a = ins.get("opacity", 1.0)
		node.z_index = int(ins.get("z", 0))
		parent.add_child(node)

func _clip_frames(clip: String) -> SpriteFrames:
	if _anim_cache.has(clip):
		return _anim_cache[clip]
	var c = _amanifest[clip]
	var tex: Texture2D = load(ANIM_BASE + c["file"])
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", c["fps"])
	sf.set_animation_loop("default", true)
	var fw := int(c["fw"]); var fh := int(c["fh"]); var cols := int(c["cols"]); var cnt := int(c["count"])
	for i in cnt:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		sf.add_frame("default", at)
	_anim_cache[clip] = sf
	return sf

# —— 碰撞(实心矩形) ——
func _build_colliders() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1   # world
	layers["play"].add_child(body)
	for c in data.get("colliders", []):
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(c["w"], c["h"])
		cs.shape = rect
		cs.position = Vector2(c["x"] + c["w"] / 2.0, c["y"] + c["h"] / 2.0)
		body.add_child(cs)

# —— 玩家 ——
func _build_player() -> void:
	player = VIIR.instantiate()
	var sp = _marker("spawn")
	var pos := Vector2(sp["x"], sp["y"]) if sp else Vector2(200, 200)
	player.spawn_point = pos
	player.global_position = pos
	layers["play"].add_child(player)

# —— 标记：敌人(弹跳)/机关(致死)/出口(过关) ——
func _build_markers() -> void:
	for m in data["markers"]:
		match m["type"]:
			"enemy":
				_make_area(m, Vector2(150, 80), Color(1, 0.4, 0.4, 0.0), "_on_bounce")
			"hazard":
				_make_area(m, Vector2(150, 150), Color(1, 0.7, 0.2, 0.0), "_on_hazard")
			"exit":
				_make_area(m, Vector2(160, 220), Color(0.4, 0.9, 0.9, 0.0), "_on_exit")

func _make_area(m: Dictionary, size: Vector2, _c: Color, cb: String) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2     # 只检测玩家(layer2)
	area.position = Vector2(m["x"], m["y"])
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	area.add_child(cs)
	area.body_entered.connect(Callable(self, cb).bind(area))
	layers["play"].add_child(area)

func _on_bounce(body: Node, _area: Area2D) -> void:
	if body == player and player.velocity.y > -50.0:
		player.bounce()

func _on_hazard(body: Node, _area: Area2D) -> void:
	if body == player:
		_kill()

func _on_exit(body: Node, _area: Area2D) -> void:
	if body == player and not won:
		_win()

func _marker(type: String):
	for m in data["markers"]:
		if m["type"] == type:
			return m
	return null

# —— 相机 ——
func _build_camera() -> void:
	cam = Camera2D.new()
	var vh := float(data["view"]["h"])
	var screen_h := float(get_viewport().get_visible_rect().size.y)
	cam.zoom = Vector2(screen_h / vh, screen_h / vh)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(data["world"]["width"])
	cam.limit_bottom = int(data["world"]["height"])
	add_child(cam)

# —— HUD ——
func _build_hud() -> void:
	var cl := CanvasLayer.new(); cl.layer = 50; add_child(cl)
	lbl_time = _hud_label(cl, Vector2(16, 12), 22)
	lbl_death = _hud_label(cl, Vector2(16, 40), 18)
	lbl_win = _hud_label(cl, Vector2(0, 0), 40)
	lbl_win.set_anchors_preset(Control.PRESET_CENTER)
	lbl_win.position = Vector2(-160, -40)
	lbl_win.visible = false

func _hud_label(cl: CanvasLayer, pos: Vector2, sz: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(0.85, 1, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.12))
	l.add_theme_constant_override("outline_size", 4)
	cl.add_child(l)
	return l

func _kill() -> void:
	deaths += 1
	player.respawn()

func _win() -> void:
	won = true
	lbl_win.visible = true
	lbl_win.text = "孢心点亮!\n%.2f 秒  死亡%d" % [time, deaths]

func _process(delta: float) -> void:
	# 视差：层位置 = 相机位置 * (1 - 视差系数)
	if cam:
		for id in layers:
			if id == "play": continue
			layers[id].position = cam.global_position * (1.0 - PARALLAX[id])
		cam.global_position = player.global_position
	if player and player.global_position.y > kill_y:
		_kill()
	if not won:
		time += delta
		lbl_time.text = "时间 %.2f" % time
		lbl_death.text = "死亡 %d" % deaths
	# 重开
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().reload_current_scene()
