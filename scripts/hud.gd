class_name Hud
extends Node2D
## 屏幕界面：左上角玩家状态和铜钱魂玉，顶上的小地图，底部敌人名字和血条，
## Tab 打开的整张地图，按 H 打开的操作说明，死亡结算，换房间的黑屏。

const GOLD := Color("c9a24a")
const GOLD_DARK := Color("6b5426")
const FRAME := Color("0c0a12")

const HELP := [
	["1P", "A/D 移动  W/空格 跳  S 下  J 攻击(长按重击)  K 格挡/弹反  L/Shift 闪身  U 药罐  I 回旋斩  O 换架势"],
	["2P", "←/→ 移动  ↑ 跳  ↓ 下  小键盘1 攻击 2 格挡 3 闪身 4 药罐 5 回旋斩 6 换架势"],
	["招式", "连按攻击五连  下+攻击 升龙斩  空中攻击 空中斩  空中下+攻击 落雷斩  闪身中攻击 闪身突刺"],
	["手柄", "A 跳  X 攻击  RB 格挡  B 闪身  Y 药罐  LB 回旋斩  十字键上 换架势"],
	["闯关", "站在门、货物、香炉、供台前按 下 互动  Tab 地图  清完敌人出口才开"],
	["其他", "F2 2P 加入/退出  F1 低难度  F3 判定框  F4 练武场（数字键换对手）  Esc 退出"],
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

	if show_map and Game.run != null:
		_draw_map(font)
	if show_help:
		_draw_help(font)
	else:
		var hint := "H 操作说明" + ("  Tab 地图" if Game.run != null else "")
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


func _will(r: Rect2, ratio: float, ready: bool) -> void:
	draw_rect(r, Color("10141a"))
	var col := Color(0.55, 0.85, 1.0) if not ready else Color(1.0, 0.85, 0.4).lerp(Color(1, 1, 1), 0.2 + 0.2 * sin(_time * 8.0))
	var w := roundf(r.size.x * clampf(ratio, 0.0, 1.0))
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(w, 1)), col.lightened(0.4))
	# 每 40 一格的刻度
	var step := r.size.x * float(Player.ART["cost"]) / Player.MAX_WILL
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
	_will(wi_r, p.will / Player.MAX_WILL, p.will >= float(Player.ART["cost"]))
	# 药罐
	for i in range(p.max_gourds):
		_gourd(at + Vector2(140 + i * 9, 36), i < p.gourds)
	# 弹反次数
	_text(font, "弹反 × %d" % p.parry_count, at + Vector2(32, 40), Color(0.95, 0.85, 0.55), 12)
	# 当前架势
	_text(font, "架势 · " + str(p.stance()["name"]), at + Vector2(32, 54), Color(0.8, 0.86, 1.0), 12)
	if p.state == Player.S.DEAD:
		var msg := "%.0f 秒后复活" % maxf(p.respawn_timer, 0.0) if p.auto_respawn else "清完这间复苏"
		_text(font, msg, at + Vector2(110, 54), Color(1, 0.4, 0.4), 12)


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
	var r := Rect2(24, 218, 592, 106)
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
	var at := Vector2(14, 84)
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
	var kept := int(floor(r.jade * LevelData.DEATH_KEEP))
	var la := clampf((t - 0.7) / 0.4, 0.0, 1.0)
	var lines := [
		["走到", "第 %d / %d 间 · %s" % [r.row + 1, r.rows.size(), LevelData.room(r.room_key())["name"]]],
		["斩敌", "%d" % r.kills],
		["魂玉", "%d → 带回 %d（60%%）" % [r.jade, kept]],
		["铜钱", "%d · 散落" % r.coins],
	]
	for i in range(lines.size()):
		var y := 178.0 + i * 16.0
		_text(font, lines[i][0], Vector2(252, y), Color(GOLD, la), 12)
		_text(font, lines[i][1], Vector2(292, y), Color(0.92, 0.9, 0.88, la), 12)
	if t > 1.4:
		var blink := 0.55 + 0.45 * sin(t * 4.0)
		_text_centered(font, "按 攻击 回破庙", Vector2(320, 260), Color(1, 0.95, 0.8, blink), 12)
