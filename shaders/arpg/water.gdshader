// 青井地宫的积水：一层半透明的冰蓝水面，上面两层焦散（Kenney Light Masks · water_caustics）错开流动。
// level 0~1：头目半血后水位上涨，水更亮、更不透明，焦散流得更快。
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D caustic : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.12, 0.34, 0.46, 0.1);
uniform float scale = 0.32;
uniform float level = 0.0;
uniform sampler2D mask : filter_linear;   // 哪里有积水（arena 按地面的“湿”噪声画的）
uniform vec4 rect = vec4(-20.0, -20.0, 40.0, 40.0);
uniform vec3 glint : source_color = vec3(0.45, 0.85, 1.0);   // 焦散的颜色（灯冢的熔铜沟用橙色）
uniform float spread = 1.3;   // level 涨满时没水的地方盖多少

void fragment() {
	vec2 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float sp = 0.035 * (1.0 + level * 1.5);
	float t = TIME * sp;
	float c1 = texture(caustic, wp * scale + vec2(t, t * 0.6)).r;
	float c2 = texture(caustic, wp * scale * 1.37 - vec2(t * 0.7, t)).r;
	float c = pow(c1 * c2, 1.5) * 1.2;
	vec3 col = mix(tint.rgb, tint.rgb * 1.6, level);
	ALBEDO = col + glint * c * (0.45 + level * 0.5);
	float m = texture(mask, (wp - rect.xy) / rect.zw).r;
	float cover = clamp(m + level * spread, 0.0, 1.0);
	ALPHA = cover * clamp(tint.a + level * 0.16 + c * (0.16 + level * 0.12), 0.0, 0.7);
}
