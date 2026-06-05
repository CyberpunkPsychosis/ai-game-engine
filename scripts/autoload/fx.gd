extends Node
## 通用视觉/音效工具箱。autoload 名: FX
## - FX.flash(sprite)        受击整体闪白(着色器)
## - FX.screen_flash(col,a)  全屏闪光
## - FX.dissolve(sprite)     死亡溶解(放大+淡出)
## - FX.sfx("hit")           播 assets/sfx/hit.wav(没有就静默，方便以后补音效)

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
var _layer: CanvasLayer
var _rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new(); _layer.layer = 80; add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = Color(1, 1, 1, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)

func flash(ci: CanvasItem, dur := 0.12, col := Color(1, 1, 1)) -> void:
	if ci == null or not is_instance_valid(ci): return
	var mat := ci.material as ShaderMaterial
	if mat == null or mat.shader != FLASH_SHADER:
		mat = ShaderMaterial.new(); mat.shader = FLASH_SHADER; ci.material = mat
	mat.set_shader_parameter("flash_color", col)
	mat.set_shader_parameter("flash", 1.0)
	var tw := ci.create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("flash", v), 1.0, 0.0, dur)

func screen_flash(col := Color(1, 1, 1), a := 0.5, dur := 0.18) -> void:
	_rect.color = Color(col.r, col.g, col.b, a)
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, dur)

func dissolve(spr: CanvasItem, dur := 0.2) -> void:
	if spr == null or not is_instance_valid(spr): return
	var tw := spr.create_tween().set_parallel(true)
	tw.tween_property(spr, "scale", spr.scale * 1.4, dur)
	tw.tween_property(spr, "modulate:a", 0.0, dur)

const HOLY_NOVA := preload("res://art/fx/holy_nova.png")
const HOLY_SLASH := preload("res://art/fx/holy_slash.png")

## 在世界坐标播一张序列帧特效（播完自动销毁）。
func play_sheet(tex: Texture2D, cell: Vector2i, fps: float, pos: Vector2, scale := 1.0, flip := false) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpriteSheet.build_from_strips({"e": {"tex": tex, "fps": fps, "loop": false}}, cell)
	spr.animation = "e"
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = Vector2(scale, scale)
	spr.flip_h = flip
	spr.z_index = 200
	scene.add_child(spr)
	spr.play("e")
	spr.animation_finished.connect(spr.queue_free)

## 弹反/拼刀：金色圆形新星
func nova(pos: Vector2, scale := 1.0) -> void:
	play_sheet(HOLY_NOVA, Vector2i(128, 64), 26.0, pos, scale)

## 攻击命中：金色斩光
func slash(pos: Vector2, flip := false, scale := 1.0) -> void:
	play_sheet(HOLY_SLASH, Vector2i(64, 64), 24.0, pos, scale, flip)

## 在世界坐标放一个一次性火花（程序生成，备用）。
func spark(world_pos: Vector2, color := Color(1, 1, 0.7), rays := 6, length := 11.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var n := Node2D.new()
	n.position = world_pos
	n.z_index = 200
	scene.add_child(n)
	for i in range(rays):
		var ln := Line2D.new()
		var ang := TAU * float(i) / float(rays)
		ln.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(ang) * length])
		ln.width = 2.0
		ln.default_color = color
		n.add_child(ln)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector2(2.3, 2.3), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(n.queue_free)

func sfx(name: String, vol := 0.0, pitch := 1.0) -> void:
	var path := "res://assets/sfx/%s.wav" % name
	if ResourceLoader.exists(path):
		AudioManager.play_sfx(load(path), vol, pitch)
