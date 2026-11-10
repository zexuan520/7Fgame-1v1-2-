class_name Feel
extends CanvasLayer
## 打击感中枢：所有命中都走 on_hit(info)。
## 顿帧（攻击者和受击者同时停：轻 0.05 / 重 0.1 / 大招 0.15）、受击闪白、击退、黄色星形火花、方块碎屑、
## 伤害数字（从命中点弹出、随机偏移往上飘、淡出；暴击更大、黄色、缩放弹跳）、震屏强度随伤害挂钩、命中音效随机音高 ±10%。
## 也负责全屏停顿（world_pause）和全屏闪（大招白、终结红）。

static var I: Feel

const HITSTOP := [0.05, 0.1, 0.15]   # 旧的按重量取的默认值（别的地方还在引用）
## 顿帧三档（秒）：弱击 / 强击 / 会心，各自一个区间，按伤害和连击在区间里取；大招另算
const STOP_WEAK := Vector2(0.035, 0.055)   # 2026-11：原来 0~0.03，轻击几乎不顿，砍上去像砍空气
const STOP_STRONG := Vector2(0.05, 0.08)
const STOP_CRIT := Vector2(0.1, 0.15)
const STOP_ULT := 0.15
const STOP_KILL := 0.08        # 斩杀至少按强击顿
const FLASH_T := 0.08          # 受击闪白
const NUM_LIFE := 0.7
## 同时最多几张大字（“4段!”“破韧!”“连携·残月”）、几个伤害数字：多了互相压着反而读不出来
const CALLOUT_MAX := 3
const NUMBER_MAX := 22

var world_pause := 0.0
var font: Font
var post: ShaderMaterial          # 后期材质（闪屏、受伤泛红）
var _nums: Array = []             # [Label, 世界坐标, 屏幕偏移速度, 已过时间, 是否暴击, 基础缩放, 固定屏幕偏移, 大字文本（伤害数字是 ""）]
var _flash := Color(0, 0, 0, 0)
var _flash_decay := 4.0
var _hurt := 0.0
var _slow_scale := 1.0
var _slow_left := 0.0
var _slow_dur := 0.0
const COMBO_KEEP := 2.2           # 多久没打中就断连击
const COMBO_TIERS := [[10, Color(0.55, 1.0, 1.0)], [25, Color(1.0, 0.85, 0.35)], [50, Color(1.0, 0.4, 0.35)]]
var combo := 0
var _combo_t := 0.0
var _combo_punch := 0.0
var _combo_lbl: Label
var _frame := -1                  # 同一物理帧里第几下命中（一刀扫中一群：镜头、火花只算头两下，不叠成一大坨）
var _frame_hits := 0
var _impact := 0.0                # 冲击帧剩余时间（全屏黑白一两帧）
var _impact_cd := 0.0
var _speed: TextureRect           # 冲击帧时盖在屏幕上的放射速度线（pixelfx impact-frame 第 2~9 帧）
var _speed_t := -1.0


func _ready() -> void:
	I = self
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/fonts/serif-sc.woff2"):
		font = load("res://assets/fonts/serif-sc.woff2")
	else:
		font = Game.font


func on_hit(info: HitInfo) -> bool:
	var tgt := info.target
	if tgt == null or not tgt.take_hit(info):
		return false
	var w := int(info.weight)
	# 技能命中时 attacker 是空的（主角瞬移后不停顿），按挨打的一方算
	var hero_hit := (info.attacker != null and info.attacker.team == 0) or (info.attacker == null and tgt.team == 1)
	var boss := tgt is Foe and (tgt as Foe).is_boss
	var killed := not tgt.alive
	if hero_hit:
		_combo_add()
	elif tgt.team == 0:
		_combo_break()
	var pf := Engine.get_physics_frames()
	if pf != _frame:
		_frame = pf
		_frame_hits = 0
	_frame_hits += 1
	var extra := _frame_hits > 2        # 同一帧第三下以后：只出伤害数字、小火花，镜头不再推
	var hs := _hitstop(info, w, hero_hit, killed)
	tgt.freeze(hs)
	if hs > 0.0 and not killed:
		tgt.shiver(hs + 0.04, (0.05 if w == 0 else 0.09) * (0.5 if boss else 1.0) * (1.3 if info.crit else 1.0))
	if info.attacker != null:
		info.attacker.self_stop(hs * 0.9)
	if not extra or tgt.team == 0:
		_rumble_hit(info, w, hero_hit, killed, boss)
	# 受击挤压：压扁再弹回
	if tgt.rig != null:
		tgt.rig.squash((0.16 if w == 0 else 0.26) * (0.45 if boss else 1.0) * (1.3 if info.crit else 1.0))
		if tgt.team == 0:
			tgt.rig.flash(0.12, Color(1.0, 0.35, 0.35))
		# 后仰：顺着刀的方向歪一下（头目只歪一点，主角挨打也歪）
		tgt.rig.recoil(info.dir, (0.16 if w == 0 else 0.28) * (0.35 if boss else 1.0) * (1.25 if info.crit else 1.0) * (0.7 if tgt.team == 0 else 1.0))
	# 震屏逐档增强：弱 → 强 → 会心（会心至少按中档，再大三成）
	var sl: int = info.shake if info.shake >= 0 else (maxi(w, 1) if info.crit else w)
	if CamRig.I != null and not extra:
		CamRig.I.shake(sl, (1.0 + clampf(info.damage / 150.0, 0.0, 0.6)) * (1.3 if info.crit and info.shake < 0 else 1.0))
		# 定向冲击：镜头顺着打击方向推一下（挨打时更猛，让玩家“疼”）
		var kick: float = [0.06, 0.13, 0.2][w] * (1.4 if tgt.team == 0 else 1.0) * (1.3 if info.crit else 1.0)
		CamRig.I.kick(info.dir, kick, 0.0 if w == 0 else 0.012 * (w + 1))
	if Vfx.I != null:
		var spark_col := Color(1.0, 0.86, 0.35)
		if tgt.team == 0:
			spark_col = Color(1.0, 0.3, 0.25) if info.elem == "" else Vfx.ELEM_COLOR.get(info.elem, Color(1.0, 0.3, 0.25))
			if info.elem != "":
				Vfx.I.elem_burst(info.point, info.elem, w >= 1)
		elif boss:
			spark_col = (tgt as Foe).fx_color()
		Vfx.I.hit_spark(info.point, w >= 1, info.crit)
		if hero_hit:
			_weapon_fx(info, w)
		if extra:
			Vfx.I.chips(info.point, info.dir + Vector3.UP * 0.3, Color(0.92, 0.9, 0.82) if tgt.team == 1 else Color(0.9, 0.15, 0.2), 3, 5.0)
		else:
			_hit_fx(info, tgt, w, boss, hero_hit, spark_col)
	if Game.show_damage:
		var col := Color(1.0, 0.86, 0.3) if info.crit else (Color(1, 1, 1) if tgt.team == 1 else Color(1.0, 0.3, 0.3))
		number(info.point, "%d" % int(round(info.damage)), col, 1.45 if info.crit else 1.0, info.crit)
	# 声音：命中音随连段慢慢升调（最多高 3 个半音），会心叠一声刀鸣，击杀叠一记闷响
	var snd := "hit_heavy" if w >= 1 or info.crit else "hit"
	if info.snd != "":
		snd = info.snd
	var pitch := 1.0 + (minf(combo, 30) / 30.0 * 0.19 if hero_hit else 0.0)
	Game.sfx(snd, -3.0 if w < 1 else 0.0, 0.08, pitch)
	if info.crit:
		Game.sfx("crit", -6.0, 0.05)
	if killed and tgt.team == 1:
		Game.sfx("kill", -4.0 if not boss else 0.0, 0.08)
	if info.attacker != null and info.gain > 0.0 and info.attacker.has_method("gain_energy"):
		info.attacker.call("gain_energy", info.gain)
	return true


## 震动：手柄（左右两个马达）和手机（只有一个马达，只在重击、会心、斩杀、挨打时震，免得一直嗡嗡）
var _rumble_cd := 0.0


func rumble(weak: float, strong: float, dur: float, handheld := false) -> void:
	if not bool(Game.settings.get("rumble", true)):
		return
	for d: int in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), dur)
	if handheld and TouchPad.active and _rumble_cd <= 0.0:
		_rumble_cd = 0.12
		Input.vibrate_handheld(int(dur * 1000.0), clampf(maxf(weak, strong), 0.1, 1.0))
	if OS.get_cmdline_user_args().has("--feellog"):
		print("FEEL rumble %.2f %.2f %.2f %s" % [weak, strong, dur, handheld])


func _rumble_hit(info: HitInfo, w: int, hero_hit: bool, killed: bool, boss: bool) -> void:
	if info.target.team == 0:
		rumble(0.55, 0.8, 0.18, true)
	elif hero_hit:
		if killed and boss:
			rumble(1.0, 1.0, 0.4, true)
		elif w >= HitInfo.Weight.ULT:
			rumble(0.8, 0.9, 0.25, true)
		elif info.crit:
			rumble(0.5, 0.6, 0.13, true)
		elif killed:
			rumble(0.3, 0.45, 0.1, true)
		elif w >= HitInfo.Weight.HEAVY:
			rumble(0.4, 0.3, 0.09, false)
		else:
			rumble(0.22, 0.0, 0.05, false)


## 这一下顿多久：显式给了 hitstop 就用它；多段攻击的中间段不顿；否则按 弱 / 强 / 会心 三档区间取
func _hitstop(info: HitInfo, w: int, hero_hit: bool, killed: bool) -> float:
	if info.multi_mid and not killed:
		return 0.0
	var k := clampf(info.damage / 120.0, 0.0, 1.0)
	if hero_hit:
		k = clampf(k + combo / 80.0, 0.0, 1.0)
	var hs: float
	if info.hitstop >= 0.0:
		hs = info.hitstop * (1.25 if info.crit else 1.0)
	elif w >= HitInfo.Weight.ULT:
		hs = STOP_ULT
	elif info.crit:
		hs = lerpf(STOP_CRIT.x, STOP_CRIT.y, k)
	elif w >= HitInfo.Weight.HEAVY:
		hs = lerpf(STOP_STRONG.x, STOP_STRONG.y, k)
	else:
		hs = lerpf(STOP_WEAK.x, STOP_WEAK.y, k)
	if killed:
		hs = maxf(hs, STOP_KILL)
	if info.target != null and info.target.team == 0:
		hs = maxf(hs, STOP_STRONG.x)   # 主角挨打至少顿到强击下限，疼要让人感觉到
	return hs


## 一下命中的冲击线、会心字、地面刀痕、碎块（同一帧头两下才放）
func _hit_fx(info: HitInfo, tgt: Actor, w: int, boss: bool, hero_hit: bool, spark_col: Color) -> void:
	Vfx.I.streaks(info.point, info.dir, spark_col if not info.crit else Color(1.0, 0.95, 0.6),
		3 + w * 2 + (2 if info.crit else 0), 1.1 + 0.5 * w, 0.12 + 0.03 * w)
	if info.crit:
		Vfx.I.sheet("crit-hit", info.point - Vector3(0, 0.7, 0), 3.3, Color(1, 1, 1), 2.2)
		Vfx.I.cut_line(info.point, info.dir.rotated(Vector3.UP, PI / 2) + Vector3.UP * 0.6, 3.0, Color(1, 1, 0.85), 0.16, 0.16, Color(1.0, 0.8, 0.3))
	elif w >= 1 or boss:
		Vfx.I.sheet("hit-spark", info.point - Vector3(0, 0.4, 0), 1.6, Color(1, 1, 1), 2.0, false, 0.0, 1.4)
	if w >= 1 and hero_hit:
		Vfx.I.scar(tgt.global_position - info.dir * 0.3, info.dir, 1.4 + 0.4 * w)
	var chip_col := Color(0.92, 0.9, 0.82) if tgt.team == 1 else Color(0.9, 0.15, 0.2)
	Vfx.I.chips(info.point, info.dir + Vector3.UP * 0.3, chip_col, 5 + 4 * w, 5.0 + 2.0 * w)


## 兵器手感：锤、棍砸出一圈尘土和更大的碎块，枪一下扎穿（顺着刺的方向拉出一道穿透光），弩箭钉进去冒木屑
func _weapon_fx(info: HitInfo, w: int) -> void:
	match info.snd:
		"hit_blunt":
			var gp := Vector3(info.target.global_position.x, 0.0, info.target.global_position.z)
			# 像素砸击（pixelfx blunt-hit）：白闪 + 一圈短刺 + 一团土；重击脚下再拍出一圈落地尘（heavy-landing）
			if Vfx.I.room_for(2):
				Vfx.I.sheet("blunt-hit", info.point - Vector3(0, 0.55, 0), 2.5 + 0.6 * w, Color(1, 0.95, 0.85), 2.2, false, 0.0, 1.5)
			if w >= 1 and _frame_hits == 1 and Vfx.I.lod >= 1:
				Vfx.I.sheet("heavy-landing", gp, 2.0, Color(0.85, 0.82, 0.75), 1.3, false, 0.0, 1.6)
			elif w >= 1 or _frame_hits == 1:
				Vfx.I.dust(gp, 1.0 + 0.5 * w, Color(0.55, 0.5, 0.42, 0.5))
			Vfx.I.chips(info.point, Vector3.UP + info.dir * 0.4, Color(0.8, 0.78, 0.7), 3 + 2 * w, 6.5, 0.13)
		"hit_pierce":
			var p := info.point + info.dir * 0.6
			Vfx.I.cut_line(p, info.dir, 2.6 + 0.8 * w, Color(1, 1, 1), 0.14, 0.12, Color(1.0, 0.75, 0.4))
			Vfx.I.streaks(p + info.dir * 0.4, info.dir, Color(1.0, 0.85, 0.55), 2 + w, 1.6, 0.12, 0.12, 0.1)
		"arrow_hit":
			Vfx.I.chips(info.point, -info.dir + Vector3.UP * 0.5, Color(0.55, 0.42, 0.28), 3, 4.0, 0.06)


## 冲击帧：全屏一两帧变成黑白高反差（动漫式“定格”），t 秒；一秒内最多一次，免得闪个不停
func impact_frame(t: float = 0.05) -> void:
	if _impact_cd > 0.0 or not bool(Game.settings.get("impact_frames", true)):
		return
	_impact = t
	_impact_cd = 1.0
	_speed_lines()
	if OS.get_cmdline_user_args().has("--feellog"):
		print("FEEL impact %.2f post=%s" % [t, post != null])



func _speed_lines() -> void:
	if _speed == null:
		_speed = TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/fx/pfx/impact-frame.png")
		_speed.texture = at
		_speed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_speed.stretch_mode = TextureRect.STRETCH_SCALE
		_speed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_speed.set_anchors_preset(Control.PRESET_FULL_RECT)
		_speed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_speed)
		move_child(_speed, 0)
	_speed_t = 0.0
	_tick_speed(0.0)


## 速度线按真实时间 30 帧每秒播，从第 2 帧（四周放射）播到第 9 帧，越往后越淡
func _tick_speed(real_dt: float) -> void:
	if _speed_t < 0.0 or _speed == null:
		return
	_speed_t += real_dt
	var f := 2 + int(_speed_t * 30.0)
	if f > 9:
		_speed.visible = false
		_speed_t = -1.0
		return
	(_speed.texture as AtlasTexture).region = Rect2((f % 3) * 320, (f / 3) * 180, 320, 180)
	_speed.visible = true
	_speed.modulate = Color(1, 1, 1, 0.42 * (1.0 - (f - 2) / 8.0))


var _multi := 0
var _multi_t := -9.0


## 敌人倒下（Foe.die 调）：斩线 + 放射线；精英、一波最后一个、头目会短暂慢镜头
func on_kill(f: Foe, impulse: Vector3) -> void:
	var p := f.chest()
	var last := get_tree().get_nodes_in_group("foes").filter(func(n: Node) -> bool: return n != f and (n as Actor).alive).is_empty()
	if f.is_boss:
		# 倒下：先定格一瞬，再慢镜头、镜头特写、上下黑边
		pause_world(0.3)
		_impact_cd = 0.0
		impact_frame(0.09)
		slowmo(0.15, 1.6)
		CamRig.I.close_up(f, 2.2, 0.85)
		if Hud3D.I != null:
			Hud3D.I.cinema(2.6)
		screen_flash(Color(1, 1, 1, 0.85), 1.6)
		Vfx.I.boss_burst(p, f.fx_color())
		CamRig.I.punch_zoom(0.9, 1.0)
		CamRig.I.shake(2, 1.6)
		Game.sfx("boss_kill", 2.0, 0.0)
		callout(f.head_top() + Vector3(0, 0.8, 0), "斩!", Color(1.0, 0.95, 0.85), 2.4)
		return
	var elite := f.max_poise > 0.0
	Vfx.I.kill_burst(p, impulse, Color(1.0, 0.85, 0.4) if not elite else Color(1.0, 0.55, 0.3), elite)
	# 2026-11-10 第二档 H3：一刀带走好几个（骨潮房常见）：0.25 秒内第三个起，每个都顿一下、镜头一推、低频再“咚”一声
	var now := Time.get_ticks_msec() / 1000.0
	_multi = _multi + 1 if now - _multi_t < 0.25 else 1
	_multi_t = now
	if _multi >= 3 and not last:
		pause_world(0.03)
		CamRig.I.punch_zoom(0.2 + 0.05 * mini(_multi - 3, 4), 0.15)
		Game.sfx("hit_blunt", -6.0, 0.05, 0.8)
	if last:
		# 清完一波：先定格两帧，再慢镜头 + 拉近，给玩家一口气
		pause_world(0.035)
		slowmo(0.22, 0.55)
		impact_frame(0.05)
		CamRig.I.punch_zoom(0.55, 0.45)
		screen_flash(Color(1, 1, 1, 0.25), 3.0)
	elif elite:
		slowmo(0.35, 0.22)
		impact_frame(0.04)
		CamRig.I.punch_zoom(0.35, 0.18)


## 慢镜头：时间缩放到 scale，持续 dur 秒（真实时间），最后 40% 慢慢恢复
func slowmo(scale: float, dur: float) -> void:
	if _slow_left <= 0.0 or scale < _slow_scale:
		_slow_scale = scale
	_slow_dur = maxf(_slow_left, dur)
	_slow_left = _slow_dur


func _tick_slow(real_dt: float) -> void:
	if _slow_left > 0.0:
		_slow_left = maxf(_slow_left - real_dt, 0.0)
		var k := _slow_left / maxf(_slow_dur, 0.001)   # 1 → 0
		var ts := _slow_scale if k > 0.4 else lerpf(1.0, _slow_scale, k / 0.4)
		Engine.time_scale = ts
		if _slow_left <= 0.0:
			Engine.time_scale = 1.0
			_slow_scale = 1.0


# ---------- 连击计数 ----------

func _combo_add() -> void:
	combo += 1
	_combo_t = COMBO_KEEP
	if combo < 3:
		return
	_combo_punch = 1.0
	if _combo_lbl == null:
		_combo_lbl = Label.new()
		_combo_lbl.add_theme_font_override("font", font)
		_combo_lbl.add_theme_constant_override("outline_size", 10)
		_combo_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06))
		_combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_combo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_combo_lbl)
	var col := Color(1, 1, 1)
	for tier: Array in COMBO_TIERS:
		if combo >= int(tier[0]):
			col = tier[1]
	_combo_lbl.text = "%d 连击" % combo
	_combo_lbl.add_theme_font_size_override("font_size", 34 if combo < 25 else 40)
	_combo_lbl.add_theme_color_override("font_color", col)
	_combo_lbl.visible = true
	_combo_lbl.modulate.a = 1.0
	if combo in [10, 25, 50, 100]:
		_combo_punch = 1.8
		Game.sfx("crit", -8.0, 0.0, 0.8 + combo / 100.0)


func _combo_break() -> void:
	if combo >= 3 and _combo_lbl != null:
		_combo_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	combo = 0
	_combo_t = minf(_combo_t, 0.35)


func _tick_combo(dt: float) -> void:
	if _combo_t > 0.0:
		_combo_t -= dt
		if _combo_t <= 0.0:
			combo = 0
	if _combo_lbl == null or not _combo_lbl.visible:
		return
	var vs := get_viewport().get_visible_rect().size
	_combo_punch = maxf(_combo_punch - dt * 6.0, 0.0)
	var s := 1.0 + 0.35 * _combo_punch
	_combo_lbl.scale = Vector2(s, s)
	_combo_lbl.size = Vector2(260, 60)
	_combo_lbl.pivot_offset = Vector2(260, 30)
	_combo_lbl.position = Vector2(vs.x - 260 - vs.x * 0.04, vs.y * 0.26)
	if _combo_t <= 0.35:
		_combo_lbl.modulate.a = maxf(_combo_t / 0.35, 0.0)
		if _combo_t <= 0.0:
			_combo_lbl.visible = false


## 伤害数字 / 飘字
func number(world_pos: Vector3, text: String, col: Color, scale: float = 1.0, crit: bool = false) -> void:
	# 2026-11-07：数字加投影（往右下错 3 像素的深色），会心字描暖色粗边、斜一点；大数字按伤害再放大一点
	var l := Label.new()
	l.text = text
	var big := clampf((float(text.to_int()) - 20.0) / 60.0, 0.0, 0.35) if text.is_valid_int() else 0.0
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(26 * scale * (1.0 + big)))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.45, 0.12, 0.02) if crit else Color(0.05, 0.03, 0.04))
	l.add_theme_constant_override("outline_size", 10 if crit else 7)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	if crit:
		l.rotation = randf_range(-0.12, 0.12)
	l.pivot_offset = Vector2(20, 16)
	l.visible = false
	add_child(l)
	var vel := Vector2(randf_range(-60, 60), randf_range(-150, -110))
	_nums.append([l, world_pos + Vector3(randf_range(-0.25, 0.25), 0.2, 0), vel, 0.0, crit, 1.0, Vector2.ZERO, ""])
	_trim_nums()


## 伤害数字太多时先收掉最老的
func _trim_nums() -> void:
	var n := 0
	for e: Array in _nums:
		if String(e[7]) == "":
			n += 1
	var i := 0
	while n > NUMBER_MAX and i < _nums.size():
		var e: Array = _nums[i]
		if String(e[7]) == "":
			(e[0] as Label).queue_free()
			_nums.remove_at(i)
			n -= 1
		else:
			i += 1


## 屏幕中间偏上的大字（连段“1段!”、技能名）
## 招式名大字：同一招一局只弹头两次（认识了就不必每刀都挡在人头上）；key 不给就按文字
static var _called_n := {}


func callout_once(world_pos: Vector3, text: String, col: Color, scale: float = 1.0, key: String = "") -> void:
	var kk := key if key != "" else text
	var n := int(_called_n.get(kk, 0))
	if n >= 2:
		return
	_called_n[kk] = n + 1
	callout(world_pos, text, col, scale)


func callout(world_pos: Vector3, text: String, col: Color, scale: float = 1.0) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(30 * scale))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.07))
	l.add_theme_constant_override("outline_size", 8)
	l.visible = false  # 第一帧算出屏幕位置前先藏着，不然会在左上角闪一下
	# 同一句大字 0.35 秒内又来：刷新旧的，不再叠一张
	for e: Array in _nums:
		if String(e[7]) == text and float(e[3]) < 0.35:
			e[3] = 0.0
			l.free()
			return
	# 大字往上错开排队，最多同时 3 张（太多就先收掉最老的）
	var calls: Array = _nums.filter(func(e: Array) -> bool: return String(e[7]) != "")
	while calls.size() >= CALLOUT_MAX:
		var old: Array = calls.pop_front()
		(old[0] as Label).queue_free()
		_nums.erase(old)
	add_child(l)
	_nums.append([l, world_pos, Vector2(0, -50), 0.0, true, 1.0, Vector2(0, -36.0 * calls.size() * scale), text])


## 全屏闪：c 的 alpha 是强度
func screen_flash(c: Color, decay: float = 4.0) -> void:
	_flash = c
	_flash_decay = decay


func hurt_pulse(v: float = 0.6) -> void:
	_hurt = maxf(_hurt, v)


## 全屏停顿（大招）：所有角色的时间停住，特效照常
func pause_world(t: float) -> void:
	world_pause = maxf(world_pause, t)


func _process(dt: float) -> void:
	var _pt := Time.get_ticks_usec() if PerfProbe.on else 0
	_process_body(dt)
	if PerfProbe.on:
		PerfProbe.add("feel", _pt)


func _process_body(dt: float) -> void:
	_rumble_cd = maxf(_rumble_cd - dt, 0.0)
	# dt 已经乘过 Engine.time_scale；慢镜头本身要按真实时间走
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	_tick_slow(real_dt)
	_impact_cd = maxf(_impact_cd - real_dt, 0.0)
	_tick_combo(dt)
	world_pause = maxf(world_pause - dt, 0.0)
	var cam := get_viewport().get_camera_3d()
	var i := 0
	while i < _nums.size():
		var e: Array = _nums[i]
		var l: Label = e[0]
		e[3] = float(e[3]) + dt
		var t: float = e[3]
		var life := NUM_LIFE * (1.3 if bool(e[4]) else 1.0)
		if t >= life or cam == null:
			l.queue_free()
			_nums.remove_at(i)
			continue
		var wp: Vector3 = e[1]
		if cam.is_position_behind(wp):
			l.visible = false
		else:
			var sp := cam.unproject_position(wp)
			var v: Vector2 = e[2]
			var off := v * t + Vector2(0, 160.0) * t * t
			l.position = sp + off - l.size * 0.5 + (e[6] as Vector2)
			l.pivot_offset = l.size * 0.5
			l.visible = true
		# 暴击：先放大弹一下再回落
		var s := 1.0
		if bool(e[4]):
			s = 1.0 + 0.6 * exp(-t * 14.0) * cos(t * 30.0)
		else:
			s = 1.0 + 0.3 * exp(-t * 20.0)
		l.scale = Vector2(s, s)
		l.modulate.a = clampf((life - t) / 0.25, 0.0, 1.0)
		i += 1
	if post != null:
		if _flash.a > 0.0:
			_flash.a = maxf(_flash.a - dt * _flash_decay, 0.0)
		post.set_shader_parameter("flash", _flash)
		_hurt = maxf(_hurt - dt * 1.5, 0.0)
		post.set_shader_parameter("hurt", _hurt)
		post.set_shader_parameter("impact", 1.0 if _impact > 0.0 else 0.0)
		_impact = maxf(_impact - real_dt, 0.0)
	_tick_speed(real_dt)
