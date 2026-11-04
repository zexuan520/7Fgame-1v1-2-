// 外描边：背面往外撑开一圈画成深色（只给角色用，场景件不描边省性能）。
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 outline_color : source_color = vec3(0.02, 0.03, 0.05);
uniform float width = 0.5;   // 模型单位（体素格）

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color;
}
