// 地面：和 toon.gdshader 同一套三阶光照，底色从一张“一像素 = 一格地面”的贴图取（最近邻，不插值），
// 不再给每格拼一个四边形——大房间十几万格也只有几块平面，手机上省顶点。
// 贴图按 sRGB 存（和体素顶点色一样），这里先 pow 2.2 换线性。
shader_type spatial;
render_mode cull_back;

uniform sampler2D floor_tex : filter_nearest, repeat_disable;
uniform vec4 floor_rect = vec4(-25.0, -20.0, 50.0, 40.0);   // 贴图覆盖的世界范围：x0, z0, 宽, 深
uniform vec3 rim_color : source_color = vec3(0.45, 0.95, 1.0);
uniform float rim_strength = 0.12;
uniform float shadow_floor = 0.38;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = (world_xz - floor_rect.xy) / floor_rect.zw;
	vec3 src = pow(texture(floor_tex, uv).rgb, vec3(2.2));
	ALBEDO = src;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_color * pow(1.0 - ndv, 3.0) * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = mix(shadow_floor, 0.68, smoothstep(-0.02, 0.04, ndl));
	band = mix(band, 1.0, smoothstep(0.45, 0.5, ndl));
	float sh = smoothstep(0.3, 0.6, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(shadow_floor, band, sh) / 3.14159;
}
