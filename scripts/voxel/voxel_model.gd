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
	# res：精细体素（2 表示一格切成 2×2×2 的小格）。关节、长度都换回原来的格子单位，网格按小格画，
	# 所以姿势、武器、碰撞这些按“格”算的东西都不用改。
	var res := float(d.get("res", 1))
	for k: String in d["joints"]:
		var a: Array = d["joints"][k]
		m.joints[k] = Vector3(a[0], a[1], a[2]) / res
	for pname: String in d["parts"]:
		var pd: Dictionary = d["parts"][pname]
		var g := VoxelGrid.new(1)
		var v: Array = pd["vox"]
		for i in range(0, v.size(), 6):
			g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
		var an: Array = pd["anchor"]
		m.parts[pname] = {"anchor": Vector3(an[0], an[1], an[2]) / res, "len": float(pd["len"]) / res, "mesh": g.build(1.0 / res)}
	_cache[id] = m
	return m


func j(name: String) -> Vector3:
	return joints.get(name, Vector3.ZERO)


func length(pname: String) -> float:
	return float(parts[pname]["len"]) if parts.has(pname) else 0.0


static var _weapons := {}


## 开源武器（assets/voxel/weapon/*.json，原点在握把、刃朝 -y），按给定的总长缩放成网格；没有返回 null
static func weapon_mesh(id: String, length: float) -> ArrayMesh:
	var key := "%s|%.1f" % [id, length]
	if _weapons.has(key):
		return _weapons[key]
	var path := "res://assets/voxel/weapon/%s.json" % id
	if id == "" or not FileAccess.file_exists(path):
		_weapons[key] = null
		return null
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var g := VoxelGrid.new(1)
	var v: Array = d["vox"]
	for i in range(0, v.size(), 6):
		g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
	# len 是像素长，vs 是一格几像素（精细版 0.5），格数 = len / vs
	var m := g.build(length * float(d.get("vs", 1.0)) / maxf(float(d.get("len", 40.0)), 1.0))
	_weapons[key] = m
	return m
