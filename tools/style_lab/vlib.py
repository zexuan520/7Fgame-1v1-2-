"""风格小样用的体素建模小工具：往字典里填方块（盒、椭球、锥台、两头不一样粗的胶囊），再存成 JSON。
坐标：x 向右、y 向上、z 朝镜头（角色脸朝 +z），y=0 是地面，x/z=0 是脚下中心。
输出 {"vs": 一格几米, "vox": [x,y,z,r,g,b,...], "glow": [...同上，自发光的格子...]}，由 style_lab.gd 读。
"""
import gzip
import json
import math
import random


def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def mul(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def nz(x, y, z, s=0.0, f=1.0):
    """平滑的伪噪声，大约 -1..1"""
    x, y, z = x * f, y * f, z * f
    a = math.sin(x * 0.37 + s * 1.7) * math.sin(y * 0.29 + s * 2.3 + 1.1) * math.sin(z * 0.41 + s * 0.7 + 2.2)
    b = math.sin(x * 0.83 + y * 0.61 + s) * math.sin(z * 0.77 - y * 0.53 + s * 3.1)
    c = math.sin(x * 0.19 - z * 0.23 + s * 5.3) * math.cos(y * 0.17 + x * 0.11 + s)
    return (a + 0.5 * b + 0.6 * c) / 1.4


class V:
    def __init__(self, seed=1):
        self.c = {}
        self.g = set()
        self.r = random.Random(seed)

    # ---------- 基本 ----------
    def put(self, p, col, j=0.0, glow=False):
        if j:
            col = mul(col, 1.0 + self.r.uniform(-j, j))
        self.c[p] = col
        if glow:
            self.g.add(p)
        else:
            self.g.discard(p)

    def has(self, p):
        return p in self.c

    def erase(self, p):
        self.c.pop(p, None)
        self.g.discard(p)

    def box(self, a, b, col, j=0.0, glow=False, keep=None):
        for x in range(min(a[0], b[0]), max(a[0], b[0]) + 1):
            for y in range(min(a[1], b[1]), max(a[1], b[1]) + 1):
                for z in range(min(a[2], b[2]), max(a[2], b[2]) + 1):
                    if keep is None or keep(x, y, z):
                        self.put((x, y, z), col if not callable(col) else col(x, y, z), j, glow)

    def ell(self, c, r, col, j=0.0, glow=False, keep=None, rough=0.0, seed=0.0):
        cx, cy, cz = c
        rx, ry, rz = r
        for x in range(math.floor(cx - rx - 1), math.ceil(cx + rx + 1) + 1):
            for y in range(math.floor(cy - ry - 1), math.ceil(cy + ry + 1) + 1):
                for z in range(math.floor(cz - rz - 1), math.ceil(cz + rz + 1) + 1):
                    d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2
                    if rough:
                        d += rough * nz(x, y, z, seed)
                    if d <= 1.0 and (keep is None or keep(x, y, z)):
                        self.put((x, y, z), col if not callable(col) else col(x, y, z), j, glow)

    def frustum(self, cx, cz, y0, y1, r0, r1, col, j=0.0, zs=1.0, glow=False, keep=None, ring=None):
        """绕 y 轴的锥台（y0 处半径 r0，y1 处 r1），zs 压扁前后。ring 给了就只画外壳 ring 格厚"""
        for y in range(y0, y1 + 1):
            t = (y - y0) / max(1, y1 - y0)
            r = r0 + (r1 - r0) * t
            if r <= 0:
                continue
            rz = r * zs
            for x in range(math.floor(cx - r) - 1, math.ceil(cx + r) + 2):
                for z in range(math.floor(cz - rz) - 1, math.ceil(cz + rz) + 2):
                    d = ((x - cx) / r) ** 2 + ((z - cz) / rz) ** 2
                    if d <= 1.0:
                        if ring is not None and d < (1.0 - ring / r) ** 2:
                            continue
                        if keep is None or keep(x, y, z):
                            self.put((x, y, z), col if not callable(col) else col(x, y, z), j, glow)

    def cap(self, p0, p1, r0, r1, col, j=0.0, glow=False, keep=None):
        """两头粗细不一样的胶囊"""
        ax, ay, az = p0
        bx, by, bz = p1
        dx, dy, dz = bx - ax, by - ay, bz - az
        L2 = dx * dx + dy * dy + dz * dz or 1e-6
        R = max(r0, r1) + 1
        for x in range(math.floor(min(ax, bx) - R), math.ceil(max(ax, bx) + R) + 1):
            for y in range(math.floor(min(ay, by) - R), math.ceil(max(ay, by) + R) + 1):
                for z in range(math.floor(min(az, bz) - R), math.ceil(max(az, bz) + R) + 1):
                    t = ((x - ax) * dx + (y - ay) * dy + (z - az) * dz) / L2
                    t = max(0.0, min(1.0, t))
                    px, py, pz = ax + dx * t, ay + dy * t, az + dz * t
                    rr = r0 + (r1 - r0) * t
                    if (x - px) ** 2 + (y - py) ** 2 + (z - pz) ** 2 <= rr * rr:
                        if keep is None or keep(x, y, z):
                            self.put((x, y, z), col if not callable(col) else col(x, y, z), j, glow)

    def chain(self, pts, r0, r1, col, j=0.0, glow=False):
        """一串点连起来的胶囊，粗细从 r0 渐变到 r1（飘带、围巾、树枝）"""
        n = len(pts) - 1
        for i in range(n):
            ra = r0 + (r1 - r0) * i / n
            rb = r0 + (r1 - r0) * (i + 1) / n
            self.cap(pts[i], pts[i + 1], ra, rb, col, j, glow)

    def paint(self, pred, col, j=0.0, glow=None):
        for p in list(self.c):
            if pred(*p):
                c = col(p, self.c[p]) if callable(col) else col
                self.put(p, c, j, (p in self.g) if glow is None else glow)

    def carve(self, pred):
        for p in list(self.c):
            if pred(*p):
                self.erase(p)

    def tops(self):
        return [p for p in self.c if (p[0], p[1] + 1, p[2]) not in self.c]

    def front(self, x, y, col, glow=False, depth=1):
        """把 (x, y) 这一列最靠前（z 最大）的格子涂色"""
        zs = [p[2] for p in self.c if p[0] == x and p[1] == y]
        if not zs:
            return
        zm = max(zs)
        for d in range(depth):
            if (x, y, zm - d) in self.c:
                self.put((x, y, zm - d), col, 0, glow)

    def bump(self, x, y, col, glow=False):
        """在 (x, y) 这一列最前面再凸出一格（眉骨、鼻梁、浮雕）"""
        zs = [p[2] for p in self.c if p[0] == x and p[1] == y]
        if zs:
            self.put((x, y, max(zs) + 1), col, 0, glow)

    def front_box(self, x0, x1, y0, y1, col, glow=False, depth=1):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                self.front(x, y, col, glow, depth)

    def surface(self):
        out = []
        for (x, y, z) in self.c:
            for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                if (x + d[0], y + d[1], z + d[2]) not in self.c:
                    out.append((x, y, z))
                    break
        return out

    def hollow(self):
        """去掉看不见的内部格子（文件小、读得快）"""
        keep = set(self.surface())
        for p in list(self.c):
            if p not in keep:
                # 多留一层，免得遮蔽算错
                near = any((p[0] + d[0], p[1] + d[1], p[2] + d[2]) in keep for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)))
                if not near:
                    self.erase(p)

    def ground_clip(self):
        self.carve(lambda x, y, z: y < 0)

    def dump(self, path, vs, extra=None):
        self.hollow()
        vox, glow = [], []
        for p, c in self.c.items():
            (glow if p in self.g else vox).extend([p[0], p[1], p[2], int(c[0]), int(c[1]), int(c[2])])
        d = {"vs": vs, "vox": vox, "glow": glow}
        if extra:
            d.update(extra)
        with gzip.open(path + ".json.gz", "wt") as f:
            json.dump(d, f, separators=(",", ":"))
        return len(self.c)
