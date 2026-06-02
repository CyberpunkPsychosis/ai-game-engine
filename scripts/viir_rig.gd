extends Node2D
## Viir 剪纸式绑骨：身体(绕脚)+ 帽子(绕帽檐),代码构建层级 + 一套"施法"动作。
## 用法：实例化后 play_cast()；在释放瞬间发出 released 信号(供生成孢爆)。

signal released

var ap: AnimationPlayer

func _ready() -> void:
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rig/viir/rig.json"))
	var fp: Array = meta["body_pivot"]   # 脚(底部中心)
	var hp: Array = meta["hat_pivot"]    # 帽檐中心
	var body_pivot := Vector2(fp[0], fp[1])
	var hat_pivot := Vector2(hp[0], hp[1])

	# 身体支点(绕脚旋转)
	var bp := Node2D.new(); bp.name = "BodyPivot"; bp.position = body_pivot; add_child(bp)
	var bs := Sprite2D.new(); bs.name = "BodySprite"
	bs.texture = load("res://assets/rig/viir/body.png")
	bs.position = -body_pivot                 # 复原到画幅中心
	bs.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bp.add_child(bs)

	# 帽子支点(绕帽檐旋转，挂在身体下，跟随身体倾斜)
	var hpv := Node2D.new(); hpv.name = "HatPivot"; hpv.position = hat_pivot - body_pivot
	bp.add_child(hpv)
	var hs := Sprite2D.new(); hs.name = "HatSprite"
	hs.texture = load("res://assets/rig/viir/hat.png")
	hs.position = -hat_pivot
	hs.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hpv.add_child(hs)

	ap = AnimationPlayer.new(); add_child(ap)
	var lib := AnimationLibrary.new()
	lib.add_animation("cast", _make_cast(body_pivot))
	ap.add_animation_library("", lib)

func _make_cast(base_pos: Vector2) -> Animation:
	var a := Animation.new()
	a.length = 0.60
	var rot := a.add_track(Animation.TYPE_VALUE); a.track_set_path(rot, "BodyPivot:rotation")
	var pos := a.add_track(Animation.TYPE_VALUE); a.track_set_path(pos, "BodyPivot:position")
	var scl := a.add_track(Animation.TYPE_VALUE); a.track_set_path(scl, "BodyPivot:scale")
	var hat := a.add_track(Animation.TYPE_VALUE); a.track_set_path(hat, "BodyPivot/HatPivot:rotation")
	# 时间, 身体角度°, 身体Y偏移, 身体缩放, 帽子角度°
	var keys := [
		[0.00,   0.0, 0.0,  Vector2(1.00, 1.00),   0.0],
		[0.10, -12.0, 12.0, Vector2(1.05, 0.95), -18.0],   # 后仰蓄力+下蹲
		[0.22,  -4.0,-10.0, Vector2(0.96, 1.06),  -6.0],   # 抬起
		[0.30,  16.0, -4.0, Vector2(1.12, 0.90),  20.0],   # 前倾释放(此刻发招)
		[0.44,   4.0,  0.0, Vector2(0.98, 1.02),   6.0],   # 回收
		[0.60,   0.0,  0.0, Vector2(1.00, 1.00),   0.0],   # 复位
	]
	for k in keys:
		a.track_insert_key(rot, k[0], deg_to_rad(k[1]))
		a.track_insert_key(pos, k[0], base_pos + Vector2(0, k[2]))
		a.track_insert_key(scl, k[0], k[3])
		a.track_insert_key(hat, k[0], deg_to_rad(k[4]))
	return a

func play_cast() -> void:
	ap.stop()
	ap.play("cast")
	var t := get_tree().create_timer(0.30)   # 释放瞬间
	t.timeout.connect(func(): released.emit())
