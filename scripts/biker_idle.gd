extends Sprite2D
## biker idle：把 192x48 的 Idle2 表当 4 帧循环播放。

@export var fps: float = 8.0
@export var total_frames: int = 4

var _t := 0.0

func _ready() -> void:
	hframes = total_frames
	frame = 0

func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.0 / fps:
		_t -= 1.0 / fps
		frame = (frame + 1) % total_frames
