class_name ArpgSecrets
extends Node
## 隐藏机制（第一、二幕）：
##   一、散件开封门：每层入口（第一间）的墙边有一道封门，门上三个凹槽。这一层的房间、侧屋、裂墙密室里偶尔藏着一件发微光的散件
##      （幽林萤石、无名冢断香、古寺铃舌、青井老铜钱、灯冢灯芯、灰衣营虎符碎片），跨局累计。凑齐三件：当场开出去“秘境”的光门，
##      以后每局走到入口，封门也开着，直到进过一次秘境。秘境里先打一拨守卫，再拿信物、宝箱、看一段旧事。
##   二、山门闲聊：拾骨婆、老刀匠、守灯僧、阿七每回山门各说一段新话（提示藏东西的地方），说到最后一段给一件信物；
##      同一次回山门缠着拾骨婆问个没完、或者反复摸地藏的脑袋，也有东西掉出来。
##   三、信物：十二件小东西，拿到就永久生效（加成并进 ArpgData.talent_stats），山门“信物匣”里看，没拿到的显示线索。
## 存档键：arpg_shards {zone: 件数}、arpg_realms {zone: true}、arpg_keeps [信物 id]、arpg_chat {人: 听到第几段}
## 测试：--secret_zone=forest 配 --room=realm 直接进秘境；--shards=forest:3 预置散件；--shardhere 本房必出散件；--chatall 闲聊不限每回一段

const C_KEEP := Color(1.0, 0.85, 0.5)
const C_DIM := Color(0.55, 0.55, 0.6)
const PER_RUN := 2            # 一局里每层最多冒几件散件（所以至少要走两局才凑得齐）
const SHARD_CHANCE := 0.35    # 每间合适的房间冒一件的几率
const NEED := 3

## 信物：拿到就永久生效。hint 是没拿到时信物匣里写的线索
const KEEPS := [
	{"id": "firefly", "name": "萤石串", "desc": "移速 +4%", "stats": {"move": 0.04}, "hint": "幽林入口有一道老树洞石门，门上三个萤火形的凹槽"},
	{"id": "incense", "name": "守墓人的香囊", "desc": "受伤 -4%", "stats": {"dmg_taken": -0.04}, "hint": "无名冢入口的孤坟石门，插着三截断香的位置空着"},
	{"id": "bell", "name": "小铜铃", "desc": "气力获取 +8%", "stats": {"energy": 0.08}, "hint": "古寺入口的钟楼地门，要三枚铃舌"},
	{"id": "dragon", "name": "龙王钱", "desc": "铜钱 +10%", "stats": {"coin": 0.1}, "hint": "青井地宫入口的水闸，认三枚老铜钱"},
	{"id": "wick", "name": "灯芯簪", "desc": "会心率 +3%", "stats": {"crit": 0.03}, "hint": "灯冢入口的封灯门，要三根没烧过的灯芯"},
	{"id": "tally", "name": "半块虎符", "desc": "伤害 +4%", "stats": {"atk": 0.04}, "hint": "灰衣营入口的军械库铁门，虎符拆成了三块"},
	{"id": "hag_lamp", "name": "拾骨婆的灯", "desc": "身死时魂玉多带回 5%", "stats": {"keep": 0.05}, "hint": "常找拾骨婆闲聊。她最后那段话，要等你知道她是谁"},
	{"id": "candy", "name": "麦芽糖", "desc": "开局铜钱 +15", "stats": {"start_coins": 15.0}, "hint": "有人被问烦了，会拿东西堵你的嘴"},
	{"id": "whetstone", "name": "老刀匠的磨刀石", "desc": "会心伤害 +10%", "stats": {"crit_dmg": 0.1}, "hint": "老刀匠爱念叨，多回山门听他说几回"},
	{"id": "beads", "name": "守灯僧的念珠", "desc": "药葫芦回复 +8%", "stats": {"gourd_heal": 0.08}, "hint": "守灯僧换物之外，也肯陪你说说话"},
	{"id": "jizo_coin", "name": "地藏的铜钱", "desc": "魂玉 +5%", "stats": {"jade": 0.05}, "hint": "求过保佑以后，地藏的石头脑袋还能多摸几下"},
	{"id": "gourd", "name": "阿七的酒葫芦", "desc": "生命 +10", "stats": {"hp": 10.0}, "hint": "第一幕救下阿七，他会来山门蹭酒"},
]

## 每层的封门和秘境（按区域；第三幕的区域没有，什么也不做）
const GATES := {
	"forest": {"piece": "萤石", "gate": "老树洞石门", "realm": "萤窟", "keep": "firefly", "color": Color(0.7, 1.0, 0.4),
		"where": "幽林的房间和侧屋", "look": "老树的树洞里嵌着一道石门，门上三个凹槽，形状像萤火虫。",
		"lines": [
			["", "石门后面是一个不大的山洞。洞顶趴满了萤火，一明一暗，像在喘气。"],
			["", "洞壁上刻着两个歪歪扭扭的名字：阿樱、阿刃。旁边画了一只风筝。"],
			["残刃", "……小时候躲雨的地方。她说萤火是村里走了的人，回来看看。", ArpgStory.C_HERO],
			["", "石台上放着一串用红线穿起来的萤石，是她当年串的，还亮着。"]]},
	"grave": {"piece": "断香", "gate": "孤坟石门", "realm": "香冢", "keep": "incense", "color": Color(1.0, 0.7, 0.45),
		"where": "无名冢的房间和侧屋", "look": "一座孤坟背后立着石门，门缝里插香的三个孔都空着。",
		"lines": [
			["", "石门后是一间低矮的墓室。正中一张供桌，香灰积了一寸厚，最上面一层还是新的。"],
			["", "供桌后面立着十二块没有字的牌位，每块前面都插着一炷香，香头一明一暗。"],
			["残刃", "守墓人……这十年，天天来上香？", ArpgStory.C_HERO],
			["", "供桌一角挂着一个旧香囊，绣着“平安”两个字，针脚歪歪扭扭。"]]},
	"temple": {"piece": "铃舌", "gate": "钟楼地门", "realm": "藏钟室", "keep": "bell", "color": Color(1.0, 0.85, 0.4),
		"where": "古寺的房间和侧屋", "look": "钟楼底下一道铁皮地门，门上三个铜扣，扣眼的形状像铃舌。",
		"lines": [
			["", "地门底下吊着一口铜钟，比寺里那口大三倍。钟身贴满了黄符，钟舌被人拆掉了。"],
			["", "你把三枚铃舌摆在钟下。地底起了一阵风，钟自己“嗡”地响了一声。"],
			["", "很远的地方，好像有很多人同时松了一口气。"],
			["残刃", "师父封了这口钟……是怕钟声叫醒死人，还是怕叫醒活人？", ArpgStory.C_HERO],
			["", "钟架下挂着一只巴掌大的小铜铃，铃身刻着“寂光”两个字。"]]},
	"well": {"piece": "老铜钱", "gate": "水闸石门", "realm": "龙王龛", "keep": "dragon", "color": Color(0.45, 0.9, 1.0),
		"where": "青井地宫的房间和侧屋", "look": "一道石砌水闸挡着暗渠，闸板上三个钱眼大小的凹孔。",
		"lines": [
			["", "水闸后面的水退得很快，露出一座小小的龙王龛。龛前的水底铺满了铜钱，最老的已经锈成了绿色。"],
			["", "龙王像手里攥着一张纸条：“青井村求雨三年，不如求灯一盏。”落款是续命司。"],
			["残刃", "青井村……七个灯座里的第一个。", ArpgStory.C_HERO],
			["", "龙王像嘴里衔着一枚大铜钱，钱眼里穿着一根新红绳。"]]},
	"vault": {"piece": "灯芯", "gate": "封灯门", "realm": "第八灯座", "keep": "wick", "color": Color(1.0, 0.6, 0.3),
		"where": "烛国灯冢的房间和侧屋", "look": "一扇铜门，门上烙着三个灯芯形的槽，槽里落满了铜灰。",
		"lines": [
			["", "封灯门后面是一间空殿。正中一座灯座，比外面那七座都大，上面什么也没有。"],
			["", "灯座上刻着字：“第八灯，以国为薪。”后面是烛国的年号，刻到一半就断了。"],
			["残刃", "一灯一村。第八盏……要烧一整个国？", ArpgStory.C_HERO],
			["", "灯座底下压着一根没烧过的灯芯，被人编成了一支簪子。"]]},
	"camp": {"piece": "虎符碎片", "gate": "军械库铁门", "realm": "续命司密档", "keep": "tally", "color": Color(1.0, 0.45, 0.4),
		"where": "灰衣营的房间和侧屋", "look": "军械库的铁门上挂着一把虎形铜锁，锁面缺了三块。",
		"lines": [
			["", "军械库里没有兵器，只有一排排木架，架上堆满卷宗。最上面一卷封着火漆，火漆上是一盏灯。"],
			["", "“七灯归京，长明宫续命一甲子。樱落、青井、柳溪……”后面的村名被墨涂掉了。"],
			["", "最后一行小字：“另：寂光弟子烬，可用。”"],
			["残刃", "王都，长明宫。……灯最后是要送到那里去的。", ArpgStory.C_HERO],
			["", "卷宗底下压着半块铜虎符。另外半块，在王都。"]]},
}

## 山门闲聊：每回山门每人说一段新的（按顺序）；need 不满足时说 wait；keep = 这一段给的信物
const CHATS := {
	"hag": [
		{"lines": [["拾骨婆", "闲聊？我一个捡骨头的，有什么好聊的。……行吧，坐。", ArpgStory.C_HAG],
			["拾骨婆", "山上有些东西会自己找人。你走近了，它就亮一下。萤石也好，铃舌也好，看见一闪一闪的，弯腰捡起来。", ArpgStory.C_HAG],
			["", "（提示：每层的房间和侧屋里偶尔藏着发微光的散件。一层凑齐三件，能打开那一层入口的封门）"]]},
		{"lines": [["拾骨婆", "墙上有裂缝的地方，别光看。清完了骨头，拿刀敲三下。", ArpgStory.C_HAG],
			["拾骨婆", "山喜欢把东西藏在藏东西的地方。裂墙后头的密室里，散件最爱往那儿滚。", ArpgStory.C_HAG]]},
		{"lines": [["拾骨婆", "那块无名碑，名字要一个一个认回来。认够了，碑底下会多出一行。", ArpgStory.C_HAG],
			["拾骨婆", "……多出来的那一行，最好别去找。找着了，你得跟自己打一架。", ArpgStory.C_HAG]]},
		{"lines": [["拾骨婆", "山里的人说话，一回只说一句。今天说了，明天再来。", ArpgStory.C_HAG],
			["拾骨婆", "刀匠、守灯僧、地藏，都一样。多来几回，他们手里总会漏点东西给你。", ArpgStory.C_HAG]]},
		{"need": "hag_told", "keep": "hag_lamp",
			"lines": [["拾骨婆", "……我那盏小灯，你拿着吧。守灯一族的灯，不照路，只认人。", ArpgStory.C_HAG],
				["拾骨婆", "你要是倒在山上，它替你多攥住一点魂玉。别点它，揣着就行。", ArpgStory.C_HAG]],
			"wait": [["", "拾骨婆张了张嘴，又闭上了。像是有话，还不到说的时候。"],
				["", "（提示：拾骨婆的身世在第二幕。灯冢的壁画廊里有一面墙，井底的枯荣也知道些什么）"]]},
	],
	"smith": [
		{"lines": [["老刀匠", "我闺女十六了，打铁比我还狠。灰衣人来那天，是她把我塞进风箱底下的。", ArpgStory.C_SMITH],
			["老刀匠", "……柳溪村在山那头。你哪天出了山，替我看一眼。", ArpgStory.C_SMITH]]},
		{"lines": [["老刀匠", "灯冢里有一道铜门，门上烙着灯芯的印子。烛国人铸灯剩下的好东西，都锁在那后头。", ArpgStory.C_SMITH],
			["老刀匠", "灯芯那玩意儿烧不坏，散得满冢都是。你捡三根插回门上，门就认你。", ArpgStory.C_SMITH]]},
		{"lines": [["老刀匠", "灰衣营有间军械库，铁门上挂一把虎形锁。虎符拆成三块，揣在营里各处。", ArpgStory.C_SMITH],
			["老刀匠", "续命司的人疑心重，连自己人都防。这种人的锁，最好撬。", ArpgStory.C_SMITH]]},
		{"keep": "whetstone",
			"lines": [["老刀匠", "来，这块磨刀石给你。跟了我四十年，磨过的刀比你见过的人都多。", ArpgStory.C_SMITH],
				["老刀匠", "刀快不快，看磨；砍不砍得进，看人。", ArpgStory.C_SMITH]]},
	],
	"monk": [
		{"lines": [["守灯僧", "寺里那口大钟，是师父亲手封的。钟舌拆成三枚，扔得满寺都是。", ArpgStory.C_MONK],
			["守灯僧", "他说钟一响，山上的客就都醒了。……我倒觉得，醒了也好。", ArpgStory.C_MONK]]},
		{"lines": [["守灯僧", "青井村的人以前往井里扔铜钱求雨。井底有座龙王龛，水闸一落就看不见了。", ArpgStory.C_MONK],
			["守灯僧", "老铜钱沉在地宫各处。凑够三枚，水闸认得。", ArpgStory.C_MONK]]},
		{"lines": [["守灯僧", "无名冢有座孤坟，坟后的石门上原本插着三截香。守墓人的香，一截都没点完。", ArpgStory.C_MONK],
			["守灯僧", "断香散在冢里。香认得回家的路，你替它们插回去。", ArpgStory.C_MONK]]},
		{"keep": "beads",
			"lines": [["守灯僧", "这串念珠是师父给我的。我念了十年经，一个客也没送走。", ArpgStory.C_MONK],
				["守灯僧", "你拿着吧。你比我会送客。", ArpgStory.C_MONK]]},
	],
	"ronin": [
		{"lines": [["阿七", "残刃！……别这么看我，我就是来蹭口酒。拾骨婆的酒，难喝得要命。", ArpgStory.C_RONIN]]},
		{"lines": [["阿七", "幽林最老的那棵树，树洞里有道石门，你见过吧？萤火虫往里钻的那棵。", ArpgStory.C_RONIN],
			["阿七", "我当兵那年在那儿躲过雨。门上三个凹槽，跟萤火虫一个形状。", ArpgStory.C_RONIN]]},
		{"lines": [["阿七", "无名冢的坟，你数过没有？十三座。刻了名字的只有十二座。", ArpgStory.C_RONIN],
			["阿七", "……第十三座里躺着的，不是死人。", ArpgStory.C_RONIN]]},
		{"lines": [["阿七", "续命司的规矩：要紧的东西拆成三份，分三个人揣着。虎符、钥匙、名册，都这样。", ArpgStory.C_RONIN],
			["阿七", "所以啊，路上看见一块碎铜，别急着当破烂。", ArpgStory.C_RONIN]]},
		{"keep": "gourd",
			"lines": [["阿七", "这个酒葫芦给你。空的。我戒了。", ArpgStory.C_RONIN],
				["阿七", "……骗你的，酒在我肚子里。拿着，装药也行。", ArpgStory.C_RONIN]]},
	],
}
## 这回已经说过了，再找他说话
const CHAT_DONE := {
	"hag": [["拾骨婆", "今天就这么多。去，上山。", ArpgStory.C_HAG]],
	"smith": [["", "老刀匠在砧子上叮叮当当，没空理你。"]],
	"monk": [["守灯僧", "阿弥陀佛。施主，下回再来。", ArpgStory.C_MONK]],
	"ronin": [["", "阿七抱着酒坛子打起了呼噜。"]],
}
## 都说完了以后的闲话（随便挑一句）
const CHAT_IDLE := {
	"hag": ["骨头记得你挨过的每一刀。", "灯油贵，骨头不要钱。", "又死了？死着死着，就会了。"],
	"smith": ["刀等得起，人等不起。", "火候到了，铁自己会说话。"],
	"monk": ["山上的客，总有一天都会走的。", "灯不是用来照亮的。……师父说的，我也没懂。"],
	"ronin": ["喝一口？……不喝拉倒。", "当兵的时候，最怕的不是死，是点名。"],
}
## 同一次回山门，说完今天那段还缠着拾骨婆问：问到第五回她塞给你一块麦芽糖（一次）
const HAG_PESTER := [
	["拾骨婆", "还问？", ArpgStory.C_HAG],
	["拾骨婆", "骨头都比你安静。", ArpgStory.C_HAG],
	["拾骨婆", "……", ArpgStory.C_HAG],
	["拾骨婆", "你小时候是不是也这么缠着你师父？", ArpgStory.C_HAG],
]
const HAG_CANDY := [
	["拾骨婆", "行行行，拿去拿去，堵上你的嘴。", ArpgStory.C_HAG],
	["", "拾骨婆从布袋最底下摸出一块麦芽糖，糖纸都黏住了。"],
]
## 求过保佑后反复摸地藏的脑袋：摸到第四下掉一枚铜钱（一次）
const JIZO_RUB := [
	"你摸了摸地藏的石头脑袋。凉的。",
	"你又摸了摸。石头脑袋上的青苔被你蹭掉了一块。",
	"地藏低垂的眉眼……好像比刚才弯了一点。",
]
const JIZO_COIN := [
	["", "你接着摸。地藏的嘴角动了一下，石缝里“叮”地滚出一枚铜钱。"],
	["", "铜钱上刻着一个小小的“谢”字。"],
]

var main: ArpgMain
var _pieces: Array[Node3D] = []
var _gate: Node3D
var _gate_npc: ArpgNpc
var _realm_pending := ""      # 这间房里凑齐了某层的散件：清场后开秘境光门
var _talked := {}             # 这次回山门已经闲聊过谁
var _pester := 0              # 这次回山门缠着拾骨婆问了几回
var _rubs := 0                # 这次回山门摸了地藏几下
var _t := 0.0


# ---------- 存档 ----------

static func keeps() -> Array:
	return Game.save.get("arpg_keeps", [])


static func has_keep(id: String) -> bool:
	return keeps().has(id)


static func keep_info(id: String) -> Dictionary:
	for k: Dictionary in KEEPS:
		if k["id"] == id:
			return k
	return {}


## 全部信物的加成（ArpgData.talent_stats 里加进去，山门和局里都生效）
static func keep_stats() -> Dictionary:
	var st := {}
	for id: String in keeps():
		ArpgData.add_stats(st, keep_info(id).get("stats", {}))
	return st


static func shards(zone: String) -> int:
	return int((Game.save.get("arpg_shards", {}) as Dictionary).get(zone, 0))


static func realm_done(zone: String) -> bool:
	return bool((Game.save.get("arpg_realms", {}) as Dictionary).get(zone, false))


static func realms() -> int:
	return (Game.save.get("arpg_realms", {}) as Dictionary).size()


## 这一层的封门开着吗（散件齐了、秘境还没进过）
static func gate_ready(zone: String) -> bool:
	return GATES.has(zone) and shards(zone) >= NEED and not realm_done(zone)


func _args() -> Dictionary:
	return main._args


## 给一件信物（已经有了返回 false）；永久生效，马上刷新主角数值
func give_keep(id: String) -> bool:
	if has_keep(id):
		return false
	var got: Array = keeps().duplicate()
	got.append(id)
	Game.save["arpg_keeps"] = got
	Game.write_save()
	ArpgAch.unlock("keep_1")
	if got.size() >= KEEPS.size():
		ArpgAch.unlock("keep_all")
	var k := keep_info(id)
	if is_instance_valid(main.hero):
		if main.state != null:
			main.hero.apply_stats(main.state.stats(), main.state.weapon)
		else:
			main.hero.apply_stats(ArpgData.talent_stats(), String(Game.save.get("arpg_weapon", "sword")), true)
		main.feel.callout(main.hero.head_top() + Vector3(0, 0.3, 0), "信物 · %s" % k["name"], C_KEEP, 1.3)
		main.vfx.shock_ring(main.hero.global_position, C_KEEP, 0.3, 3.0, 0.5)
	Game.sfx("reward")
	return true


func _keep_line(id: String) -> Array:
	var k := keep_info(id)
	return ["", "（得到信物「%s」：%s。信物永久生效，山门的信物匣里能看）" % [k["name"], k["desc"]]]


# ---------- 山门 ----------

func hub_entered() -> void:
	_talked = {}
	_pester = 0
	_rubs = 0
	if _args().has("chatall"):
		_talked = {}
	# 信物匣：出过一次门以后摆在山门左后方
	if int(Game.save.get("runs", 0)) > 0 or not keeps().is_empty():
		main._npc("信物匣 %d / %d" % [keeps().size(), KEEPS.size()], Vector3(-12.5, 0, -6.5), {"kit": "shelf", "scale": 1.0}, _open_box)
	# 阿七：第一幕最近一次救下了他，就来山门蹭酒
	if ArpgState.act1("ronin") == "ronin_saved":
		var n: ArpgNpc = main._npc("阿七 · 闲聊", Vector3(12.5, 0, 6.5), {"model": "barbarian", "weapon": "sword", "tint": Color(1.15, 0.85, 0.65)}, func(x: ArpgNpc) -> void: chat("ronin", x))
		n.display = "阿七 · 闲聊"


## 这次回山门还能听 who 一段新话吗
func can_chat(who: String) -> bool:
	return not _talked.has(who) or _args().has("chatall")


## 下一段（-1 = 都说完了）
func _chat_i(who: String) -> int:
	var i := int((Game.save.get("arpg_chat", {}) as Dictionary).get(who, 0))
	return i if i < (CHATS[who] as Array).size() else -1


## 闲聊：今天的新话 / 说过了 / 都说完了的闲话；拾骨婆被缠得烦了给麦芽糖
func chat(who: String, _n: ArpgNpc = null) -> DialogBox:
	if not can_chat(who):
		if who == "hag" and not has_keep("candy"):
			_pester += 1
			if _pester > HAG_PESTER.size():
				var cl: Array = HAG_CANDY.duplicate()
				give_keep("candy")
				ArpgAch.unlock("pester")
				cl.append(_keep_line("candy"))
				return main._say(cl)
			return main._say([HAG_PESTER[_pester - 1]])
		return main._say(CHAT_DONE[who])
	var i := _chat_i(who)
	if i < 0:
		var idle: Array = CHAT_IDLE[who]
		var nm := {"hag": "拾骨婆", "smith": "老刀匠", "monk": "守灯僧", "ronin": "阿七"}[who] as String
		var col: Color = {"hag": ArpgStory.C_HAG, "smith": ArpgStory.C_SMITH, "monk": ArpgStory.C_MONK, "ronin": ArpgStory.C_RONIN}[who]
		_talked[who] = true
		return main._say([[nm, String(idle[randi() % idle.size()]), col]])
	var e: Dictionary = CHATS[who][i]
	_talked[who] = true
	var need := String(e.get("need", ""))
	if need != "" and not _need_ok(need):
		return main._say(e["wait"])
	var lines: Array = (e["lines"] as Array).duplicate()
	var cd: Dictionary = Game.save.get("arpg_chat", {})
	cd[who] = i + 1
	Game.save["arpg_chat"] = cd
	Game.write_save()
	if e.has("keep") and give_keep(String(e["keep"])):
		lines.append(_keep_line(String(e["keep"])))
	if _args().has("storytest"):
		print("CHAT %s %d" % [who, i])
	return main._say(lines)


func _need_ok(need: String) -> bool:
	match need:
		"hag_told":
			return bool(Game.save.get("arpg_hag_told", false))
	return true


## 地藏：求过保佑以后再摸脑袋（同一回山门摸到第四下掉铜钱）
func rub_jizo() -> void:
	if has_keep("jizo_coin"):
		main._say([["", "地藏笑眯眯的，石头脑袋被你摸得发亮。保佑已经求过了，出发时就灵。"]])
		return
	_rubs += 1
	if _rubs > JIZO_RUB.size():
		var cl: Array = JIZO_COIN.duplicate()
		give_keep("jizo_coin")
		cl.append(_keep_line("jizo_coin"))
		main._say(cl)
		return
	var l: Array = [["", JIZO_RUB[_rubs - 1]]]
	if _rubs == 1:
		l.append(["", "保佑已经求过了，出发时就灵。"])
	main._say(l)


## 信物匣：拿到的写效果，没拿到的写线索；下面列各层散件和秘境
func _open_box(_n: ArpgNpc) -> void:
	var items := []
	for k: Dictionary in KEEPS:
		var have := has_keep(String(k["id"]))
		items.append({"title": String(k["name"]) if have else "？？？", "desc": String(k["desc"]) if have else "线索：" + String(k["hint"]),
			"right": "已得" if have else "", "enabled": have, "color": C_KEEP if have else C_DIM, "tag": "信物"})
	for z: String in ["forest", "grave", "temple", "well", "vault", "camp"]:
		var g: Dictionary = GATES[z]
		var s := shards(z)
		if s <= 0 and not realm_done(z):
			continue
		items.append({"title": "%s · %s" % [g["gate"], g["realm"] if realm_done(z) else "？？？"],
			"desc": ("去过了，%s到手" % keep_info(String(g["keep"]))["name"]) if realm_done(z) else "%s %d / %d　散在%s" % [g["piece"], mini(s, NEED), NEED, g["where"]],
			"right": "秘境" if realm_done(z) else ("门开着" if s >= NEED else ""), "enabled": realm_done(z), "color": g["color"], "tag": "封门"})
	main._open_menu("信物匣", "一只旧木匣，装着一路收下的小东西。信物拿到就永久生效。　%d / %d" % [keeps().size(), KEEPS.size()], items, "list", true)


# ---------- 局里：封门、散件 ----------

func room_entered(kind: String, zone: String) -> void:
	_pieces.clear()
	_gate = null
	_gate_npc = null
	_realm_pending = ""
	if main.state == null or not GATES.has(zone) or kind in ["tutorial", "boss", "realm"]:
		return
	if kind == "start":
		_build_gate(zone)
		return
	if realm_done(zone) or shards(zone) >= NEED or main._args.has("demo"):
		if not _args().has("shardhere"):
			return
	var key := "shard_" + zone
	var spawned := int(main.state.flags.get(key, 0))
	var force := _args().has("shardhere")
	var go := false
	if kind == "secret":
		go = true                  # 裂墙密室：散件最爱往这儿滚（不占每局名额）
	elif spawned < PER_RUN and kind in ["fight", "elite", "trial", "shop", "rest", "event", "story", "treasure"]:
		var before_boss: bool = main.state.run.row == main.state.run.rows.size() - 2
		go = main._rng.randf() < SHARD_CHANCE or (spawned == 0 and before_boss)
		if go:
			main.state.flags[key] = spawned + 1
	if go or force:
		_spawn_piece(zone)


## 一件散件：一小块发光的体素，上下浮动，走近了头上冒“？”，碰到就捡起来
func _spawn_piece(zone: String) -> void:
	var g: Dictionary = GATES[zone]
	var col: Color = g["color"]
	var p := Vector3.ZERO
	var sz: Vector2 = main.arena.size
	if not main.side_rooms.is_empty() and main._rng.randf() < 0.55:
		var sr: SideRoom = main.side_rooms[main._rng.randi() % main.side_rooms.size()]
		p = sr.at(main._rng.randf_range(0.6, 0.85), main._rng.randf_range(0.2, 0.8))
	else:
		var sx := -1.0 if main._rng.randf() < 0.5 else 1.0
		p = Vector3(sx * (sz.x * 0.5 - 2.6), 0, main._rng.randf_range(-sz.y * 0.5 + 3.0, sz.y * 0.5 - 4.5))
		if main.room_kind == "secret" or sz.x < 32.0:
			p = Vector3(main._rng.randf_range(-sz.x * 0.3, sz.x * 0.3), 0, -sz.y * 0.5 + 3.0)
	var root := Node3D.new()
	main.arena.add_child(root)
	root.global_position = p
	root.set_meta("zone", zone)
	var gem := Node3D.new()
	gem.position.y = 0.9
	root.add_child(gem)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.13
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = col * 1.6
	var mm2 := StandardMaterial3D.new()
	mm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm2.albedo_color = col.lightened(0.6) * 1.8
	# 菱形小块：中间亮、四周一圈
	for x in range(-2, 3):
		for y in range(-2, 3):
			if absi(x) + absi(y) > 2:
				continue
			var c := MeshInstance3D.new()
			c.mesh = cube
			c.position = Vector3(x, y, 0) * 0.13
			c.material_override = mm2 if absi(x) + absi(y) == 0 else mm
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gem.add_child(c)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.2
	l.omni_range = 3.0
	l.position.y = 0.9
	root.add_child(l)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	ring.mesh = q
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/arpg/fx_add.gdshader")
	rm.set_shader_parameter("tex", load("res://assets/fx/magic_01.png"))
	rm.set_shader_parameter("color", Color(col, 0.55))
	rm.set_shader_parameter("energy", 1.4)
	ring.material_override = rm
	ring.rotation.x = -PI / 2
	ring.position.y = 0.04
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var lab := Label3D.new()
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.font = main.feel.font
	lab.font_size = 44
	lab.outline_size = 10
	lab.pixel_size = 0.008
	lab.modulate = Color(col.lightened(0.4), 0.0)
	lab.text = "？"
	lab.position.y = 1.9
	root.add_child(lab)
	root.set_meta("label", lab)
	root.set_meta("gem", gem)
	_pieces.append(root)
	if _args().has("storytest") or _args().has("tel"):
		print("SHARD spawn %s at %s room=%s" % [zone, str(p.snapped(Vector3.ONE * 0.1)), main.room_kind])


func _take_piece(root: Node3D) -> void:
	var zone := String(root.get_meta("zone"))
	var g: Dictionary = GATES[zone]
	var p := root.global_position
	root.queue_free()
	_pieces.erase(root)
	var sd: Dictionary = Game.save.get("arpg_shards", {})
	var n := mini(int(sd.get(zone, 0)) + 1, NEED)
	sd[zone] = n
	Game.save["arpg_shards"] = sd
	Game.write_save()
	Game.sfx("memory")
	main.vfx.sheet("soul-rise", p, 2.6, g["color"], 1.8)
	main.vfx.shock_ring(p, g["color"], 0.2, 2.4, 0.4)
	main.feel.callout(p + Vector3(0, 2.0, 0), "%s %d / %d" % [g["piece"], n, NEED], g["color"], 1.2)
	if _args().has("storytest") or _args().has("tel"):
		print("SHARD take %s %d" % [zone, n])
	if n >= NEED:
		main.hud.banner("%s %d / %d" % [g["piece"], n, NEED], "齐了。远处传来石头挪开的声音……清完这间，光门会开", 3.2)
		_realm_pending = zone
	else:
		main.hud.banner("%s %d / %d" % [g["piece"], n, NEED], "这一层入口的%s上，还空着 %d 个凹槽" % [g["gate"], NEED - n], 2.6)


## 封门：入口房间的后墙右边，一道拱门 + 一块石板；石板上三个凹槽，嵌上的亮着
func _build_gate(zone: String) -> void:
	if realm_done(zone):
		return
	var g: Dictionary = GATES[zone]
	var col: Color = g["color"]
	var sz: Vector2 = main.arena.size
	var p := Vector3(sz.x * 0.5 - 6.5, 0, -sz.y * 0.5 + 3.4)
	_gate = Node3D.new()
	main.arena.add_child(_gate)
	_gate.global_position = p
	# 自己搭的石门：两根石柱 + 门楣 + 中间一块石板（离后墙远一点，别被墙挡住）
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	stone.roughness = 1.0
	for spec: Array in [[Vector3(-1.45, 1.5, 0), Vector3(0.6, 3.0, 0.7)], [Vector3(1.45, 1.5, 0), Vector3(0.6, 3.0, 0.7)], [Vector3(0, 3.2, 0), Vector3(3.8, 0.5, 0.85)], [Vector3(0, 0.08, 0.2), Vector3(3.6, 0.16, 1.2)]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[1]
		mi.mesh = b
		mi.material_override = stone
		mi.position = spec[0]
		_gate.add_child(mi)
	main.arena._box_collider(p + Vector3(0, 1, 0), Vector3(3.6, 2, 0.8))
	# 门楣上一道本层颜色的光（远远就看得出这是个“东西”）
	var trim := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(3.0, 0.08, 0.9)
	trim.mesh = tb
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = col * 1.2
	trim.material_override = tm
	trim.position = Vector3(0, 2.92, 0)
	_gate.add_child(trim)
	# 石板（挡住门洞）
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.3, 2.85, 0.4)
	slab.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.26, 0.25, 0.25)
	sm.roughness = 1.0
	slab.material_override = sm
	slab.position = Vector3(0, 1.45, 0.05)
	_gate.add_child(slab)
	_gate.set_meta("slab", slab)
	var have := shards(zone)
	for i in range(NEED):
		var s := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.42, 0.42, 0.12)
		s.mesh = sb
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col * 1.7 if i < have else Color(0.08, 0.07, 0.07)
		s.material_override = m
		s.position = Vector3((i - 1) * 0.65, 1.75, 0.22)
		slab.add_child(s)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.6 + 0.5 * have
	l.omni_range = 4.0
	l.position = Vector3(0, 1.6, 1.0)
	_gate.add_child(l)
	var is_open := have >= NEED
	var label := "%s · %s" % [g["gate"], "嵌上%s" % g["piece"] if is_open else "%d / %d" % [have, NEED]]
	_gate_npc = main._npc(label, p + Vector3(0, 0, 1.6), {}, func(nn: ArpgNpc) -> void: _use_gate(zone, nn))
	_gate_npc.radius = 2.4
	if is_open:
		main.arena.spirit_fire(p + Vector3(0, 0.2, 1.0), col, 0.9, 1.4, 4.0)
	if _args().has("storytest") or _args().has("tel"):
		print("GATE %s %d/%d" % [zone, have, NEED])


func _use_gate(zone: String, n: ArpgNpc) -> void:
	var g: Dictionary = GATES[zone]
	var have := shards(zone)
	if have < NEED:
		var lines := [["", String(g["look"])]]
		if have > 0:
			lines.append(["", "已经嵌上了 %d 个%s，还空着 %d 个。" % [have, g["piece"], NEED - have]])
		lines.append(["", "（%s散在%s，靠近时会发微光。也爱往裂墙后面的密室里滚。凑齐三件，门就开了）" % [g["piece"], g["where"]]])
		main._say(lines)
		return
	if n.used:
		return
	n.used = true
	n.queue_free()   # 站在门前的互动点会挡住光门
	# 嵌上，石板沉下去，后面是光门
	Game.sfx("boom")
	CamRig.I.shake(1)
	var slab: MeshInstance3D = _gate.get_meta("slab")
	var tw := slab.create_tween()
	tw.tween_property(slab, "position:y", -1.5, 1.2).set_trans(Tween.TRANS_QUAD)
	main.vfx.dust(_gate.global_position + Vector3(0, 0, 0.6), 2.2)
	main.hud.banner(String(g["gate"]), "%s嵌进凹槽，石板沉了下去" % g["piece"], 2.4)
	var gp := _gate.global_position
	main.get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if main.mode == "room":
			_open_realm_portal(zone, gp + Vector3(0, 0, 1.4)))


func _open_realm_portal(zone: String, p: Vector3) -> void:
	main.set_meta("realm_zone", zone)
	main._make_secret_portal(p, "realm", GATES[zone]["color"])
	if _args().has("storytest") or _args().has("tel"):
		print("REALM portal %s" % zone)


func _process(dt: float) -> void:
	_t += dt
	if main == null or main.mode != "room" or not is_instance_valid(main.hero):
		return
	var hp := main.hero.global_position
	for root: Node3D in _pieces.duplicate():
		if not is_instance_valid(root):
			_pieces.erase(root)
			continue
		var gem: Node3D = root.get_meta("gem")
		gem.position.y = 0.9 + sin(_t * 2.4) * 0.12
		gem.rotation.y += dt * 1.6
		var d := Vector2(hp.x - root.global_position.x, hp.z - root.global_position.z).length()
		var lab: Label3D = root.get_meta("label")
		lab.modulate.a = clampf((4.5 - d) / 2.0, 0.0, 1.0)
		if d < 1.2 and main.hero.alive:
			_take_piece(root)
	if _realm_pending != "" and main._room_done and main._menu == null:
		var z := _realm_pending
		_realm_pending = ""
		_open_realm_portal(z, hp + main.hero.facing * 2.5)
		main.hud.banner(String(GATES[z]["realm"]), "%s那边的门开了，光门直通过去" % GATES[z]["gate"], 2.6)


# ---------- 秘境 ----------

## 秘境房（_enter_room("realm")）：先打一拨这层的精英守卫，清场后出信物台、宝箱、旧事
func enter_realm(zone: String) -> void:
	var g: Dictionary = GATES.get(zone, GATES["forest"])
	main.hud.zone_name = "秘境 · %s" % g["realm"]
	main.hud.banner(String(g["realm"]), "%s后面藏着的地方" % g["gate"], 2.6)
	Game.music("secret")
	ArpgAch.unlock("realm_1")
	main.arena.spirit_fire(Vector3(-4.0, 0.4, -3.0), g["color"], 1.2, 2.0, 7.0)
	main.arena.spirit_fire(Vector3(4.0, 0.4, -3.0), g["color"], 1.2, 2.0, 7.0)
	var ew: Array = (FoeSquads.ELITE.get(zone, FoeSquads.ELITE["forest"]) as Array)
	if ew.is_empty() or _args().has("nowaves"):
		_realm_reward(zone)
		return
	main.waves = [(ew[0] as Array).duplicate()]
	main.wave_i = -1
	main._room_done = false
	main._wave_delay = 2.2
	main.get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if main.mode == "room":
			main.hud.banner("守门的", "秘境里有东西不想让你拿走", 1.8))


func realm_cleared() -> void:
	var zone := String(main.get_meta("realm_zone", main.state.zone()))
	main.hud.wave_text = "清场"
	Game.sfx("door")
	_realm_reward(zone)


func _realm_reward(zone: String) -> void:
	var g: Dictionary = GATES.get(zone, GATES["forest"])
	var mid := Vector3(0, 0, -2.5)
	main.arena.spirit_fire(mid + Vector3(0, 0.6, -0.6), g["color"], 1.6, 2.4, 8.0)
	main._npc(String(g["realm"]), mid, {"kit": "shrine", "scale": 1.2}, func(n: ArpgNpc) -> void:
		if n.used:
			return
		n.used = true
		Game.sfx("memory")
		main.vfx.sheet("soul-rise", n.global_position, 3.5, g["color"], 1.8)
		var lines: Array = (g["lines"] as Array).duplicate()
		var rd: Dictionary = Game.save.get("arpg_realms", {})
		rd[zone] = true
		Game.save["arpg_realms"] = rd
		Game.write_save()
		if rd.size() >= GATES.size():
			ArpgAch.unlock("realm_all")
		if give_keep(String(g["keep"])):
			lines.append(_keep_line(String(g["keep"])))
		else:
			main.state.add_jade(8)
			lines.append(["", "（这里的信物你已经有了。魂玉 +8）"])
		main._say(lines))
	main._npc("宝箱", Vector3(4.0, 0, -1.5), {"kit": "box", "scale": 1.4}, func(n: ArpgNpc) -> void: main._open_chest(n, 2))
	main._open_portal()


# ---------- 测试（--secrettest=hub / gate / piece / pending；会改写存档，只在云端跑） ----------

func _ready() -> void:
	if not main._args.has("secrettest"):
		return
	var c := String(main._args["secrettest"])
	for k: String in ["arpg_chat", "arpg_keeps", "arpg_shards", "arpg_realms"]:
		Game.save.erase(k)
	Game.save["arpg_intro"] = true
	Game.save["arpg_cycle_told"] = true
	Game.save["arpg_mutter"] = 99
	match c:
		"hub":
			Game.save["runs"] = maxi(1, int(Game.save.get("runs", 0)))
			Game.save["arpg_act1"] = {"ronin": "ronin_saved"}
			Game.save["arpg_act2_runs"] = 1
			Game.save["arpg_smith_met"] = true
			Game.save["arpg_monk_met"] = true
			Game.save["arpg_monk_buy"] = ""
			Game.save["arpg_jizo_home"] = true
			Game.save["arpg_bless"] = "平安"
			Game.save["arpg_hag_told"] = false
			main.get_tree().create_timer(1.5).timeout.connect(_test_hub)
		"gate":
			Game.save["arpg_shards"] = {"forest": 3, "grave": 3, "temple": 3, "well": 3, "vault": 3, "camp": 3}
			main.get_tree().create_timer(1.5).timeout.connect(_test_gate)
		"look":
			# 只摆好存档拍图：--shards=forest:2,well:3；--keeps=all
			var sd := {}
			for kv: String in String(main._args.get("shards", "")).split(",", false):
				var pr := kv.split(":")
				sd[pr[0]] = int(pr[1]) if pr.size() > 1 else NEED
			Game.save["arpg_shards"] = sd
			Game.save["arpg_act1"] = {"ronin": "ronin_saved"}
			Game.save["runs"] = maxi(1, int(Game.save.get("runs", 0)))
			if main._args.has("keeps"):
				var all := []
				for k: Dictionary in KEEPS:
					all.append(k["id"])
				Game.save["arpg_keeps"] = all.slice(0, 7)
			main.get_tree().create_timer(2.0).timeout.connect(func() -> void:
				main._close_menu()
				if not _pieces.is_empty():
					main._place_hero(_pieces[0].global_position + Vector3(-2.5, 0, 2.0))
				elif is_instance_valid(_gate):
					main._place_hero(_gate.global_position + Vector3(-1.5, 0, 4.5))
				if main._args.has("boxmenu"):
					_open_box(null))
		"piece", "pending":
			Game.save["arpg_shards"] = {"forest": 2 if c == "pending" else 0}
			main.get_tree().create_timer(1.5).timeout.connect(_test_piece)


## 拍图的时候（--shot）等拍完自己退出
func _test_quit() -> void:
	if not main._args.has("shot"):
		main.get_tree().create_timer(0.5).timeout.connect(func() -> void: main.get_tree().quit())


func _test_print(d: Variant) -> void:
	if d is DialogBox:
		for l: Array in (d as DialogBox).lines:
			print("SAY [%s] %s" % [l[0], l[1]])
	main._close_menu()


func _test_hub() -> void:
	var seq := []
	for i in range(6):
		seq.append("hag")
	seq.append_array(["ronin", "ronin", "monk", "jizo", "jizo", "jizo", "jizo"])
	# 再回五次山门：每回每人一段（第三回起拾骨婆的身世已知）
	for v in range(5):
		seq.append("visit%d" % v)
		seq.append_array(["hag", "smith", "monk", "ronin"])
	_test_step(seq)


func _test_step(seq: Array) -> void:
	if seq.is_empty():
		print("SECRETTEST keeps=%s chat=%s stats=%s" % [str(keeps()), str(Game.save.get("arpg_chat")), str(keep_stats())])
		_open_box(null)
		var m: Variant = main._menu
		if m is ArpgMenu:
			for it: Dictionary in (m as ArpgMenu).items:
				print("BOX %s | %s" % [it["title"], it["desc"]])
		_test_quit()
		return
	var w := String(seq.pop_front())
	print("STEP ", w)
	if w.begins_with("visit"):
		_talked = {}
		_pester = 0
		_rubs = 0
		if w == "visit1":
			Game.save["arpg_hag_told"] = true
	elif w == "jizo":
		rub_jizo()
		_test_print(main._menu)
	else:
		_test_print(chat(w))
	main.get_tree().create_timer(0.15).timeout.connect(func() -> void: _test_step(seq))


func _test_gate() -> void:
	main._close_menu()
	if not is_instance_valid(_gate_npc):
		print("SECRETTEST no gate")
		return
	_gate_npc.interacted.emit(_gate_npc)
	main.get_tree().create_timer(2.5).timeout.connect(func() -> void:
		for sp: Node3D in main._extra_portals:
			if is_instance_valid(sp) and String(sp.get_meta("kind", "")) == "realm":
				print("SECRETTEST portal ok")
				main._close_menu()
				main._place_hero(sp.global_position)
		main.get_tree().create_timer(3.0).timeout.connect(func() -> void:
			print("SECRETTEST room=%s waves=%d done=%s" % [main.room_kind, main.waves.size(), main._room_done])
			_test_realm_wait(0)))


func _test_realm_wait(n: int) -> void:
	if main._room_done or n > 60:
		main.get_tree().create_timer(1.5).timeout.connect(func() -> void:
			for npc: ArpgNpc in main._npcs:
				if is_instance_valid(npc) and npc.display in ["萤窟", "香冢", "藏钟室", "龙王龛", "第八灯座", "续命司密档"]:
					npc.interacted.emit(npc)
					_test_print(main._menu)
			print("SECRETTEST realm done=%s keeps=%s realms=%s portal=%s" % [str(main._room_done), str(keeps()), str(Game.save.get("arpg_realms")), main._portal_kind])
			_test_quit())
		return
	# 测试里把守卫直接清掉
	for f: Node in main.get_tree().get_nodes_in_group("foes"):
		var fo := f as Foe
		if fo != null and fo.alive and fo.global_position.y > -5.0:
			fo.die(Vector3.ZERO)
	main.get_tree().create_timer(0.5).timeout.connect(func() -> void: _test_realm_wait(n + 1))


func _test_piece() -> void:
	if _pieces.is_empty():
		print("SECRETTEST no piece")
		return
	main._place_hero(_pieces[0].global_position + Vector3(2.0, 0, 0))
	main.get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if not _pieces.is_empty():
			main._place_hero(_pieces[0].global_position)
		main.get_tree().create_timer(2.5).timeout.connect(func() -> void:
			var has_portal := false
			for sp: Node3D in main._extra_portals:
				if is_instance_valid(sp) and String(sp.get_meta("kind", "")) == "realm":
					has_portal = true
			print("SECRETTEST shards=%s portal=%s" % [str(Game.save.get("arpg_shards")), has_portal])
			_test_quit()))
