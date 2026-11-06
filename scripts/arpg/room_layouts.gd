class_name RoomLayouts
extends RefCounted
## 房间布局模板：战斗房 / 精英房在摆区域自己的东西之前，先按一个手工模板把场子“搭”起来
## （中央台、回廊、双柱、窄道、三岛……），每个区域用自己的件来搭，所以 12 个模板 × 每区换件 = 每区 12 种场子。
## 模板之外的摆设（灯、碎件、边坡）照旧随机铺，敌人刷怪点有一半落在模板指定的地方（刷怪区 spawn）。
##
## 坐标：模板里的 (u, v) 都是 -1~1，映射到“场内”这块地：左右离墙 5 米，后面离墙 5 米（第三幕 7 米，后排有房子），
##   前面离入口 7 米。u = -1 最左，v = -1 最远（画面上方，出口那边），v = 1 靠近入口。
## 一个模板 = id、名字、件（feat）、刷怪区（spawn：[u, v, 半径(按场内深度的比例)]）。件有四种：
##   ["post", u, v, 种类]                    一件
##   ["line", u0, v0, u1, v1, 种类]          沿横线或竖线排一排（只能横平竖直，碰撞盒才对得上）
##   ["ring", u, v, 半径, 件数, 种类, 缺口数]  围一圈，缺口均匀留在圈上（0 = 不留）
##   ["cluster", u, v, 件数, 种类]           一小堆（主件 + 旁边几件）
## 种类：post 高柱类、wall 能排成墙的长件、block 中等障碍、low 矮掩体。每个区域用哪几件见 PIECES。
## 想加一个模板：在 LIST 里加一行；想给新区域配件：在 PIECES 里加一行（没配的区域用 forest 的件）。
## 测试：--layout=<id> 指定模板（战斗房、精英房），--nolayout 关掉（回到老的随机摆法）。

const LIST := [
	{"id": "dais", "name": "中央台",
		"feat": [["ring", 0.0, 0.0, 0.55, 10, "post", 2], ["post", 0.0, 0.0, "block"]],
		"spawn": [[0.0, 0.0, 0.4]]},
	{"id": "cloister", "name": "回廊",
		"feat": [["line", -0.55, -0.55, -0.15, -0.55, "wall"], ["line", 0.15, -0.55, 0.55, -0.55, "wall"],
			["line", -0.55, 0.5, -0.15, 0.5, "wall"], ["line", 0.15, 0.5, 0.55, 0.5, "wall"],
			["line", -0.6, -0.4, -0.6, -0.1, "wall"], ["line", 0.6, 0.05, 0.6, 0.35, "wall"],
			["post", -0.6, 0.35, "post"], ["post", 0.6, -0.4, "post"]],
		"spawn": [[0.0, 0.0, 0.3], [-0.85, -0.8, 0.2], [0.85, 0.75, 0.2]]},
	{"id": "twin", "name": "双柱",
		"feat": [["cluster", -0.45, -0.1, 4, "block"], ["cluster", 0.45, 0.1, 4, "block"],
			["post", -0.45, -0.1, "post"], ["post", 0.45, 0.1, "post"]],
		"spawn": [[0.0, -0.6, 0.3], [-0.8, 0.5, 0.2], [0.8, -0.5, 0.2]]},
	{"id": "gauntlet", "name": "窄道",
		"feat": [["line", -0.22, -0.75, -0.22, -0.1, "wall"], ["line", -0.22, 0.25, -0.22, 0.6, "wall"],
			["line", 0.22, -0.75, 0.22, -0.35, "wall"], ["line", 0.22, 0.0, 0.22, 0.6, "wall"]],
		"spawn": [[0.0, -0.8, 0.25], [-0.65, 0.0, 0.3], [0.65, 0.0, 0.3]]},
	{"id": "islands", "name": "三岛",
		"feat": [["cluster", 0.0, -0.45, 5, "block"], ["cluster", -0.6, 0.4, 5, "block"], ["cluster", 0.6, 0.4, 5, "block"],
			["post", 0.0, -0.45, "post"]],
		"spawn": [[0.0, 0.2, 0.35], [-0.7, -0.6, 0.2], [0.7, -0.6, 0.2]]},
	{"id": "grove", "name": "柱林",
		"feat": [["post", -0.7, -0.55, "post"], ["post", -0.3, -0.55, "post"], ["post", 0.3, -0.55, "post"], ["post", 0.7, -0.55, "post"],
			["post", -0.5, 0.0, "post"], ["post", 0.5, 0.0, "post"],
			["post", -0.7, 0.55, "post"], ["post", -0.3, 0.55, "post"], ["post", 0.3, 0.55, "post"], ["post", 0.7, 0.55, "post"],
			["post", -0.1, 0.0, "low"], ["post", 0.1, 0.0, "low"]],
		"spawn": [[0.0, -0.3, 0.5]]},
	{"id": "zigzag", "name": "断墙",
		"feat": [["line", -0.85, -0.5, -0.15, -0.5, "wall"], ["line", 0.15, 0.0, 0.85, 0.0, "wall"],
			["line", -0.65, 0.5, 0.05, 0.5, "wall"], ["post", -0.1, -0.5, "post"], ["post", 0.1, 0.0, "post"]],
		"spawn": [[0.5, -0.7, 0.25], [-0.5, -0.2, 0.25], [0.5, 0.4, 0.2]]},
	{"id": "corners", "name": "四角",
		"feat": [["line", -0.75, -0.6, -0.4, -0.6, "wall"], ["line", -0.75, -0.6, -0.75, -0.25, "wall"],
			["line", 0.4, -0.6, 0.75, -0.6, "wall"], ["line", 0.75, -0.6, 0.75, -0.25, "wall"],
			["line", -0.75, 0.6, -0.4, 0.6, "wall"], ["line", -0.75, 0.25, -0.75, 0.6, "wall"],
			["line", 0.4, 0.6, 0.75, 0.6, "wall"], ["line", 0.75, 0.25, 0.75, 0.6, "wall"],
			["post", 0.0, 0.0, "post"]],
		"spawn": [[-0.6, -0.45, 0.15], [0.6, -0.45, 0.15], [-0.6, 0.45, 0.15], [0.6, 0.45, 0.15]]},
	{"id": "cover_ring", "name": "环阵",
		"feat": [["ring", 0.0, 0.0, 0.8, 14, "low", 4], ["cluster", 0.0, 0.0, 3, "block"]],
		"spawn": [[0.0, -0.95, 0.2], [-0.95, 0.0, 0.2], [0.95, 0.0, 0.2]]},
	{"id": "wings", "name": "两厢",
		"feat": [["line", -0.45, -0.8, -0.45, -0.4, "wall"], ["line", -0.45, -0.05, -0.45, 0.35, "wall"],
			["line", 0.45, -0.6, 0.45, -0.2, "wall"], ["line", 0.45, 0.15, 0.45, 0.6, "wall"],
			["post", -0.8, 0.0, "block"], ["post", 0.8, -0.1, "block"]],
		"spawn": [[-0.75, -0.4, 0.2], [0.75, 0.3, 0.2], [0.0, -0.6, 0.25]]},
	{"id": "stagger", "name": "斜阵",
		"feat": [["post", -0.75, -0.65, "post"], ["post", -0.45, -0.3, "block"], ["post", -0.15, 0.05, "post"],
			["post", 0.15, -0.6, "block"], ["post", 0.45, -0.25, "post"], ["post", 0.75, 0.1, "block"],
			["post", -0.55, 0.5, "block"], ["post", 0.2, 0.55, "low"], ["post", 0.6, 0.6, "post"]],
		"spawn": [[0.6, -0.65, 0.25], [-0.6, 0.15, 0.25]]},
	{"id": "plaza", "name": "擂台",
		"feat": [["post", -0.3, -0.35, "post"], ["post", 0.3, -0.35, "post"], ["post", -0.3, 0.35, "post"], ["post", 0.3, 0.35, "post"],
			["line", -0.9, -0.7, -0.9, 0.6, "low"], ["line", 0.9, -0.7, 0.9, 0.6, "low"]],
		"spawn": [[0.0, 0.0, 0.3], [0.0, -0.8, 0.2]]},
]

## 每个区域拿什么件来搭：[件 id, 缩放]
const PIECES := {
	"forest": {"post": [["pillar", 1.0], ["column", 1.8]], "wall": [["wall_broken", 1.0], ["wall", 1.0], ["rubble", 1.0]],
		"block": [["rubble", 1.0], ["crates", 1.0], ["rock_c", 1.0]], "low": [["rubble_half", 1.0], ["rock_d", 1.2]]},
	"grave": {"post": [["grave_a", 1.3], ["fence_pillar", 1.5]], "wall": [["fence_stone", 1.0], ["coffin", 1.0]],
		"block": [["coffin", 1.0], ["grave_broken", 1.2], ["rock_c", 1.0]], "low": [["gravestone", 1.2], ["grave_broken", 1.0]]},
	"temple": {"post": [["pillar", 1.0], ["column", 1.6]], "wall": [["wall_arch", 1.0], ["wall", 1.0], ["barrier_col", 1.0]],
		"block": [["shrine", 1.1], ["rubble", 1.0], ["table_m", 1.0]], "low": [["rubble_half", 1.0], ["shrine", 0.8]]},
	"sakura": {"post": [["pillar", 1.0]], "wall": [["fence", 1.0], ["barrier_col", 1.0]],
		"block": [["rock_c", 1.0], ["rock_e", 1.0]], "low": [["rock_d", 1.2]]},
	"well": {"post": [["column", 1.6], ["pillar", 1.0]], "wall": [["wall_broken", 1.0], ["barrier_col", 1.0]],
		"block": [["rock_c", 1.0], ["rubble", 1.0]], "low": [["rubble_half", 1.0], ["rock_d", 1.2]]},
	"vault": {"post": [["column", 1.5], ["pillar", 1.0]], "wall": [["wall", 1.0], ["crate_long", 1.0], ["keg", 1.0]],
		"block": [["chest_gold", 1.0], ["crates", 1.0], ["keg", 1.0], ["trunk", 1.2]], "low": [["barrel_deco", 1.0], ["coffin", 1.0]]},
	"camp": {"post": [["weaponrack", 1.1], ["banner", 1.2]], "wall": [["barrier", 1.0], ["crate_long", 1.0], ["lumber", 1.0]],
		"block": [["crates", 1.0], ["barrel", 1.0], ["lumber", 1.0]], "low": [["sword_shield", 1.2], ["target", 1.0], ["sack", 1.0]]},
	"liuxi": {"post": [["well", 1.0], ["crates", 1.1]], "wall": [["fence", 1.0], ["fence_wood", 1.0]],
		"block": [["crates", 1.0], ["barrel", 1.0], ["lumber", 1.0]], "low": [["sack", 1.0], ["pumpkin", 1.0]]},
	"post": {"post": [["post_lantern", 1.0], ["crates", 1.1]], "wall": [["fence_stone", 1.0], ["crate_long", 1.0], ["fence", 1.0]],
		"block": [["crates", 1.0], ["barrel", 1.0], ["lumber", 1.0]], "low": [["sack", 1.0], ["barrel", 0.9]]},
	"palace": {"post": [["column", 1.5], ["banner", 1.3]], "wall": [["barrier_col", 1.0]],
		"block": [["table_m", 1.0], ["chest_gold", 1.0]], "low": [["candles", 1.3], ["chest_gold", 0.8]]},
}

## 比这高的件当前景遮挡物（挡住主角时变透明）
const TALL := 2.2


static func get_layout(id: String) -> Dictionary:
	for l: Dictionary in LIST:
		if l["id"] == id:
			return l
	return {}


static func ids() -> Array:
	return LIST.map(func(l: Dictionary) -> String: return String(l["id"]))


## 挑一个模板：最近用过的几个不挑；每 13 间里大约有一间不用模板（老的随机摆法），返回 ""
static func pick(rng: RandomNumberGenerator, recent: Array) -> String:
	if rng.randf() < 1.0 / 13.0:
		return ""
	var pool := ids().filter(func(i: String) -> bool: return not recent.has(i))
	if pool.is_empty():
		pool = ids()
	return pool[rng.randi_range(0, pool.size() - 1)]


## 场内这块地（模板坐标映射到这里）
static func box(a: Arena) -> Rect2:
	var hx := a.size.x * 0.5
	var hz := a.size.y * 0.5
	var back := a._layout_back()
	return Rect2(-hx + 5.0, -hz + back, a.size.x - 10.0, a.size.y - back - 7.0)


static func to_world(a: Arena, u: float, v: float) -> Vector3:
	var b := box(a)
	var c := b.get_center()
	return Vector3(c.x + u * b.size.x * 0.5, 0, c.y + v * b.size.y * 0.5)


static func apply(a: Arena, id: String) -> void:
	var lay := get_layout(id)
	if lay.is_empty():
		return
	var pcs: Dictionary = PIECES.get(a.zone, PIECES["forest"])
	var n0 := a._solid.size()   # 只和模板之前的碰撞（墙、门口空地）比，同一个模板里的件可以挨着
	var b := box(a)
	for f: Array in lay["feat"]:
		match String(f[0]):
			"post":
				_put(a, pcs, String(f[3]), to_world(a, f[1], f[2]), n0, -1.0)
			"cluster":
				var c := to_world(a, f[1], f[2])
				var n := int(f[3])
				_put(a, pcs, String(f[4]), c, n0, -1.0)
				for i in range(n - 1):
					var ang := TAU * float(i) / float(maxi(n - 1, 1)) + a.rng.randf_range(-0.3, 0.3)
					_put(a, pcs, "low" if i % 2 == 1 else String(f[4]), c + Vector3(cos(ang), 0, sin(ang)) * a.rng.randf_range(2.0, 2.6), n0, -1.0)
			"line":
				_line(a, pcs, to_world(a, f[1], f[2]), to_world(a, f[3], f[4]), String(f[5]), n0)
			"ring":
				var c := to_world(a, f[1], f[2])
				var r := float(f[3]) * b.size.y * 0.5
				var n := int(f[4])
				var gaps := int(f[6])
				var off := a.rng.randf() * TAU / float(n)
				for i in range(n):
					if gaps > 0 and i % int(round(float(n) / float(gaps))) == 0:
						continue
					var ang := off + TAU * float(i) / float(n)
					_put(a, pcs, String(f[5]), c + Vector3(cos(ang) * r * 1.3, 0, sin(ang) * r), n0, -1.0)
	a.layout_spawns.clear()
	for s: Array in lay.get("spawn", []):
		a.layout_spawns.append([to_world(a, s[0], s[1]), float(s[2]) * b.size.y * 0.5])


## 摆一件：yaw < 0 时随机朝向（只转 90° 的倍数再抖一点，碰撞盒才对）
static func _put(a: Arena, pcs: Dictionary, kind: String, p: Vector3, n0: int, yaw: float, choice: Array = []) -> float:
	var list: Array = pcs.get(kind, pcs["block"])
	var e: Array = choice if not choice.is_empty() else list[a.rng.randi() % list.size()]
	var piece := VoxelKit.get_piece(String(e[0]))
	if piece.is_empty():
		return 0.0
	var sc := float(e[1])
	var sz: Vector3 = piece["size"] * Arena.PX * sc
	if yaw < 0.0:
		yaw = PI * 0.5 * float(a.rng.randi() % 4) + a.rng.randf_range(-0.12, 0.12)
	var ext := Vector2(sz.x, sz.z)
	if absf(sin(yaw)) > 0.7:
		ext = Vector2(sz.z, sz.x)
	var r := Rect2(p.x - ext.x * 0.5, p.z - ext.y * 0.5, ext.x, ext.y)
	if not a._layout_ok(r):
		return 0.0
	for i in range(n0):
		var s: Rect2 = a._solid[i]
		if s.grow(-0.2).intersects(r):
			return 0.0
	a.kit(String(e[0]), p, yaw, sc, true, sz.y > TALL)
	a._placed.append(p)
	return maxf(sz.x, sz.z)


## 沿横线或竖线排一排同一种件
static func _line(a: Arena, pcs: Dictionary, p0: Vector3, p1: Vector3, kind: String, n0: int) -> void:
	var list: Array = pcs.get(kind, pcs["block"])
	var e: Array = list[a.rng.randi() % list.size()]
	var piece := VoxelKit.get_piece(String(e[0]))
	if piece.is_empty():
		return
	var sz: Vector3 = piece["size"] * Arena.PX * float(e[1])
	var horiz := absf(p1.x - p0.x) >= absf(p1.z - p0.z)
	var long_x := sz.x >= sz.z
	var yaw := 0.0 if horiz == long_x else PI * 0.5
	var step := maxf(maxf(sz.x, sz.z), 0.8) * 0.98
	var length := p0.distance_to(p1)
	var n := maxi(1, int(round(length / step)) + 1)
	var dir := (p1 - p0).normalized() if length > 0.01 else Vector3.RIGHT
	var start := (p0 + p1) * 0.5 - dir * step * float(n - 1) * 0.5
	for i in range(n):
		var flip := PI if a.rng.randf() < 0.5 else 0.0
		_put(a, pcs, kind, start + dir * step * float(i), n0, yaw + flip, e)
