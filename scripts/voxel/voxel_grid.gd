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
	return _downsample.call(f, false)


## 后台分帧版（见 build_sliced）
func downsample_sliced(f: int) -> VoxelGrid:
	return await _downsample(f, true)


func _downsample(f: int, sliced: bool) -> VoxelGrid:
	var _lp := LoadProf.t()
	var acc := {}
	var nn := 0
	for p: Vector3i in cells:
		nn += 1
		if sliced and (nn & 1023) == 0 and VoxelWarm.over():
			await VoxelWarm.pause()
		var q := Vector3i(floori(p.x / float(f)), floori(p.y / float(f)), floori(p.z / float(f)))
		var c: Color = cells[p]
		var a: Variant = acc.get(q)
		if a == null:
			acc[q] = [c.r, c.g, c.b, 1, c if c.a < 0.99 else null]
		else:
			a[0] += c.r
			a[1] += c.g
			a[2] += c.b
			a[3] += 1
			if c.a < 0.99 and a[4] == null:
				a[4] = c
	var g := VoxelGrid.new(0)
	var need := maxi(1, f * f * f / 4)
	for q: Vector3i in acc:
		var a: Array = acc[q]
		var n := int(a[3])
		if a[4] != null:
			g.cells[q] = a[4]   # 发光格（alpha < 1，眼睛之类）缩小时不跟旁边平均，整格保住
		elif n >= need:
			g.cells[q] = Color(a[0] / n, a[1] / n, a[2] / n)
	LoadProf.add("grid.downsample", _lp)
	return g


static func _q(c: Color) -> Color:
	if quant <= 0.0:
		return c
	return Color(roundf(c.r * quant) / quant, roundf(c.g * quant) / quant, roundf(c.b * quant) / quant, c.a)


## 合成网格。vsize：一格多大（世界单位）；origin：格子坐标里哪一点放在节点原点
func build(vsize: float, origin: Vector3 = Vector3.ZERO, glow: bool = false) -> ArrayMesh:
	if greedy:
		var _lp := LoadProf.t()
		# _build_fast 带 await（后台分帧时用），同步调用走 Callable，不让它停下来就直接拿到结果
		var gm: ArrayMesh = _build_fast.call(vsize, origin, glow, false) if fast and not cells.is_empty() else _build_greedy(vsize, origin, glow)
		LoadProf.add("grid.build", _lp)
		if LoadProf.on and LoadProf.big and Time.get_ticks_usec() - _lp > 15000:
			print("  big grid %d cells %.1f ms vs=%.3f glow=%s %s" % [cells.size(), (Time.get_ticks_usec() - _lp) / 1000.0, vsize, glow, str(get_meta("wk", ""))])
		return gm
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


## 快速版贪心合并（和 _build_greedy 结果一样，快几倍）：格子先摊平成一维数组，邻格查表靠下标加减，
## 不再用 Vector3i 查字典；可合并的面按“法线层 → v → u”的顺序用整数排序（C++ 排序，不走 GDScript 比较函数）。
## 网页版单线程，进房间的时间大半花在合网格上，这里每快一倍，第一次进新区域就少等一半。
static var fast := true
static var glow_merge := true   # 测试时关掉（和老版逐位对比）
static var _AO := PackedFloat32Array([1.0, 0.8, 0.66, 0.52])   # 和老版一样存成 32 位（对角线挑法、颜色逐位相同）
static var _tab := {}   # 预算好的表：每个朝向每个角的切向符号


static func _tables() -> Dictionary:
	if not _tab.is_empty():
		return _tab
	var s1 := PackedInt32Array()
	var s2 := PackedInt32Array()
	for f in range(6):
		var face: Array = _FACES[f]
		var t1: Vector3i = face[2]
		var t2: Vector3i = face[3]
		for ci in range(4):
			var cv: Vector3 = face[1][ci]
			s1.append(1 if cv.dot(Vector3(t1)) + _neg(t1) > 0.5 else -1)
			s2.append(1 if cv.dot(Vector3(t2)) + _neg(t2) > 0.5 else -1)
	_tab = {"s1": s1, "s2": s2}
	return _tab


## 后台分帧版：每帧只做 VoxelWarm.budget_us 微秒，做不完下一帧接着做（标题、山门、清完房这些空档里提前拼下一区域的件）
func build_sliced(vsize: float, origin: Vector3 = Vector3.ZERO, glow: bool = false) -> ArrayMesh:
	if not greedy or not fast or cells.is_empty():
		return build(vsize, origin, glow)
	return await _build_fast(vsize, origin, glow, true)


func _build_fast(vsize: float, origin: Vector3, glow: bool, sliced: bool = false) -> ArrayMesh:
	var keys: Array = cells.keys()
	var vals: Array = cells.values()
	var n_cells := keys.size()
	var mn: Vector3i = keys[0]
	var mx: Vector3i = keys[0]
	for p: Vector3i in keys:
		mn = mn.min(p)
		mx = mx.max(p)
	# 四周各留一格空，查邻格不用判断越界
	var sx := mx.x - mn.x + 3
	var sy := mx.y - mn.y + 3
	var sz := mx.z - mn.z + 3
	var sxy := sx * sy
	if sxy * sz > 24000000:
		return _build_greedy(vsize, origin, glow)   # 特别稀疏的大格子：摊平太占内存，走老办法
	var lo := mn - Vector3i.ONE
	var occ := PackedByteArray()
	occ.resize(sxy * sz)
	var idx_of := PackedInt32Array()
	idx_of.resize(n_cells)
	for k in range(n_cells):
		var p: Vector3i = keys[k]
		var i := (p.x - lo.x) + (p.y - lo.y) * sx + (p.z - lo.z) * sxy
		occ[i] = 1
		idx_of[k] = i
	var stride := [1, sx, sxy]
	var tb := _tables()
	var s1t: PackedInt32Array = tb["s1"]
	var s2t: PackedInt32Array = tb["s2"]
	# 每个朝向：法线偏移、四个角三个邻格的偏移（相对 q = 面前那一格）
	var noff := PackedInt32Array()
	var aoff := PackedInt32Array()   # f*12 + ci*3 + (a, b, c)
	var cvs := []                    # f*4 + ci → 角坐标
	var nrm := []
	for f in range(6):
		var face: Array = _FACES[f]
		var nn: Vector3i = face[0]
		var t1: Vector3i = face[2]
		var t2: Vector3i = face[3]
		noff.append(nn.x + nn.y * sx + nn.z * sxy)
		var o1 := t1.x + t1.y * sx + t1.z * sxy
		var o2 := t2.x + t2.y * sx + t2.z * sxy
		for ci in range(4):
			var a1 := o1 * s1t[f * 4 + ci]
			var a2 := o2 * s2t[f * 4 + ci]
			aoff.append(a1)
			aoff.append(a2)
			aoff.append(a1 + a2)
			cvs.append(Vector3(face[1][ci]))
		nrm.append(Vector3(nn))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# 可合并的面：按朝向分开，记 (排序键, 颜色)
	# （Packed 数组放进 Array 里取出来是副本，所以六个朝向共用一个键数组：键 = 朝向 × 体积 + 层内键）
	var mkeys := PackedInt64Array()
	var mcol: Array = [{}, {}, {}, {}, {}, {}]
	var vol: int = sxy * sz
	var dims := [sx, sy, sz]
	var kmul := PackedInt64Array()   # f*3 + 轴 → 这个轴在排序键里的倍数
	for f in range(6):
		var ax: Array = _AX[f]
		var m3 := [0, 0, 0]
		m3[ax[0]] = dims[ax[2]] * dims[ax[1]]
		m3[ax[2]] = dims[ax[1]]
		m3[ax[1]] = 1
		kmul.append_array(m3)
	var q := quant
	for k in range(n_cells):
		if sliced and (k & 63) == 0 and VoxelWarm.over():
			await VoxelWarm.pause()
		var i: int = idx_of[k]
		var base: Color = vals[k]
		if q > 0.0:
			base = Color(roundf(base.r * q) / q, roundf(base.g * q) / q, roundf(base.b * q) / q, base.a)
		var pv: Vector3 = Vector3(keys[k])
		for f in range(6):
			var qi := i + noff[f]
			if occ[qi] != 0:
				continue
			if glow and glow_merge:
				# 发光件不吃遮蔽（颜色每个角都一样），四角遮蔽不同也能并：画面一样，算得少、三角形也少
				var kg := f * 3
				mkeys.append(f * vol + (i % sx) * kmul[kg] + ((i / sx) % sy) * kmul[kg + 1] + (i / sxy) * kmul[kg + 2])
				(mcol[f] as Dictionary)[i] = base
				continue
			var ob := f * 12
			var a := occ[qi + aoff[ob]]
			var b := occ[qi + aoff[ob + 1]]
			var o0 := 3 if (a != 0 and b != 0) else a + b + occ[qi + aoff[ob + 2]]
			a = occ[qi + aoff[ob + 3]]
			b = occ[qi + aoff[ob + 4]]
			var o1 := 3 if (a != 0 and b != 0) else a + b + occ[qi + aoff[ob + 5]]
			a = occ[qi + aoff[ob + 6]]
			b = occ[qi + aoff[ob + 7]]
			var o2 := 3 if (a != 0 and b != 0) else a + b + occ[qi + aoff[ob + 8]]
			a = occ[qi + aoff[ob + 9]]
			b = occ[qi + aoff[ob + 10]]
			var o3 := 3 if (a != 0 and b != 0) else a + b + occ[qi + aoff[ob + 11]]
			if o0 == o1 and o1 == o2 and o2 == o3:
				var sh: float = 1.0 if glow else _SHADE[f] * _AO[o0]
				# 排序键：(法线轴坐标, v 轴坐标, u 轴坐标)，都用摊平后的格子坐标
				var kb := f * 3
				mkeys.append(f * vol + (i % sx) * kmul[kb] + ((i / sx) % sy) * kmul[kb + 1] + (i / sxy) * kmul[kb + 2])
				(mcol[f] as Dictionary)[i] = Color(base.r * sh, base.g * sh, base.b * sh, base.a)
				continue
			var start := verts.size()
			var nv: Vector3 = nrm[f]
			var cb := f * 4
			verts.append((pv + cvs[cb] - origin) * vsize)
			verts.append((pv + cvs[cb + 1] - origin) * vsize)
			verts.append((pv + cvs[cb + 2] - origin) * vsize)
			verts.append((pv + cvs[cb + 3] - origin) * vsize)
			norms.append(nv)
			norms.append(nv)
			norms.append(nv)
			norms.append(nv)
			if glow:
				cols.append(base)
				cols.append(base)
				cols.append(base)
				cols.append(base)
			else:
				var shf: float = _SHADE[f]
				var k0: float = _AO[o0] * shf
				var k1: float = _AO[o1] * shf
				var k2: float = _AO[o2] * shf
				var k3: float = _AO[o3] * shf
				cols.append(Color(base.r * k0, base.g * k0, base.b * k0, base.a))
				cols.append(Color(base.r * k1, base.g * k1, base.b * k1, base.a))
				cols.append(Color(base.r * k2, base.g * k2, base.b * k2, base.a))
				cols.append(Color(base.r * k3, base.g * k3, base.b * k3, base.a))
			# 按遮蔽选对角线（和 _build_greedy 一样）
			if _AO[o0] + _AO[o2] >= _AO[o1] + _AO[o3]:
				idx.append(start)
				idx.append(start + 2)
				idx.append(start + 1)
				idx.append(start)
				idx.append(start + 3)
				idx.append(start + 2)
			else:
				idx.append(start + 1)
				idx.append(start + 3)
				idx.append(start + 2)
				idx.append(start + 1)
				idx.append(start)
				idx.append(start + 3)
	# 第二遍：每个朝向里同色的面沿两个切向拉成矩形
	mkeys.sort()
	var kpos := 0
	var nk := mkeys.size()
	for f in range(6):
		if kpos >= nk or mkeys[kpos] >= (f + 1) * vol:
			continue
		var fm: Dictionary = mcol[f]
		var ax: Array = _AX[f]
		var na: int = ax[0]
		var ua: int = ax[1]
		var va: int = ax[2]
		var su: int = dims[ua]
		var sv: int = dims[va]
		var du: int = stride[ua]
		var dv: int = stride[va]
		var dn: int = stride[na]
		var face: Array = _FACES[f]
		var corners: Array = face[1]
		var nv: Vector3 = nrm[f]
		var cu := Vector3.ZERO
		cu[ua] = 1.0
		var cvv := Vector3.ZERO
		cvv[va] = 1.0
		var fbase: int = f * vol
		var fend: int = fbase + vol
		while kpos < nk and mkeys[kpos] < fend:
			var key: int = mkeys[kpos] - fbase
			kpos += 1
			if sliced and (kpos & 255) == 0 and VoxelWarm.over():
				await VoxelWarm.pause()
			var pu := key % su
			var pvv := (key / su) % sv
			var pn := key / (su * sv)
			var i := pu * du + pvv * dv + pn * dn
			var cc: Variant = fm.get(i)
			if cc == null:
				continue
			var col: Color = cc
			var w := 1
			while true:
				var c2: Variant = fm.get(i + du * w)
				if c2 == null or c2 != col:
					break
				w += 1
			var h := 1
			var grow := true
			while grow:
				var row := i + dv * h
				for t in range(w):
					var c2: Variant = fm.get(row + du * t)
					if c2 == null or c2 != col:
						grow = false
						break
				if grow:
					h += 1
			for jj in range(h):
				var row := i + dv * jj
				for t in range(w):
					fm.erase(row + du * t)
			var cell := Vector3(i % sx + lo.x, (i / sx) % sy + lo.y, i / sxy + lo.z)
			var sc := Vector3.ONE + cu * (w - 1) + cvv * (h - 1)
			var start := verts.size()
			for ci in range(4):
				var cv: Vector3 = corners[ci]
				verts.append((cell + cv * sc - origin) * vsize)
			norms.append(nv)
			norms.append(nv)
			norms.append(nv)
			norms.append(nv)
			cols.append(col)
			cols.append(col)
			cols.append(col)
			cols.append(col)
			idx.append(start)
			idx.append(start + 2)
			idx.append(start + 1)
			idx.append(start)
			idx.append(start + 3)
			idx.append(start + 2)
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
