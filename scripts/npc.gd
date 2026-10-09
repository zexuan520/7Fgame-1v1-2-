class_name Npc
extends Node2D
## 不打架的人：行脚商人、破庙的老和尚。玩家走近时说一句话。

var main: Node
var npc_name := ""
var lines: Array = []       # 走近时轮流说
var look := Puppet.Look.new()
var pack := ""              # merchant 背货架 / monk 拿念珠
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
	Puppet.draw_lit(self, p, look, facing, Color(0.9, 0.6, 0.4, 0.4))
	if pack == "monk":
		# 念珠
		for k in range(6):
			draw_rect(Rect2(Vector2(facing * (4 + k % 3), -36 + k * 2), Vector2(1, 1)), Color("3a1a14"))
	var font: Font = Game.font
	var w := font.get_string_size(npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var at := Vector2(-w / 2.0, -72).round()
	draw_string_outline(font, at, npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 2, Color(0, 0, 0, 0.8))
	draw_string(font, at, npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.7, 0.8))
