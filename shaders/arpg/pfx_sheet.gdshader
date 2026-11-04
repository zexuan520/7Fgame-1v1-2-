// pixelfx 像素特效精灵表（MIT，github.com/patch-gg/pixelfx）：按 frame 取一格，最近邻采样保住像素感。
// 半透明混合 + 颜色乘 energy（超过 1 让 Bloom 吃到）。billboard 时始终朝镜头，平放时贴在地上。
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec2 grid = vec2(1.0, 1.0);      // 列数、行数
uniform float frame = 0.0;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 1.6;
uniform bool billboard = true;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	float f = floor(frame);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	vec4 t = texture(tex, (cell + UV) / grid);
	ALBEDO = t.rgb * color.rgb * energy;
	ALPHA = t.a * color.a;
}
