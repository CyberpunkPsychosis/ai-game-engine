shader_type canvas_item;
// 悬龙身体波动:片元 UV 正弦涟漪(在四边形 Sprite 上也平滑)。
// wave_time 由 boss.gd 用 sdt 累加 → 被冻/定格时不前进 → 波动自动停。
// freeze 0..1 把整体染向冻蓝。

uniform float wave_time = 0.0;
uniform float amp = 0.022;        // UV 振幅
uniform float freq = 9.0;
uniform float speed = 2.2;
uniform float freeze = 0.0;       // 0..1 被冻程度
uniform vec4 freeze_col : source_color = vec4(0.32, 0.86, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * freq + wave_time * speed) * amp;
	uv.y += sin(uv.x * freq * 0.7 + wave_time * speed * 0.8) * amp * 0.5;
	vec4 c = texture(TEXTURE, uv);
	c.rgb = mix(c.rgb, freeze_col.rgb, freeze * 0.55);
	COLOR = c;
}
