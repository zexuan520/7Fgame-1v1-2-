class_name PerfProbe
extends Node
## 测性能用（--perf）：每 2 秒打一行帧数、脚本耗时、节点数、绘制调用、可见灯、粒子、敌人数；退出时打汇总。
## 云端是软件渲染，帧数本身不准，主要看绘制调用、节点和脚本耗时这些和机器无关的量。

var _t := 0.0
static var on := false
static var acc := {}
var _frames := 0


static func add(tag: String, t0: int) -> void:
	acc[tag] = int(acc.get(tag, 0)) + Time.get_ticks_usec() - t0
var _n := 0
var _sum := {}
var _max := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	on = true


var _dumped := false


static func _tris(m: Mesh) -> int:
	if m == null:
		return 0
	var n := 0
	for i in range(m.get_surface_count()):
		var arr := m.surface_get_arrays(i)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## 一次性：按“挂在谁下面”汇总可见几何体的三角形数，找大头
func _dump() -> void:
	var by := {}
	var cnt := {}
	var cache := {}
	for n: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var t := 0
		var m: Mesh = null
		var mult := 1
		if g is MeshInstance3D:
			m = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			m = (g as MultiMeshInstance3D).multimesh.mesh
			mult = (g as MultiMeshInstance3D).multimesh.visible_instance_count
			if mult < 0:
				mult = (g as MultiMeshInstance3D).multimesh.instance_count
		elif g is CPUParticles3D:
			m = (g as CPUParticles3D).mesh
			mult = (g as CPUParticles3D).amount
		if m != null:
			if not cache.has(m):
				cache[m] = _tris(m)
			t = int(cache[m]) * mult
		# 分组键：往上找第一个带脚本的祖先的类名 + 自己的类型
		var key := g.get_class()
		var a: Node = g.get_parent()
		while a != null:
			var sc: Script = a.get_script()
			if sc != null:
				key = "%s<%s>/%s" % [sc.get_global_name(), a.name.left(14), g.get_class()]
				break
			a = a.get_parent()
		by[key] = int(by.get(key, 0)) + t
		cnt[key] = int(cnt.get(key, 0)) + 1
	var singles := []
	for m: Mesh in cache:
		singles.append([int(cache[m]), m])
	singles.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var tot := 0
	for e: Array in singles:
		tot += int(e[0])
	print("UNIQUE meshes %d tris %d" % [singles.size(), tot])
	for e: Array in singles.slice(0, 20):
		var users := 0
		for n: Node in get_tree().root.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).mesh == e[1] and (n as Node3D).is_visible_in_tree():
				users += 1
		print("MESH %7d x%d aabb=%s %s" % [e[0], users, str((e[1] as Mesh).get_aabb().size.snapped(Vector3.ONE * 0.01)), _who(e[1])])
	# 每类可见几何体有多少个（大致就是绘制调用的来源）
	var kinds := {}
	for n: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var k := g.get_class()
		if g.has_meta("batched"):
			k += "(batched)"
		var a: Node = g.get_parent()
		while a != null:
			if a.get_script() != null:
				k = "%s/%s" % [(a.get_script() as Script).get_global_name(), k]
				break
			a = a.get_parent()
		kinds[k] = int(kinds.get(k, 0)) + 1
	print("KINDS ", kinds)
	var keys := by.keys()
	keys.sort_custom(func(x: String, y: String) -> bool: return int(by[x]) > int(by[y]))
	for k: String in keys.slice(0, 25):
		print("TRIS %8d  x%-4d %s" % [by[k], cnt[k], k])


func _process(dt: float) -> void:
	_t += dt
	_frames += 1
	if not _dumped and Time.get_ticks_msec() > 9000:
		_dumped = true
		_dump()
	if _t < 2.0:
		return
	_t = 0.0
	var lights := 0
	var parts := 0
	var meshes := 0
	for n: Node in get_tree().root.find_children("*", "OmniLight3D", true, false):
		if (n as Node3D).is_visible_in_tree():
			lights += 1
	for n: Node in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		if (n as CPUParticles3D).emitting and (n as Node3D).is_visible_in_tree():
			parts += (n as CPUParticles3D).amount
	for n: Node in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		if (n as Node3D).is_visible_in_tree():
			meshes += 1
	var row := {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"proc_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"phys_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objs": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"prims_k": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		"lights": lights,
		"parts": parts,
		"meshes": meshes,
		"foes": get_tree().get_nodes_in_group("foes").size(),
	}
	var s := ""
	for k: String in row:
		s += "%s=%d " % [k, int(row[k])]
		_sum[k] = float(_sum.get(k, 0.0)) + float(row[k])
		_max[k] = maxf(float(_max.get(k, 0.0)), float(row[k]))
	_n += 1
	var cpu := ""
	for k: String in acc:
		cpu += "%s=%.2f " % [k, float(acc[k]) / 1000.0 / maxi(_frames, 1)]
	acc.clear()
	_frames = 0
	print("PERF ", s, "| ms/frame: ", cpu)


func _exit_tree() -> void:
	if _n == 0:
		return
	var s := ""
	for k: String in _sum:
		s += "%s=%d/%d " % [k, int(float(_sum[k]) / _n), int(_max[k])]
	print("PERFSUM(avg/max) ", s)


func _who(m: Mesh) -> String:
	for n: Node in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh == m:
			return str(n.get_path()).right(60)
	return ""
