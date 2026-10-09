"""主角（粉衣剑客）：按姿势画一帧。

姿势参数（像素、弧度；没写的用 DEF 里的默认值）：
  hip        胯部位置（脚底中心为原点）
  lean       上身前倾（正数往前）
  rot        整个人绕身体中心转（空翻、倒地）
  head       头的表情：n 平常 / f 凶 / h 疼 / c 闭眼
  head_off   头相对脖子挪几像素
  ff fb      前脚、后脚落点；ffa fba 脚尖往下压的角度
  hf hb      前手、后手的位置（给了就用 IK 算手肘）；不给就按 af ab（大臂、小臂角度）
  ebf ebb    手肘往哪边弯：-1 往后下（自然垂）、+1 往前上（举刀）
  sw         剑的角度；None 表示剑在鞘里
  grip2      双手握剑：后手自动握到剑柄上
  sw_back    剑画在身体后面（往后抡的时候）
  robe       衣摆往后飘多少像素；lift 衣摆往上掀
  sleeve     袖子往后飘
"""
import math
from rig import (RAMPS, OUTLINE, EXTRA, HEAD_W, HEAD_H, HEAD_NECK, HEAD_BUN, HEAD_COLORS, _head_grid,
                 v, add, sub, mul, lerp, norm, length, adir, rot, ik,
                 Canvas, Part, Frame, poly_mask, capsule_mask, line_px, shade)

W, H = 112, 88
OX, OY = 48, 80

DEF = dict(hip=(0.0, -18.0), lean=0.06, rot=0.0, head="n", head_off=(0.0, 0.0),
           ff=(4.0, 0.0), fb=(-4.0, 0.0), ffa=0.0, fba=0.0,
           hf=None, hb=None, af=(0.25, 0.5), ab=(-0.15, 0.1), ebf=-1, ebb=-1,
           sw=None, grip2=False, sw_back=False, swlen=20.0,
           robe=0.0, lift=0.0, sleeve=0.0)

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
    """远处那一侧（后腿、后手）整体暗一阶"""
    return [ramp[0], ramp[1], ramp[1], ramp[2]]


def skeleton(p):
    """算出所有关节的位置（已经套上整体旋转）"""
    hip = v(*p["hip"])
    lean = p["lean"]
    up = (math.sin(lean), -math.cos(lean))
    fwd = (math.cos(lean), math.sin(lean))
    j = {"hip": hip, "up": up, "fwd": fwd, "_rot": p["rot"]}
    j["neck"] = add(hip, mul(up, TORSO))
    j["sh_f"] = add(add(hip, mul(up, 8.5)), mul(fwd, 1.0))
    j["sh_b"] = add(add(hip, mul(up, 8.5)), mul(fwd, -1.5))
    j["hip_f"] = add(hip, mul(fwd, 1.0))
    j["hip_b"] = add(hip, mul(fwd, -1.5))
    for side, foot, ang in (("f", p["ff"], p["ffa"]), ("b", p["fb"], p["fba"])):
        # 脚尖压下去时绕脚尖转：脚跟抬起来，脚尖还在原来的高度
        ankle = add(v(*foot), (-4.0 * (1.0 - math.cos(ang)), -2.0 - 4.0 * math.sin(max(0.0, ang))))
        j["ankle_" + side] = ankle
        j["knee_" + side] = ik(j["hip_" + side], ankle, THIGH, SHIN, +1)
        j["fa_" + side] = ang
    # 手：剑在手里时前手握剑，双手握时后手握到剑柄上
    for side in ("f", "b"):
        sh = j["sh_" + side]
        target = p["h" + side]
        if side == "b" and p["grip2"] and p["sw"] is not None and p["hf"] is not None:
            target = add(v(*p["hf"]), mul(adir(p["sw"]), -2.5))
        if target is not None:
            wrist = v(*target)
            elbow = ik(sh, wrist, UPPER, FORE, p["eb" + side])
        else:
            a0, a1 = p["a" + side]
            elbow = add(sh, mul(adir(a0), UPPER))
            wrist = add(elbow, mul(adir(a1), FORE))
        j["elbow_" + side] = elbow
        j["wrist_" + side] = wrist
    j["head"] = add(j["neck"], v(*p["head_off"]))
    j["bun"] = add(j["head"], (HEAD_BUN[0] - HEAD_NECK[0], HEAD_BUN[1] - HEAD_NECK[1]))
    # 剑
    if p["sw"] is not None:
        d = adir(p["sw"])
        j["sw_d"] = d
        j["tip"] = add(j["wrist_f"], mul(d, 3.0 + p["swlen"]))
    # 剑鞘
    j["mouth"] = add(add(hip, mul(up, 0.8)), mul(fwd, 2.6))
    # 剑鞘挂在腰带上，大体朝后下方垂着，身子前倾时只跟着转一半
    j["sheath_d"] = norm(rot((-0.62, 0.78), lean * 0.3))      # 挂在胯侧，往后下方垂
    # 整体旋转：绕身体中心
    if abs(p["rot"]) > 1e-4:
        c = add(hip, mul(up, 4.0))
        j["rot_c"] = c
        for k, val in list(j.items()):
            if k in ("up", "fwd", "sw_d", "sheath_d"):
                j[k] = rot(val, p["rot"])
            elif isinstance(val, tuple) and k not in ("rot_c",) and not k.startswith("fa_"):
                j[k] = rot(val, p["rot"], c)
    return j


def _tatters(a, b, n, depth, seed=0):
    pat = [0.0, 0.9, 0.2, 1.0, 0.4, 0.75, 0.1, 0.95]
    out = []
    for i in range(1, n):
        t = i / n
        q = lerp(a, b, t)
        out.append((q[0], q[1] + depth * pat[(i + seed) % len(pat)]))
    return out


def draw(p, hair=None, smear=None, flip=False):
    """画一帧，返回 (图, 元数据)。hair 是马尾各节的位置（不给就按默认垂着）；
    smear 是这一帧的刀光（见 smear.py）；flip 为 True 时整帧左右翻过来（旋风斩转身用）"""
    cv = Canvas(W, H, OX, OY)
    j = skeleton(p)
    fr = Frame(cv)
    up, fwd, hip = j["up"], j["fwd"], j["hip"]
    pink, white = RAMPS["pink"], RAMPS["white"]

    # 1 马尾
    if hair is None:
        hair = default_hair(j["bun"])
    hp = Part(line=RAMPS["hair"][0])
    m = set()
    radii = [1.8, 1.7, 1.6, 1.4, 1.2, 1.0, 0.8, 0.6, 0.5]
    for i in range(len(hair) - 1):
        m |= capsule_mask(cv, hair[i], hair[i + 1], radii[i], radii[i + 1])
    hp.px.update(shade(m, RAMPS["hair"]))
    fr.add(hp)

    # 2 后手（袖子）
    back_arm, back_hand = _arm(cv, p, j, "b")
    fr.add(back_arm)
    if not p["grip2"]:
        fr.add(back_hand)

    # 剑在身后
    if p["sw"] is not None and p["sw_back"]:
        for part in _sword(cv, p, j):
            fr.add(part)

    # 3 后腿
    for part in _leg(cv, j, "b"):
        fr.add(part)

    # 剑鞘本身挂在袍子后面，只露出袍摆下面一截
    sheath_parts = _sheath(cv, p, j)
    fr.add(sheath_parts[0])

    # 4 长袍后片
    rp = Part(line=pink[0])
    kb, kf = j["knee_b"], j["knee_f"]
    hem_y = hip[1] + 11.0 - p["lift"]
    top_b = add(add(hip, mul(up, 1.5)), mul(fwd, -4.5))
    top_f = add(add(hip, mul(up, 1.5)), mul(fwd, 1.5))
    back_x = min(hip[0] - 6.0, kb[0] - 2.0) - p["robe"]
    front_x = hip[0] - 0.5 + max(0.0, kf[0] - hip[0]) * 0.2
    mid_b = (hip[0] - 5.5 - p["robe"] * 0.55, hip[1] + 5.0 - p["lift"] * 0.4)
    hem_b = (back_x - p["robe"] * 0.3, hem_y - p["robe"] * 0.35)
    hem_f = (front_x, hem_y - 1.0)
    pts = [top_f, top_b, mid_b, hem_b] + _tatters(hem_b, hem_f, 6, 2.6) + [hem_f]
    m = poly_mask(cv, [_rr(j, p, q) for q in pts])
    rp.px.update(shade(m, pink, dark2=True))
    for t, dy in ((0.25, -2.5), (0.6, -3.5)):
        c = cv.to_px(_rr(j, p, add(lerp(hem_b, hem_f, t), (0.0, dy))))
        if c in rp.px:
            rp.px[c] = white[3]
            for d in ((1, 0), (-1, 0), (0, -1), (0, 1)):
                q = (c[0] + d[0], c[1] + d[1])
                if q in rp.px:
                    rp.px[q] = pink[3]
    fr.add(rp)

    # 5 前腿
    for part in _leg(cv, j, "f"):
        fr.add(part)

    # 6 上身、腰封
    neck = j["neck"]
    tp = Part(line=pink[0])
    torso = [add(add(hip, mul(up, 0.5)), mul(fwd, -4.3)), add(add(hip, mul(up, 0.5)), mul(fwd, 3.8)),
             add(add(hip, mul(up, 8.0)), mul(fwd, 4.0)), add(neck, mul(fwd, 2.0)),
             add(neck, mul(fwd, -2.5)), add(add(hip, mul(up, 8.0)), mul(fwd, -4.5))]
    tm = poly_mask(cv, [_rr(j, p, q) for q in torso])
    tp.px.update(shade(tm, pink, dark2=True))
    for q in line_px(cv, _rr(j, p, add(neck, mul(fwd, 1.2))), _rr(j, p, add(add(hip, mul(up, 3.0)), mul(fwd, 3.2)))):
        if q in tp.px:
            tp.px[q] = white[2]
    q = cv.to_px(_rr(j, p, add(add(neck, mul(fwd, 1.6)), mul(up, -0.6))))
    if q in tp.px:
        tp.px[q] = RAMPS["skin"][1]
    fr.add(tp)
    sp = Part()
    band = [add(add(hip, mul(up, 1.0)), mul(fwd, -4.6)), add(add(hip, mul(up, 1.0)), mul(fwd, 4.1)),
            add(add(hip, mul(up, 3.6)), mul(fwd, 4.1)), add(add(hip, mul(up, 3.6)), mul(fwd, -4.6))]
    sm = poly_mask(cv, [_rr(j, p, q) for q in band]) & set(tm) | poly_mask(cv, [_rr(j, p, q) for q in band])
    sp.px.update(shade(sm, RAMPS["sash"], front=(9, 9)))
    fr.add(sp)

    # 7 腰间坠子（前襟不画：垂在腿前面，举剑时看起来像多了一只手）
    pd = Part()
    knot = add(add(hip, mul(up, 0.5)), mul(fwd, 2.4))
    k0 = cv.to_px(_rr(j, p, knot))
    for i, c in enumerate([RAMPS["flower"][2], EXTRA["J"], RAMPS["flower"][1]]):
        pd.put((k0[0], k0[1] + i), c)
    fr.add(pd)

    # 8 剑在鞘里时，剑柄从腰前露出来
    for part in sheath_parts[1:]:
        fr.add(part)

    # 9 头
    fr.add(_head(cv, p, j))

    # 10 双手握剑时后手的拳头
    if p["grip2"]:
        fr.add(back_hand)

    # 11 剑
    if p["sw"] is not None and not p["sw_back"]:
        for part in _sword(cv, p, j):
            fr.add(part)

    # 12 前手
    front_arm, front_hand = _arm(cv, p, j, "f")
    fr.add(front_arm)
    fr.add(front_hand)

    if smear is not None:
        import smear as sm
        sp = sm.render(cv, smear, p)
        # 刀光压在身子后面：先放刀光，再把身子的像素盖回来
        body = dict(fr.px)
        fr.px = {}
        fr.add(sp, glow=True)
        for q, val in body.items():
            fr.px[q] = val
            fr.glow.discard(q)
    img = fr.finish()
    tip = j.get("tip")
    if flip:
        from PIL import Image as _I
        img = img.transpose(_I.FLIP_LEFT_RIGHT)
        # 以脚底中心为轴翻
        shift = 2 * OX - W
        out = _I.new("RGBA", img.size, (0, 0, 0, 0))
        out.alpha_composite(img, (shift, 0)) if shift >= 0 else out.alpha_composite(img.crop((-shift, 0, W, H)), (0, 0))
        img = out
        tip = (-tip[0], tip[1]) if tip else None
    hb = j["wrist_b"]
    if flip:
        hb = (-hb[0], hb[1])
    meta = {"tip": tip, "hand": j["wrist_f"], "hand_b": hb, "bun": j["bun"]}
    return img, meta


def _rr(j, p, q):
    """draw() 里现算的点都是用转过的关节和方向向量算的，已经在旋转后的坐标里，原样返回"""
    return q


def _leg(cv, j, side):
    near = side == "f"
    hipj, knee, ankle = j["hip_" + side], j["knee_" + side], j["ankle_" + side]
    wr = RAMPS["white"] if near else _darker(RAMPS["white"])
    br = RAMPS["boot"] if near else _darker(RAMPS["boot"])
    boot_top = lerp(knee, ankle, 0.38)
    pants = Part(line=RAMPS["white"][0])
    m = capsule_mask(cv, hipj, knee, 2.4, 2.1) | capsule_mask(cv, knee, boot_top, 2.1, 2.0)
    boot = Part(line=RAMPS["boot"][0])
    up = j["up"]
    fa = j["fa_" + side]
    sole = [(-2.0, -0.6), (1.0, -0.6), (4.0, 1.0), (4.2, 2.0), (-2.2, 2.0)]
    foot = [add(ankle, rot(rot(q, fa), j["_rot"])) for q in sole]   # 脚也跟着整个人转
    bm = capsule_mask(cv, boot_top, ankle, 2.0, 1.9) | poly_mask(cv, foot)
    m -= bm
    pants.px.update(shade(m, wr))
    boot.px.update(shade(bm, br))
    # 靴口绑带
    for q in line_px(cv, add(boot_top, (-2.2, 0.0)), add(boot_top, (2.2, 0.0))):
        if q in boot.px:
            boot.px[q] = RAMPS["sash"][2] if near else RAMPS["sash"][1]
    return [pants, boot]


def _arm(cv, p, j, side):
    near = side == "f"
    sh, el, wr = j["sh_" + side], j["elbow_" + side], j["wrist_" + side]
    ramp = RAMPS["pink"] if near else _darker(RAMPS["pink"])
    arm = Part(line=RAMPS["pink"][0])
    cuff = lerp(el, wr, 0.72)
    m = capsule_mask(cv, sh, el, 2.3, 2.0) | capsule_mask(cv, el, cuff, 2.0, 2.2)
    # 袖口垂下来的一小片（重力朝下，跑起来往后飘）
    fl = p["sleeve"]
    drape = [add(el, (0.0, 1.6)), add(cuff, (0.0, 1.9)), add(cuff, (-0.8 - fl, 3.6))] + \
        _tatters(add(cuff, (-0.8 - fl, 3.6)), add(el, (-1.2 - fl * 0.8, 3.0)), 3, 1.3, seed=1 if near else 5) + \
        [add(el, (-1.2 - fl * 0.8, 3.0))]
    m |= poly_mask(cv, drape)
    arm.px.update(shade(m, ramp))
    d = norm(sub(wr, el))
    perp = (-d[1], d[0])
    for q in line_px(cv, add(cuff, mul(perp, 2.2)), add(cuff, mul(perp, -2.2))):
        if q in arm.px:
            arm.px[q] = RAMPS["white"][2] if near else RAMPS["white"][1]
    hand = Part(line=RAMPS["skin"][0])
    hm = capsule_mask(cv, lerp(cuff, wr, 0.5), wr, 1.0, 1.35)
    hand.px.update(shade(hm, RAMPS["skin"] if near else _darker(RAMPS["skin"])))
    return arm, hand


def _sword(cv, p, j):
    wr = j["wrist_f"]
    d = j["sw_d"]
    perp = (-d[1], d[0])
    if perp[1] > 0:
        perp = (-perp[0], -perp[1])        # perp 指向上方（受光的一侧）
    L = p["swlen"]
    parts = []
    # 剑身
    blade = Part(line=RAMPS["blade"][0])
    b0 = add(wr, mul(d, 3.0))
    b1 = add(wr, mul(d, 3.0 + L))
    m = capsule_mask(cv, b0, add(b1, mul(d, -2.5)), 0.95) | capsule_mask(cv, add(b1, mul(d, -2.5)), b1, 0.9, 0.35)
    for q in m:
        c = cv.center(*q)
        side = (c[0] - b0[0]) * perp[0] + (c[1] - b0[1]) * perp[1]
        blade.put(q, RAMPS["blade"][3] if side > 0.15 else RAMPS["blade"][2])
    # 只有一像素宽的地方用基础色
    for q in list(blade.px):
        if (q[0], q[1] + 1) not in blade.px and (q[0], q[1] - 1) not in blade.px and \
                (q[0] + 1, q[1]) not in blade.px and (q[0] - 1, q[1]) not in blade.px:
            blade.px[q] = RAMPS["blade"][2]
    parts.append(blade)
    # 剑柄、护手、柄尾、剑穗
    hilt = Part(line=RAMPS["hilt"][0])
    hilt.px.update(shade(capsule_mask(cv, add(wr, mul(d, -3.0)), add(wr, mul(d, 1.6)), 0.9), RAMPS["hilt"]))
    pm = cv.to_px(add(wr, mul(d, -3.8)))
    hilt.put(pm, RAMPS["silver"][2])
    parts.append(hilt)
    guard = Part()
    gc = add(wr, mul(d, 2.2))
    for q in line_px(cv, add(gc, mul(perp, 1.7)), add(gc, mul(perp, -1.7))):
        guard.put(q, RAMPS["silver"][3] if q == cv.to_px(add(gc, mul(perp, 1.7))) else RAMPS["silver"][2])
    parts.append(guard)
    tassel = Part()
    for i, c in enumerate([RAMPS["flower"][2], RAMPS["flower"][2], RAMPS["flower"][1]]):
        tassel.put((pm[0] - (1 if i == 2 else 0), pm[1] + 1 + i), c)
    parts.append(tassel)
    return parts


def _sheath(cv, p, j):
    mouth, bd = j["mouth"], j["sheath_d"]
    end = add(mouth, mul(bd, 17.0))
    parts = []
    sh = Part(line=RAMPS["sheath"][0])
    sh.px.update(shade(capsule_mask(cv, mouth, end, 1.1), RAMPS["sheath"]))
    for q in capsule_mask(cv, add(end, mul(bd, -1.6)), end, 1.1):
        sh.px[q] = RAMPS["silver"][2]
    for q in line_px(cv, add(mouth, mul(bd, 1.2)), add(mouth, mul(bd, 1.2))):
        sh.px[q] = RAMPS["silver"][2]
    parts.append(sh)
    if p["sw"] is None:
        hd = norm(rot((0.9, -0.45), p["lean"] * 0.3 + p["rot"]))      # 剑柄朝前上方
        perp = (-hd[1], hd[0])
        hilt = Part(line=RAMPS["hilt"][0])
        hilt.px.update(shade(capsule_mask(cv, add(mouth, mul(hd, 1.5)), add(mouth, mul(hd, 6.0)), 0.9), RAMPS["hilt"]))
        pm = cv.to_px(add(mouth, mul(hd, 6.8)))
        hilt.put(pm, RAMPS["silver"][2])
        parts.append(hilt)
        guard = Part()
        for q in line_px(cv, add(add(mouth, mul(hd, 0.8)), mul(perp, 1.6)), add(add(mouth, mul(hd, 0.8)), mul(perp, -1.6))):
            guard.put(q, RAMPS["silver"][2])
        parts.append(guard)
        tassel = Part()
        for i, c in enumerate([RAMPS["flower"][2], RAMPS["flower"][2], RAMPS["flower"][1]]):
            tassel.put((pm[0] + (1 if i == 2 else 0), pm[1] + 1 + i), c)
        parts.append(tassel)
    return parts


def _head(cv, p, j):
    g = _head_grid(p["head"])
    part = Part(line=RAMPS["hair"][0])
    origin = sub(j["head"], HEAD_NECK)     # 网格 (0,0) 在画布上的位置（没转之前）
    ang = p["rot"] + (p["lean"] - 0.06) * 0.0
    if abs(ang) < 1e-4:
        ox, oy = cv.to_px(add(origin, (0.0, 0.0)))
        # 对齐：网格左上角像素
        for gy in range(HEAD_H):
            for gx in range(HEAD_W):
                c = g[gy][gx]
                if c != ".":
                    part.put((ox + gx, oy + gy), HEAD_COLORS[c])
        return part
    # 转过的头：反向采样（最近邻），像素不会散开
    c0 = j["head"]
    for py in range(max(0, int(c0[1] + cv.oy) - 20), min(cv.h, int(c0[1] + cv.oy) + 6)):
        for px in range(max(0, int(c0[0] + cv.ox) - 16), min(cv.w, int(c0[0] + cv.ox) + 16)):
            q = cv.center(px, py)
            u = rot(q, -ang, c0)
            gx = int(math.floor(u[0] - origin[0]))
            gy = int(math.floor(u[1] - origin[1]))
            if 0 <= gx < HEAD_W and 0 <= gy < HEAD_H and g[gy][gx] != ".":
                part.put((px, py), HEAD_COLORS[g[gy][gx]])
    return part


# ---------------- 马尾 ----------------

SEG = 2.6
NSEG = 8


def default_hair(root, wind=(0.0, 0.0)):
    pts = [root]
    ang = -1.0
    for i in range(NSEG):
        ang += 0.12
        d = adir(ang)
        d = norm(add(d, mul(wind, 0.15)))
        pts.append(add(pts[-1], mul(d, SEG)))
    return pts


def simulate_hair(roots, durations, wind, loop, world_dx=None):
    """马尾：一串节点，根跟着发髻走，每节受重力和风（往后吹），有惯性。
    roots：每帧发髻的位置；durations：每帧多长（秒）；wind：每帧的风（像素/秒²量级的方向）；
    world_dx：每帧角色在世界里挪了多少（跑起来马尾往后甩）。循环动画先空跑两遍让它稳定。"""
    n = len(roots)
    world_dx = world_dx or [0.0] * n
    pts = default_hair(roots[0])
    prev = [q for q in pts]
    out = [None] * n
    offset = 0.0
    passes = 3 if loop else 1
    for ps in range(passes):
        for i in range(n):
            steps = max(1, int(durations[i] / 0.008))
            r0 = add(roots[i - 1] if i > 0 else roots[i if not loop else n - 1], (offset, 0.0))
            offset_next = offset + world_dx[i]
            r1 = add(roots[i], (offset_next, 0.0))
            for s in range(steps):
                t = (s + 1) / steps
                root = lerp(r0, r1, t)
                dt = durations[i] / steps
                g = (wind[i][0], 520.0 + wind[i][1])
                newp = [root]
                for k in range(1, len(pts)):
                    q, pq = pts[k], prev[k]
                    vel = sub(q, pq)
                    nq = add(add(q, mul(vel, 0.9)), mul(g, dt * dt))
                    newp.append(nq)
                prev = pts
                pts = newp
                for _ in range(3):
                    for k in range(1, len(pts)):
                        dvec = sub(pts[k], pts[k - 1])
                        dl = length(dvec) or 1.0
                        pts[k] = add(pts[k - 1], mul(dvec, SEG / dl))
                    # 第一节不能翘到头顶前面去：往后上方贴着头
                    first = sub(pts[1], pts[0])
                    if first[0] > -0.6:
                        pts[1] = add(pts[0], mul(norm((min(first[0], -0.6), first[1])), SEG))
            offset = offset_next
            if ps == passes - 1:
                out[i] = [sub(q, (offset, 0.0)) for q in pts]
    return out
