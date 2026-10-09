class_name Background
extends Node2D
## 夜晚山寺场景，分成多层做视差：夜空、远山、寺庙、竹林和石灯笼、地面、前景。
## 发光的东西（月晕、光柱、灯笼光、萤火）放在叠加混合的图层里。
## 每层按 factor 跟随镜头移动：0 = 固定在屏幕上（天空），1 = 和地面一起动，大于 1 = 前景。

const VIEW_W := 640.0
const VIEW_H := 360.0

var floor_y := 300.0
var arena_w := 800.0
var seed_value := 0
var time := 0.0
var _layers: Array[Layer] = []
var _front: Array[Layer] = []
var _petals: Array[Vector3] = []
var _flies: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


class Layer extends Node2D:
	var factor := 1.0
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func _ready() -> void:
	_build()


## 子类（荒村、河畔）重写这两个函数换一套图层
func _build() -> void:
	_rng.seed = 7
	for i in range(30):
		_petals.append(Vector3(_rng.randf() * arena_w, _rng.randf() * floor_y, _rng.randf() * TAU))
	for i in range(14):
		_flies.append(Vector3(_rng.randf() * arena_w, floor_y - 20.0 - _rng.randf() * 90.0, _rng.randf() * TAU))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer(0.0, _paint_sky)
	_add_layer(0.0, _paint_moon_glow, add)
	_add_layer(0.12, _paint_far_mountains)
	_add_layer(0.3, _paint_temple)
	_add_layer(0.3, _paint_rays, add)
	_add_layer(0.6, _paint_near)
	_add_layer(0.6, _paint_lantern_glow, add)
	_add_layer(1.0, _paint_ground)
	_add_layer(1.0, _paint_ground_glow, add)


## 前景层要放在角色前面，由主场景加到更高的层级
func make_foreground() -> Array[Layer]:
	return _build_front()


func _build_front() -> Array[Layer]:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front.append(_new_layer(1.0, _paint_fireflies, add))
	_front.append(_new_layer(1.0, _paint_petals))
	_front.append(_new_layer(1.0, _paint_fog))
	_front.append(_new_layer(1.3, _paint_foreground))
	return _front


func _new_layer(factor: float, painter: Callable, mat: Material = null) -> Layer:
	var l := Layer.new()
	l.factor = factor
	l.painter = painter
	if mat != null:
		l.material = mat
	return l


func _add_layer(factor: float, painter: Callable, mat: Material = null) -> void:
	var l := _new_layer(factor, painter, mat)
	add_child(l)
	_layers.append(l)


## 镜头左边缘的世界坐标为 cam_left 时，更新各层位置
func set_camera(cam_left: float) -> void:
	for l in _layers + _front:
		l.position.x = cam_left * (1.0 - l.factor)


## 视差层要画多宽才能盖住整个房间
func span(factor: float) -> float:
	return VIEW_W + maxf(arena_w - VIEW_W, 0.0) * factor + 40.0


func _process(delta: float) -> void:
	time += delta
	_tick(delta)
	for l in _layers + _front:
		l.queue_redraw()


func _tick(delta: float) -> void:
	for i in range(_petals.size()):
		var p := _petals[i]
		p.z += delta * 2.0
		p.x += (16.0 + sin(p.z) * 14.0) * delta
		p.y += 20.0 * delta
		if p.y > floor_y + 10.0 or p.x > arena_w + 10.0:
			p = Vector3(_rng.randf() * arena_w - 80.0, -6.0, _rng.randf() * TAU)
		_petals[i] = p
	for i in range(_flies.size()):
		var f := _flies[i]
		f.z += delta
		f.x += cos(f.z * 0.7 + i) * 8.0 * delta
		f.y += sin(f.z * 1.1 + i * 2.0) * 6.0 * delta
		_flies[i] = f


# ---------- 各层 ----------

func _paint_sky(c: CanvasItem) -> void:
	var top := Color("0a0818")
	var mid := Color("1d1538")
	var low := Color("4a2a55")
	var steps := 24
	var band := floor_y / steps
	for i in range(steps):
		var t := float(i) / (steps - 1)
		var col := top.lerp(mid, t * 1.6) if t < 0.6 else mid.lerp(low, (t - 0.6) / 0.4)
		c.draw_rect(Rect2(0, roundf(i * band), VIEW_W + 200, ceilf(band) + 1), col)
	# 星星，部分会闪
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in range(90):
		var pos := Vector2(rng.randi_range(0, int(VIEW_W)), rng.randi_range(0, 190))
		var b := rng.randf_range(0.3, 1.0) * (0.6 + 0.4 * sin(time * rng.randf_range(1.0, 4.0) + i))
		c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(0.9, 0.9, 1.0, b))
		if i % 17 == 0:
			c.draw_rect(Rect2(pos - Vector2(1, 0), Vector2(3, 1)), Color(0.9, 0.9, 1.0, b * 0.4))
			c.draw_rect(Rect2(pos - Vector2(0, 1), Vector2(1, 3)), Color(0.9, 0.9, 1.0, b * 0.4))
	# 月亮
	var m := Vector2(470, 84)
	c.draw_circle(m, 26, Color("f1e6c8"))
	c.draw_circle(m + Vector2(3, 2), 24, Color("e8dbb8"))
	c.draw_circle(m + Vector2(-8, -6), 5, Color("d6c8a2"))
	c.draw_circle(m + Vector2(9, 7), 4, Color("d6c8a2"))
	c.draw_circle(m + Vector2(-2, 11), 3, Color("d6c8a2"))
	c.draw_circle(m + Vector2(10, -9), 2, Color("d6c8a2"))


func _paint_moon_glow(c: CanvasItem) -> void:
	var m := Vector2(470, 84)
	for i in range(10):
		c.draw_circle(m, 28.0 + i * 6.0, Color(0.3, 0.22, 0.36, 0.035))


func _paint_far_mountains(c: CanvasItem) -> void:
	var w := VIEW_W + 220.0
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(0, 210), Vector2(80, 150), Vector2(150, 185), Vector2(250, 118), Vector2(340, 178),
		Vector2(430, 140), Vector2(520, 196), Vector2(640, 128), Vector2(760, 186), Vector2(w, 160),
		Vector2(w, floor_y), Vector2(0, floor_y),
	]), Color("2b1f47"))
	# 受月光一侧的亮面
	for peak in [Vector2(250, 118), Vector2(640, 128), Vector2(80, 150), Vector2(430, 140)]:
		c.draw_colored_polygon(PackedVector2Array([peak, peak + Vector2(26, 34), peak + Vector2(8, 34)]), Color("3d2f63"))
	# 山脚的雾
	for i in range(8):
		c.draw_rect(Rect2(0, 200 + i * 6, w, 6), Color(0.4, 0.3, 0.55, 0.05 + i * 0.012))
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(0, 238), Vector2(110, 206), Vector2(220, 232), Vector2(330, 198), Vector2(450, 236),
		Vector2(580, 204), Vector2(700, 230), Vector2(w, 210), Vector2(w, floor_y), Vector2(0, floor_y),
	]), Color("221a3a"))


func _paint_temple(c: CanvasItem) -> void:
	var col := Color("150f24")
	var lit := Color("2a2040")
	# 宝塔
	var base := Vector2(150, 262)
	var w := 46.0
	var y := base.y
	for i in range(5):
		_roof(c, Vector2(base.x, y), w + 16.0, col, lit)
		c.draw_rect(Rect2(base.x - w / 2.0 + 5, y - 16, w - 10, 12), col)
		if i < 4:
			var glow := 0.7 + 0.3 * sin(time * 2.0 + i)
			c.draw_rect(Rect2(base.x - 3, y - 13, 6, 6), Color(0.95, 0.6, 0.25, glow))
		y -= 18
		w -= 7
	c.draw_line(Vector2(base.x, y), Vector2(base.x, y - 22), col, 2.0)
	for k in range(3):
		c.draw_rect(Rect2(base.x - 3, y - 8 - k * 5, 7, 1), col)
	c.draw_rect(Rect2(base.x - 30, base.y, 60, floor_y - base.y), col)
	# 主殿屋顶
	var hall := Vector2(560, 258)
	_roof(c, hall, 150.0, col, lit)
	c.draw_rect(Rect2(hall.x - 62, hall.y, 124, floor_y - hall.y), col)
	for i in range(4):
		c.draw_rect(Rect2(hall.x - 50 + i * 30, hall.y + 10, 14, 18), Color(0.85, 0.5, 0.2, 0.55))
	# 樱花树（右侧）
	var tree := Vector2(720, floor_y)
	c.draw_line(tree, tree + Vector2(-10, -60), col, 6.0)
	c.draw_line(tree + Vector2(-8, -45), tree + Vector2(-40, -78), col, 3.0)
	c.draw_line(tree + Vector2(-10, -60), tree + Vector2(14, -92), col, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in range(26):
		var p := tree + Vector2(rng.randf_range(-60, 30), rng.randf_range(-115, -62))
		var r := rng.randf_range(6, 12)
		c.draw_circle(p, r, Color("5a2c4e"))
		c.draw_circle(p + Vector2(2, -2), r * 0.6, Color("7a3a62"))


func _roof(c: CanvasItem, at: Vector2, width: float, col: Color, lit: Color) -> void:
	# 弯翘的屋檐
	var hw := width / 2.0
	c.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-hw - 4, -9), at + Vector2(-hw + 6, -4), at + Vector2(hw - 6, -4), at + Vector2(hw + 4, -9),
		at + Vector2(hw - 10, -13), at + Vector2(-hw + 10, -13),
	]), col)
	c.draw_line(at + Vector2(-hw + 10, -13), at + Vector2(hw - 10, -13), lit, 1.0)
	c.draw_line(at + Vector2(hw - 10, -13), at + Vector2(hw + 4, -9), lit, 1.0)


func _paint_rays(c: CanvasItem) -> void:
	var a := 0.035 + 0.015 * sin(time * 0.8)
	for i in range(4):
		var x0 := 360.0 + i * 70.0
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(x0, 0), Vector2(x0 + 26 + i * 6, 0), Vector2(x0 - 140 + i * 10, floor_y), Vector2(x0 - 190, floor_y),
		]), Color(0.55, 0.5, 0.75, a))


func _paint_near(c: CanvasItem) -> void:
	var stalks := [6.0, 22.0, 36.0, 52.0, 806.0, 822.0, 838.0, 856.0]
	for i in range(stalks.size()):
		var x: float = stalks[i]
		var col := Color("16271f") if i % 2 == 0 else Color("1c3327")
		var hl := Color("2c4a37")
		c.draw_rect(Rect2(x, 0, 6, floor_y), col)
		c.draw_rect(Rect2(x + 4, 0, 1, floor_y), hl)
		for y in range(16 + i * 9, int(floor_y), 38):
			c.draw_rect(Rect2(x - 1, y, 8, 2), hl)
			var side := -1.0 if (y / 38 + i) % 2 == 0 else 1.0
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(x + 3, y), Vector2(x + 3 + side * 20, y - 7), Vector2(x + 3 + side * 17, y - 2),
			]), col.lightened(0.08))
	# 石灯笼
	for x in [120.0, 470.0, 760.0]:
		_stone_lantern(c, Vector2(x, floor_y))


func _stone_lantern(c: CanvasItem, at: Vector2) -> void:
	var stone := Color("3a3448")
	var dark := Color("231f2e")
	c.draw_rect(Rect2(at.x - 3, at.y - 26, 6, 26), dark)
	c.draw_rect(Rect2(at.x - 8, at.y - 4, 16, 4), dark)
	c.draw_rect(Rect2(at.x - 7, at.y - 30, 14, 4), stone)
	c.draw_rect(Rect2(at.x - 6, at.y - 41, 12, 11), dark)
	var flick := 0.8 + 0.2 * sin(time * 13.0 + at.x) * sin(time * 7.0)
	c.draw_rect(Rect2(at.x - 3, at.y - 39, 6, 7), Color(1.0, 0.7, 0.3, flick))
	c.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-11, -41), at + Vector2(11, -41), at + Vector2(4, -48), at + Vector2(-4, -48),
	]), stone)
	c.draw_rect(Rect2(at.x - 1, at.y - 51, 3, 3), stone)


func _paint_lantern_glow(c: CanvasItem) -> void:
	for x in [120.0, 470.0, 760.0]:
		var flick := 0.85 + 0.15 * sin(time * 13.0 + x) * sin(time * 7.0)
		var p := Vector2(x, floor_y - 36)
		for i in range(5):
			c.draw_circle(p, 8.0 + i * 9.0, Color(0.45, 0.22, 0.05, 0.09 * flick))


func _paint_ground(c: CanvasItem) -> void:
	var w := arena_w + 200.0
	c.draw_rect(Rect2(-100, floor_y, w, VIEW_H - floor_y + 40), Color("1b1622"))
	# 地面边缘：受光的石沿
	c.draw_rect(Rect2(-100, floor_y, w, 4), Color("4a4058"))
	c.draw_rect(Rect2(-100, floor_y, w, 1), Color("6b5f80"))
	# 石砖
	for row in range(4):
		var y := floor_y + 5 + row * 11
		var off := 0 if row % 2 == 0 else 17
		var shade := 1.0 - row * 0.18
		for x in range(-100 - off, int(arena_w + 100), 34):
			var v := posmod((x / 34) * 7 + row * 3, 5)
			var col := Color("332a3e").lerp(Color("3d3349"), v / 5.0) * Color(shade, shade, shade)
			c.draw_rect(Rect2(x + 1, y, 32, 9), col)
			c.draw_rect(Rect2(x + 1, y, 32, 1), col.lightened(0.15))
			if v == 2:
				c.draw_line(Vector2(x + 8, y + 2), Vector2(x + 14, y + 7), col.darkened(0.3), 1.0)
	# 青苔和草
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(140):
		var x := rng.randi_range(-100, int(arena_w + 100))
		var h := rng.randi_range(2, 6)
		var g := Color("35593c") if i % 3 else Color("4f7d4c")
		c.draw_rect(Rect2(x, floor_y - h + 1, 1, h), g)
		if i % 4 == 0:
			c.draw_rect(Rect2(x - 2, floor_y + 1, 5, 1), Color("2f4a34"))


func _paint_ground_glow(c: CanvasItem) -> void:
	# 灯笼在地上的光斑
	for x in [470.0]:
		c.draw_set_transform(Vector2(x, floor_y + 4), 0.0, Vector2(1.0, 0.2))
		for i in range(4):
			c.draw_circle(Vector2.ZERO, 30.0 + i * 16.0, Color(0.35, 0.16, 0.04, 0.08))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_fireflies(c: CanvasItem) -> void:
	for f in _flies:
		var b := 0.5 + 0.5 * sin(f.z * 3.0)
		var p := Vector2(f.x, f.y).round()
		c.draw_circle(p, 3.0, Color(0.4, 0.6, 0.15, 0.15 * b))
		c.draw_rect(Rect2(p, Vector2(1, 1)), Color(0.8, 1.0, 0.5, b))


func _paint_petals(c: CanvasItem) -> void:
	for p in _petals:
		var col := Color("f4b3cc") if int(p.z * 3.0) % 2 == 0 else Color("e47fa8")
		c.draw_rect(Rect2(Vector2(p.x, p.y).round(), Vector2(2, 1 + int(sin(p.z) > 0.0))), col)


func _paint_fog(c: CanvasItem) -> void:
	# 贴地的薄雾，缓慢流动
	for i in range(3):
		var x := fmod(time * (6.0 + i * 3.0), 300.0) - 300.0
		while x < arena_w + 100.0:
			c.draw_rect(Rect2(x, floor_y - 6 - i * 4, 180, 6 + i * 2), Color(0.55, 0.45, 0.7, 0.05))
			x += 300.0


func _paint_foreground(c: CanvasItem) -> void:
	# 画面最前面的暗色草丛和枝条
	var col := Color("07060b")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for cluster in [Vector2(-20, VIEW_H), Vector2(330, VIEW_H), Vector2(900, VIEW_H)]:
		for i in range(14):
			var x: float = cluster.x + rng.randf_range(-40, 60)
			var h := rng.randf_range(14, 38)
			var lean := rng.randf_range(-8, 8)
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(x - 3, cluster.y), Vector2(x + 3, cluster.y), Vector2(x + lean, cluster.y - h),
			]), col)
	# 左上角垂下的枝叶
	c.draw_line(Vector2(-30, 0), Vector2(70, 26), col, 4.0)
	for i in range(8):
		var p := Vector2(-20, 0).lerp(Vector2(70, 26), i / 7.0)
		c.draw_circle(p + Vector2(0, 6 + (i % 3) * 3), 5.0, col)
