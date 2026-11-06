class_name ArpgHints
extends Node
## 新手引导：头一次碰到某种情况时，在屏幕上方弹一张小提示卡（不挡操作、不暂停），几秒后自己收起，点一下也能关。
## 菜单（心法、技能分支、岔路、行囊、属性）第一次打开时，提示卡贴在菜单下方。
## 按键按玩家最近用的设备写：键鼠（J、K……）/ 手柄（X、B……）/ 触屏（「斩」「突」……），见 label()。
##
## 第一局逐步解锁（存档 arpg_guide == "on"：从没出发过的新存档，第一次回山门时结束）：
##   第一间只有攻击、翻滚、药葫芦；第二间亮出突进斩；气力第一次攒满（或第三间）亮出光束斩；
##   第一次有敌人出血（或第三间）亮出终结技。没亮出来的招式右下角不画、触屏不显示按键；
##   键盘手柄提前按了也照样能用，按下那一刻就算解锁。
##
## 每条只提示一次（存档 arpg_hints）；做完试刀场的玩家，操作类提示算看过。
## 暂停菜单“新手提示”：开关、回看全部提示、重新提示一遍。挂在 ArpgMain 下面。

var main: ArpgMain
var _t := 0.0
var _room_t := 0.0
var _gap := 0.0            # 两条提示之间至少隔几秒
var _rooms := 0            # 这一局进过几间房（逐步解锁按这个排）
var _queue: Array = []     # 等着弹的提示 id
var _queued_at := {}       # id → 排进来的时刻；看情况弹的提示等太久、或者已经换了房间就作废（下次碰到再排）
var _queued_room := {}
const STICKY := ["dash", "beam", "finish", "hub", "gear", "level"]   # 这些不作废
var _card: Card
var _layer: CanvasLayer
var _npc_t := 0.0

## 第一局逐步解锁的招式
const LOCKABLE := ["dash", "beam", "finish"]
## 试刀场教过的（做完试刀场算看过）
const COMBAT := ["move", "roll", "dash", "beam", "finish", "heal"]

## id → [标签, 标题, 说明, 触屏标题（可省）, 触屏说明（可省）]。{attack} 这类按当前设备换成按键名
const HINTS := {
	"move": ["操作", "{move} 移动　{attack} 攻击", "连按攻击打出四段连招，最后一段最重"],
	"roll": ["操作", "{roll} 翻滚", "敌人举刀发红光时滚开，翻滚的一瞬间无敌"],
	"heal": ["操作", "{heal} 药葫芦", "血不多了喝一口，回一大截。挨打会被打断，先滚开再喝"],
	"dash": ["新招式", "{dash} 突进斩", "隔着几步也能一刀贴上去。用完要等冷却，右下角的圈转满就好了",
		"「突」突进斩", "隔着几步也能一刀贴上去。用完要等冷却，按键上的圈转满就好了"],
	"beam": ["新招式", "{beam} 光束斩", "打中敌人攒气力（血条下的黄条），满了放出一道直线光束，放的时候无敌"],
	"finish": ["新招式", "{finish} 终结技", "连招会让敌人出血（头顶红色菱形），终结技一次引爆附近所有出血，层数越多越疼"],
	"go": ["操作", "{move} 走到发光的门", "走进前面发光的门，往山上去"],
	"portal": ["清场", "选一个心法，再走进光门", "每清一间房都能挑一个心法。光门后面的路，到岔口时自己挑"],
	"side": ["清场", "两侧的门开了", "墙上的侧室清场后才开，里面可能是宝箱、机关，也可能是埋伏"],
	"link": ["连携", "图标外亮起一圈就按它", "某一招的图标外面亮一圈、写着“连携”时马上按，两招接上有额外效果"],
	"swap": ["兵器", "{swap} 换兵器", "身上带着两把兵器。贴着敌人换手，新兵器直接打出收势一击（换刃斩）"],
	"item": ["道具", "{item} 用道具　{item_next} 换一种", "火油罐、雷符、烟丸……最多带三种。捡到、开箱、游商那里都有",
		"「器」用道具", "火油罐、雷符、烟丸……最多带三种。捡到、开箱、游商那里都有"],
	"gear": ["装备", "捡到装备了", "空着的部位自动穿上，其余放进行囊。{bag} 打开行囊换装、对比"],
	"level": ["悟道", "悟道升了一重", "斩敌攒悟道（左下金色细条），每升一重得 1 个天赋点，清场后用来点技能分支"],
	"stats": ["属性", "{stats} 看属性面板", "最终数值和每一项从哪来，装备套装、心法流派都在里面"],
	"boons": ["心法", "三选一，这一局一直有效", "同一流派凑够三个就“大成”；两个流派各有一个，可能凑成“双修”"],
	"skills": ["技能分支", "天赋点用在这里", "五个招式各有两支，先点哪一支就锁定哪一支。秘技是四选一的新大招，学了按 {art}"],
	"path": ["岔路", "上面是这一层的路线图", "战斗房给心法，精英掉装备，游商买东西，土地庙回血，问号是奇遇。走到头是头目"],
	"bag": ["行囊", "换装备、换兵器", "选一件就换上，换下来的放回行囊。同一套的装备穿齐三件有套装效果"],
	"stats_menu": ["属性", "左右换页", "四页：属性、装备、心法与技能、境况。每个数值后面列着它从哪来",
		"点页签换页", "四页：属性、装备、心法与技能、境况。上下拖动翻看，每个数值后面列着它从哪来"],
	"room_shop": ["游商", "走过去按 {interact} 买东西", "铜钱带不出这一局，有就花掉：心法、道具、装备、补药"],
	"room_rest": ["土地庙", "歇一歇", "走过去按 {interact}：回血或者别的好处，只能选一样"],
	"room_event": ["奇遇", "听听对方怎么说", "走过去按 {interact}。选择有好有坏，看清再选"],
	"room_treasure": ["宝箱", "走过去按 {interact} 打开", "宝箱里是装备，品质比平常掉的好"],
	"room_trial": ["试炼", "同一间房，四道试", "疾、守、狂、乱四道试，每道按要求过了就得一枚印。印越多，奖励越好"],
	"room_elite": ["精英", "敌人更硬更狠", "精英带词缀（名字旁边写着）。清完多一个心法可选，还掉装备"],
	"room_boss": ["头目", "看清起手再出刀", "发红光、地上出现红圈的招滚开；它打完一套有空当，那时上去砍"],
	"hub": ["山门", "死了、通关都回到这里", "带回的魂玉在山门花：找拾骨婆点天赋、到兵器架换兵器。走进光门再出发"],
	"npc_hag": ["山门", "拾骨婆 · 天赋", "花魂玉点三棵天赋树，永久生效。也可以跟她闲聊"],
	"npc_rack": ["山门", "兵器架", "挑出发带的兵器（九种，手感各不同），也能开副手、第二个饰品栏"],
	"npc_skin": ["山门", "衣箱", "换外观，只是好看，不影响数值"],
	"npc_tut": ["山门", "试刀 · 教学", "一步一步练一遍全部按键，随时可以来"],
	"npc_ach": ["山门", "功业碑", "成就都记在这里，存档永久保留"],
	"npc_cycle": ["山门", "轮回盘", "通关后才有：点一级，敌人更凶、魂玉更多。级数叠加，每级第一次打通还有一笔魂玉"],
}

## 触屏按键的字（和 TouchPad 上画的一致）
const TOUCH := {"move": "左下摇杆", "attack": "「斩」", "roll": "「滚」", "dash": "「突」", "beam": "「光」", "finish": "「终」",
	"heal": "「药」", "art": "「秘」", "interact": "「互」", "swap": "「换」", "item": "「器」", "item_next": "「器」",
	"bag": "右上「囊」", "stats": "右上「属」", "quit": "右上「Ⅱ」"}
const TOKENS := ["move", "attack", "roll", "dash", "beam", "finish", "heal", "art", "interact", "swap", "item_next", "item", "bag", "stats", "quit"]
## 山门里的人：名字开头 → 提示 id
const NPC_HINTS := [["拾骨婆", "npc_hag"], ["兵器架", "npc_rack"], ["衣箱", "npc_skin"], ["试刀", "npc_tut"], ["功业碑", "npc_ach"], ["轮回盘", "npc_cycle"]]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_layer = CanvasLayer.new()
	_layer.layer = 9   # 在菜单（8）上面
	add_child(_layer)
	_card = Card.new()
	_card.hints = self
	_layer.add_child(_card)


func _input(event: InputEvent) -> void:
	ArpgInput.note(event)


# ---------- 存档 ----------

static func enabled() -> bool:
	return not bool(Game.save.get("arpg_hints_off", false))


static func seen() -> Dictionary:
	var d = Game.save.get("arpg_hints", {})
	return d if d is Dictionary else {}


static func is_seen(id: String) -> bool:
	var s := seen()
	if s.has(id):
		return true
	# 做完试刀场：操作类算看过（“重新提示一遍”之后不算）
	return COMBAT.has(id) and bool(Game.save.get("arpg_tutorial", false)) and not s.has("_reset")


static func _mark(id: String) -> void:
	var s := seen().duplicate()
	s[id] = true
	Game.save["arpg_hints"] = s
	Game.write_save()


## 第一局逐步解锁是否还在进行
static func guide_on() -> bool:
	return enabled() and String(Game.save.get("arpg_guide", "")) == "on"


## 这一招还没亮出来（第一局逐步解锁）
static func locked(action: String) -> bool:
	if not LOCKABLE.has(action) or not guide_on():
		return false
	return not (Game.save.get("arpg_unlocked", []) as Array).has(action)


## 新存档第一局开始时调：打开逐步解锁
static func begin_guide() -> void:
	if int(Game.save.get("runs", 0)) == 0 and not bool(Game.save.get("arpg_tutorial", false)) and enabled():
		Game.save["arpg_guide"] = "on"
		Game.save["arpg_unlocked"] = []
		Game.save["arpg_guide_fights"] = 0
		Game.write_save()


## 第一次回山门：逐步解锁结束，全部招式都在
static func end_guide() -> void:
	if String(Game.save.get("arpg_guide", "")) == "on":
		Game.save["arpg_guide"] = "done"
		Game.write_save()


# ---------- 按键名 ----------

## 当前设备上这个动作怎么按：键鼠 “J” / 手柄 “X” / 触屏 “「斩」”
static func label(action: String) -> String:
	var dev := ArpgInput.device(0)
	if dev == "touch":
		return String(TOUCH.get(action, ""))
	if action == "move":
		return "左摇杆" if dev == "pad" else "WASD"
	if dev == "pad" and action == "bag":
		return "Back"
	var k := ArpgInput.key_name(0, action)
	return "空格" if k == "Space" else k


static func fmt(text: String) -> String:
	for a: String in TOKENS:
		var k := "{" + a + "}"
		if text.contains(k):
			text = text.replace(k, label(a))
	return text


## [标签, 标题, 说明]（按当前设备）
static func text_of(id: String) -> Array:
	var h: Array = HINTS[id]
	var touch := ArpgInput.device(0) == "touch"
	var title := String(h[3]) if touch and h.size() > 3 else String(h[1])
	var body := String(h[4]) if touch and h.size() > 4 else String(h[2])
	return [String(h[0]), fmt(title), fmt(body)]


# ---------- 弹提示 ----------

func _blocked() -> bool:
	return not enabled() or main._args.has("demo") or main._args.has("nohints")


## 头一次碰到：排进队列，空出来就弹（返回 true = 这次排上了）
func show(id: String) -> bool:
	if _blocked() or is_seen(id) or _queue.has(id) or _card.id == id:
		return false
	_queue.append(id)
	_queued_at[id] = main._clock
	_queued_room[id] = _room_no()
	return true


## 菜单第一次打开：提示卡贴在菜单下方，菜单关了就收起
func menu_tip(id: String, menu: Control) -> void:
	if _blocked() or is_seen(id) or menu == null:
		return
	_queue.erase(id)
	if _card.busy() and _card.menu == null and _card.id != "" and _card.id != id and _card.age < 2.5:
		# 局内提示刚弹出来就被菜单顶掉：放回队首，菜单关了再弹
		var old := _card.id
		var s := seen().duplicate()
		s.erase(old)
		Game.save["arpg_hints"] = s
		_queue.push_front(old)
		_queued_at[old] = main._clock
		_queued_room[old] = _room_no()
	_mark(id)
	var tx := text_of(id)
	_log("MENU", id, tx)
	_card.open(id, tx[0], tx[1], tx[2], 12.0, menu)


func _room_no() -> int:
	return main.state.rooms if main.state != null and main.mode == "room" else -1


## 测试：--hintlog 时每弹一条打一行
func _log(what: String, id: String, tx: Array) -> void:
	if main._args.has("hintlog"):
		print("HINT %s %s t=%.1f rooms=%d %s" % [what, id, main._clock, _rooms, " | ".join(tx)])


func _pop() -> void:
	if main._args.has("hintdbg") and not _queue.is_empty() and Engine.get_process_frames() % 60 == 0:
		print("POP q=%s busy=%s gap=%.1f menu=%s dlg=%s" % [str(_queue), _card.busy(), _gap, is_instance_valid(main._menu), not main._no_dialog()])
	if _queue.is_empty() or _card.busy() or _gap > 0.0:
		return
	if is_instance_valid(main._menu) or not main._no_dialog():
		return
	var id := String(_queue.pop_front())
	if is_seen(id):
		return
	if id.begins_with("room_") and id != "room_" + main.room_kind:
		_pop()   # 已经离开那间房了，下回再碰到再说
		return
	if not STICKY.has(id) and not id.begins_with("room_") and not id.begins_with("npc_") \
			and (main._clock - float(_queued_at.get(id, main._clock)) > 10.0 or int(_queued_room.get(id, -1)) != _room_no()):
		_pop()   # 等太久，情况早过去了
		return
	_mark(id)
	var tx := text_of(id)
	_log("CARD", id, tx)
	_card.open(id, tx[0], tx[1], tx[2], 6.5 if String(tx[0]) == "新招式" else 5.5)
	Game.sfx("ui_back", -6.0)
	_gap = 1.2


## 第一局：亮出一招（右下角出现、触屏按键出现、弹提示）
func unlock(action: String) -> void:
	if not locked(action):
		return
	var u: Array = (Game.save.get("arpg_unlocked", []) as Array).duplicate()
	u.append(action)
	Game.save["arpg_unlocked"] = u
	Game.write_save()
	_log("UNLOCK", action, [])
	if is_instance_valid(main.hero) and main.hero.alive:
		var nm := String(ArpgInput.NAMES.get(action, action))
		Feel.I.callout(main.hero.head_top() + Vector3(0, 0.4, 0), "新招式 · " + nm, Color(1.0, 0.88, 0.5), 1.4)
		Vfx.I.shock_ring(main.hero.global_position, Color(1.0, 0.85, 0.45), 0.3, 3.0, 0.4)
		Game.sfx("reward", -6.0)
	# 提示插到队首
	_queue.erase(action)
	if not is_seen(action) and not _blocked():
		_queue.push_front(action)


func room_entered() -> void:
	_room_t = 0.0
	if main.room_kind in ["fight", "elite", "trial", "boss"] and guide_on():
		# 第一局按打过几间战斗房排：第一间只有攻击翻滚，第二间突进斩（气力满了再给光束斩），第三间终结技
		_rooms = int(Game.save.get("arpg_guide_fights", 0)) + 1
		Game.save["arpg_guide_fights"] = _rooms
		Game.write_save()
		if _rooms >= 2:
			unlock("dash")
		if _rooms >= 3:
			unlock("beam")
			unlock("finish")
	var rk := "room_" + main.room_kind
	if HINTS.has(rk):
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if main.mode == "room" and "room_" + main.room_kind == rk:
				show(rk))


func hub_entered() -> void:
	_rooms = 0
	end_guide()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if main.mode == "hub" and int(Game.save.get("runs", 0)) > 0:
			show("hub"))


func _process(dt: float) -> void:
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	_gap -= rdt
	_room_t += dt
	_t += dt
	_pop()
	if _t < 0.25:
		return
	_t = 0.0
	if _blocked():
		return
	var hero := main.hero
	if main.mode == "hub":
		_hub_tick()
		return
	if main.mode != "room" or main.room_kind == "tutorial" or is_instance_valid(main._menu) or not main._no_dialog():
		return
	if not is_instance_valid(hero) or not hero.alive or _room_t < 3.0:
		return
	# 第一局：键盘手柄提前按了没亮出来的招式，就当亮出来了
	for a: String in LOCKABLE:
		if locked(a) and Input.is_action_pressed(ArpgInput.act(0, a)):
			unlock(a)
	if main._room_done:
		if main.room_kind in ["fight", "elite", "trial"]:
			show("portal")
			if not main.side_rooms.is_empty():
				show("side")
		elif main.room_kind == "start":
			show("go")
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
		if locked("beam") and _rooms >= 2 and _room_t > 20.0:
			unlock("beam")
		elif not locked("beam"):
			show("beam")
	if bleeding >= 2 and hero.cd["finish"] <= 0.0 and not locked("finish"):
		show("finish")
	if hero.hp < hero.max_hp * 0.5 and hero.gourds > 0:
		show("heal")
	if near > 4.0 and near < 9.0 and _room_t > 8.0 and hero.cd["dash"] <= 0.0 and not locked("dash"):
		show("dash")
	for s: String in ["dash", "beam", "finish", "art"]:
		if hero.link_glow(s).a > 0.0:
			show("link")
			break
	if hero.kit != null:
		if not hero.kit.props.is_empty() and _room_t > 6.0:
			show("item")
		if not (hero.kit.arms[1] as Dictionary).is_empty() and near < 5.0:
			show("swap")
		if hero.kit.boons.size() >= 1 and hero.kit.rooms >= 3 and _room_t > 10.0:
			show("stats")


## 山门：走到人跟前，头一次说一句他是做什么的
func _hub_tick() -> void:
	if is_instance_valid(main._menu) or not main._no_dialog():
		return
	for n: ArpgNpc in main._npcs:
		if not is_instance_valid(n) or not n._near:
			continue
		for pr: Array in NPC_HINTS:
			if n.display.begins_with(String(pr[0])):
				show(String(pr[1]))
		return


# ---------- 暂停菜单“新手提示” ----------

func open_menu(back: Callable, sel: int = 0) -> void:
	var items := [
		{"title": "新手提示", "right": "开" if enabled() else "关", "desc": "关掉以后不再弹提示，第一局的招式也一次全给"},
		{"title": "重新提示一遍", "desc": "已经看过的提示清掉，之后碰到再弹一次"},
	]
	var ids := []
	for id: String in HINTS:
		var tx := text_of(id)
		var have := is_seen(id)
		items.append({"tag": String(tx[0]), "title": String(tx[1]), "desc": String(tx[2]), "right": "" if have else "还没遇到",
			"color": Color(0.95, 0.92, 0.85) if have else Color(0.6, 0.65, 0.65)})
		ids.append(id)
	var m := main._open_menu("新手提示", "回看全部提示（按键跟着你现在用的键鼠 / 手柄 / 触屏写）", items, "list", true)
	m.index = clampi(sel, 0, items.size() - 1)
	# 选中的那条，完整的说明写在左边
	m.extra_draw = func(c: Control, vs: Vector2) -> void:
		var i := int(c.get("index"))
		if i < 2:
			return
		var tx2 := text_of(String(ids[i - 2]))
		var w := (vs.x - 620.0) * 0.5 - 48.0
		if w < 160.0:
			return
		var x := 24.0
		var y := vs.y * 0.16 + 80.0
		var f: Font = c.get("font")
		c.draw_rect(Rect2(x - 8, y - 4, w + 16, 190), Color(0.03, 0.06, 0.07, 0.85))
		c.draw_rect(Rect2(x - 8, y - 4, 4, 190), Color(ArpgMenu.GOLD, 0.9))
		c.draw_string(f, Vector2(x + 4, y + 20), String(tx2[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ArpgMenu.TEAL)
		(c as ArpgMenu)._wrap(String(tx2[1]), Vector2(x + 4, y + 48), w - 8, 19, Color(0.96, 0.92, 0.84))
		(c as ArpgMenu)._wrap(String(tx2[2]), Vector2(x + 4, y + 84), w - 8, 15, Color(0.75, 0.84, 0.84))
	m.chosen.connect(func(i: int) -> void:
		match i:
			0:
				Game.save["arpg_hints_off"] = enabled()
				if not enabled():
					_queue.clear()
					_card.close()
				Game.write_save()
				Game.sfx("coin")
			1:
				Game.save["arpg_hints"] = {"_reset": true}
				Game.write_save()
				Game.sfx("coin")
				if is_instance_valid(main.hero):
					main.feel.callout(main.hero.head_top(), "提示已重置", Color(0.85, 0.95, 0.95), 1.0)
			_:
				Game.sfx("ui_back", -8.0)
		main._close_menu()
		open_menu(back, i))
	m.cancelled.connect(func() -> void: back.call(), CONNECT_DEFERRED)


# ---------- 提示卡 ----------

class Card extends Control:
	var hints: ArpgHints
	var id := ""
	var tag := ""
	var title := ""
	var body := ""
	var menu: Control           # 贴着哪个菜单（菜单关了就收）
	var _left := 0.0
	var _a := 0.0
	var _rect := Rect2()
	var _w := 0.0
	var age := 0.0              # 这张卡亮了多久
	var _dev := ""
	var _lines: Array = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false

	func busy() -> bool:
		return _left > 0.0

	func open(i: String, tg: String, tt: String, bd: String, secs: float, m: Control = null) -> void:
		id = i
		tag = tg
		title = tt
		body = bd
		menu = m
		_left = secs
		_lines = []
		_dev = ArpgInput.device(0)
		age = 0.0
		visible = true

	func close() -> void:
		_left = minf(_left, 0.25)

	func _process(dt: float) -> void:
		var rdt := clampf(dt / maxf(Engine.time_scale, 0.01), 0.0, 0.1)   # 慢镜头里也按真实时间走
		if Zaohua.is_platform_paused():
			return
		var vs := get_viewport_rect().size
		var menu_open := is_instance_valid(hints.main._menu)
		var hide := false
		if menu != null:
			if not is_instance_valid(menu) or not menu.is_inside_tree():
				menu = null
				_left = minf(_left, 0.0)
		elif menu_open or not hints.main._no_dialog():
			hide = true   # 世界里的提示：菜单、对话框打开时先藏着，不减时间
		if not hide:
			_left -= rdt
			age += rdt
		var want := 1.0 if _left > 0.0 and not hide else 0.0
		_a = move_toward(_a, want, rdt * (5.0 if want > 0.0 else 3.0))
		if _a <= 0.0 and _left <= 0.0:
			if visible:
				visible = false
				id = ""
			return
		mouse_filter = Control.MOUSE_FILTER_STOP if _a > 0.5 and not hide else Control.MOUSE_FILTER_IGNORE
		_layout(vs)
		position = _rect.position
		size = _rect.size
		queue_redraw()

	func _font() -> Font:
		return Feel.I.font if Feel.I != null else Game.font

	## 局内：左边中间（上面是区域名、横幅和成就，下面是血条）；菜单里：底下居中
	func _layout(vs: Vector2) -> void:
		# 提示开着时换了设备（比如第一次摸屏幕）：按键名跟着换
		var dev := ArpgInput.device(0)
		if dev != _dev:
			_dev = dev
			if HINTS.has(id):
				var tx := ArpgHints.text_of(id)
				title = String(tx[1])
				body = String(tx[2])
				_lines = []
		var w := minf(640.0, vs.x - 40.0) if menu != null else minf(420.0, vs.x * 0.4)
		if _lines.is_empty() or _w != w:
			_lines = _wrap_lines(body, w - 36.0, 16)
			_w = w
		var h := 64.0 + _lines.size() * 22.0
		if menu != null:
			var side := (vs.x - 620.0) * 0.5 - 48.0
			if menu is ArpgMenu and not menu is ArpgStatsPanel and String(menu.get("layout")) == "list" and side >= 240.0:
				# 竖排列表：贴在列表右边，不挡选项
				w = minf(side, 340.0)
				if _lines.is_empty() or _w != w:
					_lines = _wrap_lines(body, w - 36.0, 16)
					_w = w
				h = 64.0 + _lines.size() * 22.0
				_rect = Rect2(vs.x - 24.0 - w, vs.y * 0.16 + 80.0, w, h)
			else:
				_rect = Rect2((vs.x - w) * 0.5, vs.y - 66.0 - h, w, h)
		else:
			# 触屏：左上是血条面板，下面是摇杆，夹在中间
			_rect = Rect2(24.0, maxf(vs.y * (0.44 if TouchPad.active else 0.375), 262.0), w, h)

	func _wrap_lines(text: String, width: float, fs: int) -> Array:
		var f := _font()
		var out := []
		var line := ""
		for ch in text:
			var t := line + ch
			if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
				out.append(line)
				line = ch
			else:
				line = t
		if line != "":
			out.append(line)
		return out

	func _draw() -> void:
		var f := _font()
		var r := Rect2(Vector2.ZERO, _rect.size)
		var a := _a
		var accent := Color(1.0, 0.85, 0.45) if tag == "新招式" else ArpgMenu.GOLD
		draw_rect(r, Color(0.02, 0.04, 0.05, 0.86 * a))
		draw_rect(Rect2(0, 0, 4, r.size.y), Color(accent, 0.95 * a))
		draw_rect(r, Color(accent, 0.55 * a), false, 1.0)
		draw_string(f, Vector2(18, 24), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ArpgMenu.TEAL, 0.95 * a))
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(f, Vector2(30 + tw, 26), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60 - tw, 21, Color(0.97, 0.93, 0.85, a))
		for i in range(_lines.size()):
			draw_string(f, Vector2(18, 52 + i * 22), String(_lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.78, 0.87, 0.87, a))
		var foot := "点一下关闭" if TouchPad.active else "暂停菜单里可关掉或回看提示"
		draw_string(f, Vector2(0, r.size.y - 8), foot, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12, 11, Color(0.55, 0.62, 0.62, 0.8 * a))
		# 剩余时间细条
		if menu == null:
			draw_rect(Rect2(4, r.size.y - 2, (r.size.x - 4) * clampf(_left / 5.5, 0.0, 1.0), 2), Color(accent, 0.5 * a))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _left > 0.0:
			accept_event()
			close()
