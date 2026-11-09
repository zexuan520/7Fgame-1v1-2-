# 角色模型（2026-11-08 起）

游戏里的主角、小怪、头目、NPC 现在都是**本作自制**的体素角色，用 `tools/charforge`（角色锻造台）按斜俯视镜头重新设计：
头身比约 1:4、每种人一个顶视剪影、三层明度配色、敌人眼睛自发光。不来自任何第三方素材。
生成：`python3 tools/charforge/forge.py [名字 ...]`，角色定义在 `tools/charforge/chars*.py`，零件在 `kit.py`。

下面 KayKit 体素化的老模型（rogue、knight、skel_* 等）只剩早期横版原型（scenes/main.tscn）还在用。

# 体素角色模型出处

这里的 json 都是用 `tools/voxelize/voxelize_char.py` 从下面的 3D 模型体素化出来的（按骨骼切块、1 格 1 像素、颜色取自原贴图）。

- 作者：Kay Lousberg（www.kaylousberg.com）
- 许可：CC0 1.0（公有领域，可商用，不要求署名；参赛说明里仍写明出处）
- 来源：https://github.com/KayKit-Game-Assets

| 文件 | 原模型 | 游戏里用在 |
|---|---|---|
| rogue.json | KayKit Adventurers 1.0 · Rogue_Hooded | 主角 |
| knight.json | KayKit Adventurers 1.0 · Knight | 头目 断水 · 柳江远 |
| barbarian.json | KayKit Adventurers 1.0 · Barbarian | 头目 禅刃 · 寂光 |
| skel_warrior.json | KayKit Skeletons 1.0 · Skeleton_Warrior | 堕落浪人 |
| skel_rogue.json | KayKit Skeletons 1.0 · Skeleton_Rogue | 弓手、忍者 |
| skel_minion.json | KayKit Skeletons 1.0 · Skeleton_Minion | 盾兵、僧兵 |
| skel_mage.json | KayKit Skeletons 1.0 · Skeleton_Mage | 破戒僧 |
| mage.json | KayKit Adventurers 1.0 · Mage | 斜俯视版小怪 招魂巫 |

## 场景件（kit/）

`kit/*.json` 由 `tools/voxelize/voxelize_prop.py` 体素化（2 像素一格），清单见 `tools/voxelize/kit_list.txt`。作者同样是 Kay Lousberg，CC0 1.0：

- KayKit Dungeon Remastered 1.0：木桶、木箱、火把、蜡烛、碎石、旗、柱子、架子、桌子、墙
- KayKit Halloween Bits 1.0：墓碑、坟、灯笼、灯柱、骷髅柱、栅栏、神龛、棺材、长椅、南瓜灯、骷髅蜡烛、肋骨、枯树、松树、地穴、拱门
- KayKit Medieval Hexagon Pack 1.0：木材堆、麻袋、房屋、酒馆、教堂、塔楼、风车、废墟、树林、帐篷
- 第二批（地形和场景件改造，2026-11-06）：Medieval Hexagon 的五种山石、石料堆、兵器架、箭桶、水桶、箭靶、独轮车、木托盘、长木箱、开口木箱、军旗、睡莲、水草、两种树、木栅栏、石栅栏；Halloween Bits 的三种骨头、骷髅、碎墓、木墓标、栅栏柱、吊灯笼、小枯树；Dungeon Remastered 的宝箱、金宝箱、铜钱堆、木箱笼、酒桶架、花木桶、小桌、桌布长桌、窄旗、三联金旗、石栏、石栏柱、半堆碎石

## 武器（weapon/）

2026-11-09 起全部兵器都是**本作自制**：剑、长刀、匕首、钺、齐眉棍（gun）、诸葛连弩、拐杖、锈环首刀、锈板斧、锡杖、藤牌、弩箭由 `tools/charforge/arms.py` 生成；锤、鸳鸯双刀由 `tools/voxelize/gen_arms.py`，枪、灯、旗由 `tools/voxelize/gen_act2_props.py` 生成。不再用 KayKit 的兵器。
