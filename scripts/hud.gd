class_name Hud
extends Node2D
## 屏幕界面：玩家生命和架势、操作说明。

var main: Node
var show_help := true

const HELP_1P := "1P  A/D 移动  W/空格 跳(二段跳)  J 攻击(长按重击)  K 格挡(按准时机=弹反)  L/Shift 闪身"
const HELP_2P := "2P  ←/→ 移动  ↑ 跳  小键盘1 或 , 攻击  小键盘2 或 . 格挡  小键盘3 或 / 闪身   (手柄: X 攻击 RB 格挡 B 闪身 A 跳)"
const HELP_SYS := "F2 加入/退出 2P   F1 低难度弹反窗口   F3 显示判定框   R 重置   H 隐藏说明   Esc 退出"


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = Game.font
	for p: Player in main.get_players():
		var right := p.index == 2
		var x := 640.0 - 12.0 - 150.0 if right else 12.0
		_draw_player_panel(font, p, Vector2(x, 10))
	if not main.has_player(2):
		_text(font, "2P 按 F2 或攻击键加入", Vector2(640 - 12 - 150, 22), Color(0.7, 0.7, 0.7), 10)

	var mode := "弹反窗口 %.2f 秒%s" % [Game.parry_window(), "（低难度）" if Game.easy_mode else ""]
	_text(font, mode, Vector2(270, 20), Color(0.8, 0.8, 0.8), 10)

	if show_help:
		draw_rect(Rect2(0, 316, 640, 44), Color(0, 0, 0, 0.55))
		_text(font, HELP_1P, Vector2(8, 328), Color(0.85, 0.9, 1.0), 9)
		_text(font, HELP_2P, Vector2(8, 341), Color(0.85, 1.0, 0.85), 9)
		_text(font, HELP_SYS, Vector2(8, 354), Color(0.85, 0.85, 0.85), 9)


func _draw_player_panel(font: Font, p: Player, at: Vector2) -> void:
	_text(font, "%dP" % p.index, at + Vector2(0, 9), p.color, 11)
	var bar := Vector2(at.x + 22, at.y + 1)
	# 生命
	draw_rect(Rect2(bar, Vector2(128, 6)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar, Vector2(128 * p.hp / p.max_hp, 6)), Color(0.85, 0.2, 0.2))
	# 架势（中间向两边）
	var ratio := p.posture / p.max_posture
	var w := 128.0 * ratio
	var py := bar.y + 9
	draw_rect(Rect2(bar.x, py, 128, 4), Color(0, 0, 0, 0.7))
	var col := Color(1.0, 0.75, 0.2).lerp(Color(1.0, 0.25, 0.1), clampf((ratio - 0.5) * 2.0, 0.0, 1.0))
	draw_rect(Rect2(bar.x + 64 - w / 2.0, py, w, 4), col)
	_text(font, "弹反 %d" % p.parry_count, Vector2(bar.x, py + 14), Color(1.0, 0.9, 0.5), 9)
	if p.state == Player.S.DEAD:
		_text(font, "%.0f 秒后复活" % maxf(p.respawn_timer, 0.0), Vector2(bar.x + 50, py + 14), Color(1, 0.4, 0.4), 9)


func _text(font: Font, s: String, pos: Vector2, col: Color, size: int) -> void:
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
