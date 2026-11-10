// 半月形刀光：网格是一段扇环，UV.x 沿挥砍方向（0 = 刀尾，1 = 刀头），UV.y 从内圈到外圈。
// 2026-11 重做：月牙加厚（刀头处占环宽七成半），外缘一道利落的白线，里面主色分三档台阶往内淡，
// 预乘混合压暗背后一点：亮地面（古寺、雪地）上也是一道清楚的色弧，不再被冲成一层白雾。
shader_type spatial;
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float energy = 3.0;
uniform float head = 1.0;     // 刀头位置（0~1，随时间往前走）
uniform float tail_len = 0.85; // 尾巴长度
uniform float fade = 1.0;
uniform float shade = 0.55;   // 压暗背后多少

float aa(float th, float x) {
	float w = max(fwidth(x), 0.0001);
	return smoothstep(th - w, th + w, x);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float t = clamp((u - (head - tail_len)) / max(tail_len, 0.001), 0.0, 1.0);
	t *= step(u, head);
	// 月牙：外缘厚、内缘薄，越靠近刀头越宽
	float width = mix(0.08, 0.75, t);
	float d = 1.0 - v;            // 0 = 外缘
	float x = d / max(width, 0.001);   // 0 = 外缘，1 = 月牙内缘
	float body = 1.0 - aa(1.0, x);
	float rim = 1.0 - aa(mix(0.05, 0.16, t) / max(width, 0.001), x);
	// 主色三档：外 1.0、中 0.6、内 0.3
	float steps = 1.0 - floor(clamp(x, 0.0, 0.999) * 3.0) / 3.0;
	float k = mix(steps * 0.9, 1.0, rim);
	vec3 c = mix(edge.rgb, core.rgb, rim);
	float tt = ceil(t * 5.0) / 5.0;   // 尾巴也按台阶收
	float a = body * k * tt * fade;
	ALBEDO = c * a * mix(1.0, energy, rim);
	ALPHA = a * shade * (1.0 - rim * 0.3);
}
