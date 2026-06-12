shader_type canvas_item;
// 全屏后处理叠加层(不读屏幕纹理, GL Compatibility 安全):
//  freeze 0..1 越大越"时停"——暗角加深 + 边缘冷霜脉动 + 细微扫描线
//  flash  0..1 全场定格触发瞬间的白闪
uniform float freeze : hint_range(0.0, 1.0) = 0.0;
uniform float flash  : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5));

	// 暗角(平时淡, 时停时重)
	float vig = smoothstep(0.45, 0.95, d) * (0.30 + 0.55 * freeze);

	// 边缘冷霜, 带呼吸脉动
	float edge = smoothstep(0.30, 1.0, d);
	float frost = edge * freeze * (0.22 + 0.10 * sin(TIME * 5.0));

	// 时停时的细扫描线
	float scan = freeze * 0.04 * (0.5 + 0.5 * sin(uv.y * 850.0 + TIME * 14.0));

	vec3 frost_col = vec3(0.55, 0.78, 1.0);
	vec3 col = frost_col * frost + vec3(1.0) * flash * 0.8;
	float a = vig + frost + scan + flash * 0.55;
	COLOR = vec4(col, clamp(a, 0.0, 0.95));
}
