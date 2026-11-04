class_name VoxelRig
extends Node3D
## 体素角色：头、躯干、袴、大臂小臂、大腿小腿、刀、刀鞘、斗笠、披风、围巾都是一块块体素部件，
## 挂在同一个节点下。每帧读角色身上现成的骨骼姿势（Puppet 的姿势字典，player/enemy 的 _pose），
## 用 Puppet.solve 算出关节位置，再把每块部件摆到两个关节之间。
## 所以 2D 里所有招式（蓄力、出手、收势、弹簧滞后）原样带到 3D，不用逐帧做模型。
##
## 坐标：部件按朝右、未缩放的姿势摆（x 朝前，y 朝上），整个节点再按朝向和体型缩放（朝左就是 x 取负镜像）。
## 前手前腿放在 z+（靠镜头），后手后腿放在 z-。

const VS := 2.0                     # 一格体素 = 2 像素
const Z_FRONT := 4.0
const Z_BACK := -4.0

var fighter: Node2D                 # Player 或 Enemy
var look: Puppet.Look
var is_player := false
var parts := {}                     # 部件名 → MeshInstance3D
var _overlay: StandardMaterial3D
var _sway := 0.0
var _last_x := 0.0

static var _mesh_cache := {}


func setup(f: Node2D) -> void:
	fighter = f
	look = f.look
	is_player = f is Player
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	var key := _look_key()
	for pname in ["torso", "skirt", "head", "arm_u_f", "arm_l_f", "arm_u_b", "arm_l_b",
			"leg_u_f", "leg_l_f", "leg_u_b", "leg_l_b", "sword"]:
		_add_part(pname, key)
	if look.saya:
		_add_part("saya", key)
		_add_part("hilt", key)
	if look.hat or look.helm == "kasa":
		_add_part("hat", key)
	if look.cape:
		_add_part("cape", key)
	if is_player:
		_add_part("scarf", key)
		_add_part("tail", key)


func _add_part(pname: String, key: String) -> void:
	var mi := MeshInstance3D.new()
	var ck := pname + "|" + key
	if not _mesh_cache.has(ck):
		_mesh_cache[ck] = _build_part(pname)
	mi.mesh = _mesh_cache[ck]
	mi.material_overlay = _overlay
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	parts[pname] = mi


func _look_key() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%.1f|%s" % [look.cloth.to_html(), look.pants.to_html(), look.band.to_html(),
		look.hair.to_html(), look.skin.to_html(), look.hat, look.cape, look.sword_len, is_player]


# ---------- 部件建模 ----------

## 一根“从关节往下长”的部件：原点在顶面中心，往 -y 长 len_v 格
func _seg_grid(w: int, len_v: int, d: int, c: Color, jitter: float = 0.06) -> VoxelGrid:
	var g := VoxelGrid.new(hash(c.to_html()) + w * 7 + len_v)
	g.box(Vector3i(0, 0, 0), Vector3i(w - 1, len_v - 1, d - 1), c, jitter)
	return g


func _seg_build(g: VoxelGrid, w: int, len_v: int, d: int) -> ArrayMesh:
	return g.build(VS, Vector3(w / 2.0, len_v, d / 2.0))


func _build_part(pname: String) -> ArrayMesh:
	var L := look
	match pname:
		"torso":
			# 从脖子往下到腰：上宽下窄一点，前面有里衣领口，最下两排是腰带
			var w := 6
			var n := 8
			var d := 5
			var g := _seg_grid(w, n, d, L.cloth)
			g.box(Vector3i(-1, n - 3, 0), Vector3i(w, n - 1, d - 1), L.cloth, 0.06)   # 肩
			g.paint(Vector3i(0, 0, 0), Vector3i(w - 1, 0, d - 1), L.cloth_dark)
			g.paint(Vector3i(0, 1, 0), Vector3i(w - 1, 1, d - 1), L.belt, 0.04)
			g.paint(Vector3i(0, 2, 0), Vector3i(w - 1, 2, d - 1), L.belt.darkened(0.25))
			for y in range(4, n):   # 交领：前面一道斜的浅色
				var x := w - 1 - (n - 1 - y) / 2
				g.paint(Vector3i(x, y, 0), Vector3i(x, y, d - 1), L.collar)
			g.paint(Vector3i(-1, n - 1, 0), Vector3i(w, n - 1, d - 1), L.cloth_light)
			return _seg_build(g, w, n, d)
		"skirt":
			# 袴：挂在腰上，比腿宽，下摆张开
			var g := VoxelGrid.new(3)
			g.box(Vector3i(0, -2, 0), Vector3i(6, 0, 5), L.pants, 0.07)
			g.box(Vector3i(-1, -5, -1), Vector3i(7, -3, 6), L.pants, 0.07)
			g.paint(Vector3i(-1, -5, -1), Vector3i(7, -5, 6), L.pants_dark)
			g.carve(Vector3i(2, -5, -1), Vector3i(4, -4, 6))   # 两条裤腿中间的缝
			return g.build(VS, Vector3(3.5, 1, 3))
		"head":
			# 6×6×6 的头：前脸（x+）是皮肤，顶上和后面是头发，一只眼（靠镜头那边），头带
			var g := VoxelGrid.new(5)
			g.box(Vector3i(0, 0, 0), Vector3i(5, 5, 5), L.skin, 0.03)
			g.paint(Vector3i(0, 4, 0), Vector3i(5, 5, 5), L.hair, 0.05)
			g.paint(Vector3i(0, 0, 0), Vector3i(2, 5, 5), L.hair, 0.05)
			g.box(Vector3i(-1, 1, 1), Vector3i(-1, 4, 4), L.hair, 0.05)
			g.set_v(Vector3i(6, 2, 3), L.skin_dark)             # 鼻子
			g.set_v(Vector3i(5, 3, 5), Color("15121c"))          # 眼睛
			g.set_v(Vector3i(5, 3, 2), Color("15121c"))
			g.set_v(Vector3i(5, 1, 4), L.skin_dark)              # 嘴
			if is_player or L.band.a > 0.0:
				g.paint(Vector3i(0, 4, 0), Vector3i(5, 4, 5), L.band)
				if not is_player:
					g.box(Vector3i(-2, 3, 2), Vector3i(-1, 4, 3), L.band)
			return g.build(VS, Vector3(3, 3, 3))
		"hat":
			# 斗笠：一层层收小的圆锥
			var g := VoxelGrid.new(9)
			for r in [[7.0, 0], [5.0, 1], [3.0, 2], [1.4, 3]]:
				var rad: float = r[0]
				var y: int = r[1]
				for x in range(-8, 9):
					for z in range(-8, 9):
						if Vector2(x, z).length() <= rad:
							g.set_v(Vector3i(x, y, z), L.hat_color if y > 0 else L.hat_dark)
			g.rng.seed = 4
			for p: Vector3i in g.cells.keys():
				if g.rng.randf() < 0.25:
					g.cells[p] = (g.cells[p] as Color).darkened(0.15)
			return g.build(VS, Vector3(0.5, 0, 0.5))
		"arm_u_f", "arm_u_b":
			var g := _seg_grid(3, 5, 3, L.cloth if pname == "arm_u_f" else L.cloth_dark)
			return _seg_build(g, 3, 5, 3)
		"arm_l_f", "arm_l_b":
			var g := _seg_grid(2, 5, 2, L.skin if pname == "arm_l_f" else L.skin_dark, 0.03)
			g.paint(Vector3i(0, 4, 0), Vector3i(1, 4, 1), L.cloth_light)   # 袖口
			g.box(Vector3i(0, -1, 0), Vector3i(1, 0, 1), L.skin, 0.02)      # 手
			return _seg_build(g, 2, 5, 2)
		"leg_u_f", "leg_u_b":
			var g := _seg_grid(3, 6, 3, L.pants if pname == "leg_u_f" else L.pants_dark)
			return _seg_build(g, 3, 6, 3)
		"leg_l_f", "leg_l_b":
			var c := L.pants if pname == "leg_l_f" else L.pants_dark
			var g := _seg_grid(3, 5, 3, c)
			g.paint(Vector3i(0, 0, 0), Vector3i(2, 1, 2), Color("d8d0c0"))     # 绑腿
			g.box(Vector3i(0, -1, 0), Vector3i(4, -1, 2), Color("3a2a22"), 0.05)  # 草鞋（往前伸）
			return _seg_build(g, 3, 5, 3)
		"sword":
			# 原点在握刀的手：刀柄朝 +y，护手，刀身朝 -y
			var blade_n := maxi(4, int(roundf(L.sword_len / VS)))
			var g := VoxelGrid.new(11)
			g.box(Vector3i(0, 1, 0), Vector3i(0, 3, 0), L.hilt)
			g.box(Vector3i(-1, 0, -1), Vector3i(1, 0, 1), L.tsuba)
			g.box(Vector3i(0, -blade_n, 0), Vector3i(0, -1, 0), L.blade)
			g.box(Vector3i(1, -blade_n + 1, 0), Vector3i(1, -1, 0), L.blade_edge)
			return g.build(VS, Vector3(0.5, 0, 0.5))
		"saya":
			var g := _seg_grid(2, 13, 2, L.saya_color, 0.04)
			g.paint(Vector3i(0, 12, 0), Vector3i(1, 12, 1), L.tsuba)
			return _seg_build(g, 2, 13, 2)
		"hilt":
			var g := VoxelGrid.new(12)
			g.box(Vector3i(0, 0, 0), Vector3i(0, 3, 0), L.hilt)
			g.box(Vector3i(-1, 0, -1), Vector3i(1, 0, 1), L.tsuba)
			return g.build(VS, Vector3(0.5, 0, 0.5))
		"cape":
			var g := _seg_grid(2, 12, 7, L.cape_color, 0.12)
			g.rng.seed = 7
			for z in range(7):   # 破烂的下摆
				for y in range(g.rng.randi_range(0, 3)):
					g.erase(Vector3i(0, y, z))
					g.erase(Vector3i(1, y, z))
			return _seg_build(g, 2, 12, 7)
		"scarf":
			var g := VoxelGrid.new(13)
			g.box(Vector3i(0, 0, 0), Vector3i(4, 1, 4), L.band, 0.05)
			return g.build(VS, Vector3(2.5, 1, 2.5))
		"tail":
			# 围巾尾巴，跟着跑动往后飘
			var g := _seg_grid(1, 9, 2, L.band, 0.06)
			g.paint(Vector3i(0, 0, 0), Vector3i(0, 1, 1), L.band.darkened(0.2))
			return _seg_build(g, 1, 9, 2)
	return ArrayMesh.new()


# ---------- 每帧摆姿势 ----------

func _v3(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, -p.y, z)


## 把部件放到 a，-y 指向 b
func _place(pname: String, a: Vector2, b: Vector2, z: float) -> void:
	var mi: MeshInstance3D = parts.get(pname)
	if mi == null:
		return
	var d := Vector3(b.x - a.x, -(b.y - a.y), 0.0)
	if d.length_squared() < 0.0001:
		d = Vector3(0, -1, 0)
	var yv := -d.normalized()
	var zv := Vector3(0, 0, 1)
	var xv := yv.cross(zv)
	mi.transform = Transform3D(Basis(xv, yv, zv), _v3(a, z))


## 按角度放（Puppet 的角度：0 朝下，PI/2 朝前）
func _place_dir(pname: String, a: Vector2, angle: float, z: float) -> void:
	_place(pname, a, a + Vector2(sin(angle), cos(angle)), z)


func sync(dt: float) -> void:
	if not is_instance_valid(fighter):
		return
	var pose: Dictionary = fighter._pose
	if pose.is_empty():
		return
	var j := Puppet.solve(pose, Puppet.grip_of(look))
	var facing: int = fighter.facing
	var s := look.scale
	var squash := Vector2.ONE
	if is_player:
		squash = fighter._squash
	var gp: Vector2 = fighter.global_position
	position = Vector3(gp.x, -gp.y, 0.0)
	scale = Vector3(facing * s * squash.x * look.width, s * squash.y, s)
	rotation = Vector3.ZERO

	var hip: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	_place("torso", neck, hip, 0.0)
	_place("skirt", hip, hip + (hip - neck), 0.0)
	var hd: Vector2 = j["head"]
	var mi: MeshInstance3D = parts["head"]
	mi.transform = Transform3D(Basis(Vector3(0, 0, 1), -(float(pose["lean"]) + float(pose["head"])) * 0.6), _v3(hd, 0.0))
	if parts.has("hat"):
		(parts["hat"] as MeshInstance3D).transform = Transform3D(mi.transform.basis, _v3(hd + Vector2(0, -5.5), 0.0))
	_place("arm_u_b", j["shoulder_b"], j["elbow_b"], Z_BACK)
	_place("arm_l_b", j["elbow_b"], j["hand_b"], Z_BACK)
	_place("leg_u_b", hip - Vector2(1.5, 0), j["knee_b"], Z_BACK + 1.0)
	_place("leg_l_b", j["knee_b"], j["foot_b"], Z_BACK + 1.0)
	_place("leg_u_f", hip + Vector2(1.5, 0), j["knee_f"], Z_FRONT - 1.0)
	_place("leg_l_f", j["knee_f"], j["foot_f"], Z_FRONT - 1.0)
	_place("arm_u_f", j["shoulder"], j["elbow_f"], Z_FRONT)
	_place("arm_l_f", j["elbow_f"], j["hand_f"], Z_FRONT)

	# 刀：在手里、收在鞘里、或者脱手飞出去
	var sw: MeshInstance3D = parts["sword"]
	var sheathed := float(pose.get("sheathed", 0.0)) > 0.5
	var up: Vector2 = j["up"]
	var fwd := Vector2(-up.y, up.x)
	if fwd.x < 0.0:
		fwd = -fwd
	if parts.has("saya"):
		var mouth := Puppet.saya_mouth(hip, up, fwd)
		var saya_dir := (-fwd * 0.82 + Vector2(0, 0.55)).normalized()
		_place("saya", mouth, mouth + saya_dir, Z_BACK - 1.0)
		var hl: MeshInstance3D = parts["hilt"]
		hl.visible = sheathed
		_place("hilt", mouth, mouth - saya_dir, Z_BACK - 1.0)
	sw.visible = not sheathed and float(pose.get("sword_free", 0.0)) < 0.5
	if fighter is Enemy and String(fighter.data.get("prop", "")) == "bow":
		sw.visible = false
	_place_dir("sword", j["grip_at"], float(pose["sword"]), Z_FRONT + 2.0)

	# 披风、围巾：跟着速度往后飘
	var vx: float = fighter.velocity.x * facing if "velocity" in fighter else 0.0
	_sway = lerpf(_sway, clampf(vx / 200.0, -0.4, 1.2), 1.0 - exp(-6.0 * dt))
	if parts.has("cape"):
		var top := neck + Vector2(-2.5, 1.0)
		_place("cape", top, top + Vector2(-0.35 - _sway * 0.7, 1.0), -2.5)
	if parts.has("scarf"):
		(parts["scarf"] as MeshInstance3D).transform = Transform3D(Basis.IDENTITY, _v3(neck + Vector2(0, 1.5), 0.0))
		var t0 := neck + Vector2(-2.0, 1.5)
		var flap := sin(Time.get_ticks_msec() * 0.012) * 0.15 * (0.4 + _sway)
		_place("tail", t0, t0 + Vector2(-0.3 - _sway * 1.4, 1.0 - _sway * 0.5 + flap), -1.5)

	_update_state(dt)


## 受击闪白、危招红光、倒地、闪身半透明
func _update_state(_dt: float) -> void:
	var tint := Color(0, 0, 0, 0)
	if fighter is Enemy:
		var e: Enemy = fighter
		tint = e._tint()
		if e.state == Enemy.S.DYING:
			var k := clampf((e.state_time - 0.6) / 0.4, 0.0, 1.0)
			rotation.z = -PI / 2.0 * Player._ease_out_bounce(k) * (1.0 if e.facing > 0 else -1.0)
			position.y -= clampf(e.state_time - 1.3, 0.0, 1.0) * 8.0
			visible = e.state_time < 2.0
		else:
			visible = e.state != Enemy.S.DEAD
	else:
		var p: Player = fighter
		if p.flash_timer > 0.0:
			tint = Color(p.flash_color, 0.45 if p.state == Player.S.DRINK or p.state == Player.S.ART else 0.9)
		elif p.state == Player.S.BROKEN:
			tint = Color(0.2, 0.2, 0.25, 0.35)
		elif p.state == Player.S.DODGE:
			tint = Color(0.75, 0.9, 1.0, 0.3)
		visible = p.visible
	_overlay.albedo_color = tint
