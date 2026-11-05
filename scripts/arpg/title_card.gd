class_name TitleCard
extends Control
## 标题画面：夜樱广场做背景，正中写游戏名，按 J / 回车 / 点鼠标开始。打开时世界暂停（花瓣照飘）。

signal started

var font: Font
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Feel.I.font if Feel.I != null else Game.font


func _process(dt: float) -> void:
	if Zaohua.is_platform_paused():
		return   # 平台把游戏暂停了（切后台等），菜单也不能动
	_t += dt
	if Feel.I != null:
		Feel.I.world_pause = maxf(Feel.I.world_pause, 0.05)
	queue_redraw()
	if _t < 0.6:
		return
	var go := Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed(ArpgInput.act(0, "attack")) \
		or Input.is_action_just_pressed(ArpgInput.act(0, "interact")) or Input.is_action_just_pressed(ArpgInput.act(1, "attack"))
	if go:
		Game.sfx("reward", -6.0)
		started.emit()


func _draw() -> void:
	var vs := get_viewport_rect().size
	var a := clampf(_t / 1.2, 0.0, 1.0)
	# 上下两条暗带，像电影画幅
	draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.0, 0.02, 0.03, 0.35))
	draw_rect(Rect2(0, 0, vs.x, vs.y * 0.12), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(0, vs.y * 0.88, vs.x, vs.y * 0.12), Color(0, 0, 0, 0.7))
	var y := vs.y * 0.4
	var gold := Color(0.86, 0.72, 0.42, a)
	draw_string(font, Vector2(0, y + 4), "残刃归途", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 96, Color(0.0, 0.0, 0.0, 0.5 * a))
	draw_string(font, Vector2(0, y), "残刃归途", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 96, Color(0.97, 0.93, 0.86, a))
	draw_line(Vector2(vs.x * 0.36, y + 30), Vector2(vs.x * 0.64, y + 30), gold, 1.0)
	draw_string(font, Vector2(0, y + 64), "幽林　·　无名冢　·　古寺", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 22, Color(0.6, 0.9, 0.9, a))
	var blink := 0.55 + 0.45 * sin(_t * 3.0)
	draw_string(font, Vector2(0, vs.y * 0.74), "按 J 开始", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 26, Color(1.0, 0.9, 0.65, a * blink))
	var keys := "WASD 移动　J 攻击　空格 翻滚　K 突进斩　I 光束斩　E 终结技　U 喝药　F 互动"
	draw_string(font, Vector2(0, vs.y * 0.94), keys, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(0.65, 0.75, 0.75, a))
	draw_string(font, Vector2(0, vs.y * 0.08), "魂玉 %d" % int(Game.save.get("jade", 0)), HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 30, 18, Color(0.55, 1.0, 0.85, a))
