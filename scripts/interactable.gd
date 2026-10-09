class_name Interactable
extends Node2D
## 房间里能按「下」互动的东西：出口的门、商人的货、土地庙的香炉、地上的装备、破庙的拾骨婆和兵器架。
## 主场景每帧把离玩家最近的一个设成 highlight，按「下」时调用 main.interact()。

const RANGE := 26.0

var kind := "door"          # door 门 / item 货物 / rest 土地庙 / chest 宝箱 / note 遗骸 / gear 装备 / talent 天赋 / rack 兵器架 / codex 招式谱
var label := ""             # 头上的字
var sub := ""               # 小字（价格、说明）
var icon := ""              # 图标：门是房间类型，货物是货物 id
var color := Color(1, 1, 1)
var enabled := true         # 门锁着、货卖完了就是 false
var used := false
var data: Dictionary = {}
var highlight := false
var time := 0.0
var _open_t := 1.0          # 门打开的动画


func set_enabled(v: bool) -> void:
	if v and not enabled:
		_open_t = 0.0
	enabled = v


func prompt() -> String:
	match kind:
		"door": return "↓ 进入" if enabled else "清完敌人才能走"
		"item": return "↓ 购买" if enabled else "卖完了"
		"rest": return "↓ 上香" if enabled else "香已经点上了"
		"talent": return "↓ 点天赋"
		"rack": return "↓ 换出发武器"
		"codex": return "↓ 翻招式谱"
		"gear":
			var price := int(data.get("price", 0))
			return "↓ 买下换上 · %d 铜钱" % price if price > 0 else "↓ 换上"
		"chest": return "↓ 打开" if enabled else "空了"
		"note": return "↓ 查看"
	return "↓"


func _process(delta: float) -> void:
	time += delta
	z_index = 4 if highlight else 2   # 走近的那个字盖在别的上面
	_open_t = minf(_open_t + delta * 1.5, 1.0)
	queue_redraw()


func _draw() -> void:
	match kind:
		"door": _draw_door()
		"item": _draw_item()
		"gear": _draw_gear()
		"rack": _draw_rack()
		"codex": _draw_codex()
		"rest": _draw_shrine()
		"chest": _draw_chest()
		"note": _draw_note()
	var font: Font = Game.font
	# 门：字在门匾上面；货物、供台：平时只显示名字，走近了才显示说明和价格
	var top := -100.0 if kind == "door" else -40.0
	if kind == "rest":
		top = -60.0
	elif kind == "chest" or kind == "note":
		top = -30.0
	elif kind == "talent":
		top = -86.0
	elif kind == "rack" or kind == "codex":
		top = -62.0
	var a := 1.0 if highlight else 0.75
	var show_sub := sub != "" and (highlight or kind == "door" or kind == "rest") and kind != "gear"
	if highlight:
		var w := maxf(font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x,
			font.get_string_size(prompt(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 12.0
		draw_rect(Rect2(-w / 2.0, top - 28, w, 46 if show_sub else 32).abs(), Color(0.02, 0.01, 0.03, 0.6))
	_label(font, label, Vector2(0, top), Color(color.lightened(0.25), a))
	if show_sub:
		_label(font, sub, Vector2(0, top + 13), Color(0.85, 0.82, 0.78, a * 0.9))
	if highlight:
		var bob := roundf(sin(time * 5.0) * 1.0)
		_label(font, prompt(), Vector2(0, top - 15 + bob), Color(1.0, 0.95, 0.75) if enabled else Color(0.75, 0.7, 0.72))


func _label(font: Font, s: String, at: Vector2, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var p := (at - Vector2(w / 2.0, 0)).round()
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 2, Color(0, 0, 0, col.a * 0.9))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


# ---------- 门 ----------

func _draw_door() -> void:
	var post := Color("2a1418")
	var post_lit := Color("8a2e26") if icon != "boss" else Color("3a4a7a")
	var wood := Color("6e2a22") if icon != "boss" else Color("2a3458")
	var hw := 22.0
	var h := 62.0
	# 门里面：开着是暖光，锁着是黑的
	var inner := Rect2(-hw + 4, -h + 10, hw * 2 - 8, h - 10)
	var glow := color if enabled else Color(0.1, 0.08, 0.1)
	var k := _open_t if enabled else 1.0
	for i in range(6):
		var t := float(i) / 5.0
		var col := Color(0.04, 0.03, 0.05).lerp(glow.darkened(0.3), (1.0 - t) * (0.55 if enabled else 0.1) * k)
		draw_rect(Rect2(inner.position.x, inner.position.y + t * inner.size.y * 0.8, inner.size.x, inner.size.y * (1.0 - t * 0.8)), col)
	if enabled:
		# 地上往外漏的光、往上飘的光点
		for i in range(3):
			draw_rect(Rect2(-hw + 2 - i * 4, -2, hw * 2 - 4 + i * 8, 2), Color(glow, 0.12 * k))
		for i in range(5):
			var t := fmod(time * 0.5 + i * 0.2, 1.0)
			var p := Vector2(sin(i * 2.3 + time) * 10.0, -6.0 - t * 46.0).round()
			draw_rect(Rect2(p, Vector2(1, 1)), Color(glow.lightened(0.4), (1.0 - t) * k))
	# 两根柱子 + 上面两道横梁（鸟居）
	for s in [-1.0, 1.0]:
		draw_rect(Rect2(s * hw - 3, -h, 6, h), Color("0c080a"))
		draw_rect(Rect2(s * hw - 2, -h, 4, h), post)
		draw_rect(Rect2(s * hw - 2, -h, 1, h), post_lit)
	draw_rect(Rect2(-hw - 9, -h - 6, hw * 2 + 18, 6), Color("0c080a"))
	draw_rect(Rect2(-hw - 8, -h - 5, hw * 2 + 16, 4), wood)
	draw_rect(Rect2(-hw - 8, -h - 5, hw * 2 + 16, 1), post_lit.lightened(0.2))
	draw_rect(Rect2(-hw - 11, -h - 8, 4, 3), wood)
	draw_rect(Rect2(hw + 7, -h - 8, 4, 3), wood)
	draw_rect(Rect2(-hw, -h + 4, hw * 2, 3), post)
	# 注连绳和纸垂
	var rope := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		rope.append(Vector2(-hw + t * hw * 2, -h + 9 + sin(t * PI) * 4.0).round())
	draw_polyline(rope, Color("c8b07a"), 2.0)
	for i in [2, 4, 6]:
		var p: Vector2 = rope[i]
		var sw := roundf(sin(time * 2.0 + i) * 1.0)
		draw_rect(Rect2(p.x - 1 + sw, p.y + 1, 2, 6), Color("e8e2d2"))
	if not enabled:
		# 锁着：两块木板钉成叉
		draw_line(Vector2(-hw + 3, -h + 14), Vector2(hw - 3, -6), Color("3a2418"), 4.0)
		draw_line(Vector2(hw - 3, -h + 14), Vector2(-hw + 3, -6), Color("3a2418"), 4.0)
		draw_line(Vector2(-hw + 3, -h + 13), Vector2(hw - 3, -7), Color("5a3a26"), 1.0)
	# 门匾上的图标
	var plaque := Rect2(-9, -h - 22, 18, 15)
	draw_rect(plaque.grow(1), Color("0c080a"))
	draw_rect(plaque, Color("1c1418"))
	draw_rect(plaque, Color(color, 0.6 if enabled else 0.25), false, 1.0)
	Icons.draw(self, icon, plaque.get_center(), color if enabled else color.darkened(0.5))


# ---------- 货物、供台 ----------

func _draw_item() -> void:
	var base := Color("3a2a26") if kind == "item" else Color("3a3440")
	# 摊子：草席或石台
	if kind == "item":
		draw_rect(Rect2(-14, -3, 28, 3), Color("0c080a"))
		draw_rect(Rect2(-13, -3, 26, 2), Color("8a7448"))
		for i in range(6):
			draw_rect(Rect2(-12 + i * 5, -3, 1, 2), Color("6a5636"))
	else:
		draw_rect(Rect2(-12, -16, 24, 16), Color("0c080a"))
		draw_rect(Rect2(-11, -15, 22, 15), base)
		draw_rect(Rect2(-11, -15, 22, 1), base.lightened(0.3))
		draw_rect(Rect2(-14, -18, 28, 3), base.lightened(0.15))
	var y := -10.0 if kind == "item" else -26.0
	var bob := roundf(sin(time * 2.5 + position.x) * 1.5)
	var c := Vector2(0, y + bob)
	if enabled:
		for i in range(3):
			draw_circle(c, 6.0 + i * 3.0, Color(color, 0.06))
	Icons.draw(self, icon, c, color if enabled else Color(0.35, 0.32, 0.35))


# ---------- 地上的装备 ----------

func _draw_gear() -> void:
	var q := int(data["item"]["q"])
	var pulse := 0.6 + 0.4 * sin(time * 3.0 + position.x)
	# 品质越高光柱越高
	if q >= 1:
		var h := 22.0 + q * 12.0
		for i in range(6):
			var t := float(i) / 6.0
			draw_rect(Rect2(-3 + t * 1.0, -h * (1.0 - t) - 4, 6 - t * 2.0, h * (1.0 - t)), Color(color, 0.05 * pulse))
		draw_rect(Rect2(-0.5, -h - 4, 1, h), Color(color.lightened(0.3), 0.18 * pulse))
	# 落地的一圈光、往上飘的光点
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 10.0, Color(color, 0.18 * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(2 + q):
		var t := fmod(time * 0.6 + i * 0.37, 1.0)
		var at := Vector2(sin(i * 2.1 + time) * 6.0, -4.0 - t * (18.0 + q * 6.0)).round()
		draw_rect(Rect2(at, Vector2(1, 1)), Color(color.lightened(0.4), (1.0 - t) * 0.8))
	var bob := roundf(sin(time * 2.5 + position.x) * 1.5)
	Icons.draw(self, icon, Vector2(0, -9 + bob), color)


# ---------- 兵器架 ----------

func _draw_rack() -> void:
	var o := Color("0c080a")
	var wood := Color("5a3a24")
	var lit := Color("8a5a36")
	for x in [-26.0, 24.0]:
		draw_rect(Rect2(x - 1, -46, 4, 46), o)
		draw_rect(Rect2(x, -45, 2, 45), wood)
		draw_rect(Rect2(x, -45, 1, 45), lit)
	for y in [-42.0, -22.0]:
		draw_rect(Rect2(-28, y - 1, 56, 4), o)
		draw_rect(Rect2(-27, y, 54, 2), wood)
		draw_rect(Rect2(-27, y, 54, 1), lit)
	draw_rect(Rect2(-30, -2, 60, 2), o)
	# 架子上挂着解锁的武器，出发要带的那把发光
	var ids: Array = GearData.WEAPONS.keys()
	var have: Array = Game.save["weapons"]
	for i in range(ids.size()):
		var id: String = ids[i]
		var at := Vector2(-20 + i * 10, -30)
		if not have.has(id):
			draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 12)), Color(0.15, 0.12, 0.14))
			continue
		var cur: bool = id == data.get("weapon", "")
		if cur:
			for k in range(3):
				draw_circle(at, 6.0 + k * 3.0, Color(1.0, 0.85, 0.4, 0.06 + 0.03 * sin(time * 3.0)))
		draw_set_transform(at, -PI / 2.0, Vector2.ONE)
		Icons.draw(self, "w_" + id, Vector2.ZERO, Color(1, 1, 1) if cur else Color(0.6, 0.58, 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- 招式谱 ----------

## 经案上摊着一卷谱，谱上加进掉落池的招式越多，上面的字越多
func _draw_codex() -> void:
	var o := Color("0c080a")
	var wood := Color("5a3a24")
	var lit := Color("8a5a36")
	# 案腿和案面
	for x in [-16.0, 14.0]:
		draw_rect(Rect2(x - 1, -26, 4, 26), o)
		draw_rect(Rect2(x, -25, 2, 25), wood)
	draw_rect(Rect2(-22, -30, 44, 6), o)
	draw_rect(Rect2(-21, -29, 42, 4), wood)
	draw_rect(Rect2(-21, -29, 42, 1), lit)
	# 摊开的卷轴，两头卷着
	draw_rect(Rect2(-17, -38, 34, 9), o)
	draw_rect(Rect2(-16, -37, 32, 7), Color("d8ccae"))
	for x in [-18.0, 16.0]:
		draw_rect(Rect2(x - 1, -39, 4, 11), o)
		draw_rect(Rect2(x, -38, 2, 9), Color("8a5a36"))
	var n := 0
	for id: String in Arts.ARTS:
		if Arts.in_pool("art", id):
			n += 1
	for id: String in Arts.MINDS:
		if Arts.in_pool("mind", id):
			n += 1
	for i in range(n):
		draw_rect(Rect2(-14 + i * 2.5, -36 + (i % 2), 1, 4), Color("3a2a20"))
	# 微微的光
	draw_circle(Vector2(0, -34), 10.0, Color(1.0, 0.85, 0.5, 0.05 + 0.03 * sin(time * 2.5)))


# ---------- 土地庙 ----------

func _draw_shrine() -> void:
	var stone := Color("4a4450")
	var dark := Color("2a2630")
	var o := Color("0c080a")
	draw_rect(Rect2(-18, -6, 36, 6), o)
	draw_rect(Rect2(-17, -5, 34, 5), dark)
	draw_rect(Rect2(-13, -34, 26, 29), o)
	draw_rect(Rect2(-12, -33, 24, 28), stone)
	draw_rect(Rect2(-12, -33, 2, 28), stone.lightened(0.2))
	draw_rect(Rect2(-7, -28, 14, 18), Color("120e14"))
	# 里面的小土地公
	draw_circle(Vector2(0, -20), 3, Color("8a7a62"))
	draw_rect(Rect2(-3, -17, 6, 6), Color("7a3a2a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-19, -33), Vector2(19, -33), Vector2(13, -42), Vector2(-13, -42)]), o)
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -34), Vector2(17, -34), Vector2(12, -41), Vector2(-12, -41)]), Color("5a2a26"))
	draw_line(Vector2(-17, -34), Vector2(-12, -41), Color("9a4a3a"), 1.0)
	# 香炉
	draw_rect(Rect2(-6, -6, 12, 6), Color("6a5a3a"))
	draw_rect(Rect2(-7, -7, 14, 2), Color("9a8a5a"))
	if used:
		# 三炷香，烟往上飘
		for i in range(3):
			var x := -3.0 + i * 3.0
			draw_line(Vector2(x, -7), Vector2(x, -15), Color("8a4a2a"), 1.0)
			draw_rect(Rect2(x, -16, 1, 1), Color(1.0, 0.5, 0.2))
			for k in range(6):
				var t := fmod(time * 0.4 + k / 6.0 + i * 0.3, 1.0)
				var p := Vector2(x + sin(t * 8.0 + i) * 3.0 * t, -17.0 - t * 34.0).round()
				draw_rect(Rect2(p, Vector2(1, 1)), Color(0.75, 0.75, 0.8, 0.5 * (1.0 - t)))
	elif enabled:
		for i in range(3):
			draw_circle(Vector2(0, -20), 10.0 + i * 5.0, Color(color, 0.05 + 0.03 * sin(time * 3.0)))


# ---------- 宝箱、遗骸 ----------

func _draw_chest() -> void:
	var o := Color("0c080a")
	var wood := Color("6a3a24")
	var trim := Color("c9a24a")
	draw_rect(Rect2(-12, -13, 24, 13), o)
	draw_rect(Rect2(-11, -12, 22, 12), wood)
	draw_rect(Rect2(-11, -12, 22, 1), wood.lightened(0.25))
	if used:
		# 打开了：盖子往后翻，里面空的
		draw_rect(Rect2(-12, -22, 24, 6), o)
		draw_rect(Rect2(-11, -21, 22, 4), wood.darkened(0.2))
		draw_rect(Rect2(-10, -12, 20, 3), Color("1a0e0a"))
	else:
		draw_rect(Rect2(-12, -18, 24, 7), o)
		draw_rect(Rect2(-11, -17, 22, 6), wood.lightened(0.1))
		draw_rect(Rect2(-11, -17, 22, 1), wood.lightened(0.35))
		var glint := 0.6 + 0.4 * sin(time * 3.0)
		for i in range(3):
			draw_circle(Vector2(0, -10), 8.0 + i * 5.0, Color(1.0, 0.8, 0.3, 0.04 * glint))
	for x in [-9, 7]:
		draw_rect(Rect2(x, -17 if not used else -12, 2, 17 if not used else 12), trim.darkened(0.2))
	draw_rect(Rect2(-2, -12, 4, 4), trim)
	draw_rect(Rect2(-1, -11, 2, 2), o)


func _draw_note() -> void:
	var o := Color("0c080a")
	# 靠着石头坐着的遗骸：斗笠、破衣服、插在地上的刀、手边一卷纸
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-10, -12), Vector2(4, -14), Vector2(10, 0)]), Color("2a2430"))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-6, -14), Vector2(2, -16), Vector2(5, 0)]), Color("4a3a36"))
	draw_circle(Vector2(-2, -18), 4, Color("c8bca8"))
	draw_rect(Rect2(-4, -19, 1, 1), o)
	draw_rect(Rect2(-1, -19, 1, 1), o)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -20), Vector2(6, -20), Vector2(-2, -26)]), Color("8a7a4a"))
	draw_line(Vector2(12, 0), Vector2(15, -24), Color("9a9aa4"), 1.0)
	draw_rect(Rect2(13, -28, 5, 2), Color("3a2a22"))
	draw_rect(Rect2(6, -4, 7, 3), Color("e0d4b8"))
	draw_rect(Rect2(6, -4, 1, 3), Color("a8946a"))
	if not used:
		var b := 0.5 + 0.5 * sin(time * 3.0)
		draw_rect(Rect2(9, -9 - roundf(b * 2.0), 1, 1), Color(1.0, 0.95, 0.7, b))
