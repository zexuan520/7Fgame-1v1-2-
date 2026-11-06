"""方案 B「夜灯」：暗夜灯火 + Q 版大头。靛蓝、深紫打底，暖黄灯火和青玉色是两种发光色，红灯笼是题眼。
角色 1:2.5 大头（身高 40 格，一格 3.5 厘米），轮廓粗、手机上一眼认得出；场景件两倍粗、地面四倍粗。"""
import math
import os
import sys

from vlib import V, hx, mix, mul, nz

IND = hx("1d2240")
IND2 = hx("2a3156")
PURP = hx("3a2d5c")
PURP2 = hx("54437e")
TEAL = hx("2f7a72")
TEAL2 = hx("1f5550")
GOLD = hx("e2b04a")
GOLD2 = hx("9c7430")
SKIN = hx("f0d2b0")
HAIR = hx("1a1420")
WHITE = hx("f4efe6")
AMBER = hx("ffb245")
JADE = hx("6ff0c4")
RED = hx("e0452f")
RED2 = hx("8a2a22")
BONE = hx("d9cdb0")
BONE2 = hx("a39880")
DARK = hx("15121f")
WOOD = hx("4a3428")
STEEL = hx("cfe0ea")
MOSS = hx("2e5a4c")

VS = 0.035


def hero(out):
    v = V(1)
    # 短腿、靴
    v.box((-4, 0, -2), (-1, 7, 2), IND)
    v.box((1, 0, -2), (4, 7, 2), IND)
    v.box((-4, 0, -2), (-1, 2, 3), DARK)
    v.box((1, 0, -2), (4, 2, 3), DARK)
    # 青色短褂，金边
    v.frustum(0, 0, 6, 20, 7.5, 6, TEAL, j=0.03, zs=0.8)
    v.paint(lambda x, y, z: y <= 7, GOLD)
    v.paint(lambda x, y, z: z >= 4 and abs(x + (y - 19) * 0.4) <= 0.8 and y > 7, GOLD)
    v.frustum(0, 0, 12, 13, 7.2, 7.2, hx("6b3b2a"), zs=0.82)
    # 胸前青玉坠（发光）
    v.front(1, 15, JADE, glow=True)
    v.front(1, 16, JADE, glow=True)
    # 腰间小红灯笼
    v.ell((7.5, 8, 3), (2.4, 3, 2.4), RED, glow=True)
    v.box((6, 11, 2), (9, 11, 4), GOLD)
    v.box((6, 5, 2), (9, 5, 4), GOLD)
    v.box((7, 12, 3), (7, 13, 3), GOLD)
    # 手
    v.cap((6.5, 18, 0), (10, 11, 4), 2.3, 2.3, TEAL)
    v.ell((10.5, 10, 5), (1.8, 1.8, 1.8), SKIN)
    v.cap((-6.5, 18, 0), (-9, 11, 1), 2.3, 2.3, TEAL)
    v.ell((-9.5, 10, 1.5), (1.8, 1.8, 1.8), SKIN)
    # 大头
    v.ell((0, 29, 0.5), (9, 9, 8.2), SKIN)
    v.ell((0, 30, 0), (9.7, 9.7, 8.9), HAIR,
          keep=lambda x, y, z: y >= 33 or z < -1 or (abs(x) >= 7 and y >= 23) or (y >= 31 and (x + 9) % 5 < 3))
    # 发髻 + 青色发带
    v.ell((0, 40, -2), (3.4, 3, 3.4), HAIR)
    v.box((-3, 38, -2), (3, 38, 1), TEAL)
    v.chain([(3, 38, -4), (6, 35, -8), (8, 31, -10)], 1.0, 0.7, TEAL)
    # 眼睛（墨色 2×3，带高光）、腮红、小嘴
    for sx in (-1, 1):
        for x in (3, 4):
            for y in (26, 27, 28):
                v.front(sx * x, y, hx("2a1a20"))
        v.front(sx * 3 if sx > 0 else -4, 28, WHITE)
        v.front(sx * 6, 25, hx("f0a090"))
    v.front(0, 24, hx("b06050"))
    # 刀：向前上挑，刀刃一点青光
    v.cap((11, 10, 6), (16, 26, 10), 1.0, 0.7, STEEL)
    v.cap((15, 23, 10), (16, 26, 10), 0.8, 0.5, JADE, glow=True)
    v.box((10, 11, 5), (12, 12, 7), GOLD)
    v.cap((10, 9, 5), (9, 6, 4), 0.8, 0.8, WOOD)
    v.ground_clip()
    return v.dump(os.path.join(out, "hero"), VS)


def grunt(out, seed=0):
    """灯骨卒：大头骷髅，眼窝里两点灯火，挑一杆挂灯笼的骨矛"""
    v = V(10 + seed)
    v.cap((-3, 8, 0), (-3, 1, 1), 1.3, 1.3, BONE)
    v.cap((3, 8, 0), (3, 1, -1), 1.3, 1.3, BONE)
    v.box((-4, 0, -1), (-2, 1, 3), BONE2)
    v.box((2, 0, -3), (4, 1, 1), BONE2)
    v.box((-4, 8, -2), (4, 10, 2), BONE2)
    # 肋骨：先填暗芯，再一行骨一行缝
    v.frustum(0, 0, 10, 19, 5, 6, DARK, zs=0.75)
    v.paint(lambda x, y, z: 10 <= y <= 19 and y % 3 != 0 and (abs(z) >= 2 or abs(x) >= 4), BONE)
    v.box((0, 10, -4), (0, 19, -3), BONE)
    # 破红布披肩
    v.frustum(0, 0, 15, 20, 7.5, 6.5, RED2, zs=0.8, ring=1.5,
              keep=lambda x, y, z: y > 17 or nz(x, y, z, seed + 1, 2.0) < 0.2)
    # 手臂骨
    v.cap((6, 18, 0), (8, 11, 4), 1.2, 1.2, BONE)
    v.cap((-6, 18, 0), (-7, 11, 2), 1.2, 1.2, BONE)
    # 大骷髅头
    v.ell((0, 27, 0), (7.4, 7, 6.6), BONE, j=0.03)
    v.box((-4, 20, 1), (4, 22, 5), BONE2)
    for x in range(-3, 4, 2):
        v.front(x, 21, DARK)
    for sx in (-1, 1):
        for x in range(2, 5):
            for y in range(25, 29):
                v.front(sx * x, y, DARK, depth=2)
        v.front(sx * 3, 26, AMBER, glow=True)
        v.front(sx * 3, 27, AMBER, glow=True)
    v.front(0, 24, DARK)
    v.paint(lambda x, y, z: y >= 31 and abs(x - 2 - (y - 31)) < 0.6 and z > 0, DARK)   # 裂纹
    # 骨矛挂灯笼
    v.cap((8, 4, 5), (10, 36, 6), 0.7, 0.7, WOOD)
    v.cap((10, 36, 6), (11, 41, 6), 1.2, 0.3, BONE)
    v.box((10, 34, 6), (14, 34, 6), WOOD)
    v.box((14, 31, 6), (14, 33, 6), DARK)
    v.ell((14, 28, 6), (2.2, 2.8, 2.2), RED, glow=True)
    v.box((13, 25, 5), (15, 25, 7), GOLD2)
    v.ground_clip()
    return v.dump(os.path.join(out, "grunt%d" % seed), VS)


def boss(out):
    """灯冢王：圆滚滚的紫袍，脑袋是一盏会说话的大灯笼，背后一杆挑三盏小灯"""
    v = V(30)
    v.ell((0, 24, 0), (24, 26, 20), PURP, j=0.03)
    v.carve(lambda x, y, z: y < 0)
    v.paint(lambda x, y, z: nz(x, y, z, 2, 1.2) > 0.45, PURP2)
    v.paint(lambda x, y, z: y in (6, 7, 30), GOLD)
    v.frustum(0, 0, 0, 3, 22, 22, PURP2, zs=0.85)
    # 胸前一块金牌
    v.front_box(-4, 4, 18, 26, GOLD2)
    v.front_box(-2, 2, 20, 24, GOLD)
    # 胳膊、骨爪
    v.cap((20, 38, 0), (30, 22, 10), 5, 6, PURP)
    v.cap((-20, 38, 0), (-29, 24, 6), 5, 6, PURP)
    for i in range(3):
        v.cap((30, 18, 10 + i * 2), (32, 12, 13 + i * 2), 1.1, 0.6, BONE)
        v.cap((-29, 20, 6 + i * 2), (-31, 14, 9 + i * 2), 1.1, 0.6, BONE)
    # 大灯笼头：竖长的红纱灯，金顶金底、竖骨不发光，底下垂金穗；灯纱上一双墨画的眼
    v.ell((0, 64, 0), (13, 17, 12), RED, glow=True)
    v.paint(lambda x, y, z: y > 47 and (x % 4 == 0) and abs(z) > 5, RED2, glow=False)
    v.frustum(0, 0, 46, 49, 9, 9, GOLD)
    v.frustum(0, 0, 79, 82, 9, 7, GOLD)
    v.box((-1, 83, -1), (1, 86, 1), GOLD2)
    for x in (-6, -2, 2, 6):
        v.box((x, 38, 9), (x, 45, 9), GOLD)
    for sx in (-1, 1):
        for x in range(3, 8):
            v.front(sx * x, 66 + (1 if x in (4, 5, 6) else 0), DARK, depth=2)
            v.front(sx * x, 65, DARK, depth=2)
        v.front(sx * 5, 66, WHITE, glow=True)
    # 背后挑灯杆
    v.cap((-8, 30, -16), (-12, 98, -20), 1.2, 1.2, WOOD)
    v.box((-24, 96, -20), (2, 97, -20), WOOD)
    for x in (-22, -12, 0):
        v.box((x, 90, -20), (x, 95, -20), DARK)
        v.ell((x, 86, -20), (3, 4, 3), AMBER, glow=True)
        v.box((x - 2, 82, -21), (x + 2, 82, -19), GOLD2)
    v.ground_clip()
    return v.dump(os.path.join(out, "boss"), VS)


PVS = VS * 2


def gate(out):
    """牌坊：四柱三间，中间高两边低，金匾、青黑瓦顶、两层翘檐，梁下挂两盏灯"""
    v = V(40)
    for sx in (-1, 1):
        x0 = sx * 38
        v.box((x0 - 2, 0, -2), (x0 + 2, 32, 2), hx("6a2a2a"), j=0.04)
        v.box((x0 - 3, 0, -3), (x0 + 3, 3, 3), hx("3a3c4a"))
        lo, hi = (22, 40) if sx > 0 else (-40, -22)
        v.box((lo, 28, -2), (hi, 30, 2), hx("6a2a2a"))
        v.box((lo, 31, -2), (hi, 32, 2), GOLD2)
        for y in range(33, 38):
            k = y - 33
            for x in range(lo - 4, hi + 5):
                for z in range(-(5 - k), 6 - k):
                    v.put((x, y + int(max(0, (abs(x) - 38) * 0.7)), z), hx("1f2a33") if (x // 2) % 2 == 0 else hx("2a3844"))
    for x in (-22, 22):
        v.box((x - 2, 0, -2), (x + 2, 44, 2), hx("6a2a2a"), j=0.04)
        v.box((x - 3, 0, -3), (x + 3, 3, 3), hx("3a3c4a"))
    v.box((-26, 38, -2), (26, 41, 2), hx("6a2a2a"))
    v.box((-26, 44, -2), (26, 46, 2), GOLD2)
    v.box((-8, 30, 2), (8, 37, 3), GOLD2)
    v.box((-6, 31, 3), (6, 36, 3), DARK)
    for x in range(-4, 5, 2):
        v.box((x, 32, 4), (x, 35, 4), GOLD)
    for y in range(47, 54):
        k = y - 47
        half = 7 - k
        for x in range(-32, 33):
            lift = int(max(0, (abs(x) - 24) * 0.7))
            col = hx("1f2a33") if (x // 2) % 2 == 0 else hx("2a3844")
            for z in range(-half, half + 1):
                v.put((x, y + lift, z), col)
    v.box((-30, 54, -1), (30, 55, 1), DARK)
    for x in (-12, 12):
        v.box((x, 33, 0), (x, 37, 0), DARK)
        v.ell((x, 29, 0), (2.6, 3.4, 2.6), RED, glow=True)
        v.box((x - 2, 25, -1), (x + 2, 25, 1), GOLD)
    return v.dump(os.path.join(out, "gate"), PVS)


def willow(out, seed=0):
    v = V(50 + seed)
    v.chain([(0, 0, 0), (3, 12, 0), (0, 24, 1), (2, 34, 0)], 3.4, 1.8, hx("2a2230"), j=0.05)
    for (a, l) in ((0.3, 12), (2.2, 11), (4.0, 13), (5.3, 10)):
        v.cap((2, 32, 0), (2 + math.cos(a) * l, 38, math.sin(a) * l * 0.8), 1.4, 0.8, hx("2a2230"))
    v.ell((1, 39, 0), (15, 4.5, 12), TEAL2, j=0.08, rough=0.5, seed=seed)
    r = v.r
    for i in range(90):
        a = r.uniform(0, math.tau)
        d = r.uniform(9, 16)
        x, z = 1 + math.cos(a) * d, math.sin(a) * d * 0.8
        top = 38
        ln = r.randint(6, 26)
        col = TEAL2 if r.random() < 0.55 else (MOSS if r.random() < 0.6 else TEAL)
        # 枝条外飘一点
        pts = [(x, top, z), (x * 1.08, top - ln * 0.5, z * 1.08), (x * 1.12, top - ln, z * 1.12)]
        v.chain(pts, 0.6, 0.5, col, 0.08)
    for i in range(7):   # 萤火
        v.put((r.randint(-16, 16), r.randint(10, 30), r.randint(-12, 14)), JADE, glow=True)
    return v.dump(os.path.join(out, "willow%d" % seed), PVS)


def tomb(out, seed=0):
    v = V(60 + seed)
    v.ell((0, 0, 0), (12, 5, 10), hx("2b3040"), j=0.06, rough=0.3, seed=seed)
    v.box((-5, 0, -2), (5, 16, 1), hx("4a4f60"), j=0.05)
    v.ell((0, 16, -0.5), (5, 2, 1.5), hx("4a4f60"))
    v.paint(lambda x, y, z: nz(x, y, z, seed + 3, 1.5) > 0.4, MOSS)
    for y in range(5, 14, 2):
        v.box((-1, y, 2), (0, y, 2), DARK)
    v.box((4, 0, 4), (4, 4, 4), WOOD)
    v.put((4, 5, 4), AMBER, glow=True)
    v.ground_clip()
    return v.dump(os.path.join(out, "tomb%d" % seed), PVS)


def censer(out):
    v = V(70)
    for a in (0, 2.1, 4.2):
        v.cap((math.cos(a) * 6, 0, math.sin(a) * 6), (math.cos(a) * 5, 6, math.sin(a) * 5), 1.2, 1.2, GOLD2)
    v.ell((0, 10, 0), (9, 6, 9), hx("5a4a3a"), j=0.05, keep=lambda x, y, z: y <= 12)
    v.frustum(0, 0, 12, 13, 9, 9, GOLD2)
    v.frustum(0, 0, 13, 13, 7.5, 7.5, AMBER, glow=True)
    for (x, z) in ((-2, 0), (1, 1), (3, -2)):
        v.box((x, 14, z), (x, 22, z), hx("8a6a4a"))
        v.put((x, 23, z), AMBER, glow=True)
    return v.dump(os.path.join(out, "censer"), PVS)


def lanterns(out):
    """两根竹竿拉一根绳，挂一串红灯笼"""
    v = V(80)
    v.box((-20, 0, 0), (-20, 34, 0), WOOD)
    v.box((20, 0, 0), (20, 34, 0), WOOD)
    for x in range(-20, 21):
        y = 33 - int(5 * (1 - (x / 20) ** 2))
        v.put((x, y, 0), DARK)
        if x in (-12, -4, 4, 12):
            v.ell((x, y - 4, 0), (2.4, 3, 2.4), RED, glow=True)
            v.put((x, y - 1, 0), DARK)
            v.box((x - 1, y - 8, -1), (x + 1, y - 8, 1), GOLD)
    return v.dump(os.path.join(out, "lanterns"), PVS)


def wisp(out):
    v = V(90)
    v.ell((0, 26, 0), (2.5, 3, 2.5), hx("7fd4ff"), glow=True)
    v.cap((0, 28, 0), (1, 34, 0), 1.6, 0.3, hx("bfeaff"), glow=True)
    return v.dump(os.path.join(out, "wisp"), VS)


GVS = VS * 4


def ground(out, w=16.0, d=12.0):
    v = V(100)
    nx, nzc = int(w / GVS / 2), int(d / GVS / 2)
    base = hx("1f2338")
    for x in range(-nx, nx + 1):
        for z in range(-nzc, nzc + 1):
            # 大块石板（4×3 格一块，行间错缝），缝里长苔
            row = (z + 100) // 3
            gx = (x + 100 + (row % 2) * 2) % 4 == 0
            gz = (z + 100) % 3 == 0
            k = 1.0 + 0.08 * nz(((x + 100 + (row % 2) * 2) // 4) * 7.0, 0, row * 5.0, 3)
            col = mul(base, k)
            if gx or gz:
                col = mix(mul(base, 0.72), MOSS, 0.35 if nz(x * 1.2, 0, z * 1.2, 2) > 0.2 else 0.0)
            elif nz(x * 0.7, 0, z * 0.7, 2) > 0.55:
                col = mix(col, MOSS, 0.45)
            v.put((x, 0, z), col, 0.02)
    return v.dump(os.path.join(out, "ground"), GVS)


def slash(out):
    """刀光：暖金弧，带火星"""
    v = V(110)
    for i in range(50):
        t = i / 49
        a = -1.2 + t * 2.6
        r = 22
        th = 1.8 * math.sin(t * math.pi) + 0.3
        p = (math.cos(a) * r, 14 + t * 4, math.sin(a) * r)
        v.ell(p, (th, th * 0.5, th), mix(AMBER, hx("fff0c0"), t), glow=True)
    for k in range(10):
        a = v.r.uniform(-1.0, 1.4)
        v.put((int(math.cos(a) * 26), v.r.randint(10, 24), int(math.sin(a) * 26)), AMBER, glow=True)
    return v.dump(os.path.join(out, "slash"), VS)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    print("hero", hero(out))
    for s in range(3):
        print("grunt", grunt(out, s))
    print("boss", boss(out))
    print("gate", gate(out))
    for s in range(2):
        print("willow", willow(out, s))
        print("tomb", tomb(out, s))
    print("censer", censer(out))
    print("lanterns", lanterns(out))
    print("wisp", wisp(out))
    print("ground", ground(out))
    print("slash", slash(out))
