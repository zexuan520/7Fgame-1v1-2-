"""第二幕新小怪的手持物（程序生成体素，和 weapon/*.json 同格式：握把在原点，尖端朝 -y，一格 0.5 像素）。
python tools/voxelize/gen_act2_props.py  →  assets/voxel/weapon/spear.json、lantern_h.json、flag.json"""
import gzip, json, os, random

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "voxel", "weapon")
random.seed(7)


def save(name, cells):
    vox = []
    for (x, y, z), c in sorted(cells.items()):
        vox += [x, y, z, *c]
    xs = [k[0] for k in cells]; ys = [k[1] for k in cells]; zs = [k[2] for k in cells]
    d = {"vs": 0.5, "len": (max(ys) - min(ys) + 1) * 0.5,
         "size": [max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, max(zs) - min(zs) + 1],
         "min": [min(xs), min(ys), min(zs)], "vox": vox}
    with gzip.open(os.path.join(OUT, name + ".json.gz"), "wt", compresslevel=9) as f:   # 游戏读 .json.gz（VoxelModel.read_data）
        json.dump(d, f, separators=(",", ":"))
    print(name, d["size"], len(cells))


def jit(c, a=8):
    return tuple(max(0, min(255, v + random.randint(-a, a))) for v in c)


def shaft(cells, y0, y1, col, r=1):
    for y in range(y0, y1 + 1):
        for x in range(-r, r + 1):
            for z in range(-r, r + 1):
                cells[(x, y, z)] = jit(col, 6)


# 枪：木杆 + 叶形枪头 + 红缨
sp = {}
shaft(sp, -92, 22, (92, 62, 38))
for y in range(-112, -92):
    t = (y + 112) / 20.0          # 0 尖 → 1 根
    w = int(round(3.2 * min(t * 1.6, 1.0) * (1.0 if t < 0.7 else (1.0 - (t - 0.7) * 1.5))))
    for x in range(-w, w + 1):
        cells_c = (196, 200, 206) if abs(x) < max(w, 1) else (150, 156, 164)
        sp[(x, y, 0)] = jit(cells_c, 6)
        if abs(x) <= max(w - 1, 0):
            sp[(x, y, 1)] = jit((170, 175, 182), 6)
            sp[(x, y, -1)] = jit((170, 175, 182), 6)
for y in range(-92, -84):
    for x in range(-3, 4):
        for z in range(-3, 4):
            if x * x + z * z <= 9 - (y + 92) // 2 and random.random() < 0.85:
                sp[(x, y, z)] = jit((176, 36, 32), 12)
save("spear", sp)

# 灯童的灯：一根竹竿，竿头挂一盏纸灯（格子粗一点，缩小到 20 多像素长还看得清）
la = {}
shaft(la, -22, 8, (110, 86, 52))
for y in range(-26, -22):
    la[(0, y, 0)] = (60, 50, 40)
for y in range(-42, -26):
    for x in range(-7, 8):
        for z in range(-7, 8):
            rr = x * x + z * z
            lim = 49 - (abs(y + 34) ** 2) * 0.35
            if rr <= lim:
                edge = rr > lim - 14
                la[(x, y, z)] = jit((255, 226, 150) if not edge else (232, 170, 90), 6)
for y in (-27, -42):
    for x in range(-3, 4):
        for z in range(-3, 4):
            la[(x, y, z)] = (70, 52, 36)
save("lantern_h", la)

# 灰衣旗手的旗：长杆，杆头一面灰旗（旗上一盏红灯的纹样），旗面两面都有
import math
fl = {}
shaft(fl, -78, 8, (80, 66, 52))
for y in range(-78, -38):
    for x in range(2, 38):
        wave = int(round(1.5 * math.sin(x * 0.3)))
        c = (120, 122, 128)
        cx, cy = 20, -58
        r2 = (x - cx) ** 2 + ((y - cy) * 1.1) ** 2
        if r2 < 60:
            c = (196, 54, 40)
        elif r2 < 95:
            c = (86, 88, 94)
        if x > 34 and (y % 6) in (0, 1, 2):
            continue
        for xx in (wave, wave + 1):          # 旗面在 z 方向展开（举起来时正对镜头）
            fl[(xx, y, x)] = jit(c, 6)
save("flag", fl)
