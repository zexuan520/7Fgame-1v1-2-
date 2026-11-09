class_name Arena3
extends Arena
## 第三幕“出山”的三种场景（其余区域照旧交给 Arena）：
##   liuxi 柳溪村：黄昏的溪边村子。踩实的土路、横穿过去的小溪和石桥、两边的稻田；后面一排农舍、风车、水车，
##         家家门口挂着一盏灰纸灯（续命司“收村”的记号）。火师半血 ignite() 时整个村子烧起来
##   post  官道驿站：雨夜。中间一条积水的青石驿道和灯车车辙，两边泥地；驿站、马厩、驿亭、里程石，路边一排暖橙的灯笼，下着雨
##   palace 长明宫：白玉地砖金缝、中间一道红毯；两排朱漆金箍的柱子、长明灯架、铜鹤香炉；后面朱红金格的屏风，金殿上有御座

const ZONES3 := {
	"liuxi": {"bg": Color(0.09, 0.06, 0.07), "fog": Color(0.3, 0.17, 0.13), "fog_d": 0.5, "amb": Color(0.64, 0.52, 0.5), "amb_e": 1.35,
		"sun": Color(1.0, 0.7, 0.48), "sun_e": 1.35, "spore": Color(1.0, 0.78, 0.45), "foe_rim": Color(0.6, 0.92, 1.0), "foe_rim_k": 0.8},
	"post": {"bg": Color(0.03, 0.04, 0.06), "fog": Color(0.13, 0.16, 0.22), "fog_d": 0.6, "amb": Color(0.56, 0.6, 0.72), "amb_e": 1.55,
		"sun": Color(0.72, 0.8, 1.0), "sun_e": 1.2, "spore": Color(0.65, 0.78, 1.0)},
	"palace": {"bg": Color(0.07, 0.03, 0.03), "fog": Color(0.22, 0.1, 0.06), "fog_d": 0.45, "amb": Color(0.72, 0.58, 0.48), "amb_e": 1.45,
		"sun": Color(1.0, 0.85, 0.62), "sun_e": 1.25, "spore": Color(1.0, 0.82, 0.45), "foe_rim": Color(0.6, 0.92, 1.0), "foe_rim_k": 0.8},
}

var _houses: Array[Vector3] = []   # 柳溪村的屋子（ignite 时点着）


func zone_info() -> Dictionary:
	if ZONES3.has(zone):
		return ZONES3[zone]
	return super.zone_info()


func _dress_more() -> void:
	match zone:
		"liuxi":
			_dress_liuxi()
		"post":
			_dress_post()
		"palace":
			_dress_palace()


func _layout_back() -> float:
	return 7.5 if ZONES3.has(zone) else super._layout_back()


## 布局模板别压到小溪、驿道两边的灯笼和驿亭、宫里的两排柱子和香炉上
func _layout_ok(r: Rect2) -> bool:
	var c := r.get_center()
	match zone:
		"liuxi":
			return absf(c.y - _stream_z(c.x)) > 3.0 + r.size.y * 0.5
		"post":
			var road := 5.5 * _kx()
			if absf(absf(c.x) - (road + 1.0)) < 1.6 + r.size.x * 0.5:
				return false
			if absf(absf(c.x) - (road + 4.5)) < 2.8 + r.size.x * 0.5 and absf(c.y - 1.5 * _kz()) < 2.8 + r.size.y * 0.5:
				return false
		"palace":
			var cx := 7.5 * _kx()
			for x: float in [cx, cx + 4.0]:
				if absf(absf(c.x) - x) < 1.6 + r.size.x * 0.5:
					return false
	return true


## 头目房（48×36）：比战斗房小、比小房大
func _is_boss_room() -> bool:
	return size.x > 44.0 and size.x < 52.0


# ---------- 地面 ----------

## 柳溪村的小溪：z 方向的中心线（随 x 弯一点）
func _stream_z(x: float) -> float:
	return -size.y * 0.06 + sin(x * 0.14) * 1.8


func _floor_color(x: float, z: float) -> Color:
	_fc_grass = false
	var n := noise.get_noise_2d(x * 3.0, z * 3.0)
	var n2 := noise.get_noise_2d(x * 13.0 + 100.0, z * 13.0)
	# 每格一个哈希：零星的石子、花、颗粒深浅都从它派生（2026-11-08 地面重画加的）
	var h := fposmod(sin(x * 127.1 + z * 311.7) * 43758.5453, 1.0)
	var grain := 0.97 + fposmod(h * 7.31, 1.0) * 0.06
	match zone:
		"liuxi":
			# 踩实的黄土 + 中间一条村路；两边稻田（一垄一垄，田埂上长草）；一条小溪横穿，正中石桥，河滩上铺卵石
			var c := Color(0.36, 0.29, 0.21).lerp(Color(0.42, 0.34, 0.24), n * 0.5 + 0.5)
			var big := noise.get_noise_2d(x * 0.5 + 60.0, z * 0.5)
			if big > 0.25:
				_fc_grass = true
				c = c.lerp(Color(0.3, 0.36, 0.17), minf((big - 0.25) * 2.0, 0.6))   # 路边野草地
			var paddy := absf(x) > size.x * 0.22 and absf(x) < size.x * 0.5 - 2.5 and z > -size.y * 0.5 + 5.0
			if paddy:
				_fc_grass = false
				var dike := fposmod(z, 4.0) < 0.35 or fposmod(x, 6.0) < 0.35
				if dike:
					c = Color(0.38, 0.3, 0.2).lerp(Color(0.3, 0.36, 0.17), clampf(n2 + 0.3, 0.0, 0.7))
					_fc_grass = n2 > 0.0
				else:
					var row := fposmod(x, 0.5) < 0.2
					c = Color(0.3, 0.38, 0.16).lerp(Color(0.5, 0.48, 0.2), n * 0.5 + 0.5) * (1.12 if row else 0.82)
					if not row and noise.get_noise_2d(x * 0.7, z * 0.7 + 90.0) > 0.35:
						c = c.lerp(Color(0.25, 0.32, 0.36), 0.45)   # 田里的水面映着天
			if absf(x) < 1.6:
				_fc_grass = false
				c = Color(0.46, 0.38, 0.28) * (0.92 + 0.08 * sin(floor(z / 0.6) * 12.9898))
				if absf(absf(x) - 0.8) < 0.18:
					c = c * 0.88   # 两道车辙
			var sd := absf(z - _stream_z(x))
			if sd < 1.7:
				_fc_grass = false
				if absf(x) < 1.9:
					var slab := int(floor(z / 0.7)) % 2 == 0
					c = Color(0.42, 0.42, 0.42) if slab else Color(0.37, 0.37, 0.38)
					if absf(absf(x) - 1.8) < FV:
						c = Color(0.25, 0.24, 0.24)
				elif sd < 1.25:
					c = Color(0.2, 0.3, 0.36).lerp(Color(0.85, 0.55, 0.32), clampf(n2 * 1.5 - 0.3, 0.0, 0.45))
					if h > 0.993:
						c = c * 1.35   # 水面闪光
				else:
					# 河滩卵石：细胞噪声一颗一颗
					var sv := stone_val.get_noise_2d(x * 3.0, z * 3.0)
					c = Color(0.3, 0.27, 0.22).lerp(Color(0.48, 0.46, 0.42), sv * 0.5 + 0.5)
					if stone_noise.get_noise_2d(x * 3.0, z * 3.0) < -0.8:
						c = Color(0.2, 0.18, 0.15)
			elif _fc_grass and h > 0.997:
				c = [Color(0.9, 0.85, 0.6), Color(0.85, 0.5, 0.5), Color(0.75, 0.7, 0.95)][int(h * 3000.0) % 3]   # 野花
			return c * (1.12 + n2 * 0.1) * grain
		"post":
			# 青石驿道（中间宽，错缝铺，少数石板缺了露出泥、缝里冒草）积着水，两道车辙；两边泥地和枯草
			var road := absf(x) < 5.5 * _kx()
			var c := Color(0.2, 0.18, 0.16).lerp(Color(0.25, 0.23, 0.19), n * 0.5 + 0.5)
			if n2 > 0.3:
				c = c.lerp(Color(0.22, 0.27, 0.17), 0.5)
			var big := noise.get_noise_2d(x * 0.5 - 40.0, z * 0.5)
			if not road and big > 0.1:
				_fc_grass = true
				c = c.lerp(Color(0.33, 0.3, 0.17), minf((big - 0.1) * 2.0, 0.65))   # 枯草
			if road:
				var sx := int(floor(x / 0.9))
				var zo := 0.45 if sx % 2 == 0 else 0.0
				var sz := int(floor((z + zo) / 0.9))
				var tk := fposmod(sin(sx * 12.9898 + sz * 78.233) * 43758.5453, 1.0)
				var edge := absf(x) / (5.5 * _kx())
				if tk < 0.04 + maxf(edge - 0.8, 0.0) * 1.2:
					# 缺了的石板：露出泥，长着草
					c = Color(0.2, 0.2, 0.14) * (0.9 + n * 0.1)
					_fc_grass = h > 0.5
				else:
					c = Color(0.26, 0.28, 0.3) * (0.86 + 0.14 * tk)
					if fposmod(x, 0.9) < FV * 0.7 or fposmod(z + zo, 0.9) < FV * 0.7:
						c = Color(0.12, 0.13, 0.15)
						if n2 > 0.35:
							c = Color(0.16, 0.22, 0.13)   # 缝里的草
					elif tk > 0.93:
						c = c * 0.82   # 换过的新旧石板
				for rx: float in [-2.3, 2.3]:
					if absf(x - rx) < 0.28:
						c = c * 0.7
			var wet := noise.get_noise_2d(x * 0.8 + 40.0, z * 0.8)
			if wet > 0.22:
				_fc_grass = false
				c = c.lerp(Color(0.1, 0.14, 0.2), clampf((wet - 0.22) * 4.0, 0.0, 0.75))
				if n2 > 0.45:
					c = c.lerp(Color(0.55, 0.42, 0.3), 0.25)   # 水坑里映着灯笼
			elif h > 0.997 and not road:
				c = Color(0.62, 0.36, 0.14)   # 落叶
			return c * (1.15 + n2 * 0.1) * grain
		"palace":
			# 白玉方砖（金缝，砖面有淡青的玉纹）+ 中间一道红毯（金边），红毯上隔一段一朵金团花
			var tile := 2.0
			var sx := int(floor(x / tile))
			var sz := int(floor(z / tile))
			var shade := 0.9 + 0.1 * sin(sx * 12.9898 + sz * 78.233)
			var c := Color(0.62, 0.6, 0.56).lerp(Color(0.7, 0.68, 0.63), n * 0.5 + 0.5) * shade
			# 玉纹：每块砖里几道弯弯的细纹（噪声的等值线），每块走向不同
			var vein := noise.get_noise_2d(x * 1.4 + sx * 37.0, z * 1.4 + sz * 53.0)
			if absf(vein) < 0.025:
				c = c.lerp(Color(0.48, 0.55, 0.52), 0.5)
			if fposmod(x, tile) < FV * 0.8 or fposmod(z, tile) < FV * 0.8:
				c = Color(0.62, 0.48, 0.2)
			elif absf(fposmod(x, tile) - 1.0) < 0.35 and absf(fposmod(z, tile) - 1.0) < 0.35 and (sx + sz) % 2 == 0:
				c = c * 0.9
			if absf(x) < 2.4:
				c = Color(0.48, 0.08, 0.07) * (0.9 + n2 * 0.1)
				if absf(absf(x) - 2.2) < 0.12:
					c = Color(0.75, 0.56, 0.2)
				elif absf(x) < 1.6 and fposmod(z, 3.0) < 0.12:
					c = Color(0.62, 0.42, 0.14)
				else:
					var fz := fposmod(z, 3.0) - 1.5
					var fr := Vector2(x, fz).length()
					if fr < 0.7 and (absf(fr - 0.6) < 0.05 or (fr < 0.45 and fposmod(atan2(fz, x) * 8.0 / TAU, 1.0) < 0.3)):
						c = Color(0.7, 0.5, 0.16)   # 团花
			return c * (1.05 + n2 * 0.06) * grain
	return super._floor_color(x, z)


# ---------- 柳溪村 ----------

func _dress_liuxi() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var ka := _ka()
	_houses.clear()
	# 后面一排农舍（中间留出村路），门口挂灰纸灯
	var houses := ["home_a", "home_b", "house_ruin", "home_b", "home_a"]
	var nh := int((hx - 3.0) / 5.2)
	for i in range(-nh, nh + 1):
		var x := i * 5.2
		if absf(x) < 3.5:
			continue
		var id: String = houses[(absi(i) + (1 if x < 0 else 0)) % houses.size()]
		var hp := Vector3(x, 0, -hz + 2.2)
		kit(id, hp, rng.randf_range(-0.08, 0.08), 1.15, true)
		_houses.append(hp)
		if absi(i) % 2 == 1:
			_paper_lamp(hp + Vector3(1.6, 0, 2.4))
	# 风车立在一角，水车靠着小溪的那面墙
	var wm_side := -1.0 if rng.randf() < 0.5 else 1.0
	kit("windmill", Vector3(wm_side * (hx - 3.2), 0, -hz + 4.0), wm_side * 0.4, 1.25, true)
	var ws := -wm_side
	var wz := _stream_z(ws * (hx - 1.5))
	voxel_piece(_cached("waterwheel", _waterwheel), Vector3(ws * (hx - 1.0), 0, wz), 0.12, null, Vector3(1.2, 3, 3.6), false, PI * 0.5)
	# 两侧：树林、稻草垛、篱笆，路边几盏灰纸灯
	for side: float in [-1.0, 1.0]:
		var nt := maxi(2, int(round(3.0 * _kz())))
		for j in range(nt):
			var z := lerpf(-hz + 7.0, hz - 3.0, (j + 0.5) / float(nt))
			if absf(z - _stream_z(side * (hx - 1.5))) < 2.5:
				continue
			kit("tree_pine" if (j + int(side)) % 3 != 0 else "trees", Vector3(side * (hx - 1.2), 0, z), rng.randf() * TAU, 1.0 if j % 3 != 0 else 0.7, true)
		for j in range(maxi(2, int(round(2.0 * _kz())))):
			var p := Vector3(side * rng.randf_range(hx * 0.32, hx * 0.42), 0, rng.randf_range(-hz + 7.0, hz - 6.0))
			if absf(p.z - _stream_z(p.x)) > 2.6:
				voxel_piece(_cached("haystack", _haystack), p, 0.12, null, Vector3(1.4, 2, 1.4))
		var lz := [-hz * 0.25, hz * 0.4]
		for z: float in lz:
			_paper_lamp(Vector3(side * 2.6, 0, z))
	# 石桥两头的栏柱
	var sz0 := _stream_z(0.0)
	for sx: float in [-1.9, 1.9]:
		for dz: float in [-1.8, 1.8]:
			kit("column", Vector3(sx, 0, sz0 + dz), 0.0, 0.8, true)
	# 场地里：水井、木柴、木箱、腌菜缸（障碍）
	var spots := [Vector3(-5.5 * kx, 0, 5.0 * _kz()), Vector3(6.0 * kx, 0, -4.0 * _kz())]
	for i in range(int(round(3.0 * (ka - 1.0))) + 2):
		var p0 := _free_spot(4.5)
		if p0 != Vector3.INF and absf(p0.z - _stream_z(p0.x)) > 2.5:
			spots.append(p0)
	for s0: Vector3 in _spots_ok(spots):
		var r := rng.randf()
		if r < 0.25:
			kit("well", s0, rng.randf() * TAU, 1.0, true)
		elif r < 0.5:
			kit("lumber", s0, rng.randf() * TAU, 1.0, true)
		elif r < 0.75:
			kit("barrel", s0, rng.randf() * TAU, 1.0, true)
		else:
			kit("crates", s0, rng.randf() * TAU, 1.0, true)
	for i in range(int(5 * ka)):
		var p := Vector3(rng.randf_range(-hx + 3, hx - 3), 0, rng.randf_range(-hz + 5, hz - 3))
		if absf(p.x) > 2.2 and absf(p.z - _stream_z(p.x)) > 2.0:
			kit(["sack", "barrel_small", "pumpkin", "lumber"][rng.randi() % 4], p, rng.randf() * TAU, 0.8, false)
	if _is_boss_room():
		# 祠堂前：后面正中两座小祠、两面幡
		for sx: float in [-1.0, 1.0]:
			kit("shrine", Vector3(sx * 4.5, 0, -hz + 2.0), 0.0, 1.4, true)
			kit("banner", Vector3(sx * 6.5, 0, -hz + 1.0), 0.0, 1.3, true)
	# 黄昏的光：后面一盏大暖光，两边补光
	for p: Vector3 in [Vector3(0, 6.0, -hz + 1.0), Vector3(-hx * 0.5, 4.5, 0), Vector3(hx * 0.5, 4.5, 0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.68, 0.42)
		l.light_energy = 1.6
		l.omni_range = 14.0
		add_child(l)
		l.position = p
	_shaft(Vector3(-hx * 0.3, 0, -hz * 0.4), Color(1.0, 0.65, 0.35, 0.08), 2.4)
	_shaft(Vector3(hx * 0.35, 0, -hz * 0.2), Color(1.0, 0.65, 0.35, 0.07), 2.0)
	# 前景：靠镜头一排篱笆剪影
	for x0: float in _fg_xs():
		kit("fence", Vector3(x0 + rng.randf_range(-1.0, 1.0), 0, hz + 1.0), 0.0, 1.2, false, true)


## 火师半血：整个村子烧起来（每间屋子冒火冒烟，天边一片橙）
func ignite() -> void:
	if zone != "liuxi":
		super.ignite()
		return
	for hp: Vector3 in _houses:
		for k in range(3):
			_flame(hp + Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(1.5, 3.2), rng.randf_range(0.0, 1.5)))
		_smoke_column(hp + Vector3(0, 4.0, 0))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.45, 0.15)
		l.light_energy = 0.0
		l.omni_range = 9.0
		add_child(l)
		l.position = hp + Vector3(0, 2.5, 2.0)
		create_tween().tween_property(l, "light_energy", 3.0, 1.2)
	_ash()


## 灰纸灯：一根竹竿挑着一盏灰白的纸灯笼，灯里是冷冷的灰光
func _paper_lamp(p: Vector3) -> void:
	var pl: Array = _cached("paperlamp", _paper_lamp_grid)
	voxel_piece(pl[0], p, 0.1, pl[1], Vector3(0.4, 2, 0.4))
	if Arena.lod > 0:
		var l := OmniLight3D.new()
		l.light_color = Color(0.78, 0.82, 0.9)
		l.light_energy = 1.0
		l.omni_range = 3.5
		add_child(l)
		l.position = p + Vector3(0.6, 2.2, 0)


func _paper_lamp_grid() -> Array:
	var g := VoxelGrid.new(301)
	var glow := VoxelGrid.new(302)
	var wood := Color(0.3, 0.24, 0.15)
	g.box(Vector3i(-1, 0, -1), Vector3i(1, 27, 1), wood, 0.08)
	g.box(Vector3i(0, 26, 0), Vector3i(7, 27, 0), wood, 0.05)
	g.box(Vector3i(6, 24, 0), Vector3i(6, 25, 0), Color(0.15, 0.12, 0.1), 0.0)
	# 灯笼：上下两圈深色，中间灰白纸（发光）
	g.box(Vector3i(4, 23, -2), Vector3i(8, 23, 2), Color(0.18, 0.16, 0.15), 0.0)
	g.box(Vector3i(4, 16, -2), Vector3i(8, 16, 2), Color(0.18, 0.16, 0.15), 0.0)
	for y in range(17, 23):
		for x in range(4, 9):
			for z in range(-2, 3):
				if x == 4 or x == 8 or z == -2 or z == 2:
					glow.cells[Vector3i(x, y, z)] = Color(0.78, 0.8, 0.84) * (0.85 + 0.15 * float(y % 3 == 0))
	# 纸上一个黑字（“收”）
	glow.cells[Vector3i(6, 20, 2)] = Color(0.2, 0.2, 0.22)
	glow.cells[Vector3i(6, 19, 2)] = Color(0.2, 0.2, 0.22)
	glow.cells[Vector3i(5, 20, 2)] = Color(0.2, 0.2, 0.22)
	return [g, glow]


## 水车：一个竖着的大轮子，辐条 + 叶板，轴架在两根木桩上
func _waterwheel() -> VoxelGrid:
	var g := VoxelGrid.new(303)
	var wood := Color(0.34, 0.25, 0.16)
	var r := 13
	for a in range(96):
		var t := TAU * a / 96.0
		var px := int(round(cos(t) * r))
		var py := int(round(sin(t) * r)) + r + 2
		g.box(Vector3i(px, py, -2), Vector3i(px, py, 2), wood * 1.05, 0.06)
		if a % 8 == 0:
			var ox := int(round(cos(t) * (r + 2)))
			var oy := int(round(sin(t) * (r + 2))) + r + 2
			g.box(Vector3i(mini(px, ox), mini(py, oy), -3), Vector3i(maxi(px, ox), maxi(py, oy), 3), wood * 0.85, 0.05)
	for s in range(6):
		var t := TAU * s / 6.0
		for k in range(r):
			g.cells[Vector3i(int(round(cos(t) * k)), int(round(sin(t) * k)) + r + 2, 0)] = wood * 0.9
	g.box(Vector3i(-1, 0, -5), Vector3i(1, r + 3, -4), wood * 0.75, 0.05)
	g.box(Vector3i(-1, 0, 4), Vector3i(1, r + 3, 5), wood * 0.75, 0.05)
	g.box(Vector3i(-1, r + 1, -5), Vector3i(1, r + 3, 5), wood * 0.7, 0.05)
	return g


## 稻草垛：圆鼓鼓的一堆，顶上扎一把
func _haystack() -> VoxelGrid:
	var g := VoxelGrid.new(304)
	g.ellipsoid(Vector3(0, 6, 0), Vector3(6.5, 7, 6.5), Color(0.72, 0.6, 0.32), 0.12)
	g.box(Vector3i(-1, 12, -1), Vector3i(1, 15, 1), Color(0.62, 0.5, 0.26), 0.1)
	g.box(Vector3i(-6, 4, -6), Vector3i(6, 4, 6), Color(0.45, 0.35, 0.18), 0.05)
	for x in range(-7, 8):
		for z in range(-7, 8):
			if g.cells.has(Vector3i(x, 4, z)):
				g.cells[Vector3i(x, 4, z)] = Color(0.45, 0.35, 0.18)
	return g


# ---------- 官道驿站 ----------

func _dress_post() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var ka := _ka()
	var road := 5.5 * kx
	# 后面：左边驿站、右边马厩（官道从中间穿过去）
	kit("tavern", Vector3(-road - 4.0, 0, -hz + 2.6), 0.0, 1.3, true)
	kit("home_b", Vector3(-road - 9.5, 0, -hz + 2.4), 0.0, 1.1, true)
	voxel_piece(_cached("stable", _stable), Vector3(road + 4.5, 0, -hz + 2.4), 0.12, null, Vector3(6.0, 3, 2.6))
	kit("banner", Vector3(-3.0, 0, -hz + 0.8), 0.0, 1.3, true)
	kit("banner", Vector3(3.0, 0, -hz + 0.8), 0.0, 1.3, true)
	# 驿亭：路边一座四角亭子
	var pav_side := -1.0 if rng.randf() < 0.5 else 1.0
	voxel_piece(_cached("pavilion", _pavilion), Vector3(pav_side * (road + 4.5), 0, 1.5 * _kz()), 0.12, null, Vector3(3.6, 3, 3.6))
	kit("bench", Vector3(pav_side * (road + 4.5), 0, 1.5 * _kz()), PI * 0.5, 1.0, false)
	# 路两边：灯笼一排（暖光），里程石，枯树
	var nl := maxi(3, int(round(3.0 * _kz())))
	for j in range(nl):
		var z := lerpf(-hz + 5.0, hz - 4.0, (j + 0.5) / float(nl))
		for sx: float in [-1.0, 1.0]:
			if j % 2 == (0 if sx < 0 else 1):
				kit("post_lantern", Vector3(sx * (road + 0.6), 0, z), -sx * PI * 0.5, 1.0, true)
	var ms_n := maxi(2, int(round(2.0 * _kz())))
	for j in range(ms_n):
		var z := lerpf(-hz + 6.0, hz - 6.0, (j + 0.3) / float(ms_n))
		voxel_piece(_cached("milestone", _milestone), Vector3((road + 1.6) * (1.0 if j % 2 == 0 else -1.0), 0, z), 0.1, null, Vector3(0.8, 2, 0.6))
	for side: float in [-1.0, 1.0]:
		var nt := maxi(2, int(round(2.5 * _kz())))
		for j in range(nt):
			var z := lerpf(-hz + 6.0, hz - 3.0, (j + 0.5) / float(nt))
			kit("tree_dead" if j % 2 == 0 else "tree_pine", Vector3(side * (hx - 1.4), 0, z), rng.randf() * TAU, 1.0, true)
	# 场地里：翻倒的灯车（木箱、桶、草袋堆在一起）、拴马桩
	var spots := [Vector3(-(road + 6.0), 0, 5.0 * _kz()), Vector3(road + 7.0, 0, -3.0 * _kz())]
	for i in range(int(round(3.0 * (ka - 1.0))) + 1):
		var p0 := _free_spot(4.5, 3.0, road + 1.5)
		if p0 != Vector3.INF:
			spots.append(p0)
	for s0: Vector3 in _spots_ok(spots):
		var r := rng.randf()
		if r < 0.4:
			kit("crates", s0, rng.randf() * TAU, 1.0, true)
			kit("sack", s0 + Vector3(1.2, 0, 0.4), rng.randf() * TAU, 0.9, false)
		elif r < 0.7:
			kit("barrel", s0, rng.randf() * TAU, 1.0, true)
			kit("barrel_small", s0 + Vector3(-1.0, 0, 0.6), rng.randf() * TAU, 0.9, false)
		else:
			kit("lumber", s0, rng.randf() * TAU, 1.0, true)
	if _is_boss_room():
		# 十里亭：头目房后面正中一座亭子
		voxel_piece(_cached("pavilion", _pavilion), Vector3(0, 0, -hz + 3.0), 0.12, null, Vector3(3.6, 3, 3.6))
	_rain()
	for p: Vector3 in [Vector3(0, 5.0, -hz + 2.0), Vector3(-road - 4.0, 3.0, -hz + 5.0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.68, 0.4)
		l.light_energy = 1.8
		l.omni_range = 10.0
		add_child(l)
		l.position = p
	for x0: float in _fg_xs():
		kit("fence_broken" if rng.randf() < 0.5 else "fence", Vector3(x0 + rng.randf_range(-1.0, 1.0), 0, hz + 1.0), 0.0, 1.2, false, true)


## 下雨：细长的雨丝斜着落，地上溅起的小水花用几层贴地的涟漪代替
func _rain() -> void:
	var pt := CPUParticles3D.new()
	pt.amount = mini(int(260 * _ka()), 600) / (2 if lod == 0 else 1)
	pt.lifetime = 0.9
	pt.preprocess = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.7)
	pt.mesh = q
	pt.material_override = _fx_mat("light_01", Color(0.65, 0.75, 0.95, 0.5), true, 0.9)
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pt.emission_box_extents = Vector3(size.x * 0.5, 0.5, size.y * 0.5)
	pt.direction = Vector3(0.12, -1, 0.05)
	pt.spread = 3.0
	pt.initial_velocity_min = 12.0
	pt.initial_velocity_max = 15.0
	pt.gravity = Vector3(0, -6, 0)
	pt.particle_flag_align_y = true
	add_child(pt)
	pt.position = Vector3(0, 9.0, 0)
	var sp := CPUParticles3D.new()
	sp.amount = mini(int(40 * _ka()), 100) / (2 if lod == 0 else 1)
	sp.lifetime = 0.5
	sp.mesh = _particle_quad(0.35)
	sp.material_override = _fx_mat("lm_ring_b", Color(0.6, 0.7, 0.9, 0.35), true, 1.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	sp.gravity = Vector3.ZERO
	sp.initial_velocity_max = 0.0
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 1.4
	add_child(sp)
	sp.position = Vector3(0, 0.05, 0)
	sp.rotation.x = -PI / 2


## 驿亭：四根红柱、两层檐的屋顶
func _pavilion() -> VoxelGrid:
	var g := VoxelGrid.new(310)
	var red := Color(0.45, 0.12, 0.09)
	var roof := Color(0.2, 0.22, 0.25)
	for cx: int in [-12, 12]:
		for cz: int in [-12, 12]:
			g.box(Vector3i(cx - 1, 0, cz - 1), Vector3i(cx + 1, 24, cz + 1), red, 0.06)
	g.box(Vector3i(-15, 0, -15), Vector3i(15, 0, 15), Color(0.35, 0.34, 0.33), 0.08)
	g.box(Vector3i(-13, 21, -13), Vector3i(13, 22, 13), red * 0.7, 0.05)
	for k in range(6):
		var w := 17 - k * 3
		g.box(Vector3i(-w, 25 + k * 2, -w), Vector3i(w, 26 + k * 2, w), roof * (1.0 + 0.04 * k), 0.08)
	for cx: int in [-17, 17]:
		for cz: int in [-17, 17]:
			g.box(Vector3i(cx, 27, cz), Vector3i(cx, 28, cz), roof * 1.2, 0.0)
	g.box(Vector3i(-1, 37, -1), Vector3i(1, 39, 1), Color(0.55, 0.42, 0.18), 0.05)
	return g


## 马厩：一溜木柱 + 斜顶，柱间一道横栏，前面一个水槽
func _stable() -> VoxelGrid:
	var g := VoxelGrid.new(311)
	var wood := Color(0.32, 0.23, 0.15)
	for x in range(-24, 25, 8):
		g.box(Vector3i(x, 0, 6), Vector3i(x + 1, 20, 7), wood, 0.08)
		g.box(Vector3i(x, 0, -8), Vector3i(x + 1, 24, -7), wood * 0.85, 0.08)
	for y: int in [8, 14]:
		g.box(Vector3i(-24, y, 6), Vector3i(25, y, 7), wood * 0.9, 0.05)
	for z in range(-10, 10):
		var y := 24 - int((z + 10) * 0.25)
		g.box(Vector3i(-26, y, z), Vector3i(27, y + 1, z), Color(0.28, 0.2, 0.13) * (0.9 + 0.1 * float(z % 2 == 0)), 0.05)
	g.box(Vector3i(-20, 0, 9), Vector3i(-6, 4, 11), wood * 0.8, 0.05)
	g.box(Vector3i(-19, 4, 10), Vector3i(-7, 4, 10), Color(0.2, 0.28, 0.35), 0.0)
	g.box(Vector3i(-24, 0, -6), Vector3i(25, 2, 5), Color(0.5, 0.42, 0.24), 0.15)   # 草料
	return g


## 里程石：一块竖石，刻着“距京三百里”（几道深色刻痕）
func _milestone() -> VoxelGrid:
	var g := VoxelGrid.new(312)
	var st := Color(0.4, 0.4, 0.42)
	g.box(Vector3i(-4, 0, -2), Vector3i(4, 13, 2), st, 0.1)
	g.box(Vector3i(-3, 14, -2), Vector3i(3, 14, 2), st * 0.9, 0.05)
	for y in range(3, 12, 2):
		g.cells[Vector3i(0, y, 3)] = Color(0.12, 0.12, 0.14)
		if y % 4 == 1:
			g.cells[Vector3i(-1, y, 3)] = Color(0.12, 0.12, 0.14)
			g.cells[Vector3i(1, y, 3)] = Color(0.12, 0.12, 0.14)
	g.box(Vector3i(-5, 0, -3), Vector3i(5, 0, 3), Color(0.25, 0.27, 0.2), 0.1)
	return g


# ---------- 长明宫 ----------

func _dress_palace() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	# 后面：朱红金格屏风一排（中间留门），两边垂幔
	var ns := int((hx - 1.0) / 3.4)
	for i in range(-ns, ns + 1):
		var x := i * 3.4
		if absf(x) < 2.6:
			continue
		var sc: Array = _cached("screen", _screen)
		voxel_piece(sc[0], Vector3(x - 1.6, 0, -hz - 0.2), 0.11, sc[1])
	for sx: float in [-1.0, 1.0]:
		kit("banner", Vector3(sx * 3.2, 0, -hz + 0.8), 0.0, 1.5, true)
	# 两排柱子（朱漆金箍），柱间长明灯架
	var cx := 7.5 * kx
	var np := maxi(3, int(round(3.0 * _kz())))
	for sx: float in [-1.0, 1.0]:
		for j in range(np):
			var z := lerpf(-hz + 4.0, hz - 4.0, j / float(np - 1))
			voxel_piece(_cached("gpillar", _gold_pillar), Vector3(sx * cx, 0, z), 0.12, null, Vector3(1.0, 4, 1.0))
			if j < np - 1:
				var lz := z + (size.y - 8.0) / float(np - 1) * 0.5
				var ls: Array = _cached("lampstand_g", _lamp_stand.bind(Color(0.62, 0.48, 0.2)))
				voxel_piece(ls[0], Vector3(sx * cx, 0, lz), 0.12, ls[1], Vector3(0.8, 3, 0.8))
				_flame(Vector3(sx * cx, 2.45, lz))
				if j % 2 == 0:
					var l := OmniLight3D.new()
					l.light_color = Color(1.0, 0.75, 0.4)
					l.light_energy = 2.0
					l.omni_range = 7.0
					add_child(l)
					l.position = Vector3(sx * cx - sx * 0.6, 2.6, lz)
		# 柱子外侧：铜鹤香炉，靠墙一排垂幔
		var nc := maxi(1, int(round(1.5 * _kz())))
		for j in range(nc):
			var z := lerpf(-hz + 6.0, hz - 6.0, (j + 0.5) / float(nc))
			var cn: Array = _cached("censer", _censer)
			voxel_piece(cn[0], Vector3(sx * (cx + 4.0), 0, z), 0.1, cn[1], Vector3(1.2, 2, 1.2))
			_smoke_column(Vector3(sx * (cx + 4.0), 1.4, z))
		var nb := maxi(2, int(round(3.0 * _kz())))
		for j in range(nb):
			var z := lerpf(-hz + 3.0, hz - 3.0, (j + 0.5) / float(nb))
			kit("banner", Vector3(sx * (hx - 0.9), 0, z), -sx * PI * 0.5, 1.4, true)
	if _is_boss_room():
		# 金殿：后面正中的御座（台阶 + 金椅）
		var th: Array = _cached("throne", _throne)
		voxel_piece(th[0], Vector3(0, 0, -hz + 2.2), 0.12, th[1], Vector3(4.0, 2, 2.2))
	# 场地里散几件：翻倒的香案、碎瓷
	for i in range(int(3 * _ka())):
		var p := Vector3(rng.randf_range(-cx + 2.0, cx - 2.0), 0, rng.randf_range(-hz + 4, hz - 3))
		if absf(p.x) > 3.0:
			kit(["candles", "box", "candles"][rng.randi() % 3], p, rng.randf() * TAU, 0.8, false)
	for p: Vector3 in [Vector3(0, 6.0, -hz + 2.0), Vector3(0, 6.0, 0), Vector3(0, 6.0, hz - 5.0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.55)
		l.light_energy = 1.6
		l.omni_range = 14.0
		add_child(l)
		l.position = p
	for i in range(3):
		_shaft(Vector3(rng.randf_range(-cx, cx), 0, rng.randf_range(-hz * 0.5, hz * 0.2)), Color(1.0, 0.85, 0.55, 0.08), rng.randf_range(1.8, 2.6))
	for x0: float in _fg_xs():
		voxel_piece(_cached("gpillar_fg", _gold_pillar), Vector3(x0 + rng.randf_range(-1.0, 1.0), 0, hz + 1.3), 0.14, null, Vector3.ZERO, true)


## 朱漆柱：石础、红柱身、上下两道金箍、斗拱
func _gold_pillar() -> VoxelGrid:
	var g := VoxelGrid.new(320)
	var red := Color(0.5, 0.08, 0.06)
	var gold := Color(0.75, 0.56, 0.2)
	g.box(Vector3i(-5, 0, -5), Vector3i(5, 2, 5), Color(0.62, 0.6, 0.56), 0.06)
	g.box(Vector3i(-3, 3, -3), Vector3i(3, 40, 3), red, 0.05)
	for y: int in [6, 34]:
		g.box(Vector3i(-4, y, -4), Vector3i(4, y + 1, 4), gold, 0.05)
	g.box(Vector3i(-5, 41, -5), Vector3i(5, 43, 5), Color(0.2, 0.3, 0.32), 0.05)
	g.box(Vector3i(-6, 44, -6), Vector3i(6, 45, 6), gold * 0.85, 0.05)
	return g


## 屏风一扇：朱红框、金色格子，格子里透一点暖光
func _screen() -> Array:
	var g := VoxelGrid.new(321)
	var glow := VoxelGrid.new(322)
	var red := Color(0.45, 0.07, 0.05)
	var gold := Color(0.72, 0.54, 0.2)
	for x in range(0, 30):
		for y in range(0, 34):
			var edge := x < 2 or x > 27 or y < 2 or y > 31
			var bar := x % 6 == 2 or y % 6 == 2
			if edge:
				g.cells[Vector3i(x, y, 0)] = red
				g.cells[Vector3i(x, y, 1)] = red
			elif bar:
				g.cells[Vector3i(x, y, 0)] = gold
			else:
				glow.cells[Vector3i(x, y, 0)] = Color(0.9, 0.55, 0.3) * 0.5
	g.box(Vector3i(-1, 34, -1), Vector3i(30, 35, 2), Color(0.25, 0.2, 0.15), 0.05)
	return [g, glow]


## 铜鹤香炉：三足炉身，炉口有火星
func _censer() -> Array:
	var g := VoxelGrid.new(323)
	var glow := VoxelGrid.new(324)
	var b := Color(0.45, 0.33, 0.18)
	for a in range(3):
		var t := TAU * a / 3.0
		g.box(Vector3i(int(cos(t) * 4), 0, int(sin(t) * 4)), Vector3i(int(cos(t) * 4), 4, int(sin(t) * 4)), b * 0.8, 0.05)
	g.ellipsoid(Vector3(0, 8, 0), Vector3(6, 4, 6), b, 0.08)
	g.carve(Vector3i(-4, 11, -4), Vector3i(4, 13, 4))
	for x in range(-4, 5):
		for z in range(-4, 5):
			if x * x + z * z < 16:
				glow.cells[Vector3i(x, 10, z)] = Color(1.0, 0.5, 0.2)
	# 鹤：细长的脖子立在炉沿上
	g.box(Vector3i(5, 11, 0), Vector3i(5, 19, 0), Color(0.85, 0.85, 0.8), 0.0)
	g.box(Vector3i(3, 19, 0), Vector3i(5, 20, 0), Color(0.85, 0.85, 0.8), 0.0)
	g.cells[Vector3i(3, 21, 0)] = Color(0.75, 0.15, 0.1)
	return [g, glow]


## 御座：三级台阶，金椅，椅背后一圈光
func _throne() -> Array:
	var g := VoxelGrid.new(325)
	var glow := VoxelGrid.new(326)
	var gold := Color(0.78, 0.6, 0.22)
	for k in range(3):
		g.box(Vector3i(-16 + k * 3, k * 2, -8 + k * 2), Vector3i(16 - k * 3, k * 2 + 1, 9), Color(0.6, 0.58, 0.54) * (1.0 - 0.05 * k), 0.05)
	g.box(Vector3i(-5, 6, -2), Vector3i(5, 9, 4), gold, 0.06)
	g.box(Vector3i(-5, 10, -3), Vector3i(5, 22, -2), gold * 0.95, 0.06)
	g.box(Vector3i(-7, 6, -2), Vector3i(-6, 13, 4), gold * 0.85, 0.05)
	g.box(Vector3i(6, 6, -2), Vector3i(7, 13, 4), gold * 0.85, 0.05)
	g.box(Vector3i(-3, 7, 0), Vector3i(3, 9, 3), Color(0.5, 0.08, 0.06), 0.0)
	for a in range(40):
		var t := PI * a / 39.0
		glow.cells[Vector3i(int(round(cos(t) * 10)), 16 + int(round(sin(t) * 10)), -4)] = Color(1.0, 0.8, 0.4)
	return [g, glow]
