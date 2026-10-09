class_name BgRiver
extends Background
## 断水河畔，夜。满月照着河面，对岸是一排柳树和一座石拱桥；近处芦苇摇，头顶垂下柳条。
## 柳江远守在这里。光从右上方的月亮来，轮廓光偏冷。

const MOON := Vector2(480, 70)

var _leaves: Array[Vector3] = []
var _motes: Array[Vector3] = []


func _build() -> void:
	_rng.seed = 200 + seed_value
	for i in range(22):
		_leaves.append(Vector3(_rng.randf() * arena_w, _rng.randf() * floor_y, _rng.randf() * TAU))
	for i in range(16):
		_motes.append(Vector3(_rng.randf() * arena_w, floor_y - 10.0 - _rng.randf() * 80.0, _rng.randf() * TAU))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer(0.0, _paint_sky)
	_add_layer(0.0, _paint_moon_glow, add)
	_add_layer(0.1, _paint_mountains)
	_add_layer(0.3, _paint_far_bank)
	_add_layer(0.45, _paint_water)
	_add_layer(0.45, _paint_water_glow, add)
	_add_layer(0.7, _paint_reeds)
	_add_layer(1.0, _paint_ground)


func _build_front() -> Array[Layer]:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front.append(_new_layer(1.0, _paint_motes, add))
	_front.append(_new_layer(1.0, _paint_leaves))
	_front.append(_new_layer(1.0, _paint_mist))
	_front.append(_new_layer(1.3, _paint_willow))
	return _front


func _tick(delta: float) -> void:
	for i in range(_leaves.size()):
		var l := _leaves[i]
		l.z += delta * 2.2
		l.x += (-14.0 + sin(l.z) * 16.0) * delta
		l.y += 16.0 * delta
		if l.y > floor_y + 8.0 or l.x < -20.0:
			l = Vector3(_rng.randf() * arena_w + 80.0, -6.0, _rng.randf() * TAU)
		_leaves[i] = l
	for i in range(_motes.size()):
		var f := _motes[i]
		f.z += delta
		f.x += cos(f.z * 0.6 + i) * 7.0 * delta
		f.y += sin(f.z * 1.0 + i * 2.0) * 5.0 * delta
		_motes[i] = f


func _paint_sky(c: CanvasItem) -> void:
	var top := Color("05081a")
	var low := Color("1c2a4e")
	var steps := 24
	var band := 240.0 / steps
	for i in range(steps):
		c.draw_rect(Rect2(0, roundf(i * band), VIEW_W + 200, ceilf(band) + 1), top.lerp(low, float(i) / (steps - 1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in range(110):
		var pos := Vector2(rng.randi_range(0, int(VIEW_W)), rng.randi_range(0, 200))
		var b := rng.randf_range(0.3, 1.0) * (0.6 + 0.4 * sin(time * rng.randf_range(1.0, 4.0) + i))
		c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(0.8, 0.88, 1.0, b))
	c.draw_circle(MOON, 30, Color("dfe8f2"))
	c.draw_circle(MOON + Vector2(-3, 2), 28, Color("cfdbe8"))
	for s in [Vector3(-9, -7, 6), Vector3(8, 6, 5), Vector3(-2, 12, 3), Vector3(12, -10, 3)]:
		c.draw_circle(MOON + Vector2(s.x, s.y), s.z, Color("b8c6d6"))


func _paint_moon_glow(c: CanvasItem) -> void:
	for i in range(12):
		c.draw_circle(MOON, 32.0 + i * 7.0, Color(0.12, 0.16, 0.28, 0.05))


func _paint_mountains(c: CanvasItem) -> void:
	var w := span(0.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33 + seed_value
	for layer in range(2):
		var pts := PackedVector2Array()
		var base := 200.0 + layer * 22.0
		var x := -20.0
		pts.append(Vector2(x, 260))
		while x < w + 40.0:
			pts.append(Vector2(x, base - rng.randf_range(10, 70 - layer * 25)))
			x += rng.randf_range(50, 110)
		pts.append(Vector2(x, 260))
		c.draw_colored_polygon(pts, Color("1a2444") if layer == 0 else Color("121a33"))
		for i in range(1, pts.size() - 1):
			if pts[i].y < pts[i + 1].y:
				c.draw_line(pts[i], pts[i + 1].lerp(pts[i], 0.6), Color(0.45, 0.55, 0.8, 0.45 - layer * 0.2), 1.0)
	for k in range(6):
		c.draw_rect(Rect2(0, 218 + k * 6, w, 6), Color(0.35, 0.45, 0.7, 0.04))


func _paint_far_bank(c: CanvasItem) -> void:
	var w := span(0.3)
	var col := Color("0d1428")
	var bank := 238.0
	c.draw_rect(Rect2(-20, bank, w + 40, 8), col)
	# 石拱桥
	var bx := w * 0.55
	var arch := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		arch.append(Vector2(bx - 70 + t * 140, bank - 26 - sin(t * PI) * 14.0))
	for i in range(12, -1, -1):
		var t := float(i) / 12.0
		arch.append(Vector2(bx - 50 + t * 100, bank + 2 - sin(t * PI) * 26.0))
	c.draw_colored_polygon(arch, col)
	for i in range(12):
		var t := float(i) / 11.0
		var p := Vector2(bx - 66 + t * 132, bank - 30 - sin(t * PI) * 14.0)
		c.draw_rect(Rect2(p.round(), Vector2(1, 4)), col)
	c.draw_polyline(arch.slice(0, 13), Color(0.4, 0.5, 0.75, 0.6), 1.0)
	# 对岸的柳树：树干 + 一缕缕垂下来的枝条
	var rng := RandomNumberGenerator.new()
	rng.seed = 44 + seed_value
	var x := rng.randf_range(0, 80)
	while x < w:
		if absf(x - bx) > 90.0:
			_willow_tree(c, Vector2(x, bank), rng.randf_range(40, 60), rng, col)
		x += rng.randf_range(70, 150)


func _willow_tree(c: CanvasItem, at: Vector2, h: float, rng: RandomNumberGenerator, col: Color) -> void:
	c.draw_line(at, at + Vector2(3, -h), col, 3.0)
	var top := at + Vector2(3, -h)
	for k in range(14):
		var sx := top.x + rng.randf_range(-22, 22)
		var sy := top.y + rng.randf_range(-6, 6)
		var len := rng.randf_range(20, h * 0.9)
		var sway := sin(time * 0.8 + sx * 0.1) * 2.0
		c.draw_line(Vector2(sx, sy), Vector2(sx + sway, sy + len), col, 1.0)
	c.draw_circle(top, 14, col)
	c.draw_circle(top + Vector2(-12, 4), 10, col)
	c.draw_circle(top + Vector2(12, 4), 10, col)


func _paint_water(c: CanvasItem) -> void:
	var w := span(0.45)
	var top := 246.0
	var bottom := floor_y
	var steps := 8
	for i in range(steps):
		var t := float(i) / steps
		c.draw_rect(Rect2(-20, top + t * (bottom - top), w + 40, (bottom - top) / steps + 1), Color("101c38").lerp(Color("0a1226"), t))
	# 波纹：一条条短横线左右漂
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in range(70):
		var y := rng.randf_range(top + 2, bottom - 4)
		var x := fmod(rng.randf_range(0, w) + time * rng.randf_range(4, 10), w + 40.0) - 20.0
		var len := rng.randf_range(6, 22)
		c.draw_rect(Rect2(roundf(x), roundf(y), len, 1), Color(0.35, 0.45, 0.7, 0.35))


func _paint_water_glow(c: CanvasItem) -> void:
	# 月亮在河面的倒影：一列抖动的亮条
	var mx := MOON.x + (0.0 - 0.0)
	var top := 248.0
	for i in range(16):
		var y := top + i * 3.4
		var wob := sin(time * 2.2 + i * 1.3) * (3.0 + i * 0.4)
		var len := 34.0 - i * 1.2 + sin(time * 3.0 + i) * 4.0
		c.draw_rect(Rect2(roundf(mx - len / 2.0 + wob), roundf(y), len, 1), Color(0.55, 0.65, 0.85, 0.5 - i * 0.025))


func _paint_reeds(c: CanvasItem) -> void:
	var w := span(0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 66 + seed_value
	var x := -10.0
	while x < w:
		var n := rng.randi_range(6, 14)
		for k in range(n):
			var px := x + rng.randf_range(0, 40)
			var h := rng.randf_range(18, 46)
			var sway := sin(time * 1.4 + px * 0.05) * 3.0
			var col := Color("16253a") if k % 2 else Color("1d3147")
			c.draw_line(Vector2(px, floor_y), Vector2(px + sway, floor_y - h), col, 1.0)
			if k % 3 == 0:
				c.draw_rect(Rect2(Vector2(px + sway - 1, floor_y - h - 5).round(), Vector2(2, 6)), Color("3a3a4a"))
		# 河边的大石头
		if rng.randf() < 0.4:
			var sx := x + rng.randf_range(10, 40)
			c.draw_colored_polygon(PackedVector2Array([Vector2(sx - 14, floor_y), Vector2(sx - 9, floor_y - 10),
				Vector2(sx + 6, floor_y - 13), Vector2(sx + 15, floor_y)]), Color("1b2233"))
			c.draw_line(Vector2(sx - 9, floor_y - 10), Vector2(sx + 6, floor_y - 13), Color(0.45, 0.55, 0.75, 0.6), 1.0)
		x += rng.randf_range(80, 180)


func _paint_ground(c: CanvasItem) -> void:
	var w := arena_w + 200.0
	c.draw_rect(Rect2(-100, floor_y, w, VIEW_H - floor_y + 40), Color("151a26"))
	c.draw_rect(Rect2(-100, floor_y, w, 3), Color("3a4458"))
	c.draw_rect(Rect2(-100, floor_y, w, 1), Color("7a8aa8"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# 鹅卵石
	for row in range(4):
		var y := floor_y + 6 + row * 11
		var shade := 1.0 - row * 0.2
		for i in range(int(w / 18.0)):
			var x := -100 + i * 18 + rng.randi_range(0, 10)
			var col := Color("262d3d").lerp(Color("343c50"), rng.randf()) * Color(shade, shade, shade)
			var sw := rng.randi_range(4, 9)
			c.draw_rect(Rect2(x, y + rng.randi_range(-2, 2), sw, 4), col)
			c.draw_rect(Rect2(x + 1, y - 1 + rng.randi_range(-2, 2), sw - 2, 1), col.lightened(0.2))
	for i in range(int(w / 7.0)):
		var x := rng.randi_range(-100, int(arena_w + 100))
		c.draw_line(Vector2(x, floor_y + 1), Vector2(x + rng.randi_range(-2, 2), floor_y - rng.randi_range(2, 6)), Color("2c4a4a"), 1.0)


func _paint_motes(c: CanvasItem) -> void:
	for f in _motes:
		var b := 0.5 + 0.5 * sin(f.z * 3.0)
		var p := Vector2(f.x, f.y).round()
		c.draw_circle(p, 3.0, Color(0.2, 0.35, 0.55, 0.15 * b))
		c.draw_rect(Rect2(p, Vector2(1, 1)), Color(0.7, 0.9, 1.0, b))


func _paint_leaves(c: CanvasItem) -> void:
	for l in _leaves:
		var col := Color("5a7a4a") if int(l.z * 2.0) % 2 == 0 else Color("3e5a38")
		c.draw_rect(Rect2(Vector2(l.x, l.y).round(), Vector2(2 + int(sin(l.z) > 0.0), 1)), col)


func _paint_mist(c: CanvasItem) -> void:
	for i in range(3):
		var x := fmod(time * (5.0 + i * 3.0), 300.0) - 300.0
		while x < arena_w + 100.0:
			c.draw_rect(Rect2(x, floor_y - 7 - i * 4, 190, 6 + i * 2), Color(0.5, 0.6, 0.85, 0.05))
			x += 300.0


func _paint_willow(c: CanvasItem) -> void:
	# 头顶垂下来的柳条，随风摆
	var col := Color("05080e")
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var x := -40.0
	while x < span(1.3) + 200.0:
		c.draw_line(Vector2(x - 30, -2), Vector2(x + 60, 8), col, 4.0)
		for k in range(16):
			var sx := x - 20 + k * 6.0 + rng.randf_range(-2, 2)
			var len := rng.randf_range(30, 110)
			var pts := PackedVector2Array()
			for s in range(8):
				var t := float(s) / 7.0
				var sway := sin(time * 1.1 + sx * 0.07 + t * 1.5) * 6.0 * t
				pts.append(Vector2(sx + sway, 4 + t * len).round())
			c.draw_polyline(pts, col, 1.0)
			for s in range(1, 8, 2):
				c.draw_rect(Rect2(pts[s] + Vector2(-1, 0), Vector2(3, 2)), col)
		# 前景的芦苇
		for i in range(8):
			var gx := x + 120 + rng.randf_range(-30, 30)
			var h := rng.randf_range(20, 44)
			c.draw_colored_polygon(PackedVector2Array([Vector2(gx - 2, VIEW_H), Vector2(gx + 2, VIEW_H),
				Vector2(gx + sin(time + gx) * 3.0, VIEW_H - h)]), col)
		x += rng.randf_range(420, 640)
