class_name BgVillage
extends Background
## 山脚荒村，黄昏。夕阳压在山口，远处的屋子在烧，烟往上飘，乌鸦绕着枯树飞。
## 光从左边来（夕阳），屋子、树的左边缘描一道暖色轮廓光。

const SUN := Vector2(150, 196)

var _embers: Array[Vector3] = []
var _ash: Array[Vector3] = []
var _crows: Array[Vector3] = []
var _houses_far: Array = []          # [x, 宽, 高, 是否破]
var _houses_near: Array = []         # [x, 宽, 高, 是否破, 是否着火]
var _trees: Array = []               # [x, 高, 种子]
var _fires: Array[float] = []        # 远处着火的屋子（冒烟的位置）


func _build() -> void:
	_rng.seed = 100 + seed_value
	var far_w := span(0.3)
	var x := -40.0 + _rng.randf_range(0, 60)
	while x < far_w:
		var w := _rng.randf_range(34, 62)
		var broken := _rng.randf() < 0.35
		_houses_far.append([x, w, _rng.randf_range(20, 34), broken])
		if broken and _rng.randf() < 0.6:
			_fires.append(x + w * 0.5)
		x += w + _rng.randf_range(10, 90)
	var near_w := span(0.6)
	x = 30.0 + _rng.randf_range(0, 80)
	while x < near_w:
		var w := _rng.randf_range(70, 110)
		_houses_near.append([x, w, _rng.randf_range(38, 52), _rng.randf() < 0.4, _rng.randf() < 0.3])
		x += w + _rng.randf_range(120, 260)
	x = _rng.randf_range(60, 200)
	while x < near_w:
		_trees.append([x, _rng.randf_range(70, 110), _rng.randi()])
		x += _rng.randf_range(260, 480)
	if _fires.is_empty():
		_fires.append(far_w * 0.6)
	for i in range(40):
		_embers.append(Vector3(_rng.randf() * arena_w, _rng.randf() * floor_y, _rng.randf() * TAU))
	for i in range(30):
		_ash.append(Vector3(_rng.randf() * arena_w, _rng.randf() * floor_y, _rng.randf() * TAU))
	for i in range(7):
		_crows.append(Vector3(_rng.randf() * far_w, 60.0 + _rng.randf() * 70.0, _rng.randf() * TAU))

	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer(0.0, _paint_sky)
	_add_layer(0.0, _paint_sun_glow, add)
	_add_layer(0.05, _paint_clouds)
	_add_layer(0.12, _paint_mountains)
	_add_layer(0.25, _paint_smoke)
	_add_layer(0.3, _paint_far_village)
	_add_layer(0.3, _paint_crows)
	_add_layer(0.3, _paint_far_fire, add)
	_add_layer(0.6, _paint_near)
	_add_layer(0.6, _paint_near_glow, add)
	_add_layer(1.0, _paint_ground)


func _build_front() -> Array[Layer]:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front.append(_new_layer(1.0, _paint_embers, add))
	_front.append(_new_layer(1.0, _paint_ash))
	_front.append(_new_layer(1.0, _paint_haze))
	_front.append(_new_layer(1.3, _paint_front))
	return _front


func _tick(delta: float) -> void:
	for i in range(_embers.size()):
		var e := _embers[i]
		e.z += delta * 3.0
		e.x += sin(e.z) * 10.0 * delta + 8.0 * delta
		e.y -= (18.0 + fmod(float(i) * 7.0, 16.0)) * delta
		if e.y < 20.0:
			e = Vector3(_rng.randf() * arena_w, floor_y + 4.0, _rng.randf() * TAU)
		_embers[i] = e
	for i in range(_ash.size()):
		var a := _ash[i]
		a.z += delta * 1.5
		a.x += (10.0 + sin(a.z) * 12.0) * delta
		a.y += 12.0 * delta
		if a.y > floor_y + 8.0 or a.x > arena_w + 20.0:
			a = Vector3(_rng.randf() * arena_w - 60.0, -4.0, _rng.randf() * TAU)
		_ash[i] = a
	for i in range(_crows.size()):
		var cr := _crows[i]
		cr.z += delta
		_crows[i] = cr


# ---------- 天空 ----------

func _paint_sky(c: CanvasItem) -> void:
	var stops := [Color("140c26"), Color("3a1a40"), Color("7a2c45"), Color("c4513a"), Color("eb9a4e")]
	var steps := 30
	var band := floor_y / steps
	for i in range(steps):
		var t := float(i) / (steps - 1) * (stops.size() - 1)
		var k := mini(int(t), stops.size() - 2)
		var col: Color = (stops[k] as Color).lerp(stops[k + 1], t - k)
		c.draw_rect(Rect2(0, roundf(i * band), VIEW_W + 200, ceilf(band) + 1), col)
	# 最早出来的几颗星
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in range(26):
		var pos := Vector2(rng.randi_range(0, int(VIEW_W)), rng.randi_range(0, 70))
		var b := rng.randf_range(0.2, 0.7) * (0.6 + 0.4 * sin(time * rng.randf_range(1.0, 3.0) + i))
		c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(1.0, 0.9, 0.85, b))
	# 夕阳：一圈圈往里变亮，下半截被山挡住
	c.draw_circle(SUN, 30, Color("f2a24e"))
	c.draw_circle(SUN, 26, Color("f7c06a"))
	c.draw_circle(SUN, 21, Color("fde3a0"))
	# 横穿太阳的细云
	for k in range(3):
		var y := SUN.y - 14.0 + k * 9.0
		c.draw_rect(Rect2(SUN.x - 46 + k * 9, y, 70 - k * 12, 2), Color("8a3a40"))


func _paint_sun_glow(c: CanvasItem) -> void:
	for i in range(12):
		c.draw_circle(SUN, 32.0 + i * 9.0, Color(0.42, 0.18, 0.06, 0.05))
	# 地平线上的一道亮带
	c.draw_rect(Rect2(0, 236, VIEW_W + 200, 26), Color(0.35, 0.14, 0.04, 0.18))


func _paint_clouds(c: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51 + seed_value
	var w := span(0.05)
	for i in range(9):
		var y := rng.randf_range(40, 170)
		var x := fmod(rng.randf_range(0, w) + time * rng.randf_range(1.0, 3.0), w + 160.0) - 120.0
		var len := rng.randf_range(80, 170)
		var col := Color("5a2440") if y < 120 else Color("8e3a3e")
		c.draw_rect(Rect2(roundf(x), roundf(y), len, 3), col)
		c.draw_rect(Rect2(roundf(x + 14), roundf(y - 2), len * 0.55, 2), col)
		c.draw_rect(Rect2(roundf(x + 10), roundf(y + 3), len * 0.7, 1), Color(col.lightened(0.25), 0.8))


func _paint_mountains(c: CanvasItem) -> void:
	var w := span(0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61 + seed_value
	# 远山两层：越远越偏紫、越亮
	for layer in range(2):
		var pts := PackedVector2Array()
		var base := 230.0 + layer * 18.0
		var col := Color("4a2240") if layer == 0 else Color("2c1530")
		var x := -20.0
		pts.append(Vector2(x, floor_y))
		while x < w + 40.0:
			pts.append(Vector2(x, base - rng.randf_range(10, 60 - layer * 18)))
			x += rng.randf_range(40, 90)
		pts.append(Vector2(x, floor_y))
		c.draw_colored_polygon(pts, col)
		# 朝夕阳的一侧描亮边
		for i in range(1, pts.size() - 2):
			if pts[i].y < pts[i + 1].y:
				continue
			c.draw_line(pts[i - 1] if pts[i - 1].y > pts[i].y else pts[i], pts[i], Color(0.85, 0.4, 0.3, 0.5 - layer * 0.25), 1.0)
		# 山脚的雾
		for k in range(5):
			c.draw_rect(Rect2(0, base - 4 + k * 5, w, 5), Color(0.75, 0.32, 0.3, 0.05))


func _paint_smoke(c: CanvasItem) -> void:
	# 着火的屋子冒出的烟柱，往右上方飘散
	for f in _fires:
		var fx: float = f * (0.25 / 0.3)
		for i in range(18):
			var t := fmod(time * 0.18 + i / 18.0, 1.0)
			var p := Vector2(fx + t * t * 60.0 + sin(t * 6.0 + i) * 4.0, 262.0 - t * 200.0)
			var r := 5.0 + t * 22.0
			c.draw_circle(p.round(), r, Color(0.14, 0.08, 0.12, 0.28 * (1.0 - t)))


func _paint_far_village(c: CanvasItem) -> void:
	var col := Color("26142a")
	var lit := Color("6e2c38")
	var ground := 270.0
	c.draw_rect(Rect2(-20, ground, span(0.3) + 40, floor_y - ground), col)
	for h in _houses_far:
		var x: float = h[0]
		var w: float = h[1]
		var ht: float = h[2]
		c.draw_rect(Rect2(x + 4, ground - ht, w - 8, ht), col)
		var roof := PackedVector2Array([Vector2(x - 4, ground - ht + 2), Vector2(x + w * 0.5, ground - ht - 16),
			Vector2(x + w + 4, ground - ht + 2)])
		if h[3]:
			# 塌了一半的屋顶
			roof = PackedVector2Array([Vector2(x - 4, ground - ht + 2), Vector2(x + w * 0.35, ground - ht - 12),
				Vector2(x + w * 0.5, ground - ht - 4), Vector2(x + w * 0.62, ground - ht - 9), Vector2(x + w + 4, ground - ht + 2)])
		c.draw_colored_polygon(roof, col)
		c.draw_line(roof[0], roof[1], lit, 1.0)
	# 望楼
	var tx := span(0.3) * 0.45
	c.draw_rect(Rect2(tx - 2, ground - 64, 2, 64), col)
	c.draw_rect(Rect2(tx + 14, ground - 64, 2, 64), col)
	c.draw_line(Vector2(tx, ground - 10), Vector2(tx + 14, ground - 40), col, 1.0)
	c.draw_line(Vector2(tx + 14, ground - 10), Vector2(tx, ground - 40), col, 1.0)
	c.draw_rect(Rect2(tx - 5, ground - 72, 24, 10), col)
	c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 8, ground - 72), Vector2(tx + 7, ground - 82), Vector2(tx + 22, ground - 72)]), col)
	c.draw_line(Vector2(tx - 8, ground - 72), Vector2(tx + 7, ground - 82), lit, 1.0)


func _paint_far_fire(c: CanvasItem) -> void:
	for f in _fires:
		var p := Vector2(f, 262)
		var flick := 0.75 + 0.25 * sin(time * 9.0 + f) * sin(time * 5.3)
		for i in range(4):
			c.draw_circle(p, 6.0 + i * 7.0, Color(0.5, 0.18, 0.04, 0.12 * flick))
		c.draw_rect(Rect2(p.x - 3, p.y - 4, 6, 4), Color(1.0, 0.55, 0.15, flick))


func _paint_crows(c: CanvasItem) -> void:
	var col := Color("140a14")
	for i in range(_crows.size()):
		var cr := _crows[i]
		var center := Vector2(cr.x, cr.y)
		var p := center + Vector2(cos(cr.z * 0.5 + i), sin(cr.z * 0.8 + i) * 0.4) * 30.0
		var flap := sin(cr.z * 9.0 + i) > 0.0
		p = p.round()
		c.draw_rect(Rect2(p, Vector2(2, 1)), col)
		if flap:
			c.draw_line(p, p + Vector2(-3, -2), col, 1.0)
			c.draw_line(p + Vector2(1, 0), p + Vector2(4, -2), col, 1.0)
		else:
			c.draw_line(p, p + Vector2(-3, 1), col, 1.0)
			c.draw_line(p + Vector2(1, 0), p + Vector2(4, 1), col, 1.0)


# ---------- 近处 ----------

func _paint_near(c: CanvasItem) -> void:
	for t in _trees:
		_dead_tree(c, Vector2(t[0], floor_y), t[1], t[2])
	for h in _houses_near:
		_house(c, h[0], floor_y, h[1], h[2], h[3], h[4])
	# 破篱笆
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + seed_value
	var x := rng.randf_range(0, 100)
	var w := span(0.6)
	while x < w:
		var n := rng.randi_range(3, 7)
		for k in range(n):
			var px := x + k * 9.0
			var ph := rng.randf_range(12, 20)
			var lean := rng.randf_range(-2, 2)
			c.draw_line(Vector2(px, floor_y), Vector2(px + lean, floor_y - ph), Color("2a1a22"), 2.0)
			c.draw_rect(Rect2(px + lean - 1, floor_y - ph, 1, 1), Color("8a4a3a"))
		c.draw_line(Vector2(x - 2, floor_y - 10), Vector2(x + n * 9.0 - 6.0, floor_y - 12), Color("2a1a22"), 1.0)
		x += n * 9.0 + rng.randf_range(160, 340)


func _house(c: CanvasItem, x: float, base: float, w: float, h: float, broken: bool, burning: bool) -> void:
	var wall := Color("2e1c26")
	var wall_lit := Color("4a2a2e")
	var beam := Color("1c1018")
	var roof := Color("3a2420")
	var roof_lit := Color("8a4a32")
	var rim := Color("c2633c")
	# 墙：木柱 + 土墙
	c.draw_rect(Rect2(x, base - h, w, h), wall)
	c.draw_rect(Rect2(x, base - h, 3, h), wall_lit)
	c.draw_rect(Rect2(x, base - h, 1, h), rim)
	for k in range(4):
		c.draw_rect(Rect2(x + roundf(w * k / 3.0) - 1, base - h, 3, h), beam)
	c.draw_rect(Rect2(x, base - h * 0.55, w, 2), beam)
	# 门洞和窗
	var door := Rect2(x + w * 0.38, base - h * 0.7, w * 0.2, h * 0.7)
	c.draw_rect(door, Color("0e070c"))
	var win := Rect2(x + w * 0.72, base - h * 0.85, 10, 8)
	if burning:
		var flick := 0.7 + 0.3 * sin(time * 11.0 + x) * sin(time * 6.0)
		c.draw_rect(win, Color(1.0, 0.55, 0.2, flick))
		c.draw_rect(Rect2(door.position + Vector2(0, door.size.y * 0.5), door.size * Vector2(1, 0.5)), Color(0.9, 0.35, 0.12, flick * 0.8))
	else:
		c.draw_rect(win, Color("0e070c"))
	c.draw_line(win.position + Vector2(5, 0), win.position + Vector2(5, 8), beam, 1.0)
	# 茅草屋顶，屋檐出挑
	var top := base - h
	var pts := PackedVector2Array([Vector2(x - 10, top + 4), Vector2(x + w * 0.5, top - 26), Vector2(x + w + 10, top + 4)])
	if broken:
		pts = PackedVector2Array([Vector2(x - 10, top + 4), Vector2(x + w * 0.3, top - 18), Vector2(x + w * 0.42, top - 8),
			Vector2(x + w * 0.55, top - 16), Vector2(x + w * 0.62, top - 4), Vector2(x + w + 10, top + 4)])
	c.draw_colored_polygon(pts, roof)
	# 草的纹理
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x)
	for k in range(int(w / 3.0)):
		var px := x - 6 + k * 3.0 + rng.randf_range(0, 2)
		var py := top + 2 - rng.randf_range(0, 12)
		if Geometry2D.is_point_in_polygon(Vector2(px, py), pts):
			c.draw_line(Vector2(px, py), Vector2(px + 1, py + 4), Color("2a1816"), 1.0)
	c.draw_line(pts[0], pts[1], roof_lit, 2.0)
	c.draw_line(pts[0] + Vector2(0, 1), pts[pts.size() - 1] + Vector2(0, 1), Color("1a0e10"), 2.0)
	if broken:
		# 露出来的房梁
		c.draw_line(Vector2(x + w * 0.42, top - 8), Vector2(x + w * 0.5, top - 26), beam, 2.0)
		c.draw_line(Vector2(x + w * 0.5, top - 26), Vector2(x + w * 0.58, top - 12), beam, 2.0)


func _dead_tree(c: CanvasItem, at: Vector2, h: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var col := Color("1e1018")
	c.draw_line(at, at + Vector2(2, -h * 0.5), col, 5.0)
	c.draw_line(at + Vector2(2, -h * 0.5), at + Vector2(-2, -h), col, 3.0)
	c.draw_line(at + Vector2(-2, 0), at + Vector2(-1, -h * 0.6), Color("7a3a30"), 1.0)
	_branch(c, at + Vector2(2, -h * 0.5), -0.6, h * 0.45, 3, rng, col)
	_branch(c, at + Vector2(0, -h * 0.75), 0.7, h * 0.4, 3, rng, col)
	_branch(c, at + Vector2(-2, -h), -0.1, h * 0.3, 2, rng, col)


func _branch(c: CanvasItem, from: Vector2, angle: float, length: float, depth: int, rng: RandomNumberGenerator, col: Color) -> void:
	if depth <= 0 or length < 4.0:
		return
	var to := from + Vector2(sin(angle), -cos(angle)) * length
	c.draw_line(from, to, col, maxf(1.0, depth * 0.8))
	_branch(c, to, angle + rng.randf_range(-0.7, -0.2), length * 0.6, depth - 1, rng, col)
	_branch(c, to, angle + rng.randf_range(0.2, 0.7), length * 0.55, depth - 1, rng, col)


func _paint_near_glow(c: CanvasItem) -> void:
	for h in _houses_near:
		if not h[4]:
			continue
		var x: float = h[0]
		var w: float = h[1]
		var flick := 0.8 + 0.2 * sin(time * 11.0 + x) * sin(time * 6.0)
		var p := Vector2(x + w * 0.6, floor_y - 24)
		for i in range(5):
			c.draw_circle(p, 10.0 + i * 10.0, Color(0.45, 0.16, 0.04, 0.08 * flick))


# ---------- 地面 ----------

func _paint_ground(c: CanvasItem) -> void:
	var w := arena_w + 200.0
	c.draw_rect(Rect2(-100, floor_y, w, VIEW_H - floor_y + 40), Color("1e1416"))
	# 土路：上沿被夕阳照亮
	c.draw_rect(Rect2(-100, floor_y, w, 3), Color("5a3a30"))
	c.draw_rect(Rect2(-100, floor_y, w, 1), Color("a8643e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 81 + seed_value
	# 车辙和石子
	for row in range(4):
		var y := floor_y + 6 + row * 10
		var shade := 1.0 - row * 0.2
		for i in range(int(w / 26.0)):
			var x := -100 + i * 26 + rng.randi_range(0, 18)
			var col := Color("3a2a28").lerp(Color("4a3430"), rng.randf()) * Color(shade, shade, shade)
			c.draw_rect(Rect2(x, y + rng.randi_range(-2, 2), rng.randi_range(3, 9), 2), col)
			if rng.randf() < 0.25:
				c.draw_rect(Rect2(x + 4, y - 3, 2, 1), col.lightened(0.2))
	c.draw_rect(Rect2(-100, floor_y + 12, w, 1), Color("140c0e"))
	c.draw_rect(Rect2(-100, floor_y + 26, w, 1), Color("140c0e"))
	# 枯草
	for i in range(int(w / 6.0)):
		var x := rng.randi_range(-100, int(arena_w + 100))
		var hh := rng.randi_range(2, 8)
		var g := Color("7a5a32") if i % 3 else Color("a87a40")
		c.draw_line(Vector2(x, floor_y + 1), Vector2(x + rng.randi_range(-2, 2), floor_y - hh), g, 1.0)


# ---------- 前景 ----------

func _paint_embers(c: CanvasItem) -> void:
	for e in _embers:
		var b := 0.5 + 0.5 * sin(e.z * 2.0)
		var p := Vector2(e.x, e.y).round()
		c.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.55, 0.2, b))
		c.draw_circle(p, 2.0, Color(0.5, 0.18, 0.05, 0.2 * b))


func _paint_ash(c: CanvasItem) -> void:
	for a in _ash:
		c.draw_rect(Rect2(Vector2(a.x, a.y).round(), Vector2(1 + int(sin(a.z) > 0.3), 1)), Color(0.55, 0.45, 0.45, 0.6))


func _paint_haze(c: CanvasItem) -> void:
	for i in range(3):
		var x := fmod(time * (5.0 + i * 3.0), 320.0) - 320.0
		while x < arena_w + 100.0:
			c.draw_rect(Rect2(x, floor_y - 8 - i * 5, 200, 7 + i * 2), Color(0.85, 0.45, 0.35, 0.045))
			x += 320.0


func _paint_front(c: CanvasItem) -> void:
	var col := Color("0a0608")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + seed_value
	var x := -40.0
	while x < span(1.3) + 200.0:
		for i in range(12):
			var gx := x + rng.randf_range(-40, 60)
			var h := rng.randf_range(12, 34)
			var lean := rng.randf_range(-9, 9)
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(gx - 3, VIEW_H), Vector2(gx + 3, VIEW_H), Vector2(gx + lean, VIEW_H - h),
			]), col)
		# 歪倒的篱笆桩
		if rng.randf() < 0.5:
			var px := x + rng.randf_range(0, 60)
			c.draw_line(Vector2(px, VIEW_H), Vector2(px + rng.randf_range(-10, 10), VIEW_H - rng.randf_range(40, 60)), col, 5.0)
		x += rng.randf_range(380, 620)
