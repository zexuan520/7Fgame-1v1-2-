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


## 合并相邻同色的面（贪心合并）：同一朝向、同一层、颜色和四角遮蔽都一样的面拼成一个大矩形。
## 看起来和逐格画完全一样，三角形少好几倍（KayKit 体素化的件大片同色，手机上主要省在这里）。
static var greedy := true
## 颜色分档（每个通道分成多少档，0 = 不分）：颜色差一两个色阶的面也能合并。低画质分得粗（砖面的随机明暗变成几档），
## 中高画质只并掉体素化时采样出来的近似色
static var quant := 0.0


## 缩小 f 倍（f×f×f 个小格并成一格，颜色取平均；一半以上是空的就不要）：低画质给精细体素的角色用
func downsample(f: int) -> VoxelGrid:
	var acc := {}
	for p: Vector3i in cells:
		var q := Vector3i(floori(p.x / float(f)), floori(p.y / float(f)), floori(p.z / float(f)))
		var c: Color = cells[p]
		var a: Variant = acc.get(q)
		if a == null:
			acc[q] = [c.r, c.g, c.b, 1]
		else:
			a[0] += c.r
			a[1] += c.g
			a[2] += c.b
			a[3] += 1
	var g := VoxelGrid.new(0)
	var need := maxi(1, f * f * f / 4)
	for q: Vector3i in acc:
		var a: Array = acc[q]
		var n := int(a[3])
		if n >= need:
			g.cells[q] = Color(a[0] / n, a[1] / n, a[2] / n)
	return g


static func _q(c: Color) -> Color:
	if quant <= 0.0:
		return c
	return Color(roundf(c.r * quant) / quant, roundf(c.g * quant) / quant, roundf(c.b * quant) / quant, c.a)


## 合成网格。vsize：一格多大（世界单位）；origin：格子坐标里哪一点放在节点原点
func build(vsize: float, origin: Vector3 = Vector3.ZERO, glow: bool = false) -> ArrayMesh:
	if greedy:
		return _build_greedy(vsize, origin, glow)
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


## 每个面的法线轴、两个切向轴（贪心合并时在这两个轴上拉长矩形）
const _AX := [[0, 1, 2], [0, 1, 2], [1, 2, 0], [1, 2, 0], [2, 0, 1], [2, 0, 1]]


func _build_greedy(vsize: float, origin: Vector3, glow: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# 第一遍：找出所有露在外面的面，算好四角遮蔽。四角一样的面进“可合并”表（按朝向分），不一样的直接画
	var flat: Array = [{}, {}, {}, {}, {}, {}]   # 朝向 → {格子: 颜色键}
	for p: Vector3i in cells:
		var base: Color = _q(cells[p])
		for f in range(6):
			var face: Array = _FACES[f]
			var n: Vector3i = face[0]
			if cells.has(p + n):
				continue
			var t1: Vector3i = face[2]
			var t2: Vector3i = face[3]
			var corners: Array = face[1]
			var q := p + n
			var ao := PackedFloat32Array()
			ao.resize(4)
			for ci in range(4):
				var cv: Vector3 = corners[ci]
				var s1 := 1 if cv.dot(Vector3(t1)) + _neg(t1) > 0.5 else -1
				var s2 := 1 if cv.dot(Vector3(t2)) + _neg(t2) > 0.5 else -1
				var a := cells.has(q + t1 * s1)
				var b := cells.has(q + t2 * s2)
				var c := cells.has(q + t1 * s1 + t2 * s2)
				var occ := 3 if (a and b) else int(a) + int(b) + int(c)
				ao[ci] = [1.0, 0.8, 0.66, 0.52][occ]
			if ao[0] == ao[1] and ao[1] == ao[2] and ao[2] == ao[3]:
				var sh: float = 1.0 if glow else _SHADE[f] * ao[0]
				(flat[f] as Dictionary)[p] = Color(base.r * sh, base.g * sh, base.b * sh, base.a)
				continue
			var start := verts.size()
			for ci in range(4):
				var cv: Vector3 = corners[ci]
				verts.append((Vector3(p) + cv - origin) * vsize)
				norms.append(Vector3(n))
				var sh2: float = 1.0 if glow else _SHADE[f] * ao[ci]
				cols.append(Color(base.r * sh2, base.g * sh2, base.b * sh2, base.a))
			if ao[0] + ao[2] >= ao[1] + ao[3]:
				idx.append_array([start, start + 2, start + 1, start, start + 3, start + 2])
			else:
				idx.append_array([start + 1, start + 3, start + 2, start + 1, start, start + 3])
	# 第二遍：每个朝向里，同色的面沿两个切向贪心拉成矩形
	for f in range(6):
		var fm: Dictionary = flat[f]
		if fm.is_empty():
			continue
		var face: Array = _FACES[f]
		var n: Vector3i = face[0]
		var corners: Array = face[1]
		var ax: Array = _AX[f]
		var ua: int = ax[1]
		var va: int = ax[2]
		var du := Vector3i.ZERO
		du[ua] = 1
		var dv := Vector3i.ZERO
		dv[va] = 1
		var keys := fm.keys()
		# 按 (法线轴, v, u) 排序，从每个矩形的最小角开始扫
		var na: int = ax[0]
		keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a[na] != b[na]:
				return a[na] < b[na]
			if a[va] != b[va]:
				return a[va] < b[va]
			return a[ua] < b[ua])
		for p: Vector3i in keys:
			if not fm.has(p):
				continue
			var col: Color = fm[p]
			var w := 1
			while fm.has(p + du * w) and fm[p + du * w] == col:
				w += 1
			var h := 1
			var grow := true
			while grow:
				var row := p + dv * h
				for i in range(w):
					var c2: Variant = fm.get(row + du * i)
					if c2 == null or c2 != col:
						grow = false
						break
				if grow:
					h += 1
			for j in range(h):
				for i in range(w):
					fm.erase(p + du * i + dv * j)
			var sc := Vector3.ONE
			sc[ua] = w
			sc[va] = h
			var start := verts.size()
			for ci in range(4):
				var cv: Vector3 = corners[ci]
				verts.append((Vector3(p) + cv * sc - origin) * vsize)
				norms.append(Vector3(n))
				cols.append(col)
			idx.append_array([start, start + 2, start + 1, start, start + 3, start + 2])
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
