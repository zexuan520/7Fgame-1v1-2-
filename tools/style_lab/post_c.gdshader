shader_type canvas_item;
// 青绿：移轴（上下糊、中间清楚），像在看桌上的微缩模型
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec2 uv = SCREEN_UV;
	float b = smoothstep(0.16, 0.48, abs(uv.y - 0.56));
	vec3 c = textureLod(screen, uv, b * 2.6).rgb;
	float vig = smoothstep(0.55, 1.0, length((uv - 0.5) * vec2(1.2, 1.0)));
	c = mix(c, c * vec3(0.82, 0.86, 0.9), vig);
	COLOR = vec4(c, 1.0);
}
