// 画面后期（盖在 3D 画面上的全屏矩形）：调色、移轴微缩、暗角、轻微色差、胶片颗粒、闪屏。
// Bloom 用 WorldEnvironment 自带的 Glow（兼容渲染器也支持），这里不再做。
// 2026-11-07 画面改造：
//   移轴微缩：画面上下两条带子按离焦点带的远近做圆盘模糊（12 个采样点），中间人物清清楚楚，远处的墙和地面糊开，
//            斜俯视的体素房间看着像桌上的微缩模型；
//   分区调色：暗部偏冷、亮部偏暖（ArpgMain 按区域换 shadow_tint / highlight_tint），整片青绿里拉出冷暖对比；
//   颗粒：很淡的一层动态噪点，大块平涂的暗部不再“死”。
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette = 0.5;
uniform float aberration = 0.00035;
uniform vec3 shadow_tint = vec3(0.0, 0.05, 0.09);
uniform vec3 highlight_tint = vec3(1.05, 1.0, 0.92);
uniform float saturation = 1.0;
uniform float contrast = 1.06;
uniform float tilt = 1.0;             // 移轴强度（0 关）
uniform float tilt_focus = 0.55;      // 焦点带中心（屏幕 y，0 顶 1 底；主角在画面中间略下）
uniform float tilt_band = 0.2;        // 焦点带半宽，带内完全清楚
uniform float tilt_px = 3.2;          // 最远处模糊半径（像素，按 720 高算）
uniform float grain = 0.025;
uniform vec4 flash = vec4(0.0);       // 全屏闪（大招白、终结红）
uniform float hurt = 0.0;             // 主角挨打时四周泛红
uniform float impact = 0.0;           // 冲击帧：1 时整屏变成黑底白影的高反差画面（只亮一两帧）

const vec2 DISC[12] = vec2[](
	vec2(1.0, 0.0), vec2(0.5, 0.866), vec2(-0.5, 0.866), vec2(-1.0, 0.0), vec2(-0.5, -0.866), vec2(0.5, -0.866),
	vec2(0.5, 0.0), vec2(0.25, 0.433), vec2(-0.25, 0.433), vec2(-0.5, 0.0), vec2(-0.25, -0.433), vec2(0.25, -0.433));

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dc = uv - 0.5;
	float r2 = dot(dc, dc);
	vec2 off = dc * r2 * aberration * 40.0;
	vec3 c;
	c.r = texture(screen, uv - off).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv + off).b;
	// 移轴：离焦点带越远糊得越开（上边比下边糊得多：上边是远处）
	float dy = uv.y - tilt_focus;
	float blur = smoothstep(tilt_band, tilt_band + 0.32, abs(dy) * (dy < 0.0 ? 1.15 : 0.9)) * tilt;
	if (blur > 0.01) {
		vec2 px = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) * (tilt_px / 720.0) * blur;
		vec3 acc = c;
		for (int i = 0; i < 12; i++) {
			acc += texture(screen, uv + DISC[i] * px).rgb;
		}
		c = mix(c, acc / 13.0, smoothstep(0.0, 0.35, blur));
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	// 冷暗暖亮
	c = mix(c + shadow_tint * (1.0 - smoothstep(0.0, 0.45, l)), c * highlight_tint, smoothstep(0.2, 0.8, l));
	c = (c - 0.5) * contrast + 0.5;
	vec2 d = dc * vec2(1.0, 0.8);
	float vig = smoothstep(0.2, 0.75, length(d));
	c *= 1.0 - vignette * vig;
	c = mix(c, vec3(0.55, 0.02, 0.04), hurt * vig);
	c += (hash(uv * 911.0 + fract(TIME * 7.13)) - 0.5) * grain;
	// 冲击帧：亮处白、暗处近黑，带一点青，像漫画里定格的那一格
	float il = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 ink = mix(vec3(0.015, 0.02, 0.03), vec3(0.94, 1.0, 1.0), smoothstep(0.13, 0.2, il));
	c = mix(c, ink, impact);
	c = mix(c, flash.rgb, flash.a);
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
