class_name RoomProps
extends Node2D
## 房间里的摆设和地形结构。每条是 [种类, x] 或 [种类, x, 离地高度]（放在平台上的东西写高度）。
##
## 能站的结构（单向平台，从下面能跳穿，按 下+跳 往下落）：
##   cart 板车 · crates 木箱堆 · hay 草垛 · shed 破棚（旁边有木箱当台阶） · wall 断墙
##   house2 两层木楼（左边楼梯走上二楼走廊，再跳上屋顶） · scaffold 两层脚手架 · tower 望楼
## 纯摆设：well 井 · scarecrow 稻草人 · fire 篝火 · sign 路牌 · grave 坟头 · lantern 灯笼柱
##   laundry 晾衣绳 · barrel_d 木桶 · bucket 水桶 · woodpile 柴堆 · banner 破旗 · rubble 碎石
##   bamboo 竹丛 · tent 帐篷 · rack 兵器架 · stone_lantern 石灯笼
## 能砍碎的（jar urn barrel box）和能互动的（chest note）由主场景另外生成，见 Breakable、Interactable。

## 每种结构的平台：[离地高度, 中心相对 x, 宽度]
const PLATFORMS := {
	"cart": [[26.0, 0.0, 58.0]],
	"crates": [[34.0, 0.0, 38.0]],
	"hay": [[28.0, 0.0, 42.0]],
	"shed": [[74.0, 0.0, 104.0], [34.0, -70.0, 30.0]],
	"wall": [[46.0, 0.0, 96.0]],
	"house2": [[70.0, 0.0, 164.0], [128.0, 10.0, 120.0]],
	"scaffold": [[56.0, 0.0, 66.0], [112.0, 0.0, 66.0]],
	"tower": [[52.0, -30.0, 30.0], [100.0, 0.0, 56.0]],
}
## 楼梯（斜坡）：[起点相对 x, 终点相对 x, 终点高度]，从起点的地面走上去
const RAMPS := {
	"house2": [[-172.0, -82.0, 70.0]],
}

var props: Array = []
var floor_y := 300.0
## 天色：决定用哪张摆设图集（tools/sprites/build_village.py 画的），没有图集就用下面的程序画法
var mood := "night"
static var _atlas_data: Dictionary = {}
static var _atlas_tex: Dictionary = {}
var _tex: Texture2D
var time := 0.0
var _glow: Node2D


class Glow extends Node2D:
	var owner_props: RoomProps

	func _draw() -> void:
		owner_props._draw_glow(self)


func _ready() -> void:
	_load_atlas()
	_glow = Glow.new()
	_glow.owner_props = self
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)


func _load_atlas() -> void:
	if _atlas_data.is_empty():
		var f := FileAccess.open("res://assets/scenes/props.json", FileAccess.READ)
		if f == null:
			return
		_atlas_data = JSON.parse_string(f.get_as_text())
	var path := "res://assets/scenes/props_%s.png" % mood
	if not ResourceLoader.exists(path):
		return
	if not _atlas_tex.has(mood):
		_atlas_tex[mood] = load(path)
	_tex = _atlas_tex[mood]


## 画一个摆设的像素图（贴地点对齐 (x, y)）；没有这张图返回 false
func _sprite(kind: String, x: float, y: float) -> bool:
	if _tex == null or not _atlas_data.has(kind):
		return false
	var d: Dictionary = _atlas_data[kind]
	var r: Array = d["rect"]
	var o: Array = d["origin"]
	draw_texture_rect_region(_tex, Rect2(roundf(x) - o[0], roundf(y) - o[1], r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]))
	var flick := 0.8 + 0.2 * sin(time * 11.0 + x)
	for wv: Array in d["windows"]:
		if wv.size() > 4:
			var wr := Rect2(roundf(x) - o[0] + wv[0], roundf(y) - o[1] + wv[1], wv[2], wv[3])
			draw_rect(wr, Color(1.0, 0.62, 0.26, flick))
			draw_rect(wr.grow(-1), Color(1.0, 0.82, 0.5, flick))
	return true


## 房间摆设用哪种天色的图集（和背景的光对上）
static func mood_for(def: Dictionary) -> String:
	var m := String(def.get("mood", ""))
	match String(def.get("theme", "temple")):
		"village":
			return m if m != "" else "dusk"
		"bamboo_temple":
			return {"mist": "fog", "dusk": "dusk", "night": "night"}.get(m, "fog")
	return "night"


static func _base(pr: Array) -> float:
	return float(pr[2]) if pr.size() > 2 else 0.0


## 所有能站的平台（世界坐标，顶边）
static func platform_rects(list: Array, floor_y: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pr: Array in list:
		if PLATFORMS.has(pr[0]):
			var x: float = pr[1]
			for spec: Array in PLATFORMS[pr[0]]:
				var w: float = spec[2]
				out.append(Rect2(x + float(spec[1]) - w / 2.0, floor_y - _base(pr) - float(spec[0]), w, 6))
	return out


## 所有楼梯：[低端, 高端]（世界坐标）
static func ramps(list: Array, floor_y: float) -> Array:
	var out := []
	for pr: Array in list:
		if RAMPS.has(pr[0]):
			var x: float = pr[1]
			for spec: Array in RAMPS[pr[0]]:
				out.append([Vector2(x + float(spec[0]), floor_y), Vector2(x + float(spec[1]), floor_y - float(spec[2]))])
	return out


func _process(delta: float) -> void:
	time += delta
	queue_redraw()
	_glow.queue_redraw()


func _draw() -> void:
	# 大结构先画，小摆设盖在上面
	for pass_i in range(2):
		for pr: Array in props:
			var big: bool = PLATFORMS.has(pr[0]) and pr[0] != "cart" and pr[0] != "crates" and pr[0] != "hay"
			if big != (pass_i == 0):
				continue
			var x: float = pr[1]
			var y := floor_y - _base(pr)
			if _sprite(String(pr[0]), x, y):
				match String(pr[0]):
					"fire": _fire_flames(x, y)
					"lantern": _lantern_box(x, y)
					"laundry": _laundry_cloth(x, y)
					"house2": _house2_lantern(x, y)
				continue
			match String(pr[0]):
				"well": _well(x, y)
				"cart": _cart(x, y)
				"crates": _crates(x, y)
				"hay": _hay(x, y)
				"shed": _shed(x, y)
				"wall": _wall(x, y)
				"house2": _house2(x, y)
				"scaffold": _scaffold(x, y)
				"tower": _tower(x, y)
				"scarecrow": _scarecrow(x, y)
				"fire": _fire(x, y)
				"sign": _sign(x, y)
				"grave": _grave(x, y)
				"lantern": _lantern(x, y)
				"laundry": _laundry(x, y)
				"barrel_d": _barrel(x, y)
				"bucket": _bucket(x, y)
				"woodpile": _woodpile(x, y)
				"banner": _banner(x, y)
				"rubble": _rubble(x, y)
				"bamboo": _bamboo(x, y)
				"tent": _tent(x, y)
				"rack": _rack(x, y)
				"stone_lantern": _stone_lantern(x, y)


func _draw_glow(c: CanvasItem) -> void:
	for pr: Array in props:
		var x: float = pr[1]
		var y := floor_y - _base(pr)
		var flick := 0.85 + 0.15 * sin(time * 13.0 + x) * sin(time * 7.0)
		match String(pr[0]):
			"fire":
				for i in range(6):
					c.draw_circle(Vector2(x, y - 10), 8.0 + i * 11.0, Color(0.5, 0.2, 0.05, 0.08 * flick))
				c.draw_set_transform(Vector2(x, y + 3), 0.0, Vector2(1.0, 0.18))
				for i in range(4):
					c.draw_circle(Vector2.ZERO, 30.0 + i * 18.0, Color(0.4, 0.15, 0.03, 0.09 * flick))
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"lantern":
				for i in range(4):
					c.draw_circle(Vector2(x + 7, y - 40), 5.0 + i * 8.0, Color(0.5, 0.18, 0.04, 0.1 * flick))
			"stone_lantern":
				for i in range(4):
					c.draw_circle(Vector2(x, y - 34), 6.0 + i * 8.0, Color(0.45, 0.22, 0.05, 0.09 * flick))
			"house2":
				for i in range(3):
					c.draw_circle(Vector2(x + 34, y - 96), 6.0 + i * 8.0, Color(0.5, 0.22, 0.05, 0.08 * flick))
			"tower":
				for i in range(3):
					c.draw_circle(Vector2(x, y - 118), 5.0 + i * 7.0, Color(0.5, 0.2, 0.04, 0.09 * flick))


const WOOD := Color("4a3024")
const WOOD_DARK := Color("2a1a16")
const WOOD_LIT := Color("8a5a3a")
const STONE := Color("4a4048")
const STONE_DARK := Color("2a2430")
const OUTLINE := Color("0c080a")


func _well(x: float, y: float) -> void:
	draw_rect(Rect2(x - 22, y - 22, 44, 22), OUTLINE)
	draw_rect(Rect2(x - 21, y - 21, 42, 21), STONE_DARK)
	for row in range(3):
		for k in range(4):
			var bx := x - 20 + k * 11 + (5 if row % 2 else 0)
			if bx + 9 > x + 21:
				continue
			draw_rect(Rect2(bx, y - 20 + row * 7, 9, 5), STONE)
			draw_rect(Rect2(bx, y - 20 + row * 7, 9, 1), STONE.lightened(0.2))
	draw_rect(Rect2(x - 23, y - 24, 46, 3), Color("5a5058"))
	# 井架和轱辘
	draw_rect(Rect2(x - 19, y - 52, 3, 30), WOOD_DARK)
	draw_rect(Rect2(x + 16, y - 52, 3, 30), WOOD_DARK)
	draw_rect(Rect2(x - 22, y - 55, 44, 3), WOOD)
	draw_rect(Rect2(x - 22, y - 55, 44, 1), WOOD_LIT)
	draw_line(Vector2(x, y - 52), Vector2(x, y - 34), Color("6a5a4a"), 1.0)
	draw_rect(Rect2(x - 3, y - 36, 6, 5), WOOD)


func _cart(x: float, y: float) -> void:
	var top := y - 26.0
	# 车板
	draw_rect(Rect2(x - 30, top - 1, 60, 8), OUTLINE)
	draw_rect(Rect2(x - 29, top, 58, 6), WOOD)
	draw_rect(Rect2(x - 29, top, 58, 1), WOOD_LIT)
	for k in range(5):
		draw_rect(Rect2(x - 29 + k * 12, top + 1, 1, 5), WOOD_DARK)
	# 车把斜着搭在地上
	draw_line(Vector2(x + 28, top + 4), Vector2(x + 52, y), WOOD_DARK, 2.0)
	# 轮子
	var wc := Vector2(x - 10, y - 11)
	draw_circle(wc, 11, OUTLINE)
	draw_circle(wc, 10, WOOD_DARK)
	draw_circle(wc, 7, Color(0, 0, 0, 0.0))
	draw_arc(wc, 8, 0, TAU, 16, WOOD, 2.0)
	for k in range(4):
		var a := k * PI / 4.0
		draw_line(wc - Vector2(cos(a), sin(a)) * 8, wc + Vector2(cos(a), sin(a)) * 8, WOOD, 1.0)
	draw_circle(wc, 2, WOOD_LIT)
	# 车上的麻袋
	draw_circle(Vector2(x + 8, top - 5), 7, Color("6a5a3e"))
	draw_circle(Vector2(x + 18, top - 4), 5, Color("5a4a32"))
	draw_rect(Rect2(x + 4, top - 11, 3, 1), Color("8a7a52"))


func _crate(at: Vector2, s: float) -> void:
	draw_rect(Rect2(at.x - 1, at.y - s - 1, s + 2, s + 2), OUTLINE)
	draw_rect(Rect2(at.x, at.y - s, s, s), WOOD)
	draw_rect(Rect2(at.x, at.y - s, s, 2), WOOD_LIT)
	draw_rect(Rect2(at.x, at.y - s, 2, s), WOOD_LIT.darkened(0.2))
	draw_rect(Rect2(at.x + 2, at.y - s + 2, s - 4, s - 4), WOOD_DARK, false, 1.0)
	draw_line(at + Vector2(2, -2), at + Vector2(s - 2, -s + 2), WOOD_DARK, 2.0)


func _crates(x: float, y: float) -> void:
	_crate(Vector2(x - 19, y), 19)
	_crate(Vector2(x, y), 19)
	_crate(Vector2(x - 12, y - 19), 15)
	# 顶上补一块木板，站的地方
	draw_rect(Rect2(x - 20, y - 35, 40, 3), WOOD_LIT.darkened(0.15))


func _shed(x: float, y: float) -> void:
	var top := y - 74.0
	var hw := 52.0
	# 柱子
	for px in [x - hw + 6, x + hw - 8]:
		draw_rect(Rect2(px, top, 4, 74), WOOD_DARK)
		draw_rect(Rect2(px, top, 1, 74), WOOD)
	draw_line(Vector2(x - hw + 8, top + 16), Vector2(x - hw + 30, top + 2), WOOD_DARK, 2.0)
	# 棚顶：歪掉的木板，上面盖着烂茅草
	draw_rect(Rect2(x - hw - 2, top - 2, hw * 2 + 4, 8), OUTLINE)
	draw_rect(Rect2(x - hw, top, hw * 2, 5), WOOD)
	draw_rect(Rect2(x - hw, top, hw * 2, 1), WOOD_LIT)
	for k in range(int(hw * 2 / 3.0)):
		var px := x - hw + k * 3.0
		draw_line(Vector2(px, top - 1), Vector2(px + 1, top - 4 - (k * 7) % 4), Color("6a4a2a"), 1.0)
		if k % 5 == 0:
			draw_line(Vector2(px, top + 5), Vector2(px + 1, top + 9 + k % 3), Color("4a3420"), 1.0)
	# 旁边当台阶的木箱
	_crate(Vector2(x - hw - 30, y), 17)
	_crate(Vector2(x - hw - 13, y), 17)
	_crate(Vector2(x - hw - 26, y - 17), 16)
	# 棚下堆的草垛
	draw_circle(Vector2(x + 16, y - 9), 12, Color("5a4220"))
	draw_circle(Vector2(x + 30, y - 7), 9, Color("4a3618"))
	draw_line(Vector2(x + 8, y - 16), Vector2(x + 22, y - 18), Color("8a6a3a"), 1.0)


func _scarecrow(x: float, y: float) -> void:
	var sway := sin(time * 1.3 + x) * 0.04
	draw_set_transform(Vector2(x, y), sway, Vector2.ONE)
	draw_rect(Rect2(-1, -56, 3, 56), WOOD_DARK)
	draw_rect(Rect2(-18, -44, 36, 3), WOOD_DARK)
	# 破衣服
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -44), Vector2(12, -44), Vector2(9, -22), Vector2(4, -26),
		Vector2(0, -20), Vector2(-5, -25), Vector2(-10, -21)]), Color("5a3a3a"))
	draw_line(Vector2(-12, -44), Vector2(-4, -30), Color("7a5048"), 1.0)
	# 斗笠和草头
	draw_circle(Vector2(0, -52), 6, Color("8a7a4a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -55), Vector2(14, -55), Vector2(0, -64)]), Color("6a5a32"))
	draw_line(Vector2(-14, -55), Vector2(0, -64), Color("9a8a5a"), 1.0)
	# 袖口漏出来的草
	for s in [-1.0, 1.0]:
		for k in range(3):
			draw_line(Vector2(s * 18, -43), Vector2(s * (21 + k), -40 + k * 2), Color("a8904a"), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _fire(x: float, y: float) -> void:
	# 柴堆
	draw_line(Vector2(x - 10, y), Vector2(x + 8, y - 6), WOOD_DARK, 3.0)
	draw_line(Vector2(x + 10, y), Vector2(x - 8, y - 6), WOOD_DARK, 3.0)
	for k in range(5):
		var a := k * TAU / 5.0
		draw_rect(Rect2(x + cos(a) * 11 - 2, y - 2, 4, 2), STONE)
	_fire_flames(x, y)


func _fire_flames(x: float, y: float) -> void:
	# 火苗：几层颜色叠起来，抖动
	for k in range(3):
		var f := sin(time * (11.0 + k * 3.0) + k) * 1.5
		var h := 14.0 - k * 4.0 + f
		var w := 8.0 - k * 2.0
		var col: Color = [Color("c2401a"), Color("f08a2a"), Color("ffe08a")][k]
		draw_colored_polygon(PackedVector2Array([Vector2(x - w, y - 3), Vector2(x + w, y - 3),
			Vector2(x + f * 0.6, y - 3 - h)]), col)
	# 火星
	for k in range(4):
		var t := fmod(time * 0.9 + k * 0.25, 1.0)
		var p := Vector2(x + sin(t * 9.0 + k) * 5.0, y - 10 - t * 26.0).round()
		draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.7, 0.3, 1.0 - t))


func _sign(x: float, y: float) -> void:
	draw_rect(Rect2(x - 1, y - 44, 3, 44), WOOD_DARK)
	draw_rect(Rect2(x - 20, y - 46, 40, 14), OUTLINE)
	draw_rect(Rect2(x - 19, y - 45, 38, 12), WOOD)
	draw_rect(Rect2(x - 19, y - 45, 38, 1), WOOD_LIT)
	# 路牌上刻的字用几道划痕代替
	for k in range(4):
		draw_rect(Rect2(x - 14 + k * 8, y - 42, 5, 6), WOOD_DARK)
	draw_line(Vector2(x + 19, y - 39), Vector2(x + 25, y - 39), WOOD, 2.0)


func _grave(x: float, y: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y), Vector2(x - 8, y - 7), Vector2(x + 8, y - 7), Vector2(x + 14, y)]), Color("2a2026"))
	draw_rect(Rect2(x - 5, y - 26, 10, 20), OUTLINE)
	draw_rect(Rect2(x - 4, y - 25, 8, 19), Color("5a5058"))
	draw_rect(Rect2(x - 4, y - 25, 2, 19), Color("7a7078"))
	draw_rect(Rect2(x - 1, y - 21, 2, 10), Color("3a3038"))
	# 插着的破刀
	draw_line(Vector2(x + 10, y), Vector2(x + 13, y - 22), Color("8a8a92"), 1.0)
	draw_rect(Rect2(x + 11, y - 26, 4, 2), Color("3a2a22"))


# ---------- 能站的结构 ----------

func _plank(x0: float, x1: float, top: float) -> void:
	# 一条木板走道：上沿亮、下面一条暗边
	draw_rect(Rect2(x0 - 1, top - 1, x1 - x0 + 2, 7), OUTLINE)
	draw_rect(Rect2(x0, top, x1 - x0, 5), WOOD)
	draw_rect(Rect2(x0, top, x1 - x0, 1), WOOD_LIT)
	var k := x0 + 9.0
	while k < x1 - 2.0:
		draw_rect(Rect2(k, top + 1, 1, 4), WOOD_DARK)
		k += 13.0


func _hay(x: float, y: float) -> void:
	# 捆好的草垛：圆顶，暗处偏褐，上沿被夕阳照亮
	var col := Color("6a5026")
	draw_rect(Rect2(x - 22, y - 25, 44, 25), OUTLINE)
	draw_circle(Vector2(x - 12, y - 22), 9, OUTLINE)
	draw_circle(Vector2(x + 10, y - 22), 10, OUTLINE)
	draw_rect(Rect2(x - 21, y - 24, 42, 24), col)
	draw_circle(Vector2(x - 12, y - 22), 8, col)
	draw_circle(Vector2(x + 10, y - 22), 9, col)
	draw_line(Vector2(x - 18, y - 28), Vector2(x - 6, y - 30), Color("b08840"), 1.0)
	draw_line(Vector2(x + 3, y - 30), Vector2(x + 16, y - 29), Color("b08840"), 1.0)
	for k in range(14):
		var px := x - 20 + k * 3.0
		draw_line(Vector2(px, y - 24 + (k % 3)), Vector2(px + 1, y - 18 + (k % 3)), col.darkened(0.35), 1.0)
		draw_line(Vector2(px + 1, y - 11), Vector2(px, y - 5 + (k % 2)), col.darkened(0.35), 1.0)
	draw_rect(Rect2(x - 21, y - 13, 42, 1), col.darkened(0.45))
	draw_rect(Rect2(x - 9, y - 30, 2, 30), Color("3a2410"))
	draw_rect(Rect2(x + 7, y - 30, 2, 30), Color("3a2410"))


func _wall(x: float, y: float) -> void:
	# 断掉的石墙，顶上平的能站
	var top := y - 46.0
	draw_rect(Rect2(x - 49, top - 1, 98, 47), OUTLINE)
	draw_rect(Rect2(x - 48, top, 96, 46), STONE_DARK)
	for row in range(4):
		for k in range(6):
			var bx := x - 47 + k * 16 + (8 if row % 2 else 0)
			if bx + 14 > x + 48:
				continue
			draw_rect(Rect2(bx, top + 3 + row * 11, 14, 9), STONE)
			draw_rect(Rect2(bx, top + 3 + row * 11, 14, 1), STONE.lightened(0.2))
	draw_rect(Rect2(x - 48, top, 96, 3), Color("6a6070"))
	# 塌下来的碎石
	_rubble(x + 60, y)
	# 墙头长的草
	for k in range(10):
		draw_line(Vector2(x - 44 + k * 9, top), Vector2(x - 45 + k * 9, top - 3 - k % 3), Color("4a6a3a"), 1.0)


func _house2(x: float, y: float) -> void:
	var o := OUTLINE
	var wall := Color("2e1c26")
	var wall_lit := Color("4a2a2e")
	var beam := Color("1c1018")
	var hw := 82.0
	# 一楼：墙、门、柱子
	draw_rect(Rect2(x - hw + 4, y - 70, hw * 2 - 8, 70), wall)
	for k in range(5):
		draw_rect(Rect2(x - hw + 4 + k * (hw * 2 - 12) / 4.0, y - 70, 4, 70), beam)
	draw_rect(Rect2(x - 20, y - 46, 30, 46), Color("0e070c"))
	draw_rect(Rect2(x - 20, y - 46, 30, 3), beam)
	# 门口挂的破布帘
	for k in range(4):
		draw_rect(Rect2(x - 19 + k * 7, y - 43, 6, 14 + (k % 2) * 4), Color("5a2a2a"))
	draw_rect(Rect2(x + 34, y - 52, 18, 14), Color("0e070c"))
	draw_line(Vector2(x + 43, y - 52), Vector2(x + 43, y - 38), beam, 1.0)
	# 二楼：缩进去一点，窗里有灯
	var up := y - 70.0
	draw_rect(Rect2(x - 56, up - 48, 132, 48), wall)
	draw_rect(Rect2(x - 56, up - 48, 3, 48), wall_lit)
	for k in range(4):
		draw_rect(Rect2(x - 56 + k * 43.0, up - 48, 3, 48), beam)
	var flick := 0.8 + 0.2 * sin(time * 9.0 + x)
	draw_rect(Rect2(x + 26, up - 34, 16, 12), Color(1.0, 0.6, 0.25, flick))
	draw_line(Vector2(x + 34, up - 34), Vector2(x + 34, up - 22), beam, 1.0)
	draw_rect(Rect2(x - 36, up - 34, 16, 12), Color("0e070c"))
	# 二楼走廊（平台）+ 栏杆
	_plank(x - hw, x + hw, up)
	for k in range(9):
		var px := x - hw + 4 + k * 19.5
		draw_rect(Rect2(px, up - 12, 2, 12), WOOD_DARK)
	draw_rect(Rect2(x - hw, up - 13, hw * 2, 2), WOOD)
	draw_rect(Rect2(x - hw, up - 13, hw * 2, 1), WOOD_LIT)
	# 屋顶：茅草厚板，两头出檐往下垂
	var rt := y - 128.0
	draw_colored_polygon(PackedVector2Array([Vector2(x - 58, rt), Vector2(x + 78, rt), Vector2(x + 92, rt + 14),
		Vector2(x + 76, rt + 10), Vector2(x - 56, rt + 10), Vector2(x - 72, rt + 14)]), o)
	draw_rect(Rect2(x - 57, rt + 1, 134, 8), Color("3a2420"))
	draw_rect(Rect2(x - 57, rt + 1, 134, 1), Color("8a4a32"))
	for k in range(44):
		var px := x - 56 + k * 3.0
		draw_line(Vector2(px, rt + 2), Vector2(px + 1, rt + 7 + (k * 5) % 3), Color("2a1816"), 1.0)
		if k % 4 == 0:
			draw_line(Vector2(px, rt), Vector2(px + 1, rt - 2 - k % 3), Color("6a4a2a"), 1.0)
	# 楼梯：从左边地面斜着上到二楼
	var a := Vector2(x - 172, y)
	var b := Vector2(x - hw, up)
	draw_line(a + Vector2(0, 2), b + Vector2(0, 2), OUTLINE, 4.0)
	var n := 8
	for k in range(n):
		var t := (k + 0.5) / n
		var p := a.lerp(b, t)
		draw_rect(Rect2(p.x - 5, p.y - 1, 10, 3), OUTLINE)
		draw_rect(Rect2(p.x - 4, p.y - 1, 9, 2), WOOD)
		draw_rect(Rect2(p.x - 4, p.y - 1, 9, 1), WOOD_LIT)
	draw_line(a, b, WOOD_DARK, 2.0)
	# 扶手
	draw_line(a + Vector2(2, -14), b + Vector2(0, -14), WOOD_DARK, 1.0)
	for k in range(4):
		var p := a.lerp(b, (k + 0.2) / 4.0)
		draw_line(p, p + Vector2(0, -14), WOOD_DARK, 1.0)
	_house2_lantern(x, y)


func _house2_lantern(x: float, y: float) -> void:
	var rt := y - 128.0
	var flick := 0.8 + 0.2 * sin(time * 9.0 + x)
	# 挂在檐下的灯笼
	draw_line(Vector2(x + 34, rt + 10), Vector2(x + 34, rt + 18), Color("3a2a22"), 1.0)
	draw_rect(Rect2(x + 30, rt + 18, 8, 9), Color(0.85, 0.3, 0.15, flick))
	draw_rect(Rect2(x + 30, rt + 18, 8, 1), Color("3a2a22"))


func _scaffold(x: float, y: float) -> void:
	var hw := 33.0
	for px in [x - hw + 2, x + hw - 4]:
		draw_rect(Rect2(px, y - 116, 3, 116), WOOD_DARK)
		draw_rect(Rect2(px, y - 116, 1, 116), WOOD)
	# 交叉的斜撑
	draw_line(Vector2(x - hw + 3, y - 2), Vector2(x + hw - 3, y - 54), WOOD_DARK, 2.0)
	draw_line(Vector2(x + hw - 3, y - 58), Vector2(x - hw + 3, y - 110), WOOD_DARK, 2.0)
	# 梯子
	draw_line(Vector2(x + hw + 4, y), Vector2(x + hw + 4, y - 112), WOOD, 1.0)
	draw_line(Vector2(x + hw + 10, y), Vector2(x + hw + 10, y - 112), WOOD, 1.0)
	for k in range(14):
		draw_line(Vector2(x + hw + 4, y - 4 - k * 8), Vector2(x + hw + 10, y - 4 - k * 8), WOOD_DARK, 1.0)
	_plank(x - hw, x + hw, y - 56.0)
	_plank(x - hw, x + hw, y - 112.0)
	# 绑着的草绳和挂着的麻袋
	draw_circle(Vector2(x - 12, y - 48), 6, Color("6a5a3e"))
	draw_line(Vector2(x - 12, y - 56), Vector2(x - 12, y - 53), Color("8a7a52"), 1.0)


func _tower(x: float, y: float) -> void:
	var top := y - 100.0
	for px in [x - 24, x + 21]:
		draw_rect(Rect2(px, top, 3, 100), WOOD_DARK)
		draw_rect(Rect2(px, top, 1, 100), WOOD)
	draw_line(Vector2(x - 23, y - 4), Vector2(x + 22, top + 8), WOOD_DARK, 2.0)
	draw_line(Vector2(x + 22, y - 4), Vector2(x - 23, top + 8), WOOD_DARK, 2.0)
	# 半腰的踏板
	_plank(x - 45, x - 15, y - 52.0)
	_plank(x - 28, x + 28, top)
	# 护栏和顶棚
	draw_rect(Rect2(x - 28, top - 14, 56, 2), WOOD)
	for px in [x - 27, x - 9, x + 9, x + 25]:
		draw_rect(Rect2(px, top - 14, 2, 14), WOOD_DARK)
	for px in [x - 26, x + 23]:
		draw_rect(Rect2(px, top - 40, 2, 26), WOOD_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 34, top - 38), Vector2(x + 34, top - 38), Vector2(x, top - 54)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 32, top - 39), Vector2(x + 32, top - 39), Vector2(x, top - 52)]), Color("3a2420"))
	draw_line(Vector2(x - 32, top - 39), Vector2(x, top - 52), Color("8a4a32"), 1.0)
	var flick := 0.8 + 0.2 * sin(time * 9.0 + x)
	draw_rect(Rect2(x - 3, top - 22, 6, 7), Color(0.9, 0.35, 0.15, flick))


# ---------- 摆设 ----------

func _lantern(x: float, y: float) -> void:
	draw_rect(Rect2(x - 1, y - 52, 3, 52), WOOD_DARK)
	draw_rect(Rect2(x - 1, y - 52, 12, 2), WOOD_DARK)
	_lantern_box(x, y)


func _lantern_box(x: float, y: float) -> void:
	draw_line(Vector2(x + 7, y - 50), Vector2(x + 7, y - 46), Color("3a2a22"), 1.0)
	var flick := 0.8 + 0.2 * sin(time * 11.0 + x)
	var sway := roundf(sin(time * 1.5 + x) * 1.0)
	draw_rect(Rect2(x + 3 + sway, y - 46, 9, 11), OUTLINE)
	draw_rect(Rect2(x + 4 + sway, y - 45, 7, 9), Color(0.9, 0.32, 0.14, flick))
	draw_rect(Rect2(x + 4 + sway, y - 42, 7, 1), Color(0.5, 0.1, 0.05))
	draw_rect(Rect2(x + 5 + sway, y - 44, 2, 6), Color(1.0, 0.8, 0.5, flick))


func _laundry(x: float, y: float) -> void:
	# 两根竹竿之间拉一根绳，挂着破衣服随风摆
	draw_rect(Rect2(x - 42, y - 50, 2, 50), Color("4a5a3a"))
	draw_rect(Rect2(x + 40, y - 50, 2, 50), Color("4a5a3a"))
	_laundry_cloth(x, y)


func _laundry_cloth(x: float, y: float) -> void:
	var pts := PackedVector2Array()
	for k in range(9):
		var t := k / 8.0
		pts.append(Vector2(x - 41 + t * 82, y - 48 + sin(t * PI) * 6.0).round())
	draw_polyline(pts, Color("8a7a5a"), 1.0)
	var cloths := [Color("6a3a3a"), Color("3a4a6a"), Color("8a8070"), Color("4a5a3a")]
	for k in range(4):
		var p: Vector2 = pts[1 + k * 2]
		var sw := sin(time * 2.0 + k) * 2.0
		var w := 10.0 + (k % 2) * 4.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(-w / 2, 0), p + Vector2(w / 2, 0),
			p + Vector2(w / 2 + sw, 14 + k % 2 * 4), p + Vector2(-w / 2 + sw, 16)]), cloths[k])
		draw_line(p + Vector2(-w / 2, 1), p + Vector2(w / 2, 1), Color(cloths[k]).lightened(0.25), 1.0)


func _barrel(x: float, y: float) -> void:
	draw_rect(Rect2(x - 9, y - 21, 18, 21), OUTLINE)
	draw_rect(Rect2(x - 8, y - 20, 16, 20), Color("4a3428"))
	draw_rect(Rect2(x - 8, y - 20, 3, 20), Color("5a4232"))
	for yy in [-17, -10, -3]:
		draw_rect(Rect2(x - 8, y + yy, 16, 2), Color("2a2428"))


func _bucket(x: float, y: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y - 10), Vector2(x + 6, y - 10), Vector2(x + 5, y), Vector2(x - 5, y)]), WOOD)
	draw_rect(Rect2(x - 6, y - 10, 12, 1), WOOD_LIT)
	draw_rect(Rect2(x - 6, y - 6, 12, 1), Color("3a3036"))
	draw_arc(Vector2(x, y - 10), 6, PI, TAU, 8, Color("6a6a72"), 1.0)


func _woodpile(x: float, y: float) -> void:
	for row in range(3):
		for k in range(4 - row):
			var c := Vector2(x - 15 + k * 10 + row * 5, y - 5 - row * 9)
			draw_circle(c, 5, OUTLINE)
			draw_circle(c, 4, WOOD)
			draw_circle(c, 2, Color("a07850"))


func _banner(x: float, y: float) -> void:
	# 破旗：一根歪杆，上面挂着烂成条的布
	draw_line(Vector2(x, y), Vector2(x + 2, y - 70), WOOD_DARK, 2.0)
	var col := Color("7a2a24")
	for k in range(5):
		var sw := sin(time * 2.4 + k * 0.6) * (2.0 + k)
		var top := y - 68.0 + k * 0.0
		var len := 26.0 - (k % 3) * 6.0
		draw_line(Vector2(x + 3 + k * 4, top), Vector2(x + 3 + k * 4 + sw, top + len), col if k % 2 else col.darkened(0.2), 4.0)
	draw_rect(Rect2(x + 1, y - 70, 22, 2), WOOD)


func _rubble(x: float, y: float) -> void:
	for k in range(5):
		var p := Vector2(x - 10 + k * 5, y - 3 - (k % 2) * 2)
		draw_rect(Rect2(p, Vector2(5 + k % 2, 3 + k % 3)), STONE_DARK if k % 2 else STONE)


func _bamboo(x: float, y: float) -> void:
	for k in range(5):
		var px := x - 10 + k * 5
		var h := 60.0 + (k * 13) % 30
		var sway := sin(time * 1.2 + k) * 2.0
		draw_line(Vector2(px, y), Vector2(px + sway, y - h), Color("2f4a2a") if k % 2 else Color("3e5e34"), 2.0)
		for j in range(3):
			var py := y - 14 - j * 18
			draw_rect(Rect2(px - 1, py, 3, 1), Color("5a7a44"))
		draw_colored_polygon(PackedVector2Array([Vector2(px + sway, y - h), Vector2(px + sway + 12, y - h + 4),
			Vector2(px + sway + 2, y - h + 3)]), Color("3e5e34"))


func _tent(x: float, y: float) -> void:
	var col := Color("5a4a3a")
	draw_colored_polygon(PackedVector2Array([Vector2(x - 34, y), Vector2(x, y - 46), Vector2(x + 34, y)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 32, y), Vector2(x, y - 44), Vector2(x + 32, y)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y), Vector2(x, y - 30), Vector2(x + 8, y)]), Color("140c0c"))
	draw_line(Vector2(x - 32, y), Vector2(x, y - 44), col.lightened(0.3), 1.0)
	draw_line(Vector2(x, y - 44), Vector2(x, y - 52), WOOD_DARK, 2.0)
	for k in range(3):
		draw_line(Vector2(x - 26 + k * 9, y - 8 - k * 10), Vector2(x - 22 + k * 9, y - 6 - k * 10), col.darkened(0.3), 1.0)


func _rack(x: float, y: float) -> void:
	draw_rect(Rect2(x - 16, y - 34, 2, 34), WOOD_DARK)
	draw_rect(Rect2(x + 14, y - 34, 2, 34), WOOD_DARK)
	draw_rect(Rect2(x - 17, y - 30, 34, 2), WOOD)
	draw_rect(Rect2(x - 17, y - 12, 34, 2), WOOD)
	for k in range(4):
		var px := x - 11 + k * 7
		draw_line(Vector2(px, y - 2), Vector2(px + 1, y - 44 - (k % 2) * 6), Color("9a9aa4"), 1.0)
		draw_rect(Rect2(px - 1, y - 14, 3, 4), Color("3a2a22"))


func _stone_lantern(x: float, y: float) -> void:
	draw_rect(Rect2(x - 3, y - 26, 6, 26), STONE_DARK)
	draw_rect(Rect2(x - 8, y - 4, 16, 4), STONE_DARK)
	draw_rect(Rect2(x - 7, y - 30, 14, 4), STONE)
	draw_rect(Rect2(x - 6, y - 41, 12, 11), STONE_DARK)
	var flick := 0.8 + 0.2 * sin(time * 13.0 + x) * sin(time * 7.0)
	draw_rect(Rect2(x - 3, y - 39, 6, 7), Color(1.0, 0.7, 0.3, flick))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 11, y - 41), Vector2(x + 11, y - 41), Vector2(x + 4, y - 48), Vector2(x - 4, y - 48)]), STONE)
