"""战马（冲骑、幽骑骑的）：和人物同一套小格、同一种明暗，输出 assets/voxel/horse.json.gz。

部件：torso = 马身 + 脖子 + 头 + 尾（锚点在鞍上，骑手的胯就放在这里）；
      hleg_fr / hleg_fl / hleg_br / hleg_bl = 四条腿（锚点在腿根，VoxActor 绕腿根前后摆做奔跑）。
比人物略小一号（鞍高约 1.2 米、身长约 2 米）：斜俯视镜头下马要能和骑手一起看清，又不能把一屋子小怪全挡住。
面朝 +x，+z 是右边。

用法：python3 tools/charforge/horse.py
"""
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import forge
from kit import C

forge.XR = (-52, 64)       # 马比人长：模型空间往前后放宽
LEGS = {"hleg_fr": (20, 6.5), "hleg_fl": (20, -6.5), "hleg_br": (-21, 6.5), "hleg_bl": (-21, -6.5)}
SADDLE_Y = 62
for pn in LEGS:
    forge.PART_IDS.append(pn)
    forge.SPAN[pn] = (pn, None)

COAT, COAT_D, COAT_L = "#a29a8e", "#6c665e", "#cbc4b6"     # 青骢（灰白马）：驿站夜里、宫里金砖上都跳得出来；深色马在暗地面上整匹看不见
MANE, HOOF = "#2a2628", "#141012"


def horse():
    J = {"head": (0, SADDLE_Y, 0), "hips": (0, 40, 0)}
    for pn, (x, z) in LEGS.items():
        J[pn] = (x, 47, z)
    f = forge.Forge("horse", J, source="本作自制（锻造台）", seed=7)

    def coat(X, Y, Z):
        # 上亮下暗：肚子底下一圈暗色，背上一点亮
        t = np.clip((Y - 38) / 24.0, 0, 1)[..., None]
        return forge.rgb(COAT_D) * (1 - t) + forge.rgb(COAT_L) * t * 0.55 + forge.rgb(COAT) * t * 0.45

    # ---- 身子：胸、桶、臀 ----
    body = f.ell((0, 49, 0), (29, 11.5, 10)) | f.ell((20, 50, 0), (12, 13, 9.5)) | f.ell((-21, 51, 0), (12.5, 12, 10.5))
    f.fill(body, "torso", coat)
    # ---- 脖子、头 ----
    f.fill(f.seg((24, 55, 0), (36, 75, 0), 8.0, 5.2), "torso", coat)
    f.fill(f.seg((37, 78, 0), (51, 66, 0), 5.6, 3.8), "torso", COAT)
    f.paint(f.seg((48, 67, 0), (52, 65, 0), 4.2), "#5c5650", part="torso")          # 口鼻暗一点
    for z in (2.6, -2.6):
        f.fill(f.seg((35, 81, z), (34, 86, z), 1.5, 0.9), "torso", COAT_D)          # 耳朵
    # 鬃毛：脖子后上沿一道黑
    f.fill(f.seg((21, 60, 0), (34, 82, 0), 2.6, 2.0) & ~f.seg((24, 55, 0), (36, 75, 0), 7.0, 4.4), "torso", MANE)
    # 尾巴
    f.fill(f.seg((-32, 57, 0), (-41, 46, 0), 3.6, 3.0) | f.seg((-41, 46, 0), (-39, 28, 0), 3.0, 2.2), "torso", MANE)

    # ---- 马甲：钢面帘、颈甲两道、蓝鞍褥铜边、黑漆鞍 ----
    f.paint(f.seg((37, 78, 0), (49, 68, 0), 6.0) & (f.Y > 72 - (f.X - 37) * 0.5), C["steel"], part="torso")   # 面帘盖额头到鼻梁
    f.paint(f.seg((38, 79, 0), (48, 70, 0), 6.2) & (np.abs(f.Z) < 1.2) & (f.Y > 74 - (f.X - 37) * 0.5), C["steel_l"], part="torso")
    for t in (0.35, 0.7):
        a = np.array([24, 55, 0]) + (np.array([36, 75, 0]) - np.array([24, 55, 0])) * t
        f.paint(f.ell(tuple(a), (3.0, 3.0, 9)) & (f.Y > a[1] - 2), C["steel_d"] if t < 0.5 else C["steel"], part="torso")
    cloth = f.box(-13, 11, 38, 64, -12, 12)
    f.paint(cloth, C["navy"], part="torso")
    f.paint(cloth & ~f.box(-12, 10, 40, 64, -12, 12), C["brass"], part="torso")          # 鞍褥下沿铜边
    f.paint(cloth & (f.Y < 41.5), C["brass"], part="torso")
    f.paint(f.box(-13, -11, 38, 64, -12, 12) | f.box(9, 11, 38, 64, -12, 12), C["navy_d"], part="torso")
    f.fill(f.box(-9, 9, 58, 63, -6, 6) & f.ell((0, 58, 0), (10, 6, 7)), "torso", C["lacq"])  # 鞍
    f.fill(f.box(-10, -6, 60, 66, -5, 5), "torso", C["lacq_l"])                             # 后鞍桥
    f.fill(f.box(6, 9, 60, 65, -4, 4), "torso", C["lacq_l"])                                # 前鞍桥
    # 胸前一颗红缨
    f.fill(f.ell((31, 54, 0), (2.5, 4.5, 2.5)), "torso", C["red"])
    # 眼睛：敌人统一红光
    for z in (4.2, -4.2):
        f.fill(f.box(42, 44, 73, 75, z - 0.6 if z > 0 else z - 0.4, z + 0.4 if z > 0 else z + 0.6), "torso", C["eye"], glow=1.0)

    # ---- 腿：前腿直、后腿有飞节往后折 ----
    for pn, (x, z) in LEGS.items():
        front = x > 0
        if front:
            up = f.seg((x, 47, z), (x + 1, 25, z), 5.0, 3.4)
            lo = f.seg((x + 1, 25, z), (x + 0.5, 6, z), 2.7, 2.4)
        else:
            up = f.seg((x, 49, z), (x - 4, 27, z), 5.8, 3.2)
            lo = f.seg((x - 4, 27, z), (x - 1, 6, z), 2.6, 2.4)
        hx = x + (0.5 if front else -1)
        f.fill(up & (f.part < 0), pn, coat)   # 腿根埋在肚子里的那截归身子：腿一摆不会从肚子里翻出洞
        f.fill(lo, pn, COAT_D)
        f.fill(f.cyl(hx, z, 3.0, 4, 9), pn, "#3a3634")       # 球节
        f.fill(f.cyl(hx + 0.5, z, 3.4, 0, 4.5), pn, HOOF)    # 蹄
    return f


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "voxel")
    f = horse()
    f.shade()
    f.export(os.path.normpath(out))
