class_name Npc
extends Node2D
## 不打架的人：行脚商人、破庙的老和尚、拾骨婆，奇遇里的受伤浪人、赌客、隐士。玩家走近时说一句话。
## 破庙的人说什么随轮回变化（见 Story.NPC_LINES）。

var main: Node
var npc_name := ""
var lines: Array = []       # 走近时轮流说
var look := Puppet.Look.new()
var pack := ""              # merchant 背货架 / monk 拿念珠 / granny 拄拐、腰上挂骨头 / ronin_w 跪坐捂伤 / gambler 蹲着摇骰 / hermit 盘坐
var facing := -1
var time := 0.0
var _said := 0
var _near := false


func setup(kind: String) -> void:
	Player._build_poses()
	pack = kind
	look.saya = false
	look.sword_len = 0.0
	if kind == "merchant":
		npc_name = "行脚商人"
		lines = ["客官，路上不太平，买点东西防身？", "铜钱留着也带不回去，不如花了。", "前面河边那位……我劝你别去。"]
		look.hat = true
		look.hat_color = Color("a8905a")
		look.hat_dark = Color("6e5a36")
		look.cloth = Color("5a4a3a")
		look.cloth_dark = Color("3a3026")
		look.cloth_light = Color("7a6a52")
		look.pants = Color("3a3a42")
		look.pants_dark = Color("26262c")
		look.pants_light = Color("50505a")
		look.belt = Color("8a6a3a")
		look.band = Color("5a4a3a")
	elif kind == "granny":
		npc_name = "拾骨婆"
		lines = ["死在山上的人，骨头里还留着本事。拿魂玉来换。", "点错了不要紧，洗一洗，重新来。", "修罗、不动、行者……三条路，走哪条都是回家。"]
		look.hat = false
		look.cloth = Color("3a2e44")
		look.cloth_dark = Color("241c2c")
		look.cloth_light = Color("56466a")
		look.collar = Color("b8ab96")
		look.pants = Color("2a2430")
		look.pants_dark = Color("1a1620")
		look.pants_light = Color("3a3444")
		look.hair = Color("d8d4cc")      # 白头发
		look.band = Color("8a7a9a")
		look.belt = Color("6a5a3a")
		look.skin = Color("d8a888")
		look.skin_dark = Color("a8785e")
		lines = Story.npc_lines("granny", lines)
	elif kind == "ronin_w":
		npc_name = "受伤的浪人"
		look.cloth = Color("4a3a4a")
		look.cloth_dark = Color("2e242e")
		look.cloth_light = Color("6a566a")
		look.band = Color("8a2a2a")
		look.saya = true
		look.sword_len = 22.0
	elif kind == "gambler":
		npc_name = "赌客"
		look.hat = true
		look.hat_color = Color("4a4a3a")
		look.hat_dark = Color("2e2e24")
		look.cloth = Color("6a3a2a")
		look.cloth_dark = Color("4a261a")
		look.cloth_light = Color("8a5a3a")
		look.band = Color("c9a24a")
	elif kind == "hermit":
		npc_name = "隐士"
		look.cloth = Color("6a6a5a")
		look.cloth_dark = Color("4a4a3e")
		look.cloth_light = Color("8a8a76")
		look.hair = Color("d8d4cc")
		look.band = Color("d8d4cc")
		look.belt = Color("5a4a3a")
	else:
		npc_name = "老僧"
		lines = ["回来了就好。魂玉供在台上，下次能走得更远。", "那把刀在河对岸。柳施主守了它二十年。", "死不可怕，怕的是忘了为什么出发。"]
		look.hat = false
		look.cloth = Color("8a5a2a")
		look.cloth_dark = Color("5a3a1a")
		look.cloth_light = Color("b07a3a")
		look.collar = Color("d8c8a0")
		look.pants = Color("5a3a1a")
		look.pants_dark = Color("3a2410")
		look.pants_light = Color("7a5228")
		look.hair = Color("d8a888")      # 光头
		look.band = Color("d8a888")
		look.belt = Color("c9a24a")
		lines = Story.npc_lines("monk", lines)


func _process(delta: float) -> void:
	time += delta
	var p: Player = main.nearest_player(global_position) if main != null else null
	var near := p != null and absf(p.global_position.x - global_position.x) < 90.0
	if p != null and absf(p.global_position.x - global_position.x) < 200.0:
		facing = 1 if p.global_position.x > global_position.x else -1
	if near and not _near and not lines.is_empty():
		main.hud.say(npc_name, lines[_said % lines.size()], 3.0)
		_said += 1
	_near = near
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if pack == "merchant":
		# 背后的货架：木框、布包、挂着的小葫芦
		var bx := -facing * 9.0
		draw_rect(Rect2(bx - 9, -58, 18, 40), Color("0c080a"))
		draw_rect(Rect2(bx - 8, -57, 16, 38), Color("4a3024"))
		draw_rect(Rect2(bx - 8, -57, 16, 1), Color("8a5a3a"))
		for k in range(3):
			draw_rect(Rect2(bx - 7, -54 + k * 12, 14, 10), [Color("6a3a3a"), Color("3a4a5a"), Color("5a5a3a")][k])
		draw_circle(Vector2(bx + facing * -10.0, -40), 3, Color("a5402f"))
	var p := Puppet.breathe(Player.POSES["relaxed"], time, 0.8)
	if pack == "monk":
		p = Puppet.breathe(Player.POSES["drink"], time * 0.5, 0.4)
	elif pack == "ronin_w":
		p = Puppet.breathe(Player.POSES["kneel"], time * 0.6, 0.6)
	elif pack == "hermit":
		p = Puppet.breathe(Player.POSES["kneel"], time * 0.3, 0.3).duplicate()
		p["lean"] = 0.0
		p["head"] = 0.1
	elif pack == "gambler":
		p = p.duplicate()
		p["crouch"] = 6.0
		p["arm_f"] = Vector2(0.4 + 0.25 * sin(time * 9.0), 0.9)   # 摇骰子
	elif pack == "granny":
		# 弯着腰
		p = p.duplicate()
		p["lean"] = 0.45
		p["crouch"] = 1.15
	if pack == "granny":
		# 拐杖和腰上挂的一串骨头、背后的骨灯笼
		var sx := facing * 12.0
		draw_line(Vector2(sx, 0), Vector2(sx + facing * 1.0, -34), Color("0c080a"), 3.0)
		draw_line(Vector2(sx, 0), Vector2(sx + facing * 1.0, -34), Color("6a4a2a"), 1.0)
		var lx := -facing * 12.0
		draw_line(Vector2(lx, -50), Vector2(lx, -40), Color("6a4a2a"), 1.0)
		var glow := 0.7 + 0.3 * sin(time * 2.0)
		for k in range(3):
			draw_circle(Vector2(lx, -36), 5.0 + k * 4.0, Color(0.4, 1.0, 0.75, 0.05 * glow))
		draw_rect(Rect2(lx - 3, -40, 6, 7), Color("0c080a"))
		draw_rect(Rect2(lx - 2, -39, 4, 5), Color(0.5, 1.0, 0.8, glow))
	Puppet.draw_lit(self, p, look, facing, Color(0.9, 0.6, 0.4, 0.4))
	if pack == "granny":
		for k in range(3):
			draw_rect(Rect2(Vector2(facing * (2 - k * 3), -22 + (k % 2)), Vector2(2, 4)), Color("e0d8c0"))
	if pack == "monk":
		# 念珠
		for k in range(6):
			draw_rect(Rect2(Vector2(facing * (4 + k % 3), -36 + k * 2), Vector2(1, 1)), Color("3a1a14"))
	var font: Font = Game.font
	var w := font.get_string_size(npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var at := Vector2(-w / 2.0, -72).round()
	draw_string_outline(font, at, npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 2, Color(0, 0, 0, 0.8))
	draw_string(font, at, npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.7, 0.8))
