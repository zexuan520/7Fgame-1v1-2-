// 敌人脚下的底圈：一圈压暗的软影 + 一道暖色细环，把敌人从同色的地面上托出来（俯视时一眼分得清敌我）。
// 小怪红、精英金、头目粉；主角脚下另有自己的冷却圆环（foot_ring）。
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 ring_color : source_color = vec3(1.0, 0.3, 0.2);
uniform float ring_alpha = 0.75;
uniform float shade = 0.45;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.06, 0.0, abs(d - 0.86));
	float soft = smoothstep(0.95, 0.2, d) * shade;
	ALBEDO = mix(vec3(0.0), ring_color, ring);
	ALPHA = clamp(max(soft, ring * ring_alpha), 0.0, 1.0) * step(d, 1.0);
}
