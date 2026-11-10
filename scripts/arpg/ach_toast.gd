class_name AchToast
extends Control
## 成就解锁弹窗：从屏幕正上方滑下一块金边牌子，停 3 秒再收回去。几个一起解锁就排队一个个来。
## （2026-11-07 从正上方挪到右侧中段、改小：原来压在战场正上方，打着打着挡住前面的敌人）
## 不受世界暂停影响（菜单、对话框开着也会弹）。
## 2026-11-10：战斗中（场上还有活着的敌人）先攒着，清完再弹，最多压 40 秒；挪到正上方居中、再小一号
## （右侧中段在手机上正好压住技能键）。

const GOLD := Color(0.86, 0.72, 0.42)
const SHOW := 3.2
const SLIDE := 0.28

var font: Font
var _queue: Array = []       # [[名字, 说明], ...]
var _cur: Array = []
var _t := 0.0
var _held := 0.0
const HOLD_MAX := 40.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Feel.I.font if Feel.I != null else Game.font


func push(title: String, desc: String) -> void:
	_queue.append([title, desc])


func _process(dt: float) -> void:
	if _cur.is_empty():
		if _queue.is_empty():
			_held = 0.0
			return
		if _in_fight() and _held < HOLD_MAX:
			_held += dt
			return
		_held = 0.0
		_cur = _queue.pop_front()
		_t = 0.0
		Game.sfx("memory", -4.0)
	_t += dt
	if _t >= SHOW + SLIDE * 2.0:
		_cur = []
	queue_redraw()


func _in_fight() -> bool:
	if get_tree().paused:
		return false
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a != null and a.alive:
			return true
	return false


func _draw() -> void:
	if _cur.is_empty():
		return
	var vs := get_viewport_rect().size
	var w := minf(320.0, vs.x - 32.0)
	var h := 62.0
	# 进：从上往下滑；出：往上收
	var k := 1.0
	if _t < SLIDE:
		k = 1.0 - pow(1.0 - _t / SLIDE, 3.0)
	elif _t > SHOW + SLIDE:
		k = 1.0 - (_t - SHOW - SLIDE) / SLIDE
	k = clampf(k, 0.0, 1.0)
	var r := Rect2((vs.x - w) * 0.5, -h + (h + 14.0) * k, w, h)
	draw_rect(r, Color(0.02, 0.04, 0.05, 0.9 * k))
	draw_rect(r, Color(GOLD, k), false, 2.0)
	draw_rect(r.grow(-4), Color(GOLD, 0.25 * k), false, 1.0)
	# 左边一枚菱形印（亮一下）
	var c := r.position + Vector2(36, h * 0.5)
	var glow := 1.0 + 0.6 * maxf(0.0, 1.0 - _t / 0.6)
	var s := 15.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]),
		Color(GOLD.r * glow, GOLD.g * glow, GOLD.b * glow, k))
	s = 7.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), Color(0.05, 0.06, 0.07, k))
	var tx := r.position.x + 64
	draw_string(font, Vector2(tx, r.position.y + 17), "成就达成", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.35, 0.85, 0.85, k))
	draw_string(font, Vector2(tx, r.position.y + 38), String(_cur[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.86, 0.5, k))
	draw_string(font, Vector2(tx, r.position.y + 55), String(_cur[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 74, 12, Color(0.75, 0.82, 0.82, k))
