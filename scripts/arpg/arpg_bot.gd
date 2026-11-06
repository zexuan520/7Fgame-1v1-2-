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
var _stuck_n := 0         # 连着卡了几次（绕得越来越久）
var _far_t := 0.0         # 够不着敌人、站着不动多久
var _last_p := Vector3.ZERO
var _side_t := 0.0
var _side := 1.0
var _heal_t := 0.0
var _portal_t := 0.0
var _esc_t := 0.0         # 连着躲圈躲了多久
var _brave_t := 0.0       # 不躲圈、硬冲的剩余时间


func _act(n: String) -> String:
	return ArpgInput.act(0, n)


func _tap(n: String) -> void:
	# 已经按着的先松开一帧，不然 is_action_just_pressed 不会再触发（一直按住就卡住了）
	if _press.has(n) or Input.is_action_pressed(_act(n)) or ArpgHints.locked(n):
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
		elif _menu_t > 0.8 and _menu_t - dt <= 0.8 and not (str(menu.get("title")) in ["再战？", "龙椅底下"]):   # 龙椅底下：机器人总是下去打烛王
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
			# 数值联调（--quitend）：机器人只会直线走，偶尔被凹进去的摆设卡住走不到光门（人能绕过去，
			# tests/test_rooms 查过出口都走得到），卡 8 秒就直接挪过去，别让一局白白超时
			_portal_t += dt
			if _portal_t > 8.0 and hero.velocity.length() < 0.5 and OS.get_cmdline_user_args().has("--quitend"):
				print("BOTWARP %s -> %s" % [str(hero.global_position.snapped(Vector3.ONE * 0.1)), str(portal.global_position)])
				hero.global_position = portal.global_position + Vector3(0, 0, 1.6)
				_portal_t = 0.0
		else:
			_portal_t = 0.0
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
			# 绕一次没绕开：下次往同一边绕得更久（原来每次换边，会在障碍凹里左右来回晃）
			_stuck_t = 0.0
			_stuck_n += 1
			if _stuck_n % 3 == 0:
				_side = -_side
			_side_t = 0.7 + 0.5 * float(_stuck_n % 3)
	else:
		_stuck_t = 0.0
	# 够不着最近的敌人、原地干站 6 秒（多半卡在摆设后面挨弓手射）：数值联调时直接挪到敌人身边，别把这种死算进难度
	if near != null and nd > 3.0 and hero.velocity.length() < 0.5 and esc_free():
		_far_t += dt
		if _far_t > 6.0 and OS.get_cmdline_user_args().has("--quitend"):
			var to := near.global_position + (hero.global_position - near.global_position).normalized() * 2.0
			print("BOTWARPF %s -> %s (%s)" % [str(hero.global_position.snapped(Vector3.ONE * 0.1)), str(to.snapped(Vector3.ONE * 0.1)), near.kind])
			hero.global_position = Vector3(to.x, hero.global_position.y, to.z)
			_far_t = 0.0
			_stuck_n = 0
	else:
		_far_t = maxf(_far_t - dt, 0.0)
		if hero.velocity.length() > 2.0:
			_stuck_n = 0
	_last_p = hero.global_position
	# 站在地上的火圈、毒圈里：先走出去（数值联调发现机器人一半以上的伤是站在圈里挨的，真人会走开）
	var esc := _pool_escape()
	# 圈挡在路上一直绕不过去（来回躲了 4 秒）：先不管圈，硬冲 3 秒（不然会在圈边来回晃，一间房清不完）
	if _brave_t > 0.0:
		_brave_t -= dt
		esc = Vector3.ZERO
	elif esc != Vector3.ZERO:
		_esc_t += dt
		if _esc_t > 4.0:
			_esc_t = 0.0
			_brave_t = 3.0
			esc = Vector3.ZERO
	else:
		_esc_t = maxf(_esc_t - dt * 0.5, 0.0)
	if esc != Vector3.ZERO:
		move = esc
		_side_t = 0.0
	if _side_t > 0.0:
		_side_t -= dt
		move = move.normalized().cross(Vector3.UP) * _side * 2.0 - move.normalized() * 0.5
	_set_move(move)
	_atk_t -= dt
	_roll_t -= dt
	_skill_t -= dt
	if near == null:
		return
	# 在圈里：先别出刀（出刀会定在原地），陷得深就直接滚出去
	if esc != Vector3.ZERO and _heal_t <= 0.0:
		if esc.length() > 1.2 and _roll_t <= 0.0:
			_roll_t = 0.9
			_tap("roll")
		return
	# 喝药：离得远或敌人收招时喝；血太低（< 25%）且没在挨刀的前摇里也喝（不然打头目时药一直不喝就死了）
	# （数值联调时改的：原来要“离得远或敌人收招”才喝，成群的时候几乎等不到，机器人常带着满葫芦死掉，测出来的难度偏高。
	#  现在想喝就先停手 0.8 秒、每 0.15 秒按一下，直到真喝上：攻击键会把缓冲里的喝药顶掉）
	if _heal_t > 0.0:
		_heal_t -= dt
		if hero.state == "heal":
			_heal_t = 0.0
		elif int(_heal_t / 0.15) != int((_heal_t + dt) / 0.15):
			_tap("heal")
		return
	if hero.hp < hero.max_hp * 0.45 and hero.gourds > 0 and _skill_t <= 0.0 \
			and (not danger or hero.hp < hero.max_hp * 0.2):
		_skill_t = 1.0
		_atk_t = 0.7
		_heal_t = 0.8
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
		if not (hero.kit.arms[1] as Dictionary).is_empty() and hero.cd["swap_strike"] <= 0.0 and not OS.get_cmdline_user_args().has("--lockarms") and nd < 3.0 and randf() < 0.01:
			_skill_t = 0.8
			_tap("swap")
			return
	var reach := 9.0 if hero.weapon_id == "crossbow" else (3.6 if hero.weapon_id == "spear" else 2.8)
	if nd < reach and _atk_t <= 0.0:
		_atk_t = 0.11
		_tap("attack")


func esc_free() -> bool:
	return _esc_t <= 0.0 and _heal_t <= 0.0


## 脚下（或快要踩进去）的敌方火圈毒圈：返回往圈外走的方向，没有就是零
func _pool_escape() -> Vector3:
	if OS.get_cmdline_user_args().has("--botpools"):
		return Vector3.ZERO   # 对比用：照旧不躲
	var out := Vector3.ZERO
	for n: Node in get_tree().get_nodes_in_group("pools"):
		var fp := n as FirePool
		if fp == null or fp.hurts_foes:
			continue
		var to := hero.global_position - fp.global_position
		to.y = 0
		var r := fp.radius + hero.radius + 0.5
		if to.length() < r:
			out += (to.normalized() if to.length() > 0.05 else Vector3(1, 0, 0)) * (r - to.length() + 0.5)
	return out


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
