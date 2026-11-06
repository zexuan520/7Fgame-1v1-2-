class_name SkillFx
extends RefCounted
## 技能分支、连携、双修用的特效（在 Vfx 的贴片池上拼出来，不改 Vfx 本身）：
##   落雷、天降光柱、血莲、吸血流光、内收环、连携金字。每条分支一个主色，一眼能分出来。

const THUNDER := Color(1.0, 0.92, 0.45)
const SHADOW := Color(0.7, 0.45, 1.0)
const BLOOD := Color(1.0, 0.18, 0.22)
const LIGHT := Color(0.6, 1.0, 1.0)


## 落雷：天上劈下一道折线闪电，地上炸一圈
static func bolt(pos: Vector3, c: Color = THUNDER, h: float = 8.0) -> void:
	var v := Vfx.I
	if v == null:
		return
	var p := Vector3(pos.x, 0.0, pos.z)
	var top := p + Vector3(randf_range(-0.6, 0.6), h, randf_range(-0.6, 0.6))
	var segs := 5 if v.lod > 0 else 3
	var prev := top
	for i in range(segs):
		var k := float(i + 1) / segs
		var nxt := top.lerp(p, k)
		if i < segs - 1:
			nxt += Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))
		var mid := (prev + nxt) * 0.5
		var d := nxt - prev
		v.cut_line(mid, d, d.length() * 1.1, Color(1, 1, 1), 0.26, 0.34, c)
		prev = nxt
	v.impact_flash(p + Vector3(0, 0.5, 0), 2.6, c)
	v.shock_ring(p, c, 0.3, 3.0, 0.3)
	v.ground(p, "scorch_01", Color(0.06, 0.05, 0.03, 0.7), 1.6, 1.9, 1.4, false)
	v.chips(p + Vector3(0, 0.3, 0), Vector3.UP, c, 6, 7.0, 0.08)


## 天降光柱：从天上落一根光柱到地上（天落、升重）
static func pillar(pos: Vector3, h: float = 12.0, w: float = 1.4, dur: float = 0.5) -> void:
	if Vfx.I == null:
		return
	var p := Vector3(pos.x, 0.0, pos.z)
	Vfx.I.beam(p + Vector3(0, h, 0), p, w, dur)
	Vfx.I.shock_ring(p, LIGHT, 0.4, 3.2, 0.4)


## 血莲：六瓣红光从敌人身上绽开，地上一朵血花
static func lotus(pos: Vector3, r: float = 2.2) -> void:
	var v := Vfx.I
	if v == null:
		return
	var a0 := randf() * TAU
	for i in range(6):
		var a := a0 + TAU * i / 6.0
		var d := Vector3(cos(a), 0.35, sin(a))
		v.cut_line(pos + d * r * 0.45, d, r, Color(1, 0.85, 0.85), 0.3, 0.2, BLOOD)
	v.ground(Vector3(pos.x, 0, pos.z), "magic_05", Color(1.0, 0.2, 0.25, 0.85), r * 0.6, r * 2.2, 0.6)
	v.shock_ring(Vector3(pos.x, 0, pos.z), BLOOD, 0.3, r * 2.0, 0.35)


## 一颗光点从 from 飞到 to（吸血、回气），走一道弧线
static func drain(from: Vector3, to_node: Node3D, c: Color = BLOOD, n: int = 4) -> void:
	var v := Vfx.I
	if v == null or not is_instance_valid(to_node):
		return
	for i in range(n):
		var mi := v._take()
		var m := v._mat(mi, true, "light_01", c, true, 3.2)
		var side := Vector3(randf_range(-1.5, 1.5), randf_range(0.8, 2.2), randf_range(-1.5, 1.5))
		var dur := randf_range(0.35, 0.55)
		var s := randf_range(0.35, 0.55)
		var st := from
		v._run(mi, dur, func(nd: MeshInstance3D, k: float) -> void:
			var end := (to_node.global_position + Vector3(0, 1.1, 0)) if is_instance_valid(to_node) else st
			var e := k * k
			var p := st.lerp(end, e) + side * sin(k * PI) * 0.6
			nd.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s * (1.0 - k * 0.4)), p)
			var cc := c
			cc.a = 1.0 - k * 0.3
			m.set_shader_parameter("color", cc))


## 内收环：一圈光从外往里收（回风卷人）
static func ring_in(pos: Vector3, c: Color, r: float) -> void:
	if Vfx.I == null:
		return
	var p := Vector3(pos.x, 0, pos.z)
	Vfx.I.ground(p, "lm_ring_b", c, r * 2.2, 0.4, 0.3, true)
	Vfx.I.ground(p, "twirl_01", Color(c, 0.8), r * 1.6, r * 0.4, 0.35, true)


## 满月：一整圈刀光（残月）
static func full_moon(pos: Vector3, r: float, c: Color = SHADOW) -> void:
	var v := Vfx.I
	if v == null:
		return
	var xf := Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.8, 0))
	v.slash(xf, r, 0.0, -TAU, 0.32, Color(1, 1, 1), c, 3.8, 0.7)
	v.slash(xf, r * 0.75, PI, PI - TAU, 0.3, Color(1, 0.95, 1), Color(c, 0.8), 2.4, 0.6)
	v.shock_ring(Vector3(pos.x, 0, pos.z), c, 0.5, r * 2.2, 0.4)
	v.ground(Vector3(pos.x, 0, pos.z), "lm_circle_a", Color(c, 0.6), r * 1.2, r * 2.4, 0.5)


## 在离人偶 offset 的地方拷一份人偶当下的样子（分身）。和 Vfx.ghost 一样共用网格、叠加纯色
static func ghost_at(actor: VoxActor, offset: Vector3, c: Color, dur: float) -> void:
	var v := Vfx.I
	if v == null or actor == null or actor.body == null:
		return
	var g := Node3D.new()
	v.add_child(g)
	g.global_transform = actor.body.global_transform
	g.global_position += offset
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_color = c
	for mi: MeshInstance3D in actor.body.get_children():
		if not mi.visible:
			continue
		var cp := MeshInstance3D.new()
		cp.mesh = mi.mesh
		cp.material_override = gm
		cp.transform = mi.transform
		cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(cp)
	v._run(g, dur, func(_n: Node3D, k: float) -> void:
		var cc := c
		cc.a = 0.7 * (1.0 - k)
		gm.albedo_color = cc)
