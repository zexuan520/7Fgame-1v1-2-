class_name Tutorial
extends Node
## 新手引导：第一次出发时，第一间房换成“村外小路”，教头一步一步教：
## 走跑跳 → 砍木桩 → 格挡 → 弹反 → 跳过下段横扫 → 看破突刺 → 处决。教完（或按 Tab 跳过）出口才开，以后不再出现。
## 教头不自己出招，这里按步骤喂招；他的伤害只有四分之一，玩家血太低会自动回满，不会死在教学里。
##
## 加一步：STEPS 里加一条（text 里的 {动作} 换成 1P 现在的按键），再在 _step_done() 里写怎么算过关、
## _feed() 里写教头这一步出什么招。

const STEPS := [
	{"id": "move", "text": "{left} / {right} 走，同一个方向连按两下是跑；{jump} 跳，空中再按一次是二段跳。往右走。"},
	{"id": "attack", "text": "{attack} 攻击，连按是五连；按住不放是重劈。砍木桩三下。"},
	{"id": "block", "text": "教头要出刀了。按住 {guard} 格挡，挡下两刀。", "feed": "quick", "need": 2},
	{"id": "parry", "text": "出刀前刀尖白光一闪——就在那一下按 {guard}：弹反。弹反两次。", "feed": "quick", "need": 2},
	{"id": "sweep", "text": "红色「危」，蹲低横扫：挡不住，按 {jump} 跳起来躲开。", "feed": "sweep", "need": 1},
	{"id": "mikiri", "text": "红色「危」，往后撤再突刺：迎着他按 {dodge} 闪身，是看破。", "feed": "thrust", "need": 1},
	{"id": "execute", "text": "他的架势崩了，身上出现红点：靠近按 {attack} 处决。"},
]
const FEED_GAP := 1.6               # 教头两次出招之间等多久
const FEED_RANGE := 130.0           # 玩家走到这么近教头才出招
const TUTOR_X := 820.0
const DUMMY_X := 560.0
const DMG_MULT := 0.25

var main: Node
var step := 0
var count := 0                      # 这一步做成了几次
var tutor: Enemy = null
var dummy: Enemy = null
var _base := {}                     # 这一步开始时的统计（弹反、格挡、看破次数）
var _gap := 0.0
var _feed_hp := 0.0                 # 喂招时玩家的血（招收完没掉血 = 躲开了）
var _feeding := false
var _start_x := 0.0
var _jumped := false
var done := false


func _ready() -> void:
	_begin(0)


func player() -> Player:
	return main.players[0] if not main.players.is_empty() else null


## 这一步的提示，{动作} 换成 1P 现在绑的第一个键
func text() -> String:
	if done:
		return ""
	var t: String = STEPS[step]["text"]
	for a: String in Game.ACTION_NAMES:
		var names := Game.key_names("p1_" + a).split(" / ")
		t = t.replace("{%s}" % a, names[0] if not names.is_empty() else a)
	return t


func _begin(i: int) -> void:
	step = i
	count = 0
	_gap = 0.8
	_feeding = false
	var p := player()
	if p != null:
		p.hp = p.max_hp
		p.posture = 0.0
		_base = {"parry": p.parry_count, "block": p.block_count, "mikiri": p.mikiri_count}
		_start_x = p.global_position.x
	match String(STEPS[i]["id"]):
		"attack":
			dummy = main.spawn_enemy("dummy", Vector2(DUMMY_X, main.FLOOR_Y))
		"block":
			_clear_dummy()
			tutor = main.spawn_enemy("tutor", Vector2(TUTOR_X, main.FLOOR_Y))
			tutor.dmg_mult = DMG_MULT
			tutor.facing = -1
		"execute":
			if is_instance_valid(tutor):
				tutor._break()
	main.hud.tutorial(text())
	if i > 0:
		Game.sfx("ui_select")


func _clear_dummy() -> void:
	if is_instance_valid(dummy):
		main.spawn_dust(dummy.global_position, 0.0, 10)
		main.enemies.erase(dummy)
		dummy.queue_free()
	dummy = null


func _process(delta: float) -> void:
	if done:
		return
	var p := player()
	if p == null:
		return
	# 教学里不会死：血低了回满
	if p.hp < p.max_hp * 0.3 and p.is_alive():
		p.hp = p.max_hp
		main.spawn_text(p.global_position + Vector2(0, -70), "（教头收了手）", Color(0.8, 0.8, 0.85), 12)
	if Input.is_action_just_pressed("toggle_map"):
		finish(true)
		return
	if not p.is_on_floor():
		_jumped = true
	if is_instance_valid(tutor) and tutor.lives <= 0 and String(STEPS[step]["id"]) != "execute":
		finish(false)   # 提前把教头放倒了：也算教完
		return
	_feed(delta, p)
	if _step_done(p):
		Game.sfx("reward")
		main.spawn_text(p.global_position + Vector2(0, -84), "好", Color(1.0, 0.9, 0.5), 16)
		if step + 1 < STEPS.size():
			_begin(step + 1)
		else:
			finish(false)


## 这一步做到了没有
func _step_done(p: Player) -> bool:
	var need := int(STEPS[step].get("need", 1))
	match String(STEPS[step]["id"]):
		"move":
			return p.global_position.x > _start_x + 160.0 and _jumped
		"attack":
			return is_instance_valid(dummy) and dummy.max_hp - dummy.hp >= 3 * 15.0
		"block":
			return p.block_count - int(_base["block"]) >= need
		"parry":
			return p.parry_count - int(_base["parry"]) >= need
		"sweep":
			return count >= need
		"mikiri":
			return p.mikiri_count - int(_base["mikiri"]) >= need
		"execute":
			return not is_instance_valid(tutor) or tutor.lives <= 0
	return false


## 教头喂招：玩家走近了、上一招收完了、等了一会儿，就出这一步的招
func _feed(delta: float, p: Player) -> void:
	var move: String = STEPS[step].get("feed", "")
	if not is_instance_valid(tutor):
		return
	if String(STEPS[step]["id"]) == "execute":
		if tutor.lives > 0 and tutor.state != Enemy.S.BROKEN and tutor.is_hittable():
			tutor._break()   # 架势一直是崩的，等玩家来处决
		return
	if move == "":
		return
	var idle := tutor.state == Enemy.S.IDLE or tutor.state == Enemy.S.GUARD
	if _feeding and idle:
		# 一招收完：跳过横扫这一步，没掉血就算躲开了
		_feeding = false
		if move == "sweep" and p.hp >= _feed_hp - 0.5:
			count += 1
	if not idle:
		return
	_gap -= delta
	if _gap > 0.0 or absf(p.global_position.x - tutor.global_position.x) > FEED_RANGE:
		return
	_gap = FEED_GAP
	_feeding = true
	_feed_hp = p.hp
	tutor.target = p
	tutor._start_move(move)


## 教完（或者跳过）：记进存档，出口开
func finish(skipped: bool) -> void:
	done = true
	Game.save["tutorial_done"] = true
	Game.write_save()
	_clear_dummy()
	if is_instance_valid(tutor) and tutor.lives > 0:
		main.spawn_dust(tutor.global_position, 0.0, 12)
		main.enemies.erase(tutor)
		tutor.queue_free()
	main.hud.tutorial("")
	main.hud.say("教头", "……跳过也行。山上的人可不会手下留情。" if skipped else "去吧。山上的人，可不会这么手下留情。", 3.5)
	main.tutorial_finished()
	queue_free()
