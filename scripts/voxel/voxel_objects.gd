class_name VoxelObjects
extends RefCounted
## 会动、会坏的东西的体素模型：能砍碎的罐子箱子、宝箱、遗骸、房门、土地庙，
## 还有机关（竹签、烂木板、木架、寨门、拉杆、石灯笼、裂墙）。
## 网格都按种类缓存；摆在哪、开没开、亮没亮由 VoxelView 每帧照 2D 的状态去改。
## 原点都在贴地中心，一格 2 像素（SMALL）或 4 像素（BIG）。

const SMALL := 2.0
const BIG := 4.0

static var _cache := {}


static func mesh(key: String) -> Mesh:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


static func _build(key: String) -> Mesh:
	var g := VoxelGrid.new(hash(key))
	var s := SMALL
	var glow := false
	match key:
		"jar":
			g.ellipsoid(Vector3(0, 3, 0), Vector3(3.2, 3.2, 3.2), Color("a86a44"), 0.08)
			g.carve(Vector3i(-4, -2, -4), Vector3i(4, -1, 4))
			g.box(Vector3i(-1, 6, -1), Vector3i(1, 7, 1), Color("8a5636"))
			g.paint(Vector3i(-4, 4, -4), Vector3i(4, 4, 4), Color("e0c890"))
		"urn":
			g.ellipsoid(Vector3(0, 4.5, 0), Vector3(3.6, 4.8, 3.6), Color("4a5a6a"), 0.08)
			g.carve(Vector3i(-4, -2, -4), Vector3i(4, -1, 4))
			g.box(Vector3i(-2, 9, -2), Vector3i(2, 9, 2), Color("3a4656"))
			g.paint(Vector3i(-4, 6, -4), Vector3i(4, 6, 4), Color("c8b070"))
		"barrel":
			g.ellipsoid(Vector3(0, 4.5, 0), Vector3(4.0, 5.2, 4.0), Color("7a5232"), 0.1)
			g.carve(Vector3i(-5, -2, -5), Vector3i(5, -1, 5))
			g.carve(Vector3i(-5, 10, -5), Vector3i(5, 11, 5))
			for y in [1, 8]:
				g.paint(Vector3i(-5, y, -5), Vector3i(5, y, 5), Color("3a3a3e"))
		"box":
			g.box(Vector3i(-4, 0, -4), Vector3i(3, 7, 3), Color("9a7650"), 0.08)
			for e in [[-4, -4], [3, -4], [-4, 3], [3, 3]]:
				g.paint(Vector3i(e[0], 0, e[1]), Vector3i(e[0], 7, e[1]), Color("4a3324"))
			g.paint(Vector3i(-4, 7, -4), Vector3i(3, 7, 3), Color("6b4a33"))
		"chest_base":
			g.box(Vector3i(-6, 0, -4), Vector3i(5, 4, 3), Color("7a4a2a"), 0.08)
			g.paint(Vector3i(-6, 0, -4), Vector3i(-6, 4, 3), Color("c8a040"))
			g.paint(Vector3i(5, 0, -4), Vector3i(5, 4, 3), Color("c8a040"))
		"chest_lid":
			# 原点在后边的铰链上
			g.box(Vector3i(0, 0, -4), Vector3i(11, 2, 3), Color("8a5432"), 0.08)
			g.paint(Vector3i(0, 0, -4), Vector3i(0, 2, 3), Color("c8a040"))
			g.paint(Vector3i(11, 0, -4), Vector3i(11, 2, 3), Color("c8a040"))
			g.box(Vector3i(5, -1, 4), Vector3i(6, 0, 4), Color("e8c860"))   # 锁扣
			return g.build(s, Vector3(0, 0, -4))
		"chest_gold":
			g.box(Vector3i(-5, 4, -3), Vector3i(4, 4, 2), Color("ffd060"))
			glow = true
		"note":
			# 遗骸：一堆白骨、半截刀、一张纸
			var bone := Color("d8d0bc")
			g.ellipsoid(Vector3(-3, 1.5, -2), Vector3(2.2, 2.0, 2.0), bone, 0.06)
			g.set_v(Vector3i(-2, 1, 0), Color("2a2420"))
			g.box(Vector3i(0, 0, -3), Vector3i(6, 0, -3), bone)
			g.box(Vector3i(1, 0, -1), Vector3i(5, 0, -1), bone)
			g.box(Vector3i(2, 0, 1), Vector3i(8, 0, 1), Color("8a8e96"))
			g.box(Vector3i(-6, 0, 0), Vector3i(-4, 0, 3), Color("e8dcc0"))
		"door_frame":
			# 房门：鸟居一样的红木门框，宽 44 高 62（一格 2 像素）
			var post := Color("6e2a22")
			var dark := Color("2a1418")
			g.box(Vector3i(-11, 0, -2), Vector3i(-10, 31, 1), post, 0.06)
			g.box(Vector3i(10, 0, -2), Vector3i(11, 31, 1), post, 0.06)
			g.box(Vector3i(-14, 32, -3), Vector3i(14, 33, 2), dark, 0.05)
			g.box(Vector3i(-12, 28, -2), Vector3i(12, 28, 1), post)
			g.box(Vector3i(-1, 29, -1), Vector3i(0, 31, 0), Color("c8b890"))
			g.box(Vector3i(-12, 0, -3), Vector3i(-9, 0, 2), Color("4a4040"))
			g.box(Vector3i(9, 0, -3), Vector3i(12, 0, 2), Color("4a4040"))
		"shrine":
			# 土地庙：石台、小木龛、瓦顶
			g.box(Vector3i(-7, 0, -5), Vector3i(6, 3, 4), Color("8a8478"), 0.08)
			g.box(Vector3i(-5, 4, -4), Vector3i(4, 12, 3), Color("6b4a33"), 0.06)
			g.carve(Vector3i(-3, 5, 3), Vector3i(2, 10, 3))
			g.box(Vector3i(-3, 5, 2), Vector3i(2, 10, 2), Color("2a1a14"))
			g.box(Vector3i(-1, 5, 1), Vector3i(0, 7, 1), Color("c8b890"))
			g.box(Vector3i(-8, 13, -6), Vector3i(7, 13, 5), Color("4a4a56"), 0.06)
			g.box(Vector3i(-6, 14, -5), Vector3i(5, 14, 4), Color("5a5a66"), 0.06)
			g.box(Vector3i(-3, 15, -3), Vector3i(2, 15, 2), Color("4a4a56"))
		"shrine_glow":
			g.box(Vector3i(-2, 8, 1), Vector3i(1, 9, 1), Color("ffb860"))
			glow = true
		# ---------- 机关（4 像素一格）----------
		"spike":
			s = BIG
			g.box(Vector3i(0, 0, 0), Vector3i(0, 3, 0), Color("8a8a50"))
			g.set_v(Vector3i(0, 4, 0), Color("c8c890"))
		"plank":
			s = BIG
			g.box(Vector3i(-3, -1, -4), Vector3i(2, 0, 2), Color("8a7050"), 0.12)
			g.paint(Vector3i(-3, 0, -4), Vector3i(2, 0, 2), Color("a08060"), 0.12)
		"ledge":
			s = BIG
			g.box(Vector3i(-3, -1, -4), Vector3i(2, 0, 2), Color("7a5a3a"), 0.08)
			g.box(Vector3i(-1, -20, -2), Vector3i(0, -2, -2), Color("5a3e28"))
		"gate_wall":
			# 寨墙：一排削尖的圆木，从门洞顶上到 190 像素高；z 跨过角色那一层
			s = BIG
			for x in range(-3, 3):
				var h := 47 - (absi(x) % 2)
				for z in range(-8, 6):
					for y in range(19, h + 1):
						g.set_v(Vector3i(x, y, z), Color("3e2a20").lightened(0.06 if (x + z) % 2 == 0 else 0.0))
				for z in range(-8, 6):
					g.set_v(Vector3i(x, h + 1, z), Color("5a3e2a"))
			g.box(Vector3i(-4, 17, -9), Vector3i(3, 18, 6), Color("1e1410"))
			for x in [-4, 3]:
				g.box(Vector3i(x, 0, -9), Vector3i(x, 16, -8), Color("1e1410"))
				g.box(Vector3i(x, 0, 5), Vector3i(x, 16, 6), Color("1e1410"))
		"gate_bars":
			# 铁栅栏：原点在底边，高 74
			s = BIG
			for z in range(-8, 6, 2):
				g.box(Vector3i(-3, 0, z), Vector3i(-3, 17, z), Color("5a5a64"))
				g.box(Vector3i(2, 0, z), Vector3i(2, 17, z), Color("5a5a64"))
			g.box(Vector3i(-3, 9, -8), Vector3i(2, 9, 5), Color("6a6a74"))
			g.box(Vector3i(-3, 0, -8), Vector3i(2, 0, 5), Color("6a6a74"))
		"lever_base":
			s = SMALL
			g.box(Vector3i(-3, 0, -3), Vector3i(2, 2, 2), Color("625d55"), 0.08)
			g.box(Vector3i(-1, 3, -1), Vector3i(0, 4, 0), Color("4a4a50"))
		"lever_handle":
			s = SMALL
			g.box(Vector3i(0, 0, 0), Vector3i(0, 9, 0), Color("6b4a33"))
			g.box(Vector3i(-1, 10, -1), Vector3i(1, 11, 1), Color("c84a3a"))
			return g.build(s, Vector3(0.5, 0, 0.5))
		"stone_lantern":
			s = SMALL
			g.box(Vector3i(-2, 0, -2), Vector3i(1, 10, 1), Color("8a8478"), 0.08)
			g.box(Vector3i(-4, 11, -4), Vector3i(3, 12, 3), Color("8a8478"), 0.08)
			g.box(Vector3i(-3, 13, -3), Vector3i(2, 17, 2), Color("8a8478"), 0.08)
			g.carve(Vector3i(-2, 14, 2), Vector3i(1, 16, 2))
			g.box(Vector3i(-2, 14, 1), Vector3i(1, 16, 1), Color("2a2420"))
			g.box(Vector3i(-5, 18, -5), Vector3i(4, 18, 4), Color("625d55"))
			g.box(Vector3i(-3, 19, -3), Vector3i(2, 20, 2), Color("625d55"))
			g.box(Vector3i(-1, 21, -1), Vector3i(0, 22, 0), Color("625d55"))
		"stone_lantern_glow":
			s = SMALL
			g.box(Vector3i(-2, 14, 1), Vector3i(1, 16, 1), Color("ffb050"))
			glow = true
		"crack":
			s = BIG
			g.rng.seed = 5
			for x in range(-3, 3):
				for y in range(0, 48):
					for z in range(-8, 6):
						var c := Color("6e5a44").darkened(g.rng.randf() * 0.15)
						if (y + x * 2) % 9 == 0:
							c = Color("4a3e34")
						g.set_v(Vector3i(x, y, z), c)
			for k in range(10):   # 裂缝
				g.paint(Vector3i(2, 8 + k * 2, -1 + (k % 3)), Vector3i(2, 8 + k * 2, -1 + (k % 3)), Color("1e1814"))
			g.box(Vector3i(-4, 48, -9), Vector3i(3, 48, 6), Color("5f6a3a"), 0.1)
		"crack_rubble":
			s = BIG
			g.rng.seed = 6
			for i in range(30):
				var p := Vector3i(g.rng.randi_range(-4, 4), 0, g.rng.randi_range(-8, 5))
				g.set_v(p, Color("4a3e34").darkened(g.rng.randf() * 0.2))
				if g.rng.randf() < 0.4:
					g.set_v(p + Vector3i(0, 1, 0), Color("5a4a3c"))
	return g.build(s, Vector3(0.5, 0, 0.5), glow)


## 砍碎时溅出来的方块颜色
static func shard_colors(kind: String) -> Array:
	match kind:
		"jar": return [Color("a86a44"), Color("8a5636"), Color("e0c890")]
		"urn": return [Color("4a5a6a"), Color("3a4656"), Color("c8b070")]
		"barrel": return [Color("7a5232"), Color("3a3a3e"), Color("5a3e28")]
		"box": return [Color("9a7650"), Color("4a3324"), Color("6b4a33")]
		"crack": return [Color("6e5a44"), Color("4a3e34"), Color("5a4a3c")]
	return [Color("8a8478")]
