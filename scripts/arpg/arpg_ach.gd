class_name ArpgAch
extends RefCounted
## 成就：跨局永久记录在存档里（Game.save["ach"] = {id: 解锁时的 unix 秒}，累计数在 Game.save["ach_stat"]）。
## 网页版的 user:// 存在浏览器 IndexedDB 里，刷新、关掉再开都还在。
## 解锁时调 on_unlock（ArpgMain 接到 AchToast 弹窗）。山门“功业碑”和暂停菜单里能看全部成就。

## [id, 名字, 怎么拿, 隐藏（没拿到时不显示说明）]
const LIST := [
	["first_run", "初出山门", "第一次从山门出发", false],
	["tutorial", "试刀", "走完试刀场教学", false],
	["first_death", "残刃折", "第一次身死", false],
	["deaths_10", "百折不回", "累计身死 10 次", false],
	["boss1", "夜樱散尽", "打倒第一层头目夜樱", false],
	["boss2", "万骨归土", "打倒第二层头目百骨将", false],
	["clear", "残刃归途", "登顶古寺，打完一局", false],
	["clears_3", "三上古寺", "累计登顶 3 次", false],
	["clear_fast", "一气呵成", "20 分钟内登顶", false],
	["clear_dry", "滴药未沾", "一口药葫芦都不喝，登顶", false],
	["boss_clean", "毫发无伤", "不挨一下，打倒一个头目", false],
	["room_clean", "片叶不沾身", "不挨一下，清完一间战斗房", false],
	["combo_25", "刀不停", "打出 25 连击", false],
	["combo_50", "行云流水", "打出 50 连击", false],
	["combo_100", "百刃千锋", "打出 100 连击", false],
	["burst_5", "血雨", "一次血爆炸到 5 个敌人", false],
	["kills_100", "斩百", "累计斩敌 100", false],
	["kills_1000", "斩千", "累计斩敌 1000", false],
	["seal_1", "得印", "在试炼房拿到第一枚印", false],
	["seal_4", "四印俱全", "一间试炼房里拿齐疾、守、狂、乱四印", false],
	["set_any", "流派大成", "一局里同一流派的心法拿够 3 个", false],
	["side_1", "推门而入", "第一次拿完一间侧室", false],
	["side_20", "门门都推", "累计拿完 20 间侧室", false],
	["side_ambush", "反客为主", "在侧室里打退一次伏兵", false],
	["side_trial", "限时斩尽", "在时限内过一次侧室小试炼", false],
	["secret", "墙后有风", "打塌裂墙，走进密室", true],
	["gear_legend", "传世之物", "得到一件「传」品装备", false],
	["rich", "腰缠万贯", "一局里身上同时揣着 300 铜钱", false],
	["pages", "五页残卷", "集齐寂光的五页残页", true],
	["end_true", "师父的字", "看到真结局", true],
	["end_all", "灯明灯灭", "三种结局都看过", true],
	["kite", "纸鸢", "凑齐阿樱的风筝", true],
	["names", "十二个名字", "替无名冢的人认回全部名字", true],
	["shadow", "替我回来", "打倒隐藏头目残影", true],
	["end_souls", "众生", "看到隐藏结局 · 众生", true],
	["weapons_all", "兵器满架", "兵器架上的兵器全部收齐", false],
	# 第二幕
	["act2", "入井", "第一次走进第二幕的“入井”光门", false],
	["boss4", "灯链尽断", "打倒第二幕头目井中人·枯荣", false],
	["jizo_home", "地藏归位", "把井底捡到的石头放回无头地藏身上", true],
	["boss5", "长夜将尽", "打倒第二幕头目不夜将军", false],
	["hag_truth", "守灯一族", "听拾骨婆说出自己的身世", true],
	["boss6", "灰灯", "打倒第二幕头目执灯使·烬", false],
	["letters", "家书", "找齐烬的五封家书", true],
	["smith", "刀镡", "替老刀匠找齐寒铁、烛铜、灰衣印", true],
	["end2_zhan", "斩烬", "第二幕结局：斩烬", false],
	["end2_du", "渡烬", "第二幕结局：渡烬", true],
	["end2_he", "合刃", "第二幕真结局：合刃", true],
	# 第二幕 · 扩充（新小怪、独有侧室）
	["a2_foes", "山中百态", "引魂灯童、井鳗骨、泼油俑、殉灯俑、灰衣枪兵、灰衣旗手都斩过", false],
	["lampkid_10", "吹灯", "累计打灭 10 个引魂灯童", false],
	["eel_15", "截流", "累计斩 15 条井鳗骨", false],
	["twin_pair", "同穴", "一秒之内打倒两只殉灯俑", false],
	["flag_cut", "斩旗", "灰衣旗手还没举过旗就把他斩了", false],
	["wish", "投钱问井", "在青井的许愿井里投一次钱", false],
	["forge", "回炉", "在灯冢的熔铜炉里淬刃、铸甲或熔一件装备", false],
	["cage_10", "破笼", "累计从灰衣营的木笼里放出 10 个人", false],
	["side_act2", "山中别室", "许愿井、熔铜炉、木笼三种侧室都进过", false],
	# 各层独有小怪、精英词缀
	["a1_foes", "山下三怪", "瘴菇骨、抬棺骨、铜钟僧都斩过", false],
	["affix_30", "斩将", "累计斩 30 只带词缀的精英", false],
	# 轮回（通关后的加难，见 ArpgCycle）
	["cycle_1", "再入轮回", "在轮回一或更高打通一幕", false],
	["cycle_5", "五世", "在轮回五或更高打通一幕", false],
	["cycle_10", "十世归途", "在轮回十打通一幕", false],
	# 悟道、技能分支、连携、双修
	["lv_10", "十重悟道", "一局里悟道到第十重", false],
	["branch_max", "一招通透", "把一条技能分支点满三级", false],
	["link_1", "招招相连", "第一次打出连携", false],
	["link_all", "七式俱通", "瞬狱、残月、焚血、天落、血步、风雷、归一七种连携都打出过", false],
	["art_all", "四门秘技", "旋风、飞轮、震岳、分身四种秘技都学过", false],
	["dual_any", "双修", "一局里凑成一种双修", false],
]

## 第二幕扩充的新小怪（全都斩过：山中百态）
const A2_FOES := ["lampkid", "eel", "oiler", "twin", "greyspear", "greyflag"]
## 第一幕每层独有的小怪（全都斩过：山下三怪）
const A1_FOES := ["sporer", "coffin", "bellmonk"]

## 累计数到了就解锁：统计键 → [[数量, 成就id], ...]
const STAT_GOALS := {
	"kills": [[100, "kills_100"], [1000, "kills_1000"]],
	"side_rooms": [[20, "side_20"]],
	"freed": [[10, "cage_10"]],
	"k_lampkid": [[10, "lampkid_10"]],
	"k_eel": [[15, "eel_15"]],
	"k_affix": [[30, "affix_30"]],
}

static var on_unlock: Callable      # func(id: String, name: String, desc: String)
static var enabled := true          # 测试（无敌机器人）时关掉，免得刷满存档


static func _got() -> Dictionary:
	if not Game.save.has("ach") or not (Game.save["ach"] is Dictionary):
		Game.save["ach"] = {}
	return Game.save["ach"]


static func has(id: String) -> bool:
	return _got().has(id)


static func count() -> int:
	return _got().size()


static func info(id: String) -> Array:
	for a: Array in LIST:
		if a[0] == id:
			return a
	return []


## 解锁一个成就；第一次解锁时存档并弹窗。quiet 时只记下不弹（补发旧存档用）
static func unlock(id: String, quiet: bool = false) -> bool:
	if not enabled or has(id):
		return false
	var a := info(id)
	if a.is_empty():
		push_warning("未知成就 " + id)
		return false
	_got()[id] = int(Time.get_unix_time_from_system())
	Game.write_save()
	if not quiet and on_unlock.is_valid():
		on_unlock.call(id, String(a[1]), String(a[2]))
	return true


static func stat(key: String) -> int:
	var st: Dictionary = Game.save.get("ach_stat", {})
	return int(st.get(key, 0))


## 累计数加 n（不单独写盘：跟着下一次存档一起存），到目标就解锁
static func add(key: String, n: int = 1) -> void:
	if not enabled or n <= 0:
		return
	if not Game.save.has("ach_stat") or not (Game.save["ach_stat"] is Dictionary):
		Game.save["ach_stat"] = {}
	var v := stat(key) + n
	Game.save["ach_stat"][key] = v
	for g: Array in STAT_GOALS.get(key, []):
		if v >= int(g[0]):
			unlock(String(g[1]))


## 斩了一只敌人：第二幕新小怪记种类、记数
static func killed(kind: String) -> void:
	if not enabled:
		return
	for pair: Array in [[A2_FOES, "a2_foes"], [A1_FOES, "a1_foes"]]:
		var lst: Array = pair[0]
		if not lst.has(kind):
			continue
		add("k_" + kind)
		var st: Dictionary = Game.save.get("ach_stat", {})
		var all := true
		for k: String in lst:
			if int(st.get("k_" + k, 0)) <= 0:
				all = false
		if all:
			unlock(String(pair[1]))


## 打的连击数（每次连击 +1 时调）
static func combo(n: int) -> void:
	for g: Array in [[25, "combo_25"], [50, "combo_50"], [100, "combo_100"]]:
		if n >= int(g[0]):
			unlock(String(g[1]))


## 从已有存档里能看出来的成就（旧存档补发、结局和残页这类）
static func check_save(quiet: bool = false) -> void:
	if int(Game.save.get("runs", 0)) >= 1:
		unlock("first_run", quiet)
	var deaths := int(Game.save.get("deaths", 0))
	if deaths >= 1:
		unlock("first_death", quiet)
	if deaths >= 10:
		unlock("deaths_10", quiet)
	var clears := int(Game.save.get("clears", 0))
	if clears >= 1:
		unlock("clear", quiet)
		unlock("boss1", quiet)
		unlock("boss2", quiet)
	if clears >= 3:
		unlock("clears_3", quiet)
	if bool(Game.save.get("arpg_tutorial", false)):
		unlock("tutorial", quiet)
	if ArpgStory.has_all_pages():
		unlock("pages", quiet)
	var ends: Dictionary = Game.save.get("arpg_endings", {})
	if ends.has("true"):
		unlock("end_true", quiet)
	if ends.has("douse") and ends.has("keep") and ends.has("true"):
		unlock("end_all", quiet)
	if ends.has("souls"):
		unlock("end_souls", quiet)
	if ArpgStory.kite() >= ArpgStory.KITE.size():
		unlock("kite", quiet)
	if ArpgStory.names_done():
		unlock("names", quiet)
	if bool(Game.save.get("arpg_shadow", false)):
		unlock("shadow", quiet)
	if bool(Game.save.get("arpg_jizo_home", false)):
		unlock("jizo_home", quiet)
	var owned: Array = Game.save.get("arpg_weapons", [])
	var all := true
	for w: String in ArpgData.WEAPONS:
		if not owned.has(w):
			all = false
	if all:
		unlock("weapons_all", quiet)


## 成就列表的菜单项（ArpgMenu 格式）。已解锁的排前面
static func menu_items() -> Array:
	var done := []
	var todo := []
	for a: Array in LIST:
		var got := has(String(a[0]))
		var it := {"title": String(a[1]) if got or not a[3] else "？？？",
			"desc": String(a[2]) if got or not a[3] else "隐藏成就：走得够远自然会知道",
			"right": _date(int(_got()[a[0]])) if got else "未达成",
			"color": Color(0.95, 0.8, 0.45) if got else Color(0.55, 0.58, 0.62),
			"tag": "已达成" if got else "", "enabled": got}
		if got:
			done.append(it)
		else:
			todo.append(it)
	return done + todo


static func _date(t: int) -> String:
	if t <= 0:
		return "已达成"
	var d := Time.get_datetime_dict_from_unix_time(t + _tz_bias())
	return "%d.%d.%d" % [d["year"], d["month"], d["day"]]


static func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
