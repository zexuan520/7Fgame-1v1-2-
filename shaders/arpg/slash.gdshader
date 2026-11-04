// 半月形刀光：网格是一段扇环，UV.x 沿挥砍方向（0 = 刀尾，1 = 刀头），UV.y 从内圈到外圈。
// 蓝白渐变，外缘最亮，尾巴淡出；progress 推动整条刀光向前擦过去再消散。
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float energy = 3.0;
uniform float head = 1.0;     // 刀头位置（0~1，随时间往前走）
uniform float tail_len = 0.85; // 尾巴长度
uniform float fade = 1.0;

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float t = clamp((u - (head - tail_len)) / max(tail_len, 0.001), 0.0, 1.0);
	t *= step(u, head);
	// 月牙：外缘厚、内缘薄，越靠近刀头越宽
	float width = mix(0.06, 0.6, t);
	float d = 1.0 - v;            // 0 = 外缘
	float body = smoothstep(width, width * 0.3, d) * smoothstep(0.0, 0.04, d + 0.02);
	float rim = smoothstep(0.12, 0.0, d);
	vec3 c = mix(edge.rgb * 0.8, core.rgb, rim);
	float a = body * mix(0.35, 1.0, rim) * t * t * fade;
	ALBEDO = c * a * energy;
}
