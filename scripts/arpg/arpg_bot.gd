class_name ArpgBot
extends Node
## 自动打的机器人（录演示视频、冒烟测试用）：按真实按键动作去按，走的是和玩家一样的输入路径。

var hero: Hero
var mode := "fight"
var _t := 0.0
var _press := {}          # 动作 → 剩余按住时间
var _atk_t := 0.0
var _roll_t := 0.0


func _act(n: String) -> String:
	return ArpgInput.act(0, n)


func _tap(n: String) -> void:
	Input.action_press(_act(n))
	_press[n] = 0.05


func _physics_process(dt: float) -> void:
	_t += dt
	for n: String in _press.keys():
		_press[n] = float(_press[n]) - dt
		if float(_press[n]) <= 0.0:
			Input.action_release(_act(n))
			_press.erase(n)
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
	var move := Vector3.ZERO
	var portal := get_parent().get("_portal") as Node3D
	if near == null:
		if is_instance_valid(portal):
			move = portal.global_position - hero.global_position
	elif nd > 2.2:
		move = near.global_position - hero.global_position
	_set_move(move)
	_atk_t -= dt
	_roll_t -= dt
	if near == null:
		return
	if danger and _roll_t <= 0.0:
		_roll_t = 0.9
		_tap("roll")
		return
	if hero.energy >= hero.max_energy and foes.size() >= 3:
		_tap("beam")
		return
	if bleeding >= 2 and hero.cd["finish"] <= 0.0:
		_tap("finish")
		return
	if nd > 3.5 and nd < 7.5 and hero.cd["dash"] <= 0.0:
		_tap("dash")
		return
	if nd < 2.8 and _atk_t <= 0.0:
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
