class_name FirePool
extends Node3D
## 地上一滩火：披火骨死后留下的、不夜将军二阶段点着的灯油。站在里面每 0.5 秒烫一下（只伤主角，烧不死人）。
## warn > 0 时先亮一圈预警，过了这段时间才烧起来。
## elem = "poison" 时是一滩毒瘴（瘴菇骨、瘴毒词缀、瘴林）：绿色、冒烟，字是“毒”。

var radius := 1.6
var damage := 6.0
var life := 4.0
var warn := 0.0
var elem := "fire"
var hurts_foes := false   # 主角扔的火油罐：烧敌人，不烧自己
var hero: Actor           # 扔火的人（算伤害归属）
var _t := 0.0
var _tick := 0.0
var _lit := false


func _ready() -> void:
	if warn > 0.0:
		Vfx.I.telegraph_circle(global_position, radius, Vfx.DANGER["poison" if elem == "poison" else "fire"], warn)
	else:
		_light()


func _light() -> void:
	_lit = true
	if elem == "poison":
		_light_poison()
		return
	Vfx.I.ground(global_position, "scorch_01", Color(0.08, 0.04, 0.02, 0.8), radius * 1.8, radius * 2.0, life + 0.6, false)
	Vfx.I.ground(global_position, "magic_03", Color(1.0, 0.45, 0.12, 0.7), radius * 1.6, radius * 2.1, life, true, 0.15)
	var n := 3 if Vfx.I.lod > 0 else 1
	for i in range(n):
		var a := TAU * i / n + randf()
		var f := Vfx.I.sheet("spirit-flame", global_position + Vector3(cos(a), 0, sin(a)) * radius * 0.45, 1.1, Color(1.0, 0.55, 0.2), 2.2, false, life)
		if f != null:
			f.reparent(self)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 1.6
	l.omni_range = radius * 3.0
	add_child(l)
	l.position.y = 0.6
	Game.sfx("flame", -8.0, 0.1, 0.9)


## 毒瘴：一片贴地的绿雾，几缕绿色鬼火往上冒
func _light_poison() -> void:
	Vfx.I.ground(global_position, "smoke_04", Color(0.25, 0.55, 0.12, 0.75), radius * 1.7, radius * 2.2, life + 0.4, false, 0.2)
	Vfx.I.ground(global_position, "magic_03", Color(0.5, 1.0, 0.25, 0.55), radius * 1.5, radius * 2.0, life, true, 0.15)
	var n := 3 if Vfx.I.lod > 0 else 1
	for i in range(n):
		var a := TAU * i / n + randf()
		var f := Vfx.I.sheet("spirit-flame", global_position + Vector3(cos(a), 0, sin(a)) * radius * 0.5, 0.9, Color(0.55, 1.0, 0.35), 1.8, false, life)
		if f != null:
			f.reparent(self)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 1.0, 0.3)
	l.light_energy = 1.0
	l.omni_range = radius * 2.6
	add_child(l)
	l.position.y = 0.5
	Game.sfx("flame", -10.0, 0.1, 0.6)


func _process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_t += dt
	if not _lit:
		if _t >= warn:
			_t = 0.0
			_light()
		return
	_tick -= dt
	if _tick <= 0.0 and hurts_foes:
		_tick = 0.5
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Actor
			if a == null or not a.alive:
				continue
			var d := a.global_position - global_position
			d.y = 0
			if d.length() < radius + a.radius * 0.5:
				var info := HitInfo.make(hero if is_instance_valid(hero) else null, a, damage, HitInfo.Weight.LIGHT)
				info.attacker = null
				info.knock = 0.0
				info.stun = 0.1
				info.dir = d.normalized() if d.length() > 0.05 else Vector3.FORWARD
				Feel.I.on_hit(info)
	elif _tick <= 0.0:
		_tick = 0.5
		for h: Node in get_tree().get_nodes_in_group("heroes"):
			var hh := h as Hero
			if hh == null or not hh.alive or hh.iframes > 0.0:
				continue
			var d := hh.global_position - global_position
			d.y = 0
			if d.length() < radius + hh.radius * 0.5 and not hh.invincible:
				# 烫一下：直接扣血（不打断动作，好让人走出去；烧不死人，最多剩 1 点）
				hh.hp = maxf(hh.hp - damage * hh.taken_mult, minf(hh.hp, 1.0))
				hh.dmg_total += damage * hh.taken_mult
				Feel.I.hurt_pulse(0.35)
				if elem == "poison":
					Feel.I.callout(hh.head_top(), "毒", Color(0.6, 1.0, 0.35), 0.5)
					Vfx.I.elem_burst(hh.chest(), "poison", false)
				else:
					Feel.I.callout(hh.head_top(), "烫", Color(1.0, 0.55, 0.2), 0.5)
	if _t >= life:
		queue_free()
