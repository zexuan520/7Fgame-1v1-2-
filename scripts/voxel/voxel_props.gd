class_name VoxelProps
extends RefCounted
## 荒村的体素摆设和远近景。每个函数返回一个 VoxelGrid，格子坐标的原点在摆设的贴地中心，
## 一格 ES 像素。能站的结构（板车、木箱、草垛、破棚、断墙、木楼、脚手架、望楼）的平台高度和 RoomProps.PLATFORMS 对齐。
##
## 纵深约定（z，单位像素）：角色站在 z = 0，身体厚 ±6。能站的结构都放在 z ≤ -8 的地方，
## 角色从前面走过不会穿模，站上去时看起来站在结构的前沿。

const ES := 4.0                       # 摆设一格 = 4 像素
const Z_NEAR := -2                    # 结构最靠前的一格（格子坐标，× ES = -8 像素）

const WOOD := Color("6b4a33")
const WOOD_DARK := Color("4a3324")
const WOOD_LIGHT := Color("8a6444")
const PLANK := Color("9a7650")
const STRAW := Color("c8a256")
const STRAW_DARK := Color("9a7838")
const PLASTER := Color("cdbfa2")
const STONE := Color("8a8478")
const STONE_DARK := Color("625d55")
const ROOF := Color("6a5a4a")
const WINDOW := Color("ffb860")
const CLOTH_A := Color("c9b9a0")
const CLOTH_B := Color("8a5a5a")


static func _px(v: float) -> int:
	return int(roundf(v / ES))


## 能站的结构：[种类] → 函数
static func build(kind: String, seed_value: int) -> Dictionary:
	# 返回 {"grid": VoxelGrid, "glow": VoxelGrid 或 null, "lights": [[Vector3 本地像素坐标, Color, 半径]]}
	var g := VoxelGrid.new(seed_value)
	var glow := VoxelGrid.new(seed_value + 1)
	var lights := []
	match kind:
		"crates": _crates(g, 0, 9)
		"hay": _hay(g)
		"cart": _cart(g)
		"shed": _shed(g)
		"wall": _wall(g)
		"house2": _house2(g, glow, lights)
		"scaffold": _scaffold(g)
		"tower": _tower(g)
		"lantern": _lantern(g, glow, lights)
		"stone_lantern": _stone_lantern(g, glow, lights)
		"fire": _fire(g, glow, lights)
		"woodpile": _woodpile(g)
		"laundry": _laundry(g)
		"sign": _sign(g)
		"barrel_d": _barrel(g, 0, -6)
		"well": _well(g)
		"grave": _grave(g)
		"rubble": _rubble(g)
		"scarecrow": _scarecrow(g)
		"bamboo": _bamboo(g)
		_: return {}
	return {"grid": g, "glow": glow if glow.size() > 0 else null, "lights": lights}


static func _crates(g: VoxelGrid, cx: int, top: int) -> void:
	# 两个底箱一个顶箱，箱子有深色边框
	for c in [[-5, 0, 4], [0, 0, 4], [-2, 4, top - 4]]:
		var x0: int = cx + int(c[0])
		var y0: int = c[1]
		var h: int = c[2]
		g.box(Vector3i(x0, y0, -9), Vector3i(x0 + 4, y0 + h - 1, Z_NEAR), PLANK, 0.08)
		g.paint(Vector3i(x0, y0, -9), Vector3i(x0, y0 + h - 1, Z_NEAR), WOOD_DARK)
		g.paint(Vector3i(x0 + 4, y0, -9), Vector3i(x0 + 4, y0 + h - 1, Z_NEAR), WOOD_DARK)
		g.paint(Vector3i(x0, y0 + h - 1, -9), Vector3i(x0 + 4, y0 + h - 1, Z_NEAR), WOOD)


static func _hay(g: VoxelGrid) -> void:
	g.ellipsoid(Vector3(0, 2.5, -6), Vector3(5.6, 4.6, 4.4), STRAW, 0.12)
	g.carve(Vector3i(-7, -6, -12), Vector3i(7, -1, 0))
	g.rng.seed = 21
	for p: Vector3i in g.cells.keys():
		if g.rng.randf() < 0.3:
			g.cells[p] = STRAW_DARK
	g.box(Vector3i(-5, 3, Z_NEAR), Vector3i(5, 3, Z_NEAR), Color("7a5a30"))   # 捆绳


static func _cart(g: VoxelGrid) -> void:
	# 车板高 26 像素（6.5 格），两个轮子，车把朝左
	g.box(Vector3i(-7, 5, -9), Vector3i(7, 6, -3), PLANK, 0.1)
	g.box(Vector3i(-7, 7, -9), Vector3i(-7, 8, -3), WOOD)
	g.box(Vector3i(7, 7, -9), Vector3i(7, 8, -3), WOOD)
	g.box(Vector3i(-12, 4, -6), Vector3i(-8, 4, -6), WOOD_DARK)
	for wz in [-10, -2]:
		for a in range(16):
			var ang := a / 16.0 * TAU
			g.set_v(Vector3i(roundi(cos(ang) * 3.0), 3 + roundi(sin(ang) * 3.0), wz), WOOD_DARK)
		g.box(Vector3i(0, 1, wz), Vector3i(0, 5, wz), WOOD)
		g.box(Vector3i(-2, 3, wz), Vector3i(2, 3, wz), WOOD)


static func _shed(g: VoxelGrid) -> void:
	# 四根柱子、斜的草顶（平台在 74 像素），左边一个木箱当台阶（34 像素，x -70）
	for px in [-12, 12]:
		g.box(Vector3i(px, 0, -14), Vector3i(px, 17, -14), WOOD)
		g.box(Vector3i(px, 0, Z_NEAR - 1), Vector3i(px, 17, Z_NEAR - 1), WOOD)
	g.box(Vector3i(-14, 18, -16), Vector3i(14, 18, Z_NEAR), STRAW_DARK, 0.1)
	g.box(Vector3i(-13, 19, -15), Vector3i(13, 19, -5), STRAW, 0.12)
	_crates_small(g, -18, 8)


static func _crates_small(g: VoxelGrid, cx: int, h: int) -> void:
	g.box(Vector3i(cx - 3, 0, -9), Vector3i(cx + 3, h - 1, Z_NEAR), PLANK, 0.08)
	g.paint(Vector3i(cx - 3, h - 1, -9), Vector3i(cx + 3, h - 1, Z_NEAR), WOOD)


static func _wall(g: VoxelGrid) -> void:
	# 土石断墙：顶上参差（平台 46 像素 ≈ 11.5 格）
	g.rng.seed = 33
	for x in range(-12, 13):
		var top := 11 + (1 if g.rng.randf() < 0.3 else 0) - (2 if absi(x) > 10 and g.rng.randf() < 0.6 else 0)
		for y in range(0, top):
			for z in range(-8, Z_NEAR + 1):
				var c := STONE if (x + y * 3 + z) % 5 != 0 else STONE_DARK
				g.set_v(Vector3i(x, y, z), c.darkened(g.rng.randf() * 0.12))


static func _house2(g: VoxelGrid, glow: VoxelGrid, lights: Array) -> void:
	# 两层木楼：一楼宽 164 像素，二楼走廊 70 像素高；二楼宽 120 像素（中心 +10），屋顶 128 像素高能站人。
	# 楼体在后面（z -64 ~ -16），走廊的木板伸到前面（z -8）。左边楼梯从 x -172 走上 70。
	var hw := 20                          # 一楼半宽（格）
	# 一楼墙：木框白墙
	g.box(Vector3i(-hw, 0, -16), Vector3i(hw, 16, -4), PLASTER, 0.05)
	for x in range(-hw, hw + 1, 5):
		g.box(Vector3i(x, 0, -4), Vector3i(x, 16, -4), WOOD)
	g.box(Vector3i(-hw, 0, -4), Vector3i(hw, 0, -4), WOOD_DARK)
	g.box(Vector3i(-hw, 8, -4), Vector3i(hw, 8, -4), WOOD)
	# 一楼门、窗
	g.carve(Vector3i(-3, 1, -4), Vector3i(0, 7, -4))
	g.box(Vector3i(-3, 1, -5), Vector3i(0, 7, -5), WOOD_DARK)
	for wx in [-14, 7, 13]:
		g.carve(Vector3i(wx, 10, -4), Vector3i(wx + 2, 13, -4))
		glow.box(Vector3i(wx, 10, -5), Vector3i(wx + 2, 13, -5), WINDOW)
		lights.append([Vector3((wx + 1) * ES, 12 * ES, -2.0 * ES), Color(1.0, 0.65, 0.3), 70.0])
	# 二楼走廊（平台 70 像素 = 17.5 格）：木板铺到前面，前沿有栏杆柱
	g.box(Vector3i(-hw - 1, 17, -16), Vector3i(hw + 1, 17, Z_NEAR), PLANK, 0.08)
	g.box(Vector3i(-hw - 1, 16, Z_NEAR), Vector3i(hw + 1, 16, Z_NEAR), WOOD_DARK)
	for x in range(-hw - 1, hw + 2, 6):
		g.box(Vector3i(x, 0, Z_NEAR), Vector3i(x, 15, Z_NEAR), WOOD_DARK)
	# 二楼楼体
	var x0 := 2 - 15
	var x1 := 2 + 15
	g.box(Vector3i(x0, 18, -16), Vector3i(x1, 30, -10), PLASTER, 0.05)
	for x in range(x0, x1 + 1, 5):
		g.box(Vector3i(x, 18, -10), Vector3i(x, 30, -10), WOOD)
	for wx in [x0 + 4, x1 - 7]:
		g.carve(Vector3i(wx, 22, -10), Vector3i(wx + 3, 26, -10))
		glow.box(Vector3i(wx, 22, -11), Vector3i(wx + 3, 26, -11), WINDOW)
		lights.append([Vector3((wx + 1.5) * ES, 24 * ES, -9.0 * ES), Color(1.0, 0.65, 0.3), 60.0])
	# 屋顶：平台 128 像素 = 32 格，草顶从后往前压下来，顶面能站
	g.box(Vector3i(x0 - 2, 31, -18), Vector3i(x1 + 2, 31, Z_NEAR), STRAW_DARK, 0.1)
	g.box(Vector3i(x0 - 1, 32, -17), Vector3i(x1 + 1, 32, -6), STRAW, 0.12)
	g.box(Vector3i(x0, 33, -16), Vector3i(x1, 33, -10), STRAW, 0.12)
	g.box(Vector3i(x0 + 1, 34, -15), Vector3i(x1 - 1, 34, -13), STRAW_DARK, 0.1)
	# 楼梯：x -172 → -82，升到 70 像素
	var steps := 18
	for i in range(steps):
		var sx := _px(-172.0 + 90.0 * (i + 0.5) / steps)
		var sy := int(roundf(17.5 * (i + 1) / steps)) - 1
		g.box(Vector3i(sx - 1, maxi(sy - 1, 0), -12), Vector3i(sx, sy, -5), PLANK, 0.06)
	g.box(Vector3i(_px(-172.0), 0, -4), Vector3i(_px(-172.0), 4, -4), WOOD_DARK)


static func _scaffold(g: VoxelGrid) -> void:
	# 竹脚手架：平台 56、112 像素，宽 66
	for px in [-8, 8]:
		g.box(Vector3i(px, 0, -14), Vector3i(px, 29, -14), Color("8f9a52"))
		g.box(Vector3i(px, 0, Z_NEAR - 1), Vector3i(px, 29, Z_NEAR - 1), Color("8f9a52"))
	for h in [13, 27]:
		g.box(Vector3i(-9, h, -15), Vector3i(9, h, Z_NEAR), PLANK, 0.1)
	for i in range(12):   # 斜撑
		g.set_v(Vector3i(-7 + i, 1 + i, -14), Color("7a8444"))


static func _tower(g: VoxelGrid) -> void:
	# 望楼：低台 52（中心 -30，宽 30），顶台 100（宽 56），四根柱子和梯子
	for px in [-6, 6]:
		g.box(Vector3i(px, 0, -14), Vector3i(px, 24, -14), WOOD)
		g.box(Vector3i(px, 0, Z_NEAR - 1), Vector3i(px, 24, Z_NEAR - 1), WOOD)
	g.box(Vector3i(-7, 25, -15), Vector3i(7, 25, Z_NEAR), PLANK, 0.08)
	g.box(Vector3i(-7, 26, -15), Vector3i(-7, 28, -15), WOOD_DARK)
	g.box(Vector3i(7, 26, -15), Vector3i(7, 28, -15), WOOD_DARK)
	g.box(Vector3i(-11, 12, -12), Vector3i(-4, 12, Z_NEAR), PLANK, 0.08)
	g.box(Vector3i(-11, 0, -10), Vector3i(-11, 11, -10), WOOD)


static func _lantern(g: VoxelGrid, glow: VoxelGrid, lights: Array) -> void:
	g.box(Vector3i(0, 0, -6), Vector3i(0, 11, -6), WOOD_DARK)
	g.box(Vector3i(1, 11, -6), Vector3i(2, 11, -6), WOOD_DARK)
	glow.box(Vector3i(2, 8, -7), Vector3i(3, 10, -5), Color("ff9a48"))
	lights.append([Vector3(2.5 * ES, 9 * ES, -4.0 * ES), Color(1.0, 0.6, 0.28), 110.0])


static func _stone_lantern(g: VoxelGrid, glow: VoxelGrid, lights: Array) -> void:
	g.box(Vector3i(-1, 0, -8), Vector3i(1, 4, -6), STONE, 0.08)
	g.box(Vector3i(-2, 5, -9), Vector3i(2, 7, -5), STONE, 0.08)
	g.box(Vector3i(-3, 8, -10), Vector3i(3, 8, -4), STONE_DARK)
	glow.box(Vector3i(-1, 6, -5), Vector3i(1, 6, -5), Color("ffb060"))
	lights.append([Vector3(0, 6.5 * ES, -3.0 * ES), Color(1.0, 0.65, 0.3), 70.0])


static func _fire(g: VoxelGrid, glow: VoxelGrid, lights: Array) -> void:
	for i in range(8):
		var a := i / 8.0 * TAU
		g.set_v(Vector3i(roundi(cos(a) * 2.5), 0, -6 + roundi(sin(a) * 2.5)), STONE_DARK)
	g.box(Vector3i(-1, 0, -7), Vector3i(1, 0, -5), WOOD_DARK)
	glow.box(Vector3i(-1, 1, -7), Vector3i(1, 2, -5), Color("ff7a28"))
	glow.box(Vector3i(0, 3, -6), Vector3i(0, 4, -6), Color("ffc860"))
	lights.append([Vector3(0, 3 * ES, -4.0 * ES), Color(1.0, 0.5, 0.2), 140.0])


static func _woodpile(g: VoxelGrid) -> void:
	for row in range(3):
		for i in range(4 - row):
			var x := -4 + i * 2 + row
			g.box(Vector3i(x, row, -8), Vector3i(x + 1, row, -3), WOOD_LIGHT if (i + row) % 2 == 0 else WOOD, 0.1)


static func _laundry(g: VoxelGrid) -> void:
	g.box(Vector3i(-10, 0, -12), Vector3i(-10, 14, -12), WOOD)
	g.box(Vector3i(10, 0, -12), Vector3i(10, 14, -12), WOOD)
	g.box(Vector3i(-10, 14, -12), Vector3i(10, 14, -12), Color("d8d0c0"))
	g.box(Vector3i(-7, 9, -12), Vector3i(-3, 13, -12), CLOTH_A, 0.06)
	g.box(Vector3i(1, 10, -12), Vector3i(4, 13, -12), CLOTH_B, 0.06)
	g.box(Vector3i(6, 11, -12), Vector3i(8, 13, -12), Color("5a6a8a"), 0.06)


static func _sign(g: VoxelGrid) -> void:
	g.box(Vector3i(0, 0, -6), Vector3i(0, 9, -6), WOOD_DARK)
	g.box(Vector3i(-3, 7, -6), Vector3i(4, 9, -6), PLANK, 0.06)
	g.box(Vector3i(-2, 8, -5), Vector3i(3, 8, -5), Color("3a2a20"))


static func _barrel(g: VoxelGrid, cx: int, cz: int) -> void:
	g.ellipsoid(Vector3(cx, 2.5, cz), Vector3(2.2, 3.0, 2.2), WOOD, 0.1)
	g.carve(Vector3i(cx - 3, -2, cz - 3), Vector3i(cx + 3, -1, cz + 3))
	g.paint(Vector3i(cx - 3, 1, cz - 3), Vector3i(cx + 3, 1, cz + 3), Color("3a3a3a"))
	g.paint(Vector3i(cx - 3, 4, cz - 3), Vector3i(cx + 3, 4, cz + 3), Color("3a3a3a"))


static func _well(g: VoxelGrid) -> void:
	for a in range(14):
		var ang := a / 14.0 * TAU
		g.box(Vector3i(roundi(cos(ang) * 4.0), 0, -9 + roundi(sin(ang) * 3.0)),
			Vector3i(roundi(cos(ang) * 4.0), 3, -9 + roundi(sin(ang) * 3.0)), STONE, 0.1)
	g.box(Vector3i(-4, 4, -9), Vector3i(-4, 11, -9), WOOD)
	g.box(Vector3i(4, 4, -9), Vector3i(4, 11, -9), WOOD)
	g.box(Vector3i(-5, 12, -11), Vector3i(5, 12, -7), ROOF, 0.08)


static func _grave(g: VoxelGrid) -> void:
	g.box(Vector3i(-1, 0, -8), Vector3i(1, 5, -7), STONE, 0.1)
	g.ellipsoid(Vector3(0, 0, -11), Vector3(4, 2, 3), Color("5a5040"), 0.1)


static func _rubble(g: VoxelGrid) -> void:
	g.rng.seed = 41
	for i in range(14):
		var p := Vector3i(g.rng.randi_range(-5, 5), 0, g.rng.randi_range(-10, -3))
		g.set_v(p, STONE.darkened(g.rng.randf() * 0.3))
		if g.rng.randf() < 0.4:
			g.set_v(p + Vector3i(0, 1, 0), STONE_DARK)


static func _scarecrow(g: VoxelGrid) -> void:
	g.box(Vector3i(0, 0, -8), Vector3i(0, 12, -8), WOOD)
	g.box(Vector3i(-4, 9, -8), Vector3i(4, 9, -8), WOOD)
	g.box(Vector3i(-1, 5, -9), Vector3i(1, 9, -7), CLOTH_B, 0.08)
	g.box(Vector3i(-1, 10, -9), Vector3i(1, 12, -7), STRAW, 0.08)
	g.box(Vector3i(-3, 13, -10), Vector3i(3, 13, -6), STRAW_DARK)


static func _bamboo(g: VoxelGrid) -> void:
	for i in range(4):
		var x := -4 + i * 3
		var h := 18 + (i * 7) % 6
		g.box(Vector3i(x, 0, -12 - i), Vector3i(x, h, -12 - i), Color("6f8a3a"), 0.08)
		g.box(Vector3i(x - 1, h - 2, -12 - i), Vector3i(x + 1, h, -12 - i), Color("4f7030"), 0.1)


# ---------- 远近景 ----------

## 背景的茅草屋（大格子，6 像素一格），原点在贴地中心
static func bg_house(seed_value: int, lit: bool) -> Array:
	var g := VoxelGrid.new(seed_value)
	var glow := VoxelGrid.new(seed_value + 5)
	var r := g.rng
	var hw := r.randi_range(6, 9)
	var h := r.randi_range(6, 8)
	var d := r.randi_range(5, 7)
	var wall := PLASTER.darkened(r.randf_range(0.1, 0.3)) if r.randf() < 0.6 else WOOD.lightened(0.05)
	# 只做外壳（里面是空的，少算很多格子）
	for x in range(-hw, hw + 1):
		for y in range(0, h):
			for z in range(-d, d + 1):
				if absi(x) == hw or absi(z) == d:
					g.set_v(Vector3i(x, y, z), wall.darkened(r.randf() * 0.08))
	for x in range(-hw, hw + 1, 3):
		g.box(Vector3i(x, 0, d), Vector3i(x, h - 1, d), WOOD_DARK)
	if lit:
		var wx := r.randi_range(-hw + 2, hw - 4)
		g.carve(Vector3i(wx, 2, d), Vector3i(wx + 1, 4, d))
		glow.box(Vector3i(wx, 2, d - 1), Vector3i(wx + 1, 4, d - 1), WINDOW)
	# 草顶：一层层往里收
	var layers := hw + 1
	for i in range(layers):
		var y := h + i
		var zz := d + 2 - i
		if zz < 0:
			break
		for x in range(-hw - 2 + i / 3, hw + 3 - i / 3):
			for z in [-zz, zz]:
				g.set_v(Vector3i(x, y, z), (STRAW if i % 2 == 0 else STRAW_DARK).darkened(0.15 + r.randf() * 0.1))
			if zz <= 1:
				for z in range(-zz, zz + 1):
					g.set_v(Vector3i(x, y, z), STRAW_DARK.darkened(0.2))
	return [g, glow if glow.size() > 0 else null, hw]


## 背景的树（松树或枯树；dead 只要枯树）
static func bg_tree(seed_value: int, dead: bool = false) -> VoxelGrid:
	var g := VoxelGrid.new(seed_value)
	var r := g.rng
	var h := r.randi_range(10, 16)
	g.box(Vector3i(0, 0, 0), Vector3i(0, h, 0), Color("3a2a22"))
	if not dead and r.randf() < 0.65:
		for i in range(4):
			var y := h - 2 - i * 3
			if y < 3:
				break
			var rad := 1.8 + i * 1.1
			g.ellipsoid(Vector3(0, y, 0), Vector3(rad, 1.6, rad), Color("2e4a3a").darkened(r.randf() * 0.15), 0.12)
	else:
		for i in range(3):
			var y := h - 3 - i * 3
			var dir := 1 if i % 2 == 0 else -1
			for k in range(3 + i):
				g.set_v(Vector3i(dir * (k + 1), y + k / 2, 0), Color("3a2a22"))
	return g


## 远山：一排高低起伏的柱子，有几座尖一点的山峰（tall 控制高度）
static func mountains(width_px: float, seed_value: int, col: Color, tall: float = 1.0) -> VoxelGrid:
	var g := VoxelGrid.new(seed_value)
	var cell := 20.0
	var n := int(width_px / cell) + 1
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	for x in range(n):
		var v := (noise.get_noise_1d(x) + 1.0) * 0.5
		var h := int((3.0 + 12.0 * v * v) * tall)
		for y in range(h):
			var c := col.lightened(float(y) / maxf(h, 1.0) * 0.1)
			if y >= h - 1 and h > 9:
				c = Color("8a7a9a")   # 山顶一点残雪
			g.set_v(Vector3i(x, y, 0), c)
			g.set_v(Vector3i(x, y, 1), c)
	return g


## 夕阳：一个发光的圆盘
static func sun_disc() -> VoxelGrid:
	var g := VoxelGrid.new(1)
	for x in range(-6, 7):
		for y in range(-6, 7):
			var d := Vector2(x, y).length()
			if d <= 6.2:
				g.set_v(Vector3i(x, y, 0), Color("ffd27a").lerp(Color("ff8a4a"), clampf(d / 6.2, 0.0, 1.0) * 0.7))
	return g


## 月亮
static func moon_disc() -> VoxelGrid:
	var g := VoxelGrid.new(2)
	for x in range(-5, 6):
		for y in range(-5, 6):
			var d := Vector2(x, y).length()
			if d <= 5.2:
				var c := Color("eef2ff")
				if (x == 1 and y == 2) or (x == -2 and y == -1) or (x == 2 and y == -2):
					c = Color("c8d0e8")   # 月面的坑
				g.set_v(Vector3i(x, y, 0), c)
	return g


## 坟地：几座坟包、木牌、石碑（4 像素一格）
static func bg_graves(seed_value: int) -> VoxelGrid:
	var g := VoxelGrid.new(seed_value)
	var r := g.rng
	for i in range(r.randi_range(3, 5)):
		var x := r.randi_range(-14, 14)
		var z := r.randi_range(-10, 4)
		g.ellipsoid(Vector3(x, 0, z), Vector3(3, 1.8, 2.4), Color("4a4236").darkened(r.randf() * 0.2), 0.1)
		if r.randf() < 0.6:
			g.box(Vector3i(x, 1, z - 2), Vector3i(x, 5, z - 2), Color("6b5a44"))
			g.box(Vector3i(x - 1, 4, z - 2), Vector3i(x + 1, 4, z - 2), Color("6b5a44"))
		else:
			g.box(Vector3i(x - 1, 0, z - 3), Vector3i(x + 1, 5, z - 3), STONE.darkened(0.2), 0.1)
	g.carve(Vector3i(-20, -4, -20), Vector3i(20, -1, 20))
	return g


## 竹丛（4 像素一格）
static func bg_bamboo(seed_value: int) -> VoxelGrid:
	var g := VoxelGrid.new(seed_value)
	var r := g.rng
	for i in range(r.randi_range(3, 6)):
		var x := r.randi_range(-6, 6)
		var z := r.randi_range(-6, 6)
		var h := r.randi_range(28, 46)
		var c := Color("5f7a34").darkened(r.randf() * 0.25)
		for y in range(h):
			g.set_v(Vector3i(x, y, z), c if y % 6 != 0 else c.darkened(0.3))
		for k in range(4):
			var y := h - 2 - k * 4
			var dir := 1 if (k + i) % 2 == 0 else -1
			for j in range(3):
				g.set_v(Vector3i(x + dir * (j + 1), y - j / 2, z), Color("4f7030").darkened(r.randf() * 0.2))
	return g


## 山贼营的帐篷，返回 [格子, 发光格子]（5 像素一格）
static func bg_tent(seed_value: int) -> Array:
	var g := VoxelGrid.new(seed_value)
	var glow := VoxelGrid.new(seed_value + 3)
	var c := Color("6a5a48").darkened(g.rng.randf() * 0.2)
	for y in range(0, 9):
		var hw := 9 - y
		for x in range(-hw, hw + 1):
			for z in range(-5, 6):
				if absi(x) == hw or y == 8:
					g.set_v(Vector3i(x, y, z), c if (z + y) % 3 != 0 else c.darkened(0.15))
	g.carve(Vector3i(-2, 0, 5), Vector3i(2, 4, 5))
	glow.box(Vector3i(-2, 0, 4), Vector3i(2, 3, 4), Color("ff9040"))
	g.box(Vector3i(0, 9, 0), Vector3i(0, 13, 0), WOOD_DARK)
	g.box(Vector3i(1, 11, 0), Vector3i(4, 13, 0), Color("8a2a24"))   # 破旗
	# 篝火
	for i in range(6):
		var a := i / 6.0 * TAU
		g.set_v(Vector3i(6 + roundi(cos(a) * 2.0), 0, 8 + roundi(sin(a) * 2.0)), STONE_DARK)
	glow.box(Vector3i(5, 1, 7), Vector3i(7, 2, 9), Color("ff7a28"))
	return [g, glow]


## 芦苇（河边，4 像素一格）
static func bg_reeds(seed_value: int) -> VoxelGrid:
	var g := VoxelGrid.new(seed_value)
	var r := g.rng
	for i in range(r.randi_range(5, 9)):
		var x := r.randi_range(-10, 10)
		var z := r.randi_range(-3, 3)
		var h := r.randi_range(4, 9)
		for y in range(h):
			g.set_v(Vector3i(x + (1 if y > h - 3 and i % 2 == 0 else 0), y, z), Color("6a6a3a").darkened(r.randf() * 0.2))
		g.set_v(Vector3i(x, h, z), Color("8a7a4a"))
	return g


## 河面：一大片深蓝，带几道月光反光（8 像素一格，原点在左前角）
static func water(width_px: float, seed_value: int) -> VoxelGrid:
	var g := VoxelGrid.new(seed_value)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.12
	var n := int(width_px / 8.0)
	for x in range(n):
		for z in range(-70, 1):
			var v := noise.get_noise_2d(x * 0.5, z * 2.0)
			var c := Color("101a30").lerp(Color("1a2c48"), clampf(v + 0.5, 0.0, 1.0))
			if v > 0.45:
				c = Color("5a6e90")   # 波光
			g.set_v(Vector3i(x, 0, z), c)
	return g


## 破庙：大殿、台阶、两根柱子、瓦顶，门里透出灯光。返回 [格子, 发光格子]（6 像素一格）
static func bg_temple(seed_value: int) -> Array:
	var g := VoxelGrid.new(seed_value)
	var glow := VoxelGrid.new(seed_value + 1)
	var wall := Color("6a4a3a")
	g.box(Vector3i(-24, 0, -8), Vector3i(24, 2, 8), STONE, 0.08)          # 台基
	for i in range(3):
		g.box(Vector3i(-8, i, 9 + i), Vector3i(8, i, 9 + i), STONE_DARK, 0.06)
	for x in range(-20, 21):                                              # 墙（外壳）
		for y in range(3, 16):
			for z in [-6, 6]:
				g.set_v(Vector3i(x, y, z), wall.darkened(g.rng.randf() * 0.1))
	for x in [-20, 20]:
		g.box(Vector3i(x, 3, -6), Vector3i(x, 15, 6), wall)
	for x in [-14, -7, 7, 14]:                                            # 红柱
		g.box(Vector3i(x, 3, 7), Vector3i(x, 15, 7), Color("8a2e26"))
	g.carve(Vector3i(-4, 3, 6), Vector3i(4, 12, 6))                        # 门
	glow.box(Vector3i(-4, 3, 5), Vector3i(4, 12, 5), Color("ffa850"))
	for wx in [-16, 11]:
		g.carve(Vector3i(wx, 7, 6), Vector3i(wx + 4, 11, 6))
		glow.box(Vector3i(wx, 7, 5), Vector3i(wx + 4, 11, 5), Color("ff9a48"))
	for i in range(8):                                                    # 歇山顶，一层层往里收
		var y := 16 + i
		var zz := 10 - i
		for x in range(-26 + i, 27 - i):
			for z in [-zz, zz]:
				g.set_v(Vector3i(x, y, z), Color("3a3a48").lightened(0.06 if i % 2 == 0 else 0.0))
		if zz <= 3:
			for x in range(-26 + i, 27 - i):
				for z in range(-zz, zz + 1):
					g.set_v(Vector3i(x, y, z), Color("2e2e3a"))
	for x in [-26, 26]:                                                    # 翘角
		g.set_v(Vector3i(x, 17, 10), Color("3a3a48"))
		g.set_v(Vector3i(x + (1 if x > 0 else -1), 18, 10), Color("3a3a48"))
	g.carve(Vector3i(8, 21, -10), Vector3i(14, 24, 10))                    # 塌了一块屋顶
	return [g, glow]
