class_name Background
extends Node2D
## 夜晚山寺场景：渐变夜空、月亮、远山、塔、竹林、石板地面，飘落的樱花。

const W := 640.0
const H := 360.0

var floor_y := 300.0
var _petals: Array[Vector3] = []   # x, y, 相位
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in range(28):
		_petals.append(Vector3(_rng.randf() * W, _rng.randf() * floor_y, _rng.randf() * TAU))


func _process(delta: float) -> void:
	for i in range(_petals.size()):
		var p := _petals[i]
		p.z += delta * 2.0
		p.x += (14.0 + sin(p.z) * 12.0) * delta
		p.y += 18.0 * delta
		if p.y > floor_y or p.x > W + 4:
			p = Vector3(_rng.randf() * W - 60.0, -4.0, _rng.randf() * TAU)
		_petals[i] = p
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_moon(Vector2(500, 78))
	_draw_mountains()
	_draw_pagoda(Vector2(118, 236))
	_draw_bamboo()
	_draw_ground()
	for p in _petals:
		var c := Color("f2a7c3") if int(p.z * 3.0) % 2 == 0 else Color("e57fa6")
		draw_rect(Rect2(Vector2(p.x, p.y).round(), Vector2(2, 1 + int(sin(p.z) > 0.0))), c)


func _draw_sky() -> void:
	var bands := [Color("0d0b1e"), Color("140f2b"), Color("1c1438"), Color("261a44"), Color("33204d"), Color("422752")]
	var band_h := floor_y / bands.size()
	for i in range(bands.size()):
		var c: Color = bands[i]
		draw_rect(Rect2(0, i * band_h, W, band_h + 1), c)
		# 抖动过渡：相邻两色之间点阵交错
		if i + 1 < bands.size():
			var nc: Color = bands[i + 1]
			var y0 := (i + 1) * band_h - 4
			for y in range(int(y0), int(y0) + 4, 2):
				for x in range((y / 2) % 2 * 2, int(W), 4):
					draw_rect(Rect2(x, y, 2, 2), nc)
	# 星星
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in range(70):
		var pos := Vector2(rng.randi_range(0, int(W)), rng.randi_range(0, 170))
		var b := rng.randf_range(0.4, 1.0)
		draw_rect(Rect2(pos, Vector2(1, 1)), Color(1, 1, 0.9, b))


func _draw_moon(c: Vector2) -> void:
	draw_circle(c, 36, Color(0.95, 0.85, 0.7, 0.06))
	draw_circle(c, 30, Color(0.95, 0.85, 0.7, 0.08))
	draw_circle(c, 24, Color("efe3c4"))
	draw_circle(c + Vector2(-7, -5), 5, Color("dccfae"))
	draw_circle(c + Vector2(8, 6), 4, Color("dccfae"))
	draw_circle(c + Vector2(-2, 10), 3, Color("dccfae"))


func _draw_mountains() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 220), Vector2(70, 160), Vector2(130, 196), Vector2(220, 128), Vector2(300, 190),
		Vector2(380, 150), Vector2(460, 205), Vector2(560, 140), Vector2(640, 190),
		Vector2(640, floor_y), Vector2(0, floor_y),
	]), Color("2a1d42"))
	# 山顶积雪的亮边
	draw_polyline(PackedVector2Array([
		Vector2(200, 143), Vector2(220, 128), Vector2(240, 143)]), Color("4b3a6b"), 2.0)
	draw_polyline(PackedVector2Array([
		Vector2(545, 151), Vector2(560, 140), Vector2(577, 152)]), Color("4b3a6b"), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 250), Vector2(90, 214), Vector2(190, 240), Vector2(290, 206), Vector2(400, 244),
		Vector2(520, 212), Vector2(640, 238), Vector2(640, floor_y), Vector2(0, floor_y),
	]), Color("1f1633"))


func _draw_pagoda(base: Vector2) -> void:
	var col := Color("140e22")
	var w := 34.0
	var y := base.y
	for i in range(4):
		# 屋檐
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - w / 2.0 - 8, y), Vector2(base.x + w / 2.0 + 8, y),
			Vector2(base.x + w / 2.0 - 2, y - 6), Vector2(base.x - w / 2.0 + 2, y - 6),
		]), col)
		draw_rect(Rect2(base.x - w / 2.0 + 4, y - 18, w - 8, 12), col)
		# 窗户的灯光
		if i % 2 == 0:
			draw_rect(Rect2(base.x - 2, y - 14, 4, 4), Color("e0a050"))
		y -= 18
		w -= 6
	draw_line(Vector2(base.x, y - 6), Vector2(base.x, y - 22), col, 2.0)
	# 石台
	draw_rect(Rect2(base.x - 26, base.y, 52, floor_y - base.y), col)
	draw_rect(Rect2(base.x - 30, base.y, 60, 3), col.lightened(0.08))


func _draw_bamboo() -> void:
	var stalks := [8.0, 22.0, 34.0, 598.0, 612.0, 628.0]
	for i in range(stalks.size()):
		var x: float = stalks[i]
		var col := Color("1d3a2c") if i % 2 == 0 else Color("244a37")
		draw_rect(Rect2(x, 0, 5, floor_y), col)
		for y in range(20 + i * 7, int(floor_y), 34):
			draw_rect(Rect2(x - 1, y, 7, 2), col.lightened(0.15))
			var side := -1.0 if (y / 34 + i) % 2 == 0 else 1.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + 2.5, y), Vector2(x + 2.5 + side * 16, y - 6), Vector2(x + 2.5 + side * 14, y - 2),
			]), col.lightened(0.05))


func _draw_ground() -> void:
	draw_rect(Rect2(0, floor_y, W, H - floor_y), Color("2b2230"))
	# 石板
	for row in range(3):
		var y := floor_y + 3 + row * 10
		var off := 0 if row % 2 == 0 else 14
		for x in range(-off, int(W), 28):
			var shade := 0.0 if (x / 28 + row) % 3 else 0.06
			draw_rect(Rect2(x + 1, y, 26, 8), Color("3d3243").lightened(shade))
	# 草边
	draw_rect(Rect2(0, floor_y, W, 3), Color("2e4a35"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(90):
		var x := rng.randi_range(0, int(W))
		var h := rng.randi_range(1, 4)
		draw_rect(Rect2(x, floor_y - h, 1, h), Color("3f6a47"))
