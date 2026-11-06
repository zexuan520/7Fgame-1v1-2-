class_name FoeSfx
extends RefCounted
## 第二、三幕小怪、头目、机关的专属音效。原来的通用声（挥刀、轰、火、预警…）照旧放，
## 这里在关键那一下再叠一层“这个怪自己的声音”：水骨冒头的水花、灯奴僧的铁链、旗手的号角和战鼓、
## 镇魂铃的铃声、冲骑的马蹄、甲士的铜甲、长明帝的金光……素材见 tools/audio/build_audio.py（全部 CC0）。
##
## 事件名：windup:<招式>（抬手预警）、release:<招式>（出手那一下）、emerge / submerge（冒头 / 潜回水里）、
## death、armor（刀砍在甲上）、aura（灯亮 / 举旗 / 摇铃）、rage（头目半血狂暴）、rage2（烬第三段）、
## wake（稻草人扑起来）、blink（宫灯魂闪身）、rise（灯兵 / 殉灯俑再站起来）。
## 每项是 [[音效, 音量 dB, 音高], ...]，可以叠几层。

## 活人倒下是身子砸地，不是骨头碎
const _BODY := [["body_fall", -4.0, 1.0]]
const _ARMOR_FALL := [["armor_fall", -3.0, 1.0]]
const _GHOST_DIE := [["ghost", -5.0, 1.0]]

const KIND := {
	# ---------- 第二幕 · 青井地宫 ----------
	"drowned": {"emerge": [["splash", -2.0, 1.0]], "death": [["death", -5.0, 1.0], ["splash", -8.0, 1.1]]},
	"eel": {"emerge": [["splash", -1.0, 0.9]], "submerge": [["splash", -4.0, 1.1]], "death": [["death", -5.0, 1.0], ["splash", -8.0, 1.1]]},
	"chainmonk": {"windup:chain": [["chain", -9.0, 0.9]], "release:chain": [["chain", -2.0, 1.0]]},
	"lampkid": {"aura": [["chime", -3.0, 1.0], ["bell_ward", -12.0, 1.4]], "death": [["jar_break", -4.0, 1.2]]},
	# ---------- 第二幕 · 烛国灯冢 ----------
	"armored": {"armor": [["armor_clank", -5.0, 0.9]], "death": _ARMOR_FALL},
	"flameskel": {"death": [["death", -5.0, 1.0], ["fire_burst", -8.0, 1.1]]},
	"oiler": {"release:lob": [["fire_cast", -9.0, 1.2]], "death": [["armor_fall", -6.0, 1.15]]},
	"twin": {"rise": [["rise", -3.0, 1.0]]},
	"phantom": {"windup:charge": [["armor_clank", -12.0, 0.8]], "death": _GHOST_DIE},
	# ---------- 第二幕 · 灰衣营（活人） ----------
	"greyblade": {"death": _BODY}, "greyguard": {"death": _BODY}, "greybow": {"death": _BODY},
	"officer": {"death": [["body_fall", -3.0, 0.9], ["armor_clank", -10.0, 0.8]]},
	"greyspear": {"release:thrust": [["spear", -3.0, 1.0]], "death": _BODY},
	"greyflag": {"aura": [["horn", -6.0, 1.0], ["war_drum", -4.0, 1.0]], "death": _BODY},
	"digger": {"death": _BODY}, "ronin": {"death": _BODY},
	"ashghost": {"windup:charge": [["ghost", -8.0, 1.2]], "death": _GHOST_DIE},
	# ---------- 第三幕 · 柳溪村 ----------
	"lampman": {"rise": [["rise", -4.0, 0.9]], "death": _BODY},
	"scarecrow": {"wake": [["straw", -1.0, 1.0]], "death": [["straw", -3.0, 0.85]]},
	"lampguard": {"release:thrust": [["spear", -3.0, 0.95]], "death": _BODY},
	"torcher": {"release:lob": [["fire_cast", -9.0, 1.2]], "death": _BODY},
	# ---------- 第三幕 · 官道驿站 ----------
	"courier": {"death": _BODY},
	"lancer": {"windup:charge": [["hooves", -2.0, 1.0]], "release:thrust": [["spear", -2.0, 0.9]], "death": [["body_fall", -3.0, 0.9], ["armor_clank", -10.0, 0.8]]},
	"wardbell": {"aura": [["bell_ward", -2.0, 1.0]], "death": [["body_fall", -4.0, 1.0], ["bell_ward", -12.0, 0.8]]},
	"ghostrider": {"windup:charge": [["hooves", -6.0, 0.9], ["ghost", -12.0, 0.8]], "death": _GHOST_DIE},
	# ---------- 第三幕 · 长明宫 ----------
	"goldguard": {"armor": [["armor_clank", -5.0, 1.1]], "death": _ARMOR_FALL},
	"censer": {"release:lob": [["fire_cast", -9.0, 0.9]], "death": _BODY},
	"palaceghost": {"blink": [["ghost", -4.0, 1.2]], "death": _GHOST_DIE},
	"courtghost": {"windup:charge": [["ghost", -8.0, 1.0]], "death": _GHOST_DIE},
	"chief": {"death": _BODY},
	"lampnode": {"death": [["jar_break", -1.0, 0.85], ["gong", -10.0, 1.3]]},
	# ---------- 头目 ----------
	# 井中人·枯荣：铁链横扫、水柱、半血涨水
	"boss4": {"windup:boss_chain": [["chain", -7.0, 0.85]], "release:boss_chain": [["chain", 0.0, 0.85]],
		"release:boss_spikes": [["water_big", -3.0, 1.1]], "windup:boss_tide": [["water_big", -10.0, 0.8]],
		"release:boss_tide": [["water_big", 0.0, 0.9]], "rage": [["gong", -4.0, 0.8], ["water_big", -2.0, 0.8]]},
	# 不夜将军：铜链横扫、号令亲兵、泼油点火
	"boss5": {"death": _ARMOR_FALL, "windup:boss_chain": [["chain", -7.0, 0.8]], "release:boss_chain": [["chain", 0.0, 0.75], ["armor_clank", -8.0, 0.8]],
		"windup:boss_rank": [["war_drum", -2.0, 0.95]], "release:boss_rank": [["horn", -3.0, 0.9]],
		"windup:boss_fire": [["fire_cast", -6.0, 0.9]], "release:boss_fire": [["fire_burst", -2.0, 0.9]],
		"armor": [["armor_clank", -9.0, 0.75]], "rage": [["gong", -4.0, 0.75], ["fire_burst", -3.0, 0.8]]},
	# 执灯使·烬：叫灰衣营、点灯放火、燃烬残影冲阵
	"boss6": {"release:boss_summon": [["horn", -4.0, 1.0]], "windup:boss_rank": [["fire_cast", -6.0, 1.0]],
		"release:boss_rank": [["ghost", -3.0, 0.9]], "windup:boss_fire": [["fire_cast", -6.0, 1.1]],
		"release:boss_fire": [["fire_burst", -2.0, 1.0]], "rage": [["gong", -5.0, 0.9], ["fire_burst", -3.0, 1.0]],
		"rage2": [["fire_burst", 0.0, 0.8], ["ghost", -4.0, 0.8]], "death": [["body_fall", -2.0, 0.9]]},
	# 火师焦明：火罐、火场一圈、天火
	"boss7": {"windup:f_lob": [["fire_cast", -6.0, 1.0]], "windup:f_ring": [["fire_cast", -4.0, 0.9]],
		"release:f_ring": [["fire_burst", -2.0, 0.9]], "windup:f_rain": [["fire_cast", -4.0, 0.8]],
		"release:f_rain": [["fire_burst", -2.0, 0.8]], "rage": [["gong", -4.0, 0.85], ["fire_burst", -2.0, 0.7]],
		"death": [["body_fall", -2.0, 0.9]]},
	# 押灯将霍长风：三连刺、幽骑列阵、箭雨
	"boss8": {"release:h_thrust": [["spear", -2.0, 0.85]], "windup:h_rank": [["horn", -3.0, 0.9]],
		"release:h_rank": [["hooves", 0.0, 0.9], ["ghost", -8.0, 0.8]], "windup:h_rain": [["war_drum", -3.0, 1.0]],
		"release:h_rain": [["arrow_volley", -1.0, 1.0]], "rage": [["horn", -2.0, 0.85], ["war_drum", -2.0, 0.9]],
		"armor": [["armor_clank", -10.0, 0.85]], "death": [["armor_fall", -2.0, 0.85]]},
	# 长明帝：金光扇、光柱、护驾、宫人魂列阵
	"boss9": {"death": [["body_fall", -2.0, 0.85], ["gong", -8.0, 0.6]], "release:boss_wave": [["holy", -4.0, 1.1]], "windup:e_pillar": [["holy", -9.0, 0.8]],
		"release:e_pillar": [["holy", 0.0, 0.9]], "windup:e_summon": [["gong", -6.0, 1.0]],
		"windup:e_rank": [["bell_ward", -4.0, 0.7]], "release:e_rank": [["ghost", -2.0, 0.85]],
		"rage": [["gong", -2.0, 0.7], ["holy", -4.0, 0.8]], "lamp_out": [["jar_break", -2.0, 0.8], ["gong", -6.0, 1.2]]},
}


## 放这个怪这个事件的专属声；没配就返回 false（调用的地方照旧放通用声）
static func play(f: Node, ev: String) -> bool:
	var k: Dictionary = KIND.get(String(f.get("kind")), {})
	if not k.has(ev):
		return false
	for e: Array in k[ev]:
		Game.sfx(String(e[0]), float(e[1]), 0.07, float(e[2]))
	return true
