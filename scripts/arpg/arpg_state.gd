class_name ArpgState
extends RefCounted
## 一局的状态（斜俯视版）：分岔地图（沿用原来的 Run 生成，房间类型一样：开局/战斗/精英/商人/歇脚/奇遇/头目）、
## 铜钱魂玉、兵器、护甲、护符、心法、药葫芦、生命。主角节点换房间时不重建，生命就留着。

static var cur: ArpgState

## 一局三层。第一幕“归乡”：幽林遗迹（头目夜樱）→ 无名冢（头目百骨将）→ 古寺（最终头目寂光）
## 第二幕“入山”（第一幕任一结局后，山门出现“入井”光门）：青井地宫（井中人·枯荣）→ 烛国灯冢（不夜将军）→ 灰衣营（执灯使·烬）
## 下面这些表按“全局层号”排（gfloor = 第几幕的偏移 + 本幕第几层），一幕三层
const FLOOR_ZONES := ["forest", "grave", "temple", "well", "vault", "camp", "liuxi", "post", "palace"]
const FLOOR_NAMES := ["幽林遗迹", "无名冢", "古寺", "青井地宫", "烛国灯冢", "灰衣营", "柳溪村", "官道驿站", "长明宫"]
const BOSS_KINDS := ["boss", "boss3", "boss2", "boss4", "boss5", "boss6", "boss7", "boss8", "boss9"]
const BOSS_ZONES := ["sakura", "grave", "temple", "well", "vault", "camp", "liuxi", "post", "palace"]
const BOSS_TITLES := ["夜樱广场", "无名冢 · 万骨坑", "古寺 · 寂光殿", "青井 · 井底", "灯冢 · 不夜殿", "灰衣营 · 帅帐", "柳溪村 · 祠堂前", "官道 · 十里亭", "长明宫 · 金殿"]
## 头目曲：第一幕三首轮着用；第二、三幕每个头目一首（assets/music/boss_<场景>.ogg）
const BOSS_MUSIC := ["boss", "boss2", "boss", "boss_well", "boss_vault", "boss_camp", "boss_liuxi", "boss_post", "boss_palace"]
## 场景曲（战斗房、精英房等）：第二、三幕每层一首
const ZONE_MUSIC := {"temple": "bamboo", "grave": "secret", "well": "well", "vault": "vault", "camp": "camp",
	"liuxi": "liuxi", "post": "post", "palace": "palace"}
const LAST_FLOOR := 2
## 第二幕已经做好的层数（分阶段做：先只有青井地宫，打完头目算这一章暂时通关）
const ACT2_READY := 3
## 第三幕“出山”（第二幕任一结局后，山门左边下山的路口出现“出山”光门）：柳溪村（火师焦明）→ 官道驿站（押灯将霍长风）→ 长明宫（长明帝）
const ACT3_READY := 3
const ACT_NAMES := {1: "第一幕 · 归乡", 2: "第二幕 · 入山", 3: "第三幕 · 出山"}
const CN_NUM := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
const TYPE_NAMES := {"start": "林口", "fight": "战", "elite": "精英", "shop": "商人", "rest": "歇脚", "event": "奇遇", "boss": "头目",
	"treasure": "宝箱", "trial": "试炼", "story": "故人", "secret": "密室", "nook": "秘处"}
const TYPE_DESC := {"start": "", "fight": "成群的敌人，清完选一个心法", "elite": "赤甲武士带队，心法更好，必掉装备",
	"shop": "游商：买心法、装备、补药，也能合成装备", "rest": "土地庙：回血或者补满药葫芦，也能合成装备", "event": "说不准会碰到什么",
	"boss": "这一层的守关头目", "treasure": "没人看守的宝箱，开出装备和铜钱", "trial": "同一间房里连过四道试（疾、守、狂、乱），得印越多奖励越好",
	"story": "路上遇到的人。你的选择会改变后面的事", "secret": "藏在裂墙后面的房间", "nook": "支线的尽头：三样别处拿不到的东西选一样"}

var run: Run
var act := 1                # 第几幕（1 归乡 / 2 入山 / 3 出山）
var cycle := 0              # 轮回级（通关后的加难，见 ArpgCycle；0 = 本相）
var coins := 0
var jade := 0
var kills := 0
var rooms := 0
var weapon := "sword"                     # 主手兵器 id（= arms[0].base）
var arms: Array = [{}, {}]               # 主手、副手兵器（ArpgGear 兵器字典，副手空着就是 {}）；Q 换手
var gear := {"armor": {}, "helm": {}, "boots": {}, "charm": {}, "charm2": {}}   # 身上穿的装备（ArpgGear 字典，空字典表示没穿）
var props: Array = []                    # 道具：[{"id", "n"}...]，最多 ArpgArms.ITEM_KINDS 种
var prop_sel := 0                        # 当前选中的道具
var bag: Array = []                      # 行囊里的装备
var flags := {}                          # 这一局的剧情选择（ronin_saved、sakura_blade ...）
var seen := {}                           # 这一局见过的剧情遭遇
var curse := 0                           # 拿了地藏的钱：受伤 +10% 每层
var secrets_done := {}                   # 已经打开过的隐藏房间（房间坐标）
var squads := {}                         # 每间战斗房抽到的“阵”（"层号:房间坐标" → 阵 id，FoeSquads）
var side_rooms := 0                      # 这一局拿完的侧室（藏宝 / 伏兵 / 灵泉 / 遗骸 / 小试炼）
var boons: Array[String] = []
var forged := 0            # 这一局在灯冢熔铜炉里铸过几层甲（每层生命 +FORGE_HP）
var whet := 0               # 这一局在游商那里磨过几次刀（每次伤害 +6%，铜钱的长期去处）
var revives := 0
var xp := 0                 # 悟道：这一重攒了多少悟（ArpgSkills.need）
var level := 1              # 悟道第几重
var points := 0             # 还没用的天赋点
var skills := {}            # 技能分支：分支 id → 级数
var links_done := {}        # 这一局打出过的连携
var omen := ""              # 这一局的天象（OMENS 的键）
var boss_retry := {}        # 游历难度：这一层头目已经重打过（层号 → true）
var seed_value := 0
var bought := {}            # 商人房间里已经买过的货：房间坐标 → [下标...]
var shop_cache := {}        # 商人房间的货：房间坐标 → [货物...]
var event_cache := {}       # 奇遇房间抽到的奇遇


static func start_new(act_: int = 1) -> ArpgState:
	var s := ArpgState.new()
	s.act = act_
	s.cycle = ArpgCycle.picked()
	s.seed_value = randi() if not OS.get_cmdline_user_args().has("--seed0") else 12345   # --seed0：测试时固定房间
	s.run = Run.create(0, s.seed_value)
	s.weapon = String(Game.save.get("arpg_weapon", "sword"))
	if not ArpgData.WEAPONS.has(s.weapon):
		s.weapon = "sword"
	s.arms[0] = ArpgGear.weapon_item(s.weapon)
	# 兵器架“备刃”：出发时副手带上第二把
	var w2 := String(Game.save.get("arpg_weapon2", ""))
	if bool(Game.save.get("arpg_spare", false)) and w2 != "" and w2 != s.weapon and ArpgData.WEAPONS.has(w2):
		s.arms[1] = ArpgGear.weapon_item(w2)
	# 开局送一样道具，让人知道有这回事
	var irng := RandomNumberGenerator.new()
	irng.seed = s.seed_value + 77
	s.add_item(ArpgArms.random_item(irng))
	var st := ArpgData.talent_stats()
	s.coins = int(ArpgData.stat(st, "start_coins"))
	s.revives = int(ArpgData.stat(st, "revive"))
	s.points = int(ArpgData.stat(st, "insight"))   # 天赋“慧根”：开局就有天赋点
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
	# 三幕都一样：一层多两列房间，再加一条分岔支线（ArpgRoutes）
	ArpgRoutes.expand(self)


func floor_i() -> int:
	return run.floor_index


## 全局层号：第二幕第一层是 3
func gfloor() -> int:
	return mini(run.floor_index + (act - 1) * 3, FLOOR_ZONES.size() - 1)


## 这一幕的最后一层（本幕层号）
func last_floor() -> int:
	return LAST_FLOOR if act == 1 else (ACT2_READY - 1 if act == 2 else ACT3_READY - 1)


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


## 第二幕敌人更硬一点（开局没有心法，所以只加两成多，不按第四层算）；第三幕再硬一档
func act_hp() -> float:
	return [1.0, 1.0, 1.3, 1.42][clampi(act, 0, 3)]


func act_dmg() -> float:
	return [1.0, 1.0, 1.15, 1.25][clampi(act, 0, 3)]


func room_type() -> String:
	return run.room_type()


## 所有加成：天赋 + 兵器 + 护甲 + 护符 + 心法……（逐项见 stat_parts，属性面板按它列出每一项的来源）
func stats() -> Dictionary:
	var st := {}
	for p: Dictionary in stat_parts():
		ArpgData.add_stats(st, p["st"])
	return st


## 加成的每一个来源：[{"src": 显示名, "kind": 分类, "st": 这一项给的 stats}]。stats() 就是把它们全加起来
func stat_parts() -> Array:
	var out := []
	var add := func(kind: String, src: String, st: Dictionary) -> void:
		if not st.is_empty():
			out.append({"kind": kind, "src": src, "st": st})
	for t: Dictionary in ArpgData.TALENT_TREES:
		for tier: Array in t["tiers"]:
			for nd: Dictionary in tier:
				var r := ArpgData.talent_rank(nd["id"])
				if r > 0:
					var ts := {}
					ArpgData.add_stats(ts, nd["stats"], r)
					add.call("天赋", "天赋·%s%s" % [nd["name"], " ×%d" % r if r > 1 else ""], ts)
	for kid: String in ArpgSecrets.keeps():
		add.call("信物", "信物·%s" % ArpgSecrets.keep_info(kid).get("name", kid), ArpgSecrets.keep_info(kid).get("stats", {}))
	var wd := ArpgData.weapon(weapon)
	add.call("兵器", "兵器特性·%s" % wd["name"], ArpgArms.weapon_stats(weapon))
	add.call("兵器", "主手·%s" % String((arms[0] as Dictionary).get("name", wd["name"])), ArpgGear.stats(arms[0]))
	for slot: String in gear:
		var it: Dictionary = gear[slot]
		if not it.is_empty():
			add.call("装备", "%s·%s" % [ArpgData.SLOT_NAMES.get(slot, slot), it.get("name", ArpgData.gear(String(it.get("base", ""))).get("name", ""))], ArpgGear.stats(it))
	for sp: Array in ArpgArms.set_parts(gear):
		add.call("套装", "套装·%s（%d 件）" % [ArpgArms.GEAR_SETS[sp[0]]["name"], sp[1]], sp[2])
	if curse > 0:
		add.call("境况", "诅咒·地藏的钱%s" % (" ×%d" % curse if curse > 1 else ""), {"dmg_taken": 0.1 * curse})
	var seen_b := {}
	for b: String in boons:
		seen_b[b] = int(seen_b.get(b, 0)) + 1
	for b: String in seen_b:
		var bd := ArpgData.boon(b)
		var bs := {}
		ArpgData.add_stats(bs, bd.get("stats", {}), int(seen_b[b]))
		add.call("心法", "心法·%s%s" % [bd.get("name", b), " ×%d" % seen_b[b] if int(seen_b[b]) > 1 else ""], bs)
	if whet > 0:
		add.call("境况", "磨刀 ×%d" % whet, {"atk": WHET_ATK * whet})
	if forged > 0:
		add.call("境况", "熔铜炉铸甲 ×%d" % forged, {"hp": FORGE_HP * forged})
	if omen != "" and OMENS.has(omen):
		add.call("境况", "天象·%s" % OMENS[omen]["name"], OMENS[omen].get("stats", {}))
	if act == 3 and (flags.has("lamp_carried") or flags.has("stable_fed")):
		# 第三幕：带着的石门灯、喂过的驿马（数值照 Act3.run_stats 算，这里只起个名字）
		var a3 := {}
		Act3.run_stats(self, a3)
		var got := []
		if flags.has("lamp_carried"):
			got.append("石门灯")
		if flags.has("stable_fed"):
			got.append("驿马")
		add.call("境况", "路上·%s" % "、".join(got), a3)
	if not (flags.get("route_stats", {}) as Dictionary).is_empty():
		add.call("境况", "支线所得", flags["route_stats"])   # 分岔支线尽头拿的加成（ArpgRoutes）
	var sc := ArpgData.school_counts(boons)
	for k: String in sc:
		if int(sc[k]) >= ArpgData.SET_NEED and ArpgData.SETS.has(k):
			add.call("心法", "大成·%s" % ArpgData.SETS[k]["name"], {String(ArpgData.SETS[k]["id"]): 1.0})
	if cycle > 0:
		add.call("轮回", ArpgCycle.label(cycle), ArpgCycle.hero_stats(cycle))
	var ks := {}
	ArpgSkills.add_stats(ks, skills, boons)
	add.call("技能", "技能分支与双修", ks)
	if difficulty() == 0:
		add.call("难度", "难度·游历", {"easy": EASY_TAKEN})
	else:
		add.call("难度", "难度·修罗", {"jade": HARD_JADE})
	return out


## 山门里看的“出发时”的样子：兵器架选的主副手、这次出发的轮回级，没有心法和装备（不改 cur，不掷随机数）
static func preview() -> ArpgState:
	var s := ArpgState.new()
	s.cycle = ArpgCycle.picked()
	s.weapon = String(Game.save.get("arpg_weapon", "sword"))
	if not ArpgData.WEAPONS.has(s.weapon):
		s.weapon = "sword"
	s.arms[0] = ArpgGear.weapon_item(s.weapon)
	var w2 := String(Game.save.get("arpg_weapon2", ""))
	if bool(Game.save.get("arpg_spare", false)) and w2 != "" and w2 != s.weapon and ArpgData.WEAPONS.has(w2):
		s.arms[1] = ArpgGear.weapon_item(w2)
	var st := ArpgData.talent_stats()
	s.coins = int(ArpgData.stat(st, "start_coins"))
	s.points = int(ArpgData.stat(st, "insight"))
	return s


## 难度：0 游历（受伤 -35%，头目前倒下可以重打一次）/ 1 修罗（原数值，魂玉 +20%）。存在存档里，没选过算游历
const DIFF_NAMES := ["游历", "修罗"]
const DIFF_DESC := ["受伤 -35%，每层头目倒下后可以原地重打一次。第一次玩推荐", "原汁原味的数值，魂玉 +20%。想要挑战选这个"]
const EASY_TAKEN := 0.35
const HARD_JADE := 0.2


static func difficulty() -> int:
	return clampi(int(Game.save.get("arpg_diff", 0)), 0, 1)


const WHET_ATK := 0.06
const FORGE_HP := 20.0


## 换手：主手和副手对调
func swap_arms() -> void:
	if (arms[1] as Dictionary).is_empty():
		return
	var a: Dictionary = arms[0]
	arms[0] = arms[1]
	arms[1] = a
	weapon = String(arms[0]["base"])


## 第二个护符槽（兵器架“双佩”解锁）
static func charm2_open() -> bool:
	return bool(Game.save.get("arpg_charm2", false))


## 捡到道具：已经有这种就叠上去（到上限为止），没有就占一格。返回实际放进去几个
func add_item(id: String, n: int = 1) -> int:
	var mx := int(ArpgArms.item(id).get("max", 3))
	for it: Dictionary in props:
		if String(it["id"]) == id:
			var add := mini(n, mx - int(it["n"]))
			it["n"] = int(it["n"]) + add
			return add
	if props.size() >= ArpgArms.ITEM_KINDS:
		return 0
	props.append({"id": id, "n": mini(n, mx)})
	return mini(n, mx)


## 还能再放几个这种道具（不改动）
func add_item_room(id: String) -> int:
	var mx := int(ArpgArms.item(id).get("max", 3))
	for it: Dictionary in props:
		if String(it["id"]) == id:
			return mx - int(it["n"])
	return mx if props.size() < ArpgArms.ITEM_KINDS else 0


func use_item(id: String) -> void:
	for i in range(props.size()):
		if String(props[i]["id"]) == id:
			props[i]["n"] = int(props[i]["n"]) - 1
			if int(props[i]["n"]) <= 0:
				props.remove_at(i)
			break
	prop_sel = clampi(prop_sel, 0, maxi(props.size() - 1, 0))


## 磨刀一次的价钱：越磨越贵（第三层铜钱多了也有地方花）
func whet_price() -> int:
	return 60 + 35 * whet


## 悟道：加悟，返回升了几重（每重 1 个天赋点）
func gain_xp(n: int) -> int:
	if level >= ArpgSkills.MAX_LEVEL:
		return 0
	xp += int(round(n * (1.0 + ArpgData.stat(ArpgData.talent_stats(), "xp"))))
	var ups := 0
	while level < ArpgSkills.MAX_LEVEL and xp >= ArpgSkills.need(level):
		xp -= ArpgSkills.need(level)
		level += 1
		points += 1
		ups += 1
	if level >= ArpgSkills.MAX_LEVEL:
		xp = 0
	return ups


## 点一级技能分支
func learn(bid: String) -> bool:
	if ArpgSkills.why_not(skills, points, bid) != "":
		return false
	skills[bid] = int(skills.get(bid, 0)) + 1
	points -= 1
	return true


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
	# 装备两件（四个部位里随机两个）、兵器一把、道具两样
	var slots: Array = ArpgData.GEAR_SLOTS.duplicate()
	for i in range(2):
		var slot := String(slots.pop_at(rng.randi_range(0, slots.size() - 1)))
		# 越往后货越好（也越贵）：第一层 良~精，第二层 精~珍，第三层 精~传
		var fl := floor_i()
		var it := ArpgGear.roll(rng, rng.randi_range(1 + mini(fl, 1), mini(2 + fl, 4)), 0.0, slot)
		var base := ArpgData.gear(String(it["base"]))
		items.append({"kind": "gear", "item": it, "name": it["name"], "desc": ArpgGear.slot_name(it) + "：" + ArpgGear.describe(it),
			"price": int(base["price"]) + 25 * int(it["rarity"])})
	var wi := ArpgGear.roll_weapon(rng, rng.randi_range(1, mini(2 + floor_i(), 4)))
	var wd := ArpgData.weapon(String(wi["base"]))
	items.append({"kind": "weapon", "item": wi, "name": wi["name"], "desc": "兵器：" + String(wd["desc"]) + "。" + ArpgGear.describe(wi),
		"price": 40 + int(wd["price"]) + 25 * int(wi["rarity"])})
	var ks := ArpgArms.ITEMS.keys()
	for i in range(2):
		var iid := String(ks.pop_at(rng.randi_range(0, ks.size() - 1)))
		var idef := ArpgArms.item(iid)
		items.append({"kind": "item", "id": iid, "name": idef["name"], "desc": "道具：" + String(idef["desc"]), "price": int(idef["price"])})
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


# ---------- 局中断点 ----------
## 整个状态存成字典（ArpgState 和 Run 上所有 var 都自动存进去，以后新加的字段不用改这里）。
## 存不进去的只有对象：Run.rng 另存种子和状态。
func to_dict() -> Dictionary:
	var d := SaveStore.dump_vars(self, ["run"])
	d["run"] = SaveStore.dump_vars(run, ["rng"])
	d["run_rng"] = [run.rng.seed, run.rng.state]
	return d


## 从字典恢复一局；数据不完整时返回 null
static func from_dict(d: Dictionary) -> ArpgState:
	if not (d.get("run") is Dictionary):
		return null
	var s := ArpgState.new()
	s.run = Run.new()
	SaveStore.load_vars(s, d, ["run"])
	SaveStore.load_vars(s.run, d["run"], ["rng"])
	var rr = d.get("run_rng", [])
	if rr is Array and (rr as Array).size() == 2:
		s.run.rng.seed = int(rr[0])
		s.run.rng.state = int(rr[1])
	var rows: Array = s.run.rows
	if rows.is_empty() or s.run.row < 0 or s.run.row >= rows.size() or s.run.col < 0 or s.run.col >= (rows[s.run.row] as Array).size():
		return null
	if s.act < 1 or s.act > ACT_NAMES.size():
		return null
	s.fix_kit()
	cur = s
	return s


## 旧断点（加兵器多重化、新装备部位之前存的）补齐：缺的部位补空、主手按 weapon 补上、坏掉的道具丢掉
func fix_kit() -> void:
	for slot: String in ["armor", "helm", "boots", "charm", "charm2"]:
		if not (gear.get(slot) is Dictionary):
			gear[slot] = {}
	if not ArpgData.WEAPONS.has(weapon):
		weapon = "sword"
	if arms.size() != 2:
		arms = [{}, {}]
	for i in range(2):
		if not (arms[i] is Dictionary):
			arms[i] = {}
		elif not (arms[i] as Dictionary).is_empty() and not ArpgData.WEAPONS.has(String(arms[i].get("base", ""))):
			arms[i] = {}
	if (arms[0] as Dictionary).is_empty() or String(arms[0]["base"]) != weapon:
		arms[0] = ArpgGear.weapon_item(weapon)
	var ok := []
	for it in props:
		if it is Dictionary and ArpgArms.ITEMS.has(String(it.get("id", ""))) and int(it.get("n", 0)) > 0:
			ok.append(it)
	props = ok
	prop_sel = clampi(prop_sel, 0, maxi(props.size() - 1, 0))
