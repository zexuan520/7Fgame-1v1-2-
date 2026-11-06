class_name ArpgBot
extends Node
## 自动打的机器人（录演示视频、冒烟测试用）：按真实按键动作去按，走的是和玩家一样的输入路径。

var hero: Hero
var mode := "fight"
var _t := 0.0
var _press := {}          # 动作 → 剩余按住时间
var _atk_t := 0.0
var _roll_t := 0.0
var _skill_t := 0.0
var _menu_t := 0.0
var _stuck_t := 0.0
var _last_p := Vector3.ZERO
var _side_t := 0.0
var _side := 1.0


func _act(n: String) -> String:
	return ArpgInput.act(0, n)


func _tap(n: String) -> void:
	# 已经按着的先松开一帧，不然 is_action_just_pressed 不会再触发（一直按住就卡住了）
	if _press.has(n) or Input.is_action_pressed(_act(n)):
		return
	Input.action_press(_act(n))
	_press[n] = 0.05


func _physics_process(dt: float) -> void:
	_t += dt
	for n: String in _press.keys():
		_press[n] = float(_press[n]) - dt
		if float(_press[n]) <= 0.0:
			Input.action_release(_act(n))
			_press.erase(n)
	# 菜单开着（心法三选一、分岔路）：看一会儿再随手选一个
	var menu := get_parent().get("_menu") as Control
	if is_instance_valid(menu):
		_set_move(Vector3.ZERO)
		_menu_t += dt
		if _menu_t > 1.6:
			_menu_t = 0.0
			_tap("attack")
		elif _menu_t > 0.8 and _menu_t - dt <= 0.8 and str(menu.get("title")) != "再战？":
			_tap("right")
		return
	_menu_t = 0.0
	if not is_instance_valid(hero) or not hero.alive:
		return
	var foes := get_tree().get_nodes_in_group("foes")
	var near: Foe = null
	var nd := 1e9
	var bleeding := 0
	var danger := false
	for f: Node in foes:
		var a := f as Foe
		if a == null or not a.alive:
			continue
		var d := a.global_position.distance_to(hero.global_position)
		if d < nd:
			nd = d
			near = a
		if a.bleed > 0 and d < 7.0:
			bleeding += 1
		if a.state == "windup" and d < 4.0 and a.st_t > a._windup_time() * 0.6:
			danger = true
		if a.state in ["windup", "attack"] and a._atk in ["leap", "boss_leap"] and a._atk_target.distance_to(hero.global_position) < 3.4:
			danger = true
	# 试刀场：按教学要求的键来
	var need = get_parent().get("_tut_need")
	if need is String and need != "":
		if need == "move":
			_set_move(Vector3(sin(_t * 1.3), 0, cos(_t * 0.9)))
			return
		_skill_t -= dt
		if need != "attack" and _skill_t <= 0.0 and (near != null or need in ["roll", "heal"]):
			_skill_t = 1.2
			if need != "dash" or nd < 8.0:
				_tap(need)
				return
	var move := Vector3.ZERO
	var pv: Variant = get_parent().get("_portal")
	var portal: Node3D = pv as Node3D if is_instance_valid(pv) else null
	if near == null:
		if is_instance_valid(portal):
			move = portal.global_position - hero.global_position
	elif nd > (6.0 if hero.weapon_id == "crossbow" else 2.2):
		move = near.global_position - hero.global_position
	elif hero.weapon_id == "crossbow" and nd < 3.5:
		move = hero.global_position - near.global_position
	# 卡在障碍上：原地不动超过 0.8 秒就往侧面绕一下
	if move.length() > 0.5:
		if hero.global_position.distance_to(_last_p) < 0.05:
			_stuck_t += dt
		else:
			_stuck_t = 0.0
		if _stuck_t > 0.8:
			_stuck_t = 0.0
			_side_t = 0.7
			_side = -_side
	_last_p = hero.global_position
	if _side_t > 0.0:
		_side_t -= dt
		move = move.normalized().cross(Vector3.UP) * _side * 2.0 - move.normalized() * 0.5
	_set_move(move)
	_atk_t -= dt
	_roll_t -= dt
	_skill_t -= dt
	if near == null:
		return
	# 喝药：离得远或敌人收招时喝；血太低（< 25%）且没在挨刀的前摇里也喝（不然打头目时药一直不喝就死了）
	# （数值联调时改的：原来要“离得远或敌人收招”才喝，成群的时候几乎等不到，机器人常带着满葫芦死掉，测出来的难度偏高）
	if hero.hp < hero.max_hp * 0.45 and hero.gourds > 0 and _skill_t <= 0.0 \
			and (not danger or hero.hp < hero.max_hp * 0.2):
		_skill_t = 1.0
		_atk_t = 0.7   # 别马上又按攻击把喝药的输入盖掉
		_tap("heal")
		return
	if danger and _roll_t <= 0.0:
		_roll_t = 0.9
		_tap("roll")
		return
	if hero.art_id() != "" and hero.cd["art"] <= 0.0 and nd < 4.5 and _skill_t <= 0.0:
		_skill_t = 0.6
		_tap("art")
		return
	if hero.energy >= hero.beam_cost and foes.size() >= 3 and _skill_t <= 0.0:
		_skill_t = 0.5
		_tap("beam")
		return
	if bleeding >= 2 and hero.cd["finish"] <= 0.0:
		_tap("finish")
		return
	if nd > 3.5 and nd < 7.5 and hero.cd["dash"] <= 0.0:
		_tap("dash")
		return
	# 兵器、道具：成群的时候扔道具，副手冷却好了贴身换手打换刃斩
	if hero.kit != null and _skill_t <= 0.0:
		if not hero.kit.props.is_empty() and foes.size() >= 3 and nd < 6.0 and randf() < 0.02:
			_skill_t = 0.8
			_tap("item")
			return
		if not (hero.kit.arms[1] as Dictionary).is_empty() and hero.cd["swap_strike"] <= 0.0 and nd < 3.0 and randf() < 0.01:
			_skill_t = 0.8
			_tap("swap")
			return
	var reach := 9.0 if hero.weapon_id == "crossbow" else (3.6 if hero.weapon_id == "spear" else 2.8)
	if nd < reach and _atk_t <= 0.0:
		_atk_t = 0.11
		_tap("attack")


func _set_move(v: Vector3) -> void:
	v.y = 0
	var dirs := {"right": v.x, "left": -v.x, "down": v.z, "up": -v.z}
	var l := v.length()
	for n: String in dirs:
		var s := clampf(float(dirs[n]) / maxf(l, 0.001), 0.0, 1.0) if l > 0.3 else 0.0
		if s > 0.05:
			Input.action_press(_act(n), s)
		else:
			Input.action_release(_act(n))
