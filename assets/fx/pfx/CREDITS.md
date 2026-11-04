# pixelfx 像素特效（MIT）

来源：https://github.com/patch-gg/pixelfx （MIT 许可，许可证原文见 LICENSE-pixelfx.txt）。
用它自带的 `node tools/render.mjs <id> --sheet --bg none --no-actor` 渲染成精灵表（PNG + JSON），没有改动特效代码。
部分特效用 `--opts '{"palette": [...]}'` 换了配色：

| 文件 | 原特效 | 配色 | 游戏里用在 |
|---|---|---|---|
| spawn-cast | arcane/magic-circle-cast | 青 | 小怪出场法阵光柱 |
| rune-cast | arcane/magic-circle-cast | 樱粉 | 头目出场、幽魂术士的落点法阵 |
| portal | arcane/portal | 青 | 光门旋涡 |
| dark-explosion | shadow/dark-explosion | 血红 | 终结技血爆 |
| crit-hit | impacts/crit-hit | 原色 | 会心一击 |
| hit-spark | impacts/hit-spark | 原色 | 重击火花 |
| ground-slam | impacts/ground-slam | 原色 | 赤甲武士、头目跳劈落地 |
| stunned | status/stunned | 原色 | 重甲敌人被打断时头上的星星 |
| soul-rise | spawn/soul-rise | 原色 | 掉魂玉的敌人飘出的魂 |
| charge-up | lightning/charge-up | 原色 | 光束斩蓄力 |
| spirit-flame、bleeding | fire/spirit-flame、status/bleeding | 原色 | 备用 |

画廊里的 Patch Pixel 字体不在 MIT 范围内，没有使用。
