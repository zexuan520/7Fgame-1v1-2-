// 自发光体素（纸窗、灯笼、樱花、符文）：顶点色直接发光，energy > 1 时让 Bloom 吃到。
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform float energy = 1.6;
uniform float fade = 1.0;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * energy;
	if (fade < 0.999) {
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (fade < (bayer[y * 4 + x] + 0.5) / 16.0) {
			discard;
		}
	}
}
