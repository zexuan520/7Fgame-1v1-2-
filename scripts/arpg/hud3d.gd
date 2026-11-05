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
var wave_text := ""
var seals: Array = []            # 试炼房四枚印：0 没开始 / 1 进行中 / 2 得印 / 3 失手
var coins := 0
var jade := 0
var boss: Foe
var _banner := ""
var _banner_t := 0.0
var _banner_sub := ""
var _hp_show := 1.0               # 血条掉血时慢慢跟上的白色残影
var _shown_hp := {}


func _ready() -> void:
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


func banner(text: String, sub: String = "", t: float = 2.2) -> void:
	_banner = text
	_banner_sub = sub
	_banner_t = t


func _process(dt: float) -> void:
	_banner_t = maxf(_banner_t - dt, 0.0)
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
	if _banner_t > 0.0:
		var a := clampf(_banner_t / 0.4, 0.0, 1.0)
		var y := vs.y * 0.3
		draw_rect(Rect2(0, y - 46, vs.x, 80), Color(0, 0, 0, 0.45 * a))
		draw_line(Vector2(vs.x * 0.2, y - 46), Vector2(vs.x * 0.8, y - 46), Color(GOLD, 0.7 * a), 1.0)
		draw_line(Vector2(vs.x * 0.2, y + 34), Vector2(vs.x * 0.8, y + 34), Color(GOLD, 0.7 * a), 1.0)
		draw_string(font, Vector2(0, y), _banner, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 40, Color(0.95, 0.92, 0.85, a))
		if _banner_sub != "":
			draw_string(font, Vector2(0, y + 26), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 18, Color(0.6, 0.9, 0.9, a))


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
	var e := hero.energy / hero.max_energy
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
	draw_rect(Rect2(x0, y0 + 6, w, 9), Color(0.08, 0.02, 0.03))
	draw_rect(Rect2(x0, y0 + 6, w * _hp_show, 9), Color(0.95, 0.85, 0.8, 0.8))
	draw_rect(Rect2(x0, y0 + 6, w * hero.hp / hero.max_hp, 9), Color(0.78, 0.12, 0.14))
	draw_rect(Rect2(x0, y0 + 6, w, 9), Color(GOLD, 0.6), false, 1.0)
	draw_string(font, Vector2(x0 + w - 70, y0 - 4), "%d / %d" % [int(hero.hp), int(hero.max_hp)], HORIZONTAL_ALIGNMENT_RIGHT, 70, 15, Color(0.9, 0.85, 0.8))
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
		["突", "dash", 1.0 - float(hero.cd["dash"]) / hero.dash_cd, ArpgInput.key_name(hero.index, "dash")],
		["光", "beam", hero.energy / hero.max_energy, ArpgInput.key_name(hero.index, "beam")],
		["终", "finish", 1.0 - float(hero.cd["finish"]) / hero.finish_cd, ArpgInput.key_name(hero.index, "finish")],
		["药", "heal", 1.0 if hero.gourds > 0 else 0.0, ArpgInput.key_name(hero.index, "heal")],
	]
	for i in range(items.size()):
		var it: Array = items[i]
		var c := Vector2(vs.x - 250 + i * 62, vs.y - 64)
		var ready := float(it[2]) >= 0.999
		draw_circle(c, 25, PANEL)
		var col := TEAL
		if it[1] == "finish":
			col = Color(1.0, 0.3, 0.3)
		elif it[1] == "beam":
			col = Color(1.0, 0.85, 0.4)
		elif it[1] == "heal":
			col = Color(0.4, 1.0, 0.6)
		# 冷却：暗色扇形 + 亮色进度环
		if not ready:
			var pts := PackedVector2Array([c])
			var a0 := -PI / 2 + TAU * float(it[2])
			for s in range(25):
				var a := lerpf(a0, -PI / 2 + TAU, s / 24.0)
				pts.append(c + Vector2(cos(a), sin(a)) * 24)
			if pts.size() > 2:
				draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		draw_arc(c, 27, -PI / 2, -PI / 2 + TAU * clampf(float(it[2]), 0, 1), 48, col if ready else Color(col, 0.6), 3.0, true)
		draw_arc(c, 25, 0, TAU, 48, Color(GOLD, 0.5), 1.0, true)
		draw_string(font, c + Vector2(-13, 9), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col if ready else Color(0.5, 0.55, 0.55))
		draw_string(pixel, c + Vector2(-20, 44), it[3], HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(0.75, 0.8, 0.8))
	# 普攻和翻滚提示
	draw_string(pixel, Vector2(vs.x - 250, vs.y - 112), "%s 攻击  %s 翻滚" % [ArpgInput.key_name(hero.index, "attack"), ArpgInput.key_name(hero.index, "roll")], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.7))


func _draw_enemy_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Foe
		if a == null or not a.alive or a.is_boss:
			continue
		var wp := a.head_top()
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var w := 46.0 * (1.25 if a.kind == "samurai" else 1.0)
		var k := a.hp / a.max_hp
		var shown: float = _shown_hp.get(a, 1.0)
		shown = move_toward(shown, k, 0.01) if shown > k else k
		_shown_hp[a] = shown
		if k >= 0.999 and a.bleed <= 0:
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
