// 兵器拖尾丝带：UV.y 0 = 内缘（往刀根一侧），1 = 刀尖划过的外缘；COLOR.a 是新旧（1 = 刚划过）。
// 2026-11 重做：原来是整把刀长的一片白三角。现在只留刀尖外侧一窄条，分三层色块（外缘一道白线 → 主色 → 淡主色），
// 越旧越窄越淡，并且按台阶淡出（不是一片糊开的渐变），像画出来的一笔。预乘混合：背后压暗一点，亮地面上也看得清。
shader_type spatial;
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float energy = 2.2;
uniform float shade = 0.5;   // 压暗背后多少（0 = 纯叠加）

float aa(float th, float x) {
	float w = max(fwidth(x), 0.0001);
	return smoothstep(th - w, th + w, x);
}

void fragment() {
	float fresh = COLOR.a;
	float v = UV.y;
	// 台阶淡出：新旧分四档
	float f = ceil(fresh * 4.0) / 4.0;
	// 三层：外缘白线（越新越粗）、主色带、淡主色
	float line_w = mix(0.04, 0.16, f);
	float rim = aa(1.0 - line_w, v);
	float band = aa(0.45, v);
	float inner = aa(0.02, v);
	vec3 c = mix(edge.rgb, core.rgb, rim);
	float k = mix(inner * 0.35, 1.0, band);
	k = mix(k, 1.0, rim);
	float a = k * f * mix(0.75, 1.0, rim);
	ALBEDO = c * a * mix(0.9, energy, rim);
	ALPHA = a * shade * (1.0 - rim * 0.4);
}
