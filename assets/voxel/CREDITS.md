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

## 武器（weapon/）

`weapon/*.json` 由 `voxelize_prop.py --grip` 体素化（原点在握把），清单见 `tools/voxelize/weapon_list.txt`。KayKit Adventurers 1.0 的单手剑、双手剑、匕首、双手斧、法杖，KayKit Skeletons 1.0 的骷髅刀、骷髅斧、骷髅法杖、骷髅大盾，以及骷髅弩（骨弩手）、骷髅大盾的转向版 shield_f（盾骷髅）、骷髅箭（弩箭飞行物）。Kay Lousberg，CC0 1.0。
