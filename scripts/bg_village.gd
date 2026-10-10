class_name BgVillage
extends Background
## 山脚荒村，黄昏。夕阳压在山口，远处的屋子在烧，烟往上飘，乌鸦绕着枯树飞。
## 光从左边来（夕阳），屋子、树的左边缘描一道暖色轮廓光。
##
## mood 换一套天色和远近景，同一个村子的不同地方看起来不一样：
##   dusk 黄昏烧村 · night 月夜 · graves 乱坟岗（鬼火、坟包、石塔） · fog 雾田（清晨大雾）
##   bamboo 竹林 · camp 山贼营（营火、帐篷、栅栏）

var mood := "dusk"

## 每种天色的配色。sky 从上到下五段；orb 是太阳或月亮
const MOODS := {
	"dusk": {"sky": ["140c26", "3a1a40", "7a2c45", "c4513a", "eb9a4e"], "stars": 1.0,
		"orb": ["f2a24e", "f7c06a", "fde3a0"], "orb_pos": Vector2(150, 196), "orb_r": 30.0, "orb_bar": "8a3a40",
		"glow": Color(0.42, 0.18, 0.06, 0.05), "band": Color(0.35, 0.14, 0.04, 0.18),
		"cloud": ["5a2440", "8e3a3e"], "mtn": ["4a2240", "2c1530"], "mtn_rim": Color(0.85, 0.4, 0.3, 0.5),
		"mtn_fog": Color(0.75, 0.32, 0.3, 0.05), "smoke": Color(0.14, 0.08, 0.12, 0.28),
		"far": "26142a", "far_lit": "6e2c38", "wall": "2e1c26", "wall_lit": "4a2a2e", "beam": "1c1018",
		"roof": "3a2420", "roof_lit": "8a4a32", "rim": "c2633c", "win": "0e070c", "tree": "1e1018", "tree_rim": "7a3a30",
		"ground": "1e1416", "ground_top": "5a3a30", "ground_lip": "a8643e", "stone": ["3a2a28", "4a3430"],
		"grass": ["7a5a32", "a87a40"], "haze": Color(0.85, 0.45, 0.35, 0.045), "front": "0a0608",
		"fires": true, "motes": "ember", "fall": "ash"},
	"night": {"sky": ["05070f", "0b1226", "16213e", "26345a", "3a4a70"], "stars": 2.2,
		"orb": ["b8c4d8", "d6dce8", "f0f2f6"], "orb_pos": Vector2(470, 70), "orb_r": 16.0, "orb_bar": "1c2840",
		"glow": Color(0.12, 0.16, 0.26, 0.05), "band": Color(0.08, 0.1, 0.18, 0.15),
		"cloud": ["1a2238", "2a3654"], "mtn": ["1a2440", "10162a"], "mtn_rim": Color(0.6, 0.7, 0.9, 0.35),
		"mtn_fog": Color(0.4, 0.5, 0.7, 0.05), "smoke": Color(0.1, 0.12, 0.18, 0.2),
		"far": "0e1424", "far_lit": "2a3a5a", "wall": "1a2030", "wall_lit": "28324a", "beam": "0c1018",
		"roof": "1e2230", "roof_lit": "46587a", "rim": "8aa2c8", "win": "06080e", "tree": "0c1018", "tree_rim": "3a4a6a",
		"ground": "121620", "ground_top": "2a3244", "ground_lip": "6a7c9a", "stone": ["222a38", "2c3646"],
		"grass": ["3a4a4a", "5a6a6a"], "haze": Color(0.45, 0.55, 0.75, 0.05), "front": "04060a",
		"fires": false, "lamps": true, "motes": "firefly", "fall": "leaf"},
	"graves": {"sky": ["060a0a", "0e1a18", "1a2a26", "2c3e34", "46584a"], "stars": 0.5,
		"orb": ["a8b89a", "c8d4b4", "e0e8cc"], "orb_pos": Vector2(320, 64), "orb_r": 20.0, "orb_bar": "1a2622",
		"glow": Color(0.12, 0.2, 0.14, 0.05), "band": Color(0.1, 0.2, 0.14, 0.2),
		"cloud": ["141e1c", "26342e"], "mtn": ["16221e", "0c1412"], "mtn_rim": Color(0.5, 0.7, 0.55, 0.3),
		"mtn_fog": Color(0.35, 0.6, 0.45, 0.07), "smoke": Color(0.1, 0.14, 0.12, 0.2),
		"far": "0c1412", "far_lit": "2a4034", "wall": "1a2220", "wall_lit": "26302c", "beam": "0c1010",
		"roof": "1a201c", "roof_lit": "3e5244", "rim": "7aa88a", "win": "060908", "tree": "0a0e0c", "tree_rim": "3a5444",
		"ground": "141814", "ground_top": "2c362c", "ground_lip": "5e7a5e", "stone": ["262e28", "323c34"],
		"grass": ["3e4a34", "56624a"], "haze": Color(0.4, 0.75, 0.55, 0.07), "front": "040605",
		"fires": false, "motes": "wisp", "fall": "ash", "fog": 2.0},
	"fog": {"sky": ["5a6470", "6e7884", "848c96", "9aa0a6", "aeb2b4"], "stars": 0.0,
		"orb": ["c8c8c0", "d8d8d0", "e8e6de"], "orb_pos": Vector2(200, 120), "orb_r": 18.0, "orb_bar": "a0a4a8",
		"glow": Color(0.18, 0.18, 0.16, 0.05), "band": Color(0.2, 0.2, 0.2, 0.15),
		"cloud": ["7a828c", "949aa2"], "mtn": ["8a929a", "767e88"], "mtn_rim": Color(0.9, 0.92, 0.95, 0.25),
		"mtn_fog": Color(0.85, 0.87, 0.9, 0.12), "smoke": Color(0.5, 0.52, 0.56, 0.2),
		"far": "6a727c", "far_lit": "8a929a", "wall": "3e4248", "wall_lit": "52585e", "beam": "2a2e32",
		"roof": "40444a", "roof_lit": "70767c", "rim": "b0b6bc", "win": "1e2024", "tree": "2a2e32", "tree_rim": "6a7078",
		"ground": "2a2c2c", "ground_top": "4a4e4c", "ground_lip": "8a908a", "stone": ["3a3e3c", "464a48"],
		"grass": ["6a7058", "86906c"], "haze": Color(0.85, 0.88, 0.9, 0.09), "front": "14161a",
		"fires": false, "motes": "none", "fall": "leaf", "fog": 3.0},
	"bamboo": {"sky": ["0a140e", "142a1c", "1e4028", "3a5e34", "6e8a4a"], "stars": 0.3,
		"orb": ["c8d890", "dce8a8", "eef4c8"], "orb_pos": Vector2(420, 150), "orb_r": 22.0, "orb_bar": "2a4a2c",
		"glow": Color(0.18, 0.24, 0.08, 0.05), "band": Color(0.2, 0.26, 0.08, 0.15),
		"cloud": ["1e3a24", "36583a"], "mtn": ["1a3422", "0e2216"], "mtn_rim": Color(0.6, 0.85, 0.5, 0.3),
		"mtn_fog": Color(0.5, 0.75, 0.45, 0.06), "smoke": Color(0.1, 0.16, 0.1, 0.2),
		"far": "0c1e12", "far_lit": "2a4a2c", "wall": "1a2a1c", "wall_lit": "2a3e2a", "beam": "0c140c",
		"roof": "1e2a1c", "roof_lit": "4a6a3a", "rim": "9ac870", "win": "060a06", "tree": "0c160c", "tree_rim": "4a6a34",
		"ground": "141a12", "ground_top": "2e3e24", "ground_lip": "6a8a44", "stone": ["24301e", "2e3c26"],
		"grass": ["4a6a2c", "6a8e3a"], "haze": Color(0.55, 0.8, 0.45, 0.05), "front": "040804",
		"fires": false, "motes": "firefly", "fall": "leaf"},
	"camp": {"sky": ["0e0608", "220a0e", "3e1214", "6a1e18", "94341e"], "stars": 0.8,
		"orb": ["c84a2a", "e06a3a", "f09a5a"], "orb_pos": Vector2(520, 96), "orb_r": 14.0, "orb_bar": "4a1414",
		"glow": Color(0.35, 0.08, 0.04, 0.05), "band": Color(0.4, 0.1, 0.02, 0.22),
		"cloud": ["2a0c10", "4e1a18"], "mtn": ["2a0e12", "180608"], "mtn_rim": Color(0.9, 0.35, 0.2, 0.4),
		"mtn_fog": Color(0.7, 0.2, 0.12, 0.06), "smoke": Color(0.12, 0.05, 0.05, 0.3),
		"far": "1a080a", "far_lit": "5a1a14", "wall": "2a1612", "wall_lit": "44221a", "beam": "160a08",
		"roof": "3a1a12", "roof_lit": "8a3a20", "rim": "e0602e", "win": "0a0404", "tree": "140808", "tree_rim": "6a2a1c",
		"ground": "1a100c", "ground_top": "4a2a1c", "ground_lip": "a85a2e", "stone": ["342218", "40281c"],
		"grass": ["6a4a24", "8a5e2a"], "haze": Color(0.9, 0.4, 0.2, 0.05), "front": "080404",
		"fires": true, "motes": "ember", "fall": "ash"},
}

var P: Dictionary

## 离线画好的场景件（tools/sprites/build_village.py）：每种天色一张图集
const ATLAS_JSON := "res://assets/scenes/village.json"
static var _atlas_data: Dictionary = {}
static var _atlas_tex: Dictionary = {}
var _tex: Texture2D
var _pieces: Dictionary      # 名字 -> {rect, layer}
var _pmeta: Dictionary       # 名字 -> 这个天色下的 {origin, windows, smoke}
var _decals: Array = []      # 地上的草簇和石头：[名字, x]
const NEAR_HOUSES := ["house_thatch", "house_tile", "storehouse", "house_thatch"]
const BROKEN_HOUSES := ["house_thatch_b", "house_ruin"]
const FAR_HOUSES := ["far_a", "far_b", "far_c", "far_d", "far_e"]


func _load_atlas() -> void:
	if _atlas_data.is_empty():
		var f := FileAccess.open(ATLAS_JSON, FileAccess.READ)
		if f == null:
			return
		_atlas_data = JSON.parse_string(f.get_as_text())
	if not _atlas_tex.has(mood):
		_atlas_tex[mood] = load("res://assets/scenes/village_%s.png" % mood)
	_tex = _atlas_tex[mood]
	_pieces = _atlas_data["pieces"]
	_pmeta = _atlas_data["moods"][mood]


func has_atlas() -> bool:
	return _tex != null


## 把一个场景件画在 at（件的贴地点对齐 at）
func _piece(c: CanvasItem, name: String, at: Vector2, mod := Color.WHITE) -> Rect2:
	var r: Array = _pieces[name]["rect"]
	var o: Array = _pmeta[name]["origin"]
	var dst := Rect2(roundf(at.x) - o[0], roundf(at.y) - o[1], r[2], r[3])
	c.draw_texture_rect_region(_tex, dst, Rect2(r[0], r[1], r[2], r[3]), mod)
	return dst


func _piece_size(name: String) -> Vector2:
	var r: Array = _pieces[name]["rect"]
	return Vector2(r[2], r[3])


## 近景房子用哪张图
func _house_piece(h: Array) -> String:
	var i := int(h[0]) / 7
	if h[3]:
		return BROKEN_HOUSES[i % BROKEN_HOUSES.size()]
	return NEAR_HOUSES[i % NEAR_HOUSES.size()]


func _c(k: String) -> Color:
	return Color(P[k])

var _motes: Array[Vector3] = []      # 火星 / 萤火 / 鬼火
var _fall: Array[Vector3] = []       # 飘下来的灰或叶子
var _crows: Array[Vector3] = []
var _houses_far: Array = []          # [x, 宽, 高, 是否破]
var _houses_near: Array = []         # [x, 宽, 高, 是否破, 是否着火]
var _trees: Array = []               # [x, 高, 种子]
var _fires: Array[float] = []        # 远处着火的屋子（冒烟的位置）
var _graves: Array = []              # 乱坟岗近景：[x, 种类, 种子]
var _stalks: Array = []              # 竹林近景：[x, 高, 粗细, 种子]
var _tents: Array = []               # 营地近景：[x, 宽]


func _scene() -> String:
	match mood:
		"graves": return "graves"
		"bamboo": return "bamboo"
		"camp": return "camp"
	return "village"


func _build() -> void:
	if not MOODS.has(mood):
		mood = "dusk"
	P = MOODS[mood]
	_load_atlas()
	_rng.seed = 100 + seed_value
	var far_w := span(0.3)
	var near_w := span(0.6)
	var x := -40.0 + _rng.randf_range(0, 60)
	while x < far_w:
		var w := _rng.randf_range(34, 62)
		var broken := _rng.randf() < 0.35
		_houses_far.append([x, w, _rng.randf_range(20, 34), broken])
		if broken and _rng.randf() < 0.6:
			_fires.append(x + w * 0.5)
		x += w + _rng.randf_range(10, 90)
	match _scene():
		"village":
			x = 30.0 + _rng.randf_range(0, 80)
			while x < near_w:
				var w := _rng.randf_range(70, 110)
				var h := [x, w, _rng.randf_range(38, 52), _rng.randf() < 0.4, P["fires"] and _rng.randf() < 0.3]
				if has_atlas():
					h[1] = _piece_size(_house_piece(h)).x
				_houses_near.append(h)
				x += float(h[1]) + _rng.randf_range(110, 240)
		"graves":
			x = _rng.randf_range(10, 60)
			while x < near_w:
				_graves.append([x, _rng.randi_range(0, 3), _rng.randi()])
				x += _rng.randf_range(26, 70)
		"bamboo":
			x = -10.0
			while x < near_w:
				_stalks.append([x, _rng.randf_range(160, 300), _rng.randi_range(3, 5), _rng.randi()])
				x += _rng.randf_range(8, 46)
		"camp":
			x = _rng.randf_range(40, 140)
			while x < near_w:
				_tents.append([x, _rng.randf_range(60, 90)])
				x += _rng.randf_range(180, 300)
	if _scene() != "bamboo":
		x = _rng.randf_range(60, 200)
		var gap := 160.0 if _scene() == "graves" else 260.0
		while x < near_w:
			_trees.append([x, _rng.randf_range(70, 120), _rng.randi()])
			x += _rng.randf_range(gap, gap * 1.8)
	if _fires.is_empty():
		_fires.append(far_w * 0.6)
	if has_atlas():
		x = _rng.randf_range(0, 40)
		var names := ["tuft_a", "tuft_b", "tuft_c", "tuft_d", "rock_a", "rock_b", "tuft_a", "tuft_c"]
		while x < arena_w + 100.0:
			_decals.append([names[_rng.randi() % names.size()], x])
			x += _rng.randf_range(24, 90)
	var nm := {"ember": 40, "firefly": 26, "wisp": 12, "none": 0}
	for i in range(int(nm.get(P["motes"], 0))):
		_motes.append(Vector3(_rng.randf() * arena_w, _rng.randf() * floor_y, _rng.randf() * TAU))
	for i in range(30):
		_fall.append(Vector3(_rng.randf() * arena_w, _rng.randf() * floor_y, _rng.randf() * TAU))
	if mood != "bamboo" and mood != "camp":
		for i in range(7):
			_crows.append(Vector3(_rng.randf() * far_w, 60.0 + _rng.randf() * 70.0, _rng.randf() * TAU))

	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer(0.0, _paint_sky)
	_add_layer(0.0, _paint_sun_glow, add)
	_add_layer(0.05, _paint_clouds)
	_add_layer(0.12, _paint_mountains)
	if P["fires"]:
		_add_layer(0.25, _paint_smoke)
	match _scene():
		"village": _add_layer(0.3, _paint_far_village)
		"graves": _add_layer(0.3, _paint_far_graves)
		"bamboo":
			_add_layer(0.2, _paint_far_bamboo.bind(0))
			_add_layer(0.35, _paint_far_bamboo.bind(1))
			_add_layer(0.35, _paint_shafts, add)
		"camp": _add_layer(0.3, _paint_far_camp)
	_add_layer(0.3, _paint_crows)
	if P["fires"] or P.get("lamps", false) or _scene() == "camp":
		_add_layer(0.3, _paint_far_fire, add)
	_add_layer(0.6, _paint_near)
	_add_layer(0.6, _paint_near_glow, add)
	_add_layer(1.0, _paint_ground)


func _build_front() -> Array[Layer]:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front.append(_new_layer(1.0, _paint_motes, add))
	_front.append(_new_layer(1.0, _paint_fall))
	_front.append(_new_layer(1.0, _paint_haze))
	_front.append(_new_layer(1.3, _paint_front))
	return _front


func _tick(delta: float) -> void:
	var kind: String = P["motes"]
	for i in range(_motes.size()):
		var e := _motes[i]
		e.z += delta * (3.0 if kind == "ember" else 1.0)
		match kind:
			"ember":
				e.x += sin(e.z) * 10.0 * delta + 8.0 * delta
				e.y -= (18.0 + fmod(float(i) * 7.0, 16.0)) * delta
				if e.y < 20.0:
					e = Vector3(_rng.randf() * arena_w, floor_y + 4.0, _rng.randf() * TAU)
			"firefly":
				e.x += cos(e.z * 0.7 + i) * 9.0 * delta
				e.y += sin(e.z * 1.1 + i * 2.0) * 7.0 * delta
				e.y = clampf(e.y, floor_y - 140.0, floor_y - 6.0)
			"wisp":
				e.x += (sin(e.z * 0.5 + i) * 14.0 + 4.0) * delta
				e.y = floor_y - 30.0 - fmod(float(i) * 23.0, 70.0) + sin(e.z * 1.3 + i) * 10.0
				if e.x > arena_w + 20.0:
					e.x = -20.0
		_motes[i] = e
	var leaf: bool = P["fall"] == "leaf"
	for i in range(_fall.size()):
		var a := _fall[i]
		a.z += delta * (2.2 if leaf else 1.5)
		a.x += ((16.0 if leaf else 10.0) + sin(a.z) * (18.0 if leaf else 12.0)) * delta
		a.y += (20.0 if leaf else 12.0) * delta
		if a.y > floor_y + 8.0 or a.x > arena_w + 20.0:
			a = Vector3(_rng.randf() * arena_w - 60.0, -4.0, _rng.randf() * TAU)
		_fall[i] = a
	for i in range(_crows.size()):
		var cr := _crows[i]
		cr.z += delta
		_crows[i] = cr


# ---------- 天空 ----------

func _paint_sky(c: CanvasItem) -> void:
	var stops: Array = P["sky"]
	var steps := 30
	var band := floor_y / steps
	for i in range(steps):
		var t := float(i) / (steps - 1) * (stops.size() - 1)
		var k := mini(int(t), stops.size() - 2)
		var col: Color = Color(stops[k]).lerp(Color(stops[k + 1]), t - k)
		c.draw_rect(Rect2(0, roundf(i * band), VIEW_W + 200, ceilf(band) + 1), col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var stars := float(P["stars"])
	for i in range(int(26 * stars)):
		var pos := Vector2(rng.randi_range(0, int(VIEW_W)), rng.randi_range(0, int(70 + 40 * stars)))
		var b := rng.randf_range(0.2, 0.7) * (0.6 + 0.4 * sin(time * rng.randf_range(1.0, 3.0) + i))
		c.draw_rect(Rect2(pos, Vector2(1, 1)), Color(1.0, 0.95, 0.9, b))
	var at: Vector2 = P["orb_pos"]
	var r: float = P["orb_r"]
	var oc: Array = P["orb"]
	c.draw_circle(at, r, Color(oc[0]))
	c.draw_circle(at, r * 0.86, Color(oc[1]))
	c.draw_circle(at, r * 0.7, Color(oc[2]))
	if mood == "night" or mood == "graves":
		# 月亮上的暗斑
		c.draw_circle(at + Vector2(-r * 0.3, -r * 0.2), r * 0.2, Color(oc[0]))
		c.draw_circle(at + Vector2(r * 0.25, r * 0.3), r * 0.14, Color(oc[0]))
	if P["fires"]:
		for k in range(3):
			var y := at.y - r * 0.45 + k * r * 0.3
			c.draw_rect(Rect2(at.x - r * 1.5 + k * 9, y, r * 2.3 - k * 12, 2), Color(P["orb_bar"]))
	else:
		# 一缕云从月亮前面飘过
		var cx := at.x - r * 2.0 + fmod(time * 4.0, r * 4.0)
		c.draw_rect(Rect2(cx, at.y + r * 0.3, r * 1.6, 2), Color(P["orb_bar"]))


func _paint_sun_glow(c: CanvasItem) -> void:
	var at: Vector2 = P["orb_pos"]
	for i in range(12):
		c.draw_circle(at, float(P["orb_r"]) + 2.0 + i * 9.0, P["glow"])
	c.draw_rect(Rect2(0, 236, VIEW_W + 200, 26), P["band"])


func _paint_clouds(c: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51 + seed_value
	var w := span(0.05)
	var n := 14 if mood == "fog" or mood == "graves" else 9
	for i in range(n):
		var y := rng.randf_range(40, 170)
		var x := fmod(rng.randf_range(0, w) + time * rng.randf_range(1.0, 3.0), w + 160.0) - 120.0
		var len := rng.randf_range(80, 170)
		var col := Color(P["cloud"][0]) if y < 120 else Color(P["cloud"][1])
		c.draw_rect(Rect2(roundf(x), roundf(y), len, 3), col)
		c.draw_rect(Rect2(roundf(x + 14), roundf(y - 2), len * 0.55, 2), col)
		c.draw_rect(Rect2(roundf(x + 10), roundf(y + 3), len * 0.7, 1), Color(col.lightened(0.25), 0.8))


func _paint_mountains(c: CanvasItem) -> void:
	var w := span(0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61 + seed_value
	for layer in range(2):
		var pts := PackedVector2Array()
		var base := 230.0 + layer * 18.0
		var col := Color(P["mtn"][layer])
		var x := -20.0
		pts.append(Vector2(x, floor_y))
		while x < w + 40.0:
			pts.append(Vector2(x, base - rng.randf_range(10, 60 - layer * 18)))
			x += rng.randf_range(40, 90)
		pts.append(Vector2(x, floor_y))
		c.draw_colored_polygon(pts, col)
		var rim: Color = P["mtn_rim"]
		for i in range(1, pts.size() - 2):
			if pts[i].y < pts[i + 1].y:
				continue
			c.draw_line(pts[i - 1] if pts[i - 1].y > pts[i].y else pts[i], pts[i], Color(rim, rim.a - layer * 0.2), 1.0)
		for k in range(5):
			c.draw_rect(Rect2(0, base - 4 + k * 5, w, 5), P["mtn_fog"])
	if mood == "fog":
		# 大雾把远山吃掉一半
		for k in range(8):
			c.draw_rect(Rect2(0, 190 + k * 12, w, 12), Color(0.8, 0.82, 0.85, 0.07 + k * 0.012))


func _paint_smoke(c: CanvasItem) -> void:
	var sc: Color = P["smoke"]
	for f in _fires:
		var fx: float = f * (0.25 / 0.3)
		for i in range(18):
			var t := fmod(time * 0.18 + i / 18.0, 1.0)
			var p := Vector2(fx + t * t * 60.0 + sin(t * 6.0 + i) * 4.0, 262.0 - t * 200.0)
			var r := 5.0 + t * 22.0
			c.draw_circle(p.round(), r, Color(sc, sc.a * (1.0 - t)))


func _paint_far_village(c: CanvasItem) -> void:
	var col := _c("far")
	var lit := _c("far_lit")
	var ground := 270.0
	c.draw_rect(Rect2(-20, ground, span(0.3) + 40, floor_y - ground), col)
	if has_atlas():
		var k := 0
		for h in _houses_far:
			var name: String = FAR_HOUSES[(k + seed_value) % FAR_HOUSES.size()]
			_piece(c, name, Vector2(float(h[0]) + float(h[1]) * 0.5, ground + 1))
			k += 1
		_piece(c, "tower", Vector2(span(0.3) * 0.45 + 7, ground + 1))
		return
	for h in _houses_far:
		var x: float = h[0]
		var w: float = h[1]
		var ht: float = h[2]
		c.draw_rect(Rect2(x + 4, ground - ht, w - 8, ht), col)
		var roof := PackedVector2Array([Vector2(x - 4, ground - ht + 2), Vector2(x + w * 0.5, ground - ht - 16),
			Vector2(x + w + 4, ground - ht + 2)])
		if h[3]:
			roof = PackedVector2Array([Vector2(x - 4, ground - ht + 2), Vector2(x + w * 0.35, ground - ht - 12),
				Vector2(x + w * 0.5, ground - ht - 4), Vector2(x + w * 0.62, ground - ht - 9), Vector2(x + w + 4, ground - ht + 2)])
		c.draw_colored_polygon(roof, col)
		c.draw_line(roof[0], roof[1], lit, 1.0)
	var tx := span(0.3) * 0.45
	c.draw_rect(Rect2(tx - 2, ground - 64, 2, 64), col)
	c.draw_rect(Rect2(tx + 14, ground - 64, 2, 64), col)
	c.draw_line(Vector2(tx, ground - 10), Vector2(tx + 14, ground - 40), col, 1.0)
	c.draw_line(Vector2(tx + 14, ground - 10), Vector2(tx, ground - 40), col, 1.0)
	c.draw_rect(Rect2(tx - 5, ground - 72, 24, 10), col)
	c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 8, ground - 72), Vector2(tx + 7, ground - 82), Vector2(tx + 22, ground - 72)]), col)
	c.draw_line(Vector2(tx - 8, ground - 72), Vector2(tx + 7, ground - 82), lit, 1.0)


## 乱坟岗远景：一层层坟包和歪斜的石塔、卒塔婆，山坡上一棵歪脖子树
func _paint_far_graves(c: CanvasItem) -> void:
	var col := _c("far")
	var lit := _c("far_lit")
	var w := span(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 131 + seed_value
	# 起伏的坟坡
	var pts := PackedVector2Array([Vector2(-20, floor_y)])
	var x := -20.0
	while x < w + 40.0:
		pts.append(Vector2(x, 262.0 - sin(x * 0.012) * 12.0 - rng.randf_range(0, 5)))
		x += 18.0
	pts.append(Vector2(x, floor_y))
	c.draw_colored_polygon(pts, col)
	x = rng.randf_range(0, 30)
	while x < w:
		var y := 262.0 - sin(x * 0.012) * 12.0
		match rng.randi_range(0, 3):
			0:   # 坟包
				c.draw_circle(Vector2(x, y + 2), rng.randf_range(6, 10), col)
				c.draw_line(Vector2(x - 6, y - 4), Vector2(x - 2, y - 7), lit, 1.0)
			1:   # 墓碑
				var h := rng.randf_range(8, 14)
				c.draw_rect(Rect2(x - 3, y - h, 6, h), col)
				c.draw_rect(Rect2(x - 3, y - h, 1, h), lit)
			2:   # 卒塔婆，木条歪着
				var lean := rng.randf_range(-3, 3)
				for k in range(3):
					c.draw_line(Vector2(x + k * 3, y), Vector2(x + k * 3 + lean, y - 16 - k * 3), col, 1.0)
			3:   # 五轮石塔
				c.draw_rect(Rect2(x - 5, y - 6, 10, 6), col)
				c.draw_circle(Vector2(x, y - 9), 4, col)
				c.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y - 12), Vector2(x, y - 17), Vector2(x + 6, y - 12)]), col)
				c.draw_rect(Rect2(x - 1, y - 23, 2, 6), col)
		x += rng.randf_range(10, 30)
	# 山坡上的歪脖子树和吊着的破灯
	var tx := w * 0.55
	c.draw_line(Vector2(tx, 252), Vector2(tx + 6, 200), col, 4.0)
	c.draw_line(Vector2(tx + 6, 200), Vector2(tx + 40, 186), col, 3.0)
	c.draw_line(Vector2(tx + 20, 194), Vector2(tx + 28, 176), col, 2.0)
	c.draw_line(Vector2(tx + 36, 188), Vector2(tx + 36, 204), col, 1.0)
	c.draw_rect(Rect2(tx + 33, 204, 6, 7), col)


## 竹林远景：两层竹竿，越远越淡、越细
func _paint_far_bamboo(c: CanvasItem, layer: int) -> void:
	var w := span(0.2 if layer == 0 else 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 141 + layer * 7 + seed_value
	var col := Color(P["mtn"][0]).lerp(_c("far"), 0.5) if layer == 0 else _c("far")
	var leaf := col.lightened(0.08)
	var x := -10.0
	while x < w:
		var thick := 2.0 if layer == 0 else 3.0
		var sway := sin(time * 0.8 + x * 0.05) * (1.0 + layer)
		c.draw_line(Vector2(x, floor_y), Vector2(x + sway, -10), col, thick)
		var y := floor_y - rng.randf_range(10, 30)
		while y > 0:
			c.draw_rect(Rect2(x - 1 + sway * (1.0 - y / floor_y), y, thick + 2, 1), col.lightened(0.12))
			y -= rng.randf_range(22, 34)
		for k in range(3):
			var ly := rng.randf_range(10, 160)
			var lx := x + sway * (1.0 - ly / floor_y)
			var d := -1.0 if rng.randf() < 0.5 else 1.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(lx, ly), Vector2(lx + d * 14, ly + 3), Vector2(lx + d * 3, ly + 4)]), leaf)
		x += rng.randf_range(6, 22) if layer == 0 else rng.randf_range(14, 40)
	if layer == 1:
		for k in range(4):
			c.draw_rect(Rect2(0, 230 + k * 14, w, 14), Color(P["mtn_fog"], 0.05 + k * 0.02))


func _paint_shafts(c: CanvasItem) -> void:
	# 从竹叶缝里漏下来的斜光
	var w := span(0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 151 + seed_value
	var x := rng.randf_range(40, 160)
	while x < w:
		var a := 0.035 + 0.015 * sin(time * 0.6 + x)
		var top := x
		c.draw_colored_polygon(PackedVector2Array([Vector2(top, 0), Vector2(top + 18, 0),
			Vector2(top + 18 + 90, floor_y), Vector2(top + 90 - 12, floor_y)]), Color(0.5, 0.6, 0.3, a))
		x += rng.randf_range(160, 320)


## 山贼营远景：木栅栏、望楼、一片帐篷和营火
func _paint_far_camp(c: CanvasItem) -> void:
	var col := _c("far")
	var lit := _c("far_lit")
	var w := span(0.3)
	var ground := 268.0
	c.draw_rect(Rect2(-20, ground, w + 40, floor_y - ground), col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 161 + seed_value
	var x := -10.0
	while x < w:
		var h := rng.randf_range(16, 22)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, ground), Vector2(x, ground - h), Vector2(x + 2, ground - h - 4),
			Vector2(x + 4, ground - h), Vector2(x + 4, ground)]), col)
		x += 5.0
	c.draw_line(Vector2(-10, ground - 10), Vector2(w, ground - 10), lit, 1.0)
	x = rng.randf_range(20, 80)
	while x < w:
		if rng.randf() < 0.3:
			c.draw_rect(Rect2(x, ground - 60, 2, 60), col)
			c.draw_rect(Rect2(x + 16, ground - 60, 2, 60), col)
			c.draw_rect(Rect2(x - 3, ground - 68, 24, 9), col)
			c.draw_line(Vector2(x + 9, ground - 68), Vector2(x + 9, ground - 84), col, 1.0)
			c.draw_rect(Rect2(x + 10, ground - 84, 8, 5), lit)
		else:
			var tw := rng.randf_range(20, 32)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, ground - 12), Vector2(x + tw * 0.5, ground - 12 - tw * 0.6),
				Vector2(x + tw, ground - 12)]), col)
			c.draw_line(Vector2(x, ground - 12), Vector2(x + tw * 0.5, ground - 12 - tw * 0.6), lit, 1.0)
		x += rng.randf_range(30, 70)


func _paint_far_fire(c: CanvasItem) -> void:
	var list: Array = _fires
	if _scene() == "camp":
		list = []
		var x := 60.0
		while x < span(0.3):
			list.append(x)
			x += 130.0
	for f: float in list:
		var p := Vector2(f, 262)
		var flick := 0.75 + 0.25 * sin(time * 9.0 + f) * sin(time * 5.3)
		if not P["fires"] and _scene() != "camp":
			# 月夜：远处零星几盏灯
			c.draw_rect(Rect2(p.x - 1, p.y - 14, 3, 3), Color(1.0, 0.75, 0.4, 0.8 * flick))
			c.draw_circle(p + Vector2(0, -13), 6.0, Color(0.4, 0.25, 0.08, 0.15 * flick))
			continue
		for i in range(4):
			c.draw_circle(p, 6.0 + i * 7.0, Color(0.5, 0.18, 0.04, 0.12 * flick))
		c.draw_rect(Rect2(p.x - 3, p.y - 4, 6, 4), Color(1.0, 0.55, 0.15, flick))


func _paint_crows(c: CanvasItem) -> void:
	var col := _c("front")
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
		if has_atlas():
			_piece(c, _tree_piece(t), Vector2(t[0], floor_y + 1))
		else:
			_dead_tree(c, Vector2(t[0], floor_y), t[1], t[2])
	match _scene():
		"village":
			for h in _houses_near:
				if has_atlas():
					_piece(c, _house_piece(h), Vector2(float(h[0]) + float(h[1]) * 0.5, floor_y + 1))
				else:
					_house(c, h[0], floor_y, h[1], h[2], h[3], h[4])
			_fence(c)
		"graves":
			for g in _graves:
				_near_grave(c, g[0], g[1], g[2])
		"bamboo":
			for s in _stalks:
				_stalk(c, s[0], s[1], s[2], s[3])
		"camp":
			_palisade(c)
			for t in _tents:
				_near_tent(c, t[0], t[1])


func _tree_piece(t: Array) -> String:
	var k := int(t[2]) % 3
	if mood == "fog" or mood == "night":
		return ["pine", "tree_dead", "pine"][k]
	return ["tree_dead", "tree_dead_b", "tree_dead"][k]


func _fence(c: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + seed_value
	var x := rng.randf_range(0, 100)
	var w := span(0.6)
	if has_atlas():
		while x < w:
			var n := rng.randi_range(1, 3)
			for k in range(n):
				_piece(c, "fence_b" if rng.randf() < 0.3 else "fence", Vector2(x + k * 70.0, floor_y + 1))
			x += n * 70.0 + rng.randf_range(200, 380)
		return
	var col := _c("beam").lightened(0.06)
	while x < w:
		var n := rng.randi_range(3, 7)
		for k in range(n):
			var px := x + k * 9.0
			var ph := rng.randf_range(12, 20)
			var lean := rng.randf_range(-2, 2)
			c.draw_line(Vector2(px, floor_y), Vector2(px + lean, floor_y - ph), col, 2.0)
			c.draw_rect(Rect2(px + lean - 1, floor_y - ph, 1, 1), _c("tree_rim"))
		c.draw_line(Vector2(x - 2, floor_y - 10), Vector2(x + n * 9.0 - 6.0, floor_y - 12), col, 1.0)
		x += n * 9.0 + rng.randf_range(160, 340)


func _near_grave(c: CanvasItem, x: float, kind: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var col := _c("wall")
	var lit := _c("rim")
	var dark := _c("beam")
	var y := floor_y
	match kind:
		0:   # 土坟包，插着一根木牌
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 18, y), Vector2(x - 12, y - 9), Vector2(x, y - 13),
				Vector2(x + 12, y - 9), Vector2(x + 18, y)]), dark)
			c.draw_line(Vector2(x - 12, y - 9), Vector2(x, y - 13), lit.darkened(0.4), 1.0)
			c.draw_rect(Rect2(x - 2, y - 30, 4, 20), col)
			c.draw_rect(Rect2(x - 2, y - 30, 1, 20), lit.darkened(0.2))
		1:   # 歪倒的墓碑
			var lean := rng.randf_range(-0.25, 0.25)
			c.draw_set_transform(Vector2(x, y), lean, Vector2.ONE)
			c.draw_rect(Rect2(-6, -26, 12, 26), col)
			c.draw_rect(Rect2(-6, -26, 2, 26), lit.darkened(0.2))
			c.draw_rect(Rect2(-7, -28, 14, 3), col.lightened(0.05))
			for k in range(3):
				c.draw_rect(Rect2(-1, -22 + k * 6, 2, 3), dark)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		2:   # 一排卒塔婆
			for k in range(rng.randi_range(3, 6)):
				var px := x + k * 5.0
				var h := rng.randf_range(26, 44)
				var lean := rng.randf_range(-4, 4)
				c.draw_line(Vector2(px, y), Vector2(px + lean, y - h), col, 3.0)
				c.draw_line(Vector2(px - 1, y), Vector2(px - 1 + lean, y - h), lit.darkened(0.35), 1.0)
				c.draw_colored_polygon(PackedVector2Array([Vector2(px + lean - 2, y - h), Vector2(px + lean, y - h - 4),
					Vector2(px + lean + 2, y - h)]), col)
		3:   # 五轮塔
			c.draw_rect(Rect2(x - 10, y - 12, 20, 12), col)
			c.draw_circle(Vector2(x, y - 18), 8, col)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 13, y - 24), Vector2(x, y - 34), Vector2(x + 13, y - 24)]), col)
			c.draw_circle(Vector2(x, y - 38), 4, col)
			c.draw_rect(Rect2(x - 10, y - 12, 2, 12), lit.darkened(0.2))
			c.draw_line(Vector2(x - 13, y - 24), Vector2(x, y - 34), lit.darkened(0.3), 1.0)


func _stalk(c: CanvasItem, x: float, h: float, thick: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var col := _c("wall_lit")
	var dark := _c("wall")
	var lit := _c("rim").darkened(0.35)
	var sway := sin(time * 1.1 + x * 0.03) * 3.0
	var top := Vector2(x + sway, floor_y - h)
	c.draw_line(Vector2(x, floor_y), top, dark, float(thick))
	c.draw_line(Vector2(x - thick * 0.5 + 1, floor_y), top + Vector2(-thick * 0.5 + 1, 0), lit, 1.0)
	var y := floor_y - rng.randf_range(10, 30)
	while y > floor_y - h:
		var k := (floor_y - y) / h
		c.draw_rect(Rect2(x + sway * k - thick * 0.5 - 1, y, thick + 2, 2), col)
		y -= rng.randf_range(26, 40)
	for i in range(rng.randi_range(2, 4)):
		var ly := floor_y - h * rng.randf_range(0.5, 1.0)
		var k := (floor_y - ly) / h
		var lx := x + sway * k
		var d := -1.0 if rng.randf() < 0.5 else 1.0
		for j in range(3):
			c.draw_colored_polygon(PackedVector2Array([Vector2(lx, ly + j * 3), Vector2(lx + d * (18 - j * 3), ly + 6 + j * 4),
				Vector2(lx + d * 4, ly + 4 + j * 3)]), col if j == 0 else dark)


func _palisade(c: CanvasItem) -> void:
	var w := span(0.6)
	var col := _c("wall")
	var lit := _c("rim").darkened(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 171 + seed_value
	var x := -10.0
	while x < w:
		var h := rng.randf_range(40, 54)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, floor_y), Vector2(x, floor_y - h), Vector2(x + 3, floor_y - h - 6),
			Vector2(x + 6, floor_y - h), Vector2(x + 6, floor_y)]), col)
		c.draw_line(Vector2(x, floor_y), Vector2(x, floor_y - h), lit, 1.0)
		x += 7.0
	c.draw_rect(Rect2(-10, floor_y - 30, w + 10, 3), _c("beam"))
	c.draw_rect(Rect2(-10, floor_y - 14, w + 10, 3), _c("beam"))
	# 栅栏上挂着的红旗
	x = rng.randf_range(80, 200)
	while x < w:
		c.draw_line(Vector2(x, floor_y - 50), Vector2(x, floor_y - 92), _c("beam"), 2.0)
		var wave := sin(time * 3.0 + x) * 2.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 1, floor_y - 92), Vector2(x + 20, floor_y - 90 + wave),
			Vector2(x + 18, floor_y - 76 + wave), Vector2(x + 1, floor_y - 78)]), Color("7a1c18"))
		x += rng.randf_range(220, 380)


func _near_tent(c: CanvasItem, x: float, w: float) -> void:
	var col := _c("wall_lit")
	var dark := _c("beam")
	var y := floor_y
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, y), Vector2(x, y - w * 0.62), Vector2(x + w * 0.5, y)]), col)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 9, y), Vector2(x, y - w * 0.4), Vector2(x + 9, y)]), dark)
	c.draw_line(Vector2(x - w * 0.5, y), Vector2(x, y - w * 0.62), _c("rim").darkened(0.2), 1.0)
	c.draw_line(Vector2(x, y - w * 0.62), Vector2(x, y - w * 0.62 - 10), dark, 2.0)
	c.draw_line(Vector2(x + w * 0.5, y), Vector2(x + w * 0.5 + 12, y - 8), dark, 1.0)


func _house(c: CanvasItem, x: float, base: float, w: float, h: float, broken: bool, burning: bool) -> void:
	var wall := _c("wall")
	var wall_lit := _c("wall_lit")
	var beam := _c("beam")
	var roof := _c("roof")
	var roof_lit := _c("roof_lit")
	var rim := _c("rim")
	c.draw_rect(Rect2(x, base - h, w, h), wall)
	c.draw_rect(Rect2(x, base - h, 3, h), wall_lit)
	c.draw_rect(Rect2(x, base - h, 1, h), rim)
	for k in range(4):
		c.draw_rect(Rect2(x + roundf(w * k / 3.0) - 1, base - h, 3, h), beam)
	c.draw_rect(Rect2(x, base - h * 0.55, w, 2), beam)
	var door := Rect2(x + w * 0.38, base - h * 0.7, w * 0.2, h * 0.7)
	c.draw_rect(door, _c("win"))
	var win := Rect2(x + w * 0.72, base - h * 0.85, 10, 8)
	if burning:
		var flick := 0.7 + 0.3 * sin(time * 11.0 + x) * sin(time * 6.0)
		c.draw_rect(win, Color(1.0, 0.55, 0.2, flick))
		c.draw_rect(Rect2(door.position + Vector2(0, door.size.y * 0.5), door.size * Vector2(1, 0.5)), Color(0.9, 0.35, 0.12, flick * 0.8))
	elif P.get("lamps", false) and int(x) % 3 == 0:
		c.draw_rect(win, Color(0.95, 0.7, 0.35, 0.85))
	else:
		c.draw_rect(win, _c("win"))
	c.draw_line(win.position + Vector2(5, 0), win.position + Vector2(5, 8), beam, 1.0)
	var top := base - h
	var pts := PackedVector2Array([Vector2(x - 10, top + 4), Vector2(x + w * 0.5, top - 26), Vector2(x + w + 10, top + 4)])
	if broken:
		pts = PackedVector2Array([Vector2(x - 10, top + 4), Vector2(x + w * 0.3, top - 18), Vector2(x + w * 0.42, top - 8),
			Vector2(x + w * 0.55, top - 16), Vector2(x + w * 0.62, top - 4), Vector2(x + w + 10, top + 4)])
	c.draw_colored_polygon(pts, roof)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x)
	for k in range(int(w / 3.0)):
		var px := x - 6 + k * 3.0 + rng.randf_range(0, 2)
		var py := top + 2 - rng.randf_range(0, 12)
		if Geometry2D.is_point_in_polygon(Vector2(px, py), pts):
			c.draw_line(Vector2(px, py), Vector2(px + 1, py + 4), roof.darkened(0.25), 1.0)
	c.draw_line(pts[0], pts[1], roof_lit, 2.0)
	c.draw_line(pts[0] + Vector2(0, 1), pts[pts.size() - 1] + Vector2(0, 1), beam.darkened(0.2), 2.0)
	if broken:
		c.draw_line(Vector2(x + w * 0.42, top - 8), Vector2(x + w * 0.5, top - 26), beam, 2.0)
		c.draw_line(Vector2(x + w * 0.5, top - 26), Vector2(x + w * 0.58, top - 12), beam, 2.0)


func _dead_tree(c: CanvasItem, at: Vector2, h: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var col := _c("tree")
	c.draw_line(at, at + Vector2(2, -h * 0.5), col, 5.0)
	c.draw_line(at + Vector2(2, -h * 0.5), at + Vector2(-2, -h), col, 3.0)
	c.draw_line(at + Vector2(-2, 0), at + Vector2(-1, -h * 0.6), _c("tree_rim"), 1.0)
	_branch(c, at + Vector2(2, -h * 0.5), -0.6, h * 0.45, 3, rng, col)
	_branch(c, at + Vector2(0, -h * 0.75), 0.7, h * 0.4, 3, rng, col)
	_branch(c, at + Vector2(-2, -h), -0.1, h * 0.3, 2, rng, col)
	if mood == "graves" and seed_v % 2 == 0:
		# 树上吊着的破纸灯，幽幽发绿
		var p := at + Vector2(h * 0.25, -h * 0.72)
		c.draw_line(p, p + Vector2(0, 10), col, 1.0)
		c.draw_rect(Rect2(p.x - 3, p.y + 10, 6, 8), Color("3a5a44"))


func _branch(c: CanvasItem, from: Vector2, angle: float, length: float, depth: int, rng: RandomNumberGenerator, col: Color) -> void:
	if depth <= 0 or length < 4.0:
		return
	var to := from + Vector2(sin(angle), -cos(angle)) * length
	c.draw_line(from, to, col, maxf(1.0, depth * 0.8))
	_branch(c, to, angle + rng.randf_range(-0.7, -0.2), length * 0.6, depth - 1, rng, col)
	_branch(c, to, angle + rng.randf_range(0.2, 0.7), length * 0.55, depth - 1, rng, col)


func _paint_near_glow(c: CanvasItem) -> void:
	if has_atlas() and _scene() == "village":
		_paint_windows(c)
	for h in _houses_near:
		if not h[4]:
			continue
		var x: float = h[0]
		var w: float = h[1]
		var flick := 0.8 + 0.2 * sin(time * 11.0 + x) * sin(time * 6.0)
		var p := Vector2(x + w * 0.6, floor_y - 24)
		for i in range(5):
			c.draw_circle(p, 10.0 + i * 10.0, Color(0.45, 0.16, 0.04, 0.08 * flick))
	if mood == "graves":
		for t in _trees:
			if int(t[2]) % 2 == 0:
				var p := Vector2(t[0], floor_y) + Vector2(float(t[1]) * 0.25, -float(t[1]) * 0.72 + 14)
				var flick := 0.8 + 0.2 * sin(time * 3.0 + p.x)
				for i in range(4):
					c.draw_circle(p, 4.0 + i * 6.0, Color(0.15, 0.4, 0.22, 0.09 * flick))
	if _scene() == "camp":
		for t in _tents:
			var flick := 0.8 + 0.2 * sin(time * 9.0 + float(t[0])) * sin(time * 4.0)
			var p := Vector2(float(t[0]) + float(t[1]) * 0.7, floor_y - 6)
			for i in range(5):
				c.draw_circle(p, 8.0 + i * 9.0, Color(0.45, 0.14, 0.03, 0.08 * flick))
			c.draw_rect(Rect2(p.x - 3, p.y - 3, 6, 4), Color(1.0, 0.55, 0.2, flick))


## 近景房子窗里的光：着火的屋子窗里是跳动的火光，月夜零星几户点着灯，纸拉门透一层暖光
func _paint_windows(c: CanvasItem) -> void:
	for h in _houses_near:
		var name := _house_piece(h)
		var o: Array = _pmeta[name]["origin"]
		var base := Vector2(roundf(float(h[0]) + float(h[1]) * 0.5) - o[0], floor_y + 1 - o[1])
		var x: float = h[0]
		var lamp: bool = P.get("lamps", false) and int(x) % 3 != 1
		if not h[4] and not lamp:
			continue
		var flick := 0.75 + 0.25 * sin(time * 11.0 + x) * sin(time * 6.0 + x * 0.3)
		if not h[4]:
			flick = 0.92 + 0.08 * sin(time * 2.0 + x)
		var col := Color(1.0, 0.5, 0.16) if h[4] else Color(1.0, 0.72, 0.36)
		for wv: Array in _pmeta[name]["windows"]:
			var r := Rect2(base + Vector2(wv[0], wv[1]), Vector2(wv[2], wv[3]))
			var paper := wv.size() > 4
			var a := (0.28 if paper else 0.55) * flick
			c.draw_rect(r, Color(col, a))
			if not paper:
				c.draw_rect(r.grow(-1), Color(col, a * 0.6))
			var ctr := r.get_center()
			for i in range(3):
				c.draw_circle(ctr, r.size.length() * 0.5 + 4.0 + i * 6.0, Color(col * 0.45, 0.06 * flick))


# ---------- 地面 ----------

func _paint_ground(c: CanvasItem) -> void:
	if has_atlas():
		_paint_ground_tiles(c)
		return
	var w := arena_w + 200.0
	c.draw_rect(Rect2(-100, floor_y, w, VIEW_H - floor_y + 40), _c("ground"))
	c.draw_rect(Rect2(-100, floor_y, w, 3), _c("ground_top"))
	c.draw_rect(Rect2(-100, floor_y, w, 1), _c("ground_lip"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 81 + seed_value
	var sa := Color(P["stone"][0])
	var sb := Color(P["stone"][1])
	for row in range(4):
		var y := floor_y + 6 + row * 10
		var shade := 1.0 - row * 0.2
		for i in range(int(w / 26.0)):
			var x := -100 + i * 26 + rng.randi_range(0, 18)
			var col := sa.lerp(sb, rng.randf()) * Color(shade, shade, shade)
			c.draw_rect(Rect2(x, y + rng.randi_range(-2, 2), rng.randi_range(3, 9), 2), col)
			if rng.randf() < 0.25:
				c.draw_rect(Rect2(x + 4, y - 3, 2, 1), col.lightened(0.2))
	var seam := _c("ground").darkened(0.35)
	c.draw_rect(Rect2(-100, floor_y + 12, w, 1), seam)
	c.draw_rect(Rect2(-100, floor_y + 26, w, 1), seam)
	var ga := Color(P["grass"][0])
	var gb := Color(P["grass"][1])
	for i in range(int(w / 6.0)):
		var x := rng.randi_range(-100, int(arena_w + 100))
		var hh := rng.randi_range(2, 8)
		c.draw_line(Vector2(x, floor_y + 1), Vector2(x + rng.randi_range(-2, 2), floor_y - hh), ga if i % 3 else gb, 1.0)
	if mood == "bamboo":
		# 竹叶落了一地
		for i in range(int(w / 14.0)):
			var x := rng.randi_range(-100, int(arena_w + 100))
			c.draw_rect(Rect2(x, floor_y + rng.randi_range(1, 4), rng.randi_range(3, 5), 1), gb.darkened(0.2))


func _paint_ground_tiles(c: CanvasItem) -> void:
	var r: Array = _pieces["ground"]["rect"]
	var o: Array = _pmeta["ground"]["origin"]
	var x := -128.0
	var src := Rect2(r[0], r[1], r[2], r[3])
	while x < arena_w + 200.0:
		c.draw_texture_rect_region(_tex, Rect2(x, floor_y - o[1], r[2], r[3]), src)
		x += float(r[2])
	var bottom := floor_y - float(o[1]) + float(r[3])
	if bottom < VIEW_H + 40.0:
		c.draw_rect(Rect2(-128, bottom, arena_w + 400, VIEW_H + 40 - bottom), Color(P["front"]))
	for d in _decals:
		_piece(c, d[0], Vector2(d[1], floor_y + 1))
	if mood == "bamboo":
		var rng := RandomNumberGenerator.new()
		rng.seed = 83 + seed_value
		var gb := Color(P["grass"][1])
		for i in range(int(arena_w / 14.0)):
			var lx := rng.randi_range(-100, int(arena_w + 100))
			c.draw_rect(Rect2(lx, floor_y + rng.randi_range(1, 4), rng.randi_range(3, 5), 1), gb.darkened(0.2))


# ---------- 前景 ----------

func _paint_motes(c: CanvasItem) -> void:
	match String(P["motes"]):
		"ember":
			for e in _motes:
				var b := 0.5 + 0.5 * sin(e.z * 2.0)
				var p := Vector2(e.x, e.y).round()
				c.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.55, 0.2, b))
				c.draw_circle(p, 2.0, Color(0.5, 0.18, 0.05, 0.2 * b))
		"firefly":
			for e in _motes:
				var b := maxf(0.0, sin(e.z * 1.7))
				var p := Vector2(e.x, e.y).round()
				c.draw_rect(Rect2(p, Vector2(1, 1)), Color(0.85, 1.0, 0.5, b))
				c.draw_circle(p, 3.0, Color(0.3, 0.45, 0.1, 0.25 * b))
		"wisp":
			# 鬼火：一团青绿的光，拖着尾巴飘
			for e in _motes:
				var b := 0.6 + 0.4 * sin(e.z * 2.3)
				var p := Vector2(e.x, e.y).round()
				for k in range(4):
					c.draw_circle(p - Vector2(k * 3.0, -k * 1.0), 3.0 - k * 0.6, Color(0.3, 0.9, 0.6, 0.35 * b * (1.0 - k * 0.22)))
				for i in range(3):
					c.draw_circle(p, 6.0 + i * 5.0, Color(0.1, 0.35, 0.22, 0.08 * b))


func _paint_fall(c: CanvasItem) -> void:
	if P["fall"] == "leaf":
		var col := Color(P["grass"][1]) if mood != "fog" else Color("8a6a3a")
		for a in _fall:
			var p := Vector2(a.x, a.y).round()
			if sin(a.z) > 0.0:
				c.draw_rect(Rect2(p, Vector2(3, 1)), col)
			else:
				c.draw_rect(Rect2(p, Vector2(1, 2)), col.darkened(0.2))
	else:
		for a in _fall:
			c.draw_rect(Rect2(Vector2(a.x, a.y).round(), Vector2(1 + int(sin(a.z) > 0.3), 1)), Color(0.55, 0.5, 0.5, 0.6))


func _paint_haze(c: CanvasItem) -> void:
	var col: Color = P["haze"]
	var thick := float(P.get("fog", 1.0))
	for i in range(int(3 * thick)):
		var x := fmod(time * (5.0 + i * 3.0), 320.0) - 320.0
		var y := floor_y - 8 - i * 5 * (1.6 if thick > 1.0 else 1.0)
		while x < arena_w + 100.0:
			c.draw_rect(Rect2(x, y, 200, 7 + i * 2), col)
			x += 320.0
	if thick >= 3.0:
		# 雾田：整片画面都蒙上一层
		c.draw_rect(Rect2(-100, 0, arena_w + 200, floor_y), Color(col, 0.06))


func _paint_front(c: CanvasItem) -> void:
	var col := _c("front")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + seed_value
	var x := -40.0
	var clumps := ["front_a", "front_b", "front_c"]
	while x < span(1.3) + 200.0:
		if has_atlas():
			_piece(c, clumps[rng.randi() % 3], Vector2(x + rng.randf_range(-40, 60), VIEW_H + rng.randf_range(2, 14)))
		for i in range(0 if has_atlas() else 12):
			var gx := x + rng.randf_range(-40, 60)
			var h := rng.randf_range(12, 34)
			var lean := rng.randf_range(-9, 9)
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(gx - 3, VIEW_H), Vector2(gx + 3, VIEW_H), Vector2(gx + lean, VIEW_H - h),
			]), col)
		if mood == "bamboo" and rng.randf() < 0.6:
			# 镜头前一根粗竹子
			var px := x + rng.randf_range(0, 60)
			c.draw_line(Vector2(px, VIEW_H), Vector2(px + 4, -10), col, 9.0)
		elif mood == "graves" and rng.randf() < 0.5:
			var px := x + rng.randf_range(0, 60)
			c.draw_rect(Rect2(px - 7, VIEW_H - 40, 14, 40), col)
		elif rng.randf() < 0.5:
			var px := x + rng.randf_range(0, 60)
			c.draw_line(Vector2(px, VIEW_H), Vector2(px + rng.randf_range(-10, 10), VIEW_H - rng.randf_range(40, 60)), col, 5.0)
		x += rng.randf_range(380, 620)
