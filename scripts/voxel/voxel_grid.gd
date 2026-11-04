class_name VoxelGrid
extends RefCounted
## 体素格子：往里填方块，再合成一个 ArrayMesh。
## 只生成露在外面的面（两个方块贴在一起的那面不画），每个顶点按周围的方块算环境光遮蔽，
## 角落和缝里会暗一点，方块感更强。颜色写在顶点上，材质统一用 VoxelGrid.material()。
##
## 坐标：格子是整数 Vector3i，x 朝前（角色面朝的方向）、y 朝上、z 朝镜头。
## build() 时乘以 vsize 换成世界单位（1 单位 = 2D 里的 1 像素），再减去 origin（格子坐标）。

var cells := {}          # Vector3i → Color
var rng := RandomNumberGenerator.new()

const _FACES := [
	# 法线, 面上四个角（相对方块最小角的偏移），两个切向（算遮蔽用）
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)], Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)], Vector3i(0, 1, 0), Vector3i(0, 0, -1)],
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], Vector3i(0, 0, 1), Vector3i(1, 0, 0)],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(0, 0, -1), [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)], Vector3i(-1, 0, 0), Vector3i(0, 1, 0)],
]
## 按朝向烘一点明暗（顶面最亮、底面最暗），实时灯光再叠在上面
const _SHADE := [0.86, 0.86, 1.0, 0.62, 0.94, 0.8]

static var _mat: StandardMaterial3D
static var _mat_glow: StandardMaterial3D


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 1.0
		_mat.metallic_specular = 0.0
		_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _mat


## 自发光材质（灯笼、窗户、刀光碎片）
static func glow_material() -> StandardMaterial3D:
	if _mat_glow == null:
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.vertex_color_use_as_albedo = true
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mat_glow


func set_v(p: Vector3i, c: Color) -> void:
	cells[p] = c


func erase(p: Vector3i) -> void:
	cells.erase(p)


func has(p: Vector3i) -> bool:
	return cells.has(p)


## 填一个长方体（两角都包含）。jitter：每格颜色随机明暗一点，看起来不那么平
func box(a: Vector3i, b: Vector3i, c: Color, jitter: float = 0.0) -> void:
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				cells[Vector3i(x, y, z)] = _jit(c, jitter)


## 挖掉一个长方体
func carve(a: Vector3i, b: Vector3i) -> void:
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				cells.erase(Vector3i(x, y, z))


## 只给已经有的格子换颜色
func paint(a: Vector3i, b: Vector3i, c: Color, jitter: float = 0.0) -> void:
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				var p := Vector3i(x, y, z)
				if cells.has(p):
					cells[p] = _jit(c, jitter)


## 椭球（中心、半径都按格子算）
func ellipsoid(center: Vector3, radius: Vector3, c: Color, jitter: float = 0.0) -> void:
	for x in range(floori(center.x - radius.x), ceili(center.x + radius.x) + 1):
		for y in range(floori(center.y - radius.y), ceili(center.y + radius.y) + 1):
			for z in range(floori(center.z - radius.z), ceili(center.z + radius.z) + 1):
				var d := Vector3((x - center.x) / radius.x, (y - center.y) / radius.y, (z - center.z) / radius.z)
				if d.length_squared() <= 1.0:
					cells[Vector3i(x, y, z)] = _jit(c, jitter)


func _jit(c: Color, jitter: float) -> Color:
	if jitter <= 0.0:
		return c
	var k := 1.0 + rng.randf_range(-jitter, jitter)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## 合成网格。vsize：一格多大（世界单位）；origin：格子坐标里哪一点放在节点原点
func build(vsize: float, origin: Vector3 = Vector3.ZERO, glow: bool = false) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p: Vector3i in cells:
		var base: Color = cells[p]
		for f in range(6):
			var face: Array = _FACES[f]
			var n: Vector3i = face[0]
			if cells.has(p + n):
				continue
			var t1: Vector3i = face[2]
			var t2: Vector3i = face[3]
			var corners: Array = face[1]
			var start := verts.size()
			var ao := PackedFloat32Array()
			for ci in range(4):
				var cv: Vector3 = corners[ci]
				# 这个角在两个切向上朝哪边（0 → 负方向，1 → 正方向）
				var s1 := 1 if cv.dot(Vector3(t1)) + _neg(t1) > 0.5 else -1
				var s2 := 1 if cv.dot(Vector3(t2)) + _neg(t2) > 0.5 else -1
				var q := p + n
				var a := cells.has(q + t1 * s1)
				var b := cells.has(q + t2 * s2)
				var c := cells.has(q + t1 * s1 + t2 * s2)
				var occ := 3 if (a and b) else int(a) + int(b) + int(c)
				var k: float = [1.0, 0.8, 0.66, 0.52][occ]
				ao.append(k)
				verts.append((Vector3(p) + cv - origin) * vsize)
				norms.append(Vector3(n))
				var sh: float = 1.0 if glow else _SHADE[f] * k
				cols.append(Color(base.r * sh, base.g * sh, base.b * sh, base.a))
			# 按遮蔽选对角线，避免明暗出现斜着的折痕（Godot 正面是顺时针）
			if ao[0] + ao[2] >= ao[1] + ao[3]:
				idx.append_array([start, start + 2, start + 1, start, start + 3, start + 2])
			else:
				idx.append_array([start + 1, start + 3, start + 2, start + 1, start, start + 3])
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, glow_material() if glow else material())
	return mesh


## 切向是负方向时，角坐标要反过来看
static func _neg(t: Vector3i) -> float:
	return 1.0 if (t.x + t.y + t.z) < 0 else 0.0


func size() -> int:
	return cells.size()
