class_name ArpgState
extends RefCounted
## 一局的状态（斜俯视版）：分岔地图（沿用原来的 Run 生成，房间类型一样：开局/战斗/精英/商人/歇脚/奇遇/头目）、
## 铜钱魂玉、兵器、护甲、护符、心法、药葫芦、生命。主角节点换房间时不重建，生命就留着。

static var cur: ArpgState

## 一局三层。第一幕“归乡”：幽林遗迹（头目夜樱）→ 无名冢（头目百骨将）→ 古寺（最终头目寂光）
## 第二幕“入山”（第一幕任一结局后，山门出现“入井”光门）：青井地宫（井中人·枯荣）→ 烛国灯冢（不夜将军）→ 灰衣营（执灯使·烬）
## 下面这些表按“全局层号”排（gfloor = 第几幕的偏移 + 本幕第几层），一幕三层
const FLOOR_ZONES := ["forest", "grave", "temple", "well", "vault", "camp"]
const FLOOR_NAMES := ["幽林遗迹", "无名冢", "古寺", "青井地宫", "烛国灯冢", "灰衣营"]
const BOSS_KINDS := ["boss", "boss3", "boss2", "boss4", "boss5", "boss6"]
const BOSS_ZONES := ["sakura", "grave", "temple", "well", "vault", "camp"]
const BOSS_TITLES := ["夜樱广场", "无名冢 · 万骨坑", "古寺 · 寂光殿", "青井 · 井底", "灯冢 · 不夜殿", "灰衣营 · 帅帐"]
const BOSS_MUSIC := ["boss", "boss2", "boss", "boss2", "boss", "boss2"]
const LAST_FLOOR := 2
## 第二幕已经做好的层数（分阶段做：先只有青井地宫，打完头目算这一章暂时通关）
const ACT2_READY := 3
const ACT_NAMES := {1: "第一幕 · 归乡", 2: "第二幕 · 入山"}
const CN_NUM := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
const TYPE_NAMES := {"start": "林口", "fight": "战", "elite": "精英", "shop": "商人", "rest": "歇脚", "event": "奇遇", "boss": "头目",
	"treasure": "宝箱", "trial": "试炼", "story": "故人", "secret": "密室"}
const TYPE_DESC := {"start": "", "fight": "成群的敌人，清完选一个心法", "elite": "赤甲武士带队，心法更好，必掉装备",
	"shop": "游商：买心法、装备、补药，也能合成装备", "rest": "土地庙：回血或者补满药葫芦，也能合成装备", "event": "说不准会碰到什么",
	"boss": "这一层的守关头目", "treasure": "没人看守的宝箱，开出装备和铜钱", "trial": "同一间房里连过四道试（疾、守、狂、乱），得印越多奖励越好",
	"story": "路上遇到的人。你的选择会改变后面的事", "secret": "藏在裂墙后面的房间"}

var run: Run
var act := 1                # 第几幕（1 归乡 / 2 入山）
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
var side_rooms := 0                      # 这一局拿完的侧室（藏宝 / 伏兵 / 灵泉 / 遗骸 / 小试炼）
var boons: Array[String] = []
var whet := 0               # 这一局在游商那里磨过几次刀（每次伤害 +6%，铜钱的长期去处）
var revives := 0
var omen := ""              # 这一局的天象（OMENS 的键）
var boss_retry := {}        # 游历难度：这一层头目已经重打过（层号 → true）
var seed_value := 0
var bought := {}            # 商人房间里已经买过的货：房间坐标 → [下标...]
var shop_cache := {}        # 商人房间的货：房间坐标 → [货物...]
var event_cache := {}       # 奇遇房间抽到的奇遇


static func start_new(act_: int = 1) -> ArpgState:
	var s := ArpgState.new()
	s.act = act_
	s.seed_value = randi() if not OS.get_cmdline_user_args().has("--seed0") else 12345   # --seed0：测试时固定房间
	s.run = Run.create(0, s.seed_value)
	s.weapon = String(Game.save.get("arpg_weapon", "sword"))
	var st := ArpgData.talent_stats()
	s.coins = int(ArpgData.stat(st, "start_coins"))
	s.revives = int(ArpgData.stat(st, "revive"))
	var ks := OMENS.keys()
	s.omen = String(ks[randi() % ks.size()])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--omen="):
			s.omen = a.substr(7) if OMENS.has(a.substr(7)) else ""
	# 第二幕：第一幕最后选了“守灯人”，残刃带着灯，天象固定“残灯”（小怪被灯引来）
	if s.act == 2 and String(Game.save.get("arpg_last_end", "")) == "keep":
		s.omen = "lantern"
	s.remap()
	cur = s
	return s


## 天象：每局开局随机一个，整局生效。count/hp/dmg/speed 改敌人（头目不改数量），stats 加到主角身上
const OMENS := {
	"blood_moon": {"name": "血月", "desc": "敌人多三成，铜钱 +50%", "count": 1.3, "stats": {"coin": 0.5}, "color": Color(1.0, 0.35, 0.3)},
	"bone_tide": {"name": "骨潮", "desc": "敌人多四成，但血少两成：砍个痛快", "count": 1.4, "hp": 0.8, "color": Color(0.85, 0.9, 0.75)},
	"fog": {"name": "浓雾", "desc": "雾更浓，看不远；会心率 +12%", "stats": {"crit": 0.12}, "fog": 1.7, "color": Color(0.6, 0.75, 0.8)},
	"gale": {"name": "疾风", "desc": "你和敌人都快 15%", "speed": 1.15, "stats": {"move": 0.15}, "color": Color(0.5, 1.0, 0.8)},
	"lantern": {"name": "残灯", "desc": "敌人伤害 +15%，掉的装备更好", "dmg": 1.15, "luck": 0.35, "color": Color(1.0, 0.8, 0.4)},
	"calm": {"name": "清明", "desc": "每清完一间战斗房，回复 12% 生命", "heal": 0.12, "color": Color(0.7, 0.9, 1.0)},
}


func omen_val(k: String, def: float = 1.0) -> float:
	if omen == "" or not OMENS.has(omen):
		return def
	return float(OMENS[omen].get(k, def))


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


## 全局层号：第二幕第一层是 3
func gfloor() -> int:
	return mini(run.floor_index + (act - 1) * 3, FLOOR_ZONES.size() - 1)


## 这一幕的最后一层（本幕层号）
func last_floor() -> int:
	return LAST_FLOOR if act == 1 else ACT2_READY - 1


func is_last_floor() -> bool:
	return run.floor_index >= last_floor()


func zone() -> String:
	return FLOOR_ZONES[gfloor()]


func floor_name() -> String:
	return FLOOR_NAMES[gfloor()]


func boss_kind() -> String:
	return BOSS_KINDS[gfloor()]


func boss_zone() -> String:
	return BOSS_ZONES[gfloor()]


func boss_title() -> String:
	return BOSS_TITLES[gfloor()]


func boss_music() -> String:
	return BOSS_MUSIC[gfloor()]


## 第二幕敌人更硬一点（开局没有心法，所以只加两成多，不按第四层算）
func act_hp() -> float:
	return 1.0 if act == 1 else 1.3


func act_dmg() -> float:
	return 1.0 if act == 1 else 1.15


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
	if whet > 0:
		ArpgData.add_stats(st, {"atk": WHET_ATK * whet})
	if omen != "" and OMENS.has(omen):
		ArpgData.add_stats(st, OMENS[omen].get("stats", {}))
	var sc := ArpgData.school_counts(boons)
	for k: String in sc:
		if int(sc[k]) >= ArpgData.SET_NEED and ArpgData.SETS.has(k):
			st[String(ArpgData.SETS[k]["id"])] = 1.0
	if difficulty() == 0:
		ArpgData.add_stats(st, {"easy": EASY_TAKEN})
	else:
		ArpgData.add_stats(st, {"jade": HARD_JADE})
	return st


## 难度：0 游历（受伤 -35%，头目前倒下可以重打一次）/ 1 修罗（原数值，魂玉 +20%）。存在存档里，没选过算游历
const DIFF_NAMES := ["游历", "修罗"]
const DIFF_DESC := ["受伤 -35%，每层头目倒下后可以原地重打一次。第一次玩推荐", "原汁原味的数值，魂玉 +20%。想要挑战选这个"]
const EASY_TAKEN := 0.35
const HARD_JADE := 0.2


static func difficulty() -> int:
	return clampi(int(Game.save.get("arpg_diff", 0)), 0, 1)


const WHET_ATK := 0.06


## 磨刀一次的价钱：越磨越贵（第三层铜钱多了也有地方花）
func whet_price() -> int:
	return 60 + 35 * whet


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
	var pool := []
	for b: Dictionary in ArpgData.BOONS:
		if not b.get("hidden", false) or bool(Game.save.get(String(b.get("unlock", "arpg_shadow")), false)):
			pool.append(b)
	var out := []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


## 这间商人房的货：2 个心法、1 件护甲、1 个护符、补满药葫芦、磨刀（不限次数）
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
		# 越往后货越好（也越贵）：第一层 良~精，第二层 精~珍，第三层 精~传
		var fl := floor_i()
		var it := ArpgGear.roll(rng, rng.randi_range(1 + mini(fl, 1), mini(2 + fl, 4)), 0.0, slot)
		var base := ArpgData.gear(String(it["base"]))
		items.append({"kind": "gear", "item": it, "name": it["name"], "desc": ("护甲：" if slot == "armor" else "护符：") + ArpgGear.describe(it),
			"price": int(base["price"]) + 25 * int(it["rarity"])})
	items.append({"kind": "refill", "id": "refill", "name": "补药", "desc": "补满药葫芦", "price": 20})
	items.append({"kind": "whet", "id": "whet", "name": "磨刀", "desc": "这一局伤害 +6%（可以一直磨，越磨越贵）", "price": 0})
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
	Game.save["best_floor"] = maxi(int(Game.save["best_floor"]), gfloor() + 1)
	if act == 1:
		remember_act1()
	Game.write_save()
	return {"won": won, "jade": jade, "kept": kept, "coins": coins, "kills": kills, "rooms": rooms, "floor": gfloor() + 1}


## 跨幕的选择：第一幕每条人物线最近一局选了什么，记进存档 arpg_act1（组 → 旗标），第二幕里有人记得
const ACT1_GROUPS := {
	"ronin": ["ronin_saved", "ronin_left", "ronin_ignored"],
	"sakura": ["sakura_rest", "sakura_blade"],
	"grave": ["graves_named", "iron_helm"],
	"monk": ["monk_told", "monk_fought"],
}


func remember_act1() -> void:
	var mem: Dictionary = Game.save.get("arpg_act1", {})
	for g: String in ACT1_GROUPS:
		for f: String in ACT1_GROUPS[g]:
			if flags.has(f):
				mem[g] = f
	Game.save["arpg_act1"] = mem


## 第一幕某条线最近一次的选择（没走到过返回 ""）
static func act1(group: String) -> String:
	return String((Game.save.get("arpg_act1", {}) as Dictionary).get(group, ""))
