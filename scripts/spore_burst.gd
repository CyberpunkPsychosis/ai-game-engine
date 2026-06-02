extends Node2D
## 孢爆特效：扩散光环 + 向外迸发的发光孢子粒子 + 内层光晕，约半秒后自毁。

@export var dur := 0.55
@export var max_r := 340.0
var _t := 0.0

func _ready() -> void:
	z_index = 30
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = 70
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 240.0
	p.initial_velocity_max = 560.0
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 6.0
	p.color = Color(0.78, 1.0, 0.82, 0.95)
	add_child(p)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= dur:
		queue_free()

func _draw() -> void:
	var k: float = clampf(_t / dur, 0.0, 1.0)
	var r: float = max_r * ease(k, 0.4)        # 先快后慢扩散
	var a: float = 1.0 - k
	draw_circle(Vector2.ZERO, r * 0.62, Color(0.6, 1.0, 0.8, a * 0.22))          # 内层光晕
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(0.85, 1.0, 0.88, a * 0.9), 8.0 * (1.0 - k) + 2.0, true)  # 冲击光环
