class_name ArpgState
extends RefCounted
## 一局的状态（斜俯视版）：分岔地图（沿用原来的 Run 生成，房间类型一样：开局/战斗/精英/商人/歇脚/奇遇/头目）、
## 铜钱魂玉、兵器、护甲、护符、心法、药葫芦、生命。主角节点换房间时不重建，生命就留着。

static var cur: ArpgState

const FLOOR_ZONES := ["forest", "temple"]
const FLOOR_NAMES := ["幽林遗迹", "古寺"]
const TYPE_NAMES := {"start": "林口", "fight": "战", "elite": "精英", "shop": "商人", "rest": "歇脚", "event": "奇遇", "boss": "头目"}
const TYPE_DESC := {"start": "", "fight": "成群的敌人，清完选一个心法", "elite": "赤甲武士带队，心法更好、铜钱更多",
	"shop": "游商：买心法、护甲、护符、补药", "rest": "土地庙：回血或者补满药葫芦", "event": "说不准会碰到什么", "boss": "这一层的守关头目"}

var run: Run
var coins := 0
var jade := 0
var kills := 0
var rooms := 0
var weapon := "sword"
var armor := ""
var charm := ""
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
	cur = s
	return s


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
	for gid: String in [armor, charm]:
		if gid != "":
			ArpgData.add_stats(st, ArpgData.gear(gid).get("stats", {}))
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
	var ar: Dictionary = ArpgData.ARMORS[rng.randi_range(0, ArpgData.ARMORS.size() - 1)]
	items.append({"kind": "armor", "id": ar["id"], "name": ar["name"], "desc": "护甲：" + String(ar["desc"]), "price": ar["price"]})
	var ch: Dictionary = ArpgData.CHARMS[rng.randi_range(0, ArpgData.CHARMS.size() - 1)]
	items.append({"kind": "charm", "id": ch["id"], "name": ch["name"], "desc": "护符：" + String(ch["desc"]), "price": ch["price"]})
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
