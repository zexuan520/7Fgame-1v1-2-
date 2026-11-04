class_name VoxelView
extends Node3D
## 体素显示层：和 2D 游戏画在同一个 SubViewport 里，3D 在下面，2D 的特效、文字、机关叠在上面。
## 玩法完全不动：2D 的坐标 (x, y) 对应 3D 的 (x, -y, 0)，镜头是透视的，
## 放在 z = CAM_D 处、视野正好让 z = 0 这一层和 2D 画面一一对齐，所以判定框、特效的位置不会错开。
## 远近景放在 z 更小的地方，靠透视产生真正的纵深和视差。
##
## 开关：Game.voxel（F6 切换），关掉就回到原来的 2D 画面。

const CAM_D := 600.0
const FLOOR_Y := 300.0
const GROUND_S := 8.0                 # 地面一格 = 8 像素
const GROUND_Z0 := -280.0             # 地面从这里铺到镜头前
const GROUND_Z1 := 48.0
const DEBRIS_MAX := 160

var main: Node                        # Main
var camera: Camera3D
var env: Environment
var sun: DirectionalLight3D
var room: Node3D                      # 当前房间的地面、摆设、远近景（换房间整个删掉）
var rigs := {}                        # Fighter → VoxelRig
var _debris: Array = []               # [MeshInstance3D, 速度, 剩余时间, 自转]
var _debris_mesh: BoxMesh
var _debris_mats := {}
var last_build_ms := 0

static var _room_cache := {}          # 房间名 → {摆设名: 网格}（同一间房再进来不用重算）


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = rad_to_deg(2.0 * atan(180.0 / CAM_D))
	camera.near = 4.0
	camera.far = 4000.0
	camera.position = Vector3(320, -180, CAM_D)
	add_child(camera)
	camera.current = true

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2a2248")
	sm.sky_horizon_color = Color("b8644a")
	sm.ground_horizon_color = Color("7a4a42")
	sm.ground_bottom_color = Color("2a2030")
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a6a9e")
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color("5e4a7a")
	env.fog_density = 0.0004
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.76, 0.56)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 1400.0
	sun.shadow_bias = 0.05
	add_child(sun)
	# 夕阳从左后上方斜照过来，角色正面带一点暖光
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.6, -0.5), Vector3.UP)
	# 冷色的逆光：给人物和房子右侧、顶上勾一道蓝紫边，和暖色的背景分开
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.62, 1.0)
	rim.light_energy = 0.7
	add_child(rim)
	rim.look_at_from_position(Vector3.ZERO, Vector3(-0.75, -0.35, 0.55), Vector3.UP)

	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3.ONE * 2.4


# ---------- 房间 ----------

func build_room(def: Dictionary) -> void:
	if room != null:
		room.queue_free()
	for f in rigs.keys():
		(rigs[f] as Node).queue_free()
	rigs.clear()
	for d: Array in _debris:
		(d[0] as Node).queue_free()
	_debris.clear()
	room = Node3D.new()
	add_child(room)
	var name_key := "%s|%s|%s" % [def.get("name", ""), def.get("seed", 0), def.get("width", 0)]
	var cache: Dictionary = _room_cache.get(name_key, {})
	_room_cache[name_key] = cache
	var w := float(def.get("width", 800.0))
	var t0 := Time.get_ticks_msec()
	_build_ground(def, w, cache)
	_build_props(def, cache)
	_build_scenery(def, w, cache)
	if OS.is_debug_build():
		print_verbose("体素房间 %s 搭好，用时 %d 毫秒" % [name_key, Time.get_ticks_msec() - t0])
	last_build_ms = Time.get_ticks_msec() - t0


func _mi(mesh: Mesh, pos: Vector3, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)
	return mi


func _light(pos: Vector3, col: Color, rng_px: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = 1.6
	l.omni_range = rng_px
	l.omni_attenuation = 1.4
	room.add_child(l)


## 地面：被坑切成几段；最前面一排往下多铺几层，挡住画面底部
func _build_ground(def: Dictionary, w: float, cache: Dictionary) -> void:
	if not cache.has("ground"):
		var g := VoxelGrid.new(int(def.get("seed", 0)) + 100)
		var noise := FastNoiseLite.new()
		noise.seed = int(def.get("seed", 0))
		noise.frequency = 0.08
		var dirt := Color("6e5a44")
		var grass := Color("5f6a3a")
		var path := Color("8a7458")
		var z0 := int(GROUND_Z0 / GROUND_S)
		var z1 := int(GROUND_Z1 / GROUND_S)
		for sp: Array in RoomFeatures.ground_spans(def.get("features", []), w):
			var xa := int(floorf(float(sp[0]) / GROUND_S))
			var xb := int(ceilf(float(sp[1]) / GROUND_S)) - 1
			if sp[0] <= -99.0:
				xa = int(-400.0 / GROUND_S)
			if sp[1] >= w + 99.0:
				xb = int((w + 400.0) / GROUND_S)
			for x in range(xa, xb + 1):
				for z in range(z0, z1 + 1):
					var n := noise.get_noise_2d(x, z)
					var c := grass.lerp(dirt, clampf(n + 0.4, 0.0, 1.0))
					if z >= -3 and z <= 1:          # 角色走的那条土路
						c = path.darkened(absf(n) * 0.25)
					c = c.darkened(g.rng.randf() * 0.1)
					g.set_v(Vector3i(x, -1, z), c)
					if z == z1:
						for y in range(-8, -1):
							g.set_v(Vector3i(x, y, z), dirt.darkened(0.25 + g.rng.randf() * 0.1))
					elif n > 0.35 and g.rng.randf() < 0.25 and (z < -4 or z > 2):   # 草丛冒出地面
						g.set_v(Vector3i(x, 0, z), grass.lightened(0.1))
			# 坑边：露出土层
			for x in [xa, xb]:
				for z in range(z0, z1 + 1):
					for y in range(-8, -1):
						g.set_v(Vector3i(x, y, z), dirt.darkened(0.3))
		cache["ground"] = g.build(GROUND_S)
	_mi(cache["ground"], Vector3(0, -FLOOR_Y, 0), false)


func _build_props(def: Dictionary, cache: Dictionary) -> void:
	var i := 0
	for pr: Array in def.get("props", []):
		var kind := String(pr[0])
		var x := float(pr[1])
		var base := float(pr[2]) if pr.size() > 2 else 0.0
		var key := "prop|" + kind
		if not cache.has(key):
			var d := VoxelProps.build(kind, 7 + i)
			if d.is_empty():
				cache[key] = null
			else:
				var glow: VoxelGrid = d["glow"]
				cache[key] = {"mesh": (d["grid"] as VoxelGrid).build(VoxelProps.ES),
					"glow": glow.build(VoxelProps.ES, Vector3.ZERO, true) if glow != null else null,
					"lights": d["lights"]}
		var c: Variant = cache[key]
		i += 1
		if c == null:
			continue
		var at := Vector3(x, -(FLOOR_Y - base), 0.0)
		_mi(c["mesh"], at)
		if c["glow"] != null:
			_mi(c["glow"], at, false)
		for l: Array in c["lights"]:
			_light(at + (l[0] as Vector3), l[1], l[2])


## 远近景：中景茅草屋和树，远处一排山，最前面零星的草
func _build_scenery(def: Dictionary, w: float, cache: Dictionary) -> void:
	var seed_value := int(def.get("seed", 0))
	if not cache.has("scenery"):
		var items := []
		var r := RandomNumberGenerator.new()
		r.seed = seed_value * 31 + 7
		var x := -300.0
		var k := 0
		while x < w + 300.0:
			x += r.randf_range(110.0, 220.0)
			var z := r.randf_range(-230.0, -150.0)
			if r.randf() < 0.55:
				var hd := VoxelProps.bg_house(seed_value * 100 + k, r.randf() < 0.5)
				var glow: VoxelGrid = hd[1]
				items.append({"mesh": (hd[0] as VoxelGrid).build(6.0), "pos": Vector3(x, -FLOOR_Y, z),
					"glow": glow.build(6.0, Vector3.ZERO, true) if glow != null else null})
			else:
				items.append({"mesh": VoxelProps.bg_tree(seed_value * 100 + k).build(6.0), "pos": Vector3(x, -FLOOR_Y, z), "glow": null})
			if r.randf() < 0.6:   # 再往后一排树
				items.append({"mesh": VoxelProps.bg_tree(seed_value * 100 + k + 50).build(8.0),
					"pos": Vector3(x + r.randf_range(-60, 60), -FLOOR_Y, r.randf_range(-420.0, -320.0)), "glow": null})
			k += 1
		cache["scenery"] = items
		cache["mountains"] = VoxelProps.mountains(w + 2400.0, seed_value, Color("3e3256"), 0.8).build(20.0)
		cache["mountains2"] = VoxelProps.mountains(w + 3600.0, seed_value + 9, Color("5a4266"), 1.0).build(36.0)
		cache["sun"] = VoxelProps.sun_disc().build(30.0, Vector3.ZERO, true)
	for it: Dictionary in cache["scenery"]:
		_mi(it["mesh"], it["pos"])
		if it["glow"] != null:
			_mi(it["glow"], it["pos"], false)
	_mi(cache["mountains"], Vector3(-1200.0, -FLOOR_Y - 40.0, -900.0), false)
	_mi(cache["mountains2"], Vector3(-1600.0, -FLOOR_Y - 60.0, -1700.0), false)
	_mi(cache["sun"], Vector3(w * 0.25, -FLOOR_Y + 260.0, -2600.0), false)


# ---------- 每帧 ----------

func sync(dt: float) -> void:
	# 镜头跟 2D 镜头对齐（震屏、拉近都带上）
	var c2: Camera2D = main.camera
	var center := c2.get_screen_center_position()
	var zoom := c2.zoom.x
	camera.position = Vector3(center.x, -center.y, CAM_D / zoom)
	# 角色：新出现的建体素人偶，没了的删掉
	var alive := {}
	for p in main.players:
		alive[p] = true
	for e in main.enemies:
		if is_instance_valid(e) and String(e.kind) != "dog":
			alive[e] = true
	for f in rigs.keys():
		if not alive.has(f) or not is_instance_valid(f):
			(rigs[f] as Node).queue_free()
			rigs.erase(f)
	for f in alive.keys():
		if not rigs.has(f):
			var rig := VoxelRig.new()
			add_child(rig)
			rig.setup(f)
			rigs[f] = rig
		(rigs[f] as VoxelRig).sync(dt)
		if f.get("body") != null:
			(f.body as Sprite2D).visible = false
	_update_debris(dt)


## 命中溅出的小方块：往刀的方向飞，落地弹两下，慢慢缩没
func spawn_debris(pos: Vector2, dir: float, count: int, colors: Array) -> void:
	for i in range(count):
		if _debris.size() >= DEBRIS_MAX:
			var old: Array = _debris.pop_front()
			(old[0] as Node).queue_free()
		var mi := MeshInstance3D.new()
		mi.mesh = _debris_mesh
		var col: Color = colors[randi() % colors.size()]
		var key := col.to_html()
		if not _debris_mats.has(key):
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			m.roughness = 1.0
			if col.v > 0.85:
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_debris_mats[key] = m
		mi.material_override = _debris_mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(pos.x, -pos.y, randf_range(-6.0, 10.0))
		mi.scale = Vector3.ONE * randf_range(0.6, 1.4)
		add_child(mi)
		var sx := (dir if dir != 0.0 else (1.0 if randf() < 0.5 else -1.0)) * randf_range(60.0, 220.0)
		var vel := Vector3(sx, randf_range(60.0, 240.0), randf_range(-80.0, 120.0))
		var spin := Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		_debris.append([mi, vel, randf_range(0.8, 1.4), spin])


func _update_debris(dt: float) -> void:
	var keep: Array = []
	for d: Array in _debris:
		var mi: MeshInstance3D = d[0]
		var vel: Vector3 = d[1]
		d[2] = float(d[2]) - dt
		if d[2] <= 0.0:
			mi.queue_free()
			continue
		vel.y -= 700.0 * dt
		mi.position += vel * dt
		if mi.position.y < -FLOOR_Y + 1.2 and vel.y < 0.0:
			mi.position.y = -FLOOR_Y + 1.2
			vel = Vector3(vel.x * 0.5, -vel.y * 0.35, vel.z * 0.5)
			d[3] = (d[3] as Vector3) * 0.5
		mi.rotation += (d[3] as Vector3) * dt
		if d[2] < 0.3:
			mi.scale = Vector3.ONE * maxf(float(d[2]) / 0.3, 0.05)
		d[1] = vel
		keep.append(d)
	_debris = keep
