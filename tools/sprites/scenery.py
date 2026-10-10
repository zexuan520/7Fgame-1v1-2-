"""场景像素画的底子：材质画布 + 按天色打光。

画的时候每个像素只记“什么材质、第几阶亮度”，不记颜色；输出时按天色（黄昏、月夜、雾……）
把材质的固有色乘上这一阶的光（暗面偏环境色、亮面偏主光色），再按远近往雾色里混一点。
这样同一套房子、树、地面，换天色时光影和整体色调自动统一。

亮度阶：0 = 内描线（最暗），1 暗面，2 中间，3 受光面，4 高光。
特殊材质：RIM 轮廓光（主光色），GLOW 发光（窗里的火光，Godot 里另外叠闪烁），VOID 屋里的黑洞。
"""
import numpy as np
from PIL import Image, ImageDraw

# 固有色（白天的颜色）
ALBEDO = {
    "wood":    (122, 84, 56),
    "oldwood": (112, 98, 84),     # 风吹日晒发灰的木板
    "plaster": (206, 190, 164),
    "mud":     (150, 118, 86),    # 土墙
    "thatch":  (176, 146, 86),
    "tile":    (92, 98, 112),
    "stone":   (132, 128, 120),
    "dirt":    (118, 90, 66),
    "grass":   (104, 126, 62),
    "dry":     (160, 138, 80),    # 枯草
    "paper":   (232, 222, 192),
    "char":    (52, 44, 40),      # 烧黑的木头
    "cloth":   (150, 54, 44),
    "indigo":  (54, 66, 104),
    "bark":    (92, 74, 62),
    "leaf":    (70, 92, 56),
    "rope":    (170, 150, 110),
    "iron":    (70, 72, 80),
}
MATS = list(ALBEDO) + ["RIM", "GLOW", "VOID", "SHADOW"]
MID = {m: i for i, m in enumerate(MATS)}

# 天色：暗面乘 shadow，亮面乘 key；rim 是轮廓光颜色；haze 是远景雾色；side 是光从哪边来
MOODS = {
    "dusk":   {"shadow": (0.34, 0.22, 0.40), "key": (1.22, 0.80, 0.56), "rim": (255, 168, 98),
               "haze": (70, 32, 60), "void": (16, 8, 14), "glow": (255, 150, 70), "side": -1},
    "night":  {"shadow": (0.17, 0.21, 0.36), "key": (0.52, 0.62, 0.88), "rim": (176, 196, 236),
               "haze": (24, 34, 60), "void": (6, 8, 14), "glow": (255, 196, 110), "side": 1},
    "fog":    {"shadow": (0.40, 0.42, 0.47), "key": (0.86, 0.88, 0.92), "rim": (214, 220, 226),
               "haze": (134, 142, 150), "void": (30, 32, 36), "glow": (240, 210, 150), "side": -1},
    "graves": {"shadow": (0.16, 0.24, 0.22), "key": (0.52, 0.70, 0.58), "rim": (140, 196, 160),
               "haze": (20, 32, 28), "void": (6, 9, 8), "glow": (140, 255, 190), "side": 1},
    "bamboo": {"shadow": (0.17, 0.27, 0.19), "key": (0.72, 0.88, 0.56), "rim": (184, 220, 130),
               "haze": (24, 48, 32), "void": (6, 10, 6), "glow": (255, 220, 140), "side": 1},
    "camp":   {"shadow": (0.30, 0.13, 0.13), "key": (1.12, 0.56, 0.36), "rim": (244, 112, 60),
               "haze": (40, 14, 18), "void": (10, 4, 4), "glow": (255, 140, 60), "side": 1},
}
# 每阶在 暗→亮 之间的位置
LEVEL_T = [None, 0.0, 0.42, 0.78, 1.0]


def mood_color(mood, mat, level, fog=0.0):
    M = MOODS[mood]
    if mat == "RIM":
        c = np.array(M["rim"], float)
    elif mat == "GLOW":
        c = np.array(M["glow"], float)
    elif mat == "VOID":
        c = np.array(M["void"], float)
    elif mat == "SHADOW":
        c = np.array(M["void"], float) * 1.4 + 6
    else:
        a = np.array(ALBEDO[mat], float)
        s = np.array(M["shadow"])
        k = np.array(M["key"])
        if level == 0:
            c = a * s * 0.5
            c = c * 0.7 + np.array(M["void"]) * 0.3
        else:
            t = LEVEL_T[level]
            light = s + (k - s) * t
            c = a * light
            if level == 4:
                c = c * 0.75 + np.array(M["rim"]) * 0.25
    if fog > 0 and mat != "GLOW":
        c = c * (1 - fog) + np.array(M["haze"], float) * fog
    return tuple(int(max(0, min(255, round(x)))) for x in c)


class Canvas:
    """记材质和亮度阶的画布。坐标 x 向右、y 向下，(0,0) 在左上角。"""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.mat = np.full((h, w), -1, np.int16)
        self.lv = np.zeros((h, w), np.int8)

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def put(self, x, y, mat, lv=2):
        x, y = int(x), int(y)
        if self.inside(x, y):
            self.mat[y, x] = MID[mat]
            self.lv[y, x] = lv

    def get(self, x, y):
        if not self.inside(x, y) or self.mat[y, x] < 0:
            return None
        return MATS[self.mat[y, x]], int(self.lv[y, x])

    def filled(self, x, y):
        return self.inside(x, y) and self.mat[y, x] >= 0

    def rect(self, x, y, w, h, mat, lv=2):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        if x1 > x0 and y1 > y0:
            self.mat[y0:y1, x0:x1] = MID[mat]
            self.lv[y0:y1, x0:x1] = lv

    def mask_poly(self, pts):
        img = Image.new("1", (self.w, self.h), 0)
        ImageDraw.Draw(img).polygon([(float(px), float(py)) for px, py in pts], fill=1)
        return np.array(img, bool)

    def poly(self, pts, mat, lv=2):
        m = self.mask_poly(pts)
        self.mat[m] = MID[mat]
        self.lv[m] = lv
        return m

    def apply(self, mask, mat=None, lv=None, only_filled=True):
        m = mask & (self.mat >= 0) if only_filled else mask
        if mat is not None:
            self.mat[m] = MID[mat]
        if lv is not None:
            self.lv[m] = lv

    def line(self, x0, y0, x1, y1, mat, lv=2, width=1):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            for k in range(width):
                if dx >= -dy:
                    self.put(x0, y0 + k, mat, lv)
                else:
                    self.put(x0 + k, y0, mat, lv)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def shade_where(self, mat, lv_from, lv_to, mask):
        m = mask & (self.mat == MID[mat]) & (self.lv == lv_from)
        self.lv[m] = lv_to

    def outline(self, lv=0, rim_side=None, rim_mats=None):
        """外描边：空像素挨着实心像素就描成那个材质的最暗阶（选择性描边，不是一刀切的黑线）。
        rim_side=-1 时左边缘的受光面描一像素轮廓光。"""
        filled = self.mat >= 0
        H, W = filled.shape
        new_mat = self.mat.copy()
        new_lv = self.lv.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.full_like(self.mat, -1)
            ys = slice(max(0, dy), H + min(0, dy))
            yd = slice(max(0, -dy), H + min(0, -dy))
            xs = slice(max(0, dx), W + min(0, dx))
            xd = slice(max(0, -dx), W + min(0, -dx))
            src[yd, xd] = self.mat[ys, xs]
            put = (~filled) & (src >= 0) & (new_mat < 0)
            new_mat[put] = src[put]
            new_lv[put] = 0
        bad = {MID["GLOW"], MID["RIM"], MID["VOID"], MID["SHADOW"]}
        for b in bad:
            sel = (new_mat == b) & (~filled)
            new_mat[sel] = MID["char"]
        self.mat, self.lv = new_mat, new_lv
        if rim_side:
            self.rim(rim_side, rim_mats)

    def rim(self, side, mats=None, depth=1):
        """光那一侧的边缘（描线里面一格）点成轮廓光。"""
        H, W = self.mat.shape
        for y in range(H):
            row = self.mat[y]
            xs = np.nonzero(row >= 0)[0]
            if len(xs) == 0:
                continue
            # 每一段连续像素的受光端
            runs = np.split(xs, np.nonzero(np.diff(xs) != 1)[0] + 1)
            for r in runs:
                if len(r) < 3:
                    continue
                order = r if side < 0 else r[::-1]
                for x in order[1:1 + depth]:
                    m = MATS[row[x]]
                    if m in ("GLOW", "VOID", "SHADOW", "RIM"):
                        continue
                    if mats and m not in mats:
                        continue
                    if self.lv[y, x] >= 2:
                        self.mat[y, x] = MID["RIM"]
                        self.lv[y, x] = 2

    def disc_line(self, a, b, r0, r1, mat, lv=2):
        """粗细渐变的线段（树干、树枝）：从 a 半径 r0 到 b 半径 r1。返回画到的像素。"""
        ax, ay = a
        bx, by = b
        pad = max(r0, r1) + 1
        x0, x1 = int(max(0, min(ax, bx) - pad)), int(min(self.w, max(ax, bx) + pad + 1))
        y0, y1 = int(max(0, min(ay, by) - pad)), int(min(self.h, max(ay, by) + pad + 1))
        if x1 <= x0 or y1 <= y0:
            return np.zeros_like(self.mat, bool)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        px, py = xx + 0.5, yy + 0.5
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy or 1e-6
        t = np.clip(((px - ax) * dx + (py - ay) * dy) / L, 0, 1)
        d = np.hypot(px - (ax + t * dx), py - (ay + t * dy))
        rad = r0 + (r1 - r0) * t
        sel = d <= rad
        full = np.zeros_like(self.mat, bool)
        full[y0:y1, x0:x1] = sel
        self.mat[full] = MID[mat]
        self.lv[full] = lv
        return full

    def ellipse(self, cx, cy, rx, ry, mat, lv=2, clip=None):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        m = ((xx + 0.5 - cx) / max(rx, 0.1)) ** 2 + ((yy + 0.5 - cy) / max(ry, 0.1)) ** 2 <= 1.0
        if clip is not None:
            m &= clip
        self.mat[m] = MID[mat]
        self.lv[m] = lv
        return m

    def shade_runs(self, mask, lo=0.25, hi=0.7, mats=None):
        """按每一行左右位置打光：左边受光（亮一阶），右边背光（暗一阶）。用在树干这种圆柱体上。"""
        H, W = self.mat.shape
        for y in range(H):
            xs = np.nonzero(mask[y])[0]
            if len(xs) == 0:
                continue
            runs = np.split(xs, np.nonzero(np.diff(xs) != 1)[0] + 1)
            for r in runs:
                n = len(r)
                for i, x in enumerate(r):
                    if mats and MATS[self.mat[y, x]] not in mats:
                        continue
                    t = (i + 0.5) / n
                    if t < lo and n >= 3:
                        self.lv[y, x] = 3
                    elif t > hi:
                        self.lv[y, x] = 1
                    else:
                        self.lv[y, x] = 2

    def trim(self, meta, pad=1):
        """裁掉四周的空白，meta 里的坐标跟着平移。"""
        ys, xs = np.nonzero(self.mat >= 0)
        x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
        x1, y1 = min(self.w, xs.max() + 1 + pad), min(self.h, ys.max() + 1 + pad)
        c = Canvas(x1 - x0, y1 - y0)
        c.mat = self.mat[y0:y1, x0:x1].copy()
        c.lv = self.lv[y0:y1, x0:x1].copy()
        m = dict(meta)
        m["origin"] = [meta["origin"][0] - x0, meta["origin"][1] - y0]
        for k in ("windows", "smoke", "glow"):
            if k in m:
                m[k] = [[v[0] - x0, v[1] - y0] + list(v[2:]) for v in m[k]]
        return c, m

    def render(self, mood, fog=0.0, flip=False, dark=0.0):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        cache = {}
        ys, xs = np.nonzero(self.mat >= 0)
        for y, x in zip(ys, xs):
            key = (int(self.mat[y, x]), int(self.lv[y, x]))
            if key not in cache:
                c = mood_color(mood, MATS[key[0]], key[1], fog)
                if dark > 0:
                    v = MOODS[mood]["void"]
                    c = tuple(int(round(c[i] * (1 - dark) + v[i] * dark)) for i in range(3))
                cache[key] = c + (255,)
            out[y, x] = cache[key]
        img = Image.fromarray(out, "RGBA")
        if flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        return img


def rng(seed):
    return np.random.default_rng(seed)
