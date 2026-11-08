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
var offhand: MeshInstance3D       # 左手拿的东西（盾兵的盾）
var offhand_len := 20.0
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
## 腿长倍数：姿势里的步幅、抬脚是按 KayKit 短腿（约 8.4 格）写的，锻造台的新模型腿长一倍多，步子要跟着放大，不然像在碎步挪
var _legk := 1.0


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


## 主角专用的浅色描边：俯视时兜帽一团深色，深色描边在暗地面上等于没有；浅描边一眼找得到自己
static var _hero_outline_mat: ShaderMaterial


static func hero_outline_material() -> ShaderMaterial:
	if _hero_outline_mat == null:
		_hero_outline_mat = ShaderMaterial.new()
		_hero_outline_mat.shader = load("res://shaders/arpg/outline.gdshader")
		_hero_outline_mat.set_shader_parameter("width", 0.6)
		_hero_outline_mat.set_shader_parameter("outline_color", Vector3(0.93, 0.88, 0.74))
	return _hero_outline_mat


## model_id：assets/voxel 下的模型名；weapon_id：assets/voxel/weapon 下的武器名（"" 不拿武器）
func setup(model_id: String, weapon_id: String = "", wlen: float = 30.0, tint: Color = Color.WHITE, k: float = 1.0) -> void:
	scale_k = k
	model = VoxelModel.load_model(model_id)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	mat = toon_material()
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("face_mul", 0.5)   # 角色的体素面明暗减半：人要比场景亮、比场景“跳”
	mat.next_pass = outline_material()
	if model == null:
		return
	height = float(model.joints.get("head", Vector3(0, 28, 0)).y) + 12.0
	_hipmid = (model.j("upperleg.r") + model.j("upperleg.l")) * 0.5
	_legk = clampf((model.length("leg_u_f") + model.length("leg_l_f")) / 8.4, 1.0, 2.4)
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


## 换脑袋：用另一个模型的头（同一套 KayKit 骨架），比如给骷髅法师摘掉尖帽子当老僧
func swap_head(model_id: String) -> void:
	var m2 := VoxelModel.load_model(model_id)
	if m2 != null and m2.parts.has("head") and parts.has("head"):
		(parts["head"] as MeshInstance3D).mesh = m2.parts["head"]["mesh"]


## 换手里的兵器
func set_weapon(weapon_id: String, wlen: float) -> void:
	if weapon != null:
		weapon.queue_free()
		weapon = null
	weapon_len = wlen
	var wm := VoxelModel.weapon_mesh(weapon_id, wlen)
	if wm != null:
		weapon = MeshInstance3D.new()
		weapon.mesh = wm
		weapon.material_override = mat
		body.add_child(weapon)


## 左手挂一件（盾牌等），跟着左手走，面朝前
func set_offhand(item_id: String, l: float) -> void:
	if offhand != null:
		offhand.queue_free()
		offhand = null
	offhand_len = l
	var wm := VoxelModel.weapon_mesh(item_id, l)
	if wm != null:
		offhand = MeshInstance3D.new()
		offhand.mesh = wm
		offhand.material_override = mat
		body.add_child(offhand)
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


## 受击挤压：上下压扁、左右鼓起，再弹两下回原样（顿帧时也在动，所以停住的那一下能看到被打扁）
var _sq := 0.0
var _sq_t := 1.0


## 受击后仰：人偶顺着挨打的方向歪一下再弹回来（dir 是世界空间的打击方向，amt 弧度）
var _rec := Vector3.ZERO      # 人偶自己坐标里的歪倒方向 × 角度
var _rec_t := 1.0


func recoil(dir: Vector3, amt: float) -> void:
	var p := get_parent() as Node3D
	var d := dir
	if p != null:
		d = p.global_transform.basis.inverse() * dir
	d.y = 0
	if d.length_squared() < 0.0001:
		return
	_rec = d.normalized() * amt
	_rec_t = 0.0


func squash(amount: float) -> void:
	_sq = maxf(amount, _sq * maxf(0.0, 1.0 - _sq_t * 4.0))
	_sq_t = 0.0


func set_fade(f: float) -> void:
	mat.set_shader_parameter("fade", f)


func tick_flash(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - dt, 0.0)
		mat.set_shader_parameter("flash", clampf(_flash / 0.1, 0.0, 1.0))
	if _sq_t < 0.5:
		_sq_t += dt
		var a := 0.0
		if _sq_t < 0.5:
			a = _sq * exp(-_sq_t * 9.0) * cos(_sq_t * 34.0)
		scale = Vector3(1.0 + a * 0.6, 1.0 - a, 1.0 + a * 0.6)
	if _rec_t < 0.6:
		_rec_t += dt
		var r := _rec * exp(-_rec_t * 7.0) * cos(_rec_t * 15.0) if _rec_t < 0.6 else Vector3.ZERO
		# 小角度：绕 x 转让头往 +z 倒，绕 z 转让头往 -x 倒
		rotation.x = r.z
		rotation.z = -r.x


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
	var bob := float(p.get("bob", 0.0)) * _legk
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
		var off: Vector3 = p.get("foot_" + side, Vector3.ZERO) * Vector3(_legk, _legk, 1.0)
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
	if offhand != null:
		# 盾：竖着立在左手前面（握把在手里，盾面朝前）
		var hl: Vector3 = hand["l"]
		var od: Vector3 = p.get("shield", Vector3(0.25, 1.0, 0.0))
		_place("", hl + Vector3(2.0, 0, 0), hl + Vector3(2.0, 0, 0) + od.normalized(), offhand)


## 死了碎成方块：把每块部件拆出来，往外飞、落地弹一下、缩小消失
func shatter(world: Node3D, impulse: Vector3) -> void:
	var list: Array = parts.values()
	if weapon != null:
		list.append(weapon)
	if offhand != null:
		list.append(offhand)
	# 先按每个部件自己的颜色崩出一把细小方块（精细体素碎成颗粒，比只飞几块肢体更像“碎掉”）
	if Vfx.I != null:
		for mi: MeshInstance3D in list:
			var cols := _sample_colors(mi.mesh, 3)
			for c: Color in cols:
				Vfx.I.chips(mi.global_position, impulse + Vector3.UP, c, 4, 5.5, 0.055)
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


static var _palette_cache := {}


## 从网格的顶点色里随便挑几个颜色（碎块用）
static func _sample_colors(mesh: Mesh, n: int) -> Array[Color]:
	var out: Array[Color] = []
	if mesh == null or mesh.get_surface_count() == 0:
		return out
	var key := mesh.get_instance_id()
	if not _palette_cache.has(key):
		# 只取一小把颜色存起来（同一种敌人的部件网格是共用的，取一次就够）
		var arr := mesh.surface_get_arrays(0)
		var all: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var pal := PackedColorArray()
		for i in range(mini(24, all.size())):
			pal.append(all[randi() % all.size()])
		_palette_cache[key] = pal
	var cols: PackedColorArray = _palette_cache[key]
	if cols.is_empty():
		return out
	for i in range(n):
		out.append(cols[randi() % cols.size()])
	return out
