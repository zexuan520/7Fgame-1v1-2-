"""第一幕每层独有小怪的手持物（程序生成体素，和 weapon/*.json 同格式：握把在原点，尖端朝 -y，一格 0.5 像素）。
python tools/voxelize/gen_act1_props.py  →  assets/voxel/weapon/shroom.json（瘴菇骨）、coffin_lid.json（抬棺骨）、bell_h.json（铜钟僧）"""
import json, math, os, random

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


def shaft(cells, y0, y1, col, r=1):
    for y in range(y0, y1 + 1):
        for x in range(-r, r + 1):
            for z in range(-r, r + 1):
                cells[(x, y, z)] = jit(col, 6)


# 瘴菇：一根歪歪的菌柄，顶上一朵毒绿色大菌盖，盖上几颗淡黄斑点（格子粗，缩小后还看得清）
sh = {}
for y in range(-24, 8):
    off = int(round(1.2 * math.sin(y * 0.18)))
    for x in range(-2, 3):
        for z in range(-2, 3):
            if x * x + z * z <= 5:
                sh[(x + off, y, z)] = jit((214, 206, 170), 8)
for y in range(-40, -23):
    t = (y + 40) / 16.0                # 0 顶 → 1 盖沿
    rr = 4.0 + 9.0 * math.sin(min(t, 1.0) * math.pi * 0.5)
    for x in range(-13, 14):
        for z in range(-13, 14):
            d2 = x * x + z * z
            if d2 <= rr * rr and (t > 0.75 or d2 >= (rr - 3.0) ** 2 or y < -37):
                spot = (x * 7 + z * 13 + y * 3) % 23 == 0 or ((x + 4) ** 2 + (z - 3) ** 2 < 5 and y < -33)
                c = (232, 220, 120) if spot else ((98, 168, 62) if t < 0.85 else (62, 110, 46))
                sh[(x, y, z)] = jit(c, 10)
save("shroom", sh)

# 棺盖：一块竖着的厚木板（x 方向是厚度、z 方向是宽度，盾面朝前），上面贴一道黄符、一枚朱印
cl = {}
for y in range(-30, 31):
    w = 11 if y < 18 else 11 - (y - 18) // 3        # 下头窄一点（棺材盖是一头宽一头窄）
    for z in range(-w, w + 1):
        for x in range(-2, 2):
            edge = abs(z) >= w - 1 or y in (-30, 30)
            c = (58, 38, 28) if edge else (88, 58, 40)
            if (y + 30) % 9 == 0 and not edge:
                c = (66, 44, 32)
            # 黄符：中间一竖条
            if x == -2 and abs(z) <= 2 and -22 <= y <= 8:
                c = (226, 196, 92)
                if y % 4 == 0 and z == 0:
                    c = (150, 40, 32)
            # 朱印
            if x == -2 and (z - 5) ** 2 + (y + 18) ** 2 <= 6:
                c = (186, 40, 32)
            cl[(x, y, z)] = jit(c, 6)
save("coffin_lid", cl)

# 钟杖：一根锡杖似的长杆，杆头吊一口铜钟（钟口朝下 = 朝 -y 的尖端），钟身两道箍
bl = {}
shaft(bl, -58, 20, (96, 70, 44))
for y in range(-62, -58):
    bl[(0, y, 0)] = (70, 60, 50)
for y in range(-84, -62):
    t = (y + 84) / 22.0               # 0 钟口 → 1 钟顶
    rr = 9.5 - 5.0 * t ** 1.4
    for x in range(-10, 11):
        for z in range(-10, 11):
            d2 = x * x + z * z
            if d2 <= rr * rr and (d2 >= (rr - 2.2) ** 2 or t > 0.85):
                c = (176, 128, 56)
                if y in (-80, -79, -70, -69):
                    c = (120, 84, 36)
                if x < -3 and z > 2:
                    c = (220, 176, 92)          # 一侧高光
                bl[(x, y, z)] = jit(c, 8)
for y in range(-88, -82):
    for x in range(-1, 2):
        for z in range(-1, 2):
            bl[(x, y, z)] = jit((140, 100, 44), 6)   # 钟舌
save("bell_h", bl)
