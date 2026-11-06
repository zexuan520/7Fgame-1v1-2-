// 画面后期（盖在 3D 画面上的全屏矩形）：偏冷青绿调色、暗角、轻微色差、闪屏。
// Bloom 用 WorldEnvironment 自带的 Glow（兼容渲染器也支持），这里不再做。
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette = 0.5;
uniform float aberration = 0.00035;
uniform vec3 shadow_tint = vec3(0.02, 0.10, 0.11);
uniform vec3 highlight_tint = vec3(0.96, 1.03, 1.02);
uniform float saturation = 0.9;
uniform vec4 flash = vec4(0.0);       // 全屏闪（大招白、终结红）
uniform float hurt = 0.0;             // 主角挨打时四周泛红
uniform float impact = 0.0;           // 冲击帧：1 时整屏变成黑底白影的高反差画面（只亮一两帧）

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dc = uv - 0.5;
	float r2 = dot(dc, dc);
	vec2 off = dc * r2 * aberration * 40.0;
	vec3 c;
	c.r = texture(screen, uv - off).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv + off).b;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = mix(c + shadow_tint * (1.0 - smoothstep(0.0, 0.5, l)), c * highlight_tint, smoothstep(0.25, 0.85, l));
	vec2 d = dc * vec2(1.0, 0.8);
	float vig = smoothstep(0.18, 0.72, length(d));
	c *= 1.0 - vignette * vig;
	c = mix(c, vec3(0.55, 0.02, 0.04), hurt * vig);
	// 冲击帧：亮处白、暗处近黑，带一点青，像漫画里定格的那一格
	float il = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 ink = mix(vec3(0.015, 0.02, 0.03), vec3(0.94, 1.0, 1.0), smoothstep(0.13, 0.2, il));
	c = mix(c, ink, impact);
	c = mix(c, flash.rgb, flash.a);
	COLOR = vec4(c, 1.0);
}
