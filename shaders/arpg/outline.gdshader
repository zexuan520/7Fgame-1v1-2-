// 外描边：背面往外撑开一圈画成深色（只给角色用，场景件不描边省性能）。
// 体素模型表面是一级级台阶，背面沿法线撑开 0.5 格会从前面的台阶里冒出来，人身上一道道竖条纹（主角兜帽“毛糙”）。
// 现在描边在视空间里再往后推 depth_push 米：被模型自己挡住的部分全藏到身后，只剩轮廓外那一圈。
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

uniform vec3 outline_color : source_color = vec3(0.02, 0.03, 0.05);
uniform float width = 0.5;   // 模型单位（体素格）
uniform float depth_push = 0.09;

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX + NORMAL * width, 1.0);
	v.z -= depth_push;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = outline_color;
}
