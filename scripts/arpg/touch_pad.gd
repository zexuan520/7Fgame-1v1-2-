class_name TouchPad
extends Control
## 手机触屏操作：左半屏任意处按下出现浮动摇杆（移动），右下角一组圆形按键（斩、滚、突、光、终、药），
## 靠近可互动的人时多出“互”键，右上角“囊”（行囊）和“Ⅱ”（暂停菜单）。
## 按键直接 Input.action_press / action_release 玩家一的动作，所以角色、菜单代码都不用改。
## 菜单、对话框、标题画面打开时战斗按键全部收起，点击交给那些界面自己处理（它们在触屏模式下吃鼠标点击）。
## 竖着拿手机时盖一层“请横过来”的提示并暂停世界。

const GOLD := Color(0.86, 0.72, 0.42)
const TEAL := Color(0.35, 0.85, 0.85)
const PANEL := Color(0.03, 0.05, 0.06, 0.55)

## 触屏模式是否打开（别的界面据此改提示文字、接受点击）
static var active := false
static var I: TouchPad

var hero: Hero
var font: Font
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _btn_finger := {}         # 手指编号 -> 按键名
var _flash := {}              # 按键名 -> 剩余高亮时间
var _portrait := false
var _modal := false
var _t := 0.0
var _auto_t := 0.0            # 按住“斩”自动连砍：每隔一会儿松开一帧再按下


## 手机网页（安卓/苹果）或命令行 --touch 时打开；电脑上第一次摸屏幕也会打开
static func want() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios") \
		or OS.get_cmdline_user_args().has("--touch")


static func hint(keys: String, touch: String) -> String:
	return touch if active else keys


func _ready() -> void:
	I = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Feel.I.font if Feel.I != null else Game.font
	if want():
		enable()


func enable() -> void:
	if active:
		return
	active = true
	ArpgInput.drop_mouse()
	# 手机屏幕小：界面按 1024x576 排版（比 1280x720 大四分之一），3D 画面不受影响
	get_window().content_scale_size = Vector2i(1024, 576)
	visible = true


# ---------- 布局 ----------

func _buttons(vs: Vector2) -> Array:
	## [名字, 字, 圆心, 半径, 颜色]
	var a := Vector2(vs.x - 118, vs.y - 112)
	var out := [
		["attack", "斩", a, 66.0, GOLD],
		["roll", "滚", a + Vector2(-150, 38), 42.0, Color(0.75, 0.85, 0.9)],
		["dash", "突", a + Vector2(-128, -76), 40.0, TEAL],
		["beam", "光", a + Vector2(-56, -146), 40.0, Color(1.0, 0.85, 0.4)],
		["finish", "终", a + Vector2(44, -164), 40.0, Color(1.0, 0.35, 0.35)],
		["heal", "药", a + Vector2(-236, 52), 32.0, Color(0.4, 1.0, 0.6)],
	]
	if _npc_near():
		out.append(["interact", "互", a + Vector2(-250, -60), 40.0, Color(1.0, 0.95, 0.8)])
	return out


func _top_buttons(vs: Vector2) -> Array:
	return [["quit", "Ⅱ", Vector2(vs.x - 44, 112), 26.0, Color(0.85, 0.9, 0.9)],
		["bag", "囊", Vector2(vs.x - 104, 112), 26.0, Color(0.85, 0.9, 0.9)]]


func _npc_near() -> bool:
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if n is ArpgNpc and bool((n as ArpgNpc)._near):
			return true
	return false


func _modal_open() -> bool:
	var tree := get_tree()
	if not tree.get_nodes_in_group("dialog_box").is_empty() or not tree.get_nodes_in_group("modal_ui").is_empty():
		return true
	return false


func _hero_ok() -> bool:
	return is_instance_valid(hero) and hero.alive and hero.is_inside_tree()


# ---------- 输入 ----------

func _input(event: InputEvent) -> void:
	if not active:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			enable()
		else:
			return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_press(e.index, e.position)
		else:
			_release(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_stick_pos = d.position
			_apply_stick()


func _press(finger: int, p: Vector2) -> void:

	if _portrait or _modal:
		return
	var vs := get_viewport_rect().size
	for b: Array in _top_buttons(vs):
		if p.distance_to(b[2]) < float(b[3]) * 1.4:
			_tap_action(String(b[0]))
			get_viewport().set_input_as_handled()
			return
	if not _hero_ok():
		return
	# 先找最近的按键（手指粗，命中范围放大一些）
	var best: Array = []
	var best_d := INF
	for b: Array in _buttons(vs):
		var dd := p.distance_to(b[2])
		if dd < float(b[3]) * 1.3 and dd < best_d:
			best = b
			best_d = dd
	if not best.is_empty():
		var n := String(best[0])
		_btn_finger[finger] = n
		Input.action_press(ArpgInput.act(0, n))
		_flash[n] = 0.15
		get_viewport().set_input_as_handled()
		return
	if p.x < vs.x * 0.5 and _stick_finger < 0:
		_stick_finger = finger
		_stick_origin = p
		_stick_pos = p
		_apply_stick()
		get_viewport().set_input_as_handled()


func _release(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		_stick_pos = _stick_origin
		_apply_stick()
	if _btn_finger.has(finger):
		Input.action_release(ArpgInput.act(0, String(_btn_finger[finger])))
		_btn_finger.erase(finger)


## 暂停、行囊这类是“按一下”：按下这一帧，下一帧松开
func _tap_action(n: String) -> void:
	var an := "quit" if n == "quit" else ArpgInput.act(0, n)
	Input.action_press(an)
	_flash[n] = 0.15
	get_tree().create_timer(0.06, true, false, true).timeout.connect(func() -> void: Input.action_release(an))


const STICK_R := 70.0

func _apply_stick() -> void:
	var v := Vector2.ZERO
	if _stick_finger >= 0:
		v = (_stick_pos - _stick_origin) / STICK_R
		if v.length() > 1.0:
			# 手指拖出圈外时圈跟着走，回拉马上能反向
			_stick_origin = _stick_pos - v.normalized() * STICK_R
			v = v.normalized()
	for pair: Array in [["right", maxf(v.x, 0.0)], ["left", maxf(-v.x, 0.0)], ["down", maxf(v.y, 0.0)], ["up", maxf(-v.y, 0.0)]]:
		var an := ArpgInput.act(0, String(pair[0]))
		if float(pair[1]) > 0.05:
			Input.action_press(an, float(pair[1]))
		else:
			Input.action_release(an)


## 手机上连点很累：按住“斩”就自动打完四段连招
func _auto_attack(dt: float) -> void:
	var an := ArpgInput.act(0, "attack")
	if not _btn_finger.values().has("attack"):
		_auto_t = 0.0
		return
	_auto_t += dt
	if _auto_t >= 0.22:
		_auto_t = 0.0
		Input.action_release(an)
		get_tree().process_frame.connect(func() -> void:
			if _btn_finger.values().has("attack"):
				Input.action_press(an), CONNECT_ONE_SHOT)


func _release_all() -> void:
	for f: int in _btn_finger:
		Input.action_release(ArpgInput.act(0, String(_btn_finger[f])))
	_btn_finger.clear()
	if _stick_finger >= 0:
		_stick_finger = -1
		_apply_stick()


# ---------- 每帧 ----------

func _process(dt: float) -> void:
	if not active:
		return
	_t += dt
	var vs := get_viewport_rect().size
	var was_portrait := _portrait
	_portrait = vs.y > vs.x * 1.05
	mouse_filter = Control.MOUSE_FILTER_STOP if _portrait else Control.MOUSE_FILTER_IGNORE   # 竖屏时挡住下面菜单的点击
	var m := _modal_open()
	if (m and not _modal) or (_portrait and not was_portrait):
		_release_all()
	_modal = m
	if _portrait and Feel.I != null:
		Feel.I.world_pause = maxf(Feel.I.world_pause, 0.05)
	_auto_attack(dt)
	for k: String in _flash.keys():
		_flash[k] = float(_flash[k]) - dt
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var vs := get_viewport_rect().size
	if _portrait:
		_draw_rotate_hint(vs)
		return
	if _modal or not _hero_ok():
		return
	for b: Array in _top_buttons(vs):
		_draw_button(b, 1.0, false)
	# 摇杆：没按时在左下角画一个淡淡的提示圈
	var base := _stick_origin if _stick_finger >= 0 else Vector2(170, vs.y - 150)
	var knob := _stick_pos if _stick_finger >= 0 else base
	var alpha := 0.9 if _stick_finger >= 0 else 0.35
	draw_circle(base, STICK_R + 8, Color(0.02, 0.04, 0.05, 0.35 * alpha))
	draw_arc(base, STICK_R + 8, 0, TAU, 64, Color(GOLD, 0.5 * alpha), 2.0, true)
	for i in range(4):
		var a := i * PI / 2
		var p := base + Vector2(cos(a), sin(a)) * (STICK_R - 6)
		draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * 8, p + Vector2(cos(a + 2.2), sin(a + 2.2)) * 6, p + Vector2(cos(a - 2.2), sin(a - 2.2)) * 6]), Color(TEAL, 0.6 * alpha))
	draw_circle(knob, 30, Color(0.1, 0.14, 0.15, 0.75 * alpha))
	draw_arc(knob, 30, 0, TAU, 48, Color(GOLD, 0.9 * alpha), 2.5, true)
	for b: Array in _buttons(vs):
		var n := String(b[0])
		_draw_button(b, _ready_k(n), _btn_finger.values().has(n) or _flash.has(n))


func _ready_k(n: String) -> float:
	if not _hero_ok():
		return 1.0
	match n:
		"dash":
			return 1.0 - float(hero.cd["dash"]) / hero.dash_cd
		"finish":
			return 1.0 - float(hero.cd["finish"]) / hero.finish_cd
		"beam":
			return hero.energy / hero.max_energy
		"heal":
			return 1.0 if hero.gourds > 0 else 0.0
	return 1.0


func _draw_button(b: Array, k: float, down: bool) -> void:
	var c: Vector2 = b[2]
	var r: float = b[3]
	var col: Color = b[4]
	var ready := k >= 0.999
	draw_circle(c, r, Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.7) if down else PANEL)
	if not ready and k < 0.98:   # 剩一丝时扇形太窄，三角化会失败
		var pts := PackedVector2Array([c])
		var a0 := -PI / 2 + TAU * clampf(k, 0.0, 1.0)
		for s in range(25):
			var a := lerpf(a0, -PI / 2 + TAU, s / 24.0)
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 1))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
	draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(k, 0.0, 1.0), 48, Color(col, 0.95 if ready else 0.55), 3.0 if ready else 2.0, true)
	draw_arc(c, r + 4, 0, TAU, 48, Color(GOLD, 0.25), 1.0, true)
	var fs := int(r * 0.78)
	draw_string(font, c + Vector2(-r, fs * 0.36), String(b[1]), HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, col if ready else Color(0.55, 0.6, 0.6))
	if String(b[0]) == "heal" and _hero_ok():
		draw_string(font, c + Vector2(r * 0.35, r * 0.95), str(hero.gourds), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 1.0, 0.85))


func _draw_rotate_hint(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.02, 0.03, 0.94))
	var c := vs * 0.5 + Vector2(0, -120)
	# 一部手机从竖转到横
	var ang := -PI / 2 * clampf(fmod(_t, 2.4) / 1.2 - 0.3, 0.0, 1.0)
	var w := 70.0
	var h := 130.0
	var pts := PackedVector2Array()
	for p: Vector2 in [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h), Vector2(-w, -h)]:
		pts.append(c + p.rotated(ang) * 0.6)
	draw_polyline(pts, GOLD, 3.0, true)
	draw_circle(c + Vector2(0, h * 0.48).rotated(ang), 4, GOLD)
	var y := vs.y * 0.5 + 60
	draw_string(font, Vector2(0, y), "请把手机横过来", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 52, Color(0.96, 0.92, 0.84))
	draw_string(font, Vector2(0, y + 60), "横屏游玩，左手摇杆，右手出招", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30, Color(0.6, 0.9, 0.9))
	draw_string(font, Vector2(0, y + 104), "（锁定了屏幕方向的话，先在系统里打开自动旋转）", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 24, Color(0.6, 0.7, 0.7))
