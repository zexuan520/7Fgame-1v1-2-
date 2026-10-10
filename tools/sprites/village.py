"""荒村的场景件：房子、枯树、篱笆、远处的屋影、地面、近景草丛。

每个件是一个函数，返回 (Canvas, meta)。meta 里 origin 是贴地点（脚底中心），
windows 是窗洞矩形（Godot 里按天色往里叠火光或灯光），smoke 是冒烟的位置。
光一律画成从左边来；天色的光在右边时整张图水平翻转。
"""
import math
import numpy as np
from scenery import Canvas, rng


# ---------- 通用纹理 ----------

def planks_v(cv, x0, y0, x1, y1, mat, r, w=5, rot=0.0):
    """竖木板：每块板子左亮右暗，板缝描暗线，偶尔一个木节、一块缺口。"""
    x = x0
    while x < x1:
        pw = int(w + r.integers(-1, 2))
        top = y0 + (int(r.integers(0, 3)) if r.random() < rot else 0)
        cv.rect(x, top, min(pw, x1 - x), y1 - top, mat, 2)
        cv.rect(x, top, 1, y1 - top, mat, 3)
        cv.rect(min(x + pw - 1, x1 - 1), top, 1, y1 - top, mat, 1)
        if r.random() < 0.35:
            ky = int(r.integers(y0 + 2, max(y0 + 3, y1 - 2)))
            cv.put(x + pw // 2, ky, mat, 0)
            cv.put(x + pw // 2, ky + 1, mat, 1)
        if r.random() < 0.3:
            # 纵向木纹
            gx = x + int(r.integers(1, max(2, pw - 1)))
            gy = int(r.integers(y0, max(y0 + 1, y1 - 6)))
            for k in range(int(r.integers(3, 8))):
                cv.put(gx, gy + k, mat, 1)
        x += pw


def planks_h(cv, x0, y0, x1, y1, mat, r, h=4):
    y = y0
    while y < y1:
        ph = int(h + r.integers(0, 2))
        cv.rect(x0, y, x1 - x0, min(ph, y1 - y), mat, 2)
        cv.rect(x0, y, x1 - x0, 1, mat, 3)
        cv.rect(x0, min(y + ph - 1, y1 - 1), x1 - x0, 1, mat, 1)
        # 板子接缝
        sx = x0 + int(r.integers(8, 30))
        while sx < x1 - 2:
            cv.rect(sx, y, 1, min(ph, y1 - y), mat, 0)
            sx += int(r.integers(18, 40))
        y += ph


def post(cv, x, y0, y1, w=4, mat="wood"):
    cv.rect(x, y0, w, y1 - y0, mat, 2)
    cv.rect(x, y0, 1, y1 - y0, mat, 3)
    cv.rect(x + w - 1, y0, 1, y1 - y0, mat, 1)


def beam(cv, x0, x1, y, h=3, mat="wood"):
    cv.rect(x0, y, x1 - x0, h, mat, 2)
    cv.rect(x0, y, x1 - x0, 1, mat, 3)
    cv.rect(x0, y + h - 1, x1 - x0, 1, mat, 1)


def plaster(cv, x0, y0, x1, y1, r, mat="mud", fallen=0.25):
    """抹灰墙：整体中间阶，散些亮点暗点，几道裂缝，掉了灰的地方露出里面的竹编。"""
    cv.rect(x0, y0, x1 - x0, y1 - y0, mat, 2)
    for _ in range((x1 - x0) * (y1 - y0) // 14):
        x, y = int(r.integers(x0, x1)), int(r.integers(y0, y1))
        cv.put(x, y, mat, 3 if r.random() < 0.5 else 1)
    for _ in range(max(1, (x1 - x0) // 20)):
        x, y = int(r.integers(x0 + 2, x1 - 2)), int(r.integers(y0, y1))
        for _ in range(int(r.integers(4, 10))):
            cv.put(x, y, mat, 0)
            x += int(r.integers(-1, 2))
            y += 1
            if y >= y1 or x <= x0 or x >= x1 - 1:
                break
    if r.random() < fallen:
        w, h = int(r.integers(6, 12)), int(r.integers(5, min(10, y1 - y0)))
        px, py = int(r.integers(x0 + 1, max(x0 + 2, x1 - w - 1))), int(r.integers(y0, max(y0 + 1, y1 - h)))
        m = cv.mask_poly([(px, py + 2), (px + 3, py), (px + w, py + 1), (px + w - 1, py + h), (px + 1, py + h - 1)])
        cv.apply(m, "VOID", 1)
        for yy in range(py, py + h + 1, 3):
            for xx in range(px, px + w + 1):
                if m[min(yy, cv.h - 1), xx]:
                    cv.put(xx, yy, "oldwood", 1)
        for xx in range(px + 1, px + w, 3):
            for yy in range(py, py + h + 1):
                if m[min(yy, cv.h - 1), xx]:
                    cv.put(xx, yy, "oldwood", 2)
        # 剥落的边缘亮一点
        for yy in range(py - 1, py + h + 2):
            for xx in range(px - 1, px + w + 2):
                if cv.get(xx, yy) and cv.get(xx, yy)[0] == mat and (m[min(yy + 1, cv.h - 1), xx] or m[yy, min(xx + 1, cv.w - 1)]):
                    cv.put(xx, yy, mat, 3)


def stones_row(cv, x0, x1, y0, y1, r, mat="stone"):
    """一排石头基脚：大小不一的石块，块与块之间暗缝，上沿受光。"""
    x = x0
    while x < x1:
        w = int(r.integers(5, 11))
        top = y0 + int(r.integers(0, 2))
        cv.rect(x, top, min(w, x1 - x), y1 - top, mat, 2)
        cv.rect(x, top, min(w, x1 - x), 1, mat, 3)
        cv.rect(x, top, 1, y1 - top, mat, 3)
        cv.rect(min(x + w - 1, x1 - 1), top, 1, y1 - top, mat, 0)
        cv.rect(x, y1 - 1, min(w, x1 - x), 1, mat, 1)
        x += w


def thatch(cv, m, r, band=8):
    """茅草：一层层压上去的草。每层上沿被上一层盖住是暗的（垂下来的草茎长短不一），
    下沿鼓出来受光；层内是竖着的草茎条纹。光从左上来，左边整体亮一阶、右边暗一阶。"""
    ys, xs = np.nonzero(m)
    if len(ys) == 0:
        return
    top = ys.min()
    left, right = xs.min(), xs.max()
    cv.apply(m, "thatch", 2, only_filled=False)
    nb = (ys.max() - top) // band + 2
    streak = r.random((nb, cv.w + 2))
    # 条纹宽 1~2 像素：相邻两列共用一个随机数
    for b in range(nb):
        for x in range(1, cv.w + 2, 2):
            if r.random() < 0.5:
                streak[b, x] = streak[b, x - 1]
    hang = r.integers(1, 4, (nb, cv.w))
    span = max(1, right - left)
    for y, x in zip(ys, xs):
        b = (y - top) // band
        dy = (y - top) % band
        lv = 2
        if dy < hang[b, x]:
            lv = 0 if (dy == 0 and hang[b, x] == 3) else 1
        elif dy >= band - 2:
            lv = 3
        s = streak[b, x]
        if lv == 2:
            if s < 0.14:
                lv = 1
            elif s > 0.9:
                lv = 3
        t = (x - left) / span
        if t < 0.16:
            lv += 1
        elif t > 0.84:
            lv -= 1
        cv.lv[y, x] = max(0, min(4, lv))


def tiles(cv, m, r, row_h=5):
    """瓦屋顶：一排排筒瓦，每片瓦一条亮脊一条暗沟，每排下沿一道暗影。"""
    ys, xs = np.nonzero(m)
    top = ys.min()
    cv.apply(m, "tile", 2, only_filled=False)
    for y, x in zip(ys, xs):
        row = (y - top) // row_h
        dy = (y - top) % row_h
        col = (x + (row % 2) * 2) % 4
        lv = 2
        if col == 0:
            lv = 3
        elif col == 3:
            lv = 1
        if dy == row_h - 1:
            lv = 0 if col == 3 else 1
        elif dy == 0 and col in (0, 1):
            lv = 4 if col == 0 else 3
        cv.lv[y, x] = lv
    # 掉了几片瓦
    for _ in range(int(r.integers(1, 4))):
        k = int(r.integers(0, len(xs)))
        y, x = ys[k], xs[k]
        for dx in range(3):
            for dy in range(row_h - 1):
                if m[min(y + dy, cv.h - 1), min(x + dx, cv.w - 1)]:
                    cv.put(x + dx, y + dy, "oldwood", 1 if dy else 0)


def lattice(cv, x0, y0, x1, y1, step=3, mat="wood", glass="VOID"):
    cv.rect(x0, y0, x1 - x0, y1 - y0, glass, 1)
    for x in range(x0, x1, step):
        cv.rect(x, y0, 1, y1 - y0, mat, 2)
    for y in range(y0, y1, step + 1):
        cv.rect(x0, y, x1 - x0, 1, mat, 1)
    # 窗框
    cv.rect(x0 - 1, y0 - 1, x1 - x0 + 2, 1, mat, 3)
    cv.rect(x0 - 1, y1, x1 - x0 + 2, 1, mat, 1)
    cv.rect(x0 - 1, y0 - 1, 1, y1 - y0 + 2, mat, 3)
    cv.rect(x1, y0 - 1, 1, y1 - y0 + 2, mat, 1)


def shadow_band(cv, x0, x1, y0, h, keep=("VOID", "GLOW")):
    """屋檐在墙上投下的影子：这一带的像素降一阶。"""
    for y in range(y0, y0 + h):
        for x in range(x0, x1):
            g = cv.get(x, y)
            if g and g[0] not in keep and g[1] > 1:
                cv.lv[y, x] = g[1] - 1 - (1 if y < y0 + h // 2 and g[1] > 2 else 0)


# ---------- 房子 ----------

def house_thatch(seed=1, broken=False):
    """茅草顶农家：石基、木柱横梁、下半截竖板、上半截土墙，一扇门挂着破门帘，一扇格子窗。"""
    r = rng(seed)
    W, H = 156, 112
    G = H - 1
    cv = Canvas(W, H)
    x0, x1 = 16, 140
    top = G - 46
    meta = {"windows": [], "smoke": []}
    # 墙
    plaster(cv, x0, top, x1, G - 22, r, "mud", 0.7)
    planks_v(cv, x0, G - 22, x1, G - 4, "oldwood", r, rot=0.4)
    beam(cv, x0, x1, G - 23, 3)
    posts = [x0, x0 + 40, x0 + 82, x1 - 4]
    for px in posts:
        post(cv, px, top, G - 3)
    # 门：门洞里黑，半拉开的门板，上面挂破布门帘
    dx0, dx1 = x0 + 48, x0 + 74
    cv.rect(dx0, top + 6, dx1 - dx0, G - 4 - top - 6, "VOID", 1)
    planks_v(cv, dx1 - 9, top + 6, dx1, G - 4, "wood", r, w=4)
    cv.rect(dx1 - 10, top + 6, 1, G - 4 - top - 6, "wood", 0)
    beam(cv, dx0 - 2, dx1 + 2, top + 4, 3)
    for k, (sx, ln) in enumerate([(dx0, 13), (dx0 + 6, 9), (dx0 + 12, 15)]):
        cv.rect(sx, top + 7, 5, ln, "indigo", 2)
        cv.rect(sx, top + 7, 1, ln, "indigo", 3)
        cv.rect(sx + 4, top + 7, 1, ln, "indigo", 1)
        cv.put(sx + 1 + k % 3, top + 7 + ln, "indigo", 1)
    cv.rect(dx0 + 2, top + 10, 1, 1, "paper", 3)
    meta["windows"].append([dx0, top + 22, dx1 - dx0 - 10, G - 4 - top - 22])
    # 格子窗
    wx0, wy0 = x0 + 92, top + 8
    lattice(cv, wx0, wy0, wx0 + 18, wy0 + 12)
    meta["windows"].append([wx0, wy0, 18, 12])
    # 小窗（左边那间）
    lattice(cv, x0 + 14, top + 9, x0 + 26, top + 18, step=4)
    meta["windows"].append([x0 + 14, top + 9, 12, 9])
    # 墙根石基
    stones_row(cv, x0 - 2, x1 + 2, G - 4, G + 1, r)
    # 屋顶
    eave = top + 3
    roof = [(2, eave), (44, 20), (112, 20), (W - 3, eave)]
    m = cv.mask_poly(roof + [(W - 3, eave + 6), (2, eave + 6)])
    thatch(cv, m, r)
    # 檐口截面：剪齐的草茬，竖纹更密更亮
    for x in range(2, W - 2):
        for y in range(eave, eave + 6):
            if m[y, x]:
                cv.lv[y, x] = 3 if (x * 7) % 5 < 2 else 2
                if y == eave + 5:
                    cv.lv[y, x] = 1
        if (x * 13) % 7 == 0:
            cv.put(x, eave + 6, "thatch", 1)
    cv.rect(2, eave, W - 5, 1, "thatch", 4)
    # 屋脊：压草的木脊 + 交叉的压脊木
    ry = 14
    cv.rect(40, ry, 76, 6, "thatch", 1)
    cv.rect(38, ry - 1, 80, 2, "oldwood", 2)
    cv.rect(38, ry - 1, 80, 1, "oldwood", 3)
    for cx in range(44, 116, 12):
        cv.line(cx - 3, ry - 6, cx + 3, ry + 3, "oldwood", 2)
        cv.line(cx + 3, ry - 6, cx - 3, ry + 3, "oldwood", 1)
    # 山墙通风口
    cv.poly([(70, 21), (78, 15), (86, 21)], "oldwood", 1)
    lattice(cv, 74, 19, 82, 22, step=2)
    shadow_band(cv, x0, x1, top, 6)
    if broken:
        # 屋顶塌了一块，露出椽子
        hx = int(r.integers(78, 96))
        pts = [(hx - 16, eave - 1), (hx - 13, eave - 9), (hx - 15, 44), (hx - 9, 38), (hx - 10, 31), (hx - 3, 33),
               (hx + 1, 27), (hx + 5, 34), (hx + 11, 30), (hx + 10, 40), (hx + 17, 44), (hx + 14, eave - 8), (hx + 18, eave - 1),
               (hx + 6, eave + 2), (hx - 2, eave - 2), (hx - 8, eave + 2)]
        hole = cv.mask_poly(pts)
        cv.apply(hole, "VOID", 1, only_filled=False)
        inner = Canvas(cv.w, cv.h)
        for k in range(6):
            xx = hx - 15 + k * 6
            inner.line(xx, eave + 2, xx + 7, 24, "char", 2, width=2)
            inner.line(xx + 1, eave + 2, xx + 8, 24, "char", 1)
        for yy in (36, 48):
            inner.line(hx - 18, yy, hx + 18, yy - 1, "oldwood", 1, width=2)
            inner.line(hx - 18, yy, hx + 18, yy - 1, "oldwood", 2)
        sel = hole & (inner.mat >= 0)
        cv.mat[sel] = inner.mat[sel]
        cv.lv[sel] = inner.lv[sel]
        # 塌口边缘：草茎翘出来，烧焦的一圈
        ys, xs = np.nonzero(hole)
        for y, x in zip(ys, xs):
            for ddx, ddy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                g = cv.get(x + ddx, y + ddy)
                if g and g[0] == "thatch":
                    cv.put(x + ddx, y + ddy, "char", 2 if r.random() < 0.5 else 1)
        for _ in range(14):
            k = int(r.integers(0, len(xs)))
            y, x = ys[k], xs[k]
            if r.random() < 0.6:
                cv.line(x, y, x + int(r.integers(-2, 3)), y + int(r.integers(2, 5)), "thatch", 3)
        meta["smoke"].append([hx, 30])
    cv.outline()
    cv.rim(-1)
    return cv, dict(meta, origin=[W // 2, G])


def roof_tiles(cv, x0, x1, eave, ridge_y, inset, r, ridge_h=6):
    """瓦顶：梯形瓦面 + 屋脊（两头翘起的鬼瓦）+ 檐口一排瓦当。"""
    m = cv.mask_poly([(x0, eave), (x0 + inset, ridge_y), (x1 - inset, ridge_y), (x1, eave)])
    tiles(cv, m, r)
    # 檐口瓦当：一排圆头
    for x in range(x0 + 1, x1 - 1, 4):
        cv.rect(x, eave - 1, 3, 3, "tile", 2)
        cv.put(x, eave - 1, "tile", 4)
        cv.put(x + 2, eave + 1, "tile", 0)
    cv.rect(x0, eave + 2, x1 - x0, 1, "tile", 0)
    # 屋脊
    rx0, rx1 = x0 + inset - 3, x1 - inset + 3
    cv.rect(rx0, ridge_y - ridge_h, rx1 - rx0, ridge_h, "tile", 2)
    cv.rect(rx0, ridge_y - ridge_h, rx1 - rx0, 1, "tile", 4)
    cv.rect(rx0, ridge_y - ridge_h + 1, rx1 - rx0, 1, "tile", 3)
    cv.rect(rx0, ridge_y - 2, rx1 - rx0, 1, "tile", 1)
    for x in range(rx0 + 2, rx1 - 2, 3):
        cv.put(x, ridge_y - 3, "tile", 1)
    # 鬼瓦：两头翘起
    for sx, d in ((rx0, -1), (rx1, 1)):
        cv.poly([(sx, ridge_y), (sx, ridge_y - ridge_h - 1), (sx + 4 * d, ridge_y - ridge_h - 5), (sx + 5 * d, ridge_y - ridge_h - 3),
                 (sx + 3 * d, ridge_y)], "tile", 3 if d < 0 else 1)
    return m


def house_tile(seed=2, lit=True):
    """瓦顶的人家：白灰墙黑木框，正面一道小披檐，下面是外廊和纸拉门（夜里纸门透灯光）。"""
    r = rng(seed)
    W, H = 160, 118
    G = H - 1
    cv = Canvas(W, H)
    x0, x1 = 18, 142
    top = G - 58
    meta = {"windows": [], "smoke": []}
    plaster(cv, x0, top, x1, G - 26, r, "plaster", 0.6)
    beam(cv, x0, x1, top + 16, 3, "char")
    for px in (x0, x0 + 30, x0 + 62, x0 + 94, x1 - 4):
        post(cv, px, top, G - 8, 4, "char")
    # 二楼小窗（虫笼窗）
    for wx in (x0 + 8, x0 + 70):
        lattice(cv, wx, top + 4, wx + 16, top + 12, step=2, mat="char")
        meta["windows"].append([wx, top + 4, 16, 8])
    # 披檐
    pe = top + 26
    m = cv.mask_poly([(x0 - 8, pe + 4), (x0 - 2, pe - 4), (x1 + 2, pe - 4), (x1 + 8, pe + 4)])
    tiles(cv, m, r, row_h=4)
    cv.rect(x0 - 8, pe + 4, x1 - x0 + 16, 2, "char", 1)
    # 纸拉门
    dy0 = pe + 7
    for k, dx in enumerate(range(x0 + 4, x1 - 8, 30)):
        if k == 2:
            cv.rect(dx, dy0, 26, G - 8 - dy0, "VOID", 1)
            meta["windows"].append([dx, dy0, 26, G - 8 - dy0])
            continue
        cv.rect(dx, dy0, 26, G - 8 - dy0, "paper", 2)
        for gx in range(dx, dx + 27, 6):
            cv.rect(gx, dy0, 1, G - 8 - dy0, "char", 1)
        for gy in range(dy0, G - 8, 6):
            cv.rect(dx, gy, 26, 1, "char", 1)
        cv.rect(dx, dy0, 26, 1, "char", 0)
        # 破了几个格子
        for _ in range(int(r.integers(1, 4))):
            hx, hy = dx + 1 + 6 * int(r.integers(0, 4)), dy0 + 1 + 6 * int(r.integers(0, 3))
            cv.rect(hx, hy, 5, 5, "VOID", 1)
            cv.put(hx, hy + 4, "paper", 3)
        if lit:
            meta["windows"].append([dx, dy0, 26, G - 8 - dy0, "paper"])
    # 外廊
    planks_h(cv, x0 - 6, G - 8, x1 + 6, G - 5, "oldwood", r, 3)
    for px in range(x0 - 4, x1 + 6, 26):
        post(cv, px, G - 5, G + 1, 3, "oldwood")
    cv.rect(x0 - 6, G - 5, x1 - x0 + 12, 6, "SHADOW", 1) if False else None
    for y in range(G - 5, G + 1):
        for x in range(x0 - 6, x1 + 6):
            if not cv.filled(x, y):
                cv.put(x, y, "VOID", 1)
    roof_tiles(cv, 4, W - 4, top + 2, 22, 30, r)
    shadow_band(cv, x0, x1, top, 5)
    shadow_band(cv, x0, x1, pe + 6, 4, keep=("VOID",))
    cv.outline()
    cv.rim(-1)
    return cv, dict(meta, origin=[W // 2, G])


def house_ruin(seed=4):
    """烧塌的屋子：几根焦黑的柱子还立着，屋顶斜着塌到地上，地上一堆碎木。"""
    r = rng(seed)
    W, H = 150, 96
    G = H - 1
    cv = Canvas(W, H)
    meta = {"windows": [], "smoke": [[60, 40], [104, 50]]}
    # 后墙残片
    plaster(cv, 20, G - 40, 70, G - 14, r, "mud", 1.0)
    cv.poly([(20, G - 40), (36, G - 46), (52, G - 38), (70, G - 44), (70, G - 14), (20, G - 14)], "mud", 2)
    plaster(cv, 22, G - 38, 68, G - 16, r, "mud", 1.0)
    planks_v(cv, 20, G - 14, 70, G - 3, "char", r, rot=0.9)
    # 柱子：一根直的，一根歪的，一根断的
    post(cv, 18, G - 56, G, 5, "char")
    cv.disc_line((72, G), (80, G - 62), 2.4, 2.0, "char", 2)
    cv.disc_line((120, G), (122, G - 30), 2.4, 2.2, "char", 2)
    cv.poly([(119, G - 30), (122, G - 36), (125, G - 30)], "char", 3)
    # 横梁斜着搭在柱子上
    cv.disc_line((14, G - 54), (84, G - 58), 2.0, 2.0, "char", 2)
    # 塌下来的茅草顶
    roof = cv.mask_poly([(70, G - 50), (144, G - 4), (140, G), (86, G), (64, G - 30)])
    thatch(cv, roof, r, band=6)
    # 烧焦：越往下越黑，散几道焦痕
    ys_, xs_ = np.nonzero(roof)
    for y, x in zip(ys_, xs_):
        if r.random() < (y - (G - 50)) / 70.0:
            cv.put(x, y, "char", int(cv.lv[y, x]))
    # 露出来的椽子
    for k in range(5):
        cv.line(76 + k * 12, G - 46 + k * 7, 88 + k * 12, G - 54 + k * 7, "char", 2)
    # 碎木堆
    for _ in range(14):
        x, y = int(r.integers(30, 140)), G - int(r.integers(0, 5))
        L = int(r.integers(6, 16))
        a = r.uniform(-0.5, 0.5)
        cv.line(x, y, x + L * math.cos(a), y - L * math.sin(a) - 2, "char" if r.random() < 0.6 else "oldwood", int(r.integers(1, 3)))
    cv.outline()
    cv.rim(-1)
    return cv, dict(meta, origin=[W // 2, G])


def storehouse(seed=5):
    """土仓：厚厚的白灰墙，下半截海鼠壁（斜方格的瓦片），高处一扇小铁窗，瓦顶。"""
    r = rng(seed)
    W, H = 96, 128
    G = H - 1
    cv = Canvas(W, H)
    x0, x1 = 14, 82
    top = G - 78
    meta = {"windows": [], "smoke": []}
    plaster(cv, x0, top, x1, G - 26, r, "plaster", 0.9)
    # 海鼠壁
    cv.rect(x0, G - 26, x1 - x0, 22, "tile", 2)
    for y in range(G - 26, G - 4):
        for x in range(x0, x1):
            u, v = (x + y) % 8, (x - y) % 8
            if u == 0 or v == 0:
                cv.put(x, y, "plaster", 3 if u == 0 else 2)
            elif u == 1 or v == 7:
                cv.put(x, y, "tile", 1)
    cv.rect(x0, G - 27, x1 - x0, 1, "plaster", 1)
    # 铁窗
    wx, wy = 38, top + 14
    cv.rect(wx - 3, wy - 3, 26, 18, "plaster", 3)
    cv.rect(wx - 3, wy + 15, 26, 1, "plaster", 1)
    cv.rect(wx, wy, 20, 12, "VOID", 1)
    for gx in range(wx + 3, wx + 20, 4):
        cv.rect(gx, wy, 1, 12, "iron", 2)
    meta["windows"].append([wx, wy, 20, 12])
    # 门：厚木门，铁钉
    cv.rect(36, G - 34, 24, 30, "wood", 2)
    planks_v(cv, 36, G - 34, 60, G - 4, "wood", r, w=6)
    for yy in (G - 30, G - 18, G - 8):
        cv.rect(36, yy, 24, 2, "iron", 2)
        for xx in range(38, 60, 5):
            cv.put(xx, yy, "iron", 4)
    stones_row(cv, x0 - 3, x1 + 3, G - 4, G + 1, r)
    roof_tiles(cv, 4, W - 4, top + 2, top - 26, 14, r, ridge_h=7)
    shadow_band(cv, x0, x1, top, 6)
    cv.outline()
    cv.rim(-1)
    return cv, dict(meta, origin=[W // 2, G])


# ---------- 树 ----------

def _branches(cv, a, ang, length, rad, depth, r, out):
    if depth == 0 or length < 3 or rad < 0.4:
        return
    b = (a[0] + math.sin(ang) * length, a[1] - math.cos(ang) * length)
    out.append(cv.disc_line(a, b, rad, max(0.45, rad * 0.62), "bark", 2))
    n = 2 if depth > 1 else 1
    for k in range(n):
        da = r.uniform(0.25, 0.75) * (1 if k == 0 else -1) * (1 if r.random() < 0.5 else -1)
        _branches(cv, b, ang + da + r.uniform(-0.15, 0.15), length * r.uniform(0.55, 0.78), rad * 0.62, depth - 1, r, out)
    # 末梢的小枝杈
    if depth <= 2:
        for _ in range(2):
            cv.line(b[0], b[1], b[0] + r.uniform(-5, 5), b[1] - r.uniform(2, 6), "bark", 1)


def dead_tree(seed=1, h=110):
    """枯树：扭着长的树干，分几叉，枝梢细到一像素；左边受光，树皮竖纹。"""
    r = rng(seed)
    W, H = 200, h + 60
    G = H - 1
    cv = Canvas(W, H)
    parts = []
    cx = W / 2
    pts = [(cx, G)]
    x, y = cx, G
    seg = 4
    for i in range(seg):
        x += r.uniform(-7, 7)
        y -= h * 0.5 / seg
        pts.append((x, y))
    for i in range(len(pts) - 1):
        t = i / (len(pts) - 1)
        parts.append(cv.disc_line(pts[i], pts[i + 1], 6.5 - 3 * t, 6.5 - 3 * (t + 1 / seg), "bark", 2))
    # 根
    for d in (-1, 1):
        parts.append(cv.disc_line((cx + d * 3, G - 6), (cx + d * 14, G + 1), 2.5, 1.0, "bark", 2))
    top = pts[-1]
    _branches(cv, top, r.uniform(-0.2, 0.2), h * 0.32, 3.4, 5, r, parts)
    _branches(cv, pts[-2], -0.9 - r.uniform(0, 0.4), h * 0.34, 2.6, 4, r, parts)
    _branches(cv, pts[-3], 0.9 + r.uniform(0, 0.4), h * 0.3, 2.4, 4, r, parts)
    m = cv.mat >= 0
    cv.shade_runs(m, 0.3, 0.66)
    # 树皮纹
    ys, xs = np.nonzero(m)
    for _ in range(len(xs) // 12):
        k = int(r.integers(0, len(xs)))
        y, x = ys[k], xs[k]
        for d in range(int(r.integers(2, 6))):
            if cv.filled(x, y + d) and cv.lv[y + d, x] >= 2:
                cv.lv[y + d, x] = 1
    # 树洞
    hy = int(G - h * 0.25)
    cv.ellipse(cx + 1, hy, 2, 3, "VOID", 1)
    cv.outline()
    cv.rim(-1)
    return cv.trim({"origin": [W // 2, G]})


def pine(seed=3, h=120):
    """松树：歪着长的树干，几层平平的松针团，团的上沿受光，下沿压暗。"""
    r = rng(seed)
    W, H = 170, h + 30
    G = H - 1
    cv = Canvas(W, H)
    cx = W * 0.45
    pts = [(cx, G), (cx + 6, G - h * 0.3), (cx - 2, G - h * 0.55), (cx + 10, G - h * 0.78), (cx + 4, G - h * 0.95)]
    for i in range(len(pts) - 1):
        cv.disc_line(pts[i], pts[i + 1], 5.5 - i * 1.1, 4.4 - i * 1.1, "bark", 2)
    cv.shade_runs(cv.mat >= 0, 0.3, 0.66)
    pads = [(pts[1], 0.9, -1), (pts[2], 1.0, 1), (pts[3], 0.85, -1), (pts[4], 0.7, 1), (pts[2], 0.7, -1)]
    for (px, py), s, d in pads:
        tx, ty = px + d * 22 * s, py - 6
        cv.disc_line((px, py), (tx, ty), 1.6, 1.0, "bark", 2)
        rx, ry = 26 * s, 9 * s
        mm = np.zeros_like(cv.mat, bool)
        for k in range(7):
            ox = (k / 6.0 - 0.5) * 2 * rx * 0.8 + r.uniform(-3, 3)
            oy = -abs(ox) * 0.18 + r.uniform(-2, 1)
            er = rx * r.uniform(0.28, 0.42)
            mm |= cv.ellipse(tx + ox, ty - 3 + oy, er, ry * r.uniform(0.6, 0.9), "leaf", 2)
        ys, xs = np.nonzero(mm)
        for y, x in zip(ys, xs):
            above = sum(1 for d in (1, 2, 3) if mm[max(0, y - d), x])
            below = sum(1 for d in (1, 2, 3) if mm[min(cv.h - 1, y + d), x])
            lv = 2
            if above <= 1:
                lv = 3 if above == 1 else 4
            elif below <= 1:
                lv = 1
            cv.lv[y, x] = lv
        # 针叶簇：一小撮一小撮的亮横线，下面跟一道暗
        for _ in range(int(rx * 1.2)):
            k = int(r.integers(0, len(xs)))
            y, x = ys[k], xs[k]
            if cv.lv[y, x] == 2:
                for d in range(int(r.integers(2, 5))):
                    if mm[y, min(cv.w - 1, x + d)]:
                        cv.lv[y, x + d] = 3
                        if mm[min(cv.h - 1, y + 1), x + d] and cv.lv[y + 1, x + d] == 2:
                            cv.lv[y + 1, x + d] = 1
        # 下沿锯齿：针叶一簇簇垂下来
        for x in range(int(tx - rx), int(tx + rx)):
            col = np.nonzero(mm[:, max(0, min(cv.w - 1, x))])[0]
            if len(col) and (x * 7) % 5 < 2:
                cv.put(x, col.max() + 1, "leaf", 1)
    cv.outline()
    cv.rim(-1)
    return cv.trim({"origin": [int(cx), G]})


# ---------- 篱笆 ----------

def fence(seed=1, broken=False):
    """木篱笆：几根歪立的木桩，两道横杆用草绳绑着，断的那段横杆垂到地上。"""
    r = rng(seed)
    W, H = 72, 30
    G = H - 1
    cv = Canvas(W, H)
    xs = [4, 20, 38, 54, 68]
    tops = []
    for i, x in enumerate(xs):
        h = int(r.integers(18, 26))
        lean = r.uniform(-2, 2)
        if broken and i == 3:
            h = 10
        cv.disc_line((x, G), (x + lean, G - h), 1.6, 1.4, "oldwood", 2)
        tops.append((x + lean, G - h))
    cv.shade_runs(cv.mat >= 0, 0.34, 0.66)
    for k, yy in enumerate((G - 16, G - 8)):
        if broken and k == 0:
            cv.line(xs[0], yy, xs[3] - 2, yy + 1, "oldwood", 2, 2)
            cv.line(xs[3] - 2, yy + 1, xs[4] + 2, G, "oldwood", 2, 2)
        else:
            cv.line(xs[0] - 2, yy, xs[-1] + 2, yy - 1, "oldwood", 2, 2)
            cv.line(xs[0] - 2, yy, xs[-1] + 2, yy - 1, "oldwood", 3)
        for x in xs:
            cv.put(x - 1, yy, "rope", 3)
            cv.put(x + 1, yy + 1, "rope", 2)
    for (tx, ty) in tops:
        cv.put(tx, ty, "oldwood", 4)
    cv.outline()
    cv.rim(-1)
    return cv, {"origin": [W // 2, G]}


# ---------- 地面 ----------

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
GROUND_TOP = 8      # 贴图最上面 8 行是冒出地面的草


def stamp(dst, src, ox, oy, wrap=False):
    """把 src 的实心像素盖到 dst 上；wrap 时左右越界的部分绕回来（拼接贴图用）。"""
    ys, xs = np.nonzero(src.mat >= 0)
    for y, x in zip(ys, xs):
        tx, ty = x + ox, y + oy
        if wrap:
            tx %= dst.w
        if dst.inside(tx, ty):
            dst.mat[ty, tx] = src.mat[y, x]
            dst.lv[ty, tx] = src.lv[y, x]


def rock(seed, w, h, mat="stone"):
    r = rng(seed)
    cv = Canvas(w + 2, h + 2)
    pts = []
    n = 9
    for k in range(n):
        a = k / n * math.tau
        rr = 1 - r.uniform(0, 0.22)
        pts.append((1 + w / 2 + math.cos(a) * w / 2 * rr, 1 + h / 2 + math.sin(a) * h / 2 * rr))
    m = cv.poly(pts, mat, 2)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        u = (x - 1) / w - 0.5
        v = (y - 1) / h - 0.5
        d = -u * 0.6 - v
        lv = 3 if d > 0.35 else (1 if d < -0.25 else 2)
        if d > 0.62:
            lv = 4
        cv.lv[y, x] = lv
    for _ in range(max(1, w // 6)):
        k = int(r.integers(0, len(xs)))
        cv.put(xs[k], ys[k], mat, 1)
    cv.outline()
    return cv


def ground_tile(seed=1, W=128):
    """能左右无缝拼接的地面：最上面一层草皮（草叶冒出地面、草根垂下来），
    下面是土，越往下越暗（用拜耳点阵过渡，不出色带），土里埋着石头和草根，中间一道碎石层。"""
    r = rng(seed)
    H = GROUND_TOP + 60
    cv = Canvas(W, H)
    T = GROUND_TOP
    for y in range(T, H):
        d = (y - T) / (H - T)
        for x in range(W):
            # 深度 -> 亮度阶，阶与阶之间点阵过渡
            f = 2.6 - d * 2.4
            lv = int(f) + (1 if (f - int(f)) > BAYER4[y % 4, x % 4] else 0)
            cv.put(x, y, "dirt", max(0, min(3, lv)))
    # 碎石层
    for y0 in (T + 18, T + 34):
        for x in range(W):
            if r.random() < 0.35:
                cv.put(x, y0 + int(r.integers(-1, 2)), "stone", 1)
        for _ in range(W // 10):
            x = int(r.integers(0, W))
            cv.put(x, y0, "stone", 3)
            cv.put(x + 1, y0, "stone", 2)
    # 埋着的石头
    for k in range(5):
        w, h = int(r.integers(5, 12)), int(r.integers(4, 7))
        st = rock(seed * 31 + k, w, h)
        stamp(cv, st, int(r.integers(0, W)), int(r.integers(T + 6, H - 10)), wrap=True)
    # 草根
    for _ in range(W // 12):
        x, y = int(r.integers(0, W)), T + 3
        for _ in range(int(r.integers(4, 12))):
            cv.put(x % W, y, "bark", 1)
            x += int(r.integers(-1, 2))
            y += 1
    # 草皮：地面线下 3 行是草，往下一截截垂着草根
    for x in range(W):
        cv.put(x, T, "grass", 4 if r.random() < 0.3 else 3)
        cv.put(x, T + 1, "grass", 2)
        cv.put(x, T + 2, "grass", 2 if r.random() < 0.6 else 1)
        hang = int(r.integers(0, 4))
        for d in range(hang):
            cv.put(x, T + 3 + d, "grass", 1)
        cv.put(x, T + 3 + hang, "dirt", 0 if hang else 1)
    # 冒出地面的草叶
    for _ in range(W // 2):
        x = int(r.integers(0, W))
        h = int(r.integers(1, 7))
        lean = r.choice([-1, 0, 0, 1])
        mat = "dry" if r.random() < 0.25 else "grass"
        for d in range(h):
            xx = (x + (lean if d > h // 2 else 0)) % W
            cv.put(xx, T - 1 - d, mat, 3 if d == h - 1 else 2)
    return cv, {"origin": [0, T], "tile": True}


def tuft(seed=1, w=16, h=10, dry=False):
    """一簇草：从一点散开的弯草叶，叶尖受光。"""
    r = rng(seed)
    cv = Canvas(w + 4, h + 3)
    G = h + 1
    cx = (w + 4) / 2
    for k in range(int(w * 0.9)):
        a = r.uniform(-1.1, 1.1)
        L = h * r.uniform(0.5, 1.0) * (1 - abs(a) * 0.3)
        bend = r.uniform(-0.3, 0.3) + a * 0.5
        x, y = cx + r.uniform(-2, 2), G
        n = int(L)
        mat = "dry" if (dry or r.random() < 0.15) else "grass"
        for i in range(n):
            t = i / max(1, n)
            x += math.sin(a + bend * t)
            y -= math.cos(a + bend * t)
            lv = 3 if t > 0.7 else (2 if t > 0.25 else 1)
            cv.put(x, y, mat, lv)
    cv.outline()
    cv.rim(-1)
    return cv.trim({"origin": [int(cx), G]})


def rock_piece(seed, w, h):
    st = rock(seed, w, h)
    cv = Canvas(st.w, st.h + 1)
    stamp(cv, st, 0, 0)
    cv.rim(-1)
    return cv, {"origin": [st.w // 2, st.h - 2]}


# ---------- 远景 ----------

def far_house(seed=1, kind="thatch"):
    """远处的屋子：轮廓清楚、细节少。墙一个暗阶，屋顶两阶，檐口一道亮线，黑门洞。"""
    r = rng(seed)
    w = int(r.integers(40, 64))
    wh = int(r.integers(14, 22))
    W, H = w + 16, wh + 34
    G = H - 1
    cv = Canvas(W, H)
    x0, x1 = 8, 8 + w
    cv.rect(x0, G - wh, w, wh, "mud" if kind == "thatch" else "plaster", 1)
    cv.rect(x0, G - wh, 1, wh, "mud" if kind == "thatch" else "plaster", 2)
    for px in range(x0, x1, int(r.integers(12, 18))):
        cv.rect(px, G - wh, 2, wh, "char", 1)
    dx = x0 + int(r.integers(6, max(7, w - 14)))
    cv.rect(dx, G - wh + 5, 7, wh - 5, "VOID", 1)
    wx = x0 + 4 if dx > x0 + w // 2 else x1 - 12
    cv.rect(wx, G - wh + 4, 6, 4, "VOID", 1)
    meta = {"windows": [[wx, G - wh + 4, 6, 4], [dx, G - wh + 5, 7, wh - 5]], "smoke": []}
    eave = G - wh + 1
    rh = int(r.integers(12, 20))
    broken = r.random() < 0.35
    pts = [(1, eave), (x0 + 8, eave - rh), (x1 - 8, eave - rh), (W - 2, eave)]
    if kind == "thatch":
        m = cv.poly(pts, "thatch", 2)
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            cv.lv[y, x] = 1 if (y - (eave - rh)) % 5 == 0 else (3 if x < x0 + 6 else 2)
        cv.rect(1, eave - 1, W - 3, 2, "thatch", 3)
    else:
        m = cv.mask_poly(pts)
        tiles(cv, m, r, row_h=4)
        cv.rect(x0 + 5, eave - rh - 3, w - 10, 3, "tile", 2)
        cv.rect(x0 + 5, eave - rh - 3, w - 10, 1, "tile", 3)
    if broken:
        hx = int(r.integers(x0 + 8, x1 - 8))
        cv.poly([(hx - 6, eave - 1), (hx - 2, eave - rh + 2), (hx + 3, eave - rh + 5), (hx + 6, eave - 1)], "VOID", 1)
        meta["smoke"].append([hx, eave - rh + 3])
    cv.outline()
    cv.rim(-1)
    return cv, dict(meta, origin=[W // 2, G])


def watchtower(seed=1):
    """远处的望楼：四根细腿、斜撑、上面一个带顶的小台子。"""
    r = rng(seed)
    W, H = 34, 86
    G = H - 1
    cv = Canvas(W, H)
    for x, lean in ((8, 3), (25, -3)):
        cv.line(x, G, x + lean, 26, "oldwood", 1, 2)
    for y in range(G - 12, 30, -16):
        cv.line(10, y, 24, y - 12, "oldwood", 1)
        cv.line(24, y, 10, y - 12, "oldwood", 1)
        cv.line(10, y, 24, y, "oldwood", 2)
    cv.rect(6, 20, 22, 7, "oldwood", 2)
    planks_v(cv, 6, 20, 28, 27, "oldwood", r, w=3)
    cv.poly([(2, 18), (17, 6), (32, 18)], "thatch", 2)
    cv.rect(2, 17, 31, 2, "thatch", 3)
    cv.rect(4, 14, 3, 1, "thatch", 3)
    cv.rect(12, 9, 3, 1, "thatch", 3)
    cv.outline()
    cv.rim(-1)
    return cv, {"origin": [W // 2, G], "windows": [[10, 21, 14, 5]], "smoke": []}


# ---------- 前景 ----------

def front_clump(seed=1, w=70, h=52, reeds=False):
    """镜头最前面的草丛：长草叶从底边弯上来，几根带穗的芦苇。画出来几乎是剪影，只留一点轮廓光。"""
    r = rng(seed)
    W, H = w + 30, h + 4
    G = H - 1
    cv = Canvas(W, H)
    for k in range(int(w * 0.55)):
        bx = 15 + r.uniform(0, w)
        a = r.uniform(-0.7, 0.7)
        L = h * r.uniform(0.35, 1.0)
        bend = a * r.uniform(0.6, 1.6)
        x, y = bx, G
        n = int(L)
        for i in range(n):
            t = i / max(1, n)
            wdt = 3 if t < 0.3 else (2 if t < 0.65 else 1)
            for d in range(wdt):
                cv.put(x + d, y, "grass", 2 if t > 0.5 else 1)
            x += math.sin(a + bend * t)
            y -= math.cos(a + bend * t)
    if reeds:
        for k in range(3):
            bx = 15 + r.uniform(w * 0.2, w * 0.8)
            top = G - h * r.uniform(0.85, 1.0)
            lean = r.uniform(-8, 8)
            cv.line(bx, G, bx + lean, top, "dry", 2)
            cv.disc_line((bx + lean, top), (bx + lean * 1.15, top - 8), 1.6, 0.8, "dry", 3)
    cv.outline()
    cv.rim(-1)
    return cv.trim({"origin": [W // 2, G]})


PIECES = {
    "house_thatch": lambda: house_thatch(3),
    "house_thatch_b": lambda: house_thatch(7, broken=True),
    "house_tile": lambda: house_tile(2),
    "house_ruin": lambda: house_ruin(4),
    "storehouse": lambda: storehouse(5),
    "tree_dead": lambda: dead_tree(1, 110),
    "tree_dead_b": lambda: dead_tree(9, 90),
    "pine": lambda: pine(3),
    "fence": lambda: fence(1),
    "fence_b": lambda: fence(2, True),
    "ground": lambda: ground_tile(1),
    "tuft_a": lambda: tuft(1, 16, 10),
    "tuft_b": lambda: tuft(2, 22, 13),
    "tuft_c": lambda: tuft(3, 12, 8, dry=True),
    "tuft_d": lambda: tuft(4, 18, 16, dry=True),
    "rock_a": lambda: rock_piece(5, 12, 7),
    "rock_b": lambda: rock_piece(6, 7, 5),
    "far_a": lambda: far_house(1, "thatch"),
    "far_b": lambda: far_house(2, "tile"),
    "far_c": lambda: far_house(3, "thatch"),
    "far_d": lambda: far_house(5, "tile"),
    "far_e": lambda: far_house(8, "thatch"),
    "tower": lambda: watchtower(1),
    "front_a": lambda: front_clump(1, 70, 52),
    "front_b": lambda: front_clump(2, 50, 40, True),
    "front_c": lambda: front_clump(3, 90, 64, True),
}

# 每个件画在哪一层：决定雾和压暗的程度
LAYER = {"near": {"fog": 0.3}, "far": {"fog": 0.52}, "ground": {"fog": 0.0}, "front": {"fog": 0.0, "dark": 0.72}}


def layer_of(name):
    if name.startswith("far_") or name == "tower":
        return "far"
    if name.startswith("front_"):
        return "front"
    if name == "ground" or name.startswith("tuft_") or name.startswith("rock_"):
        return "ground"
    return "near"
