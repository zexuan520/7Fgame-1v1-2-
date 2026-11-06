"""方案 C「青绿」：青绿山水微缩。矿物颜料的石青、石绿、赭石、泥金、朱砂，日光明亮，像桌上摆的一盘工笔沙盘。
角色 1:5 写实比例、细体素（身高 96 格，一格 1.85 厘米），衣纹、兵器、纹样都能刻出来；场景件两倍粗、地面四倍粗。"""
import math
import os
import sys

from vlib import V, hx, mix, mul, nz

QING = hx("2f6f9f")      # 石青
QING2 = hx("1f4f78")
LV = hx("3f9a7a")        # 石绿
LV2 = hx("2a6e58")
LV3 = hx("74c09a")
ZHE = hx("a8653c")       # 赭石
ZHE2 = hx("7a4428")
JIN = hx("d8b45a")       # 泥金
JIN2 = hx("9c7a34")
ZHU = hx("c23b30")       # 朱砂
WHITE = hx("efe9dc")
WHITE2 = hx("d6cebd")
SKIN = hx("ecceac")
HAIR = hx("1b1a20")
BRZ = hx("3f7e6c")       # 铜锈
BRZ2 = hx("2c5a4e")
DARK = hx("1c2a2a")
STEEL = hx("e3ebee")
WOOD = hx("5a3b28")

VS = 0.0185


def hero(out):
    v = V(1)
    # 腿（被长袍盖住大半）、靴
    v.cap((-5, 40, 0), (-7, 4, 3), 4.2, 3.6, QING2)
    v.cap((5, 40, 0), (9, 4, -3), 4.2, 3.6, QING2)
    v.box((-10, 0, 0), (-4, 3, 8), HAIR)
    v.box((6, 0, -7), (12, 3, 1), HAIR)
    # 外袍：白，下摆石青宽边，前开衩露出石青内袍
    v.frustum(0, 0, 6, 48, 15, 10, WHITE, j=0.02, zs=0.78,
              keep=lambda x, y, z: not (z > 5 and abs(x - (48 - y) * 0.12) < 3.5 and y < 40))
    v.paint(lambda x, y, z: y <= 11, QING)
    v.paint(lambda x, y, z: y == 12, JIN)
    v.frustum(0, 0, 8, 46, 11, 9, QING, zs=0.7)
    # 上身、交领（石青领缘）、腰带、玉佩和朱红穗
    v.frustum(0, 0, 46, 70, 10, 12, WHITE, j=0.02, zs=0.6)
    v.paint(lambda x, y, z: z >= 4 and 54 <= y <= 71 and abs(x + (y - 70) * 0.55) <= 1.6, QING)
    v.frustum(0, 0, 46, 49, 10.6, 10.6, QING2, zs=0.64)
    v.front_box(-1, 1, 47, 48, JIN)
    v.box((-4, 36, 7), (-3, 45, 7), JIN2)
    v.ell((-3.5, 34, 7), (2, 2.4, 1), LV3)
    v.cap((-3.5, 31, 7), (-4, 24, 7), 0.9, 0.6, ZHU)
    # 广袖：右手持剑外展，左手背后
    v.cap((12, 68, 0), (22, 55, 9), 3.6, 6.5, WHITE, j=0.02)
    v.paint(lambda x, y, z: x > 17 and ((x - 22) ** 2 + (y - 55) ** 2 + (z - 9) ** 2) < 49 and ((x - 22) ** 2 + (y - 55) ** 2 + (z - 9) ** 2) > 25, QING)
    v.ell((24, 52, 11), (2.4, 2.4, 2.4), SKIN)
    v.cap((-12, 68, 0), (-17, 50, -6), 3.6, 7, WHITE, j=0.02)
    v.paint(lambda x, y, z: x < -13 and y < 50, QING)
    # 飘带：石青绸带从左肘绕到身后、飘向右后
    pts = []
    for i in range(22):
        t = i / 21
        pts.append((-17 + 40 * t, 52 + 10 * math.sin(t * 3.4) - 4 * t, -10 - 6 * math.sin(t * 2.0)))
    v.chain(pts, 1.4, 1.0, QING, j=0.03)
    # 颈、头、发、冠
    v.box((-2, 70, -2), (2, 73, 2), SKIN)
    v.ell((0, 80, 0.5), (6.6, 8, 6.6), SKIN)
    v.ell((0, 81, -0.5), (7.1, 8.4, 7.1), HAIR, keep=lambda x, y, z: z < -1 or y > 84 or (abs(x) > 5 and y > 76))
    v.cap((0, 80, -5), (-2, 54, -11), 5.5, 2.5, HAIR)
    v.box((-2, 88, -2), (2, 91, 2), JIN)
    v.cap((-6, 89, 0), (6, 89, 0), 0.6, 0.6, JIN2)
    for sx in (-1, 1):
        v.front(sx * 3, 80, HAIR)
        v.front(sx * 2, 80, HAIR)
        v.front(sx * 3, 82, HAIR)
        v.front(sx * 4, 82, HAIR)
    v.front(0, 75, hx("b06050"))
    # 剑：细长，剑格泥金，挂朱红穗
    v.cap((26, 52, 12), (46, 62, 26), 1.1, 0.7, STEEL)
    v.box((24, 50, 10), (26, 54, 13), JIN)
    v.cap((23, 51, 11), (19, 48, 9), 1.0, 1.0, WOOD)
    v.chain([(19, 48, 9), (18, 42, 10), (19, 36, 11)], 0.9, 0.6, ZHU)
    v.ground_clip()
    return v.dump(os.path.join(out, "hero"), VS)


def mask(v, cx, y0, w):
    """饕餮面：泥金底，凸起的眉骨和鼻梁，圆眼朱砂瞳，两颊卷云纹，獠牙"""
    k = w / 6.0
    v.front_box(cx - w, cx + w, y0, y0 + int(11 * k), JIN2)
    for sx in (-1, 1):
        ex = cx + sx * int(3 * k)
        ey = y0 + int(6 * k)
        for dx in range(-int(k) - 1, int(k) + 1):
            for dy in range(-int(k), int(k) + 1):
                v.front(ex + dx, ey + dy, DARK)
        v.front(ex, ey, ZHU, glow=True)
        v.front(ex - (1 if sx > 0 else 0), ey, ZHU, glow=True)
        for i in range(int(4 * k) + 1):   # 眉骨往外上挑
            v.bump(cx + sx * (1 + i), ey + int(2 * k) + i // 2, JIN)
        for (dx, dy) in ((5, 2), (5, 3), (4, 3), (6, 4), (6, 1)):   # 卷云纹
            v.front(cx + sx * int(dx * k), y0 + int(dy * k), DARK)
        v.bump(cx + sx * int(2 * k), y0, hx("efe2b0"))   # 獠牙
    for y in range(y0 + int(2 * k), y0 + int(8 * k)):
        v.bump(cx, y, JIN)
    v.front_box(cx - int(3 * k), cx + int(3 * k), y0 + 1, y0 + 1, DARK)


def grunt(out, seed=0):
    """铜傀：青铜甲士，甲片一排排，饕餮纹面具，执戟"""
    v = V(10 + seed)
    lam = lambda x, y, z: (BRZ if y % 4 < 2 else BRZ2) if nz(x, y, z, seed, 1.4) < 0.72 else JIN2
    v.box((-8, 0, -3), (-3, 4, 6), BRZ2)
    v.box((3, 0, -6), (8, 4, 3), BRZ2)
    v.cap((-5, 38, 0), (-6, 4, 2), 4, 3.6, DARK)
    v.cap((5, 38, 0), (6, 4, -2), 4, 3.6, DARK)
    v.box((-7, 10, -2), (-3, 22, 4), BRZ)
    v.box((3, 10, -4), (7, 22, 2), BRZ)
    # 甲裙 + 身甲
    v.frustum(0, 0, 26, 42, 13, 11, lam, zs=0.75)
    v.frustum(0, 0, 42, 66, 11, 13, lam, zs=0.62)
    v.paint(lambda x, y, z: y % 4 == 0 and (x + y) % 6 == 0, JIN)
    v.frustum(0, 0, 41, 43, 11.6, 11.6, JIN2, zs=0.66)
    # 护肩、臂
    v.ell((13, 64, 0), (6, 4, 6), BRZ)
    v.ell((-13, 64, 0), (6, 4, 6), BRZ)
    v.cap((14, 62, 0), (17, 44, 8), 3.4, 3.2, DARK)
    v.cap((-14, 62, 0), (-16, 46, 4), 3.4, 3.2, DARK)
    v.ell((17, 42, 9), (2.6, 2.6, 2.6), BRZ2)
    v.ell((-16, 44, 5), (2.6, 2.6, 2.6), BRZ2)
    # 头盔 + 饕餮面具
    v.box((-6, 68, -6), (6, 82, 6), BRZ, j=0.03)
    v.frustum(0, 0, 82, 86, 7, 2, BRZ2)
    v.box((0, 86, 0), (0, 92, 0), ZHU)
    mask(v, 0, 70, 6)
    v.box((-7, 82, -7), (7, 82, 7), JIN)
    # 戟：长杆、侧刃
    v.cap((18, 2, 10), (20, 108, 12), 1.0, 1.0, WOOD)
    v.cap((20, 108, 12), (20, 118, 12), 1.6, 0.3, JIN)
    v.box((21, 96, 11), (29, 100, 13), JIN, keep=lambda x, y, z: (x - 21) * 0.5 <= (y - 96))
    v.ground_clip()
    return v.dump(os.path.join(out, "grunt%d" % seed), VS)


def boss(out):
    """铜甲将：高一丈，双角兽盔，朱红披风，扛一柄钺"""
    v = V(30)
    lam = lambda x, y, z: (BRZ if y % 5 < 3 else BRZ2) if nz(x, y, z, 1, 1.0) < 0.7 else JIN2
    v.box((-16, 0, -6), (-6, 7, 12), BRZ2)
    v.box((6, 0, -10), (16, 7, 8), BRZ2)
    v.cap((-10, 60, 0), (-11, 6, 3), 7, 6, DARK)
    v.cap((10, 60, 0), (11, 6, -1), 7, 6, DARK)
    v.box((-15, 14, -4), (-6, 34, 8), lam)
    v.box((6, 14, -6), (15, 34, 6), lam)
    # 披风（身后）
    v.frustum(0, -8, 8, 112, 26, 22, ZHU, zs=0.35, keep=lambda x, y, z: z < -7 and not (y < 20 and nz(x, y, z, 4, 1.6) > 0.25))
    v.paint(lambda x, y, z: z < -7 and nz(x * 0.6, y * 1.6, z, 6) > 0.5, hx("9a2a22"))
    # 甲
    v.frustum(0, 0, 44, 66, 21, 18, lam, zs=0.7)
    v.frustum(0, 0, 66, 108, 18, 24, lam, zs=0.62)
    v.frustum(0, 0, 64, 68, 19, 19, JIN, zs=0.66)
    v.front_box(-5, 5, 61, 69, JIN2)
    v.front_box(-3, 3, 63, 67, ZHU)
    v.ell((0, 90, 9), (12, 10, 4), JIN2)   # 护心镜
    v.ell((0, 90, 11), (7, 6, 2), JIN)
    v.front_box(-2, 2, 88, 92, QING)
    # 兽头护肩
    for sx in (-1, 1):
        v.ell((sx * 24, 104, 0), (9, 7, 9), BRZ)
        v.front_box(sx * 24 - 3, sx * 24 + 3, 102, 105, JIN)
        v.front(sx * 24 - 2, 104, ZHU, glow=True)
        v.front(sx * 24 + 2, 104, ZHU, glow=True)
    v.cap((26, 100, 0), (34, 72, 10), 6, 5.6, DARK)
    v.cap((-26, 100, 0), (-30, 72, 6), 6, 5.6, DARK)
    v.ell((34, 68, 12), (4.5, 4.5, 4.5), BRZ2)
    v.ell((-30, 68, 8), (4.5, 4.5, 4.5), BRZ2)
    # 兽盔、双角、面具
    v.box((-10, 110, -9), (10, 132, 10), BRZ, j=0.03)
    mask(v, 0, 112, 10)
    v.box((-11, 130, -10), (11, 131, 11), JIN)
    for sx in (-1, 1):
        v.chain([(sx * 9, 128, 0), (sx * 16, 136, -2), (sx * 18, 146, -6), (sx * 15, 152, -10)], 3.2, 1.0, JIN)
    # 钺：长柄扛在右肩，宽刃
    v.cap((36, 66, 13), (16, 150, -8), 1.6, 1.6, WOOD)
    v.ell((22, 140, -4), (12, 14, 2.5), JIN, keep=lambda x, y, z: x > 20)
    v.paint(lambda x, y, z: x > 30 and y > 128 and 126 < y < 154 and z > -8 and z < 0, STEEL)
    v.ground_clip()
    return v.dump(os.path.join(out, "boss"), VS)


PVS = VS * 2


def peak(out, seed=0, h=70):
    """青绿山石：层层叠起的石柱，越往上越绿越蓝，脚下赭石"""
    v = V(40 + seed)
    y = 0
    cx = cz = 0.0
    r = 18
    while y < h:
        layer_h = v.r.randint(6, 10)
        v.ell((cx, y + layer_h * 0.5, cz), (r, layer_h * 0.75, r * 0.8), ZHE, j=0.05, rough=0.35, seed=seed + y)
        y += layer_h - 2
        cx += v.r.uniform(-3, 3)
        cz += v.r.uniform(-2, 2)
        r = max(5, r - v.r.uniform(1.0, 3.0))
    ymax = max(p[1] for p in v.c)
    for p in list(v.c):
        t = p[1] / ymax
        if nz(p[0] * 2, p[1] * 0.4, p[2] * 2, seed) > 0.4:
            v.put(p, ZHE2)
    for p in v.tops():
        t = p[1] / ymax
        v.put(p, mix(LV, QING, t * 1.2) if t > 0.15 else LV2, 0.05)
        below = (p[0], p[1] - 1, p[2])
        if below in v.c and t > 0.2:
            v.put(below, mix(LV2, QING2, t))
    # 顶上一棵小松
    top = max(v.c, key=lambda p: p[1])
    v.cap(top, (top[0] + 2, top[1] + 8, top[2]), 1.0, 0.6, WOOD)
    v.ell((top[0] + 2, top[1] + 9, top[2]), (5, 2, 4), LV2)
    v.ground_clip()
    return v.dump(os.path.join(out, "peak%d" % seed), PVS)


def pine(out, seed=0, h=74):
    v = V(50 + seed)
    pts = []
    x = 0.0
    for i in range(8):
        t = i / 7
        pts.append((x, t * h * 0.85, 0))
        x += 2.0 if i % 2 == 0 else -1.4
    v.chain(pts, 3.6, 1.4, ZHE2, j=0.05)
    for (t, dx, dz) in ((0.5, 12, 2), (0.65, -10, -2), (0.82, 8, 3), (0.98, -2, 0)):
        b = pts[min(7, int(t * 7))]
        c = (b[0] + dx, t * h * 0.85 + 3, b[2] + dz)
        v.cap(b, c, 1.4, 0.8, ZHE2)
        rx = 11 - t * 4
        v.ell(c, (rx, 3, rx * 0.8), LV2, j=0.06, rough=0.35, seed=seed + t * 5)
    for p in v.tops():
        if p[1] > 25 and v.c[p][1] > 80:
            v.put(p, LV3 if nz(*p, seed) > 0.2 else LV, 0.04)
    v.ground_clip()
    return v.dump(os.path.join(out, "pine%d" % seed), PVS)


def pavilion(out):
    """亭子一角：白石台基、朱柱、泥金额枋、石青瓦顶、翘角"""
    v = V(60)
    v.box((-24, 0, -20), (24, 5, 20), WHITE2, j=0.03)
    v.box((-26, 0, -22), (26, 1, 22), hx("b9b1a0"))
    for x in (-19, 19):
        for z in (-15, 15):
            v.box((x - 2, 6, z - 2), (x + 2, 44, z + 2), ZHU, j=0.03)
    v.box((-22, 44, -18), (22, 48, 18), JIN2)
    v.box((-22, 45, 17), (22, 47, 18), QING)
    for x in range(-20, 21, 4):
        v.box((x, 45, 19), (x + 1, 47, 19), JIN)
    for y in range(49, 68):
        k = y - 49
        half = 32 - k * 1.7
        if half < 1:
            break
        for x in range(-int(half), int(half) + 1):
            for z in range(-int(half * 0.85), int(half * 0.85) + 1):
                edge = max(abs(x) / half, abs(z) / (half * 0.85))
                if edge > 0.86 or k == 18:
                    col = QING if (x // 2 + z // 2) % 2 == 0 else QING2
                    v.put((x, y, z), col, 0.03)
    for sx in (-1, 1):
        for sz in (-1, 1):
            v.chain([(sx * 30, 50, sz * 26), (sx * 35, 52, sz * 30), (sx * 37, 56, sz * 32)], 1.6, 0.8, JIN)
    v.box((-1, 68, -1), (1, 74, 1), JIN)
    return v.dump(os.path.join(out, "pavilion"), PVS)


def bridge(out):
    v = V(70)
    for x in range(-34, 35):
        y = int(14 * (1 - (x / 34.0) ** 2)) + 2
        v.box((x, max(0, y - 3), -8), (x, y, 8), WHITE2, j=0.03)
        if abs(x) % 6 == 0:
            v.box((x, y + 1, -8), (x, y + 5, -8), WHITE)
            v.box((x, y + 1, 8), (x, y + 5, 8), WHITE)
        v.put((x, y + 4, -8), WHITE)
        v.put((x, y + 4, 8), WHITE)
    v.carve(lambda x, y, z: (x / 18.0) ** 2 + (y / 10.0) ** 2 < 1)
    return v.dump(os.path.join(out, "bridge"), PVS)


def flowers(out):
    v = V(80)
    r = v.r
    for i in range(26):
        x, z = r.randint(-12, 12), r.randint(-10, 10)
        hgt = r.randint(2, 6)
        v.box((x, 0, z), (x, hgt, z), LV2)
        col = [ZHU, WHITE, JIN, hx("d77fa0")][i % 4]
        v.put((x, hgt + 1, z), col)
        v.put((x + 1, hgt, z), col)
    return v.dump(os.path.join(out, "flowers"), PVS)


GVS = VS * 4


def ground(out, w=16.0, d=12.0):
    v = V(100)
    nx, nzc = int(w / GVS / 2), int(d / GVS / 2)
    for x in range(-nx, nx + 1):
        for z in range(-nzc, nzc + 1):
            # 右前方一湾水（桥架在上面），中间一条赭石小路，其余是草
            river = abs(z - 24 - 9 * math.sin(x * 0.05) + x * 0.18) < 9 and x > 20
            path = abs(z - 8 - 6 * math.sin(x * 0.04)) < 4
            n = nz(x * 1.4, 0, z * 1.4, 1)
            if river:
                col = mix(QING2, QING, 0.5 + 0.5 * nz(x * 2, 0, z * 0.6, 3))
                if nz(x * 3, 0, z * 1.2, 5) > 0.6:
                    col = hx("8fc4d8")
                v.put((x, 0, z), col)
                continue
            if path:
                col = mix(hx("c09060"), ZHE, 0.3 + 0.3 * n)
            else:
                col = mix(hx("8f9a66"), hx("6e8256"), 0.5 + 0.5 * n)
                n2 = nz(x * 0.9, 0, z * 0.9, 7)
                if n2 > 0.45:
                    col = mix(col, hx("b39a6c"), 0.6)      # 赭色地皮
                elif n2 < -0.5:
                    col = mix(col, LV2, 0.5)
            v.put((x, 0, z), col, 0.03)
            v.put((x, 1, z), col, 0.03)
    return v.dump(os.path.join(out, "ground"), GVS)


def slash(out):
    """剑光：泥金绸带一样的弧"""
    v = V(110)
    for i in range(70):
        t = i / 69
        a = -1.2 + t * 2.6
        r = 46
        th = 2.6 * math.sin(t * math.pi) + 0.3
        p = (math.cos(a) * r, 40 + t * 12, math.sin(a) * r)
        v.ell(p, (th, th * 0.35, th), mix(JIN, hx("fff3cc"), t), glow=True)
    return v.dump(os.path.join(out, "slash"), VS)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    print("hero", hero(out))
    for s in range(3):
        print("grunt", grunt(out, s))
    print("boss", boss(out))
    for s in range(3):
        print("peak", peak(out, s, 60 + s * 16))
    for s in range(2):
        print("pine", pine(out, s, 70 + s * 10))
    print("pavilion", pavilion(out))
    print("bridge", bridge(out))
    print("flowers", flowers(out))
    print("ground", ground(out))
    print("slash", slash(out))
