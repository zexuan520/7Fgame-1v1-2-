shader_type canvas_item;
// 墨韵：宣纸纤维纹 + 四角晕墨
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float fib = h(floor(FRAGCOORD.xy / 2.0)) * 0.6 + h(floor(FRAGCOORD.xy * vec2(0.05, 0.5))) * 0.4;
	float vig = smoothstep(0.45, 0.95, length((uv - 0.5) * vec2(1.25, 1.0)));
	COLOR = vec4(mix(vec3(0.95, 0.92, 0.84), vec3(0.18, 0.17, 0.16), vig), fib * 0.07 + vig * 0.38);
}
