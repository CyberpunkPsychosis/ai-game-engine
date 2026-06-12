extends Node2D
class_name TSBoss
## 悬龙 Boss(飞行残响)。接统一时间系统:被全场定格/单体冻结时——
## 身体波动停 + 染蓝(同 enemy 的契约,用 game.scale_for(frozen_t))。
##
## 飞行/盘旋/俯冲全靠程序化(正弦弧 + 波动 shader),不靠逐帧动画。
## 美术未就位时用占位锥形蛇身贴图;真龙立绘一出,set_texture() 即可替换。

var game
var hp := 600.0
var maxhp := 600.0
var frozen_t := 0.0
var flash_t := 0.0

var _spr: Sprite2D
var _mat: ShaderMaterial
var _wave := 0.0          # 波动累计时间(受 sdt 控)
var _t := 0.0            # 飞行相位(受 sdt 控)
var _home := Vector2(640.0, 200.0)
var _dive_cd := 4.0
var _diving := false
var _dive_t := 0.0

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://timestop/wave.gdshader")
	_spr = Sprite2D.new()
	_spr.material = _mat
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.texture = _placeholder_tex()
	_spr.scale = Vector2(1.8, 1.8)
	add_child(_spr)
	position = _home

## 真龙立绘就位后调它替换占位
func set_texture(t: Texture2D) -> void:
	_spr.texture = t

func take_hit(dmg: float) -> void:
	hp -= dmg
	flash_t = 0.08

func _process(delta: float) -> void:
	frozen_t = maxf(0.0, frozen_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	var s: float = game.scale_for(frozen_t) if game else 1.0
	_mat.set_shader_parameter("freeze", 1.0 - s)
	_spr.modulate = Color(2.0, 2.0, 2.0) if flash_t > 0.0 else Color.WHITE
	if s <= 0.0:
		return                       # 冻结/定格 → 波动与飞行全停
	var sdt := delta * s
	_wave += sdt
	_t += sdt
	_mat.set_shader_parameter("wave_time", _wave)
	_fly(sdt)

func _fly(sdt: float) -> void:
	_dive_cd -= sdt
	if not _diving and _dive_cd <= 0.0:
		_diving = true
		_dive_t = 1.4
		_dive_cd = randf_range(4.0, 6.0)
	if _diving:
		_dive_t -= sdt
		var px: float = game.player.position.x if game else _home.x
		position.x = lerpf(position.x, px, minf(1.0, sdt * 2.2))
		position.y = lerpf(position.y, game.GROUND - 130.0, minf(1.0, sdt * 2.2))
		if _dive_t <= 0.0:
			_diving = false
	else:
		position.x = _home.x + sin(_t * 0.6) * 360.0
		position.y = _home.y + sin(_t * 1.3) * 40.0
	if game:
		_spr.flip_h = game.player.position.x < position.x

## 占位贴图:一条横向锥形蛇身(待真龙立绘替换)
func _placeholder_tex() -> Texture2D:
	var W := 200
	var H := 76
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(W):
		var t := float(x) / float(W)
		var rad := (1.0 - t) * 28.0 + 6.0
		var cy := float(H) * 0.5 + sin(t * 9.0) * 11.0
		for y in range(H):
			if absf(float(y) - cy) <= rad:
				var edge := absf(float(y) - cy) > rad - 2.0
				img.set_pixel(x, y, Color(0.10, 0.16, 0.22) if edge else Color(0.30, 0.55, 0.70))
	return ImageTexture.create_from_image(img)
