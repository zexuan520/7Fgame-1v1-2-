class_name SideRoom
extends Node3D
## 侧室：主房间左墙或右墙开一道拱门，门外接一间小屋。每间房各有各的（一到两间），每层名字和摆设不同：
##   藏宝（宝箱、散落的铜钱）/ 伏兵（进门就关门刷一群怪，打完开箱）/ 灵泉（回血、补一口药）/
##   遗骸（一段旧事，给魂玉；古寺的藏经阁还给一个心法）/ 小试炼（限时斩尽，成了给心法和魂玉）
## 有战斗的房间清场后门才开；商人、土地庙这类房间一进来门就开着。挂在 Arena 下面，换房间时跟着一起清掉。

const KINDS := ["cache", "ambush", "spring", "lore", "trial"]
const WEIGHTS := [20, 28, 14, 20, 18]
## 每层一套名字：[名字, 门上小字]
const NAMES := {
	"forest": {"cache": ["猎户木屋", "门没锁"], "ambush": ["藤下伏兵", "里面有动静"], "spring": ["林间灵泉", "水声"],
		"lore": ["樵夫遗骸", "一股旧味"], "trial": ["试剑石", "石上有剑痕"]},
	"grave": {"cache": ["陪葬室", "没人动过"], "ambush": ["尸窟", "骨头在响"], "spring": ["守墓人的井", "井水还清"],
		"lore": ["守墓人骨室", "墙上刻着字"], "trial": ["魂灯阵", "七盏灯"]},
	"temple": {"cache": ["香积库", "香火味"], "ambush": ["罗汉堂", "有人在等"], "spring": ["禅房", "很静"],
		"lore": ["藏经阁", "满架经卷"], "trial": ["铜铃阵", "铃在自己响"]},
	"well": {"cache": ["沉经库", "水底有光"], "ambush": ["水牢", "铁链在晃"], "spring": ["青泉", "水是温的"],
		"lore": ["刻经僧遗骸", "满墙刻字"], "trial": ["链阵", "七根灯链"]},
}
## 遗骸 / 骨室 / 藏经阁里读到的旧事（每层几段，随机一段）
const LORE := {
	"forest": [
		[["", "木门后面是个塌了一半的樵屋。墙角坐着一具白骨，怀里还抱着斧头。"], ["樵夫的刻痕", "“山上的樱花今年开了两次。第二次开的时候，剑鬼就来了。”"]],
		[["", "一张旧弓挂在墙上，弓弦早就烂了。桌上压着一封没寄出去的信。"], ["猎户的信", "“阿娘，等打完这一季的鹿就回家。林子里最近总有人影在樱树下练剑……”"]],
		[["", "屋里供着一块无字牌位，前面的香灰积了厚厚一层。"], ["", "牌位底下塞着一枚魂玉，像是有人专门留给后来的人。"]],
	],
	"grave": [
		[["", "骨室的墙上密密麻麻刻着名字，最后一行只刻了一半。"], ["守墓人的刻字", "“百骨将原本是守冢的将军。他说要替死人守到天亮，可这里一直没有天亮。”"]],
		[["", "石台上摆着一盏熄了的灯，灯油是黑的。"], ["守墓人的手记", "“灯灭一盏，坑里就多站起来一个。我只剩最后几盏了。”"]],
		[["", "一具穿着守墓人衣服的骸骨靠在墙边，手里攥着一串铜钥匙。"], ["", "钥匙早就锈死了。你把它放回他手里，在他身边找到几枚魂玉。"]],
	],
	"temple": [
		[["", "经架上的卷子大多被虫蛀了，只有一卷用油布包着。"], ["残经", "“寂光者，非光也。灯不灭，则人不得去。”"]],
		[["", "藏经阁的窗纸破了个洞，月光正好照在一卷摊开的经上。"], ["寂光的批注", "“徒儿若来，莫寻我。此灯一灭，寺中千魂俱散，我也就散了。”"]],
		[["", "角落里一个小沙弥的蒲团，旁边放着没抄完的经。"], ["", "抄到一半的那一页上写着你的名字。墨迹还很新。"]],
	],
	"well": [
		[["", "一具僧人的骸骨跪在墙前，手里还攥着凿子。墙上的经文刻到一半，最后几个字歪得不成样子。"], ["刻经僧的最后一行", "“灯在吃水，水在吃人。我刻经，是怕忘了自己是谁。”"]],
		[["", "石台上摊着一本泡烂的寺志，只有一页还认得出字。"], ["寂光寺志", "“某年冬，住持枯荣下井寻灯，七日不返。弟子寂光守井四十九日，封井。”"]],
		[["", "水里沉着一块灰布，布上缝着一盏灯的纹样。不是寺里的东西。"], ["", "布角绣着两个小字：续命。你把它塞进行囊，在布底下摸到几枚魂玉。"]],
	],
}
const ZONE_OF := {"forest": "forest", "sakura": "forest", "grave": "grave", "temple": "temple", "well": "well"}
## 屋里的摆设（靠墙放）
const PROPS := {
	"forest": ["crates", "barrel", "sack", "lumber", "barrel_small", "table", "bench"],
	"grave": ["coffin", "gravestone", "skull_candle", "ribcage", "post_skull", "candles", "grave_b"],
	"temple": ["shelf", "candles", "bench", "banner", "lantern", "shelf", "candles"],
	"well": ["column", "candles", "shrine", "rubble", "skull_candle", "shelf", "pillar"],
}
const WALL := {"forest": "wall", "grave": "wall_broken", "temple": "wall", "well": "wall_broken"}
const LIGHT := {"forest": Color(1.0, 0.75, 0.45), "grave": Color(0.55, 1.0, 0.7), "temple": Color(1.0, 0.8, 0.5), "well": Color(0.5, 0.85, 1.0)}
const TINT := {"forest": Color(1.3, 1.15, 1.0), "grave": Color(0.85, 0.95, 0.9), "temple": Color(0.62, 0.5, 0.48), "well": Color(0.8, 0.95, 1.1)}

var main: ArpgMain
var arena: Arena
var kind := "cache"
var side := 1.0               # -1 左墙 / 1 右墙
var door_z := 0.0
var room := Vector2(12, 10)   # 侧室大小（x 宽 × z 深）
var rect := Rect2()           # 侧室地面（xz）
var zone := "forest"
var stage := "locked"         # locked 门关着 / open 门开着 / fight 伏兵或试炼进行中 / done 拿完了
var _door: Vector3
var _seal: Node3D
var _seal_body: StaticBody3D
var _label: Label3D
var _t := 0.0
var _fight_t := 0.0
var _trial_left := 0.0
var _rng := RandomNumberGenerator.new()


## 这间房要开的侧室：返回 [{side, z, w, kind, room}]，交给 Arena.doors 和 SideRoom.build
static func plan(room_kind: String, sz: Vector2, rng: RandomNumberGenerator, force_kind: String = "") -> Array:
	var n := 0
	if room_kind in ["fight", "elite", "trial"]:
		n = 1 + (1 if rng.randf() < 0.4 else 0)
	elif room_kind in ["shop", "rest", "event", "story", "treasure", "start"]:
		n = 1 if rng.randf() < 0.5 else 0
	if force_kind != "":
		n = maxi(n, 1)
	var out := []
	var first_side := -1.0 if rng.randf() < 0.5 else 1.0
	var big := sz.x >= 40.0
	for i in range(n):
		var k := force_kind if force_kind != "" else _pick_kind(rng, out)
		var r := Vector2(16, 12) if (big and k in ["ambush", "trial"]) else (Vector2(12, 10) if big else Vector2(10, 9))
		var hz := sz.y * 0.5
		out.append({"side": first_side * (1.0 if i == 0 else -1.0), "z": rng.randf_range(-hz + 6.0, hz - 6.0), "w": 3.0, "kind": k, "room": r})
	return out


static func _pick_kind(rng: RandomNumberGenerator, taken: Array) -> String:
	for _t in range(8):
		var total := 0
		for w: int in WEIGHTS:
			total += w
		var r := rng.randi() % total
		for i in range(KINDS.size()):
			r -= int(WEIGHTS[i])
			if r < 0:
				var k: String = KINDS[i]
				var dup := false
				for p: Dictionary in taken:
					if p["kind"] == k:
						dup = true
				if not dup:
					return k
				break
	return "cache"


func display_name() -> String:
	return String(NAMES[zone][kind][0])


func build(plan_: Dictionary) -> void:
	_rng.randomize()
	side = float(plan_["side"])
	door_z = float(plan_["z"])
	kind = String(plan_["kind"])
	room = plan_["room"]
	zone = String(ZONE_OF.get(arena.zone, "forest"))
	var hx := arena.size.x * 0.5
	var x_in := side * (hx + 1.0)
	var x_out := side * (hx + 1.0 + room.x)
	rect = Rect2(minf(x_in, x_out), door_z - room.y * 0.5, room.x, room.y)
	_door = Vector3(side * (hx + 0.5), 0, door_z)
	arena.floor_patch(rect, TINT[zone])
	_build_walls(hx)
	_build_door()
	_dress()
	_build_content()


func center() -> Vector3:
	return Vector3(rect.get_center().x, 0, rect.get_center().y)


## 侧室里一点（u 沿门→里墙 0~1，v 沿 z 0~1）
func at(u: float, v: float) -> Vector3:
	var x := lerpf(side * (arena.size.x * 0.5 + 1.0), side * (arena.size.x * 0.5 + 1.0 + room.x), u)
	return Vector3(x, 0, rect.position.y + rect.size.y * v)


func _build_walls(hx: float) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var far := x1 if side > 0.0 else x0
	# 碰撞：里墙、上墙、下墙（和主房间的侧墙接上）
	arena._box_collider(Vector3(far + side * 0.5, 1, door_z), Vector3(1, 2, room.y + 2.0))
	var wx0 := minf(side * hx, far)
	var wx1 := maxf(side * hx, far)
	arena._box_collider(Vector3((wx0 + wx1) * 0.5, 1, z0 - 0.5), Vector3(wx1 - wx0 + 1.0, 2, 1))
	arena._box_collider(Vector3((wx0 + wx1) * 0.5, 1, z1 + 0.5), Vector3(wx1 - wx0 + 1.0, 2, 1))
	# 样子：上墙（画面上方）一排墙，里墙一排侧着的墙，下墙（靠镜头）一排矮栅栏（挡住人时自动变透明）
	var wid: String = WALL[zone]
	var nw := int(ceil((room.x + 1.0) / 3.1))
	for i in range(nw):
		var x := lerpf(side * (hx + 1.0), far, (i + 0.5) / nw)
		arena.kit(wid if _rng.randf() < 0.75 else "wall_arch", Vector3(x, 0, z0 - 0.35), 0.0, 1.0, false)
	var nd := int(ceil((room.y + 1.0) / 3.1))
	for i in range(nd):
		var z := lerpf(z0 - 0.3, z1 + 0.3, (i + 0.5) / nd)
		arena.kit(wid, Vector3(far + side * 0.35, 0, z), PI * 0.5, 1.0, false)
	var nf := int(ceil(room.x / 2.8))
	for i in range(nf):
		var x := lerpf(side * (hx + 1.0), far, (i + 0.5) / nf)
		arena.kit("fence" if _rng.randf() < 0.7 else "fence_broken", Vector3(x, 0, z1 + 0.3), 0.0, 1.0, false, true)


func _build_door() -> void:
	arena.kit("arch_gate", _door, PI * 0.5, 1.0, false)
	var col: Color = LIGHT[zone]
	for s: float in [-1.0, 1.0]:
		arena.kit("torch_wall", _door + Vector3(-side * 0.7, 1.2, s * 1.9), -side * PI * 0.5, 1.0, false)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font = Feel.I.font if Feel.I != null else Game.font
	_label.font_size = 36
	_label.outline_size = 10
	_label.pixel_size = 0.008
	_label.modulate = col.lightened(0.3)
	add_child(_label)
	_label.global_position = _door + Vector3(-side * 0.6, 3.6, 0)
	_seal_on()


## 门上一道光幕 + 一块碰撞：门关着时进不去
func _seal_on() -> void:
	if is_instance_valid(_seal):
		return
	_seal = Node3D.new()
	add_child(_seal)
	_seal.global_position = _door
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 2.6)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/lm_cone_a_blur.png"))
	m.set_shader_parameter("color", Color(0.9, 0.35, 0.3, 0.7) if stage == "fight" else Color(0.55, 0.6, 0.9, 0.55))
	m.set_shader_parameter("energy", 1.4)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = PI * 0.5
	mi.position.y = 1.3
	_seal.add_child(mi)
	_seal_body = StaticBody3D.new()
	_seal_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 2.0, 3.2)
	cs.shape = bs
	cs.position.y = 1.0
	_seal_body.add_child(cs)
	_seal.add_child(_seal_body)
	_update_label()


func _seal_off() -> void:
	if is_instance_valid(_seal):
		_seal.queue_free()
	_seal = null
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	var nm := display_name()
	match stage:
		"locked":
			_label.text = "%s\n（清场后开）" % nm
		"open":
			_label.text = "%s\n%s" % [nm, NAMES[zone][kind][1]]
		"fight":
			_label.text = nm
		_:
			_label.text = nm
			_label.modulate.a = 0.45


## 门打开（清场后，或者没有战斗的房间一进来）
func unlock(loud: bool) -> void:
	if stage != "locked":
		return
	stage = "open"
	_seal_off()
	if loud:
		Game.sfx("door", -4.0)
		main.vfx.shock_ring(_door, LIGHT[zone], 0.4, 3.0, 0.6)
		main.feel.callout(_door + Vector3(-side * 1.2, 2.4, 0), "侧门开了：%s" % display_name(), Color(LIGHT[zone]).lightened(0.3), 1.0)


func _dress() -> void:
	var col: Color = LIGHT[zone]
	# 一盏顶灯 + 里墙两团火
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.4
	l.omni_range = maxf(room.x, room.y) * 0.75
	add_child(l)
	l.global_position = center() + Vector3(0, 3.2, 0)
	if zone == "grave" or zone == "well":
		arena.spirit_fire(at(0.92, 0.3) + Vector3(0, 0.4, 0), Color(0.55, 1.0, 0.7) if zone == "grave" else Color(0.45, 0.85, 1.0), 0.9, 1.2, 5.0)
	elif Arena.lod > 0:
		arena.kit("torch_wall", at(1.0, 0.5) + Vector3(-side * 0.5, 1.2, 0), side * PI * 0.5 + PI, 1.0, false)
	# 靠上墙、里墙放几件摆设（要碰撞，绕着走）
	var props: Array = PROPS[zone]
	var spots := [at(0.35, 0.12), at(0.6, 0.12), at(0.85, 0.12), at(0.9, 0.82), at(0.88, 0.35)]
	var n := 3 + (2 if room.x >= 12.0 else 1)
	for i in range(mini(n, spots.size())):
		var id: String = props[_rng.randi() % props.size()]
		arena.kit(id, spots[i], (0.0 if i < 3 else PI * 0.5) + _rng.randf_range(-0.2, 0.2), 1.0, true)
	# 地上散几件小东西（不挡路）
	var bits := {"forest": ["sack", "barrel_small", "lumber"], "grave": ["ribcage", "gravemarker", "candles"], "temple": ["candles", "candles", "sack"],
		"well": ["rubble", "candles", "ribcage"]}
	for i in range(3):
		var p := at(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.55, 0.85))
		arena.kit(bits[zone][i], p, _rng.randf() * TAU, 0.8, false)


# ---------- 各类侧室的内容 ----------

func _build_content() -> void:
	var mid := at(0.62, 0.45)
	match kind:
		"cache":
			main._npc("宝箱", mid, {"kit": "box", "scale": 1.4}, func(n: ArpgNpc) -> void: _finish_chest(n, 1))
			for i in range(5):
				var lp := at(_rng.randf_range(0.3, 0.9), _rng.randf_range(0.25, 0.75))
				_coin_pile(lp)
		"ambush":
			arena.kit({"forest": "tree_dead", "grave": "crypt", "temple": "shrine", "well": "shrine"}[zone], at(0.85, 0.5), -side * PI * 0.5, 0.9 if zone != "grave" else 0.6, true)
		"spring":
			var k: String = "shrine" if zone == "temple" else "well"
			main._npc(display_name(), mid, {"kit": k, "scale": 1.3}, _use_spring)
			if Vfx.I != null:
				Vfx.I.ground(mid + Vector3(0, 0.02, 0), "magic_01", Color(0.5, 1.0, 0.8, 0.6), 2.2, 2.6, 1.0e6).reparent(self)
		"lore":
			var k2: String = {"forest": "grave_a", "grave": "coffin", "temple": "shelf", "well": "coffin"}[zone]
			main._npc(display_name(), mid, {"kit": k2, "scale": 1.3}, _read_lore)
		"trial":
			var k3: String = {"forest": "gravestone", "grave": "skull_candle", "temple": "lantern", "well": "lantern"}[zone]
			main._npc(display_name(), mid, {"kit": k3, "scale": 1.6}, _start_trial)
			arena.spirit_fire(mid + Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.35) if zone != "grave" else Color(0.55, 1.0, 0.7), 1.1, 1.6, 6.0)


## 地上一小撮铜钱：走近了自己吸过来
func _coin_pile(p: Vector3) -> void:
	var a := Node3D.new()
	add_child(a)
	a.global_position = p
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.35, 0.12, 0.35)
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.78, 0.3) * 1.4
	mi.material_override = m
	mi.position.y = 0.06
	a.add_child(mi)
	a.set_meta("coin_pile", true)


func _process(dt: float) -> void:
	_t += dt
	if main == null or not is_instance_valid(main.hero) or main.mode != "room":
		return
	var hp := main.hero.global_position
	# 铜钱堆
	for c: Node in get_children():
		if c.has_meta("coin_pile") and (c as Node3D).global_position.distance_to(hp) < 1.4:
			main._on_drop((c as Node3D).global_position, 3 + main.state.floor_i() * 2, 0, "")
			c.queue_free()
	if stage == "open" and kind == "ambush" and _inside(hp, 2.5):
		_start_ambush()
	if stage == "fight":
		_fight_t += dt
		var left := main.get_tree().get_nodes_in_group("foes").size()
		if kind == "trial":
			_trial_left -= dt
			main.hud.wave_text = "%s　剩 %d 只　%.0f 秒" % [display_name(), left, maxf(_trial_left, 0.0)]
		if _fight_t > 1.5 and left == 0:
			_end_fight(kind != "trial" or _trial_left > 0.0)


func _inside(p: Vector3, depth: float) -> bool:
	if not rect.has_point(Vector2(p.x, p.z)):
		return false
	return absf(p.x) > arena.size.x * 0.5 + 1.0 + depth


func _start_ambush() -> void:
	stage = "fight"
	_fight_t = 0.0
	_seal_on()
	Game.sfx("danger", -2.0)
	main.hud.banner(display_name(), "门在身后关上了", 1.8)
	main.cam_rig.punch_zoom(0.3, 0.6)
	var fl := main.state.floor_i()
	var w: Array = [["crawler", 4, "skeleton", 2], ["rogue", 2, "skeleton", 2, "mage", 1], ["skeleton", 2, "rogue", 2, "mage", 1]][mini(fl, 2)]
	if zone == "well":
		w = ["drowned", 4, "chainmonk", 1]
	if main.state.run.row >= 2 or fl >= 1:
		w = w + ["samurai", 1]
	_spawn(w)


func _spawn(w: Array) -> void:
	var pts := []
	for i in range(12):
		pts.append(at(_rng.randf_range(0.4, 0.92), _rng.randf_range(0.25, 0.8)))
	var pi := 0
	for j in range(0, w.size(), 2):
		for k in range(int(w[j + 1])):
			main._spawn_foe(String(w[j]), pts[pi % pts.size()], 0.15 + pi * 0.1)
			main.vfx.sheet("spawn-cast", pts[pi % pts.size()], 2.0, Color(LIGHT[zone]), 1.6)
			pi += 1


func _start_trial(n: ArpgNpc) -> void:
	if n.used or stage != "open":
		return
	n.used = true
	stage = "fight"
	_fight_t = 0.0
	_trial_left = 22.0
	_seal_on()
	Game.sfx("danger", -2.0)
	main.hud.banner(display_name(), "22 秒内斩尽来敌", 1.8)
	var fl := main.state.floor_i()
	if zone == "well":
		_spawn(["crawler", 6, "drowned", 4])
		return
	_spawn([["crawler", 8, "skeleton", 2], ["crawler", 5, "rogue", 3, "mage", 1], ["skeleton", 3, "rogue", 3, "mage", 1]][mini(fl, 2)])


func _end_fight(won: bool) -> void:
	stage = "done"
	if OS.get_cmdline_user_args().has("--tel"):
		print("SIDE %s won=%s t=%.1f" % [kind, won, _fight_t])
	_seal_off()
	main.hud.wave_text = "清场"
	_count()
	if kind == "ambush":
		ArpgAch.unlock("side_ambush")
		main.hud.banner("伏兵尽灭", "箱子里的东西归你了", 1.8)
		Game.sfx("door")
		var n := main._npc("宝箱", at(0.6, 0.45), {"kit": "box", "scale": 1.4}, func(x: ArpgNpc) -> void: _finish_chest(x, 2, false))
		main.vfx.sheet("crit-hit", n.global_position, 3.0, Color(1.0, 0.9, 0.6), 2.0)
	elif won:
		ArpgAch.unlock("side_trial")
		main.hud.banner("试炼成了", "选一个心法", 1.6)
		for i in range(2 + mini(main.state.floor_i(), 1)):
			main._loot(main.hero.global_position, "jade", 1)
		main.get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if main._menu == null:
				main._offer_boons_then(1))
	else:
		main.hud.banner("超时了", "下次快一点", 1.6)
	_update_label()


## 拿完一间侧室：这一局计数 + 成就
func _count() -> void:
	main.state.side_rooms += 1
	ArpgAch.unlock("side_1")
	ArpgAch.add("side_rooms")


func _finish_chest(n: ArpgNpc, min_rarity: int, count: bool = true) -> void:
	if n.used:
		return
	main._open_chest(n, min_rarity)
	if count:
		stage = "done"
		_count()
		_update_label()


func _use_spring(n: ArpgNpc) -> void:
	if n.used:
		return
	n.used = true
	stage = "done"
	_count()
	main._heal(0.4)
	var h := main.hero
	if h.gourds < h.max_gourds:
		h.gourds += 1
		main.feel.callout(h.head_top(), "药葫芦 +1", Color(0.6, 1.0, 0.8), 1.0)
	main.vfx.sheet("soul-rise", n.global_position, 3.0, Color(0.6, 1.0, 0.85), 1.8)
	_update_label()


## 支线物件：幽林先找阿樱的风筝（一次一件），再找无名冢的名牌（幽林一个、无名冢两个，要先拿到守墓人的名单）
func _story_finds(lines: Array) -> void:
	# 第二幕支线 · 地藏的头：青井的遗骸侧室水底摸到
	if zone == "well" and not bool(Game.save.get("arpg_jizo_head", false)):
		Game.save["arpg_jizo_head"] = true
		Game.write_save()
		lines.append_array(ArpgStory.JIZO_HEAD_FOUND)
		return
	if zone == "forest" and ArpgStory.kite() < ArpgStory.KITE.size():
		var k := ArpgStory.kite()
		lines.append_array(ArpgStory.KITE[k])
		Game.save["arpg_kite"] = k + 1
		Game.write_save()
		lines.append(["", "（阿樱的风筝 %d / %d%s）" % [k + 1, ArpgStory.KITE.size(), "：回山门看看" if k + 1 >= ArpgStory.KITE.size() else ""]])
		if k + 1 >= ArpgStory.KITE.size():
			ArpgAch.unlock("kite")
		return
	if not (zone in ["forest", "grave"]) or not ArpgStory.has_name_list() or ArpgStory.names_done():
		return
	for _i in range(1 if zone == "forest" else 2):
		var ni := ArpgStory.next_name()
		if ni < 0:
			break
		ArpgStory.take_name(ni)
		lines.append(["", "骨头旁边有一块烧黑的木名牌：%s。" % String(ArpgStory.NAMES[ni][0])])
		lines.append(["守墓人的名单", String(ArpgStory.NAMES[ni][1]), ArpgStory.C_KEEPER])
	lines.append(["", "（无名冢的名字 %d / %d）" % [ArpgStory.names().size(), ArpgStory.NAMES.size()]])
	if ArpgStory.names_done():
		lines.append_array(ArpgStory.NAMES_DONE)
		ArpgAch.unlock("names")


func _read_lore(n: ArpgNpc) -> void:
	if n.used:
		return
	n.used = true
	stage = "done"
	_count()
	Game.sfx("memory")
	var pool: Array = LORE[zone]
	var lines: Array = (pool[_rng.randi() % pool.size()] as Array).duplicate()
	var jade := 2 + main.state.floor_i()
	lines.append(["", "（魂玉 +%d%s）" % [jade, "，经卷里悟出一门心法" if zone == "temple" else ""]])
	_story_finds(lines)
	var box := main._say(lines)
	for i in range(jade):
		main._loot(n.global_position + Vector3(0, 0, 1.0), "jade", 1)
	if zone == "temple" and box != null:
		box.finished.connect(func() -> void:
			if is_instance_valid(main) and main.mode == "room":
				main._offer_boons_then(1))
	_update_label()
