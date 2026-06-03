extends Sprite2D
## 残影：拷贝当前帧的渐隐分身，约 0.26s 消失。setup() 传入贴图/位置/缩放/翻转。

var _t := 0.0
const DUR := 0.26
var _a0 := 0.55

func setup(tex: Texture2D, gpos: Vector2, sc: Vector2, flip: bool, tint := Color(0.55, 0.85, 1.0)) -> void:
	texture = tex
	global_position = gpos
	scale = sc
	flip_h = flip
	z_index = -2
	modulate = Color(tint.r, tint.g, tint.b, _a0)

func _process(delta: float) -> void:
	_t += delta
	modulate.a = lerpf(_a0, 0.0, clampf(_t / DUR, 0.0, 1.0))
	if _t >= DUR:
		queue_free()
