"""像素绑定：用关节姿势一像素一像素地画出角色。

为什么不直接在 Godot 里画多边形：多边形缩小以后边缘发糊、比例乱，像素画讲究每个像素都摆在对的地方。
这里在离线脚本里按姿势“点”出每一帧（像素中心采样、不抗锯齿），每个部件单独描一圈深色内线，
最后整体描 1 像素外描边、清掉孤立像素，输出精灵表。头部是手绘像素，不旋转缩放。

坐标：脚底中心为原点，x 向前（角色朝右），y 向下。长度单位就是像素。
角度：0 = 竖直向下，PI/2 = 水平向前，PI = 竖直向上，负数 = 向后。
"""
import math
from PIL import Image

OUTLINE = "1c1424"

# 材质的四阶色：[内描线, 暗, 基础, 亮]
RAMPS = {
    "pink":   ["7a2e52", "b95f84", "ea8cad", "fbc4d6"],
    "white":  ["7d7394", "c9c0d4", "f2eef6", "ffffff"],
    "hair":   ["0e0a14", "1e1828", "2a2236", "4e4466"],
    "skin":   ["8a4e40", "d29a80", "f4cdb0", "fde4cc"],
    "boot":   ["0c0a12", "1e1a28", "2a2634", "4a4660"],
    "sash":   ["24222c", "3c3a4a", "5c5a6c", "7a788c"],
    "sheath": ["240a18", "4a1a32", "6a2846", "9a4a6c"],
    "blade":  ["7a3a58", "d07898", "f4aac6", "fff0f6"],
    "silver": ["4a4a5a", "8a8a9e", "cfd0dc", "f4f4fa"],
    "hilt":   ["2a0e1c", "5a2040", "7a3050", "a04a70"],
    "flower": ["8a2048", "c43e6e", "f2608f", "ffa0c0"],
}
EXTRA = {"Y": "ffe08a", "J": "7ad8bc", "r": "ec8a9a", "m": "b85a70"}

# 头（手绘，朝右）：14 x 14，最后一行正中下方是脖子接点
HEAD_W, HEAD_H = 14, 14
HEAD_NECK = (9.5, 14.0)
HEAD_BUN = (1.5, 3.0)        # 马尾从这里垂下


def _head_grid(variant="n"):
    g = [["."] * HEAD_W for _ in range(HEAD_H)]

    def seg(y, x, s):
        for i, c in enumerate(s):
            if c != ".":
                g[y][x - 10 + i] = c
    for y, x, s in [(3, 13, "HHHHHHHH"), (4, 12, "HHHHHHHHhHH"), (5, 11, "HHHHHHHHHhhH"), (6, 11, "HHHHHHHHHHHH"),
                    (7, 11, "HHHHHHHSHHSH"), (8, 11, "HHHHHHSSSSSS"), (9, 11, "HHHHsHSSKKSS"), (10, 11, "HHHHsHSSKESSS"),
                    (11, 11, "HHHHHHSSSSrS"), (12, 12, "HHHsHSSSmS"), (13, 13, "HssSSSSS"),
                    (1, 11, "HHH"), (2, 10, "HhHHH"), (3, 10, "HhHHH"), (4, 11, "HHH"),
                    (0, 16, "FfF"), (1, 16, "fYf"), (2, 16, "FfF")]:
        seg(y, x, s)
    if variant == "f":          # 凶：眉压下来，眼神更利
        seg(8, 18, "KKK")
        seg(9, 18, "SKK")
        seg(10, 18, "SKE")
        seg(12, 12, "HHHsHSSSSS")
    elif variant == "h":        # 疼：闭眼，张嘴
        seg(9, 18, "SSKS")
        seg(10, 18, "SSSK")
        seg(12, 12, "HHHsHSSmmS")
    elif variant == "c":        # 闭眼（喝药、倒下）
        seg(9, 18, "SSSS")
        seg(10, 18, "SKKS")
    return g


HEAD_COLORS = {"E": "4a3a6a", "H": RAMPS["hair"][2], "h": RAMPS["hair"][3], "S": RAMPS["skin"][2], "s": RAMPS["skin"][1],
               "K": OUTLINE, "r": EXTRA["r"], "m": EXTRA["m"], "F": RAMPS["flower"][2], "f": RAMPS["flower"][1],
               "Y": EXTRA["Y"]}


def v(x, y):
    return (float(x), float(y))


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def mul(a, k):
    return (a[0] * k, a[1] * k)


def length(a):
    return math.hypot(a[0], a[1])


def norm(a):
    l = length(a) or 1.0
    return (a[0] / l, a[1] / l)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def adir(angle):
    """角度转方向（0 向下，PI/2 向前）"""
    return (math.sin(angle), math.cos(angle))


def rot(p, ang, c=(0.0, 0.0)):
    s, co = math.sin(ang), math.cos(ang)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * co - y * s, c[1] + x * s + y * co)


def ik(start, end, l1, l2, bend):
    """两节骨骼：bend=+1 关节往前（膝盖），-1 往后（手肘下垂）"""
    d = sub(end, start)
    dist = max(0.01, min(length(d), l1 + l2 - 0.01))
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    n = norm(d)
    mid = add(start, mul(n, a))
    perp = (-n[1], n[0])
    j1 = add(mid, mul(perp, h))
    j2 = sub(mid, mul(perp, h))
    return j1 if (j1[0] - j2[0]) * bend >= 0 else j2


# ---------------- 栅格化（像素中心采样，不抗锯齿） ----------------

class Canvas:
    def __init__(self, w, h, ox, oy):
        self.w, self.h, self.ox, self.oy = w, h, ox, oy

    def center(self, px, py):
        return (px - self.ox + 0.5, py - self.oy + 0.5)

    def to_px(self, p):
        return (int(math.floor(p[0] + self.ox)), int(math.floor(p[1] + self.oy)))

    def bbox(self, pts, pad=2.0):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0 = max(0, int(math.floor(min(xs) - pad + self.ox)))
        x1 = min(self.w - 1, int(math.ceil(max(xs) + pad + self.ox)))
        y0 = max(0, int(math.floor(min(ys) - pad + self.oy)))
        y1 = min(self.h - 1, int(math.ceil(max(ys) + pad + self.oy)))
        return x0, x1, y0, y1


def _in_poly(pt, poly):
    x, y = pt
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def poly_mask(cv, poly):
    out = set()
    x0, x1, y0, y1 = cv.bbox(poly, 1)
    for py in range(y0, y1 + 1):
        for px in range(x0, x1 + 1):
            if _in_poly(cv.center(px, py), poly):
                out.add((px, py))
    return out


def _seg_dist(p, a, b):
    ab = sub(b, a)
    t = max(0.0, min(1.0, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / (ab[0] ** 2 + ab[1] ** 2 + 1e-9)))
    q = add(a, mul(ab, t))
    return length(sub(p, q)), t


def capsule_mask(cv, a, b, ra, rb=None):
    rb = ra if rb is None else rb
    out = set()
    x0, x1, y0, y1 = cv.bbox([a, b], max(ra, rb) + 1)
    for py in range(y0, y1 + 1):
        for px in range(x0, x1 + 1):
            d, t = _seg_dist(cv.center(px, py), a, b)
            if d <= ra + (rb - ra) * t:
                out.add((px, py))
    return out


def line_px(cv, a, b):
    """1 像素宽的直线（像素完美：去掉 L 形拐角）"""
    pa, pb = cv.to_px(a), cv.to_px(b)
    x0, y0 = pa
    x1, y1 = pb
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    # 像素完美：去掉多余的拐角像素
    i = 1
    while i < len(pts) - 1:
        p, c, n = pts[i - 1], pts[i], pts[i + 1]
        if (p[0] == c[0] or p[1] == c[1]) and (n[0] == c[0] or n[1] == c[1]) and p[0] != n[0] and p[1] != n[1]:
            pts.pop(i)
        else:
            i += 1
    return pts


# ---------------- 部件 ----------------

class Part:
    """一个部件：像素 -> 颜色。line 是它压在别的部件上时描的那圈内线（None = 不描）。"""

    def __init__(self, line=None):
        self.px = {}
        self.line = line

    def put(self, p, col):
        self.px[p] = col

    def fill(self, mask, col):
        for p in mask:
            self.px[p] = col


def shade(mask, ramp, light=True, dark=True, back=(-1, 0), low=(0, 1), top=(0, -1), front=(1, 0), dark2=False):
    """按边缘上色：朝光（上、前）的边一像素亮色，背光（后、下）的边一像素暗色，中间基础色。"""
    out = {}
    for p in mask:
        def outside(d):
            return (p[0] + d[0], p[1] + d[1]) not in mask
        is_dark = dark and (outside(back) or outside(low) or (dark2 and outside((back[0] * 2, back[1] * 2))))
        is_light = light and (outside(top) or outside(front))
        if is_dark and is_light:
            out[p] = ramp[2]
        elif is_dark:
            out[p] = ramp[1]
        elif is_light:
            out[p] = ramp[3]
        else:
            out[p] = ramp[2]
    return out


class Frame:
    def __init__(self, cv):
        self.cv = cv
        self.px = {}       # 像素 -> (颜色, 部件序号)
        self.n = 0
        self.glow = set()  # 刀光：不描边、也不算进外轮廓

    def add(self, part, glow=False):
        i = self.n
        self.n += 1
        for p, c in part.px.items():
            if 0 <= p[0] < self.cv.w and 0 <= p[1] < self.cv.h:
                self.px[p] = (c, i)
                if glow:
                    self.glow.add(p)
                else:
                    self.glow.discard(p)
        if part.line:
            for p in part.px:
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (p[0] + d[0], p[1] + d[1])
                    if q not in part.px and q in self.px and self.px[q][1] != i:
                        self.px[q] = (part.line, i)

    def finish(self):
        """去孤立像素、外描边，返回 RGBA 图"""
        for p in list(self.px):
            if p not in self.glow and all((p[0] + d[0], p[1] + d[1]) not in self.px for d in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                del self.px[p]
        for p in [q for q in self.px if q[1] >= self.cv.oy]:     # 地面以下的都不要
            del self.px[p]
        solid = {p for p in self.px if p not in self.glow}
        img = Image.new("RGBA", (self.cv.w, self.cv.h), (0, 0, 0, 0))
        pix = img.load()
        for (x, y), (c, _) in self.px.items():
            pix[x, y] = _rgba(c)
        o = _rgba(OUTLINE)
        for y in range(self.cv.h):
            for x in range(self.cv.w):
                if (x, y) in self.px:
                    continue
                if any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    pix[x, y] = o
        return img


_cache = {}


def _rgba(h):
    if h not in _cache:
        _cache[h] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    return _cache[h]
