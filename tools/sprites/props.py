"""房间里的摆设和能站的结构（RoomProps）的像素画。

尺寸和平台高度跟 scripts/room_props.gd 里的 PLATFORMS、RAMPS 一一对应：
每个件的 origin 是摆设的 (x, 地面)，画的时候所有坐标都写成相对 origin 的偏移（dx 向右，dy 向上为负）。
摆设不翻转（楼梯、梯子的位置跟碰撞绑定），光一律从左边来。
会动的部分（火苗、灯笼、晾的衣服、旗子、竹子）还在 Godot 里画，这里只画不动的底子。
"""
import math
import numpy as np
from scenery import Canvas, rng
from village import planks_v, planks_h, post, beam, plaster, stones_row, thatch, tiles, lattice, shadow_band, rock, stamp


class Rel:
    """以 (ox, oy) 为原点的画布包装：所有坐标都是相对摆设落地点的偏移。"""

    def __init__(self, left, right, up, down=2):
        self.ox, self.oy = left, up
        self.cv = Canvas(left + right, up + down)

    def X(self, dx):
        return self.ox + dx

    def Y(self, dy):
        return self.oy + dy

    def rect(self, dx, dy, w, h, mat, lv=2):
        self.cv.rect(self.X(dx), self.Y(dy), w, h, mat, lv)

    def line(self, x0, y0, x1, y1, mat, lv=2, width=1):
        self.cv.line(self.X(x0), self.Y(y0), self.X(x1), self.Y(y1), mat, lv, width)

    def poly(self, pts, mat, lv=2):
        return self.cv.poly([(self.X(x), self.Y(y)) for x, y in pts], mat, lv)

    def mask(self, pts):
        return self.cv.mask_poly([(self.X(x), self.Y(y)) for x, y in pts])

    def disc(self, a, b, r0, r1, mat, lv=2):
        return self.cv.disc_line((self.X(a[0]), self.Y(a[1])), (self.X(b[0]), self.Y(b[1])), r0, r1, mat, lv)

    def ellipse(self, cx, cy, rx, ry, mat, lv=2, clip=None):
        return self.cv.ellipse(self.X(cx), self.Y(cy), rx, ry, mat, lv, clip)

    def put(self, dx, dy, mat, lv=2):
        self.cv.put(self.X(dx), self.Y(dy), mat, lv)

    def finish(self, meta=None, rim=True):
        self.cv.outline()
        if rim:
            self.cv.rim(-1)
        m = dict(meta or {})
        m["origin"] = [self.ox, self.oy]
        for k in ("windows", "glow"):
            if k in m:
                m[k] = [[self.X(v[0]), self.Y(v[1])] + list(v[2:]) for v in m[k]]
        return self.cv.trim(m, pad=1)


def plank(R, x0, x1, top, r, mat="wood"):
    """一条能站的木板走道：上沿亮，板子接缝，下沿暗。"""
    R.rect(x0, top, x1 - x0, 5, mat, 2)
    R.rect(x0, top, x1 - x0, 1, mat, 4)
    R.rect(x0, top + 1, x1 - x0, 1, mat, 3)
    R.rect(x0, top + 4, x1 - x0, 1, mat, 1)
    k = x0 + int(r.integers(6, 12))
    while k < x1 - 2:
        R.rect(k, top + 1, 1, 4, mat, 0)
        k += int(r.integers(10, 16))


def vpost(R, x, top, bottom, w=3, mat="wood"):
    R.rect(x, top, w, bottom - top, mat, 2)
    R.rect(x, top, 1, bottom - top, mat, 3)
    R.rect(x + w - 1, top, 1, bottom - top, mat, 1)


def crate(R, x, y, s, r):
    """木箱：外框粗木条，中间板子，斜撑一根。(x, y) 是左下角。"""
    R.rect(x, y - s, s, s, "wood", 2)
    for k in range(1, s - 1, 4):
        R.rect(x + 2, y - s + 2 + k, s - 4, 1, "wood", 1)
    R.line(x + 2, y - 3, x + s - 3, y - s + 2, "wood", 3, 2)
    R.line(x + 3, y - 3, x + s - 3, y - s + 3, "wood", 1)
    for side in ((x, y - s, s, 2), (x, y - 2, s, 2), (x, y - s, 2, s), (x + s - 2, y - s, 2, s)):
        R.rect(*side, "oldwood", 2)
    R.rect(x, y - s, s, 1, "oldwood", 4)
    R.rect(x, y - s, 1, s, "oldwood", 3)
    R.rect(x + s - 1, y - s, 1, s, "oldwood", 1)
    R.rect(x, y - 1, s, 1, "oldwood", 1)
    for cx, cy in ((x + 1, y - s + 1), (x + s - 2, y - s + 1), (x + 1, y - 2), (x + s - 2, y - 2)):
        R.put(cx, cy, "iron", 3)


def sack(R, cx, cy, rx, ry, r):
    m = R.ellipse(cx, cy, rx, ry, "rope", 2)
    ys, xs = np.nonzero(m)
    top, bot = ys.min(), ys.max()
    for y, x in zip(ys, xs):
        t = (y - top) / max(1, bot - top)
        u = (x - xs.min()) / max(1, xs.max() - xs.min())
        lv = 3 if (t < 0.35 and u < 0.6) else (1 if (t > 0.7 or u > 0.8) else 2)
        R.cv.lv[y, x] = lv
    R.rect(cx - 1, cy - ry - 2, 3, 2, "rope", 1)
    R.put(cx, cy - ry - 3, "rope", 3)


# ---------- 能站的结构 ----------

def house2():
    r = rng(21)
    R = Rel(176, 96, 146, 2)
    hw = 82
    up = -70
    rt = -128
    # 一楼
    plaster(R.cv, R.X(-78), R.Y(-70), R.X(78), R.Y(-30), r, "mud", 0.8)
    planks_v(R.cv, R.X(-78), R.Y(-30), R.X(78), R.Y(-3), "oldwood", r, rot=0.5)
    beam(R.cv, R.X(-78), R.X(78), R.Y(-31), 3)
    for k in range(5):
        px = -78 + k * 38
        post(R.cv, R.X(px), R.Y(-70), R.Y(0), 4)
    R.rect(-20, -46, 30, 46, "VOID", 1)
    beam(R.cv, R.X(-22), R.X(12), R.Y(-48), 3)
    for k in range(4):
        ln = 14 + (k % 2) * 4
        R.rect(-19 + k * 7, -45, 6, ln, "cloth", 2)
        R.rect(-19 + k * 7, -45, 1, ln, "cloth", 3)
        R.rect(-14 + k * 7, -45, 1, ln, "cloth", 1)
    lattice(R.cv, R.X(34), R.Y(-52), R.X(52), R.Y(-38))
    stones_row(R.cv, R.X(-80), R.X(80), R.Y(-3), R.Y(1), r)
    # 二楼
    planks_h(R.cv, R.X(-56), R.Y(up - 48), R.X(76), R.Y(up), "oldwood", r, 4)
    for k in range(4):
        post(R.cv, R.X(-56 + k * 43), R.Y(up - 48), R.Y(up), 4)
    lattice(R.cv, R.X(26), R.Y(up - 34), R.X(42), R.Y(up - 22))
    lattice(R.cv, R.X(-36), R.Y(up - 34), R.X(-20), R.Y(up - 22))
    # 走廊下面的托梁
    for k in range(9):
        px = -hw + 4 + k * 19.5
        R.line(px, up + 5, px + 6, up + 12, "wood", 1, 2)
    shadow_band(R.cv, R.X(-78), R.X(78), R.Y(up + 5), 6)
    # 二楼走廊 + 栏杆
    plank(R, -hw, hw, up, r)
    for k in range(9):
        vpost(R, -hw + 4 + k * 19.5, up - 12, up, 2)
    R.rect(-hw, up - 13, hw * 2, 2, "wood", 2)
    R.rect(-hw, up - 13, hw * 2, 1, "wood", 4)
    # 屋顶：厚茅草，两头出檐往下垂，顶上平的能站
    m = R.mask([(-58, rt), (78, rt), (92, rt + 14), (76, rt + 10), (-56, rt + 10), (-72, rt + 14)])
    thatch(R.cv, m, r, band=5)
    R.rect(-56, rt, 134, 1, "thatch", 4)
    for k in range(0, 134, 3):
        if (k * 7) % 5 < 2:
            R.put(-56 + k, rt - 1, "dry", 3)
            if k % 2:
                R.put(-56 + k, rt - 2, "dry", 3)
    # 屋檐下的影子
    shadow_band(R.cv, R.X(-56), R.X(76), R.Y(rt + 11), 6)
    # 楼梯
    a = (-172, 0)
    b = (-hw, up)
    R.line(a[0], a[1] + 2, b[0], b[1] + 2, "wood", 1, 3)
    n = 8
    for k in range(n):
        t = (k + 0.5) / n
        px, py = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        R.rect(int(px) - 5, int(py) - 1, 10, 3, "wood", 2)
        R.rect(int(px) - 5, int(py) - 1, 10, 1, "wood", 4)
    R.line(a[0] + 2, a[1] - 14, b[0], b[1] - 14, "wood", 2)
    for k in range(4):
        t = (k + 0.2) / 4
        px, py = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        R.line(px, py, px, py - 14, "wood", 1)
    return R.finish({"windows": [[34, -52, 18, 14], [26, up - 34, 16, 12, "lit"]]})


def scaffold():
    r = rng(22)
    R = Rel(40, 48, 120, 2)
    hw = 33
    for px in (-hw + 2, hw - 4):
        vpost(R, px, -116, 0, 3)
    R.line(-hw + 3, -2, hw - 3, -54, "oldwood", 2, 2)
    R.line(hw - 3, -58, -hw + 3, -110, "oldwood", 2, 2)
    # 梯子
    for lx in (hw + 4, hw + 10):
        R.rect(lx, -112, 1, 112, "oldwood", 2)
    for k in range(14):
        R.rect(hw + 4, -4 - k * 8, 7, 1, "oldwood", 3)
    plank(R, -hw, hw, -56, r)
    plank(R, -hw, hw, -112, r)
    # 绑绳
    for px in (-hw + 2, hw - 4):
        for py in (-56, -112):
            R.rect(px - 1, py + 5, 5, 2, "rope", 3)
    sack(R, -12, -47, 6, 6, r)
    return R.finish()


def tower():
    r = rng(23)
    R = Rel(50, 40, 158, 2)
    top = -100
    for px in (-24, 21):
        vpost(R, px, top, 0, 3)
    R.line(-23, -4, 22, top + 8, "oldwood", 2, 2)
    R.line(22, -4, -23, top + 8, "oldwood", 1, 2)
    plank(R, -45, -15, -52, r)
    R.line(-43, -47, -24, -30, "oldwood", 1, 2)
    plank(R, -28, 28, top, r)
    R.rect(-28, top - 14, 56, 2, "wood", 2)
    R.rect(-28, top - 14, 56, 1, "wood", 4)
    for px in (-27, -9, 9, 25):
        vpost(R, px, top - 14, top, 2)
    for px in (-26, 23):
        vpost(R, px, top - 40, top - 14, 2)
    m = R.mask([(-34, top - 38), (34, top - 38), (0, top - 55)])
    thatch(R.cv, m, r, band=4)
    R.rect(-34, top - 38, 69, 2, "thatch", 3)
    R.rect(-6, top - 24, 12, 10, "VOID", 1)
    return R.finish({"windows": [[-3, top - 22, 6, 7, "lit"]]})


def shed():
    r = rng(24)
    R = Rel(90, 58, 84, 2)
    top = -74
    hw = 52
    for px in (-hw + 6, hw - 8):
        vpost(R, px, top, 0, 4, "oldwood")
    R.line(-hw + 8, top + 16, -hw + 30, top + 2, "oldwood", 2, 2)
    R.line(hw - 8, top + 16, hw - 30, top + 2, "oldwood", 1, 2)
    # 棚顶：歪掉的木板，盖着烂茅草
    plank(R, -hw, hw, top, r, "oldwood")
    m = R.mask([(-hw - 2, top), (-hw + 4, top - 5), (hw - 6, top - 6), (hw + 2, top)])
    thatch(R.cv, m, r, band=3)
    for k in range(-hw, hw, 3):
        if (k * 5) % 7 < 3:
            R.line(k, top + 5, k + 1, top + 8 + (k % 3), "thatch", 1)
    shadow_band(R.cv, R.X(-hw), R.X(hw), R.Y(top + 5), 4)
    # 当台阶的木箱
    crate(R, -hw - 30, 0, 17, r)
    crate(R, -hw - 13, 0, 17, r)
    crate(R, -hw - 26, -17, 16, r)
    # 棚下的草垛
    m = R.mask([(4, 0), (6, -16), (18, -21), (34, -15), (40, 0)])
    thatch(R.cv, m, r, band=4)
    return R.finish()


def wall():
    r = rng(25)
    R = Rel(52, 76, 52, 2)
    top = -46
    R.rect(-48, top, 96, 46, "stone", 1)
    for row in range(4):
        y = top + 3 + row * 11
        x = -48 + (8 if row % 2 else 0) - 16
        while x < 48:
            w = int(r.integers(12, 17))
            x0, x1 = max(-47, x), min(47, x + w - 2)
            if x1 > x0:
                R.rect(x0, y, x1 - x0, 9, "stone", 2)
                R.rect(x0, y, x1 - x0, 1, "stone", 3)
                R.rect(x0, y, 1, 9, "stone", 3)
                R.rect(x0, y + 8, x1 - x0, 1, "stone", 1)
                if r.random() < 0.3:
                    R.put(x0 + int(r.integers(2, max(3, x1 - x0 - 1))), y + int(r.integers(2, 7)), "stone", 1)
                if r.random() < 0.25:
                    R.rect(x0 + 1, y + 7, min(5, x1 - x0 - 1), 1, "grass", 2)
            x += w
    R.rect(-48, top, 96, 3, "stone", 3)
    R.rect(-48, top, 96, 1, "stone", 4)
    # 墙头长草、垂下来的藤
    for k in range(-46, 47, 3):
        if (k * 7) % 5 < 3:
            R.line(k, top - 1, k - 1 + (k % 2), top - 3 - (k * 3) % 3, "grass", 3)
    for vx in (-30, 6, 30):
        for d in range(int(r.integers(6, 16))):
            R.put(vx + (d // 4) % 2, top + 2 + d, "leaf", 2 if d % 3 else 3)
    # 塌下来的碎石
    for k in range(6):
        st = rock(70 + k, int(r.integers(5, 10)), int(r.integers(3, 6)))
        stamp(R.cv, st, R.X(52 + k * 5 - 4), R.Y(-st.h + 1 - (k % 2) * 2))
    return R.finish()


def cart():
    r = rng(26)
    R = Rel(36, 58, 44, 2)
    top = -26
    R.line(28, top + 4, 52, 0, "oldwood", 2, 2)
    R.line(28, top + 3, 52, -1, "oldwood", 3)
    R.rect(-29, top, 58, 6, "wood", 2)
    planks_v(R.cv, R.X(-29), R.Y(top), R.X(29), R.Y(top + 6), "wood", r, w=12)
    R.rect(-29, top, 58, 1, "wood", 4)
    R.rect(-29, top + 5, 58, 1, "wood", 1)
    # 轮子
    cx, cy = -10, -11
    m = R.ellipse(cx, cy, 11, 11, "oldwood", 2)
    hole = R.ellipse(cx, cy, 8.2, 8.2, "VOID", 1)
    R.cv.mat[hole] = -1
    ys, xs = np.nonzero(m & ~hole)
    for y, x in zip(ys, xs):
        a = math.atan2(y - R.Y(cy), x - R.X(cx))
        R.cv.lv[y, x] = 3 if -2.6 < a < -1.0 else (1 if 0.4 < a < 2.2 else 2)
    for k in range(4):
        a = k * math.pi / 4
        R.line(cx - math.cos(a) * 8, cy - math.sin(a) * 8, cx + math.cos(a) * 8, cy + math.sin(a) * 8, "oldwood", 2)
    R.ellipse(cx, cy, 2.2, 2.2, "iron", 3)
    sack(R, 8, top - 6, 7, 6, r)
    sack(R, 19, top - 4, 5, 4, r)
    return R.finish()


def crates():
    r = rng(27)
    R = Rel(24, 24, 40, 2)
    crate(R, -19, 0, 19, r)
    crate(R, 0, 0, 19, r)
    crate(R, -12, -19, 15, r)
    plank(R, -20, 20, -35, r, "oldwood")
    return R.finish()


def hay():
    r = rng(28)
    R = Rel(26, 26, 36, 2)
    m = R.mask([(-22, 0), (-22, -22), (-18, -28), (-10, -31), (2, -30), (12, -32), (19, -28), (22, -22), (22, 0)])
    thatch(R.cv, m, r, band=6)
    for x in range(-21, 22):
        if (x * 7) % 4 < 2:
            R.put(x, -29 - (x % 2), "dry", 3)
    for bx in (-9, 7):
        R.rect(bx, -31, 2, 31, "rope", 2)
        R.rect(bx, -31, 1, 31, "rope", 3)
    R.rect(-22, -13, 44, 1, "thatch", 0)
    return R.finish()


# ---------- 摆设 ----------

def well():
    r = rng(29)
    R = Rel(26, 26, 60, 2)
    R.rect(-21, -21, 42, 21, "stone", 1)
    for row in range(3):
        for k in range(5):
            bx = -20 + k * 11 + (5 if row % 2 else 0) - 5
            x0, x1 = max(-20, bx), min(20, bx + 9)
            if x1 <= x0:
                continue
            R.rect(x0, -20 + row * 7, x1 - x0, 5, "stone", 2)
            R.rect(x0, -20 + row * 7, x1 - x0, 1, "stone", 3)
            R.rect(x0, -16 + row * 7, x1 - x0, 1, "stone", 1)
    R.rect(-23, -24, 46, 3, "stone", 3)
    R.rect(-23, -24, 46, 1, "stone", 4)
    R.rect(-20, -21, 40, 1, "VOID", 1)
    vpost(R, -19, -52, -22, 3, "oldwood")
    vpost(R, 16, -52, -22, 3, "oldwood")
    R.rect(-22, -55, 44, 3, "wood", 2)
    R.rect(-22, -55, 44, 1, "wood", 4)
    R.line(0, -52, 0, -34, "rope", 2)
    R.rect(-3, -36, 6, 5, "wood", 2)
    R.rect(-3, -36, 6, 1, "wood", 4)
    R.rect(-3, -33, 6, 1, "iron", 2)
    # 井沿的青苔
    for x in range(-22, 23, 2):
        if (x * 5) % 7 < 3:
            R.put(x, -21, "grass", 3)
    return R.finish()


def scarecrow():
    r = rng(30)
    R = Rel(24, 24, 68, 2)
    R.rect(-1, -56, 3, 56, "oldwood", 2)
    R.rect(-1, -56, 1, 56, "oldwood", 3)
    R.rect(-18, -44, 36, 3, "oldwood", 2)
    R.rect(-18, -44, 36, 1, "oldwood", 3)
    m = R.mask([(-12, -44), (12, -44), (9, -22), (4, -26), (0, -20), (-5, -25), (-10, -21)])
    R.cv.apply(m, "indigo", 2, only_filled=False)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        u = x - R.X(0)
        R.cv.lv[y, x] = 3 if u < -6 else (1 if u > 6 else 2)
    R.rect(-4, -36, 5, 4, "cloth", 2)
    R.line(-12, -44, -4, -30, "indigo", 1)
    R.rect(-1, -44, 2, 14, "rope", 2)
    R.ellipse(0, -51, 5.5, 5.5, "rope", 2)
    R.put(-2, -52, "VOID", 1)
    R.put(2, -52, "VOID", 1)
    m = R.mask([(-15, -55), (15, -55), (3, -65), (-3, -65)])
    R.cv.apply(m, "thatch", 2, only_filled=False)
    R.rect(-15, -56, 30, 1, "thatch", 3)
    R.line(-15, -55, -3, -65, "thatch", 4)
    for s in (-1, 1):
        for k in range(3):
            R.line(s * 18, -43, s * (21 + k), -40 + k * 2, "dry", 3)
    return R.finish()


def fire_base():
    R = Rel(16, 16, 10, 2)
    for k in range(6):
        a = k * math.tau / 6
        st = rock(90 + k, 5, 3)
        stamp(R.cv, st, R.X(int(math.cos(a) * 11) - 3), R.Y(-st.h + 1))
    R.line(-10, 0, 8, -6, "char", 2, 3)
    R.line(10, 0, -8, -6, "char", 1, 3)
    R.rect(-4, -3, 8, 2, "GLOW", 2)
    return R.finish()


def sign():
    r = rng(31)
    R = Rel(24, 30, 50, 2)
    R.rect(-1, -44, 3, 44, "oldwood", 2)
    R.rect(-1, -44, 1, 44, "oldwood", 3)
    R.rect(-19, -45, 38, 12, "wood", 2)
    planks_h(R.cv, R.X(-19), R.Y(-45), R.X(19), R.Y(-33), "wood", r, 6)
    for k in range(4):
        R.rect(-14 + k * 8, -42, 4, 6, "char", 1)
        R.put(-13 + k * 8, -40, "wood", 2)
    R.line(19, -39, 25, -39, "wood", 2, 2)
    R.poly([(25, -41), (28, -39), (25, -37)], "wood", 2)
    return R.finish()


def grave():
    R = Rel(18, 20, 30, 2)
    R.poly([(-14, 0), (-8, -7), (8, -7), (14, 0)], "dirt", 2)
    R.rect(-12, -6, 10, 1, "dirt", 3)
    R.rect(-4, -25, 8, 19, "stone", 2)
    R.rect(-4, -25, 2, 19, "stone", 3)
    R.rect(3, -25, 1, 19, "stone", 1)
    R.rect(-4, -26, 8, 1, "stone", 4)
    R.rect(-1, -21, 2, 10, "stone", 0)
    R.line(10, 0, 13, -22, "iron", 3)
    R.line(11, 0, 14, -22, "iron", 1)
    R.rect(11, -26, 4, 3, "wood", 1)
    for x in (-10, -7, 7, 10):
        R.put(x, -8, "grass", 3)
    return R.finish()


def barrel():
    R = Rel(10, 10, 24, 2)
    m = R.mask([(-8, 0), (-9, -10), (-8, -20), (8, -20), (9, -10), (8, 0)])
    R.cv.apply(m, "wood", 2, only_filled=False)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        u = (x - R.X(-9)) / 18.0
        R.cv.lv[y, x] = 3 if u < 0.28 else (1 if u > 0.75 else 2)
        if (x - R.X(-9)) % 4 == 0 and 0.1 < u < 0.9:
            R.cv.lv[y, x] = max(1, R.cv.lv[y, x] - 1)
    for yy in (-17, -10, -3):
        R.rect(-9, yy, 18, 2, "iron", 2)
        R.rect(-9, yy, 4, 1, "iron", 4)
    R.rect(-8, -21, 16, 2, "wood", 1)
    R.rect(-7, -21, 14, 1, "wood", 3)
    return R.finish()


def bucket():
    R = Rel(8, 8, 18, 2)
    R.poly([(-6, -10), (6, -10), (5, 0), (-5, 0)], "wood", 2)
    R.rect(-6, -10, 2, 10, "wood", 3)
    R.rect(4, -10, 2, 10, "wood", 1)
    R.rect(-6, -10, 12, 1, "wood", 4)
    R.rect(-6, -6, 12, 1, "iron", 2)
    R.rect(-6, -2, 12, 1, "iron", 2)
    R.line(-6, -11, -4, -15, "iron", 3)
    R.line(-4, -15, 4, -15, "iron", 3)
    R.line(4, -15, 6, -11, "iron", 2)
    return R.finish()


def woodpile():
    R = Rel(22, 22, 32, 2)
    for row in range(3):
        for k in range(4 - row):
            cx, cy = -15 + k * 10 + row * 5, -5 - row * 9
            R.ellipse(cx, cy, 5, 5, "bark", 2)
            R.ellipse(cx, cy, 3.6, 3.6, "wood", 3)
            R.ellipse(cx + 0.5, cy + 0.5, 1.4, 1.4, "wood", 2)
            R.put(cx - 2, cy - 2, "wood", 4)
    return R.finish()


def rubble():
    r = rng(32)
    R = Rel(16, 18, 10, 2)
    for k in range(5):
        st = rock(40 + k, 5 + k % 2, 3 + k % 3)
        stamp(R.cv, st, R.X(-10 + k * 5 - 1), R.Y(-st.h + 1 - (k % 2) * 2))
    return R.finish()


def tent():
    r = rng(33)
    R = Rel(38, 38, 56, 2)
    m = R.mask([(-33, 0), (0, -45), (33, 0)])
    R.cv.apply(m, "rope", 2, only_filled=False)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        u = x - R.X(0)
        lv = 3 if u < -2 else 2
        if u > 14:
            lv = 1
        if (x + y) % 9 == 0:
            lv = max(1, lv - 1)
        R.cv.lv[y, x] = lv
    for k in range(4):
        R.line(-26 + k * 9, -8 - k * 10, -20 + k * 9, -5 - k * 10, "rope", 1)
    R.poly([(-9, 0), (0, -30), (9, 0)], "VOID", 1)
    R.line(0, -30, -12, 0, "rope", 3)
    R.line(0, -45, 0, -53, "oldwood", 2, 2)
    R.line(33, 0, 38, -2, "rope", 2)
    return R.finish()


def rack():
    R = Rel(20, 20, 52, 2)
    vpost(R, -16, -34, 0, 2, "wood")
    vpost(R, 14, -34, 0, 2, "wood")
    R.rect(-17, -30, 34, 2, "wood", 2)
    R.rect(-17, -30, 34, 1, "wood", 4)
    R.rect(-17, -12, 34, 2, "wood", 2)
    for k in range(4):
        px = -11 + k * 7
        R.line(px, -2, px + 1, -44 - (k % 2) * 6, "iron", 3)
        R.line(px + 1, -2, px + 2, -44 - (k % 2) * 6, "iron", 1)
        R.rect(px - 1, -14, 3, 4, "wood", 1)
        R.rect(px - 2, -15, 5, 1, "iron", 4)
    return R.finish()


def stone_lantern():
    R = Rel(14, 14, 52, 2)
    R.rect(-8, -4, 16, 4, "stone", 2)
    R.rect(-8, -4, 16, 1, "stone", 3)
    R.rect(-3, -26, 6, 22, "stone", 2)
    R.rect(-3, -26, 2, 22, "stone", 3)
    R.rect(2, -26, 1, 22, "stone", 1)
    R.rect(-7, -30, 14, 4, "stone", 2)
    R.rect(-7, -30, 14, 1, "stone", 4)
    R.rect(-6, -41, 12, 11, "stone", 2)
    R.rect(-6, -41, 2, 11, "stone", 3)
    R.rect(-3, -39, 6, 7, "VOID", 1)
    R.poly([(-11, -41), (11, -41), (4, -48), (-4, -48)], "stone", 2)
    R.line(-11, -41, -4, -48, "stone", 4)
    R.rect(-1, -51, 2, 3, "stone", 2)
    for x in (-8, -5, 6):
        R.put(x, -5, "grass", 3)
    return R.finish({"windows": [[-3, -39, 6, 7, "lit"]]})


def lantern_post():
    R = Rel(6, 16, 56, 2)
    vpost(R, -1, -52, 0, 3, "oldwood")
    R.rect(-1, -52, 12, 2, "oldwood", 2)
    R.rect(-1, -52, 12, 1, "oldwood", 3)
    return R.finish()


def laundry_poles():
    R = Rel(46, 46, 54, 2)
    for x in (-42, 40):
        R.rect(x, -50, 2, 50, "leaf", 2)
        R.rect(x, -50, 1, 50, "leaf", 3)
        for y in (-40, -26, -12):
            R.rect(x - 1, y, 4, 1, "leaf", 1)
    return R.finish()


PIECES = {
    "house2": house2, "scaffold": scaffold, "tower": tower, "shed": shed, "wall": wall,
    "cart": cart, "crates": crates, "hay": hay, "well": well, "scarecrow": scarecrow,
    "fire": fire_base, "sign": sign, "grave": grave, "barrel_d": barrel, "bucket": bucket,
    "woodpile": woodpile, "rubble": rubble, "tent": tent, "rack": rack,
    "stone_lantern": stone_lantern, "lantern": lantern_post, "laundry": laundry_poles,
}
