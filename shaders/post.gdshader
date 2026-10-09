// 画面后期：泛光、调色、暗角，以及处决时的红色闪光。
// 用在显示游戏画面的 SubViewportContainer 上，TEXTURE 是 640×360 的像素画面。
shader_type canvas_item;

uniform float bloom_strength = 0.9;
uniform float bloom_threshold = 0.62;
uniform float vignette = 0.45;
uniform vec3 shadow_tint = vec3(0.10, 0.05, 0.18);
uniform vec3 highlight_tint = vec3(1.04, 0.98, 0.92);
uniform vec4 flash = vec4(0.0);

void fragment() {
	vec2 uv = UV;
	vec3 c = texture(TEXTURE, uv).rgb;

	// 泛光：取周围亮部的平均值加回去
	vec3 glow = vec3(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 o = vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * 2.5;
			float wgt = 1.0 / (1.0 + float(x * x + y * y));
			vec3 s = texture(TEXTURE, uv + o).rgb;
			glow += max(s - bloom_threshold, vec3(0.0)) * wgt;
			total += wgt;
		}
	}
	c += glow / total * bloom_strength * 3.0;

	// 调色：暗部偏紫，亮部偏暖
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c + shadow_tint * (1.0 - l) * 0.6, c * highlight_tint, smoothstep(0.2, 0.8, l));
	c = mix(vec3(l), c, 1.08);

	// 暗角
	vec2 d = (uv - 0.5) * vec2(1.0, 0.75);
	c *= 1.0 - vignette * smoothstep(0.2, 0.62, length(d));

	c = mix(c, flash.rgb, flash.a);
	COLOR = vec4(c, 1.0);
}
