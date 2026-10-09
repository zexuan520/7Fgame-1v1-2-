class_name Run
extends RefCounted
## 一局的状态：这一层的岔路地图、走到哪了、身上的铜钱和魂玉、商人买的加成。
## 地图是一列一列的房间（从左往右走），每个房间连向下一列的一到两个房间，就是岔路。

var floor_index := 0
var rows: Array = []                # rows[列] = [{type, room, next: [下一列的序号], visited}, ...]
var row := 0                        # 现在在第几列
var col := 0                        # 这一列的第几个
var coins := 0
var jade := 0
var kills := 0
var rooms_cleared := 0
var buffs := {"dmg": 0.0, "hp": 0.0, "gourds": 0, "posture": 0.0}
var shop_stock := {}                # 商人房间的货：房间坐标 → [货物 id, ...]（买过的从里面去掉）
var rested := {}                    # 上过香的土地庙
var gear := {}                      # 每个玩家身上的装备：玩家序号 → {weapon, head, body, charm1, charm2}
var revives := {}                   # 不动“不死身”：玩家序号 → 这一局还能站起来几次
var bank := {"coin": 0.0, "jade": 0.0}   # 加成后不满 1 的零头，攒够了再进钱袋
var shop_gear := {}                 # 商人房间卖的装备：房间坐标 → [装备, ...]（买过的设成 null）
var builds := {}                    # 每个玩家这一局的招式和心法：玩家序号 → Arts.new_build()
var events_done := {}               # 选过的奇遇：房间坐标 → true
var rng := RandomNumberGenerator.new()


static func create(floor_i: int, seed_value: int = -1) -> Run:
	var r := Run.new()
	r.floor_index = floor_i
	if seed_value >= 0:
		r.rng.seed = seed_value
	else:
		r.rng.randomize()
	r._generate()
	r.rows[0][0]["visited"] = true
	return r


func floor_data() -> Dictionary:
	return LevelData.floor_data(floor_index)


func node() -> Dictionary:
	return rows[row][col]


func room_key() -> String:
	return node()["room"]


func room() -> Dictionary:
	return LevelData.room(room_key())


func room_type() -> String:
	return node()["type"]


func room_id() -> String:
	return "%d_%d" % [row, col]


## 当前房间的出口：[[列序号, 节点], ...]
func exits() -> Array:
	var out := []
	if row + 1 >= rows.size():
		return out
	for c: int in node()["next"]:
		out.append([c, rows[row + 1][c]])
	return out


func advance(next_col: int) -> void:
	row += 1
	col = next_col
	node()["visited"] = true


func is_last_room() -> bool:
	return row == rows.size() - 1


# ---------- 地图生成 ----------

func _generate() -> void:
	var fd := floor_data()
	var pools: Dictionary = fd["pools"]
	var used := {}
	var used_events := {}
	rows.clear()
	for spec: Dictionary in fd["rows"]:
		var types := _pick_types(spec)
		var r := []
		for t: String in types:
			var nd := {"type": t, "room": _pick_room(pools[t], used), "next": [], "visited": false}
			if t == "event":
				nd["event"] = _pick_room(fd["events"], used_events)   # 奇遇房里碰到哪件奇遇，一局不重复
			r.append(nd)
		rows.append(r)
	_connect()


func _pick_types(spec: Dictionary) -> Array:
	var count: int = spec["count"]
	var cands: Array = (spec["types"] as Array).duplicate(true)
	var out := []
	while out.size() < count and not cands.is_empty():
		var total := 0
		for c: Array in cands:
			total += int(c[1])
		var roll := rng.randi_range(1, total)
		for i in range(cands.size()):
			roll -= int(cands[i][1])
			if roll <= 0:
				out.append(cands[i][0])
				if cands[i][0] != "fight":
					cands.remove_at(i)   # 同一列不要两个商人、两个精英
				break
	# 战斗放中间，特殊房间放两边，地图看起来不会太乱
	out.shuffle()
	return out


func _pick_room(pool: Array, used: Dictionary) -> String:
	var fresh := []
	for k: String in pool:
		if not used.has(k):
			fresh.append(k)
	var from := fresh if not fresh.is_empty() else pool
	var k: String = from[rng.randi_range(0, from.size() - 1)]
	used[k] = true
	return k


## 每个房间连向下一列位置相近的一到两个房间，保证每个房间都有路进、有路出，线不交叉
func _connect() -> void:
	for r in range(rows.size() - 1):
		var a: Array = rows[r]
		var b: Array = rows[r + 1]
		for i in range(a.size()):
			var pos := _norm(i, a.size())
			var best := 0
			for j in range(b.size()):
				if absf(_norm(j, b.size()) - pos) < absf(_norm(best, b.size()) - pos):
					best = j
			var nxt: Array = a[i]["next"]
			nxt.append(best)
			# 再往旁边多连一条，形成岔路
			var side := best + (1 if rng.randf() < 0.5 else -1)
			if b.size() > 1 and (side < 0 or side >= b.size()):
				side = best - (side - best)
			if side >= 0 and side < b.size() and side != best and rng.randf() < 0.75:
				nxt.append(side)
		_uncross(a)
		# 下一列没人连到的房间，从上一列最近的连过去
		for j in range(b.size()):
			var reached := false
			for n: Dictionary in a:
				if (n["next"] as Array).has(j):
					reached = true
			if not reached:
				var best := 0
				for i in range(a.size()):
					if absf(_norm(i, a.size()) - _norm(j, b.size())) < absf(_norm(best, a.size()) - _norm(j, b.size())):
						best = i
				(a[best]["next"] as Array).append(j)
		for n: Dictionary in a:
			(n["next"] as Array).sort()


## 去掉交叉的线：i < k 时 i 的最大出口不能大于 k 的最小出口
func _uncross(a: Array) -> void:
	for i in range(a.size()):
		for k in range(i + 1, a.size()):
			var ni: Array = a[i]["next"]
			var nk: Array = a[k]["next"]
			while ni.size() > 1 and nk.size() > 0 and ni.max() > nk.min():
				ni.erase(ni.max())
			while nk.size() > 1 and ni.size() > 0 and ni.max() > nk.min():
				nk.erase(nk.min())


func _norm(i: int, n: int) -> float:
	return 0.5 if n <= 1 else float(i) / float(n - 1)


# ---------- 商人 ----------

func stock() -> Array:
	var id := room_id()
	if not shop_stock.has(id):
		var keys: Array = LevelData.SHOP_ITEMS.keys()
		var picked := []
		while picked.size() < 3 and not keys.is_empty():
			picked.append(keys.pop_at(rng.randi_range(0, keys.size() - 1)))
		shop_stock[id] = picked
	return shop_stock[id]


## 商人摊上的装备：一件，行者“随缘”多一件
func shop_gear_list() -> Array:
	var id := room_id()
	if not shop_gear.has(id):
		var list := []
		for i in range(1 + int(Talents.run_value("shop_extra"))):
			list.append(GearData.roll(rng, GearData.weights_for("shop", row, int(Talents.run_value("luck")))))
		shop_gear[id] = list
	return shop_gear[id]


## 某个玩家这一局的招式和心法（第一次要的时候只带回旋斩）
func build(index: int) -> Dictionary:
	if not builds.has(index):
		builds[index] = Arts.new_build()
	return builds[index]


## 某个玩家这一局的装备（第一次要的时候按兵器架上选的武器新建）
func loadout(index: int) -> Dictionary:
	if not gear.has(index):
		var g := GearData.empty_loadout(String(Game.save["start_weapon"]))
		if int(Talents.run_value("start_charm")) > 0:
			g["charm1"] = GearData.roll(rng, [0.0, 1.0, 0.0, 0.0, 0.0], "charm")
		gear[index] = g
	return gear[index]
