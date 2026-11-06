class_name ArpgMenu
extends Control
## 通用选择面板（天赋、兵器架、商人、奇遇、清房三选一、分岔路）：暗色半透明底 + 金/青细边，衬线字体。
## 上下（或左右）选，J / F / 回车确认，空格 / Esc 返回（cancellable 时）。打开时整个世界暂停（Feel.world_pause）。
## items 里每项：{"title", "desc", "right"（右侧小字，如价格）, "enabled", "color", "tag"（左上角小标签）}

signal chosen(index: int)
signal cancelled

const GOLD := Color(0.86, 0.72, 0.42)
const TEAL := Color(0.35, 0.85, 0.85)

var title := ""
var subtitle := ""
var footer := ""
var items: Array = []
var layout := "list"         # list 竖排 / cards 横排卡片
var cancellable := true
var index := 0
var font: Font
var _t := 0.0
var _cool := 0.15            # 打开后一小会儿不吃按键（免得攻击键连按直接选掉）
var cards_top_min := 0.0    # 卡片最高只能到这个 y（上面画了路线图时往下让）
var extra_draw: Callable     # 额外画点东西（分岔路地图）
var _hits: Array = []        # 触屏：每帧画出来的 [Rect2, 选项序号]；-1 关闭，-2 上一页，-3 下一页


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = Feel.I.font if Feel.I != null else Game.font
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	for i in range(items.size()):
		if bool(items[i].get("enabled", true)):
			index = i
			break


func _act(n: String) -> bool:
	return Input.is_action_just_pressed(ArpgInput.act(0, n)) or Input.is_action_just_pressed(ArpgInput.act(1, n))


func _process(dt: float) -> void:
	if Zaohua.is_platform_paused():
		return   # 平台把游戏暂停了（切后台等），菜单也不能动
	_t += dt
	_fit()
	if Feel.I != null:
		Feel.I.world_pause = maxf(Feel.I.world_pause, 0.05)
	_cool -= dt
	queue_redraw()
	if _cool > 0.0 or items.is_empty():
		return
	var prev := ["up", "left"]
	var nxt := ["down", "right"]
	for a: String in prev:
		if _act(a):
			index = (index - 1 + items.size()) % items.size()
			Game.sfx("ui_back", -12.0)
	for a: String in nxt:
		if _act(a):
			index = (index + 1) % items.size()
			Game.sfx("ui_back", -12.0)
	if _act("attack") or _act("interact") or Input.is_action_just_pressed("ui_accept"):
		if bool(items[index].get("enabled", true)):
			Game.sfx("reward", -6.0)
			chosen.emit(index)
		else:
			Game.sfx("block", -8.0)
	elif cancellable and (_act("roll") or _act("bag") or Input.is_action_just_pressed("ui_cancel")):
		cancelled.emit()


## 触屏：点选项直接确认，点右上角 ✕ 返回，长列表点 ▲▼ 翻页
func _gui_input(event: InputEvent) -> void:
	if not TouchPad.active or Zaohua.is_platform_paused() or _cool > 0.0:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	for h: Array in _hits:
		if not (h[0] as Rect2).grow(6).has_point(mb.position):
			continue
		var i := int(h[1])
		if i == -1:
			cancelled.emit()
		elif i == -2 or i == -3:
			index = clampi(index + (-_per_page if i == -2 else _per_page), 0, items.size() - 1)
			Game.sfx("ui_back", -12.0)
		else:
			index = i
			if bool(items[i].get("enabled", true)):
				Game.sfx("reward", -6.0)
				chosen.emit(i)
			else:
				Game.sfx("block", -8.0)
		return


var _per_page := 6


func _draw() -> void:
	var vs := get_viewport_rect().size
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.02, 0.03, 0.62))
	var y0 := vs.y * 0.16
	draw_string(font, Vector2(0, y0), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 38, Color(0.96, 0.92, 0.84))
	draw_line(Vector2(vs.x * 0.3, y0 + 14), Vector2(vs.x * 0.7, y0 + 14), Color(GOLD, 0.7), 1.0)
	if subtitle != "":
		draw_string(font, Vector2(0, y0 + 42), subtitle, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 18, Color(0.7, 0.88, 0.88))
	if extra_draw.is_valid():
		extra_draw.call(self, vs)
	if layout == "cards":
		_draw_cards(vs)
	else:
		_draw_list(vs)
	var foot := footer if footer != "" else TouchPad.hint("J 确认" + ("    空格 返回" if cancellable else ""), "点选一项" + ("    右上角 ✕ 返回" if cancellable else ""))
	if TouchPad.active and cancellable:
		var br := Rect2(vs.x - 150, 24, 126, 54)
		draw_rect(br, Color(0.03, 0.06, 0.07, 0.85))
		draw_rect(br, Color(GOLD, 0.8), false, 1.5)
		draw_string(font, br.position + Vector2(0, 36), "✕ 返回", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 24, Color(0.95, 0.92, 0.85))
		_hits.append([br, -1])
	draw_string(font, Vector2(0, vs.y - 40), foot, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(0.65, 0.75, 0.75))


func _draw_list(vs: Vector2) -> void:
	var w := 620.0
	var x := (vs.x - w) * 0.5
	var y := vs.y * 0.16 + 80
	var h := 62.0
	var per_page := maxi(1, int((vs.y - y - 80) / h))
	_per_page = per_page
	var start := clampi(index - per_page + 1, 0, maxi(0, items.size() - per_page))
	if TouchPad.active and items.size() > per_page:
		# 长列表：右侧上下翻页
		var up := Rect2(x + w + 16, y, 56, 56)
		var dn := Rect2(x + w + 16, y + per_page * h - 64, 56, 56)
		for pr: Array in [[up, -2, "▲", start > 0], [dn, -3, "▼", start + per_page < items.size()]]:
			var rr: Rect2 = pr[0]
			draw_rect(rr, Color(0.03, 0.06, 0.07, 0.85))
			draw_rect(rr, Color(GOLD, 0.8 if pr[3] else 0.25), false, 1.5)
			draw_string(font, rr.position + Vector2(0, 38), pr[2], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 26, Color(GOLD, 1.0 if pr[3] else 0.3))
			_hits.append([rr, pr[1]])
	for i in range(start, mini(items.size(), start + per_page)):
		var it: Dictionary = items[i]
		var sel := i == index
		var en := bool(it.get("enabled", true))
		var r := Rect2(x, y, w, h - 8)
		_hits.append([r, i])
		draw_rect(r, Color(0.03, 0.06, 0.07, 0.85 if sel else 0.6))
		draw_rect(r, Color(GOLD if sel else Color(TEAL, 0.25), 0.9 if sel else 1.0), false, 2.0 if sel else 1.0)
		if sel:
			var px := x - 18 + sin(_t * 8.0) * 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(px, y + 18), Vector2(px + 10, y + 27), Vector2(px, y + 36)]), GOLD)
		var col: Color = it.get("color", Color(0.95, 0.92, 0.85))
		if not en:
			col = Color(0.45, 0.48, 0.48)
		var tag := String(it.get("tag", ""))
		var tx := x + 16
		if tag != "":
			draw_string(font, Vector2(tx, y + 24), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(it.get("tag_color", TEAL), 0.9 if en else 0.4))
			tx += 54
		draw_string(font, Vector2(tx, y + 24), String(it.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		draw_string(font, Vector2(tx, y + 46), String(it.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x) - 120, 15, Color(0.72, 0.8, 0.8) if en else Color(0.4, 0.42, 0.42))
		var right := String(it.get("right", ""))
		if right != "":
			draw_string(font, Vector2(x + w - 140, y + 24), right, HORIZONTAL_ALIGNMENT_RIGHT, 124, 17, Color(1.0, 0.85, 0.45) if en else Color(0.55, 0.45, 0.35))
		y += h


func _draw_cards(vs: Vector2) -> void:
	var n := items.size()
	var cw := 240.0
	var ch := 300.0 if vs.y >= 650 else 268.0   # 触屏矮屏：别压到底下的操作提示
	var gap := 36.0
	var total := n * cw + (n - 1) * gap
	var x := (vs.x - total) * 0.5
	var y := maxf(vs.y * 0.5 - ch * 0.5 + 30, cards_top_min)
	for i in range(n):
		var it: Dictionary = items[i]
		var sel := i == index
		var en := bool(it.get("enabled", true))
		var lift := -10.0 if sel else 0.0
		var r := Rect2(x + i * (cw + gap), y + lift, cw, ch)
		_hits.append([r, i])
		var col: Color = it.get("color", TEAL)
		draw_rect(r, Color(0.03, 0.05, 0.06, 0.92))
		draw_rect(Rect2(r.position, Vector2(cw, 6)), Color(col, 0.9))
		draw_rect(r, Color(GOLD, 1.0) if sel else Color(col, 0.35), false, 2.5 if sel else 1.0)
		# 中间一个发光的菱形徽记
		var c := r.position + Vector2(cw * 0.5, 92)
		var s := 34.0 + (sin(_t * 4.0) * 3.0 if sel else 0.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), Color(col, 0.25))
		draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s)]), Color(col, 0.9), 2.0)
		var glyph := String(it.get("glyph", String(it.get("title", " ")).substr(0, 1)))
		draw_string(font, c + Vector2(-16, 12), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1, 0.95))
		var tag := String(it.get("tag", ""))
		if tag != "":
			draw_string(font, r.position + Vector2(0, 30), tag, HORIZONTAL_ALIGNMENT_CENTER, cw, 14, Color(col, 0.9))
		draw_string(font, r.position + Vector2(0, 168), String(it.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, cw, 26, Color(0.96, 0.93, 0.86) if en else Color(0.5, 0.5, 0.5))
		_wrap(String(it.get("desc", "")), r.position + Vector2(18, 206), cw - 36, 16, Color(0.75, 0.84, 0.84))
		var right := String(it.get("right", ""))
		if right != "":
			draw_string(font, r.position + Vector2(0, ch - 18), right, HORIZONTAL_ALIGNMENT_CENTER, cw, 17, Color(1.0, 0.85, 0.45))


func _wrap(text: String, pos: Vector2, width: float, size: int, col: Color) -> void:
	var line := ""
	var y := pos.y
	for ch in text:
		var t := line + ch
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size + 6
			line = ch
		else:
			line = t
	if line != "":
		draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## 父节点是 CanvasLayer，锚点铺满不生效（尺寸是 0，点不到）；每帧按视口大小摆好，触屏点击才收得到
func _fit() -> void:
	var vs := get_viewport_rect().size
	if size != vs:
		position = Vector2.ZERO
		size = vs
