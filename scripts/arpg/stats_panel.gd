class_name ArpgStatsPanel
extends ArpgMenu
## 属性面板（暂停菜单“属性”、C 键、触屏右上角“属”；山门里也能开，看出发时的样子）。
## 四页：属性（最终数值 + 每一项的来源）/ 装备（兵器、五个部位、套装、道具）/ 心法与技能（心法、流派、技能分支、双修、连携）/
## 境况（难度、轮回规矩、天象、天赋、敌人词缀）。
## 最终数值直接读主角身上已经算好的（Hero.apply_stats 的结果），来源逐项读 ArpgState.stat_parts()，不另算一套。
## 左右（A / D）换页，上下（W / S）选行或翻看，空格 / Esc 返回；触屏点页签、点行，上下拖动翻看，右上角 ✕ 返回。

const TABS := ["属性", "装备", "心法与技能", "境况"]
const ROW_H := 34.0
const DIM := Color(0.5, 0.55, 0.55)
const GOOD := Color(0.55, 1.0, 0.65)
const BAD := Color(1.0, 0.5, 0.42)
const WHITE := Color(0.95, 0.92, 0.85)
const SOFT := Color(0.72, 0.8, 0.8)
const GROUP_COL := {"攻": Color(1.0, 0.45, 0.4), "守": Color(0.45, 0.95, 0.6), "身法": Color(0.4, 0.85, 0.95),
	"特效": Color(0.85, 0.6, 1.0), "收益": Color(1.0, 0.82, 0.4)}
const GROUP_ICON := {"攻": "attack", "守": "g_def", "身法": "roll", "特效": "g_fx", "收益": "g_gain"}

## stats 键 → [名字, 写法]。写法：pct 百分比带正负号 / neg 越少越好的百分比（冷却、价格，显示成减号）/ flat 整数 / sec 秒 / lv 级
const KEYS := {
	"hp": ["生命", "flat"], "atk": ["伤害", "pct"], "crit": ["会心率", "pct"], "crit_dmg": ["会心伤害", "pct"],
	"dmg_taken": ["受伤", "pct"], "easy": ["受伤", "neg"], "taken_extra": ["受伤", "pct"], "move": ["移速", "pct"], "dash_cd": ["突进冷却", "neg"],
	"finish_cd": ["终结冷却", "neg"], "iframes": ["翻滚无敌", "sec"], "roll_far": ["翻滚距离", "pct"], "energy": ["气力获取", "pct"],
	"hurt_energy": ["挨打回气", "flat"], "beam": ["光束斩伤害", "pct"], "finish": ["终结技伤害", "pct"], "bleed": ["出血层数", "flat"],
	"bleed_dmg": ["出血伤害", "pct"], "lifesteal": ["吸血", "pct1"], "kill_heal": ["斩杀回血", "flat"], "gourds": ["药葫芦", "flat"],
	"gourd_heal": ["每口回复", "pct"], "revive": ["倒下再起", "flat"], "thorns": ["反伤", "pct"], "rage": ["半血以下伤害", "pct"],
	"roll_bolt": ["翻滚落雷伤害", "flat"], "crit_bolt": ["会心落雷几率", "pct"], "fire_proc": ["命中炸火几率", "pct"],
	"execute": ["残血敌人增伤", "pct"], "roll_cd": ["翻滚减突进冷却", "sec"], "beam_heal": ["光束每敌回血", "flat"],
	"fire_dmg": ["火团伤害", "pct"], "kill_fire": ["斩杀爆燃几率", "pct"],
	"coin": ["铜钱", "pct"], "jade": ["魂玉", "pct"], "discount": ["商人价格", "neg"], "keep": ["身死魂玉带回", "pct"],
	"start_coins": ["开局铜钱", "flat"], "insight": ["开局天赋点", "flat"], "xp": ["悟道", "pct"],
	"sk_echo": ["连闪", "lv"], "sk_drink": ["饮血", "lv"], "sk_lotus": ["血莲", "lv"], "sk_split": ["裂空", "lv"],
}

var hero: Hero
var state: ArpgState
var in_hub := false
var tab := 0
var _rows: Array = []        # 属性页的每一行
var _parts: Array = []       # ArpgState.stat_parts()
var _cols: Array = []        # 其他页：[左列条目, 右列条目]
var _scroll := 0.0
var _scroll_max := 0.0
var _row_top := 0            # 属性页列表从第几行开始画
var _drag_y := -1.0
var _drag_moved := 0.0


func _ready() -> void:
	super._ready()
	_build()


func _build() -> void:
	_parts = state.stat_parts()
	_rows = _stat_rows()
	index = clampi(index, 0, maxi(_rows.size() - 1, 0))
	_scroll = 0.0
	match tab:
		1:
			_cols = _gear_cols()
		2:
			_cols = _build_cols()
		3:
			_cols = _world_cols()
		_:
			_cols = []


func set_tab(t: int) -> void:
	tab = (t + TABS.size()) % TABS.size()
	_build()
	Game.sfx("ui_back", -12.0)


# ---------- 输入 ----------

func _process(dt: float) -> void:
	if Zaohua.is_platform_paused():
		return
	_t += dt
	_fit()
	if Feel.I != null:
		Feel.I.world_pause = maxf(Feel.I.world_pause, 0.05)
	_cool -= dt
	queue_redraw()
	if _cool > 0.0:
		return
	if _act("left"):
		set_tab(tab - 1)
	elif _act("right"):
		set_tab(tab + 1)
	var dy := 0
	if _act("up"):
		dy = -1
	elif _act("down"):
		dy = 1
	if dy != 0:
		if tab == 0:
			index = clampi(index + dy, 0, _rows.size() - 1)
		else:
			_scroll = clampf(_scroll + dy * 90.0, 0.0, _scroll_max)
		Game.sfx("ui_back", -14.0)
	if _act("roll") or _act("bag") or _act("stats") or Input.is_action_just_pressed("ui_cancel"):
		cancelled.emit()


## 鼠标和触屏都收：点页签、点行、拖动翻看、滚轮
func _gui_input(event: InputEvent) -> void:
	if Zaohua.is_platform_paused() or _cool > 0.0:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		accept_event()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var d := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
				if tab == 0:
					index = clampi(index + d, 0, _rows.size() - 1)
				else:
					_scroll = clampf(_scroll + d * 60.0, 0.0, _scroll_max)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag_y = mb.position.y
			_drag_moved = 0.0
			return
		# 松手：没怎么拖动才算点
		var was_drag := _drag_moved > 14.0
		_drag_y = -1.0
		if was_drag:
			return
		for h: Array in _hits:
			if not (h[0] as Rect2).grow(4).has_point(mb.position):
				continue
			var i := int(h[1])
			if i == -1:
				cancelled.emit()
			elif i <= -10:
				set_tab(-10 - i)
			elif tab == 0:
				index = i
				Game.sfx("ui_back", -14.0)
			return
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drag_y >= 0.0 and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		accept_event()
		var d := mm.position.y - _drag_y
		_drag_y = mm.position.y
		_drag_moved += absf(d)
		if tab == 0:
			_row_drag += d
			while _row_drag > ROW_H * 0.8:
				_row_drag -= ROW_H * 0.8
				index = maxi(index - 1, 0)
			while _row_drag < -ROW_H * 0.8:
				_row_drag += ROW_H * 0.8
				index = mini(index + 1, _rows.size() - 1)
		else:
			_scroll = clampf(_scroll - d, 0.0, _scroll_max)


var _row_drag := 0.0


# ---------- 画 ----------

func _draw() -> void:
	var vs := get_viewport_rect().size
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.02, 0.03, 0.82))
	var w := minf(vs.x - 64.0, 1180.0)
	var x0 := (vs.x - w) * 0.5
	draw_string(font, Vector2(0, 50), "属性" if not in_hub else "属性 · 出发时", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 32, WHITE)
	draw_string(font, Vector2(0, 80), _headline(), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(0.7, 0.88, 0.88))
	# 页签
	var tw := 168.0
	var tx := (vs.x - tw * TABS.size() - 10.0 * (TABS.size() - 1)) * 0.5
	for i in range(TABS.size()):
		var r := Rect2(tx + i * (tw + 10.0), 96, tw, 42)
		var sel := i == tab
		draw_rect(r, Color(0.05, 0.09, 0.1, 0.95) if sel else Color(0.03, 0.05, 0.06, 0.8))
		draw_rect(r, Color(GOLD, 0.95) if sel else Color(TEAL, 0.3), false, 2.0 if sel else 1.0)
		if sel:
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), GOLD)
		draw_string(font, r.position + Vector2(0, 29), TABS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, WHITE if sel else SOFT)
		_hits.append([r, -10 - i])
	var area := Rect2(x0, 152, w, vs.y - 152 - 52)
	if tab == 0:
		_draw_stats(area)
	else:
		_draw_cols(area)
	# 返回钮（鼠标、触屏都能点）
	var br := Rect2(vs.x - 150, 24, 126, 50)
	draw_rect(br, Color(0.03, 0.06, 0.07, 0.85))
	draw_rect(br, Color(GOLD, 0.8), false, 1.5)
	draw_string(font, br.position + Vector2(0, 34), "✕ 返回", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 22, WHITE)
	_hits.append([br, -1])
	var foot := TouchPad.hint("A / D 换页　W / S %s　空格 返回" % ("选一行看来源" if tab == 0 else "翻看"),
		"点上面的页签换页　%s　右上角 ✕ 返回" % ("点一行看来源" if tab == 0 else "上下拖动翻看"))
	draw_string(font, Vector2(0, vs.y - 18), foot, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 15, Color(0.6, 0.7, 0.7))


func _headline() -> String:
	if in_hub:
		return "兵器架的兵器、天赋、%s、%s难度。路上捡的装备和心法出发后才有" % [ArpgCycle.label(state.cycle), ArpgState.DIFF_NAMES[ArpgState.difficulty()]]
	var parts := ["%s 第 %d 层" % [ArpgState.ACT_NAMES.get(state.act, ""), state.gfloor() + 1],
		"悟道 %s重" % Hud3D._cn(state.level), "天赋点 %d" % state.points, "铜钱 %d" % state.coins, "魂玉 %d" % state.jade]
	if state.cycle > 0:
		parts.append(ArpgCycle.label(state.cycle))
	return "　·　".join(parts)


## 属性页：左边一行一项最终数值，右边是选中这一项的来源明细
func _draw_stats(area: Rect2) -> void:
	var lw := floorf(area.size.x * 0.54)
	var rx := area.position.x + lw + 20.0
	var rw := area.size.x - lw - 20.0
	var per := maxi(1, int(area.size.y / ROW_H))
	if index < _row_top:
		_row_top = index
	elif index >= _row_top + per:
		_row_top = index - per + 1
	_row_top = clampi(_row_top, 0, maxi(0, _rows.size() - per))
	var y := area.position.y
	var last_group := ""
	if _row_top > 0:
		last_group = String(_rows[_row_top - 1]["group"])
	for i in range(_row_top, mini(_rows.size(), _row_top + per)):
		var row: Dictionary = _rows[i]
		var r := Rect2(area.position.x, y, lw, ROW_H - 4)
		var sel := i == index
		_hits.append([r, i])
		var g := String(row["group"])
		var gc: Color = GROUP_COL.get(g, TEAL)
		# 2026-11-10 第二档 A3：每组一种颜色，左边一道色条；组的第一行画组图标和组名，一眼分得出攻、守、身法
		draw_rect(r, Color(0.05, 0.09, 0.1, 0.92) if sel else Color(gc.r * 0.08, gc.g * 0.08, gc.b * 0.08, 0.6))
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(gc, 0.8))
		if sel:
			draw_rect(r, GOLD, false, 1.5)
		if g != last_group:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(gc, 0.45))
			var gi := Hud3D.icon(String(GROUP_ICON.get(g, "")))
			if gi != null:
				draw_texture_rect(gi, Rect2(r.position + Vector2(9, 5), Vector2(20, 20)), false, gc)
			else:
				draw_string(font, r.position + Vector2(8, 21), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(gc, 0.85))
			last_group = g
		# 比基础值好多少：数值下面一道细条（绿是变好、红是变差，满格 = 翻一倍）
		if row.has("num") and row.has("base_num"):
			var bn := float(row["base_num"])
			var dv := (float(row["num"]) - bn) * float(row.get("dir", 1.0))
			var frac := clampf(absf(dv) / maxf(absf(bn), 1.0 if bn == 0.0 else 0.0001), 0.0, 1.0)
			if frac > 0.005:
				var bw := 150.0 * frac
				draw_rect(Rect2(r.position.x + lw - 12 - bw, r.position.y + r.size.y - 4, bw, 2), Color(GOOD if dv > 0.0 else BAD, 0.7))
		draw_string(font, r.position + Vector2(44, 22), String(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WHITE)
		var base := String(row.get("base_txt", ""))
		if base != "":
			draw_string(font, r.position + Vector2(178, 22), "基础 " + base, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
		draw_string(font, r.position + Vector2(lw - 330, 22), String(row["value"]), HORIZONTAL_ALIGNMENT_RIGHT, 318, 19, _row_color(row))
		y += ROW_H
	# 滚动条
	if _rows.size() > per:
		var bh := area.size.y * float(per) / _rows.size()
		var by := area.position.y + (area.size.y - bh) * float(_row_top) / maxf(1.0, _rows.size() - per)
		draw_rect(Rect2(area.position.x + lw + 6, by, 3, bh), Color(GOLD, 0.5))
	if _rows.is_empty():
		return
	_draw_detail(_rows[index], Rect2(rx, area.position.y, rw, area.size.y))


func _row_color(row: Dictionary) -> Color:
	if not row.has("num") or not row.has("base_num"):
		return WHITE
	var d := (float(row["num"]) - float(row["base_num"])) * float(row.get("dir", 1.0))
	if absf(d) < 0.0001:
		return WHITE
	return GOOD if d > 0.0 else BAD


func _draw_detail(row: Dictionary, r: Rect2) -> void:
	draw_rect(r, Color(0.03, 0.05, 0.06, 0.8))
	draw_rect(r, Color(TEAL, 0.3), false, 1.0)
	var x := r.position.x + 18.0
	var w := r.size.x - 36.0
	var y := r.position.y + 34.0
	draw_string(font, Vector2(x, y), String(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, WHITE)
	draw_string(font, Vector2(x, y), String(row["value"]), HORIZONTAL_ALIGNMENT_RIGHT, w, 22, _row_color(row))
	y += 26.0
	if String(row.get("base_txt", "")) != "":
		draw_string(font, Vector2(x, y), "基础 " + String(row["base_txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DIM)
		y += 8.0
	draw_line(Vector2(x, y + 4), Vector2(x + w, y + 4), Color(GOLD, 0.5), 1.0)
	y += 30.0
	var lines := _sources(row["keys"])
	var bottom := r.end.y - 12.0
	if lines.is_empty():
		draw_string(font, Vector2(x, y), "没有任何加成，都是基础值", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DIM)
		y += 28.0
	for ln: Array in lines:
		if y > bottom - 60.0:
			draw_string(font, Vector2(x, y), "……还有 %d 项" % (lines.size() - lines.find(ln)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
			y += 24.0
			break
		draw_string(font, Vector2(x, y), String(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.62, 16, _kind_color(String(ln[2])))
		draw_string(font, Vector2(x, y), String(ln[1]), HORIZONTAL_ALIGNMENT_RIGHT, w, 16, WHITE)
		y += 25.0
	var note := String(row.get("note", ""))
	if note != "" and y < bottom - 20.0:
		y += 8.0
		for l: String in _lines(note, w, 15):
			if y > bottom:
				break
			draw_string(font, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SOFT)
			y += 21.0


const KIND_COLORS := {"角色": Color(1.0, 0.9, 0.7), "天赋": Color(0.95, 0.75, 0.5), "信物": Color(1.0, 0.8, 0.6), "兵器": Color(0.6, 1.0, 0.95), "装备": Color(0.6, 0.8, 1.0), "套装": Color(0.65, 0.85, 1.0),
	"心法": Color(1.0, 0.85, 0.5), "奇物": Color(1.0, 0.62, 0.3), "境况": Color(0.85, 0.9, 0.75), "轮回": Color(0.85, 0.6, 1.0), "技能": Color(0.6, 1.0, 1.0), "难度": Color(0.75, 0.8, 0.8)}


func _kind_color(k: String) -> Color:
	return KIND_COLORS.get(k, SOFT)


## 这一行的数值都从哪来：[[来源名, 加了多少, 分类]...]
func _sources(keys: Array) -> Array:
	var out := []
	for p: Dictionary in _parts:
		var bits := []
		for k: String in keys:
			if (p["st"] as Dictionary).has(k) and absf(float(p["st"][k])) > 0.0001:
				bits.append(fmt_key(k, float(p["st"][k]), keys.size() > 1))
		if not bits.is_empty():
			out.append([p["src"], "、".join(bits), p["kind"]])
	return out


## 一个 stats 键的数值写成字：伤害 +12% / 生命 +20 / 突进冷却 -15%
static func fmt_key(k: String, v: float, with_name: bool = false) -> String:
	var d: Array = KEYS.get(k, [k, "pct"])
	var s := ""
	match String(d[1]):
		"flat":
			s = "%+d" % int(round(v))
		"sec":
			s = "%+.2f 秒" % v
		"neg":
			s = "%+d%%" % int(round(-v * 100.0))
		"pct1":
			s = "%+.1f%%" % (v * 100.0)
		"lv":
			s = "%d 级" % int(v)
		_:
			s = "%+d%%" % int(round(v * 100.0))
	return (String(d[0]) + " " + s) if with_name else s


## 装备 / 心法 / 境况页：两列条目，整体上下翻
func _draw_cols(area: Rect2) -> void:
	var gap := 24.0
	var cw := (area.size.x - gap) * 0.5
	var max_h := 0.0
	for ci in range(_cols.size()):
		var x := area.position.x + ci * (cw + gap)
		var y := area.position.y - _scroll
		for e: Dictionary in _cols[ci]:
			y = _draw_entry(e, x, y, cw, area)
		max_h = maxf(max_h, y + _scroll - area.position.y)
	_scroll_max = maxf(0.0, max_h - area.size.y + 10.0)
	_scroll = clampf(_scroll, 0.0, _scroll_max)
	if _scroll_max > 0.0:
		var bh := area.size.y * area.size.y / (area.size.y + _scroll_max)
		var by := area.position.y + (area.size.y - bh) * _scroll / _scroll_max
		draw_rect(Rect2(area.end.x + 8, by, 3, bh), Color(GOLD, 0.5))
		if _scroll < _scroll_max - 1.0:
			draw_string(font, Vector2(area.position.x, area.end.y + 14), "▼", HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 14, Color(GOLD, 0.6 + 0.3 * sin(_t * 5.0)))


## 一个条目：{"head"} 小标题；或 {"title", "tag", "right", "desc", "color", "on"}。超出区域的行不画
func _draw_entry(e: Dictionary, x: float, y: float, w: float, area: Rect2) -> float:
	var vis := func(yy: float, h: float) -> bool: return yy - h >= area.position.y - 2.0 and yy <= area.end.y
	if e.has("head"):
		y += 10.0
		if vis.call(y + 18.0, 18.0):
			draw_string(font, Vector2(x, y + 18.0), String(e["head"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)
			draw_line(Vector2(x, y + 26.0), Vector2(x + w, y + 26.0), Color(GOLD, 0.35), 1.0)
		return y + 36.0
	var on := bool(e.get("on", true))
	var col: Color = e.get("color", WHITE)
	if not on:
		col = Color(col.lerp(Color(0.5, 0.5, 0.5), 0.6), 0.85)
	var desc := _lines(String(e.get("desc", "")), w - 24.0, 15)
	var h := 34.0 + desc.size() * 20.0
	var top := maxf(y, area.position.y)
	var bot := minf(y + h - 6.0, area.end.y)
	if bot > top:
		draw_rect(Rect2(x, top, w, bot - top), Color(0.03, 0.05, 0.06, 0.72 if on else 0.4))
		draw_rect(Rect2(x, top, 3, bot - top), Color(col, 0.9 if on else 0.35))
	var tx := x + 14.0
	if vis.call(y + 24.0, 20.0):
		var tag := String(e.get("tag", ""))
		if tag != "":
			draw_string(font, Vector2(tx, y + 23.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(e.get("tag_color", TEAL), 0.9 if on else 0.45))
			tx += font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
		draw_string(font, Vector2(tx, y + 24.0), String(e.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x) - 130.0, 19, col)
		var right := String(e.get("right", ""))
		if right != "":
			draw_string(font, Vector2(x + w - 200.0, y + 23.0), right, HORIZONTAL_ALIGNMENT_RIGHT, 188.0, 15, Color(1.0, 0.85, 0.45) if on else DIM)
	var ly := y + 46.0
	for l: String in desc:
		if vis.call(ly, 15.0):
			draw_string(font, Vector2(x + 14.0, ly), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SOFT if on else DIM)
		ly += 20.0
	return y + h + 2.0


## 按宽度折行（中文按字折），\n 强制换行
func _lines(text: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	if text == "":
		return out
	for para: String in text.split("\n"):
		var line := ""
		for ch in para:
			var t := line + ch
			if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = ch
			else:
				line = t
		out.append(line)
	return out


# ---------- 属性页的行 ----------

func _row(group: String, label: String, value: String, keys: Array, extra: Dictionary = {}) -> Dictionary:
	var r := {"group": group, "label": label, "value": value, "keys": keys}
	r.merge(extra)
	return r


func _stat_rows() -> Array:
	var h := hero
	var st := state.stats()
	var wd := ArpgData.weapon(state.weapon)
	var rows := []
	# 攻
	var wdm := float(wd["dmg"])
	var dn := "＝(1 + 伤害加成) × 兵器本身 ×%.2f（%s）。\n另乘：招式本身伤害、会心、磨刀石 ×1.35" % [wdm, wd["name"]]
	if h.duo.has("budong"):
		dn += "、不动明王（生命七成以上 ×1.2）"
	if h.rage > 0.0:
		dn += "、半血以下 ×%.2f" % (1.0 + h.rage)
	if h.set_oni:
		dn += "、鬼面三件（残血 ×1.3）"
	match state.weapon:
		"twin":
			dn += "、双刀刀势（每层 +4%，最多 10 层）"
		"spear":
			dn += "、枪尖（2.4 米外 ×1.25）"
	rows.append(_row("攻", "伤害倍率", "×%.2f" % h.dmg_mult, ["atk"], {"num": h.dmg_mult, "base_num": wdm, "base_txt": "×%.2f" % wdm, "note": dn}))
	var cr := 0.12 + h.crit_bonus
	var cn := "每一刀本身 12%（个别招式不同）。"
	if state.weapon == "dagger":
		cn += "短匕背刺必定会心。"
	if state.weapon == "crossbow":
		cn += "连弩翻滚后第一箭必定会心。"
	if h.set_wind:
		cn += "御风：翻滚后 1.2 秒内下一刀必定会心。"
	rows.append(_row("攻", "会心率", "%d%%" % int(round(minf(cr, 1.0) * 100.0)), ["crit"], {"num": cr, "base_num": 0.12, "base_txt": "12%", "note": cn}))
	rows.append(_row("攻", "会心伤害", "×%.2f" % h.crit_mult, ["crit_dmg"], {"num": h.crit_mult, "base_num": 1.8, "base_txt": "×1.80",
		"note": "会心一击的伤害倍数。" + ("修罗场：会心的余劲斩到身边其他敌人（40%）。" if h.set_shura else "")}))
	rows.append(_row("攻", "光束斩", "×%.2f · 满气 %d" % [h.beam_mult, int(h.beam_cost)], ["beam", "sk_split"], {"num": h.beam_mult, "base_num": 1.0, "base_txt": "×1.00 · 满气 100",
		"note": "光束斩伤害倍数，气力攒满放一次。" + ("天光：返还 40% 气力，命中叠 3 层出血。" if h.set_light else "")}))
	rows.append(_row("攻", "终结技（血爆）", "×%.2f" % h.finish_mult, ["finish"], {"num": h.finish_mult, "base_num": 1.0, "base_txt": "×1.00", "note": "引爆敌人身上的出血。"}))
	var bl := "+%d 层 · 伤害 ×%.2f" % [h.bleed_bonus, h.bleed_dmg] if h.bleed_bonus > 0 else "伤害 ×%.2f" % h.bleed_dmg
	rows.append(_row("攻", "出血", bl, ["bleed", "bleed_dmg"], {"num": h.bleed_dmg + h.bleed_bonus * 0.2, "base_num": 1.0, "base_txt": "×1.00",
		"note": "带出血的招式每次多叠的层数和出血伤害倍数。" + ("血涌：叠到 6 层自己炸开。" if h.set_blood else "") + ("血刃：会心多叠 2 层。" if h.duo.has("xueren") else "")}))
	# 守
	rows.append(_row("守", "生命", "%d / %d" % [int(ceil(h.hp)), int(h.max_hp)], ["hp"], {"num": h.max_hp, "base_num": Hero.BASE_HP, "base_txt": "%d" % int(Hero.BASE_HP),
		"note": "生命上限。" + ("不动三件：挨打时震开一圈反震。" if h.set_iron else "") + ("金身：每 10 秒凝一层金光，挡掉下一次伤害。" if h.set_guard else "")}))
	var tm := h.taken_mult
	var tn := "挨打时伤害乘这个数（加成后最低 ×0.30，轮回八再另乘 1.15，游历难度再另乘 0.65）。"
	if state.weapon == "greatsword":
		tn += "大剑出刀时再 ×0.85。"
	if h.duo.has("mingjing"):
		tn += "明镜：光束斩后 4 秒再 ×0.6。"
	rows.append(_row("守", "受到伤害", "×%.2f（%s %d%%）" % [tm, "减伤" if tm <= 1.0 else "多受", int(round(absf(1.0 - tm) * 100.0))], ["dmg_taken", "taken_extra", "easy"],
		{"num": tm, "base_num": 1.0, "dir": -1.0, "base_txt": "×1.00", "note": tn}))
	var ls := "%.1f%%" % (h.lifesteal * 100.0)
	if h.kill_heal > 0.0:
		ls += " · 斩杀回 %d" % int(h.kill_heal)
	rows.append(_row("守", "吸血", ls, ["lifesteal", "kill_heal"], {"num": h.lifesteal + h.kill_heal * 0.01, "base_num": 0.0, "base_txt": "0",
		"note": "命中回复伤害的这么多生命（最多 %d%%）。" % int(round(Hero.LIFESTEAL_MAX * 100.0)) + ("饮血：引爆的每层出血回血。" if h.skr("drink") > 0 else "")}))
	rows.append(_row("守", "药葫芦", "%d / %d 个 · 每口 %d%%" % [h.gourds, h.max_gourds, int(round(h.gourd_heal * 100.0))], ["gourds", "gourd_heal"],
		{"num": h.max_gourds + h.gourd_heal, "base_num": 3.4, "base_txt": "3 个 · 40%", "note": "歇脚的土地庙、游商能补满。最多 %d 个。" % Hero.GOURDS_MAX + ("轮回七起回血少三成。" if state.cycle >= 7 else "")}))
	rows.append(_row("守", "倒下再起", "%d 次" % h.revives, ["revive"], {"num": h.revives, "base_num": 0, "base_txt": "0", "note": "倒下时以 50% 生命站起来。"}))
	# 身法
	var mv := h.move_speed / Hero.BASE_MOVE - 1.0
	rows.append(_row("身法", "移速", "%.1f 米/秒（%+d%%）" % [h.move_speed, int(round(mv * 100.0))], ["move"], {"num": h.move_speed, "base_num": Hero.BASE_MOVE, "base_txt": "%.1f" % Hero.BASE_MOVE,
		"note": "加成最多 +%d%%。" % int(round((Hero.MOVE_MAX - 1.0) * 100.0))}))
	rows.append(_row("身法", "翻滚", "无敌 %.2f 秒 · %.1f 米" % [h.roll_iframes, h.roll_dist], ["iframes", "roll_far"],
		{"num": h.roll_iframes + h.roll_dist * 0.01, "base_num": Hero.BASE_IFRAMES + Hero.BASE_ROLL_DIST * 0.01, "base_txt": "%.2f 秒 · %.1f 米" % [Hero.BASE_IFRAMES, Hero.BASE_ROLL_DIST],
		"note": "翻滚一次 0.4 秒，无敌最多 %.2f 秒（再多就能一直滚着不挨打了）。" % Hero.ROLL_IFRAMES_MAX}))
	rows.append(_row("身法", "突进斩冷却", "%.1f 秒" % h.dash_cd, ["dash_cd", "sk_echo"], {"num": h.dash_cd, "base_num": Hero.BASE_DASH_CD, "dir": -1.0, "base_txt": "%.1f 秒" % Hero.BASE_DASH_CD,
		"note": "加成最多缩短七成；技能分支“连闪”二级再 ×0.85、三级 ×0.7。" + ("御风：每次翻滚再 -0.8 秒。" if h.set_wind else "")}))
	rows.append(_row("身法", "终结技冷却", "%.1f 秒" % h.finish_cd, ["finish_cd", "sk_drink", "sk_lotus"], {"num": h.finish_cd, "base_num": Hero.BASE_FINISH_CD, "dir": -1.0, "base_txt": "%.1f 秒" % Hero.BASE_FINISH_CD,
		"note": "加成最多缩短七成；“饮血”每级再 -10%，“血莲”三级再 ×0.85。"}))
	var art := h.art_id()
	if art != "":
		rows.append(_row("身法", "秘技冷却", "%s %.0f 秒" % [ArpgSkills.branch(art)["name"], h.art_cd], [], {"note": "秘技四选一，学了哪种就是哪种的冷却。"}))
	rows.append(_row("身法", "气力获取", "×%.2f" % h.energy_mult, ["energy", "hurt_energy"], {"num": h.energy_mult, "base_num": 1.0, "base_txt": "×1.00",
		"note": "砍中敌人回气，满了放光束斩。最多 ×%.1f。" % Hero.ENERGY_MAX + ("棍扫：每一棍多回 3 点。" if state.weapon == "staff" else "") + ("挨打回 %d 点气。" % int(h.hurt_energy) if h.hurt_energy > 0.0 else "")}))
	# 装备特效（有才列）
	var fx := [["thorns", "反伤", "%d%%", "近身挨打时把 %d%% 的伤害弹回去", h.thorns * 100.0],
		["rage", "狼首", "+%d%%", "生命低于一半时伤害 +%d%%", h.rage * 100.0],
		["roll_bolt", "翻滚落雷", "伤害 %d", "翻滚落地放一圈雷，伤害 %d", h.roll_bolt],
		["crit_bolt", "会心落雷", "%d%%", "会心时 %d%% 机会引一道落雷", h.crit_bolt * 100.0],
		["fire_proc", "命中炸火", "%d%%", "命中时 %d%% 机会在敌人身上炸开一团火", h.fire_proc * 100.0]]
	for f: Array in fx:
		if float(f[4]) > 0.0:
			var v := int(round(float(f[4])))
			rows.append(_row("特效", String(f[1]), String(f[2]) % v, [f[0]], {"note": (String(f[3]) % v) + "。"}))
	if h.set_thunder:
		rows.append(_row("特效", "雷殛三件", "每 5 次命中一道落雷", [], {"note": "每 5 次命中引一道落雷（伤害 30）。"}))
	# 收益
	rows.append(_row("收益", "铜钱", "%+d%%" % int(round(ArpgData.stat(st, "coin") * 100.0)), ["coin"], {"num": ArpgData.stat(st, "coin"), "base_num": 0.0, "base_txt": "+0%"}))
	rows.append(_row("收益", "魂玉", "%+d%%" % int(round(ArpgData.stat(st, "jade") * 100.0)), ["jade"], {"num": ArpgData.stat(st, "jade"), "base_num": 0.0, "base_txt": "+0%"}))
	var disc := 1.0 - ArpgData.stat(st, "discount")
	rows.append(_row("收益", "商人价格", "×%.2f" % disc, ["discount"], {"num": disc, "base_num": 1.0, "dir": -1.0, "base_txt": "×1.00"}))
	var keep := 0.6 + ArpgData.stat(st, "keep")
	rows.append(_row("收益", "身死带回魂玉", "%d%%" % int(round(keep * 100.0)), ["keep"], {"num": keep, "base_num": 0.6, "base_txt": "60%", "note": "倒下（或放弃这一局）时魂玉带回这么多，打通全拿。"}))
	var xpv := "第 %s 重" % Hud3D._cn(state.level)
	if state.level < ArpgSkills.MAX_LEVEL and not in_hub:
		xpv += " · %d / %d 悟" % [state.xp, ArpgSkills.need(state.level)]
	rows.append(_row("收益", "悟道", xpv, ["xp", "insight"], {"note": "斩敌得悟，攒满升一重，每重 1 个天赋点（技能分支用）。最高 %d 重。" % ArpgSkills.MAX_LEVEL}))
	return rows


# ---------- 其他页的条目 ----------

func _gear_cols() -> Array:
	var a := [{"head": "兵器"}]
	for k in range(2):
		var it: Dictionary = state.arms[k]
		var nm := "主手" if k == 0 else "副手"
		if it.is_empty():
			a.append({"tag": nm, "title": "空着", "on": false,
				"desc": "路上捡到兵器会挂到副手，%s换手" % TouchPad.hint(ArpgInput.key_name(0, "swap") + " 键", "触屏“换”键") if k == 1 else ""})
			continue
		var wd := ArpgData.weapon(String(it["base"]))
		a.append({"tag": nm, "title": String(it["name"]), "color": ArpgGear.color(it), "right": ArpgGear.RARITY_NAMES[int(it["rarity"])] + "品",
			"desc": "%s\n%s" % [wd["desc"], ArpgGear.describe(it)]})
	a.append({"head": "装备"})
	for slot: String in ["armor", "helm", "boots", "charm", "charm2"]:
		var it: Dictionary = state.gear.get(slot, {})
		var sn := String(ArpgData.SLOT_NAMES[slot])
		if slot == "charm2" and not ArpgState.charm2_open():
			a.append({"tag": sn, "title": "没开", "on": false, "desc": "山门兵器架花魂玉开“双佩”，就能戴第二个护符"})
		elif it.is_empty():
			a.append({"tag": sn, "title": "空着", "on": false, "desc": "出发后路上捡、游商买" if in_hub else ""})
		else:
			a.append({"tag": sn, "title": String(it.get("name", ArpgData.gear(String(it.get("base", ""))).get("name", ""))), "color": ArpgGear.color(it), "right": ArpgGear.RARITY_NAMES[int(it["rarity"])] + "品",
				"desc": ArpgGear.describe(it)})
	var b := [{"head": "套装"}]
	var gsc := ArpgArms.set_counts(state.gear)
	for sid: String in ArpgArms.GEAR_SETS:
		var gs: Dictionary = ArpgArms.GEAR_SETS[sid]
		var n := int(gsc.get(sid, 0))
		b.append({"title": "「%s」" % gs["name"], "right": "%d / 3 件" % mini(n, 3), "color": gs["color"], "on": n >= 2,
			"desc": "%s 两件：%s\n%s 三件：%s\n%s" % ["●" if n >= 2 else "○", gs["d2"], "●" if n >= 3 else "○", gs["d3"], gs["pieces"]]})
	b.append({"head": "道具（最多 %d 种）" % ArpgArms.ITEM_KINDS})
	if state.props.is_empty():
		b.append({"title": "没有道具", "on": false, "desc": "游商有卖，宝箱、精英也会掉"})
	for i in range(state.props.size()):
		var p: Dictionary = state.props[i]
		var idef := ArpgArms.item(String(p["id"]))
		b.append({"title": "%s ×%d" % [idef["name"], int(p["n"])], "color": idef.get("color", WHITE), "right": "当前选中" if i == state.prop_sel else "",
			"desc": String(idef["desc"])})
	if not in_hub:
		b.append({"title": "行囊", "right": "%d / %d 件" % [state.bag.size(), ArpgGear.BAG_MAX], "desc": "%s打开行囊换装备、合成" % TouchPad.hint(ArpgInput.key_name(0, "bag") + " 键", "右上角“囊”")})
	return [a, b]


func _build_cols() -> Array:
	var a := [{"head": "心法（%d 个）" % state.boons.size()}]
	var cnt := {}
	var order := []
	for bid: String in state.boons:
		if not cnt.has(bid):
			order.append(bid)
		cnt[bid] = int(cnt.get(bid, 0)) + 1
	if order.is_empty():
		a.append({"title": "还没有", "on": false, "desc": "清完战斗房三选一，游商也卖"})
	for bid: String in order:
		var bd := ArpgData.boon(bid)
		var sc := String(bd.get("school", ""))
		a.append({"tag": sc, "tag_color": ArpgData.SCHOOL_COLORS.get(sc, TEAL), "title": String(bd.get("name", bid)) + (" ×%d" % cnt[bid] if int(cnt[bid]) > 1 else ""),
			"desc": String(bd.get("desc", "")), "color": WHITE})
	a.append({"head": "流派大成（同一流派 %d 个）" % ArpgData.SET_NEED})
	var scn := ArpgData.school_counts(state.build_ids())
	for k: String in ArpgData.SETS:
		var n := int(scn.get(k, 0))
		var sd: Dictionary = ArpgData.SETS[k]
		a.append({"tag": k, "tag_color": ArpgData.SCHOOL_COLORS.get(k, TEAL), "title": "「%s」" % sd["name"], "on": n >= ArpgData.SET_NEED,
			"right": "已大成" if n >= ArpgData.SET_NEED else "%d / %d" % [n, ArpgData.SET_NEED], "desc": sd["desc"], "color": ArpgData.SCHOOL_COLORS.get(k, WHITE)})
	var b := [{"head": "技能分支　悟道 %s重 · 天赋点 %d" % [Hud3D._cn(state.level), state.points]}]
	for s: Dictionary in ArpgSkills.SKILLS:
		var cb := ArpgSkills.chosen_branch(state.skills, String(s["id"]))
		if cb == "":
			var names := []
			for br: Dictionary in s["branches"]:
				names.append(String(br["name"]))
			b.append({"tag": String(s["full"]), "title": "未点", "on": false, "desc": "可选：" + " / ".join(names)})
			continue
		var bd := ArpgSkills.branch(cb)
		var lv := int(state.skills.get(cb, 0))
		var ranks: Array = bd["ranks"]
		b.append({"tag": String(s["full"]), "title": "%s　%s" % [bd["name"], "●".repeat(lv) + "○".repeat(ranks.size() - lv)], "color": s["color"],
			"right": "%d / %d 级" % [lv, ranks.size()], "desc": "%s\n当前：%s" % [bd["brief"], ranks[clampi(lv - 1, 0, ranks.size() - 1)]]})
	b.append({"head": "双修（相邻两流派各 %d 个）" % ArpgSkills.DUAL_NEED})
	var ds := ArpgSkills.duals_of(state.build_ids())
	for d: Dictionary in ArpgSkills.DUALS:
		var on := ds.has(String(d["id"]))
		var prog := mini(int(scn.get(d["a"], 0)), ArpgSkills.DUAL_NEED) + mini(int(scn.get(d["b"], 0)), ArpgSkills.DUAL_NEED)
		b.append({"tag": "%s+%s" % [d["a"], d["b"]], "tag_color": ArpgData.SCHOOL_COLORS.get(d["a"], TEAL), "title": "「%s」" % d["name"], "on": on,
			"right": "已成" if on else "%d / %d" % [prog, ArpgSkills.DUAL_NEED * 2], "desc": d["desc"], "color": ArpgData.SCHOOL_COLORS.get(d["a"], WHITE)})
	b.append({"head": "连携（放完一招，马上接另一招）"})
	for l: Dictionary in ArpgSkills.LINKS:
		var got := state.links_done.has(String(l["id"]))
		var need_art := String(l["from"]) == "art" or String(l["to"]) == "art"
		var ok := not need_art or hero.art_id() != ""
		b.append({"title": String(l["name"]), "color": l["color"], "on": ok, "right": "这一局打出过" if got else ("要先学秘技" if not ok else ""),
			"desc": String(l["desc"])})
	return [a, b]


func _world_cols() -> Array:
	var d := ArpgState.difficulty()
	var a := [{"head": "难度与轮回"}]
	a.append({"tag": "难度", "title": ArpgState.DIFF_NAMES[d], "desc": ArpgState.DIFF_DESC[d] + "（暂停菜单里能改）"})
	if state.cycle <= 0:
		a.append({"tag": "轮回", "title": "本相", "tag_color": Color(0.85, 0.6, 1.0), "desc": "不加难。" + ("山门轮回盘可以选更高的轮回级" if ArpgCycle.unlocked() > 0 else "打通一次后山门出现轮回盘")})
	else:
		a.append({"tag": "轮回", "tag_color": Color(0.85, 0.6, 1.0), "title": ArpgCycle.label(state.cycle), "color": Color(0.85, 0.6, 1.0),
			"desc": "敌人生命 +%d%%、伤害 +%d%%；魂玉 +%d%%；掉的装备更好" % [int(round(ArpgCycle.hp_mult_raw(state.cycle) * 100.0 - 100.0)),
				int(round(ArpgCycle.dmg_mult_raw(state.cycle) * 100.0 - 100.0)), int(round(ArpgCycle.JADE_PER * state.cycle * 100.0))]})
		for i in range(1, state.cycle + 1):
			a.append({"tag": "规矩 %s" % ArpgCycle.NUM[i], "tag_color": Color(0.85, 0.6, 1.0), "title": String(ArpgCycle.RULES[i][0]), "desc": String(ArpgCycle.RULES[i][1])})
	if not in_hub:
		a.append({"head": "这一局"})
		if state.omen != "" and ArpgState.OMENS.has(state.omen):
			var om: Dictionary = ArpgState.OMENS[state.omen]
			a.append({"tag": "天象", "title": String(om["name"]), "color": om.get("color", WHITE), "desc": String(om["desc"])})
		if state.curse > 0:
			a.append({"tag": "诅咒", "title": "地藏的钱 ×%d" % state.curse, "color": BAD, "desc": "受到的伤害 +%d%%" % (10 * state.curse)})
		if state.whet > 0:
			a.append({"tag": "磨刀", "title": "磨过 %d 次" % state.whet, "desc": "伤害 +%d%%" % int(round(ArpgState.WHET_ATK * 100.0 * state.whet))})
		if state.forged > 0:
			a.append({"tag": "铸甲", "title": "铸过 %d 层" % state.forged, "desc": "生命 +%d" % int(ArpgState.FORGE_HP * state.forged)})
		a.append({"tag": "战绩", "title": "斩敌 %d · 走过 %d 间" % [state.kills, state.rooms], "desc": ""})
	a.append({"head": "天赋（山门拾骨婆，永久）"})
	for t: Dictionary in ArpgData.TALENT_TREES:
		var got := []
		for tier: Array in t["tiers"]:
			for nd: Dictionary in tier:
				var r := ArpgData.talent_rank(nd["id"])
				if r > 0:
					got.append("%s %d/%d" % [nd["name"], r, int(nd["max"])])
		a.append({"tag": String(t["role"]), "tag_color": t["color"], "title": String(t["name"]), "color": t["color"], "on": not got.is_empty(),
			"right": "投入 %d 点" % ArpgData.talent_spent_in(t), "desc": "、".join(got) if not got.is_empty() else "还没点"})
	var ks: Array = ArpgSecrets.keeps()
	a.append({"head": "信物（%d / %d，永久）" % [ks.size(), ArpgSecrets.KEEPS.size()]})
	if ks.is_empty():
		a.append({"title": "还没有", "on": false, "desc": "山门信物匣里有线索"})
	for kid: String in ks:
		var kd: Dictionary = ArpgSecrets.keep_info(kid)
		a.append({"title": String(kd.get("name", kid)), "color": Color(1.0, 0.8, 0.6), "desc": String(kd.get("desc", ""))})
	var b := [{"head": "敌人词缀（精英和轮回里的敌人会带）"}]
	for id: String in FoeAffix.DEFS:
		var fd: Dictionary = FoeAffix.DEFS[id]
		b.append({"tag": String(fd["name"]), "tag_color": fd["color"], "title": String(fd["full"]), "color": fd["color"], "desc": String(fd["desc"])})
	return [a, b]
