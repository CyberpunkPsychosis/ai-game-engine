shader_type canvas_item;
// 受击闪白：flash=1 时整体染成 flash_color，按 alpha 保形。
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	COLOR = c * COLOR;
}
