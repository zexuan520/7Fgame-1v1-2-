shader_type canvas_item;
// 低画质用的轻量后期：不读屏幕贴图（省一次整屏拷贝），只画暗角、受伤泛红、全屏闪。
// 参数名和 post3d 一样，Feel 照常设置 flash / hurt。

uniform float vignette = 0.38;
uniform vec4 flash = vec4(0.0);
uniform float hurt = 0.0;
uniform float impact = 0.0;   // 冲击帧：低画质读不到屏幕，压一层半透明暗色代替

void fragment() {
	vec2 dc = UV - 0.5;
	vec2 d = dc * vec2(1.0, 0.8);
	float vig = smoothstep(0.18, 0.72, length(d));
	vec3 c = vec3(0.0);
	float a = vignette * vig;
	float h = hurt * vig;
	c = mix(c, vec3(0.55, 0.02, 0.04), h);
	a = a + h * (1.0 - a);
	c = mix(c, vec3(0.01, 0.02, 0.03), impact);
	a = a + impact * 0.55 * (1.0 - a);
	c = mix(c, flash.rgb, flash.a);
	a = a + flash.a * (1.0 - a);
	COLOR = vec4(c, a);
}
