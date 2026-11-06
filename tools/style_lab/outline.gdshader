shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, skip_vertex_transform, cull_disabled, blend_mix;
// 屏幕空间描边：相邻像素深度差大就画墨线（远处自动变细变淡）
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 ink : source_color = vec4(0.08, 0.08, 0.1, 1.0);
uniform float strength = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin(vec2 uv, mat4 inv) {
	float d = texture(depth_tex, uv).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float c = lin(SCREEN_UV, INV_PROJECTION_MATRIX);
	float e = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 o = vec2(i == 0 ? 1.0 : (i == 1 ? -1.0 : 0.0), i == 2 ? 1.0 : (i == 3 ? -1.0 : 0.0)) * px * 1.5;
		float n = lin(SCREEN_UV + o, INV_PROJECTION_MATRIX);
		e = max(e, abs(n - c));
	}
	float a = smoothstep(0.06, 0.2, e) * strength * (1.0 - smoothstep(18.0, 30.0, c));
	ALBEDO = ink.rgb;
	ALPHA = a;
}
