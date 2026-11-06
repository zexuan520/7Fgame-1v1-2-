extends Node
## 体素拼网格的自动测试（无界面运行）：
##   godot --headless --path . res://tests/test_voxel_mesh.tscn
## 验证：快速版 _build_fast 和老版 _build_greedy 拼出来的网格逐位相同（顶点、法线、颜色、索引）；
## 发光件合并面以后画面不变（每种颜色盖住的面积一样）；分帧版和一口气拼的结果一样；顺带打印快了几倍。

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		failures += 1


func _grid_of(id: String) -> VoxelGrid:
	var d := VoxelModel.read_data("res://assets/voxel/kit/%s.json" % id)
	var g := VoxelGrid.new(1)
	var v: Array = d["vox"]
	for i in range(0, v.size(), 6):
		g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
	return g


func _random_grid(seed_value: int, n: int) -> VoxelGrid:
	var g := VoxelGrid.new(seed_value)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var cols := [Color(0.5, 0.4, 0.3), Color(0.2, 0.6, 0.3), Color(0.9, 0.9, 0.85)]
	for k in range(n):
		g.cells[Vector3i(r.randi_range(-6, 6), r.randi_range(-3, 5), r.randi_range(-6, 6))] = cols[r.randi() % 3]
	return g


func _same(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	if a.get_surface_count() == 0:
		return true
	return var_to_bytes(a.surface_get_arrays(0)) == var_to_bytes(b.surface_get_arrays(0))


## 每种颜色盖住的总面积（发光件合并前后应该一样）
func _coverage(m: ArrayMesh) -> Dictionary:
	var out := {}
	if m.get_surface_count() == 0:
		return out
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for t in range(0, ix.size(), 3):
		var ar := (v[ix[t + 1]] - v[ix[t]]).cross(v[ix[t + 2]] - v[ix[t]]).length() * 0.5
		var k := (c[ix[t]] as Color).to_html()
		out[k] = snappedf(float(out.get(k, 0.0)) + ar, 0.001)
	return out


func _run() -> void:
	VoxelGrid.quant = 64.0
	print("== 快速版和老版逐位相同 ==")
	VoxelGrid.glow_merge = false
	var t_old := 0
	var t_new := 0
	var grids := {}
	for id: String in ["barrel", "wall", "torch", "candles", "rubble", "tavern"]:
		grids[id] = _grid_of(id)
	for s in range(6):
		grids["随机%d" % s] = _random_grid(s, 200 + s * 150)
	for name: String in grids:
		var g: VoxelGrid = grids[name]
		for glow in [false, true]:
			for vs_or in [[1.4, Vector3.ZERO], [0.12, Vector3(3, 0.5, 2)]]:
				var t0 := Time.get_ticks_usec()
				var m1 := g._build_greedy(vs_or[0], vs_or[1], glow)
				var t1 := Time.get_ticks_usec()
				var m2: ArrayMesh = g._build_fast.call(vs_or[0], vs_or[1], glow, false)
				var t2 := Time.get_ticks_usec()
				t_old += t1 - t0
				t_new += t2 - t1
				_check(_same(m1, m2), "%s 发光=%s vs=%.2f" % [name, glow, vs_or[0]])
	print("  老版 %.0f ms，快速版 %.0f ms（快 %.1f 倍）" % [t_old / 1000.0, t_new / 1000.0, float(t_old) / maxf(t_new, 1)])
	print("== 发光件合并面：每种颜色的面积不变、三角形更少 ==")
	VoxelGrid.glow_merge = true
	for name: String in ["tavern", "随机3", "随机5"]:
		var g: VoxelGrid = grids[name]
		var m1 := g._build_greedy(1.0, Vector3.ZERO, true)
		var m2: ArrayMesh = g._build_fast.call(1.0, Vector3.ZERO, true, false)
		_check(_coverage(m1) == _coverage(m2), "%s 颜色面积一样" % name)
		_check(m2.surface_get_array_len(0) <= m1.surface_get_array_len(0), "%s 顶点 %d → %d" % [name, m1.surface_get_array_len(0), m2.surface_get_array_len(0)])
	print("== 分帧版和一口气拼的一样 ==")
	VoxelWarm.budget_us = 300
	for name: String in ["wall", "随机4"]:
		var g: VoxelGrid = grids[name]
		var m1 := g.build(0.5)
		var m2 := await g.build_sliced(0.5)
		_check(_same(m1, m2), "%s 分帧拼" % name)
		var d1 := g.downsample(2)
		var d2 := await g.downsample_sliced(2)
		_check(d1.cells == d2.cells, "%s 分帧缩小" % name)
	VoxelWarm.budget_us = 0
	print("== 结果：%s ==" % ("全部通过" if failures == 0 else "%d 项失败" % failures))
	get_tree().quit(1 if failures > 0 else 0)
