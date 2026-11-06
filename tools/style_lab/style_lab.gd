extends Node3D
## 风格小样台：读 tools/style_lab/models/<方案>/*.json.gz（gen 脚本生成），摆一个小场景，按方案配灯光、雾、后期，拍图退出。
## 不进游戏，不改游戏代码。用法（-- 后面）：
##   --style=a|b|c  --mode=scene|lineup|close  --out=路径.png  --w=1280 --h=720
## 打印 tris= 这一帧画了多少三角形，方便比性能。

const DIR := "res://tools/style_lab/models/%s/%s.json"

var args := {}
var style := "a"
var mode := "scene"
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var glow_mat: ShaderMaterial
var lights := 0
var look_key := ""

## 每套方案：环境、灯光、后期参数
const LOOK := {
	"a": {"bg": Color("d9d2c0"), "amb": Color("f0e8d8"), "amb_e": 0.42, "sun": Color("fff3e0"), "sun_e": 1.1, "sun_rot": Vector3(-55, -40, 0),
		"fog": Color("ddd6c4"), "fog_d": 0.05, "fog_b": 13.0, "fog_e": 30.0, "sat": 0.85, "con": 1.12, "outline": Color("141418"), "glow": false,
		"light": Color("ffe2a8"), "light_e": 1.2},
	"an": {"bg": Color("101014"), "amb": Color("8a8aa0"), "amb_e": 0.16, "sun": Color("aab4d0"), "sun_e": 0.35, "sun_rot": Vector3(-60, 30, 0),
		"fog": Color("141418"), "fog_d": 0.06, "fog_b": 12.0, "fog_e": 28.0, "sat": 0.9, "con": 1.15, "outline": Color("050506"), "glow": true,
		"light": Color("ffd59a"), "light_e": 3.5},
	"b": {"bg": Color("0b0e1c"), "amb": Color("5a4f86"), "amb_e": 0.4, "sun": Color("8fa4ff"), "sun_e": 0.45, "sun_rot": Vector3(-60, 30, 0),
		"fog": Color("1c2140"), "fog_d": 0.06, "fog_b": 12.0, "fog_e": 30.0, "sat": 1.1, "con": 1.1, "outline": Color("05060c"), "glow": true,
		"light": Color("ffae55"), "light_e": 2.6},
	"c": {"bg": Color("e6dcc4"), "amb": Color("b8c8d0"), "amb_e": 0.6, "sun": Color("fff0d8"), "sun_e": 1.35, "sun_rot": Vector3(-50, -30, 0),
		"fog": Color("e6dcc4"), "fog_d": 0.04, "fog_b": 14.0, "fog_e": 34.0, "sat": 1.12, "con": 1.06, "outline": Color("1d2a33"), "glow": false,
		"light": Color("ffd890"), "light_e": 1.0},
}

## 场景摆放：[模型, x, z, 朝向(度), 是否角色]
const LAYOUT := {
	"a": [
		["ground", 0, 0, 0], ["wall", -1.6, -4.0, 0], ["pine0", -6.2, -2.4, 0], ["pine1", 5.6, -4.2, 40],
		["maple", -4.4, -3.9, 0], ["rock2", -5.4, 2.6, 20], ["rock1", 4.9, 2.9, 70], ["rock0", 6.4, 0.6, 0],
		["lantern", -2.8, -2.0, 0], ["stele", -6.6, 0.4, 25],
		["hero", -0.9, 1.0, 35, true], ["slash", -0.9, 1.0, 35],
		["grunt0", 0.9, 0.3, -70, true], ["grunt1", 1.4, 1.7, -110, true], ["grunt2", -2.6, -0.3, 80, true], ["grunt1", 0.2, -1.0, -20, true],
		["boss", 2.9, -2.0, -40, true],
	],
	"b": [
		["ground", 0, 0, 0], ["gate", -0.6, -4.3, 0], ["willow0", -6.0, -2.6, 0], ["willow1", 5.8, -3.8, 50],
		["tomb0", -4.6, 1.8, 15], ["tomb1", -5.8, 0.4, -20], ["tomb0", 5.2, 2.2, -30], ["censer", 3.6, -2.4, 0],
		["lanterns", -3.2, -2.0, 0], ["wisp", -2.0, 2.6, 0], ["wisp", 4.2, 0.4, 0], ["wisp", -5.0, -1.0, 0],
		["hero", -0.9, 1.0, 35, true], ["slash", -0.9, 1.0, 35],
		["grunt0", 0.9, 0.3, -70, true], ["grunt1", 1.5, 1.6, -110, true], ["grunt2", -2.6, -0.3, 80, true], ["grunt0", 0.3, -1.0, -20, true],
		["boss", 2.9, -1.8, -40, true],
	],
	"c": [
		["ground", 0, 0, 0], ["pavilion", -3.6, -3.6, 20], ["bridge", 4.6, 1.8, -10], ["peak0", 6.2, -3.4, 0], ["peak1", -6.6, -1.2, 0],
		["peak2", -5.6, 3.2, 40], ["pine0", 2.2, -4.4, 0], ["pine1", -1.0, -4.8, 60], ["flowers", -2.8, 2.6, 0], ["flowers", 1.8, 3.0, 90],
		["hero", -0.9, 1.0, 35, true], ["slash", -0.9, 1.0, 35],
		["grunt0", 0.9, 0.3, -70, true], ["grunt1", 1.5, 1.6, -110, true], ["grunt2", -2.6, -0.3, 80, true], ["grunt0", 0.3, -1.0, -20, true],
		["boss", 2.9, -1.8, -40, true],
	],
}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	style = String(args.get("style", "a"))
	if args.has("night"):
		look_key = style + "n"
	mode = String(args.get("mode", "scene"))
	VoxelGrid.quant = 64.0
	if mode == "count":
		_count()
		get_tree().quit()
		return
	_env()
	if mode == "lineup":
		_lineup()
	else:
		_scene()
	_post()
	_camera()
	for i in range(8):
		await get_tree().process_frame
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("style=%s mode=%s tris=%d draws=%d lights=%d" % [style, mode, tris, dc, lights])
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(args.get("out", "/tmp/style_%s_%s.png" % [style, mode])))
	get_tree().quit()


func _look() -> Dictionary:
	return LOOK[look_key] if look_key != "" else LOOK[style]


func _env() -> void:
	var L: Dictionary = _look()
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = L["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = L["amb"]
	env.ambient_light_energy = L["amb_e"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = L["fog"]
	env.fog_density = L["fog_d"]
	env.fog_depth_begin = L["fog_b"]
	env.fog_depth_end = L["fog_e"]
	env.adjustment_enabled = true
	env.adjustment_saturation = L["sat"]
	env.adjustment_contrast = L["con"]
	if L["glow"]:
		env.glow_enabled = true
		env.glow_intensity = 1.1
		env.glow_strength = 1.1
		env.glow_hdr_threshold = 0.85
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		env.set_glow_level(1, 1.0)
		env.set_glow_level(2, 0.9)
		env.set_glow_level(3, 0.7)
		env.set_glow_level(4, 0.5)
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	var r: Vector3 = L["sun_rot"]
	sun.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
	sun.light_color = L["sun"]
	sun.light_energy = L["sun_e"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_blur = 1.5
	add_child(sun)
	glow_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nuniform float boost = 1.0;\nvoid fragment(){ ALBEDO = COLOR.rgb * boost; }\n"
	glow_mat.shader = sh
	glow_mat.set_shader_parameter("boost", 1.6 if L["glow"] else 1.0)


func _model(id: String) -> Node3D:
	var path := DIR % [style, id]
	var d := VoxelModel.read_data(path)
	var root := Node3D.new()
	root.name = id
	if d.is_empty():
		push_warning("没有模型 " + path)
		return root
	var vs := float(d["vs"])
	for key: String in ["vox", "glow"]:
		var v: Array = d[key]
		if v.is_empty():
			continue
		var g := VoxelGrid.new(1)
		var sum := Vector3.ZERO
		for i in range(0, v.size(), 6):
			g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
			sum += Vector3(v[i], v[i + 1], v[i + 2])
		var mi := MeshInstance3D.new()
		mi.mesh = g.build(vs, Vector3(0.5, 0.0, 0.5), key == "glow")
		if key == "glow":
			mi.mesh.surface_set_material(0, glow_mat)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.set_meta("glow_at", sum / (v.size() / 6.0) * vs)
			root.set_meta("glow_n", v.size() / 6)
		root.add_child(mi)
	return root


func _add_light(root: Node3D) -> void:
	if not root.has_meta("glow_at") or int(root.get_meta("glow_n")) < 6:
		return
	var L: Dictionary = _look()
	var ol := OmniLight3D.new()
	ol.light_color = L["light"]
	ol.light_energy = L["light_e"]
	ol.omni_range = 3.2 if style == "b" else (4.0 if look_key != "" else 2.0)
	ol.position = root.get_meta("glow_at") + Vector3(0, 0.15, 0.1)
	root.add_child(ol)
	lights += 1


func _scene() -> void:
	for e: Array in LAYOUT[style]:
		var n := _model(String(e[0]))
		n.position = Vector3(float(e[1]), 0, float(e[2]))
		n.rotation.y = deg_to_rad(float(e[3]))
		add_child(n)
		if lights < 8 and String(e[0]) != "slash" and String(e[0]) != "boss":
			_add_light(n)


func _lineup() -> void:
	var g := _model("ground")
	add_child(g)
	var row := [["grunt0", -1.6], ["hero", -0.2], ["grunt1", 1.0], ["boss", 2.8]]
	for e: Array in row:
		var n := _model(String(e[0]))
		n.position = Vector3(float(e[1]) - 0.4, 0, 1.0)
		add_child(n)
	# 补一盏正面暖光（夜灯方案全靠灯，排排站时没有场景灯）
	if style == "b":
		var ol := OmniLight3D.new()
		ol.light_color = Color("ffc070")
		ol.light_energy = 2.2
		ol.omni_range = 7.0
		ol.position = Vector3(0.0, 1.6, 3.4)
		add_child(ol)


## 每个模型合成后多少三角形（和游戏里同一套贪心合并）；顺便量现在游戏里的 KayKit 角色
func _count() -> void:
	var out := []
	for st: String in ["a", "b", "c"]:
		style = st
		for id: String in ["hero", "grunt0", "boss", "ground"]:
			out.append("%s.%s=%d" % [st, id, _tris(_model(id))])
	for id: String in ["rogue", "skel_warrior", "barbarian"]:
		var d := VoxelModel.read_data("res://assets/voxel/%s.json" % id)
		var g := VoxelGrid.new(1)
		var off := 0
		for pn: String in d["parts"]:
			var v: Array = d["parts"][pn]["vox"]
			off += 200
			for i in range(0, v.size(), 6):
				g.cells[Vector3i(int(v[i]) + off, int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
		out.append("now.%s=%d" % [id, g.build(0.02).get_faces().size() / 3])
	print("COUNT " + " ".join(out))


func _tris(n: Node) -> int:
	var t := 0
	for c in n.get_children():
		if c is MeshInstance3D:
			t += (c as MeshInstance3D).mesh.get_faces().size() / 3
	return t


func _camera() -> void:
	cam = Camera3D.new()
	add_child(cam)
	var target := Vector3(0.0, 0.6, 0.0)
	var pitch := 50.0
	var dist := 14.5
	cam.fov = 38.0
	if mode == "lineup":
		target = Vector3(0.3, 1.1, 1.0)
		pitch = 12.0
		dist = 9.0
	elif mode == "close":
		target = Vector3(0.6, 0.8, 0.2)
		pitch = 38.0
		dist = 8.0
	var p := deg_to_rad(pitch)
	cam.position = target + Vector3(0, sin(p), cos(p)) * dist
	cam.look_at(target)


func _post() -> void:
	var L: Dictionary = _look()
	# 描边：按深度找轮廓（屏幕空间，一张全屏面片）
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	q.mesh = qm
	q.extra_cull_margin = 16384.0
	var m := ShaderMaterial.new()
	m.shader = load("res://tools/style_lab/outline.gdshader")
	m.set_shader_parameter("ink", L["outline"])
	m.set_shader_parameter("strength", {"a": 1.0, "b": 0.85, "c": 0.55}[style])
	q.material_override = m
	add_child(q)
	# 纸纹 / 移轴 / 暗角
	var layer := CanvasLayer.new()
	add_child(layer)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://tools/style_lab/post_%s.gdshader" % style)
	cr.material = pm
	layer.add_child(cr)
