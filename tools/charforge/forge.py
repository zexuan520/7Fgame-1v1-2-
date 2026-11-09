"""角色体素“锻造台”：用几何体（方块、椭球、圆柱、圆锥、胶囊）直接搭角色，输出和 voxelize_char.py 一样的
分部件 JSON（assets/voxel/<id>.json.gz），VoxActor 直接能用。

为什么不再用 KayKit：KayKit 是 1:2 的大头 Q 版，斜俯视 50° 镜头下头占了画面上的大半个人，
身体、手脚、兵器全被头盖住，所有骷髅都是一颗“光头蛋”，只能靠染色区分。这里按斜俯视重新定比例：
  - 头身比约 1:4，肩宽、手大、脚大，四肢粗细至少 4 小格（镜头下约 3 像素），否则糊成一团
  - 每种角色有自己的“顶视剪影”（斗笠、头盔、兜帽、高帽……从上往下看第一眼就认得出）
  - 配色三层明度分区：主色 / 暗色 / 一点高饱和的点缀色；主角暖、敌人冷，敌人眼睛统一发红光
坐标：小格（res=2，一个游戏格切成 2×2×2），脚底 y=0，面朝 +x，+z 是右手（持刀手，靠镜头）。
四肢在静止姿势里竖直下垂，部件局部坐标 = 模型坐标 - 起点关节，和 VoxActor._place 对上。

用法：python3 tools/charforge/forge.py [角色名 ...]   （不写就全做；角色在 chars.py）
"""
import gzip, json, os, sys
import numpy as np

# 一游戏格切几小格。1.75：100 小格高的人 ≈ 57 格 ≈ 2.05 米，比 KayKit 的 50 格高一点（镜头远，个头大一点才压得住场面）
RES = 1.75
# 模型空间范围（小格）
XR = (-40, 40)
YR = (0, 120)
ZR = (-40, 40)
PART_IDS = ["torso", "hips", "head", "arm_u_f", "arm_l_f", "arm_u_b", "arm_l_b", "leg_u_f", "leg_l_f", "leg_u_b", "leg_l_b",
            "hair", "tail_r", "tail_l", "sleeve_f", "sleeve_b"]
# 后面五个是“会飘的件”（2026-11-09 动作衔接）：长发/发带、袍子后摆左右两片、广袖袖口。VoxActor 按惯性和弹簧单独摆，
# 没有这些件的模型照旧（全长在头、胯、前臂上）
# 部件 → (起点关节, 终点关节)；None = 竖直往下
SPAN = {
    "torso": ("head", "hips"), "hips": ("hips", None), "head": ("head", None),
    "arm_u_f": ("upperarm.r", "lowerarm.r"), "arm_l_f": ("lowerarm.r", "wrist.r"),
    "arm_u_b": ("upperarm.l", "lowerarm.l"), "arm_l_b": ("lowerarm.l", "wrist.l"),
    "leg_u_f": ("upperleg.r", "lowerleg.r"), "leg_l_f": ("lowerleg.r", "foot.r"),
    "leg_u_b": ("upperleg.l", "lowerleg.l"), "leg_l_b": ("lowerleg.l", "foot.l"),
    "hair": ("head", None), "tail_r": ("hips", None), "tail_l": ("hips", None),
    "sleeve_f": ("lowerarm.r", "wrist.r"), "sleeve_b": ("lowerarm.l", "wrist.l"),
}


def rgb(h):
    """'#rrggbb' → np.array([r,g,b])"""
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


class Forge:
    def __init__(self, name, joints, source="", seed=1):
        self.name = name
        self.source = source
        self.J = {k: np.array(v, dtype=float) for k, v in joints.items()}
        xs = np.arange(*XR) + 0.5
        ys = np.arange(*YR) + 0.5
        zs = np.arange(*ZR) + 0.5
        self.X, self.Y, self.Z = np.meshgrid(xs, ys, zs, indexing="ij")
        shp = self.X.shape
        self.part = np.full(shp, -1, dtype=np.int16)
        self.col = np.zeros(shp + (3,), dtype=float)
        self.rng = np.random.default_rng(seed)
        self.pivots = {}                            # 会飘的件绕哪个点转（模型坐标，小格）
        self.glow = np.zeros(shp, dtype=float)      # 发光强度 0~1（眼睛、灯火）：不做明暗，导出成 alpha = 1 - glow

    # ---------- 形状（返回布尔掩码） ----------
    def box(self, x0, x1, y0, y1, z0, z1):
        X, Y, Z = self.X, self.Y, self.Z
        return (X >= x0) & (X < x1) & (Y >= y0) & (Y < y1) & (Z >= z0) & (Z < z1)

    def ell(self, c, r):
        return ((self.X - c[0]) / r[0]) ** 2 + ((self.Y - c[1]) / r[1]) ** 2 + ((self.Z - c[2]) / r[2]) ** 2 <= 1.0

    def cyl(self, cx, cz, r, y0, y1, rz=None):
        rz = r if rz is None else rz
        return (((self.X - cx) / r) ** 2 + ((self.Z - cz) / rz) ** 2 <= 1.0) & (self.Y >= y0) & (self.Y < y1)

    def cone(self, cx, cz, r0, y0, r1, y1, squash=1.0):
        """竖直圆台：y0 处半径 r0，y1 处半径 r1；squash < 1 把 z 方向压扁"""
        t = np.clip((self.Y - y0) / (y1 - y0), 0, 1)
        r = r0 + (r1 - r0) * t
        return ((self.X - cx) ** 2 + ((self.Z - cz) / squash) ** 2 <= r ** 2) & (self.Y >= y0) & (self.Y < y1)

    def seg(self, a, b, r0, r1=None):
        """胶囊：a→b，半径从 r0 渐变到 r1"""
        r1 = r0 if r1 is None else r1
        a = np.asarray(a, float)
        b = np.asarray(b, float)
        d = b - a
        L2 = float(d @ d)
        P = np.stack([self.X - a[0], self.Y - a[1], self.Z - a[2]], -1)
        t = np.clip((P @ d) / max(L2, 1e-6), 0, 1)
        Q = P - t[..., None] * d
        r = r0 + (r1 - r0) * t
        return (Q ** 2).sum(-1) <= r ** 2

    def side(self, axis, op, v):
        A = {"x": self.X, "y": self.Y, "z": self.Z}[axis]
        return A > v if op == ">" else A < v

    # ---------- 上色 ----------
    def fill(self, mask, part, color, glow=0.0):
        """把掩码里的格放进 part（覆盖之前的），上 color（'#hex' 或函数 (X,Y,Z)->(...,3)）"""
        pid = PART_IDS.index(part)
        self.part[mask] = pid
        self._paint(mask, color)
        self.glow[mask] = glow

    def paint(self, mask, color, part=None, glow=0.0):
        """只给已有的格换颜色（part 限定部件）"""
        m = mask & (self.part >= 0)
        if part is not None:
            m &= self.part == PART_IDS.index(part)
        self._paint(m, color)
        self.glow[m] = glow

    def move(self, mask, src, dst):
        """把 src 部件里落在掩码内的格挪到 dst 部件（颜色不变）：拆出会飘的件用"""
        m = mask & (self.part == PART_IDS.index(src))
        self.part[m] = PART_IDS.index(dst)

    def carve(self, mask, part=None):
        m = mask
        if part is not None:
            m = m & (self.part == PART_IDS.index(part))
        self.part[m] = -1

    def _paint(self, mask, color):
        if callable(color):
            self.col[mask] = color(self.X[mask], self.Y[mask], self.Z[mask])
        else:
            self.col[mask] = rgb(color) if isinstance(color, str) else np.asarray(color, float)

    # ---------- 输出 ----------
    def shade(self, top_light=0.10, noise=0.05, block=2):
        """体素像素画的明暗：越往上越亮一点（斜俯视主要看顶面），再加 block×block 的块状噪点（大块才不破坏网格合并）"""
        on = (self.part >= 0) & (self.glow <= 0)
        # 每个部件内部按高度做一点点渐变：用整体高度归一化
        yn = (self.Y - YR[0]) / (YR[1] - YR[0])
        mul = 1.0 - top_light * 0.5 + top_light * yn
        bx = (np.floor(self.X / block) * 73856093).astype(np.int64) ^ (np.floor(self.Y / block) * 19349663).astype(np.int64) ^ (np.floor(self.Z / block) * 83492791).astype(np.int64)
        nz = ((bx % 1000) / 1000.0 - 0.5) * 2.0 * noise
        mul = mul + nz
        # 量化成 4 档，减少颜色数（合网格更省）
        mul = np.round(mul * 25) / 25
        self.col[on] = np.clip(self.col[on] * mul[on][:, None], 0, 255)

    def export(self, out_dir):
        parts = {}
        occ = self.part >= 0
        ix = np.argwhere(occ)
        # 用于判断“是否表面”：六邻居都被（任何部件的）格挡住就不存
        pad = np.pad(occ, 1)
        full = np.ones_like(occ)
        for ax in range(3):
            for s in (-1, 1):
                full &= np.roll(pad, s, axis=ax)[1:-1, 1:-1, 1:-1]
        total = 0
        for pi, pname in enumerate(PART_IDS):
            sel = (self.part == pi)
            if not sel.any():
                continue
            # 同部件内部的六邻居才算挡住（不同部件会动开，接缝处要留面）
            pp = np.pad(sel, 1)
            inner = np.ones_like(sel)
            for ax in range(3):
                for s in (-1, 1):
                    inner &= np.roll(pp, s, axis=ax)[1:-1, 1:-1, 1:-1]
            surf = sel & ~inner
            a_name, b_name = SPAN[pname]
            A = self.J[a_name]
            L = 0.0 if b_name is None else float(np.linalg.norm(self.J[b_name] - A))
            pts = np.argwhere(surf)
            cells = np.stack([pts[:, 0] + XR[0], pts[:, 1] + YR[0], pts[:, 2] + ZR[0]], -1) - np.floor(A).astype(int)
            cols = np.clip(np.round(self.col[surf]), 0, 255).astype(int)
            gl = self.glow[surf]
            pd = {"anchor": [float(x) for x in np.floor(A)], "len": round(L, 2)}
            if pname in self.pivots:
                pd["pivot"] = [round(float(x), 2) for x in (np.array(self.pivots[pname], dtype=float) - np.floor(A))]
            if (gl > 0).any():
                alpha = np.clip(np.round(255 * (1.0 - gl)), 0, 255).astype(int)[:, None]
                pd["vox"] = np.concatenate([cells, cols, alpha], 1).reshape(-1).tolist()
                pd["stride"] = 7
            else:
                pd["vox"] = np.concatenate([cells, cols], 1).reshape(-1).tolist()
            parts[pname] = pd
            total += len(pts)
        joints = {k: [float(x) for x in v] for k, v in self.J.items()}
        out = {"source": self.source, "license": "CC0 1.0（本作自制）", "height": 100.0, "res": RES,
               "joints": joints, "parts": parts}
        path = os.path.join(out_dir, self.name + ".json.gz")
        with gzip.open(path, "wt", compresslevel=9) as f:
            json.dump(out, f, separators=(",", ":"))
        print(f"{self.name}: {total} 表面格 → {path} ({os.path.getsize(path) // 1024} KB)")


def std_joints(neck=74, sh_y=70, sh_z=14, hip_y=44, leg_z=7, knee_y=24, ankle_y=6, elbow_y=None, wrist_y=None, knee_x=1):
    """标准人形关节（小格）。四肢竖直下垂"""
    elbow_y = sh_y - 16 if elbow_y is None else elbow_y
    wrist_y = elbow_y - 15 if wrist_y is None else wrist_y
    leg_top = hip_y - 2
    J = {
        "hips": (0, hip_y, 0), "spine": (0, hip_y + 8, 0), "chest": (0, (hip_y + neck) // 2 + 4, 0), "head": (0, neck, 0),
        "upperleg.r": (0, leg_top, leg_z), "lowerleg.r": (0, knee_y, leg_z), "foot.r": (0, ankle_y, leg_z),
        "upperleg.l": (0, leg_top, -leg_z), "lowerleg.l": (0, knee_y, -leg_z), "foot.l": (0, ankle_y, -leg_z),
        "upperarm.r": (0, sh_y, sh_z), "lowerarm.r": (0, elbow_y, sh_z), "wrist.r": (0, wrist_y, sh_z),
        "upperarm.l": (0, sh_y, -sh_z), "lowerarm.l": (0, elbow_y, -sh_z), "wrist.l": (0, wrist_y, -sh_z),
    }
    return J


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import chars
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "voxel")
    names = sys.argv[1:] or list(chars.ALL.keys())
    for n in names:
        f = chars.ALL[n]() if n in chars.ALL else chars.DRAFTS[n]()
        f.shade()
        f.export(out_dir)
