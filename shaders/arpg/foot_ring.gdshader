// 主角脚下的冷却圆环：内圈青色 = 突进斩冷却，中圈红色 = 终结技冷却，外圈金色细线 = 气力（满了才能放光束斩）。
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float dash = 1.0;
uniform float finish = 1.0;
uniform float energy = 0.0;

float arc(vec2 p, float r, float w, float fill) {
	float d = length(p);
	float band = smoothstep(w, w * 0.4, abs(d - r));
	float a = atan(p.x, -p.y) / 6.28318 + 0.5;   // 0~1，从正上方顺时针
	return band * step(a, fill);
}

void fragment() {
	vec2 p = UV - 0.5;
	vec3 c = vec3(0.0);
	float ready_d = step(0.999, dash);
	c += vec3(0.2, 0.9, 1.0) * arc(p, 0.30, 0.018, dash) * mix(0.6, 1.3, ready_d);
	float ready_f = step(0.999, finish);
	c += vec3(1.0, 0.2, 0.25) * arc(p, 0.355, 0.014, finish) * mix(0.5, 1.2, ready_f);
	float full = step(0.999, energy);
	c += vec3(1.0, 0.8, 0.35) * arc(p, 0.42, 0.012, energy) * mix(0.6, 1.8, full);
	// 底下一圈很淡的圆，把主角从地面上托出来
	c += vec3(0.1, 0.35, 0.4) * smoothstep(0.32, 0.0, length(p)) * 0.25;
	ALBEDO = c;
}
