class_name ArpgState
extends RefCounted
## 一局的状态（斜俯视版）：分岔地图（沿用原来的 Run 生成，房间类型一样：开局/战斗/精英/商人/歇脚/奇遇/头目）、
## 铜钱魂玉、兵器、护甲、护符、心法、药葫芦、生命。主角节点换房间时不重建，生命就留着。

static var cur: ArpgState

## 一局三层：幽林遗迹（头目夜樱）→ 无名冢（头目百骨将）→ 古寺（最终头目寂光）
const FLOOR_ZONES := ["forest", "grave", "temple"]
const FLOOR_NAMES := ["幽林遗迹", "无名冢", "古寺"]
const BOSS_KINDS := ["boss", "boss3", "boss2"]
const BOSS_ZONES := ["sakura", "grave", "temple"]
const BOSS_TITLES := ["夜樱广场", "无名冢 · 万骨坑", "古寺 · 寂光殿"]
const BOSS_MUSIC := ["boss", "boss2", "boss"]
const LAST_FLOOR := 2
const TYPE_NAMES := {"start": "林口", "fight": "战", "elite": "精英", "shop": "商人", "rest": "歇脚", "event": "奇遇", "boss": "头目",
	"treasure": "宝箱", "trial": "试炼", "story": "故人", "secret": "密室"}
const TYPE_DESC := {"start": "", "fight": "成群的敌人，清完选一个心法", "elite": "赤甲武士带队，心法更好，必掉装备",
	"shop": "游商：买心法、装备、补药，也能合成装备", "rest": "土地庙：回血或者补满药葫芦，也能合成装备", "event": "说不准会碰到什么",
	"boss": "这一层的守关头目", "treasure": "没人看守的宝箱，开出装备和铜钱", "trial": "同一间房里连过四道试（疾、守、狂、乱），得印越多奖励越好",
	"story": "路上遇到的人。你的选择会改变后面的事", "secret": "藏在裂墙后面的房间"}

var run: Run
var coins := 0
var jade := 0
var kills := 0
var rooms := 0
var weapon := "sword"
var gear := {"armor": {}, "charm": {}}   # 身上穿的装备（ArpgGear 字典，空字典表示没穿）
var bag: Array = []                      # 行囊里的装备
var flags := {}                          # 这一局的剧情选择（ronin_saved、sakura_blade ...）
var seen := {}                           # 这一局见过的剧情遭遇
var curse := 0                           # 拿了地藏的钱：受伤 +10% 每层
var secrets_done := {}                   # 已经打开过的隐藏房间（房间坐标）
var boons: Array[String] = []
var revives := 0
var seed_value := 0
var bought := {}            # 商人房间里已经买过的货：房间坐标 → [下标...]
var shop_cache := {}        # 商人房间的货：房间坐标 → [货物...]
var event_cache := {}       # 奇遇房间抽到的奇遇


static func start_new() -> ArpgState:
	var s := ArpgState.new()
	s.seed_value = randi()
	s.run = Run.create(0, s.seed_value)
	s.weapon = String(Game.save.get("arpg_weapon", "sword"))
	var st := ArpgData.talent_stats()
	s.coins = int(ArpgData.stat(st, "start_coins"))
	s.revives = int(ArpgData.stat(st, "revive"))
	s.remap()
	cur = s
	return s


## 在原来的地图上换出新房间：一部分战斗房变成宝箱房、试炼房，每层第一个奇遇房变成剧情遭遇（故人）。
## 换层（run.next_floor）之后也要再调一次。
func remap() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + run.floor_index * 101
	var rows: Array = run.rows
	var story_done := false
	for r in range(1, rows.size() - 2):
		for nd: Dictionary in rows[r]:
			var t := String(nd["type"])
			if t == "fight" and r >= 2:
				var x := rng.randf()
				if x < 0.14:
					nd["type"] = "treasure"
				elif x < 0.26:
					nd["type"] = "trial"
			elif t == "event" and not story_done:
				nd["type"] = "story"
				story_done = true
	if not story_done:
		for nd: Dictionary in rows[2]:
			if nd["type"] == "fight":
				nd["type"] = "story"
				break


func floor_i() -> int:
	return run.floor_index


func zone() -> String:
	return FLOOR_ZONES[mini(run.floor_index, FLOOR_ZONES.size() - 1)]


func room_type() -> String:
	return run.room_type()


## 所有加成：天赋 + 兵器 + 护甲 + 护符 + 心法
func stats() -> Dictionary:
	var st := ArpgData.talent_stats()
	var w := ArpgData.weapon(weapon)
	if w.has("bleed"):
		ArpgData.add_stats(st, {"bleed": w["bleed"]})
	if w.has("crit_dmg"):
		ArpgData.add_stats(st, {"crit_dmg": w["crit_dmg"]})
	for slot: String in gear:
		ArpgData.add_stats(st, ArpgGear.stats(gear[slot]))
	if curse > 0:
		ArpgData.add_stats(st, {"dmg_taken": 0.1 * curse})
	for b: String in boons:
		ArpgData.add_stats(st, ArpgData.boon(b).get("stats", {}))
	return st


func add_coins(n: int) -> int:
	var k := 1.0 + ArpgData.stat(stats(), "coin")
	var got := int(round(n * k))
	coins += got
	return got


func add_jade(n: int) -> int:
	var k := 1.0 + ArpgData.stat(stats(), "jade")
	var got := int(round(n * k))
	jade += got
	return got


func price(base: int) -> int:
	return maxi(1, int(round(base * (1.0 - ArpgData.stat(stats(), "discount")))))


## 随机抽 n 个心法（不重复）
func roll_boons(n: int, rng: RandomNumberGenerator) -> Array:
	var pool := ArpgData.BOONS.duplicate()
	var out := []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


## 这间商人房的货：2 个心法、1 件护甲、1 个护符、补满药葫芦、（没解锁的话）一把兵器
func shop_stock() -> Array:
	var key := run.room_id()
	if shop_cache.has(key):
		return shop_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + run.row * 31 + run.col * 7
	var items := []
	for b: Dictionary in roll_boons(2, rng):
		items.append({"kind": "boon", "id": b["id"], "name": b["name"], "desc": b["desc"], "price": 45 + run.row * 3})
	for slot: String in ["armor", "charm"]:
		var it := ArpgGear.roll(rng, rng.randi_range(1, 2), 0.0, slot)
		var base := ArpgData.gear(String(it["base"]))
		items.append({"kind": "gear", "item": it, "name": it["name"], "desc": ("护甲：" if slot == "armor" else "护符：") + ArpgGear.describe(it),
			"price": int(base["price"]) + 25 * int(it["rarity"])})
	items.append({"kind": "refill", "id": "refill", "name": "补药", "desc": "补满药葫芦", "price": 20})
	shop_cache[key] = items
	return items


func event_for_room() -> Dictionary:
	var key := run.room_id()
	if not event_cache.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + run.row * 13 + run.col
		event_cache[key] = ArpgData.EVENTS[rng.randi_range(0, ArpgData.EVENTS.size() - 1)]
	return event_cache[key]


## 局结束：把魂玉存进存档。死了只带回一部分（60%，天赋“归途”加成）
func settle(won: bool) -> Dictionary:
	var keep := 1.0 if won else 0.6 + ArpgData.stat(stats(), "keep")
	var kept := int(floor(jade * keep))
	Game.save["jade"] = int(Game.save["jade"]) + kept
	Game.save["runs"] = int(Game.save["runs"]) + 1
	if won:
		Game.save["clears"] = int(Game.save["clears"]) + 1
	else:
		Game.save["deaths"] = int(Game.save["deaths"]) + 1
	Game.save["best_floor"] = maxi(int(Game.save["best_floor"]), run.floor_index + 1)
	Game.write_save()
	return {"won": won, "jade": jade, "kept": kept, "coins": coins, "kills": kills, "rooms": rooms, "floor": run.floor_index + 1}
