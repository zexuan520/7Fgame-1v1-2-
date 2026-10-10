"""人形敌人：和主角同一套骨架和画法（rig.py），体型、头、衣服、武器按“行头”表 costume 来画。

姿势参数和主角一样（见 heroine.py），另外：
  pull       弓手拉弦（后手拉到胸前，搭着箭）
  open_hand  后手张开往前抓（擒拿）
坐标按 costume["scale"] 放大：同一套姿势数字，大个子的敌人画出来就高一些（头还是那么大，显得更魁梧）。

行头 costume 的字段：
  scale        身材（1.0 和主角一样高）
  head         头（HEADS 里的名字）
  ramps        各部分的四阶色：cloth 上衣、pants 裤子、skin、hair、belt、cape、hat、metal、wood、blade、hilt、guard……
  sleeves      wide 宽袖（袖口垂一片）/ tight 窄袖（护臂）
  legs         hakama 宽裤腿 / wrapped 绑腿
  feet         sandal 草鞋（露脚）/ boot 靴
  skirt        袍子后摆长度（0 = 没有）
  cape         披风：ragged 破披风 / haori 外褂（长到膝盖）
  armor        胸甲（铁片）和肩甲
  weapon       katana 刀 / spear 长枪 / bow 弓 / none
  shield       后手拿木盾挡在身前
  quiver       背上挂箭袋
  sheath       腰上挂刀鞘
  band_tails   头带的两条飘带（用马尾的物理）
"""
import math
from rig import (OUTLINE, v, add, sub, mul, lerp, norm, length, adir, rot, ik,
                 Canvas, Part, Frame, poly_mask, capsule_mask, line_px, shade)

W, H = 128, 96
OX, OY = 56, 88

DEF = dict(hip=(0.0, -18.0), lean=0.06, rot=0.0, head="n", head_off=(0.0, 0.0),
           ff=(4.0, 0.0), fb=(-4.0, 0.0), ffa=0.0, fba=0.0,
           hf=None, hb=None, af=(0.25, 0.5), ab=(-0.15, 0.1), ebf=-1, ebb=-1,
           sw=None, grip2=False, sw_back=False, swlen=None,
           robe=0.0, lift=0.0, sleeve=0.0, pull=False, open_hand=False, bowv=False)

THIGH, SHIN = 8.5, 8.0
UPPER, FORE = 6.3, 6.0
TORSO = 10.0


def pose(**kw):
    p = dict(DEF)
    p.update(kw)
    return p


def lerp_pose(a, b, t):
    out = {}
    for k in DEF:
        x, y = a[k], b[k]
        if isinstance(x, (int, float)) and isinstance(y, (int, float)) and not isinstance(x, bool):
            out[k] = x + (y - x) * t
        elif isinstance(x, tuple) and isinstance(y, tuple):
            out[k] = lerp(x, y, t)
        else:
            out[k] = x if t < 0.5 else y
    return out


def _darker(ramp):
    return [ramp[0], ramp[1], ramp[1], ramp[2]]


# ---------------- 头（手绘像素，朝右） ----------------
# 每个头：rows 是像素行，neck 是脖子接点在网格里的位置，tails 是头带飘带的根（没有就是 None）。
# 字母：K 描线 H 头发 h 头发亮 S 皮肤 s 皮肤暗 E 眼睛 e 眼白/眼光 T 帽子 t 帽子暗 L 帽子亮
#       M 铁 m 铁暗 N 铁亮 W 头带 w 头带暗 B 胡茬 R 嘴
HEADS = {
    # 浪人：压得很低的斗笠，脸藏在阴影里，只露一只眼和胡茬
    "kasa": {"neck": (13.5, 15.0), "tails": None, "rows": [
        "..........KK..........",
        "........KLLTK.........",
        "......KLLLTTTK........",
        "....KLLLTTTTTTTK......",
        "..KLLLTTTTTTTTTTTK....",
        "KLLTTTTTTTTTTTTTTTtK..",
        "KttttttttttttttttttttK",
        "......KHHHtssssss.....",
        ".......HHHsseEss......",
        ".......HHHHSSSSSSS....",
        "........HHSSSSSSS.....",
        "........HHBSBBBS......",
        ".........HBBBBB.......",
        "..........sBBBs.......",
        "...........sss........",
    ]},
    # 弓手：短发、扎一条头带，年轻山贼
    "bandana": {"neck": (9.5, 14.0), "tails": (2.0, 5.0), "rows": [
        "....KHHHHK....",
        "..KHHHhhHHK...",
        ".KHHHHHHhHHK..",
        ".KWWWWWWWWWWK.",
        ".KwwwHHHHWWWK.",
        ".KHHHHHHSHHSK.",
        ".KHHHHHSSSSSS.",
        ".KHHHHsHSSEKS.",
        ".KHHHHsHSSEES.",
        "..KHHHHSSSSSSK",
        "..KHHHsHSSSRS.",
        "...KHHsSSSSS..",
        "....KssSSSS...",
        "......sSs.....",
    ]},
    # 盾兵：铁斗笠（阵笠），一字胡
    "jingasa": {"neck": (10.5, 15.0), "tails": None, "rows": [
        "........KK........",
        ".......KNNK.......",
        "....KKNNMMMMKK....",
        "..KNNMMMMMMMMmmK..",
        "KNMMMMMMMMMMMMMmmK",
        "KmmmmmmmmmmmmmmmmK",
        "...KHHHHSSSSSS....",
        "...HHHHsSSEKSS....",
        "...HHHHsSSEESSS...",
        "...HHHHHSSSSSSS...",
        "....HHHSBBBBBB....",
        "....HHHSSSRSS.....",
        ".....HHsSSSS......",
        ".......ssSS.......",
        "........s.........",
    ]},
    # 柳江远：灰白鬓角、发髻、白头带（两条飘带），短须
    "liu": {"neck": (9.5, 14.0), "tails": (2.5, 5.5), "rows": [
        "....KKK.......",
        "...KHhHK......",
        "..KHHHHHHK....",
        ".KHHHhHHHHHK..",
        ".KWWWWWWWWWWK.",
        ".KwwHHHHHHWWK.",
        ".KhHHHHHHSHSK.",
        ".KhHHHHHSSSSS.",
        ".KhHHHsHSSEKS.",
        "..hHHHsHSSEES.",
        "..KhHHHSSSSSSK",
        "..KhHHsSBSSBS.",
        "...KHHsSBBBS..",
        "....KssSBBS...",
    ]},
    # 教头：发髻，浓眉
    "topknot": {"neck": (9.5, 14.0), "tails": None, "rows": [
        "....KKK.......",
        "...KHHHK......",
        "..KKHHHKKK....",
        ".KHHHHHHHHK...",
        ".KHHHHHHHHHK..",
        ".KHHHHHHHHHHK.",
        ".KHHHHHHHKKSK.",
        ".KHHHHHHSSSSS.",
        ".KHHHHsHSSEKS.",
        "..KHHHsHSSEES.",
        "..KHHHHSSSSSSK",
        "..KHHHsSSSRSS.",
        "...KHHsSSSSS..",
        "....KssSSSS...",
    ]},
}


def _head_grid(name, expr):
    rows = [list(r) for r in HEADS[name]["rows"]]
    # 表情：疼的时候闭眼，倒下闭眼。只改眼睛那两格（E/K/e 换成皮肤或描线）
    if expr in ("h", "c"):
        for y, r in enumerate(rows):
            for x, c in enumerate(r):
                if c in "Ee":
                    r[x] = "S" if c == "E" else "s"
                elif c == "K" and 6 <= y <= 9 and x > len(r) // 2 and "E" in "".join(HEADS[name]["rows"][y]):
                    r[x] = "S"
        # 闭眼一道横线
        for y, r in enumerate(HEADS[name]["rows"]):
            if "E" in r:
                x = r.index("E")
                rows[y][x] = "K"
                if x + 1 < len(rows[y]):
                    rows[y][x + 1] = "K" if rows[y][x + 1] in "SEe" else rows[y][x + 1]
                break
    return rows


# ---------------- 骨架 ----------------

def skeleton(p, C):
    s = C["scale"]
    S = lambda q: (q[0] * s, q[1] * s)
    hip = S(v(*p["hip"]))
    lean = p["lean"]
    up = (math.sin(lean), -math.cos(lean))
    fwd = (math.cos(lean), math.sin(lean))
    j = {"hip": hip, "up": up, "fwd": fwd, "_rot": p["rot"], "s": s}
    j["neck"] = add(hip, mul(up, TORSO * s))
    j["sh_f"] = add(add(hip, mul(up, 8.5 * s)), mul(fwd, 1.0 * s))
    j["sh_b"] = add(add(hip, mul(up, 8.5 * s)), mul(fwd, -1.5 * s))
    j["hip_f"] = add(hip, mul(fwd, 1.0 * s))
    j["hip_b"] = add(hip, mul(fwd, -1.5 * s))
    for side, foot, ang in (("f", p["ff"], p["ffa"]), ("b", p["fb"], p["fba"])):
        ankle = add(S(v(*foot)), (-4.0 * s * (1.0 - math.cos(ang)), (-2.0 - 4.0 * math.sin(max(0.0, ang))) * s))
        j["ankle_" + side] = ankle
        j["knee_" + side] = ik(j["hip_" + side], ankle, THIGH * s, SHIN * s, +1)
        j["fa_" + side] = ang
    for side in ("f", "b"):
        sh = j["sh_" + side]
        target = p["h" + side]
        if side == "b" and p["grip2"] and p["sw"] is not None and p["hf"] is not None:
            target = add(v(*p["hf"]), mul(adir(p["sw"]), -2.5))
        if target is not None:
            wrist = S(v(*target))
            elbow = ik(sh, wrist, UPPER * s, FORE * s, p["eb" + side])
        else:
            a0, a1 = p["a" + side]
            elbow = add(sh, mul(adir(a0), UPPER * s))
            wrist = add(elbow, mul(adir(a1), FORE * s))
        j["elbow_" + side] = elbow
        j["wrist_" + side] = wrist
    j["head"] = add(j["neck"], S(v(*p["head_off"])))
    hd = HEADS[C["head"]]
    if hd["tails"]:
        j["tails"] = add(j["head"], (hd["tails"][0] - hd["neck"][0], hd["tails"][1] - hd["neck"][1]))
    else:
        j["tails"] = j["head"]
    swlen = p["swlen"] if p["swlen"] is not None else C.get("swlen", 22.0)
    j["swlen"] = swlen * s
    if p["sw"] is not None:
        d = adir(p["sw"])
        j["sw_d"] = d
        j["tip"] = add(j["wrist_f"], mul(d, (3.0 + swlen) * s))
    j["mouth"] = add(add(hip, mul(up, 1.5 * s)), mul(fwd, 2.8 * s))
    j["sheath_d"] = norm(rot((-0.62, 0.78), lean * 0.3))      # 斜挂在胯侧
    if abs(p["rot"]) > 1e-4:
        c = add(hip, mul(up, 4.0 * s))
        j["rot_c"] = c
        for k, val in list(j.items()):
            if k in ("up", "fwd", "sw_d", "sheath_d"):
                j[k] = rot(val, p["rot"])
            elif isinstance(val, tuple) and k != "rot_c" and not k.startswith("fa_"):
                j[k] = rot(val, p["rot"], c)
    return j


def _tatters(a, b, n, depth, seed=0):
    pat = [0.0, 0.9, 0.2, 1.0, 0.4, 0.75, 0.1, 0.95]
    out = []
    for i in range(1, n):
        q = lerp(a, b, i / n)
        out.append((q[0], q[1] + depth * pat[(i + seed) % len(pat)]))
    return out


# ---------------- 部件 ----------------

def _cape(cv, p, j, C):
    """披风（破的）或外褂：从肩膀后面垂下来，跑动、出招时往后飘"""
    R = C["ramps"]["cape"]
    s = j["s"]
    up, fwd, hip, neck = j["up"], j["fwd"], j["hip"], j["neck"]
    fl = p["robe"] * s
    kind = C["cape"]
    length_ = (21.0 if kind == "haori" else 19.0) * s
    top_f = add(add(neck, mul(fwd, 1.0 * s)), mul(up, -1.0 * s))
    top_b = add(add(neck, mul(fwd, -5.5 * s)), mul(up, -1.5 * s))
    hem_b = (top_b[0] - 5.0 * s - fl, top_b[1] + length_ - fl * 0.3 - p["lift"] * s)
    hem_f = (hip[0] + 1.0 * s, hip[1] + (6.0 if kind == "haori" else 2.0) * s - p["lift"] * s * 0.5)
    mid = (top_b[0] - 1.5 * s - fl * 0.5, (top_b[1] + hem_b[1]) / 2)
    pts = [top_f, top_b, mid, hem_b] + _tatters(hem_b, hem_f, 5, (3.0 if kind == "ragged" else 1.2) * s, seed=2) + [hem_f]
    part = Part(line=R[0])
    part.px.update(shade(poly_mask(cv, pts), R, dark2=True))
    return part


def _leg(cv, p, j, side, C):
    near = side == "f"
    s = j["s"]
    hipj, knee, ankle = j["hip_" + side], j["knee_" + side], j["ankle_" + side]
    PR = C["ramps"]["pants"]
    pr = PR if near else _darker(PR)
    pants = Part(line=PR[0])
    fa = j["fa_" + side]
    sole = [(-2.0, -0.6), (1.0, -0.6), (4.0, 1.0), (4.2, 2.0), (-2.2, 2.0)]
    foot = [add(ankle, mul(rot(rot(q, fa), j["_rot"]), s)) for q in sole]
    parts = []
    if C["legs"] == "hakama":
        # 宽裤腿：大腿到脚踝越来越宽，像裙裤
        m = capsule_mask(cv, hipj, knee, 2.6 * s, 2.6 * s) | capsule_mask(cv, knee, add(ankle, (0, -0.5)), 2.6 * s, 3.3 * s)
        pants.px.update(shade(m, pr))
        for q in line_px(cv, lerp(hipj, knee, 0.3), lerp(knee, ankle, 0.85)):
            if q in pants.px:
                pants.px[q] = pr[1]
        parts.append(pants)
        wrap_top = None
    else:
        wrap_top = lerp(knee, ankle, 0.3)
        m = capsule_mask(cv, hipj, knee, 2.4 * s, 2.1 * s) | capsule_mask(cv, knee, wrap_top, 2.1 * s, 2.0 * s)
        pants.px.update(shade(m, pr))
        parts.append(pants)
    # 小腿绑腿 / 靴子、脚
    if C["feet"] == "boot":
        FR = C["ramps"]["boot"]
    else:
        FR = C["ramps"]["wrap"]
    fr = FR if near else _darker(FR)
    shin = Part(line=FR[0])
    bm = poly_mask(cv, foot)
    if wrap_top is not None:
        bm |= capsule_mask(cv, wrap_top, ankle, 2.0 * s, 1.8 * s)
    shin.px.update(shade(bm, fr))
    if C["feet"] == "sandal":
        # 草鞋：脚背露皮肤，鞋底一道草色
        sk = C["ramps"]["skin"] if near else _darker(C["ramps"]["skin"])
        for q in list(shin.px):
            if q[1] < cv.to_px(ankle)[1] + int(1.5 * s) and q not in (capsule_mask(cv, wrap_top, ankle, 2.0 * s, 1.8 * s) if wrap_top else set()):
                shin.px[q] = sk[2]
        for q in line_px(cv, foot[4], foot[3]):
            shin.px[q] = C["ramps"]["wrap"][3] if near else C["ramps"]["wrap"][2]
    if wrap_top is not None:
        # 绑腿的斜纹
        for k in range(3):
            a = lerp(wrap_top, ankle, 0.2 + k * 0.28)
            for q in line_px(cv, add(a, (-1.8 * s, -0.8)), add(a, (1.8 * s, 0.8))):
                if q in shin.px:
                    shin.px[q] = fr[1]
    parts.append(shin)
    return parts


def _skirt(cv, p, j, C):
    """袍子后摆（外褂、长衣）：从腰垂到小腿，往后飘"""
    R = C["ramps"]["cloth"]
    s = j["s"]
    hip, up, fwd = j["hip"], j["up"], j["fwd"]
    kb, kf = j["knee_b"], j["knee_f"]
    hem_y = hip[1] + C["skirt"] * s - p["lift"] * s
    top_b = add(add(hip, mul(up, 1.5 * s)), mul(fwd, -4.5 * s))
    top_f = add(add(hip, mul(up, 1.5 * s)), mul(fwd, 1.5 * s))
    fl = p["robe"] * s
    back_x = min(hip[0] - 6.0 * s, kb[0] - 2.0 * s) - fl
    front_x = hip[0] + 1.0 * s + max(0.0, kf[0] - hip[0]) * 0.3
    mid_b = (hip[0] - 5.5 * s - fl * 0.55, hip[1] + 5.0 * s)
    hem_b = (back_x - fl * 0.3, hem_y - fl * 0.35)
    hem_f = (front_x, hem_y - 1.0)
    pts = [top_f, top_b, mid_b, hem_b] + _tatters(hem_b, hem_f, 5, 1.5 * s) + [hem_f]
    part = Part(line=R[0])
    part.px.update(shade(poly_mask(cv, pts), R, dark2=True))
    return part


def _torso(cv, p, j, C):
    R = C["ramps"]["cloth"]
    s = j["s"]
    hip, up, fwd, neck = j["hip"], j["up"], j["fwd"], j["neck"]
    w = C.get("width", 1.0)
    pts = [add(add(hip, mul(up, 0.5 * s)), mul(fwd, -4.5 * s * w)), add(add(hip, mul(up, 0.5 * s)), mul(fwd, 4.0 * s * w)),
           add(add(hip, mul(up, 8.0 * s)), mul(fwd, 4.3 * s * w)), add(neck, mul(fwd, 2.2 * s)),
           add(neck, mul(fwd, -2.7 * s)), add(add(hip, mul(up, 8.0 * s)), mul(fwd, -4.8 * s * w))]
    tm = poly_mask(cv, pts)
    parts = []
    tp = Part(line=R[0])
    tp.px.update(shade(tm, R, dark2=True))
    # 交领：里衣一道
    col = C["ramps"].get("collar", R)
    for q in line_px(cv, add(neck, mul(fwd, 1.3 * s)), add(add(hip, mul(up, 3.0 * s)), mul(fwd, 3.4 * s * w))):
        if q in tp.px:
            tp.px[q] = col[2]
    parts.append(tp)
    if C.get("armor"):
        M = C["ramps"]["metal"]
        ap = Part(line=M[0])
        plate = [add(add(hip, mul(up, 3.5 * s)), mul(fwd, -3.8 * s * w)), add(add(hip, mul(up, 3.5 * s)), mul(fwd, 4.4 * s * w)),
                 add(add(hip, mul(up, 9.0 * s)), mul(fwd, 4.2 * s * w)), add(add(hip, mul(up, 9.0 * s)), mul(fwd, -4.0 * s * w))]
        am = poly_mask(cv, plate)
        ap.px.update(shade(am, M))
        # 一排排甲片
        for k in range(1, 4):
            a = lerp(plate[0], plate[3], k / 4)
            b = lerp(plate[1], plate[2], k / 4)
            for q in line_px(cv, a, b):
                if q in ap.px:
                    ap.px[q] = M[1]
        parts.append(ap)
    # 腰带
    B = C["ramps"]["belt"]
    bp = Part()
    band = [add(add(hip, mul(up, 1.0 * s)), mul(fwd, -4.8 * s * w)), add(add(hip, mul(up, 1.0 * s)), mul(fwd, 4.3 * s * w)),
            add(add(hip, mul(up, 3.4 * s)), mul(fwd, 4.3 * s * w)), add(add(hip, mul(up, 3.4 * s)), mul(fwd, -4.8 * s * w))]
    bp.px.update(shade(poly_mask(cv, band), B, front=(9, 9)))
    parts.append(bp)
    return parts


def _arm(cv, p, j, side, C):
    near = side == "f"
    s = j["s"]
    sh, el, wr = j["sh_" + side], j["elbow_" + side], j["wrist_" + side]
    CR = C["ramps"]["cloth"]
    ramp = CR if near else _darker(CR)
    arm = Part(line=CR[0])
    cuff = lerp(el, wr, 0.7 if C["sleeves"] == "wide" else 0.85)
    m = capsule_mask(cv, sh, el, 2.4 * s, 2.1 * s) | capsule_mask(cv, el, cuff, 2.1 * s, 2.2 * s)
    if C["sleeves"] == "wide":
        fl = p["sleeve"] * s
        drape = [add(el, (0.0, 1.6 * s)), add(cuff, (0.0, 2.0 * s)), add(cuff, (-0.8 * s - fl, 4.0 * s)),
                 add(el, (-1.2 * s - fl * 0.8, 3.2 * s))]
        m |= poly_mask(cv, drape)
    arm.px.update(shade(m, ramp))
    parts = [arm]
    if C.get("armor"):
        # 肩甲：一块铁片压在肩上
        M = C["ramps"]["metal"]
        sp = Part(line=M[0])
        d = norm(sub(el, sh))
        perp = (-d[1], d[0])
        pad = [add(sh, mul(perp, 3.2 * s)), add(sh, mul(perp, -3.2 * s)),
               add(add(sh, mul(d, 5.0 * s)), mul(perp, -3.0 * s)), add(add(sh, mul(d, 5.0 * s)), mul(perp, 3.0 * s))]
        sp.px.update(shade(poly_mask(cv, pad), M if near else _darker(M)))
        parts.append(sp)
    if C["sleeves"] == "tight":
        # 护臂：小臂一截皮护腕
        G = C["ramps"]["belt"]
        gp = Part(line=G[0])
        gp.px.update(shade(capsule_mask(cv, lerp(el, wr, 0.45), cuff, 1.9 * s, 1.9 * s), G if near else _darker(G)))
        parts.append(gp)
    hand = Part(line=C["ramps"]["skin"][0])
    sk = C["ramps"]["skin"] if near else _darker(C["ramps"]["skin"])
    if not near and p["open_hand"]:
        # 张开的手：五指散开
        d = norm(sub(wr, el))
        perp = (-d[1], d[0])
        hm = capsule_mask(cv, lerp(cuff, wr, 0.4), wr, 1.2 * s, 1.6 * s)
        for k in (-1.0, 0.0, 1.0):
            hm |= capsule_mask(cv, wr, add(add(wr, mul(d, 2.2 * s)), mul(perp, k * 1.4 * s)), 0.5)
        hand.px.update(shade(hm, C["ramps"]["skin"]))
    else:
        hand.px.update(shade(capsule_mask(cv, lerp(cuff, wr, 0.5), wr, 1.1 * s, 1.4 * s), sk))
    return parts, hand


def _katana(cv, p, j, C):
    """刀：微弯的刀身（刃口朝下），圆形护手，缠绳刀柄"""
    s = j["s"]
    wr, d = j["wrist_f"], j["sw_d"]
    perp = (-d[1], d[0])
    if perp[1] > 0:
        perp = (-perp[0], -perp[1])
    L = j["swlen"]
    BR, HR, GR = C["ramps"]["blade"], C["ramps"]["hilt"], C["ramps"]["guard"]
    parts = []
    blade = Part(line=BR[0])
    b0 = add(wr, mul(d, 3.0 * s))
    mid = add(add(wr, mul(d, 3.0 * s + L * 0.55)), mul(perp, 0.8 * s))   # 刀背微微拱起
    b1 = add(add(wr, mul(d, 3.0 * s + L)), mul(perp, 0.3 * s))
    m = capsule_mask(cv, b0, mid, 1.0 * s) | capsule_mask(cv, mid, add(b1, mul(d, -2.5 * s)), 1.0 * s, 0.9 * s) | \
        capsule_mask(cv, add(b1, mul(d, -2.5 * s)), b1, 0.9 * s, 0.3)
    for q in m:
        c = cv.center(*q)
        side_ = (c[0] - b0[0]) * perp[0] + (c[1] - b0[1]) * perp[1]
        blade.put(q, BR[3] if side_ > 0.5 else BR[2])
    parts.append(blade)
    hilt = Part(line=HR[0])
    hm = capsule_mask(cv, add(wr, mul(d, -3.5 * s)), add(wr, mul(d, 1.8 * s)), 0.95 * s)
    hilt.px.update(shade(hm, HR))
    # 缠绳的菱形花纹
    for k in range(3):
        q = cv.to_px(add(wr, mul(d, (-2.6 + k * 1.6) * s)))
        if q in hilt.px:
            hilt.px[q] = HR[3]
    parts.append(hilt)
    guard = Part(line=GR[0])
    gc = add(wr, mul(d, 2.4 * s))
    guard.px.update(shade(capsule_mask(cv, add(gc, mul(perp, 1.8 * s)), add(gc, mul(perp, -1.8 * s)), 0.9 * s), GR))
    parts.append(guard)
    return parts


def _spear(cv, p, j, C):
    """长枪：木杆从手后面伸出去很长，枪头一截铁，枪头下一撮红缨"""
    s = j["s"]
    wr, d = j["wrist_f"], j["sw_d"]
    perp = (-d[1], d[0])
    WR, BR = C["ramps"]["wood"], C["ramps"]["blade"]
    L = j["swlen"]
    tail = add(wr, mul(d, -14.0 * s))
    head0 = add(wr, mul(d, L - 6.0 * s))
    tip = add(wr, mul(d, L))
    parts = []
    shaft = Part(line=WR[0])
    shaft.px.update(shade(capsule_mask(cv, tail, head0, 0.8 * s), WR))
    parts.append(shaft)
    head = Part(line=BR[0])
    hp = [add(head0, mul(perp, 1.8 * s)), tip, add(head0, mul(perp, -1.8 * s)), add(head0, mul(d, -1.0 * s))]
    head.px.update(shade(poly_mask(cv, hp), BR))
    parts.append(head)
    tas = Part()
    TR = C["ramps"].get("tassel", ["5a0e0e", "8a1e1a", "c0302a", "e04a3a"])
    for q in capsule_mask(cv, add(head0, mul(d, -1.5 * s)), add(add(head0, mul(d, -4.5 * s)), (0, 2.0 * s)), 1.1 * s):
        tas.put(q, TR[2])
    parts.append(tas)
    return parts


def _bow(cv, p, j, C, front):
    """弓：前手握弓背，弓身和前臂垂直；拉弦时弦拉到后手，搭着一支箭。front=False 只画身后的弦"""
    s = j["s"]
    hf, hb, el = j["wrist_f"], j["wrist_b"], j["elbow_f"]
    d = norm(sub(hf, el))
    if p["bowv"]:
        d = (0.97, 0.25)          # 垂着手拿弓：弓身竖着
    axis = (-d[1], d[0])
    half = 13.0 * s
    top = add(add(hf, mul(axis, half)), mul(d, -3.0 * s))
    bot = add(add(hf, mul(axis, -half)), mul(d, -3.0 * s))
    nock = hb if p["pull"] else lerp(top, bot, 0.5)
    WR = C["ramps"]["wood"]
    if not front:
        sp = Part()
        for a, b in ((top, nock), (nock, bot)):
            for q in line_px(cv, a, b):
                sp.put(q, "d8d0c0")
        return [sp]
    parts = []
    bow = Part(line=WR[0])
    m = set()
    prev = None
    for i in range(11):
        t = -1.0 + i / 5.0
        q = add(add(hf, mul(axis, half * t)), mul(d, 2.5 * s * (1.0 - t * t) - 3.0 * s))
        if prev is not None:
            m |= capsule_mask(cv, prev, q, 0.9 * s)
        prev = q
    bow.px.update(shade(m, WR))
    parts.append(bow)
    if p["pull"]:
        arrow = Part()
        tip = add(hf, mul(d, 6.0 * s))
        for q in line_px(cv, nock, tip):
            arrow.put(q, "c9b08a")
        arrow.put(cv.to_px(tip), "eef0f6")
        for q in line_px(cv, nock, add(nock, mul(d, 2.5 * s))):
            arrow.put((q[0], q[1] - 1), "f0ece4")     # 箭羽
        parts.append(arrow)
    return parts


def _shield(cv, p, j, C):
    """木盾：后手拿着挡在身前，几块木板拼的，两道铁箍"""
    s = j["s"]
    c = add(j["wrist_b"], (2.0 * s, -1.0 * s))
    WR, M = C["ramps"]["wood"], C["ramps"]["metal"]
    w, h = 5.0 * s, 11.5 * s
    pts = [(c[0] - w, c[1] - h), (c[0] + w, c[1] - h + 1.0), (c[0] + w, c[1] + h - 1.0), (c[0] - w, c[1] + h)]
    part = Part(line=WR[0])
    m = poly_mask(cv, pts)
    part.px.update(shade(m, WR))
    for k in (1, 2):
        x = c[0] - w + 2 * w * k / 3
        for q in line_px(cv, (x, c[1] - h + 1.5), (x, c[1] + h - 1.5)):
            if q in part.px:
                part.px[q] = WR[1]
    for yy in (c[1] - h * 0.55, c[1] + h * 0.5):
        for q in line_px(cv, (c[0] - w, yy), (c[0] + w, yy)):
            if q in part.px:
                part.px[q] = M[2]
    boss = cv.to_px(c)
    part.px[boss] = M[3]
    return part


def _sheath(cv, p, j, C):
    s = j["s"]
    mouth, bd = j["mouth"], j["sheath_d"]
    end = add(mouth, mul(bd, j["swlen"] * 0.85))
    SR = C["ramps"]["sheath"]
    sh = Part(line=SR[0])
    sh.px.update(shade(capsule_mask(cv, mouth, end, 1.1 * s), SR))
    parts = [sh]
    if p["sw"] is None:
        # 刀在鞘里：露出护手和刀柄
        hd = norm(rot((0.92, -0.38), p["lean"] * 0.3 + p["rot"]))
        perp = (-hd[1], hd[0])
        HR, GR = C["ramps"]["hilt"], C["ramps"]["guard"]
        hilt = Part(line=HR[0])
        hilt.px.update(shade(capsule_mask(cv, add(mouth, mul(hd, 1.5 * s)), add(mouth, mul(hd, 7.0 * s)), 0.95 * s), HR))
        parts.append(hilt)
        guard = Part(line=GR[0])
        gc = add(mouth, mul(hd, 1.0 * s))
        guard.px.update(shade(capsule_mask(cv, add(gc, mul(perp, 1.7 * s)), add(gc, mul(perp, -1.7 * s)), 0.85 * s), GR))
        parts.append(guard)
    return parts


def _quiver(cv, p, j, C):
    s = j["s"]
    a = add(add(j["neck"], mul(j["fwd"], -3.5 * s)), mul(j["up"], 0.5 * s))
    b = add(add(j["hip"], mul(j["fwd"], -5.0 * s)), mul(j["up"], 2.0 * s))
    WR = C["ramps"]["belt"]
    part = Part(line=WR[0])
    part.px.update(shade(capsule_mask(cv, a, b, 1.6 * s), WR))
    for k in range(3):
        q = cv.to_px(add(a, (k * 1.2 - 1.0, -1.5 * s)))
        part.put(q, "f0ece4")
        part.put((q[0], q[1] - 1), "c9b08a")
    return part


def _head(cv, p, j, C):
    hd = HEADS[C["head"]]
    g = _head_grid(C["head"], p["head"])
    pal = C["head_colors"]
    part = Part(line=OUTLINE)
    origin = sub(j["head"], hd["neck"])
    ang = p["rot"]
    hh, hw = len(g), max(len(r) for r in g)
    if abs(ang) < 1e-4:
        ox, oy = cv.to_px(origin)
        for gy in range(hh):
            for gx, c in enumerate(g[gy]):
                if c != "." and c in pal:
                    part.put((ox + gx, oy + gy), pal[c])
        return part
    c0 = j["head"]
    for py in range(max(0, int(c0[1] + cv.oy) - 24), min(cv.h, int(c0[1] + cv.oy) + 8)):
        for px in range(max(0, int(c0[0] + cv.ox) - 20), min(cv.w, int(c0[0] + cv.ox) + 20)):
            u = rot(cv.center(px, py), -ang, c0)
            gx = int(math.floor(u[0] - origin[0]))
            gy = int(math.floor(u[1] - origin[1]))
            if 0 <= gy < hh and 0 <= gx < len(g[gy]) and g[gy][gx] != "." and g[gy][gx] in pal:
                part.put((px, py), pal[g[gy][gx]])
    return part


def _tails(cv, pts, C):
    """头带的两条飘带（用马尾一样的物理）"""
    R = C["ramps"]["band"]
    part = Part(line=R[0])
    m = set()
    for k in range(len(pts) - 1):
        m |= capsule_mask(cv, pts[k], pts[k + 1], 0.9 if k < 3 else 0.6)
    part.px.update(shade(m, R))
    return part


# ---------------- 画一帧 ----------------

def draw(p, C, tails=None, smear=None, flip=False, glow=None):
    cv = Canvas(W, H, OX, OY)
    j = skeleton(p, C)
    fr = Frame(cv)

    if C.get("band_tails") and tails is not None:
        fr.add(_tails(cv, tails, C))
    if C.get("cape"):
        fr.add(_cape(cv, p, j, C))
    if C.get("quiver"):
        fr.add(_quiver(cv, p, j, C))
    weapon = C["weapon"]
    if weapon == "bow":
        for part in _bow(cv, p, j, C, front=False):
            fr.add(part)

    back_parts, back_hand = _arm(cv, p, j, "b", C)
    for part in back_parts:
        fr.add(part)
    hold_back = p["grip2"] and p["sw"] is not None
    if not hold_back and not C.get("shield"):
        fr.add(back_hand)

    if p["sw"] is not None and p["sw_back"] and weapon in ("katana", "spear"):
        for part in (_katana if weapon == "katana" else _spear)(cv, p, j, C):
            fr.add(part)

    for part in _leg(cv, p, j, "b", C):
        fr.add(part)
    sheath_parts = _sheath(cv, p, j, C) if C.get("sheath") else []
    if sheath_parts:
        fr.add(sheath_parts[0])
    if C.get("skirt"):
        fr.add(_skirt(cv, p, j, C))
    for part in _leg(cv, p, j, "f", C):
        fr.add(part)
    for part in _torso(cv, p, j, C):
        fr.add(part)
    for part in sheath_parts[1:]:
        fr.add(part)
    fr.add(_head(cv, p, j, C))
    if C.get("shield"):
        fr.add(_shield(cv, p, j, C))
        fr.add(back_hand)
    if hold_back:
        fr.add(back_hand)
    if p["sw"] is not None and not p["sw_back"] and weapon in ("katana", "spear"):
        for part in (_katana if weapon == "katana" else _spear)(cv, p, j, C):
            fr.add(part)
    front_parts, front_hand = _arm(cv, p, j, "f", C)
    for part in front_parts:
        fr.add(part)
    fr.add(front_hand)
    if weapon == "bow":
        for part in _bow(cv, p, j, C, front=True):
            fr.add(part)

    if smear is not None:
        import smear as sm
        sp = sm.render(cv, smear, p, skeleton_fn=lambda q: skeleton(q, C))
        body = dict(fr.px)
        fr.px = {}
        fr.add(sp, glow=True)
        for q, val in body.items():
            fr.px[q] = val
            fr.glow.discard(q)
    img = fr.finish()
    tip = j.get("tip")
    if weapon == "bow":
        tip = add(j["wrist_f"], mul(norm(sub(j["wrist_f"], j["elbow_f"])), 6.0 * j["s"]))
    if flip:
        from PIL import Image as _I
        img = img.transpose(_I.FLIP_LEFT_RIGHT)
        shift = 2 * OX - W
        out = _I.new("RGBA", img.size, (0, 0, 0, 0))
        out.alpha_composite(img, (shift, 0)) if shift >= 0 else out.alpha_composite(img.crop((-shift, 0, W, H)), (0, 0))
        img = out
        tip = (-tip[0], tip[1]) if tip else None
    hd = HEADS[C["head"]]
    eye = None
    for y, r in enumerate(hd["rows"]):
        if "E" in r:
            eye = add(sub(j["head"], hd["neck"]), (r.index("E") + 0.5, y + 0.5))
            break
    meta = {"tip": tip, "hand": j["wrist_f"], "hand_b": j["wrist_b"], "tails": j["tails"], "eye": eye}
    return img, meta


def default_tails(root):
    pts = [root]
    ang = -1.3
    for _ in range(6):
        ang += 0.15
        pts.append(add(pts[-1], mul(adir(ang), 2.4)))
    return pts
