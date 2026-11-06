class_name TideRing
extends Node3D
## 井中人·枯荣二阶段推出的水波：一圈冰蓝的水环从头目脚下往外涨，环的前沿扫到主角就挨打。
## 只在前沿那一窄条里判定，所以站远一点的人有时间看清楚；翻滚的无敌帧可以直接穿过去。

var damage := 16.0
var delay := 0.0
var owner_foe: Actor
var _src := ""   # 射出时记下射手种类：箭飞到时射手死了也知道是谁
var speed := 6.5
var max_r := 20.0
var band := 0.6
var color := Color(0.55, 0.9, 1.0)     # 环的颜色（铜钟僧的钟声是金色）
var elem := "water"
var _r := 0.6
var _hit := {}
var _ring: MeshInstance3D
var _glow: MeshInstance3D
var _m: ShaderMaterial
var _gm: ShaderMaterial


func _ready() -> void:
	if is_instance_valid(owner_foe) and owner_foe.get("kind") != null:
		_src = String(owner_foe.get("kind"))
	_m = _mat("lm_ring_b", Color(color, 0.95), 2.4)
	_ring = _quad(_m)
	_gm = _mat("lm_ring_b", Color(color.darkened(0.35), 0.5), 1.4)
	_glow = _quad(_gm)
	visible = delay <= 0.0


func _mat(tex: String, c: Color, e: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/%s.png" % tex))
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("energy", e)
	return m


func _quad(m: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation = Vector3(-PI / 2, 0, 0)
	mi.position.y = 0.06
	add_child(mi)
	return mi


func _process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	if delay > 0.0:
		delay -= dt
		if delay <= 0.0:
			visible = true
		return
	_r += speed * dt
	# 贴图里的环大约在半径 0.45 处，所以缩放 = 半径 × 2.2
	_ring.scale = Vector3.ONE * _r * 2.2
	_glow.scale = Vector3.ONE * (_r * 2.2 + 0.8)
	var fade := clampf(1.0 - (_r - max_r * 0.7) / (max_r * 0.3), 0.0, 1.0)
	_m.set_shader_parameter("color", Color(color, 0.95 * fade))
	_gm.set_shader_parameter("color", Color(color.darkened(0.35), 0.5 * fade))
	# 前沿溅起水花
	if Vfx.I != null and Vfx.I.lod > 0 and randf() < dt * 14.0:
		var a := randf() * TAU
		Vfx.I.chips(global_position + Vector3(cos(a), 0.15, sin(a)) * _r, Vector3(cos(a), 1.2, sin(a)), color.lightened(0.1), 2, 4.0, 0.08)
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive or _hit.has(hh) or hh.iframes > 0.0:
			continue
		var d := hh.global_position - global_position
		d.y = 0
		if absf(d.length() - _r) < band + hh.radius * 0.5:
			_hit[hh] = true
			var info := HitInfo.make(owner_foe if is_instance_valid(owner_foe) else null, hh, damage, HitInfo.Weight.HEAVY)
			info.src = _src
			info.attacker = null
			info.dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
			info.knock = 9.0
			info.elem = elem
			Feel.I.on_hit(info)
	if _r >= max_r:
		queue_free()
