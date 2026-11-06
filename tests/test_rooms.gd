extends Node
## 房间连通自检（无界面运行）：
##   godot --headless --path . res://tests/test_rooms.tscn
## 九个区域 × 战斗房 / 小房间 / 头目房 × 几个随机种子，各建一次房间，按碰撞盒（加上主角半径）在 0.25 米的格子上
## 从入口往外漫：出口光门要走得到，刷怪点要大多走得到（敌人没有寻路，刷在围死的角落里就会一直卡着）。

var failures := 0
const SEEDS := [11, 23, 37, 41, 59]
const CELL := 0.25
const HERO_R := 0.45


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		failures += 1


func _boxes(n: Node, out: Array) -> void:
	for c: Node in n.get_children():
		if c is StaticBody3D:
			for cs: Node in c.get_children():
				if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
					var sz: Vector3 = ((cs as CollisionShape3D).shape as BoxShape3D).size
					var p: Vector3 = (cs as CollisionShape3D).global_position
					out.append(Rect2(p.x - sz.x * 0.5 - HERO_R, p.z - sz.z * 0.5 - HERO_R, sz.x + HERO_R * 2.0, sz.z + HERO_R * 2.0))
		_boxes(c, out)


func _reach(a: Arena) -> Dictionary:
	var boxes := []
	_boxes(a, boxes)
	var hx := a.size.x * 0.5
	var hz := a.size.y * 0.5
	var nx := int(a.size.x / CELL)
	var nz := int(a.size.y / CELL)
	var blocked := PackedByteArray()
	blocked.resize(nx * nz)
	for i in range(nx):
		for j in range(nz):
			var p := Vector2(-hx + (i + 0.5) * CELL, -hz + (j + 0.5) * CELL)
			for r: Rect2 in boxes:
				if r.has_point(p):
					blocked[i + j * nx] = 1
					break
	var seen := PackedByteArray()
	seen.resize(nx * nz)
	var si := clampi(int((a.entry_pos.x + hx) / CELL), 0, nx - 1)
	var sj := clampi(int((a.entry_pos.z + hz) / CELL), 0, nz - 1)
	var q: Array[int] = [si + sj * nx]
	seen[q[0]] = 1
	while not q.is_empty():
		var c: int = q.pop_back()
		var ci := c % nx
		var cj := c / nx
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ii := ci + d.x
			var jj := cj + d.y
			if ii < 0 or jj < 0 or ii >= nx or jj >= nz:
				continue
			var k := ii + jj * nx
			if seen[k] == 0 and blocked[k] == 0:
				seen[k] = 1
				q.append(k)
	var near := func(p: Vector3, rad: float) -> bool:
		var r := int(ceil(rad / CELL))
		var ci := int((p.x + hx) / CELL)
		var cj := int((p.z + hz) / CELL)
		for ii in range(ci - r, ci + r + 1):
			for jj in range(cj - r, cj + r + 1):
				if ii < 0 or jj < 0 or ii >= nx or jj >= nz:
					continue
				var cp := Vector2(-hx + (ii + 0.5) * CELL, -hz + (jj + 0.5) * CELL)
				if seen[ii + jj * nx] == 1 and cp.distance_to(Vector2(p.x, p.z)) <= rad:
					return true
		return false
	var spawn_ok := 0
	for sp: Vector3 in a.spawn_points:
		if near.call(sp, 0.6):
			spawn_ok += 1
	return {"exit": near.call(a.open_exit(), 1.2), "spawn_ok": spawn_ok, "spawn_n": a.spawn_points.size(), "entry_blocked": blocked[si + sj * nx] == 1}


func _run() -> void:
	var kinds := {
		1: [["战斗", ArpgMain.ROOM_SIZE], ["小房间", ArpgMain.SMALL_ROOM], ["头目", ArpgMain.BOSS_ROOM]],
		2: [["战斗", ArpgMain.ACT2_ROOM], ["小房间", ArpgMain.ACT2_SMALL], ["头目", ArpgMain.ACT2_BOSS]],
		3: [["战斗", ArpgMain.ACT3_ROOM], ["小房间", ArpgMain.ACT3_SMALL], ["头目", ArpgMain.ACT3_BOSS]],
	}
	var zones := {"forest": 1, "grave": 1, "temple": 1, "sakura": 1, "well": 2, "vault": 2, "camp": 2, "liuxi": 3, "post": 3, "palace": 3}
	for z: String in zones:
		for k: Array in kinds[zones[z]]:
			var bad_exit := []
			var worst := 1.0
			var worst_seed := 0
			for sd: int in SEEDS:
				var a: Arena = Arena3.new() if Arena3.ZONES3.has(z) else Arena.new()
				add_child(a)
				a.build(z, sd, k[1])
				var r := _reach(a)
				if not bool(r["exit"]) or bool(r["entry_blocked"]):
					bad_exit.append(sd)
				var frac := float(r["spawn_ok"]) / maxf(float(r["spawn_n"]), 1.0)
				if frac < worst:
					worst = frac
					worst_seed = sd
				a.free()
			_check(bad_exit.is_empty() and worst >= 0.9, "%s · %s：出口%s，刷怪点最少 %d%% 走得到%s" % [z, k[0],
				"都走得到" if bad_exit.is_empty() else "走不到（种子 %s）" % str(bad_exit), int(worst * 100.0), "（种子 %d）" % worst_seed if worst < 1.0 else ""])
	print("\n" + ("全部测试通过" if failures == 0 else "有 %d 项没通过" % failures))
	get_tree().quit(1 if failures > 0 else 0)
