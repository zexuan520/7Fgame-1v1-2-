class_name ArpgDaily
extends RefCounted
## 每日挑战与种子局（山门光门右边的告示牌，出发过一次以后才出现）。
##   每日挑战：按当天日期定种子（同一天进几次都是同一张图）、哪一幕、兵器（只带这一把）、天象和一条“今日规矩”。
##            一局跑完（登顶或身死）记当天最好成绩；每天第一次跑完给魂玉。轮回不算（固定本相），难度照你选的。
##   种子局：用上一局的种子和天象再走一次同一张图（规矩照常、轮回照你选的）。
## 存档：arpg_daily {"date", "score", "txt", "won", "tries", "paid"}（只记最近一天）、arpg_daily_days [跑完过的日期]、
##       arpg_last_seed {"seed", "act", "omen"}（上一局，不含每日挑战）
## 测试参数：--daily（不看解锁，山门立告示牌）、--dailydate=2026-11-06（换一天）、--dailyrule=horde（换规矩）、
##           --dailygo（配 --demo 等直接开今天的挑战，代替 --act）

## 今日规矩：stats 加到主角身上；count / hp / speed 改小怪（头目不改数量）
const RULES := {
	"kensei": {"name": "一刀流", "desc": "伤害 +50%，受伤也 +50%", "stats": {"atk": 0.5, "taken_extra": 0.5}},
	"dry": {"name": "断药", "desc": "药葫芦 -3（至少留 1 个），换来吸血 +5%、斩杀回 3 血", "stats": {"gourds": -3, "lifesteal": 0.05, "kill_heal": 3.0}},
	"master": {"name": "宗师", "desc": "出发就带着同一流派的三个心法，开局就大成", "stats": {}},
	"horde": {"name": "百鬼夜行", "desc": "敌人多五成，但血少两成五", "count": 1.5, "hp": 0.75, "stats": {}},
	"greed": {"name": "富贵险中求", "desc": "铜钱翻倍、魂玉 +30%，代价是受伤 +20%", "stats": {"coin": 1.0, "jade": 0.3, "taken_extra": 0.2}},
	"swift": {"name": "疾行", "desc": "移速 +25%、突进冷却 -30%；敌人也快 15%", "speed": 1.15, "stats": {"move": 0.25, "dash_cd": 0.3}},
	"bloodpact": {"name": "血契", "desc": "生命上限 -30，所有出血伤害 +80%、每刀出血 +1", "stats": {"hp": -30.0, "bleed_dmg": 0.8, "bleed": 1}},
}
const SCHOOLS := ["修罗", "血", "风", "光", "守", "雷", "焰"]
const C_BOARD := Color(1.0, 0.82, 0.5)
const BOARD_POS := Vector3(3.6, 0, 0)   # z 按山门大小算（光门右边，和轮回盘对称）


static func _args() -> PackedStringArray:
	return OS.get_cmdline_user_args()


static func _arg(k: String) -> String:
	for a: String in _args():
		if a.begins_with("--%s=" % k):
			return a.substr(k.length() + 3)
	return ""


## 今天的日期（本机时间），--dailydate 可以换
static func today() -> String:
	var o := _arg("dailydate")
	if o != "":
		return o
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


static func date_cn(date: String) -> String:
	var p := date.split("-")
	if p.size() < 3:
		return date
	return "%d月%d日" % [int(p[1]), int(p[2])]


## 已经打开的幕（每日挑战只会抽到你走得进去的幕）
static func acts_open() -> Array:
	var out := [1]
	if not (Game.save.get("arpg_endings", {}) as Dictionary).is_empty():
		out.append(2)
	if not (Game.save.get("arpg_act2_endings", {}) as Dictionary).is_empty():
		out.append(3)
	return out


## 这一天的挑战：同一天、同样的已开幕数，结果都一样
static func plan(date: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("canren_daily_" + date)
	var seed_v := rng.randi() & 0x7fffffff
	var acts := acts_open()
	var act: int = acts[rng.randi_range(0, acts.size() - 1)]
	var ws := ArpgData.WEAPONS.keys()
	var weapon := String(ws[rng.randi_range(0, ws.size() - 1)])
	var oms := ArpgState.OMENS.keys()
	var omen := String(oms[rng.randi_range(0, oms.size() - 1)])
	var rs := RULES.keys()
	var rule := String(rs[rng.randi_range(0, rs.size() - 1)])
	var school := String(SCHOOLS[rng.randi_range(0, SCHOOLS.size() - 1)])
	var r := _arg("dailyrule")
	if RULES.has(r):
		rule = r
	return {"kind": "daily", "date": date, "seed": seed_v, "act": act, "weapon": weapon, "omen": omen, "rule": rule, "school": school}


static func open_for(main: ArpgMain) -> bool:
	return int(Game.save.get("runs", 0)) > 0 or main._args.has("daily")


## 山门：光门右边立一块告示牌
static func hub(main: ArpgMain) -> void:
	if not open_for(main):
		return
	var p := BOARD_POS + Vector3(0, 0, -ArpgMain.HUB_SIZE.y * 0.5 + 3.4)
	var d: Dictionary = Game.save.get("arpg_daily", {})
	var done_today := String(d.get("date", "")) == today()
	main._npc("告示牌 · 每日挑战" + (" ✓" if done_today else ""), p, {"kit": "banner", "scale": 1.2}, func(n: ArpgNpc) -> void: open_board(main, n))
	main.arena.spirit_fire(p + Vector3(0, 1.0, 0), C_BOARD, 0.9, 1.6, 5.0)


static func describe(p: Dictionary) -> String:
	var rd: Dictionary = RULES[p["rule"]]
	var om: Dictionary = ArpgState.OMENS.get(p["omen"], {})
	var s := "%s · 只带%s · 天象%s\n今日规矩「%s」：%s" % [ArpgState.ACT_NAMES[int(p["act"])], ArpgData.weapon(String(p["weapon"]))["name"], om.get("name", "无"), rd["name"], rd["desc"]]
	if p["rule"] == "master":
		s += "（今天是「%s」）" % p["school"]
	return s


static func open_board(main: ArpgMain, n: ArpgNpc = null) -> void:
	var date := today()
	var p := plan(date)
	var d: Dictionary = Game.save.get("arpg_daily", {})
	var mine := String(d.get("date", "")) == date
	var items := [{"title": "今日挑战 · %s" % date_cn(date), "desc": describe(p), "tag": "每日",
		"right": ("今日最好：" + String(d.get("txt", ""))) if mine else "还没挑战", "color": C_BOARD}]
	var ls: Dictionary = Game.save.get("arpg_last_seed", {})
	if not ls.is_empty():
		var om: Dictionary = ArpgState.OMENS.get(String(ls.get("omen", "")), {})
		items.append({"title": "种子局 · 重走上一局的图", "tag": "种子",
			"desc": "%s · 种子 %d · 天象%s。房间、路线和第一件道具都和上一局一样，心法掉落看手气" % [ArpgState.ACT_NAMES.get(int(ls.get("act", 1)), ""), int(ls.get("seed", 0)), om.get("name", "无")],
			"color": Color(0.7, 0.85, 1.0)})
	items.append({"title": "算了", "desc": ""})
	var days: Array = Game.save.get("arpg_daily_days", [])
	var sub := "同一天谁来都是同一张图。每天第一次跑完给魂玉　·　挑战过 %d 天，最长连着 %d 天" % [days.size(), streak(days)]
	var m := main._open_menu("告示牌", sub, items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		main._close_menu()
		if i == 0:
			start(main, p)
		elif i == 1 and not ls.is_empty():
			start(main, {"kind": "seed", "seed": int(ls["seed"]), "act": int(ls.get("act", 1)), "omen": String(ls.get("omen", ""))}))


## 最长连续天数
static func streak(days: Array) -> int:
	var best := 0
	var cur := 0
	var prev := -1
	var ds := days.duplicate()
	ds.sort()
	for dd: String in ds:
		var u := Time.get_unix_time_from_datetime_string(dd + "T12:00:00")
		var dn := int(u / 86400)
		cur = cur + 1 if prev >= 0 and dn == prev + 1 else 1
		prev = dn
		best = maxi(best, cur)
	return best


## 开一局：ArpgState.start_new 读 ArpgState.pending
static func start(main: ArpgMain, p: Dictionary) -> void:
	if main.mode != "hub":
		return
	main._going = true
	Game.sfx("door")
	ArpgState.pending = p
	main._start_run(true, int(p["act"]))
	after_start(main, p)
	main._fade_then(func() -> void: main._enter_room())


## 出发以后：每日挑战的心法、掉落也跟着种子走；“宗师”规矩先发三个同流派心法
static func after_start(main: ArpgMain, p: Dictionary) -> void:
	var st := main.state
	if String(p["kind"]) == "daily":
		main._rng.seed = int(p["seed"]) + 991   # 心法、掉落也跟着种子走（打法不同还是会岔开）
		if String(p["rule"]) == "master":
			var pool := []
			for b: Dictionary in ArpgData.BOONS:
				if String(b.get("school", "")) == String(p["school"]) and not b.get("hidden", false):
					pool.append(String(b["id"]))
			var r := RandomNumberGenerator.new()
			r.seed = int(p["seed"]) + 5
			for i in range(ArpgData.SET_NEED):
				if not pool.is_empty():
					st.boons.append(String(pool[r.randi_range(0, pool.size() - 1)]))
		main.hero.apply_stats(st.stats(), st.weapon, true)
		main.hero.revives = st.revives


## 出发时（ArpgMain._start_run 末尾）：普通局记下种子，给“种子局”用
static func on_start(st: ArpgState) -> void:
	if String(st.daily.get("kind", "")) == "daily":
		return
	Game.save["arpg_last_seed"] = {"seed": st.seed_value, "act": st.act, "omen": st.omen}
	Game.write_save()


## 规矩给敌人的倍率（count / hp / speed），不是每日挑战就是 1
static func foe_mult(st: ArpgState, k: String) -> float:
	if st == null or String(st.daily.get("kind", "")) != "daily":
		return 1.0
	return float((RULES.get(String(st.daily.get("rule", "")), {}) as Dictionary).get(k, 1.0))


## 规矩给主角的 stats（ArpgState.stat_parts 调）
static func rule_part(st: ArpgState) -> Array:
	if String(st.daily.get("kind", "")) != "daily":
		return []
	var rd: Dictionary = RULES.get(String(st.daily.get("rule", "")), {})
	if rd.is_empty():
		return []
	return ["今日规矩·%s" % rd["name"], rd.get("stats", {})]


## 一局结束（ArpgMain._game_over）：每日挑战记成绩、发首次魂玉；返回要显示在结算菜单里的几行
static func on_end(main: ArpgMain, won: bool) -> Array:
	var st := main.state
	if st == null or String(st.daily.get("kind", "")) != "daily":
		return []
	var date := String(st.daily.get("date", today()))
	var secs := int(main._clock - main._run_t0)
	var fl := st.floor_i() + 1
	var row := st.run.row + 1
	# 分数：登顶最高；同样登顶比用时，没登顶比走到哪一间
	var score := 1000000 - secs if won else fl * 1000 + row
	var txt := ("登顶 · %d:%02d" % [secs / 60, secs % 60]) if won else "第 %d 层第 %d 间" % [fl, row]
	var d: Dictionary = Game.save.get("arpg_daily", {})
	if String(d.get("date", "")) != date:
		d = {"date": date, "score": -1, "txt": "", "won": false, "tries": 0, "paid": false}
	d["tries"] = int(d.get("tries", 0)) + 1
	var lines := []
	var better := score > int(d.get("score", -1))
	if better:
		d["score"] = score
		d["txt"] = txt
		d["won"] = bool(d.get("won", false)) or won
	lines.append("%s　%s%s" % [date_cn(date), txt, "（今日最好）" if better else "（今日最好：%s）" % d["txt"]])
	if not bool(d.get("paid", false)):
		d["paid"] = true
		var pay := 15 + 10 * (fl - 1) + (30 if won else 0)
		Game.save["jade"] = int(Game.save["jade"]) + pay
		lines.append("今天第一次跑完：魂玉 +%d" % pay)
	Game.save["arpg_daily"] = d
	var days: Array = Game.save.get("arpg_daily_days", [])
	if not days.has(date):
		days.append(date)
		days.sort()
		while days.size() > 60:
			days.pop_front()
	Game.save["arpg_daily_days"] = days
	Game.write_save()
	ArpgAch.unlock("daily_1")
	if won:
		ArpgAch.unlock("daily_win")
	if days.size() >= 7:
		ArpgAch.unlock("daily_7")
	if main._args.has("tel"):
		print("DAILY date=%s won=%s score=%d txt=%s tries=%d" % [date, won, score, txt, int(d["tries"])])
	return lines
