class_name VoxelTrail
extends MeshInstance3D
## 刀光拖尾：每帧记下刀根和刀尖在世界里的位置，刀挥得够快就连成一条月牙形的发光带，很快淡掉。
## 两帧之间刀转过的角度可能很大，所以绕着刀根按角度补几段，弧线才是圆的，不会变成折线。
## 不看招式表，任何挥刀（主角连段、敌人出招、招式、闪身突刺）都会自动带上。

const LIFE := 0.16          # 一段刀光留多久（游戏时间，顿帧时跟着定住）
const MIN_SPEED := 420.0    # 刀尖每秒走多少像素才算在挥刀
const SUBDIV := 5

var color := Color(0.8, 0.92, 1.0)
var width := 1.0            # 刀光宽度倍率（重击更宽）
var _samples: Array = []    # [年龄, 刀根, 刀尖, 是否在挥]
var _im := ImmediateMesh.new()
static var _mat: StandardMaterial3D


func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.no_depth_test = false
	material_override = _mat


## 每帧调一次。gdt 是游戏时间（顿帧时接近 0），force 为真时不管快慢都出刀光
func push(grip: Vector3, tip: Vector3, gdt: float, force: bool = false) -> void:
	for s: Array in _samples:
		s[0] = float(s[0]) + gdt
	while not _samples.is_empty() and float(_samples[0][0]) > LIFE:
		_samples.pop_front()
	var swinging := force
	if not _samples.is_empty() and gdt > 0.0001:
		var last: Array = _samples[-1]
		var speed := (tip - (last[2] as Vector3)).length() / gdt
		swinging = swinging or speed > MIN_SPEED
	if gdt > 0.0001 or _samples.is_empty():
		_samples.append([0.0, grip, tip, swinging])
	_rebuild()


func clear() -> void:
	_samples.clear()
	_im.clear_surfaces()


func _rebuild() -> void:
	_im.clear_surfaces()
	# 先把相邻两个都在挥的采样点之间按角度补点，得到一串 [年龄, 刀根, 刀尖]
	var pts: Array = []
	for i in range(1, _samples.size()):
		var a: Array = _samples[i - 1]
		var b: Array = _samples[i]
		if not (a[3] and b[3]):
			if not pts.is_empty():
				pts.append(null)   # 断开
			continue
		var g0: Vector3 = a[1]
		var g1: Vector3 = b[1]
		var v0: Vector3 = (a[2] as Vector3) - g0
		var v1: Vector3 = (b[2] as Vector3) - g1
		var a0 := atan2(v0.y, v0.x)
		var a1 := atan2(v1.y, v1.x)
		var da := wrapf(a1 - a0, -PI, PI)
		var l0 := Vector2(v0.x, v0.y).length()
		var l1 := Vector2(v1.x, v1.y).length()
		var start := 0 if pts.is_empty() or pts[-1] == null else 1
		for k in range(start, SUBDIV + 1):
			var t := float(k) / SUBDIV
			var g := g0.lerp(g1, t)
			var ang := a0 + da * t
			var ln := lerpf(l0, l1, t)
			var dir := Vector3(cos(ang), sin(ang), 0.0)
			pts.append([lerpf(float(a[0]), float(b[0]), t), g, dir * ln])
	if pts.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var hot := Color(minf(color.r + 0.35, 1.0), minf(color.g + 0.35, 1.0), minf(color.b + 0.35, 1.0))
	for i in range(1, pts.size()):
		if pts[i] == null or pts[i - 1] == null:
			continue
		var p: Array = pts[i - 1]
		var q: Array = pts[i]
		var ap := pow(clampf(1.0 - float(p[0]) / LIFE, 0.0, 1.0), 1.4)
		var aq := pow(clampf(1.0 - float(q[0]) / LIFE, 0.0, 1.0), 1.4)
		# 三圈：刀身中段（透明）→ 靠刀尖（本色）→ 刀尖外一点（亮白），像月牙
		var rin := 1.0 - 0.6 * width
		var rows := [[rin, 0.0, color], [0.86, 0.55, color], [1.0 + 0.06 * width, 0.95, hot]]
		for r in range(2):
			var r0: Array = rows[r]
			var r1: Array = rows[r + 1]
			var p0: Vector3 = (p[1] as Vector3) + (p[2] as Vector3) * float(r0[0])
			var p1: Vector3 = (p[1] as Vector3) + (p[2] as Vector3) * float(r1[0])
			var q0: Vector3 = (q[1] as Vector3) + (q[2] as Vector3) * float(r0[0])
			var q1: Vector3 = (q[1] as Vector3) + (q[2] as Vector3) * float(r1[0])
			var cp0 := Color(r0[2] as Color, float(r0[1]) * ap)
			var cp1 := Color(r1[2] as Color, float(r1[1]) * ap)
			var cq0 := Color(r0[2] as Color, float(r0[1]) * aq)
			var cq1 := Color(r1[2] as Color, float(r1[1]) * aq)
			_tri(p0, cp0, p1, cp1, q1, cq1)
			_tri(p0, cp0, q1, cq1, q0, cq0)
	_im.surface_end()


func _tri(a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void:
	_im.surface_set_color(ca)
	_im.surface_add_vertex(a)
	_im.surface_set_color(cb)
	_im.surface_add_vertex(b)
	_im.surface_set_color(cc)
	_im.surface_add_vertex(c)
