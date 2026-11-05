// 兵器拖尾丝带：UV.y 0 = 刀根一侧，1 = 刀尖一侧；COLOR.a 是新旧（1 = 刚划过）。
// 刀尖那条边最亮最白，往里过渡成青色并变透明；越旧越淡。叠加混合，亮度超过 1 让 Bloom 吃到。
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float energy = 2.6;

void fragment() {
	float fresh = COLOR.a;
	float v = UV.y;
	float rim = smoothstep(0.7, 1.0, v);
	float body = smoothstep(0.0, 0.85, v);
	vec3 c = mix(edge.rgb, core.rgb, rim * fresh);
	float a = body * fresh * fresh * mix(0.45, 1.0, rim);
	ALBEDO = c * a * energy;
}
