class_name RoomFeatures
extends Node2D
## 房间里的跑酷和解谜机关。房间数据里的 features 每条一种：
##
## 跑酷：
##   ["pit", x0, x1]                  地上的坑，坑底插着竹签。掉下去扣 15% 生命，回到坑边站稳的地方；敌人掉下去就死
##   ["spikes", x0, x1]               地上一排竹签，踩上去扣血、被弹起来
##   ["plank", x, 高度, 宽]           烂木板（单向平台）：站上去 0.45 秒就塌，3 秒后有人重新搭好
##   ["ledge", x, 高度, 宽]           结实的木架子（单向平台），坑上落脚用
## 解谜：
##   ["gate", x, id]                  寨门：一堵木墙中间一道门，门没开过不去，跳也跳不过
##   ["lever", x, id, 高度, 秒数]      拉杆：砍一刀扳下去，打开同 id 的门；秒数 > 0 时过这么久门自己落下，得跑着过去
##   ["lantern", x, id, 高度]          石灯笼：砍一刀点亮，8 秒后熄灭；同 id 的灯笼同时亮着，同 id 的门就开了，灯也不再灭
##   ["crack", x]                     裂了的土墙：砍三刀砸开，后面往往藏着宝箱
##
## 坐标：x 是世界坐标，高度是离地面的高度（平台顶边）。

const PIT_DMG := 0.15
const SPIKE_DMG := 0.08
const PLANK_DELAY := 0.45
const PLANK_BACK := 3.0
const LANTERN_TIME := 8.0
const CRACK_HP := 3
const WALL_H := 190.0           # 寨门、土墙画多高（跳不过去：二段跳最高约 165）
const DOOR_H := 74.0            # 门洞多高
const PIT_FALL := 60.0          # 掉到地面以下这么深算掉进坑里

var main: Node
var floor_y := 300.0
var arena_w := 800.0
var features: Array = []
var time := 0.0

var pits: Array = []            # [x0, x1]
var spikes: Array = []          # [x0, x1]
var planks: Array = []          # {x, top, w, crumble, shape, t, down, fall}
var gates: Array = []           # {x, id, shape, open, opened, close_t, timed}
var levers: Array = []          # {x, y, id, secs, on, cd}
var lanterns: Array = []        # {x, y, id, lit, done, cd}
var cracks: Array = []          # {x, hp, shapes, broken, shake, cd}
var _safe := {}                 # 玩家 → 最近一次站稳的位置
var _spike_cd := {}             # 玩家 → 竹签伤害冷却
var _solid: StaticBody2D
var _plat: StaticBody2D


## 坑把地面切成几段：返回 [[x0, x1], ...]，主场景按这个铺地面碰撞
static func ground_spans(list: Array, width: float) -> Array:
	var cuts := []
	for f: Array in list:
		if f[0] == "pit":
			cuts.append([float(f[1]), float(f[2])])
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := []
	var x := -100.0
	for c: Array in cuts:
		out.append([x, c[0]])
		x = c[1]
	out.append([x, width + 100.0])
	return out


func setup() -> void:
	_solid = StaticBody2D.new()
	_solid.collision_layer = 1
	_solid.collision_mask = 0
	add_child(_solid)
	_plat = StaticBody2D.new()
	_plat.collision_layer = 0
	_plat.collision_mask = 0
	_plat.set_collision_layer_value(Fighter.PLATFORM_LAYER, true)
	add_child(_plat)
	for f: Array in features:
		match String(f[0]):
			"pit":
				pits.append([float(f[1]), float(f[2])])
			"spikes":
				spikes.append([float(f[1]), float(f[2])])
			"plank", "ledge":
				var top := floor_y - float(f[2])
				var w := float(f[3]) if f.size() > 3 else 48.0
				var pl := {"x": float(f[1]), "top": top, "w": w, "crumble": f[0] == "plank", "t": -1.0, "down": 0.0, "fall": 0.0}
				pl["shape"] = _box(_plat, Rect2(pl["x"] - w / 2.0, top, w, 6), true)
				planks.append(pl)
			"gate":
				var x := float(f[1])
				_box(_solid, Rect2(x - 12, floor_y - 600, 24, 600 - DOOR_H))
				var g := {"x": x, "id": String(f[2]), "open": 0.0, "opened": false, "close_t": -1.0}
				g["shape"] = _box(_solid, Rect2(x - 12, floor_y - DOOR_H, 24, DOOR_H))
				gates.append(g)
			"lever":
				levers.append({"x": float(f[1]), "y": floor_y - (float(f[3]) if f.size() > 3 else 0.0), "id": String(f[2]),
					"secs": float(f[4]) if f.size() > 4 else 0.0, "on": false, "cd": 0.0})
			"lantern":
				lanterns.append({"x": float(f[1]), "y": floor_y - (float(f[3]) if f.size() > 3 else 0.0), "id": String(f[2]),
					"lit": 0.0, "done": false, "cd": 0.0})
			"crack":
				var x := float(f[1])
				var cr := {"x": x, "hp": CRACK_HP, "broken": false, "shake": 0.0, "cd": 0.0}
				cr["shapes"] = [_box(_solid, Rect2(x - 13, floor_y - 600, 26, 600))]
				cracks.append(cr)


func _box(body: StaticBody2D, r: Rect2, one_way: bool = false) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)
	return shape


func in_pit(x: float) -> bool:
	for p: Array in pits:
		if x > p[0] and x < p[1]:
			return true
	return false


func _near_hazard(x: float, margin: float) -> bool:
	for p: Array in pits:
		if x > p[0] - margin and x < p[1] + margin:
			return true
	for s: Array in spikes:
		if x > s[0] - margin and x < s[1] + margin:
			return true
	return false


func gate_open(id: String) -> bool:
	for g: Dictionary in gates:
		if g["id"] == id:
			return g["opened"]
	return false


## 关着的门挡在 a 和 b 之间吗（刷怪时别刷到门那边去）
func blocked_between(a: float, b: float) -> bool:
	for g: Dictionary in gates:
		if not g["opened"] and g["x"] > minf(a, b) and g["x"] < maxf(a, b):
			return true
	for c: Dictionary in cracks:
		if not c["broken"] and c["x"] > minf(a, b) and c["x"] < maxf(a, b):
			return true
	return false


# ---------- 每帧 ----------

func _physics_process(delta: float) -> void:
	time += delta
	for p: Player in main.get_players():
		_check_player(p, delta)
	for e: Enemy in main.get_enemies():
		if e.state != Enemy.S.DYING and e.state != Enemy.S.DEAD and e.global_position.y > floor_y + PIT_FALL:
			e.hp = 0.0
			e.lives = 0
			main.spawn_text(Vector2(e.global_position.x, floor_y - 40), "坠崖", Color(1.0, 0.5, 0.3), 14)
			e._die()
		if e.global_position.y > floor_y + 200.0:
			e.velocity = Vector2.ZERO
			e.global_position.y = floor_y + 200.0
	for pl: Dictionary in planks:
		_tick_plank(pl, delta)
	for g: Dictionary in gates:
		_tick_gate(g, delta)
	for lv: Dictionary in levers:
		lv["cd"] = maxf(0.0, lv["cd"] - delta)
	for ln: Dictionary in lanterns:
		ln["cd"] = maxf(0.0, ln["cd"] - delta)
		if not ln["done"] and ln["lit"] > 0.0:
			ln["lit"] = maxf(0.0, ln["lit"] - delta)
	for c: Dictionary in cracks:
		c["cd"] = maxf(0.0, c["cd"] - delta)
		c["shake"] = maxf(0.0, c["shake"] - delta)
	queue_redraw()


func _check_player(p: Player, delta: float) -> void:
	var pos := p.global_position
	_spike_cd[p] = maxf(0.0, float(_spike_cd.get(p, 0.0)) - delta)
	if p.is_on_floor() and pos.y >= floor_y - 2.0 and not _near_hazard(pos.x, 26.0) and p.is_alive():
		_safe[p] = pos
	elif p.is_on_floor() and pos.y < floor_y - 2.0 and not _on_crumble(pos):
		_safe[p] = pos
	if pos.y > floor_y + PIT_FALL:
		# 掉进坑里：回到坑边，扣血
		p.global_position = _safe.get(p, _edge_before(pos.x))
		p.velocity = Vector2.ZERO
		main.spawn_dust(p.global_position, 0.0, 8)
		main.spawn_text(p.global_position + Vector2(0, -70), "坠落", Color(1.0, 0.5, 0.3), 14)
		main.shake(3.0)
		p.env_hit(PIT_DMG, Vector2.ZERO)
		return
	if _spike_cd[p] <= 0.0 and pos.y >= floor_y - 4.0:
		for s: Array in spikes:
			if pos.x > s[0] - 6.0 and pos.x < s[1] + 6.0:
				var away := -1.0 if p.velocity.x > 0.0 else 1.0
				if p.env_hit(SPIKE_DMG, Vector2(away * 140.0, -380.0)):
					_spike_cd[p] = 0.8
					main.spawn_blood(pos + Vector2(0, -6), 0.0, 6)
					main.shake(2.5)
				break


## 还没站稳过就掉下去了：放回这个坑左边的地面上
func _edge_before(x: float) -> Vector2:
	for p: Array in pits:
		if x > p[0] - 30.0 and x < p[1] + 30.0:
			return Vector2(p[0] - 30.0, floor_y)
	return Vector2(x, floor_y)


func _on_crumble(pos: Vector2) -> bool:
	for pl: Dictionary in planks:
		if pl["crumble"] and absf(pos.y - pl["top"]) < 4.0 and absf(pos.x - pl["x"]) < pl["w"] / 2.0 + 10.0:
			return true
	return false


func _tick_plank(pl: Dictionary, delta: float) -> void:
	if not pl["crumble"]:
		return
	if pl["down"] > 0.0:
		pl["down"] -= delta
		pl["fall"] += delta
		if pl["down"] <= 0.0:
			pl["shape"].set_deferred("disabled", false)
			pl["fall"] = 0.0
			main.spawn_dust(Vector2(pl["x"], pl["top"]), 0.0, 5)
		return
	if pl["t"] < 0.0:
		for p: Player in main.get_players():
			var pos := p.global_position
			if p.is_on_floor() and absf(pos.y - pl["top"]) < 3.0 and absf(pos.x - pl["x"]) < pl["w"] / 2.0 + 10.0:
				pl["t"] = 0.0
				break
		return
	pl["t"] += delta
	if pl["t"] >= PLANK_DELAY:
		pl["t"] = -1.0
		pl["down"] = PLANK_BACK
		pl["shape"].set_deferred("disabled", true)
		main.spawn_dust(Vector2(pl["x"], pl["top"]), 0.0, 10)
		main.shake(1.5)


func _tick_gate(g: Dictionary, delta: float) -> void:
	g["open"] = move_toward(g["open"], 1.0 if g["opened"] else 0.0, delta * (2.5 if g["opened"] else 4.0))
	if g["close_t"] > 0.0:
		g["close_t"] -= delta
		if g["close_t"] <= 0.0:
			if _someone_in(g["x"]):
				g["close_t"] = 0.1   # 有人站在门洞里，等他过去
			else:
				g["close_t"] = -1.0
				g["opened"] = false
				g["shape"].set_deferred("disabled", false)
				main.shake(2.0)
				for lv: Dictionary in levers:
					if lv["id"] == g["id"]:
						lv["on"] = false


func _someone_in(x: float) -> bool:
	for f: Node2D in main.get_players() + main.get_enemies():
		if absf(f.global_position.x - x) < 26.0:
			return true
	return false


func open_gates(id: String, secs: float = 0.0) -> void:
	for g: Dictionary in gates:
		if g["id"] != id:
			continue
		if not g["opened"]:
			main.shake(2.5)
			main.spawn_dust(Vector2(g["x"], floor_y), 0.0, 10)
		g["opened"] = true
		g["shape"].set_deferred("disabled", true)
		g["close_t"] = secs if secs > 0.0 else -1.0
		g["timed"] = secs


# ---------- 被砍 ----------

## 玩家出手的判定框碰到机关
func hit(r: Rect2, p: Player) -> void:
	for lv: Dictionary in levers:
		if lv["cd"] <= 0.0 and r.intersects(Rect2(lv["x"] - 10, lv["y"] - 34, 20, 34)):
			lv["cd"] = 0.5
			if lv["on"] and lv["secs"] <= 0.0:
				continue
			lv["on"] = true
			main.spawn_spark(Vector2(lv["x"], lv["y"] - 22), Color(1.0, 0.85, 0.5), 8)
			open_gates(lv["id"], lv["secs"])
			if lv["secs"] > 0.0:
				main.hud.toast("门开了，快跑！")
			else:
				main.hud.toast("机关响了一声")
	for ln: Dictionary in lanterns:
		if ln["cd"] <= 0.0 and not ln["done"] and r.intersects(Rect2(ln["x"] - 9, ln["y"] - 46, 18, 46)):
			ln["cd"] = 0.4
			ln["lit"] = LANTERN_TIME
			main.spawn_spark(Vector2(ln["x"], ln["y"] - 36), Color(1.0, 0.7, 0.3), 10)
			_check_lanterns(ln["id"])
	for c: Dictionary in cracks:
		if c["broken"] or c["cd"] > 0.0:
			continue
		if r.intersects(Rect2(c["x"] - 14, floor_y - WALL_H, 28, WALL_H)):
			c["cd"] = 0.25
			c["hp"] -= 1
			c["shake"] = 0.2
			main.spawn_spark(Vector2(c["x"] - 12.0 * signf(c["x"] - p.global_position.x), floor_y - 30), Color(0.8, 0.7, 0.55), 6)
			main.shake(1.5)
			if c["hp"] <= 0:
				_break_wall(c, p)


func _check_lanterns(id: String) -> void:
	var lit := 0
	var total := 0
	for ln: Dictionary in lanterns:
		if ln["id"] == id:
			total += 1
			if ln["lit"] > 0.0:
				lit += 1
	if lit < total:
		main.hud.toast("灯 %d / %d" % [lit, total])
		return
	for ln: Dictionary in lanterns:
		if ln["id"] == id:
			ln["done"] = true
	main.hud.toast("灯笼全亮了，机关开了")
	main.flash_screen(Color(1.0, 0.8, 0.4), 0.15)
	open_gates(id)


func _break_wall(c: Dictionary, p: Player) -> void:
	c["broken"] = true
	for s: CollisionShape2D in c["shapes"]:
		s.set_deferred("disabled", true)
	var dir := signf(c["x"] - p.global_position.x)
	for k in range(4):
		var shards := Fx.Particles.new()
		shards.position = Vector2(c["x"], floor_y - 20 - k * 40)
		shards.color = Color("6a5a48") if k % 2 else Color("4a3e34")
		shards.count = 10
		shards.dir = dir
		shards.speed = Vector2(130, 120)
		shards.gravity = 600.0
		shards.life = 0.8
		shards.size = 3.0
		main.fx_root.add_child(shards)
	main.spawn_dust(Vector2(c["x"], floor_y), dir, 14)
	main.shake(5.0)
	main.hud.toast("墙后面有东西")


# ---------- 画 ----------

func _draw() -> void:
	for p: Array in pits:
		_draw_pit(p[0], p[1])
	for s: Array in spikes:
		_draw_spikes(s[0], s[1], floor_y, false)
	for pl: Dictionary in planks:
		_draw_plank(pl)
	for g: Dictionary in gates:
		_draw_gate(g)
	for c: Dictionary in cracks:
		_draw_crack(c)
	for lv: Dictionary in levers:
		_draw_lever(lv)
	for ln: Dictionary in lanterns:
		_draw_lantern(ln)


func _draw_pit(x0: float, x1: float) -> void:
	var w := x1 - x0
	draw_rect(Rect2(x0, floor_y, w, 70), Color("07050a"))
	# 坑壁：上沿的土和挂下来的草根
	draw_rect(Rect2(x0 - 2, floor_y, 3, 70), Color("2a1e1a"))
	draw_rect(Rect2(x1 - 1, floor_y, 3, 70), Color("2a1e1a"))
	draw_rect(Rect2(x0 - 3, floor_y, 4, 2), Color("5a4232"))
	draw_rect(Rect2(x1 - 1, floor_y, 4, 2), Color("5a4232"))
	for k in range(int(w / 9.0)):
		var px := x0 + 4 + k * 9.0
		draw_line(Vector2(px, floor_y), Vector2(px + 1, floor_y + 4 + (k * 7) % 6), Color("1a1210"), 1.0)
	for k in range(4):
		draw_rect(Rect2(x0, floor_y + 6 + k * 10, w, 10), Color(0.0, 0.0, 0.0, 0.12 * k))
	_draw_spikes(x0 + 4, x1 - 4, floor_y + 52, true)


func _draw_spikes(x0: float, x1: float, base: float, deep: bool) -> void:
	var col := Color("5a5a3a") if deep else Color("8a8456")
	var lit := Color("b8b07a")
	var dark := Color("2a281a")
	var x := x0
	var i := 0
	while x <= x1:
		var h := 11.0 + float((i * 5) % 4)
		var lean := float((i * 3) % 3 - 1)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, base), Vector2(x + 2, base), Vector2(x + lean, base - h)]), col)
		draw_line(Vector2(x - 1, base), Vector2(x + lean, base - h), lit if not deep else col.lightened(0.15), 1.0)
		if not deep and i % 3 == 0:
			draw_rect(Rect2(x - 1 + lean, base - h, 1, 2), Color("8a2a20"))   # 竹签尖上的血迹
		x += 6.0
		i += 1
	draw_rect(Rect2(x0 - 3, base - 2, x1 - x0 + 6, 2), dark)


func _draw_plank(pl: Dictionary) -> void:
	var x: float = pl["x"]
	var top: float = pl["top"]
	var w: float = pl["w"]
	var wood := RoomProps.WOOD if not pl["crumble"] else Color("5a4632")
	var lit := RoomProps.WOOD_LIT if not pl["crumble"] else Color("8a7050")
	var dark := RoomProps.WOOD_DARK
	# 撑着的柱子，一直插到坑底
	for sx in [x - w / 2.0 + 5.0, x + w / 2.0 - 5.0]:
		draw_rect(Rect2(sx - 1.5, top + 4, 3, floor_y + 60 - top), dark)
	if not pl["crumble"]:
		draw_line(Vector2(x - w / 2.0 + 5, top + 6), Vector2(x + w / 2.0 - 5, top + 26), dark, 1.0)
	if pl["down"] > 0.0:
		# 塌了：几块碎木板往下掉
		var f: float = pl["fall"]
		if f < 0.6:
			for k in range(3):
				var px: float = x - w / 3.0 + k * w / 3.0
				var py: float = top + 260.0 * f * f + k * 4.0
				draw_set_transform(Vector2(px, py), (k - 1) * f * 3.0, Vector2.ONE)
				draw_rect(Rect2(-w / 6.0, 0, w / 3.0 - 2, 4), wood)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 快搭回来的时候闪一下提示
		if pl["down"] < 0.6 and int(pl["down"] * 10.0) % 2 == 0:
			draw_rect(Rect2(x - w / 2.0, top, w, 5), Color(lit, 0.35))
		return
	var shake := 0.0
	if pl["t"] >= 0.0:
		shake = sin(time * 60.0) * 1.0
	var r := Rect2(x - w / 2.0 + shake, top, w, 5)
	draw_rect(r.grow(1), RoomProps.OUTLINE)
	draw_rect(r, wood)
	draw_rect(Rect2(r.position, Vector2(w, 1)), lit)
	var n := int(w / 12.0)
	for k in range(1, n):
		draw_rect(Rect2(r.position.x + k * w / n, top, 1, 5), dark)
	if pl["crumble"]:
		# 烂木板：有裂缝和缺口
		draw_line(Vector2(x - 6 + shake, top + 1), Vector2(x - 2 + shake, top + 4), dark, 1.0)
		draw_line(Vector2(x + 7 + shake, top), Vector2(x + 10 + shake, top + 3), dark, 1.0)
		draw_rect(Rect2(x + w / 2.0 - 7 + shake, top + 3, 5, 2), RoomProps.OUTLINE)


func _draw_gate(g: Dictionary) -> void:
	var x: float = g["x"]
	var o: float = g["open"]
	var top := floor_y - WALL_H
	var wood := Color("3e2a20")
	var lit := Color("7a5236")
	var dark := Color("1e1410")
	# 寨墙：一排削尖的圆木
	for k in range(5):
		var px := x - 12 + k * 5
		var h := WALL_H - (k % 2) * 6
		draw_colored_polygon(PackedVector2Array([Vector2(px, floor_y - DOOR_H), Vector2(px, floor_y - h),
			Vector2(px + 2.5, floor_y - h - 6), Vector2(px + 5, floor_y - h), Vector2(px + 5, floor_y - DOOR_H)]), wood)
		draw_line(Vector2(px, floor_y - DOOR_H), Vector2(px, floor_y - h), lit if k == 0 else dark, 1.0)
	draw_rect(Rect2(x - 14, top + 30, 28, 3), dark)
	draw_rect(Rect2(x - 14, floor_y - DOOR_H - 6, 28, 6), dark)
	draw_rect(Rect2(x - 14, floor_y - DOOR_H - 6, 28, 1), lit)
	# 门柱
	draw_rect(Rect2(x - 14, floor_y - DOOR_H, 3, DOOR_H), dark)
	draw_rect(Rect2(x + 11, floor_y - DOOR_H, 3, DOOR_H), dark)
	# 铁栅栏：开的时候往上收
	var lift := o * (DOOR_H - 8)
	var bars := Color("5a5a64")
	for k in range(4):
		var px := x - 9 + k * 6
		draw_rect(Rect2(px, floor_y - DOOR_H, 2, DOOR_H - lift), bars)
		draw_rect(Rect2(px - 1, floor_y - lift - 4, 4, 4), Color("8a8a94"))
	draw_rect(Rect2(x - 11, floor_y - DOOR_H + (DOOR_H - lift) * 0.5, 22, 2), bars)
	# 门上的符：跟哪个机关一伙（拉杆、灯笼画同一个颜色）
	var col := _id_color(g["id"])
	draw_rect(Rect2(x - 4, top + 40, 8, 12), Color("c8b890"))
	draw_rect(Rect2(x - 2, top + 43, 4, 6), col)
	if g.get("timed", 0.0) > 0.0 and g["opened"] and g["close_t"] > 0.0:
		var t: float = g["close_t"] / float(g["timed"])
		draw_rect(Rect2(x - 12, floor_y - DOOR_H - 12, 24, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(x - 12, floor_y - DOOR_H - 12, 24 * t, 3), Color(1.0, 0.7, 0.3))


func _id_color(id: String) -> Color:
	match id:
		"a": return Color("e05a48")
		"b": return Color("6aa8f0")
		"c": return Color("6fc28a")
	return Color("e0b860")


func _draw_crack(c: Dictionary) -> void:
	var x: float = c["x"]
	if c["broken"]:
		# 砸开了：只剩一堆土块
		for k in range(6):
			draw_rect(Rect2(x - 16 + k * 6, floor_y - 4 - (k % 3) * 2, 6, 4 + (k % 3) * 2), Color("4a3e34"))
		draw_rect(Rect2(x - 13, floor_y - 30, 4, 30), Color("3a3028"))
		return
	var sx := sin(time * 70.0) * 1.5 if c["shake"] > 0.0 else 0.0
	var top := floor_y - WALL_H
	var wall := Color("5a4a3c")
	var lit := Color("8a7458")
	var dark := Color("2e241e")
	draw_rect(Rect2(x - 13 + sx, top, 26, WALL_H), wall)
	draw_rect(Rect2(x - 13 + sx, top, 2, WALL_H), lit)
	for k in range(int(WALL_H / 14.0)):
		draw_rect(Rect2(x - 13 + sx, top + k * 14, 26, 1), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 18 + sx, top), Vector2(x + 18 + sx, top),
		Vector2(x + 14 + sx, top - 6), Vector2(x - 14 + sx, top - 6)]), Color("3a2a22"))
	# 裂缝：砍得越多越大
	var stage := CRACK_HP - int(c["hp"])
	var pts := [Vector2(-2, -70), Vector2(4, -58), Vector2(-3, -44), Vector2(5, -30), Vector2(-1, -16), Vector2(3, -4)]
	for i in range(pts.size() - 1):
		draw_line(Vector2(x + sx, floor_y) + pts[i], Vector2(x + sx, floor_y) + pts[i + 1], RoomProps.OUTLINE, 1.0 + stage)
	if stage >= 1:
		draw_line(Vector2(x + sx + 4, floor_y - 58), Vector2(x + sx + 11, floor_y - 66), RoomProps.OUTLINE, 1.0)
		draw_line(Vector2(x + sx - 3, floor_y - 44), Vector2(x + sx - 11, floor_y - 40), RoomProps.OUTLINE, 1.0)
	if stage >= 2:
		draw_rect(Rect2(x + sx - 3, floor_y - 40, 6, 8), RoomProps.OUTLINE)


func _draw_lever(lv: Dictionary) -> void:
	var x: float = lv["x"]
	var y: float = lv["y"]
	draw_rect(Rect2(x - 7, y - 8, 14, 8), RoomProps.STONE_DARK)
	draw_rect(Rect2(x - 7, y - 8, 14, 1), RoomProps.STONE)
	var ang := 0.7 if lv["on"] else -0.7
	var tip := Vector2(x, y - 6) + Vector2(sin(ang), -cos(ang)) * 24.0
	draw_line(Vector2(x, y - 6), tip, RoomProps.WOOD_DARK, 3.0)
	draw_line(Vector2(x, y - 6), tip, RoomProps.WOOD_LIT, 1.0)
	draw_circle(tip, 3.0, _id_color(lv["id"]))
	if not lv["on"]:
		# 提示：没扳的拉杆一闪一闪
		var a := 0.3 + 0.3 * sin(time * 4.0)
		draw_circle(tip, 5.0, Color(1.0, 0.9, 0.6, a * 0.5))


func _draw_lantern(ln: Dictionary) -> void:
	var x: float = ln["x"]
	var y: float = ln["y"]
	draw_rect(Rect2(x - 3, y - 26, 6, 26), RoomProps.STONE_DARK)
	draw_rect(Rect2(x - 8, y - 4, 16, 4), RoomProps.STONE_DARK)
	draw_rect(Rect2(x - 7, y - 30, 14, 4), RoomProps.STONE)
	draw_rect(Rect2(x - 6, y - 41, 12, 11), RoomProps.STONE_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 11, y - 41), Vector2(x + 11, y - 41), Vector2(x + 4, y - 48), Vector2(x - 4, y - 48)]), RoomProps.STONE)
	draw_rect(Rect2(x - 2, y - 24, 4, 3), _id_color(ln["id"]))
	var lit: float = 1.0 if ln["done"] else clampf(ln["lit"] / 1.5, 0.0, 1.0)
	if lit > 0.0:
		var flick := 0.8 + 0.2 * sin(time * 13.0 + x) * sin(time * 7.0)
		if not ln["done"] and ln["lit"] < 2.0:
			flick *= 0.5 + 0.5 * absf(sin(time * 12.0))   # 快灭了，火苗乱跳
		draw_rect(Rect2(x - 3, y - 39, 6, 7), Color(1.0, 0.7, 0.3, flick * lit))
		for i in range(4):
			draw_circle(Vector2(x, y - 35), 6.0 + i * 8.0, Color(1.0, 0.6, 0.2, 0.05 * flick * lit))
	else:
		draw_rect(Rect2(x - 3, y - 39, 6, 7), Color("140e10"))
