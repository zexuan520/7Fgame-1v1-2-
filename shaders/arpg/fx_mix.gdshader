// 普通混合的特效贴片（烟、尘、黑色碎屑、雾），不受光照。
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform bool billboard = false;
uniform float soft = 0.0;   // 雾片：离地面近的地方更淡（防止和地面交界出硬边）

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = color.rgb * t.rgb;
	ALPHA = t.a * color.a * COLOR.a;
}
