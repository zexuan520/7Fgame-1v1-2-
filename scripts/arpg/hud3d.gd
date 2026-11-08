class_name Hud3D
extends Control
## 斜俯视版 HUD：暗色半透明底 + 金/青细边，衬线字体。
##   左下：圆形头像框（实时拍主角的脸）+ 细血条 + 气力条 + 药葫芦数
##   右下：技能图标和冷却圆环（突进斩 / 光束斩 / 终结技 / 药葫芦）
##   敌人头顶：红色菱形里写出血层数 + 细血条 + 血滴图标（出血中），始终朝屏幕
##   上方：头目血条；左上：区域名和波次；中间：提示横幅

const GOLD := Color(0.86, 0.72, 0.42)
const TEAL := Color(0.35, 0.85, 0.85)
const PANEL := Color(0.03, 0.05, 0.06, 0.72)

var hero: Hero
var font: Font
var pixel: Font
var _orb_t := 0.0                # 血玉徽记的液面晃动
var zone_name := ""
var omen := ""                   # 这一局的天象（区域名下面一行小字）
var omen_color := Color.WHITE
var wave_text := ""
var seals: Array = []            # 试炼房四枚印：0 没开始 / 1 进行中 / 2 得印 / 3 失手
var coins := 0
var jade := 0
var boss: Foe
var _banner := ""
var _banner_t := 0.0
var _banner_sub := ""
var _banner_full := 0.0
static var I: Hud3D
var _bars := 0.0                  # 电影黑边：剩余真实秒
var _bars_k := 0.0                # 黑边当前高度 0~1
var _hp_show := 1.0               # 血条掉血时慢慢跟上的白色残影
var _shown_hp := {}
## 悟道（局内等级）：第几重、这一重攒了多少（0~1）、没用的天赋点
var level := 0
var xp_k := 0.0
var points := 0
var _link_name := ""
var _link_sub := ""
var _link_col := Color.WHITE
var _link_t := 0.0
const LINK_SHOW := 1.6


func _ready() -> void:
	I = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = Feel.I.font if Feel.I != null else Game.font
	pixel = Game.font
	# 2026-11-07：原来左下角是一个小视口实时拍主角的脸——每帧多渲染一遍整个场景（手机上很贵），
	# 拍出来又常常是兜帽里面一团看不清的方块。换成画出来的“血玉”徽记：圆里一汪血按生命高低涨落，中间一把断刃。


## 上下电影黑边（头目登场、变身、倒下的特写）
func cinema(dur: float) -> void:
	_bars = maxf(_bars, dur)


## 连携：屏幕上方偏中一条金边横条，字从大缩回正常
func link_flash(name: String, sub: String, c: Color) -> void:
	_link_name = name
	_link_sub = sub
	_link_col = c
	_link_t = LINK_SHOW


func banner(text: String, sub: String = "", t: float = 2.2) -> void:
	_banner = text
	_banner_sub = sub
	_banner_t = t
	_banner_full = t


func _process(dt: float) -> void:
	var _pt := Time.get_ticks_usec() if PerfProbe.on else 0
	_process_body(dt)
	if PerfProbe.on:
		PerfProbe.add("hud", _pt)


func _process_body(dt: float) -> void:
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	_bars = maxf(_bars - rdt, 0.0)
	_bars_k = move_toward(_bars_k, 1.0 if _bars > 0.0 else 0.0, rdt * 4.0)
	_banner_t = maxf(_banner_t - dt, 0.0)
	_link_t = maxf(_link_t - rdt, 0.0)
	if is_instance_valid(hero):
		var k := hero.hp / hero.max_hp
		_hp_show = move_toward(_hp_show, k, dt * 0.5) if _hp_show > k else k
	_orb_t += rdt
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	if _bars_k > 0.001:
		var bh := vs.y * 0.1 * _bars_k
		draw_rect(Rect2(0, 0, vs.x, bh), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, vs.y - bh, vs.x, bh), Color(0, 0, 0, 0.92))
	_draw_enemy_marks()
	if is_instance_valid(hero):
		_draw_player_panel(vs)
		if not TouchPad.active:
			_draw_skills(vs)   # 触屏模式下冷却画在按键上
	_draw_boss(vs)
	# 左上：区域名 + 波次 + 钱
	draw_string(font, Vector2(28, 44), zone_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GOLD)
	draw_line(Vector2(28, 52), Vector2(220, 52), Color(GOLD, 0.6), 1.0)
	draw_string(font, Vector2(28, 76), wave_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.9, 0.9))
	if not seals.is_empty():
		_draw_seals()
	draw_string(font, Vector2(vs.x - 220, 44), "铜钱 %d" % coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.45))
	draw_string(font, Vector2(vs.x - 220, 70), "魂玉 %d" % jade, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.55, 1.0, 0.85))
	if omen != "":
		draw_string(font, Vector2(vs.x - 220, 94), omen, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(omen_color, 0.9))
	if _link_t > 0.0:
		_draw_link(vs)
	if _banner_t > 0.0:
		_draw_banner(vs)


## 横幅（2026-11-07 改）：原来是屏幕三成高处一整条黑带，正好压在战场上；现在挪到上方、两头渐隐的墨带，
## 字先放大再落定，左右两枚菱形，少挡视线也更有“题字”的味道
func _draw_banner(vs: Vector2) -> void:
	var a := clampf(_banner_t / 0.4, 0.0, 1.0)
	var y := vs.y * (0.26 if is_instance_valid(boss) and boss.alive else 0.17)   # 头目战让开顶上的血条
	var bw := minf(vs.x * 0.62, 760.0)
	var x0 := (vs.x - bw) * 0.5
	# 墨带：中间浓、两头淡（分 12 段画渐变）
	for i in range(12):
		var t0 := float(i) / 12.0
		var k := 1.0 - absf(t0 + 1.0 / 24.0 - 0.5) * 2.0
		draw_rect(Rect2(x0 + bw * t0, y - 40, bw / 12.0 + 1.0, 70), Color(0.01, 0.015, 0.02, 0.62 * a * sqrt(k)))
	var gl := Color(GOLD, 0.8 * a)
	draw_line(Vector2(x0 + bw * 0.12, y - 40), Vector2(x0 + bw * 0.88, y - 40), gl, 1.0)
	draw_line(Vector2(x0 + bw * 0.12, y + 30), Vector2(x0 + bw * 0.88, y + 30), gl, 1.0)
	for sx: float in [x0 + bw * 0.1, x0 + bw * 0.9]:
		var p := Vector2(sx, y - 5)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), gl)
	var age := maxf(_banner_full - _banner_t, 0.0)
	var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - age / 0.2)
	draw_string(font, Vector2(0, y + 4), _banner, HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(36 * pop), Color(0.97, 0.93, 0.84, a))
	if _banner_sub != "":
		draw_string(font, Vector2(0, y + 24), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(0.65, 0.92, 0.9, a))


func _draw_link(vs: Vector2) -> void:
	var age := LINK_SHOW - _link_t
	var a := clampf(_link_t / 0.35, 0.0, 1.0) * clampf(age / 0.06, 0.0, 1.0)
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - age / 0.18)
	var y := vs.y * (0.38 if _banner_t > 0.0 else 0.19)   # 和横幅同时出现时往下让开，不叠字
	var w := 380.0
	var x := (vs.x - w) * 0.5
	draw_rect(Rect2(x, y - 34, w, 58), Color(0, 0, 0, 0.5 * a))
	draw_line(Vector2(x, y - 34), Vector2(x + w, y - 34), Color(_link_col, 0.9 * a), 2.0)
	draw_line(Vector2(x + 40, y + 24), Vector2(x + w - 40, y + 24), Color(GOLD, 0.6 * a), 1.0)
	draw_string(font, Vector2(x, y - 14), "连 携", HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(GOLD, a))
	draw_string(font, Vector2(x, y + 14), _link_name, HORIZONTAL_ALIGNMENT_CENTER, w, int(30 * pop), Color(_link_col.lightened(0.3), a))
	if _link_sub != "":
		draw_string(font, Vector2(x, y + 44), _link_sub, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0.85, 0.85, 0.8, a * 0.9))


## 头像圆心的 y：平时在左下；触屏模式左下要放摇杆，挪到左上区域名下面
func _panel_y(vs: Vector2) -> float:
	return 168.0 if TouchPad.active else vs.y - 82


func _draw_player_panel(vs: Vector2) -> void:
	var c := Vector2(82, _panel_y(vs))
	var top := c.y - 38
	# 底板
	draw_rect(Rect2(c.x, top, 330, 78), PANEL)
	draw_line(Vector2(c.x, top), Vector2(c.x + 330, top), Color(GOLD, 0.5), 1.0)
	# 血玉徽记：外圈金、里面一汪血按生命涨落，中间一把断刃
	_draw_orb(c, 54.0)
	draw_arc(c, 56, 0, TAU, 64, GOLD, 2.5, true)
	draw_arc(c, 61, 0, TAU, 64, Color(GOLD, 0.35), 1.0, true)
	# 气力环（头像外圈）
	var e := minf(hero.energy / hero.beam_cost, 1.0)
	draw_arc(c, 66, -PI / 2, -PI / 2 + TAU * e, 64, Color(1.0, 0.85, 0.4) if e >= 1.0 else TEAL, 3.0, true)
	for i in range(4):
		var a := -PI / 2 + i * PI / 2
		var p := c + Vector2(cos(a), sin(a)) * 60
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), GOLD)
	# 血条
	var x0 := c.x + 76
	var y0 := top + 20
	var w := 240.0
	draw_string(font, Vector2(x0, y0 - 4), "残刃", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)
	if level > 0:
		# 悟道：名字旁边写第几重，底板上沿一条金线是这一重的进度
		var lv := "悟道 %s重" % _cn(level)
		draw_string(font, Vector2(x0 + 42, y0 - 5), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.88, 0.55))
		draw_rect(Rect2(c.x, top - 3, 330 * xp_k, 3), Color(1.0, 0.82, 0.4, 0.9))
		if points > 0:
			var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
			draw_string(font, Vector2(c.x + 76, top - 8), "天赋点 %d　%s" % [points, TouchPad.hint("Esc → 技能分支", "暂停 → 技能分支")], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.4, blink))
	draw_rect(Rect2(x0, y0 + 5, w, 11), Color(0.08, 0.02, 0.03))
	draw_rect(Rect2(x0, y0 + 5, w * _hp_show, 11), Color(0.95, 0.85, 0.8, 0.8))
	var hk := hero.hp / hero.max_hp
	var hc := Color(0.8, 0.12, 0.14)
	if hk < 0.3:
		hc = hc.lerp(Color(1.0, 0.35, 0.3), 0.3 + 0.3 * sin(_orb_t * 9.0))
	draw_rect(Rect2(x0, y0 + 5, w * hk, 11), hc)
	draw_rect(Rect2(x0, y0 + 5, w * hk, 3), Color(1.0, 0.6, 0.55, 0.5))   # 上沿高光
	for i in range(1, int(hero.max_hp / 20.0)):
		var tx := x0 + w * (i * 20.0) / hero.max_hp
		draw_line(Vector2(tx, y0 + 6), Vector2(tx, y0 + 15), Color(0, 0, 0, 0.35), 1.0)   # 每 20 点一格
	draw_rect(Rect2(x0, y0 + 5, w, 11), Color(GOLD, 0.6), false, 1.0)
	draw_string(font, Vector2(x0 + w - 70, y0 - 4), "%d / %d" % [int(hero.hp), int(hero.max_hp)], HORIZONTAL_ALIGNMENT_RIGHT, 70, 15, Color(0.9, 0.85, 0.8))
	if hero.golden:
		draw_rect(Rect2(x0 - 3, y0 + 3, w + 6, 15), Color(1.0, 0.85, 0.4, 0.9), false, 2.0)   # 金身
	if hero._mirror_t > 0.0:
		draw_rect(Rect2(x0 - 5, y0 + 1, w + 10, 19), Color(0.7, 1.0, 0.9, 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.012)), false, 1.5)   # 双修·明镜
	var sets := []
	for pair: Array in [[hero.set_shura, "修罗场"], [hero.set_blood, "血涌"], [hero.set_wind, "御风"], [hero.set_light, "天光"], [hero.set_guard, "金身"], [hero.set_storm, "天雷"], [hero.set_pyre, "燎原"]]:
		if pair[0]:
			sets.append(pair[1])
	if not sets.is_empty():
		draw_string(font, Vector2(x0, y0 + 66), "大成 " + "  ".join(sets), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	# 兵器状态：鸳鸯双刀的刀势、磨刀石、烟丸
	var tags := []
	if hero.edge > 0:
		tags.append("刀势 ×%d" % hero.edge)
	if hero.buffs.has("whet"):
		tags.append("刃利 %d" % int(ceil(float(hero.buffs["whet"]))))
	if hero.buffs.has("smoke"):
		tags.append("烟遁")
	if not tags.is_empty():
		draw_string(font, Vector2(x0 + 140, y0 + 66), "  ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.6, 0.55))
	if TouchPad.active and hero.kit != null:
		draw_string(font, Vector2(x0, y0 + 84), _arms_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.9, 0.9))
	# 气力条
	draw_rect(Rect2(x0, y0 + 22, w, 5), Color(0.02, 0.06, 0.07))
	draw_rect(Rect2(x0, y0 + 22, w * e, 5), Color(1.0, 0.85, 0.4) if e >= 1.0 else TEAL)
	draw_rect(Rect2(x0, y0 + 22, w, 5), Color(TEAL, 0.5), false, 1.0)
	draw_string(font, Vector2(x0, y0 + 46), "气 %d" % int(hero.energy) + ("  光束斩就绪" if e >= 1.0 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.9, 0.9))
	# 药葫芦
	for i in range(hero.max_gourds):
		var gp := Vector2(x0 + 168 + i * 22, y0 + 40)
		var col := Color(0.4, 1.0, 0.6) if i < hero.gourds else Color(0.2, 0.25, 0.25)
		draw_circle(gp, 6, col)
		draw_circle(gp + Vector2(0, -8), 4, col)


func _draw_orb(c: Vector2, r: float) -> void:
	draw_circle(c, r + 4, Color(0.02, 0.025, 0.035))
	var k := clampf(hero.hp / hero.max_hp, 0.0, 1.0)
	var low := k < 0.3
	# 液面：一条正弦波，水位 = 生命；低血时一闪一闪
	var lvl := c.y + r - 2.0 * r * k
	var pts := PackedVector2Array()
	var steps := 40
	for i in range(steps + 1):
		var x := c.x - r + 2.0 * r * float(i) / steps
		var y := lvl + sin(float(i) * 0.5 + _orb_t * 3.0) * 2.2 * (1.0 if k < 0.999 else 0.0)
		var dx := x - c.x
		var half := sqrt(maxf(r * r - dx * dx, 0.0))
		pts.append(Vector2(x, clampf(y, c.y - half, c.y + half)))
	for i in range(steps, -1, -1):
		var x := c.x - r + 2.0 * r * float(i) / steps
		var dx := x - c.x
		pts.append(Vector2(x, c.y + sqrt(maxf(r * r - dx * dx, 0.0))))
	var blood := Color(0.62, 0.05, 0.08)
	if low:
		blood = blood.lerp(Color(1.0, 0.2, 0.2), 0.35 + 0.35 * sin(_orb_t * 9.0))
	# 两端水位和球边重合会出重复点、低血时液面贴着球底成了零面积的尖条，直接画会刷“triangulation failed”报错：
	# 先去掉挨得太近的点，再试着三角化一下，分不开的那一帧就不画液面
	var poly := PackedVector2Array()
	for p in pts:
		if poly.is_empty() or poly[poly.size() - 1].distance_squared_to(p) > 0.09:
			poly.append(p)
	if poly.size() > 1 and poly[0].distance_squared_to(poly[poly.size() - 1]) <= 0.09:
		poly.remove_at(poly.size() - 1)
	if k > 0.001 and poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
		draw_colored_polygon(poly, blood)
		# 液面一道亮线
		var top := PackedVector2Array()
		for i in range(steps + 1):
			top.append(pts[i])
		draw_polyline(top, Color(1.0, 0.55, 0.5, 0.8), 1.5, true)
	# 玻璃高光
	draw_arc(c + Vector2(-6, -8), r * 0.72, PI * 1.05, PI * 1.45, 16, Color(1, 1, 1, 0.22), 4.0, true)
	# 断刃：斜着一把刀，刀尖断成锯齿（游戏名“残刃”）
	var ang := -PI * 0.25
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-u.y, u.x)
	var base := c - u * r * 0.62
	var blade_w := 5.5
	var tip := base + u * r * 1.05
	var bl := PackedVector2Array([base + v * blade_w * 0.8, base - v * blade_w * 0.8,
		tip - v * blade_w - u * 3.0, tip - v * 2.0 + u * 4.0, tip + v * 1.0 - u * 2.0, tip + v * blade_w + u * 3.0])
	draw_colored_polygon(bl, Color(0.86, 0.9, 0.92))
	draw_polyline(PackedVector2Array([base + v * 1.0, tip + v * 1.0 - u * 4.0]), Color(1, 1, 1, 0.9), 1.5, true)
	# 刀镡和刀柄
	var gd := base
	draw_colored_polygon(PackedVector2Array([gd + v * 13 - u * 2, gd + v * 13 + u * 3, gd - v * 13 + u * 3, gd - v * 13 - u * 2]), GOLD)
	draw_line(gd - u * 3, gd - u * 22, Color(0.32, 0.12, 0.1), 7.0)
	for i in range(3):
		draw_line(gd - u * (7 + i * 5) - v * 3.5, gd - u * (9 + i * 5) + v * 3.5, Color(0.75, 0.6, 0.35), 1.5)
	draw_circle(gd - u * 24, 3.5, GOLD)


func _draw_skills(vs: Vector2) -> void:
	var items := [
		["突", "dash", 1.0 if hero._echo_t > 0.0 else 1.0 - float(hero.cd["dash"]) / hero.dash_cd, ArpgInput.key_name(hero.index, "dash")],
		["光", "beam", minf(hero.energy / hero.beam_cost, 1.0), ArpgInput.key_name(hero.index, "beam")],
		["终", "finish", 1.0 - float(hero.cd["finish"]) / hero.finish_cd, ArpgInput.key_name(hero.index, "finish")],
		["药", "heal", 1.0 if hero.gourds > 0 else 0.0, ArpgInput.key_name(hero.index, "heal")],
	]
	if hero.art_id() != "":
		items.insert(3, ["秘", "art", 1.0 - float(hero.cd["art"]) / hero.art_cd, ArpgInput.key_name(hero.index, "art")])
	if hero.index == 0:
		items = items.filter(func(it: Array) -> bool: return not ArpgHints.locked(String(it[1])))   # 第一局还没亮出来的招式
	var x0 := vs.x - 250 - (items.size() - 4) * 62
	for i in range(items.size()):
		var it: Array = items[i]
		var c := Vector2(x0 + i * 62, vs.y - 64)
		var ready := float(it[2]) >= 0.999
		draw_circle(c, 25, PANEL)
		var col := TEAL
		if it[1] == "finish":
			col = Color(1.0, 0.3, 0.3)
		elif it[1] == "beam":
			col = Color(1.0, 0.85, 0.4)
		elif it[1] == "heal":
			col = Color(0.4, 1.0, 0.6)
		elif it[1] == "art":
			col = Color(1.0, 0.7, 0.35)
		# 冷却：暗色扇形 + 亮色进度环
		if not ready and float(it[2]) < 0.98:   # 剩一丝时扇形太窄，三角化会失败
			var pts := PackedVector2Array([c])
			var a0 := -PI / 2 + TAU * clampf(float(it[2]), 0.0, 1.0)
			for s in range(25):
				var a := lerpf(a0, -PI / 2 + TAU, s / 24.0)
				pts.append(c + Vector2(cos(a), sin(a)) * 24)
			if pts.size() > 2:
				draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		draw_arc(c, 27, -PI / 2, -PI / 2 + TAU * clampf(float(it[2]), 0, 1), 48, col if ready else Color(col, 0.6), 3.0, true)
		draw_arc(c, 25, 0, TAU, 48, Color(GOLD, 0.5), 1.0, true)
		# 连携：现在按这一招能接上连携，外面亮一圈本色、轻轻跳
		var lg := hero.link_glow(String(it[1]))
		if lg.a > 0.0:
			var pul := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
			draw_arc(c, 31 + 2 * pul, 0, TAU, 48, Color(lg, 0.6 + 0.4 * pul), 3.0, true)
			draw_string(font, c + Vector2(-20, -34), "连携", HORIZONTAL_ALIGNMENT_CENTER, 40, 13, lg.lightened(0.3))
		draw_string(font, c + Vector2(-13, 9), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col if ready else Color(0.5, 0.55, 0.55))
		# 按键名垫一个小键帽，小屏上也一眼认得出
		var kw := maxf(pixel.get_string_size(String(it[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8, 16)
		var kr := Rect2(c.x - kw / 2, c.y + 31, kw, 17)
		draw_rect(kr, Color(PANEL, 0.85))
		draw_rect(kr, Color(GOLD, 0.35), false, 1.0)
		draw_string(pixel, c + Vector2(-20, 44), it[3], HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(0.85, 0.9, 0.9))
	# 普攻和翻滚提示
	draw_string(pixel, Vector2(vs.x - 250, vs.y - 112), "%s 攻击  %s 翻滚" % [ArpgInput.key_name(hero.index, "attack"), ArpgInput.key_name(hero.index, "roll")], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.7))
	if hero.kit == null:
		return
	# 兵器（主手 / 副手、换刃斩冷却）和道具
	var k := hero.kit
	var wy := vs.y - 140
	draw_rect(Rect2(vs.x - 262, wy - 46, 250, 56), Color(PANEL, 0.5))
	draw_string(font, Vector2(vs.x - 252, wy - 26), _arms_line(), HORIZONTAL_ALIGNMENT_LEFT, 236, 15, Color(0.85, 0.92, 0.92))
	if not (k.arms[1] as Dictionary).is_empty():
		var rdy := 1.0 - float(hero.cd["swap_strike"]) / Hero.SWAP_STRIKE_CD
		draw_rect(Rect2(vs.x - 252, wy - 20, 120 * rdy, 2), Color(TEAL, 0.8))
	var pl := "无道具"
	var pc := Color(0.55, 0.6, 0.6)
	if not k.props.is_empty():
		var pr: Dictionary = k.props[clampi(k.prop_sel, 0, k.props.size() - 1)]
		var d := ArpgArms.item(String(pr["id"]))
		pl = "%s %s ×%d" % [ArpgInput.key_name(hero.index, "item"), d["name"], int(pr["n"])]
		if k.props.size() > 1:
			pl += "　%s 换（%d 种）" % [ArpgInput.key_name(hero.index, "item_next"), k.props.size()]
		pc = d["color"]
	draw_string(font, Vector2(vs.x - 252, wy - 2), pl, HORIZONTAL_ALIGNMENT_LEFT, 236, 15, pc)


## “主 破阵枪　副 连弩　Q 换”
func _arms_line() -> String:
	var k := hero.kit
	var a := String(ArpgData.weapon(String((k.arms[0] as Dictionary).get("base", hero.weapon_id)))["name"])
	if (k.arms[1] as Dictionary).is_empty():
		return "兵器 " + a
	var b := String(ArpgData.weapon(String(k.arms[1]["base"]))["name"])
	if TouchPad.active:
		return "主 %s　副 %s" % [a, b]
	return "主 %s　副 %s　%s 换" % [a, b, ArpgInput.key_name(hero.index, "swap")]


static func _cn(n: int) -> String:
	const D := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n < 10:
		return D[n]
	if n < 20:
		return "十" + (D[n % 10] if n % 10 > 0 else "")
	return D[n / 10] + "十" + (D[n % 10] if n % 10 > 0 else "")


func _draw_enemy_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := get_viewport_rect().size
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Foe
		if a == null or not a.alive or a.is_boss:
			continue
		var wp := a.head_top()
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		# 房间大了，画面外的敌人在屏幕边上画个红箭头指过去（不然最后几只要满屋子找）
		var inner := Rect2(Vector2(28, 28), vs - Vector2(56, 56))
		if not inner.has_point(sp):
			var ctr := vs * 0.5
			var dv := sp - ctr
			var sc := minf(absf((inner.size.x * 0.5) / maxf(absf(dv.x), 0.001)), absf((inner.size.y * 0.5) / maxf(absf(dv.y), 0.001)))
			var ep := ctr + dv * minf(sc, 1.0)
			var dn := dv.normalized()
			var pn := Vector2(-dn.y, dn.x)
			var col := Color(1.0, 0.3, 0.25, 0.85) if a.kind != "samurai" else Color(1.0, 0.75, 0.3, 0.9)
			if not a.affixes.is_empty():
				col = Color(FoeAffix.color(a), 0.95)
			draw_colored_polygon(PackedVector2Array([ep + dn * 11, ep - dn * 6 + pn * 8, ep - dn * 6 - pn * 8]), col)
			continue
		var w := 46.0 * (1.25 if a.kind == "samurai" else 1.0)
		var k := a.hp / a.max_hp
		var shown: float = _shown_hp.get(a, 1.0)
		shown = move_toward(shown, k, 0.01) if shown > k else k
		_shown_hp[a] = shown
		if not a.affixes.is_empty():
			# 精英词缀：血条上方挂一排字（每个字一个颜色的小方块），金罩剩多少画一道金条
			var tw := 23.0 * a.affixes.size()
			var x0 := sp.x - tw * 0.5
			for i in range(a.affixes.size()):
				var d: Dictionary = FoeAffix.DEFS[a.affixes[i]]
				var r := Rect2(x0 + i * 23.0, sp.y - 27, 21, 22)
				draw_rect(r, Color(0.05, 0.03, 0.03, 0.85))
				draw_rect(r, d["color"], false, 2.0)
				draw_string(font, Vector2(r.position.x, r.position.y + 18), String(d["name"]), HORIZONTAL_ALIGNMENT_CENTER, 21, 18, d["color"])
			if a.ward > 0.0:
				draw_rect(Rect2(sp.x - w * 0.5, sp.y - 4, w * a.ward / maxf(a.ward_max, 1.0), 3), Color(1.0, 0.85, 0.35, 0.95))
		if k >= 0.999 and a.bleed <= 0 and a.affixes.is_empty():
			continue
		var y := sp.y
		draw_rect(Rect2(sp.x - w * 0.5, y, w, 4), Color(0.05, 0.01, 0.01, 0.85))
		draw_rect(Rect2(sp.x - w * 0.5, y, w * shown, 4), Color(1.0, 0.85, 0.8, 0.7))
		draw_rect(Rect2(sp.x - w * 0.5, y, w * k, 4), Color(0.65, 0.06, 0.08))
		if a.max_poise > 0.0:
			draw_rect(Rect2(sp.x - w * 0.5, y + 5, w * a.poise / a.max_poise, 2), Color(1.0, 0.8, 0.4, 0.8))
		if a.bleed > 0:
			# 红色菱形 + 层数
			var dc := Vector2(sp.x - w * 0.5 - 12, y + 2)
			draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -10), dc + Vector2(9, 0), dc + Vector2(0, 10), dc + Vector2(-9, 0)]), Color(0.75, 0.05, 0.08))
			draw_polyline(PackedVector2Array([dc + Vector2(0, -10), dc + Vector2(9, 0), dc + Vector2(0, 10), dc + Vector2(-9, 0), dc + Vector2(0, -10)]), Color(1.0, 0.6, 0.5), 1.0)
			draw_string(font, dc + Vector2(-5, 6), str(a.bleed), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.95, 0.9))
			# 血滴（下方）
			var bc := Vector2(sp.x, y + 16)
			draw_circle(bc, 4.5, Color(0.85, 0.08, 0.1))
			draw_colored_polygon(PackedVector2Array([bc + Vector2(-4, -1), bc + Vector2(0, -10), bc + Vector2(4, -1)]), Color(0.85, 0.08, 0.1))


func _draw_boss(vs: Vector2) -> void:
	if not is_instance_valid(boss) or not boss.alive:
		return
	# 2026-11-07 重画：名字两边金线和菱形、血条加厚加暗框、每 10% 一道刻度、掉血那一截先白后红慢慢退、
	# 半血以下血条泛暗红呼吸；架势条贴在底下
	var w := vs.x * 0.5
	var x := (vs.x - w) * 0.5
	var y := 74.0
	var nm := boss.display_name
	var nw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(font, Vector2(0, y - 14), nm, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 24, Color(1.0, 0.82, 0.86))
	var cx := vs.x * 0.5
	for sgn: float in [-1.0, 1.0]:
		var e0 := cx + sgn * (nw * 0.5 + 14.0)
		var e1 := cx + sgn * (nw * 0.5 + 120.0)
		draw_line(Vector2(e0, y - 22), Vector2(e1, y - 22), Color(GOLD, 0.7), 1.0)
		var p := Vector2(e0 + sgn * 2.0, y - 22)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), GOLD)
	draw_rect(Rect2(x - 4, y - 4, w + 8, 20), Color(0, 0, 0, 0.7))
	var k := boss.hp / boss.max_hp
	var shown: float = _shown_hp.get(boss, 1.0)
	shown = move_toward(shown, k, 0.004) if shown > k else k
	_shown_hp[boss] = shown
	draw_rect(Rect2(x, y, w * shown, 12), Color(1.0, 0.92, 0.85, 0.75))
	var bc := Color(0.72, 0.07, 0.18)
	if k < 0.5:
		bc = bc.lerp(Color(0.95, 0.15, 0.2), 0.25 + 0.25 * sin(_orb_t * 5.0))
	draw_rect(Rect2(x, y, w * k, 12), bc)
	draw_rect(Rect2(x, y, w * k, 3), Color(1.0, 0.55, 0.6, 0.55))   # 上沿高光
	for i in range(1, 10):
		var tx := x + w * i / 10.0
		draw_line(Vector2(tx, y + 1), Vector2(tx, y + 11), Color(0, 0, 0, 0.45), 1.0)
	draw_rect(Rect2(x - 1, y - 1, w + 2, 14), Color(GOLD, 0.85), false, 1.0)
	for ex: float in [x - 8, x + w + 8]:
		var p := Vector2(ex, y + 6)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)]), GOLD)
	draw_rect(Rect2(x, y + 15, w * boss.poise / maxf(boss.max_poise, 1.0), 3), Color(1.0, 0.8, 0.4, 0.85))
	if boss.bleed > 0:
		draw_string(font, Vector2(x + w + 18, y + 12), "出血 ×%d" % boss.bleed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.35, 0.35))


## 试炼四枚印：方块里写“疾守狂乱”，得印金色、进行中闪、失手灰
func _draw_seals() -> void:
	var names := ["疾", "守", "狂", "乱"]
	for i in range(mini(seals.size(), 4)):
		var st := int(seals[i])
		var c := Color(0.35, 0.4, 0.42, 0.8)
		match st:
			1:
				c = Color(0.85, 0.95, 0.95, 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.006)))
			2:
				c = Color(1.0, 0.82, 0.35)
			3:
				c = Color(0.4, 0.3, 0.3, 0.8)
		var r := Rect2(28 + i * 34, 86, 28, 28)
		draw_rect(r, Color(0, 0, 0, 0.45))
		draw_rect(r, c, false, 2.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 21), names[i], HORIZONTAL_ALIGNMENT_CENTER, 28, 18, c)
		if st == 3:
			draw_line(r.position + Vector2(4, 24), r.position + Vector2(24, 4), c, 2.0)
