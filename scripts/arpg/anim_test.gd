class_name AnimTest
extends Node
## 测试：按剧本按键，连拍主角动作（检查动作衔接）。
##   --animtest=run|combo|roll|skills|idle  剧本（SEQ）
##   --anim_out=目录（默认 /tmp/anim）  --anim_every=几帧拍一张（默认 3，60 帧/秒下 0.05 秒）  --anim_crop=像素（默认 420）
##   --anim_nofoes 清掉房间里的敌人（只看主角）
## 每张图以主角为中心裁一块，存 frame_000.png…，tools/anim_sheet.py 拼成联络表。结束时打印 ANIM 行（状态、时间）。

const SEQ := {
	# 跑 → 急停 → 起跑 → 反向急转身 → 停
	"run": [[0.4, "+right"], [1.5, "-right"], [2.1, "+up"], [2.7, "-up"], [2.7, "+down"], [3.4, "-down"], [4.2, "end"]],
	# 按住攻击打完一整套 → 架势 → 振刀
	"combo": [[0.4, "+attack"], [2.4, "-attack"], [4.6, "end"]],
	# 跑着翻滚 → 起身斩 → 再砍 → 翻滚 → 突进斩
	"roll": [[0.3, "+right"], [0.7, "roll"], [1.0, "attack"], [1.3, "attack"], [1.6, "-right"], [1.9, "roll"], [2.3, "dash"], [3.6, "end"]],
	# 连招中途翻滚取消、突进斩、喝药
	"skills": [[0.3, "attack"], [0.55, "attack"], [0.7, "roll"], [1.1, "dash"], [2.0, "heal"], [3.4, "end"]],
	# 点四下打完一套 → 收刀（振刀 / 扛肩 / 转枪）→ 架势放松
	"settle": [[0.3, "attack"], [0.6, "attack"], [0.95, "attack"], [1.35, "attack"], [4.2, "end"]],
	# 三段兵器（大剑、斧、锤）打完一套
	"settle3": [[0.3, "attack"], [0.75, "attack"], [1.25, "attack"], [4.0, "end"]],
	# 站着不动：架势放松、站久的小动作
	"idle": [[0.3, "attack"], [8.5, "end"]],
}

var main: Node
var hero: Hero
var seq: Array = []
var t := 0.0
var _i := 0
var _n := 0
var _f := 0
var every := 3
var crop := 420
var out := "/tmp/anim"
var _log := []


func _ready() -> void:
	var a: Dictionary = main._args
	seq = SEQ.get(String(a["animtest"]), SEQ["run"])
	every = int(a.get("anim_every", "3"))
	crop = int(a.get("anim_crop", "420"))
	out = String(a.get("anim_out", "/tmp/anim"))
	DirAccess.make_dir_recursive_absolute(out)
	hero.hp = hero.max_hp * 0.5     # 留出喝药的余地
	process_priority = 100
	if a.has("anim_nofoes"):
		for f: Node in get_tree().get_nodes_in_group("foes"):
			f.queue_free()


func _physics_process(dt: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	t += dt
	if main._args.has("anim_nofoes"):
		for f: Node in get_tree().get_nodes_in_group("foes"):
			f.queue_free()
	while _i < seq.size() and t >= float(seq[_i][0]):
		_do(String(seq[_i][1]))
		_i += 1
	_f += 1
	if _f % every == 0:
		_shot()
	if _f % every == 0:
		_log.append("%.2f %s st%.1f se%.2f" % [t, hero.state, hero._stance, hero._settle_t])


func _do(cmd: String) -> void:
	if cmd == "end":
		print("ANIM frames=%d %s" % [_n, " | ".join(_log)])
		get_tree().quit()
		return
	var act := cmd.substr(1) if cmd[0] in ["+", "-"] else cmd
	var name := ArpgInput.act(0, act)
	if cmd[0] == "-":
		Input.action_release(name)
	else:
		Input.action_press(name)
		if cmd[0] != "+":
			get_tree().create_timer(0.06).timeout.connect(func() -> void: Input.action_release(name))


func _shot() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var img := get_viewport().get_texture().get_image()
	var c := cam.unproject_position(hero.global_position + Vector3(0, 0.9, 0))
	var r := Rect2i(int(c.x) - crop / 2, int(c.y) - crop / 2, crop, crop)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 8 or r.size.y < 8:
		return
	img.get_region(r).save_png("%s/frame_%03d.png" % [out, _n])
	_n += 1
