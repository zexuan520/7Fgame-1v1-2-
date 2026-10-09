class_name Hud
extends Node2D
## 屏幕界面：左上角玩家状态，底部敌人名字和血条，按 H 打开的操作说明。

const GOLD := Color("c9a24a")
const GOLD_DARK := Color("6b5426")
const FRAME := Color("0c0a12")

const HELP := [
	["1P", "A/D 移动  W/空格 跳  J 攻击(长按重击)  K 格挡/弹反  L/Shift 闪身  U 药罐  I 回旋斩"],
	["2P", "←/→ 移动  ↑ 跳  小键盘1 攻击 2 格挡 3 闪身 4 药罐 5 回旋斩"],
	["手柄", "A 跳  X 攻击  RB 格挡  B 闪身  Y 药罐  LB 回旋斩"],
	["其他", "F2 2P 加入/退出  F1 低难度  F3 判定框  R 重置  Esc 退出"],
]

var main: Node
var show_help := false
var _toast := ""
var _toast_time := 0.0
var _trail := {}            # 血条掉血时的白色残影
var _time := 0.0


func toast(text: String) -> void:
	_toast = text
	_toast_time = 1.6


func _process(delta: float) -> void:
	_time += delta
	_toast_time = maxf(0.0, _toast_time - delta)
	queue_redraw()


func _draw() -> void:
	var font: Font = Game.font
	for p: Player in main.get_players():
		var at := Vector2(10, 10) if p.index == 1 else Vector2(640 - 10 - 168, 10)
		_draw_player_panel(font, p, at)
	if not main.has_player(2):
		_text(font, "2P 按 F2 加入", Vector2(640 - 10, 22), Color(0.75, 0.72, 0.8, 0.55), 12, true)

	for e: Enemy in main.get_enemies():
		if e.visible and e.state != Enemy.S.DEAD:
			_draw_boss_bar(font, e)

	if _toast_time > 0.0:
		var a := clampf(_toast_time / 0.4, 0.0, 1.0)
		_text_centered(font, _toast, Vector2(320, 70), Color(1, 0.95, 0.8, a), 12)

	if show_help:
		_draw_help(font)
	else:
		_text(font, "H 操作说明", Vector2(640 - 8, 354), Color(0.8, 0.78, 0.85, 0.45), 12, true)


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
	for i in range(Player.MAX_GOURDS):
		_gourd(at + Vector2(140 + i * 9, 36), i < p.gourds)
	# 弹反次数
	_text(font, "弹反 × %d" % p.parry_count, at + Vector2(32, 40), Color(0.95, 0.85, 0.55), 12)
	if p.state == Player.S.DEAD:
		_text(font, "%.0f 秒后复活" % maxf(p.respawn_timer, 0.0), at + Vector2(32, 54), Color(1, 0.4, 0.4), 12)


func _draw_boss_bar(font: Font, e: Enemy) -> void:
	var r := Rect2(160, 330, 320, 7)
	_text_centered(font, "无名浪人", Vector2(320, 322), Color(0.92, 0.86, 0.78), 12)
	# 剩余血管
	for i in range(Enemy.LIVES):
		var c := Vector2(320 + 40 + i * 9, 316)
		draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), FRAME)
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color("c42a2a") if i < e.lives else Color("3a3040"))
	_frame(r)
	_bar(r, e.hp / e.max_hp, Color("9e1c24"), "boss")
	var po := Rect2(200, 342, 240, 3)
	_frame(po)
	_posture(po, e.posture / e.max_posture)


func _draw_help(font: Font) -> void:
	var r := Rect2(24, 250, 592, 74)
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
