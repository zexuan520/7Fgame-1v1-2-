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
var portrait_vp: SubViewport
var portrait_cam: Camera3D
var portrait_rect: TextureRect
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
	# 头像：一个小视口，镜头对着主角的脸
	portrait_vp = SubViewport.new()
	portrait_vp.size = Vector2i(128, 128)
	portrait_vp.transparent_bg = false
	portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(portrait_vp)
	portrait_cam = Camera3D.new()
	portrait_cam.fov = 24.0
	portrait_cam.cull_mask = 0xFFFFF
	portrait_vp.add_child(portrait_cam)
	portrait_rect = TextureRect.new()
	portrait_rect.texture = portrait_vp.get_texture()
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.size = Vector2(104, 104)
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d = UV - 0.5; float r = length(d); vec4 c = texture(TEXTURE, UV); c.rgb = c.rgb * 1.15 + vec3(0.02, 0.05, 0.06); COLOR = vec4(c.rgb, smoothstep(0.5, 0.47, r)); }"
	m.shader = sh
	portrait_rect.material = m
	add_child(portrait_rect)


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


func _process(dt: float) -> void:
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	_bars = maxf(_bars - rdt, 0.0)
	_bars_k = move_toward(_bars_k, 1.0 if _bars > 0.0 else 0.0, rdt * 4.0)
	_banner_t = maxf(_banner_t - dt, 0.0)
	_link_t = maxf(_link_t - rdt, 0.0)
	if is_instance_valid(hero):
		var k := hero.hp / hero.max_hp
		_hp_show = move_toward(_hp_show, k, dt * 0.5) if _hp_show > k else k
		# 头像镜头：放在主角脸前方偏上
		if hero.alive and hero.rig != null and hero.rig.parts.has("head"):
			var head: Node3D = hero.rig.parts["head"]
			var hp := head.global_position + Vector3(0, 0.24, 0)
			var fwd := hero.facing
			portrait_cam.global_position = hp + fwd * 1.5 + Vector3(0, 0.12, 0) + fwd.cross(Vector3.UP) * 0.35
			portrait_cam.look_at(hp, Vector3.UP)
	var vs := get_viewport_rect().size
	portrait_rect.position = Vector2(30, _panel_y(vs) - 52)
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
		var a := clampf(_banner_t / 0.4, 0.0, 1.0)
		var y := vs.y * 0.3
		draw_rect(Rect2(0, y - 46, vs.x, 80), Color(0, 0, 0, 0.45 * a))
		draw_line(Vector2(vs.x * 0.2, y - 46), Vector2(vs.x * 0.8, y - 46), Color(GOLD, 0.7 * a), 1.0)
		draw_line(Vector2(vs.x * 0.2, y + 34), Vector2(vs.x * 0.8, y + 34), Color(GOLD, 0.7 * a), 1.0)
		draw_string(font, Vector2(0, y), _banner, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 40, Color(0.95, 0.92, 0.85, a))
		if _banner_sub != "":
			draw_string(font, Vector2(0, y + 26), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 18, Color(0.6, 0.9, 0.9, a))


func _draw_link(vs: Vector2) -> void:
	var age := LINK_SHOW - _link_t
	var a := clampf(_link_t / 0.35, 0.0, 1.0) * clampf(age / 0.06, 0.0, 1.0)
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - age / 0.18)
	var y := vs.y * 0.19
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
	# 头像框：外圈金、内圈青
	draw_circle(c, 58, Color(0.02, 0.03, 0.04))
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
	draw_rect(Rect2(x0, y0 + 6, w, 9), Color(0.08, 0.02, 0.03))
	draw_rect(Rect2(x0, y0 + 6, w * _hp_show, 9), Color(0.95, 0.85, 0.8, 0.8))
	draw_rect(Rect2(x0, y0 + 6, w * hero.hp / hero.max_hp, 9), Color(0.78, 0.12, 0.14))
	draw_rect(Rect2(x0, y0 + 6, w, 9), Color(GOLD, 0.6), false, 1.0)
	draw_string(font, Vector2(x0 + w - 70, y0 - 4), "%d / %d" % [int(hero.hp), int(hero.max_hp)], HORIZONTAL_ALIGNMENT_RIGHT, 70, 15, Color(0.9, 0.85, 0.8))
	if hero.golden:
		draw_rect(Rect2(x0 - 3, y0 + 3, w + 6, 15), Color(1.0, 0.85, 0.4, 0.9), false, 2.0)   # 金身
	if hero._mirror_t > 0.0:
		draw_rect(Rect2(x0 - 5, y0 + 1, w + 10, 19), Color(0.7, 1.0, 0.9, 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.012)), false, 1.5)   # 双修·明镜
	var sets := []
	for pair: Array in [[hero.set_shura, "修罗场"], [hero.set_blood, "血涌"], [hero.set_wind, "御风"], [hero.set_light, "天光"], [hero.set_guard, "金身"]]:
		if pair[0]:
			sets.append(pair[1])
	if not sets.is_empty():
		draw_string(font, Vector2(x0, y0 + 66), "大成 " + "  ".join(sets), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
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


func _draw_skills(vs: Vector2) -> void:
	var items := [
		["突", "dash", 1.0 if hero._echo_t > 0.0 else 1.0 - float(hero.cd["dash"]) / hero.dash_cd, ArpgInput.key_name(hero.index, "dash")],
		["光", "beam", minf(hero.energy / hero.beam_cost, 1.0), ArpgInput.key_name(hero.index, "beam")],
		["终", "finish", 1.0 - float(hero.cd["finish"]) / hero.finish_cd, ArpgInput.key_name(hero.index, "finish")],
		["药", "heal", 1.0 if hero.gourds > 0 else 0.0, ArpgInput.key_name(hero.index, "heal")],
	]
	if hero.art_id() != "":
		items.insert(3, ["秘", "art", 1.0 - float(hero.cd["art"]) / hero.art_cd, ArpgInput.key_name(hero.index, "art")])
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
		draw_string(pixel, c + Vector2(-20, 44), it[3], HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(0.75, 0.8, 0.8))
	# 普攻和翻滚提示
	draw_string(pixel, Vector2(vs.x - 250, vs.y - 112), "%s 攻击  %s 翻滚" % [ArpgInput.key_name(hero.index, "attack"), ArpgInput.key_name(hero.index, "roll")], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.7))


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
	var w := vs.x * 0.5
	var x := (vs.x - w) * 0.5
	var y := 70.0
	draw_string(font, Vector2(0, y - 12), boss.display_name, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 24, Color(1.0, 0.75, 0.82))
	draw_rect(Rect2(x - 2, y - 2, w + 4, 14), Color(0, 0, 0, 0.6))
	var k := boss.hp / boss.max_hp
	var shown: float = _shown_hp.get(boss, 1.0)
	shown = move_toward(shown, k, 0.004) if shown > k else k
	_shown_hp[boss] = shown
	draw_rect(Rect2(x, y, w * shown, 10), Color(1.0, 0.9, 0.85, 0.7))
	draw_rect(Rect2(x, y, w * k, 10), Color(0.7, 0.08, 0.2))
	draw_rect(Rect2(x, y, w, 10), Color(GOLD, 0.7), false, 1.0)
	draw_rect(Rect2(x, y + 13, w * boss.poise / maxf(boss.max_poise, 1.0), 3), Color(1.0, 0.8, 0.4, 0.8))
	if boss.bleed > 0:
		draw_string(font, Vector2(x + w + 10, y + 11), "出血 ×%d" % boss.bleed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.35, 0.35))


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
