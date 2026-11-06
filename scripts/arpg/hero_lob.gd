class_name HeroLob
extends Node3D
## 主角扔出去的火油罐：抛一道弧线，落地炸开（伤害 35 × 主角伤害倍率），留下一滩烧敌人的火

const FLIGHT := 0.5

var hero: Hero
var from := Vector3.ZERO
var to := Vector3.ZERO
var _t := 0.0
var _mi: MeshInstance3D


func _ready() -> void:
	_mi = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.3, 0.36, 0.3)
	_mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.3, 0.16)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.2)
	m.emission_energy_multiplier = 1.2
	_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	global_position = from
	if Vfx.I != null:
		Vfx.I.telegraph_circle(to, 2.4, Color(0.5, 0.95, 1.0, 0.35), FLIGHT)   # 主角自己的落点用青色，和敌人的红橙预警分开


func _process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_t += dt
	var k := clampf(_t / FLIGHT, 0.0, 1.0)
	var p := from.lerp(to, k)
	p.y = lerpf(from.y, 0.2, k) + sin(k * PI) * 2.6
	global_position = p
	_mi.rotation += Vector3(9.0, 6.0, 0.0) * dt
	if Vfx.I != null and Vfx.I.lod > 0 and randf() < dt * 25.0:
		Vfx.I.pop(p, "spark_05", Color(1.0, 0.6, 0.2), 0.15, 0.45, 0.2)
	if k >= 1.0:
		_land()


func _land() -> void:
	var g := Vector3(to.x, 0, to.z)
	var fp := FirePool.new()
	fp.radius = 2.0
	fp.damage = 8.0 * (hero.dmg_mult if is_instance_valid(hero) else 1.0)
	fp.life = 4.0
	fp.hurts_foes = true
	fp.hero = hero
	get_parent().add_child(fp)
	fp.global_position = g
	if Vfx.I != null:
		Vfx.I.explosion(g + Vector3(0, 0.4, 0), 0.9)
		Vfx.I.chips(g + Vector3(0, 0.3, 0), Vector3.UP, Color(0.5, 0.32, 0.2), 10, 6.0, 0.1)
		Vfx.I.shock_ring(g, Color(1.0, 0.55, 0.2), 0.4, 3.0, 0.35)
	Game.sfx("boom", -4.0)
	if CamRig.I != null:
		CamRig.I.shake(1)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var d := a.global_position - g
		d.y = 0
		if d.length() > 2.4 + a.radius:
			continue
		var info := HitInfo.make(hero if is_instance_valid(hero) else null, a, 35.0 * (hero.dmg_mult if is_instance_valid(hero) else 1.0), HitInfo.Weight.HEAVY)
		info.attacker = null
		info.dir = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
		info.knock = 7.0
		Feel.I.on_hit(info)
	queue_free()
