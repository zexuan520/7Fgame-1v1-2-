class_name ArpgRelics
extends RefCounted
## 奇物：比心法稀有、会改变打法的东西。精英房、门上写“奇物”的战斗房、游商、诅咒祭坛能拿到，一局里可以有很多件。
## 每件带 1~2 个流派标签（tags），标签和心法一起算流派件数（凑大成、凑双修），所以奇物是跨流派协同的桥。
## 强的带代价（cost 写给玩家看，代价本身写在 stats 里）。
## stats 走和心法一样的 stats 表；机制效果由 HeroRelics 按 "r_<id>" 键判断（ArpgState.stat_parts 会自动加上）。
## lock：开局不在掉落池里，要在山门解锁（ArpgChars.unlock_relic，见第 5 批）。
## 想加一件：在 LIST 里加一行；纯数值就只写 stats，带机制的在 HeroRelics 里按 id 写触发点。

const LIST := [
	# ---------- 开局就在池子里 ----------
	{"id": "duanxian", "name": "断弦", "tags": ["修罗"], "desc": "会心伤害 +60%", "cost": "不会心的攻击伤害 -20%",
		"stats": {"crit_dmg": 0.6}},
	{"id": "lingying", "name": "留影符", "tags": ["风", "魂"], "desc": "每次翻滚在原地留一个残影，半秒后炸开（冷却 1.5 秒）", "cost": "",
		"stats": {}},
	{"id": "xueshu", "name": "血书", "tags": ["血", "守"], "desc": "每斩杀一个敌人回 3% 最大生命", "cost": "生命上限 -20%",
		"stats": {"hp_pct": -0.2, "kill_heal_pct": 0.03}},
	{"id": "chuanxue", "name": "传血蛊", "tags": ["血"], "desc": "出血的敌人死时，身上的出血层数全部传给最近的敌人", "cost": "",
		"stats": {"bleed": 1}},
	{"id": "tiezhuang", "name": "铁桩", "tags": ["守", "修罗"], "desc": "站着出刀不挪步 0.5 秒后扎桩：伤害 +25%、受伤 -20%；一走动就散", "cost": "",
		"stats": {}},
	{"id": "jinggu", "name": "荆骨", "tags": ["守", "血"], "desc": "挨打时给打你的敌人叠 4 层出血，并反弹 30% 伤害", "cost": "药葫芦 -1",
		"stats": {"thorns": 0.3, "gourds": -1}},
	{"id": "bilei", "name": "避雷针", "tags": ["雷"], "desc": "每 5 秒自动在最近的敌人身上劈一道雷", "cost": "受伤 +8%",
		"stats": {"taken_extra": 0.08}},
	{"id": "leigu", "name": "雷鼓", "tags": ["雷", "风"], "desc": "突进斩每穿过一个敌人，在它身上引一道雷", "cost": "突进斩冷却 +20%",
		"stats": {"dash_cd": -0.2}},
	{"id": "sanzhe", "name": "三折光", "tags": ["光"], "desc": "光束斩分成扇形三道，照得更宽", "cost": "每道伤害 -35%",
		"stats": {}},
	{"id": "huoyou", "name": "火油葫芦", "tags": ["焰", "守"], "desc": "药葫芦 +1；喝药时身边炸开三团火", "cost": "药葫芦回复 -10%",
		"stats": {"gourds": 1, "gourd_heal": -0.1}},
	{"id": "zhaohun", "name": "招魂幡", "tags": ["魂"], "desc": "斩杀时 60% 机会收一团魂火（魂火上限 +2），魂火绕身自动飞向敌人", "cost": "生命上限 -15",
		"stats": {"soul_rate": 0.6, "soul_max": 2, "hp": -15.0}},
	{"id": "tanlang", "name": "贪狼牙", "tags": ["修罗", "血"], "desc": "这间房里每斩杀一个敌人伤害 +2%（最多 +40%，换房清零）", "cost": "受伤 +10%",
		"stats": {"taken_extra": 0.1}},
	# ---------- 要解锁 ----------
	{"id": "guiyan", "name": "鬼眼", "tags": ["修罗", "风"], "desc": "翻滚后 1.5 秒内会心率 +35%", "cost": "", "stats": {}, "lock": true},
	{"id": "nifeng", "name": "逆风", "tags": ["风"], "desc": "见切的时机放宽到翻滚头 0.35 秒，见切后 3 秒伤害 +40%", "cost": "翻滚无敌 -0.04 秒",
		"stats": {"iframes": -0.04}, "lock": true},
	{"id": "manyue", "name": "满月", "tags": ["光", "守"], "desc": "气力满格时受伤 -35%", "cost": "气力获取 -15%",
		"stats": {"energy": -0.15}, "lock": true},
	{"id": "jinxin", "name": "烬心", "tags": ["焰"], "desc": "斩杀的敌人必定爆燃", "cost": "生命上限 -20",
		"stats": {"kill_fire": 1.0, "hp": -20.0}, "lock": true},
	{"id": "gudi", "name": "骨笛", "tags": ["魂", "雷"], "desc": "魂火打中时 25% 机会引一道落雷；斩杀时 20% 机会收魂火", "cost": "",
		"stats": {"soul_rate": 0.2}, "lock": true},
	{"id": "shuangling", "name": "双生铃", "tags": ["风", "雷"], "desc": "换兵器后的第一刀必定会心，换手时身边放一圈雷", "cost": "", "stats": {}, "lock": true},
	{"id": "jianpu", "name": "无名剑谱", "tags": ["风", "光"], "desc": "连招最后一段打中后，突进斩冷却立刻减半", "cost": "", "stats": {}, "lock": true},
	{"id": "zhenhun", "name": "镇魂钟", "tags": ["守", "魂"], "desc": "每 10 秒自动震一圈金环，推开身边的敌人并让它们晕 0.8 秒", "cost": "", "stats": {}, "lock": true},
]

const COLOR := Color(1.0, 0.62, 0.3)


static func get_relic(id: String) -> Dictionary:
	for r: Dictionary in LIST:
		if r["id"] == id:
			return r
	return {}


static func tags(id: String) -> Array:
	return get_relic(id).get("tags", [])


## 这件奇物的 stats（加上机制标记 r_<id>，HeroRelics 用）
static func stats_of(id: String) -> Dictionary:
	var st: Dictionary = (get_relic(id).get("stats", {}) as Dictionary).duplicate()
	st["r_" + id] = 1.0
	return st


static func unlocked(id: String) -> bool:
	var r := get_relic(id)
	if r.is_empty():
		return false
	if not r.get("lock", false):
		return true
	return (Game.save.get("arpg_relics_open", []) as Array).has(id)


## 抽 n 件这一局还没有的奇物（解锁了的才进池）
static func roll(n: int, have: Array, rng: RandomNumberGenerator) -> Array:
	var pool := []
	for r: Dictionary in LIST:
		if not have.has(r["id"]) and unlocked(String(r["id"])):
			pool.append(r)
	var out := []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


## 卡片上的说明：效果，再一行代价
static func card_desc(r: Dictionary) -> String:
	var c := String(r.get("cost", ""))
	return String(r["desc"]) + ("。代价：" + c if c != "" else "")


static func tag_text(r: Dictionary) -> String:
	return "奇物 · " + "·".join(r.get("tags", []))
