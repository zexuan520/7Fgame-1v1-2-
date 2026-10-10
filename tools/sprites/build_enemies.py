"""把第一层人形敌人的动作画成精灵表：assets/sprites/enemy_<种类>.png 和 .json（格式和主角的一样）。

  python3 tools/sprites/build_enemies.py                 全部生成
  python3 tools/sprites/build_enemies.py --preview 目录 [种类...]   另外出总览图
"""
import json
import math
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import humanoid as hu
import heroine as hz
import enemies as en
import dog as dg

KINDS = list(en.USES) + ["dog"]

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLS = 16
B = hu.lerp_pose

# 出手姿势是往前扎的（突刺、长枪、居合、盾击、踢、擒拿）：刀光画成一道直光或者不画
STREAK = {"cut3", "spear", "iai_cut"}
NO_SMEAR = {"bash", "kick", "grab_reach", "bow_loose", "hop"}


def _breath(kind, name, n, drop, ms, sway=0.4, sw_amp=0.05):
    base = dict(en.POSES[name])
    out = []
    for i in range(n):
        k = (1.0 - math.cos(i / n * math.tau)) / 2.0
        hip = base["hip"]
        over = {"hip": (hip[0], hip[1] + drop * k), "robe": sway * math.sin(i / n * math.tau)}
        for hk in ("hf", "hb"):
            if base.get(hk) is not None:
                h = base[hk]
                over[hk] = (h[0], h[1] + drop * k * 0.8)
        if base.get("sw") is not None:
            over["sw"] = base["sw"] + sw_amp * k
        out.append((en.get(kind, name, **over), ms))
    return out


def _walk(kind, name, near):
    """走动：脚交替迈步，胯一起一伏；近处（戒备）步子小、身子压得低"""
    base = dict(en.POSES[name])
    out = []
    stride = 4.0 if near else 5.5
    lift = 2.0 if near else 3.0
    for i in range(8):
        ph = i / 8 * math.tau
        c, s = math.cos(ph), math.sin(ph)
        f0, b0 = base["ff"], base["fb"]
        mid = (f0[0] + b0[0]) / 2.0
        half = (f0[0] - b0[0]) / 2.0 * (0.6 if near else 0.3)
        over = {"ff": (mid + half + stride * c, -lift * max(0.0, -s)),
                "fb": (mid - half - stride * c, -lift * max(0.0, s)),
                "hip": (base["hip"][0], base["hip"][1] - 0.8 * (1.0 - abs(c))),
                "robe": 1.0 + 0.6 * abs(s)}
        dy = over["hip"][1] - base["hip"][1]
        for hk in ("hf", "hb"):
            if base.get(hk) is not None:
                h = base[hk]
                over[hk] = (h[0], h[1] + dy)
        out.append((en.get(kind, name, **over), 90))
    return out


def anims_for(kind):
    if kind == "dog":
        return dg.build()
    U = en.USES[kind]
    far, near = U["idle"]
    ready = en.get(kind, near)
    A = {}
    A["idle_far"] = {"loop": True, "frames": _breath(kind, far, 6, 1.0, 180)}
    A["idle_near"] = {"loop": True, "frames": _breath(kind, near, 6, 1.0, 150)}
    A["walk_far"] = {"loop": True, "frames": _walk(kind, far, False)}
    A["walk_near"] = {"loop": True, "frames": _walk(kind, near, True)}
    g = en.get(kind, "guard")
    A["guard"] = {"loop": True, "frames": [(g, 200), (en.get(kind, "guard", hip=(-1.0, -15.5)), 200)]}
    hit = en.get(kind, "hit")
    A["hit"] = {"frames": [(hit, 80), (B(hit, ready, 0.5), 120)]}
    A["broken"] = {"loop": True, "frames": [(en.get(kind, "broken"), 200), (en.get(kind, "broken", lean=0.52, hip=(0.0, -14.5)), 200),
                                             (en.get(kind, "broken", lean=0.68, hip=(0.0, -13.5)), 200)]}
    kn = en.get(kind, "kneel")
    A["death"] = {"frames": [(hit, 60), (B(hit, kn, 0.6), 100), (kn, 440),
                             (en.get(kind, "kneel", rot=0.6, hip=(1.0, -9.0)), 130),
                             (en.get(kind, "kneel", rot=1.2, hip=(3.0, -6.0)), 130),
                             (en.get(kind, "kneel", rot=1.5, hip=(5.0, -4.5), hf=(14.0, -4.0)), 1000)]}
    for r, c in U["pairs"]:
        rp, cp = en.get(kind, r), en.get(kind, c)
        danger = (r, c) in en.DANGER_PAIRS
        col = "red" if danger else "warm"
        a1 = B(rp, cp, 0.75)
        if c in NO_SMEAR or cp["sw"] is None:
            s1 = s2 = {}
        elif c == "sweep_cut":
            # 下段横扫：贴着地面一道扁平的弧光（剑往下扫，按剑扫过的范围画会被地面挡掉）
            j = hu.skeleton(cp, en.COSTUMES[kind])
            fl = dict(type="flat", c=(j["wrist_f"][0] - 4.0, -7.0), rx=30.0, ry=4.5, a0=math.pi, a1=0.05, th=5.0,
                      colors=col)
            s1, s2 = {"smear": fl}, {"smear": dict(fl, fade=True)}
        elif c in STREAK:
            j = hu.skeleton(cp, en.COSTUMES[kind])
            tip, hand = j["tip"], j["wrist_f"]
            st = dict(type="streak", y=tip[1] - 0.5, x0=hand[0] - 10.0, x1=tip[0] + 14.0, th=3.0, colors=col)
            s1, s2 = {"smear": st}, {"smear": dict(st, fade=True)}
        else:
            sw = dict(type="sweep", colors=col, inner=0.4)
            sw["from"] = rp
            s1, s2 = {"smear": sw}, {"smear": dict(sw, fade=True)}
        A["%s>%s" % (r, c)] = {"phases": [2, 2, 2], "frames": [
            (B(ready, rp, 0.55), 30), (rp, 70), (a1, 45, s1), (cp, 55, s2), (cp, 50), (B(cp, ready, 0.5), 50)]}
    if kind == "ronin":
        flourishes(A, kind)
    return A


def flourishes(A, kind):
    """浪人走着走着耍的花样（远处扛刀时、近处戒备时都有）"""
    sh = en.get(kind, "shoulder")
    st = en.get(kind, "stalk")
    # 扛着刀在肩上敲两下
    tap = en.get(kind, "shoulder", hf=(4.0, -26.5), sw=-2.35)
    A["fl_tap"] = {"frames": [(sh, 200), (tap, 120), (sh, 160), (tap, 120), (sh, 400)]}
    # 刀在手里转一圈再扛回肩上
    A["fl_shoulder_twirl"] = {"frames": [(sh, 150)] + [(en.get(kind, "stalk", hf=(8.0, -22.0), sw=1.95 + k * math.tau / 8, grip2=False,
                                                                 hb=(-3.0, -14.0)), 60) for k in range(8)] + [(sh, 300)]}
    # 压一压斗笠
    hat = en.get(kind, "shoulder", hb=(3.0, -32.0), ebb=-1)
    A["fl_hat"] = {"frames": [(sh, 200), (hat, 500), (en.get(kind, "shoulder", hb=(3.0, -31.0), ebb=-1), 300), (sh, 300)]}
    # 后手勾一勾：来啊
    bk1 = en.get(kind, "stalk", grip2=False, hb=(8.0, -24.0), ebb=-1)
    bk2 = en.get(kind, "stalk", grip2=False, hb=(6.0, -26.0), ebb=-1)
    A["fl_beckon"] = {"frames": [(st, 150), (bk1, 180), (bk2, 180), (bk1, 180), (bk2, 180), (st, 300)]}
    # 刀往下一甩
    A["fl_flick"] = {"frames": [(st, 150), (en.get(kind, "stalk", hf=(10.0, -16.0), sw=1.0), 80), (st, 400)]}


def render(kind, A):
    if kind == "dog":
        out = {}
        for name, a in A.items():
            out[name] = [dg.draw(f[0], smear=(f[2] if len(f) > 2 else {}).get("smear")) for f in a["frames"]]
        return out
    C = en.COSTUMES[kind]
    out = {}
    for name, a in A.items():
        frames = a["frames"]
        poses = [f[0] for f in frames]
        durs = [f[1] / 1000.0 for f in frames]
        tails = [None] * len(frames)
        if C.get("band_tails"):
            roots = [hu.skeleton(p, C)["tails"] for p in poses]
            sim = hz.simulate_hair(roots, durs, [(0.0, 0.0)] * len(frames), a.get("loop", False))
            tails = [pts[:5] for pts in sim]
        res = []
        for f, p, t in zip(frames, poses, tails):
            opt = f[2] if len(f) > 2 else {}
            res.append(hu.draw(p, C, tails=t, smear=opt.get("smear"), flip=opt.get("flip", False)))
        out[name] = res
    return out


def _r(q):
    return None if q is None else [round(q[0], 1), round(q[1], 1)]


def write(kind, A, R):
    mod = dg if kind == "dog" else hu
    total = sum(len(v) for v in R.values())
    rows = (total + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * mod.W, rows * mod.H), (0, 0, 0, 0))
    data = {"frame": [mod.W, mod.H], "origin": [mod.OX, mod.OY], "cols": COLS, "anims": {}}
    i = 0
    for name, frames in R.items():
        idx, tips, hbs, eyes = [], [], [], []
        for img, meta in frames:
            sheet.alpha_composite(img, ((i % COLS) * mod.W, (i // COLS) * mod.H))
            idx.append(i)
            tips.append(_r(meta.get("tip")))
            hbs.append(_r(meta["hand_b"]))
            eyes.append(_r(meta.get("eye")))
            i += 1
        data["anims"][name] = {"frames": idx, "ms": [f[1] for f in A[name]["frames"]],
                               "loop": A[name].get("loop", False), "tips": tips, "hb": hbs, "eye": eyes}
        if A[name].get("phases"):
            data["anims"][name]["phases"] = A[name]["phases"]
    out = os.path.join(ROOT, "assets", "sprites")
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, "enemy_%s.png" % kind))
    with open(os.path.join(out, "enemy_%s.json" % kind), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("%s：%d 帧，%d 个动作" % (kind, i, len(R)))


def preview(kind, A, R, out, per=6, scale=3, box=(10, 6, 124, 92)):
    if kind == "dog":
        box = (8, 20, 88, 62)
    rows = []
    for name, frames in R.items():
        w, h = box[2] - box[0], box[3] - box[1]
        k = min(per, len(frames))
        row = Image.new("RGBA", (k * (w + 2) + 90, h), (14, 10, 22, 255))
        for i in range(k):
            t = Image.new("RGBA", (w, h), (44, 38, 62, 255))
            t.alpha_composite(frames[i][0].crop(box))
            row.alpha_composite(t, (90 + i * (w + 2), 0))
        ImageDraw.Draw(row).text((2, 2), name, fill=(230, 220, 240, 255))
        rows.append(row.resize((row.width * scale, row.height * scale), Image.NEAREST))
    os.makedirs(out, exist_ok=True)
    for g in range(0, len(rows), 6):
        part = rows[g:g + 6]
        img = Image.new("RGBA", (max(r.width for r in part), sum(r.height + 6 for r in part)), (0, 0, 0, 255))
        y = 0
        for r in part:
            img.alpha_composite(r, (0, y))
            y += r.height + 6
        img.save(os.path.join(out, "%s_%02d.png" % (kind, g // 6)))


if __name__ == "__main__":
    args = sys.argv[1:]
    out = None
    if args and args[0] == "--preview":
        out = args[1]
        args = args[2:]
    for kind in (args or KINDS):
        A = anims_for(kind)
        R = render(kind, A)
        if out:
            preview(kind, A, R, out)
        else:
            write(kind, A, R)
