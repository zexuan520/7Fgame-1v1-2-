class_name Arena
extends Node3D
## 一个房间的场景：体素地面（分块，好让每块只吃附近的灯）、四周的墙和障碍（带碰撞）、摆设、灯光、雾片、漂浮孢子、光柱。
## 三种区域：
##   forest 幽暗森林遗迹：苔藓石地、枯树、断墙、锈蚀巨管、木脚手架、垂藤，青绿雾最浓
##   temple 寺庙内殿：木地板、朱红柱、纸窗透冷月光、供台蜡烛、挂轴、香烟
##   sakura 夜樱广场（头目）：石板地、中央发光大樱树、鸟居、石灯笼、落花
##   well 青井地宫（第二幕）：古寺井下的水淹殿堂，湿石板、冰蓝积水和焦散、经文石壁、垂下来的灯链、井口漏下来的冷光
## 开源件（KayKit，CC0）体素化后放在 assets/voxel/kit/；樱树、鸟居、石灯笼、纸窗、巨管是这里按格子画的。
## 坐标：1 单位 = 1 米，房间中心在原点，-z 是画面上方（远处），+z 是靠镜头的一边。

const PX := 0.036
const FV := 0.1                    # 地面一格 0.1 米（和精细体素角色同一档）

var zone := "forest"
var abyss := false                 # 终章无光殿：按灯冢摆，用 abyss 的光
var size := Vector2(30, 22)        # 房间 x 宽、z 深（米）
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var occluders: Array = []          # 前景遮挡物：[节点(Node3D), 材质数组, AABB]
var env_mat: ShaderMaterial
var glow_mat: ShaderMaterial
var spawn_points: Array[Vector3] = []
var exit_pos := Vector3.ZERO
var entry_pos := Vector3.ZERO
var _solid := []                   # 不能走的格子（地面坐标矩形），刷怪时避开
var _placed: Array[Vector3] = []   # _free_spot 找过的位置（互相隔开）
## 侧墙上开的门（通侧室）：[{side: -1 左 / 1 右, z: 门中心, w: 门宽}]，build 之前填好
var doors: Array = []
## 画质档（ArpgMain.apply_quality 设）：0 低档时漂浮光尘、雾片、落花减半
static var lod := 2

const ZONES := {
	"forest": {"bg": Color(0.03, 0.07, 0.08), "fog": Color(0.07, 0.2, 0.21), "fog_d": 0.75, "amb": Color(0.3, 0.55, 0.58), "amb_e": 1.15,
		"sun": Color(0.55, 0.85, 0.95), "sun_e": 1.25, "spore": Color(0.55, 1.0, 0.85)},
	"temple": {"bg": Color(0.03, 0.04, 0.06), "fog": Color(0.06, 0.14, 0.18), "fog_d": 0.7, "amb": Color(0.4, 0.42, 0.55), "amb_e": 1.35,
		"sun": Color(0.6, 0.72, 1.0), "sun_e": 1.1, "spore": Color(0.7, 0.9, 1.0)},
	"grave": {"bg": Color(0.03, 0.05, 0.05), "fog": Color(0.1, 0.16, 0.14), "fog_d": 0.85, "amb": Color(0.38, 0.5, 0.45), "amb_e": 1.2,
		"sun": Color(0.62, 0.8, 0.75), "sun_e": 1.15, "spore": Color(0.6, 1.0, 0.6)},
	"well": {"bg": Color(0.02, 0.04, 0.07), "fog": Color(0.05, 0.14, 0.2), "fog_d": 0.6, "amb": Color(0.48, 0.52, 0.58), "amb_e": 1.45,
		"sun": Color(0.7, 0.85, 1.0), "sun_e": 1.2, "spore": Color(0.5, 0.9, 1.0)},
	"vault": {"bg": Color(0.06, 0.03, 0.02), "fog": Color(0.18, 0.09, 0.04), "fog_d": 0.55, "amb": Color(0.6, 0.47, 0.36), "amb_e": 1.35,
		"sun": Color(1.0, 0.78, 0.55), "sun_e": 1.1, "spore": Color(1.0, 0.6, 0.25)},
	"camp": {"bg": Color(0.05, 0.05, 0.07), "fog": Color(0.16, 0.14, 0.16), "fog_d": 0.6, "amb": Color(0.56, 0.52, 0.56), "amb_e": 1.3,
		"sun": Color(1.0, 0.72, 0.5), "sun_e": 1.15, "spore": Color(1.0, 0.55, 0.3)},
	# 终章 · 无光殿（灯冢最深处，烛王坐的地方）：摆设和灯冢一样，光压得很暗、发红
	"abyss": {"bg": Color(0.015, 0.008, 0.006), "fog": Color(0.12, 0.03, 0.02), "fog_d": 0.85, "amb": Color(0.42, 0.3, 0.26), "amb_e": 1.05,
		"sun": Color(0.95, 0.5, 0.3), "sun_e": 0.7, "spore": Color(1.0, 0.45, 0.2)},
	"sakura": {"bg": Color(0.05, 0.04, 0.09), "fog": Color(0.12, 0.1, 0.2), "fog_d": 0.65, "amb": Color(0.45, 0.38, 0.6), "amb_e": 1.25,
		"sun": Color(0.72, 0.76, 1.0), "sun_e": 1.2, "spore": Color(1.0, 0.6, 0.8)},
}


func build(zone_id: String, seed_value: int, room_size: Vector2 = Vector2(30, 22)) -> void:
	abyss = zone_id == "abyss"
	zone = "vault" if abyss else zone_id
	size = room_size
	rng.seed = seed_value
	noise.seed = seed_value
	noise.frequency = 0.08
	env_mat = VoxActor.toon_material()
	env_mat.set_shader_parameter("rim_strength", 0.12)
	env_mat.set_shader_parameter("shadow_floor", 0.38)
	glow_mat = ShaderMaterial.new()
	glow_mat.shader = load("res://shaders/arpg/vcol_emit.gdshader")
	entry_pos = Vector3(0, 0, size.y * 0.5 - 3.0)
	exit_pos = Vector3(0, 0, -size.y * 0.5 + 1.5)
	var _lp := LoadProf.t()
	_build_floor()
	LoadProf.add("arena.floor", _lp)
	_build_bounds()
	# 门口留出空地：摆设、刷怪点都别放这里
	for dr: Dictionary in doors:
		_solid.append(_door_clear_rect(dr))
	_lp = LoadProf.t()
	match zone:
		"forest":
			_dress_forest()
		"temple":
			_dress_temple()
		"grave":
			_dress_grave()
		"sakura":
			_dress_sakura()
		"well":
			_dress_well()
		"vault":
			_dress_vault()
		"camp":
			_dress_camp()
		_:
			_dress_more()
	LoadProf.add("arena.dress", _lp)
	_lp = LoadProf.t()
	TerrainDress.apply(self)   # 地形层：墙外边坡、地面碎件、场中石丛、每层专属摆设
	LoadProf.add("arena.terrain", _lp)
	_lp = LoadProf.t()
	_atmosphere()
	LoadProf.add("arena.atmosphere", _lp)
	_clear_doorways()
	_make_spawns()
	if lod <= 1:
		_lp = LoadProf.t()
		_batch_static()
		LoadProf.add("arena.batch", _lp)


## 静态合批：摆设大多共用一份场景材质，按 10 米一格把它们并成一块大网格，绘制调用少很多
## （手机网页上每次绘制调用都很贵）。只并共用 env_mat、自己没有子节点、往上到房间都没挂脚本的件；
## 前景遮挡件（材质是复制出来的）、发光件、灯、粒子、侧室和之后才摆的东西（裂墙）都不动。
const BATCH_CELL := 10.0
## 顶点比这多的大件（房子、大树、墙）不并：本来就是一次绘制，复制几十万个顶点在网页上要好几秒，
## 省下的只是这几十次绘制调用。合批主要省在满地的小件（石头、蜡烛、草丛）上
static var batch_max := 30000


func _batch_static() -> void:
	var buckets := {}
	for n: Node in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.material_override != env_mat or not mi.visible or mi.mesh == null or mi.has_meta("floor") \
				or mi.get_child_count() > 0 or mi.mesh.get_surface_count() != 1 \
				or mi.mesh.surface_get_array_len(0) > batch_max:
			continue
		var ok := true
		var a := mi.get_parent()
		while a != self:
			if a == null or a.get_script() != null or not (a is Node3D) or not (a as Node3D).visible:
				ok = false
				break
			a = a.get_parent()
		if not ok:
			continue
		var p := mi.position if mi.get_parent() == self else to_local(mi.global_position)
		var key := Vector2i(floori(p.x / BATCH_CELL), floori(p.z / BATCH_CELL))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(mi)
	var inv := global_transform.affine_inverse()
	for key: Vector2i in buckets:
		var list: Array = buckets[key]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi: MeshInstance3D in list:
			st.append_from(mi.mesh, 0, inv * mi.global_transform)
		var out := MeshInstance3D.new()
		out.mesh = st.commit()
		out.material_override = env_mat
		out.set_meta("batched", true)
		add_child(out)
		for mi: MeshInstance3D in list:
			mi.get_parent().remove_child(mi)
			mi.queue_free()


func zone_info() -> Dictionary:
	return ZONES["abyss" if abyss else zone]


## 别的区域（子类 Arena3：第三幕）在这里摆
func _dress_more() -> void:
	pass


## 房间相对 30×22 老尺寸的倍数（摆设按这个放大位置、加数量，密度保持差不多）
func _kx() -> float:
	return size.x / 30.0


func _kz() -> float:
	return size.y / 22.0


func _ka() -> float:
	return size.x * size.y / 660.0


## 找一块空地：离墙 margin 米，避开中间那条入口→出口的路（半宽 lane）、入口出口附近、
## 已经有碰撞的东西和之前找过的位置（相距 gap 米）。找不到返回 Vector3.INF
func _free_spot(gap: float = 3.5, margin: float = 3.0, lane: float = 2.5) -> Vector3:
	for t in range(60):
		var p := Vector3(rng.randf_range(-size.x * 0.5 + margin, size.x * 0.5 - margin), 0, rng.randf_range(-size.y * 0.5 + margin, size.y * 0.5 - margin))
		if absf(p.x) < lane or p.distance_to(entry_pos) < 5.0 or p.distance_to(exit_pos) < 4.0:
			continue
		var ok := true
		for r: Rect2 in _solid:
			if r.grow(0.8).has_point(Vector2(p.x, p.z)):
				ok = false
				break
		if ok:
			for q: Vector3 in _placed:
				if q.distance_to(p) < gap:
					ok = false
					break
		if ok:
			_placed.append(p)
			return p
	return Vector3.INF


# ---------- 地面 ----------

func _floor_color(x: float, z: float) -> Color:
	var n := noise.get_noise_2d(x * 3.0, z * 3.0)
	var n2 := noise.get_noise_2d(x * 13.0 + 100.0, z * 13.0)
	match zone:
		"forest":
			# 石板路 + 苔藓 + 泥土
			var tile := (int(floor(x / 1.2)) + int(floor(z / 1.2))) % 2 == 0
			var path := absf(x * 0.25 + sin(z * 0.3) * 1.5) < 2.6
			var base := Color(0.16, 0.2, 0.17).lerp(Color(0.22, 0.3, 0.2), n * 0.5 + 0.5)
			if path:
				base = Color(0.3, 0.32, 0.3) if tile else Color(0.26, 0.28, 0.27)
				var gx := fposmod(x + floor(z / 1.2) * 0.5, 1.2) < FV * 0.6 or fposmod(z, 1.2) < FV * 0.6
				if gx and n2 > -0.3:
					base = Color(0.17, 0.2, 0.17)
			if n2 > 0.35:
				base = base.lerp(Color(0.12, 0.26, 0.18), 0.6)
			return base * (0.9 + n2 * 0.15)
		"grave":
			# 墓园：黑土 + 枯草 + 一条碎石板路（从入口通到出口）
			var soil := Color(0.16, 0.15, 0.13).lerp(Color(0.2, 0.22, 0.16), n * 0.5 + 0.5)
			if n2 > 0.2:
				soil = soil.lerp(Color(0.2, 0.27, 0.17), 0.6)
			var path_w := 1.6 + sin(z * 0.4) * 0.3
			if absf(x - sin(z * 0.25) * 1.2) < path_w:
				var slab := (int(floor(z / 0.9)) + int(floor((x + 5.0) / 1.1))) % 3
				soil = [Color(0.3, 0.3, 0.29), Color(0.27, 0.27, 0.27), Color(0.33, 0.32, 0.3)][slab]
				if fposmod(z, 0.9) < FV * 0.8 or fposmod(x + 5.0, 1.1) < FV * 0.8:
					soil = Color(0.14, 0.15, 0.13)
			return soil * (0.9 + n2 * 0.12)
		"well":
			# 湿石板：大块方砖 + 深缝，低洼处积着冰蓝的水（水面另有一层焦散，见 _water_plane）
			var sx := int(floor(x / 1.5))
			var sz := int(floor(z / 1.5))
			var shade := 0.85 + 0.15 * sin(sx * 12.9898 + sz * 78.233)
			var c := Color(0.2, 0.23, 0.26).lerp(Color(0.26, 0.29, 0.31), n * 0.5 + 0.5) * shade
			if fposmod(x, 1.5) < FV * 0.8 or fposmod(z, 1.5) < FV * 0.8:
				c = Color(0.07, 0.09, 0.12)
			var wet := noise.get_noise_2d(x * 1.1 + 40.0, z * 1.1)
			if wet > 0.18:
				c = c.lerp(Color(0.08, 0.26, 0.34), clampf((wet - 0.18) * 4.0, 0.0, 0.85))
			elif wet > 0.08:
				c = c * 0.8
			# 中间一条青石道（入口到出口），两边一道浅色石沿
			if absf(x) < 1.8:
				c = c.lerp(Color(0.27, 0.31, 0.34), 0.6)
				if absf(absf(x) - 1.7) < FV:
					c = c * 1.2
			return c * (1.2 + n2 * 0.12)
		"vault":
			# 灯冢：深褐的大方砖，砖缝嵌铜线；两道熔铜沟沿着柱廊从里通到外，中间一圈铜纹地心
			var sx := int(floor(x / 1.8))
			var sz := int(floor(z / 1.8))
			var shade := 0.85 + 0.15 * sin(sx * 12.9898 + sz * 78.233)
			var c := Color(0.25, 0.2, 0.17).lerp(Color(0.31, 0.25, 0.2), n * 0.5 + 0.5) * shade
			if fposmod(x, 1.8) < FV * 0.8 or fposmod(z, 1.8) < FV * 0.8:
				c = Color(0.3, 0.21, 0.12) if n2 > 0.25 else Color(0.11, 0.08, 0.06)
			var ch := _vault_channel(x, z)
			if ch > 0.0:
				c = Color(0.12, 0.07, 0.05).lerp(Color(1.0, 0.55, 0.18), ch)
			var r := Vector2(x, z).length()
			if absf(r - 3.2) < 0.1 or absf(r - 4.4) < 0.06:
				c = Color(0.42, 0.3, 0.15)
			elif r < 3.2 and fposmod(atan2(z, x) * 7.0 / TAU, 1.0) < 0.05:
				c = Color(0.34, 0.25, 0.14)
			return c * (1.15 + n2 * 0.1)
		"camp":
			# 灰衣营：踩实的黄土 + 车辙泥坑 + 散落的稻草；中间一条木板道通到营门
			var c := Color(0.27, 0.25, 0.22).lerp(Color(0.33, 0.3, 0.26), n * 0.5 + 0.5)
			var mud := noise.get_noise_2d(x * 0.9 - 30.0, z * 0.9)
			if mud > 0.25:
				c = c.lerp(Color(0.14, 0.12, 0.11), clampf((mud - 0.25) * 4.0, 0.0, 0.8))
			if n2 > 0.5:
				c = c.lerp(Color(0.42, 0.37, 0.26), 0.35)
			for rx: float in [-1.0, 1.0]:
				if absf(x - rx * 3.4 - sin(z * 0.2) * 0.4) < 0.2:
					c = c * 0.84
			if absf(x) < 1.4:
				var pl := int(floor(z / 0.5))
				c = Color(0.36, 0.27, 0.19) * (0.88 + 0.12 * sin(pl * 12.9898))
				if fposmod(z, 0.5) < FV * 0.8 or absf(absf(x) - 1.35) < FV:
					c = Color(0.18, 0.13, 0.1)
			return c * (1.12 + n2 * 0.1)
		"temple":
			var plank := int(floor(x / 0.6))
			var seam := fposmod(x, 0.6) < FV * 0.6
			var shade := 0.85 + 0.15 * sin(plank * 12.9898)
			var c := Color(0.42, 0.29, 0.2) * shade
			if seam:
				c = Color(0.27, 0.18, 0.13)
			# 中间铺一条深色地毯
			if absf(x) < 2.2 and absf(z) < size.y * 0.5 - 2.0:
				c = Color(0.36, 0.1, 0.1) * (0.9 + n2 * 0.1)
				if absf(absf(x) - 2.0) < FV:
					c = Color(0.45, 0.34, 0.15)
			return c * (1.15 + n * 0.12)
		_:
			var tile := fposmod(x, 1.4) < FV * 0.7 or fposmod(z, 1.4) < FV * 0.7
			var c := Color(0.3, 0.28, 0.34).lerp(Color(0.37, 0.35, 0.41), n * 0.5 + 0.5)
			if tile and n2 > -0.4:
				c = Color(0.2, 0.18, 0.24)
			# 花瓣：靠近樱树多，远处少
			var near_tree := clampf(1.0 - Vector2(x, z + size.y * 0.5 - 4.5).length() / 9.0, 0.0, 1.0)
			if rng.randf() < 0.004 + 0.08 * near_tree * near_tree:
				c = Color(0.5, 0.32, 0.4)
			return c


func _build_floor() -> void:
	# 地面 0.1 米一格（大房间十几万格）。每格的颜色写进一张贴图（一像素一格，最近邻采样），
	# 地面本身只是几块平面（分块好让每块只吃附近的灯：兼容渲染器每个物体最多 8 盏）；
	# 只有边上的草丛 / 碎石凸起走 VoxelGrid
	var nx := int(size.x / FV) + 20
	var nz := int(size.y / FV) + 20
	_floor_patch(-nx * 0.5 * FV, -nz * 0.5 * FV, nx, nz, true, Color.WHITE)


## 侧室的地面：rect 是 xz 矩形（米），颜色乘 tint、再加一层方砖缝，看得出是另一间屋
func floor_patch(rect: Rect2, tint: Color) -> void:
	_floor_patch(rect.position.x, rect.position.y, int(round(rect.size.x / FV)), int(round(rect.size.y / FV)), false, tint)


func _floor_patch(x0: float, z0: float, nx: int, nz: int, main_room: bool, tint: Color) -> void:
	var _lpf := LoadProf.t()
	var px := PackedByteArray()
	px.resize(nx * nz * 3)
	var bumps := VoxelGrid.new(rng.randi())
	for iz in range(nz):
		var z := z0 + iz * FV
		var row := iz * nx * 3
		for ix in range(nx):
			var x := x0 + ix * FV
			var c := _floor_color(x, z)
			if not main_room:
				c = c * tint
				if fposmod(x, 1.0) < FV * 0.6 or fposmod(z, 1.0) < FV * 0.6:
					c = c * 0.72
			# 草丛 / 碎石凸起（只在边上，不挡路）
			elif zone == "forest":
				var edge := maxf(absf(x) - size.x * 0.5 + 3.0, absf(z) - size.y * 0.5 + 3.0)
				if edge > 0.0 and noise.get_noise_2d(x * 9.0, z * 9.0) > 0.4:
					var h := 2 + int(rng.randf() * 3.0)
					if lod == 0:
						h = 2   # 低画质：一样高，顶面能合并成大块（逐格高低不齐时一格四个侧面）
					c = Color(0.1, 0.22, 0.16).lerp(Color(0.16, 0.3, 0.2), rng.randf())
					for y in range(1, h + 1):
						bumps.cells[Vector3i(ix, y, iz)] = c * (1.0 + 0.1 * y)
					c = c * 0.7
			var o := row + ix * 3
			px[o] = clampi(int(c.r * 255.0), 0, 255)
			px[o + 1] = clampi(int(c.g * 255.0), 0, 255)
			px[o + 2] = clampi(int(c.b * 255.0), 0, 255)
	LoadProf.add("floor.pixels", _lpf)
	var img := Image.create_from_data(nx, nz, false, Image.FORMAT_RGB8, px)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/arpg/floor.gdshader")
	mat.set_shader_parameter("floor_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("floor_rect", Vector4(x0, z0, nx * FV, nz * FV))
	# 分块：每块约 10 米见方
	var cx := maxi(1, int(ceil(nx * FV / 10.0)))
	var cz := maxi(1, int(ceil(nz * FV / 10.0)))
	var cw := nx * FV / cx
	var cd := nz * FV / cz
	var pm := PlaneMesh.new()
	pm.size = Vector2(cw, cd)
	for i in range(cx):
		for j in range(cz):
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta("floor", true)
			add_child(mi)
			mi.position = Vector3(x0 + (i + 0.5) * cw, 0.0, z0 + (j + 0.5) * cd)
	if bumps.size() > 0:
		var bi := MeshInstance3D.new()
		bi.mesh = bumps.build(FV, Vector3(nx * 0.5, 1.0, nz * 0.5))
		bi.material_override = env_mat
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bi.set_meta("floor", true)
		add_child(bi)


# ---------- 边界和碰撞 ----------

func _box_collider(center: Vector3, ext: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ext
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_position = center
	_solid.append(Rect2(center.x - ext.x * 0.5 - 0.6, center.z - ext.z * 0.5 - 0.6, ext.x + 1.2, ext.z + 1.2))


func _build_bounds() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	_box_collider(Vector3(0, 1, -hz - 0.5), Vector3(size.x + 2, 2, 1))
	_box_collider(Vector3(0, 1, hz + 0.5), Vector3(size.x + 2, 2, 1))
	for side: float in [-1.0, 1.0]:
		# 侧墙按门切成几段，门口空出来
		var gaps := []
		for dr: Dictionary in doors:
			if float(dr["side"]) == side:
				gaps.append(Vector2(float(dr["z"]) - float(dr["w"]) * 0.5, float(dr["z"]) + float(dr["w"]) * 0.5))
		gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var z := -hz - 1.0
		for g: Vector2 in gaps:
			if g.x > z:
				_box_collider(Vector3(side * (hx + 0.5), 1, (z + g.x) * 0.5), Vector3(1, 2, g.x - z))
			z = g.y
		_box_collider(Vector3(side * (hx + 0.5), 1, (z + hz + 1.0) * 0.5), Vector3(1, 2, hz + 1.0 - z))


## 门口要清空的一块（房间里靠墙那一截 + 墙本身）
## 出口光门的位置：exit_pos 被摆设压住（比如第三幕驿站头目房的十里亭正好盖在出口上，光门开在亭子里面，走不进去）
## 就往房间里挪，挪到第一个空地
func open_exit() -> Vector3:
	var p := exit_pos
	for i in range(40):
		var q := p + Vector3(0, 0, 0.5 * i)
		var free := true
		for r: Rect2 in _solid:
			if r.has_point(Vector2(q.x, q.z)):
				free = false
				break
		if free:
			if i > 0 and OS.get_cmdline_user_args().has("--tel"):
				print("EXIT moved %s -> %s" % [str(p), str(q)])
			return q
	return p


func _door_clear_rect(dr: Dictionary) -> Rect2:
	var hx := size.x * 0.5
	var side := float(dr["side"])
	var w := float(dr["w"]) + 2.4
	var x0 := hx - 3.6 if side > 0.0 else -hx - 1.2
	return Rect2(x0, float(dr["z"]) - w * 0.5, 4.8, w)


## 摆完以后，把挡在门口的东西（侧墙的树干、灯柱、蘑菇……）拿掉
func _clear_doorways() -> void:
	if doors.is_empty():
		return
	var rects: Array[Rect2] = []
	for dr: Dictionary in doors:
		rects.append(_door_clear_rect(dr))
	for c: Node in get_children():
		var n := c as Node3D
		if n == null or n.has_meta("floor"):
			continue
		var p := Vector2(n.global_position.x, n.global_position.z)
		for r: Rect2 in rects:
			if r.has_point(p):
				n.queue_free()
				break
	occluders = occluders.filter(func(o: Array) -> bool:
		var nd: Node3D = o[0]
		return not nd.is_queued_for_deletion())


# ---------- 放件 ----------

## 放一个开源件（assets/voxel/kit），scale 是相对原尺寸的倍数；返回节点
func kit(id: String, pos: Vector3, yaw: float = 0.0, scale: float = 1.0, solid: bool = true, fg: bool = false) -> Node3D:
	var piece := VoxelKit.get_piece(id)
	if piece.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = piece["mesh"]
	var m := env_mat
	if fg:
		m = env_mat.duplicate()
	mi.material_override = m
	add_child(mi)
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * PX * scale
	var sz: Vector3 = piece["size"] * PX * scale
	var light: Array = piece["light"]
	if not light.is_empty():
		var lp: Vector3 = pos + Basis(Vector3.UP, yaw) * (Vector3(light[0]) * PX * scale)
		var l := OmniLight3D.new()
		l.light_color = light[1]
		l.light_energy = 2.2
		l.omni_range = float(light[2]) * PX * 1.6 * scale
		l.omni_attenuation = 1.4
		add_child(l)
		l.position = lp
		_flame(lp)
	if solid:
		var ext := Vector3(sz.x, 2.0, sz.z)
		if absf(sin(yaw)) > 0.7:
			ext = Vector3(sz.z, 2.0, sz.x)
		_box_collider(pos + Vector3(0, 1, 0), ext * Vector3(0.85, 1, 0.85))
	if fg:
		occluders.append([mi, [m], AABB(pos - Vector3(sz.x * 0.5, 0, sz.z * 0.5), sz)])
	return mi


## 自己画的体素件：fill(grid) 往格子里填，vs 是一格多少米
func voxel_piece(g: VoxelGrid, pos: Vector3, vs: float, glow: VoxelGrid = null, solid_ext: Vector3 = Vector3.ZERO, fg: bool = false, yaw: float = 0.0) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var mats: Array = []
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_of(g, vs, false)
	var m := env_mat.duplicate() if fg else env_mat
	mi.material_override = m
	mats.append(m)
	root.add_child(mi)
	if glow != null and glow.size() > 0:
		var gi := MeshInstance3D.new()
		gi.mesh = _mesh_of(glow, vs, true)
		var gm := glow_mat.duplicate() if fg else glow_mat
		gi.material_override = gm
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mats.append(gm)
		root.add_child(gi)
	if solid_ext != Vector3.ZERO:
		_box_collider(pos + Vector3(0, solid_ext.y * 0.5, 0), solid_ext)
	if fg:
		var aabb := mi.get_aabb()
		occluders.append([root, mats, AABB(pos + aabb.position, aabb.size)])
	return root


## 鬼火：pixelfx 的像素火苗（循环）+ 一盏同色点光
func spirit_fire(p: Vector3, c: Color, h: float = 1.0, energy: float = 1.8, rng_: float = 6.0) -> void:
	if Vfx.I != null:
		var f := Vfx.I.sheet("spirit-flame", p, h, c, 2.0, false, 1.0e6)
		f.reparent(self)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_
	add_child(l)
	l.position = p + Vector3(0, h * 0.4, 0)


func _flame(p: Vector3) -> void:
	var fl := CPUParticles3D.new()
	fl.amount = 10
	fl.lifetime = 0.5
	fl.mesh = _particle_quad(0.25)
	fl.material_override = _fx_mat("flame_01", Color(1.0, 0.55, 0.2), true, 2.5)
	fl.direction = Vector3.UP
	fl.spread = 10.0
	fl.initial_velocity_min = 0.4
	fl.initial_velocity_max = 0.8
	fl.gravity = Vector3(0, 0.6, 0)
	fl.scale_amount_min = 0.6
	fl.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	fl.scale_amount_curve = curve
	add_child(fl)
	fl.global_position = p


func _particle_quad(s: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	return q


func _fx_mat(tex: String, c: Color, additive: bool, energy: float = 2.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader" if additive else "res://shaders/arpg/fx_mix.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/%s.png" % tex))
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("billboard", true)
	if additive:
		m.set_shader_parameter("energy", energy)
	return m


# ---------- 自己画的件 ----------

## 大树干（深色，带根和苔藓），h 高（格），vs 0.12 米
## 同一个格子（缓存下来的树干、樱树、管子）只合一次网格
func _mesh_of(g: VoxelGrid, vs: float, glow: bool) -> ArrayMesh:
	if g.has_meta("wk") and VoxelKit.record != null:
		var wk: Array = g.get_meta("wk")
		var rec: Dictionary = VoxelKit.record.get("grid|" + String(wk[0]), {})
		if not rec.is_empty() and not (rec["meshes"] as Array).has([wk[1], vs, glow]):
			(rec["meshes"] as Array).append([wk[1], vs, glow])
	var key := _mesh_key(vs, glow)
	if g.has_meta(key):
		return g.get_meta(key)
	var m := g.downsample(2).build(vs * 2.0, Vector3.ZERO, glow) if _mesh_coarse(vs, glow) else g.build(vs, Vector3.ZERO, glow)
	g.set_meta(key, m)
	return m


static func _mesh_coarse(vs: float, glow: bool) -> bool:
	return VoxelModel.coarse and vs < 0.1 and not glow   # 低画质：细格子的件两格并一格


static func _mesh_key(vs: float, glow: bool) -> StringName:
	return StringName("mesh_%d_%d_%d" % [int(round(vs * 100000.0)), int(VoxelGrid.quant), int(_mesh_coarse(vs, glow))])


## 精细体素的件生成很慢（几万格），按参数缓存下来跨房间复用。make 返回格子（或 [格子, 发光格子]）
static var _grid_cache := {}


func _cached(key: String, make: Callable) -> Variant:
	if not _grid_cache.has(key):
		_grid_cache[key] = make.call()
		if VoxelKit.record != null and make.get_object() is Arena:
			# 记下怎么生成（tools/gen_warm_list.sh 写进预拼清单，VoxelWarm 照着提前生成、拼网格）
			var cls := "Arena3" if make.get_object() is Arena3 else "Arena"
			VoxelKit.record["grid|" + key] = {"cls": cls, "key": key, "method": String(make.get_method()), "args": make.get_bound_arguments(), "meshes": []}
			var r: Variant = _grid_cache[key]
			if r is VoxelGrid:
				(r as VoxelGrid).set_meta("wk", [key, -1])
			elif r is Array:
				for i in range((r as Array).size()):
					if r[i] is VoxelGrid:
						(r[i] as VoxelGrid).set_meta("wk", [key, i])
	return _grid_cache[key]


## 后台预拼自己画的件（VoxelWarm 用）：job = ["grid", 类名, 键, 方法, 参数, [[第几个格子, vs, 发光], ...]]
## 生成格子那一步不分帧（这些件生成都很快，慢的是拼网格）
static func warm_grid(job: Array) -> void:
	var key := String(job[2])
	if not _grid_cache.has(key):
		var dummy: Arena = Arena3.new() if String(job[1]) == "Arena3" else Arena.new()
		dummy.rng.seed = hash(key)
		dummy.noise.seed = hash(key)
		dummy.noise.frequency = 0.08
		var r: Variant = dummy.callv(String(job[3]), _args_of(job[4]))
		dummy.free()
		if _grid_cache.has(key) or r == null:
			return
		_grid_cache[key] = r
	var res: Variant = _grid_cache[key]
	for m: Array in job[5]:
		var g: VoxelGrid = res if int(m[0]) < 0 else res[int(m[0])]
		var vs := float(m[1])
		var glow := bool(m[2])
		var mk := _mesh_key(vs, glow)
		if g == null or g.has_meta(mk) or g.size() == 0:
			continue
		var mesh: ArrayMesh
		if _mesh_coarse(vs, glow):
			mesh = await (await g.downsample_sliced(2)).build_sliced(vs * 2.0, Vector3.ZERO, glow)
		else:
			mesh = await g.build_sliced(vs, Vector3.ZERO, glow)
		if not g.has_meta(mk) and mk == _mesh_key(vs, glow):
			g.set_meta(mk, mesh)


## 清单里的参数是 JSON 存的：整数存成 ["i", n]、颜色存成 ["c", "rrggbbaa"]，还原成方法要的类型
static func _args_of(a: Variant) -> Array:
	var out := []
	for v: Variant in a:
		if v is Array and (v as Array).size() == 2 and v[0] is String:
			out.append(int(v[1]) if v[0] == "i" else Color.html(String(v[1])))
		else:
			out.append(v)
	return out


static func args_to_json(a: Array) -> Array:
	var out := []
	for v: Variant in a:
		if v is int:
			out.append(["i", v])
		elif v is Color:
			out.append(["c", (v as Color).to_html(true)])
		else:
			out.append(v)
	return out


## 树干只留三种粗细高矮（按传进来的高度挑最近的一档），同色同档的跨房间复用
func _trunk_c(h: int, r: float, bark: Color, moss: Color) -> VoxelGrid:
	var v := clampi(int(round((h - 40) / 12.0)), 0, 2)
	var hq: int = [44, 54, 66][v]
	var rq: float = clampf(roundf(r), 4.0, 6.0)
	return _cached("trunk|%d|%.1f|%s|%s" % [hq, rq, bark.to_html(), moss.to_html()], _trunk.bind(hq, rq, bark, moss))


## 精细体素的倍数：手搓的弯曲件（树干、樱树、管子）按 FINE 倍格子数生成，调用处 vs 除以 FINE
const FINE := 2


func _trunk(h0: int, r0: float, bark: Color, moss: Color) -> VoxelGrid:
	var g := VoxelGrid.new(rng.randi())
	var k := float(FINE)
	var h := h0 * FINE
	var r := r0 * k
	for y in range(h):
		var yf := y / k
		var rr := r * (1.0 + 0.5 * maxf(0.0, 1.0 - yf / 4.0)) * (1.0 - 0.15 * y / h)
		var wob := Vector2(sin(yf * 0.3) * 0.6, cos(yf * 0.25) * 0.5) * k
		for x in range(-int(rr) - 2, int(rr) + 3):
			for z in range(-int(rr) - 2, int(rr) + 3):
				var d := Vector2(x - wob.x, z - wob.y).length()
				if d <= rr:
					var c := bark
					# 树皮竖纹 + 苔藓斑
					var n := noise.get_noise_3d(x * 7.0 / k, yf * 3.0, z * 7.0 / k)
					if n > 0.25:
						c = moss
					elif sin(atan2(z - wob.y, x - wob.x) * 9.0 + yf * 0.15) > 0.6:
						c = bark * 0.7
					if d < rr - 2.0 and x != 0:
						continue
					g.cells[Vector3i(x, y, z)] = c * (0.85 + rng.randf() * 0.25)
	# 树根
	for i in range(5):
		var a := TAU * i / 5.0 + rng.randf() * 0.5
		var dir := Vector2(cos(a), sin(a))
		for s in range(int(r * 2.5)):
			var p := dir * (r + s)
			var yy := maxi(0, int((2 - s / (3.0 * k)) * k))
			for y in range(yy + 1):
				for w in range(-1, 1):
					g.cells[Vector3i(int(p.x) + w * int(dir.y), y, int(p.y) + w * int(-dir.x))] = bark * 0.9
	return g


## 锈蚀巨管：沿 x 方向的圆管，带铆钉环
func _pipe(length0: int, r0: float) -> VoxelGrid:
	var g := VoxelGrid.new(rng.randi())
	var length := length0 * FINE
	var r := r0 * FINE
	for x in range(length):
		var ring := (x / FINE) % 10 == 0
		var rr := r + (0.6 * FINE if ring else 0.0)
		for y in range(-int(rr) - 1, int(rr) + 2):
			for z in range(-int(rr) - 1, int(rr) + 2):
				var d := Vector2(y, z).length()
				if d <= rr and d > rr - 2.0:
					var rust := noise.get_noise_3d(x * 5.0 / FINE, y * 5.0 / FINE, z * 5.0 / FINE)
					var c := Color(0.32, 0.22, 0.16).lerp(Color(0.5, 0.26, 0.12), rust * 0.5 + 0.5)
					if rust > 0.4:
						c = Color(0.2, 0.32, 0.26)
					if ring:
						c = Color(0.22, 0.2, 0.2)
					g.cells[Vector3i(x, y + int(r) + 1, z)] = c
	return g


## 木脚手架：两根立柱 + 横梁 + 斜撑
func _scaffold(w: int, h: int) -> VoxelGrid:
	var g := VoxelGrid.new(rng.randi())
	var wood := Color(0.3, 0.2, 0.13)
	for px in [0, w]:
		for pz in [0, 6]:
			g.box(Vector3i(px, 0, pz), Vector3i(px + 1, h, pz + 1), wood, 0.12)
	for y in [h / 2, h]:
		g.box(Vector3i(0, y, 0), Vector3i(w + 1, y + 1, 1), wood * 1.1, 0.1)
		g.box(Vector3i(0, y, 6), Vector3i(w + 1, y + 1, 7), wood * 1.1, 0.1)
		g.box(Vector3i(0, y + 1, 0), Vector3i(w + 1, y + 1, 7), Color(0.36, 0.26, 0.16), 0.15)
	for i in range(w):
		var y := int(float(i) / w * h / 2)
		g.cells[Vector3i(i, y, 0)] = wood
		g.cells[Vector3i(i, y + 1, 0)] = wood
	# 垂下来的藤
	for i in range(6):
		var x := rng.randi_range(0, w)
		var len := rng.randi_range(3, h / 2)
		for y in range(len):
			g.cells[Vector3i(x, h - y, 7)] = Color(0.16, 0.38, 0.24) * (0.8 + rng.randf() * 0.4)
	return g


## 朱红柱
func _pillar(h: int, c: Color) -> VoxelGrid:
	var g := VoxelGrid.new(rng.randi())
	g.box(Vector3i(-3, 0, -3), Vector3i(3, 1, 3), Color(0.25, 0.24, 0.24), 0.08)
	g.box(Vector3i(-2, 2, -2), Vector3i(2, h, 2), c, 0.06)
	g.box(Vector3i(-3, h, -3), Vector3i(3, h + 1, 3), Color(0.15, 0.1, 0.08), 0.05)
	return g


## 纸窗（格子窗，透冷月光）：返回 [木框, 发光纸]
func _shoji(w: int, h: int) -> Array:
	var frame := VoxelGrid.new(rng.randi())
	var paper := VoxelGrid.new(rng.randi())
	var wood := Color(0.22, 0.14, 0.1)
	for x in range(w + 1):
		for y in range(h + 1):
			var edge := x == 0 or y == 0 or x == w or y == h
			var bar := x % 5 == 0 or y % 6 == 0
			if edge or bar:
				frame.cells[Vector3i(x, y, 0)] = wood
				if edge:
					frame.cells[Vector3i(x, y, 1)] = wood
			else:
				paper.cells[Vector3i(x, y, 0)] = Color(0.55, 0.75, 1.0) * (0.55 + 0.1 * rng.randf())
	return [frame, paper]


## 鸟居
func _torii(w: int, h: int) -> VoxelGrid:
	var g := VoxelGrid.new(rng.randi())
	var red := Color(0.62, 0.1, 0.08)
	for px in [3, w - 4]:
		g.box(Vector3i(px - 1, 0, -1), Vector3i(px + 1, h, 1), red, 0.06)
		g.box(Vector3i(px - 2, 0, -2), Vector3i(px + 2, 1, 2), Color(0.12, 0.1, 0.1), 0.05)
	g.box(Vector3i(0, h - 6, -1), Vector3i(w, h - 5, 0), red, 0.05)
	g.box(Vector3i(-2, h, -2), Vector3i(w + 2, h + 1, 1), Color(0.1, 0.08, 0.08), 0.05)
	g.box(Vector3i(-1, h - 1, -1), Vector3i(w + 1, h - 1, 0), red, 0.05)
	g.box(Vector3i(w / 2 - 1, h - 5, -1), Vector3i(w / 2 + 1, h - 2, 0), Color(0.1, 0.08, 0.08), 0.0)
	return g


## 石灯笼：返回 [石头, 发光的灯]
func _stone_lantern() -> Array:
	var g := VoxelGrid.new(rng.randi())
	var lit := VoxelGrid.new(rng.randi())
	var st := Color(0.42, 0.42, 0.45)
	g.box(Vector3i(-3, 0, -3), Vector3i(3, 1, 3), st * 0.85, 0.1)
	g.box(Vector3i(-1, 2, -1), Vector3i(1, 8, 1), st, 0.1)
	g.box(Vector3i(-3, 9, -3), Vector3i(3, 9, 3), st, 0.1)
	for x in range(-2, 3):
		for z in range(-2, 3):
			for y in range(10, 13):
				if absf(x) == 2 or absf(z) == 2:
					if (absf(x) == 2 and absf(z) == 2) or y == 10:
						g.cells[Vector3i(x, y, z)] = st
					else:
						lit.cells[Vector3i(x, y, z)] = Color(1.0, 0.7, 0.35)
				else:
					lit.cells[Vector3i(x, y, z)] = Color(1.0, 0.8, 0.45)
	g.box(Vector3i(-4, 13, -4), Vector3i(4, 13, 4), st * 0.9, 0.1)
	g.box(Vector3i(-2, 14, -2), Vector3i(2, 14, 2), st * 0.9, 0.1)
	g.cells[Vector3i(0, 15, 0)] = st
	return [g, lit]


## 大樱树：粗干 + 一团团发光的粉色花冠
func _sakura_tree() -> Array:
	var g := VoxelGrid.new(rng.randi())
	var bloom := VoxelGrid.new(rng.randi())
	var bark := Color(0.2, 0.13, 0.13)
	var k := float(FINE)
	# 树干弯一点往上分叉
	for y in range(0, 34 * FINE):
		var yf := y / k
		var r := (3.5 - yf * 0.06) * k
		var cx := sin(yf * 0.12) * 2.0 * k
		for x in range(-6 * FINE, 6 * FINE + 1):
			for z in range(-6 * FINE, 6 * FINE + 1):
				var d := Vector2(x - cx, z).length()
				if d <= r and d > r - 2.5:
					var c := bark * (0.8 + rng.randf() * 0.3)
					if sin(atan2(z, x - cx) * 7.0 + yf * 0.2) > 0.55:
						c *= 0.75
					g.cells[Vector3i(x, y, z)] = c
	var tips := []
	for i in range(6):
		var a := TAU * i / 6.0 + rng.randf() * 0.4
		var dir := Vector3(cos(a), 0.0, sin(a))
		var p := Vector3(0, 30, 0) * k
		for s in range(16 * FINE):
			p += (dir * 0.9 + Vector3(0, 0.55, 0))
			var bw := 2 if s < 8 * FINE else 1
			for dx in range(-bw, bw + 1):
				for dz in range(-bw, bw + 1):
					for dy in range(0, 2):
						g.cells[Vector3i(int(p.x) + dx, int(p.y) + dy, int(p.z) + dz)] = bark * (0.85 + rng.randf() * 0.2)
		tips.append(p)
	tips.append(Vector3(0, 46, 0) * k)
	for t: Vector3 in tips:
		var rad := rng.randf_range(6.0, 9.0) * k
		for x in range(int(-rad), int(rad) + 1):
			for y in range(int(-rad * 0.7), int(rad * 0.7) + 1):
				for z in range(int(-rad), int(rad) + 1):
					var d := Vector3(x / rad, y / (rad * 0.7), z / rad).length()
					if d > 1.0:
						continue
					var key := Vector3i(int(t.x) + x, int(t.y) + y, int(t.z) + z)
					if bloom.cells.has(key):
						continue
					# 只要外壳：里面看不见，省面数
					if d < 0.72:
						continue
					if noise.get_noise_3d(key.x * 9.0 / k, key.y * 9.0 / k, key.z * 9.0 / k) > -0.3 - (1.0 - d) * 0.6:
						# 花团：低频噪声分出一簇一簇，上面亮下面暗，零星深色花心
						var clump := noise.get_noise_3d(key.x * 3.0 / k, key.y * 3.0 / k, key.z * 3.0 / k) * 0.5 + 0.5
						var c := Color(0.95, 0.5, 0.68).lerp(Color(1.0, 0.86, 0.92), clump * 0.8 + rng.randf() * 0.2)
						c = c * (0.62 + 0.4 * clampf(float(y) / (rad * 0.7) * 0.5 + 0.5, 0.0, 1.0))
						if rng.randf() < 0.05:
							c = Color(0.8, 0.3, 0.5)
						bloom.cells[key] = c * 0.8
	return [g, bloom]


## 一丛发光蘑菇：返回 [柄, 发光的伞]
func _mushrooms() -> Array:
	var g := VoxelGrid.new(rng.randi())
	var lit := VoxelGrid.new(rng.randi())
	for i in range(rng.randi_range(3, 6)):
		var base := Vector2(rng.randi_range(-12, 12), rng.randi_range(-12, 12))
		var h := rng.randi_range(4, 12)
		var lean := Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
		# 柄：微微歪着，两格粗
		var top := Vector3i()
		for y in range(h):
			var q := base + lean * y
			for dx in range(0, 2):
				for dz in range(0, 2):
					g.cells[Vector3i(int(q.x) + dx, y, int(q.y) + dz)] = Color(0.72, 0.78, 0.74) * (0.9 + rng.randf() * 0.15)
			top = Vector3i(int(q.x), y, int(q.y))
		# 伞：半球壳，边缘一圈暗一点，顶上亮点
		var r := rng.randf_range(2.5, 4.5)
		var c := Color(0.3, 0.95, 0.9) if rng.randf() < 0.75 else Color(0.6, 0.5, 1.0)
		for x in range(-int(r) - 1, int(r) + 2):
			for z in range(-int(r) - 1, int(r) + 2):
				for y in range(0, int(r * 0.7) + 2):
					var d := Vector3(x / r, y / (r * 0.7), z / r).length()
					if d <= 1.0 and d > 0.6:
						var cc := c * (0.75 + 0.35 * float(y) / (r * 0.7))
						if y == 0:
							cc = c * 0.55
						lit.cells[top + Vector3i(x, y + 1, z)] = cc
	return [g, lit]


## 带发光部分的小件（不挡路），顺便放一盏很弱的点光
func voxel_piece_glow(parts_: Array, pos: Vector3, vs: float) -> void:
	var n := voxel_piece(parts_[0], pos, vs, parts_[1])
	if rng.randf() < 0.4:
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 1.0, 0.9)
		l.light_energy = 0.8
		l.omni_range = 2.5
		n.add_child(l)
		l.position = Vector3(0, 0.4, 0)


## 挂轴
func _scroll() -> VoxelGrid:
	var g := VoxelGrid.new(rng.randi())
	g.box(Vector3i(-4, 20, 0), Vector3i(4, 20, 0), Color(0.15, 0.1, 0.08))
	g.box(Vector3i(-3, 2, 0), Vector3i(3, 19, 0), Color(0.75, 0.7, 0.58), 0.05)
	# 墨画：几笔山
	for x in range(-2, 3):
		var top := 10 + 3 - absi(x) * 2
		for y in range(6, top):
			g.cells[Vector3i(x, y, 0)] = Color(0.2, 0.2, 0.22)
	g.box(Vector3i(-4, 1, 0), Vector3i(4, 1, 0), Color(0.15, 0.1, 0.08))
	return g


# ---------- 各区域布置 ----------

func _dress_forest() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var kz := _kz()
	var ka := _ka()
	# 远处（画面上方）：断墙 + 巨管 + 脚手架，形成背景墙
	var nw := int(hx / 3.3)
	for i in range(-nw, nw + 1):
		var x := i * 3.3 + rng.randf_range(-0.3, 0.3)
		if absf(x) < 2.5:
			continue   # 出口留空
		var id := "wall" if rng.randf() < 0.6 else ("wall_broken" if rng.randf() < 0.5 else "wall_arch")
		kit(id, Vector3(x, 0, -hz - 0.3), 0.0, 1.0, false)
	voxel_piece(_cached("pipe160", _pipe.bind(160, 6.0)), Vector3(-hx, 3.4, -hz - 1.2), 0.12 / FINE)
	voxel_piece(_cached("pipe60", _pipe.bind(60, 4.0)), Vector3(hx - 9.0, 0.0, -hz + 0.6), 0.12 / FINE, null, Vector3(7.2, 1.2, 1.2))
	voxel_piece(_scaffold(40, 34), Vector3(-hx + 1.0, 0, -hz + 0.2), 0.12, null, Vector3(0.1, 0.1, 0.1))
	voxel_piece(_scaffold(30, 28), Vector3(hx - 5.5, 0, -hz + 1.6), 0.12)
	# 左右两侧：大树干和枯树
	for side: float in [-1.0, 1.0]:
		var nt := maxi(4, int(round(4.0 * kz)))
		for j in range(nt):
			var z := -hz + 3.0 + j * (size.y - 5.0) / float(nt - 1) + rng.randf_range(-1, 1)
			var x := side * (hx - 0.5 + rng.randf_range(-0.4, 0.4))
			voxel_piece(_trunk_c(rng.randi_range(40, 60), rng.randf_range(4.0, 6.0), Color(0.16, 0.13, 0.12), Color(0.18, 0.34, 0.22)), Vector3(x, 0, z), 0.12 / FINE, null, Vector3(1.4, 4, 1.4))
		kit("tree_dead", Vector3(side * (hx - 3.0), 0, -hz + 4.0), rng.randf() * TAU, 1.0, true)
	# 房间里的障碍：柱子、碎石、墓碑、火把
	var spots := [Vector3(-7 * kx, 0, -3 * kz), Vector3(7.5 * kx, 0, -2 * kz), Vector3(-5 * kx, 0, 5 * kz), Vector3(6 * kx, 0, 4.5 * kz)]
	for i in range(int(round(4.0 * (ka - 1.0)))):
		var fp := _free_spot(4.5)
		if fp != Vector3.INF:
			spots.append(fp)
	for s: Vector3 in spots:
		var r := rng.randf()
		if r < 0.35:
			kit("pillar", s, rng.randf() * TAU, 1.0, true)
		elif r < 0.6:
			kit("rubble", s, rng.randf() * TAU, 1.0, true)
		elif r < 0.8:
			kit("column", s, 0.0, 1.8, true)
		else:
			kit("crates", s, rng.randf() * TAU, 1.0, true)
	var lamps := [Vector3(-3.5, 0, -hz + 1.2), Vector3(3.5, 0, -hz + 1.2), Vector3(-hx + 2.5, 0, 1), Vector3(hx - 2.5, 0, -1)]
	if ka > 1.5:
		lamps.append_array([Vector3(-hx + 2.5, 0, -hz * 0.55), Vector3(hx - 2.5, 0, hz * 0.45)])
	for s: Vector3 in lamps:
		kit("post_lantern", s, 0.0, 1.0, true)
	# 大房间：中间两侧各一处断墙残垣，可以绕着打、卡位
	if ka > 1.5:
		for _k in range(2):
			var c := _free_spot(6.0, 5.0, 5.0)
			if c == Vector3.INF:
				continue
			var side := signf(c.x)
			kit("wall_broken", c, PI * 0.5 * float(rng.randi() % 2), 1.0, true)
			kit("rubble", c + Vector3(side * 2.2, 0, 1.6), rng.randf() * TAU, 1.0, true)
			spirit_fire(c + Vector3(-side * 1.6, 0.5, 1.2), Color(0.55, 1.0, 0.85), 0.9, 1.4, 5.5)
	for i in range(int(6 * ka)):
		var p := Vector3(rng.randf_range(-hx + 3, hx - 3), 0, rng.randf_range(-hz + 3, hz - 3))
		if p.length() > 4.0:
			kit(["gravestone", "grave_a", "gravemarker", "ribcage", "sword_shield"][rng.randi() % 5], p, rng.randf() * TAU, 1.0, false)
	# 鬼火：几团飘在墙根的青色火，给暗处一点光
	for i in range(int(round(4.0 * sqrt(ka)))):
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(hx - 5.0, hx - 3.0), 0.5, rng.randf_range(-hz + 3, hz - 4))
		spirit_fire(p, Color(0.55, 1.0, 0.85), 0.9, 1.4, 5.5)
	# 发光蘑菇丛：青色小光点，沿墙根和树根长
	for i in range(int(16 * ka)):
		var edge_p := Vector3(rng.randf_range(-hx + 1.5, hx - 1.5), 0, rng.randf_range(-hz + 1.5, hz - 1.5))
		if rng.randf() < 0.6:
			edge_p.x = (hx - rng.randf_range(1.0, 3.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
		voxel_piece_glow(_mushrooms(), edge_p, 0.03)
	# 前景剪影（靠镜头那边）：粗树干、垂藤，挡住主角时自动变透明
	for x0: float in _fg_xs():
		var x := x0 + rng.randf_range(-1.0, 1.0)
		voxel_piece(_trunk_c(rng.randi_range(55, 65), rng.randf_range(5.0, 6.0), Color(0.04, 0.05, 0.05), Color(0.05, 0.09, 0.07)), Vector3(x, 0, hz + 1.5), 0.12 / FINE, null, Vector3.ZERO, true)


## 无名冢：后面一排地穴和铁栅，两边枯树，场地里散着墓碑、棺材、骨堆，鬼火和挂灯
func _dress_grave() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var kz := _kz()
	var ka := _ka()
	# 后排：地穴、石门、栅栏
	kit("crypt", Vector3(-hx + 5.0, 0, -hz - 1.2), 0.0, 1.0, false)
	kit("crypt", Vector3(hx - 5.0, 0, -hz - 1.2), 0.0, 1.0, false)
	kit("arch_gate", Vector3(0, 0, -hz - 0.4), 0.0, 1.0, false)
	var nf := int((hx - 1.0) / 1.9)
	for i in range(-nf, nf + 1):
		var x := i * 1.9
		if absf(x) < 2.6 or absf(absf(x) - (hx - 5.0)) < 2.6:
			continue
		kit("fence" if rng.randf() < 0.7 else "fence_broken", Vector3(x, 0, -hz + 0.2), 0.0, 1.0, false)
	# 两侧：枯树、松树、挂骷髅的杆子
	for side: float in [-1.0, 1.0]:
		var nt := maxi(3, int(round(3.0 * kz)))
		for j in range(nt):
			var z := -hz + 3.0 + j * (size.y - 6.0) / float(nt - 1) + rng.randf_range(-1, 1)
			kit(["tree_dead", "tree_dead_m", "tree_pine"][rng.randi() % 3], Vector3(side * (hx - 1.0), 0, z), rng.randf() * TAU, 1.0, true)
		kit("post_skull", Vector3(side * (hx - 3.2), 0, -hz + 2.0), 0.0, 1.0, true)
	# 场地里：几排墓碑（成排更像墓园），中间留出路
	var nrow := maxi(3, int((size.y - 9.0) / 4.2) + 1)
	var ncol := maxi(2, int(round(2.5 * kx)))
	for row in range(nrow):
		var z := -hz + 4.0 + row * 4.2
		for i in range(ncol * 2):
			var x := (-hx + 3.0) + i * 1.6 if i < ncol else (hx - 3.0) - (i - ncol) * 1.6
			if rng.randf() < 0.3:
				continue
			kit(["gravestone", "grave_a", "grave_b", "gravemarker"][rng.randi() % 4], Vector3(x + rng.randf_range(-0.3, 0.3), 0, z + rng.randf_range(-0.3, 0.3)), rng.randf_range(-0.2, 0.2), 1.0, true)
	var spots := [Vector3(-6.5 * kx, 0, 1.5 * kz), Vector3(6.0 * kx, 0, -2.5 * kz), Vector3(-2.5 * kx, 0, 6.0 * kz)]
	for i in range(int(round(3.0 * (ka - 1.0)))):
		var fp := _free_spot(4.0)
		if fp != Vector3.INF:
			spots.append(fp)
	for s: Vector3 in spots:
		var r := rng.randf()
		if r < 0.4:
			kit("coffin", s, rng.randf() * TAU, 1.0, true)
		elif r < 0.7:
			kit("ribcage", s, rng.randf() * TAU, 1.3, false)
		else:
			kit("rubble", s, rng.randf() * TAU, 1.0, true)
	# 灯：挂灯和骷髅烛，冷绿色的鬼火
	var lamps := [Vector3(-3.2, 0, -hz + 1.6), Vector3(3.2, 0, -hz + 1.6), Vector3(-hx + 2.2, 0, 2.0), Vector3(hx - 2.2, 0, 0.0)]
	if ka > 1.5:
		lamps.append_array([Vector3(-hx + 2.2, 0, -hz * 0.5), Vector3(hx - 2.2, 0, hz * 0.5)])
	for s: Vector3 in lamps:
		kit("post_lantern", s, 0.0, 1.0, true)
	# 大房间：场地中间一左一右两座石门残墓（带棺材和鬼火），可以绕着打
	if ka > 1.5:
		for _k in range(2):
			var c := _free_spot(6.0, 5.0, 5.0)
			if c == Vector3.INF:
				continue
			var side := signf(c.x)
			kit("arch_gate", c, PI * 0.5, 1.0, true)
			kit("coffin", c + Vector3(side * 2.0, 0, 1.5), rng.randf() * TAU, 1.0, true)
			spirit_fire(c + Vector3(-side * 1.4, 0.6, 0.8), Color(0.5, 1.0, 0.55), 0.9, 1.3, 5.0)
	for i in range(int(round(3.0 * ka))):
		kit("skull_candle", Vector3(rng.randf_range(-hx + 3, hx - 3), 0, rng.randf_range(-hz + 3, hz - 3)), rng.randf() * TAU, 1.0, false)
	for i in range(int(round(5.0 * sqrt(ka)))):
		var side := -1.0 if i % 2 == 0 else 1.0
		spirit_fire(Vector3(side * rng.randf_range(2.0, hx - 3.0), 0.6, rng.randf_range(-hz + 2, hz - 4)), Color(0.5, 1.0, 0.55), 0.9, 1.3, 5.0)
	# 前景：黑树干剪影
	for x0: float in _fg_xs():
		var x := x0 + rng.randf_range(-1.0, 1.0)
		voxel_piece(_trunk_c(60, 5.0, Color(0.04, 0.05, 0.05), Color(0.06, 0.08, 0.06)), Vector3(x, 0, hz + 1.5), 0.12 / FINE, null, Vector3.ZERO, true)


func _dress_temple() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var red := Color(0.45, 0.08, 0.06)
	var kx := _kx()
	var kz := _kz()
	var ka := _ka()
	# 后墙：纸窗一排，透冷蓝月光
	var nwin := int((hx - 1.6) / 2.6)
	for i in range(-nwin, nwin + 1):
		var x := i * 2.6
		if absf(x) < 2.0:
			continue
		var sh := _shoji(18, 22)
		var n := voxel_piece(sh[0], Vector3(x - 1.1, 0.6, -hz - 0.2), 0.12, sh[1])
		var l := SpotLight3D.new()
		l.light_color = Color(0.55, 0.75, 1.0)
		l.light_energy = 3.0
		l.spot_range = 9.0
		l.spot_angle = 30.0
		n.add_child(l)
		l.position = Vector3(1.1, 2.6, -0.5)
		l.rotation = Vector3(-0.7, 0, 0)
		if i % 2 == 0:
			_shaft(Vector3(x, 0, -hz + 2.0), Color(0.5, 0.75, 1.0, 0.25), 3.5)
	# 墙下面的木台
	var g := VoxelGrid.new(1)
	g.box(Vector3i(0, 0, 0), Vector3i(int(size.x / 0.2), 2, 6), Color(0.2, 0.13, 0.09), 0.1)
	voxel_piece(g, Vector3(-hx, 0, -hz - 0.4), 0.2)
	# 柱子：两排朱红柱（障碍）
	var npl := int((hx - 2.5) / 6.0)
	for i in range(-npl, npl + 1):
		if i == 0:
			continue
		var rows := [-hz + 3.5, hz - 4.0]
		if size.y >= 28.0 and absi(i) >= 2:
			rows.append(-0.5)   # 大殿：两翼中间再立一根，隔出几处可以绕的柱间
		for zz: float in rows:
			voxel_piece(_pillar(34, red), Vector3(i * 6.0, 0, zz), 0.12, null, Vector3(0.7, 4, 0.7))
	# 供台、蜡烛、香炉
	var alt := VoxelGrid.new(2)
	alt.box(Vector3i(-14, 0, -4), Vector3i(14, 6, 4), Color(0.18, 0.1, 0.08), 0.08)
	alt.box(Vector3i(-15, 7, -5), Vector3i(15, 7, 5), Color(0.35, 0.08, 0.06), 0.05)
	voxel_piece(alt, Vector3(0, 0, -hz + 1.2), 0.12, null, Vector3(3.6, 1.2, 1.2))
	kit("shrine", Vector3(0, 0.95, -hz + 1.2), 0.0, 1.0, false)
	for x: float in [-1.2, 1.2]:
		kit("candles", Vector3(x, 0.95, -hz + 1.0), 0.0, 1.0, false)
	for x: float in [-hx + 2.0, hx - 2.0]:
		kit("candles", Vector3(x, 0, -hz + 2.0), 0.0, 1.2, false)
		kit("lantern", Vector3(x, 0, hz - 2.5), 0.0, 1.2, false)
	# 挂轴
	var nsc := int((hx - 3.0) / 4.5)
	for i in range(-nsc, nsc + 1):
		if i != 0:
			voxel_piece(_scroll(), Vector3(i * 4.5, 0.8, -hz + 0.25), 0.12)
	# 左右墙
	for side: float in [-1.0, 1.0]:
		var w := VoxelGrid.new(3)
		w.box(Vector3i(0, 0, 0), Vector3i(4, 30, int(size.y / 0.12)), Color(0.2, 0.14, 0.1), 0.08)
		voxel_piece(w, Vector3(side * (hx + 0.2), 0, -hz), 0.12)
	# 香烟
	_smoke_column(Vector3(0, 1.3, -hz + 1.2))
	# 殿中四盏石灯，点着青色鬼火；头顶几盏暖色吊灯把地板照亮
	var stones := [Vector3(-3.6 * kx, 0, -3.0 * kz), Vector3(3.6 * kx, 0, -3.0 * kz), Vector3(-3.6 * kx, 0, 3.0 * kz), Vector3(3.6 * kx, 0, 3.0 * kz)]
	if ka > 1.5:
		stones.append_array([Vector3(-hx + 4.0, 0, 0.5), Vector3(hx - 4.0, 0, 0.5)])
	for p: Vector3 in stones:
		var sl := _stone_lantern()
		voxel_piece(sl[0], p, 0.12, sl[1], Vector3(0.8, 2, 0.8))
		spirit_fire(p + Vector3(0, 1.7, 0), Color(0.6, 1.0, 1.0), 1.9, 2.2, 7.0)
	var tops := [Vector3(0, 4.0, -1.0), Vector3(-9 * kx, 4.0, 3.0 * kz), Vector3(9 * kx, 4.0, 3.0 * kz)]
	if ka > 1.5:
		tops.append_array([Vector3(-9 * kx, 4.0, -4.0 * kz), Vector3(9 * kx, 4.0, -4.0 * kz)])
	for p: Vector3 in tops:
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.72, 0.45)
		wl.light_energy = 2.0
		wl.omni_range = 12.0
		add_child(wl)
		wl.position = p
	# 前景：靠镜头的粗梁和柱子剪影
	var nfp := maxi(3, int(round(3.0 * kx)))
	for i in range(nfp):
		var x := -hx + 5.0 + i * (size.x - 10.0) / float(nfp - 1)
		voxel_piece(_pillar(60, Color(0.08, 0.05, 0.05)), Vector3(x, 0, hz + 1.0), 0.14, null, Vector3.ZERO, true)
	var beam := VoxelGrid.new(4)
	beam.box(Vector3i(0, 0, 0), Vector3i(int(size.x / 0.14), 4, 4), Color(0.07, 0.05, 0.04), 0.05)
	voxel_piece(beam, Vector3(-hx, 6.5, hz + 0.5), 0.14, null, Vector3.ZERO, true)


func _dress_sakura() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var kz := _kz()
	# 中央偏后：发光大樱树（有碰撞，绕着打）
	var st: Array = _cached("sakura|%d" % (rng.randi() % 2), _sakura_tree)
	var tree := voxel_piece(st[0], Vector3(0, 0, -hz + 4.5), 0.14 / FINE, st[1], Vector3(1.4, 4, 1.4))
	var tl := OmniLight3D.new()
	tl.light_color = Color(1.0, 0.55, 0.75)
	tl.light_energy = 2.5
	tl.omni_range = 14.0
	tree.add_child(tl)
	tl.position = Vector3(0, 6, 0)
	# 鸟居（后面和两侧）
	voxel_piece(_torii(46, 40), Vector3(-hx + 1.0, 0, -hz + 0.5), 0.14, null, Vector3.ZERO)
	voxel_piece(_torii(46, 40), Vector3(hx - 7.5, 0, -hz + 0.5), 0.14, null, Vector3.ZERO)
	# 石灯笼一圈
	for p: Vector3 in [Vector3(-9 * kx, 0, -4 * kz), Vector3(9 * kx, 0, -4 * kz), Vector3(-11 * kx, 0, 4 * kz), Vector3(11 * kx, 0, 4 * kz), Vector3(-5 * kx, 0, -hz + 2), Vector3(5 * kx, 0, -hz + 2), Vector3(-3.8 * kx, 0, 5.5 * kz), Vector3(3.8 * kx, 0, 5.5 * kz)]:
		var sl := _stone_lantern()
		var n := voxel_piece(sl[0], p, 0.12, sl[1], Vector3(0.8, 2, 0.8))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 2.4
		l.omni_range = 7.0
		n.add_child(l)
		l.position = Vector3(0, 1.4, 0)
		spirit_fire(p + Vector3(0, 1.7, 0), Color(1.0, 0.6, 0.85), 1.6, 1.6, 6.0)
	# 围墙：低矮石墙 + 后面竹林剪影
	for side: float in [-1.0, 1.0]:
		var w := VoxelGrid.new(5)
		w.box(Vector3i(0, 0, 0), Vector3i(4, 8, int(size.y / 0.14)), Color(0.3, 0.3, 0.34), 0.1)
		w.box(Vector3i(-1, 9, 0), Vector3i(5, 10, int(size.y / 0.14)), Color(0.15, 0.13, 0.18), 0.05)
		voxel_piece(w, Vector3(side * (hx + 0.2), 0, -hz), 0.14)
	var back := VoxelGrid.new(6)
	back.box(Vector3i(0, 0, 0), Vector3i(int(size.x / 0.14), 8, 4), Color(0.3, 0.3, 0.34), 0.1)
	back.box(Vector3i(0, 9, -1), Vector3i(int(size.x / 0.14), 10, 5), Color(0.15, 0.13, 0.18), 0.05)
	voxel_piece(back, Vector3(-hx, 0, -hz - 0.8), 0.14)
	# 前景：樱花枝剪影
	var nfg := maxi(3, int(round(3.0 * kx)))
	for i in range(nfg):
		var x := -hx + 4.0 + i * (size.x - 8.0) / float(nfg - 1) + rng.randf_range(-2, 2)
		voxel_piece(_trunk_c(70, 5.0, Color(0.06, 0.04, 0.05), Color(0.12, 0.05, 0.08)), Vector3(x, 0, hz + 1.5), 0.12 / FINE, null, Vector3.ZERO, true)
	# 前面两侧再种两棵小樱树、摆长椅和灯笼，免得入口一片空地
	for side: float in [-1.0, 1.0]:
		var st2: Array = _cached("sakura|%d" % (rng.randi() % 2), _sakura_tree)
		var t2 := voxel_piece(st2[0], Vector3(side * 9.5 * kx, 0, 5.5 * kz), 0.1 / FINE, st2[1], Vector3(1.0, 4, 1.0), false, rng.randf() * TAU)
		var l2 := OmniLight3D.new()
		l2.light_color = Color(1.0, 0.55, 0.75)
		l2.light_energy = 1.6
		l2.omni_range = 8.0
		t2.add_child(l2)
		l2.position = Vector3(0, 4.0, 0)
		kit("bench", Vector3(side * 6.5 * kx, 0, 8.0 * kz), PI * 0.5, 1.0, true)
		kit("lantern", Vector3(side * 12.5 * kx, 0, -1.0 * kz), 0.0, 1.2, false)
	_petals()


## 青井地宫：后面一排经文石壁和塌掉的佛龛，两侧石柱，柱上和顶上垂下灯链；
## 地上散着断佛像、经幢、碎石，冰蓝的鬼火和井口漏下的冷光柱；整片地面铺一层带焦散的薄水
func _dress_well() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var kz := _kz()
	var ka := _ka()
	# 后墙：经文石壁（一块块刻满字的石板），中间留出口
	var nt := int((hx - 1.0) / 2.4)
	for i in range(-nt, nt + 1):
		var x := i * 2.4
		if absf(x) < 2.2:
			continue
		voxel_piece(_cached("tablet|%d" % (absi(i) % 3), _sutra_tablet.bind(absi(i) % 3)), Vector3(x - 1.05, 0, -hz - 0.25), 0.12, null)
	kit("shrine", Vector3(-hx + 4.0, 0, -hz + 1.0), 0.0, 1.2, true)
	kit("shrine", Vector3(hx - 4.0, 0, -hz + 1.0), 0.0, 1.2, true)
	# 两侧：石柱一排，柱上挂灯链
	for side: float in [-1.0, 1.0]:
		var np := maxi(3, int(round(3.0 * kz)))
		for j in range(np):
			var z := -hz + 3.0 + j * (size.y - 6.0) / float(np - 1)
			var p := Vector3(side * (hx - 1.2), 0, z)
			voxel_piece(_cached("wpillar", _well_pillar), p, 0.12, null, Vector3(0.9, 4, 0.9))
			if j % 2 == 0:
				voxel_piece(_cached("chain|%d" % (j % 3), _chain.bind(22 + (j % 3) * 6)), p + Vector3(-side * 0.6, 1.2, 0.0), 0.06, null)
	# 殿中两排大石柱（隔出柱廊，可以绕着打），每根柱上缠一截灯链，柱脚一圈积水反光
	for sx: float in [-1.0, 1.0]:
		for zz: float in [-4.0 * kz, 3.5 * kz]:
			var cp := Vector3(sx * 7.5 * kx, 0, zz)
			voxel_piece(_cached("wpillar", _well_pillar), cp, 0.12, null, Vector3(0.9, 4, 0.9))
			voxel_piece(_cached("chain|2", _chain.bind(34)), cp + Vector3(0.0, 1.6, 0.55), 0.06, null)
			_solid.append(Rect2(cp.x - 1.2, cp.z - 1.2, 2.4, 2.4))
	# 场地里：断佛像、经幢、碎石（障碍，可以绕着打）
	var spots := [Vector3(-3.5 * kx, 0, -6.0 * kz), Vector3(4.0 * kx, 0, 0.5 * kz), Vector3(-12.0 * kx, 0, 1.0 * kz), Vector3(12.5 * kx, 0, -2.0 * kz)]
	for i in range(int(round(3.0 * (ka - 1.0)))):
		var fp := _free_spot(4.5)
		if fp != Vector3.INF:
			spots.append(fp)
	for s0: Vector3 in spots:
		var r := rng.randf()
		if r < 0.35:
			kit("column", s0, 0.0, 1.6, true)
			voxel_piece(_cached("chain|1", _chain.bind(28)), s0 + Vector3(0.0, 1.0, 0.0), 0.06, null)
		elif r < 0.6:
			kit("rubble", s0, rng.randf() * TAU, 1.0, true)
		elif r < 0.85:
			kit("shrine", s0, rng.randf_range(-0.4, 0.4), 0.9, true)
		else:
			kit("pillar", s0, rng.randf() * TAU, 1.0, true)
	# 地上的碎件：经卷、蜡烛、骨头
	for i in range(int(5 * ka)):
		var p := Vector3(rng.randf_range(-hx + 3, hx - 3), 0, rng.randf_range(-hz + 3, hz - 3))
		if absf(p.x) > 2.5:
			kit(["candles", "ribcage", "rubble", "skull_candle"][rng.randi() % 4], p, rng.randf() * TAU, 0.8, false)
	# 冰蓝鬼火 + 井口漏下来的冷光
	for i in range(int(round(5.0 * sqrt(ka)))):
		var side := -1.0 if i % 2 == 0 else 1.0
		spirit_fire(Vector3(side * rng.randf_range(3.0, hx - 3.0), 0.5, rng.randf_range(-hz + 3, hz - 4)), Color(0.45, 0.85, 1.0), 1.0, 1.6, 6.0)
	for i in range(int(round(3.0 * sqrt(ka)))):
		_shaft(Vector3(rng.randf_range(-size.x * 0.35, size.x * 0.35), 0, rng.randf_range(-size.y * 0.4, size.y * 0.15)), Color(0.45, 0.8, 1.0, 0.14), rng.randf_range(2.0, 3.2))
	# 暖色：佛龛前、柱脚下几簇供烛（整间青蓝里的一点人气）
	var votive := [Vector3(-hx + 4.0, 0, -hz + 2.4), Vector3(hx - 4.0, 0, -hz + 2.4)]
	for i in range(int(round(2.0 * ka))):
		var vp := _free_spot(3.0)
		if vp != Vector3.INF:
			votive.append(vp)
	for vp: Vector3 in votive:
		kit("candles", vp, rng.randf() * TAU, 1.1, false)
		var cl := OmniLight3D.new()
		cl.light_color = Color(1.0, 0.65, 0.35)
		cl.light_energy = 1.8
		cl.omni_range = 5.0
		add_child(cl)
		cl.position = vp + Vector3(0, 0.8, 0)
	var tops := [Vector3(0, 4.0, -1.0), Vector3(-9 * kx, 4.0, 2.0 * kz), Vector3(9 * kx, 4.0, 2.0 * kz)]
	for p: Vector3 in tops:
		var wl := OmniLight3D.new()
		wl.light_color = Color(0.6, 0.85, 1.0)
		wl.light_energy = 1.6
		wl.omni_range = 12.0
		add_child(wl)
		wl.position = p
	_water_plane()
	# 前景：靠镜头的断柱剪影
	for x0: float in _fg_xs():
		voxel_piece(_cached("wpillar_fg", _well_pillar.bind(Color(0.04, 0.06, 0.08))), Vector3(x0 + rng.randf_range(-1.0, 1.0), 0, hz + 1.2), 0.16, null, Vector3.ZERO, true)


## 积水：整块地面上一层薄水（带焦散），头目半血时 flood() 让它涨起来
var water: MeshInstance3D


func _water_plane() -> void:
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x + 4.0, size.y + 4.0)
	water.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/water.gdshader")
	m.set_shader_parameter("caustic", load("res://assets/fx/lm_water_caustics_b.png"))
	# 积水只在低洼处：按 _floor_color 里同一个“湿”噪声画一张遮罩（0.25 米一格）
	var w := int((size.x + 4.0) / 0.25)
	var h := int((size.y + 4.0) / 0.25)
	var px := PackedByteArray()
	px.resize(w * h)
	var x0 := -(size.x + 4.0) * 0.5
	var z0 := -(size.y + 4.0) * 0.5
	for iz in range(h):
		for ix in range(w):
			var wet := noise.get_noise_2d((x0 + ix * 0.25) * 1.1 + 40.0, (z0 + iz * 0.25) * 1.1)
			px[iz * w + ix] = clampi(int((wet - 0.1) * 6.0 * 255.0), 0, 255)
	m.set_shader_parameter("mask", ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, px)))
	m.set_shader_parameter("rect", Vector4(x0, z0, size.x + 4.0, size.y + 4.0))
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("floor", true)
	add_child(water)
	water.position = Vector3(0, 0.015, 0)


## 水位上涨（井中人·枯荣半血）：水面变亮、焦散流快
func flood(on: bool) -> void:
	if water == null:
		return
	var m := water.material_override as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("level", v), 0.0 if on else 1.0, 1.0 if on else 0.0, 1.6)


## 经文石壁：一块竖石板，上面一行行刻痕（三种字样轮换），顶上一道檐
func _sutra_tablet(v: int) -> VoxelGrid:
	var g := VoxelGrid.new(100 + v)
	var stone := Color(0.24, 0.29, 0.33)
	g.box(Vector3i(0, 0, 0), Vector3i(17, 30, 2), stone, 0.08)
	g.box(Vector3i(-1, 31, -1), Vector3i(18, 32, 3), Color(0.15, 0.19, 0.22), 0.05)
	var r := RandomNumberGenerator.new()
	r.seed = 7 + v * 31
	for col in range(5):
		var x := 2 + col * 3
		var y := 27
		while y > 3:
			var l := r.randi_range(1, 3)
			if r.randf() < 0.75:
				for k in range(l):
					g.cells[Vector3i(x, y - k, 3)] = Color(0.35, 0.65, 0.8) * (0.7 + 0.3 * r.randf())
			y -= l + 1
	return g


## 石柱：方柱 + 底座 + 柱头，带一圈刻纹
func _well_pillar(c: Color = Color(0.22, 0.27, 0.31)) -> VoxelGrid:
	var g := VoxelGrid.new(120)
	g.box(Vector3i(-4, 0, -4), Vector3i(4, 2, 4), c * 0.8, 0.06)
	g.box(Vector3i(-3, 3, -3), Vector3i(3, 34, 3), c, 0.08)
	g.box(Vector3i(-4, 35, -4), Vector3i(4, 37, 4), c * 0.8, 0.06)
	for y: int in [10, 22]:
		g.box(Vector3i(-3, y, -3), Vector3i(3, y, 3), Color(0.3, 0.55, 0.65), 0.05)
	return g


## 灯链：一串交错的铁环从上往下垂，末端一盏熄掉的小灯
func _chain(n: int) -> VoxelGrid:
	var g := VoxelGrid.new(130 + n)
	var iron := Color(0.2, 0.22, 0.25)
	for i in range(n):
		var y := 40 - i * 2
		if i % 2 == 0:
			g.box(Vector3i(-1, y, 0), Vector3i(1, y + 1, 0), iron, 0.05)
		else:
			g.box(Vector3i(0, y, -1), Vector3i(0, y + 1, 1), iron * 1.2, 0.05)
	var yb := 40 - n * 2
	g.box(Vector3i(-2, yb - 3, -2), Vector3i(2, yb, 2), Color(0.25, 0.35, 0.4), 0.05)
	g.cells[Vector3i(0, yb - 2, 3)] = Color(0.4, 0.8, 1.0)
	return g


## 灰衣营：后面一道削尖的木栅（营门在中间），两侧营帐和旗；场地里篝火、兵器架、粮草、关人的木笼；
## 天上飘灰，靠镜头一排木桩剪影
func _dress_camp() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var kz := _kz()
	var ka := _ka()
	# 后墙：木栅（一根根削尖的原木），中间留营门，门两边两根旗杆
	var nst := int((hx - 1.0) / 1.6)
	for i in range(-nst, nst + 1):
		var x := i * 1.6
		if absf(x) < 2.0:
			continue
		voxel_piece(_cached("stake|%d" % (absi(i) % 3), _stake.bind(absi(i) % 3, Color(0.3, 0.22, 0.15))), Vector3(x, 0, -hz - 0.3), 0.12, null)
	for sx: float in [-1.0, 1.0]:
		kit("banner", Vector3(sx * 2.6, 0, -hz + 0.6), 0.0, 1.4, true)
		kit("torch", Vector3(sx * 4.0, 0, -hz + 0.8), 0.0, 1.2, false)
	# 两侧：营帐一排，帐前插旗
	for side: float in [-1.0, 1.0]:
		var nt := maxi(2, int(round(2.0 * kz)))
		for j in range(nt):
			var z := lerpf(-hz + 4.0, hz - 5.0, (j + 0.5) / float(nt))
			kit("tent", Vector3(side * (hx - 2.6), 0, z), side * PI * 0.5 + PI, 1.25, true)
			if j % 2 == 0:
				kit("banner", Vector3(side * (hx - 5.0), 0, z + 1.8), 0.0, 1.0, true)
	# 篝火：场地两三处，一圈石头 + 柴 + 火光
	var fires := [Vector3(-6.5 * kx, 0, -2.0 * kz), Vector3(6.0 * kx, 0, 3.5 * kz)]
	if ka > 1.5:
		fires.append(Vector3(-5.0 * kx, 0, 6.0 * kz))
	for fp: Vector3 in fires:
		voxel_piece(_cached("campfire", _campfire), fp, 0.1, null, Vector3(1.4, 1, 1.4))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 2.6
		l.omni_range = 8.0
		add_child(l)
		l.position = fp + Vector3(0, 1.0, 0)
		_flame(fp + Vector3(0, 0.3, 0))
		_flame(fp + Vector3(0.18, 0.25, 0.1))
		_flame(fp + Vector3(-0.15, 0.25, -0.1))
		_smoke_column(fp + Vector3(0, 1.2, 0))
		kit("bench", fp + Vector3(0, 0, 1.8), 0.0, 0.9, true)
	# 木笼（续命司抓来的人关在里面，空着门）
	var cages := [Vector3(8.0 * kx, 0, -4.5 * kz), Vector3(-9.5 * kx, 0, 2.5 * kz)]
	for cp: Vector3 in cages:
		voxel_piece(_cached("cage", _cage), cp, 0.12, null, Vector3(1.8, 2, 1.8))
	# 场地里：兵器架、粮草、木箱（障碍）
	var spots := [Vector3(3.0 * kx, 0, -5.5 * kz), Vector3(-2.8 * kx, 0, 4.5 * kz)]
	for i in range(int(round(3.0 * (ka - 1.0))) + 2):
		var p0 := _free_spot(4.5)
		if p0 != Vector3.INF:
			spots.append(p0)
	for s0: Vector3 in spots:
		var r := rng.randf()
		if r < 0.3:
			kit("sword_shield", s0, rng.randf_range(-0.4, 0.4), 1.2, true)
		elif r < 0.55:
			kit("crates", s0, rng.randf() * TAU, 1.0, true)
		elif r < 0.8:
			kit("barrel", s0, rng.randf() * TAU, 1.0, true)
		else:
			kit("lumber", s0, rng.randf() * TAU, 1.0, true)
	for i in range(int(6 * ka)):
		var p := Vector3(rng.randf_range(-hx + 3, hx - 3), 0, rng.randf_range(-hz + 3, hz - 3))
		if absf(p.x) > 2.2:
			kit(["sack", "barrel_small", "box", "lumber"][rng.randi() % 4], p, rng.randf() * TAU, 0.8, false)
	var tops := [Vector3(0, 4.5, -1.0), Vector3(-9 * kx, 4.5, 2.0 * kz), Vector3(9 * kx, 4.5, 2.0 * kz)]
	for p: Vector3 in tops:
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.8, 0.65)
		wl.light_energy = 1.5
		wl.omni_range = 12.0
		add_child(wl)
		wl.position = p
	_ash()
	# 前景：靠镜头一排木桩剪影
	for x0: float in _fg_xs():
		voxel_piece(_cached("stake_fg", _stake.bind(1, Color(0.05, 0.04, 0.03))), Vector3(x0 + rng.randf_range(-1.0, 1.0), 0, hz + 1.2), 0.16, null, Vector3.ZERO, true)


## 飘灰：灰白的小片慢慢往下落
func _ash() -> void:
	var pt := CPUParticles3D.new()
	pt.amount = mini(int(60 * _ka()), 120) / (2 if lod == 0 else 1)
	pt.lifetime = 8.0
	pt.preprocess = 8.0
	pt.mesh = _particle_quad(0.1)
	pt.material_override = _fx_mat("light_01", Color(0.75, 0.72, 0.7), true, 1.0)
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pt.emission_box_extents = Vector3(size.x * 0.5, 0.5, size.y * 0.5)
	pt.direction = Vector3(0.4, -0.3, 0.2)
	pt.spread = 30.0
	pt.initial_velocity_min = 0.2
	pt.initial_velocity_max = 0.5
	pt.gravity = Vector3(0.1, -0.2, 0.05)
	add_child(pt)
	pt.position = Vector3(0, 7.0, 0)


## 木栅的一根原木：上头削尖，三种高矮
func _stake(v: int, c: Color) -> VoxelGrid:
	var g := VoxelGrid.new(200 + v)
	var h := 26 + v * 4
	for x in range(0, 12):
		var lx := x % 4
		var top := h + (2 - absi(lx - 1)) * 2 + (x / 4) % 2 * 2
		for y in range(0, top):
			for z in range(0, 3):
				g.cells[Vector3i(x, y, z)] = c * (0.85 + 0.15 * float(lx == 1 or lx == 2)) * (0.9 + 0.1 * float((y / 5) % 2))
	g.box(Vector3i(0, 8, 3), Vector3i(11, 9, 3), c * 0.6, 0.05)
	g.box(Vector3i(0, h - 6, 3), Vector3i(11, h - 5, 3), c * 0.6, 0.05)
	return g


## 篝火：一圈石头，中间交叉的柴
func _campfire() -> VoxelGrid:
	var g := VoxelGrid.new(210)
	for a in range(10):
		var d := Vector2(cos(a * TAU / 10.0), sin(a * TAU / 10.0)) * 5.5
		g.box(Vector3i(int(d.x) - 1, 0, int(d.y) - 1), Vector3i(int(d.x) + 1, 1, int(d.y) + 1), Color(0.35, 0.33, 0.32), 0.1)
	for k in range(-4, 5):
		g.cells[Vector3i(k, 1, k)] = Color(0.25, 0.16, 0.1)
		g.cells[Vector3i(k, 1, -k)] = Color(0.22, 0.14, 0.09)
	g.box(Vector3i(-2, 0, -2), Vector3i(2, 0, 2), Color(0.15, 0.1, 0.08), 0.0)
	return g


## 木笼：方框 + 竖栏，门开着
func _cage() -> VoxelGrid:
	var g := VoxelGrid.new(220)
	var w := Color(0.28, 0.2, 0.13)
	g.box(Vector3i(-7, 0, -7), Vector3i(7, 0, 7), w * 0.8, 0.05)
	g.box(Vector3i(-7, 17, -7), Vector3i(7, 17, 7), w * 0.8, 0.05)
	for i in range(-7, 8, 2):
		for y in range(1, 17):
			g.cells[Vector3i(i, y, -7)] = w
			g.cells[Vector3i(-7, y, i)] = w
			g.cells[Vector3i(7, y, i)] = w
			if i < -1 or i > 3:
				g.cells[Vector3i(i, y, 7)] = w
	for y in range(1, 17):
		g.cells[Vector3i(5, y, 9)] = w * 0.9   # 推开的门
	return g


## 熔铜沟：0 不在沟里，0~1 越靠沟中间越亮（柱廊两侧各一道竖沟，后半截一道横沟连起来）
func _vault_channel(x: float, z: float) -> float:
	var cx := 5.0 * _kx()
	var w := 0.32
	var d := absf(absf(x) - cx)
	var best := 0.0
	if d < w and z > -size.y * 0.5 + 2.5 and z < size.y * 0.5 - 3.5:
		best = 1.0 - d / w
	var dz := absf(z + size.y * 0.5 - 4.0)
	if dz < w and absf(x) <= cx:
		best = maxf(best, 1.0 - dz / w)
	return best


## 烛国灯冢：后墙一排七盏灯龛（只亮着几盏），两侧铜灯架和熔炉，柱廊里站着成排的铜甲士像；
## 地上两道熔铜沟，头目半血 ignite() 时沟里的铜水烧起来
var lava: MeshInstance3D
var _lava_lights: Array[OmniLight3D] = []


func _dress_vault() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var kx := _kx()
	var kz := _kz()
	var ka := _ka()
	# 后墙：灯龛（青铜壁上一格格凹进去，每格一盏铜灯，七格里亮三四格）
	var nt := int((hx - 1.0) / 2.6)
	for i in range(-nt, nt + 1):
		var x := i * 2.6
		if absf(x) < 2.2:
			continue
		var lit := (absi(i) + rng.randi()) % 3 != 0
		var ni: Array = _cached("niche|%d" % int(lit), _lamp_niche.bind(lit))
		voxel_piece(ni[0], Vector3(x - 1.1, 0, -hz - 0.3), 0.12, ni[1])
		if lit and absi(i) % 2 == 1:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.3)
			l.light_energy = 1.6
			l.omni_range = 5.5
			add_child(l)
			l.position = Vector3(x, 2.2, -hz + 0.6)
	# 两侧：铜灯架一排（高脚灯盏，点着火）
	for side: float in [-1.0, 1.0]:
		var np := maxi(3, int(round(3.0 * kz)))
		for j in range(np):
			var z := -hz + 3.0 + j * (size.y - 6.0) / float(np - 1)
			var p := Vector3(side * (hx - 1.3), 0, z)
			var ls: Array = _cached("lampstand", _lamp_stand)
			voxel_piece(ls[0], p, 0.12, ls[1], Vector3(0.8, 3, 0.8))
			if j % 2 == 0:
				var fl := OmniLight3D.new()
				fl.light_color = Color(1.0, 0.62, 0.3)
				fl.light_energy = 1.8
				fl.omni_range = 6.5
				add_child(fl)
				fl.position = p + Vector3(-side * 0.4, 2.6, 0)
				_flame(p + Vector3(0, 2.45, 0))
	# 柱廊：熔铜沟外侧一排铜甲士像（站岗的样子，烛国的兵），中间留出打架的场地
	var cx := 5.0 * kx
	for sx: float in [-1.0, 1.0]:
		var ns := maxi(2, int(round(2.0 * kz)))
		for j in range(ns):
			var z := lerpf(-hz + 4.5, hz - 5.5, (j + 0.5) / float(ns))
			_bronze_statue(Vector3(sx * (cx + 2.2), 0, z), -sx * 0.25)
	# 熔炉：左右后角各一座，冒着烟和火星
	for sx: float in [-1.0, 1.0]:
		var fp := Vector3(sx * (hx - 4.5), 0, -hz + 2.2)
		var fu: Array = _cached("furnace", _furnace)
		voxel_piece(fu[0], fp, 0.12, fu[1], Vector3(2.2, 2, 1.8))
		var fl2 := OmniLight3D.new()
		fl2.light_color = Color(1.0, 0.5, 0.2)
		fl2.light_energy = 2.4
		fl2.omni_range = 7.0
		add_child(fl2)
		fl2.position = fp + Vector3(0, 1.0, 1.2)
		_smoke_column(fp + Vector3(0, 2.6, 0))
		_flame(fp + Vector3(0, 0.6, 1.0))
	# 场地里：倒下的灯架、铜箱、碎陶俑（障碍）
	var spots := [Vector3(-2.5 * kx, 0, -5.0 * kz), Vector3(2.8 * kx, 0, 4.0 * kz)]
	for i in range(int(round(3.0 * (ka - 1.0))) + 2):
		var fp := _free_spot(4.5)
		if fp != Vector3.INF:
			spots.append(fp)
	for s0: Vector3 in spots:
		var r := rng.randf()
		if r < 0.3:
			kit("crates", s0, rng.randf() * TAU, 1.0, true)
		elif r < 0.55:
			kit("rubble", s0, rng.randf() * TAU, 1.1, true)
		elif r < 0.8:
			kit("coffin", s0, rng.randf_range(-0.3, 0.3), 1.0, true)
		else:
			kit("column", s0, 0.0, 1.5, true)
	for i in range(int(6 * ka)):
		var p := Vector3(rng.randf_range(-hx + 3, hx - 3), 0, rng.randf_range(-hz + 3, hz - 3))
		if absf(absf(p.x) - cx) > 1.0 and absf(p.x) > 2.5:
			kit(["candles", "skull_candle", "barrel_small", "rubble", "sack"][rng.randi() % 5], p, rng.randf() * TAU, 0.8, false)
	# 熔铜沟上方的一串暖光（ignite 时一起变亮），顶上几盏大灯把地照亮
	var nl := maxi(3, int(round(3.0 * kz)))
	for sx: float in [-1.0, 1.0]:
		for j in range(nl):
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.5, 0.18)
			l.light_energy = 0.7
			l.omni_range = 4.5
			add_child(l)
			l.position = Vector3(sx * cx, 0.6, lerpf(-hz + 3.0, hz - 4.0, j / float(nl - 1)))
			_lava_lights.append(l)
	var tops := [Vector3(0, 4.0, -1.0), Vector3(-9 * kx, 4.0, 2.0 * kz), Vector3(9 * kx, 4.0, 2.0 * kz)]
	for p: Vector3 in tops:
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.78, 0.55)
		wl.light_energy = 1.7
		wl.omni_range = 12.0
		add_child(wl)
		wl.position = p
	_lava_plane()
	_embers()
	# 前景：靠镜头的铜灯架剪影
	for x0: float in _fg_xs():
		var ls2: Array = _cached("lampstand_fg", _lamp_stand.bind(Color(0.07, 0.05, 0.03)))
		voxel_piece(ls2[0], Vector3(x0 + rng.randf_range(-1.0, 1.0), 0, hz + 1.2), 0.18, null, Vector3.ZERO, true)


## 铜水：熔铜沟上一层流动的亮橙色（借积水的焦散 shader，换成橙色）
func _lava_plane() -> void:
	lava = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x + 4.0, size.y + 4.0)
	lava.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/water.gdshader")
	m.set_shader_parameter("caustic", load("res://assets/fx/lm_water_caustics_b.png"))
	m.set_shader_parameter("tint", Color(0.9, 0.35, 0.08, 0.35))
	m.set_shader_parameter("glint", Color(1.0, 0.85, 0.4))
	m.set_shader_parameter("scale", 0.6)
	m.set_shader_parameter("spread", 0.12)
	var w := int((size.x + 4.0) / 0.2)
	var h := int((size.y + 4.0) / 0.2)
	var px := PackedByteArray()
	px.resize(w * h)
	var x0 := -(size.x + 4.0) * 0.5
	var z0 := -(size.y + 4.0) * 0.5
	for iz in range(h):
		for ix in range(w):
			px[iz * w + ix] = clampi(int(_vault_channel(x0 + ix * 0.2, z0 + iz * 0.2) * 1.6 * 255.0), 0, 255)
	m.set_shader_parameter("mask", ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, px)))
	m.set_shader_parameter("rect", Vector4(x0, z0, size.x + 4.0, size.y + 4.0))
	lava.material_override = m
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lava.set_meta("floor", true)
	add_child(lava)
	lava.position = Vector3(0, 0.02, 0)


## 火星：满屋子往上飘的橙色小亮点
func _embers() -> void:
	var pt := CPUParticles3D.new()
	pt.amount = mini(int(50 * _ka()), 110) / (2 if lod == 0 else 1)
	pt.lifetime = 5.0
	pt.preprocess = 5.0
	pt.mesh = _particle_quad(0.08)
	pt.material_override = _fx_mat("light_01", Color(1.0, 0.55, 0.2), true, 2.2)
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pt.emission_box_extents = Vector3(size.x * 0.5, 0.3, size.y * 0.5)
	pt.direction = Vector3(0.1, 1, 0)
	pt.spread = 25.0
	pt.initial_velocity_min = 0.3
	pt.initial_velocity_max = 0.8
	pt.gravity = Vector3(0.1, 0.15, 0)
	add_child(pt)
	pt.position = Vector3(0, 0.3, 0)


## 灯冢点火（不夜将军半血）：铜水沟烧起来，沟上的光变亮，墙边灯架窜起火苗
func ignite() -> void:
	if lava != null:
		var m := lava.material_override as ShaderMaterial
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("level", v), 0.0, 1.0, 1.4)
	for l: OmniLight3D in _lava_lights:
		var tw2 := create_tween()
		tw2.tween_property(l, "light_energy", 2.6, 1.4)
		tw2.parallel().tween_property(l, "omni_range", 7.0, 1.4)
	var hz := size.y * 0.5
	var cx := 5.0 * _kx()
	for sx: float in [-1.0, 1.0]:
		for j in range(4):
			spirit_fire(Vector3(sx * cx, 0.1, lerpf(-hz + 3.0, hz - 4.0, j / 3.0)), Color(1.0, 0.55, 0.2), 1.3, 0.0, 0.1)


## 灯龛：一格青铜壁，中间凹进去放一盏灯；返回 [铜壁, 发光的灯火]
func _lamp_niche(lit: bool) -> Array:
	var g := VoxelGrid.new(160 + int(lit))
	var glow := VoxelGrid.new(162)
	var bronze := Color(0.36, 0.25, 0.14)
	g.box(Vector3i(0, 0, 0), Vector3i(18, 30, 2), bronze, 0.08)
	# 凹进去的龛（挖空成深色）
	for x in range(5, 14):
		for y in range(12, 24):
			g.cells[Vector3i(x, y, 2)] = Color(0.08, 0.05, 0.04)
	g.box(Vector3i(4, 11, 2), Vector3i(14, 11, 4), bronze * 1.3, 0.05)
	g.box(Vector3i(-1, 31, -1), Vector3i(19, 32, 3), bronze * 0.7, 0.05)
	g.box(Vector3i(0, 3, 3), Vector3i(18, 3, 3), Color(0.55, 0.4, 0.2), 0.04)
	# 灯盏：小铜碗
	g.box(Vector3i(7, 12, 3), Vector3i(11, 13, 5), Color(0.6, 0.42, 0.2), 0.05)
	if lit:
		glow.box(Vector3i(8, 14, 4), Vector3i(10, 16, 4), Color(1.0, 0.7, 0.3), 0.0)
		glow.cells[Vector3i(9, 17, 4)] = Color(1.0, 0.85, 0.5)
	return [g, glow]


## 高脚铜灯架：三足底座 + 细长杆 + 顶上大灯盏（发光的火）
func _lamp_stand(c: Color = Color(0.45, 0.31, 0.16)) -> Array:
	var g := VoxelGrid.new(170)
	var glow := VoxelGrid.new(171)
	for a in range(3):
		var d := Vector2(cos(a * TAU / 3.0), sin(a * TAU / 3.0))
		for k in range(4):
			g.cells[Vector3i(int(round(d.x * k)), maxi(0, 1 - k / 2), int(round(d.y * k)))] = c * 0.8
	g.box(Vector3i(-1, 1, -1), Vector3i(1, 2, 1), c, 0.05)
	g.box(Vector3i(0, 3, 0), Vector3i(0, 18, 0), c, 0.05)
	g.box(Vector3i(-1, 10, -1), Vector3i(1, 10, 1), c * 1.2, 0.03)
	g.box(Vector3i(-3, 19, -3), Vector3i(3, 19, 3), c, 0.05)
	g.box(Vector3i(-3, 20, -3), Vector3i(3, 20, 3), c * 1.15, 0.05)
	for x in range(-2, 3):
		for z in range(-2, 3):
			g.cells.erase(Vector3i(x, 20, z))
			if c.r > 0.2:
				glow.cells[Vector3i(x, 20, z)] = Color(1.0, 0.6, 0.25)
	if c.r > 0.2:
		glow.box(Vector3i(-1, 21, -1), Vector3i(1, 21, 1), Color(1.0, 0.75, 0.35), 0.0)
	return [g, glow]


## 熔炉：方形铜炉，正面炉口发着橙光
func _furnace() -> Array:
	var g := VoxelGrid.new(180)
	var glow := VoxelGrid.new(181)
	var b := Color(0.3, 0.21, 0.13)
	g.box(Vector3i(-9, 0, -7), Vector3i(9, 14, 7), b, 0.08)
	g.box(Vector3i(-10, 15, -8), Vector3i(10, 16, 8), b * 0.75, 0.05)
	g.box(Vector3i(-3, 17, -3), Vector3i(3, 22, 3), b * 0.9, 0.05)
	for x in range(-5, 6):
		for y in range(2, 8):
			g.cells.erase(Vector3i(x, y, 7))
			glow.cells[Vector3i(x, y, 7)] = Color(1.0, 0.5, 0.15).lerp(Color(1.0, 0.8, 0.4), float(y - 2) / 6.0)
	return [g, glow]


## 铜甲士像：一具骑士模型染成铜色，立在方台上，拄着剑
func _bronze_statue(p: Vector3, yaw: float) -> void:
	var base := VoxelGrid.new(190)
	base.box(Vector3i(-5, 0, -5), Vector3i(5, 3, 5), Color(0.24, 0.18, 0.13), 0.06)
	voxel_piece(base, p, 0.12, null, Vector3(1.3, 3, 1.3))
	var a := VoxActor.new()
	add_child(a)
	a.position = p + Vector3(0, 0.45, 0)
	a.rotation.y = yaw
	a.setup("knight", "sword", 36.0, Color(1.25, 0.85, 0.48), 1.15)
	a.mat.set_shader_parameter("mono", 1.0)
	a.apply(Poses.idle(0.0))
	a.set_rim(Color(1.0, 0.7, 0.35), 0.35)


## 前景剪影的 x 位置：左右两侧各一棵，房间宽了中间再加
func _fg_xs() -> Array[float]:
	var hx := size.x * 0.5
	var xs: Array[float] = [-(hx - 3.0), hx - 3.0]
	if size.x >= 40.0:
		xs.append_array([-hx * 0.35, hx * 0.35])
	return xs


# ---------- 氛围 ----------

func _shaft(pos: Vector3, c: Color, w: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, 9.0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/lm_cone_a_blur.png"))
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("energy", 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos + Vector3(0, 4.0, 0)
	mi.rotation = Vector3(0, 0, 0.35)


func _smoke_column(p: Vector3) -> void:
	var sm := CPUParticles3D.new()
	sm.amount = 14
	sm.lifetime = 3.5
	sm.mesh = _particle_quad(0.6)
	sm.material_override = _fx_mat("smoke_04", Color(0.7, 0.8, 0.85, 0.18), false)
	sm.direction = Vector3.UP
	sm.spread = 8.0
	sm.initial_velocity_min = 0.3
	sm.initial_velocity_max = 0.5
	sm.gravity = Vector3(0.1, 0.1, 0)
	sm.scale_amount_min = 1.0
	sm.scale_amount_max = 2.5
	add_child(sm)
	sm.position = p


func _petals() -> void:
	var pt := CPUParticles3D.new()
	pt.amount = mini(int(90 * _ka()), 180) / (2 if lod == 0 else 1)
	pt.lifetime = 7.0
	pt.preprocess = 7.0
	pt.mesh = _particle_quad(0.14)
	pt.material_override = _fx_mat("light_01", Color(1.0, 0.6, 0.78), true, 1.6)
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pt.emission_box_extents = Vector3(size.x * 0.5, 0.5, size.y * 0.5)
	pt.direction = Vector3(1, -0.3, 0.3)
	pt.spread = 30.0
	pt.initial_velocity_min = 0.3
	pt.initial_velocity_max = 0.9
	pt.gravity = Vector3(0.2, -0.35, 0.1)
	add_child(pt)
	pt.position = Vector3(0, 7.0, 0)


func _atmosphere() -> void:
	var info: Dictionary = zone_info()
	# 漂浮孢子 / 光尘
	var sp := CPUParticles3D.new()
	sp.amount = mini(int(140 * _ka()), 280) / (2 if lod == 0 else 1)
	sp.lifetime = 8.0
	sp.preprocess = 8.0
	sp.mesh = _particle_quad(0.09)
	sp.material_override = _fx_mat("light_01", info["spore"], true, 3.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(size.x * 0.5, 1.6, size.y * 0.5)
	sp.direction = Vector3.UP
	sp.spread = 180.0
	sp.initial_velocity_min = 0.05
	sp.initial_velocity_max = 0.25
	sp.gravity = Vector3(0, 0.05, 0)
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 1.6
	add_child(sp)
	sp.position = Vector3(0, 1.8, 0)
	# 贴地雾片：几层慢慢飘的雾，挡一点地面，让画面有层次
	for i in range(mini(int(14 * _ka()), 28) / (2 if lod == 0 else 1)):
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(8, 14), rng.randf_range(3, 5))
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/arpg/fx_mix.gdshader")
		m.set_shader_parameter("tex", load("res://assets/fx/fog01.png"))
		var fc: Color = info["fog"]
		m.set_shader_parameter("color", Color(fc.r * 1.6, fc.g * 1.6, fc.b * 1.6, 0.16))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = Vector3(rng.randf_range(-size.x * 0.5, size.x * 0.5), rng.randf_range(0.3, 1.2), rng.randf_range(-size.y * 0.5, size.y * 0.5))
		mi.rotation = Vector3(-PI / 2 + 0.25, rng.randf() * 0.4 - 0.2, 0)
		var drift := FogDrift.new()
		drift.speed = rng.randf_range(0.15, 0.35) * (1.0 if rng.randf() < 0.5 else -1.0)
		drift.span = size.x * 0.6
		mi.add_child(drift)
	# 大房间：靠镜头这半边离灯远，补几盏不显眼的补光（区域氛围色），免得入口一片黑
	if _ka() > 1.5:
		for p: Vector3 in [Vector3(0, 3.5, size.y * 0.5 - 4.0), Vector3(-size.x * 0.3, 3.5, size.y * 0.2), Vector3(size.x * 0.3, 3.5, size.y * 0.2)]:
			var fl := OmniLight3D.new()
			fl.light_color = info["spore"]
			fl.light_energy = 0.9
			fl.omni_range = 11.0
			fl.omni_attenuation = 1.2
			add_child(fl)
			fl.position = p
	if zone == "forest":
		for i in range(int(round(4.0 * sqrt(_ka())))):
			_shaft(Vector3(rng.randf_range(-size.x * 0.4, size.x * 0.4), 0, rng.randf_range(-size.y * 0.4, size.y * 0.2)), Color(0.5, 1.0, 0.9, 0.09), rng.randf_range(1.5, 2.5))


func _make_spawns() -> void:
	spawn_points.clear()
	var tries := 0
	var want := int(24 * _ka())
	while spawn_points.size() < want and tries < 800:
		tries += 1
		var p := Vector3(rng.randf_range(-size.x * 0.5 + 2.0, size.x * 0.5 - 2.0), 0, rng.randf_range(-size.y * 0.5 + 2.0, size.y * 0.5 - 4.0))
		if p.distance_to(entry_pos) < 7.0:
			continue
		var ok := true
		# 离障碍物至少留 1.2 米：刷怪时还会再随手偏 0.6 米，贴着墙刷容易卡进去（敌人没有寻路，卡住就出不来）
		for r: Rect2 in _solid:
			if r.grow(1.2).has_point(Vector2(p.x, p.z)):
				ok = false
				break
		if ok:
			spawn_points.append(p)


## 前景遮挡：挡在镜头和主角之间的物体变半透明
func update_occluders(cam: Camera3D, targets: Array) -> void:
	for o: Array in occluders:
		var node: Node3D = o[0]
		var aabb: AABB = o[2]
		var blocking := false
		for t: Node3D in targets:
			if not is_instance_valid(t):
				continue
			var from := cam.global_position
			var to := t.global_position + Vector3(0, 1.0, 0)
			if aabb.grow(0.4).intersects_segment(from, to):
				blocking = true
				break
		var want := 0.06 if blocking else 1.0
		var cur: float = node.get_meta("fade", 1.0)
		cur = move_toward(cur, want, 0.08)
		node.set_meta("fade", cur)
		for m: ShaderMaterial in o[1]:
			m.set_shader_parameter("fade", cur)
