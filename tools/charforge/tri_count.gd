extends SceneTree
## 数三角形：godot4 --headless -s tools/charforge/tri_count.gd -- 模型名 ...（中画质 / 低画质各一遍）


func _init() -> void:
	var ids := OS.get_cmdline_user_args()
	VoxelGrid.greedy = true
	VoxelGrid.fast = true
	for coarse: bool in [false, true]:
		VoxelModel.coarse = coarse
		VoxelGrid.quant = 24.0 if coarse else 64.0
		for id: String in ids:
			var m := VoxelModel.load_model(id)
			if m == null:
				print(id, " 没有")
				continue
			var tris := 0
			for pn: String in m.parts:
				var mesh: ArrayMesh = m.parts[pn]["mesh"]
				for si in range(mesh.get_surface_count()):
					var arr := mesh.surface_get_arrays(si)
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
					tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			print("%s %s 三角形 %d" % ["低" if coarse else "中", id, tris])
	quit()
