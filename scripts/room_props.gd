class_name RoomProps
extends Node2D
## 房间里的摆设：井、板车、木箱、破棚、稻草人、篝火、路牌、坟头。
## 板车、木箱、棚顶能站上去（单向平台，从下面能跳穿）。

## 能站的摆设：[顶面离地高度, 宽度]
const PLATFORMS := {"cart": [26.0, 58.0], "crates": [34.0, 38.0], "shed": [74.0, 104.0]}

var props: Array = []
var floor_y := 300.0
var time := 0.0
var _glow: Node2D


class Glow extends Node2D:
	var owner_props: RoomProps

	func _draw() -> void:
		owner_props._draw_glow(self)


func _ready() -> void:
	_glow = Glow.new()
	_glow.owner_props = self
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)


## 所有能站的平台（世界坐标，顶边）
static func platform_rects(list: Array, floor_y: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pr: Array in list:
		if PLATFORMS.has(pr[0]):
			var spec: Array = PLATFORMS[pr[0]]
			var x: float = pr[1]
			out.append(Rect2(x - spec[1] / 2.0, floor_y - spec[0], spec[1], 6))
			if pr[0] == "shed":
				# 棚子旁边叠两个木箱当台阶
				out.append(Rect2(x - spec[1] / 2.0 - 30.0, floor_y - 34.0, 34.0, 6))
	return out


func _process(delta: float) -> void:
	time += delta
	queue_redraw()
	_glow.queue_redraw()


func _draw() -> void:
	for pr: Array in props:
		var x: float = pr[1]
		match String(pr[0]):
			"well": _well(x)
			"cart": _cart(x)
			"crates": _crates(x, 0.0)
			"shed": _shed(x)
			"scarecrow": _scarecrow(x)
			"fire": _fire(x)
			"sign": _sign(x)
			"grave": _grave(x)


func _draw_glow(c: CanvasItem) -> void:
	for pr: Array in props:
		if pr[0] == "fire":
			var x: float = pr[1]
			var flick := 0.85 + 0.15 * sin(time * 13.0 + x) * sin(time * 7.0)
			for i in range(6):
				c.draw_circle(Vector2(x, floor_y - 10), 8.0 + i * 11.0, Color(0.5, 0.2, 0.05, 0.08 * flick))
			c.draw_set_transform(Vector2(x, floor_y + 3), 0.0, Vector2(1.0, 0.18))
			for i in range(4):
				c.draw_circle(Vector2.ZERO, 30.0 + i * 18.0, Color(0.4, 0.15, 0.03, 0.09 * flick))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const WOOD := Color("4a3024")
const WOOD_DARK := Color("2a1a16")
const WOOD_LIT := Color("8a5a3a")
const STONE := Color("4a4048")
const STONE_DARK := Color("2a2430")
const OUTLINE := Color("0c080a")


func _well(x: float) -> void:
	var y := floor_y
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


func _cart(x: float) -> void:
	var top := floor_y - 26.0
	# 车板
	draw_rect(Rect2(x - 30, top - 1, 60, 8), OUTLINE)
	draw_rect(Rect2(x - 29, top, 58, 6), WOOD)
	draw_rect(Rect2(x - 29, top, 58, 1), WOOD_LIT)
	for k in range(5):
		draw_rect(Rect2(x - 29 + k * 12, top + 1, 1, 5), WOOD_DARK)
	# 车把斜着搭在地上
	draw_line(Vector2(x + 28, top + 4), Vector2(x + 52, floor_y), WOOD_DARK, 2.0)
	# 轮子
	var wc := Vector2(x - 10, floor_y - 11)
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


func _crates(x: float, _h: float) -> void:
	_crate(Vector2(x - 19, floor_y), 19)
	_crate(Vector2(x, floor_y), 19)
	_crate(Vector2(x - 12, floor_y - 19), 15)
	# 顶上补一块木板，站的地方
	draw_rect(Rect2(x - 20, floor_y - 35, 40, 3), WOOD_LIT.darkened(0.15))


func _shed(x: float) -> void:
	var top := floor_y - 74.0
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
	_crate(Vector2(x - hw - 30, floor_y), 17)
	_crate(Vector2(x - hw - 13, floor_y), 17)
	_crate(Vector2(x - hw - 26, floor_y - 17), 16)
	# 棚下堆的草垛
	draw_circle(Vector2(x + 16, floor_y - 9), 12, Color("5a4220"))
	draw_circle(Vector2(x + 30, floor_y - 7), 9, Color("4a3618"))
	draw_line(Vector2(x + 8, floor_y - 16), Vector2(x + 22, floor_y - 18), Color("8a6a3a"), 1.0)


func _scarecrow(x: float) -> void:
	var y := floor_y
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


func _fire(x: float) -> void:
	var y := floor_y
	# 柴堆
	draw_line(Vector2(x - 10, y), Vector2(x + 8, y - 6), WOOD_DARK, 3.0)
	draw_line(Vector2(x + 10, y), Vector2(x - 8, y - 6), WOOD_DARK, 3.0)
	for k in range(5):
		var a := k * TAU / 5.0
		draw_rect(Rect2(x + cos(a) * 11 - 2, y - 2, 4, 2), STONE)
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


func _sign(x: float) -> void:
	var y := floor_y
	draw_rect(Rect2(x - 1, y - 44, 3, 44), WOOD_DARK)
	draw_rect(Rect2(x - 20, y - 46, 40, 14), OUTLINE)
	draw_rect(Rect2(x - 19, y - 45, 38, 12), WOOD)
	draw_rect(Rect2(x - 19, y - 45, 38, 1), WOOD_LIT)
	# 路牌上刻的字用几道划痕代替
	for k in range(4):
		draw_rect(Rect2(x - 14 + k * 8, y - 42, 5, 6), WOOD_DARK)
	draw_line(Vector2(x + 19, y - 39), Vector2(x + 25, y - 39), WOOD, 2.0)


func _grave(x: float) -> void:
	var y := floor_y
	draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y), Vector2(x - 8, y - 7), Vector2(x + 8, y - 7), Vector2(x + 14, y)]), Color("2a2026"))
	draw_rect(Rect2(x - 5, y - 26, 10, 20), OUTLINE)
	draw_rect(Rect2(x - 4, y - 25, 8, 19), Color("5a5058"))
	draw_rect(Rect2(x - 4, y - 25, 2, 19), Color("7a7078"))
	draw_rect(Rect2(x - 1, y - 21, 2, 10), Color("3a3038"))
	# 插着的破刀
	draw_line(Vector2(x + 10, y), Vector2(x + 13, y - 22), Color("8a8a92"), 1.0)
	draw_rect(Rect2(x + 11, y - 26, 4, 2), Color("3a2a22"))
