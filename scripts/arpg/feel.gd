class_name Feel
extends CanvasLayer
## 打击感中枢：所有命中都走 on_hit(info)。
## 顿帧（攻击者和受击者同时停：轻 0.05 / 重 0.1 / 大招 0.15）、受击闪白、击退、黄色星形火花、方块碎屑、
## 伤害数字（从命中点弹出、随机偏移往上飘、淡出；暴击更大、黄色、缩放弹跳）、震屏强度随伤害挂钩、命中音效随机音高 ±10%。
## 也负责全屏停顿（world_pause）和全屏闪（大招白、终结红）。

static var I: Feel

const HITSTOP := [0.05, 0.1, 0.15]
const NUM_LIFE := 0.7

var world_pause := 0.0
var font: Font
var post: ShaderMaterial          # 后期材质（闪屏、受伤泛红）
var _nums: Array = []             # [Label, 世界坐标, 屏幕偏移速度, 已过时间, 是否暴击, 基础缩放]
var _flash := Color(0, 0, 0, 0)
var _flash_decay := 4.0
var _hurt := 0.0


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
	var hs: float = info.hitstop if info.hitstop >= 0.0 else HITSTOP[w]
	# 伤害越高顿得越久（最多再加 40%）
	hs *= 1.0 + clampf(info.damage / 120.0, 0.0, 0.4)
	if info.crit:
		hs *= 1.25
	tgt.freeze(hs)
	if info.attacker != null:
		info.attacker.freeze(hs * 0.9)
	var sl: int = info.shake if info.shake >= 0 else w
	if CamRig.I != null:
		CamRig.I.shake(sl, 1.0 + clampf(info.damage / 150.0, 0.0, 0.6))
	if Vfx.I != null:
		Vfx.I.hit_spark(info.point, w >= 1, info.crit)
		if info.crit:
			Vfx.I.sheet("crit-hit", info.point - Vector3(0, 0.7, 0), 3.3, Color(1, 1, 1), 2.2)
		elif w >= 1:
			Vfx.I.sheet("hit-spark", info.point - Vector3(0, 0.4, 0), 1.6, Color(1, 1, 1), 2.0, false, 0.0, 1.4)
		var chip_col := Color(0.92, 0.9, 0.82) if tgt.team == 1 else Color(0.9, 0.15, 0.2)
		Vfx.I.chips(info.point, info.dir + Vector3.UP * 0.3, chip_col, 5 + 4 * w, 5.0 + 2.0 * w)
	if Game.show_damage:
		var col := Color(1.0, 0.86, 0.3) if info.crit else (Color(1, 1, 1) if tgt.team == 1 else Color(1.0, 0.3, 0.3))
		number(info.point, "%d" % int(round(info.damage)), col, 1.45 if info.crit else 1.0, info.crit)
	var snd := "hit_heavy" if w >= 1 or info.crit else "hit"
	Game.sfx(snd, -3.0 if w < 1 else 0.0, 0.1)
	if info.attacker != null and info.gain > 0.0 and info.attacker.has_method("gain_energy"):
		info.attacker.call("gain_energy", info.gain)
	return true


## 伤害数字 / 飘字
func number(world_pos: Vector3, text: String, col: Color, scale: float = 1.0, crit: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(26 * scale))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.04))
	l.add_theme_constant_override("outline_size", 7)
	l.pivot_offset = Vector2(20, 16)
	l.visible = false
	add_child(l)
	var vel := Vector2(randf_range(-60, 60), randf_range(-150, -110))
	_nums.append([l, world_pos + Vector3(randf_range(-0.25, 0.25), 0.2, 0), vel, 0.0, crit, 1.0])


## 屏幕中间偏上的大字（连段“1段!”、技能名）
func callout(world_pos: Vector3, text: String, col: Color, scale: float = 1.0) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(30 * scale))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.07))
	l.add_theme_constant_override("outline_size", 8)
	l.visible = false  # 第一帧算出屏幕位置前先藏着，不然会在左上角闪一下
	add_child(l)
	_nums.append([l, world_pos, Vector2(0, -50), 0.0, true, 1.0])


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
			l.position = sp + off - l.size * 0.5
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
