class_name Finale
extends RefCounted
## 终章 · 第八灯（隐藏头目烛王、终章结局“天明”）。
## 伏笔：灯冢秘境“第八灯座”上刻着“第八灯，以国为薪”；不夜将军说毁了灯模“世上就不会有第八盏”；
##       拾骨婆是守灯一族最后一人，真结局里她说出自己叫阿烛。
## 设定：烛国最后的王把第八盏灯点在自己胸口，烧的是整个烛国，所以烛国的兵和民都成了骨头站在山里。
##       长明帝的“以灯代心”是学他的。七盏都灭了以后，第八盏还在山腹最深处跳。阿烛是他的女儿。
## 流程：看过第三幕真结局“归途”以后，回山门拾骨婆提一次（arpg_finale_told）；之后第三幕打倒长明帝，
##       战后多一段“龙椅底下有心跳”，选下去就进无光殿打烛王（state.flags.finale，ArpgState.boss_kind 换成 boss10）。
##       打赢：终章结局“天明”，解锁隐藏心法“第八灯”（arpg_king）；倒下：被灯光推回金殿，照常选最终结局。
## 存档：arpg_finale_told、arpg_king（打赢过烛王）、arpg_dawn（看过天明）
## 测试：--storytest=finale（存档改成看过归途，直接进长明帝房）、--room=boss --act=3 --floor=2 --finale（直接进无光殿）

const C_KING := Color(1.0, 0.62, 0.35)
const C_HAG := ArpgStory.C_HAG
const C_HERO := ArpgStory.C_HERO
const C_JIN := ArpgStory.C_JIN


## 解锁：看过第三幕真结局
static func unlocked() -> bool:
	return (Game.save.get("arpg_act3_endings", {}) as Dictionary).has("true")


## 山门：看过归途后第一次回来，拾骨婆提一句
static func hint_ready() -> bool:
	return unlocked() and not bool(Game.save.get("arpg_finale_told", false))


const HINT := [
	["", "拾骨婆坐在小院的门槛上。灯都灭了，她却还在。"],
	["拾骨婆", "……你又回来了。我也纳闷，怎么还没躺下。", C_HAG],
	["拾骨婆", "夜里我贴着地听。山底下有东西在跳，一下，一下，比我老，比七盏灯都老。", C_HAG],
	["残刃", "第八灯。灯冢里那座空灯座。", C_HERO],
	["拾骨婆", "灯座是空的，因为灯不在座上。……在一个人的胸口里。", C_HAG],
	["拾骨婆", "下回你在王都打倒那个皇帝，别急着走。听听龙椅底下。", C_HAG],
]

## 长明帝倒下后多出来的一段
const HEARTBEAT := [
	["", "殿里静下来以后，你听见了一声心跳。"],
	["", "从龙椅底下传来，很慢，很沉，像一口埋在地里的钟。每跳一下，殿里的长明灯就一齐暗一下。"],
	["残刃", "……这底下不是王都的地。是山。", C_HERO],
]
const HEARTBEAT_JIN := [["执灯使·烬", "续命司的老档里写过：长明宫是压着一座古陵盖的。我以为是吓唬人的。", C_JIN]]

## 无光殿 · 战前
const PRE := [
	["", "山腹最深处没有一点光。只有一颗心在跳，每跳一下，四壁就亮一下。"],
	["", "一个穿铜甲的人坐在石座上，胸口嵌着一盏灯。灯里烧的不是火，是一整个国家的影子。"],
	["烛王", "七盏都灭了。……我数着。一盏，一盏，又一盏。", C_KING],
	["烛王", "你是来还刀的，还是来借火的？", C_KING],
	["残刃", "我来让他们躺下。", C_HERO],
	["烛王", "他们？我的兵，我的民，我的女儿……没有一个肯躺下。因为灯不许。", C_KING],
	["烛王", "那你就试试。以国为薪的灯，要几刀才斩得断。", C_KING],
]
const PRE_JIN := [["执灯使·烬", "师弟。这一回，我替你看着后背。", C_JIN]]

## 无光殿 · 战后
const POST := [
	["", "烛王胸口的灯裂开一道缝。光从缝里漏出来，照在四壁上，照出成千上万张脸。"],
	["烛王", "……阿烛。你还在外面吗。", C_KING],
	["", "没有人回答。灯芯在你的刀下颤了一下，像是在等。"],
]

## 终章结局 · 天明
const DAWN := [
	["", "你举起合起来的刀。刀身上，师父刻的那行小字亮了：刃断，心不断。"],
	["", "第八盏灯芯断开的时候，没有声音。"],
	["", "山腹里的光一层一层退下去。铜甲士一排一排坐下，像走了很远的路，终于到家。"],
	["烛王", "……原来躺下，是这种感觉。", C_KING],
	["", "你顺着暗河往上走。灯冢、青井、古寺，一路上的骨头都安安静静地躺着，没有一具再站起来。"],
	["", "回到山门，天快亮了。拾骨婆坐在门槛上，第一次没有在数魂玉。"],
	["拾骨婆", "父王他……走得安稳吗。", C_HAG],
	["残刃", "他问你还在不在外面。", C_HERO],
	["拾骨婆", "……在。一直在。", C_HAG],
	["", "她把怀里最后一颗魂玉放在门槛上，靠着门框，闭上了眼睛。东边的山脊上，太阳出来了。"],
]
const DAWN_JIN := [["执灯使·烬", "师弟，下山吧。樱落村的樱树，该浇水了。", C_JIN]]
const DAWN_END := [
	["", "残刃归途，到此为止。"],
	["", "（终章 · 天明　完）"],
]

## 倒在第八灯下
const FALLEN := [
	["", "第八灯的光把你推了出来。"],
	["", "你醒过来，躺在金殿冰凉的地砖上。龙椅底下的缝已经合上了，心跳声远了。"],
	["", "（烛王还在等。下次打倒长明帝，再来。）"],
]


## 长明帝战后：解锁了就先听心跳、问下不下去；没解锁照常选最终结局
static func after_emperor(main: ArpgMain) -> bool:
	if not (unlocked() or main._args.has("finale")) or main.state.flags.has("finale_done"):
		return false
	var lines: Array = HEARTBEAT.duplicate()
	if main.state.flags.has("jin_along") or main.state.flags.has("a2_he"):
		lines.append_array(HEARTBEAT_JIN)
	var d := main._say(lines)
	d.finished.connect(func() -> void:
		var items := [
			{"title": "循着心跳下去", "desc": "隐藏头目 · 烛王。倒下了也不丢这一局：会被推回金殿，照常选结局", "color": C_KING, "tag": "终章"},
			{"title": "不管它", "desc": "处置殿里的长明灯（照常选最终结局）"}]
		var m := main._open_menu("龙椅底下", "心跳声一下一下，从很深的地方传上来。", items, "list", false)
		m.chosen.connect(func(i: int) -> void:
			main._close_menu()
			if i == 1:
				Act3.final_choice(main)
				return
			descend(main)))
	return true


static func descend(main: ArpgMain) -> void:
	main.state.flags["finale"] = true
	main.hud.banner("第八灯", "龙椅底下的石阶，一直往下", 2.4)
	main.feel.screen_flash(Color(1.0, 0.5, 0.2, 0.6), 1.2)
	Game.sfx("memory")
	main.get_tree().create_timer(1.2).timeout.connect(func() -> void:
		main._fade_then(func() -> void: main._enter_room("boss")))


## 战前对白（ArpgMain._boss_intro 经 Act3.boss_pre）
static func pre(main: ArpgMain) -> Array:
	var lines: Array = PRE.duplicate()
	if main.state.flags.has("jin_along") or main.state.flags.has("a2_he"):
		lines.append_array(PRE_JIN)
	return lines


## 打赢：天明
static func won(main: ArpgMain) -> void:
	var st := main.state
	st.flags.erase("finale")
	st.flags["finale_done"] = true
	Game.save["arpg_king"] = true
	Game.save["arpg_dawn"] = true
	var seen: Dictionary = Game.save.get("arpg_act3_endings", {})
	seen["dawn"] = true
	Game.save["arpg_act3_endings"] = seen
	Game.write_save()
	ArpgAch.unlock("boss10")
	ArpgAch.unlock("end_dawn")
	st.add_jade(60)
	var lines: Array = DAWN.duplicate()
	if st.flags.has("jin_along") or st.flags.has("a2_he"):
		lines.append_array(DAWN_JIN)
	lines.append_array(DAWN_END)
	var d := main._say(lines)
	d.finished.connect(func() -> void:
		main.hud.banner("终章 · 天明", "残刃归途", 5.0)
		Game.sfx("reward")
		main.feel.screen_flash(Color(1.0, 0.92, 0.7, 0.8), 2.5)
		main.get_tree().create_timer(3.5).timeout.connect(func() -> void: main._game_over(true, "终章 · 天明")))


## 倒在无光殿：推回金殿，照常选最终结局（这一局打倒长明帝已经算数）
static func fallen(main: ArpgMain) -> void:
	if main.mode != "room":
		return
	main.state.flags.erase("finale")
	main.state.flags["finale_done"] = true
	var d := main._say(FALLEN)
	d.finished.connect(func() -> void: Act3.final_choice(main))
