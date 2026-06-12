extends RefCounted
class_name SpriteSheet
## 网格精灵表 → SpriteFrames 的通用切片器。
## 任意角色（主角/敌人/Boss）只要给出「格子尺寸 + 动画布局」就能切，免手搓 .tres。
##
## anims 每项：name -> [row, frames, fps, loop]  或  { row=, frames=, fps=, loop= }

## 每个动画是一张独立的「横条」png（一行若干帧），帧数 = 宽 / cell.x。
## strips 每项：name -> { tex: Texture2D, fps: float, loop: bool }
static func build_from_strips(strips: Dictionary, cell: Vector2i) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name in strips:
		var d: Dictionary = strips[name]
		var tex: Texture2D = d["tex"]
		var fps := float(d.get("fps", 10.0))
		var loop := bool(d.get("loop", true))
		var frames := int(tex.get_width() / cell.x)
		sf.add_animation(name)
		sf.set_animation_speed(name, fps)
		sf.set_animation_loop(name, loop)
		for i in range(frames):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * cell.x, 0, cell.x, cell.y)
			sf.add_frame(name, at)
	return sf

## 单张网格表（多行=多动画）。anims 每项：name -> [row, frames, fps, loop]
static func build(sheet: Texture2D, cell: Vector2i, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name in anims:
		var d = anims[name]
		var row: int
		var frames: int
		var fps: float
		var loop: bool
		if d is Dictionary:
			row = int(d.get("row", 0))
			frames = int(d.get("frames", 1))
			fps = float(d.get("fps", 10.0))
			loop = bool(d.get("loop", true))
		else:  # Array [row, frames, fps, loop]
			row = int(d[0])
			frames = int(d[1])
			fps = float(d[2])
			loop = bool(d[3])
		sf.add_animation(name)
		sf.set_animation_speed(name, fps)
		sf.set_animation_loop(name, loop)
		for i in range(frames):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * cell.x, row * cell.y, cell.x, cell.y)
			sf.add_frame(name, at)
	return sf
