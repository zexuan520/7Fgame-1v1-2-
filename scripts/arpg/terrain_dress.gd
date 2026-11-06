class_name TerrainDress
extends RefCounted
## 地形层：Arena 摆完各区域自己的件以后再铺一层，让地面不再是一张平图、墙外不再是一片黑。
##   1. 边坡：墙外一圈体素土坡 / 岩壁 / 石阶（按区域换样式），从墙根的矮沿升到几米高的台地，台地上种树、堆石头
##   2. 地面碎件：草丛、碎石、落叶、树根、苔藓、骨头、稻草、碎瓦、铜钱、灰烬……一小片一小片撒在地上，靠墙、靠障碍物的地方多
##   3. 场中石丛（大房间）：大石头 + 碎石 + 草，当掩体绕着打
##   4. 每层专属摆设（大房间）：营地的兵器架和箭靶、内库的宝箱、村子的独轮车和水桶……
## 性能：边坡一段、碎件一片都按样式缓存（跨房间复用），摆的时候按 10 米一格合成一块大网格，绘制调用很少；
## 低画质边坡格子放粗一倍、碎件减半。没有新灯。
## 测试：--noterrain 关掉整层（对比用）

const SEG := 5.0       # 边坡一段多长（米）
const DEPTH := 4.5     # 边坡往墙外伸多深
const CV := 0.05       # 碎件一格多大（米）
const CHUNK := 10.0

## 边坡样式：top/top2 顶面两种颜色（按噪声分块）、side/side2 坡面两种（按层分带）、rock 嵌在坡里的石头、
## h 台地高度（米）、ramp 墙根到台地的坡长、rough 起伏（米）、step 台阶高（格，0 = 不做台阶）、
## back 后墙外也堆（false 只堆两侧）、crown 台地上种什么（kit 件 id）
const BANK := {
	"forest": {"top": Color(0.11, 0.22, 0.15), "top2": Color(0.16, 0.28, 0.17), "side": Color(0.19, 0.15, 0.12), "side2": Color(0.15, 0.12, 0.1),
		"rock": Color(0.28, 0.3, 0.29), "h": 2.4, "ramp": 2.2, "rough": 0.8, "step": 0, "back": true,
		"crown": ["tree_dead", "tree_dead_m", "rock_c", "rock_a", "tree_dead_s"]},
	"sakura": {"top": Color(0.2, 0.17, 0.26), "top2": Color(0.32, 0.2, 0.3), "side": Color(0.22, 0.19, 0.22), "side2": Color(0.18, 0.15, 0.19),
		"rock": Color(0.32, 0.31, 0.36), "h": 1.6, "ramp": 1.8, "rough": 0.5, "step": 0, "back": false,
		"crown": ["rock_c", "rock_e", "tree_dead_s"]},
	"grave": {"top": Color(0.15, 0.19, 0.13), "top2": Color(0.2, 0.22, 0.14), "side": Color(0.17, 0.15, 0.12), "side2": Color(0.13, 0.12, 0.1),
		"rock": Color(0.3, 0.3, 0.29), "h": 2.0, "ramp": 2.4, "rough": 0.7, "step": 0, "back": true,
		"crown": ["tree_dead", "tree_dead_m", "gravestone", "grave_broken", "tree_dead_s", "rock_a"]},
	"well": {"top": Color(0.17, 0.2, 0.23), "top2": Color(0.12, 0.2, 0.22), "side": Color(0.2, 0.23, 0.26), "side2": Color(0.14, 0.17, 0.2),
		"rock": Color(0.26, 0.3, 0.33), "h": 3.4, "ramp": 1.6, "rough": 1.1, "step": 0, "back": false,
		"crown": ["rock_c", "rock_e", "rock_a", "column"]},
	"vault": {"top": Color(0.2, 0.15, 0.12), "top2": Color(0.26, 0.19, 0.13), "side": Color(0.27, 0.2, 0.15), "side2": Color(0.19, 0.14, 0.11),
		"rock": Color(0.33, 0.25, 0.18), "h": 3.0, "ramp": 1.4, "rough": 0.9, "step": 3, "back": false,
		"crown": ["rubble_half", "rock_c", "pillar"]},
	"camp": {"top": Color(0.24, 0.24, 0.17), "top2": Color(0.3, 0.27, 0.19), "side": Color(0.27, 0.22, 0.17), "side2": Color(0.22, 0.18, 0.14),
		"rock": Color(0.36, 0.34, 0.31), "h": 1.6, "ramp": 1.8, "rough": 0.5, "step": 0, "back": true,
		"crown": ["fence_wood", "tree_dead_m", "rock_a", "flag", "tree_dead_s"]},
	"liuxi": {"top": Color(0.3, 0.36, 0.17), "top2": Color(0.4, 0.4, 0.2), "side": Color(0.36, 0.28, 0.2), "side2": Color(0.3, 0.23, 0.17),
		"rock": Color(0.42, 0.4, 0.37), "h": 1.4, "ramp": 2.0, "rough": 0.5, "step": 0, "back": false,
		"crown": ["tree_a", "tree_b", "fence_wood", "rock_e", "trees"]},
	"post": {"top": Color(0.17, 0.2, 0.16), "top2": Color(0.22, 0.22, 0.17), "side": Color(0.2, 0.18, 0.16), "side2": Color(0.16, 0.15, 0.14),
		"rock": Color(0.32, 0.33, 0.35), "h": 1.8, "ramp": 2.0, "rough": 0.6, "step": 0, "back": false,
		"crown": ["tree_dead", "tree_pine", "fence_stone", "rock_c", "tree_b"]},
	"palace": {"top": Color(0.78, 0.72, 0.6), "top2": Color(0.72, 0.66, 0.55), "side": Color(0.66, 0.6, 0.5), "side2": Color(0.58, 0.5, 0.36),
		"rock": Color(0.75, 0.6, 0.3), "h": 1.2, "ramp": 1.6, "rough": 0.0, "step": 2, "back": false, "lum": 1.0,
		"crown": ["barrier_col", "banner_gold", "barrier"]},
}

## 地面碎件：d 每百平米撒几片，k 是 [种类, 权重, 颜色...]
const CLUTTER := {
	"forest": {"d": 10, "k": [["grass", 6, Color(0.1, 0.26, 0.16), Color(0.2, 0.4, 0.22)], ["pebbles", 2, Color(0.3, 0.32, 0.3)],
		["roots", 2, Color(0.17, 0.12, 0.1)], ["leaves", 2, Color(0.3, 0.24, 0.12), Color(0.2, 0.28, 0.14)], ["moss", 3, Color(0.12, 0.27, 0.17), Color(0.16, 0.32, 0.18)]]},
	"sakura": {"d": 8, "k": [["leaves", 6, Color(0.85, 0.5, 0.65), Color(0.7, 0.36, 0.5)], ["grass", 3, Color(0.16, 0.22, 0.2), Color(0.24, 0.32, 0.26)],
		["pebbles", 2, Color(0.36, 0.35, 0.4)]]},
	"grave": {"d": 10, "k": [["grass", 5, Color(0.17, 0.22, 0.13), Color(0.3, 0.32, 0.17)], ["bones", 3, Color(0.78, 0.74, 0.62)],
		["pebbles", 2, Color(0.3, 0.3, 0.28)], ["leaves", 2, Color(0.27, 0.22, 0.14), Color(0.2, 0.17, 0.12)], ["roots", 1, Color(0.14, 0.11, 0.09)]]},
	"temple": {"d": 6, "k": [["shards", 3, Color(0.3, 0.3, 0.33)], ["leaves", 3, Color(0.78, 0.72, 0.56), Color(0.62, 0.55, 0.42)],
		["ash", 2, Color(0.36, 0.34, 0.33), Color(0.24, 0.22, 0.22)], ["pebbles", 1, Color(0.36, 0.3, 0.26)]]},
	"well": {"d": 9, "k": [["moss", 4, Color(0.1, 0.24, 0.24), Color(0.14, 0.3, 0.28)], ["pebbles", 3, Color(0.3, 0.34, 0.37)],
		["weeds", 3, Color(0.1, 0.28, 0.27), Color(0.2, 0.42, 0.36)], ["shards", 2, Color(0.24, 0.27, 0.3)], ["bones", 1, Color(0.62, 0.66, 0.66)]]},
	"vault": {"d": 8, "k": [["coins", 3, Color(0.85, 0.62, 0.22)], ["shards", 3, Color(0.3, 0.22, 0.16)], ["ash", 3, Color(0.22, 0.16, 0.13), Color(0.5, 0.25, 0.1)],
		["pebbles", 2, Color(0.34, 0.26, 0.2)]]},
	"camp": {"d": 10, "k": [["straw", 5, Color(0.46, 0.4, 0.26), Color(0.36, 0.3, 0.2)], ["pebbles", 2, Color(0.4, 0.37, 0.33)],
		["grass", 2, Color(0.28, 0.28, 0.17), Color(0.38, 0.36, 0.2)], ["ash", 2, Color(0.26, 0.24, 0.23), Color(0.16, 0.15, 0.15)], ["leaves", 1, Color(0.4, 0.33, 0.2), Color(0.32, 0.26, 0.17)]]},
	"liuxi": {"d": 11, "k": [["grass", 5, Color(0.3, 0.4, 0.16), Color(0.48, 0.5, 0.22)], ["straw", 3, Color(0.56, 0.48, 0.3), Color(0.44, 0.36, 0.22)],
		["pebbles", 2, Color(0.44, 0.42, 0.38)], ["leaves", 3, Color(0.6, 0.38, 0.2), Color(0.5, 0.3, 0.16)]]},
	"post": {"d": 10, "k": [["grass", 4, Color(0.16, 0.22, 0.17), Color(0.26, 0.3, 0.2)], ["pebbles", 3, Color(0.32, 0.34, 0.37)],
		["leaves", 3, Color(0.3, 0.24, 0.15), Color(0.22, 0.2, 0.14)], ["straw", 1, Color(0.4, 0.34, 0.2)], ["shards", 1, Color(0.3, 0.32, 0.35)]]},
	"palace": {"d": 3, "k": [["shards", 3, Color(0.8, 0.74, 0.62)], ["coins", 1, Color(0.95, 0.75, 0.3)]]},
}

## 每层专属摆设（只摆在大房间）：[kit id, 权重, 有碰撞, 缩放]
const PROPS := {
	"forest": [["tree_dead_s", 2, true, 1.0], ["bone_c", 2, false, 0.6], ["stones", 2, false, 1.0], ["rubble_half", 1, true, 1.0]],
	"sakura": [["stones", 2, false, 1.0], ["rock_d", 2, true, 1.0]],
	"grave": [["grave_broken", 3, true, 1.0], ["gravemarker_b", 2, false, 1.0], ["bone_a", 2, false, 0.6], ["bone_b", 2, false, 0.6],
		["fence_pillar", 1, true, 1.0], ["tree_dead_s", 1, true, 1.0], ["lantern_hang", 1, false, 1.0]],
	"temple": [["table_s", 2, true, 1.0], ["banner", 2, true, 1.1], ["chest", 1, true, 1.0], ["barrel_deco", 1, true, 1.0], ["rubble_half", 1, true, 0.8]],
	"well": [["reeds_a", 3, false, 1.0], ["reeds_b", 3, false, 1.2], ["rubble_half", 2, true, 1.0],
		["barrier_col", 1, true, 1.0]],
	"vault": [["chest_gold", 2, true, 1.0], ["coins", 3, false, 1.0], ["trunk", 2, true, 1.0], ["keg", 1, true, 1.0], ["barrel_deco", 2, true, 1.0],
		["banner_gold", 1, true, 1.0], ["rubble_half", 1, true, 1.0]],
	"camp": [["weaponrack", 3, true, 1.0], ["target", 2, true, 1.0], ["arrows", 3, false, 1.0], ["wheelbarrow", 2, true, 1.0], ["pallet", 2, false, 1.0],
		["crate_long", 2, true, 1.0], ["crate_open", 2, false, 1.0], ["flag", 1, true, 1.0], ["bucket", 2, false, 1.0], ["keg", 1, true, 1.0]],
	"liuxi": [["wheelbarrow", 2, true, 1.0], ["bucket", 3, false, 1.0], ["crate_open", 2, false, 1.0], ["pallet", 2, false, 1.0], ["sack", 2, false, 1.0],
		["fence_wood", 2, true, 1.0], ["reeds_a", 2, false, 1.0], ["tree_b", 1, true, 0.8]],
	"post": [["crate_long", 3, true, 1.0], ["barrel_deco", 2, true, 1.0], ["wheelbarrow", 2, true, 1.0], ["bucket", 2, false, 1.0], ["pallet", 1, false, 1.0],
		["fence_stone", 2, true, 1.0], ["stones", 2, false, 1.0]],
	"palace": [["banner_gold", 2, true, 1.0], ["banner", 2, true, 1.2], ["chest_gold", 2, true, 1.0], ["coins", 2, false, 1.0], ["table_m", 1, true, 1.0]],
}

## 扁平、有正面的件：只朝镜头摆
const FACING := ["banner", "banner_gold", "banner_thin", "weaponrack", "target", "flag", "barrier", "barrier_col", "fence_wood", "fence_stone", "table_m"]

## 场中石丛：哪些区域有、主石用哪几块
const OUTCROP := {
	"forest": ["rock_a", "rock_c", "rock_e"], "grave": ["gravestone", "grave_a", "grave_broken"], "sakura": ["rock_c", "rock_e"],
	"well": ["rock_a", "rock_c", "rock_e"], "camp": ["rock_c"], "liuxi": ["rock_e", "rock_c"], "post": ["rock_a", "rock_c", "rock_e"],
}

static var _seg_cache := {}
static var _patch_cache := {}


static func apply(a: Arena) -> void:
	if OS.get_cmdline_user_args().has("--noterrain"):
		return
	var t0 := Time.get_ticks_msec()
	var zid := a.zone
	var parts: Array = []   # [网格, 变换]，最后按 10 米一格合起来
	var tm := []
	if BANK.has(zid):
		_banks(a, BANK[zid], parts)
	tm.append(Time.get_ticks_msec() - t0)
	var big := a.size.x >= 40.0
	if big and OUTCROP.has(zid):
		_outcrops(a, OUTCROP[zid])
	tm.append(Time.get_ticks_msec() - t0)
	if big and PROPS.has(zid):
		_props(a, PROPS[zid])
	tm.append(Time.get_ticks_msec() - t0)
	if CLUTTER.has(zid):
		_clutter(a, CLUTTER[zid], parts)
	tm.append(Time.get_ticks_msec() - t0)
	_merge(a, parts)
	tm.append(Time.get_ticks_msec() - t0)
	if OS.get_cmdline_user_args().has("--dbg"):
		print("terrain ms ", Time.get_ticks_msec() - t0, " parts ", parts.size(), " 边坡/土丘/摆设/碎件/合并 ", tm)


# ---------- 边坡 ----------

static func _bv() -> float:
	return 0.4 if Arena.lod == 0 else 0.2


static func _banks(a: Arena, st: Dictionary, parts: Array) -> void:
	var hx := a.size.x * 0.5
	var hz := a.size.y * 0.5
	var crown: Array = st["crown"]
	var plateau := float(st["h"]) - float(st["rough"]) * 0.6
	# 后墙外（从左外角到右外角）
	if bool(st["back"]):
		var x := -hx - DEPTH
		while x < hx + DEPTH:
			var m := _segment(a.zone, st, a.rng.randi() % 4)
			parts.append([m, Transform3D(Basis.IDENTITY, Vector3(x, 0, -hz))])
			if a.rng.randf() < 0.6:
				_crown(a, crown, Vector3(x + a.rng.randf_range(0.8, SEG - 0.8), plateau, -hz - a.rng.randf_range(float(st["ramp"]) + 0.6, DEPTH - 0.6)))
			x += SEG
	# 两侧（侧室那一段空出来）
	var z0 := -hz - (0.0 if bool(st["back"]) else DEPTH)
	for side: float in [-1.0, 1.0]:
		var z := z0
		while z < hz + 2.0:
			if not _side_blocked(a, side, z, z + SEG):
				var m := _segment(a.zone, st, a.rng.randi() % 4)
				var xf: Transform3D
				if side > 0.0:
					xf = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(hx, 0, z))
				else:
					xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-hx, 0, z + SEG))
				parts.append([m, xf])
				if a.rng.randf() < 0.7:
					var out := a.rng.randf_range(float(st["ramp"]) + 0.6, DEPTH - 0.6)
					_crown(a, crown, Vector3(side * (hx + out), plateau, z + a.rng.randf_range(0.8, SEG - 0.8)))
			z += SEG


static func _side_blocked(a: Arena, side: float, z0: float, z1: float) -> bool:
	for dr: Dictionary in a.doors:
		if float(dr["side"]) != side:
			continue
		var rm: Vector2 = dr.get("room", Vector2(10, 10))
		var half := maxf(rm.y, float(dr["w"])) * 0.5 + 0.6
		var c := float(dr["z"])
		if z1 > c - half and z0 < c + half:
			return true
	return false


## 台地上种一棵树 / 一块石头（没有碰撞，在墙外）
static func _crown(a: Arena, ids: Array, p: Vector3) -> void:
	var id: String = ids[a.rng.randi() % ids.size()]
	a.kit(id, p, a.rng.randf() * TAU, a.rng.randf_range(0.85, 1.15), false)


## 一段边坡（u 沿墙 0~SEG 是 +x，v 往墙外 0~DEPTH 是 -z），两头的剖面对所有段都一样，任意两段接得上
static func _segment(zid: String, st: Dictionary, variant: int) -> Array:
	var bv := _bv()
	var key := "%s|%d|%.2f|%d" % [zid, variant, bv, int(VoxelGrid.quant)]
	if _seg_cache.has(key):
		return _seg_cache[key]
	var g := VoxelGrid.new(variant * 131 + 7)
	var rng := g.rng
	var nz := FastNoiseLite.new()
	nz.seed = 1000 + variant * 17 + zid.hash() % 1000
	nz.frequency = 0.3
	var ne := FastNoiseLite.new()
	ne.seed = zid.hash() % 9973
	ne.frequency = 0.3
	var nc := FastNoiseLite.new()
	nc.seed = 55 + variant
	nc.frequency = 0.5
	var nu := int(round(SEG / bv))
	var nv := int(round(DEPTH / bv))
	var H := float(st["h"])
	var ramp := float(st["ramp"])
	var rough := float(st["rough"])
	var step := int(st["step"])
	if step > 0 and bv > 0.3:
		step = maxi(1, step / 2)
	var hm := PackedInt32Array()
	hm.resize(nu * nv)
	for iu in range(nu):
		var u := (iu + 0.5) * bv
		var w := sin(PI * u / SEG)
		for iv in range(nv):
			var v := (iv + 0.5) * bv
			var base := 0.2 + (H - 0.2) * smoothstep(0.0, ramp, v)
			var n := lerpf(ne.get_noise_1d(v * 3.0), nz.get_noise_2d(u * 2.0, v * 2.0), w)
			var h := base + rough * n * clampf(v / ramp, 0.25, 1.0)
			var hc := maxi(1, int(round(h / bv)))
			if step == 0:
				# 两格一层的梯田状（体素味更足，同高的顶面能合并成大块，三角形少一半多）
				hc = maxi(1, int(round(hc / 2.0)) * 2)
			if step > 0:
				# 石阶：一级一级（宫里的白玉台基），每级往外退一点
				var nl := maxi(1, int(round(H / (step * bv))))
				var lvl := mini(nl - 1, int(floor(v / (ramp / nl))))
				hc = (lvl + 1) * step + (int(round(rough * n / bv)) if v > ramp else 0)
			hm[iu * nv + iv] = hc
	# 墙外没有灯（只吃环境光和月光），颜色比地面提亮一些，不然整圈黑成一片
	var lum := float(st.get("lum", 1.5))
	var top: Color = st["top"] * lum
	var top2: Color = st["top2"] * lum
	var side: Color = st["side"] * lum
	var side2: Color = st["side2"] * lum
	for iu in range(nu):
		for iv in range(nv):
			var hc := hm[iu * nv + iv]
			# 往下填到四邻里最矮的那一格（看得见的坡面），下面是实心的不用填
			var lo := hc
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ju := iu + d.x
				var jv := iv + d.y
				var nb := 0
				if jv < 0:
					nb = 0                       # 墙根：地面
				elif jv >= nv:
					nb = 0                       # 最外沿
				elif ju < 0 or ju >= nu:
					nb = hc                      # 两头：接下一段
				else:
					nb = hm[ju * nv + jv]
				lo = mini(lo, nb)
			var tc := top if nc.get_noise_2d(iu * 0.5 * bv / 0.2, iv * 0.5 * bv / 0.2) < 0.15 else top2
			# 从地面一直填上来：底面全在 y=0 同一层同一色，合并成一大块（只填露出来的几层的话，每根柱子底下都多一个朝下的面）
			for y in range(0, hc):
				var c: Color
				if y >= hc - 1:
					c = tc
				else:
					c = side if (y / 3) % 2 == 0 else side2
				g.cells[Vector3i(iu, y, -iv - 1)] = c
	# 嵌在坡上的石头（离两头远一点，别把接缝顶出来）
	var rock: Color = st["rock"] * lum
	if rough > 0.0:
		for i in range(2 + rng.randi() % 2):
			var cu := rng.randf_range(1.0, SEG - 1.0) / bv
			var cv := rng.randf_range(0.6, ramp + 0.8) / bv
			var r := rng.randf_range(0.35, 0.7) / bv
			var hh := hm[clampi(int(cu), 0, nu - 1) * nv + clampi(int(cv), 0, nv - 1)]
			var c2 := rock * (0.9 if i % 2 == 0 else 1.05)
			g.ellipsoid(Vector3(cu, hh * 0.7, -cv), Vector3(r, r * 0.8, r), c2)
	var m := _flat(g.build(bv))
	if OS.get_cmdline_user_args().has("--dbg"):
		print("  bank ", key, " tris ", (m[0] as PackedVector3Array).size() / 3)
	_seg_cache[key] = m
	return m


# ---------- 场中石丛 / 专属摆设 ----------

static func _outcrops(a: Arena, mains: Array) -> void:
	var st: Dictionary = BANK.get(a.zone, BANK["forest"])
	var n := int(round(1.3 * sqrt(a._ka())))
	for i in range(n):
		var p := a._free_spot(7.0, 5.0, 4.0)
		if p == Vector3.INF:
			continue
		# 土丘（有碰撞，绕着打）+ 丘上一块大石 + 脚下几块碎石
		var v := a.rng.randi() % 3
		var md: Array = _mound(a.zone, st, v)
		var yaw := a.rng.randi_range(0, 3) * PI * 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = md[0]
		mi.material_override = a.env_mat
		a.add_child(mi)
		mi.position = p
		mi.rotation.y = yaw
		var ext: Vector2 = md[1]
		if absf(sin(yaw)) > 0.7:
			ext = Vector2(ext.y, ext.x)
		a._box_collider(p + Vector3(0, 1, 0), Vector3(ext.x * 1.5, 2.0, ext.y * 1.5))
		var top := float(md[2])
		a.kit(mains[a.rng.randi() % mains.size()], p + Vector3(a.rng.randf_range(-0.4, 0.4), top * 0.55, a.rng.randf_range(-0.3, 0.3)),
			a.rng.randf() * TAU, a.rng.randf_range(0.45, 0.65), false)
		for k in range(2 + a.rng.randi() % 2):
			var ang := a.rng.randf() * TAU
			var off := Vector3(cos(ang) * (ext.x + 0.3), 0, sin(ang) * (ext.y + 0.3))
			a.kit(["rock_b", "rock_d", "stones"][a.rng.randi() % 3], p + off, a.rng.randf() * TAU, a.rng.randf_range(0.5, 0.8), false)


## 一个土丘（椭圆，中间高四周低，顶上长草、坡上露土，嵌一两块石头）：返回 [网格, 半径 xz（米）, 顶高（米）]
static func _mound(zid: String, st: Dictionary, variant: int) -> Array:
	var key := "mound|%s|%d|%d|%d" % [zid, variant, int(VoxelGrid.quant), int(Arena.lod == 0)]
	if _seg_cache.has(key):
		return _seg_cache[key]
	var bv := 0.2 if Arena.lod == 0 else 0.1
	var g := VoxelGrid.new(variant * 977 + zid.hash() % 1000)
	var rng := g.rng
	var rx := rng.randf_range(1.5, 2.1)
	var rz := rng.randf_range(1.1, 1.5)
	var hm := rng.randf_range(0.7, 1.1)
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = 0.6
	var lum := 1.15 if float(st.get("lum", 1.5)) > 1.0 else 1.0
	var top: Color = st["top"] * lum
	var top2: Color = st["top2"] * lum
	var side: Color = st["side"] * lum
	var side2: Color = st["side2"] * lum
	var nx := int(ceil(rx * 1.25 / bv))
	var nz := int(ceil(rz * 1.25 / bv))
	var hmap := {}
	for ix in range(-nx, nx + 1):
		for iz in range(-nz, nz + 1):
			var x := ix * bv
			var z := iz * bv
			var d := Vector2(x / rx, z / rz).length() + n.get_noise_2d(x * 2.0, z * 2.0) * 0.25
			if d >= 1.0:
				continue
			var h := hm * pow(1.0 - d * d, 0.7) + n.get_noise_2d(x * 5.0 + 30.0, z * 5.0) * 0.08
			var hc := maxi(1, int(round(h / bv)))
			hmap[Vector2i(ix, iz)] = hc
	for c: Vector2i in hmap:
		var hc: int = hmap[c]
		var lo := hc
		for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			lo = mini(lo, int(hmap.get(c + d2, 0)))
		var steep := hc - lo >= 2
		for y in range(0, hc):
			var col: Color
			if y == hc - 1 and not steep:
				col = top if n.get_noise_2d(c.x * 3.0, c.y * 3.0) < 0.1 else top2
			elif y == hc - 1:
				col = top2 * 0.85
			else:
				col = side if (y / 2) % 2 == 0 else side2
			g.cells[Vector3i(c.x, y, c.y)] = col
	var rock: Color = st["rock"] * lum
	for i in range(1 + rng.randi() % 2):
		var ang := rng.randf() * TAU
		var cx := cos(ang) * rx * 0.6 / bv
		var cz := sin(ang) * rz * 0.6 / bv
		var r := rng.randf_range(0.25, 0.4) / bv
		g.ellipsoid(Vector3(cx, hm * 0.35 / bv, cz), Vector3(r, r * 0.8, r), rock * (0.9 + 0.15 * i))
	var out := [g.build(bv, Vector3(0.0, 0.0, 0.0)), Vector2(rx, rz), hm]
	_seg_cache[key] = out
	return out


static func _props(a: Arena, list: Array) -> void:
	var total := 0
	for e: Array in list:
		total += int(e[1])
	var n := int(round(5.0 * sqrt(a._ka())))
	for i in range(n):
		var p := a._free_spot(3.5, 3.0, 2.5)
		if p == Vector3.INF:
			continue
		var r := a.rng.randi() % total
		for e: Array in list:
			r -= int(e[1])
			if r < 0:
				var yaw := a.rng.randi_range(0, 3) * PI * 0.5 + a.rng.randf_range(-0.25, 0.25)
				if String(e[0]) in FACING:
					yaw = a.rng.randf_range(-0.2, 0.2)   # 旗、兵器架、箭靶这类扁的件正面朝镜头，侧过来只是一条线
					if String(e[0]) in ["fence_wood", "fence_stone", "flag"]:
						yaw += PI * 0.5                   # 这几件模型是沿 z 摆的
				a.kit(String(e[0]), p, yaw, float(e[3]) * a.rng.randf_range(0.9, 1.1), bool(e[2]))
				break


# ---------- 地面碎件 ----------

static func _clutter(a: Arena, rec: Dictionary, parts: Array) -> void:
	var hx := a.size.x * 0.5
	var hz := a.size.y * 0.5
	var kinds: Array = rec["k"]
	var total := 0
	for e: Array in kinds:
		total += int(e[1])
	var n := int(float(rec["d"]) * a.size.x * a.size.y / 100.0)
	if Arena.lod == 0:
		n = n / 2
	var anchors: Array = a._solid.filter(func(r: Rect2) -> bool: return r.size.x < 6.0 and r.size.y < 6.0)
	for i in range(n):
		var p: Vector3
		if i % 2 == 0 and not anchors.is_empty():
			# 一半撒在障碍物边上（石头脚下长草、箱子边上散稻草）
			var r: Rect2 = anchors[a.rng.randi() % anchors.size()]
			var ang := a.rng.randf() * TAU
			var rad := maxf(r.size.x, r.size.y) * 0.5 + a.rng.randf_range(-0.2, 0.9)
			p = Vector3(r.get_center().x + cos(ang) * rad, 0, r.get_center().y + sin(ang) * rad)
		elif i % 4 == 1:
			# 靠墙根多一点
			var edge := a.rng.randi() % 3
			if edge == 0:
				p = Vector3(a.rng.randf_range(-hx + 0.8, hx - 0.8), 0, -hz + a.rng.randf_range(0.6, 2.5))
			else:
				p = Vector3((1.0 if edge == 1 else -1.0) * (hx - a.rng.randf_range(0.6, 2.5)), 0, a.rng.randf_range(-hz + 0.8, hz - 0.8))
		else:
			p = Vector3(a.rng.randf_range(-hx + 0.8, hx - 0.8), 0, a.rng.randf_range(-hz + 0.8, hz - 0.8))
		if absf(p.x) > hx - 0.5 or absf(p.z) > hz - 0.5:
			continue
		if p.distance_to(a.entry_pos) < 2.0 or p.distance_to(a.exit_pos) < 2.5:
			continue
		var blocked := false
		for dr: Dictionary in a.doors:
			if a._door_clear_rect(dr).has_point(Vector2(p.x, p.z)):
				blocked = true
				break
		if blocked:
			continue
		var r2 := a.rng.randi() % total
		for e: Array in kinds:
			r2 -= int(e[1])
			if r2 < 0:
				var m := _patch(a.zone, e, a.rng.randi() % 3)
				if not m.is_empty():
					parts.append([m, Transform3D(Basis(Vector3.UP, a.rng.randi_range(0, 3) * PI * 0.5), p)])
				break


static func _patch(zid: String, e: Array, variant: int) -> Array:
	var kind := String(e[0])
	var key := "%s|%s|%d|%d" % [zid, kind, variant, int(VoxelGrid.quant)]
	if _patch_cache.has(key):
		return _patch_cache[key]
	var g := VoxelGrid.new((zid + kind).hash() % 10007 + variant * 31)
	var c0: Color = e[2]
	var c1: Color = e[3] if e.size() > 3 else c0 * 0.8
	match kind:
		"grass":
			_grass(g, c0, c1, 3 + g.rng.randi() % 2, 4, 9)
		"weeds":
			_grass(g, c0, c1, 2 + g.rng.randi() % 2, 2, 5)
		"pebbles":
			_pebbles(g, c0)
		"leaves":
			_leaves(g, c0, c1)
		"roots":
			_roots(g, c0)
		"moss":
			_blob(g, c0, c1, 0)
		"ash":
			_blob(g, c0, c1, 1)
		"bones":
			_bones(g, c0)
		"straw":
			_straw(g, c0, c1)
		"shards":
			_shards(g, c0)
		"coins":
			_coins(g, c0)
	var m: Array = []
	if g.size() > 0:
		m = _flat(g.build(CV, Vector3.ZERO))
		if OS.get_cmdline_user_args().has("--dbg"):
			print("  patch ", key, " tris ", (m[0] as PackedVector3Array).size() / 3)
	_patch_cache[key] = m
	return m


static func _grass(g: VoxelGrid, c0: Color, c1: Color, tufts: int, hmin: int, hmax: int) -> void:
	var rng := g.rng
	for t in range(tufts):
		var cx := rng.randi_range(-9, 9)
		var cz := rng.randi_range(-9, 9)
		var lean := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		for b in range(rng.randi_range(4, 7)):
			var bx := cx + rng.randi_range(-3, 3)
			var bz := cz + rng.randi_range(-3, 3)
			var h := rng.randi_range(hmin, hmax)
			var bl := lean.rotated(rng.randf_range(-0.8, 0.8)) * rng.randf_range(0.0, 2.2)
			for y in range(h):
				var k := float(y) / float(h)
				var ox := int(round(bl.x * k * k))
				var oz := int(round(bl.y * k * k))
				g.cells[Vector3i(bx + ox, y, bz + oz)] = c0 if k < 0.5 else c1


static func _pebbles(g: VoxelGrid, c: Color) -> void:
	var rng := g.rng
	for i in range(rng.randi_range(3, 6)):
		var p := Vector3i(rng.randi_range(-9, 9), 0, rng.randi_range(-9, 9))
		var sx := rng.randi_range(1, 3)
		var sz := rng.randi_range(1, 3)
		var sy := rng.randi_range(0, 1)
		var k: float = [0.8, 1.0, 1.15][rng.randi() % 3]
		g.box(p, p + Vector3i(sx, sy, sz), c * k)
		if sx >= 2 and sz >= 2:
			g.cells.erase(p + Vector3i(sx, sy, sz))   # 削个角，别方方正正
			g.cells.erase(p + Vector3i(0, sy, 0))


static func _leaves(g: VoxelGrid, c0: Color, c1: Color) -> void:
	var rng := g.rng
	for i in range(rng.randi_range(18, 34)):
		var r := rng.randf() * 10.0
		var ang := rng.randf() * TAU
		var p := Vector3i(int(cos(ang) * r), 0, int(sin(ang) * r))
		var c := c0 if rng.randf() < 0.55 else c1
		g.cells[p] = c
		if rng.randf() < 0.4:
			g.cells[p + Vector3i(1, 0, 0) if rng.randf() < 0.5 else p + Vector3i(0, 0, 1)] = c


static func _roots(g: VoxelGrid, c: Color) -> void:
	var rng := g.rng
	for k in range(rng.randi_range(1, 2)):
		var p := Vector2(rng.randf_range(-10, -4), rng.randf_range(-8, 8))
		var dir := Vector2(1, rng.randf_range(-0.6, 0.6)).normalized()
		for s in range(rng.randi_range(14, 22)):
			var y := 1 if (s % 7 == 3 or s % 7 == 4) else 0
			var q := Vector3i(int(p.x), y, int(p.y))
			g.cells[q] = c
			g.cells[q + Vector3i(0, 0, 1)] = c * 0.85
			if y == 1:
				g.cells[Vector3i(q.x, 0, q.z)] = c * 0.8
			p += dir
			dir = dir.rotated(rng.randf_range(-0.35, 0.35))


static func _blob(g: VoxelGrid, c0: Color, c1: Color, heap: int) -> void:
	var rng := g.rng
	var r := rng.randf_range(5.0, 9.0)
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = 0.25
	for x in range(-10, 11):
		for z in range(-10, 11):
			var d := Vector2(x, z).length() / r
			if d + n.get_noise_2d(x, z) * 0.5 > 1.0:
				continue
			g.cells[Vector3i(x, 0, z)] = c0 if n.get_noise_2d(x * 2.0 + 50, z * 2.0) < 0.1 else c1
			if heap > 0 and d < 0.45:
				g.cells[Vector3i(x, 1, z)] = c0 * 1.1


static func _bones(g: VoxelGrid, c: Color) -> void:
	var rng := g.rng
	for i in range(rng.randi_range(2, 4)):
		var p := Vector3i(rng.randi_range(-8, 6), 0, rng.randi_range(-8, 8))
		var along_x := rng.randf() < 0.5
		var l := rng.randi_range(4, 7)
		var d := Vector3i(1, 0, 0) if along_x else Vector3i(0, 0, 1)
		var s := Vector3i(0, 0, 1) if along_x else Vector3i(1, 0, 0)
		for k in range(l):
			g.cells[p + d * k] = c * (0.9 + 0.1 * (k % 2))
		for end: Vector3i in [p, p + d * (l - 1)]:
			g.cells[end + s] = c
			g.cells[end - s] = c
	if rng.randf() < 0.5:
		# 半个颅骨
		var sp := Vector3i(rng.randi_range(-6, 6), 0, rng.randi_range(-6, 6))
		g.box(sp, sp + Vector3i(2, 2, 2), c)
		g.cells[sp + Vector3i(0, 1, 2)] = Color(0.08, 0.07, 0.06)
		g.cells[sp + Vector3i(2, 1, 2)] = Color(0.08, 0.07, 0.06)


static func _straw(g: VoxelGrid, c0: Color, c1: Color) -> void:
	var rng := g.rng
	for i in range(rng.randi_range(10, 18)):
		var p := Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var ang := rng.randf() * TAU
		var d := Vector2(cos(ang), sin(ang))
		var y := 1 if rng.randf() < 0.3 else 0
		var c := c0 if rng.randf() < 0.6 else c1
		for k in range(rng.randi_range(4, 9)):
			var q := p + d * k
			g.cells[Vector3i(int(q.x), y, int(q.y))] = c
			if y == 1:
				g.cells[Vector3i(int(q.x), 0, int(q.y))] = c1


static func _shards(g: VoxelGrid, c: Color) -> void:
	var rng := g.rng
	for i in range(rng.randi_range(2, 4)):
		var p := Vector3i(rng.randi_range(-9, 6), 0, rng.randi_range(-9, 6))
		var w := rng.randi_range(3, 5)
		var d := rng.randi_range(2, 4)
		var k: float = [0.85, 1.0, 1.12][rng.randi() % 3]
		g.box(p, p + Vector3i(w - 1, 0, d - 1), c * k)
		# 翘起来的一角
		g.box(p + Vector3i(w, 1, 0), p + Vector3i(w + 1, 1, d - 2), c * k * 1.08)
		g.cells.erase(p + Vector3i(0, 0, d - 1))


static func _coins(g: VoxelGrid, c: Color) -> void:
	var rng := g.rng
	for i in range(rng.randi_range(6, 12)):
		var p := Vector3i(rng.randi_range(-9, 8), 0, rng.randi_range(-9, 8))
		var hgt := 1 if rng.randf() < 0.7 else rng.randi_range(2, 3)
		for y in range(hgt):
			g.box(p + Vector3i(0, y, 0), p + Vector3i(1, y, 1), c * (1.0 if y % 2 == 0 else 0.85))


# ---------- 合并 ----------

## 网格拆成不带索引的三角形顶点（位置、法线、颜色），合并时整段 append，比 SurfaceTool 逐件拼快很多
static func _flat(m: ArrayMesh) -> Array:
	if m == null or m.get_surface_count() == 0:
		return []
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		return [v, nm, c]
	var v2 := PackedVector3Array()
	var n2 := PackedVector3Array()
	var c2 := PackedColorArray()
	v2.resize(idx.size())
	n2.resize(idx.size())
	c2.resize(idx.size())
	for i in range(idx.size()):
		var k := idx[i]
		v2[i] = v[k]
		n2[i] = nm[k]
		c2[i] = c[k]
	return [v2, n2, c2]


static func _merge(a: Arena, parts: Array) -> void:
	# 先按 10 米一格分好（只记引用），每格再一次性拼起来（Packed 数组是写时复制，边拼边存回去会反复整段复制）
	var buckets := {}
	for pt: Array in parts:
		var xf: Transform3D = pt[1]
		var key := Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(pt)
	for key: Vector2i in buckets:
		var vv := PackedVector3Array()
		var nn := PackedVector3Array()
		var cc := PackedColorArray()
		for pt: Array in buckets[key]:
			var xf: Transform3D = pt[1]
			var src: Array = pt[0]
			vv.append_array(xf * (src[0] as PackedVector3Array))
			nn.append_array(Transform3D(xf.basis, Vector3.ZERO) * (src[1] as PackedVector3Array))
			cc.append_array(src[2])
		if OS.get_cmdline_user_args().has("--dbg"):
			print("  terrain chunk ", key, " tris ", vv.size() / 3)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vv
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_COLOR] = cc
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = a.env_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("floor", true)   # 别被门口清理和静态合批再动
		a.add_child(mi)
