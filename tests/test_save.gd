extends Node
## 存档系统自动测试（无界面运行，不碰正式存档）：
##   godot --headless --path . res://tests/test_save.tscn
## 验证：读写往返、新加的键能存、写坏了从备份恢复、校验和、旧版存档迁移、类型不对换回默认值、
## 局中断点（ArpgState + Run 存成字典再读回来）、设置文件。

var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		failures += 1


func _clean(p: String) -> void:
	for x: String in [p, p + ".tmp", p + ".bak", p + ".broken"]:
		if FileAccess.file_exists(x):
			DirAccess.remove_absolute(x)


func _run() -> void:
	var real_save := Game.save_path
	var real_run := Game.run_path
	var real_set := Game.settings_path
	Game.save_path = "user://test_save2.cfg"
	Game.run_path = "user://test_run2.cfg"
	Game.settings_path = "user://test_settings2.cfg"
	var keep := Game.save.duplicate(true)
	for p: String in [Game.save_path, Game.run_path, Game.settings_path]:
		_clean(p)

	print("读写往返")
	Game.save["jade"] = 123
	Game.save["talents"] = {"vigor": 2}
	Game.save["arpg_weapons"] = ["sword", "spear"]
	Game.save["arpg_new_thing"] = {"lv": 3, "list": [1, 2]}   # 别的线程以后加的键
	Game.write_save()
	var text := FileAccess.get_file_as_string(Game.save_path)
	_check(text.begins_with(SaveStore.HEADER), "文件第一行是注释头（版本 / rev / 校验）")
	Game.save = {}
	Game._save_defaults = keep.duplicate(true)
	Game.save = keep.duplicate(true)
	Game.load_save()
	_check(int(Game.save["jade"]) == 123, "魂玉读回来 123（%s）" % str(Game.save["jade"]))
	_check(int((Game.save["talents"] as Dictionary).get("vigor", 0)) == 2, "天赋读回来")
	_check((Game.save["arpg_weapons"] as Array).has("spear"), "兵器读回来")
	_check(Game.save.get("arpg_new_thing", {}).get("lv", 0) == 3, "新加的键不用改存档代码也能存")
	_check(Game.save_notice == "", "正常读档没有提示")

	print("写第二次：上一份留作备份")
	Game.save["jade"] = 200
	Game.write_save()
	_check(FileAccess.file_exists(Game.save_path + ".bak"), "有 .bak")
	var bak := SaveStore.decode(FileAccess.get_file_as_string(Game.save_path + ".bak"), "save")
	_check(bak["ok"] and int(bak["data"]["jade"]) == 123, "备份是上一份（魂玉 123）")

	print("主文件写坏了（截断一半）→ 从备份恢复，坏文件另存")
	var full := FileAccess.get_file_as_string(Game.save_path)
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string(full.substr(0, full.length() / 2))
	f.close()
	Game.save = keep.duplicate(true)
	Game.save_notice = ""
	Game.load_save()
	_check(int(Game.save["jade"]) == 123, "用备份里的魂玉 123（%s）" % str(Game.save["jade"]))
	_check(Game.save_notice.contains("备份"), "山门会提示：%s" % Game.save_notice)
	_check(FileAccess.file_exists(Game.save_path + ".broken"), "坏文件留了一份 .broken")
	var fixed := SaveStore.decode(FileAccess.get_file_as_string(Game.save_path), "save")
	_check(fixed["ok"], "主文件已经重新写好")

	print("改了一个字节 → 校验不通过")
	var good := FileAccess.get_file_as_string(Game.save_path)
	var bad := good.replace("jade=123", "jade=999")
	_check(bad != good and not SaveStore.decode(bad, "save")["ok"], "改过的存档校验不通过")

	print("主文件和备份全坏 → 从头开始，不崩")
	for p: String in [Game.save_path, Game.save_path + ".bak"]:
		var g := FileAccess.open(p, FileAccess.WRITE)
		g.store_string("garbage [[[ ===")
		g.close()
	Game.save = keep.duplicate(true)
	Game.save["jade"] = 0
	Game.save_notice = ""
	Game.load_save()
	_check(int(Game.save["jade"]) == 0 and Game.save_notice != "", "没崩，从头开始并提示：%s" % Game.save_notice)
	_clean(Game.save_path)

	print("旧版存档（没有注释头）→ 迁移到新版")
	var old := ConfigFile.new()
	old.set_value("save", "jade", 3)
	old.set_value("save", "runs", 7)
	old.set_value("save", "altar", {"vigor": 2, "purse": 1})
	old.set_value("save", "arpg_endings", {"leave": 1})
	old.save(Game.save_path)
	Game.save = keep.duplicate(true)
	Game.save_rev = 0
	Game.load_save()
	_check(int(Game.save["jade"]) == 3 + 15 + 4 and int(Game.save["runs"]) == 7, "旧存档读进来，供台魂玉退回（%s）" % str(Game.save["jade"]))
	_check((Game.save.get("arpg_endings", {}) as Dictionary).has("leave"), "旧存档里的结局还在")
	_check(not Game.save.has("altar"), "供台键迁移后去掉")
	_check(FileAccess.get_file_as_string(Game.save_path).begins_with(SaveStore.HEADER + " v=%d" % Game.SAVE_VERSION), "已按新版格式写回")

	print("类型不对的值 → 换回默认值")
	var weird := ConfigFile.new()
	weird.set_value("save", "talents", [1, 2, 3])
	weird.set_value("save", "jade", 5.0)
	weird.save(Game.save_path)
	Game.save = keep.duplicate(true)
	Game.load_save()
	_check(Game.save["talents"] is Dictionary, "天赋是数组 → 换回空字典")
	_check(Game.save["jade"] is int and int(Game.save["jade"]) == 5, "魂玉 5.0 → 整数 5")

	print("局中断点：ArpgState + Run 存成字典再读回来")
	var s := ArpgState.start_new(2)
	s.coins = 321
	s.jade = 17
	s.boons.append("bleed_edge")
	s.flags["xiaoman"] = true
	s.gear["armor"] = {"base": "x", "rarity": 2, "name": "测试甲"}
	s.bag.append({"base": "y", "rarity": 1})
	s.run.advance(int(s.run.exits()[0][0]))
	s.bought["0_1_0"] = [1]
	var rng_next := s.run.rng.randi()
	s.run.rng.state = s.run.rng.state   # 不变
	var d := s.to_dict()
	Game.write_checkpoint({"state": d, "hero": {"hp": 55.0, "gourds": 1}, "kind": "", "zone": "", "elapsed": 30.0, "where": "测试"})
	var ck := Game.load_checkpoint()
	_check(not ck.is_empty(), "断点读回来")
	var s2 := ArpgState.from_dict(ck["state"])
	_check(s2 != null, "能还原成 ArpgState")
	if s2 != null:
		_check(s2.act == 2 and s2.coins == 321 and s2.jade == 17, "幕、铜钱、魂玉对得上")
		_check(s2.boons.has("bleed_edge") and s2.boons is Array, "心法（有类型的数组）对得上")
		_check(s2.flags.has("xiaoman") and String(s2.gear["armor"].get("name", "")) == "测试甲" and s2.bag.size() == 1, "剧情旗标、装备、行囊对得上")
		_check(s2.run.row == s.run.row and s2.run.col == s.run.col and s2.run.rows.size() == s.run.rows.size(), "地图位置对得上（第 %d 列）" % s2.run.row)
		_check(s2.run.room_type() == s.run.room_type() and s2.omen == s.omen and s2.seed_value == s.seed_value, "房间类型、天象、种子对得上")
		_check(s2.bought.has("0_1_0"), "商人买过的货对得上")
		_check(ArpgState.cur == s2, "ArpgState.cur 指向还原的那局")
	Game.clear_checkpoint()
	_check(Game.load_checkpoint().is_empty() and not FileAccess.file_exists(Game.run_path), "断点删干净")
	_check(ArpgState.from_dict({"run": {"rows": []}}) == null, "不完整的断点返回 null（丢掉不用）")

	print("设置文件")
	Game.settings["music"] = 0.25
	Game.write_settings()
	Game.settings["music"] = 1.0
	Game.load_settings()
	_check(is_equal_approx(float(Game.settings["music"]), 0.25), "音乐音量读回来 25%")

	for p: String in [Game.save_path, Game.run_path, Game.settings_path]:
		_clean(p)
	Game.save_path = real_save
	Game.run_path = real_run
	Game.settings_path = real_set
	print("")
	print("全部测试通过" if failures == 0 else "失败 %d 项" % failures)
	get_tree().quit(1 if failures > 0 else 0)
