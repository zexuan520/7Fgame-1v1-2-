class_name BladeTrail
extends MeshInstance3D
## 兵器拖尾：每帧记下刀根和刀尖的世界坐标，连成一条丝带，越旧越淡越窄。
## 采样点之间用 Catmull-Rom 插值补几段，快速挥砍也是圆滑的弧，不会一折一折。
## 跟着角色自己的时间走：顿帧时拖尾停在半空（定格的那一下更有分量），恢复后再继续淡出。

var actor: Actor                 # 拿哪个角色的时间（顿帧、全屏停顿）
var rig: VoxActor
var active := false              # 挥刀时打开，收刀关掉（已有的会自己淡完）
var life := 0.16                 # 一个采样点活多久（秒）
var subdiv := 3                  # 两个采样点之间补几段
var core := Color(1, 1, 1)
var edge := Color(0.35, 0.8, 1.0)
var width_k := 1.0               # 刀根往刀尖缩一点：1 = 整把刀长
var _pts: Array = []             # [刀根, 刀尖, 年龄]
var _im: ImmediateMesh
var _mat: ShaderMaterial


func _init() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/arpg/blade_trail.gdshader")
	material_override = _mat


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_transform = Transform3D.IDENTITY
	extra_cull_margin = 8.0


func set_colors(c_core: Color, c_edge: Color) -> void:
	core = c_core
	edge = c_edge
	_mat.set_shader_parameter("core", core)
	_mat.set_shader_parameter("edge", edge)


func _process(dt: float) -> void:
	var _pt := Time.get_ticks_usec() if PerfProbe.on else 0
	_process_body(dt)
	if PerfProbe.on:
		PerfProbe.add("trail", _pt)


func _process_body(dt: float) -> void:
	if not is_instance_valid(rig):
		return
	var adt := dt
	if is_instance_valid(actor):
		adt = actor.ldt(dt)
	if adt > 0.0:
		for p: Array in _pts:
			p[2] = float(p[2]) + adt
		while not _pts.is_empty() and float(_pts[0][2]) > life:
			_pts.pop_front()
		if active and rig.visible:
			var b := rig.blade_tip.lerp(rig.blade_base, width_k)
			var t := rig.blade_tip
			if _pts.is_empty() or (t - (_pts[-1][1] as Vector3)).length_squared() > 0.0004:
				_pts.append([b, t, 0.0])
	_rebuild()


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _rebuild() -> void:
	_im.clear_surfaces()
	var n := _pts.size()
	if n < 2:
		return
	# 先把采样点插值成更密的一串（刀根、刀尖、年龄）
	var bs: Array[Vector3] = []
	var ts: Array[Vector3] = []
	var ages: Array[float] = []
	for i in range(n - 1):
		var a0: Array = _pts[maxi(i - 1, 0)]
		var a1: Array = _pts[i]
		var a2: Array = _pts[i + 1]
		var a3: Array = _pts[mini(i + 2, n - 1)]
		var steps := subdiv if Vfx.I == null or Vfx.I.lod > 0 else 1
		for s in range(steps):
			var k := float(s) / steps
			bs.append(_cr(a0[0], a1[0], a2[0], a3[0], k))
			ts.append(_cr(a0[1], a1[1], a2[1], a3[1], k))
			ages.append(lerpf(float(a1[2]), float(a2[2]), k))
	var last: Array = _pts[n - 1]
	bs.append(last[0])
	ts.append(last[1])
	ages.append(float(last[2]))
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var m := bs.size()
	for i in range(m):
		var fresh := 1.0 - clampf(ages[i] / life, 0.0, 1.0)
		# 越旧的地方越窄（刀根往刀尖收）
		var b := ts[i].lerp(bs[i], fresh)
		var u := float(i) / float(m - 1)
		_im.surface_set_color(Color(1, 1, 1, fresh))
		_im.surface_set_uv(Vector2(u, 0.0))
		_im.surface_add_vertex(b)
		_im.surface_set_color(Color(1, 1, 1, fresh))
		_im.surface_set_uv(Vector2(u, 1.0))
		_im.surface_add_vertex(ts[i])
	_im.surface_end()
