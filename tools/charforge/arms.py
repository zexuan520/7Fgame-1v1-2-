"""兵器锻造：把 KayKit 的西式兵器换成本作自制的中式兵器（和 weapon/*.json 同格式：握把在原点，尖端朝 -y，一格 0.5 像素）。
python3 tools/charforge/arms.py [名字 ...]   → assets/voxel/weapon/<名>.json.gz

形状规矩（斜俯视下手里的东西只有二三十像素长）：
- 每把一个一眼认得的剪影：剑有剑格剑穗，刀单边开刃带弧，钺是半月，锡杖头是一个环，连弩背上一只箭匣；
- 金属三层明度（刃口亮、刃面中、脊暗），木柄暖褐，点缀色只用红（穗、缨、缠绳）和铜；
- 敌人用的（skel_* 和 sword2/axe2/staff）带锈和缺口，主角用的干净。
平面：刃面在 x-y 平面（宽在 x），厚在 z；盾面在 y-z 平面，厚在 x（盾面朝 +x）；连弩 z 朝上。
"""
import gzip, json, math, os, random, sys

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "voxel", "weapon")


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


P = {k: hx(v) for k, v in {
    "edge": "#e6eaf0", "steel": "#b4bac4", "steel_d": "#7c838f", "ridge": "#8e95a1", "iron": "#5e636d", "iron_d": "#3e4249",
    "brass": "#d0a048", "brass_d": "#8f6a26", "brass_l": "#f0cc78",
    "wood": "#8a5c34", "wood_d": "#5a3a20", "wood_l": "#a8743f", "lacq": "#3a2a26", "lacq_l": "#5a403a",
    "cord": "#2c2228", "cord_l": "#4a3a42", "red": "#c8352a", "red_d": "#86201a", "red_l": "#e8584a",
    "rust": "#8a4e2c", "rust_d": "#5c3220", "rust_l": "#a8683c", "rot": "#6e6a5c",
    "bone": "#e2d8bc", "bone_d": "#b0a282", "verd": "#5f9c8c", "verd_d": "#3f6c62",
    "rattan": "#c8a060", "rattan_d": "#8e6a38", "rattan_l": "#e2c080", "black": "#22201f", "yel": "#e8c040", "white": "#ece6d6",
    "paper": "#e8d48a", "paper_d": "#b89a50", "ink": "#3a2018", "feather": "#d8d0c0",
}.items()}


class W:
    def __init__(self, name, seed=1):
        self.name = name
        self.c = {}
        self.rng = random.Random(seed)

    def jit(self, c, a=6):
        r = self.rng
        return tuple(max(0, min(255, v + r.randint(-a, a))) for v in c)

    def put(self, x, y, z, col, a=6):
        self.c[(int(x), int(y), int(z))] = self.jit(col, a)

    def rod(self, y0, y1, col, r=1.0, col2=None, band=None, square=False):
        """沿 y 的圆杆（r 半径，格）；band(y) 返回颜色就用它（缠绳、铜箍）"""
        R = int(math.ceil(r))
        for y in range(min(y0, y1), max(y0, y1) + 1):
            cc = col
            if band is not None:
                b = band(y)
                if b is not None:
                    cc = b
            for x in range(-R, R + 1):
                for z in range(-R, R + 1):
                    if square or x * x + z * z <= r * r + 0.3:
                        self.put(x, y, z, cc)

    def disk_y(self, y, r, col, t=1, rim=None):
        """横在 y 处的圆盘（护手）"""
        for yy in range(y, y + t):
            for x in range(-r, r + 1):
                for z in range(-r, r + 1):
                    d = x * x + z * z
                    if d <= r * r + 0.5:
                        self.put(x, yy, z, rim if (rim and d > (r - 1) ** 2) else col)

    def blade(self, y_tip, y_base, w_fn, x_fn=lambda y: 0.0, edge2=True, cols=None, thick=1, nick=0.0, rust=0.0):
        """刃：w_fn(t) 给半宽（t: 0 尖 → 1 根），x_fn(y) 给中线偏移（弯刀）；edge2 双刃；rust 锈斑比例，nick 缺口比例"""
        cols = cols or (P["edge"], P["steel"], P["ridge"])
        n = y_base - y_tip
        for y in range(y_tip, y_base + 1):
            t = (y - y_tip) / max(n, 1)
            w = w_fn(t)
            cx = x_fn(y)
            lo, hi = int(round(cx - w)), int(round(cx + w))
            if not edge2:
                lo = int(round(cx - max(w * 0.5, 0.6)))   # 单刃：刀背在 -x
            for x in range(lo, hi + 1):
                if nick and x == hi and self.rng.random() < nick:
                    continue
                if x == hi or (edge2 and x == lo):
                    c = cols[0]
                elif abs(x - cx) < 0.6 or (not edge2 and x == lo):
                    c = cols[2]
                else:
                    c = cols[1]
                if rust and self.rng.random() < rust:
                    c = P["rust"] if self.rng.random() < 0.6 else P["rust_d"]
                self.put(x, y, 0, c, 5)
                if thick and lo < x < hi:
                    for z in (-1, 1):
                        cz = c if c != cols[0] else cols[1]
                        self.put(x, y, z, cz, 5)

    def save(self):
        cells = self.c
        vox = []
        for (x, y, z), col in sorted(cells.items()):
            vox += [x, y, z, *col]
        xs = [k[0] for k in cells]; ys = [k[1] for k in cells]; zs = [k[2] for k in cells]
        d = {"vs": 0.5, "len": (max(ys) - min(ys) + 1) * 0.5,
             "size": [max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, max(zs) - min(zs) + 1],
             "min": [min(xs), min(ys), min(zs)], "source": "本作自制 · 兵器锻造（tools/charforge/arms.py）", "vox": vox}
        with gzip.open(os.path.join(OUT, self.name + ".json.gz"), "wt", compresslevel=9) as f:
            json.dump(d, f, separators=(",", ":"))
        print(self.name, d["size"], len(cells))


def wrap_band(y, period=3, a=P["cord"], b=P["cord_l"]):
    return a if (y % period) else b


# ---------------- 主角那一套（干净） ----------------

def sword():
    """游侠剑：直身双刃，中脊一道暗线，铜剑格两头上翘，黑缠绳柄，铜剑首挂一条红穗"""
    w = W("sword", 3)
    w.rod(1, 14, P["cord"], 1.2, band=lambda y: wrap_band(y))
    w.disk_y(15, 2, P["brass"], 2)                      # 剑首
    for y in range(17, 23):                              # 剑穗：从剑首垂下一缕红
        for x in (0, 1):
            if y < 22 or x == 0:
                w.put(x + (y - 17) // 3, y, 0, P["red"] if y < 21 else P["red_l"])
    for x in range(-6, 7):                               # 剑格：两头翘
        yy = -1 - (1 if abs(x) >= 5 else 0)
        for z in (-1, 0, 1):
            w.put(x, yy, z, P["brass_l"] if abs(x) >= 5 else P["brass"])
            w.put(x, 0, z, P["brass_d"])
    w.blade(-60, -2, lambda t: 3.4 if t > 0.12 else max(0.4, 3.4 * t / 0.12))
    w.save()


def gun():
    """齐眉棍：一根硬木长棍，两头包铜、握手处缠一段红布。没有头尾之分，倒着拿也对"""
    w = W("gun", 5)

    def band(y):
        if y <= -60 or y >= 18:
            return P["brass"] if (y % 2) else P["brass_d"]
        if -4 <= y <= 4:
            return P["red"] if y % 3 else P["red_d"]
        return P["wood"] if (y % 7) else P["wood_d"]
    w.rod(-66, 22, P["wood"], 1.5, band=band)
    w.save()


def dagger():
    """匕首：短而宽的叶形双刃，铜护手，红缠柄"""
    w = W("dagger", 7)
    w.rod(1, 10, P["red_d"], 1.1, band=lambda y: P["red"] if y % 3 else P["red_d"])
    w.disk_y(11, 2, P["brass"], 1)
    for x in range(-4, 5):
        for z in (-1, 0, 1):
            w.put(x, 0, z, P["brass"] if abs(x) < 4 else P["brass_l"])
    w.blade(-40, -1, lambda t: 3.6 * min(1.0, t * 2.2) * (1.0 if t < 0.75 else 0.85))
    w.save()


def axe2():
    """钺（裂骨斧 / 敌人的大斧）：木柄，柄头一片半月大刃，背后一根短刺，刃根铜箍。敌人拿的同一把，暗一点"""
    w = W("axe2", 9)
    w.rod(-58, 18, P["wood"], 1.4, band=lambda y: (P["cord"] if 8 <= y <= 18 and y % 3 else None))
    w.rod(-64, -59, P["iron"], 1.0)                      # 柄尾铁钻
    for y in range(-58, -50):
        for x in range(-2, 3):
            for z in range(-2, 3):
                w.put(x, y, z, P["brass"] if y not in (-58, -51) else P["brass_d"])
    # 半月刃：中心在 (4, -54)，外缘半径 22，内缘半径 15，只取 +x 一侧
    cx, cy = 3, -54
    for y in range(-78, -30):
        for x in range(2, 26):
            r = math.hypot(x - cx, (y - cy) * 1.05)
            if r <= 22.5 and (x - cx) > 0 and (r >= 15 or abs(y - cy) <= 6):
                if x - cx < 4 and abs(y - cy) > 6:
                    continue
                c = P["edge"] if r > 21 else (P["steel"] if r > 17 else P["steel_d"])
                if 9 <= r <= 11 and abs(y - cy) < 4:
                    c = P["iron_d"]                      # 刃上镂一个小孔
                    continue
                w.put(x, y, 0, c, 5)
                if r < 21:
                    w.put(x, y, 1, P["steel_d"], 5)
                    w.put(x, y, -1, P["steel_d"], 5)
    for x in range(-9, -1):                              # 背刺
        hw = 1 if x > -6 else 0
        for y in range(-55 - hw, -53 + hw):
            for z in (-hw, 0, hw):
                w.put(x, y, z, P["iron"])
    w.save()


def crossbow():
    """诸葛连弩：木弩身，前头一张短弓，背上一只长箭匣（顶上能看到一排箭尾），后面握把往下。z 朝上"""
    w = W("crossbow", 11)
    for y in range(-48, 12):                             # 弩身
        for x in range(-2, 3):
            for z in range(-2, 2):
                w.put(x, y, z, P["wood"] if (y % 8) else P["wood_d"])
    for y in range(4, 12):                               # 握把往下
        for x in range(-2, 3):
            for z in range(-10, -2):
                if y - 4 > (-z - 3) * 0.6:
                    w.put(x, y, z, P["wood_d"] if z > -9 else P["brass"])
    for y in range(-40, -8):                             # 箭匣：一只长方盒子，顶上一排箭羽
        for x in range(-3, 4):
            for z in range(2, 9):
                edge = abs(x) == 3 or z in (2, 8) or y in (-40, -9)
                w.put(x, y, z, P["lacq"] if not edge else P["lacq_l"])
    for y in range(-38, -12, 4):
        for x in (-1, 0, 1):
            w.put(x, y, 9, P["feather"] if x != 0 else P["red"])
    for x in range(-22, 23):                             # 短弓：往后弯
        bend = int((x / 22.0) ** 2 * 7)
        y = -44 + bend
        for z in (-1, 0):
            w.put(x, y, z, P["wood_l"] if abs(x) < 18 else P["brass"])
            if abs(x) < 4:
                w.put(x, y - 1, z, P["brass"])
    for x in range(-21, 22):                             # 弓弦
        w.put(x, -37 + 0, 0, P["feather"], 3) if abs(x) > 2 else None
    w.save()


def sword2():
    """长刀（夜樱剑鬼、寂光、烬、烛王）：长柄缠绳，圆形铜盘护手，刀身略弯、单边开刃，刀背暗"""
    w = W("sword2", 13)
    w.rod(1, 20, P["cord"], 1.4, band=lambda y: wrap_band(y))
    w.disk_y(21, 2, P["brass_d"], 1)
    w.disk_y(-1, 5, P["brass"], 2, rim=P["brass_d"])
    w.blade(-84, -2, lambda t: 4.6 if t > 0.1 else max(0.5, 4.6 * t / 0.1), edge2=False)
    w.save()


def staff():
    """拐杖（招魂巫、稻草人、镇魂铃、火师、长明帝）：深色硬木杖，杖头一个弯钩，钩上挂三条黄符纸和一只铜铃"""
    w = W("staff", 15)
    w.rod(-62, 22, P["wood_l"], 1.3, band=lambda y: P["wood"] if y % 9 == 0 else None)
    w.rod(23, 26, P["brass"], 1.0)                      # 杖尾铜箍
    # 弯钩：从 -62 往上弯回去（-x 方向弯成一个问号）
    for i in range(0, 34):
        a = i / 33.0 * math.pi * 1.15
        x = -7 + 7 * math.cos(a)
        y = -62 - 7 * math.sin(a) * 1.15
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if abs(dx) + abs(dz) < 2:
                    w.put(round(x) + dx, round(y), dz, P["wood_l"] if i < 30 else P["brass_l"])
    for k, x0 in enumerate((-4, -8, -12)):              # 符纸：从钩上垂下来
        for y in range(-66, -50 + k * 2):
            for x in (x0, x0 - 1):
                c = P["paper"] if (y % 5) else P["red"]
                w.put(x, y + 14, 0, c, 4)
    for y in range(-58, -54):                            # 铜铃
        for x in range(-3, 2):
            for z in range(-2, 3):
                if (x + 1) ** 2 + z * z <= 5:
                    w.put(x - 13, y + 12, z, P["brass"] if y < -55 else P["brass_d"])
    w.save()


# ---------------- 骷髅、灰衣这些敌人用的（带锈、缺口） ----------------

def skel_blade():
    """锈环首刀：刀首一个大铁环（俯视也看得见），直身单刃，刃口崩了好几个口，满身锈斑"""
    w = W("skel_blade", 17)
    w.rod(1, 11, P["rot"], 1.1, band=lambda y: P["rust_d"] if y % 3 == 0 else None)
    for i in range(0, 40):                               # 环首
        a = i / 40.0 * math.tau
        w.put(round(4.5 * math.cos(a)), round(16 + 4.5 * math.sin(a)), 0, P["iron"] if i % 5 else P["rust"])
        w.put(round(4.5 * math.cos(a)), round(16 + 4.5 * math.sin(a)), 1, P["iron_d"])
    for x in range(-3, 4):
        for z in (-1, 0, 1):
            w.put(x, 0, z, P["iron_d"])
    w.blade(-52, -1, lambda t: 4.0 if t > 0.08 else 4.0 * t / 0.08 + 0.4, edge2=False, nick=0.18, rust=0.22,
            cols=(P["steel"], P["steel_d"], P["iron"]))
    w.save()


def skel_axe():
    """锈板斧：短柄，一大块方斧头（刃口一道亮、其余锈），柄上缠破布"""
    w = W("skel_axe", 19)
    w.rod(-44, 12, P["wood_d"], 1.3, band=lambda y: P["rot"] if 0 < y < 10 and y % 3 else None)
    for y in range(-46, -26):
        for x in range(-3, 21):
            if x < 2 and not (-42 <= y <= -32):
                continue
            far = x >= 18
            c = P["steel"] if far else (P["rust"] if w.rng.random() < 0.45 else P["iron"])
            if far and w.rng.random() < 0.15:
                continue                                 # 缺口
            w.put(x, y, 0, c, 5)
            if not far:
                w.put(x, y, 1, P["iron_d"], 4)
                w.put(x, y, -1, P["iron_d"], 4)
    w.save()


def skel_staff():
    """锡杖（幽魂术士、锁链僧、枯荣）：长杖，杖头一个桃形大环，环上套四只小环，顶上一根尖。铜绿斑驳。杖头朝上拿"""
    w = W("skel_staff", 21)
    w.rod(-58, 16, P["bone_d"], 1.2, band=lambda y: P["bone"] if y % 6 else P["rot"])
    for i in range(0, 64):                               # 桃形环
        a = i / 64.0 * math.tau
        x = 9 * math.sin(a)
        y = -70 + 11 * math.cos(a) - (3 if math.cos(a) < -0.6 else 0)
        for dz in (-1, 0, 1):
            w.put(round(x), round(y), dz, P["verd"] if i % 7 else P["brass"], 5)
    for y in range(-88, -80):                            # 顶尖
        for x in range(-1, 2):
            if abs(x) <= (y + 88) // 4:
                w.put(x, y, 0, P["brass_l"])
    for k, (ax, ay) in enumerate(((-8, -62), (8, -62), (-9, -74), (9, -74))):   # 小环
        for i in range(0, 14):
            a = i / 14.0 * math.tau
            w.put(ax + round(2.6 * math.cos(a)), ay + round(2.6 * math.sin(a)), 0, P["brass"] if k % 2 else P["verd_d"])
    w.save()


def shield_f():
    """藤牌（盾骷髅、灰衣盾兵、镇灯卫）：圆形藤编盾，一圈圈编纹，正面画一张虎脸（黄底、黑纹、红口）。面朝 +x，往前鼓"""
    w = W("shield_f", 23)
    R = 19
    for y in range(-R, R + 1):
        for z in range(-R, R + 1):
            r = math.hypot(y, z)
            if r > R + 0.3:
                continue
            bulge = int(round(4 * (1 - (r / R) ** 2)))
            ring = int(r) % 3 == 0
            c = P["rattan_d"] if ring else P["rattan"]
            if r > R - 1.5:
                c = P["rattan_d"]
            face = None
            if r < 13:                                  # 虎脸
                face = P["yel"]
                if (abs(z) in (4, 5) and -8 <= y <= -4) or (abs(z) in (3, 4, 5, 6) and y == -6):
                    face = P["black"]                   # 眼眶
                if abs(z) == 4 and y == -6:
                    face = P["white"]
                if (y in (-12, -10, -8) and abs(z) <= 2 and y != -8) or (y == -8 and abs(z) <= 3) or (z == 0 and -12 <= y <= -8):
                    face = P["black"]                   # 额上一个“王”
                if abs(z) in (9, 10, 11) and y in (-2, 1, 4) or (abs(z) in (6, 7) and y == -9):
                    face = P["black"]                   # 胡须纹、眉梢
                if abs(z) in (2, 3) and y in (8, 9):
                    face = P["white"]                   # 獠牙
                if 3 <= y <= 7 and abs(z) <= 4:
                    face = P["red"] if not (y == 5 and abs(z) <= 3) else P["white"]   # 张口露牙
                if r > 12:
                    face = P["red_d"]
            col = face if face else c
            w.put(-bulge, y, z, col, 5)                 # 盾面朝 -x（_place 把模型 -x 转到身前）
            for xb in range(-1, bulge):
                w.put(-xb, y, z, P["rattan_d"], 4)
    w.save()


def skel_shield():
    """skel_shield（老代码偶尔引用）：和 shield_f 同一张藤牌，盾面换到 x-y 平面"""
    shield_f()
    src = os.path.join(OUT, "shield_f.json.gz")
    d = json.load(gzip.open(src))
    v = d["vox"]
    out = W("skel_shield")
    for i in range(0, len(v), 6):
        x, y, z = v[i:i + 3]
        out.c[(z, y, x)] = tuple(v[i + 3:i + 6])
    out.save()


def arrow():
    """弩箭：短杆、三棱铁头、尾上白羽一点红"""
    w = W("arrow", 25)
    w.rod(-12, 14, P["wood"], 0.5)
    for y in range(-16, -12):
        for x in range(-1, 2):
            if abs(x) <= (y + 16) // 2:
                w.put(x, y, 0, P["iron"])
    for y in range(10, 16):
        for x in (-2, -1, 1, 2):
            w.put(x, y, 0, P["feather"] if y < 15 else P["red"])
    w.save()


ALL = {f.__name__: f for f in (sword, gun, dagger, axe2, crossbow, sword2, staff, skel_blade, skel_axe, skel_staff, shield_f, skel_shield, arrow)}

if __name__ == "__main__":
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()
