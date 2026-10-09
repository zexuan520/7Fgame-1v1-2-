shader_type canvas_item;
// 精灵着色：tint 的 rgb 是颜色，a 是染多少（1 = 整个变成这个颜色，受击闪白、残影用）

uniform vec4 tint = vec4(0.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, tint.rgb, tint.a);
	COLOR = c * vec4(1.0, 1.0, 1.0, COLOR.a);
}
