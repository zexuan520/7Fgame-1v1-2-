class_name VoxelModel
extends RefCounted
## 从开源 3D 模型体素化出来的角色（tools/voxelize/voxelize_char.py 生成的 assets/voxel/*.json）。
## 每块部件的原点在它的起点关节，-y 指向终点关节；joints 是静止姿势下各关节的位置（脚底 y=0，面朝 +x，+z 朝镜头）。
## 读进来以后缓存，每块部件合成一个网格（1 像素 1 格）。

var joints := {}            # 关节名 → Vector3
var parts := {}             # 部件名 → {"anchor": Vector3, "len": float, "mesh": ArrayMesh}
var source := ""

static var _cache := {}
static var off := false      # true 时一律不用开源模型（演示工具拍前后对比用）


static func load_model(id: String) -> VoxelModel:
	if off:
		return null
	if _cache.has(id):
		return _cache[id]
	var path := "res://assets/voxel/%s.json" % id
	if not FileAccess.file_exists(path):
		push_warning("没有体素模型 " + path)
		_cache[id] = null
		return null
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var m := VoxelModel.new()
	m.source = String(d.get("source", ""))
	for k: String in d["joints"]:
		var a: Array = d["joints"][k]
		m.joints[k] = Vector3(a[0], a[1], a[2])
	for pname: String in d["parts"]:
		var pd: Dictionary = d["parts"][pname]
		var g := VoxelGrid.new(1)
		var v: Array = pd["vox"]
		for i in range(0, v.size(), 6):
			g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
		var an: Array = pd["anchor"]
		m.parts[pname] = {"anchor": Vector3(an[0], an[1], an[2]), "len": float(pd["len"]), "mesh": g.build(1.0)}
	_cache[id] = m
	return m


func j(name: String) -> Vector3:
	return joints.get(name, Vector3.ZERO)


func length(pname: String) -> float:
	return float(parts[pname]["len"]) if parts.has(pname) else 0.0
