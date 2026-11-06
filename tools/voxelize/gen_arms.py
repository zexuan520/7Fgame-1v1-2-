"""新兵器的体素模型（程序生成，和 weapon/*.json 同格式：握把在原点，尖端朝 -y，一格 0.5 像素）。
python tools/voxelize/gen_arms.py  →  assets/voxel/weapon/hammer.json（镇岳锤）、twin_blade.json（鸳鸯双刀的一把）"""
import json, os, random

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "voxel", "weapon")
random.seed(11)


def save(name, cells):
    vox = []
    for (x, y, z), c in sorted(cells.items()):
        vox += [x, y, z, *c]
    xs = [k[0] for k in cells]; ys = [k[1] for k in cells]; zs = [k[2] for k in cells]
    d = {"vs": 0.5, "len": (max(ys) - min(ys) + 1) * 0.5,
         "size": [max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, max(zs) - min(zs) + 1],
         "min": [min(xs), min(ys), min(zs)], "vox": vox}
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(d, f, separators=(",", ":"))
    print(name, d["size"], len(cells))


def jit(c, a=8):
    return tuple(max(0, min(255, v + random.randint(-a, a))) for v in c)


# 镇岳锤：缠布木柄 + 方铁锤头（两面錾着回纹，四角包铜）
hm = {}
for y in range(-62, 14):
    wrap = (y % 6) in (0, 1) and y > -20
    for x in range(-2, 3):
        for z in range(-2, 3):
            if abs(x) == 2 and abs(z) == 2:
                continue
            hm[(x, y, z)] = jit((150, 40, 34) if wrap else (96, 66, 40), 6)
for y in range(-86, -60):
    for x in range(-15, 16):
        for z in range(-9, 10):
            edge = abs(x) >= 14 or abs(z) >= 8 or y in (-86, -85, -61, -62)
            corner = abs(x) >= 12 and (y < -82 or y > -65)
            if corner:
                c = (186, 140, 64)
            elif edge:
                c = (92, 96, 104)
            else:
                c = (128, 132, 140)
            # 回纹：锤面上刻一圈暗槽
            if abs(z) == 9 and (abs(x) == 9 or y in (-80, -67)) and -80 <= y <= -67 and abs(x) <= 9:
                c = (66, 70, 78)
            hm[(x, y, z)] = jit(c, 5)
save("hammer", hm)

# 鸳鸯双刀的一把：短直刀，红柄、铜护手、刀背一道血槽
tb = {}
for y in range(-2, 10):
    for x in range(-1, 2):
        for z in range(-1, 2):
            tb[(x, y, z)] = jit((140, 34, 30), 6)
for x in range(-5, 6):
    for z in range(-2, 3):
        for y in (-4, -3):
            tb[(x, y, z)] = jit((190, 146, 70), 6)
for y in range(-58, -4):
    t = (y + 58) / 54.0
    w = 3 if y > -50 else max(1, int(round(3 * (y + 58) / 8.0)))
    for x in range(-w, w + 1):
        c = (206, 210, 216) if x > -w else (150, 156, 166)
        if x == 0 and -46 < y < -8:
            c = (120, 126, 136)
        tb[(x, y, 0)] = jit(c, 5)
        if abs(x) < w:
            tb[(x, y, 1)] = jit((176, 180, 188), 5)
            tb[(x, y, -1)] = jit((176, 180, 188), 5)
save("twin_blade", tb)
