class_name VoxActor
extends Node3D
## 3D 斜俯视用的体素人偶：读开源模型体素化出来的部件（VoxelModel，assets/voxel/*.json），
## 按“姿势字典”摆每块部件。姿势都在模型空间里描述：x 朝前、y 朝上、z 朝右，单位是体素格（1 格 = PX 米）。
## 控制它的脚本（Hero / Foe）每帧算一个姿势交给 apply()；Poses 里有走路、挥刀、翻滚、受击等现成的姿势。
##
## 姿势字典的键（都可以省略，省略就用站立姿势）：
##   lean 前倾（弧度）  twist 上身转（弧度，正 = 往左转）  bob 胯上下（格）  head 低头（弧度）
##   hand_r / hand_l 手相对肩膀的方向（Vector3，长度 = 伸出去的比例 0~1）
##   blade 刀刃方向（Vector3），没有就顺着前臂
##   foot_r / foot_l 脚相对站立位置的偏移（格）
##   roll 整个人绕侧轴翻（弧度，翻滚用）  spin 整个人绕竖轴转（弧度，回旋斩用）  tilt 往后仰（弧度，受击用）

const PX := 0.036             # 1 体素格 = 0.036 米：50 格高的人物约 1.8 米

static var _toon: Shader
static var _outline_mat: ShaderMaterial

var model: VoxelModel
var parts := {}               # 部件名 → MeshInstance3D
var weapon: MeshInstance3D
var weapon_len := 30.0
var body: Node3D              # 转到 Godot 朝向（模型 +x → 本节点 -z），翻滚、回旋在这里做
var mat: ShaderMaterial       # 这个人偶专用的卡通材质（闪白、染色）
var _hipmid := Vector3.ZERO
var _rest_feet := {}
var blade_tip := Vector3.ZERO     # 刀尖的世界坐标（刀光用）
var blade_base := Vector3.ZERO
var height := 50.0
var _flash := 0.0
var _flash_col := Color.WHITE
var scale_k := 1.0


static func toon_material() -> ShaderMaterial:
	if _toon == null:
		_toon = load("res://shaders/arpg/toon.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _toon
	return m


static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/arpg/outline.gdshader")
		_outline_mat.set_shader_parameter("width", 0.55)
	return _outline_mat


## model_id：assets/voxel 下的模型名；weapon_id：assets/voxel/weapon 下的武器名（"" 不拿武器）
func setup(model_id: String, weapon_id: String = "", wlen: float = 30.0, tint: Color = Color.WHITE, k: float = 1.0) -> void:
	scale_k = k
	model = VoxelModel.load_model(model_id)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	mat = toon_material()
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.next_pass = outline_material()
	if model == null:
		return
	height = float(model.joints.get("head", Vector3(0, 28, 0)).y) + 12.0
	_hipmid = (model.j("upperleg.r") + model.j("upperleg.l")) * 0.5
	for side: String in ["r", "l"]:
		var f := model.j("foot." + side)
		_rest_feet[side] = Vector3(f.x, 0.0, f.z * 0.8)
	for pname: String in model.parts:
		var mi := MeshInstance3D.new()
		mi.mesh = model.parts[pname]["mesh"]
		mi.material_override = mat
		mi.name = pname
		body.add_child(mi)
		parts[pname] = mi
	weapon_len = wlen
	if weapon_id != "":
		var wm := VoxelModel.weapon_mesh(weapon_id, wlen)
		if wm != null:
			weapon = MeshInstance3D.new()
			weapon.mesh = wm
			weapon.material_override = mat
			body.add_child(weapon)
	apply({})


func set_tint(c: Color) -> void:
	mat.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))


func set_glow(c: Color) -> void:
	mat.set_shader_parameter("glow", Vector3(c.r, c.g, c.b))


func set_rim(c: Color, strength: float) -> void:
	mat.set_shader_parameter("rim_color", Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("rim_strength", strength)


func flash(t: float = 0.1, c: Color = Color.WHITE) -> void:
	_flash = t
	_flash_col = c
	mat.set_shader_parameter("flash_color", Vector3(c.r, c.g, c.b))


func set_fade(f: float) -> void:
	mat.set_shader_parameter("fade", f)


func tick_flash(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - dt, 0.0)
		mat.set_shader_parameter("flash", clampf(_flash / 0.1, 0.0, 1.0))


## 模型空间（格）→ body 节点空间（米）：模型 +x 朝前 → -z，+z 朝右 → +x
func _m2b(p: Vector3) -> Vector3:
	return Vector3(p.z, p.y, -p.x) * PX * scale_k


func _place(pname: String, a: Vector3, b: Vector3, mi: MeshInstance3D = null) -> void:
	if mi == null:
		mi = parts.get(pname)
	if mi == null:
		return
	var d := b - a
	if d.length_squared() < 0.0001:
		d = Vector3(0, -1, 0)
	var yv := -d.normalized()
	var zv := Vector3(0, 0, 1)
	if absf(yv.dot(zv)) > 0.95:
		zv = Vector3(-1, 0, 0)
	var xv := yv.cross(zv).normalized()
	zv = xv.cross(yv).normalized()
	# 部件网格在模型空间（格），先在模型空间摆好，再整体换到 body 空间
	var bm := Basis(xv, yv, zv)
	var conv := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))   # 模型 → body 的轴变换
	mi.transform = Transform3D(conv * bm * PX * scale_k, _m2b(a))


static func _ik2(a: Vector3, t: Vector3, l1: float, l2: float, bend: Vector3) -> Vector3:
	var d := t - a
	var dist := clampf(d.length(), 0.001, l1 + l2 - 0.001)
	var dir := d.normalized()
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var side := (bend - dir * bend.dot(dir))
	if side.length_squared() < 0.0001:
		side = Vector3(1, 0, 0)
	side = side.normalized()
	return a + dir * (l1 * cos_a) + side * (l1 * sqrt(1.0 - cos_a * cos_a))


func apply(p: Dictionary) -> void:
	if model == null:
		return
	var M := model
	var lean := float(p.get("lean", 0.05))
	var twist := float(p.get("twist", 0.0))
	var bob := float(p.get("bob", 0.0))
	# 整体：翻滚绕胯的侧轴转，回旋绕竖轴转，受击往后仰
	var hip_h := _hipmid.y * PX * scale_k
	var roll := float(p.get("roll", 0.0))
	var spin := float(p.get("spin", 0.0))
	var tilt := float(p.get("tilt", 0.0))
	var bt := Transform3D.IDENTITY
	bt = bt.translated_local(Vector3(0, hip_h, 0))
	bt = bt.rotated_local(Vector3.UP, spin)
	bt = bt.rotated_local(Vector3.RIGHT, -roll + tilt)
	bt = bt.translated_local(Vector3(0, -hip_h, 0))
	body.transform = bt

	var hip3 := _hipmid + Vector3(0, bob, 0)
	var tb := Basis(Vector3.UP, twist) * Basis(Vector3(0, 0, 1), -lean)
	var neck3 := hip3 + tb * (M.j("head") - _hipmid)
	_place("torso", neck3, neck3 + tb * (M.j("hips") - M.j("head")))
	if parts.has("hips"):
		var conv := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
		var hb := Basis(Vector3.UP, twist * 0.4) * Basis(Vector3(0, 0, 1), -lean * 0.3)
		(parts["hips"] as MeshInstance3D).transform = Transform3D(conv * hb * PX * scale_k, _m2b(hip3 + hb * (M.j("hips") - _hipmid)))
	var hdb := tb * Basis(Vector3(0, 0, 1), -float(p.get("head", 0.0)))
	var conv2 := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
	(parts["head"] as MeshInstance3D).transform = Transform3D(conv2 * hdb * PX * scale_k, _m2b(neck3))

	# 手臂：手往 hand_* 的方向伸，肘往外后方弯
	var hand := {}
	for side: String in ["r", "l"]:
		var sd := "f" if side == "r" else "b"
		var sh3 := neck3 + tb * (M.j("upperarm." + side) - M.j("head"))
		var l1 := M.length("arm_u_" + sd)
		var l2 := M.length("arm_l_" + sd)
		var zs := 1.0 if side == "r" else -1.0
		var def := Vector3(0.05, -1.0, 0.12 * zs) * 0.95
		var hv: Vector3 = p.get("hand_" + side, def)
		var reach := clampf(hv.length(), 0.2, 0.98)
		var target := sh3 + hv.normalized() * (l1 + l2) * reach
		var el := _ik2(sh3, target, l1, l2, Vector3(-0.6, -0.2, 0.8 * zs))
		var hd := el + (target - el).normalized() * l2
		_place("arm_u_" + sd, sh3, el)
		_place("arm_l_" + sd, el, hd)
		hand[side] = hd

	# 腿：两节 IK，膝盖往前弯
	var ankle_h := M.j("foot.r").y
	for side: String in ["r", "l"]:
		var sd := "f" if side == "r" else "b"
		var hj := hip3 + Basis(Vector3.UP, twist * 0.4) * (M.j("upperleg." + side) - _hipmid)
		var off: Vector3 = p.get("foot_" + side, Vector3.ZERO)
		var target: Vector3 = _rest_feet[side] + off + Vector3(0, ankle_h, 0)
		var kn := _ik2(hj, target, M.length("leg_u_" + sd), M.length("leg_l_" + sd), Vector3(1, 0, 0))
		var dl := (target - kn).normalized() * M.length("leg_l_" + sd)
		_place("leg_u_" + sd, hj, kn)
		_place("leg_l_" + sd, kn, kn + dl)

	if weapon != null:
		var hr: Vector3 = hand["r"]
		var bd: Vector3 = p.get("blade", Vector3.ZERO)
		if bd == Vector3.ZERO:
			var hv: Vector3 = p.get("hand_r", Vector3(0.05, -1, 0.12))
			bd = (hv.normalized() + Vector3(0.7, 0.2, 0)).normalized()
		bd = bd.normalized()
		_place("", hr, hr + bd, weapon)
		var bw := body.global_transform
		blade_base = bw * _m2b(hr + bd * weapon_len * 0.25)
		blade_tip = bw * _m2b(hr + bd * weapon_len)


## 死了碎成方块：把每块部件拆出来，往外飞、落地弹一下、缩小消失
func shatter(world: Node3D, impulse: Vector3) -> void:
	var list: Array = parts.values()
	if weapon != null:
		list.append(weapon)
	for mi: MeshInstance3D in list:
		var gt := mi.global_transform
		body.remove_child(mi)
		world.add_child(mi)
		mi.global_transform = gt
		var deb := VoxDebris.new()
		deb.target = mi
		deb.vel = impulse * randf_range(0.6, 1.3) + Vector3(randf_range(-2, 2), randf_range(3, 6), randf_range(-2, 2))
		deb.spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		world.add_child(deb)
	visible = false
