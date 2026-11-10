// 地面：和 toon.gdshader 同一套三阶光照，底色从一张“一像素 = 一格地面”的贴图取（最近邻，不插值），
// 不再给每格拼一个四边形——大房间十几万格也只有几块平面，手机上省顶点。
// 贴图按 sRGB 存（和体素顶点色一样），这里先 pow 2.2 换线性。
// 2026-11-07 画面改造：
//   浮雕：朝太阳那边再取一格比亮度，砖缝、石板边、草丛边自己出一道亮边和一道暗边，平贴图看着有高低；
//   接触阴影：另一张低分辨率 AO 图（Arena._bake_floor_ao 按摆设的占地烘出来，线性插值成软边），墙角、柱脚、石头底下压暗；
//   半球环境光：和 toon 一样吃天光。
shader_type spatial;
render_mode cull_back;

uniform sampler2D floor_tex : filter_nearest, repeat_disable;
uniform vec4 floor_rect = vec4(-25.0, -20.0, 50.0, 40.0);   // 贴图覆盖的世界范围：x0, z0, 宽, 深
uniform sampler2D ao_tex : filter_linear, repeat_disable, hint_default_white;
uniform vec4 ao_rect = vec4(-25.0, -20.0, 50.0, 40.0);
uniform float ao_on = 0.0;
uniform vec2 texel = vec2(0.002, 0.0025);   // 地面贴图一格在 uv 里多大
uniform float emboss = 1.5;
uniform vec3 rim_color : source_color = vec3(0.45, 0.95, 1.0);
uniform float rim_strength = 0.12;
uniform float shadow_floor = 0.38;
// 2026-11-10：地面去两成饱和、压暗一点点，人、怪、刀光、预警从地上浮出来（地面是背景，不该和角色抢颜色）
uniform float mute_sat = 0.2;
uniform float mute_dark = 0.05;
global uniform vec4 hemi_sky;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = (world_xz - floor_rect.xy) / floor_rect.zw;
	vec3 src = pow(texture(floor_tex, uv).rgb, vec3(2.2));
	// 浮雕：太阳从左后方来（-x, -z），比左上一格亮 = 这格是“高处的边”，暗 = “落进缝里”
	vec3 nb = pow(texture(floor_tex, uv - texel).rgb, vec3(2.2));
	float l0 = dot(src, vec3(0.3, 0.59, 0.11));
	float l1 = dot(nb, vec3(0.3, 0.59, 0.11));
	float dl = (l0 - l1) / max(l0 + l1, 0.02);
	// 小于 6% 的亮度差是颗粒抖动，不浮雕（不然满地噪点）；大的才是缝和边
	dl = sign(dl) * max(abs(dl) - 0.06, 0.0);
	float e = clamp(dl * emboss, -0.4, 0.5);
	src *= 1.0 + e;
	float ao = 1.0;
	if (ao_on > 0.5) {
		ao = texture(ao_tex, (world_xz - ao_rect.xy) / ao_rect.zw).r;
	}
	src *= ao;
	float lm = dot(src, vec3(0.3, 0.59, 0.11));
	src = mix(src, vec3(lm), mute_sat) * (1.0 - mute_dark);
	ALBEDO = src;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_color * pow(1.0 - ndv, 3.0) * rim_strength * ao + src * hemi_sky.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = mix(shadow_floor, 0.68, smoothstep(-0.02, 0.04, ndl));
	band = mix(band, 1.0, smoothstep(0.45, 0.5, ndl));
	float sh = smoothstep(0.3, 0.6, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(shadow_floor, band, sh) / 3.14159;
}
