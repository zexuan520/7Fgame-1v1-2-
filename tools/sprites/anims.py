"""主角的动作表：每个动作是一串 (姿势, 毫秒[, 选项])。

气质：挺胸抬头，单手持剑（直剑），另一只手往后展开配重或捏剑指；只有重劈和落雷斩双手握剑。
出刀前有蓄势（身子拧过去、剑收到身后），出刀一瞬间整个人展开，收招有余势。

字段：
  frames   [(姿势, 毫秒) 或 (姿势, 毫秒, {"smear": 刀光, "flip": 左右翻}), ...]
  loop     循环（待机、走、跑、下落）
  phases   攻击动作：[前摇帧数, 判定帧数, 后摇帧数]，游戏里按招式的时间对齐
  speed    角色在世界里往前跑的速度（像素/秒，马尾往后甩用）
  wind     每帧给马尾的额外的力：往后吹是负 x，往上掀是负 y
"""
import math
from heroine import pose as P, lerp_pose

# ---------------- 基础姿势 ----------------

# 收剑站姿：挺胸，前手自然垂在身侧，后手背在身后
STAND = dict(hip=(0.0, -18.5), lean=-0.04, ff=(3.5, 0.0), fb=(-3.5, 0.0), hf=(3.5, -14.0), hb=(-5.0, -18.0))
# 正眼（架势 A）：弓步，剑平伸到胸前，后手往后展开
READY = dict(hip=(-1.0, -15.5), lean=0.04, ff=(9.0, 0.0), fb=(-7.5, 0.0), hf=(11.5, -24.5), sw=1.72,
             hb=(-12.0, -27.0), ebb=1, head="f")
# 架势 B：剑尖斜指前上方（八相）
READY_B = dict(hip=(-1.0, -15.5), lean=0.0, ff=(9.0, 0.0), fb=(-7.5, 0.0), hf=(11.0, -23.0), sw=1.95,
               hb=(-11.0, -31.0), ebb=1, head="f")
# 拔着剑但放松：剑垂在身侧斜指前下方，后手背在身后
RELAXED = dict(STAND, hf=(5.0, -15.5), sw=1.05)


def _breath(base, n, drop, sway=0.0, extra=None):
    """呼吸：胯和手一起往下沉 drop 像素再回来；衣摆跟着轻轻摆"""
    out = []
    for i in range(n):
        k = (1.0 - math.cos(i / n * math.tau)) / 2.0           # 0 → 1 → 0
        p = dict(base)
        hip = base["hip"]
        p["hip"] = (hip[0], hip[1] + drop * k)
        for hk in ("hf", "hb"):
            if base.get(hk) is not None:
                h = base[hk]
                p[hk] = (h[0], h[1] + drop * k * 0.8)
        p["robe"] = base.get("robe", 0.0) + sway * math.sin(i / n * math.tau)
        p["sleeve"] = sway * 0.5 * math.sin(i / n * math.tau + 0.8)
        if extra:
            extra(p, i, k)
        out.append(P(**p))
    return out


def _walk_cycle(base, hand=None):
    """走路：上身直，步子不大，两腿交替；胯在两腿并拢时最高"""
    out = []
    n = 8
    for i in range(n):
        ph = i / n * math.tau
        c, s = math.cos(ph), math.sin(ph)
        p = dict(base)
        stride, lift = 6.0, 3.0
        p["ff"] = (stride * c + 0.5, -lift * max(0.0, -s))
        p["fb"] = (-stride * c - 0.5, -lift * max(0.0, s))
        p["ffa"] = 0.5 * max(0.0, s) * max(0.0, -c) * 2.0
        p["fba"] = 0.5 * max(0.0, -s) * max(0.0, c) * 2.0
        hy = base["hip"][1] - 1.0 * (1.0 - abs(c))
        p["hip"] = (base["hip"][0], hy)
        dy = hy - base["hip"][1]
        if hand:
            hand(p, ph, dy)
        hb = base["hb"]
        p["hb"] = (hb[0], hb[1] + dy)
        p["robe"] = 1.2 + 0.6 * abs(s)
        p["sleeve"] = 0.6
        out.append(P(**p))
    return out


# 跑步：一步四个关键帧（落地 → 下沉 → 蹬地、另一条腿抬膝前送 → 腾空），后半步换腿。
# 每帧：(胯, 落地那条腿的脚, 另一条腿的脚, 两只脚的脚尖角度, 摆臂 -1..1)
RUN_KEYS = [
    ((3.0, -16.5), (10.0, 0.0), (-8.0, -4.0), (0.0, 0.9), -1.0),    # 落地：前脚伸出去踩地，后腿伸直往后、脚尖点地
    ((3.0, -15.0), (5.0, 0.0), (-9.0, -8.5), (0.0, 0.5), -0.5),     # 下沉：重心压到前脚上，后脚往后上方甩起来
    ((3.0, -16.5), (0.5, 0.0), (3.0, -8.0), (0.5, 0.3), 0.3),       # 蹬地：前脚在身子下面往后蹬，另一条腿抬膝往前送
    ((3.0, -18.5), (-7.0, -3.0), (10.0, -5.0), (1.0, 0.1), 1.0),    # 腾空：蹬完的腿拖在后面，另一条腿往前伸准备落地
]


def _run_cycle(drawn=False):
    out = []
    for half in range(2):
        for k, (hip, plant, swing, toes, arm) in enumerate(RUN_KEYS):
            near_plant = half == 0
            ff, fb = (plant, swing) if near_plant else (swing, plant)
            ffa, fba = (toes[0], toes[1]) if near_plant else (toes[1], toes[0])
            a_near = -arm if near_plant else arm

            def hand(a, near):
                # a=1 往前上方，a=-1 往后：手肘弯着，手在胸前和胯后之间来回
                x = 3.0 + 7.5 * a + (1.0 if near else -1.0)
                y = -19.5 - 1.5 * max(0.0, a) + 1.0 * max(0.0, -a)
                return (x + hip[0] - 3.0, y + (hip[1] + 16.5))
            p = dict(hip=hip, lean=0.5, head="f", head_off=(1.0, 0.5), ff=ff, fb=fb, ffa=ffa, fba=fba,
                     hf=hand(a_near, True), hb=hand(-a_near, False), ebf=-1, ebb=-1,
                     robe=5.0, lift=2.5, sleeve=2.5)
            if drawn:
                # 剑握在近处的手里，剑尖朝后下方拖着
                p.update(sw=-1.25, sw_back=True, hf=(hip[0] + 1.0 + 1.5 * a_near, hip[1] + 1.0))
            out.append(P(**p))
    return out


def _between(a, b, t):
    return lerp_pose(a, b, t)


def K(**kw):
    """从正眼架势改几项"""
    d = dict(READY)
    d.update(kw)
    return P(**d)


# 空中的底子：腿收着，后手往后展开保持平衡
AIR = dict(hip=(0.0, -19.0), lean=0.1, ff=(4.0, -5.0), fb=(-3.0, -4.0), ffa=0.4, fba=0.5, lift=1.5,
           hb=(-11.0, -27.0), ebb=1)


def KA(**kw):
    d = dict(READY)
    d.update(AIR)
    d.update(kw)
    return P(**d)


def S(**kw):
    return {"smear": kw}


def build():
    A = {}
    basics(A)
    attacks(A)
    others(A)
    return A


# ======================================================================
def basics(A):
    B = _between

    # ---------- 待机 ----------
    A["idle"] = {"loop": True, "frames": [(p, 170) for p in _breath(STAND, 6, 1.0, sway=0.6)]}
    A["relaxed"] = {"loop": True, "frames": [(p, 170) for p in _breath(
        RELAXED, 6, 1.0, sway=0.6, extra=lambda p, i, k: p.update(sw=1.05 - 0.05 * k))]}
    A["ready"] = {"loop": True, "frames": [(p, 150) for p in _breath(
        READY, 6, 1.0, sway=0.5, extra=lambda p, i, k: p.update(sw=READY["sw"] + 0.06 * k))]}

    # ---------- 走、跑 ----------
    def swing(p, ph, dy):
        p["hf"] = (3.5 + 2.0 * math.cos(ph), -14.0 + dy - 0.5 * abs(math.sin(ph)))
    walk = dict(STAND, lean=0.03, hip=(0.0, -18.0))
    A["walk"] = {"loop": True, "speed": 120.0, "frames": [(p, 80) for p in _walk_cycle(walk, swing)]}

    def swing_d(p, ph, dy):
        p["hf"] = (5.0 + 1.5 * math.cos(ph), -15.5 + dy)
        p["sw"] = 1.05 + 0.08 * math.cos(ph)
    A["walk_drawn"] = {"loop": True, "speed": 120.0, "frames": [(p, 80) for p in _walk_cycle(dict(walk, sw=1.05), swing_d)]}
    A["run"] = {"loop": True, "speed": 200.0, "frames": [(p, 60) for p in _run_cycle()]}
    A["run_drawn"] = {"loop": True, "speed": 200.0, "frames": [(p, 60) for p in _run_cycle(drawn=True)]}

    # ---------- 跳 ----------
    takeoff = P(**dict(STAND, hip=(0.0, -19.5), lean=0.05, ff=(2.5, -1.0), fb=(-3.5, 0.5), ffa=0.9, fba=1.1,
                       hf=(6.0, -26.0), hb=(-8.0, -26.0), ebb=1, lift=-1.5, sleeve=-0.5))
    rise = P(**dict(STAND, hip=(0.0, -19.0), lean=0.05, ff=(3.5, -4.0), fb=(-2.5, -1.5), ffa=0.6, fba=0.9,
                    hf=(7.0, -25.0), hb=(-9.0, -27.0), ebb=1, lift=-1.0))
    apex = P(**dict(STAND, hip=(0.0, -19.0), lean=0.08, ff=(4.5, -7.0), fb=(-2.0, -5.0), ffa=0.3, fba=0.5,
                    hf=(8.0, -23.0), hb=(-10.0, -25.0), ebb=1, lift=1.0))
    fall1 = P(**dict(STAND, hip=(0.0, -19.0), lean=0.02, ff=(4.0, -2.0), fb=(-3.5, -3.5), ffa=0.4, fba=0.6,
                     hf=(8.0, -25.0), hb=(-9.0, -28.0), ebb=1, lift=3.0, robe=1.0, sleeve=-1.0))
    fall2 = P(**dict(fall1, lift=3.8, robe=1.6, hb=(-9.0, -29.0), hf=(8.0, -26.0)))
    A["jump"] = {"wind": [(0, 300), (0, 250), (0, 150)], "frames": [(takeoff, 60), (rise, 90), (rise, 90)]}
    A["apex"] = {"wind": [(0, 0), (0, -150)], "frames": [(apex, 90), (B(apex, fall1, 0.5), 90)]}
    A["fall"] = {"loop": True, "wind": [(0, -420), (0, -480)], "frames": [(fall1, 100), (fall2, 100)]}
    land1 = P(**dict(STAND, hip=(0.0, -14.0), lean=0.25, ff=(6.0, 0.0), fb=(-5.0, 0.0), hf=(8.0, -18.0),
                     hb=(-9.0, -20.0), ebb=1, lift=-1.0, robe=-0.5))
    land2 = P(**dict(STAND, hip=(0.0, -16.5), lean=0.08, ff=(5.0, 0.0), fb=(-4.5, 0.0), hf=(5.0, -16.0), hb=(-6.0, -18.0)))
    A["land"] = {"wind": [(0, 500), (0, 200), (0, 0)], "frames": [(land1, 60), (land2, 70), (P(**STAND), 80)]}

    # 二段跳：抱膝往前翻一圈
    tuck = dict(STAND, hip=(0.0, -20.0), lean=0.35, ff=(3.0, -13.0), fb=(0.5, -13.5), ffa=0.3, fba=0.3,
                hf=(5.0, -18.0), hb=(3.0, -17.0), head="f", lift=2.0)
    A["flip"] = {"wind": [(0, 0)] * 7,
                 "frames": [(P(**dict(tuck, rot=a)), 45) for a in (0.0, 0.9, 1.8, 2.7, 3.6, 4.5, 5.4)]}


# ======================================================================
def attacks(A):
    R = P(**READY)
    B = _between

    # ---------- 横斩：身子一拧，剑收到身后，整条胳膊展开横扫到身前 ----------
    w = K(hip=(-1.5, -16.0), lean=-0.06, ff=(7.0, 0.0), fb=(-8.0, 0.0), hf=(-3.0, -23.0), sw=-1.65, sw_back=True,
          hb=(6.0, -25.0), ebb=-1)
    a1 = K(hip=(1.0, -15.5), lean=0.15, ff=(11.0, 0.0), fb=(-7.0, 0.0), hf=(13.0, -23.0), sw=1.6, hb=(-12.0, -25.0),
           robe=2.5, sleeve=2.5)
    a2 = K(**dict(a1, hf=(12.0, -24.5), sw=1.95, robe=3.0, sleeve=3.0))
    f1 = K(**dict(a1, hf=(10.0, -26.0), sw=2.25, robe=2.0))
    flat = dict(type="flat", c=(5.0, -22.0), rx=28.0, ry=7.0, a0=math.pi, a1=0.1, th=6.0)
    A["slash1"] = {"phases": [1, 2, 3], "frames": [
        (w, 80), (a1, 45, S(**flat)), (a2, 45, S(**dict(flat, fade=True))), (f1, 90), (B(f1, R, 0.5), 90), (R, 90)]}

    # ---------- 上撩：剑压到身后下方，从下往上撩起，人跟着长起来 ----------
    w = K(hip=(-0.5, -14.5), lean=0.25, ff=(8.0, 0.0), fb=(-7.0, 0.0), hf=(-1.0, -16.0), sw=-1.05, sw_back=True,
          hb=(6.0, -22.0), ebb=-1)
    a1 = K(hip=(1.0, -16.5), lean=0.1, ff=(10.0, 0.0), fb=(-6.0, 0.0), hf=(12.0, -22.0), sw=2.1, hb=(-11.0, -22.0))
    a2 = K(hip=(1.0, -18.5), lean=-0.06, ff=(10.0, 0.0), fb=(-5.0, -1.0), fba=0.4, hf=(8.0, -33.0), sw=2.95,
           hb=(-12.0, -24.0), lift=1.0)
    f1 = K(hip=(0.5, -18.5), lean=-0.08, ff=(9.5, 0.0), fb=(-5.0, 0.0), hf=(6.0, -34.0), sw=3.3, hb=(-11.0, -25.0))
    A["slash2"] = {"phases": [1, 2, 3], "frames": [
        (w, 80), (a1, 45, S(type="sweep", **{"from": w})), (a2, 45, S(type="sweep", fade=True, **{"from": w})),
        (f1, 90), (B(f1, R, 0.5), 90), (R, 90)]}

    # ---------- 竖劈：剑举过头顶、后手往前指，一刀劈到身前 ----------
    w = K(hip=(-1.0, -17.5), lean=-0.1, ff=(7.0, 0.0), fb=(-7.0, 0.0), hf=(1.0, -36.0), sw=3.7, sw_back=True,
          ebf=1, hb=(7.0, -26.0), ebb=-1)
    a1 = K(hip=(1.5, -15.5), lean=0.18, ff=(11.0, 0.0), fb=(-7.0, 0.0), hf=(13.0, -26.0), sw=1.9, hb=(-12.0, -24.0),
           robe=2.0)
    a2 = K(hip=(2.0, -14.5), lean=0.28, ff=(11.0, 0.0), fb=(-7.5, 0.0), hf=(13.0, -18.0), sw=1.05,
           hb=(-12.0, -26.0), robe=2.5)
    f1 = K(**dict(a2, hf=(12.0, -16.0), sw=0.95))
    A["slash3"] = {"phases": [1, 2, 3], "frames": [
        (w, 100), (a1, 40, S(type="sweep", **{"from": w})), (a2, 45, S(type="sweep", fade=True, **{"from": w})),
        (f1, 100), (B(f1, R, 0.5), 100), (R, 90)]}

    # ---------- 突刺：剑收到耳边、后手剑指前方，整个人扎出去 ----------
    w = K(hip=(-2.0, -16.0), lean=-0.05, ff=(6.0, 0.0), fb=(-8.0, 0.0), hf=(-1.0, -25.0), sw=1.62, hb=(8.0, -25.0),
          ebb=-1)
    a1 = K(hip=(3.0, -14.5), lean=0.3, ff=(13.0, 0.0), fb=(-9.0, 0.0), fba=0.4, hf=(18.0, -23.0), sw=1.6,
           hb=(-12.0, -24.0), robe=4.0, sleeve=3.0)
    a2 = K(**dict(a1, hf=(18.5, -23.0), robe=4.5))
    f1 = K(**dict(a1, hip=(2.5, -15.0), lean=0.22, hf=(15.0, -23.5), sw=1.65, robe=3.0))
    st = dict(type="streak", y=-23.5, x0=4.0, x1=54.0, th=3.0)
    A["slash4"] = {"phases": [1, 2, 3], "frames": [
        (w, 90), (a1, 50, S(**st)), (a2, 50, S(**dict(st, fade=True))), (f1, 100), (B(f1, R, 0.5), 100), (R, 90)]}

    # ---------- 旋风斩：剑收到身后，原地转一圈，刀光一整圈 ----------
    w = K(hip=(0.0, -15.0), lean=0.12, ff=(8.0, 0.0), fb=(-8.0, 0.0), hf=(-3.0, -21.0), sw=-1.8, sw_back=True,
          hb=(7.0, -24.0), ebb=-1)
    s1 = K(hip=(1.0, -15.5), lean=0.12, ff=(9.0, 0.0), fb=(-8.0, 0.0), hf=(13.0, -22.0), sw=1.6, hb=(-12.0, -23.0),
           robe=3.0, sleeve=3.0)
    s2 = K(**dict(s1, hf=(5.0, -23.0), swlen=7.0, hb=(-6.0, -23.0)))      # 剑朝着镜头，看上去短了
    ring = dict(type="ring", c=(0.0, -21.0), rx=32.0, ry=8.0, th=6.0, turn=0.85)
    spin = []
    for k, (fp, fl) in enumerate([(s1, False), (s2, False), (s1, True), (s2, True)] * 2):
        spin.append((fp, 38, {"smear": dict(ring, a0=-math.pi / 2 + k * math.pi / 2 - math.tau * 0.85, fade=k >= 6),
                              "flip": fl}))
    f1 = K(**dict(s1, hf=(12.0, -23.0), sw=1.75, robe=1.5))
    A["slash5"] = {"phases": [1, 8, 3], "frames": [(w, 120)] + spin + [(f1, 120), (B(f1, R, 0.5), 120), (R, 120)]}

    # ---------- 重劈：双手举剑过顶，蓄满一刀砸下来（白色刀光） ----------
    ch = K(hip=(-1.0, -16.5), lean=-0.12, ff=(8.0, 0.0), fb=(-8.0, 0.0), hf=(1.0, -37.0), sw=3.9, sw_back=True,
           ebf=1, grip2=True, hb=None)
    A["charge"] = {"loop": True, "frames": [(ch, 60), (K(**dict(ch, hip=(-0.5, -16.5), hf=(1.5, -37.0))), 60)]}
    a1 = K(hip=(3.0, -14.0), lean=0.35, ff=(13.0, 0.0), fb=(-8.0, 0.0), hf=(14.0, -25.0), sw=1.85, grip2=True,
           hb=None, robe=3.0)
    a2 = K(hip=(3.5, -12.5), lean=0.45, ff=(13.0, 0.0), fb=(-8.5, 0.0), hf=(14.0, -14.0), sw=0.95, grip2=True,
           hb=None, robe=3.5)
    f1 = K(**dict(a2, robe=2.0))
    hv = dict(type="sweep", inner=0.3, reach=6.0, white=True)
    hv["from"] = ch
    A["heavy"] = {"phases": [1, 2, 4], "frames": [
        (ch, 120), (a1, 50, S(**hv)), (a2, 50, S(**dict(hv, fade=True))), (f1, 160), (f1, 120),
        (B(f1, R, 0.5), 120), (R, 120)]}

    # ---------- 升龙斩：压低，连人带剑往上冲 ----------
    w = K(hip=(0.0, -13.0), lean=0.35, ff=(8.0, 0.0), fb=(-7.0, 0.0), hf=(0.0, -15.0), sw=-1.1, sw_back=True,
          hb=(6.0, -19.0), ebb=-1)
    a1 = K(hip=(1.0, -19.5), lean=0.0, ff=(4.0, -2.0), fb=(-3.0, 0.0), ffa=0.8, fba=0.9, hf=(10.0, -28.0), sw=2.45,
           hb=(-10.0, -20.0), lift=-1.0)
    a2 = K(hip=(1.0, -20.0), lean=-0.08, ff=(5.0, -8.0), fb=(-2.0, -2.0), ffa=0.3, fba=1.0, hf=(6.0, -38.0), sw=3.1,
           hb=(-10.0, -22.0), lift=-1.5)
    f1 = KA(hf=(6.0, -35.0), sw=3.3)
    A["rising"] = {"phases": [1, 2, 2], "frames": [
        (w, 100), (a1, 60, S(type="sweep", **{"from": w})), (a2, 60, S(type="sweep", fade=True, **{"from": w})),
        (f1, 120), (KA(hf=(9.0, -27.0), sw=2.2), 120)]}

    # ---------- 空中斩、空中回斩 ----------
    w = KA(hf=(1.0, -35.0), sw=3.6, sw_back=True, ebf=1, hb=(6.0, -24.0), ebb=-1)
    a1 = KA(hf=(13.0, -24.0), sw=1.6, lean=0.2)
    a2 = KA(hf=(12.0, -17.0), sw=0.85, lean=0.25)
    A["air1"] = {"phases": [1, 2, 2], "frames": [
        (w, 60), (a1, 40, S(type="sweep", **{"from": w})), (a2, 40, S(type="sweep", fade=True, **{"from": w})),
        (KA(hf=(11.0, -18.0), sw=1.0), 80), (KA(hf=(10.0, -22.0), sw=1.5), 80)]}
    w = KA(hf=(0.0, -16.0), sw=-0.6, sw_back=True, lean=0.2, hb=(6.0, -22.0), ebb=-1)
    a1 = KA(hf=(12.0, -26.0), sw=2.3)
    a2 = KA(hf=(7.0, -34.0), sw=3.1, lean=0.0)
    A["air2"] = {"phases": [1, 2, 2], "frames": [
        (w, 60), (a1, 40, S(type="sweep", **{"from": w})), (a2, 40, S(type="sweep", fade=True, **{"from": w})),
        (KA(hf=(6.0, -33.0), sw=3.3), 100), (KA(hf=(9.0, -26.0), sw=2.4), 100)]}

    # ---------- 落雷斩：双手举剑，剑尖朝下砸下去，落地扎进土里 ----------
    up = KA(hf=(2.0, -37.0), sw=3.9, sw_back=True, ebf=1, grip2=True, hb=None, ff=(4.0, -9.0), fb=(-1.0, -8.0))
    down = KA(hf=(7.0, -18.0), sw=0.1, lean=0.25, grip2=True, hb=None, ff=(2.0, -2.0), fb=(-1.0, -1.0), ffa=0.8,
              fba=0.8, lift=4.0, robe=0.0)
    A["plunge_raise"] = {"frames": [(up, 60), (B(up, down, 0.5), 60)]}
    A["plunge_fall"] = {"loop": True, "wind": [(0, -500), (0, -560)],
                        "frames": [(down, 70), (KA(**dict(down, lift=4.6)), 70)]}
    land = K(hip=(2.0, -11.0), lean=0.45, ff=(9.0, 0.0), fb=(-8.0, 0.0), hf=(9.0, -12.0), sw=0.05, grip2=True,
             hb=None, robe=-1.0)
    A["plunge_land"] = {"frames": [(land, 120), (land, 120), (B(land, R, 0.4), 100), (B(land, R, 0.75), 100), (R, 100)]}

    # ---------- 闪身突刺：压得很低，一道长光扎出去 ----------
    w = K(hip=(0.0, -15.0), lean=0.15, hf=(0.0, -22.0), sw=1.6, hb=(7.0, -23.0), ebb=-1)
    a1 = K(hip=(4.0, -13.0), lean=0.45, ff=(14.0, 0.0), fb=(-12.0, 0.0), fba=0.6, hf=(20.0, -20.0), sw=1.68,
           hb=(-13.0, -21.0), robe=6.0, sleeve=4.0)
    st = dict(type="streak", y=-20.5, x0=-14.0, x1=58.0, th=3.0)
    A["dash"] = {"phases": [1, 2, 3], "frames": [
        (w, 40), (a1, 60, S(**st)), (K(**dict(a1, robe=5.0)), 60, S(**dict(st, fade=True))),
        (B(a1, R, 0.35), 100), (B(a1, R, 0.7), 100), (R, 90)]}


# ======================================================================
def others(A):
    R = P(**READY)
    B = _between

    # ---------- 各种架势（敌人靠近时摆着，呼吸、剑尖小幅晃） ----------
    STANCES = {
        "seigan": READY,
        "hasso": READY_B,
        "jodan": dict(READY, hip=(-1.0, -17.0), lean=-0.06, hf=(3.0, -37.0), sw=3.4, ebf=1, sw_back=True,
                      hb=(8.0, -27.0), ebb=-1),
        "gedan": dict(READY, hip=(-1.0, -16.0), lean=0.08, hf=(10.0, -18.0), sw=1.0, hb=(-11.0, -29.0)),
        "waki": dict(READY, hip=(-1.0, -15.5), lean=0.08, hf=(-3.0, -20.0), sw=-1.3, sw_back=True,
                     hb=(8.0, -25.0), ebb=-1),
        "iai": dict(STAND, hip=(-1.0, -15.5), lean=0.18, ff=(8.0, 0.0), fb=(-7.0, 0.0), hf=(6.5, -17.5),
                    hb=(1.0, -16.5), head="f"),
    }
    for sid, base in STANCES.items():
        def ex(p, i, k, base=base):
            if p.get("sw") is not None:
                p["sw"] = base["sw"] + 0.05 * k
        A["st_" + sid] = {"loop": True, "frames": [(p, 150) for p in _breath(base, 6, 1.0, sway=0.5, extra=ex)]}

    # ---------- 拔剑、收剑 ----------
    grip = P(**dict(STAND, hf=(6.5, -19.5), hb=(-5.0, -18.0)))
    out1 = P(**dict(STAND, hf=(13.0, -25.0), sw=1.8, hb=(-10.0, -24.0), ebb=1))
    A["draw"] = {"frames": [(grip, 60), (out1, 50, S(type="flat", c=(5.0, -22.0), rx=20.0, ry=4.0, a0=2.6, a1=0.2, th=3.0)),
                            (B(out1, R, 0.5), 60), (R, 60)]}
    flick = P(**dict(STAND, hf=(12.0, -24.0), sw=1.5, hb=(-8.0, -22.0), ebb=1))
    flick2 = P(**dict(STAND, hf=(10.0, -17.0), sw=1.0, hb=(-8.0, -21.0), ebb=1))
    sheath1 = P(**dict(STAND, hf=(10.0, -21.0), sw=-1.05, sw_back=True))      # 剑转成和鞘平行
    sheath2 = P(**dict(STAND, hf=(7.0, -19.5), sw=-1.05, sw_back=True, swlen=12.0))   # 剑身滑进鞘里
    A["sheathe"] = {"frames": [(flick, 90), (flick2, 70), (sheath1, 120), (sheath2, 100),
                               (P(**dict(STAND, hf=(6.5, -19.5), sw=-1.05, sw_back=True, swlen=5.0)), 90), (P(**STAND), 200)]}

    # ---------- 格挡、弹反：剑竖在身前，后手往后展开 ----------
    guard = K(hip=(-1.0, -16.0), lean=0.0, ff=(8.0, 0.0), fb=(-7.0, 0.0), hf=(9.0, -25.0), sw=2.75,
              hb=(-10.0, -26.0))
    A["guard"] = {"loop": True, "frames": [(guard, 200), (K(**dict(guard, hip=(-1.0, -15.5), hf=(9.0, -24.5))), 200)]}
    pushed = K(**dict(guard, hip=(-2.5, -15.5), lean=-0.12, hf=(7.0, -25.0), sw=2.9, head="h"))
    A["block"] = {"frames": [(pushed, 70), (B(pushed, guard, 0.5), 70), (guard, 80)]}
    snap = K(hip=(-0.5, -16.5), lean=0.0, ff=(8.0, 0.0), fb=(-7.0, 0.0), hf=(10.0, -29.0), sw=3.05, hb=(-12.0, -24.0))
    A["parry"] = {"frames": [(snap, 60), (snap, 80), (B(snap, guard, 0.5), 80), (guard, 80)]}

    # ---------- 闪身、后撤 ----------
    low = K(hip=(1.0, -14.0), lean=0.4, ff=(9.0, 0.0), fb=(-8.0, 0.0), hf=(2.0, -17.0), sw=-1.3, sw_back=True,
            hb=(-8.0, -20.0), robe=4.0, sleeve=3.0)
    dash = K(hip=(3.0, -13.5), lean=0.55, ff=(11.0, 0.0), fb=(-11.0, -3.0), fba=0.6, hf=(1.0, -16.0), sw=-1.4,
             sw_back=True, hb=(-9.0, -18.0), robe=6.0, sleeve=4.0, lift=2.0)
    rec = K(hip=(0.0, -15.5), lean=0.1, hf=(9.0, -23.0), sw=1.8, hb=(-10.0, -25.0))
    A["dodge"] = {"speed": 300.0, "frames": [(low, 50), (dash, 70), (dash, 70), (rec, 80)]}
    hop = K(hip=(-1.0, -18.0), lean=-0.15, ff=(3.0, -3.0), fb=(-6.0, -1.0), ffa=0.5, fba=0.7, hf=(9.0, -25.0),
            sw=2.0, hb=(-10.0, -29.0), robe=-2.0, lift=-1.0)
    A["backstep"] = {"frames": [(hop, 70), (K(**dict(hop, ff=(4.0, -1.0), fb=(-5.0, 0.0))), 80),
                                (K(**dict(hop, hip=(-0.5, -15.5), lean=0.05, ff=(7.0, 0.0), fb=(-7.0, 0.0))), 80), (R, 80)]}

    # ---------- 受击、破防 ----------
    hit = K(hip=(-2.0, -17.0), lean=-0.25, ff=(6.0, 0.0), fb=(-7.0, 0.0), hf=(6.0, -20.0), sw=1.2, head="h",
            hb=(-10.0, -24.0), robe=-1.5, sleeve=-2.0)
    A["hit"] = {"frames": [(hit, 70), (K(**dict(hit, lean=-0.18, hip=(-1.5, -16.5))), 90), (B(hit, R, 0.5), 90)]}
    broken = K(hip=(0.0, -14.0), lean=0.55, ff=(7.0, 0.0), fb=(-6.0, 0.0), hf=(7.0, -12.0), sw=1.3, hb=(1.0, -11.0),
               ebb=-1, head="h")
    A["broken"] = {"loop": True, "frames": [(broken, 180), (K(**dict(broken, lean=0.5, hip=(0.0, -14.5))), 180),
                                            (K(**dict(broken, lean=0.6, hip=(0.0, -13.5))), 180)]}

    # ---------- 倒下 ----------
    kneel = K(hip=(0.0, -10.0), lean=0.3, ff=(7.0, 0.0), fb=(-5.0, 0.0), fba=1.3, hf=(7.0, -9.0), sw=1.45,
              hb=(2.0, -9.0), ebb=-1, head="c")
    A["death"] = {"frames": [(hit, 80), (B(hit, kneel, 0.6), 120), (kneel, 300),
                             (K(**dict(kneel, rot=0.6, hip=(1.0, -9.0))), 90),
                             (K(**dict(kneel, rot=1.2, hip=(3.0, -6.0))), 90),
                             (K(**dict(kneel, rot=1.5, hip=(5.0, -4.5), hf=(14.0, -4.0))), 400)]}
    A["downed"] = {"loop": True, "frames": [(kneel, 400), (K(**dict(kneel, hip=(0.0, -9.5))), 400)]}

    # ---------- 喝药（后手拿葫芦往嘴里送；葫芦在游戏里画在后手上） ----------
    lift_ = P(**dict(STAND, hb=(4.0, -26.0), ebb=-1))
    drink = P(**dict(STAND, hb=(4.5, -31.0), head="c", head_off=(-0.5, -0.5), lean=-0.06))
    A["drink"] = {"frames": [(lift_, 100), (drink, 150), (P(**dict(drink, head_off=(-0.5, 0.0))), 150),
                             (drink, 150), (P(**dict(drink, head_off=(-0.5, 0.0))), 150), (lift_, 100), (P(**STAND), 100)]}

    # ---------- 处决：剑举过头，往前下方一剑扎进去 ----------
    up = K(hip=(-1.0, -17.5), lean=-0.1, hf=(2.0, -37.0), sw=3.4, ebf=1, hb=(8.0, -26.0), ebb=-1)
    thrust = K(hip=(3.0, -13.0), lean=0.4, ff=(12.0, 0.0), fb=(-8.0, 0.0), hf=(16.0, -16.0), sw=1.25,
               hb=(-12.0, -22.0), robe=3.0)
    A["execute"] = {"phases": [2, 2, 3], "frames": [(B(R, up, 0.6), 60), (up, 80),
                                                    (thrust, 60, S(type="sweep", white=True, **{"from": up})),
                                                    (thrust, 80, S(type="sweep", white=True, fade=True, **{"from": up})),
                                                    (thrust, 200), (B(thrust, R, 0.5), 120), (R, 120)]}

    # ---------- 忍具：剑收在身侧，后手往前一甩（飞镖、爆竹、烟幕） ----------
    t0 = K(hip=(-1.0, -16.0), lean=-0.05, hf=(4.0, -17.0), sw=1.05, hb=(-11.0, -29.0), ebb=1)
    t1 = K(hip=(1.0, -15.5), lean=0.15, hf=(3.0, -17.0), sw=1.05, hb=(13.0, -26.0), ebb=-1)
    A["throw"] = {"phases": [1, 1, 2], "frames": [(t0, 80), (t1, 60), (t1, 80), (B(t1, R, 0.5), 80)]}
    # 钩索：后手往前上方一伸
    A["hook"] = {"frames": [(K(hf=(4.0, -17.0), sw=1.05, hb=(12.0, -31.0), ebb=-1, lean=0.12), 100)]}

    # ---------- 道具：后手往嘴边送一下 ----------
    A["item"] = {"frames": [(P(**dict(STAND, hb=(4.0, -28.0))), 150), (P(**dict(STAND, hb=(4.5, -31.0), head="c")), 250),
                            (P(**STAND), 100)]}

    # ---------- 拔刀式的居合：从鞘里横着一剑抽出去 ----------
    st = STANCES["iai"]
    out = P(**dict(st, hf=(15.0, -23.0), sw=1.6, lean=0.25, hip=(2.0, -15.0), ff=(11.0, 0.0), hb=(-11.0, -24.0),
                   ebb=1, robe=3.0))
    out2 = P(**dict(out, hf=(13.0, -25.0), sw=2.1, robe=3.5))
    fl = dict(type="flat", c=(6.0, -21.0), rx=32.0, ry=6.0, a0=2.4, a1=-0.1, th=6.0)
    A["iai_cut"] = {"phases": [1, 2, 3], "frames": [(P(**st), 60), (out, 45, S(**fl)), (out2, 45, S(**dict(fl, fade=True))),
                                                    (out2, 100), (B(out2, R, 0.5), 100), (R, 90)]}

    # ---------- 站着没事干时耍的花剑 ----------
    rel = P(**RELAXED)
    # 甩血：剑往前一挥，再往下一甩
    A["fl_chiburi"] = {"frames": [(P(**dict(RELAXED, hf=(8.0, -28.0), sw=2.7, hb=(-6.0, -20.0))), 300), (flick, 80),
                                  (flick2, 400), (rel, 300)]}
    # 转剑：剑在手里转两圈，再收回架子上
    wheel = [(P(**dict(RELAXED, hf=(8.0, -22.0), sw=1.05 + k * math.tau / 8)), 60) for k in range(8)]
    A["fl_wheel"] = {"frames": [(rel, 200)] + wheel + wheel + [(P(**dict(READY_B)), 400), (rel, 200)]}
    # 剑花：举到身前，剑指抹过剑身，再摆个架子
    A["fl_flower"] = {"frames": [(P(**dict(RELAXED, hf=(10.0, -25.0), sw=1.8, hb=(6.0, -25.0), ebb=-1)), 300),
                                 (P(**dict(RELAXED, hf=(10.0, -25.0), sw=1.8, hb=(12.0, -26.0), ebb=-1)), 300),
                                 (P(**dict(READY)), 600), (rel, 300)]}
    # 伸懒腰
    A["fl_stretch"] = {"frames": [(P(**dict(STAND, hip=(0.0, -19.0), lean=-0.15, hb=(-2.0, -35.0), head="c")), 700),
                                  (P(**dict(STAND, hip=(0.0, -19.0), lean=-0.2, hb=(-3.0, -36.0), head="c")), 600),
                                  (P(**STAND), 400)]}
    # 回头看一眼
    A["fl_look_back"] = {"frames": [(P(**dict(STAND, head_off=(-1.0, 0.0), lean=-0.03)), 900), (P(**STAND), 500)]}
