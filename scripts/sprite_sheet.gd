class_name SpriteSheet
extends RefCounted
## 逐帧像素动画的精灵表（tools/sprites/build.py 生成）：一张大图 + 一个 JSON。
## JSON 里每个动作记着用哪几帧、每帧多少毫秒、是否循环、剑尖和后手在每帧的位置；
## 攻击动作还有 phases = [前摇帧数, 判定帧数, 后摇帧数]，播放时按招式的前摇/判定/后摇时间对齐。
##
## 坐标：每格 frame 大小，脚底中心在格子里的 origin；剑尖等位置都是相对脚底中心、朝右时的像素。

var texture: Texture2D
var frame_size := Vector2i(112, 88)
var origin := Vector2(48, 80)
var cols := 16
var anims := {}

static var _cache := {}


static func load_sheet(json_path: String, png_path: String) -> SpriteSheet:
	var key := png_path
	if _cache.has(key):
		return _cache[key]
	var s := SpriteSheet.new()
	var f := FileAccess.open(json_path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	s.texture = load(png_path)
	s.frame_size = Vector2i(int(data["frame"][0]), int(data["frame"][1]))
	s.origin = Vector2(float(data["origin"][0]), float(data["origin"][1]))
	s.cols = int(data["cols"])
	s.anims = data["anims"]
	_cache[key] = s
	return s


func has(anim: String) -> bool:
	return anims.has(anim)


## 整个动作多长（秒）
func length(anim: String) -> float:
	var total := 0.0
	for ms in anims[anim]["ms"]:
		total += float(ms)
	return total / 1000.0


func count(anim: String) -> int:
	return (anims[anim]["frames"] as Array).size()


## 按时间取第几帧（动作里的序号）；不循环的停在最后一帧
func frame_at(anim: String, t: float) -> int:
	var a: Dictionary = anims[anim]
	var ms: Array = a["ms"]
	var total := 0.0
	for m in ms:
		total += float(m)
	var x := t * 1000.0
	if bool(a["loop"]):
		x = fmod(x, total)
	var acc := 0.0
	for i in range(ms.size()):
		acc += float(ms[i])
		if x < acc:
			return i
	return ms.size() - 1


## 按“第几段、这一段走到几成”取帧（攻击动作对齐前摇/判定/后摇）。段里各帧按毫秒的比例分
func frame_in_phase(anim: String, phase: int, k: float) -> int:
	var a: Dictionary = anims[anim]
	if not a.has("phases"):
		return frame_at(anim, k * length(anim))
	var ph: Array = a["phases"]
	var start := 0
	for i in range(phase):
		start += int(ph[i])
	var n := int(ph[mini(phase, ph.size() - 1)])
	if phase >= ph.size() or n <= 0:
		return count(anim) - 1
	var ms: Array = a["ms"]
	var total := 0.0
	for i in range(n):
		total += float(ms[start + i])
	var x := clampf(k, 0.0, 0.999) * total
	var acc := 0.0
	for i in range(n):
		acc += float(ms[start + i])
		if x < acc:
			return start + i
	return start + n - 1


## 这一帧在大图上的区域
func region(anim: String, i: int) -> Rect2:
	var idx := int(anims[anim]["frames"][clampi(i, 0, count(anim) - 1)])
	return Rect2(Vector2((idx % cols) * frame_size.x, (idx / cols) * frame_size.y), Vector2(frame_size))


## 剑尖位置（朝右、相对脚底中心）；这一帧剑在鞘里就返回 null
func tip(anim: String, i: int) -> Variant:
	var t: Variant = anims[anim]["tips"][clampi(i, 0, count(anim) - 1)]
	return null if t == null else Vector2(float(t[0]), float(t[1]))


func hand_b(anim: String, i: int) -> Vector2:
	var h: Array = anims[anim]["hb"][clampi(i, 0, count(anim) - 1)]
	return Vector2(float(h[0]), float(h[1]))
