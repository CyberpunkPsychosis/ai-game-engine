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

func sfx(name: String, vol := 0.0, pitch := 1.0) -> void:
	var path := "res://assets/sfx/%s.wav" % name
	if ResourceLoader.exists(path):
		AudioManager.play_sfx(load(path), vol, pitch)
