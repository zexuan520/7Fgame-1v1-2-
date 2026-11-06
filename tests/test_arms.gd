extends Node
## 兵器、装备、道具、皮肤的数据自检（无界面运行，不碰正式存档）：
##   godot --headless --path . res://tests/test_arms.tscn
## 验证：九种兵器的连招都能建出来、装备表 id 不重复且都查得到、套装件数对、道具叠加和上限、
## 属性面板列的来源加起来等于实际生效的 stats()、局中断点带着主副手/道具/新部位存进去读回来、旧断点（没有新字段）能补齐、皮肤都能查到解锁条件。

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		failures += 1


func _run() -> void:
	var keep := Game.save.duplicate(true)
	var real_run := Game.run_path
	Game.run_path = "user://test_arms_run.cfg"

	print("兵器")
	for id: String in ArpgData.WEAPONS:
		var c := ArpgArms.combo(id)
		var w := ArpgData.weapon(id)
		var ok := c.size() >= 3 and VoxelModel.data_exists("res://assets/voxel/weapon/%s.json" % String(w["model"])) and String(w.get("trait", "")) != ""
		for s: AttackStep in c:
			ok = ok and s.startup > 0.0 and s.cancel_at <= s.total() and s.damage > 0.0
		_check(ok, "%s：%d 段连招、模型、特性" % [w["name"], c.size()])
	var wi := ArpgGear.roll_weapon(RandomNumberGenerator.new(), 4, 0.0, "hammer")
	_check(String(wi["slot"]) == "weapon" and (wi["affixes"] as Array).size() >= 1 and float(ArpgGear.stats(wi).get("atk", 0.0)) >= 0.39, "传品兵器带词条、伤害 +40%")

	print("装备")
	var ids := {}
	var dup := false
	for slot: String in ArpgData.GEAR_SLOTS:
		for g: Dictionary in ArpgData.gear_pool(slot):
			dup = dup or ids.has(g["id"])
			ids[g["id"]] = true
			_check(String(ArpgData.gear(String(g["id"]))["slot"]) == slot, "%s 查得到，部位 %s" % [g["name"], slot]) if g.get("set", "") != "" else null
	_check(not dup, "装备 id 不重复（共 %d 件）" % ids.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := {}
	for i in range(200):
		seen[ArpgGear.roll(rng)["slot"]] = true
	_check(seen.size() == 4, "随机掉落四个部位都会出")
	for sid: String in ArpgArms.GEAR_SETS:
		var n := 0
		for slot: String in ArpgData.GEAR_SLOTS:
			for g: Dictionary in ArpgData.gear_pool(slot):
				if String(g.get("set", "")) == sid:
					n += 1
		_check(n >= 3, "套装「%s」有 %d 件" % [ArpgArms.GEAR_SETS[sid]["name"], n])
	var gear := {"armor": {"slot": "armor", "base": "chain", "rarity": 0, "affixes": []}, "helm": {"slot": "helm", "base": "iron_helm", "rarity": 0, "affixes": []},
		"boots": {"slot": "boots", "base": "iron_boots", "rarity": 0, "affixes": []}, "charm": {}, "charm2": {}}
	var st := ArpgArms.set_stats(gear)
	_check(float(st.get("hp", 0.0)) == 25.0 and float(st.get("set_iron", 0.0)) == 1.0, "不动套三件：生命 +25 和反震")

	print("道具")
	var s := ArpgState.start_new(1)
	_check(s.props.size() == 1, "开局送一样道具")
	s.props.clear()
	_check(s.add_item("fire_flask", 9) == 3, "火油罐叠到上限 3")
	s.add_item("elixir")
	s.add_item("darts")
	_check(s.add_item("smoke_ball") == 0 and s.add_item_room("smoke_ball") == 0, "最多带三种")
	s.use_item("elixir")
	_check(s.props.size() == 2, "用完的道具空出格子")

	print("属性面板的来源")
	var ps := ArpgState.start_new(1)
	ps.gear = gear.duplicate(true)
	ps.boons = ["edge", "edge", "keen", "keen", "keen"]
	ps.whet = 2
	var sum := {}
	for part: Dictionary in ps.stat_parts():
		ArpgData.add_stats(sum, part["st"])
	var full := ps.stats()
	var same := sum.size() == full.size()
	for k: String in full:
		same = same and absf(float(full[k]) - float(sum.get(k, 0.0))) < 0.0001
	_check(same, "stats() 等于 stat_parts() 逐项相加（面板列的来源和实际生效的一致）")
	var srcs := ps.stat_parts().map(func(x: Dictionary) -> String: return String(x["src"]))
	_check(srcs.has("心法·利刃 ×2") and srcs.has("套装·不动（3 件）") and srcs.has("磨刀 ×2") and srcs.has("大成·修罗场"), "来源按心法、套装、磨刀、流派大成分开列")
	_check(ArpgStatsPanel.fmt_key("dash_cd", 0.15) == "-15%" and ArpgStatsPanel.fmt_key("hp", 25.0, true) == "生命 +25", "数值写法：冷却显示减号，生命显示整数")

	print("局中断点")
	s.arms[0] = ArpgGear.weapon_item("spear", 2, [["crit", 0.05]])
	s.weapon = "spear"
	s.arms[1] = ArpgGear.weapon_item("crossbow", 1)
	s.gear["boots"] = {"slot": "boots", "base": "thunder_boots", "rarity": 3, "affixes": [], "name": "珍·雷纹靴"}
	s.prop_sel = 1
	Game.write_checkpoint({"state": s.to_dict()})
	var ck := Game.load_checkpoint()
	var r := ArpgState.from_dict(ck.get("state", {}))
	_check(r != null and r.weapon == "spear" and String(r.arms[1]["base"]) == "crossbow" and int(r.arms[0]["rarity"]) == 2, "主副手读回来")
	_check(r != null and String(r.gear["boots"]["base"]) == "thunder_boots" and r.props.size() == 2 and r.prop_sel == 1, "靴子、道具读回来")
	r.swap_arms()
	_check(r.weapon == "crossbow" and String(r.arms[1]["base"]) == "spear", "换手")
	# 旧断点：没有 arms / props / 新部位
	var old := s.to_dict()
	old.erase("arms")
	old.erase("props")
	old["gear"] = {"armor": {}, "charm": {}}
	old["weapon"] = "axe"
	var r2 := ArpgState.from_dict(old)
	_check(r2 != null and r2.gear.has("helm") and r2.gear.has("charm2") and String(r2.arms[0]["base"]) == "axe" and (r2.arms[1] as Dictionary).is_empty(), "旧断点补齐新字段")
	var st2 := r2.stats()
	_check(st2.has("crit_dmg"), "旧断点的裂骨斧特性照样生效")
	Game.clear_checkpoint()

	print("皮肤")
	for sk: Dictionary in ArpgArms.SKINS:
		_check(VoxelModel.data_exists("res://assets/voxel/%s.json" % String(sk["model"])), "%s：模型 %s，条件「%s」" % [sk["name"], sk["model"], ArpgArms.skin_why_not(String(sk["id"])) if ArpgArms.skin_why_not(String(sk["id"])) != "" else "已有"])

	Game.run_path = real_run
	Game.save = keep
	print("")
	print("全部测试通过" if failures == 0 else "有 %d 项没通过" % failures)
	get_tree().quit(failures)
