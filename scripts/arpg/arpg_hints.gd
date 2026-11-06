class_name ArpgHints
extends Node
## 局内即时提示：代替出发前“要不要先教学”的询问。头一次碰到某种情况时，在顶部横幅提示一次该按什么键。
## 每条只提示一次（存档键 arpg_hints）；做完试刀场的玩家全部算看过。挂在 ArpgMain 下面。

var main: ArpgMain
var _t := 0.0
var _room_t := 0.0
var _gap := 0.0            # 两条提示之间至少隔几秒，免得横幅叠在一起

## id → [键盘标题, 触屏标题, 说明]
const HINTS := {
	"move": ["%move WASD 移动　%attack 攻击", "左摇杆移动　「斩」攻击", "连按攻击打出四段连招，最后一段最重"],
	"roll": ["%roll 翻滚", "「滚」翻滚", "敌人举刀发红光时滚开，翻滚的一瞬间无敌"],
	"dash": ["%dash 突进斩", "「突」突进斩", "隔着几步也能一刀贴上去，用完要等冷却"],
	"beam": ["%beam 光束斩", "「光」光束斩", "气力满了：一条直线上的敌人全吃到，放的时候无敌"],
	"finish": ["%finish 终结技", "「终」终结技", "敌人身上有出血（红色菱形）时引爆，层数越多越疼"],
	"heal": ["%heal 药葫芦", "「药」药葫芦", "血不多了：喝一口回一大截，挨打会被打断"],
	"portal": ["清场了", "清场了", "选一个心法，然后走进光门去下一间。路上的岔路自己挑"],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


static func seen() -> Dictionary:
	if bool(Game.save.get("arpg_tutorial", false)):
		return {"all": true}
	var d = Game.save.get("arpg_hints", {})
	return d if d is Dictionary else {}


static func is_seen(id: String) -> bool:
	var s := seen()
	return s.has("all") or s.has(id)


func show(id: String) -> bool:
	if is_seen(id) or _gap > 0.0 or main._args.has("demo") or main._args.has("nohints"):
		return false
	var h: Array = HINTS[id]
	var title := String(h[1]) if TouchPad.active else String(h[0])
	if not TouchPad.active:
		for k: String in ["move", "attack", "roll", "dash", "beam", "finish", "heal"]:
			title = title.replace("%" + k + " ", ArpgInput.key_name(0, k) + " " if k != "move" else "")
	main.hud.banner(title, String(h[2]), 3.6)
	Game.sfx("ui_back", -6.0)
	var s = Game.save.get("arpg_hints", {})
	if not s is Dictionary:
		s = {}
	s[id] = true
	Game.save["arpg_hints"] = s
	Game.write_save()
	_gap = 4.5
	return true


func room_entered() -> void:
	_room_t = 0.0


func _process(dt: float) -> void:
	_gap -= dt
	_room_t += dt
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	if main.mode != "room" or main.room_kind == "tutorial" or is_instance_valid(main._menu) or not main._no_dialog():
		return
	var hero := main.hero
	if not is_instance_valid(hero) or not hero.alive or _room_t < 3.0:
		return
	if main._room_done:
		if main.room_kind in ["fight", "elite", "trial"]:
			show("portal")
		return
	show("move")
	var near := 1e9
	var bleeding := 0
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Foe
		if a == null or not a.alive:
			continue
		var d := a.global_position.distance_to(hero.global_position)
		near = minf(near, d)
		if a.state == "windup" and d < 4.5:
			show("roll")
		if a.bleed > 0 and d < 7.5:
			bleeding += 1
	if hero.energy >= hero.max_energy:
		show("beam")
	if bleeding >= 2 and hero.cd["finish"] <= 0.0:
		show("finish")
	if hero.hp < hero.max_hp * 0.5 and hero.gourds > 0:
		show("heal")
	if near > 4.0 and near < 9.0 and _room_t > 8.0 and hero.cd["dash"] <= 0.0:
		show("dash")
