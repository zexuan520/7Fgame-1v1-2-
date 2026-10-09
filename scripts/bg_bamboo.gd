class_name BgBamboo
extends Background
## 第二层“竹林古寺”：远山、竹海里露出来的塔和大殿屋顶、近处成片的竹子和石灯笼、石板山道。
## 东西按房间宽度一路铺过去（长房间不会露空），位置由 seed_value 决定。
## mood：mist 晨雾 / dusk 暮钟 / night 寺夜

var mood := "mist"

const MOODS := {
	"mist": {"sky": ["9aa8a0", "b4beb2", "c8ccbc", "d8d4c0"], "orb": Color(1.0, 0.98, 0.9, 0.5), "orb_pos": Vector2(470, 70),
		"orb_r": 22.0, "stars": 0.0, "mtn": ["7c8a84", "64746e", "4e5e58"], "temple": "3e4a44", "temple_lit": "5e6e64",
		"window": Color(0.95, 0.75, 0.45, 0.35), "bamboo": ["2a3e30", "34503a", "40603f"], "bamboo_hl": "6a8e5e",
		"leaf": "466a44", "ground": "2a2e2a", "ground_top": "4a5248", "ground_lip": "8a9480", "stone": ["3a403a", "444a42"],
		"moss": ["4a6a3e", "5e8448"], "fog": Color(0.85, 0.9, 0.85, 0.12), "glow": Color(0.5, 0.35, 0.1, 0.05),
		"front": "1a221c", "fall": Color("6a8e4e")},
	"dusk": {"sky": ["2a1a30", "5a2a3a", "a04a3a", "e08a4a"], "orb": Color(1.0, 0.7, 0.35, 0.6), "orb_pos": Vector2(420, 150),
		"orb_r": 26.0, "stars": 0.0, "mtn": ["5a2e3a", "3e2030", "2a1624"], "temple": "1e1220", "temple_lit": "6a3424",
		"window": Color(1.0, 0.65, 0.3, 0.6), "bamboo": ["16141a", "1e1a20", "282028"], "bamboo_hl": "7a4a30",
		"leaf": "2a2228", "ground": "1a1214", "ground_top": "3e2a24", "ground_lip": "a0603a", "stone": ["2e2224", "38282a"],
		"moss": ["4a4a2a", "6a5a30"], "fog": Color(0.9, 0.5, 0.3, 0.06), "glow": Color(0.5, 0.25, 0.06, 0.07),
		"front": "0a0608", "fall": Color("c06a3a")},
	"night": {"sky": ["06081a", "0e1430", "1a2244", "2a3258"], "orb": Color(0.85, 0.9, 1.0, 0.7), "orb_pos": Vector2(500, 64),
		"orb_r": 16.0, "stars": 1.0, "mtn": ["1e2440", "161a30", "0e1222"], "temple": "0c0e1a", "temple_lit": "2e3456",
		"window": Color(1.0, 0.7, 0.35, 0.7), "bamboo": ["0e1a16", "12221c", "182c22"], "bamboo_hl": "3a5a4a",
		"leaf": "142420", "ground": "12141c", "ground_top": "2a2e40", "ground_lip": "5a6488", "stone": ["22263a", "2a2e44"],
		"moss": ["2a4a3a", "3a5e48"], "fog": Color(0.5, 0.6, 0.9, 0.06), "glow": Color(0.45, 0.22, 0.05, 0.09),
		"front": "04060a", "fall": Color("3a5a4a")},
}

var P: Dictionary
var _temples: Array = []     # 远处的塔、殿：[x, 种类 0 塔 1 殿 2 钟楼, 大小]
var _stalks: Array = []      # 近处竹子：[x, 粗细, 种子]
var _lamps: Array = []       # 石灯笼 x
var _leaves: Array[Vector3] = []


func _build() -> void:
	P = MOODS.get(mood, MOODS["mist"])
	_rng.seed = 900 + seed_value
	var x := -60.0
	while x < span(0.3) + 60.0:
		_temples.append([x + _rng.randf_range(0, 120), _rng.randi_range(0, 2), _rng.randf_range(0.8, 1.2)])
		x += _rng.randf_range(300, 460)
	x = -20.0
	while x < span(0.6) + 40.0:
		var n := _rng.randi_range(2, 5)
		for i in range(n):
			_stalks.append([x + i * _rng.randf_range(9, 15), _rng.randi_range(4, 7), _rng.randi()])
		x += _rng.randf_range(110, 220)
	x = 120.0 + _rng.randf_range(0, 120)
	while x < arena_w - 60.0:
		_lamps.append(x)
		x += _rng.randf_range(420, 620)
	for i in range(24):
		_leaves.append(Vector3(_rng.randf() * arena_w, _rng.randf() * floor_y, _rng.randf() * TAU))
	for i in range(10):
		_flies.append(Vector3(_rng.randf() * arena_w, floor_y - 20.0 - _rng.randf() * 90.0, _rng.randf() * TAU))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer(0.0, _paint_sky2)
	_add_layer(0.0, _paint_orb, add)
	_add_layer(0.1, _paint_ridges)
	_add_layer(0.3, _paint_temples)
	_add_layer(0.3, _paint_mist_band)
	_add_layer(0.6, _paint_grove)
	_add_layer(0.6, _paint_lamp_glow, add)
	_add_layer(1.0, _paint_path)


func _build_front() -> Array[Layer]:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if mood == "night":
		_front.append(_new_layer(1.0, _paint_fireflies, add))
	_front.append(_new_layer(1.0, _paint_leaves))
	_front.append(_new_layer(1.0, _paint_low_fog))
	_front.append(_new_layer(1.3, _paint_front_stalks))
	return _front


func _tick(delta: float) -> void:
	for i in range(_leaves.size()):
		var p := _leaves[i]
		p.z += delta * 1.6
		p.x += (-10.0 + sin(p.z) * 18.0) * delta
		p.y += 16.0 * delta
		if p.y > floor_y + 8.0:
			p = Vector3(_rng.randf() * arena_w, -6.0, _rng.randf() * TAU)
		_leaves[i] = p
	for i in range(_flies.size()):
		var f := _flies[i]
		f.z += delta
		f.x += sin(f.z * 0.7) * 10.0 * delta
		f.y += cos(f.z * 0.9) * 6.0 * delta
		_flies[i] = f


func _col(k: String, i: int = -1) -> Color:
	var v: Variant = P[k]
	if v is Array:
		return Color(v[clampi(i, 0, (v as Array).size() - 1)])
	if v is Color:
		return v
	return Color(v)


func _paint_sky2(c: CanvasItem) -> void:
	var bands: Array = P["sky"]
	var h := floor_y / float(bands.size())
	for i in range(bands.size()):
		c.draw_rect(Rect2(0, i * h, VIEW_W, h + 1), Color(bands[i]))
	if float(P["stars"]) > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in range(70):
			var p := Vector2(rng.randf() * VIEW_W, rng.randf() * floor_y * 0.6).round()
			var tw := 0.5 + 0.5 * sin(time * 2.0 + i)
			c.draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, 0.35 + 0.4 * tw))


func _paint_orb(c: CanvasItem) -> void:
	var at: Vector2 = P["orb_pos"]
	var col: Color = P["orb"]
	for i in range(8):
		c.draw_circle(at, float(P["orb_r"]) + i * 10.0, Color(col, col.a * 0.08))
	c.draw_circle(at, float(P["orb_r"]), Color(col, minf(1.0, col.a + 0.3)))


## 远山：三层山脊，越远越淡
func _paint_ridges(c: CanvasItem) -> void:
	var w := span(0.1)
	for layer in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + layer + seed_value
		var pts := PackedVector2Array([Vector2(-20, floor_y)])
		var x := -20.0
		var base := floor_y - 120.0 + layer * 34.0
		while x < w + 40.0:
			pts.append(Vector2(x, base - rng.randf_range(0, 70 - layer * 15)))
			x += rng.randf_range(40, 90)
		pts.append(Vector2(w + 40.0, floor_y))
		c.draw_colored_polygon(pts, _col("mtn", layer))


## 竹海里露出来的塔、大殿、钟楼屋顶
func _paint_temples(c: CanvasItem) -> void:
	var col := _col("temple")
	var lit := _col("temple_lit")
	var win: Color = P["window"]
	for t: Array in _temples:
		var x: float = t[0]
		var s: float = t[2]
		var ground := floor_y - 30.0
		match int(t[1]):
			0:
				var y := ground
				var w := 40.0 * s
				for i in range(5):
					_roof(c, Vector2(x, y), w + 14.0, col, lit)
					c.draw_rect(Rect2(x - w / 2.0 + 5, y - 15, w - 10, 11), col)
					if i < 4:
						c.draw_rect(Rect2(x - 2, y - 12, 4, 5), Color(win, win.a * (0.7 + 0.3 * sin(time * 2.0 + i + x))))
					y -= 17.0 * s
					w -= 6.0 * s
				c.draw_line(Vector2(x, y), Vector2(x, y - 18), col, 2.0)
				c.draw_rect(Rect2(x - 24 * s, ground, 48 * s, 30), col)
			1:
				var hw := 70.0 * s
				_roof(c, Vector2(x, ground - 28.0 * s), hw * 2.0 + 20.0, col, lit)
				_roof(c, Vector2(x, ground - 52.0 * s), hw * 1.2, col, lit)
				c.draw_rect(Rect2(x - hw * 0.5, ground - 52.0 * s, hw, 24.0 * s), col)
				c.draw_rect(Rect2(x - hw, ground - 28.0 * s, hw * 2.0, 58.0 * s), col)
				for i in range(4):
					c.draw_rect(Rect2(x - hw + 14 + i * (hw * 2.0 - 28) / 3.0 - 5, ground - 18.0 * s, 10, 14), Color(win, win.a * 0.8))
			2:
				# 钟楼：四根柱子，吊一口钟
				var hw2 := 24.0 * s
				_roof(c, Vector2(x, ground - 50.0 * s), hw2 * 2.0 + 16.0, col, lit)
				for k in [-1.0, 1.0]:
					c.draw_rect(Rect2(x + k * hw2 - 2, ground - 50.0 * s, 4, 80.0 * s), col)
				var swing := sin(time * 0.8 + x) * 1.5
				c.draw_circle(Vector2(x + swing, ground - 30.0 * s), 8.0 * s, col)
				c.draw_rect(Rect2(x - 8 * s + swing, ground - 30.0 * s, 16 * s, 10 * s), col)


func _paint_mist_band(c: CanvasItem) -> void:
	var fog: Color = P["fog"]
	var w := span(0.3)
	for i in range(3):
		var y := floor_y - 40.0 - i * 18.0
		c.draw_rect(Rect2(-20, y, w + 40, 16 + i * 6), Color(fog, fog.a * (1.4 - i * 0.35)))


## 近处的竹林：一丛一丛，竹节、叶子，再加几座石灯笼
func _paint_grove(c: CanvasItem) -> void:
	var hl := _col("bamboo_hl")
	for i in range(_stalks.size()):
		var s: Array = _stalks[i]
		var x: float = s[0]
		var w: int = s[1]
		var col := _col("bamboo", i % 3)
		c.draw_rect(Rect2(x, 0, w, floor_y), col)
		c.draw_rect(Rect2(x + w - 2, 0, 1, floor_y), hl)
		var seed_v: int = s[2]
		var y := 10 + seed_v % 30
		while y < floor_y - 10:
			c.draw_rect(Rect2(x - 1, y, w + 2, 2), col.lightened(0.12))
			if (y / 31 + i) % 3 == 0:
				var side := -1.0 if (seed_v + y) % 2 == 0 else 1.0
				var lc := _col("leaf")
				c.draw_colored_polygon(PackedVector2Array([Vector2(x + w / 2.0, y), Vector2(x + w / 2.0 + side * 22, y - 8),
					Vector2(x + w / 2.0 + side * 18, y - 2)]), lc)
				c.draw_colored_polygon(PackedVector2Array([Vector2(x + w / 2.0, y + 3), Vector2(x + w / 2.0 + side * 16, y + 9),
					Vector2(x + w / 2.0 + side * 13, y + 4)]), lc)
			y += 31
	for lx: float in _lamps:
		_stone_lantern(c, Vector2(lx, floor_y))


func _paint_lamp_glow(c: CanvasItem) -> void:
	var g: Color = P["glow"]
	for lx: float in _lamps:
		var flick := 0.85 + 0.15 * sin(time * 13.0 + lx) * sin(time * 7.0)
		for i in range(5):
			c.draw_circle(Vector2(lx, floor_y - 36), 8.0 + i * 9.0, Color(g, g.a * 1.6 * flick))


## 石板山道，缝里长着青苔
func _paint_path(c: CanvasItem) -> void:
	var w := arena_w + 200.0
	c.draw_rect(Rect2(-100, floor_y, w, VIEW_H - floor_y + 40), _col("ground"))
	c.draw_rect(Rect2(-100, floor_y, w, 4), _col("ground_top"))
	c.draw_rect(Rect2(-100, floor_y, w, 1), _col("ground_lip"))
	for row in range(4):
		var y := floor_y + 5 + row * 11
		var off := 0 if row % 2 == 0 else 22
		var shade := 1.0 - row * 0.18
		for x in range(-100 - off, int(arena_w + 100), 44):
			var v := posmod((x / 44) * 5 + row * 3, 4)
			var col := _col("stone", 0).lerp(_col("stone", 1), v / 4.0) * Color(shade, shade, shade)
			c.draw_rect(Rect2(x + 1, y, 42, 9), col)
			c.draw_rect(Rect2(x + 1, y, 42, 1), col.lightened(0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 17 + seed_value
	for i in range(int(arena_w / 6.0)):
		var x := rng.randi_range(-100, int(arena_w + 100))
		var h := rng.randi_range(2, 5)
		c.draw_rect(Rect2(x, floor_y - h + 1, 1, h), _col("moss", i % 2))


func _paint_leaves(c: CanvasItem) -> void:
	var col: Color = P["fall"]
	for p in _leaves:
		var flip := sin(p.z) > 0.0
		c.draw_rect(Rect2(Vector2(p.x, p.y).round(), Vector2(3 if flip else 1, 1)), col)


func _paint_low_fog(c: CanvasItem) -> void:
	var fog: Color = P["fog"]
	for i in range(3):
		var x := fmod(time * (5.0 + i * 3.0), 320.0) - 320.0
		while x < arena_w + 100.0:
			c.draw_rect(Rect2(x, floor_y - 8 - i * 5, 200, 8 + i * 2), Color(fog, fog.a * 0.8))
			x += 320.0


## 画面最前面偶尔一根黑竹子挡一下
func _paint_front_stalks(c: CanvasItem) -> void:
	var col := _col("front")
	var rng := RandomNumberGenerator.new()
	rng.seed = 61 + seed_value
	var x := rng.randf_range(100, 300)
	while x < span(1.3):
		c.draw_rect(Rect2(x, 0, 10, VIEW_H), col)
		for y in range(20, int(VIEW_H), 46):
			c.draw_rect(Rect2(x - 1, y, 12, 2), col.lightened(0.05))
		x += rng.randf_range(700, 1100)
