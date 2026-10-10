"""野狗（四条腿）：单独一套画法。

参数（像素，朝右，脚底中心为原点）：
  crouch   身子压低多少；stretch 身子拉长（扑出去）；dip 头往下低；jaw 张嘴 0..1
  legs     四条腿的脚落点，相对各自的胯/肩：{"fn": 前近, "ff": 前远, "rn": 后近, "rf": 后远}
  tail     尾巴角度（0 平着往后，正数往上翘）；rot 整只狗转（扑起来抬头、倒地）
"""
import math
from rig import (OUTLINE, add, sub, mul, lerp, norm, rot, Canvas, Part, Frame, poly_mask, capsule_mask, shade)

W, H = 96, 64
OX, OY = 40, 58
FUR = ["231a14", "40342c", "6b5848", "927a62"]
FUR_FAR = ["231a14", "2e241e", "40342c", "6b5848"]
NOSE = "1a1414"
EYE = "ff4a1a"
TEETH = "f2ece0"

DEF = dict(crouch=0.0, stretch=0.0, dip=0.0, jaw=0.0, rot=0.0, tail=0.3,
           legs={"fn": (0.0, 0.0), "ff": (0.0, 0.0), "rn": (0.0, 0.0), "rf": (0.0, 0.0)}, lift=0.0)


def pose(**kw):
    p = dict(DEF)
    p["legs"] = dict(DEF["legs"])
    legs = kw.pop("legs", None)
    p.update(kw)
    if legs:
        p["legs"].update(legs)
    return p


def lerp_pose(a, b, t):
    out = {}
    for k in DEF:
        if k == "legs":
            out[k] = {n: lerp(a[k][n], b[k][n], t) for n in a[k]}
        else:
            out[k] = a[k] + (b[k] - a[k]) * t
    return out


def draw(p, smear=None):
    cv = Canvas(W, H, OX, OY)
    fr = Frame(cv)
    y0 = -13.0 + p["crouch"] - p["lift"]
    st = p["stretch"]
    c = (0.0, y0)
    R = lambda q: rot(q, p["rot"], c)
    # 胯（后）和肩（前）的位置
    hip_n, hip_f = (-9.0 - st * 0.4, y0), (-7.5 - st * 0.4, y0 - 0.5)
    sh_n, sh_f = (8.5 + st * 0.6, y0), (10.0 + st * 0.6, y0 - 0.5)
    L = p["legs"]

    def leg(top, foot_off, rear, far):
        ramp = FUR_FAR if far else FUR
        foot = add((top[0], 0.0 - p["lift"]), foot_off)
        part = Part(line=FUR[0])
        if rear:
            # 后腿：大腿往前下、小腿往后下（狗的后腿是折的）
            knee = lerp(top, foot, 0.4)
            knee = (knee[0] + 2.5, knee[1])
            hock = lerp(top, foot, 0.72)
            hock = (hock[0] - 1.5, hock[1])
            m = capsule_mask(cv, R(top), R(knee), 2.6, 1.8) | capsule_mask(cv, R(knee), R(hock), 1.6, 1.3) | \
                capsule_mask(cv, R(hock), R(foot), 1.2, 1.2)
        else:
            elbow = lerp(top, foot, 0.45)
            elbow = (elbow[0] - 1.0, elbow[1])
            m = capsule_mask(cv, R(top), R(elbow), 2.2, 1.5) | capsule_mask(cv, R(elbow), R(foot), 1.4, 1.2)
        m |= capsule_mask(cv, R(add(foot, (-0.5, -0.5))), R(add(foot, (1.5, -0.5))), 1.0)
        part.px.update(shade(m, ramp))
        return part

    fr.add(leg(hip_f, L["rf"], True, True))
    fr.add(leg(sh_f, L["ff"], False, True))
    # 尾巴：翘着，随动作摆
    tail = Part(line=FUR[0])
    t0 = (-12.5 - st * 0.4, y0 - 4.0)
    a = p["tail"]
    pts = [t0]
    for k in range(4):
        ang = math.pi + a + k * 0.25
        pts.append(add(pts[-1], (math.cos(ang) * 2.6, -math.sin(ang) * 2.6 * -1.0 - 0.0)))
    tm = set()
    for k in range(len(pts) - 1):
        tm |= capsule_mask(cv, R(pts[k]), R(pts[k + 1]), 1.6 - k * 0.3, 1.3 - k * 0.3)
    tail.px.update(shade(tm, FUR))
    fr.add(tail)
    # 身子：胸口高、腰收细、屁股略低；肚子一层暗色，背上一道乱毛
    body = Part(line=FUR[0])
    bp = [(-13.0 - st * 0.4, y0 - 4.5), (-8.0, y0 - 7.0), (2.0, y0 - 7.0), (9.0 + st * 0.6, y0 - 8.5),
          (13.0 + st * 0.6, y0 - 4.0), (11.0 + st * 0.6, y0 + 1.5), (3.0, y0 + 0.5), (-4.0, y0 - 0.5),
          (-12.0 - st * 0.4, y0 + 1.0)]
    bm = poly_mask(cv, [R(q) for q in bp])
    body.px.update(shade(bm, FUR, dark2=True))
    for x in range(-10, 9, 3):
        q = cv.to_px(R((x + st * 0.1, y0 - 7.5 - (1 if x % 2 else 0))))
        if q in body.px or (q[0], q[1] + 1) in body.px:
            body.px[q] = FUR[1]
            body.px[(q[0], q[1] - 1)] = FUR[1]
    fr.add(body)
    fr.add(leg(hip_n, L["rn"], True, False))
    fr.add(leg(sh_n, L["fn"], False, False))
    # 头
    hx, hy = 14.5 + st, y0 - 8.0 + p["dip"]
    head = Part(line=FUR[0])
    hm = capsule_mask(cv, R((hx - 1.0, hy)), R((hx + 1.0, hy)), 3.8)
    # 上嘴筒
    j = p["jaw"]
    snout = [(hx + 1.5, hy - 2.5), (hx + 8.5, hy - 0.5), (hx + 8.5, hy + 1.2), (hx + 1.5, hy + 1.5)]
    hm |= poly_mask(cv, [R(q) for q in snout])
    # 耳朵：往后竖着
    ear = [(hx - 3.0, hy - 2.0), (hx - 1.5, hy - 8.0), (hx + 0.5, hy - 2.5)]
    hm |= poly_mask(cv, [R(q) for q in ear])
    head.px.update(shade(hm, FUR))
    nose = cv.to_px(R((hx + 8.2, hy - 0.3)))
    head.px[nose] = NOSE
    head.px[(nose[0], nose[1] + 1)] = NOSE
    eye = cv.to_px(R((hx + 1.5, hy - 1.5)))
    head.px[eye] = EYE
    head.px[(eye[0] + 1, eye[1])] = EYE
    fr.add(head)
    # 下巴：张嘴时往下开，露出一排牙
    jawp = Part(line=FUR[0])
    jp = [(hx + 1.0, hy + 2.0), (hx + 7.5, hy + 2.0 + j * 4.0), (hx + 6.5, hy + 3.5 + j * 4.0), (hx + 0.5, hy + 3.8)]
    jawp.px.update(shade(poly_mask(cv, [R(q) for q in jp]), FUR_FAR))
    if j > 0.3:
        for k in range(3):
            q = cv.to_px(R((hx + 3.0 + k * 1.8, hy + 1.6)))
            jawp.px[q] = TEETH
            q2 = cv.to_px(R((hx + 3.0 + k * 1.8, hy + 2.2 + j * 3.0)))
            jawp.px[q2] = TEETH
    fr.add(jawp)
    if smear is not None:
        import smear as sm
        sp = sm.render(cv, smear, None)
        bodypx = dict(fr.px)
        fr.px = {}
        fr.add(sp, glow=True)
        for q, val in bodypx.items():
            fr.px[q] = val
            fr.glow.discard(q)
    img = fr.finish()
    meta = {"tip": R((hx + 9.0, hy + 1.0)), "hand_b": (0.0, y0), "eye": R((hx + 1.5, hy - 1.5))}
    return img, meta


# ---------------- 动作 ----------------

STAND = pose(legs={"fn": (1.0, 0.0), "ff": (-0.5, 0.0), "rn": (-0.5, 0.0), "rf": (1.0, 0.0)})


def _gallop(n=6, amp=6.0, lift=3.5):
    out = []
    for i in range(n):
        ph = i / n * math.tau

        def foot(off):
            s, c = math.sin(ph + off), math.cos(ph + off)
            return (amp * s, -max(0.0, lift * c))
        out.append(pose(legs={"fn": foot(0.0), "ff": foot(0.5), "rn": foot(math.pi * 0.9), "rf": foot(math.pi * 1.3)},
                        stretch=1.5 * math.sin(ph), crouch=1.0 * abs(math.cos(ph)), lift=1.0 * max(0.0, math.sin(ph + 1.0)),
                        tail=0.5 + 0.2 * math.sin(ph * 2), dip=0.5 * math.sin(ph)))
    return out


def build():
    A = {}
    B = lerp_pose
    A["idle_far"] = {"loop": True, "frames": [(pose(**dict(STAND, crouch=0.6 * (1 - math.cos(i / 6 * math.tau)) / 2,
                                                             tail=0.5 + 0.35 * math.sin(i / 6 * math.tau * 2))), 140) for i in range(6)]}
    A["idle_near"] = {"loop": True, "frames": [(pose(**dict(STAND, crouch=2.5 + 0.5 * math.sin(i / 4 * math.tau), dip=1.5, jaw=0.25,
                                                              tail=-0.1)), 110) for i in range(4)]}
    run = _gallop()
    A["walk_far"] = {"loop": True, "frames": [(p, 70) for p in run]}
    A["walk_near"] = {"loop": True, "frames": [(p, 70) for p in run]}
    growl = pose(**dict(STAND, crouch=4.0, dip=2.0, jaw=0.4, tail=-0.3,
                        legs={"fn": (2.0, 0.0), "ff": (0.5, 0.0), "rn": (-2.0, 0.0), "rf": (-0.5, 0.0)}))
    lunge = pose(stretch=5.0, crouch=1.0, jaw=1.0, dip=0.5, tail=0.0,
                 legs={"fn": (7.0, -2.0), "ff": (6.0, -1.0), "rn": (-7.0, 0.0), "rf": (-6.0, 0.0)})
    bite = pose(**dict(lunge, jaw=0.15, stretch=3.0))
    rec = pose(**dict(STAND, crouch=1.5, jaw=0.3))
    bs = {"smear": {"type": "flat", "c": (20.0, -16.0), "rx": 8.0, "ry": 5.0, "a0": -1.4, "a1": 1.4, "th": 3.0, "colors": "warm"}}
    A["bite"] = {"phases": [2, 2, 2], "frames": [(B(STAND, growl, 0.5), 30), (growl, 70), (lunge, 50, bs), (bite, 50),
                                                 (rec, 50), (B(rec, STAND, 0.5), 50)]}
    leap = pose(stretch=6.0, crouch=-1.0, jaw=1.0, dip=-1.5, tail=0.4, rot=-0.15,
                legs={"fn": (6.0, -6.0), "ff": (5.0, -5.0), "rn": (-7.0, -2.0), "rf": (-6.0, -1.0)})
    A["pounce"] = {"phases": [2, 2, 2], "frames": [(B(STAND, growl, 0.5), 30), (pose(**dict(growl, crouch=5.5)), 70),
                                                   (leap, 50, bs), (pose(**dict(leap, rot=0.1, jaw=0.6)), 50),
                                                   (rec, 50), (B(rec, STAND, 0.5), 50)]}
    hit = pose(**dict(STAND, crouch=1.0, dip=-2.0, jaw=0.6, tail=-0.4, stretch=-1.5))
    A["hit"] = {"frames": [(hit, 90), (B(hit, STAND, 0.5), 100)]}
    A["guard"] = A["idle_near"]
    A["broken"] = {"loop": True, "frames": [(hit, 200), (pose(**dict(hit, crouch=2.0)), 200)]}
    down = pose(crouch=9.0, dip=4.0, jaw=0.3, tail=-0.6, rot=0.12,
                legs={"fn": (8.0, -9.0), "ff": (7.0, -9.0), "rn": (-8.0, -9.0), "rf": (-7.0, -9.0)})
    A["death"] = {"frames": [(hit, 80), (B(hit, down, 0.5), 120), (down, 1700)]}
    return A
