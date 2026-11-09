"""场景件“锻造台”：用几何体直接搭中式场景件，输出和 tools/voxelize/voxelize_prop.py 一样的
assets/voxel/kit/<id>.json.gz（VoxelKit 直接能读）。

为什么：KayKit 中世纪包的欧式木筋房、风车、十字墓碑、南瓜灯、橡木桶、圆靶、卡通树，和本作的
中式山野/道门/宫城题材冲突（审查报告第 5~8 条）。这里按原来那件的占地大小重做，沿用原来的 id，
摆放代码一行不用改；每个 id 现在是什么写在 PIECES 里。

坐标：一格 = vs 像素（游戏里 1 像素 = 0.036 米），原点在底面中心，+z 朝镜头（房子的门朝 +z），y 朝上。
导出全部实心格（网格只在实心格和空格之间出面，挖空了反而多出朝里的面）。

用法：python3 tools/charforge/props.py [id ...]   （不写就全做）
"""
import gzip, json, math, os, sys
import numpy as np

OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "voxel", "kit"))


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


# 场景色板：比角色暗、灰一点（角色要从场景里跳出来）；VoxelKit 读进来还会再乘 0.85
P = {
    "earth": "#a8875e", "earth_d": "#83674a", "earth_l": "#bc9c70",
    "plaster": "#cbc2b0", "plaster_d": "#a39a88",
    "timber": "#6e4a30", "timber_d": "#4e3424", "timber_l": "#8a5e3e",
    "tile": "#66707a", "tile_d": "#48505a", "tile_l": "#808a94", "ridge": "#3a4048",
    "stone": "#8e8b84", "stone_d": "#686660", "stone_l": "#aaa79e", "moss": "#5d6e48",
    "red": "#8e2a22", "red_d": "#5e1a16", "red_l": "#b03a2c",
    "lacq": "#3a3236", "gold": "#c9a040", "gold_d": "#8e6e28", "brass": "#b08a3a",
    "paper": "#e6dcc2", "paper_d": "#bfb293", "ink": "#2a2226",
    "thatch": "#a38c54", "thatch_d": "#7a6439", "thatch_l": "#bfa66a",
    "jar": "#4b3125", "jar_l": "#6c4834", "jar_d": "#2e1e17", "glaze": "#3a2a24",
    "straw": "#c8a860", "straw_d": "#957a3c",
    "pine": "#4a6c46", "pine_d": "#324c36", "pine_l": "#678a58",
    "willow": "#62804a", "willow_d": "#455e36", "willow_l": "#7c9a5a",
    "bark": "#4a3a30", "bark_d": "#30261f", "bark_l": "#665044",
    "dead": "#6a625a", "dead_d": "#4a4440", "dead_l": "#847a70",
    "bronze": "#7a6a48", "bronze_d": "#4e4430", "patina": "#5c8478",
    "white": "#d8d2c4", "water": "#3e6c7a",
}


class Piece:
    def __init__(self, name, sx, sy, sz, vs=2.0, seed=1, src=""):
        self.name, self.vs, self.src = name, vs, src
        self.sx, self.sy, self.sz = sx, sy, sz
        self.mn = (-(sx // 2), 0, -(sz // 2))
        xs = np.arange(sx) + self.mn[0] + 0.5
        ys = np.arange(sy) + 0.5
        zs = np.arange(sz) + self.mn[2] + 0.5
        self.X, self.Y, self.Z = np.meshgrid(xs, ys, zs, indexing="ij")
        self.occ = np.zeros(self.X.shape, bool)
        self.col = np.zeros(self.X.shape + (3,), float)
        self.flat = np.zeros(self.X.shape, bool)       # 不做明暗噪点的格（纸、灯、字）
        self.rng = np.random.default_rng(seed)

    # ---------- 形状 ----------
    def box(self, x0, x1, y0, y1, z0, z1):
        X, Y, Z = self.X, self.Y, self.Z
        return (X >= x0) & (X < x1) & (Y >= y0) & (Y < y1) & (Z >= z0) & (Z < z1)

    def ell(self, c, r):
        return ((self.X - c[0]) / r[0]) ** 2 + ((self.Y - c[1]) / r[1]) ** 2 + ((self.Z - c[2]) / r[2]) ** 2 <= 1.0

    def cyl(self, cx, cz, r, y0, y1, rz=None):
        rz = r if rz is None else rz
        return (((self.X - cx) / r) ** 2 + ((self.Z - cz) / rz) ** 2 <= 1.0) & (self.Y >= y0) & (self.Y < y1)

    def lathe(self, cx, cz, prof, y0, y1):
        """车床体：prof(y 相对 y0 的 0~1) → 半径"""
        t = np.clip((self.Y - y0) / max(y1 - y0, 1e-6), 0, 1)
        r = prof(t)
        return ((self.X - cx) ** 2 + (self.Z - cz) ** 2 <= r ** 2) & (self.Y >= y0) & (self.Y < y1)

    def seg(self, a, b, r0, r1=None):
        r1 = r0 if r1 is None else r1
        a = np.asarray(a, float)
        b = np.asarray(b, float)
        d = b - a
        L2 = float(d @ d)
        Px = self.X - a[0]
        Py = self.Y - a[1]
        Pz = self.Z - a[2]
        t = np.clip((Px * d[0] + Py * d[1] + Pz * d[2]) / max(L2, 1e-6), 0, 1)
        qx, qy, qz = Px - t * d[0], Py - t * d[1], Pz - t * d[2]
        r = r0 + (r1 - r0) * t
        return qx * qx + qy * qy + qz * qz <= r * r

    def disk_z(self, cx, cy, r, z0, z1):
        """竖着的圆盘（面朝 z）"""
        return ((self.X - cx) ** 2 + (self.Y - cy) ** 2 <= r * r) & (self.Z >= z0) & (self.Z < z1)

    def disk_x(self, cz, cy, r, x0, x1):
        return ((self.Z - cz) ** 2 + (self.Y - cy) ** 2 <= r * r) & (self.X >= x0) & (self.X < x1)

    # ---------- 上色 ----------
    def fill(self, m, c, flat=False):
        self.occ |= m
        self._paint(m, c)
        self.flat[m] = flat

    def paint(self, m, c, flat=False):
        m = m & self.occ
        self._paint(m, c)
        self.flat[m] = flat

    def carve(self, m):
        self.occ &= ~m

    def _paint(self, m, c):
        if callable(c):
            self.col[m] = c(self.X[m], self.Y[m], self.Z[m])
        else:
            self.col[m] = rgb(P.get(c, c)) if isinstance(c, str) else np.asarray(c, float)

    def stripes(self, axis, period, c, width=1, m=None):
        """每隔 period 格一道 c 色（瓦垄、木板缝）"""
        A = {"x": self.X, "y": self.Y, "z": self.Z}[axis]
        s = (np.floor(A) % period) < width
        self.paint(s if m is None else (s & m), c)

    # ---------- 输出 ----------
    def shade(self, top=0.14, noise=0.07, block=2):
        on = self.occ & ~self.flat
        yn = self.Y / max(self.sy, 1)
        mul = 1.0 - top * 0.6 + top * yn
        # 贴地一圈压暗（假的接触阴影）
        mul -= 0.12 * np.clip(1.0 - self.Y / 3.0, 0, 1)
        bx = (np.floor(self.X / block).astype(np.int64) * 73856093) ^ (np.floor(self.Y / block).astype(np.int64) * 19349663) ^ (np.floor(self.Z / block).astype(np.int64) * 83492791)
        nz = ((bx % 1000) / 1000.0 - 0.5) * 2.0 * noise
        mul = np.round((mul + nz) * 25) / 25
        self.col[on] = np.clip(self.col[on] * mul[on][:, None], 0, 255)

    def export(self):
        # 藏在里面看不见的格（离空格至少 4 格，低画质两格并一格时也露不出来）统一成一个颜色，压缩包小好几倍
        inner = self.occ.copy()
        for _ in range(4):
            e = inner.copy()
            for ax in range(3):
                for s in (1, -1):
                    r = np.roll(inner, s, ax)
                    sl = [slice(None)] * 3
                    sl[ax] = 0 if s == 1 else -1
                    r[tuple(sl)] = False
                    e &= r
            inner = e
        self.col[inner] = (96, 96, 96)
        ix = np.argwhere(self.occ)
        cells = ix + np.array(self.mn)
        cols = np.clip(np.round(self.col[self.occ]), 0, 255).astype(int)
        out = {"vs": self.vs, "len": float(self.sy * self.vs), "size": [self.sx, self.sy, self.sz], "min": list(self.mn),
               "source": "本作自制（tools/charforge/props.py）" + (" · " + self.src if self.src else ""),
               "vox": np.concatenate([cells, cols], 1).reshape(-1).tolist()}
        path = os.path.join(OUT, self.name + ".json.gz")
        with gzip.open(path, "wt", compresslevel=9) as f:
            json.dump(out, f, separators=(",", ":"))
        print(f"{self.name}: {len(ix)} 格 → {os.path.getsize(path) // 1024} KB")


# ======================================================================
# 通用构件
# ======================================================================
def grad(c0, c1, y0, y1):
    a, b = rgb(P.get(c0, c0)), rgb(P.get(c1, c1))

    def f(X, Y, Z):
        t = np.clip((Y - y0) / max(y1 - y0, 1e-6), 0, 1)[..., None]
        return a * (1 - t) + b * t
    return f


def roof(p, x0, x1, z0, z1, y_eave, y_ridge, th=2.5, curl=2.5, tile="tile", tile_d="tile_d", ridge="ridge", hip=False, ends=True, tile_l="tile_l"):
    """中式两坡瓦顶（脊沿 x）：坡面往檐口微微下凹再翘起；瓦垄每 3 格一道暗线；正脊两端起翘（鸱吻）"""
    cz = (z0 + z1) / 2
    hw = (z1 - z0) / 2
    d = np.abs(p.Z - cz) / hw                    # 0 = 脊，1 = 檐口
    # 凹曲面：y = ridge - (ridge-eave)*(d^1.4)，檐口再翘 curl
    yr = y_ridge - (y_ridge - y_eave) * d ** 1.4 + curl * np.clip((d - 0.8) / 0.2, 0, 1) ** 2
    # 四角起翘：檐角往上挑（俯视时屋顶四个角是中式屋顶最认得出的地方）
    hx0 = (x1 - x0) / 2
    dxc = np.abs(p.X - (x0 + x1) / 2) / hx0
    yr = yr + curl * 1.6 * np.clip((d - 0.6) / 0.4, 0, 1) ** 2 * np.clip((dxc - 0.75) / 0.25, 0, 1) ** 2
    m = (p.X >= x0) & (p.X < x1) & (d <= 1.0) & (p.Y <= yr) & (p.Y > yr - th)
    if hip:
        # 歇山/庑殿：两头也往下收
        hx = (x1 - x0) / 2
        cx = (x0 + x1) / 2
        dx = np.abs(p.X - cx) / hx
        yr2 = y_ridge - (y_ridge - y_eave) * np.clip((dx - 0.55) / 0.45, 0, 1) ** 1.4 + curl * np.clip((dx - 0.85) / 0.15, 0, 1) ** 2
        m = m & (p.Y <= yr2)
        m |= (p.X >= x0) & (p.X < x1) & (d <= 1.0) & (p.Y <= np.minimum(yr, yr2)) & (p.Y > np.minimum(yr, yr2) - th)
    p.fill(m, tile)
    p.stripes("x", 3, tile_d, 1, m)
    p.paint(m & (d > 0.93), tile_l)                       # 檐口一道亮边（勾头滴水），俯视时屋檐轮廓清楚
    p.paint(m & (dxc > 0.96), tile_l)
    # 正脊
    rm = p.box(x0 + 1, x1 - 1, y_ridge - 1, y_ridge + 2.5, cz - 1.6, cz + 1.6)
    p.fill(rm, ridge)
    if ends:
        for ex, sgn in ((x0 + 2, -1), (x1 - 3, 1)):
            p.fill(p.box(ex, ex + 2, y_ridge, y_ridge + 5.5, cz - 1.4, cz + 1.4), ridge)
            p.fill(p.box(ex - sgn * 1.5 if sgn > 0 else ex, ex + 2 + (1.5 if sgn > 0 else 0), y_ridge + 4, y_ridge + 6, cz - 1.2, cz + 1.2), ridge)
    return m


def thatch_roof(p, x0, x1, z0, z1, y_eave, y_ridge, th=3.5):
    cz = (z0 + z1) / 2
    hw = (z1 - z0) / 2
    d = np.abs(p.Z - cz) / hw
    yr = y_ridge - (y_ridge - y_eave) * d ** 0.9
    hx = (x1 - x0) / 2
    cx = (x0 + x1) / 2
    dx = np.abs(p.X - cx) / hx
    yr = np.minimum(yr, y_ridge - (y_ridge - y_eave) * np.clip((dx - 0.6) / 0.4, 0, 1))
    m = (dx <= 1.0) & (d <= 1.0) & (p.Y <= yr) & (p.Y > yr - th)
    p.fill(m, grad("thatch_d", "thatch_l", y_eave, y_ridge))
    p.stripes("y", 4, "thatch_d", 1, m)
    # 毛边：檐口随机缺几格
    rough = (p.rng.random(p.X.shape) < 0.35) & (d > 0.92)
    p.carve(m & rough)
    p.fill(p.box(x0 + 2, x1 - 2, y_ridge - 2, y_ridge + 1, cz - 2, cz + 2), "thatch_d")   # 压脊草
    return m


def walls(p, x0, x1, z0, z1, y0, y1, col, t=2.0):
    m = p.box(x0, x1, y0, y1, z0, z1) & ~p.box(x0 + t, x1 - t, y0, y1, z0 + t, z1 - t)
    p.fill(m, col)
    return m


def door(p, cx, w, h, zf, y0=0, col="timber", frame="timber_d", depth=1.0):
    """门：在 +z 那面墙上开一扇（往里凹 depth，门框深色）"""
    p.carve(p.box(cx - w / 2, cx + w / 2, y0, y0 + h, zf - depth, zf + 0.01))
    p.fill(p.box(cx - w / 2, cx + w / 2, y0, y0 + h, zf - depth - 1, zf - depth), col)
    p.fill(p.box(cx - 0.5, cx + 0.5, y0, y0 + h, zf - depth - 1, zf - depth), frame)    # 两扇门中缝
    p.fill(p.box(cx - w / 2 - 1, cx + w / 2 + 1, y0 + h, y0 + h + 1.2, zf - 0.5, zf + 0.6), frame)
    for sx in (-1, 1):
        p.fill(p.box(cx + sx * (w / 2 + 0.5) - 0.6, cx + sx * (w / 2 + 0.5) + 0.6, y0, y0 + h, zf - 0.5, zf + 0.6), frame)


def window(p, cx, cy, w, h, zf, frame="timber_d", paper="paper_d"):
    """格子窗：窗纸 + 深色窗棂（十字 + 外框）"""
    m = p.box(cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2, zf - 0.6, zf + 0.6)
    p.fill(m, paper)
    g = m & ((np.floor(p.X - cx + w / 2) % 3 < 0.9) | (np.floor(p.Y - cy + h / 2) % 3 < 0.9))
    p.paint(g, frame)
    p.paint(m & ~p.box(cx - w / 2 + 1, cx + w / 2 - 1, cy - h / 2 + 1, cy + h / 2 - 1, -99, 99), frame)


def window_x(p, cz, cy, w, h, xf, frame="timber_d", paper="paper_d"):
    m = p.box(xf - 0.6, xf + 0.6, cy - h / 2, cy + h / 2, cz - w / 2, cz + w / 2)
    p.fill(m, paper)
    g = m & ((np.floor(p.Z - cz + w / 2) % 3 < 0.9) | (np.floor(p.Y - cy + h / 2) % 3 < 0.9))
    p.paint(g, frame)


def jar(p, cx, cz, y0, h, r, col="jar", seal=True, mouth=0.42):
    """酒坛：鼓肚、小口；口上蒙红布扎绳"""
    prof = lambda t: r * (mouth + (1 - mouth) * np.sin(np.clip(t * 1.05, 0, 1) * math.pi) ** 0.7 * (0.75 + 0.25 * (1 - t)))
    m = p.lathe(cx, cz, prof, y0, y0 + h)
    p.fill(m, grad(P[col + "_d"] if col + "_d" in P else col, P[col + "_l"] if col + "_l" in P else col, y0, y0 + h))
    p.paint(m & (p.Y < y0 + h * 0.5) & (p.Y > y0 + h * 0.08), "glaze")         # 下半截釉色深
    if seal:
        rr = r * mouth + 1.2
        p.fill(p.cyl(cx, cz, rr, y0 + h, y0 + h + 1.5), "red")
        p.fill(p.ell((cx, y0 + h + 1.5, cz), (rr * 0.8, 1.6, rr * 0.8)), "red_l")
        p.fill(p.cyl(cx, cz, rr + 0.6, y0 + h - 0.8, y0 + h + 0.3), "straw_d")    # 绳


def crate(p, x0, x1, y0, y1, z0, z1, col="red", trim="brass", lacq=False):
    """红漆木箱：箱体 + 铜包角 + 一圈箍带"""
    m = p.box(x0, x1, y0, y1, z0, z1)
    p.fill(m, col)
    p.stripes("y", 4, col + "_d" if col + "_d" in P else "timber_d", 1, m & ~p.box(x0 + 1, x1 - 1, y0, y1, z0 + 1, z1 - 1))
    e = 2.0
    for xa in (x0, x1 - e):
        for za in (z0, z1 - e):
            p.paint(p.box(xa, xa + e, y0, y1, za, za + e), trim)
    p.paint(m & ((p.Y >= y1 - 1.0) & ~p.box(x0 + e, x1 - e, y0, y1 + 1, z0 + e, z1 - e)), trim)
    p.paint(m & (np.abs(p.Y - (y0 + y1) / 2) < 0.6), trim)


def pine_tuft(p, c, rx, ry, rz, col="pine"):
    """松针一团：扁平的云朵状（中国画里的松：一层层平托着）"""
    m = p.ell(c, (rx, ry, rz))
    # 底面平一点、顶面鼓：切掉下面 35%
    m &= p.Y > c[1] - ry * 0.55
    p.fill(m, grad(P[col + "_d"], P[col + "_l"], c[1] - ry * 0.5, c[1] + ry))
    rough = (p.rng.random(p.X.shape) < 0.25) & ~p.ell(c, (rx - 1.5, ry - 1, rz - 1.5))
    p.carve(m & rough)


def branch(p, a, b, r0, r1, col="bark"):
    p.fill(p.seg(a, b, r0, r1), col)


# ======================================================================
# 第 5 条：柳溪村
# ======================================================================
def home_a():
    """夯土茅……不，夯土瓦房：黄土墙、青瓦两坡顶、木门、格子窗，门口两级石阶"""
    p = Piece("home_a", 66, 76, 70, vs=2.0, seed=11)
    p.fill(p.box(-30, 30, 0, 3, -28, 30), "stone_d")                                  # 台基
    walls(p, -27, 27, -24, 24, 3, 40, grad("earth_d", "earth_l", 3, 40), t=3)
    p.stripes("y", 5, "earth_d", 1, p.box(-27, 27, 3, 40, -24, 24))                   # 夯土一层层的版筑线
    for x in (-27, 24):
        for z in (-24, 21):
            p.fill(p.box(x, x + 3, 3, 41, z, z + 3), "timber")                       # 角柱
    p.fill(p.box(-28, 28, 39, 42, -25, 25), "timber_d")                               # 檐下枋
    door(p, 0, 12, 22, 24, y0=3)
    window(p, -16, 24, 10, 9, 24.2)
    window(p, 16, 24, 10, 9, 24.2)
    window_x(p, 0, 24, 10, 9, 27.2)
    window_x(p, 0, 24, 10, 9, -27.2)
    p.fill(p.box(-8, 8, 0, 1.5, 30, 34), "stone")                                      # 石阶
    roof(p, -33, 33, -33, 33, 40, 66, th=3, curl=3)
    # 门上一对红春联
    for sx in (-1, 1):
        p.fill(p.box(sx * 8.5 - 1, sx * 8.5 + 1, 8, 22, 24, 24.8), "red", flat=True)
    p.fill(p.box(-5, 5, 26, 28.5, 24, 24.8), "red", flat=True)
    return p


def home_b():
    """青砖粉墙民居：白墙、深色木柱、硬山顶两头起山墙，门口挂两盏红灯笼"""
    p = Piece("home_b", 52, 76, 64, vs=2.0, seed=12)
    p.fill(p.box(-25, 25, 0, 3, -26, 28), "stone_d")
    walls(p, -22, 22, -22, 22, 3, 38, "plaster", t=3)
    p.fill(p.box(-22, 22, 3, 9, -22, 22) & ~p.box(-19, 19, 3, 9, -19, 19), "stone_d")       # 青砖墙裙
    p.stripes("y", 2, "stone", 1, p.box(-22, 22, 3, 9, -22, 22))
    for x in (-22, -8, 6, 19):
        p.fill(p.box(x, x + 3, 3, 39, 19, 23), "timber_d")                                   # 前檐柱
    p.fill(p.box(-24, 24, 37, 40, -23, 24), "timber")
    door(p, -1, 10, 21, 22, y0=3, col="red_d")
    window(p, 13, 23, 8, 10, 22.2)
    window(p, -14, 23, 6, 10, 22.2)
    # 硬山：两头山墙伸到瓦面上
    for x0 in (-25, 22):
        tri = p.box(x0, x0 + 3, 38, 64, -24, 24) & (p.Y < 64 - np.abs(p.Z) * 1.05)
        p.fill(tri, "plaster_d")
    roof(p, -24, 24, -30, 30, 38, 62, th=3, curl=1.5, ends=False)
    p.fill(p.box(-26, 26, 61, 65, -2, 2), "ridge")
    # 灯笼
    for x in (-9, 7):
        p.fill(p.box(x - 0.5, x + 0.5, 30, 34, 25, 26), "ink")
        p.fill(p.ell((x, 28, 25.5), (2.4, 3, 2.4)), "red_l", flat=True)
    return p


def tavern():
    """酒肆：两层，下层敞开柜台、上层格窗、两重檐；门前高杆挑一面“酒”旗"""
    p = Piece("tavern", 72, 86, 82, vs=2.0, seed=13)
    p.fill(p.box(-32, 30, 0, 3, -32, 34), "stone_d")
    walls(p, -29, 27, -28, 22, 3, 32, "timber_l", t=2.5)
    p.stripes("x", 4, "timber_d", 1, p.box(-29, 27, 3, 32, -28, 22))
    p.carve(p.box(-22, 14, 6, 26, 19, 23))                                                # 敞开的柜台口
    p.fill(p.box(-22, 14, 3, 12, 18, 20), "timber_d")                                     # 柜台
    for x in (-18, -10, -2, 6):
        jar(p, x, 16, 12, 8, 3.2, seal=True)                                              # 柜台上一排酒坛
    p.fill(p.box(-31, 29, 31, 34, -30, 24), "timber_d")
    roof(p, -35, 33, -34, 30, 30, 40, th=2.5, curl=2.5, ends=False)                       # 一层腰檐
    walls(p, -25, 23, -24, 16, 34, 58, "plaster", t=2.5)
    for x in (-25, -1, 21):
        p.fill(p.box(x, x + 2.5, 34, 58, 14, 17), "timber_d")
    for cx in (-13, 11):
        window(p, cx, 47, 14, 12, 16.2)
    p.fill(p.box(-27, 25, 57, 60, -26, 18), "timber_d")
    roof(p, -31, 29, -32, 24, 58, 80, th=3, curl=3)
    # 招牌横匾
    p.fill(p.box(-10, 8, 34.5, 39, 22.5, 24), "lacq")
    p.fill(p.box(-8, 6, 35.5, 38, 24, 24.6), "gold", flat=True)
    # 酒旗杆
    fx = 31
    p.fill(p.cyl(fx, 28, 1.2, 0, 84), "timber_d")
    p.fill(p.box(fx - 12, fx, 78, 80, 27.5, 28.5), "timber_d")
    flag = p.box(fx - 11, fx - 1, 50, 78, 27.6, 28.8)
    p.fill(flag, "paper", flat=True)
    p.paint(flag & ~p.box(fx - 10, fx - 2, 52, 78, -99, 99), "red", flat=True)
    # “酒”字的几笔：三点水 + 酉
    for yy in (73, 68, 62):
        p.fill(p.box(fx - 9.5, fx - 8, yy, yy + 2, 28.8, 29.4), "ink", flat=True)
    p.fill(p.box(fx - 6.5, fx - 2.5, 72, 74, 28.8, 29.4) | p.box(fx - 6.5, fx - 5.5, 58, 74, 28.8, 29.4) | p.box(fx - 3.5, fx - 2.5, 58, 74, 28.8, 29.4)
           | p.box(fx - 6.5, fx - 2.5, 58, 60, 28.8, 29.4) | p.box(fx - 6.5, fx - 2.5, 65, 66.5, 28.8, 29.4), "ink", flat=True)
    return p


def windmill():
    """水车：大木轮（竖在 x-y 面上）+ 一圈刮板 + 木架 + 引水槽 + 磨坊小茅屋"""
    p = Piece("windmill", 78, 100, 58, vs=2.0, seed=14)
    wc = (-12, 42)       # 轮心 (x, y)
    R = 38
    for z0 in (-6, 4):
        ring = p.disk_z(wc[0], wc[1], R, z0, z0 + 2) & ~p.disk_z(wc[0], wc[1], R - 3, z0, z0 + 2)
        p.fill(ring, "timber")
        ring2 = p.disk_z(wc[0], wc[1], 9, z0, z0 + 2) & ~p.disk_z(wc[0], wc[1], 6, z0, z0 + 2)
        p.fill(ring2, "timber_d")
    p.fill(p.disk_x(-1, wc[1], 4, -18, -6), "timber_d")                    # 轴（伸到磨坊）
    p.fill(p.box(wc[0] - 2.5, wc[0] + 2.5, wc[1] - 2.5, wc[1] + 2.5, -9, 10), "timber_d")
    for k in range(12):
        a = k / 12 * math.tau
        ca, sa = math.cos(a), math.sin(a)
        for z0 in (-6, 4):
            p.fill(p.seg((wc[0] + ca * 7, wc[1] + sa * 7, z0 + 1), (wc[0] + ca * (R - 2), wc[1] + sa * (R - 2), z0 + 1), 0.9), "timber_d")
        # 刮板：两圈之间横着一块
        bx, by = wc[0] + ca * (R - 1), wc[1] + sa * (R - 1)
        p.fill(p.seg((bx, by, -7), (bx, by, 7), 1.6), "timber_l")
        p.fill(p.seg((bx - sa * 3, by + ca * 3, -7), (bx + sa * 3, by - ca * 3, -7), 0.9) | p.seg((bx - sa * 3, by + ca * 3, 7), (bx + sa * 3, by - ca * 3, 7), 0.9), "timber")
    # 木架：两边 A 字
    for z in (-10, 9):
        p.fill(p.seg((wc[0] - 16, 0, z), (wc[0], wc[1], z), 1.6) | p.seg((wc[0] + 16, 0, z), (wc[0], wc[1], z), 1.6), "timber_d")
    # 底下一汪水（浅槽）
    p.fill(p.box(-50, 26, 0, 2, -12, 12), "stone_d")
    p.fill(p.box(-48, 24, 1.5, 2.5, -10, 10), "water", flat=True)
    # 引水木槽：从轮顶上方往后
    p.fill(p.box(-14, 38, 82, 84, -3, 3) & ~p.box(-14, 38, 83, 84, -2, 2), "timber")
    for x in (10, 30):
        p.fill(p.box(x, x + 2, 0, 82, -1, 1), "timber_d")
    # 磨坊小屋（右边）
    walls(p, 18, 38, -16, 14, 0, 26, grad("earth_d", "earth_l", 0, 26), t=2.5)
    door(p, 28, 8, 16, 14)
    thatch_roof(p, 15, 41, -20, 18, 24, 42)
    return p


def house_ruin():
    """残屋：塌了半边的夯土墙、断梁、塌下来的茅草堆"""
    p = Piece("house_ruin", 86, 56, 74, vs=2.0, seed=15)
    p.fill(p.box(-40, 40, 0, 2.5, -34, 34), "stone_d")
    w = walls(p, -36, 36, -30, 30, 2.5, 34, grad("earth_d", "earth_l", 2.5, 34), t=3)
    # 墙头参差地塌掉
    h = 34 - 22 * np.clip((p.X + 10) / 46, 0, 1) - 6 * np.sin(p.X * 0.5) ** 2 - 4 * np.cos(p.Z * 0.7) ** 2
    p.carve(w & (p.Y > h))
    p.carve(p.box(-6, 8, 2.5, 22, 26, 31))                                                   # 门洞
    p.stripes("y", 5, "earth_d", 1, w)
    # 断梁斜搭
    p.fill(p.seg((-34, 34, -28), (10, 10, 20), 1.6), "timber_d")
    p.fill(p.seg((-30, 33, 26), (18, 6, -10), 1.4), "timber")
    # 塌下的茅草堆、土块
    p.fill(p.ell((14, 2.5, 0), (18, 7, 16)) & (p.Y > 2), grad("thatch_d", "thatch", 2, 9))
    p.fill(p.ell((-18, 2.5, -10), (8, 4, 7)) | p.ell((26, 2.5, 18), (6, 3.5, 5)), "earth_d")
    # 剩下一角的残顶
    m = p.box(-38, -10, 30, 40, -34, 34)
    cz_d = np.abs(p.Z) / 34
    p.fill(m & (p.Y <= 40 - 8 * cz_d) & (p.Y > 37.5 - 8 * cz_d) & (p.X < -14 - 6 * np.cos(p.Z * 0.3)), "tile")
    p.stripes("x", 3, "tile_d", 1, p.box(-38, -10, 30, 41, -34, 34))
    return p


# ======================================================================
# 第 6 条：无名冢
# ======================================================================
def crypt():
    """墓：圆土坟包 + 前面石砌墓门（拱门、门钉）+ 墓碑 + 两侧石灯"""
    p = Piece("crypt", 54, 70, 70, vs=2.0, seed=21)
    p.fill(p.ell((0, 0, -8), (26, 44, 26)) & (p.Y >= 0), grad("earth_d", "earth", 0, 44))
    p.paint(p.ell((0, 0, -8), (26, 44, 26)) & (p.rng.random(p.X.shape) < 0.12) & (p.Y > 10), "moss")
    p.fill(p.box(-24, 24, 0, 4, -34, 34) & ~p.ell((0, 0, -8), (24, 42, 24)), "stone_d")       # 坟圈石
    # 石门脸
    face = p.box(-20, 20, 0, 40, 10, 18)
    p.fill(face, "stone")
    p.stripes("y", 5, "stone_d", 1, face)
    p.fill(p.box(-22, 22, 38, 42, 9, 20), "stone_d")                                          # 门楣
    p.fill(p.box(-24, 24, 42, 45, 8, 22) & (p.Y < 45 - np.abs(p.X) * 0.08), "tile_d")
    arch = p.box(-8, 8, 0, 22, 10, 19) | p.cyl(0, 14, 8, 0, 99, rz=99) & (p.Y < 30) & (p.Z > 10)
    arch = (p.box(-8, 8, 0, 22, 10, 19) | (((p.X) ** 2 + (p.Y - 22) ** 2 <= 64) & (p.Z > 10) & (p.Z < 19)))
    p.carve(arch & (p.Z > 13))
    p.fill(arch & (p.Z > 12) & (p.Z <= 13), "lacq")                                           # 黑门
    for yy in (6, 12, 18):
        for xx in (-5, -1, 3):
            p.fill(p.box(xx, xx + 1.4, yy, yy + 1.4, 13, 14), "bronze")                        # 门钉
    # 墓碑：门前
    p.fill(p.box(-6, 6, 0, 3, 23, 30), "stone_d")
    p.fill(p.box(-4, 4, 3, 20, 25, 28), "stone_l")
    p.fill(p.box(-5, 5, 20, 22.5, 24.5, 28.5), "stone")
    p.fill(p.box(-1, 1, 6, 18, 28, 28.6), "ink", flat=True)                                   # 碑文一竖行
    # 石灯
    for sx in (-1, 1):
        x = sx * 18
        p.fill(p.box(x - 3, x + 3, 0, 3, 24, 30) | p.box(x - 1.5, x + 1.5, 3, 12, 25.5, 28.5), "stone")
        p.fill(p.box(x - 3, x + 3, 12, 18, 24, 30), "stone_l")
        p.fill(p.box(x - 1.5, x + 1.5, 13.5, 16.5, 23.5, 30.5), "#d8a050", flat=True)
        p.fill(p.box(x - 4, x + 4, 18, 20, 23, 31) & (p.Y < 20 - 0 * p.X), "stone_d")
    return p


def stele(name, sx, sy, sz, vs, h, w, top="round", base=True, seed=22, broken=False, mound=False):
    p = Piece(name, sx, sy, sz, vs=vs, seed=seed)
    d = max(2, int(sz * 0.3))
    if base:
        p.fill(p.box(-w / 2 - 2, w / 2 + 2, 0, 3, -d - 1, d + 1), "stone_d")
        y0 = 3
    else:
        y0 = 0
    body = p.box(-w / 2, w / 2, y0, y0 + h, -d / 2, d / 2)
    if top == "round":
        body &= ((p.Y < y0 + h - w / 2) | ((p.X) ** 2 + (p.Y - (y0 + h - w / 2)) ** 2 <= (w / 2) ** 2))
    p.fill(body, grad("stone_d", "stone_l", y0, y0 + h))
    if top == "roof":
        p.fill(p.box(-w / 2 - 2, w / 2 + 2, y0 + h, y0 + h + 3, -d / 2 - 1.5, d / 2 + 1.5) & (p.Y < y0 + h + 3 - np.abs(p.Z) * 0.6), "tile_d")
        p.fill(p.box(-w / 2 - 1, w / 2 + 1, y0 + h + 2, y0 + h + 4, -1, 1), "ridge")
    # 碑文：正面一竖行凹槽 + 碑额一小块
    p.fill(p.box(-max(0.5, w * 0.07), max(0.5, w * 0.07), y0 + h * 0.15, y0 + h * 0.75, d / 2, d / 2 + 0.6), "stone_d")
    p.fill(p.box(-w * 0.25, w * 0.25, y0 + h * 0.8, y0 + h * 0.9, d / 2, d / 2 + 0.6), "stone_d")
    p.paint(body & (p.rng.random(p.X.shape) < 0.1), "moss")
    if broken:
        cut = p.Y > y0 + h * 0.55 + (p.X / max(w, 1)) * h * 0.25
        p.carve(body & cut)
        p.fill(p.box(w / 2 + 1, w / 2 + 1 + h * 0.35, 0, d, -d / 2, d / 2), grad("stone_d", "stone", 0, d))   # 断下来的半截倒在旁边
        p.fill(p.ell((-w / 2 - 2, 0, 1), (3, 2, 3)) & (p.Y >= 0), "stone_d")
    if mound:
        p.fill(p.ell((0, 0, -d / 2 - 6), (w * 0.8, 7, 6)) & (p.Y >= 0) & (p.Z < -d / 2), "earth_d")
    return p


def grave_a():
    return stele("grave_a", 40, 44, 21, 1.0, 36, 18, top="round", seed=23)


def grave_b():
    return stele("grave_b", 40, 45, 21, 1.0, 34, 18, top="roof", seed=24)


def gravestone():
    return stele("gravestone", 28, 33, 9, 1.0, 28, 14, top="round", seed=25)


def gravemarker():
    """木牌：一块木板插在土里，贴一条白纸"""
    p = Piece("gravemarker", 16, 25, 7, vs=1.0, seed=26)
    p.fill(p.ell((0, 0, 0), (7, 3, 3)) & (p.Y >= 0), "earth_d")
    p.fill(p.box(-3, 3, 0, 22, -1, 1) & ((p.Y < 20) | (np.abs(p.X) < 3 - (p.Y - 20))), grad("timber_d", "timber_l", 0, 22))
    p.fill(p.box(-1, 1, 5, 18, 1, 1.6), "paper", flat=True)
    return p


def gravemarker_b():
    p = Piece("gravemarker_b", 9, 13, 5, vs=2.0, seed=27)
    p.fill(p.box(-2, 2, 0, 11, -1, 1) & ((p.Y < 10) | (np.abs(p.X) < 1.2)), grad("timber_d", "timber", 0, 11))
    p.fill(p.box(-1, 1, 3, 9, 1, 1.5), "paper", flat=True)
    return p


def grave_broken():
    return stele("grave_broken", 21, 22, 13, 2.0, 18, 8, top="round", seed=28, broken=True)


def coffin():
    """中式棺材：棺头高大、棺尾低窄，棺盖拱起；黑红漆，棺头一个金“寿”圆"""
    p = Piece("coffin", 40, 20, 62, vs=1.0, seed=29)
    t = np.clip((p.Z + 30) / 60, 0, 1)             # 0 = 尾（-z），1 = 头（+z）
    hw = 12 + 6 * t
    hh = 11 + 5 * t
    body = (np.abs(p.X) <= hw) & (p.Y <= hh) & (p.Z >= -29) & (p.Z < 30)
    p.fill(body, "red_d")
    lid = (np.abs(p.X) <= hw + 1.5) & (p.Y > hh) & (p.Y <= hh + 3 * (1 - (p.X / (hw + 1.5)) ** 2)) & (p.Z >= -30) & (p.Z < 31)
    p.fill(lid, "lacq")
    p.paint(body & (p.Y < 1.5), "lacq")
    p.paint(body & (np.abs(p.Y - hh * 0.5) < 0.8), "red")
    # 棺头的“寿”
    p.fill(p.disk_z(0, 8, 6, 29.5, 30.5), "gold", flat=True)
    p.fill(p.disk_z(0, 8, 4, 30.3, 30.9) & ~p.disk_z(0, 8, 2.6, 30, 31), "red_d", flat=True)
    p.fill(p.box(-0.6, 0.6, 3, 13, 30.3, 30.9) | p.box(-3, 3, 7.4, 8.6, 30.3, 30.9), "red_d", flat=True)
    return p


def pumpkin():
    """（原南瓜灯）地上一盏白纸灯笼：竹骨、上下木箍、红穗；发暖光"""
    p = Piece("pumpkin", 26, 30, 26, vs=1.0, seed=31)
    m = p.lathe(0, 0, lambda t: 10.5 * np.sin(np.clip(0.12 + t * 0.76, 0, 1) * math.pi) ** 0.6, 3, 25)
    p.fill(m, "#efe0b0", flat=True)
    p.paint(m & ((np.floor(np.degrees(np.arctan2(p.Z, p.X)) / 30) % 2) < 0.15), "#d8c090", flat=True)
    for y in range(6, 25, 5):
        p.paint(m & (np.abs(p.Y - y) < 0.5), "#c8a060", flat=True)                         # 竹骨
    p.fill(p.cyl(0, 0, 6, 0, 3.5) | p.cyl(0, 0, 5, 24.5, 27), "timber_d")
    p.fill(p.box(-1, 1, 27, 30, -1, 1), "timber_d")
    p.fill(p.box(-1.2, 1.2, 0, 3, 9, 12), "red", flat=True)
    p.fill(p.box(-2.5, 2.5, 11, 17, 10.4, 11), "red", flat=True)                           # 灯上一个红字块
    return p


def post_skull():
    """（原骷髅桩）招魂幡：一根竹竿，顶上横木挂一长条白幡、两侧纸条飘带"""
    p = Piece("post_skull", 20, 80, 38, vs=1.0, seed=32)
    p.fill(p.cyl(0, 0, 1.4, 0, 80), grad("timber_d", "#8a7a50", 0, 80))
    for y in range(6, 80, 9):
        p.paint(p.cyl(0, 0, 1.5, y, y + 0.8), "timber_d")                                   # 竹节
    p.fill(p.box(-1, 1, 74, 76, -14, 14), "timber_d")
    sway = lambda Y: np.sin((74 - Y) * 0.09) * 2.5
    banner = (np.abs(p.Z - sway(p.Y)) < 5) & (p.Y > 28) & (p.Y < 74) & (np.abs(p.X - 1.5) < 0.7)
    p.fill(banner, "paper", flat=True)
    p.paint(banner & (np.abs(p.Z - sway(p.Y)) < 1) & (p.Y > 38) & (p.Y < 68), "ink", flat=True)   # 幡上一竖行字
    for zz in (-12, -8, 8, 12):
        strip = (np.abs(p.Z - zz - sway(p.Y) * 0.6) < 1.1) & (p.Y > 40 + abs(zz)) & (p.Y < 74) & (np.abs(p.X) < 0.7)
        p.fill(strip, "paper_d", flat=True)
    p.fill(p.ell((0, 0, 0), (6, 3, 6)) & (p.Y >= 0), "stone_d")
    return p


def skull_candle():
    """（原骷髅蜡烛）青铜三足香炉：插三炷香，炉里幽绿火（还是发绿光）"""
    p = Piece("skull_candle", 28, 37, 28, vs=1.0, seed=33)
    for k in range(3):
        a = k / 3 * math.tau + 0.5
        p.fill(p.seg((math.cos(a) * 7, 0, math.sin(a) * 7), (math.cos(a) * 6, 8, math.sin(a) * 6), 1.6), "bronze_d")
    m = p.lathe(0, 0, lambda t: 9 + 3 * np.sin(t * math.pi) - 2 * t, 6, 18)
    p.fill(m, grad("bronze_d", "bronze", 6, 18))
    p.paint(m & (p.rng.random(p.X.shape) < 0.2), "patina")
    p.fill(p.cyl(0, 0, 10.5, 17, 19) & ~p.cyl(0, 0, 8, 17, 19), "bronze")
    for sx in (-1, 1):
        p.fill(p.box(sx * 9 - 1, sx * 9 + 1, 18, 24, -1, 1) & ~p.box(sx * 9 - 0.4, sx * 9 + 0.4, 19, 23, -2, 2), "bronze")   # 炉耳
    p.fill(p.cyl(0, 0, 7.5, 17, 18), "#6a6058")                                             # 香灰
    for x, z, h in ((-2, 0, 32), (1.5, 1.5, 30), (1, -2, 34)):
        p.fill(p.box(x - 0.5, x + 0.5, 18, h, z - 0.5, z + 0.5), "#8a3a2a")
        p.fill(p.box(x - 0.6, x + 0.6, h, h + 1.2, z - 0.6, z + 0.6), "#90ffb0", flat=True)
    p.fill(p.ell((0, 20, 0), (4, 3, 4)), "#70e8a0", flat=True)
    return p


# ======================================================================
# 第 7 条：通用摆设
# ======================================================================
def barrel():
    """（原橡木桶）大酒坛"""
    p = Piece("barrel", 28, 33, 28, vs=1.0, seed=41)
    jar(p, 0, 0, 0, 29, 13)
    return p


def barrel_small():
    """（原小桶）两只小酒坛并排"""
    p = Piece("barrel_small", 34, 33, 19, vs=1.0, seed=42)
    jar(p, -8, 0, 0, 22, 8.5)
    jar(p, 8, 1, 0, 26, 9)
    return p


def barrel_deco():
    """（原装饰桶）坛子上倒扣一只陶碗、挂一把木勺"""
    p = Piece("barrel_deco", 17, 21, 15, vs=2.0, seed=43)
    jar(p, 0, 0, 0, 15, 7.5, seal=False, mouth=0.55)
    p.fill(p.lathe(0, 0, lambda t: 3 + 2.5 * t, 15, 18), "#8a6a4a")
    p.fill(p.seg((5, 16, 2), (8, 6, 4), 0.6), "timber_l")
    return p


def keg():
    """（原木桶架）木板上三只酒坛"""
    p = Piece("keg", 33, 19, 19, vs=2.0, seed=44)
    p.fill(p.box(-16, 16, 0, 2, -8, 8), "timber_d")
    p.stripes("x", 5, "timber", 1, p.box(-16, 16, 0, 2, -8, 8))
    for x, h, r in ((-10, 15, 5.5), (0, 16, 6), (10, 14, 5.2)):
        jar(p, x, 0, 2, h, r)
    return p


def crates():
    """（原木箱堆）两只红漆木箱叠起来、一只靠旁边"""
    p = Piece("crates", 39, 40, 41, vs=1.0, seed=45)
    crate(p, -18, 6, 0, 18, -18, 6)
    crate(p, -16, 4, 18, 34, -16, 4, col="red", trim="gold")
    crate(p, 6, 19, 0, 14, 2, 18, col="timber", trim="timber_d")
    # 封条交叉
    p.paint(p.box(-16, 4, 18, 34, 4, 5) & (np.abs((p.X + 6) - (p.Y - 26) * 1.2) < 1.2), "paper", flat=True)
    p.paint(p.box(-18, 6, 0, 18, 6, 7) & (np.abs((p.X + 6) + (p.Y - 9) * 1.2) < 1.2), "paper", flat=True)
    return p


def box():
    """（原铁框箱）木箱贴交叉封条、捆绳"""
    p = Piece("box", 28, 28, 28, vs=1.0, seed=46)
    crate(p, -13, 13, 0, 25, -13, 13, col="timber", trim="timber_d")
    for z in (13, 13.5):
        p.fill(p.box(-13, 13, 0, 25, 13, 14) & ((np.abs(p.X - (p.Y - 12.5)) < 1.6) | (np.abs(p.X + (p.Y - 12.5)) < 1.6)), "paper", flat=True)
    p.fill(p.box(-14, 14, 0, 26, -1, 1) & ~p.box(-13, 13, 0, 25, -2, 2), "straw_d")
    p.fill(p.box(-14, 14, 25, 26, -14, 14) & (np.abs(p.Z) < 1), "straw_d")
    return p


def chest_common(name, col, trim):
    """箱笼：拱盖、铜锁鼻、包角"""
    p = Piece(name, 19, 15, 15, vs=2.0, seed=47)
    p.fill(p.box(-9, 9, 0, 9, -7, 7), col)
    lid = p.box(-9.5, 9.5, 9, 14, -7.5, 7.5) & ((p.Y - 9) <= 5 * np.sqrt(np.clip(1 - (p.Z / 7.5) ** 2, 0, 1)))
    p.fill(lid, col)
    p.paint(p.box(-10, 10, 8.5, 9.5, -8, 8), trim)
    for xa in (-9.5, 7.5):
        p.paint(p.box(xa, xa + 2, 0, 15, -8, 8), trim)
    p.fill(p.box(-2, 2, 4, 10, 7, 8), trim)
    p.fill(p.box(-0.8, 0.8, 5, 7, 7.8, 8.6), "lacq")
    return p


def chest():
    return chest_common("chest", "red", "brass")


def chest_gold():
    p = chest_common("chest_gold", "lacq", "gold")
    p.paint(p.box(-6, 6, 2, 7, 6.5, 8) & ~p.box(-5, 5, 3, 6, -99, 99), "gold")
    return p


def target():
    """（原圆靶）草靶：稻草捆扎的圆垛立在木架上，中心贴一张红纸"""
    p = Piece("target", 19, 24, 11, vs=2.0, seed=48)
    for sx in (-1, 1):
        p.fill(p.seg((sx * 7, 0, -3), (sx * 4, 22, 0), 0.9), "timber_d")
    p.fill(p.seg((0, 0, -5), (0, 18, 0), 0.8), "timber_d")
    disk = p.disk_z(0, 13, 8.5, -2, 3)
    p.fill(disk, grad("straw_d", "straw", 4, 21))
    p.paint(disk & ((np.sqrt(p.X ** 2 + (p.Y - 13) ** 2) % 3) < 0.9), "straw_d")             # 一圈圈捆的草绳
    p.fill(p.box(-2.5, 2.5, 10.5, 15.5, 3, 3.6), "red", flat=True)
    p.fill(p.box(-1, 1, 12, 14, 3.5, 4), "paper", flat=True)
    return p


def weaponrack():
    """兵器架：木架上靠着长枪、长刀、钺"""
    p = Piece("weaponrack", 21, 24, 13, vs=2.0, seed=49)
    p.fill(p.box(-10, 10, 0, 2, -5, 5), "timber_d")
    for sx in (-1, 1):
        p.fill(p.box(sx * 9 - 1, sx * 9 + 1, 0, 18, -1, 1), "timber")
    p.fill(p.box(-10, 10, 15, 17, -1, 1) | p.box(-10, 10, 7, 8.5, -1.5, 1.5), "timber_d")
    for x, kind in ((-5, "spear"), (0, "blade"), (5, "halberd")):
        p.fill(p.box(x - 0.6, x + 0.6, 1, 21, 1.5, 2.7), "timber_d")
        if kind == "spear":
            p.fill(p.box(x - 1, x + 1, 21, 24, 1.5, 2.7) & (np.abs(p.X - x) < 1 - (p.Y - 21) / 3), "stone_l")
            p.fill(p.box(x - 1.3, x + 1.3, 19, 21, 1.2, 3), "red", flat=True)
        elif kind == "blade":
            p.fill(p.box(x - 0.4, x + 2, 14, 24, 1.6, 2.4) & (p.X - x < 2 - (p.Y - 14) * 0.08), "stone_l")
            p.fill(p.box(x - 1.2, x + 1.2, 13, 14, 1.2, 3), "brass")
        else:
            p.fill(p.box(x - 3, x + 0.6, 17, 23, 1.6, 2.4) & ((p.X - x + 1.2) ** 2 / 9 + (p.Y - 20) ** 2 / 9 <= 1), "stone_l")
    return p


def crate_long():
    """长兵器箱：木箱捆两道绳，箱头露两根枪杆"""
    p = Piece("crate_long", 27, 11, 15, vs=2.0, seed=50)
    crate(p, -13, 11, 0, 9, -7, 7, col="timber", trim="timber_d")
    for x in (-6, 5):
        p.paint(p.box(x, x + 1.2, 0, 9.5, -7.5, 7.5), "straw_d")
    for z in (-2.5, 2.5):
        p.fill(p.box(9, 14, 6, 7.2, z - 0.6, z + 0.6), "timber_l")
    return p


def crate_open():
    """开着的木箱，里面码着书卷"""
    p = Piece("crate_open", 15, 10, 9, vs=2.0, seed=51)
    p.fill(p.box(-7, 7, 0, 7, -4, 4) & ~p.box(-6, 6, 1, 7, -3, 3), "timber")
    for i, x in enumerate((-4.5, -1.5, 1.5, 4.5)):
        p.fill(p.seg((x, 6, -2.6), (x, 6, 2.6), 1.4), "paper")
        p.fill(p.cyl(x, 2.8, 1.5, 4.6, 7.4) if False else p.disk_z(x, 6, 1.5, 2.6, 3.2), ["red", "timber_d", "brass", "red_d"][i])
    p.fill(p.box(-7, 7, 7, 7.8, -6.5, -4) , "timber_d")
    return p


def banner():
    """牙旗：竖杆 + 长方旗面、锯齿边，旗心一块深色字"""
    p = Piece("banner", 31, 65, 7, vs=1.0, seed=52)
    p.fill(p.cyl(-12, 0, 1.3, 0, 65), "timber_d")
    p.fill(p.box(-13, 14, 60, 62, -1, 1), "timber_d")
    p.fill(p.ell((-12, 64, 0), (1.8, 1.8, 1.8)), "brass")
    flag = p.box(-11, 13, 18, 60, -0.8, 0.8)
    p.fill(flag, "red")
    teeth = p.box(-11, 13, 14, 18, -0.8, 0.8) & ((np.floor(p.X + 11) % 6) < 3) | p.box(13, 16, 18, 60, -0.8, 0.8) & ((np.floor(p.Y) % 6) < 3)
    p.fill(teeth, "gold")
    p.fill(p.box(-5, 7, 30, 50, 0.8, 1.4) & ~p.box(-3, 5, 32, 48, -9, 9), "gold", flat=True)
    p.fill(p.box(-2, 4, 35, 37, 0.8, 1.4) | p.box(0, 2, 33, 47, 0.8, 1.4) | p.box(-2, 4, 43, 45, 0.8, 1.4), "ink", flat=True)
    return p


def banner_gold():
    """（原金色挂毯）横木下垂一幅红底金边幔帐，中间一块团纹"""
    p = Piece("banner_gold", 37, 33, 5, vs=2.0, seed=53)
    p.fill(p.box(-18, 18, 30, 32, -1.5, 1.5), "timber_d")
    for x in (-18, 16):
        p.fill(p.box(x, x + 2, 29, 33, -2, 2), "gold")
    sway = 0.8 * np.sin(p.X * 0.6)
    cloth = p.box(-16, 16, 4, 30, -0.8, 0.8) & (p.Y > 4 + 2.5 * np.abs(np.sin(p.X * 0.2)))
    p.fill(cloth, "red")
    p.paint(cloth & ~p.box(-14.5, 14.5, 7, 28.5, -9, 9), "gold")
    p.fill(p.disk_z(0, 17, 6, 0.8, 1.4), "gold", flat=True)
    p.fill(p.disk_z(0, 17, 4, 1.2, 1.8) & ~p.disk_z(0, 17, 2.4, 1, 2), "red_d", flat=True)
    return p


def sword_shield():
    """（原西式剑盾）墙边立一面虎头藤牌、斜插一把环首刀"""
    p = Piece("sword_shield", 29, 40, 7, vs=1.0, seed=54)
    disk = p.disk_z(0, 15, 13, -2, 2) & (((p.X) ** 2 + (p.Y - 15) ** 2 + (p.Z * 4) ** 2) <= 15 ** 2)
    p.fill(disk, grad("#7a5a30", "#a88a50", 2, 28))
    p.paint(disk & ((np.sqrt(p.X ** 2 + (p.Y - 15) ** 2) % 3.5) < 0.9), "#5c4224")
    p.fill(p.disk_z(0, 15, 6, 2, 3) & (p.Z < 3), "#c89a40")
    for sx in (-1, 1):
        p.fill(p.box(sx * 3 - 1, sx * 3 + 1, 16, 18, 2.8, 3.4), "ink", flat=True)                 # 虎眼
    p.fill(p.box(-1.5, 1.5, 19, 20, 2.8, 3.4) | p.box(-0.5, 0.5, 18, 21, 2.8, 3.4), "ink", flat=True)   # “王”
    p.fill(p.seg((-12, 2, 3), (10, 38, 3), 1.0), "stone_l")
    p.fill(p.seg((-12, 2, 3), (-9, 7, 3), 1.4), "timber_d")
    p.fill(p.disk_z(-12.5, 1.5, 2, 2.5, 3.6) & ~p.disk_z(-12.5, 1.5, 1, 2, 4), "brass")
    return p


# ======================================================================
# 第 8 条：树
# ======================================================================
def pine(name, sx, sy, sz, vs, h, seed, lean=0.0, layers=4, spread=1.0):
    """松：歪脖主干 + 几根横出的枝，枝头托一团扁平松针"""
    p = Piece(name, sx, sy, sz, vs=vs, seed=seed)
    rng = np.random.default_rng(seed)
    pts = [(0.0, 0.0, 0.0)]
    x = z = 0.0
    for i in range(1, 6):
        x += lean * h / 5 + rng.uniform(-1.5, 1.5)
        z += rng.uniform(-1.2, 1.2)
        pts.append((x, h * i / 5 * 0.82, z))
    for i in range(5):
        r0 = 3.2 - i * 0.45
        branch(p, pts[i], pts[i + 1], r0, r0 - 0.45, "bark")
    p.fill(p.ell((0, 0, 0), (5, 2.5, 5)) & (p.Y >= 0), "bark_d")       # 根盘
    tufts = [(pts[5][0], pts[5][1] + 3, pts[5][2], 10 * spread, 4, 9 * spread)]
    for k in range(layers):
        yy = h * (0.42 + 0.13 * k)
        a = rng.uniform(0, math.tau)
        L = (sx * 0.38) * (1.0 - 0.15 * k) * spread
        base = pts[min(int(yy / h * 5 / 0.82), 5)]
        ex, ez = base[0] + math.cos(a) * L, base[2] + math.sin(a) * L * (sz / sx)
        branch(p, (base[0], yy - 3, base[2]), (ex, yy, ez), 1.6, 0.9, "bark")
        tufts.append((ex, yy + 2, ez, (9 - k) * spread, 3.5, (8 - k * 0.7) * spread))
    for (cx, cy, cz, rx, ry, rz) in tufts:
        cx = float(np.clip(cx, -sx / 2 + rx, sx / 2 - rx))
        cz = float(np.clip(cz, -sz / 2 + rz, sz / 2 - rz))
        pine_tuft(p, (cx, cy, cz), rx, ry, rz)
    p.paint(p.seg(pts[0], pts[3], 3.5) & (p.rng.random(p.X.shape) < 0.25), "bark_l")
    return p


def tree_a():
    return pine("tree_a", 33, 66, 31, 2.0, 60, seed=61, lean=0.05, layers=3)


def tree_pine():
    return pine("tree_pine", 69, 108, 61, 1.4, 100, seed=62, lean=0.12, layers=4, spread=1.5)


def tree_b():
    """柳：粗短主干分三四叉，枝头垂下一条条柳丝"""
    p = Piece("tree_b", 35, 61, 37, vs=2.0, seed=63)
    rng = np.random.default_rng(63)
    branch(p, (0, 0, 0), (0.5, 26, 0), 3.4, 2.6, "bark")
    p.fill(p.ell((0, 0, 0), (5, 2.5, 5)) & (p.Y >= 0), "bark_d")
    tips = []
    for k in range(5):
        a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
        e = (math.cos(a) * 11, 42 + rng.uniform(-3, 4), math.sin(a) * 11)
        branch(p, (0.5, 24, 0), e, 2.0, 1.0, "bark")
        tips.append(e)
    crown = p.ell((0, 44, 0), (15, 9, 16)) & (p.Y > 38)
    p.fill(crown, grad("willow_d", "willow_l", 38, 53))
    p.carve(crown & (p.rng.random(p.X.shape) < 0.3) & ~p.ell((0, 44, 0), (13, 7, 14)))
    # 柳丝：从冠缘垂下来的细条，长短不一
    for k in range(40):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(9, 15.5)
        x, z = math.cos(a) * rr, math.sin(a) * rr * 1.05
        top = 44 - 2
        bot = rng.uniform(12, 30)
        p.fill(p.box(x - 0.5, x + 0.5, bot, top, z - 0.5, z + 0.5), "willow" if k % 3 else "willow_l")
    return p


def trees():
    """（原一丛树）一丛：两棵松 + 一棵小松"""
    p = Piece("trees", 120, 76, 124, vs=2.0, seed=64)
    sub = [pine("_t1", 50, 76, 50, 2.0, 70, seed=71, lean=0.1, layers=3, spread=1.1),
           pine("_t2", 44, 66, 44, 2.0, 58, seed=72, lean=-0.08, layers=3),
           pine("_t3", 36, 50, 36, 2.0, 44, seed=73, lean=0.05, layers=2)]
    offs = [(-22, -20), (24, -8), (-4, 30)]
    for s, (ox, oz) in zip(sub, offs):
        idx = np.argwhere(s.occ)
        cells = idx + np.array(s.mn) + np.array([ox, 0, oz])
        cells -= np.array(p.mn)
        ok = (cells[:, 0] >= 0) & (cells[:, 0] < p.sx) & (cells[:, 1] < p.sy) & (cells[:, 2] >= 0) & (cells[:, 2] < p.sz)
        c = cells[ok]
        p.occ[c[:, 0], c[:, 1], c[:, 2]] = True
        p.col[c[:, 0], c[:, 1], c[:, 2]] = s.col[tuple(idx[ok].T)]
    return p


def dead(name, sx, sy, sz, vs, h, seed, forks=3):
    """枯树：灰褐歪干，枝杈往上张开、枝头尖细（不要卡通的圆头）"""
    p = Piece(name, sx, sy, sz, vs=vs, seed=seed)
    rng = np.random.default_rng(seed)
    r0 = max(1.6, sx * 0.07)
    top = (rng.uniform(-sx * 0.1, sx * 0.1), h * 0.6, rng.uniform(-sz * 0.1, sz * 0.1))
    branch(p, (0, 0, 0), top, r0, r0 * 0.7, "dead")
    p.fill(p.ell((0, 0, 0), (r0 * 1.8, r0, r0 * 1.8)) & (p.Y >= 0), "dead_d")
    for k in range(forks):
        a = k / forks * math.tau + rng.uniform(-0.4, 0.4)
        L = rng.uniform(0.3, 0.45) * h
        s = (top[0], top[1] - rng.uniform(0, h * 0.2), top[2])
        e = (s[0] + math.cos(a) * min(L * 0.6, sx * 0.42), s[1] + L * 0.75, s[2] + math.sin(a) * min(L * 0.6, sz * 0.42))
        branch(p, s, e, r0 * 0.6, 0.6, "dead")
        # 二级小杈
        m = tuple(np.array(s) * 0.4 + np.array(e) * 0.6)
        e2 = (m[0] + math.cos(a + 0.9) * L * 0.25, m[1] + L * 0.25, m[2] + math.sin(a + 0.9) * L * 0.25 * (sz / sx))
        e2 = (float(np.clip(e2[0], -sx / 2 + 1, sx / 2 - 1)), min(e2[1], sy - 1), float(np.clip(e2[2], -sz / 2 + 1, sz / 2 - 1)))
        branch(p, m, e2, r0 * 0.35, 0.5, "dead_l")
    p.paint(p.occ & (p.rng.random(p.X.shape) < 0.2), "dead_d")
    return p


def tree_dead():
    return dead("tree_dead", 49, 108, 31, 1.4, 104, seed=81, forks=4)


def tree_dead_m():
    return dead("tree_dead_m", 35, 80, 11, 1.4, 76, seed=82, forks=3)


def tree_dead_s():
    return dead("tree_dead_s", 17, 36, 13, 2.0, 34, seed=83, forks=3)


# ======================================================================
# 补：井、军帐、石灯、灯杆（原来也是 KayKit 欧式的）
# ======================================================================
def well():
    """井：八角石井栏 + 木辘轳架 + 小瓦顶，井边一只木桶"""
    p = Piece("well", 35, 44, 39, vs=1.4, seed=91)
    ang = np.arctan2(p.Z, p.X)
    rr = np.sqrt(p.X ** 2 + p.Z ** 2) * np.cos((ang % (math.tau / 8)) - math.tau / 16)   # 八角形的“半径”
    p.fill((rr <= 12) & (rr > 8.5) & (p.Y < 10), grad("stone_d", "stone_l", 0, 10))
    p.fill((rr <= 12.8) & (rr > 8) & (p.Y >= 9) & (p.Y < 11), "stone_l")
    p.fill((rr <= 8.5) & (p.Y < 7), "water", flat=True)
    for sx in (-1, 1):
        p.fill(p.box(sx * 13 - 1.2, sx * 13 + 1.2, 0, 30, -1.2, 1.2), "timber")
    p.fill(p.disk_x(0, 24, 1.8, -13, 13), "timber_d")                       # 辘轳轴
    p.fill(p.disk_x(0, 24, 3.2, -4, 4), "timber_l")
    p.fill(p.box(-0.4, 0.4, 10, 24, 2.6, 3.4), "straw_d")                    # 井绳
    p.fill(p.disk_x(0, 24, 5, 13, 14.5) & ~p.disk_x(0, 24, 3.5, 12, 15), "timber_d")   # 摇把
    roof(p, -16, 16, -11, 11, 29, 38, th=2, curl=1.5)
    p.fill(p.lathe(10, 13, lambda t: 3 + 0.6 * t, 0, 5), "timber")
    p.paint(p.lathe(10, 13, lambda t: 3.7, 1, 1.8) | p.lathe(10, 13, lambda t: 3.7, 3.4, 4.2), "timber_d")
    return p


def tent():
    """军帐：人字顶厚帆布、深色包边、门帘卷起一角，顶上插一面小三角旗"""
    p = Piece("tent", 59, 58, 59, vs=1.4, seed=92)
    hw, ln = 24, 26
    ridge_y = 40
    roofm = (np.abs(p.X) <= ln) & (p.Y <= ridge_y - np.abs(p.Z) * (ridge_y - 6) / hw) & (p.Y >= 0) & (np.abs(p.Z) <= hw)
    p.fill(roofm, grad("#9c927c", "#c8bea6", 0, ridge_y))
    p.carve(roofm & (np.abs(p.X) < ln - 2) & (p.Y < ridge_y - 2 - np.abs(p.Z) * (ridge_y - 6) / hw - 0.5))   # 掏空里面一点（门洞看进去是黑的）
    p.fill((np.abs(p.X) <= ln) & (np.abs(p.Z) <= hw + 1) & (p.Y < 4) & (np.abs(p.Y - (ridge_y - np.abs(p.Z) * (ridge_y - 6) / hw)) < 2.5), "#5a4a3a")   # 下摆包边
    p.stripes("x", 8, "#857b66", 1, roofm)
    p.fill(p.box(-ln - 1, ln + 1, ridge_y - 1, ridge_y + 2, -1.5, 1.5), "#5a4a3a")      # 脊
    # 门：+z 一面不是墙，前后两头才是；门开在 +x 头
    door_m = p.box(ln - 2, ln + 1, 0, 22, -7, 7) & (p.Y < 22 - np.abs(p.Z) * 1.2)
    p.carve(door_m)
    p.fill(p.box(ln - 3, ln - 2, 0, 22, -7, 7), "#2a2224")
    p.fill(p.ell((ln + 0.5, 18, 7), (1.6, 4, 2.4)), "#a89e88")                        # 卷起的门帘
    for x in (-ln - 0.5, ln + 0.5):
        p.fill(p.cyl(x, 0, 1, 0, ridge_y + 3), "timber_d")
    # 小旗
    p.fill(p.cyl(ln + 0.5, 0, 0.7, ridge_y, ridge_y + 14), "timber_d")
    p.fill(p.box(ln + 1, ln + 9, ridge_y + 8, ridge_y + 14, -0.6, 0.6) & ((p.Y - ridge_y - 8) > (p.X - ln - 1) * 0.6 - 0.5) & ((p.Y - ridge_y - 14) < -(p.X - ln - 1) * 0.1 + 0.5), "red", flat=True)
    # 地钉拉绳
    for x in (-18, 0, 18):
        for sz in (-1, 1):
            p.fill(p.seg((x, 6, sz * (hw - 2)), (x, 0, sz * (hw + 4)), 0.4), "#6a5a44")
    return p


def lantern():
    """（原立式铁灯）石灯笼：方座、细柱、灯室（亮）、宝顶"""
    p = Piece("lantern", 21, 29, 21, vs=1.0, seed=93)
    p.fill(p.box(-8, 8, 0, 3, -8, 8), "stone_d")
    p.fill(p.box(-3, 3, 3, 12, -3, 3), "stone")
    p.fill(p.box(-6, 6, 12, 14, -6, 6), "stone_l")
    p.fill(p.box(-5, 5, 14, 21, -5, 5) & ~p.box(-3.5, 3.5, 15, 20, -9, 9), "stone")
    p.fill(p.box(-3.5, 3.5, 15, 20, -4.5, 4.5), "#e8b060", flat=True)
    p.fill(p.box(-10, 10, 21, 23, -10, 10) & (np.abs(p.X) + np.abs(p.Z) < 15), "stone_d")
    p.fill(p.lathe(0, 0, lambda t: 7 * (1 - t) + 1, 23, 27), "stone_d")
    p.fill(p.ell((0, 27.5, 0), (1.6, 1.6, 1.6)), "stone_l")
    return p


def post_lantern():
    """（原欧式灯柱）木灯杆：杆头横挑一盏红纸灯笼"""
    p = Piece("post_lantern", 17, 80, 39, vs=1.0, seed=94)
    p.fill(p.box(-4, 4, 0, 3, -4, 4), "stone_d")
    p.fill(p.box(-1.4, 1.4, 0, 72, -1.4, 1.4), grad("timber_d", "timber", 0, 72))
    p.fill(p.box(-1, 1, 68, 70, -1, 15), "timber_d")
    p.fill(p.seg((0, 60, 0), (0, 68, 8), 0.7), "timber_d")
    p.fill(p.box(-0.3, 0.3, 60, 68, 13.7, 14.3), "ink")
    lm = p.lathe(0, 14, lambda t: 5.5 * np.sin(np.clip(0.1 + t * 0.8, 0, 1) * math.pi) ** 0.6, 50, 61)
    p.fill(lm, "#e04a30", flat=True)
    p.paint(lm & (np.abs(p.Y - 55.5) < 1.2), "#f0c060", flat=True)
    p.fill(p.cyl(0, 14, 3, 49, 50.5) | p.cyl(0, 14, 3, 60.5, 62), "lacq")
    p.fill(p.box(-0.5, 0.5, 43, 49, 13.5, 14.5), "gold", flat=True)
    return p


PIECES = {
    # 第 5 条 柳溪村
    "home_a": home_a, "home_b": home_b, "tavern": tavern, "windmill": windmill, "house_ruin": house_ruin,
    # 第 6 条 无名冢
    "crypt": crypt, "grave_a": grave_a, "grave_b": grave_b, "gravestone": gravestone, "gravemarker": gravemarker,
    "gravemarker_b": gravemarker_b, "grave_broken": grave_broken, "coffin": coffin, "pumpkin": pumpkin,
    "post_skull": post_skull, "skull_candle": skull_candle,
    # 第 7 条 通用摆设
    "barrel": barrel, "barrel_small": barrel_small, "barrel_deco": barrel_deco, "keg": keg, "crates": crates, "box": box,
    "chest": chest, "chest_gold": chest_gold, "target": target, "weaponrack": weaponrack, "crate_long": crate_long,
    "crate_open": crate_open, "banner": banner, "banner_gold": banner_gold, "sword_shield": sword_shield,
    # 第 8 条 树
    "tree_a": tree_a, "tree_b": tree_b, "trees": trees, "tree_pine": tree_pine,
    "tree_dead": tree_dead, "tree_dead_m": tree_dead_m, "tree_dead_s": tree_dead_s,
    # 补
    "well": well, "tent": tent, "lantern": lantern, "post_lantern": post_lantern,
}



# ======================================================================
# 第二轮：剩下的 KayKit 通用件（墙、牌坊、柱、栏杆篱笆、桌凳、烛台火盆、麻袋柴垛、车、山石、芦苇、骨头……）
# 同样沿用原 id、原占地（size × vs 不变），摆放代码不用改
# ======================================================================
P.update({
    "brick": "#8e9094", "brick_d": "#6e7074", "brick_l": "#a2a5aa",
    "marble": "#c2bdb0", "marble_d": "#9c978a", "marble_l": "#d4d0c4",
    "bamboo": "#8f8a52", "bamboo_d": "#666236", "bamboo_l": "#aaa468",
    "hemp": "#9c8462", "hemp_d": "#7a6448", "hemp_l": "#b09a74",
    "copper": "#9a6a34", "copper_d": "#6a4622", "copper_l": "#b88446",
    "iron": "#45464c", "iron_d": "#2e2f34", "iron_l": "#62646c",
    "ember": "#e0602a", "fire": "#f0a848", "coal": "#2e221e",
    "bone": "#958a74", "bone_d": "#6e6555", "bone_l": "#aa9f88",
    "reed": "#6e8a48", "reed_d": "#4c6234", "reed_l": "#9cb064", "plume": "#b09a76",
    "rock": "#7c7a74", "rock_d": "#5a5954", "rock_l": "#959189",
    "celadon": "#7a9a88", "candle": "#b8382a",
})


def top_surface(p):
    """朝上露天的格（上面一格是空的）"""
    up = np.zeros_like(p.occ)
    up[:, :-1, :] = p.occ[:, 1:, :]
    return p.occ & ~up


def oct_r(p, cx=0.0, cz=0.0):
    """八角形“半径”（八角柱、经幢用）"""
    ax, az = np.abs(p.X - cx), np.abs(p.Z - cz)
    return np.maximum(np.maximum(ax, az), (ax + az) / 1.414)


def bricks(p, m, axis="x", course=3, blen=6, base="brick", dark="brick_d", light="brick_l"):
    """青砖：一皮一皮错缝，灰缝深色，个别砖亮一点"""
    A = p.X if axis == "x" else p.Z
    row = np.floor(p.Y / course)
    off = (row % 2) * (blen / 2)
    col = np.floor((A + off) / blen)
    p.paint(m, base)
    h = ((row.astype(np.int64) * 7919 + col.astype(np.int64) * 104729) % 11)
    p.paint(m & (h < 3), light)
    p.paint(m & (h == 10), dark)
    joint = (np.floor(p.Y) % course == 0) | (np.floor(A + off) % blen == 0)
    p.paint(m & joint, dark)


def coping(p, x0, x1, y0, hw=11.0, h=9.0, th=2.2):
    """墙头小瓦顶：两坡、瓦垄，两头不起翘（墙一段接一段地摆）"""
    p.fill(p.box(x0, x1, y0, y0 + 3, -hw + 3, hw - 3), "brick_d")              # 叠涩
    roof(p, x0, x1, -hw, hw, y0 + 2, y0 + h, th=th, curl=0.0, ends=False)


def wall_common(name, seed, kind="plain"):
    """青砖墙：石墙脚、青砖错缝、腰线、墙头小瓦顶"""
    p = Piece(name, 89, 89, 23, vs=1.0, seed=seed)
    x0, x1 = -44, 45
    p.fill(p.box(x0, x1, 0, 6, -6, 7), grad("stone_d", "stone", 0, 6))
    body = p.box(x0, x1, 6, 74, -4, 5)
    p.fill(body, "brick")
    bricks(p, body)
    p.fill(p.box(x0, x1, 22, 24, -4.6, 5.6), "stone")                          # 腰线
    p.fill(p.box(x0, x1, 70, 74, -5, 6), "brick_d")
    coping(p, x0 - 0.5, x1 + 0.5, 73, hw=9.5)
    if kind == "arch":
        # 漏窗：圆窗洞 + 石框 + 冰裂纹花格
        cy, R = 46, 15
        rr = np.sqrt(p.X ** 2 + (p.Y - cy) ** 2)
        p.carve((rr < R) & (np.abs(p.Z) < 12))
        p.fill((rr >= R) & (rr < R + 2.2) & (p.Z > -5) & (p.Z < 6), "stone_l")
        lat = (rr < R) & (p.Z > -0.6) & (p.Z < 1.6) & ((np.abs((p.X + p.Y) % 7) < 1.1) | (np.abs((p.X - p.Y) % 7) < 1.1)
                                                       | (np.abs(p.X) < 0.8) | (np.abs(p.Y - cy) < 0.8))
        p.fill(lat, "stone_d")
    elif kind == "broken":
        # 墙头一段段塌下来，按砖块成台阶；塌下的砖堆在墙根
        col = np.floor((p.X + 44) / 6)
        prof = 74 - 46 * np.exp(-((col * 6 - 50) / 22.0) ** 2)
        jit = p.rng.integers(0, 4, size=40)
        yt = np.floor((prof - jit[np.clip(col.astype(int), 0, 39)] * 3) / 3) * 3
        p.carve((p.Y >= yt) & (p.Y >= 8) & (yt < 72))
        for _ in range(26):
            bx = p.rng.uniform(-16, 34)
            bz = p.rng.choice([-1, 1]) * p.rng.uniform(7, 10)
            by = p.rng.uniform(0, 3)
            w = p.rng.choice([3.0, 6.0])
            p.fill(p.box(bx, bx + w, by, by + 3, bz - 1.5, bz + 1.5), p.rng.choice(["brick", "brick_d", "brick_l"]))
        p.paint(p.occ & (p.Y > 6) & (p.rng.random(p.X.shape) < 0.06), "moss")
    return p


def wall():
    return wall_common("wall", 101)


def wall_arch():
    """（原拱窗墙）青砖墙开一扇圆漏窗"""
    return wall_common("wall_arch", 102, "arch")


def wall_broken():
    """（原破墙）塌了半截的青砖墙"""
    return wall_common("wall_broken", 103, "broken")


def arch_gate():
    """（原石拱门）石牌坊：两根方石柱、抱鼓石、两道额枋夹一块黑底金字匾、斗拱、单檐瓦顶"""
    p = Piece("arch_gate", 83, 87, 15, vs=1.4, seed=104)
    for sx in (-1, 1):
        x = sx * 33.5
        p.fill(p.box(x - 3, x + 3, 0, 68, -3, 3.5), grad("stone_d", "stone_l", 0, 68))
        p.fill(p.box(x - 4, x + 4, 0, 3, -7, 8), "stone_d")
        for sz in (-1, 1):
            p.fill(p.box(x - 2.2, x + 2.2, 3, 6, sz * 5 - 2, sz * 5 + 2), "stone")
            p.fill(p.disk_x(sz * 5, 9.5, 4, x - 2, x + 2), "stone_l")             # 抱鼓石
            p.paint(p.disk_x(sz * 5, 9.5, 2, x - 2.5, x + 2.5), "stone_d")
        # 雀替
        p.fill(p.box(x - sx * 9 - 3, x - sx * 3 + 3, 40, 46, -2, 2.5) & ((p.Y - 40) > (np.abs(p.X - x) - 3) * 0.7), "stone")
    p.fill(p.box(-37, 37, 46, 50, -2.5, 3), "stone")                               # 下额枋
    p.fill(p.box(-38, 38, 58, 62, -2.5, 3), "stone")                               # 上额枋
    p.stripes("x", 9, "stone_d", 1, p.box(-37, 37, 46, 50, -9, 9) | p.box(-38, 38, 58, 62, -9, 9))
    plaque = p.box(-11, 11, 50, 58, -1.5, 3.4)
    p.fill(plaque, "lacq")
    p.paint(plaque & ~p.box(-10, 10, 51, 57, -9, 9), "gold")
    for x in (-6, -1, 4):
        p.fill(p.box(x, x + 2.5, 52.5, 55.5, 3.2, 3.9), "gold", flat=True)       # 三个金字
    p.fill(p.box(-38, 38, 50, 58, -1, 2) & ~plaque, "stone_d")                    # 字板（花板）
    # 斗拱一排
    p.fill(p.box(-40, 40, 62, 65, -4, 4.5), "stone_d")
    for x in range(-36, 38, 6):
        p.fill(p.box(x - 1.5, x + 1.5, 62, 66, -5, 5.5), "red_d")
    roof(p, -42, 42, -7.5, 8, 66, 79, th=2.2, curl=2.2, ends=True)
    p.paint(p.occ & (p.Y < 46) & (p.rng.random(p.X.shape) < 0.07), "moss")
    return p


def pillar():
    """（原雕花石柱）石经幢：须弥座、八角幢身刻经、宝盖、小龛、八角攒尖顶、仰莲宝珠"""
    p = Piece("pillar", 45, 81, 35, vs=1.0, seed=105)
    r = oct_r(p)
    p.fill(p.box(-20, 21, 0, 4, -16, 17), "stone_d")
    p.fill((r < 14) & (p.Y >= 4) & (p.Y < 10), "stone")
    p.paint((r < 14) & (np.abs(p.Y - 7) < 1), "stone_d")
    p.fill((r < 15.5) & (p.Y >= 10) & (p.Y < 13), "stone_l")                       # 覆莲
    p.paint((r < 15.5) & (p.Y >= 10) & (p.Y < 13) & ((np.floor(np.degrees(np.arctan2(p.Z, p.X)) / 15) % 2) == 0), "stone")
    shaft = (r < 6) & (p.Y >= 13) & (p.Y < 44)
    p.fill(shaft, grad("stone_d", "stone_l", 13, 44))
    # 幢身刻经：每面一竖行竖槽
    ang = np.degrees(np.arctan2(p.Z, p.X)) % 45
    p.paint(shaft & (np.abs(ang - 22.5) < 6) & ((np.floor(p.Y) % 3) != 0) & (r > 5), "stone_d")
    p.fill((r < 11) & (p.Y >= 44) & (p.Y < 48), "stone")                           # 宝盖
    p.fill((r < 11) & (r > 9.5) & (p.Y >= 41) & (p.Y < 44) & ((np.floor(np.degrees(np.arctan2(p.Z, p.X)) / 11.25) % 2) == 0), "stone_d")
    s2 = (r < 4.6) & (p.Y >= 48) & (p.Y < 60)
    p.fill(s2, "stone")
    p.paint(s2 & (np.abs(ang - 22.5) < 9) & (p.Y > 51) & (p.Y < 57) & (r > 3.6), "ink")   # 小佛龛
    p.fill((r < 10 - (p.Y - 60) * 1.05) & (p.Y >= 60) & (p.Y < 68), "stone_d")     # 八角攒尖（石刻的檐）
    p.paint((r < 10.5) & (r > 8.6) & (p.Y >= 60) & (p.Y < 62), "stone")
    p.paint((r < 10.5) & (p.Y >= 60) & (p.Y < 68) & (np.abs(np.degrees(np.arctan2(p.Z, p.X)) % 45 - 22.5) > 20), "stone_l")   # 八条戗脊
    p.fill((r < 4.5) & (p.Y >= 68) & (p.Y < 72), "stone_l")                         # 仰莲
    p.fill(p.ell((0, 75.5, 0), (3.4, 4, 3.4)), "stone_l")                            # 宝珠
    p.fill(p.ell((0, 79.5, 0), (1.4, 1.5, 1.4)), "stone_l")
    p.paint(p.occ & (p.Y < 44) & (p.rng.random(p.X.shape) < 0.08), "moss")
    return p


def column():
    """（原短石柱）断石柱：莲瓣柱础 + 八角柱身，上头断口参差，长青苔"""
    p = Piece("column", 15, 29, 15, vs=1.0, seed=106)
    r = oct_r(p)
    p.fill(p.box(-7, 8, 0, 3, -7, 8), "stone_d")
    p.fill((r < 6.8) & (p.Y >= 3) & (p.Y < 6), "stone")
    p.paint((r < 6.8) & (p.Y >= 3) & (p.Y < 6) & ((np.floor(np.degrees(np.arctan2(p.Z, p.X)) / 22.5) % 2) == 0), "stone_l")
    ang = np.arctan2(p.Z, p.X)
    top = 22 + 4 * np.sin(ang * 2 + 0.7) + 2 * np.cos(ang * 5)
    shaft = (r < 4.4) & (p.Y >= 6) & (p.Y < top)
    p.fill(shaft, grad("stone_d", "stone_l", 6, 28))
    p.stripes("y", 7, "stone_d", 1, shaft)
    p.paint(top_surface(p) & (p.Y > 10), "moss")
    p.fill(p.box(5, 8, 0, 2, -6, -2), "stone")                                      # 掉下的一块
    return p


def balustrade(p, x0, x1, zc, top=11.0):
    """汉白玉栏板：地栿 + 栏板开宝瓶洞 + 圆寻杖"""
    p.fill(p.box(x0, x1, 0, 2, zc - 2.0, zc + 2.0), "marble_d")
    p.fill(p.box(x0, x1, 2, top - 2, zc - 1.0, zc + 1.0), "marble")
    w = x1 - x0
    for k in range(2):
        a = x0 + w * (0.08 + 0.46 * k)
        b = a + w * 0.38
        p.carve(p.box(a, b, 3.5, top - 3.2, zc - 2, zc + 2))
        c = (a + b) / 2
        vase = (np.abs(p.X - c) <= 0.9 + 1.0 * np.exp(-((p.Y - (top + 0.5) / 2) / 1.3) ** 2)) & p.box(a, b, 3.5, top - 3.2, zc - 1, zc + 1)
        p.fill(vase, "marble_l")
    p.fill(((p.Y - (top - 1)) ** 2 + (p.Z - zc) ** 2 <= 1.5 ** 2) & (p.X >= x0) & (p.X < x1), "marble_l")


def barrier():
    """（原石栏）汉白玉栏板"""
    p = Piece("barrier", 41, 12, 5, vs=2.0, seed=107)
    balustrade(p, -20, 21, 0.5)
    return p


def barrier_col():
    """（原带柱石栏）汉白玉栏板，中间一根望柱（莲头）"""
    p = Piece("barrier_col", 41, 15, 7, vs=2.0, seed=108)
    balustrade(p, -20, 21, 0.5)
    p.fill(p.box(-2, 2, 0, 12, -1.5, 2.5), "marble")
    p.fill(p.box(-2.5, 2.5, 11.5, 12.5, -2, 3), "marble_d")
    p.fill(p.ell((0, 13.5, 0.5), (1.8, 1.6, 1.8)), "marble_l")
    return p


def bamboo_pole(p, x, z, r, y0, y1, slant=0.0, col="bamboo"):
    m = p.cyl(x, z, r, y0, y1) & (p.Y < y1 - (p.X - x) * slant)
    p.fill(m, grad(col + "_d", col + "_l", y0, y1) if col + "_d" in P else col)
    p.paint(m & (np.floor(p.Y) % 9 == 0), "bamboo_d")                              # 竹节
    return m


def bamboo_fence(p, x0, x1, broken=False):
    """竹篱笆：粗竹立柱 + 上下横杆 + 斜编菱格"""
    lat = p.box(x0, x1, 5, 36, -0.8, 0.8) & ((np.floor(p.X + p.Y) % 9 < 1.5) | (np.floor(p.X - p.Y) % 9 < 1.5))
    if broken:
        hole = p.box(-8, 16, 0, 99, -9, 9) & (p.Y > 6 + 12 * np.abs(np.sin(p.X * 0.35)))
        lat &= ~hole
    p.fill(lat, "bamboo_l")
    for yc in (6, 35):
        rail = ((p.Y - yc) ** 2 + (p.Z - 1.6) ** 2 <= 1.3 ** 2) & (p.X >= x0) & (p.X < x1)
        if broken and yc == 35:
            rail &= ~p.box(-6, 14, 0, 99, -9, 9)
        p.fill(rail, "bamboo")
    for x in np.arange(x0 + 2, x1, 19.5):
        if broken and -6 < x < 14:
            continue
        bamboo_pole(p, x, 0, 1.9, 0, 40 + p.rng.uniform(-2, 3), slant=0.6)
        for yc in (6, 35):
            p.fill(p.box(x - 2.2, x + 2.2, yc - 1, yc + 1, -2.4, 3.2), "straw_d")   # 草绳扎结


def fence():
    """（原木栅栏）竹篱笆"""
    p = Piece("fence", 81, 45, 11, vs=1.0, seed=109)
    bamboo_fence(p, -40, 41)
    return p


def fence_broken():
    """（原破栅栏）破竹篱：中间一段倒了，一根竹竿斜倒在地上"""
    p = Piece("fence_broken", 81, 45, 11, vs=1.0, seed=110)
    bamboo_fence(p, -40, 41, broken=True)
    p.fill(p.seg((-6, 1.5, 3.5), (18, 9, 3), 1.6), "bamboo")
    p.fill(p.box(-4, 12, 0, 1.5, -4, -1) & ((np.floor(p.X) % 3) == 0), "bamboo_l")
    bamboo_pole(p, 2, 0, 1.9, 0, 14, slant=0.6)                                       # 断了的半截竹桩
    return p


def fence_pillar():
    """（原篱笆桩）拴马桩：木桩、缠草绳、桩头系一条红布"""
    p = Piece("fence_pillar", 5, 23, 5, vs=2.0, seed=111)
    p.fill(p.box(-1.5, 2.5, 0, 21, -1.5, 2.5) & (p.Y < 22 - np.abs(p.X - 0.5) * 0.8), grad("timber_d", "timber_l", 0, 21))
    p.fill(p.box(-2, 3, 14, 15.5, -2, 3), "straw_d")
    p.fill(p.box(-2, 3, 4, 5, -2, 3), "straw_d")
    p.fill(p.box(0, 1.5, 8, 14, 2.5, 3.2), "red", flat=True)
    return p


def fence_stone():
    """（原石墙段）矮石栏：石座 + 栏板 + 四根望柱（沿 z 摆）"""
    p = Piece("fence_stone", 11, 14, 57, vs=2.0, seed=112)
    p.fill(p.box(-4, 5, 0, 2, -28, 29), "stone_d")
    p.fill(p.box(-1.5, 2.5, 2, 9, -28, 29), grad("stone_d", "stone", 2, 9))
    p.carve(p.box(-3, 4, 4, 7.5, -28, 29) & ((np.floor(p.Z + 28) % 8) > 2) & (np.abs(((p.Z + 28) % 17) - 8.5) > 3))
    p.fill(((p.Y - 10) ** 2 + (p.X - 0.5) ** 2 <= 1.4 ** 2) & (p.Z >= -28) & (p.Z < 29), "stone_l")
    for z in (-26, -9, 8, 25):
        p.fill(p.box(-1.5, 2.5, 0, 12, z - 1.5, z + 1.5), "stone")
        p.fill(p.ell((0.5, 12.6, z), (1.8, 1.4, 1.8)), "stone_l")
    p.paint(top_surface(p) & (p.rng.random(p.X.shape) < 0.07), "moss")
    return p


def fence_wood():
    """（原木篱段）削尖的木栅（沿 z 摆）"""
    p = Piece("fence_wood", 3, 14, 29, vs=2.0, seed=113)
    for z in np.arange(-13, 15, 2.2):
        h = 11 + p.rng.uniform(0, 2.5)
        p.fill(p.box(-1, 1.6, 0, h, z - 0.9, z + 0.9) & (p.Y < h - np.abs(p.Z - z) * 1.6), grad("timber_d", "timber_l", 0, 13))
    for y in (3.5, 8.5):
        p.fill(p.box(1, 2, y, y + 1, -14, 15), "timber_d")
        p.fill(p.box(0.6, 2, y - 0.3, y + 1.3, -14, 15) & ((np.floor(p.Z) % 9) == 0), "straw_d")
    return p


def bench():
    """（原雕花长椅）美人靠长凳：厚板凳面、八字腿、后面一排靠栏"""
    p = Piece("bench", 41, 35, 21, vs=1.0, seed=114)
    p.fill(p.box(-19, 20, 13, 16, -6, 7), "timber_l")
    p.paint(p.box(-19, 20, 15, 16, -6, 7) & ((np.floor(p.Z) % 4) == 0), "timber")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.fill(p.seg((sx * 16.5, 0, sz * 5), (sx * 15, 13, sz * 3.5), 1.1), "timber_d")
        p.fill(p.box(sx * 15.5 - 1, sx * 15.5 + 1, 5, 6.5, -5, 6), "timber_d")
    p.fill(p.box(-15, 16, 5, 6.5, -0.5, 1.5), "timber_d")
    zc = lambda y: -5.0 - (y - 16) * 0.28
    back = (p.Y >= 16) & (p.Y < 33)
    spindle = back & ((np.floor(p.X + 19) % 3) == 0) & (np.abs(p.Z - zc(p.Y)) < 0.8) & (p.X > -19) & (p.X < 20)
    p.fill(spindle, "red_d")
    for y0 in (16, 31):
        p.fill((p.Y >= y0) & (p.Y < y0 + 2) & (np.abs(p.Z - zc(p.Y)) < 1.1) & (p.X >= -19) & (p.X < 20), "red")
    return p


def table():
    """（原断腿长桌）断了两条腿、一头斜塌在地上的翘头长条案"""
    p = Piece("table", 45, 24, 81, vs=1.0, seed=115)
    yt = 5 + (p.Z + 37) / 74 * 14                       # 案面高度：-z 一头着地，+z 一头还架着
    top = (np.abs(p.X - 0.5) < 15) & (p.Z >= -37) & (p.Z < 37) & (p.Y >= yt) & (p.Y < yt + 2.5)
    p.fill(top, "timber")
    p.paint(top & (p.Y >= yt + 1.8), "timber_d")
    p.fill((np.abs(p.X - 0.5) < 15) & (p.Z >= 34) & (p.Z < 37) & (p.Y >= yt) & (p.Y < yt + 2.5 + 2.5 * np.abs(p.X - 0.5) / 15), "timber_d")   # 翘头
    for sx in (-1, 1):
        x = 0.5 + sx * 12
        p.fill(p.box(x - 1.3, x + 1.3, 0, 19, 29, 32), "timber")                    # +z 两条腿完好
        p.fill(p.box(x - 1.3, x + 1.3, 0, 4, -33, -30), "timber")                   # -z 两条断了
        p.fill(p.box(x - 1.3, x + 1.3, 13, 19, 30.5, 31.5) | p.box(x - 1.3, x + 1.3, 15, 18.5, 22, 32) & (p.Y > 15 + (32 - p.Z) * 0.35), "timber_d")
    p.fill(p.box(-12, 13, 15, 17.5, 30.5, 31.5), "timber")                            # 牙板
    p.fill(p.seg((19, 1.2, -30), (21, 1.2, -8), 1.3), "timber")                         # 掉在旁边的断腿
    p.fill(p.box(-6, 6, 0, 1, -36, -20) & (p.rng.random(p.X.shape) < 0.2), "paper_d")  # 撒了一地的纸
    return p


def table_m():
    """（原铺布方桌）供桌：方桌前垂红桌围（金边团纹），桌上香炉、一对红烛、两盘供果"""
    p = Piece("table_m", 19, 18, 19, vs=2.0, seed=116)
    p.fill(p.box(-9, 10, 12, 13.5, -9, 10), "red_d")
    p.fill(p.box(-9.5, 10.5, 13, 13.5, -9.5, 10.5), "lacq")
    for sx in (-8, 8):
        for sz in (-8, 8):
            p.fill(p.box(sx - 0.5, sx + 1.5, 0, 12, sz - 0.5, sz + 1.5), "lacq")
    cloth = p.box(-8.5, 9.5, 3, 12, 9.2, 10.2)
    p.fill(cloth, "red")
    p.paint(cloth & ~p.box(-7.5, 8.5, 4, 11, -99, 99), "gold")
    p.fill(p.disk_z(0.5, 7.5, 2.4, 9.9, 10.6), "gold", flat=True)
    p.fill(p.lathe(0.5, -3, lambda t: 2.2 - 0.4 * t, 13.5, 16), "bronze")             # 香炉
    p.fill(p.box(0, 1, 16, 18, -3.4, -2.6), "#d8b070", flat=True)
    for sx in (-1, 1):
        p.fill(p.cyl(0.5 + sx * 6, -4, 0.8, 13.5, 17.5), "candle")
        p.fill(p.box(0.5 + sx * 6 - 0.3, 0.5 + sx * 6 + 0.7, 17.5, 18, -4.3, -3.3), "fire", flat=True)
        p.fill(p.cyl(0.5 + sx * 4.5, 4, 2, 13.5, 14.2), "white")                      # 盘子
        p.fill(p.ell((0.5 + sx * 4.5, 15.2, 4), (1.6, 1.2, 1.6)), "#c87a2a")           # 橘子
    return p


def table_s():
    """（原小圆桌）香几：圆面、三条弯腿、托泥圈，几上一只青瓷瓶插一枝梅"""
    p = Piece("table_s", 11, 16, 11, vs=2.0, seed=117)
    p.fill(p.cyl(0.5, 0.5, 4.6, 10.5, 12), "timber_d")
    p.fill(p.cyl(0.5, 0.5, 4.9, 11.4, 12), "lacq")
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        c, s = math.cos(a), math.sin(a)
        p.fill(p.seg((0.5 + c * 3.6, 10.5, 0.5 + s * 3.6), (0.5 + c * 4.4, 5, 0.5 + s * 4.4), 0.7) | p.seg((0.5 + c * 4.4, 5, 0.5 + s * 4.4), (0.5 + c * 3.4, 0, 0.5 + s * 3.4), 0.7), "timber_d")
    p.fill(p.cyl(0.5, 0.5, 4.2, 2, 3) & ~p.cyl(0.5, 0.5, 3.2, 0, 9), "timber_d")
    p.fill(p.lathe(0.5, 0.5, lambda t: 1.0 + 0.9 * np.sin(np.clip(t * 1.2, 0, 1) * math.pi) * (1 - 0.4 * t), 12, 15), "celadon")
    p.fill(p.seg((0.5, 14.5, 0.5), (2.5, 16, 0.5), 0.45), "bark_d")
    p.fill(p.box(2, 3.2, 15, 16, 0, 1.4), "#d86a78", flat=True)
    return p


def shrine():
    """（原烛台神龛）路边土地庙：石台、青砖三面墙、小瓦顶、红柱红联，里面坐着土地公，供台上一对红烛"""
    p = Piece("shrine", 25, 40, 25, vs=1.0, seed=118)
    p.fill(p.box(-12, 13, 0, 5, -11, 12), grad("stone_d", "stone", 0, 5))
    wallm = (p.box(-10, 11, 5, 27, -10, -7) | p.box(-10, -7, 5, 27, -10, 8) | p.box(8, 11, 5, 27, -10, 8))
    p.fill(wallm, "brick")
    bricks(p, wallm, axis="z", course=2, blen=4)
    for x in (-9.5, 9.5):
        p.fill(p.box(x - 1.2, x + 1.2, 5, 27, 7.5, 10), "red")
        p.fill(p.box(x - 1, x + 1, 9, 22, 9.6, 10.4), "paper", flat=True)          # 红柱上贴的对联（白纸）
        p.fill(p.box(x - 0.4, x + 0.4, 10, 21, 10.2, 10.6), "ink", flat=True)
    p.fill(p.box(-10, 11, 23, 27, 7, 10.5), "red_d")                                  # 门楣
    p.fill(p.box(-7, 8, 5, 9, -7, 7), "stone")                                       # 供台
    # 土地公：坐像
    p.fill(p.ell((0.5, 12, -4), (4, 4.5, 3)) & (p.Y >= 9), "#7a5a3a")
    p.fill(p.ell((0.5, 18, -4), (2.2, 2.4, 2.2)), "#c4a07c")
    p.fill(p.box(-1, 2, 14.5, 17.5, -2.6, -1.6), "white")                            # 白胡子
    p.fill(p.box(-2, 3, 20, 21.5, -6, -2), "lacq")                                   # 帽子
    p.fill(p.ell((0.5, 12, -1.5), (3, 1.4, 1)) & (p.Y > 11), "red", flat=True)
    for sx in (-1, 1):
        p.fill(p.cyl(0.5 + sx * 4, 5, 0.8, 9, 11.5), "candle")
        p.fill(p.box(0.5 + sx * 4 - 0.3, 0.5 + sx * 4 + 0.7, 11.5, 12.5, 4.7, 5.7), "fire", flat=True)
    p.fill(p.lathe(0.5, 2, lambda t: 1.6 - 0.3 * t, 9, 10.5), "bronze")
    # 山墙 + 瓦顶
    for x0 in (-10, 8):
        p.fill(p.box(x0, x0 + 3, 27, 34, -10, 10) & (p.Y < 34 - np.abs(p.Z) * 0.65), "brick_d")
    p.fill(p.box(-10, 11, 27, 30, -10, -7), "brick_d")
    roof(p, -13, 14, -12.5, 13, 27, 34, th=2.2, curl=1.6, ends=True)
    return p


def candles():
    """（原三联蜡烛）铜烛台插三支红烛"""
    p = Piece("candles", 15, 24, 11, vs=1.0, seed=119)
    p.fill(p.lathe(0.5, 0.5, lambda t: 4.2 - 1.6 * t, 0, 2.5), "bronze")
    p.fill(p.cyl(0.5, 0.5, 1.1, 2.5, 10), "bronze_d")
    p.fill(p.cyl(0.5, 0.5, 2.2, 5, 6.2), "bronze")
    p.fill(p.ell((0.5, 10.5, 0.5), (7.2, 1.2, 4.6)), "bronze")
    for x, h in ((0.5, 21), (-4.3, 17.5), (5.3, 17.5)):
        p.fill(p.cyl(x, 0.5, 1.4, 11, h), "candle")
        p.paint(p.cyl(x, 0.5, 1.5, h - 1.2, h) & (p.rng.random(p.X.shape) < 0.5), "#d8c8a8")   # 烛泪
        p.fill(p.box(x - 0.5, x + 0.5, h, h + 1.5, 0, 1), "fire", flat=True)
    p.fill(p.box(-0.3, 1.3, 2.5, 5, 0.3, 0.7) & False, "gold")
    return p


def torch():
    """（原立式火把）三足铁火盆：盆里炭火通红"""
    p = Piece("torch", 15, 30, 15, vs=1.0, seed=120)
    for k in range(3):
        a = k / 3 * math.tau + math.pi / 2
        c, s = math.cos(a), math.sin(a)
        p.fill(p.seg((0.5 + c * 6.2, 0, 0.5 + s * 6.2), (0.5 + c * 3, 21, 0.5 + s * 3), 0.85), "iron")
        p.fill(p.ell((0.5 + c * 6.2, 0.5, 0.5 + s * 6.2), (1.3, 0.8, 1.3)), "iron_d")
    p.fill(p.cyl(0.5, 0.5, 4.2, 9, 10.2) & ~p.cyl(0.5, 0.5, 3.4, 0, 99), "iron")    # 箍
    bowl = p.lathe(0.5, 0.5, lambda t: 3.2 + 3.8 * t ** 0.8, 20, 26)
    p.fill(bowl, "iron_d")
    p.paint(bowl & (p.Y >= 25), "iron_l")
    p.fill(p.ell((0.5, 26, 0.5), (5.6, 1.4, 5.6)) & (p.Y >= 25.5), "coal")
    p.paint(p.ell((0.5, 26.5, 0.5), (4.8, 1.4, 4.8)) & (p.rng.random(p.X.shape) < 0.55), "ember", flat=True)
    p.fill(p.lathe(0.5, 0.5, lambda t: 3.0 * (1 - t), 26.5, 29.5), "fire", flat=True)
    return p


def torch_wall():
    """（原壁挂火把）墙上的铁灯架：背板、挑臂，挑着一只小火盆"""
    p = Piece("torch_wall", 15, 29, 17, vs=1.0, seed=121)
    p.fill(p.box(-2.5, 3.5, 9, 24, -8, -6.5), "iron")
    p.paint(p.box(-2.5, 3.5, 9, 24, -8, -6.5) & ((np.abs(p.Y - 12) < 0.6) | (np.abs(p.Y - 21) < 0.6)), "iron_l")
    p.fill(p.seg((0.5, 21, -7), (0.5, 21, 3), 0.8), "iron")
    p.fill(p.seg((0.5, 12, -7), (0.5, 20, 2), 0.7), "iron")
    bowl = p.lathe(0.5, 3, lambda t: 1.8 + 2.6 * t, 20.5, 24.5)
    p.fill(bowl, "iron_d")
    p.fill(p.ell((0.5, 24.5, 3), (3.6, 1, 3.6)) & (p.Y >= 24), "ember", flat=True)
    p.fill(p.lathe(0.5, 3, lambda t: 2.2 * (1 - t), 25, 28), "fire", flat=True)
    return p


def lantern_hang():
    """（原吊灯）竹竿挑一盏小红灯笼"""
    p = Piece("lantern_hang", 11, 22, 11, vs=2.0, seed=122)
    p.fill(p.box(-5, -1.5, 0, 1.2, -1.5, 2), "stone_d")
    bamboo_pole(p, -3.5, 0.5, 0.8, 0, 21)
    p.fill(p.box(-3.5, 3, 19.5, 20.5, 0, 1), "bamboo_d")
    p.fill(p.box(1.6, 2.2, 15, 19.5, 0.2, 0.8), "ink")
    lm = p.lathe(1.9, 0.5, lambda t: 3.0 * np.sin(np.clip(0.12 + t * 0.76, 0, 1) * math.pi) ** 0.6, 8, 15)
    p.fill(lm, "#d04a32", flat=True)
    p.paint(lm & (np.abs(p.Y - 11.5) < 0.6), "#f0c060", flat=True)
    p.fill(p.cyl(1.9, 0.5, 1.6, 7.3, 8) | p.cyl(1.9, 0.5, 1.6, 15, 15.7), "lacq")
    p.fill(p.box(1.4, 2.4, 4.5, 7.3, 0, 1), "gold", flat=True)
    return p


def shelf():
    """（原小烛架）供架：三块黑漆金字牌位，下层一对红烛、一只香碗"""
    p = Piece("shelf", 21, 21, 11, vs=1.0, seed=123)
    p.fill(p.box(-9, 10, 0, 20, -5, -3.8), "red_d")
    for x in (-10, 9):
        p.fill(p.box(x, x + 2, 0, 20, -5, 5), "timber_d")
    for y in (7, 13):
        p.fill(p.box(-10, 11, y, y + 1.2, -5, 5.5), "timber")
    p.fill(p.box(-10, 11, 0, 2, -5, 5), "timber_d")
    for x in (-5.5, 0.5, 6.5):
        tab = p.box(x - 1.6, x + 1.6, 14.2, 20.5, -1.5, 0.5) & ((p.Y < 19.5) | (np.abs(p.X - x) < 1.6 - (p.Y - 19.5)))
        p.fill(tab, "lacq")
        p.fill(p.box(x - 0.4, x + 0.4, 15.5, 19, 0.5, 1.0), "gold", flat=True)
        p.fill(p.box(x - 2, x + 2, 14.2, 15.2, -2, 1), "timber_d")
    for x in (-6, 7):
        p.fill(p.cyl(x, 0.5, 0.8, 8.2, 11.5), "candle")
        p.fill(p.box(x - 0.4, x + 0.6, 11.5, 12.3, 0.1, 0.9), "fire", flat=True)
    p.fill(p.lathe(0.5, 0.5, lambda t: 1.8 + 0.6 * t, 8.2, 10), "bronze")
    p.fill(p.box(0, 1, 10, 12.5, 0, 1), "#d8b070", flat=True)
    return p


def coins():
    """（原金币堆）三只金元宝、几串铜钱、几枚散钱"""
    p = Piece("coins", 17, 14, 19, vs=2.0, seed=124)

    def ingot(cx, y0, cz, s=1.0):
        m = p.ell((cx, y0 + 1.4 * s, cz), (3.6 * s, 1.8 * s, 2.3 * s)) & (p.Y >= y0)
        m |= p.ell((cx - 2.8 * s, y0 + 2.6 * s, cz), (1.3 * s, 1.5 * s, 2.0 * s)) | p.ell((cx + 2.8 * s, y0 + 2.6 * s, cz), (1.3 * s, 1.5 * s, 2.0 * s))
        m |= p.ell((cx, y0 + 3.0 * s, cz), (1.3 * s, 1.3 * s, 1.3 * s))
        p.fill(m, grad("gold", "#f0cc6a", y0, y0 + 4 * s))
    ingot(-3.5, 0, -3)
    ingot(3.5, 0, -2)
    ingot(0, 3.0, -2.5, 0.9)
    for k, (x0, z0, x1, z1) in enumerate(((-7, 3, 6, 6), (-6, 6.5, 7, 8.5), (2, -8, 7, 1))):
        s = p.seg((x0, 1.2, z0), (x1, 1.2, z1), 1.3)
        p.fill(s, "copper")
        d = np.array([x1 - x0, z1 - z0], float)
        d /= np.linalg.norm(d)
        p.paint(s & ((np.floor((p.X - x0) * d[0] + (p.Z - z0) * d[1]) % 2) == 0), "copper_d")
        p.fill(p.ell((x0, 1.4, z0), (1, 1, 1)), "red")                                # 串钱的红绳头
    for _ in range(6):
        cx, cz = p.rng.uniform(-7, 8), p.rng.uniform(-8, 9)
        p.fill(p.cyl(cx, cz, 1.2, 0, 0.8) & ~p.occ, "copper_l")
    return p


def flag():
    """（原红旗）三角令旗：红底、黑火焰齿边、白圆心一个黑字（旗面在 y-z 面上，朝 x 看）"""
    p = Piece("flag", 9, 46, 43, vs=2.0, seed=125)
    pz = -19
    p.fill(p.cyl(0.5, pz, 1.0, 0, 43), "timber_d")
    p.fill(p.lathe(0.5, pz, lambda t: 1.4 * (1 - t), 43, 46), "brass")
    p.fill(p.cyl(0.5, pz, 1.6, 41.5, 43), "red")                                       # 红缨
    u = np.clip((p.Z - pz) / 36.0, 0, 1)
    wave = 0.9 * np.sin(p.Z * 0.32)
    cloth = (p.Z > pz) & (p.Z < pz + 36) & (p.Y < 43 - u * 3) & (p.Y > 24 + u * 13) & (np.abs(p.X - 0.5 - wave) < 0.8)
    p.fill(cloth, "red", flat=True)
    p.paint(cloth & (p.Y > 30 + u * 8), "red_l", flat=True)
    edge = cloth & ((p.Y > 42 - u * 3) | (p.Y < 25.5 + u * 13 + 1.2 * (np.floor(p.Z) % 4 < 2)) | (p.Z > pz + 34.5))
    p.paint(edge, "gold", flat=True)
    disk = cloth & ((p.Z - (pz + 12)) ** 2 + (p.Y - 35) ** 2 <= 16)
    p.paint(disk, "paper", flat=True)
    p.paint(disk & ((np.abs(p.Z - (pz + 12)) < 0.6) | (np.abs(p.Y - 35) < 0.6) & (np.abs(p.Z - (pz + 12)) < 2.6)), "ink", flat=True)
    return p


def arrows():
    """（原箭桶）黑漆箭壶插一把雕翎箭"""
    p = Piece("arrows", 7, 12, 7, vs=2.0, seed=126)
    q = p.lathe(0.5, 0.5, lambda t: 2.4 + 0.5 * t, 0, 7)
    p.fill(q, "lacq")
    p.paint(q & ((np.abs(p.Y - 1) < 0.6) | (np.abs(p.Y - 6.2) < 0.6)), "brass")
    p.fill(p.box(0, 1, 3, 4.5, 2.6, 3.4), "red", flat=True)
    for k in range(7):
        a = k / 7 * math.tau
        r0 = 1.2 if k else 0
        x0, z0 = 0.5 + math.cos(a) * r0, 0.5 + math.sin(a) * r0
        x1, z1 = 0.5 + math.cos(a) * r0 * 1.8, 0.5 + math.sin(a) * r0 * 1.8
        p.fill(p.seg((x0, 6, z0), (x1, 10.5, z1), 0.45), "timber_l")
        p.fill(p.seg((x1, 10, z1), (x1 + (x1 - x0) * 0.3, 12, z1 + (z1 - z0) * 0.3), 0.7), "white", flat=True)
    return p


def bucket():
    """（原水桶）木水桶：竹篾箍、提梁，里面半桶水"""
    p = Piece("bucket", 11, 9, 11, vs=2.0, seed=127)
    b = p.lathe(0.5, 0.5, lambda t: 4.0 + 0.6 * t, 0, 6) & ~p.lathe(0.5, 0.5, lambda t: 3.2 + 0.6 * t, 1, 7)
    p.fill(b, "timber")
    p.stripes("x", 2, "timber_d", 1, b & (np.abs(p.Z - 0.5) > 2))
    p.paint(b & ((np.abs(p.Y - 1.2) < 0.6) | (np.abs(p.Y - 4.8) < 0.6)), "bamboo_d")
    p.fill(p.cyl(0.5, 0.5, 3.6, 1, 4.6), "water", flat=True)
    for sx in (-1, 1):
        p.fill(p.box(0.5 + sx * 4 - 0.6, 0.5 + sx * 4 + 0.6, 5, 8.5, 0, 1), "timber_d")
    p.fill(p.box(-3.5, 4.5, 7.5, 8.6, 0, 1), "timber_d")
    return p


def sack():
    """（原麻袋）粮袋：粗麻编纹、袋口扎绳，贴一张红纸"""
    p = Piece("sack", 25, 15, 35, vs=1.0, seed=128)
    body = ((p.X / 10.5) ** 4 + ((p.Y - 6) / 6.2) ** 2 + ((p.Z + 1.5) / 14) ** 4 <= 1) & (p.Y >= 0)
    p.fill(body, grad("hemp_d", "hemp_l", 0, 12))
    p.paint(body & (((np.floor(p.X) + np.floor(p.Z)) % 2) == 0) & (p.rng.random(p.X.shape) < 0.35), "hemp_d")
    p.fill(p.ell((0.5, 5.5, 13.5), (3.2, 3, 2.4)), "hemp")
    p.fill(p.cyl(0.5, 5.5, 3.6, 0, 99, rz=99) & p.box(-4, 5, 2, 9, 13, 14.5), "straw_d")
    p.fill(p.ell((0.5, 5.5, 16), (4.2, 3.6, 1.4)), "hemp_l")
    lab = top_surface(p) & p.box(-3.5, 4.5, 0, 99, -6, 0)
    p.paint(lab, "red", flat=True)
    p.paint(lab & ((np.abs(p.X - 0.5) < 0.6) | (np.abs(p.Z + 3) < 0.6)), "ink", flat=True)
    return p


def lumber():
    """（原原木堆）柴垛：圆木码成三层，端面年轮，草绳捆两道"""
    p = Piece("lumber", 79, 25, 39, vs=1.0, seed=129)
    r = 4.4
    rows = [(r, (-13.5, -4.5, 4.5, 13.5)), (r * 2.75, (-9, 0, 9)), (r * 4.5, (-4.5, 4.5))]
    for yc, zs in rows:
        for zc in zs:
            x0, x1 = -37 + p.rng.uniform(0, 4), 37 - p.rng.uniform(0, 4)
            lg = ((p.Y - yc) ** 2 + (p.Z - zc) ** 2 <= r * r) & (p.X >= x0) & (p.X < x1)
            p.fill(lg, grad("bark_d", "bark_l", yc - r, yc + r))
            p.paint(lg & (p.rng.random(p.X.shape) < 0.15), "bark_d")
            ends = lg & ((p.X < x0 + 1) | (p.X >= x1 - 1))
            rr = np.sqrt((p.Y - yc) ** 2 + (p.Z - zc) ** 2)
            p.paint(ends, "earth_l", flat=True)
            p.paint(ends & ((np.floor(rr * 1.2) % 2) == 0), "earth", flat=True)
            p.paint(ends & (rr > r - 0.9), "bark", flat=True)
    for x in (-18, 18):
        p.paint(p.box(x, x + 2, 0, 99, -99, 99), "straw_d")
    return p


def pallet():
    """（原木托盘）竹匾：圆竹匾里晒着红辣椒"""
    p = Piece("pallet", 15, 5, 15, vs=2.0, seed=130)
    rr = np.sqrt((p.X - 0.5) ** 2 + (p.Z - 0.5) ** 2)
    p.fill((rr < 7.2) & (p.Y < 1), "bamboo")
    p.paint((rr < 7.2) & (p.Y < 1) & (((np.floor(p.X) + np.floor(p.Z)) % 2) == 0), "bamboo_d")
    p.fill((rr < 7.3) & (rr > 6.2) & (p.Y < 2.5), "bamboo_l")
    for _ in range(26):
        a, d = p.rng.uniform(0, math.tau), p.rng.uniform(0, 5.2)
        cx, cz = 0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d
        b = p.rng.uniform(0, math.tau)
        p.fill(p.seg((cx, 1.5, cz), (cx + math.cos(b) * 1.8, 1.5, cz + math.sin(b) * 1.8), 0.7) & (p.Y >= 1), p.rng.choice(["red", "red_l", "red"]))
    return p


def wheelbarrow():
    """（原独轮手推车）中式独轮车：大木轮在正中、两边货架各驮一只麻袋、两根车把朝 -z"""
    p = Piece("wheelbarrow", 19, 15, 39, vs=2.0, seed=131)
    wz, wy, R = 3, 6.5, 6.4
    rim = p.disk_x(wz, wy, R, -0.5, 1.5) & ~p.disk_x(wz, wy, R - 1.3, -1, 2)
    p.fill(rim, "timber_d")
    ang = np.arctan2(p.Y - wy, p.Z - wz)
    spokes = p.disk_x(wz, wy, R - 1, -0.5, 1.5) & ((np.abs(((ang + math.pi) % (math.pi / 4)) - math.pi / 8) < 0.16) | p.disk_x(wz, wy, 1.4, -1, 2))
    p.fill(spokes, "timber")
    for sx in (-1, 1):
        p.fill(p.seg((sx * 3, 8, 13), (sx * 6, 7.5, -19), 0.8), "timber")             # 车把
        p.fill(p.seg((sx * 5.2, 7.5, -12), (sx * 5.6, 0, -13), 0.7), "timber_d")      # 支腿
        p.fill(p.box(sx * 2.5 - (0 if sx > 0 else 6), sx * 2.5 + (6 if sx > 0 else 0), 7, 8, -6, 11), "timber_l")   # 货架板
        p.fill(((p.X - sx * 5.5) ** 2 / 9 + (p.Y - 10.5) ** 2 / 7 + (p.Z - 2.5) ** 2 / 36 <= 1), grad("hemp_d", "hemp_l", 8, 13))
        p.fill(p.box(sx * 5.5 - 3, sx * 5.5 + 3, 8, 13.5, 1.5, 2.6) & p.occ, "straw_d")
    p.fill(p.box(-1.5, 2.5, 13, 14, -4, 10), "timber_d")                               # 轮上护架
    for z in (-4, 9):
        p.fill(p.box(-1.5, 2.5, 7.5, 14, z, z + 1), "timber_d")
    return p


def rubble_common(name, sx, sy, sz, vs, seed, scale, nb, beam=True):
    p = Piece(name, sx, sy, sz, vs=vs, seed=seed)
    hx, hz = sx / 2 - 1, sz / 2 - 1
    mound = p.ell((0, 0, 0), (hx, sy * 0.32, hz)) & (p.Y >= 0)
    p.fill(mound, grad("#4e4a44", "#6a645a", 0, sy * 0.3))                          # 碎砖末、灰土
    p.paint(mound & (p.rng.random(p.X.shape) < 0.3), "brick_d")
    for _ in range(nb):
        a, d = p.rng.uniform(0, math.tau), p.rng.uniform(0, 1) ** 0.7
        cx, cz = math.cos(a) * d * hx * 0.85, math.sin(a) * d * hz * 0.85
        h = sy * 0.32 * math.sqrt(max(0.0, 1 - d * d))
        by = max(0.0, h - 1.5 * scale + p.rng.uniform(-1, 1) * scale)
        if p.rng.random() < 0.6:
            w, t = 6 * scale, 3 * scale
            if p.rng.random() < 0.5:
                m = p.box(cx - w / 2, cx + w / 2, by, by + t, cz - t / 2, cz + t / 2)
            else:
                m = p.box(cx - t / 2, cx + t / 2, by, by + t, cz - w / 2, cz + w / 2)
            p.fill(m, p.rng.choice(["brick", "brick_d", "brick_l"]))
        else:
            # 半片筒瓦
            rr = np.sqrt((p.X - cx) ** 2 + (p.Y - by) ** 2)
            m = (rr < 2.6 * scale) & (rr > 1.4 * scale) & (p.Y >= by) & (np.abs(p.Z - cz) < 3 * scale)
            p.fill(m, p.rng.choice(["tile", "tile_d", "tile_l"]))
    if beam:
        p.fill(p.seg((-hx * 0.6, 1, -hz * 0.3), (hx * 0.3, sy * 0.85, hz * 0.2), 1.6 * scale), "timber_d")
    p.paint(p.occ & (p.rng.random(p.X.shape) < 0.05), "moss")
    return p


def rubble():
    """（原大碎石堆）塌下来的砖瓦堆：青砖、碎筒瓦、一根断梁斜戳着"""
    return rubble_common("rubble", 75, 32, 29, 1.0, 132, 1.0, 90)


def rubble_half():
    """（原小碎石堆）一小堆砖瓦"""
    return rubble_common("rubble_half", 19, 17, 15, 2.0, 133, 0.55, 30)


def stones():
    """（原石料）凿好的几块条石，带錾子印"""
    p = Piece("stones", 15, 10, 13, vs=2.0, seed=134)
    p.fill(p.box(-6.5, 2, 0, 4, -5.5, 3), "stone")
    p.fill(p.box(1, 7.5, 0, 4, -3, 6), "stone_l")
    p.fill(p.box(-4, 4, 4, 8, -3.5, 2.5), "stone_d")
    p.paint(p.occ & (p.rng.random(p.X.shape) < 0.18), "stone_d")
    p.fill(p.seg((-6, 0.6, 5), (-2, 0.6, 5.5), 0.5), "timber_l")                     # 錾子
    p.fill(p.box(-2.2, -0.8, 0, 1.4, 4.8, 6.2), "iron")
    return p


def trunk():
    """（原大箱子）黑漆描金樟木箱：平盖、铜包角、正面铜锁、两侧提环"""
    p = Piece("trunk", 15, 10, 13, vs=2.0, seed=135)
    body = p.box(-6.5, 7.5, 0, 6.5, -5.5, 6.5)
    p.fill(body, "lacq")
    p.fill(p.box(-7, 8, 6.5, 8.5, -6, 7), "lacq")
    p.paint(p.box(-7, 8, 6.5, 7, -6, 7), "gold_d")
    for xa in (-7, 6.5):
        for za in (-6, 5.5):
            p.paint(p.box(xa, xa + 1.5, 0, 9, za, za + 1.5), "brass")
    p.paint(body & (np.abs(p.Y - 3.2) < 0.5), "gold_d")
    p.fill(p.box(-0.5, 1.5, 3.5, 7, 6.5, 7.2), "brass")
    p.fill(p.box(-2.5, 3.5, 2, 4, 6.5, 7.0) & (np.abs(p.X - 0.5) < 3 - (4 - p.Y)), "gold", flat=True)   # 描金云头
    for sx in (-7.4, 7.9):
        p.fill(p.disk_x(0.5, 4.5, 1.6, sx - 0.4, sx + 0.4) & ~p.disk_x(0.5, 4.5, 0.8, -99, 99), "brass")
    return p


def rock(name, sx, sy, sz, vs, seed, blobs=4, flat=0.75):
    """山石：几块棱角分明的石块（随机切面围成的多面体）挤在一起，顶面斜削，横向层理 + 斜皴，只在顶上零星长苔"""
    p = Piece(name, sx, sy, sz, vs=vs, seed=seed)
    hx, hz = sx / 2 - 1, sz / 2 - 1
    for i in range(blobs):
        main = i == 0
        cx = 0 if main else p.rng.uniform(-hx * 0.45, hx * 0.45)
        cz = 0 if main else p.rng.uniform(-hz * 0.45, hz * 0.45)
        rx = (0.9 if main else p.rng.uniform(0.45, 0.65)) * hx
        rz = (0.9 if main else p.rng.uniform(0.45, 0.65)) * hz
        rx, rz = min(rx, hx - abs(cx)), min(rz, hz - abs(cz))
        top = sy * ((flat + (1 - flat) * p.rng.uniform(0.7, 1.0)) if main else p.rng.uniform(0.4, 0.8))
        u, v = (p.X - cx) / rx, (p.Z - cz) / rz
        m = (p.Y >= 0) & (p.Y < top + (u * p.rng.uniform(-0.12, 0.12) + v * p.rng.uniform(-0.12, 0.12)) * sy)
        a0 = p.rng.uniform(0, math.tau)
        for k in range(7):                          # 一圈侧面：竖切，稍往里收（上窄下宽）
            ang = a0 + k / 7 * math.tau + p.rng.uniform(-0.25, 0.25)
            d = p.rng.uniform(0.78, 1.0)
            m &= (u * math.cos(ang) + v * math.sin(ang)) <= d - (p.Y / sy) * p.rng.uniform(0.1, 0.35)
        for k in range(3):                          # 上面几刀斜削
            ang = p.rng.uniform(0, math.tau)
            m &= (u * math.cos(ang) + v * math.sin(ang)) * 0.6 + (p.Y / max(top, 1)) * 0.8 <= p.rng.uniform(0.95, 1.15)
        p.fill(m, "rock")
    surf = p.occ & ~(np.roll(p.occ, 1, 0) & np.roll(p.occ, -1, 0) & np.roll(p.occ, 1, 2) & np.roll(p.occ, -1, 2))
    bx = (np.floor(p.X / 2).astype(np.int64) * 73856093) ^ (np.floor(p.Y / 2).astype(np.int64) * 19349663) ^ (np.floor(p.Z / 2).astype(np.int64) * 83492791)
    p.carve(surf & ((bx % 9) == 0) & (p.Y > 1))
    yn = p.Y / sy
    p.paint(p.occ, grad("rock_d", "rock_l", 0, sy))
    p.paint(p.occ & ((np.floor(p.Y + 1.2 * np.sin(p.X * 0.25 + p.Z * 0.15)) % 4) == 0), "rock_d")   # 层理
    p.paint(p.occ & ((np.floor(p.X * 0.6 + p.Y + p.Z * 0.3) % 9) == 0) & (yn > 0.2), "rock_d")    # 斜皴
    ts = top_surface(p)
    p.paint(ts & (p.rng.random(p.X.shape) < 0.35), "rock_l")
    p.paint(ts & (yn > 0.55) & (p.rng.random(p.X.shape) < 0.22), "moss")
    return p


def rock_a():
    return rock("rock_a", 65, 16, 63, 2.0, 141, blobs=5, flat=0.7)


def rock_b():
    return rock("rock_b", 27, 13, 23, 2.0, 142, blobs=3)


def rock_c():
    return rock("rock_c", 37, 21, 37, 2.0, 143, blobs=4, flat=0.8)


def rock_d():
    return rock("rock_d", 19, 11, 17, 2.0, 144, blobs=2)


def rock_e():
    return rock("rock_e", 41, 17, 29, 2.0, 145, blobs=4)


def reeds(name, sx, sy, sz, vs, seed, n):
    """芦苇：一丛细叶往外斜，几根顶着芦花"""
    p = Piece(name, sx, sy, sz, vs=vs, seed=seed)
    hx, hz = sx / 2 - 1.5, sz / 2 - 1.5
    for i in range(n):
        a, d = p.rng.uniform(0, math.tau), p.rng.uniform(0, 0.45)
        bx, bz = math.cos(a) * d * hx, math.sin(a) * d * hz
        h = p.rng.uniform(0.55, 0.98) * (sy - 1)
        lean = p.rng.uniform(0.15, 0.45)
        tx = np.clip(bx + math.cos(a) * lean * h, -hx, hx)
        tz = np.clip(bz + math.sin(a) * lean * h, -hz, hz)
        p.fill(p.seg((bx, 0, bz), (tx, h, tz), 0.85, 0.55), grad("reed_d", "reed_l", 0, sy))
        if i % 3 == 0:
            p.fill(p.ell((tx, min(h + 1, sy - 1.2), tz), (0.9, 1.6, 0.9)), "plume", flat=True)
    return p


def reeds_a():
    return reeds("reeds_a", 21, 14, 23, 2.0, 146, 44)


def reeds_b():
    return reeds("reeds_b", 7, 12, 5, 2.0, 147, 9)


def bone(name, sx, sy, sz, vs, seed, bend=0.0):
    p = Piece(name, sx, sy, sz, vs=vs, seed=seed)
    L = sx / 2 - 1.5
    p.fill(p.seg((-L, 1, 0), (0, 1, bend), 0.8) | p.seg((0, 1, bend), (L, 1, 0), 0.8), "bone")
    for ex in (-L, L):
        for dz in (-0.7, 0.7):
            p.fill(p.ell((ex, 1.2, dz), (1.1, 1.1, 0.9)) & (p.Y >= 0), "bone_l")
    p.paint(p.occ & (p.Y < 0.9), "bone_d")
    return p


def bone_a():
    return bone("bone_a", 9, 4, 3, 2.0, 151)


def bone_b():
    return bone("bone_b", 7, 3, 3, 2.0, 152)


def bone_c():
    return bone("bone_c", 13, 4, 3, 2.0, 153, bend=0.6)


def ribcage():
    """（原肋骨架）一副兽骨肋架：脊骨在上，一根根肋骨弯下来扎进土里"""
    p = Piece("ribcage", 19, 20, 17, vs=1.0, seed=154)
    p.fill(p.seg((0.5, 15.5, -7.5), (0.5, 14, 7.5), 1.3), "bone")
    for z in np.arange(-7, 8, 1.6):
        p.paint(p.box(-1.5, 2.5, 13, 18, z - 0.4, z + 0.4), "bone_l")
    for z in np.arange(-5.5, 7, 2.6):
        k = 1 - abs(z) / 12
        rr = ((p.X - 0.5) / (8.2 * k)) ** 2 + ((p.Y - 0) / (15.0 * k + 0.5)) ** 2
        rib = (rr <= 1) & (rr >= 0.78) & (np.abs(p.Z - z) < 0.65) & (p.Y >= 0)
        p.fill(rib, "bone")
    p.fill(p.ell((0.5, 0, 0), (8, 1.5, 7.5)) & (p.Y >= 0) & (p.rng.random(p.X.shape) < 0.3), "earth_d")
    p.paint(p.occ & (p.Y < 3), "bone_d")
    return p


PIECES2 = {
    "wall": wall, "wall_arch": wall_arch, "wall_broken": wall_broken, "arch_gate": arch_gate,
    "pillar": pillar, "column": column, "barrier": barrier, "barrier_col": barrier_col,
    "fence": fence, "fence_broken": fence_broken, "fence_pillar": fence_pillar, "fence_stone": fence_stone, "fence_wood": fence_wood,
    "bench": bench, "table": table, "table_m": table_m, "table_s": table_s,
    "shrine": shrine, "candles": candles, "torch": torch, "torch_wall": torch_wall, "lantern_hang": lantern_hang, "shelf": shelf,
    "coins": coins, "flag": flag, "arrows": arrows, "bucket": bucket, "sack": sack, "lumber": lumber, "pallet": pallet,
    "wheelbarrow": wheelbarrow, "rubble": rubble, "rubble_half": rubble_half, "stones": stones, "trunk": trunk,
    "rock_a": rock_a, "rock_b": rock_b, "rock_c": rock_c, "rock_d": rock_d, "rock_e": rock_e,
    "reeds_a": reeds_a, "reeds_b": reeds_b, "bone_a": bone_a, "bone_b": bone_b, "bone_c": bone_c, "ribcage": ribcage,
}
PIECES.update(PIECES2)


if __name__ == "__main__":
    names = sys.argv[1:] or list(PIECES)
    for n in names:
        p = PIECES[n]()
        p.shade()
        p.export()
