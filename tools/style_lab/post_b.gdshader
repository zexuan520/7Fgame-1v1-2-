shader_type canvas_item;
// 夜灯：深紫暗角
void fragment() {
	vec2 uv = SCREEN_UV;
	float vig = smoothstep(0.35, 0.9, length((uv - 0.5) * vec2(1.2, 1.0)));
	COLOR = vec4(0.02, 0.015, 0.06, vig * 0.75);
}
