class_name Hud
extends Node2D
## 屏幕界面：左上角玩家状态（下面一排招式格子、一排心法）和铜钱魂玉，顶上的小地图，底部敌人名字和血条，
## Tab 打开的整张地图、装备、招式心法，按 H 打开的操作说明，清房三选一，招式谱，死亡结算，换房间的黑屏。

const GOLD := Color("c9a24a")
const GOLD_DARK := Color("6b5426")
const FRAME := Color("0c0a12")

const HELP := [
	["1P", "A/D 移动  W/空格 跳  S 下  J 攻击(长按重击)  K 格挡/弹反  L/Shift 闪身  U 药罐  I 招式  O 换架势"],
	["2P", "←/→ 移动  ↑ 跳  ↓ 下  小键盘1 攻击 2 格挡 3 闪身 4 药罐 5 招式 6 换架势"],
	["连招", "连按攻击五连  下+攻击 升龙斩  空中攻击 空中斩  空中下+攻击 落雷斩  闪身中攻击 闪身突刺"],
	["招式", "招式键单按 / 按住←→ / 按住↓ 放三格招式，耗刃意  清完战斗、精英房三选一"],
	["手柄", "A 跳  X 攻击  RB 格挡  B 闪身  Y 药罐  LB 招式  十字键上 换架势"],
	["闯关", "站在门、货物、香炉、装备前按 下 互动  Tab 地图/装备  清完敌人出口才开"],
	["其他", "F2 2P 加入/退出  F1 低难度  F3 判定框  F4 练武场  F5 破庙里魂玉+50（调试）  Esc 退出"],
]

var main: Node
var show_help := false
var _toast := ""
var _toast_time := 0.0
var _trail := {}            # 血条掉血时的白色残影
var _time := 0.0
var _line_who := ""         # 字幕：说话的人和内容
var _line := ""
var _line_time := 0.0
var _title := ""            # 头目登场的大字
var _title_sub := ""
var _title_time := 0.0

const TITLE_TIME := 2.6
const BANNER_TIME := 2.8

var show_map := false
var show_gear := false      # Tab：身上的装备
var show_build := false     # Tab：这一局的招式和心法
var menu_flash := 0.0       # 天赋界面：刚点亮一个节点时闪一下
var menu_note := ""         # 天赋界面：点不了的原因
var menu_note_time := 0.0
var fade := 0.0             # 换房间时的黑屏
var _banner := ""           # 进房间时顶上的房间名
var _banner_sub := ""
var _banner_time := 0.0
var _bump := {"coin": 0.0, "jade": 0.0}
var _death: Run = null      # 结算画面显示的那一局
var _death_time := 0.0


func room_banner(title: String, sub: String) -> void:
	_banner = title
	_banner_sub = sub
	_banner_time = BANNER_TIME


## 铜钱、魂玉数字跳一下
func bump(kind: String) -> void:
	_bump[kind] = 0.25


func show_death(run: Run) -> void:
	_death = run
	_death_time = 0.0


func hide_death() -> void:
	_death = null


## 屏幕下方字幕
func say(who: String, text: String, time: float = 2.4) -> void:
	_line_who = who
	_line = text
	_line_time = time


func title_card(title: String, sub: String) -> void:
	_title = title
	_title_sub = sub
	_title_time = TITLE_TIME


func clear_lines() -> void:
	_line_time = 0.0
	_title_time = 0.0


func toast(text: String) -> void:
	_toast = text
	_toast_time = 1.6


func _process(delta: float) -> void:
	_time += delta
	_toast_time = maxf(0.0, _toast_time - delta)
	_line_time = maxf(0.0, _line_time - delta)
	_title_time = maxf(0.0, _title_time - delta)
	_banner_time = maxf(0.0, _banner_time - delta)
	menu_flash = maxf(0.0, menu_flash - delta)
	menu_note_time = maxf(0.0, menu_note_time - delta)
	_death_time += delta
	for k: String in _bump:
		_bump[k] = maxf(0.0, float(_bump[k]) - delta)
	queue_redraw()


func _draw() -> void:
	var font: Font = Game.font
	for p: Player in main.get_players():
		var at := Vector2(10, 10) if p.index == 1 else Vector2(640 - 10 - 168, 10)
		_draw_player_panel(font, p, at)
	if not main.has_player(2):
		_text(font, "2P 按 F2 加入", Vector2(640 - 10, 22), Color(0.75, 0.72, 0.8, 0.55), 12, true)

	# 底部血条只给精英和头目（杂兵头顶有小血条）
	for e: Enemy in main.get_enemies():
		if e.visible and e.state != Enemy.S.DEAD and e.state != Enemy.S.INTRO and not e.is_grunt():
			_draw_boss_bar(font, e)
			break

	_draw_purse(font)
	if Game.run != null and main.mode == "room":
		_draw_minimap(font)
	if _banner_time > 0.0:
		var t := BANNER_TIME - _banner_time
		var ba := clampf(t / 0.3, 0.0, 1.0) * clampf(_banner_time / 0.5, 0.0, 1.0)
		_text_centered(font, _banner, Vector2(320, 52), Color(0.98, 0.94, 0.85, ba), 24)
		_text_centered(font, _banner_sub, Vector2(320, 66), Color(GOLD, ba), 12)
	if _title_time > 0.0:
		_draw_title(font)
	if _line_time > 0.0:
		var la := clampf(_line_time / 0.3, 0.0, 1.0) * clampf((_line_time) * 4.0, 0.0, 1.0)
		var w := font.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var at := Vector2(320 - w / 2.0, 104)
		draw_rect(Rect2(at + Vector2(-10, -13), Vector2(w + 20, 18)), Color(0, 0, 0, 0.55 * la))
		_text(font, _line_who, at + Vector2(0, -16), Color(GOLD, la), 12)
		_text(font, _line, at, Color(0.95, 0.93, 0.9, la), 12)

	if _toast_time > 0.0:
		var a := clampf(_toast_time / 0.4, 0.0, 1.0)
		_text_centered(font, _toast, Vector2(320, 70), Color(1, 0.95, 0.8, a), 12)

	for idx: int in main.focus_gear:
		var it: Interactable = main.focus_gear[idx]
		for p: Player in main.get_players():
			if p.index == idx and is_instance_valid(it):
				_draw_gear_card(font, it, p)
	if show_map and Game.run != null:
		_draw_map(font)
	if show_gear:
		_draw_gear_screen(font)
	if show_build:
		_draw_build_screen(font)
	if main.menu_player != null:
		_draw_talents(font)
	if main.codex_player != null:
		_draw_codex(font)
	if main.event_player != null and is_instance_valid(main.event_it):
		_draw_event(font)
	if main.memory_player != null:
		_draw_memories(font)
	if not main.rewards.is_empty():
		_draw_rewards(font)
	if show_help:
		_draw_help(font)
	else:
		var hint := "H 操作说明" + ("  Tab 地图/装备/招式" if Game.run != null else "  Tab 装备/招式")
		_text(font, hint, Vector2(640 - 8, 354), Color(0.8, 0.78, 0.85, 0.45), 12, true)
	if _death != null:
		_draw_death(font)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.01, 0.03, fade))


func _frame(r: Rect2) -> void:
	# 深色底 + 金色细边 + 四角装饰
	draw_rect(r.grow(2), FRAME)
	draw_rect(r.grow(1), GOLD_DARK, false, 1.0)
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), GOLD)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), FRAME)


func _bar(r: Rect2, ratio: float, col: Color, trail_key: String) -> void:
	draw_rect(r, Color("1a1018"))
	ratio = clampf(ratio, 0.0, 1.0)
	# 掉血残影
	var trail: float = _trail.get(trail_key, ratio)
	trail = maxf(ratio, lerpf(trail, ratio, 0.05))
	_trail[trail_key] = trail
	draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * trail), r.size.y)), Color(1, 0.95, 0.85, 0.85))
	var w := roundf(r.size.x * ratio)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(w, 1)), col.lightened(0.4))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(w, 1)), col.darkened(0.35))


func _posture(r: Rect2, ratio: float) -> void:
	draw_rect(r, Color("140e0e"))
	ratio = clampf(ratio, 0.0, 1.0)
	var hw := roundf(r.size.x / 2.0 * ratio)
	var cx := r.position.x + roundf(r.size.x / 2.0)
	var col := Color(1.0, 0.72, 0.2).lerp(Color(1.0, 0.22, 0.08), clampf((ratio - 0.5) * 2.0, 0.0, 1.0))
	if ratio > 0.8:
		col = col.lerp(Color(1, 1, 1), 0.25 + 0.25 * sin(_time * 18.0))
	draw_rect(Rect2(cx - hw, r.position.y, hw * 2, r.size.y), col)
	draw_rect(Rect2(cx - hw, r.position.y, hw * 2, 1), col.lightened(0.4))
	draw_rect(Rect2(cx, r.position.y - 1, 1, r.size.y + 2), GOLD)


var _art_cost := 40.0


func _will(r: Rect2, ratio: float, ready: bool) -> void:
	draw_rect(r, Color("10141a"))
	var col := Color(0.55, 0.85, 1.0) if not ready else Color(1.0, 0.85, 0.4).lerp(Color(1, 1, 1), 0.2 + 0.2 * sin(_time * 8.0))
	var w := roundf(r.size.x * clampf(ratio, 0.0, 1.0))
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(w, 1)), col.lightened(0.4))
	# 每 40 一格的刻度
	var step := r.size.x * _art_cost / Player.MAX_WILL
	var x := step
	while x < r.size.x - 1.0:
		draw_rect(Rect2(r.position.x + roundf(x), r.position.y, 1, r.size.y), FRAME)
		x += step


func _gourd(c: Vector2, full: bool) -> void:
	var body := Color("a5402f") if full else Color("3a3040")
	draw_circle(c + Vector2(0, 1), 3.5, FRAME)
	draw_circle(c + Vector2(0, -3), 2.5, FRAME)
	draw_circle(c + Vector2(0, 1), 2.5, body)
	draw_circle(c + Vector2(0, -3), 1.5, body)
	if full:
		draw_rect(Rect2(c + Vector2(-1, 0), Vector2(1, 1)), Color("e08a6a"))
	draw_rect(Rect2(c + Vector2(-2, -1), Vector2(4, 1)), GOLD_DARK)


func _draw_player_panel(font: Font, p: Player, at: Vector2) -> void:
	# 头像框
	var face := Rect2(at, Vector2(26, 26))
	_frame(face)
	draw_rect(face, Color("221a2e"))
	var head := face.get_center() + Vector2(0, 3)
	draw_circle(head, 8, p.look.hair)
	draw_circle(head + Vector2(2, 2), 6, p.look.skin)
	draw_line(head + Vector2(-8, -2), head + Vector2(8, -3), p.look.band, 2.0)
	draw_rect(Rect2(head + Vector2(4, 0), Vector2(1, 2)), Color.BLACK)
	if p.state == Player.S.DEAD:
		draw_rect(face, Color(0, 0, 0, 0.6))
	_text(font, "%dP" % p.index, at + Vector2(1, 38), p.color.lightened(0.3), 12)

	# 生命条
	var hp_r := Rect2(at + Vector2(32, 3), Vector2(130, 8))
	_frame(hp_r)
	_bar(hp_r, p.hp / p.max_hp, Color("b8262c"), "p%d" % p.index)
	# 架势条
	var po_r := Rect2(at + Vector2(32, 16), Vector2(130, 4))
	_frame(po_r)
	_posture(po_r, p.posture / p.max_posture)
	# 刃意：攒满一格（40）可以放一次回旋斩
	var wi_r := Rect2(at + Vector2(32, 24), Vector2(130, 3))
	_frame(wi_r)
	_art_cost = p.art_cost()
	_will(wi_r, p.will / Player.MAX_WILL, p.will >= _art_cost)
	# 药罐
	for i in range(p.max_gourds):
		_gourd(at + Vector2(140 + i * 9, 36), i < p.gourds)
	# 弹反次数
	_text(font, "弹反 × %d" % p.parry_count, at + Vector2(32, 40), Color(0.95, 0.85, 0.55), 12)
	# 当前架势
	_text(font, "架势 · " + str(p.stance()["name"]), at + Vector2(32, 54), Color(0.8, 0.86, 1.0), 12)
	var wpn: Dictionary = p.gear["weapon"]
	_text(font, GearData.display_name(wpn), at + Vector2(32, 68), GearData.color(wpn), 12)
	if p.revives > 0:
		_text(font, "不死身 ×%d" % p.revives, at + Vector2(110, 68), Color(1.0, 0.85, 0.4), 12)
	if p.state == Player.S.DEAD:
		var msg := "%.0f 秒后复活" % maxf(p.respawn_timer, 0.0) if p.auto_respawn else "清完这间复苏"
		if p.downed > 0.0:
			msg = "濒死 · 同伴按住↓扶"
		_text(font, msg, at + Vector2(110, 54), Color(1, 0.4, 0.4), 12)
	_draw_build_strip(font, p, at + Vector2(0, 76))


## 面板下面：三个招式格子（单按 / ←→ / ↓），刃意够放的那格亮起来；再下面一排心法
func _draw_build_strip(font: Font, p: Player, at: Vector2) -> void:
	var slots: Array = p.build["arts"]
	for i in range(slots.size()):
		var r := Rect2(at + Vector2(i * 57, 0), Vector2(54, 14))
		draw_rect(r, Color(0.05, 0.04, 0.08, 0.85))
		var s: Variant = slots[i]
		if s == null:
			draw_rect(r, Color(0.3, 0.28, 0.34, 0.6), false, 1.0)
			_slot_glyph(r.position + Vector2(5, 7), i, Color(0.4, 0.38, 0.44))
			continue
		var a: Dictionary = Arts.ARTS[s["id"]]
		var col: Color = Arts.SCHOOL_COLORS[a["school"]]
		var ready := p.will >= p.art_cost(Arts.art(s["id"], int(s["lv"])))
		if ready:
			draw_rect(r, Color(col, 0.22 + 0.08 * sin(_time * 6.0)))
		draw_rect(r, col if ready else col.darkened(0.45), false, 1.0)
		_slot_glyph(r.position + Vector2(5, 7), i, col if ready else Color(0.6, 0.58, 0.62))
		_text(font, a["short"], r.position + Vector2(10, 11), Color(0.95, 0.92, 0.88) if ready else Color(0.7, 0.68, 0.72), 12)
		for k in range(Arts.max_level(s["id"])):
			draw_rect(Rect2(r.position.x + 49, r.position.y + 2 + k * 4, 3, 3), col if k < int(s["lv"]) else Color(0.25, 0.23, 0.28))
	var minds: Array = p.build["minds"]
	for i in range(Arts.MAX_MINDS):
		var r := Rect2(at + Vector2(i * 42, 17), Vector2(40, 13))
		if i >= minds.size():
			draw_rect(r, Color(0.3, 0.28, 0.34, 0.35), false, 1.0)
			continue
		var m: Dictionary = Arts.MINDS[minds[i]]
		var col: Color = Arts.SCHOOL_COLORS[m["school"]]
		draw_rect(r, Color(col.darkened(0.6), 0.85))
		draw_rect(r, col.darkened(0.2), false, 1.0)
		_text_centered(font, m["short"], r.position + Vector2(20, 11), Color(0.95, 0.92, 0.88), 12)


## 招式格子左边的小记号：单按一个点、←→ 一根横线带两个尖、↓ 一个往下的三角
func _slot_glyph(c: Vector2, slot: int, col: Color) -> void:
	match slot:
		0:
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), col)
		1:
			draw_rect(Rect2(c + Vector2(-3, 0), Vector2(7, 1)), col)
			draw_rect(Rect2(c + Vector2(-3, -1), Vector2(1, 3)), col)
			draw_rect(Rect2(c + Vector2(3, -1), Vector2(1, 3)), col)
		2:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -2), c + Vector2(4, -2), c + Vector2(0.5, 3)]), col)


## 头目登场：名字大字，上下两道金线从中间展开
func _draw_title(font: Font) -> void:
	var t := TITLE_TIME - _title_time
	var a := clampf(t / 0.4, 0.0, 1.0) * clampf(_title_time / 0.6, 0.0, 1.0)
	var spread := clampf(t / 0.5, 0.0, 1.0)
	var c := Vector2(320, 150)
	draw_rect(Rect2(0, c.y - 38, 640, 60), Color(0, 0, 0, 0.45 * a))
	var hw := 150.0 * spread
	draw_rect(Rect2(c.x - hw, c.y - 32, hw * 2.0, 1), Color(GOLD, a))
	draw_rect(Rect2(c.x - hw, c.y + 16, hw * 2.0, 1), Color(GOLD, a))
	_text_centered(font, _title_sub, c + Vector2(0, -14), Color(0.8, 0.78, 0.85, a), 12)
	_text_centered(font, _title, c + Vector2(0, 10), Color(0.95, 0.97, 1.0, a), 24)


func _draw_boss_bar(font: Font, e: Enemy) -> void:
	var r := Rect2(160, 330, 320, 7)
	_text_centered(font, e.display_name(), Vector2(320, 322), Color(0.92, 0.86, 0.78), 12)
	# 剩余血管
	var total: int = (e.data["phases"] as Array).size()
	var w := font.get_string_size(e.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	for i in range(total):
		var c := Vector2(320 + w / 2.0 + 10 + i * 9, 316)
		draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), FRAME)
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color("c42a2a") if i < e.lives else Color("3a3040"))
	_frame(r)
	_bar(r, e.hp / e.max_hp, Color("9e1c24"), "boss")
	var po := Rect2(200, 342, 240, 3)
	_frame(po)
	_posture(po, e.posture / e.max_posture)


func _draw_help(font: Font) -> void:
	var r := Rect2(24, 202, 592, 122)
	_frame(r)
	draw_rect(r, Color(0.05, 0.04, 0.08, 0.92))
	for i in range(HELP.size()):
		var row: Array = HELP[i]
		var y := r.position.y + 16 + i * 16
		_text(font, row[0], Vector2(r.position.x + 10, y), GOLD, 12)
		_text(font, row[1], Vector2(r.position.x + 48, y), Color(0.9, 0.88, 0.92), 12)
	_text(font, "H 关闭", Vector2(r.end.x - 6, r.position.y - 6), Color(0.8, 0.78, 0.85, 0.6), 12, true)


func _text(font: Font, s: String, pos: Vector2, col: Color, size: int, right_align: bool = false) -> void:
	var at := pos
	if right_align:
		at.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	at = at.round()
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, col.a * 0.9))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_centered(font: Font, s: String, pos: Vector2, col: Color, size: int) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(font, s, pos - Vector2(w / 2.0, 0), col, size)


# ---------- 铜钱、魂玉 ----------

func _draw_purse(font: Font) -> void:
	var at := Vector2(14, 128)
	if Game.run != null and main.mode == "room":
		_purse_row(font, "coin", Game.run.coins, at)
		_purse_row(font, "jade", Game.run.jade, at + Vector2(0, 14))
	elif main.mode == "hub":
		_purse_row(font, "jade", int(Game.save["jade"]), at)
		_text(font, "（已存）", at + Vector2(46, 4), Color(0.75, 0.72, 0.8, 0.7), 12)


func _purse_row(font: Font, kind: String, value: int, at: Vector2) -> void:
	var b: float = _bump[kind]
	var s := 1.0 + b * 1.2
	draw_set_transform(at, 0.0, Vector2(s, s))
	Icons.draw(self, kind, Vector2.ZERO, Color(1, 1, 1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var col := Color("e0a860") if kind == "coin" else Color("7ee8c0")
	if b > 0.0:
		col = col.lerp(Color(1, 1, 1), 0.6)
	_text(font, str(value), at + Vector2(9, 4 - roundf(b * 8.0)), col, 12)


# ---------- 地图 ----------

## 顶上一排小格子：每列一个，走过的实心，现在的那格闪
func _draw_minimap(_font: Font) -> void:
	var r: Run = Game.run
	var n := r.rows.size()
	var step := 20.0
	var x0 := 320.0 - (n - 1) * step / 2.0
	var y := 16.0
	draw_rect(Rect2(x0 - 12, y - 9, (n - 1) * step + 24, 18), Color(0, 0, 0, 0.35))
	for i in range(n):
		var c := Vector2(x0 + i * step, y)
		if i < n - 1:
			draw_rect(Rect2(c.x + 5, c.y, step - 10, 1), Color(0.6, 0.55, 0.5, 0.5 if i >= r.row else 0.9))
		var nd: Dictionary = r.rows[i][r.col] if i == r.row else _visited_in(r, i)
		var icon_type: String = nd["type"] if not nd.is_empty() else ""
		var col: Color = LevelData.NODE_TYPES[icon_type]["color"] if icon_type != "" else Color(0.5, 0.48, 0.52)
		if i == r.row:
			var pulse := 0.6 + 0.4 * sin(_time * 6.0)
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), Color(col, 0.35 * pulse))
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), Color(col, pulse), false, 1.0)
			Icons.draw(self, icon_type, c, col)
		elif i < r.row:
			Icons.draw(self, icon_type, c, col.darkened(0.25))
		else:
			# 还没走到：最后一格是头目，其余是问号点
			if i == n - 1:
				Icons.draw(self, "boss", c, Color(LevelData.NODE_TYPES["boss"]["color"], 0.8))
			else:
				draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), Color(0.7, 0.66, 0.6, 0.6))


func _visited_in(r: Run, i: int) -> Dictionary:
	for nd: Dictionary in r.rows[i]:
		if nd["visited"]:
			return nd
	return {}


## Tab：整张地图，从左往右走，每列的房间竖着排，线是能走的路
func _draw_map(font: Font) -> void:
	var r: Run = Game.run
	var box := Rect2(40, 40, 560, 270)
	draw_rect(box, Color(0.04, 0.03, 0.06, 0.94))
	_frame(box)
	var fd := r.floor_data()
	_text_centered(font, "%s · %s" % [fd["sub"], fd["name"]], Vector2(320, 60), Color(0.95, 0.9, 0.8), 12)
	var n := r.rows.size()
	var area := Rect2(72, 82, 496, 180)
	var pos := func(i: int, j: int) -> Vector2:
		var m: int = r.rows[i].size()
		var x := area.position.x + area.size.x * i / float(n - 1)
		var yy := area.position.y + area.size.y * (0.5 if m == 1 else j / float(m - 1))
		return Vector2(x, yy).round()
	# 路
	for i in range(n - 1):
		for j in range(r.rows[i].size()):
			var nd: Dictionary = r.rows[i][j]
			for k: int in nd["next"]:
				var taken: bool = nd["visited"] and r.rows[i + 1][k]["visited"]
				var avail := i == r.row and j == r.col
				var col := Color(0.95, 0.85, 0.55) if taken else (Color(0.9, 0.8, 0.6, 0.85) if avail else Color(0.5, 0.46, 0.5, 0.5))
				_dashed(pos.call(i, j), pos.call(i + 1, k), col, taken or avail)
	# 房间
	for i in range(n):
		for j in range(r.rows[i].size()):
			var nd: Dictionary = r.rows[i][j]
			var c: Vector2 = pos.call(i, j)
			var col: Color = LevelData.NODE_TYPES[nd["type"]]["color"]
			var here := i == r.row and j == r.col
			var reachable := i == r.row + 1 and (r.node()["next"] as Array).has(j)
			draw_circle(c, 9, Color(0.02, 0.02, 0.03))
			draw_circle(c, 8, Color(col, 0.25 if nd["visited"] or here else 0.1))
			if here:
				draw_arc(c, 10.0 + sin(_time * 6.0), 0, TAU, 20, Color(1, 0.95, 0.75), 1.0)
			elif reachable:
				draw_arc(c, 10.0, 0, TAU, 20, Color(col, 0.6 + 0.3 * sin(_time * 4.0)), 1.0)
			Icons.draw(self, nd["type"], c, col if (nd["visited"] or here or reachable or i > r.row) else col.darkened(0.4))
	# 图例
	var lx := 70.0
	for t: String in ["fight", "elite", "shop", "rest", "boss"]:
		var spec: Dictionary = LevelData.NODE_TYPES[t]
		Icons.draw(self, t, Vector2(lx, 290), spec["color"])
		_text(font, spec["label"], Vector2(lx + 10, 294), Color(0.85, 0.82, 0.8), 12)
		lx += 70.0
	_text(font, "Tab 关闭", Vector2(590, 294), Color(0.75, 0.72, 0.8, 0.7), 12, true)


func _dashed(a: Vector2, b: Vector2, col: Color, solid: bool) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var d := 10.0
	while d < len - 10.0:
		var e := minf(d + (6.0 if not solid else 4.0), len - 10.0)
		draw_line(a + dir * d, a + dir * e, col, 1.0)
		d += 6.0 if solid else 9.0


# ---------- 死亡结算 ----------

func _draw_death(font: Font) -> void:
	var t := _death_time
	var a := clampf(t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.0, 0.01, 0.72 * a))
	var c := Vector2(320, 130)
	var spread := clampf(t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(c.x - 170 * spread, c.y - 34, 340 * spread, 1), Color(0.75, 0.15, 0.12, a))
	draw_rect(Rect2(c.x - 170 * spread, c.y + 12, 340 * spread, 1), Color(0.75, 0.15, 0.12, a))
	_text_centered(font, "身 死", c + Vector2(0, 4), Color(0.9, 0.18, 0.15, a), 36)
	var r := _death
	var kept := int(floor(r.jade * main.death_keep()))
	var la := clampf((t - 0.7) / 0.4, 0.0, 1.0)
	var lines := [
		["走到", "第 %d / %d 间 · %s" % [r.row + 1, r.rows.size(), LevelData.room(r.room_key())["name"]]],
		["斩敌", "%d" % r.kills],
		["魂玉", "%d → 带回 %d（%d%%）" % [r.jade, kept, roundi(main.death_keep() * 100.0)]],
		["铜钱", "%d · 散落" % r.coins],
	]
	for i in range(lines.size()):
		var y := 178.0 + i * 16.0
		_text(font, lines[i][0], Vector2(252, y), Color(GOLD, la), 12)
		_text(font, lines[i][1], Vector2(292, y), Color(0.92, 0.9, 0.88, la), 12)
	if t > 1.4:
		var blink := 0.55 + 0.45 * sin(t * 4.0)
		_text_centered(font, "按 攻击 回破庙", Vector2(320, 260), Color(1, 0.95, 0.8, blink), 12)


# ---------- 装备 ----------

## 按宽度折行（中文按字断）
func _wrap(font: Font, s: String, width: float) -> Array:
	var out := []
	var line := ""
	for ch in s:
		if font.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > width and line != "":
			out.append(line)
			line = ch.strip_edges(true, false) if ch == " " else ch
		else:
			line += ch
	if line != "":
		out.append(line)
	return out


## 站在地上的装备跟前：新的和身上那件对比
func _draw_gear_card(font: Font, it: Interactable, p: Player) -> void:
	var item: Dictionary = it.data["item"]
	var w := 262.0
	# 卡片放在人物的另一边，不挡住人和地上的东西
	var sx: float = p.global_position.x - (main.camera.position.x - 320.0)
	var x := 640.0 - 14.0 - w if sx < 320.0 else 14.0
	var slot := GearData.target_slot(p.gear, item)
	var cur: Variant = p.gear[slot]
	var rows := []   # [文字, 颜色]
	var q := GearData.quality(item)
	rows.append([GearData.display_name(item), GearData.color(item), 0.0])
	rows.append(["%s · %s" % [q["name"], GearData.SLOT_NAMES[item["slot"]]], Color(0.75, 0.72, 0.78), 0.0])
	for l: String in GearData.describe(item):
		for wl: String in _wrap(font, l, w - 20.0):
			rows.append([wl, Color(0.93, 0.9, 0.86), 0.0])
	rows.append(["", Color.WHITE, 4.0])
	if cur == null:
		rows.append(["身上：空着", Color(0.65, 0.62, 0.68), 0.0])
	else:
		rows.append(["换下：" + GearData.display_name(cur) + " · " + String(GearData.quality(cur)["name"]), Color(GearData.color(cur), 0.8), 0.0])
		for l: String in GearData.describe(cur):
			for wl: String in _wrap(font, l, w - 20.0):
				rows.append([wl, Color(0.62, 0.6, 0.65), 0.0])
	var h := 10.0
	for r: Array in rows:
		h += 13.0 + float(r[2])
	var box := Rect2(x, 300.0 - h - 30.0, w, h)
	draw_rect(box, Color(0.04, 0.03, 0.06, 0.92))
	_frame(box)
	draw_rect(Rect2(box.position, Vector2(3, box.size.y)), GearData.color(item))
	var y := box.position.y + 14.0
	for r: Array in rows:
		if r[0] != "":
			_text(font, r[0], Vector2(box.position.x + 10, y), r[1], 12)
		elif float(r[2]) > 0.0:
			draw_rect(Rect2(box.position.x + 10, y - 6, w - 20, 1), Color(GOLD_DARK, 0.8))
		y += 13.0 + float(r[2])


## Tab：身上的五件装备和汇总数值
func _draw_gear_screen(font: Font) -> void:
	var ps: Array = main.get_players()
	var box := Rect2(30, 30, 580, 290)
	draw_rect(box, Color(0.04, 0.03, 0.06, 0.95))
	_frame(box)
	_text_centered(font, "身上的装备", Vector2(320, 48), Color(0.95, 0.9, 0.8), 12)
	var col_w := box.size.x / float(ps.size())
	for i in range(ps.size()):
		var p: Player = ps[i]
		var x := box.position.x + 12.0 + i * col_w
		var y := 66.0
		if ps.size() > 1:
			_text(font, "%dP" % p.index, Vector2(x, y), p.color.lightened(0.3), 12)
			y += 14.0
		for slot: String in GearData.SLOTS:
			var item: Variant = p.gear[slot]
			Icons.draw(self, Icons.gear_icon(item) if item != null else "", Vector2(x + 7, y - 4), GearData.color(item) if item != null else Color(0.3, 0.28, 0.32))
			if item == null:
				_text(font, GearData.SLOT_NAMES[slot] + " · 空", Vector2(x + 20, y), Color(0.5, 0.48, 0.52), 12)
				y += 18.0
				continue
			_text(font, "%s  %s" % [GearData.display_name(item), GearData.quality(item)["name"]], Vector2(x + 20, y), GearData.color(item), 12)
			y += 13.0
			var lines := GearData.describe(item)
			for l: String in lines:
				for wl: String in _wrap(font, l, col_w - 40.0):
					_text(font, wl, Vector2(x + 20, y), Color(0.78, 0.76, 0.8), 12)
					y += 12.0
			y += 5.0
		var st: Dictionary = p.stats
		var sum := "生命 %d  架势 %d  防御 %d  攻击 %+d%%  会心 %d%%" % [roundi(p.max_hp), roundi(p.max_posture),
			roundi(float(st["def"])), roundi(float(st["atk"]) * 100.0), roundi(minf(0.6, float(st["crit"])) * 100.0)]
		for wl: String in _wrap(font, sum, col_w - 24.0):
			_text(font, wl, Vector2(x, maxf(y + 4.0, 0.0)), Color(GOLD, 0.95), 12)
			y += 13.0
	_text(font, "Tab 关闭", Vector2(box.end.x - 8, box.end.y - 8), Color(0.75, 0.72, 0.8, 0.7), 12, true)


# ---------- 天赋 ----------

const TIER_NAMES := ["一层", "二层", "三层", "奥义"]


func _draw_talents(font: Font) -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.5))
	var box := Rect2(16, 18, 608, 324)
	draw_rect(box, Color(0.04, 0.03, 0.06, 0.96))
	_frame(box)
	_text_centered(font, "拾骨婆 · 天赋", Vector2(320, 36), Color(0.95, 0.9, 0.8), 12)
	_purse_row(font, "jade", int(Game.save["jade"]), Vector2(box.end.x - 70, 32))
	var cur: Vector3i = main.menu_cursor
	for ti in range(Talents.TREES.size()):
		var t: Dictionary = Talents.TREES[ti]
		var tc: Color = t["color"]
		var x0 := box.position.x + 10.0 + ti * 198.0
		var spent := Talents.spent_in(t)
		_text(font, "%s（%s）" % [t["name"], t["role"]], Vector2(x0 + 4, 60), tc.lightened(0.2), 12)
		_text(font, "已投 %d 点" % spent, Vector2(x0 + 186, 60), Color(0.75, 0.72, 0.78), 12, true)
		draw_rect(Rect2(x0, 66, 188, 1), Color(tc, 0.5))
		for tier in range((t["tiers"] as Array).size()):
			var y := 76.0 + tier * 50.0
			var open := spent >= int(Talents.UNLOCK[tier])
			_text(font, TIER_NAMES[tier], Vector2(x0 + 2, y + 20), Color(0.7, 0.68, 0.74, 1.0 if open else 0.45), 12)
			var nodes: Array = t["tiers"][tier]
			for k in range(nodes.size()):
				var nd: Dictionary = nodes[k]
				var r := Rect2(x0 + 34 + k * 52, y, 46, 34)
				var rank := Talents.rank(nd["id"])
				var locked_ult := false
				if nd.get("ult", false) and rank == 0:
					for other: Dictionary in nodes:
						if Talents.rank(other["id"]) > 0:
							locked_ult = true
				var lit := rank > 0
				var base_c := Color(0.12, 0.1, 0.14)
				if lit:
					base_c = tc.darkened(0.55)
				draw_rect(r, base_c if open and not locked_ult else Color(0.07, 0.06, 0.08))
				var sel := cur == Vector3i(ti, tier, k)
				var edge := tc if lit else Color(0.4, 0.38, 0.44)
				if sel:
					edge = Color(1.0, 0.95, 0.75).lerp(tc, 0.3 + 0.2 * sin(_time * 6.0))
					if menu_flash > 0.0:
						draw_rect(r.grow(3), Color(tc, menu_flash * 2.0))
				draw_rect(r, edge, false, 2.0 if sel else 1.0)
				var name_c := Color(0.95, 0.92, 0.88) if lit else Color(0.7, 0.68, 0.74)
				if not open or locked_ult:
					name_c = Color(0.4, 0.38, 0.42)
				_text_centered(font, nd["name"], Vector2(r.get_center().x, r.position.y + 16), name_c, 12)
				# 等级小方块
				var mx := int(nd["max"])
				var px := r.get_center().x - (mx * 6 - 2) / 2.0
				for m in range(mx):
					draw_rect(Rect2(px + m * 6, r.position.y + 24, 4, 4), tc if m < rank else Color(0.25, 0.23, 0.28))
				if locked_ult:
					draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color(0.4, 0.2, 0.2), 1.0)
	# 下面一栏：光标所在节点的说明
	var t: Dictionary = Talents.TREES[cur.x]
	var nd: Dictionary = t["tiers"][cur.y][cur.z]
	var rank := Talents.rank(nd["id"])
	var info := Rect2(box.position.x + 10, 280, box.size.x - 20, 34)
	draw_rect(info, Color(0.08, 0.06, 0.1))
	var head := "%s  %d/%d" % [nd["name"], rank, nd["max"]]
	_text(font, head, Vector2(info.position.x + 8, info.position.y + 14), (t["color"] as Color).lightened(0.2), 12)
	var desc := String(nd["desc"]) + ("（每级）" if int(nd["max"]) > 1 else "")
	_text(font, desc, Vector2(info.position.x + 96, info.position.y + 14), Color(0.92, 0.9, 0.86), 12)
	var why := Talents.why_not(cur.x, cur.y, cur.z)
	var price := "%d 魂玉" % Talents.COSTS[cur.y]
	var state := price if why == "" else why
	var sc := Color(0.5, 1.0, 0.8) if why == "" else Color(0.85, 0.6, 0.55)
	if menu_note_time > 0.0:
		state = menu_note
		sc = Color(1.0, 0.85, 0.5)
	_text(font, state, Vector2(info.end.x - 8, info.position.y + 14), sc, 12, true)
	_text(font, "←→ 选节点  跳/下 换层  攻击 点亮  药罐 洗髓（全退）  格挡/闪身 离开", Vector2(info.position.x + 8, info.position.y + 29),
		Color(0.7, 0.68, 0.74), 12)


# ---------- 招式和心法 ----------

## 清房三选一：每个还没选的玩家一列卡片
func _draw_rewards(font: Font) -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.45))
	var ids: Array = main.rewards.keys()
	ids.sort()
	var w := 300.0
	for n in range(ids.size()):
		var idx: int = ids[n]
		var x := 170.0 if ids.size() == 1 else (16.0 if idx == 1 else 324.0)
		var p: Player = null
		for q: Player in main.get_players():
			if q.index == idx:
				p = q
		if p == null:
			continue
		var rw: Dictionary = main.rewards[idx]
		var box := Rect2(x, 34, w, 284)
		draw_rect(box, Color(0.04, 0.03, 0.06, 0.95))
		_frame(box)
		var title: String = {"elite": "精英奖励", "event": "奇遇"}.get(rw["type"], "清场奖励")
		if main.get_players().size() > 1:
			title = "%dP · %s" % [idx, title]
		_text_centered(font, title + " · 三选一", Vector2(x + w / 2.0, 52), p.color.lightened(0.3) if main.get_players().size() > 1 else Color(0.95, 0.9, 0.8), 12)
		var choices: Array = rw["choices"]
		var cur := int(rw["cursor"])
		if int(rw["replace"]) < 0:
			for i in range(choices.size()):
				_reward_card(font, choices[i], Rect2(x + 10, 62 + i * 70, w - 20, 64), i == cur)
			_text(font, "←→ 选  攻击 确定", Vector2(x + 10, box.end.y - 8), Color(0.7, 0.68, 0.74), 12)
		else:
			var choice: Dictionary = choices[cur]
			_reward_card(font, choice, Rect2(x + 10, 62, w - 20, 64), true)
			var is_art: bool = choice["kind"] == "art"
			_text(font, "装满了，换掉哪一个？" if is_art else "心法装满了，换掉哪一个？", Vector2(x + 12, 146), Color(1.0, 0.85, 0.5), 12)
			var n_rows := Arts.MAX_ARTS if is_art else Arts.MAX_MINDS
			for i in range(n_rows):
				var r := Rect2(x + 10, 154 + i * 30, w - 20, 26)
				var sel := i == int(rw["replace"])
				draw_rect(r, Color(0.1, 0.08, 0.12) if not sel else Color(0.22, 0.12, 0.1))
				draw_rect(r, Color(1.0, 0.6, 0.4) if sel else Color(0.35, 0.32, 0.38), false, 2.0 if sel else 1.0)
				var name := ""
				var sub := ""
				var col := Color(0.9, 0.88, 0.85)
				if is_art:
					var s: Variant = p.build["arts"][i]
					_slot_glyph(r.position + Vector2(8, 13), i, Color(0.8, 0.78, 0.82))
					if s != null:
						var a: Dictionary = Arts.ARTS[s["id"]]
						name = "%s · %s" % [a["name"], Arts.LEVEL_NAMES[int(s["lv"])]]
						sub = Arts.SLOT_NAMES[Arts.SLOTS[i]]
						col = Arts.SCHOOL_COLORS[a["school"]]
				else:
					var m: Dictionary = Arts.MINDS[p.build["minds"][i]]
					name = m["name"]
					sub = m["desc"]
					col = Arts.SCHOOL_COLORS[m["school"]]
				_text(font, name, r.position + Vector2(18, 17), col, 12)
				if sub != "":
					var short: String = _wrap(font, sub, w - 130.0)[0]
					_text(font, short, Vector2(r.end.x - 6, r.position.y + 17), Color(0.65, 0.62, 0.68), 12, true)
			_text(font, "←→ 选  攻击 换掉  格挡 返回", Vector2(x + 10, box.end.y - 8), Color(0.7, 0.68, 0.74), 12)


func _reward_card(font: Font, choice: Dictionary, r: Rect2, sel: bool) -> void:
	var col := Arts.color(choice)
	var d: Array = Arts.describe(choice)
	draw_rect(r, Color(0.09, 0.07, 0.11) if not sel else Color(col.darkened(0.7), 0.95))
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), col)
	var edge := Color(1.0, 0.95, 0.75).lerp(col, 0.3 + 0.2 * sin(_time * 6.0)) if sel else Color(0.35, 0.32, 0.38)
	draw_rect(r, edge, false, 2.0 if sel else 1.0)
	_text(font, d[0], r.position + Vector2(10, 15), col, 12)
	_text(font, d[1], r.position + Vector2(62, 15), Color(0.98, 0.95, 0.9), 12)
	var lines: Array = _wrap(font, d[2], r.size.x - 20.0)
	for i in range(mini(lines.size(), 3)):
		_text(font, lines[i], r.position + Vector2(10, 30 + i * 13), Color(0.82, 0.8, 0.84) if sel else Color(0.65, 0.62, 0.68), 12)


## Tab：这一局装的招式和心法
func _draw_build_screen(font: Font) -> void:
	var ps: Array = main.get_players()
	var box := Rect2(30, 30, 580, 290)
	draw_rect(box, Color(0.04, 0.03, 0.06, 0.95))
	_frame(box)
	_text_centered(font, "招式与心法" + ("（这一局有效）" if Game.run != null else "（出发后清房获得）"), Vector2(320, 48), Color(0.95, 0.9, 0.8), 12)
	var col_w := box.size.x / float(ps.size())
	for i in range(ps.size()):
		var p: Player = ps[i]
		var x := box.position.x + 12.0 + i * col_w
		var y := 66.0
		if ps.size() > 1:
			_text(font, "%dP" % p.index, Vector2(x, y), p.color.lightened(0.3), 12)
			y += 14.0
		_text(font, "招式", Vector2(x, y), GOLD, 12)
		y += 14.0
		var slots: Array = p.build["arts"]
		for k in range(slots.size()):
			_slot_glyph(Vector2(x + 5, y - 4), k, Color(0.8, 0.78, 0.82))
			var s: Variant = slots[k]
			if s == null:
				_text(font, "%s · 空" % Arts.SLOT_NAMES[Arts.SLOTS[k]], Vector2(x + 14, y), Color(0.5, 0.48, 0.52), 12)
				y += 16.0
				continue
			var a: Dictionary = Arts.ARTS[s["id"]]
			var head := "%s %s · %s · 刃意 %d" % [a["name"], Arts.LEVEL_NAMES[int(s["lv"])], a["school"],
				roundi(p.art_cost(Arts.art(s["id"], int(s["lv"]))))]
			_text(font, head, Vector2(x + 14, y), Arts.SCHOOL_COLORS[a["school"]], 12)
			y += 13.0
			for wl: String in _wrap(font, "%s（%s）" % [a["desc"], Arts.level_desc(s["id"], int(s["lv"]))], col_w - 40.0):
				_text(font, wl, Vector2(x + 14, y), Color(0.78, 0.76, 0.8), 12)
				y += 12.0
			y += 4.0
		y += 4.0
		_text(font, "心法 %d/%d" % [(p.build["minds"] as Array).size(), Arts.MAX_MINDS], Vector2(x, y), GOLD, 12)
		y += 14.0
		for id: String in p.build["minds"]:
			var m: Dictionary = Arts.MINDS[id]
			for wl: String in _wrap(font, "%s：%s" % [m["name"], m["desc"]], col_w - 28.0):
				_text(font, wl, Vector2(x + 14, y), Arts.SCHOOL_COLORS[m["school"]].lightened(0.2), 12)
				y += 12.0
			y += 3.0
		if (p.build["minds"] as Array).is_empty():
			_text(font, "还没有", Vector2(x + 14, y), Color(0.5, 0.48, 0.52), 12)
	_text(font, "Tab 关闭", Vector2(box.end.x - 8, box.end.y - 8), Color(0.75, 0.72, 0.8, 0.7), 12, true)


## 破庙招式谱：两列，左边招式右边心法；没在谱上的用魂玉加进掉落池
func _draw_codex(font: Font) -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.5))
	var box := Rect2(16, 18, 608, 324)
	draw_rect(box, Color(0.04, 0.03, 0.06, 0.96))
	_frame(box)
	_text_centered(font, "招式谱 · 掉落池", Vector2(320, 36), Color(0.95, 0.9, 0.8), 12)
	_purse_row(font, "jade", int(Game.save["jade"]), Vector2(box.end.x - 70, 32))
	var cur: Vector2i = main.codex_cursor
	for c in range(2):
		var kind := "art" if c == 0 else "mind"
		var x0 := box.position.x + 12.0 + c * 300.0
		_text(font, "招式（最多装 3 个）" if c == 0 else "心法（最多装 4 个）", Vector2(x0 + 4, 60), GOLD, 12)
		draw_rect(Rect2(x0, 66, 284, 1), Color(GOLD_DARK, 0.8))
		var ids: Array = main.codex_ids(c)
		for i in range(ids.size()):
			var id: String = ids[i]
			var e := Arts.entry(kind, id)
			var r := Rect2(x0, 72 + i * 24, 284, 20)
			var sel := cur == Vector2i(c, i)
			var have := Arts.in_pool(kind, id)
			var col: Color = Arts.SCHOOL_COLORS[e["school"]]
			draw_rect(r, Color(col.darkened(0.7), 0.9) if sel else Color(0.08, 0.06, 0.1))
			if sel:
				draw_rect(r, Color(1.0, 0.95, 0.75).lerp(col, 0.3 + 0.2 * sin(_time * 6.0)), false, 2.0)
				if menu_flash > 0.0:
					draw_rect(r.grow(2), Color(col, menu_flash * 2.0))
			_text(font, e["name"], r.position + Vector2(8, 14), col if have else Color(0.45, 0.43, 0.48), 12)
			_text(font, e["school"], r.position + Vector2(80, 14), Color(0.65, 0.62, 0.68), 12)
			var state := "在谱上"
			var sc := Color(0.5, 1.0, 0.8)
			if kind == "art" and id == Arts.STARTER:
				state = "每局自带"
			elif not have:
				state = "%d 魂玉" % int(e["unlock"])
				sc = Color(0.85, 0.75, 0.55)
			_text(font, state, Vector2(r.end.x - 8, r.position.y + 14), sc, 12, true)
	# 下面一栏：光标所在条目的说明
	var kind2 := "art" if cur.x == 0 else "mind"
	var id2: String = main.codex_ids(cur.x)[cur.y]
	var e2 := Arts.entry(kind2, id2)
	var info := Rect2(box.position.x + 10, 254, box.size.x - 20, 70)
	draw_rect(info, Color(0.08, 0.06, 0.1))
	var lines := []
	if kind2 == "art":
		lines.append("%s · 刃意 %d · %s" % [e2["name"], int(e2["cost"]), e2["desc"]])
		for lv in range(1, Arts.max_level(id2) + 1):
			lines.append("%s：%s" % [Arts.LEVEL_NAMES[lv], Arts.level_desc(id2, lv)])
	else:
		lines.append("%s · %s" % [e2["name"], e2["desc"]])
	var y := info.position.y + 14
	for l: String in lines:
		_text(font, l, Vector2(info.position.x + 8, y), Color(0.92, 0.9, 0.86), 12)
		y += 13
	if menu_note_time > 0.0:
		_text(font, menu_note, Vector2(info.end.x - 8, info.position.y + 14), Color(1.0, 0.85, 0.5), 12, true)
	_text(font, "←→ 换列  跳/下 选  攻击 加进掉落池  格挡/闪身 离开", Vector2(box.position.x + 14, box.end.y - 6), Color(0.7, 0.68, 0.74), 12)


# ---------- 奇遇、忆境 ----------

## 奇遇：一段话，下面几个选项（付不起的灰掉）
func _draw_event(font: Font) -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.45))
	var it: Interactable = main.event_it
	var ev := Events.get_event(it.data["id"])
	var p: Player = main.event_player
	var box := Rect2(110, 40, 420, 270)
	draw_rect(box, Color(0.04, 0.03, 0.06, 0.95))
	_frame(box)
	_text_centered(font, "奇遇 · " + String(ev["name"]), Vector2(320, 58), Color(0.85, 0.75, 1.0), 12)
	var y := 78.0
	for l: String in _wrap(font, ev["text"], box.size.x - 30.0):
		_text(font, l, Vector2(box.position.x + 15, y), Color(0.92, 0.9, 0.86), 12)
		y += 14.0
	y += 6.0
	var opts: Array = ev["options"]
	for i in range(opts.size()):
		var opt: Dictionary = opts[i]
		var why := "" if opt.get("leave", false) else Events.why_not(opt, p, Game.run)
		var r := Rect2(box.position.x + 12, y, box.size.x - 24, 36)
		var sel: bool = i == main.event_cursor
		draw_rect(r, Color(0.2, 0.14, 0.26) if sel else Color(0.09, 0.07, 0.11))
		var edge := Color(1.0, 0.95, 0.75).lerp(Color(0.7, 0.55, 1.0), 0.3 + 0.2 * sin(_time * 6.0)) if sel else Color(0.35, 0.32, 0.38)
		draw_rect(r, edge, false, 2.0 if sel else 1.0)
		var name_c := Color(0.98, 0.95, 0.9) if why == "" else Color(0.5, 0.48, 0.52)
		_text(font, opt["label"], r.position + Vector2(10, 14), name_c, 12)
		if why != "":
			_text(font, why, Vector2(r.end.x - 8, r.position.y + 14), Color(0.85, 0.55, 0.5), 12, true)
		_text(font, _wrap(font, Events.describe(opt), r.size.x - 20.0)[0], r.position + Vector2(10, 29),
			Color(0.75, 0.72, 0.8) if why == "" else Color(0.45, 0.43, 0.48), 12)
		y += 40.0
	if menu_note_time > 0.0:
		_text_centered(font, menu_note, Vector2(320, box.end.y - 22), Color(1.0, 0.85, 0.5), 12)
	_text(font, "跳/下 选  攻击 确定  格挡 离开", Vector2(box.position.x + 12, box.end.y - 8), Color(0.7, 0.68, 0.74), 12)
	if main.get_players().size() > 1:
		_text(font, "%dP 在选" % p.index, Vector2(box.end.x - 10, box.end.y - 8), p.color.lightened(0.3), 12, true)


## 忆境：左边一列记忆（几片 / 三片），右边是选中那段拼出来的话
func _draw_memories(font: Font) -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.5))
	var box := Rect2(30, 30, 580, 290)
	draw_rect(box, Color(0.03, 0.04, 0.07, 0.96))
	_frame(box)
	_text_centered(font, "忆境", Vector2(320, 48), Color(0.75, 0.9, 1.0), 12)
	var cur: int = main.memory_cursor
	for i in range(Story.MEMORIES.size()):
		var m: Dictionary = Story.MEMORIES[i]
		var n := Story.count_in(m)
		var total := (m["frags"] as Array).size()
		var r := Rect2(box.position.x + 12, 62 + i * 30, 150, 26)
		var sel := i == cur
		draw_rect(r, Color(0.1, 0.18, 0.24) if sel else Color(0.07, 0.07, 0.1))
		if sel:
			draw_rect(r, Color(0.7, 0.9, 1.0).lerp(Color(0.3, 0.6, 0.8), 0.3 + 0.2 * sin(_time * 6.0)), false, 2.0)
		var title: String = m["title"] if n > 0 else "？？？"
		_text(font, title, r.position + Vector2(8, 17), Color(0.85, 0.95, 1.0) if n == total else Color(0.6, 0.66, 0.72), 12)
		for k in range(total):
			draw_rect(Rect2(r.end.x - 10 - (total - 1 - k) * 7, r.position.y + 10, 5, 7),
				Color(0.55, 0.85, 1.0) if Story.has(Story.frag_id(m["id"], k)) else Color(0.2, 0.22, 0.26))
	# 右边：这一段记忆
	var m2: Dictionary = Story.MEMORIES[cur]
	var tx := box.position.x + 180.0
	var y := 74.0
	var shown := Story.count_in(m2) > 0
	_text(font, m2["title"] if shown else "还没有想起来", Vector2(tx, y), Color(0.75, 0.9, 1.0), 12)
	y += 20.0
	for k in range((m2["frags"] as Array).size()):
		var line: String = m2["frags"][k] if Story.has(Story.frag_id(m2["id"], k)) else "……"
		for wl: String in _wrap(font, line, box.end.x - tx - 16.0):
			_text(font, wl, Vector2(tx, y), Color(0.9, 0.9, 0.92) if line != "……" else Color(0.4, 0.42, 0.46), 12)
			y += 14.0
		y += 8.0
	var hint := "精英、奇遇会掉记忆碎片" if m2.get("boss", "") == "" else "打败这位头目，每次想起一段"
	_text(font, hint, Vector2(tx, box.end.y - 26), Color(0.55, 0.6, 0.66), 12)
	_text(font, "跳/下 选  格挡 离开", Vector2(box.position.x + 12, box.end.y - 8), Color(0.7, 0.68, 0.74), 12)
