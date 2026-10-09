class_name Stance
extends RefCounted
## 架势（起手式）：敌人靠近时摆出的姿势，决定第一刀怎么出、以及一些被动效果。
## 加新架势只要在 LIST 里加一条，再在 Player._build_poses() 里加对应的 "st_<id>" 姿势。
##
## 字段：
##   id / name / desc      标识、显示名、一句话说明
##   first                 从架势出的第一刀：raise/cut 是举刀和出刀姿势，
##                         windup/dmg/posture 为倍率，reach 为加长距离
##   parry_bonus           弹反窗口加长（秒）
##   block_posture         格挡时自己架势增长的倍率
##   recover               连击后摇的倍率（越小接得越快）
##   will                  攒刃意的倍率
##   sheathed              摆这个架势时刀收在鞘里（拔刀式）

const LIST := [
	{
		"id": "seigan", "name": "正眼", "desc": "中段持刀，刀尖指向对方眼睛，攻守均衡",
		"first": {"raise": "yoko_raise", "cut": "yoko_cut", "windup": 1.0, "dmg": 1.0, "posture": 1.0, "reach": 0.0},
		"parry_bonus": 0.0, "block_posture": 1.0, "recover": 1.0, "will": 1.0, "sheathed": false,
	},
	{
		"id": "iai", "name": "拔刀", "desc": "刀在鞘中，第一刀居合横斩：出手极快、伤害 ×1.5、距离更远",
		"first": {"raise": "st_iai", "cut": "iai_cut", "windup": 0.5, "dmg": 1.5, "posture": 1.2, "reach": 12.0},
		"parry_bonus": 0.0, "block_posture": 1.0, "recover": 1.0, "will": 1.0, "sheathed": true,
	},
	{
		"id": "jodan", "name": "上段", "desc": "举刀过顶，第一刀重劈：出手慢，但架势伤害 ×1.6",
		"first": {"raise": "st_jodan", "cut": "cut1", "windup": 1.8, "dmg": 1.3, "posture": 1.6, "reach": 3.0},
		"parry_bonus": 0.0, "block_posture": 1.2, "recover": 1.0, "will": 1.0, "sheathed": false,
	},
	{
		"id": "gedan", "name": "下段", "desc": "刀尖垂向地面，重守：弹反窗口 +0.04 秒，格挡时架势增长 ×0.75",
		"first": {"raise": "st_gedan", "cut": "cut2", "windup": 1.0, "dmg": 0.9, "posture": 1.0, "reach": 0.0},
		"parry_bonus": 0.04, "block_posture": 0.75, "recover": 1.0, "will": 1.0, "sheathed": false,
	},
	{
		"id": "hasso", "name": "八相", "desc": "刀立在肩旁，连击后摇缩短 30%，砍得更密",
		"first": {"raise": "st_hasso", "cut": "cut1", "windup": 0.9, "dmg": 1.0, "posture": 1.0, "reach": 0.0},
		"parry_bonus": 0.0, "block_posture": 1.0, "recover": 0.7, "will": 1.0, "sheathed": false,
	},
	{
		"id": "waki", "name": "胁构", "desc": "刀藏身后，对方看不清刀长：第一刀撩斩距离 +15，刃意攒得多 50%",
		"first": {"raise": "st_waki", "cut": "cut2", "windup": 1.1, "dmg": 1.1, "posture": 1.1, "reach": 15.0},
		"parry_bonus": 0.0, "block_posture": 1.0, "recover": 1.0, "will": 1.5, "sheathed": false,
	},
]


static func get_data(index: int) -> Dictionary:
	return LIST[posmod(index, LIST.size())]


## 从架势出的第一刀：在普通第一刀的数值上乘倍率
static func first_strike(base: Dictionary, st: Dictionary) -> Dictionary:
	var f: Dictionary = st["first"]
	var a := base.duplicate()
	a["windup"] = float(base["windup"]) * float(f["windup"])
	a["dmg"] = float(base["dmg"]) * float(f["dmg"])
	a["posture"] = float(base["posture"]) * float(f["posture"])
	a["reach"] = float(base["reach"]) + float(f["reach"])
	a["raise"] = f["raise"]
	a["cut"] = f["cut"]
	a["fx"] = Moves.FX_BY_CUT.get(f["cut"], base.get("fx", ["none"]))
	a["stance"] = st["id"]
	return a
