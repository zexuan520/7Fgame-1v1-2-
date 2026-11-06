class_name ArpgRewards
extends RefCounted
## 房间奖励：每间战斗房在生成地图时就定好清完给什么，选路时在分岔卡片和光门上写出来，让选路变成一个决定。
## 节点上存 "reward"（类型 id）和 "school"（心法·某派时的流派）；老存档没有这两个键就当普通心法。
## 想加新类型：在 KINDS 里加一行（名字、一句话、颜色、权重），再在 ArpgMain._give_reward 里写发奖。

## 战斗房的奖励类型：[id, 卡片上的名字, 说明, 颜色, 权重]
const KINDS := {
	"school": {"name": "心法·%s", "desc": "清完三选一，至少两个是%s派", "color": Color(0.85, 0.75, 1.0), "w": 38},
	"boon": {"name": "心法", "desc": "清完三选一", "color": Color(0.7, 0.9, 1.0), "w": 14},
	"relic": {"name": "奇物", "desc": "清完二选一件奇物，会改变打法", "color": Color(1.0, 0.62, 0.3), "w": 9},
	"coins": {"name": "铜钱", "desc": "清完得一袋铜钱，商人那里花", "color": Color(1.0, 0.85, 0.4), "w": 11},
	"gear": {"name": "装备", "desc": "清完掉一件精品以上的装备", "color": Color(0.55, 0.85, 1.0), "w": 11},
	"xp": {"name": "悟道", "desc": "清完悟道大涨（约一重），多拿天赋点", "color": Color(0.6, 1.0, 0.75), "w": 8},
	"jade": {"name": "魂玉", "desc": "清完得几颗魂玉，带回山门点天赋", "color": Color(0.5, 1.0, 0.9), "w": 8},
}
## 精英房：奇物（要先有奇物系统）或四选一心法 + 必掉装备
const ELITE_KINDS := {"relic": 55, "boon": 45}


static func schools() -> Array:
	return ArpgData.SCHOOL_COLORS.keys()


## 给这一层还没定奖励的战斗、精英房定好奖励（remap 末尾调；种子固定，读档后不变）
static func assign(st: ArpgState) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = st.seed_value + st.run.floor_index * 977 + 31
	var sc := schools()
	for r: Array in st.run.rows:
		var last := ""
		for nd: Dictionary in r:
			var t := String(nd.get("type", ""))
			if nd.has("reward"):
				continue
			if t == "fight":
				var k := _pick(rng, KINDS, last)
				nd["reward"] = k
				if k == "school":
					nd["school"] = sc[rng.randi_range(0, sc.size() - 1)]
				last = k
			elif t == "elite":
				var ew := {}
				for k: String in ELITE_KINDS:
					ew[k] = {"w": ELITE_KINDS[k]}
				nd["reward"] = _pick(rng, ew, "")


## 按权重抽一个；同一列相邻两扇门尽量别一样（avoid 的权重压到三成）
static func _pick(rng: RandomNumberGenerator, table: Dictionary, avoid: String) -> String:
	var total := 0.0
	for k: String in table:
		total += float(table[k]["w"]) * (0.3 if k == avoid else 1.0)
	var x := rng.randf() * total
	for k: String in table:
		x -= float(table[k]["w"]) * (0.3 if k == avoid else 1.0)
		if x <= 0.0:
			return k
	return table.keys()[0]


## 节点的奖励 id（没有就是普通心法；非战斗房返回 ""）
static func of(nd: Dictionary) -> String:
	var t := String(nd.get("type", ""))
	if t != "fight" and t != "elite":
		return ""
	return String(nd.get("reward", "boon"))


## 卡片、光门上的短名：“心法·焰”“奇物”“铜钱”
static func label(nd: Dictionary) -> String:
	var k := of(nd)
	if k == "" or (String(nd.get("type", "")) == "elite" and k == "boon"):
		return ""
	if not KINDS.has(k):
		return ""
	var nm := String(KINDS[k]["name"])
	return nm % String(nd.get("school", "")) if k == "school" else nm


static func desc(nd: Dictionary) -> String:
	var k := of(nd)
	if not KINDS.has(k):
		return ""
	if String(nd.get("type", "")) == "elite":
		return "精英房：清完二选一件奇物，再必掉装备" if k == "relic" else ""
	var d := String(KINDS[k]["desc"])
	return d % String(nd.get("school", "")) if k == "school" else d


static func color(nd: Dictionary) -> Color:
	var k := of(nd)
	if k == "school":
		return ArpgData.SCHOOL_COLORS.get(String(nd.get("school", "")), Color.WHITE)
	if KINDS.has(k):
		return KINDS[k]["color"]
	return Color.WHITE


## 铜钱袋、魂玉、悟道的数量（按全局层号涨）
static func coins(gfloor: int) -> int:
	return 45 + 14 * gfloor


static func jade(gfloor: int) -> int:
	return 3 + gfloor / 2


static func xp(st: ArpgState) -> int:
	return int(ArpgSkills.need(st.level) * 0.85)
