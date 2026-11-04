class_name Vfx
extends Node3D
## 特效：刀光、命中火花、白闪、碎块、落地扬尘、冲击环、预警框、光束、爆炸、残影、漂浮孢子。
## 贴图来自 Kenney 的 Particle Pack / Light Masks（CC0，assets/fx/），全部是白底贴图 × 颜色，叠加混合发光。
## 特效一律用真实时间（_process 的 delta），顿帧时人物停住但火花照样炸开。
## 贴片节点放在对象池里重复用（pool_size 个），用完放回去。

static var I: Vfx

const TEX := "res://assets/fx/%s.png"
var _tex := {}
var _sh_add: Shader
var _sh_mix: Shader
var _sh_slash: Shader
var _quad: QuadMesh
var _cube: BoxMesh
var _pool: Array[MeshInstance3D] = []
var _live: Array = []          # [节点, 已过时间, 总时长, 更新函数(Callable)]
var _arc_cache := {}
var pool_size := 160


func _ready() -> void:
	I = self
	_sh_add = load("res://shaders/arpg/fx_add.gdshader")
	_sh_mix = load("res://shaders/arpg/fx_mix.gdshader")
	_sh_slash = load("res://shaders/arpg/slash.gdshader")
	_quad = QuadMesh.new()
	_cube = BoxMesh.new()
	_cube.size = Vector3.ONE
	for i in range(pool_size):
		var mi := MeshInstance3D.new()
		mi.mesh = _quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_pool.append(mi)


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(TEX % name)
	return _tex[name]


func _take() -> MeshInstance3D:
	var mi: MeshInstance3D
	if _pool.is_empty():
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	else:
		mi = _pool.pop_back()
	mi.mesh = _quad
	mi.visible = true
	mi.transform = Transform3D.IDENTITY
	return mi


func _give(mi: MeshInstance3D) -> void:
	mi.visible = false
	if _pool.size() < pool_size:
		_pool.append(mi)
	else:
		mi.queue_free()


func _mat(mi: MeshInstance3D, additive: bool, t: String, c: Color, bill: bool, energy: float = 2.0) -> ShaderMaterial:
	var m: ShaderMaterial = mi.material_override
	var want := _sh_add if additive else _sh_mix
	if m == null or m.shader != want:
		m = ShaderMaterial.new()
		m.shader = want
		mi.material_override = m
	m.set_shader_parameter("tex", tex(t))
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("billboard", bill)
	if additive:
		m.set_shader_parameter("energy", energy)
	return m


func _run(node: Node3D, dur: float, upd: Callable) -> void:
	_live.append([node, 0.0, dur, upd])
	upd.call(node, 0.0)


func _process(dt: float) -> void:
	var i := 0
	while i < _live.size():
		var e: Array = _live[i]
		e[1] = float(e[1]) + dt
		var k := clampf(float(e[1]) / float(e[2]), 0.0, 1.0)
		var node: Node3D = e[0]
		if is_instance_valid(node):
			(e[3] as Callable).call(node, k)
		if k >= 1.0:
			_live.remove_at(i)
			if is_instance_valid(node):
				if node is MeshInstance3D and node.get_parent() == self and (node as MeshInstance3D).mesh == _quad:
					_give(node)
				else:
					node.queue_free()
		else:
			i += 1


# ---------- 贴片特效 ----------

## 一张朝镜头的发光贴片：从 s0 缩放到 s1，同时淡出
func pop(pos: Vector3, t: String, c: Color, s0: float, s1: float, dur: float, additive: bool = true, rot: float = 0.0, energy: float = 2.5) -> MeshInstance3D:
	var mi := _take()
	var m := _mat(mi, additive, t, c, true, energy)
	var r0 := rot if rot != 0.0 else randf() * TAU
	_run(mi, dur, func(n: MeshInstance3D, k: float) -> void:
		var s := lerpf(s0, s1, 1.0 - pow(1.0 - k, 3.0))
		n.transform = Transform3D(Basis(Vector3.BACK, r0 + k * 0.6).scaled(Vector3(s, s, s)), pos)
		var cc := c
		cc.a = c.a * (1.0 - k * k)
		m.set_shader_parameter("color", cc))
	return mi


## 平铺在地上的贴片（冲击环、焦痕、预警），y 抬一点避免和地面打架
func ground(pos: Vector3, t: String, c: Color, s0: float, s1: float, dur: float, additive: bool = true, fade_in: float = 0.0) -> MeshInstance3D:
	var mi := _take()
	var m := _mat(mi, additive, t, c, false, 2.0)
	var y := pos.y + 0.03
	_run(mi, dur, func(n: MeshInstance3D, k: float) -> void:
		var s := lerpf(s0, s1, 1.0 - pow(1.0 - k, 2.0))
		n.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3(s, s, s)), Vector3(pos.x, y, pos.z))
		var cc := c
		var a := 1.0 - k
		if fade_in > 0.0:
			a = minf(a * 1.5, k / fade_in)
		cc.a = c.a * clampf(a, 0.0, 1.0)
		m.set_shader_parameter("color", cc))
	return mi


## 命中火花：黄色星形 + 白闪 + 几道细光
func hit_spark(pos: Vector3, heavy: bool, crit: bool) -> void:
	var col := Color(1.0, 0.86, 0.35) if not crit else Color(1.0, 0.95, 0.55)
	var s := 1.5 if heavy else 1.1
	if crit:
		s *= 1.35
	pop(pos, "star_06", col, s * 0.4, s, 0.16, true, 0.0, 3.0)
	pop(pos, "light_01", Color(1, 1, 1, 0.9), s * 0.7, s * 1.5, 0.1, true, 0.0, 2.2)
	pop(pos, "spark_05", Color(1.0, 0.75, 0.3), s * 0.5, s * 1.6, 0.22, true, 0.0, 2.0)
	if heavy:
		pop(pos, "star_08", Color(0.7, 0.95, 1.0), s * 0.3, s * 2.2, 0.2, true, 0.0, 2.0)


## 白色大闪光（重击、击杀）
func impact_flash(pos: Vector3, size: float = 3.0, c: Color = Color(1, 1, 1)) -> void:
	pop(pos, "circle_05", c, size * 0.3, size, 0.12, true, 0.0, 3.0)
	pop(pos, "flare_01", c, size * 0.5, size * 2.0, 0.18, true, 0.0, 2.0)


## 小方块碎片：从 pos 往 dir 方向溅开（体素风格的“喷血”换成方块）
func chips(pos: Vector3, dir: Vector3, c: Color, n: int = 8, speed: float = 6.0, size: float = 0.09) -> void:
	for i in range(n):
		var mi := MeshInstance3D.new()
		mi.mesh = _cube
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var shade := randf_range(0.7, 1.15)
		m.albedo_color = Color(c.r * shade, c.g * shade, c.b * shade)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = pos
		var s := size * randf_range(0.6, 1.4)
		mi.scale = Vector3(s, s, s)
		var d := VoxDebris.new()
		d.target = mi
		var spread := Vector3(randf_range(-1, 1), randf_range(0.2, 1.4), randf_range(-1, 1))
		d.vel = (dir.normalized() * 0.8 + spread * 0.7).normalized() * speed * randf_range(0.5, 1.2)
		d.spin = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		d.life = randf_range(0.6, 1.1)
		add_child(d)


## 落地扬尘：一圈烟往外扩
func dust(pos: Vector3, radius: float = 1.5, c: Color = Color(0.62, 0.66, 0.62, 0.55)) -> void:
	for i in range(8):
		var a := TAU * i / 8.0 + randf() * 0.3
		var off := Vector3(cos(a), 0, sin(a))
		var p0 := pos + off * radius * 0.3 + Vector3(0, 0.25, 0)
		var mi := _take()
		var m := _mat(mi, false, "smoke_04", c, true)
		var p1 := pos + off * radius + Vector3(0, 0.5, 0)
		var r0 := randf() * TAU
		_run(mi, 0.55, func(n: MeshInstance3D, k: float) -> void:
			var e := 1.0 - pow(1.0 - k, 2.0)
			var s := lerpf(0.6, 1.5, e)
			n.transform = Transform3D(Basis(Vector3.BACK, r0 + k).scaled(Vector3(s, s, s)), p0.lerp(p1, e))
			var cc := c
			cc.a = c.a * (1.0 - k)
			m.set_shader_parameter("color", cc))
	ground(pos, "lm_ring_b", Color(0.8, 0.85, 0.8, 0.45), radius * 0.5, radius * 2.4, 0.35, false)


## 冲击环
func shock_ring(pos: Vector3, c: Color, r0: float, r1: float, dur: float = 0.3) -> void:
	ground(pos, "lm_ring_b", c, r0, r1, dur, true)


# ---------- 刀光 ----------

## 一段扇环网格（单位半径），UV.x 沿挥砍方向，UV.y 内 → 外
func _arc_mesh(a0: float, a1: float, inner: float) -> ArrayMesh:
	var key := "%.2f|%.2f|%.2f" % [a0, a1, inner]
	if _arc_cache.has(key):
		return _arc_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 28
	for i in range(seg):
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var t0 := lerpf(a0, a1, u0)
		var t1 := lerpf(a0, a1, u1)
		var o0 := Vector3(sin(t0), 0, -cos(t0))
		var o1 := Vector3(sin(t1), 0, -cos(t1))
		var verts := [o0 * inner, o0, o1, o1 * inner]
		var uvs := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx])
			st.add_vertex(verts[idx])
	var m := st.commit()
	_arc_cache[key] = m
	return m


## 半月形刀光：xf 是刀光所在的平面（-z 是角度 0，绕 +y 转），radius 半径，从 a0 扫到 a1（弧度）
func slash(xf: Transform3D, radius: float, a0: float, a1: float, dur: float = 0.2, core: Color = Color(1, 1, 1), edge: Color = Color(0.3, 0.7, 1.0), energy: float = 3.0, inner: float = 0.45) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _arc_mesh(a0, a1, inner)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _sh_slash
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("energy", energy)
	mi.material_override = m
	add_child(mi)
	mi.global_transform = xf.scaled_local(Vector3(radius, radius, radius))
	_run(mi, dur, func(n: MeshInstance3D, k: float) -> void:
		var head := minf(k * 2.4, 1.0)
		m.set_shader_parameter("head", head + 0.001)
		m.set_shader_parameter("tail_len", 0.9)
		m.set_shader_parameter("fade", 1.0 if k < 0.45 else 1.0 - (k - 0.45) / 0.55)
		n.scale = Vector3.ONE * radius * (1.0 + k * 0.08))


# ---------- 技能特效 ----------

## 地面上的矩形预警框（突进斩是青色、敌人重击是红色）：from → to，宽 w
func telegraph_rect(from: Vector3, to: Vector3, w: float, c: Color, dur: float) -> MeshInstance3D:
	var mi := _take()
	var m := _mat(mi, true, "lm_cone_a_blur", c, false, 1.4)
	var d := to - from
	d.y = 0
	var len := maxf(d.length(), 0.1)
	var yaw := atan2(d.x, d.z)
	var mid := (from + to) * 0.5
	mid.y = from.y + 0.04
	_run(mi, dur, func(n: MeshInstance3D, k: float) -> void:
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2)
		n.transform = Transform3D(b.scaled(Vector3(w, len, 1)), mid)
		var cc := c
		var pulse := 0.75 + 0.25 * sin(k * 40.0)
		cc.a = c.a * minf(k * 4.0, 1.0) * pulse
		m.set_shader_parameter("color", cc))
	# 边框：两条亮线
	for sgn: float in [-1.0, 1.0]:
		var e := _take()
		var em := _mat(e, true, "trace_04", c, false, 2.5)
		var side := Vector3(cos(yaw), 0, -sin(yaw)) * sgn * w * 0.5
		_run(e, dur, func(n: MeshInstance3D, k: float) -> void:
			var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2)
			n.transform = Transform3D(b.scaled(Vector3(0.35, len, 1)), mid + side)
			var cc := c
			cc.a = minf(k * 5.0, 1.0)
			em.set_shader_parameter("color", cc))
	return mi


## 地面上的红色预警圆（敌人跳劈落点、法师法术落点）
func telegraph_circle(pos: Vector3, r: float, c: Color, dur: float) -> void:
	var mi := _take()
	var m := _mat(mi, true, "lm_circle_a", c, false, 1.3)
	_run(mi, dur, func(n: MeshInstance3D, k: float) -> void:
		n.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3.ONE * r * 2.0), pos + Vector3(0, 0.04, 0))
		var cc := c
		cc.a = c.a * (0.45 + 0.55 * k)
		m.set_shader_parameter("color", cc))
	var ring := _take()
	var rm := _mat(ring, true, "lm_ring_b", c, false, 2.0)
	_run(ring, dur, func(n: MeshInstance3D, k: float) -> void:
		var s := lerpf(r * 0.2, r, k) * 2.2
		n.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3.ONE * s), pos + Vector3(0, 0.05, 0))
		rm.set_shader_parameter("color", c))


## 光束斩：从 from 到 to 的一道青白光柱，持续 dur，留下漂浮的光粒
func beam(from: Vector3, to: Vector3, width: float, dur: float = 0.55) -> void:
	var d := to - from
	var len := d.length()
	var mid := (from + to) * 0.5
	var fwd := d.normalized()
	# 光柱贴片：沿光束方向拉长，朝镜头那面立起来（绕光束轴转向摄像机）
	var cam := get_viewport().get_camera_3d()
	for layer in range(3):
		var mi := _take()
		var t: String = ["lm_streaks_composed_a", "trace_07", "lm_cone_a_blur"][layer]
		var c: Color = [Color(0.55, 1.0, 1.0), Color(1, 1, 1), Color(0.3, 0.85, 1.0)][layer]
		var w: float = [width, width * 0.45, width * 1.8][layer]
		var en: float = [3.5, 5.0, 1.6][layer]
		var m := _mat(mi, true, t, c, false, en)
		_run(mi, dur, func(n: MeshInstance3D, k: float) -> void:
			var to_cam := (cam.global_position - mid).normalized() if is_instance_valid(cam) else Vector3.UP
			var side := fwd.cross(to_cam).normalized()
			var nrm := side.cross(fwd).normalized()
			var ww := w * (1.0 + 0.4 * sin(k * 30.0)) * (1.0 - pow(k, 3.0))
			n.transform = Transform3D(Basis(side * ww, fwd * len, nrm), mid)
			var cc := c
			cc.a = 1.0 - pow(k, 2.0)
			m.set_shader_parameter("color", cc))
	# 残留光粒
	for i in range(28):
		var p := from + d * randf() + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 1.0), randf_range(-0.5, 0.5))
		var dl := randf_range(0.6, 1.3)
		var mi := _take()
		var m2 := _mat(mi, true, "light_01", Color(0.6, 1.0, 1.0), true, 3.0)
		var drift := Vector3(randf_range(-0.3, 0.3), randf_range(0.6, 1.4), randf_range(-0.3, 0.3))
		var s := randf_range(0.15, 0.35)
		_run(mi, dl, func(n: MeshInstance3D, k: float) -> void:
			n.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s * (1.0 - k * 0.5)), p + drift * k)
			var cc := Color(0.6, 1.0, 1.0, 1.0 - k)
			m2.set_shader_parameter("color", cc))


## 终结技爆炸：红色爆闪 + 冲击环 + 黑烟 + 黑色碎块
func explosion(pos: Vector3, size: float = 1.0) -> void:
	pop(pos, "circle_05", Color(1.0, 0.25, 0.15), size * 0.6, size * 4.0, 0.22, true, 0.0, 4.0)
	pop(pos, "star_08", Color(1.0, 0.4, 0.3), size * 1.0, size * 4.5, 0.18, true, 0.0, 3.0)
	pop(pos, "magic_05", Color(1.0, 0.15, 0.1), size * 1.2, size * 3.6, 0.35, true, 0.0, 2.5)
	shock_ring(Vector3(pos.x, 0.0, pos.z), Color(1.0, 0.3, 0.2), size * 0.5, size * 5.0, 0.35)
	ground(Vector3(pos.x, 0.0, pos.z), "scorch_01", Color(0.05, 0.02, 0.02, 0.8), size * 2.5, size * 2.8, 1.6, false)
	for i in range(7):
		var off := Vector3(randf_range(-1, 1), randf_range(0, 0.8), randf_range(-1, 1)) * size
		pop(pos + off, "smoke_07", Color(0.06, 0.04, 0.05, 0.75), size * 0.8, size * 2.4, randf_range(0.5, 0.8), false)
	chips(pos, Vector3.UP, Color(0.08, 0.05, 0.06), 16, 9.0, 0.14)
	chips(pos, Vector3.UP, Color(0.9, 0.12, 0.1), 8, 7.0, 0.1)


## 出血滴：一小颗红方块往下掉
func bleed_drip(pos: Vector3) -> void:
	chips(pos, Vector3.DOWN, Color(0.75, 0.05, 0.08), 2, 1.5, 0.07)


## 残影：把人偶当前的样子拷一份，叠加青色发光，淡出
func ghost(actor: VoxActor, c: Color = Color(0.3, 0.9, 1.0), dur: float = 0.3) -> void:
	if actor == null or actor.body == null:
		return
	var g := Node3D.new()
	add_child(g)
	g.global_transform = actor.body.global_transform
	var m := ShaderMaterial.new()
	m.shader = _sh_add
	m.set_shader_parameter("tex", tex("circle_05"))
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("energy", 0.0)
	# 拷贝部件（共用网格），材质用纯色叠加
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_color = c
	gm.no_depth_test = false
	for mi: MeshInstance3D in actor.body.get_children():
		if not mi.visible:
			continue
		var cp := MeshInstance3D.new()
		cp.mesh = mi.mesh
		cp.material_override = gm
		cp.transform = mi.transform
		cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(cp)
	_run(g, dur, func(_n: Node3D, k: float) -> void:
		var cc := c
		cc.a = 0.55 * (1.0 - k)
		gm.albedo_color = cc)
