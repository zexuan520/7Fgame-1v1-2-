class_name Story
extends RefCounted
## 剧情投放（设计文档第 2 节“叙事投放”）：记忆碎片、破庙 NPC 随轮回变化的台词、头目每次见面的台词。
## 记忆碎片从精英、奇遇里拿到（头目的身世片段打败他才有），拿到就写进存档，死了也不丢；
## 一段记忆三片，在破庙的忆境里拼起来看。
##
## 加一段记忆：MEMORIES 里加一条，frags 写三片。boss 字段不为空的是头目身世，只在打败那个头目时按次数给，
## 不会从精英、奇遇里掉。加 NPC 台词：NPC_LINES 里加一条，when 是解锁条件（存档里的统计 ≥ 这个数）。

const MEMORIES := [
	{"id": "blade", "title": "断刃", "frags": [
		"梦里总有一把刀，从中间断开。断口很齐，像是被人一刀劈断的，又像是自己折断的。",
		"刀柄上缠的布条是红的。拾骨婆说，那是血浸久了的颜色。不记得是谁的血。",
		"想起来了。那天下着雨，我把刀插进石缝，用力一扳——不是敌人，是我自己断的刀。",
	]},
	{"id": "five", "title": "五人", "frags": [
		"山顶的剑冢前站着五个人，背对着我。其中一个回头，脸上全是水。",
		"他们在争。一个说要封，一个说要斩，还有一个一直不开口，只是磨刀。",
		"最后五把刀刀尖朝下，插进同一块石头。石头里传出心跳一样的声音。",
	]},
	{"id": "seal", "title": "印", "frags": [
		"手背上的印记会发烫。每次倒下之前，它烫得最厉害。",
		"破庙的钟响了三下，我又睁开眼。地上的灰里有我自己的脚印——不止一行。",
		"拾骨婆替我包扎时说漏了嘴：「上一个带着这印的人，也是从这扇门出去的。」",
	]},
	{"id": "home", "title": "归", "frags": [
		"山脚下有一间屋子，灶上温着粥。有人在等我回去吃饭。",
		"门口晾着一件小孩的衣服，袖子短了一截。我出门那年，它还合身。",
		"我站在门外没有进去。印记在发烫——进去的话，他们也会被缠上。",
	]},
	{"id": "liu", "title": "断水 · 柳江远", "boss": "liu", "frags": [
		"柳江远是剑圣门下最小的弟子。师父临终把那把刀交给他：「守住河，别让任何人上山。」",
		"他守了二十年，砍倒了一百多个上山的人。每个人倒下前，他都问同一句：「你为何上山？」",
		"没有人答得上来。直到那天你答了。你说了什么，他没告诉任何人，只是把刀放下了。",
	]},
]

## 破庙 NPC 的台词：when 里的统计都够了才会说（runs 出发次数 / deaths 身死 / clears 通关 / memories 记忆碎片数）。
## 新解锁的排在前面先说，原来的台词接在后面轮流说
const NPC_LINES := {
	"granny": [
		{"when": {"runs": 3}, "lines": ["又回来了。这回身上的伤，比上回少。"]},
		{"when": {"deaths": 5}, "lines": ["倒下的次数多了，骨头会记得怎么站起来。"]},
		{"when": {"memories": 3}, "lines": ["想起点什么了？……别急着全想起来。"]},
		{"when": {"clears": 1}, "lines": ["河边那位倒下了？……他等的人不是你。"]},
	],
	"monk": [
		{"when": {"runs": 2}, "lines": ["这扇门，你出去过不止一次了吧。"]},
		{"when": {"memories": 6}, "lines": ["忆境里的水又浑了。你想起来的东西，也有人不想你想起。"]},
		{"when": {"clears": 1}, "lines": ["柳施主……放下刀了？阿弥陀佛。"]},
	],
}


static func collected() -> Array:
	return Game.save["memories"]


static func has(frag_id: String) -> bool:
	return collected().has(frag_id)


static func frag_id(memory_id: String, i: int) -> String:
	return "%s_%d" % [memory_id, i]


static func memory(memory_id: String) -> Dictionary:
	for m: Dictionary in MEMORIES:
		if m["id"] == memory_id:
			return m
	return {}


## 一段记忆拿到了几片
static func count_in(m: Dictionary) -> int:
	var n := 0
	for i in range((m["frags"] as Array).size()):
		if has(frag_id(m["id"], i)):
			n += 1
	return n


## 拿下一片普通记忆（从前往后补，先把一段拼完再给下一段）。全拿完了返回 ""
static func next_fragment() -> String:
	for m: Dictionary in MEMORIES:
		if m.get("boss", "") != "":
			continue
		for i in range((m["frags"] as Array).size()):
			var id := frag_id(m["id"], i)
			if not has(id):
				return id
	return ""


## 记下一片；返回 [记忆名, 第几片 / 共几片] 用来提示，已经有了返回空数组
static func collect(id: String) -> Array:
	if id == "" or has(id):
		return []
	collected().append(id)
	Game.write_save()
	var mid := id.substr(0, id.rfind("_"))
	var m := memory(mid)
	return [m["title"], count_in(m), (m["frags"] as Array).size()]


## 打败头目第 n 次给第 n 片身世
static func boss_fragment(kind: String, times: int) -> String:
	for m: Dictionary in MEMORIES:
		if m.get("boss", "") == kind and times >= 1 and times <= (m["frags"] as Array).size():
			return frag_id(m["id"], times - 1)
	return ""


static func stat(k: String) -> int:
	if k == "memories":
		return collected().size()
	return int(Game.save.get(k, 0))


## NPC 现在会说的话：新解锁的在前
static func npc_lines(kind: String, base: Array) -> Array:
	var extra := []
	for entry: Dictionary in NPC_LINES.get(kind, []):
		var ok := true
		for k: String in entry["when"]:
			if stat(k) < int(entry["when"][k]):
				ok = false
		if ok:
			extra = entry["lines"] + extra
	return extra + base


## 头目见了几次，按次数挑登场台词：intro_meets 里写 {次数: 台词}，取不超过这次的最大那个
static func intro_for(data: Dictionary, meets: int) -> Array:
	var lines: Array = data.get("intro", [])
	var best := 0
	var by: Dictionary = data.get("intro_meets", {})
	for k: int in by:
		if k <= meets and k > best:
			best = k
			lines = by[k]
	return lines


## 记一次见到头目（进头目房间时）
static func meet(kind: String) -> int:
	var meets: Dictionary = Game.save["meets"]
	meets[kind] = int(meets.get(kind, 0)) + 1
	Game.write_save()
	return int(meets[kind])
