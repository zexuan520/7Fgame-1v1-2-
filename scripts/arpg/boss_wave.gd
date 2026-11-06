class_name BossWave
extends Node3D
## 头目放出的地面剑气：沿直线往前飞，碰到主角造成伤害；樱粉色发光月牙。

var dir := Vector3.FORWARD
var speed := 13.0
var damage := 18.0
var life := 1.0
var owner_foe: Actor
var _src := ""   # 射出时记下射手种类：箭飞到时射手死了也知道是谁
var _t := 0.0
var _hit := {}
var _mi: MeshInstance3D


func _ready() -> void:
	if is_instance_valid(owner_foe) and owner_foe.get("kind") != null:
		_src = String(owner_foe.get("kind"))
	_mi = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 1.0)
	_mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/slash_03.png"))
	m.set_shader_parameter("color", Color(1.0, 0.45, 0.7))
	m.set_shader_parameter("energy", 3.0)
	_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_mi.rotation = Vector3(-PI / 2, 0, 0)
	rotation.y = atan2(-dir.x, -dir.z)


func _process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_t += dt
	global_position += dir * speed * dt
	_mi.scale = Vector3.ONE * (1.0 + _t)
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive or _hit.has(hh):
			continue
		var d := hh.global_position - global_position
		d.y = 0
		if d.length() < 1.0 + hh.radius:
			_hit[hh] = true
			var info := HitInfo.make(owner_foe if is_instance_valid(owner_foe) else null, hh, damage, HitInfo.Weight.LIGHT)
			info.src = _src
			info.attacker = null
			info.dir = dir
			info.knock = 6.0
			Feel.I.on_hit(info)
	if _t >= life:
		queue_free()
