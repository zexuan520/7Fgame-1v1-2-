class_name TitleCard
extends Control
## 标题画面：夜樱广场做背景，正中写游戏名，按 J / 回车 / 点鼠标开始。打开时世界暂停（花瓣照飘）。

signal started
signal chapters      # 章节试玩：直接进第二、三幕（临时存档，不影响进度）

var font: Font
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	font = Feel.I.font if Feel.I != null else Game.font


var _tapped := false
var _tap_ch := false
var _ch_rect := Rect2()     # “章节试玩”那一行（点它进章节选择）
var paused_input := false   # 章节选择菜单开着时，标题不收按键


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _ch_rect.has_point(mb.position):
			_tap_ch = true
			accept_event()
		elif TouchPad.active:
			_tapped = true
			accept_event()


func _process(dt: float) -> void:
	if Zaohua.is_platform_paused():
		return   # 平台把游戏暂停了（切后台等），菜单也不能动
	_t += dt
	_fit()
	# 镜头绕着樱树慢慢晃（标题背景是活的）
	if CamRig.I != null:
		CamRig.I.yaw_deg = sin(_t * 0.12) * 9.0
	if Feel.I != null:
		Feel.I.world_pause = maxf(Feel.I.world_pause, 0.05)
	queue_redraw()
	if _t < 0.6:
		return
	if paused_input:
		_tapped = false
		_tap_ch = false
		return
	var ch := _tap_ch or Input.is_action_just_pressed(ArpgInput.act(0, "dash"))
	var go := _tapped or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed(ArpgInput.act(0, "attack")) \
		or Input.is_action_just_pressed(ArpgInput.act(0, "interact")) or Input.is_action_just_pressed(ArpgInput.act(1, "attack"))
	_tapped = false
	_tap_ch = false
	if ch:
		Game.sfx("ui_back", -4.0)
		chapters.emit()
		return
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
	# 左边一栏写字，右边留给樱树和主角（镜头在 ArpgMain._enter_title_body 里摆）
	var cx := vs.x * 0.29
	var w := vs.x * 0.5
	var x0 := cx - w * 0.5
	var y := vs.y * 0.36
	var gold := Color(0.86, 0.72, 0.42, a)
	# 字底下垫一层由深到浅的暗影，背景再花也读得清
	for i in range(7):
		var k := float(i) / 7.0
		draw_rect(Rect2(0, y - 130 + k * 16, vs.x * (0.6 - k * 0.07), 330 - k * 32), Color(0.0, 0.0, 0.02, 0.08 * a))
	# 2026-11-07：字后面一笔横扫的墨迹（毛边），四个字一个接一个落下来，右上角盖一枚朱红印
	_draw_brush(Vector2(cx, y - 34), w * 0.78, 96.0, a)
	var title := "残刃归途"
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 104).x
	var tx := cx - tw * 0.5
	for i in range(title.length()):
		var ch := title.substr(i, 1)
		var k := clampf((_t - 0.15 - i * 0.16) / 0.35, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var dy := (1.0 - e) * -26.0
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 104).x
		draw_string(font, Vector2(tx, y + 5 + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 104, Color(0.0, 0.0, 0.0, 0.6 * e))
		draw_string(font, Vector2(tx, y + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 104, Color(0.98, 0.94, 0.87, e))
		tx += cw
	_draw_seal(Vector2(cx + tw * 0.5 + 26, y - 74), clampf((_t - 0.95) / 0.25, 0.0, 1.0))
	draw_line(Vector2(cx - w * 0.3, y + 32), Vector2(cx + w * 0.3, y + 32), gold, 1.5)
	draw_string(font, Vector2(x0, y + 68), "归乡　·　入山　·　出山", HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0.95, 0.82, 0.62, a))
	draw_string(font, Vector2(x0, y + 100), "三幕九层 · 斜俯视体素动作肉鸽", HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(0.75, 0.82, 0.85, a * 0.85))
	# “按 J 开始”：底下垫一条暗带，呼吸但不会暗到看不见
	var blink := 0.75 + 0.25 * sin(_t * 3.0)
	var py := y + 190
	var bw := w * 0.56
	draw_rect(Rect2(cx - bw * 0.5, py - 34, bw, 48), Color(0.0, 0.0, 0.0, 0.45 * a))
	draw_line(Vector2(cx - bw * 0.5, py - 34), Vector2(cx + bw * 0.5, py - 34), Color(gold.r, gold.g, gold.b, 0.5 * a), 1.0)
	draw_line(Vector2(cx - bw * 0.5, py + 14), Vector2(cx + bw * 0.5, py + 14), Color(gold.r, gold.g, gold.b, 0.5 * a), 1.0)
	draw_string(font, Vector2(x0, py), TouchPad.hint("按 J 开始", "点击屏幕开始"), HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color(1.0, 0.9, 0.65, a * blink))
	# 章节试玩：不想从头打的（比如评委、只想看后面风景的），直接进第二、三幕
	var cy := py + 46
	_ch_rect = Rect2(cx - bw * 0.5, cy - 24, bw, 34)
	draw_rect(_ch_rect, Color(0.0, 0.0, 0.0, 0.3 * a))
	draw_string(font, Vector2(x0, cy), TouchPad.hint("按 K · 章节试玩", "点这里 · 章节试玩"), HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0.7, 0.88, 0.9, a * 0.9))
	draw_string(font, Vector2(x0, cy + 22), "直接进第二、三幕，不影响存档", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.6, 0.7, 0.72, a * 0.75))
	var keys := TouchPad.hint("WASD 移动　J 攻击　空格 翻滚　K 突进斩　I 光束斩　E 终结技　U 喝药　F 互动", "请横屏游玩　左手摇杆移动　右手：斩 攻击　滚 翻滚　突 突进斩　光 光束斩　终 终结技　药 喝药")
	draw_string(font, Vector2(0, vs.y * 0.94), keys, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(0.65, 0.75, 0.75, a))
	# 素材署名（CC BY 要求写出处；其余 CC0/MIT 素材的出处在 assets/*CREDITS.md）
	draw_string(font, Vector2(0, vs.y - 8), "图标 game-icons.net（Lorc、Delapouite，CC BY 3.0）　配乐和音效 OpenGameArt 各作者（CC0）", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 11, Color(0.5, 0.58, 0.58, a * 0.7))
	draw_string(font, Vector2(0, vs.y * 0.08), "魂玉 %d" % int(Game.save.get("jade", 0)), HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 30, 18, Color(0.55, 1.0, 0.85, a))


## 墨迹：一条两头尖、上下边毛糙的横笔（多边形，边缘用正弦叠出飞白的锯齿）
func _draw_brush(c: Vector2, w: float, h: float, a: float) -> void:
	var k := clampf((_t - 0.05) / 0.5, 0.0, 1.0)
	var ww := w * (1.0 - pow(1.0 - k, 3.0))
	if ww < 8.0:
		return
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var n := 36
	for i in range(n + 1):
		var u := float(i) / n
		var x := c.x - w * 0.5 + ww * u
		var taper := maxf(sin(PI * u), 0.08) * (1.0 - 0.35 * u)
		var j1 := sin(u * 53.0) * 4.0 + sin(u * 131.0) * 2.5
		var j2 := sin(u * 47.0 + 1.3) * 4.0 + sin(u * 117.0) * 3.0
		top.append(Vector2(x, c.y - h * 0.5 * taper + j1 * taper))
		bot.append(Vector2(x, c.y + h * 0.5 * taper + j2 * taper))
	bot.reverse()
	var poly := top + bot
	draw_colored_polygon(poly, Color(0.55, 0.06, 0.08, 0.72 * a))   # 一笔暗朱砂，衬白字


## 朱红方印，里面一个“刃”字；落下时从大缩到正常、带一点旋转
func _draw_seal(p: Vector2, k: float) -> void:
	if k <= 0.0:
		return
	var e := 1.0 - pow(1.0 - k, 3.0)
	var s := 46.0 * (1.0 + (1.0 - e) * 0.8)
	var ang := -0.12
	var xf := Transform2D(ang, p)
	draw_set_transform_matrix(xf)
	var col := Color(0.72, 0.1, 0.08, 0.92 * e)
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), col)
	draw_rect(Rect2(-s * 0.5 + 3, -s * 0.5 + 3, s - 6, s - 6), Color(1.0, 0.9, 0.82, 0.85 * e), false, 1.5)
	draw_string(font, Vector2(-s * 0.5, s * 0.22), "刃", HORIZONTAL_ALIGNMENT_CENTER, s, int(s * 0.62), Color(1.0, 0.93, 0.85, e))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 父节点是 CanvasLayer，锚点铺满不生效（尺寸是 0，点不到）；每帧按视口大小摆好，触屏点击才收得到
func _fit() -> void:
	var vs := get_viewport_rect().size
	if size != vs:
		position = Vector2.ZERO
		size = vs
