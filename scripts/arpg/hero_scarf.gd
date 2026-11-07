class_name HeroScarf
extends Node3D
## 主角脖子上的一条长飘带（2026-11-07 外观改造）：九节方块串成一条，绳子物理（Verlet）拖在身后，
## 跑起来横着飘、翻滚甩一圈、停下来垂到背上。斜俯视下人物只有指甲盖大，一条红带子在画面里拖出一道线，
## 动起来一眼就看得见主角往哪跑（参考很多动作游戏用围巾/披风当“动势线”的做法）。
## 每节一个小方块（体素风），越往后越细；颜色跟皮肤走（ArpgArms.SKINS 的 scarf，默认朱红）。
## 主角根节点是 top_level 的世界坐标模拟，不受主角转身时的旋转牵连。

const N := 11
const SEG := 0.17           # 每节长度（米）
const DAMP := 0.92
const GRAV := Vector3(0, -7.0, 0)
const DEFAULT_COLOR := Color(0.8, 0.1, 0.1)

var hero: Hero
var _p: PackedVector3Array
var _q: PackedVector3Array   # 上一帧位置
var _segs: Array[MeshInstance3D] = []
var _mat: ShaderMaterial
var _t := 0.0
var _inited := false


func _ready() -> void:
	top_level = true
	_p.resize(N)
	_q.resize(N)
	_mat = VoxActor.toon_material()
	_mat.set_shader_parameter("rim_strength", 0.25)
	_mat.set_shader_parameter("shadow_floor", 0.45)
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	for i in range(N - 1):
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_segs.append(mi)
	set_color(DEFAULT_COLOR)


func set_color(c: Color) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
	_mat.set_shader_parameter("glow", Vector3(c.r, c.g, c.b) * 0.12)
	_mat.set_shader_parameter("rim_color", Vector3(1.0, 0.75, 0.5))


func _anchor() -> Vector3:
	if hero.rig != null and hero.rig.parts.has("head"):
		var h: Node3D = hero.rig.parts["head"]
		return h.global_position - hero.facing * 0.1 + Vector3(0, -0.04, 0)
	return hero.global_position + Vector3(0, 1.4, 0)


func _physics_process(dt: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	visible = hero.visible and hero.rig != null and hero.rig.visible
	if not visible:
		_inited = false
		return
	var a := _anchor()
	if not _inited:
		for i in range(N):
			_p[i] = a - hero.facing * SEG * i + Vector3(0, -0.05 * i, 0)
			_q[i] = _p[i]
		_inited = true
	_t += dt
	# 风：一点点左右摆，停着也不会死挂着
	var side := hero.facing.cross(Vector3.UP)
	var wind := side * sin(_t * 2.3) * 1.2 - hero.facing * 1.6 + Vector3(0, 1.4, 0) + side * sin(_t * 5.1) * 0.5
	var dt2 := dt * dt
	_p[0] = a
	_q[0] = a
	for i in range(1, N):
		var v := (_p[i] - _q[i]) * DAMP
		_q[i] = _p[i]
		var k := float(i) / N
		_p[i] += v + (GRAV + wind * (0.4 + k)) * dt2
	# 约束：节距固定；不钻进地面；离脖子太近的几节别穿进身体（往背后推）
	for _it in range(3):
		_p[0] = a
		for i in range(1, N):
			var d := _p[i] - _p[i - 1]
			var l := d.length()
			if l > 0.0001:
				_p[i] = _p[i - 1] + d * (SEG / l)
			if _p[i].y < 0.06:
				_p[i].y = 0.06
			var flat := _p[i] - hero.global_position
			flat.y = 0
			var front := flat.dot(hero.facing)
			if front > -0.12 and flat.length() < 0.42:
				_p[i] -= hero.facing * (front + 0.12)
	# 摆方块
	for i in range(N - 1):
		var p0 := _p[i]
		var p1 := _p[i + 1]
		var d := p1 - p0
		var l := maxf(d.length(), 0.001)
		var fwd := d / l
		var w := lerpf(0.17, 0.07, float(i) / (N - 2))
		var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
		var right := fwd.cross(up).normalized()
		var nup := right.cross(fwd).normalized()
		var b := Basis(right * w, nup * w * 0.4, fwd * (l + 0.02))
		_segs[i].global_transform = Transform3D(b, (p0 + p1) * 0.5)


## 翻滚、冲刺时甩一下：给后面几节一个反向的初速度
func fling(dir: Vector3, amt: float = 1.0) -> void:
	for i in range(2, N):
		_q[i] = _p[i] + dir * amt * 0.05 * float(i) / N
