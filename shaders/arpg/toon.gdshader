// 卡通渲染：顶点色当底色（体素网格把颜色写在顶点上），三阶光照 + 边缘光 + 受击闪白。
// 每个角色一份材质（闪白、染色互不影响）；场景件共用一份。
shader_type spatial;
render_mode cull_back;

uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 rim_color : source_color = vec3(0.45, 0.95, 1.0);
uniform float rim_strength = 0.35;
uniform float rim_power = 3.0;
uniform float flash = 0.0;            // 受击闪白 0~1
uniform vec3 flash_color : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(0.0);   // 自发光（Bloom 只让超亮的东西发光）
uniform float shadow_floor = 0.32;    // 最暗那一阶的亮度
uniform float fade = 1.0;             // 前景遮挡时的半透明（用抖动镂空，不用排序）
uniform bool swap_green = false;      // 把模型里偏绿的颜色（KayKit 游侠的兜帽）换成 swap_color，保留明暗
uniform vec3 swap_color : source_color = vec3(0.2, 0.25, 0.4);
uniform float mono = 0.0;             // 去色（铜像、石像：先变灰再乘 tint）
uniform float swap_glow = 0.0;        // 换色那块自己亮一点（金身：不管什么颜色的灯照着都保住金色）
uniform float light_neutral = 0.0;    // 灯光去色 0~1：彩色灯照上来按亮度算，不染色（金身在青光下不发绿）
uniform float face_mul = 1.0;         // 体素面明暗的强度倍数（角色 1，场景件 1）
// 全局（ArpgMain._apply_zone_env 按区域设）：半球环境光（顶面吃天光、底面吃地面反光）+ 体素面明暗
// 兼容渲染器的环境光是一整片平涂，同一块体素朝哪边都一样亮，方块就“糊”成一团；按世界法线分面压暗，块块分明
global uniform vec4 hemi_sky;
global uniform vec4 hemi_ground;
global uniform float face_shade;

void fragment() {
	vec3 src = pow(COLOR.rgb, vec3(2.2));   // 顶点色按 sRGB 存，换成线性再算光照
	vec3 swap_emit = vec3(0.0);
	if (swap_green) {
		float g = src.g - max(src.r, src.b);
		if (g > 0.05) {
			float lum = dot(src, vec3(0.3, 0.59, 0.11));
			src = swap_color * lum * 2.2;
			swap_emit = src * swap_glow;
		}
	}
	src = mix(src, vec3(dot(src, vec3(0.3, 0.55, 0.15))), mono);
	vec3 base = src * tint;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// 顶面最亮；左右侧面压一点、朝镜头的正面压多一点（斜俯视看得最多的是顶面和正面，两者拉开才有体积）
	float fs = face_shade * face_mul;
	float face = 1.0 - fs * (abs(wn.x) * 0.3 + max(wn.z, 0.0) * 0.48 + max(-wn.z, 0.0) * 0.4 + max(-wn.y, 0.0) * 0.7);
	// 顶点色 alpha < 1 = 发光格（锻造台角色的眼睛、灯火）：不压明暗，自己发光
	float self_lit = 1.0 - COLOR.a;
	base *= mix(face, 1.0, step(0.01, self_lit));
	ALBEDO = mix(base, flash_color, flash);
	vec3 hemi = mix(hemi_ground.rgb, hemi_sky.rgb, wn.y * 0.5 + 0.5);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, rim_power);
	EMISSION = base * self_lit * 6.0 + glow + swap_emit + rim_color * rim * rim_strength + flash_color * flash * 1.6 + base * hemi * (1.0 - flash);
	if (fade < 0.999) {
		// 屏幕空间 4x4 抖动：不用透明排序也能“半透明”
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (fade < (bayer[y * 4 + x] + 0.5) / 16.0) {
			discard;
		}
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// 三阶：暗 / 中 / 亮，过渡很窄
	float band = mix(shadow_floor, 0.68, smoothstep(-0.02, 0.04, ndl));
	band = mix(band, 1.0, smoothstep(0.45, 0.5, ndl));
	float sh = smoothstep(0.3, 0.6, ATTENUATION);
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.3, 0.59, 0.11))), light_neutral);
	DIFFUSE_LIGHT += lc * mix(shadow_floor, band, sh) / 3.14159;
}
