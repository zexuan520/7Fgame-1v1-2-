class_name FoeSquads
extends RefCounted
## 战斗房的“阵”：每层四种主题编成，每间战斗房抽一种（同一层尽量不重样）。
## 一个阵定了这间房的小怪组合、可能出现的精英词缀、以及房间里的环境机关（瘴气、骨刺、钟声、涌泉、铜汁、箭雨）。
## waves：编成池，前两个是第一波用的轻松编成；late：每层深处（第 4 排起）多加的一波；
## hazard：RoomHazard 的种类（空 = 没有）；affix：这个阵里精英会带的词缀（FoeAffix 的键）。

const THEMES := {
	# ---------------- 第一幕 · 幽林 ----------------
	"forest": [
		{"id": "swarm", "name": "骨潮", "desc": "腐骨虫成群涌上来，混着几只爆骨鬼", "hazard": "", "affix": ["swift", "volatile"],
			"waves": [["crawler", 6, "bomber", 1], ["crawler", 5, "skeleton", 1], ["crawler", 6, "bomber", 2],
				["crawler", 4, "bomber", 2, "skeleton", 2], ["crawler", 7, "rogue", 1], ["crawler", 5, "bomber", 3]],
			"late": [["charger", 1, "crawler", 5], ["samurai", 1, "crawler", 4]]},
		{"id": "bowline", "name": "弩阵", "desc": "盾骷髅顶在前面，骨弩手躲在后面放箭", "hazard": "", "affix": ["stout", "warded"],
			"waves": [["skeleton", 2, "archer", 2], ["shield", 2, "archer", 1, "crawler", 2], ["shield", 2, "archer", 3],
				["skeleton", 3, "archer", 2, "crawler", 2], ["shield", 3, "archer", 2], ["shield", 2, "archer", 2, "bomber", 2]],
			"late": [["samurai", 1, "archer", 3], ["shield", 2, "archer", 2, "charger", 1]]},
		{"id": "miasma", "name": "瘴林", "desc": "瘴菇骨喷毒雾，林子里一阵阵起瘴", "hazard": "miasma", "affix": ["miasma", "stout"],
			"waves": [["sporer", 2, "crawler", 3], ["sporer", 1, "skeleton", 2, "crawler", 2], ["sporer", 3, "crawler", 3],
				["sporer", 2, "shield", 2], ["sporer", 2, "mage", 1, "crawler", 3], ["sporer", 2, "skeleton", 3]],
			"late": [["samurai", 1, "sporer", 2], ["sporer", 3, "charger", 1]]},
		{"id": "patrol", "name": "巡山骨队", "desc": "骷髅兵结队巡山，幽魂术士压阵", "hazard": "", "affix": ["frenzy", "stout"],
			"waves": [["skeleton", 3, "crawler", 2], ["skeleton", 3, "mage", 1], ["skeleton", 2, "mage", 2, "crawler", 2],
				["skeleton", 4, "shield", 1], ["skeleton", 2, "mage", 1, "archer", 1, "crawler", 2], ["skeleton", 3, "mage", 1, "bomber", 2]],
			"late": [["samurai", 1, "skeleton", 2], ["samurai", 1, "mage", 2]]},
	],
	# ---------------- 第一幕 · 无名冢 ----------------
	"grave": [
		{"id": "coffin", "name": "抬棺", "desc": "抬棺骨扛着棺盖挡刀，劈碎了棺里还会爬出东西", "hazard": "", "affix": ["haunt", "stout"],
			"waves": [["coffin", 1, "crawler", 3], ["coffin", 1, "skeleton", 2], ["coffin", 2, "crawler", 3],
				["coffin", 1, "rogue", 2, "archer", 1], ["coffin", 2, "bomber", 2], ["coffin", 1, "summoner", 1, "skeleton", 2]],
			"late": [["samurai", 1, "coffin", 1], ["coffin", 2, "charger", 1]]},
		{"id": "ambush", "name": "冢中伏", "desc": "骨刺客贴着地皮摸过来，一刺就退", "hazard": "", "affix": ["swift", "volatile"],
			"waves": [["rogue", 2, "crawler", 3], ["rogue", 3, "crawler", 1], ["rogue", 3, "archer", 2],
				["rogue", 2, "bomber", 2, "crawler", 2], ["rogue", 4, "mage", 1], ["rogue", 3, "shield", 2]],
			"late": [["samurai", 1, "rogue", 2], ["rogue", 3, "charger", 1]]},
		{"id": "summon", "name": "招魂", "desc": "招魂巫躲在后面招小鬼，地下时不时顶出骨刺", "hazard": "bones", "affix": ["haunt", "warded"],
			"waves": [["summoner", 1, "skeleton", 2], ["summoner", 1, "crawler", 3], ["summoner", 2, "skeleton", 2],
				["summoner", 1, "shield", 2, "archer", 1], ["summoner", 2, "rogue", 2], ["summoner", 1, "coffin", 1, "crawler", 2]],
			"late": [["samurai", 1, "summoner", 1, "skeleton", 1], ["summoner", 2, "charger", 1]]},
		{"id": "charge", "name": "冲阵", "desc": "冲阵骨一头头撞过来，引它们去撞墙", "hazard": "", "affix": ["frenzy", "stout"],
			"waves": [["charger", 1, "crawler", 3], ["charger", 1, "skeleton", 2], ["charger", 2, "crawler", 3],
				["charger", 1, "shield", 2, "archer", 1], ["charger", 2, "bomber", 2], ["charger", 2, "rogue", 2]],
			"late": [["samurai", 1, "charger", 1], ["charger", 3, "crawler", 2]]},
	],
	# ---------------- 第一幕 · 古寺 ----------------
	"temple": [
		{"id": "bell", "name": "钟鸣", "desc": "铜钟僧一敲钟，金色的声浪一圈圈推开，翻滚穿过去", "hazard": "bell", "affix": ["thunder", "warded"],
			"waves": [["bellmonk", 1, "crawler", 3], ["bellmonk", 1, "skeleton", 2], ["bellmonk", 2, "rogue", 2],
				["bellmonk", 1, "shield", 2, "archer", 2], ["bellmonk", 2, "crawler", 4], ["bellmonk", 1, "mage", 2, "skeleton", 1]],
			"late": [["samurai", 1, "bellmonk", 1, "archer", 1], ["bellmonk", 2, "charger", 1]]},
		{"id": "incense", "name": "香火", "desc": "幽魂术士和骨弩手隔着香炉放法术、放箭", "hazard": "", "affix": ["thunder", "swift"],
			"waves": [["mage", 2, "crawler", 3], ["archer", 2, "mage", 1, "skeleton", 1], ["mage", 2, "archer", 2, "shield", 2],
				["mage", 3, "crawler", 3], ["summoner", 1, "mage", 2, "archer", 1], ["mage", 2, "archer", 3]],
			"late": [["samurai", 1, "mage", 2], ["samurai", 1, "archer", 2, "summoner", 1]]},
		{"id": "arhat", "name": "罗汉阵", "desc": "盾骷髅结阵，赤甲武士坐镇", "hazard": "", "affix": ["stout", "warded", "frenzy"],
			"waves": [["shield", 2, "skeleton", 2], ["shield", 3, "crawler", 2], ["shield", 3, "samurai", 1],
				["shield", 2, "archer", 2, "charger", 1], ["samurai", 1, "shield", 2, "skeleton", 2], ["shield", 4, "bellmonk", 1]],
			"late": [["samurai", 2, "shield", 1], ["samurai", 1, "shield", 3]]},
		{"id": "chaos", "name": "乱葬", "desc": "骨头乱成一锅：爆骨鬼、冲阵骨、骨刺客一起上", "hazard": "", "affix": ["volatile", "frenzy", "swift"],
			"waves": [["bomber", 3, "crawler", 3], ["rogue", 3, "bomber", 2], ["charger", 2, "bomber", 2, "rogue", 1],
				["rogue", 3, "charger", 1, "bomber", 2], ["bomber", 4, "skeleton", 3], ["coffin", 1, "bomber", 3, "rogue", 2]],
			"late": [["samurai", 2, "archer", 2], ["samurai", 1, "charger", 2]]},
	],
	# ---------------- 第二幕 · 青井地宫 ----------------
	"well": [
		{"id": "flood", "name": "涌泉", "desc": "水骨、井鳗骨在水底下跟着你，地下不时冒出水柱", "hazard": "geyser", "affix": ["swift", "warded"],
			"waves": [["drowned", 5, "crawler", 2], ["eel", 3, "crawler", 3], ["drowned", 3, "eel", 2],
				["eel", 4, "drowned", 2], ["drowned", 4, "lampkid", 1, "archer", 1], ["eel", 3, "chainmonk", 1]],
			"late": [["samurai", 1, "eel", 3], ["chainmonk", 1, "drowned", 4]]},
		{"id": "chain", "name": "灯链", "desc": "灯奴僧甩着灯链守在中间，弩手在边上放冷箭", "hazard": "", "affix": ["stout", "warded"],
			"waves": [["chainmonk", 1, "drowned", 3], ["chainmonk", 1, "skeleton", 2, "archer", 1], ["chainmonk", 2, "crawler", 4],
				["chainmonk", 1, "archer", 2, "lampkid", 1], ["chainmonk", 2, "drowned", 2], ["chainmonk", 1, "shield", 2, "archer", 2]],
			"late": [["chainmonk", 1, "samurai", 1, "drowned", 2], ["chainmonk", 2, "archer", 2, "lampkid", 1]]},
		{"id": "lamp", "name": "引魂", "desc": "引魂灯童躲在后面给同伴回血，先找灯", "hazard": "", "affix": ["haunt", "swift"],
			"waves": [["lampkid", 1, "skeleton", 3], ["lampkid", 1, "drowned", 3], ["lampkid", 2, "shield", 2, "skeleton", 1],
				["lampkid", 2, "rogue", 2, "drowned", 2], ["lampkid", 1, "chainmonk", 1, "eel", 2], ["lampkid", 2, "skeleton", 2, "archer", 2]],
			"late": [["samurai", 1, "lampkid", 2, "shield", 1], ["chainmonk", 1, "lampkid", 2, "eel", 2]]},
		{"id": "abyss", "name": "井底", "desc": "整间都是积水，脚下随时有东西扑上来", "hazard": "", "affix": ["frenzy", "swift"],
			"waves": [["drowned", 4, "rogue", 1], ["eel", 2, "drowned", 2, "crawler", 2], ["eel", 3, "rogue", 2],
				["drowned", 3, "bomber", 2, "eel", 1], ["eel", 4, "archer", 1], ["drowned", 5, "chainmonk", 1]],
			"late": [["samurai", 1, "drowned", 3], ["samurai", 1, "eel", 3, "lampkid", 1]]},
	],
	# ---------------- 第二幕 · 烛国灯冢 ----------------
	"vault": [
		{"id": "molten", "name": "铜汁", "desc": "熔铜沟漫出来，顶上一阵阵往下滴铜汁", "hazard": "molten", "affix": ["blazing"],
			"waves": [["flameskel", 4, "crawler", 3], ["flameskel", 3, "oiler", 1], ["flameskel", 3, "oiler", 2],
				["flameskel", 2, "armored", 1, "oiler", 1], ["flameskel", 4, "bomber", 2], ["oiler", 2, "flameskel", 2, "twin", 2]],
			"late": [["samurai", 1, "flameskel", 3], ["armored", 1, "oiler", 2, "flameskel", 2]]},
		{"id": "armor", "name": "甲阵", "desc": "烛国甲士披着铜甲排成阵，先打破韧再下刀", "hazard": "", "affix": ["stout", "frenzy"],
			"waves": [["armored", 1, "skeleton", 3], ["armored", 1, "shield", 2], ["armored", 2, "flameskel", 2],
				["armored", 2, "bomber", 2], ["armored", 2, "archer", 2], ["armored", 1, "shield", 2, "charger", 1]],
			"late": [["armored", 2, "samurai", 1], ["armored", 3, "oiler", 1]]},
		{"id": "twins", "name": "殉葬", "desc": "殉灯俑成对守墓，一只倒下另一只还站着就会爬起来", "hazard": "", "affix": ["haunt", "volatile"],
			"waves": [["twin", 2, "crawler", 3], ["twin", 2, "skeleton", 2], ["twin", 4, "oiler", 1],
				["twin", 2, "summoner", 1, "crawler", 2], ["twin", 4, "flameskel", 1], ["twin", 2, "armored", 1, "archer", 1]],
			"late": [["twin", 4, "armored", 1], ["samurai", 1, "twin", 2, "oiler", 1]]},
		{"id": "oil", "name": "泼油", "desc": "泼油俑满屋子扔油罐，脚下到处是火", "hazard": "", "affix": ["blazing", "volatile"],
			"waves": [["oiler", 2, "crawler", 3], ["oiler", 1, "armored", 1, "skeleton", 1], ["oiler", 2, "bomber", 2],
				["oiler", 2, "armored", 1, "twin", 2], ["oiler", 3, "charger", 1], ["oiler", 2, "shield", 2, "flameskel", 1]],
			"late": [["samurai", 1, "armored", 1, "oiler", 2], ["oiler", 3, "armored", 1]]},
	],
	# ---------------- 第二幕 · 灰衣营 ----------------
	"camp": [
		{"id": "arrows", "name": "箭雨", "desc": "望楼上的弩手往下放箭，地上看见红圈就挪开", "hazard": "arrows", "affix": ["swift"],
			"waves": [["greybow", 2, "greyblade", 2], ["greyguard", 2, "greybow", 2], ["greybow", 3, "greyblade", 2],
				["greyguard", 2, "greybow", 3], ["greybow", 2, "greyspear", 2], ["greybow", 3, "greyguard", 1, "greyflag", 1]],
			"late": [["officer", 1, "greybow", 2], ["greyguard", 2, "greybow", 2, "greyflag", 1]]},
		{"id": "pikes", "name": "枪林", "desc": "盾兵在前、枪兵在后，长枪隔着盾往外扎", "hazard": "", "affix": ["stout", "warded"],
			"waves": [["greyspear", 2, "greyblade", 2], ["greyguard", 2, "greyspear", 1], ["greyspear", 3, "greyguard", 1],
				["greyguard", 2, "greyspear", 2], ["greyspear", 3, "greybow", 1], ["greyguard", 3, "greyspear", 2]],
			"late": [["officer", 1, "greyspear", 2, "greyguard", 1], ["greyspear", 3, "greyflag", 1]]},
		{"id": "banner", "name": "旗鼓", "desc": "旗手一举旗，身边的灰衣人就发狠，先砍旗", "hazard": "", "affix": ["frenzy"],
			"waves": [["greyflag", 1, "greyblade", 3], ["greyflag", 1, "greyguard", 2], ["greyflag", 1, "greyblade", 3, "greyspear", 1],
				["greyflag", 2, "greyblade", 3], ["greyflag", 1, "greyguard", 2, "greyspear", 2], ["greyflag", 1, "greyblade", 2, "greybow", 2]],
			"late": [["officer", 1, "greyflag", 1, "greyblade", 2], ["greyflag", 2, "greyguard", 2]]},
		{"id": "raid", "name": "夜袭", "desc": "刀手成群扑上来，砍一刀就退，你一挥刀就闪", "hazard": "", "affix": ["swift", "frenzy"],
			"waves": [["greyblade", 4, "crawler", 2], ["greyblade", 3, "greybow", 1], ["greyblade", 5],
				["greyblade", 4, "greyspear", 1], ["greyblade", 3, "armored", 1], ["greyblade", 4, "greyguard", 1, "greybow", 1]],
			"late": [["officer", 1, "greyblade", 3], ["officer", 1, "greyblade", 2, "greyflag", 1]]},
	],
	# ---------------- 第三幕 · 柳溪村（敌人见 Act3Foe） ----------------
	"liuxi": [
		{"id": "lamps", "name": "灰灯", "desc": "被灰纸灯点起来的村民成群走过来，倒下了还会再站起来", "hazard": "", "affix": ["haunt", "stout"],
			"waves": [["lampman", 5, "crawler", 2], ["lampman", 4, "torcher", 1], ["lampman", 6, "torcher", 1],
				["lampman", 4, "lampguard", 1, "torcher", 1], ["lampman", 5, "bomber", 2], ["lampman", 6, "scarecrow", 2]],
			"late": [["lampguard", 2, "lampman", 3], ["samurai", 1, "lampman", 4]]},
		{"id": "field", "name": "稻田", "desc": "田里站着一排稻草人，走近了才扑上来", "hazard": "", "affix": ["swift", "frenzy"],
			"waves": [["scarecrow", 3, "lampman", 2], ["scarecrow", 4, "crawler", 2], ["scarecrow", 4, "torcher", 1, "lampman", 2],
				["scarecrow", 5, "lampman", 2], ["scarecrow", 3, "rogue", 2, "torcher", 1], ["scarecrow", 4, "lampguard", 1]],
			"late": [["scarecrow", 4, "samurai", 1], ["scarecrow", 3, "lampguard", 2]]},
		{"id": "arson", "name": "纵火", "desc": "纵火手站远了扔火罐，脚下到处是火", "hazard": "", "affix": ["blazing", "volatile"],
			"waves": [["torcher", 2, "lampman", 3], ["torcher", 1, "lampman", 2, "scarecrow", 1], ["torcher", 2, "lampman", 4],
				["torcher", 3, "lampguard", 1], ["torcher", 2, "bomber", 2, "lampman", 2], ["torcher", 2, "scarecrow", 2, "lampman", 2]],
			"late": [["torcher", 3, "lampguard", 1], ["samurai", 1, "torcher", 2]]},
		{"id": "guard", "name": "收村", "desc": "王都来的镇灯卫举盾挺枪，挨家挨户收人", "hazard": "", "affix": ["stout", "warded"],
			"waves": [["lampguard", 1, "lampman", 3], ["lampguard", 1, "greybow", 2], ["lampguard", 2, "lampman", 3],
				["lampguard", 2, "greybow", 2, "torcher", 1], ["lampguard", 3, "lampman", 2], ["lampguard", 2, "greyspear", 2]],
			"late": [["officer", 1, "lampguard", 2], ["lampguard", 3, "torcher", 1]]},
	],
	# ---------------- 第三幕 · 官道驿站 ----------------
	"post": [
		{"id": "relay", "name": "驿马", "desc": "驿卒腿快，刺一下就跑，你一挥刀就闪", "hazard": "", "affix": ["swift", "frenzy"],
			"waves": [["courier", 3, "lampman", 2], ["courier", 3, "greybow", 1], ["courier", 4, "greybow", 2],
				["courier", 3, "lancer", 1, "greybow", 1], ["courier", 5, "lampguard", 1], ["courier", 4, "wardbell", 1]],
			"late": [["officer", 1, "courier", 3], ["lancer", 2, "courier", 3]]},
		{"id": "cavalry", "name": "冲骑", "desc": "下了马的禁军枪骑，隔远了就直线冲过来，引它们去撞墙", "hazard": "", "affix": ["stout", "frenzy"],
			"waves": [["lancer", 1, "courier", 2], ["lancer", 1, "lampman", 3], ["lancer", 2, "courier", 2],
				["lancer", 2, "greyguard", 2], ["lancer", 2, "greybow", 2, "courier", 1], ["lancer", 3, "wardbell", 1]],
			"late": [["lancer", 3, "lampguard", 1], ["officer", 1, "lancer", 2]]},
		{"id": "bells", "name": "镇魂", "desc": "押灯僧摇着铃跟在队里，铃一响身边的人刀枪不入一半", "hazard": "", "affix": ["warded", "haunt"],
			"waves": [["wardbell", 1, "courier", 3], ["wardbell", 1, "lampguard", 1, "lampman", 2], ["wardbell", 1, "lampguard", 2, "courier", 2],
				["wardbell", 2, "greyspear", 2, "courier", 1], ["wardbell", 1, "lancer", 2, "greybow", 1], ["wardbell", 2, "lampguard", 2]],
			"late": [["wardbell", 1, "officer", 1, "courier", 2], ["wardbell", 2, "lancer", 2]]},
		{"id": "convoy", "name": "押车", "desc": "灯车边上的弩手往路上放箭，看见红圈就挪开", "hazard": "arrows", "affix": ["swift", "thunder"],
			"waves": [["greybow", 2, "courier", 2], ["lampguard", 1, "greybow", 2], ["greybow", 3, "courier", 2],
				["lampguard", 2, "greybow", 2, "wardbell", 1], ["greybow", 2, "lancer", 1, "courier", 2], ["greybow", 3, "lampguard", 1, "courier", 1]],
			"late": [["officer", 1, "greybow", 2, "lampguard", 1], ["lancer", 2, "greybow", 2]]},
	],
	# ---------------- 第三幕 · 长明宫 ----------------
	"palace": [
		{"id": "golden", "name": "金吾", "desc": "金吾卫披着金甲列队，先打破韧再下刀", "hazard": "", "affix": ["stout", "thunder"],
			"waves": [["goldguard", 1, "lampman", 3], ["goldguard", 1, "courier", 2], ["goldguard", 2, "censer", 1],
				["goldguard", 2, "lampguard", 2], ["goldguard", 2, "palaceghost", 2], ["goldguard", 3, "wardbell", 1]],
			"late": [["goldguard", 3, "censer", 1], ["goldguard", 2, "armored", 1]]},
		{"id": "incense", "name": "御香", "desc": "提炉官把香炉往你脚下扔，落地就烧", "hazard": "", "affix": ["blazing", "volatile"],
			"waves": [["censer", 2, "lampman", 3], ["censer", 1, "goldguard", 1, "lampman", 1], ["censer", 2, "lampguard", 2],
				["censer", 3, "courier", 2], ["censer", 2, "goldguard", 1, "palaceghost", 1], ["censer", 3, "wardbell", 1]],
			"late": [["censer", 3, "goldguard", 1], ["goldguard", 2, "censer", 2]]},
		{"id": "ghosts", "name": "宫灯", "desc": "宫灯魂飘着，一眨眼就闪到你身边施法，看脚下", "hazard": "", "affix": ["haunt", "swift"],
			"waves": [["palaceghost", 2, "lampman", 2], ["palaceghost", 2, "courier", 2], ["palaceghost", 3, "lampguard", 1],
				["palaceghost", 3, "censer", 1, "lampman", 2], ["palaceghost", 4, "goldguard", 1], ["palaceghost", 3, "wardbell", 1, "courier", 1]],
			"late": [["palaceghost", 4, "goldguard", 1], ["palaceghost", 3, "goldguard", 2]]},
		{"id": "court", "name": "朝会", "desc": "整座宫里的人都来了：金吾卫、镇灯卫、押灯僧一起上", "hazard": "", "affix": ["warded", "frenzy", "stout"],
			"waves": [["lampguard", 2, "courier", 2], ["goldguard", 1, "wardbell", 1, "lampman", 2], ["goldguard", 2, "wardbell", 1, "courier", 1],
				["lampguard", 2, "goldguard", 1, "censer", 1], ["lancer", 2, "goldguard", 1, "palaceghost", 1], ["goldguard", 2, "lampguard", 2, "wardbell", 1]],
			"late": [["goldguard", 2, "officer", 1], ["goldguard", 3, "wardbell", 1]]},
	],
}

## 精英房：每层一组固定编成（领头的精英一定带词缀，第二幕带两条）
const ELITE := {
	"forest": [["skeleton", 4, "mage", 2], ["samurai", 1, "sporer", 2, "crawler", 3], ["samurai", 2, "archer", 2, "shield", 1]],
	"grave": [["skeleton", 3, "rogue", 2, "archer", 1], ["samurai", 1, "coffin", 1, "bomber", 3], ["samurai", 2, "summoner", 1, "rogue", 2]],
	"temple": [["shield", 3, "archer", 3], ["samurai", 2, "bellmonk", 1, "bomber", 2], ["samurai", 2, "summoner", 1, "charger", 1]],
	"well": [["chainmonk", 2, "drowned", 3], ["samurai", 1, "chainmonk", 1, "lampkid", 1, "archer", 2], ["samurai", 2, "eel", 3, "lampkid", 1]],
	"vault": [["armored", 2, "flameskel", 3], ["samurai", 1, "armored", 1, "oiler", 2], ["armored", 2, "samurai", 1, "twin", 2]],
	"camp": [["greyguard", 2, "greyblade", 3], ["officer", 1, "greybow", 1, "greyspear", 2], ["officer", 1, "greyguard", 2, "greyflag", 1, "greybow", 1]],
	"liuxi": [["lampguard", 2, "lampman", 4], ["samurai", 1, "lampguard", 1, "torcher", 2], ["officer", 1, "lampguard", 2, "scarecrow", 2]],
	"post": [["lancer", 2, "courier", 3], ["officer", 1, "wardbell", 1, "lancer", 2], ["lancer", 2, "lampguard", 2, "wardbell", 1]],
	"palace": [["goldguard", 2, "palaceghost", 2], ["goldguard", 2, "censer", 2, "wardbell", 1], ["goldguard", 3, "palaceghost", 2, "censer", 1]],
}
## 精英房的词缀池（每层气质不同）
const ELITE_AFFIX := {
	"forest": ["swift", "stout", "miasma"], "grave": ["haunt", "volatile", "stout"], "temple": ["thunder", "warded", "frenzy"],
	"well": ["warded", "swift", "haunt"], "vault": ["blazing", "stout", "volatile"], "camp": ["frenzy", "swift", "thunder"],
	"liuxi": ["blazing", "haunt", "stout"], "post": ["swift", "warded", "frenzy"], "palace": ["warded", "thunder", "stout"],
}


static func themes(zone: String) -> Array:
	return THEMES.get(zone, THEMES["forest"])


static func find(zone: String, id: String) -> Dictionary:
	for t: Dictionary in themes(zone):
		if String(t["id"]) == id:
			return t
	return {}


## 给这一间房挑一个阵：本层用过的先不用（四种都用过了再从头轮）
static func pick(zone: String, used: Array, rng: RandomNumberGenerator) -> Dictionary:
	var all := themes(zone)
	var fresh := []
	for t: Dictionary in all:
		if not used.has(String(t["id"])):
			fresh.append(t)
	if fresh.is_empty():
		fresh = all.duplicate()
		# 刚用过的那个别马上再来
		if used.size() > 0 and fresh.size() > 1:
			fresh = fresh.filter(func(t: Dictionary) -> bool: return String(t["id"]) != String(used[used.size() - 1]))
	return fresh[rng.randi() % fresh.size()]


## 按阵出三波（深处再加一波）：第一波从前两个轻松编成里挑，后面的打乱了挑
static func make_waves(theme: Dictionary, deep: bool, rng: RandomNumberGenerator) -> Array:
	var pool: Array = theme["waves"]
	var easy: Array = pool.slice(0, 2)
	var rest: Array = pool.slice(2)
	# 用传进来的 rng 打乱（固定种子测试时可复现）
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var w := [easy[rng.randi() % easy.size()], rest[0], rest[1]]
	if deep:
		var late: Array = theme["late"]
		w.append(late[rng.randi() % late.size()])
	return w
