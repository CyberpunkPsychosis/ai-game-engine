extends Sprite2D
## biker idle：4 帧循环；并按每帧"肩部锚点"驱动挂点(Mount)，
## 让挂在上面的胳膊+枪跟随身体的肩部位置(锚点来自拼装工具的标注)。

@export var fps: float = 8.0
@export var total_frames: int = 4
@export var mount_path: NodePath = NodePath("Mount")

# 每帧肩部锚点(帧内像素坐标)，来自工具里你标的点
const SHOULDERS := [
	Vector2(7.5, 25.5),
	Vector2(6.5, 25.5),
	Vector2(6.5, 25.5),
	Vector2(7.5, 25.5),
]
# Body 为居中精灵，48x48 帧的中心
const FRAME_CENTER := Vector2(24, 24)

var _t := 0.0
var _mount: Node2D

func _ready() -> void:
	hframes = total_frames
	_mount = get_node_or_null(mount_path)
	frame = 0
	_apply(0)

func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.0 / fps:
		_t -= 1.0 / fps
		frame = (frame + 1) % total_frames
		_apply(frame)

func _apply(f: int) -> void:
	if _mount:
		_mount.position = SHOULDERS[f % SHOULDERS.size()] - FRAME_CENTER
