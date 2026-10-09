"""刀光（拖影）：出刀那一帧画出剑扫过的那一片，越新的地方越亮。

种类：
  sweep   剑从上一个姿势扫到这一个姿势扫过的区域（竖劈、上撩、空中斩……）。只画剑身外侧那一段，像一弯月牙
  flat    横斩：一个压扁的椭圆弧（从身后绕到身前）
  ring    旋风斩：一整圈压扁的椭圆
  streak  突刺：一道往前的直光
fade 为 True 时是第二帧：整体暗一档、变细、内侧打散，像在消失。
"""
import math
from rig import Part, capsule_mask, add, mul, lerp, adir, sub, length
import heroine as hz

# 从新到旧：白 → 浅粉 → 粉 → 深玫红（最旧的地方隔一个像素画一个，打散）
COLORS = ["fffbfd", "ffe0ec", "f7aaca", "dc6aa2", "9a3a78"]
# 重劈用的白光
WHITE = ["ffffff", "f6f4fc", "dcd8ec", "aea8c8", "6e6890"]


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def _color(age, x, y, fade, colors=COLORS):
    """age 0 = 最新，1 = 最旧。色带之间用 4x4 有序抖动过渡，最旧的一截打散成点"""
    if fade:
        age = age * 0.65 + 0.35
    th = (BAYER[y % 4][x % 4] + 0.5) / 16.0
    if age > 0.78 and (age - 0.78) / 0.22 > th:
        return None
    v = age * (len(colors) - 1)
    i = int(v)
    if v - i > th:
        i += 1
    return colors[min(i, len(colors) - 1)]


def render(cv, sm, p):
    kind = sm["type"]
    fade = sm.get("fade", False)
    part = Part()
    best = {}           # 像素 -> (年龄, 径向位置 0..1)
    if kind == "sweep":
        a = sm["from"]
        ja, jb = hz.skeleton(a), hz.skeleton(p)
        wa, wb = ja["wrist_f"], jb["wrist_f"]
        sa, sb = a["sw"], p["sw"]
        la, lb = a["swlen"], p["swlen"]
        steps = 64
        inner = sm.get("inner", 0.45) + (0.2 if fade else 0.0)
        reach = sm.get("reach", 3.0)
        for k in range(steps + 1):
            t = k / steps
            w = lerp(wa, wb, t)
            d = adir(sa + (sb - sa) * t)
            L = la + (lb - la) * t
            # 月牙：越旧的地方越细，只剩靠刀尖的一截
            inn = inner + (0.93 - inner) * (1.0 - t) ** 0.75
            base = add(w, mul(d, 3.0 + L * inn))
            tip = add(w, mul(d, 3.0 + L + reach))
            age = 1.0 - t
            for q in capsule_mask(cv, base, tip, 1.2):
                c = cv.center(*q)
                r = length(sub(c, w)) / (3.0 + L + reach)
                if q not in best or best[q][0] > age:
                    best[q] = (age, r)
    elif kind in ("flat", "ring"):
        cx, cy = sm["c"]
        rx, ry = sm["rx"], sm["ry"]
        th = sm.get("th", 5.0) * (0.55 if fade else 1.0)
        a0, a1 = sm.get("a0", math.pi), sm.get("a1", 0.0)
        if kind == "ring":
            a0, a1 = sm.get("a0", -math.pi / 2), sm.get("a0", -math.pi / 2) + math.tau * sm.get("turn", 1.0)
        steps = 60
        for k in range(steps + 1):
            t = k / steps
            ang = a0 + (a1 - a0) * t
            outer = (cx + rx * math.cos(ang), cy + ry * math.sin(ang))
            inn = (cx + (rx - th) * math.cos(ang), cy + (ry - th * ry / rx * 1.4) * math.sin(ang))
            # 两头细、中间粗
            taper = math.sin(math.pi * min(1.0, max(0.0, t))) ** 0.6
            inn = lerp(outer, inn, max(0.25, taper))
            age = 1.0 - t
            for q in capsule_mask(cv, inn, outer, 0.9):
                if q not in best or best[q][0] > age:
                    best[q] = (age, 1.0)
    elif kind == "streak":
        y = sm["y"]
        x0, x1 = sm["x0"], sm["x1"]
        th = sm.get("th", 2.0) * (0.5 if fade else 1.0)
        steps = int(abs(x1 - x0))
        for k in range(steps + 1):
            t = k / max(1, steps)
            x = x0 + (x1 - x0) * t
            w = th * math.sin(math.pi * t) ** 0.5
            for q in capsule_mask(cv, (x, y - w * 0.5), (x, y + w * 0.5), 0.6):
                age = 1.0 - t
                if q not in best or best[q][0] > age:
                    best[q] = (age, 1.0)
        # 几道速度线
        for dy, l0, l1 in ((-5.0, 0.15, 0.6), (4.0, 0.3, 0.8)):
            for k in range(int((l1 - l0) * steps)):
                x = x0 + (x1 - x0) * (l0 + k / steps)
                q = cv.to_px((x, y + dy))
                if q not in best:
                    best[q] = (0.55 + 0.4 * (1 - k / max(1, (l1 - l0) * steps)), 1.0)
    for q, (age, r) in best.items():
        if q[1] >= cv.oy:          # 地面以下不画
            continue
        col = _color(age, q[0], q[1], fade, WHITE if sm.get("white") else COLORS)
        if col:
            part.put(q, col)
    return part
