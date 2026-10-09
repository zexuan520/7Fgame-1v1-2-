class_name EnemyData
extends RefCounted
## 敌人数据表：数值、外观、招式、AI 都在这里。加新敌人只要在 TYPES 里加一条；
## 需要新姿势就在 Enemy._build_poses() 里加，需要特殊画法（比如四条腿的狗）就继承 Enemy。
##
## 敌人字段：
##   name / rank            显示名；grunt 杂兵（没有架势条，血空直接死）/ elite 精英 / boss 头目
##   hp / posture           每管血的生命、架势上限
##   speed / guard          走路速度、被砍时举刀格挡的概率
##   shield                 举盾：正面的轻攻击全部挡下，要重击、回旋斩或绕到背后
##   passive                不走不打（训练场的木桩、新手引导的教头）；no_loot 倒下什么也不掉
##   beast / yokai          野兽（爆竹吓得僵直很久）/ 妖物（焰筒伤害翻倍）
##   body / look            判定框大小；外观（Puppet.Look 的字段）
##   prop                   手上额外画的东西：bow 弓 / shield 盾
##   idle                   [远处姿势, 近处姿势]；flourish 为 true 时会耍刀挑衅
##   ai                     attack_range 近身出招距离，picks 近身时按权重选招 [招式, 权重]，
##                          far 中距离按每秒概率出招 [招式, 每秒概率, 最近, 最远]，
##                          keep 想保持的距离 [最近, 最远]，retreat 出完招往后跳开的秒数，
##                          flank 为 true 时会从玩家身边窜过去包抄
##   phases                 每管血一个阶段：speed 出招时间倍率（越小越快），picks/far 覆盖 ai 里的，
##                          line 进入这一阶段时说的话，aura 身上冒的气的颜色
##   intro / death_line     登场台词、死亡台词（头目）；title_sub 登场时名字上面那行小字（默认第一层）
##   intro_meets            第几次见面换一套登场台词 {次数: [[谁, 话], ...]}（见 Story.intro_for）
##
## 招式字段：
##   kind                   slash 可弹反 / sweep 下段（跳） / thrust 突刺（看破） / grab 擒拿（闪开）
##   unblockable            危：不能格挡
##   hits                   每一段 [前摇, 判定, 后摇] 秒
##   poses                  每一段 [蓄力姿势, 出手姿势]，段数比 hits 少时沿用最后一个
##   lunge / hop            出手时向前冲的速度（负数往后跳）、往上跳的速度
##   fx                     slash 刀光 / sweep 低扫 / streak 突刺线 / bite 咬 / arrow 射箭 / none
##   feint                  假动作 {"into": 换成的招式, "at": 前摇进行到几成时换}
##   then                   这一招收完立刻接的招
##   nohit                  只有位移没有判定（后跳）
##   stun                   被抓住时的僵直秒数
##   arrow                  射出的箭 {speed, dmg, posture, style}（style 为 star 时画成手里剑）

const TYPES := {
	# ---------- 精英：堕落浪人（练手用的那个） ----------
	"ronin": {
		"name": "堕落浪人", "rank": "elite", "hp": 300.0, "posture": 200.0, "speed": 105.0, "guard": 0.4,
		"body": Vector2(30, 56), "prop": "", "flourish": true, "idle": ["shoulder", "stalk"],
		"look": {"scale": 1.12, "hat": true, "cape": true, "width": 1.15, "sword_len": 28.0,
			"cloth": Color("6e2a2a"), "cloth_dark": Color("461a1d"), "cloth_light": Color("9a4438"),
			"collar": Color("b8ab96"), "pants": Color("2f2c36"), "pants_dark": Color("1d1b22"),
			"pants_light": Color("4a4656"), "hair": Color("2a1a14"), "belt": Color("6d6247"),
			"cape_color": Color("3b2e2b")},
		"ai": {"attack_range": 93.0, "keep": [45.0, 81.0],
			"picks": [["slash", 45], ["sweep", 20], ["quick", 15], ["thrust", 20]],
			"far": [["thrust", 0.72, 93.0, 240.0]]},
		"phases": [
			{"speed": 1.0, "aura": Color(0, 0, 0, 0)},
			{"speed": 0.85, "aura": Color(1, 0.25, 0.1), "line": "第二管血"},
		],
		"moves": {
			"slash": {"name": "三连斩", "kind": "slash", "unblockable": false,
				"dmg": 25.0, "posture": 30.0, "reach": 39.0, "size": Vector2(66, 36), "height": 30.0, "lunge": 0.0,
				"hits": [[0.45, 0.10, 0.18], [0.28, 0.10, 0.18], [0.34, 0.12, 0.60]],
				"poses": [["raise1", "cut1"], ["raise2", "cut2"], ["raise1", "cut1"]], "fx": "slash"},
			"quick": {"name": "快斩", "kind": "slash", "unblockable": false,
				"dmg": 20.0, "posture": 30.0, "reach": 39.0, "size": Vector2(63, 36), "height": 30.0, "lunge": 0.0,
				"hits": [[0.24, 0.10, 0.45]], "poses": [["raise1", "cut1"]], "fx": "slash"},
			"sweep": {"name": "下段横扫", "kind": "sweep", "unblockable": true,
				"dmg": 35.0, "posture": 40.0, "reach": 45.0, "size": Vector2(96, 18), "height": 9.0, "lunge": 0.0,
				"hits": [[0.60, 0.16, 0.65]], "poses": [["sweep_prep", "sweep_cut"]], "fx": "sweep"},
			"thrust": {"name": "突刺", "kind": "thrust", "unblockable": true,
				"dmg": 40.0, "posture": 40.0, "reach": 33.0, "size": Vector2(60, 21), "height": 30.0, "lunge": 780.0,
				"hits": [[0.65, 0.20, 0.65]], "poses": [["thrust_prep", "cut3"]], "fx": "streak"},
		},
	},

	# ---------- 杂兵：野狗 ----------
	# 跑得快、咬一口就跳开，几只一起围着你转。咬和扑都能弹反，弹反一下就僵直。
	"dog": {
		"name": "野狗", "rank": "grunt", "hp": 45.0, "posture": 40.0, "speed": 175.0, "guard": 0.0,
		"body": Vector2(30, 22), "prop": "", "stomp_stagger": true, "beast": true,
		"look": {"fur": Color("6b5848"), "fur_dark": Color("40342c"), "fur_light": Color("927a62")},
		"ai": {"attack_range": 78.0, "keep": [70.0, 120.0], "retreat": 0.45, "flank": true,
			"picks": [["bite", 70], ["pounce", 30]],
			"far": [["pounce", 0.9, 90.0, 170.0]]},
		"phases": [{"speed": 1.0}],
		"moves": {
			"bite": {"name": "撕咬", "kind": "slash", "unblockable": false,
				"dmg": 14.0, "posture": 18.0, "reach": 20.0, "size": Vector2(34, 18), "height": 14.0, "lunge": 360.0,
				"hits": [[0.38, 0.14, 0.35]], "fx": "bite"},
			"pounce": {"name": "飞扑", "kind": "slash", "unblockable": false,
				"dmg": 18.0, "posture": 22.0, "reach": 18.0, "size": Vector2(34, 26), "height": 22.0, "lunge": 330.0,
				"hop": -330.0, "hits": [[0.5, 0.36, 0.4]], "fx": "bite"},
		},
	},

	# ---------- 杂兵：弓手 ----------
	# 站远处放箭；箭能格挡，弹反会把箭打回去。贴身会踢一脚然后后跳拉开。
	"archer": {
		"name": "弓手", "rank": "grunt", "hp": 50.0, "posture": 40.0, "speed": 90.0, "guard": 0.0,
		"body": Vector2(26, 52), "prop": "bow", "idle": ["bow_idle", "bow_ready"],
		"look": {"scale": 1.0, "hat": true, "width": 0.95, "sword_len": 0.0,
			"cloth": Color("4d5a3a"), "cloth_dark": Color("323b25"), "cloth_light": Color("6f7e52"),
			"collar": Color("a89f86"), "pants": Color("3a3229"), "pants_dark": Color("241f19"),
			"pants_light": Color("54493c"), "belt": Color("7a5a32"),
			"hat_color": Color("8a7a52"), "hat_dark": Color("5a4e33")},
		"ai": {"attack_range": 58.0, "keep": [150.0, 250.0], "retreat": 0.35,
			"picks": [["kick", 100]],
			"far": [["shot", 0.8, 80.0, 420.0]]},
		"phases": [{"speed": 1.0}],
		"moves": {
			"shot": {"name": "射箭", "kind": "slash", "unblockable": false, "nohit": true,
				"dmg": 0.0, "posture": 0.0, "reach": 0.0, "size": Vector2.ZERO, "height": 0.0, "lunge": 0.0,
				"hits": [[0.75, 0.05, 0.55]], "poses": [["bow_draw", "bow_loose"]], "fx": "arrow",
				"arrow": {"speed": 330.0, "dmg": 16.0, "posture": 22.0}},
			"kick": {"name": "踢", "kind": "slash", "unblockable": false,
				"dmg": 10.0, "posture": 25.0, "reach": 24.0, "size": Vector2(36, 24), "height": 18.0, "lunge": 120.0,
				"hits": [[0.32, 0.1, 0.3]], "poses": [["kick_prep", "kick"]], "fx": "none",
				"then": "hop_back"},
			"hop_back": {"name": "后跳", "kind": "slash", "unblockable": false, "nohit": true,
				"dmg": 0.0, "posture": 0.0, "reach": 0.0, "size": Vector2.ZERO, "height": 0.0, "lunge": -260.0,
				"hop": -260.0, "hits": [[0.05, 0.35, 0.15]], "poses": [["hop", "hop"]], "fx": "none"},
		},
	},

	# ---------- 杂兵：盾兵 ----------
	# 举着木盾往前压，正面的轻攻击全被挡住。重击、回旋斩能把盾打开；两个人一前一后也能绕背。
	"shield": {
		"name": "盾兵", "rank": "grunt", "hp": 70.0, "posture": 60.0, "speed": 62.0, "guard": 0.0,
		"body": Vector2(30, 54), "prop": "shield", "shield": true, "idle": ["shield_stance", "shield_stance"],
		"look": {"scale": 1.08, "hat": true, "width": 1.2, "sword_len": 38.0,
			"cloth": Color("4a4f5c"), "cloth_dark": Color("2e323b"), "cloth_light": Color("6b7282"),
			"collar": Color("9a9184"), "pants": Color("2b2a30"), "pants_dark": Color("1a191e"),
			"pants_light": Color("434149"), "belt": Color("5a4a33"),
			"hat_color": Color("4b4d55"), "hat_dark": Color("2c2d33"),
			"blade": Color("aab4bf"), "hilt": Color("6b4a2a"), "tsuba": Color("6b4a2a")},
		"ai": {"attack_range": 72.0, "keep": [52.0, 68.0],
			"picks": [["bash", 60], ["spear", 40]],
			"far": [["spear", 0.45, 72.0, 120.0]]},
		"phases": [{"speed": 1.0}],
		"moves": {
			"bash": {"name": "盾击", "kind": "slash", "unblockable": false,
				"dmg": 14.0, "posture": 35.0, "reach": 26.0, "size": Vector2(40, 40), "height": 28.0, "lunge": 240.0,
				"hits": [[0.5, 0.12, 0.5]], "poses": [["bash_prep", "bash"]], "fx": "none"},
			"spear": {"name": "长枪突刺", "kind": "thrust", "unblockable": true,
				"dmg": 30.0, "posture": 30.0, "reach": 44.0, "size": Vector2(64, 18), "height": 30.0, "lunge": 300.0,
				"hits": [[0.7, 0.16, 0.7]], "poses": [["spear_prep", "spear"]], "fx": "streak"},
		},
	},

	# ---------- 第一层头目：断水 · 柳江远 ----------
	# 教学头目：一阶段教弹反，二阶段加入看破、居合和迟斩，三阶段假动作更多、出招更快。
	"liu": {
		"name": "断水 · 柳江远", "rank": "boss", "hp": 260.0, "posture": 230.0, "speed": 115.0, "guard": 0.45,
		"body": Vector2(30, 58), "prop": "", "idle": ["liu_calm", "st_gedan"],
		"look": {"scale": 1.16, "hat": false, "cape": true, "width": 1.05, "sword_len": 33.0,
			"cloth": Color("c8cdd4"), "cloth_dark": Color("858fa0"), "cloth_light": Color("eef1f4"),
			"collar": Color("2b3a52"), "pants": Color("2b3a52"), "pants_dark": Color("1a2436"),
			"pants_light": Color("40567a"), "hair": Color("26262e"), "belt": Color("33476b"),
			"band": Color("e8ecf0"), "cape_color": Color("2f4766"), "skin": Color("e2b294")},
		"intro": [["柳江远", "……又是来找那把刀的人吗。"], ["柳江远", "这条河，我守了二十年。"]],
		"intro_meets": {
			3: [["柳江远", "又是你。你手上的印，比上回深了。"], ["柳江远", "我问过很多人为何上山。今天也问你。"]],
			5: [["柳江远", "第五回了。"], ["柳江远", "……你出刀的样子，越来越像他。来吧。"]],
		},
		"death_line": ["柳江远", "原来……水也会断。"],
		"ai": {"attack_range": 96.0, "keep": [50.0, 88.0],
			"picks": [["flow", 40], ["quick", 15], ["feint", 15], ["grab", 15], ["sweep", 15]],
			"far": [["thrust", 0.5, 96.0, 240.0]]},
		"phases": [
			{"speed": 1.0, "aura": Color(0, 0, 0, 0)},
			{"speed": 0.9, "aura": Color(0.45, 0.75, 1.0), "line": ["柳江远", "……好刀。那我也不必留手了。"],
				"picks": [["flow", 25], ["delay", 15], ["feint", 15], ["grab", 15], ["sweep", 10], ["backstep", 20]],
				"far": [["thrust", 0.5, 96.0, 240.0], ["iai", 0.6, 96.0, 200.0]]},
			{"speed": 0.8, "aura": Color(0.3, 0.6, 1.0), "line": ["柳江远", "水，是斩不断的。"],
				"picks": [["rain", 25], ["delay", 10], ["feint", 20], ["grab", 15], ["sweep", 10], ["backstep", 20]],
				"far": [["thrust", 0.5, 96.0, 240.0], ["iai", 0.9, 96.0, 220.0]]},
		],
		"moves": {
			"flow": {"name": "流水三连", "kind": "slash", "unblockable": false,
				"dmg": 26.0, "posture": 32.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.42, 0.10, 0.16], [0.24, 0.10, 0.16], [0.30, 0.12, 0.55]],
				"poses": [["raise1", "cut1"], ["raise2", "cut2"], ["raise3", "cut3"]], "fx": "slash"},
			"rain": {"name": "流水五连", "kind": "slash", "unblockable": false,
				"dmg": 24.0, "posture": 30.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.40, 0.09, 0.12], [0.22, 0.09, 0.12], [0.22, 0.09, 0.12], [0.36, 0.09, 0.12], [0.26, 0.12, 0.6]],
				"poses": [["raise1", "cut1"], ["raise2", "cut2"], ["raise1", "cut1"], ["st_jodan", "cut1"], ["raise3", "cut3"]],
				"fx": "slash"},
			"quick": {"name": "快斩", "kind": "slash", "unblockable": false,
				"dmg": 22.0, "posture": 30.0, "reach": 42.0, "size": Vector2(66, 36), "height": 30.0, "lunge": 0.0,
				"hits": [[0.22, 0.10, 0.4]], "poses": [["raise1", "cut1"]], "fx": "slash"},
			# 举刀过顶停很久才砍，急着弹反就会弹早
			"delay": {"name": "迟斩", "kind": "slash", "unblockable": false,
				"dmg": 34.0, "posture": 45.0, "reach": 44.0, "size": Vector2(72, 44), "height": 32.0, "lunge": 120.0,
				"hits": [[1.0, 0.12, 0.5]], "poses": [["st_jodan", "cut1"]], "fx": "slash"},
			# 看起来是流水三连的第一刀，蓄到一半变成突刺
			"feint": {"name": "虚斩", "kind": "slash", "unblockable": false,
				"dmg": 26.0, "posture": 32.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.42, 0.10, 0.4]], "poses": [["raise1", "cut1"]], "fx": "slash",
				"feint": {"into": "thrust", "at": 0.6}},
			"thrust": {"name": "断水突刺", "kind": "thrust", "unblockable": true,
				"dmg": 42.0, "posture": 40.0, "reach": 36.0, "size": Vector2(64, 21), "height": 30.0, "lunge": 820.0,
				"hits": [[0.55, 0.20, 0.6]], "poses": [["thrust_prep", "cut3"]], "fx": "streak"},
			"sweep": {"name": "下段横扫", "kind": "sweep", "unblockable": true,
				"dmg": 35.0, "posture": 40.0, "reach": 48.0, "size": Vector2(100, 18), "height": 9.0, "lunge": 0.0,
				"hits": [[0.55, 0.16, 0.6]], "poses": [["sweep_prep", "sweep_cut"]], "fx": "sweep"},
			# 张开手扑过来抓：不能挡，要闪开；被抓住吃双倍伤害、摔在地上
			"grab": {"name": "擒拿", "kind": "grab", "unblockable": true,
				"dmg": 56.0, "posture": 0.0, "reach": 24.0, "size": Vector2(40, 44), "height": 30.0, "lunge": 420.0,
				"hits": [[0.6, 0.18, 0.75]], "poses": [["grab_prep", "grab_reach"]], "fx": "none", "stun": 1.0},
			# 收刀入鞘，蓄力后冲刺拔刀横斩，距离很远；可以弹反
			"iai": {"name": "居合 · 断水", "kind": "slash", "unblockable": false,
				"dmg": 38.0, "posture": 50.0, "reach": 50.0, "size": Vector2(120, 30), "height": 30.0, "lunge": 620.0,
				"hits": [[0.8, 0.14, 0.7]], "poses": [["st_iai", "iai_cut"]], "fx": "iai"},
			# 往后跳开，落地立刻突刺
			"backstep": {"name": "后跃", "kind": "slash", "unblockable": false, "nohit": true,
				"dmg": 0.0, "posture": 0.0, "reach": 0.0, "size": Vector2.ZERO, "height": 0.0, "lunge": -300.0,
				"hop": -280.0, "hits": [[0.1, 0.38, 0.05]], "poses": [["hop", "hop"]], "fx": "none",
				"then": "thrust"},
		},
	},

	# ---------- 新手引导：教头 ----------
	# 不自己出招，由 Tutorial 一招一招喂：快斩（格挡、弹反）、下段横扫（跳）、突刺（看破）
	"tutor": {
		"name": "教头", "rank": "elite", "hp": 600.0, "posture": 999.0, "speed": 0.0, "guard": 0.0, "passive": true, "no_loot": true,
		"body": Vector2(30, 56), "prop": "", "idle": ["st_gedan", "st_gedan"],
		"look": {"scale": 1.1, "hat": true, "width": 1.1, "sword_len": 28.0,
			"cloth": Color("5a5a64"), "cloth_dark": Color("3a3a44"), "cloth_light": Color("7a7a86"),
			"collar": Color("c8c0b0"), "pants": Color("2e2c34"), "pants_dark": Color("1c1b20"),
			"pants_light": Color("46444e"), "belt": Color("8a6a3a"), "hat_color": Color("8a7a5a"), "hat_dark": Color("5a4e38")},
		"ai": {"attack_range": 0.0, "keep": [0.0, 0.0], "picks": []},
		"phases": [{"speed": 1.15}],
		"moves": {
			"quick": {"name": "快斩", "kind": "slash", "unblockable": false,
				"dmg": 20.0, "posture": 25.0, "reach": 39.0, "size": Vector2(63, 36), "height": 30.0, "lunge": 0.0,
				"hits": [[0.5, 0.10, 0.45]], "poses": [["raise1", "cut1"]], "fx": "slash"},
			"sweep": {"name": "下段横扫", "kind": "sweep", "unblockable": true,
				"dmg": 30.0, "posture": 30.0, "reach": 45.0, "size": Vector2(96, 18), "height": 9.0, "lunge": 0.0,
				"hits": [[0.8, 0.16, 0.65]], "poses": [["sweep_prep", "sweep_cut"]], "fx": "sweep"},
			"thrust": {"name": "突刺", "kind": "thrust", "unblockable": true,
				"dmg": 30.0, "posture": 30.0, "reach": 33.0, "size": Vector2(60, 21), "height": 30.0, "lunge": 700.0,
				"hits": [[0.85, 0.20, 0.65]], "poses": [["thrust_prep", "cut3"]], "fx": "streak"},
		},
	},

	# ---------- 训练场：稻草木桩 ----------
	# 不走不打，血和架势都厚，练连招、压架势、处决用
	"dummy": {
		"name": "稻草木桩", "rank": "elite", "hp": 3000.0, "posture": 300.0, "speed": 0.0, "guard": 0.0, "passive": true, "no_loot": true,
		"body": Vector2(28, 54), "prop": "", "idle": ["idle", "idle"],
		"look": {"scale": 1.05, "hat": false, "width": 1.1, "sword_len": 0.0,
			"cloth": Color("c8a85a"), "cloth_dark": Color("9a7a3a"), "cloth_light": Color("e0c880"),
			"collar": Color("9a7a3a"), "pants": Color("6a4a2a"), "pants_dark": Color("4a3220"),
			"pants_light": Color("8a6a42"), "hair": Color("c8a85a"), "band": Color("8a2a2a"), "belt": Color("6a4a2a"),
			"skin": Color("c8a85a"), "skin_dark": Color("9a7a3a")},
		"ai": {"attack_range": 0.0, "keep": [0.0, 0.0], "picks": []},
		"phases": [{"speed": 1.0}],
		"moves": {},
	},

	# ========== 第二层：竹林古寺 ==========

	# ---------- 杂兵：僧兵 ----------
	# 抡长棍：两下连打能弹反，扫腿要跳，戳棍要看破。会举棍挡刀。
	"sohei": {
		"name": "僧兵", "rank": "grunt", "hp": 80.0, "posture": 60.0, "speed": 85.0, "guard": 0.25,
		"body": Vector2(30, 54), "prop": "", "idle": ["shoulder", "stalk"],
		"look": {"scale": 1.1, "hat": false, "width": 1.2, "sword_len": 46.0,
			"cloth": Color("b8742e"), "cloth_dark": Color("7a4a1c"), "cloth_light": Color("d8964a"),
			"collar": Color("e0d0b0"), "pants": Color("4a3a2a"), "pants_dark": Color("2e241a"),
			"pants_light": Color("6a5440"), "hair": Color("c89070"), "band": Color("c89070"), "belt": Color("6a3a1a"),
			"blade": Color("8a6a42"), "hilt": Color("6a4a2a"), "tsuba": Color("9a9488"), "weapon": "staff"},
		"ai": {"attack_range": 88.0, "keep": [55.0, 80.0],
			"picks": [["staff_combo", 50], ["staff_sweep", 30], ["staff_thrust", 20]],
			"far": [["staff_thrust", 0.4, 88.0, 140.0]]},
		"phases": [{"speed": 1.0}],
		"moves": {
			"staff_combo": {"name": "棍二连", "kind": "slash", "unblockable": false,
				"dmg": 16.0, "posture": 26.0, "reach": 40.0, "size": Vector2(72, 36), "height": 30.0, "lunge": 0.0,
				"hits": [[0.42, 0.10, 0.16], [0.30, 0.12, 0.50]], "poses": [["raise1", "cut1"], ["raise2", "cut2"]], "fx": "slash"},
			"staff_sweep": {"name": "扫堂棍", "kind": "sweep", "unblockable": true,
				"dmg": 26.0, "posture": 30.0, "reach": 46.0, "size": Vector2(100, 18), "height": 9.0, "lunge": 0.0,
				"hits": [[0.60, 0.18, 0.60]], "poses": [["sweep_prep", "sweep_cut"]], "fx": "sweep"},
			"staff_thrust": {"name": "戳棍", "kind": "thrust", "unblockable": true,
				"dmg": 24.0, "posture": 30.0, "reach": 44.0, "size": Vector2(70, 18), "height": 30.0, "lunge": 380.0,
				"hits": [[0.60, 0.16, 0.60]], "poses": [["spear_prep", "spear"]], "fx": "streak"},
		},
	},

	# ---------- 杂兵：忍者 ----------
	# 快、血少，远处扔手里剑（能挡、弹反能打回去），突然冲过来一刀，砍完往后一跳又扔。
	"shinobi": {
		"name": "忍者", "rank": "grunt", "hp": 40.0, "posture": 30.0, "speed": 190.0, "guard": 0.0,
		"body": Vector2(24, 48), "prop": "", "stomp_stagger": true, "idle": ["stalk", "stalk"],
		"look": {"scale": 0.95, "hat": false, "width": 0.9, "sword_len": 16.0,
			"cloth": Color("2a2a34"), "cloth_dark": Color("1a1a22"), "cloth_light": Color("3e3e4c"),
			"collar": Color("2a2a34"), "pants": Color("22222c"), "pants_dark": Color("15151c"),
			"pants_light": Color("34343e"), "hair": Color("1a1a22"), "band": Color("a02a2a"), "belt": Color("3a2a2a")},
		"ai": {"attack_range": 70.0, "keep": [90.0, 160.0], "retreat": 0.5, "flank": true,
			"picks": [["dash_cut", 70], ["vanish", 30]],
			"far": [["shuriken", 0.7, 100.0, 360.0], ["dash_cut", 0.4, 90.0, 170.0]]},
		"phases": [{"speed": 1.0}],
		"moves": {
			"dash_cut": {"name": "疾斩", "kind": "slash", "unblockable": false,
				"dmg": 16.0, "posture": 20.0, "reach": 26.0, "size": Vector2(50, 30), "height": 28.0, "lunge": 620.0,
				"hits": [[0.38, 0.16, 0.40]], "poses": [["thrust_prep", "cut3"]], "fx": "streak"},
			"shuriken": {"name": "手里剑", "kind": "slash", "unblockable": false, "nohit": true,
				"dmg": 0.0, "posture": 0.0, "reach": 0.0, "size": Vector2.ZERO, "height": 0.0, "lunge": 0.0,
				"hits": [[0.45, 0.05, 0.40]], "poses": [["raise2", "cut2"]], "fx": "arrow",
				"arrow": {"speed": 380.0, "dmg": 10.0, "posture": 14.0, "style": "star"}},
			"vanish": {"name": "后跃", "kind": "slash", "unblockable": false, "nohit": true,
				"dmg": 0.0, "posture": 0.0, "reach": 0.0, "size": Vector2.ZERO, "height": 0.0, "lunge": -340.0,
				"hop": -300.0, "hits": [[0.05, 0.30, 0.05]], "poses": [["hop", "hop"]], "fx": "none", "then": "shuriken"},
		},
	},

	# ---------- 精英：破戒僧 ----------
	# 大个子，棍又长又沉：四连打、举过头顶停很久的迟砸、扫堂、突刺。第二管血更快。
	"hakai": {
		"name": "破戒僧", "rank": "elite", "hp": 320.0, "posture": 210.0, "speed": 95.0, "guard": 0.45,
		"body": Vector2(34, 60), "prop": "", "idle": ["shoulder", "stalk"],
		"look": {"scale": 1.25, "hat": false, "width": 1.35, "sword_len": 50.0,
			"cloth": Color("4a2a3a"), "cloth_dark": Color("2e1a24"), "cloth_light": Color("6a3e54"),
			"collar": Color("c8b090"), "pants": Color("2a2026"), "pants_dark": Color("1a1418"),
			"pants_light": Color("40323a"), "hair": Color("b88468"), "band": Color("b88468"), "belt": Color("8a2a2a"),
			"blade": Color("5a4a3a"), "hilt": Color("3a2a1e"), "tsuba": Color("c9a227"), "weapon": "staff"},
		"ai": {"attack_range": 100.0, "keep": [50.0, 90.0],
			"picks": [["combo4", 35], ["sweep", 20], ["slam", 25], ["thrust", 20]],
			"far": [["thrust", 0.5, 100.0, 230.0]]},
		"phases": [
			{"speed": 1.0, "aura": Color(0, 0, 0, 0)},
			{"speed": 0.85, "aura": Color(1.0, 0.5, 0.1), "line": ["破戒僧", "佛也拦不住我！"]},
		],
		"moves": {
			"combo4": {"name": "棍四连", "kind": "slash", "unblockable": false,
				"dmg": 22.0, "posture": 28.0, "reach": 44.0, "size": Vector2(78, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.50, 0.10, 0.14], [0.26, 0.10, 0.14], [0.26, 0.10, 0.14], [0.36, 0.12, 0.60]],
				"poses": [["raise1", "cut1"], ["raise2", "cut2"], ["raise1", "cut1"], ["raise3", "cut3"]], "fx": "slash"},
			"slam": {"name": "迟砸", "kind": "slash", "unblockable": false,
				"dmg": 36.0, "posture": 50.0, "reach": 46.0, "size": Vector2(80, 46), "height": 32.0, "lunge": 140.0,
				"hits": [[0.95, 0.14, 0.60]], "poses": [["st_jodan", "smash"]], "fx": "slash"},
			"sweep": {"name": "扫堂棍", "kind": "sweep", "unblockable": true,
				"dmg": 34.0, "posture": 40.0, "reach": 52.0, "size": Vector2(110, 18), "height": 9.0, "lunge": 0.0,
				"hits": [[0.60, 0.18, 0.60]], "poses": [["sweep_prep", "sweep_cut"]], "fx": "sweep"},
			"thrust": {"name": "穿心棍", "kind": "thrust", "unblockable": true,
				"dmg": 40.0, "posture": 40.0, "reach": 46.0, "size": Vector2(74, 20), "height": 30.0, "lunge": 700.0,
				"hits": [[0.65, 0.20, 0.65]], "poses": [["spear_prep", "spear"]], "fx": "streak"},
		},
	},

	# ---------- 第二层头目：禅刃 · 寂光 ----------
	# 假动作与变招：同一个起手，可能是三连斩，也可能半路变成扫腿、突刺、擒拿；
	# 二阶段会站着不动（静），什么都不做，然后突然一刀；三阶段换成五连，变招更多。
	"jakko": {
		"name": "禅刃 · 寂光", "rank": "boss", "hp": 280.0, "posture": 240.0, "speed": 120.0, "guard": 0.5,
		"body": Vector2(30, 58), "prop": "", "idle": ["liu_calm", "st_hasso"], "title_sub": "第二层 · 竹林古寺",
		"look": {"scale": 1.14, "hat": false, "cape": true, "width": 1.05, "sword_len": 30.0,
			"cloth": Color("d8d0c0"), "cloth_dark": Color("9a9080"), "cloth_light": Color("f0ece4"),
			"collar": Color("5a2a2a"), "pants": Color("3a2a2a"), "pants_dark": Color("241a1a"),
			"pants_light": Color("54403c"), "hair": Color("d8a888"), "band": Color("8a2a2a"), "belt": Color("8a2a2a"),
			"cape_color": Color("5a2a2a"), "skin": Color("d8a888")},
		"intro": [["寂光", "……施主，刀上的杀气太重了。"], ["寂光", "贫僧以刀问禅。答错了，就留在这里吧。"]],
		"intro_meets": {
			3: [["寂光", "又来了。上回的问题，想好了么。"], ["寂光", "眼睛看到的，未必是刀要去的地方。"]],
		},
		"death_line": ["寂光", "……原来，你早就答过了。"],
		"ai": {"attack_range": 96.0, "keep": [50.0, 88.0],
			"picks": [["zen3", 35], ["feint_sweep", 20], ["feint_thrust", 15], ["delay", 15], ["quick", 15]],
			"far": [["thrust", 0.45, 96.0, 230.0]]},
		"phases": [
			{"speed": 1.0, "aura": Color(0, 0, 0, 0)},
			{"speed": 0.9, "aura": Color(0.9, 0.75, 0.4), "line": ["寂光", "心动了。"],
				"picks": [["zen3", 25], ["feint_sweep", 15], ["feint_thrust", 15], ["feint_grab", 15], ["delay", 15], ["still", 15]],
				"far": [["thrust", 0.5, 96.0, 230.0], ["iai", 0.5, 96.0, 210.0]]},
			{"speed": 0.8, "aura": Color(1.0, 0.85, 0.5), "line": ["寂光", "无念，无刀。"],
				"picks": [["zen5", 25], ["feint_sweep", 15], ["feint_thrust", 15], ["feint_grab", 15], ["still", 15], ["backstep", 15]],
				"far": [["thrust", 0.6, 96.0, 240.0], ["iai", 0.8, 96.0, 220.0]]},
		],
		"moves": {
			"zen3": {"name": "禅三连", "kind": "slash", "unblockable": false,
				"dmg": 26.0, "posture": 32.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.42, 0.10, 0.16], [0.24, 0.10, 0.16], [0.30, 0.12, 0.55]],
				"poses": [["raise1", "cut1"], ["raise2", "cut2"], ["raise3", "cut3"]], "fx": "slash"},
			"zen5": {"name": "禅五连", "kind": "slash", "unblockable": false,
				"dmg": 24.0, "posture": 30.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.40, 0.09, 0.12], [0.22, 0.09, 0.12], [0.30, 0.09, 0.12], [0.22, 0.09, 0.12], [0.30, 0.12, 0.6]],
				"poses": [["raise1", "cut1"], ["raise2", "cut2"], ["st_jodan", "cut1"], ["raise2", "cut2"], ["raise3", "cut3"]],
				"fx": "slash"},
			"quick": {"name": "快斩", "kind": "slash", "unblockable": false,
				"dmg": 22.0, "posture": 30.0, "reach": 42.0, "size": Vector2(66, 36), "height": 30.0, "lunge": 0.0,
				"hits": [[0.22, 0.10, 0.4]], "poses": [["raise1", "cut1"]], "fx": "slash"},
			"delay": {"name": "迟斩", "kind": "slash", "unblockable": false,
				"dmg": 34.0, "posture": 45.0, "reach": 44.0, "size": Vector2(72, 44), "height": 32.0, "lunge": 120.0,
				"hits": [[1.1, 0.12, 0.5]], "poses": [["st_jodan", "cut1"]], "fx": "slash"},
			# 变招：起手都像禅三连的第一刀，蓄到一半变成别的
			"feint_sweep": {"name": "变招 · 扫", "kind": "slash", "unblockable": false,
				"dmg": 26.0, "posture": 32.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.42, 0.10, 0.4]], "poses": [["raise1", "cut1"]], "fx": "slash",
				"feint": {"into": "sweep", "at": 0.55}},
			"feint_thrust": {"name": "变招 · 刺", "kind": "slash", "unblockable": false,
				"dmg": 26.0, "posture": 32.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.42, 0.10, 0.4]], "poses": [["raise1", "cut1"]], "fx": "slash",
				"feint": {"into": "thrust", "at": 0.6}},
			"feint_grab": {"name": "变招 · 拿", "kind": "slash", "unblockable": false,
				"dmg": 26.0, "posture": 32.0, "reach": 42.0, "size": Vector2(70, 38), "height": 30.0, "lunge": 0.0,
				"hits": [[0.42, 0.10, 0.4]], "poses": [["raise1", "cut1"]], "fx": "slash",
				"feint": {"into": "grab", "at": 0.6}},
			# 静：收刀站定，什么都不做，然后突然快斩
			"still": {"name": "静", "kind": "slash", "unblockable": false, "nohit": true,
				"dmg": 0.0, "posture": 0.0, "reach": 0.0, "size": Vector2.ZERO, "height": 0.0, "lunge": 0.0,
				"hits": [[0.9, 0.02, 0.05]], "poses": [["st_iai", "st_iai"]], "fx": "none", "then": "quick"},
			"thrust": {"name": "寂灭突刺", "kind": "thrust", "unblockable": true,
				"dmg": 42.0, "posture": 40.0, "reach": 36.0, "size": Vector2(64, 21), "height": 30.0, "lunge": 820.0,
				"hits": [[0.55, 0.20, 0.6]], "poses": [["thrust_prep", "cut3"]], "fx": "streak"},
			"sweep": {"name": "下段横扫", "kind": "sweep", "unblockable": true,
				"dmg": 35.0, "posture": 40.0, "reach": 48.0, "size": Vector2(100, 18), "height": 9.0, "lunge": 0.0,
				"hits": [[0.55, 0.16, 0.6]], "poses": [["sweep_prep", "sweep_cut"]], "fx": "sweep"},
			"grab": {"name": "擒拿", "kind": "grab", "unblockable": true,
				"dmg": 56.0, "posture": 0.0, "reach": 24.0, "size": Vector2(40, 44), "height": 30.0, "lunge": 420.0,
				"hits": [[0.6, 0.18, 0.75]], "poses": [["grab_prep", "grab_reach"]], "fx": "none", "stun": 1.0},
			"iai": {"name": "居合 · 寂", "kind": "slash", "unblockable": false,
				"dmg": 38.0, "posture": 50.0, "reach": 50.0, "size": Vector2(120, 30), "height": 30.0, "lunge": 620.0,
				"hits": [[0.8, 0.14, 0.7]], "poses": [["st_iai", "iai_cut"]], "fx": "iai"},
			"backstep": {"name": "后跃", "kind": "slash", "unblockable": false, "nohit": true,
				"dmg": 0.0, "posture": 0.0, "reach": 0.0, "size": Vector2.ZERO, "height": 0.0, "lunge": -300.0,
				"hop": -280.0, "hits": [[0.1, 0.38, 0.05]], "poses": [["hop", "hop"]], "fx": "none",
				"then": "thrust"},
		},
	},
}


## 遭遇（数字键切换）：name 显示名，spawns [[敌人类型, x 坐标], ...]，intro 为 true 时头目先演登场
const ENCOUNTERS := [
	{"name": "堕落浪人", "spawns": [["ronin", 520.0]]},
	{"name": "野狗群", "spawns": [["dog", 470.0], ["dog", 560.0], ["dog", 650.0]]},
	{"name": "盾兵与弓手", "spawns": [["shield", 480.0], ["archer", 680.0], ["archer", 740.0]]},
	{"name": "荒村混战", "spawns": [["shield", 470.0], ["dog", 540.0], ["dog", 600.0], ["archer", 720.0], ["ronin", 660.0]]},
	{"name": "头目 · 断水 · 柳江远", "spawns": [["liu", 600.0]], "intro": true},
	{"name": "僧兵与忍者", "spawns": [["sohei", 480.0], ["sohei", 560.0], ["shinobi", 700.0], ["shinobi", 740.0]]},
	{"name": "破戒僧", "spawns": [["hakai", 540.0]]},
	{"name": "头目 · 禅刃 · 寂光", "spawns": [["jakko", 600.0]], "intro": true},
	{"name": "稻草木桩", "spawns": [["dummy", 520.0]]},
]


static func get_type(kind: String) -> Dictionary:
	return TYPES[kind]
