class_name DialogBox
extends Control
## 剧情对话框：屏幕下方一条暗色横幅，左边说话人名字（带颜色），文字逐字打出来。
## J / F / 回车：字没打完就一下打完，打完了翻下一句。打开时世界暂停。
## lines 每项：[说话人, 文字] 或 [说话人, 文字, 名字颜色]；说话人为空表示旁白（斜体灰色，居中）。

signal finished

const GOLD := Color(0.86, 0.72, 0.42)

var lines: Array = []
var font: Font
var _i := 0
var _shown := 0.0
var _t := 0.0
var _cool := 0.25


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialog_box")
	font = Feel.I.font if Feel.I != null else Game.font


func _act(n: String) -> bool:
	return Input.is_action_just_pressed(ArpgInput.act(0, n)) or Input.is_action_just_pressed(ArpgInput.act(1, n))


var _tapped := false


## 触屏：点屏幕任意处 = 确认
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if TouchPad.active and mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_tapped = true
		accept_event()


func _process(dt: float) -> void:
	if Zaohua.is_platform_paused():
		return   # 平台把游戏暂停了（切后台等），菜单也不能动
	_t += dt
	_fit()
	if Feel.I != null:
		Feel.I.world_pause = maxf(Feel.I.world_pause, 0.05)
	queue_redraw()
	if _i >= lines.size():
		return
	var text := String(lines[_i][1])
	_shown = minf(_shown + dt * 38.0, text.length())
	_cool -= dt
	if _cool > 0.0:
		return
	var tap := _tapped
	_tapped = false
	if tap or _act("attack") or _act("interact") or Input.is_action_just_pressed("ui_accept"):
		if _shown < text.length():
			_shown = text.length()
		else:
			_i += 1
			_shown = 0.0
			Game.sfx("ui_back", -14.0)
			if _i >= lines.size():
				finished.emit()
				queue_free()


func _draw() -> void:
	if _i >= lines.size():
		return
	var vs := get_viewport_rect().size
	var ln: Array = lines[_i]
	var who := String(ln[0])
	var text := String(ln[1]).substr(0, int(_shown))
	var h := 150.0
	var y := vs.y - h - 24.0
	# 上方淡淡压暗，下方一条横幅
	draw_rect(Rect2(0, y - 40, vs.x, h + 64), Color(0, 0.01, 0.02, 0.55))
	draw_line(Vector2(vs.x * 0.12, y), Vector2(vs.x * 0.88, y), Color(GOLD, 0.6), 1.0)
	draw_line(Vector2(vs.x * 0.12, y + h), Vector2(vs.x * 0.88, y + h), Color(GOLD, 0.35), 1.0)
	var x0 := vs.x * 0.16
	var w := vs.x * 0.68
	if who == "":
		_wrap(text, Vector2(x0, y + 52), w, 22, Color(0.78, 0.84, 0.84), true)
	else:
		var col: Color = ln[2] if ln.size() > 2 else GOLD
		draw_string(font, Vector2(x0, y + 36), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		_wrap(text, Vector2(x0, y + 74), w, 21, Color(0.95, 0.93, 0.88), false)
	if _shown >= String(ln[1]).length():
		var a := 0.5 + 0.5 * sin(_t * 5.0)
		draw_string(font, Vector2(x0 + w - 60, y + h - 16), TouchPad.hint("J ▸", "点击继续"), HORIZONTAL_ALIGNMENT_RIGHT, 60, 16, Color(GOLD, a))


func _wrap(text: String, pos: Vector2, width: float, size: int, col: Color, center: bool) -> void:
	var rows: Array[String] = []
	var line := ""
	for ch in text:
		if ch == "\n":
			rows.append(line)
			line = ""
			continue
		var t := line + ch
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			rows.append(line)
			line = ch
		else:
			line = t
	if line != "":
		rows.append(line)
	var y := pos.y
	for r: String in rows:
		draw_string(font, Vector2(pos.x, y), r, HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT, width if center else -1, size, col)
		y += size + 10


## 父节点是 CanvasLayer，锚点铺满不生效（尺寸是 0，点不到）；每帧按视口大小摆好，触屏点击才收得到
func _fit() -> void:
	var vs := get_viewport_rect().size
	if size != vs:
		position = Vector2.ZERO
		size = vs
