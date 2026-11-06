"""方案 A「墨韵」：水墨体素。墨黑、宣纸白、淡墨灰三层明度，唯一的彩色是朱砂红（主角、杀招、敌人要害）。
角色 1:5 偏修长，人物一格 2.8 厘米（身高 64 格），场景件两倍粗、地面四倍粗。"""
import math
import os
import sys

from vlib import V, hx, mix, mul, nz

INK = hx("1c1c21")
INK2 = hx("2b2b31")
INK3 = hx("45454b")
GRAY = hx("6f6d66")
GRAY2 = hx("9a968b")
PAPER = hx("e8e2d1")
PAPER2 = hx("c9c0a8")
SKIN = hx("d9ccb2")
RED = hx("c22e27")
RED2 = hx("8e1f1b")
STEEL = hx("dcdcd6")

VS = 0.028


def hero(out):
    v = V(1)
    # 腿和鞋
    v.cap((-3, 25, 0), (-4, 3, 2), 3, 2.6, INK2)
    v.cap((3, 25, 0), (6, 3, -2), 3, 2.6, INK2)
    v.box((-6, 0, 0), (-2, 2, 5), INK)
    v.box((4, 0, -4), (8, 2, 1), INK)
    # 长袍下摆（前面开衩露腿），边缘碎
    v.frustum(0, 0, 9, 31, 10.5, 7, INK, j=0.03, zs=0.8,
              keep=lambda x, y, z: not (z > 2 and abs(x) < 3 and y < 24) and not (y < 12 and nz(x, y, z, 3) > 0.25))
    # 上身、肩
    v.frustum(0, 0, 29, 45, 7, 8.5, INK, j=0.03, zs=0.62)
    v.ell((0, 44, 0), (9.5, 3, 5.2), INK)
    # 交领：白色内领从左肩斜到右腰
    v.paint(lambda x, y, z: z >= 3 and 33 <= y <= 46 and abs(x + (y - 44) * 0.55) <= 1.3, PAPER)
    # 朱砂腰带
    v.frustum(0, 0, 29, 31, 7.6, 7.6, RED, zs=0.7)
    v.box((-1, 26, 4), (0, 29, 5), RED)
    # 右臂持刀前伸、左臂垂下，袖口宽
    v.cap((8, 43, 0), (12, 33, 4), 2.6, 3.4, INK)
    v.ell((12.5, 31, 6), (1.8, 1.8, 1.8), SKIN)
    v.cap((-8, 43, 0), (-11, 32, -1), 2.6, 3.6, INK)
    v.ell((-11, 29.5, -1), (1.7, 1.8, 1.7), SKIN)
    # 头、发、眼
    v.box((-1, 45, -1), (1, 47, 1), SKIN)
    v.ell((0, 51, 0), (4.6, 5, 4.6), SKIN)
    v.ell((0, 52, -0.6), (5, 5.2, 4.8), INK, keep=lambda x, y, z: z < 0 or y > 54)
    v.front(-2, 51, INK)
    v.front(2, 51, INK)
    v.front(-2, 52, INK)
    v.front(2, 52, INK)
    # 斗笠：宽而平，顶上淡、下沿深
    for y in range(55, 61):
        r = 12.5 - (y - 55) * 2.3
        v.frustum(0, 0, y, y, r, r, mix(GRAY, GRAY2, (y - 55) / 5), j=0.04)
    v.frustum(0, 0, 55, 55, 12.5, 12.5, INK3, ring=1)
    # 朱红长围巾从颈后飘向右后方
    pts = []
    for i in range(16):
        t = i / 15
        pts.append((2 + 17 * t, 46 - 10 * t + 2.2 * math.sin(t * 7), -3 - 9 * t))
    v.chain(pts, 1.7, 1.0, RED, j=0.05)
    v.cap((-3, 46, 2), (3, 46, 2), 1.6, 1.6, RED)
    # 刀：细长，斜向前下，刀柄黑，挂朱红穗
    v.cap((13, 30, 7), (19, 7, 16), 1.2, 1.0, STEEL)
    v.box((12, 29, 6), (14, 30, 8), INK)
    v.cap((12, 31, 6), (11, 35, 4), 0.9, 0.9, INK)
    v.cap((11, 35, 4), (10, 28, 3), 0.7, 0.6, RED)
    v.ground_clip()
    return v.dump(os.path.join(out, "hero"), VS)


def grunt(out, seed=0, lean=1.0):
    """纸傀：宣纸糊的人形，墨迹斑驳，额前贴朱砂符"""
    v = V(10 + seed)
    pap = lambda x, y, z: PAPER2 if nz(x, y, z, seed + 1, 1.3) > 0.35 else (INK3 if nz(x, y, z, seed + 7, 0.9) > 0.62 else PAPER)
    v.cap((-3, 22, 0), (-5, 2, 1), 2, 1.5, PAPER2)
    v.cap((3, 22, 0), (4, 2, -1), 2, 1.5, PAPER2)
    v.box((-7, 0, 0), (-3, 1, 3), INK2)
    v.box((2, 0, -3), (6, 1, 0), INK2)
    # 躯干前倾（驼背）
    v.cap((0, 22, 0), (0, 40, 5 * lean), 6, 7.5, pap, j=0.04)
    # 下摆破碎
    v.frustum(0, 1, 14, 24, 8.5, 7, pap, j=0.04, zs=0.8, keep=lambda x, y, z: nz(x, y, z, seed + 3, 2.0) < 0.3 or y > 19)
    # 长臂下垂，墨爪
    v.cap((7, 39, 4 * lean), (11, 19, 9), 2.1, 1.6, pap)
    v.cap((-7, 39, 4 * lean), (-10, 21, 7), 2.1, 1.6, pap)
    v.cap((11, 19, 9), (12, 15, 11), 1.4, 0.6, INK)
    v.cap((-10, 21, 7), (-11, 17, 9), 1.4, 0.6, INK)
    # 方脑袋（纸糊），眼是两道墨缝，额前朱砂符
    hz = int(6 * lean)
    v.box((-4, 42, hz - 3), (4, 51, hz + 4), PAPER, j=0.03)
    v.box((-4, 51, hz - 3), (4, 51, hz + 4), PAPER2)
    v.front_box(-3, -1, 47, 47, INK)
    v.front_box(1, 3, 47, 47, INK)
    v.front_box(-2, 2, 44, 44, INK3)
    v.box((-1, 45, hz + 5), (1, 54, hz + 5), RED)
    for y in (47, 50, 52):
        v.put((0, y, hz + 5), RED2)
    # 墨色断刀
    v.cap((11, 18, 10), (13, 6, 19), 0.9, 0.7, INK)
    v.ground_clip()
    return v.dump(os.path.join(out, "grunt%d" % seed), VS)


def boss(out):
    """墨判官：乌纱帽、白面具、黑须，握一支一人高的判官笔，墨从袍底淌到地上"""
    v = V(30)
    # 墨池
    v.frustum(0, 2, 0, 0, 30, 30, INK, zs=0.75)
    for (x, z) in ((-14, 14), (9, 18), (20, 6), (-22, 2)):
        v.put((x, 1, z), INK3)
    # 袍
    v.frustum(0, 0, 1, 60, 23, 15, INK, j=0.025, zs=0.78,
              keep=lambda x, y, z: not (y < 10 and nz(x, y, z, 5, 1.6) > 0.2))
    for i in range(14):   # 袍底淌墨
        a = i / 14 * math.tau
        x, z = int(math.cos(a) * 20), int(math.sin(a) * 15)
        v.box((x, 0, z), (x + 1, 4 + (i * 7) % 8, z), INK2)
    v.frustum(0, 0, 58, 84, 15, 20, INK, j=0.025, zs=0.6)
    v.paint(lambda x, y, z: z >= 8 and 62 <= y <= 85 and abs(x + (y - 84) * 0.55) <= 2.0, PAPER)
    # 玉带
    v.frustum(0, 0, 57, 60, 16, 16, PAPER2, zs=0.66)
    v.box((-3, 56, 10), (3, 61, 11), RED)
    # 宽袖、手
    v.cap((18, 80, 0), (27, 54, 12), 6, 10.5, INK, j=0.02)
    v.cap((-18, 80, 0), (-25, 56, 4), 6, 10.5, INK, j=0.02)
    v.ell((27, 50, 13), (4, 4, 4), GRAY2)
    v.ell((-25, 51, 5), (4, 4, 4), GRAY2)
    # 头：白面具，朱砂眼，墨眉，黑须
    v.ell((0, 92, 2), (8.5, 9.5, 7.5), PAPER)
    v.front_box(-5, -2, 93, 94, RED, glow=True)
    v.front_box(2, 5, 93, 94, RED, glow=True)
    v.front_box(-6, -2, 96, 96, INK)
    v.front_box(2, 6, 96, 96, INK)
    v.front_box(-2, 2, 88, 88, INK3)
    v.frustum(0, 7, 73, 87, 2, 7, INK, zs=0.6)
    # 乌纱帽，两边帽翅
    v.box((-9, 99, -6), (9, 107, 7), INK)
    v.ell((0, 107, 0), (8, 4, 6), INK)
    v.box((9, 103, 0), (24, 104, 1), INK)
    v.box((-24, 103, 0), (-9, 104, 1), INK)
    v.box((22, 101, 0), (26, 106, 1), INK2)
    v.box((-26, 101, 0), (-22, 106, 1), INK2)
    # 判官笔：杆上朱红箍，笔头白毫朱砂尖
    v.cap((24, 78, 6), (31, 22, 22), 1.8, 1.8, INK2)
    for t in (0.15, 0.5):
        p = (24 + 7 * t, 78 - 56 * t, 6 + 16 * t)
        v.ell(p, (2.4, 2.4, 2.4), RED)
    v.cap((31, 22, 22), (33, 10, 27), 4.2, 1.0, PAPER, j=0.03)
    v.cap((32.5, 13, 26), (33, 8, 28), 2.0, 0.6, RED, glow=True)
    v.ground_clip()
    return v.dump(os.path.join(out, "boss"), VS)


PVS = VS * 2


def pine(out, seed=0, h=80):
    v = V(40 + seed)
    pts = []
    x = z = 0.0
    for i in range(9):
        t = i / 8
        pts.append((x, t * h * 0.82, z))
        x += (2.5 if i % 2 == 0 else -1.8) + seed * 0.4
        z += 0.6 if i % 3 else -0.9
    v.chain(pts, 4.2, 1.6, INK, j=0.05)
    pads = [(0.45, 13, -1), (0.62, -11, 1), (0.8, 9, 1), (0.95, -4, -1)]
    for (t, dx, s) in pads:
        base = pts[int(t * 8)]
        c = (base[0] + dx, t * h * 0.82 + 3, base[2] + s * 2)
        v.cap(base, c, 1.6, 1.0, INK)
        rx = 12 - t * 4
        v.ell(c, (rx, 3.2, rx * 0.75), INK2, j=0.06, rough=0.35, seed=seed + t * 9)
    for p in v.tops():
        if v.c[p] == INK2 or abs(v.c[p][0] - INK2[0]) < 12:
            if p[1] > 20 and nz(p[0] * 1.5, p[1], p[2] * 1.5, seed) > 0.1:
                v.put(p, GRAY if nz(*p, seed + 3) > 0.2 else INK3, 0.05)
    # 根
    for a in range(5):
        ang = a / 5 * math.tau + seed
        v.cap((0, 2, 0), (math.cos(ang) * 6, 0, math.sin(ang) * 5), 2.4, 1.2, INK)
    v.ground_clip()
    return v.dump(os.path.join(out, "pine%d" % seed), PVS)


def rock(out, seed=0, s=1.0):
    v = V(50 + seed)
    blobs = [((0, 6, 0), (12, 9, 9)), ((7, 4, 3), (7, 6, 6)), ((-6, 3, 2), (8, 5, 6)), ((2, 13, -1), (6, 6, 5))]
    for (c, r) in blobs:
        v.ell(tuple(a * s for a in c), tuple(a * s for a in r), INK2, j=0.06, rough=0.45, seed=seed)
    # 皴法：竖向淡墨条纹；顶面留白
    v.paint(lambda x, y, z: nz(x * 2.5, y * 0.4, z * 2.5, seed + 2) > 0.45, INK3)
    ymax = max(p[1] for p in v.c)
    for p in v.tops():
        if p[1] > ymax * 0.55 and nz(*p, seed + 4) > 0.0:
            v.put(p, PAPER2 if p[1] > ymax * 0.8 else GRAY2, 0.04)
    v.ground_clip()
    return v.dump(os.path.join(out, "rock%d" % seed), PVS)


def wall(out):
    """粉墙黛瓦一段，中间开月洞门"""
    v = V(60)
    W, H, D = 46, 34, 4
    v.box((-W, 0, -D), (W, 5, D), GRAY, j=0.05)
    v.box((-W, 6, -D + 1), (W, H, D - 1), PAPER, j=0.02)
    # 墙面水渍
    v.paint(lambda x, y, z: 6 <= y <= H and nz(x * 0.6, y * 1.4, z, 2) > 0.55, PAPER2)
    # 月洞门
    v.carve(lambda x, y, z: (x / 13.0) ** 2 + ((y - 15) / 14.0) ** 2 < 1.0 and y >= 0)
    v.paint(lambda x, y, z: 0.86 < (x / 13.0) ** 2 + ((y - 15) / 14.0) ** 2 < 1.28 and abs(z) >= D - 1, GRAY2)
    # 瓦顶：两坡，瓦垄一黑一深灰，两端起翘
    for y in range(H + 1, H + 8):
        k = y - H - 1
        half = 8 - k
        lift = lambda x: int(max(0, (abs(x) - (W - 8)) * 0.6))
        for x in range(-W - 3, W + 4):
            col = INK if (x // 2) % 2 == 0 else INK2
            for z in range(-half, half + 1):
                v.put((x, y + lift(x), z), col)
    v.box((-W - 4, H + 8, -1), (W + 4, H + 9, 1), INK)
    v.box((W + 2, H + 9, -1), (W + 6, H + 13, 1), INK)
    v.box((-W - 6, H + 9, -1), (-W - 2, H + 13, 1), INK)
    v.ground_clip()
    return v.dump(os.path.join(out, "wall"), PVS)


def maple(out):
    v = V(70)
    v.chain([(0, 0, 0), (2, 14, 0), (-1, 26, 1), (1, 34, 0)], 2.6, 1.2, INK)
    v.cap((1, 22, 0), (9, 30, 2), 1.4, 0.8, INK)
    v.cap((0, 26, 0), (-8, 33, -1), 1.4, 0.8, INK)
    for (c, r) in [((0, 38, 0), (11, 7, 9)), ((9, 32, 2), (7, 5, 6)), ((-8, 34, -1), (7, 5, 6))]:
        v.ell(c, r, lambda x, y, z: RED if nz(x, y, z, 3) > -0.1 else RED2, j=0.08, rough=0.5, seed=3)
    v.carve(lambda x, y, z: y > 28 and nz(x * 1.7, y * 1.7, z * 1.7, 9) > 0.55)
    return v.dump(os.path.join(out, "maple"), PVS)


def lantern(out):
    """石灯：叠起来的灰石，灯室里一点暖光"""
    v = V(80)
    v.box((-5, 0, -5), (5, 2, 5), GRAY)
    v.box((-2, 3, -2), (2, 14, 2), GRAY2, j=0.05)
    v.box((-5, 15, -5), (5, 16, 5), GRAY)
    v.box((-4, 17, -4), (4, 22, 4), GRAY2)
    v.box((-3, 18, -5), (3, 21, 5), PAPER, glow=True)
    v.box((-5, 18, -3), (5, 21, 3), PAPER, glow=True)
    for y in range(23, 27):
        r = 7 - (y - 23) * 1.6
        v.frustum(0, 0, y, y, r, r, INK2)
    v.box((0, 27, 0), (0, 29, 0), INK2)
    return v.dump(os.path.join(out, "lantern"), PVS)


def stele(out):
    v = V(90)
    v.box((-9, 0, -5), (9, 3, 5), GRAY)
    v.box((-6, 4, -2), (6, 34, 2), INK3, j=0.04)
    v.ell((0, 34, 0), (6, 3, 2), INK3)
    for col in (-3, 0, 3):
        for y in range(10, 30, 3):
            if nz(col, y, 0, 1) > -0.3:
                v.box((col, y, 3), (col + 1, y + 1, 3), PAPER2)
    v.carve(lambda x, y, z: x > 2 and y > 26 and nz(x, y, z, 5) > 0.1)
    return v.dump(os.path.join(out, "stele"), PVS)


GVS = VS * 4


def ground(out, w=16.0, d=12.0):
    v = V(100)
    nx, nzc = int(w / GVS / 2), int(d / GVS / 2)
    for x in range(-nx, nx + 1):
        for z in range(-nzc, nzc + 1):
            n = nz(x * 0.8, 0, z * 0.8, 1)
            h = 1
            # 前景一汪墨潭
            pond = ((x - 34) / 13.0) ** 2 + ((z - 16) / 7.0) ** 2
            if pond < 1:
                v.put((x, 0, z), INK if pond < 0.8 else INK2)
                continue
            for y in range(h):
                n2 = nz(x * 0.45, y, z * 2.6, 4)   # 横向的干笔擦痕
                n3 = nz(x * 0.7, 0, z * 0.7, 9)
                col = PAPER2 if n2 < 0.15 else (mix(PAPER2, GRAY2, 0.6) if n2 < 0.45 else (GRAY2 if n2 < 0.62 else GRAY))
                if n3 > 0.5:
                    col = mix(col, INK3, 0.45)
                rr = (x / nx) ** 2 + (z / nzc) ** 2   # 四周晕开的淡墨
                col = mix(col, GRAY, max(0.0, rr - 0.35) * 0.8 + max(0.0, n) * 0.25)
                v.put((x, y, z), col, 0.025)
    # 石板小路
    for i in range(-30, 30, 3):
        cz = int(5 + math.sin(i * 0.08) * 4)
        v.box((i, 1, cz - 1), (i + 1, 1, cz + 1), GRAY, 0.06)
    return v.dump(os.path.join(out, "ground"), GVS)


def slash(out):
    """杀招一道：墨痕弧，末端甩出朱砂点"""
    v = V(110)
    for i in range(60):
        t = i / 59
        a = -1.2 + t * 2.6
        r = 26
        th = 2.4 * math.sin(t * math.pi) + 0.3
        p = (math.cos(a) * r, 22 + t * 6, math.sin(a) * r)
        v.ell(p, (th, th * 0.6, th), INK)
    for (x, y, z) in ((24, 30, 12), (26, 33, 15), (21, 26, 18), (28, 29, 9)):
        v.ell((x, y, z), (1.2, 1.2, 1.2), RED, glow=True)
    return v.dump(os.path.join(out, "slash"), VS)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    print("hero", hero(out))
    for s in range(3):
        print("grunt", grunt(out, s, 1.0 - s * 0.2))
    print("boss", boss(out))
    for s in range(2):
        print("pine", pine(out, s, 80 + s * 14))
    for s in range(3):
        print("rock", rock(out, s, 0.7 + s * 0.3))
    print("wall", wall(out))
    print("maple", maple(out))
    print("lantern", lantern(out))
    print("stele", stele(out))
    print("ground", ground(out))
    print("slash", slash(out))
