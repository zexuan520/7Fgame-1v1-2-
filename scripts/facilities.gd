class_name Facilities
extends RefCounted
## 破庙的设施（设计文档第 12 节）：铁铺、药房、老钱的铺子、训练场。都花魂玉，买了永久有效。
## 拾骨婆的天赋、招式谱、忆境、兵器架在各自的脚本里（Talents、Arts、Story、Game）。
##
## 每个设施一张表；rows(kind) 给界面列出现在能做的事，buy(kind, row) 去做。
## 加新的一项：在对应的表里加一条，再在 rows() 里列出来、buy() 里写它做什么，效果在 apply_stats() 或 start_gear() 里生效。

## 解锁条件：forge 打败柳江远一次 / pharmacy 在第二层救下白芦 / qian 在老钱那里累计花够铜钱 / training 一开始就有
const UNLOCK_TEXT := {
	"forge": "打败第一层头目后开张",
	"pharmacy": "在第二层救下药师白芦",
	"qian": "在老钱那里累计花 %d 铜钱",
}

## 铁铺（铁匠阿强）：出发武器的品质、武器图谱（直接挂上兵器架）、忍具（副武器，价格在 Items.SUBS）、出发防具
const FORGE := {
	"weapon_q": [30, 80, 160],                 # 出发武器升到良品、精品、绝品的价格
	"weapon_unlock": 40,                       # 打一把新武器挂上兵器架
	"armor": {"head": ["kasa", 25], "body": ["leather", 35]},   # 出发带的防具（凡品）和价格
}

## 药房（药师白芦）：药罐次数、回复量
const PHARMACY := {
	"gourd": [40, 90],                          # 药罐 +1，最多两次
	"heal": [25, 50, 90],                       # 回复量 +5%，最多三次
	"heal_step": 0.05,
}

## 老钱的铺子：累计花够铜钱后来破庙开店
const QIAN := {
	"threshold": 300,                           # 在老钱那里累计花这么多铜钱
	"pick": 10,                                 # 定向商品：指定一个招式，以后他货架上的招式卷就是它
	"charm": 20,                                # 饰品图谱：解锁一种饰品，可以选一件出发带着
}


static func data() -> Dictionary:
	return Game.save["hub"]


static func unlocked(kind: String) -> bool:
	match kind:
		"forge": return int(Game.save["boss_kills"].get("liu", 0)) >= 1
		"pharmacy": return bool(data().get("herbalist", false))
		"qian": return int(data().get("qian_spent", 0)) >= int(QIAN["threshold"])
	return true


static func lock_text(kind: String) -> String:
	var t: String = UNLOCK_TEXT.get(kind, "")
	return t % int(QIAN["threshold"]) if kind == "qian" else t


## 老钱那里花了钱（商人房里买东西、找他强化重铸、刷新货架都算）
static func add_qian_spent(n: int) -> void:
	data()["qian_spent"] = int(data().get("qian_spent", 0)) + n


## 界面列出来的每一行：{id, label, sub, cost（魂玉，0 = 免费）, done（已经买满/选上了）}
static func rows(kind: String) -> Array:
	var out := []
	var d := data()
	match kind:
		"forge":
			var q := int(d.get("weapon_q", 0))
			if q < (FORGE["weapon_q"] as Array).size():
				out.append({"id": "weapon_q", "label": "出发武器 → %s" % GearData.QUALITIES[q + 1]["name"],
					"sub": "出发带的武器从%s打到%s，词条每局随机" % [GearData.QUALITIES[q]["name"], GearData.QUALITIES[q + 1]["name"]],
					"cost": int(FORGE["weapon_q"][q])})
			for w: String in GearData.WEAPONS:
				if not (Game.save["weapons"] as Array).has(w):
					var wd: Dictionary = GearData.WEAPONS[w]
					out.append({"id": "weapon:" + w, "label": "武器图谱 · %s" % wd["name"],
						"sub": "打一把挂上兵器架：%s" % wd["trait_desc"], "cost": int(FORGE["weapon_unlock"])})
			var subs: Array = d.get("subs", [])
			for id: String in Items.SUBS:
				var sd: Dictionary = Items.SUBS[id]
				if int(sd["unlock"]) > 0 and not subs.has(id):
					out.append({"id": "sub:" + id, "label": "忍具 · %s" % sd["name"],
						"sub": "%s（每次耗纸人 %d）" % [sd["desc"], int(sd["paper"])], "cost": int(sd["unlock"])})
			for slot: String in FORGE["armor"]:
				var a: Array = FORGE["armor"][slot]
				var have := bool(d.get("armor_" + slot, false))
				out.append({"id": "armor:" + slot, "label": "出发带%s" % GearData.ARMOR[a[0]]["name"],
					"sub": "每局出发身上就穿着（凡品，%s）" % GearData.ARMOR[a[0]]["weight"], "cost": int(a[1]), "done": have})
		"pharmacy":
			var g := int(d.get("gourd", 0))
			out.append({"id": "gourd", "label": "药罐 +1（%d/%d）" % [g, (PHARMACY["gourd"] as Array).size()],
				"sub": "每局多带一罐药", "cost": int(PHARMACY["gourd"][mini(g, 1)]), "done": g >= (PHARMACY["gourd"] as Array).size()})
			var h := int(d.get("heal", 0))
			out.append({"id": "heal", "label": "回复量 +5%%（%d/%d）" % [h, (PHARMACY["heal"] as Array).size()],
				"sub": "每口药多回 5% 生命", "cost": int(PHARMACY["heal"][mini(h, 2)]), "done": h >= (PHARMACY["heal"] as Array).size()})
		"qian":
			var pick: String = d.get("pick", "")
			for id: String in Arts.ARTS:
				if id == Arts.STARTER or not Arts.in_pool("art", id):
					continue
				var on := pick == id
				out.append({"id": "pick:" + id, "label": "定向商品 · %s%s" % [Arts.ARTS[id]["name"], "（已定）" if on else ""],
					"sub": "以后老钱货架上的招式卷就是它（再选一次取消）", "cost": 0 if on else int(QIAN["pick"])})
			var charms: Array = d.get("charms", [])
			for id: String in GearData.MECHS:
				var m: Dictionary = GearData.MECHS[id]
				if charms.has(id):
					var on2: bool = d.get("charm", "") == id
					out.append({"id": "charm:" + id, "label": "出发带%s%s" % [m["name"], "（带着）" if on2 else ""],
						"sub": m["desc"], "cost": 0})
				else:
					out.append({"id": "charm:" + id, "label": "饰品图谱 · %s" % m["name"], "sub": m["desc"], "cost": int(QIAN["charm"])})
	return out


## 买下这一行；返回 "" 表示成功，否则是原因
static func buy(row: Dictionary) -> String:
	if row.get("done", false):
		return "已经有了"
	var cost := int(row["cost"])
	if int(Game.save["jade"]) < cost:
		return "魂玉不够"
	var d := data()
	var id: String = row["id"]
	var parts := id.split(":")
	match parts[0]:
		"weapon_q":
			d["weapon_q"] = int(d.get("weapon_q", 0)) + 1
		"weapon":
			Game.unlock_weapon(parts[1])
		"armor":
			d["armor_" + parts[1]] = true
		"sub":
			var subs: Array = d.get("subs", [])
			subs.append(parts[1])
			d["subs"] = subs
		"gourd":
			d["gourd"] = int(d.get("gourd", 0)) + 1
		"heal":
			d["heal"] = int(d.get("heal", 0)) + 1
		"pick":
			d["pick"] = "" if d.get("pick", "") == parts[1] else parts[1]
		"charm":
			var charms: Array = d.get("charms", [])
			if charms.has(parts[1]):
				d["charm"] = "" if d.get("charm", "") == parts[1] else parts[1]
			else:
				charms.append(parts[1])
				d["charms"] = charms
				d["charm"] = parts[1]
	Game.save["jade"] = int(Game.save["jade"]) - cost
	Game.write_save()
	return ""


## 药房的加成加到 stats 表里
static func apply_stats(s: Dictionary) -> void:
	var d := data()
	s["gourds"] = int(s["gourds"]) + int(d.get("gourd", 0))
	s["gourd_heal"] = float(s["gourd_heal"]) + float(PHARMACY["heal_step"]) * int(d.get("heal", 0))


## 一局开始时身上的装备：铁铺打过的武器品质、出发防具、老钱那里选的饰品
static func start_gear(g: Dictionary, rng: RandomNumberGenerator) -> void:
	var d := data()
	var q := int(d.get("weapon_q", 0))
	if q > 0:
		g["weapon"] = GearData.make("weapon", g["weapon"]["base"], q, rng)
	for slot: String in FORGE["armor"]:
		if bool(d.get("armor_" + slot, false)) and g[slot] == null:
			g[slot] = GearData.make(slot, FORGE["armor"][slot][0], 0, rng)
	var charm: String = d.get("charm", "")
	if charm != "":
		var item := GearData.make("charm", charm, 0, rng)
		if g["charm1"] == null:
			g["charm1"] = item
		elif g["charm2"] == null:
			g["charm2"] = item


## 老钱的定向商品（没定、或者已经不在掉落池里就是 ""）
static func picked_art() -> String:
	var id: String = data().get("pick", "")
	return id if id != "" and Arts.ARTS.has(id) and Arts.in_pool("art", id) else ""
