"""把主角的动作表画成精灵表。

  python3 tools/sprites/build.py              生成 assets/sprites/heroine.png（1P）、heroine_p2.png（2P 青衣）和 heroine.json
  python3 tools/sprites/build.py --preview 目录 [动作名...]   另外输出放大的预览动图和逐帧对照图

精灵表每格 W x H，脚底中心在格子里的 (OX, OY)。JSON 记下每个动作的帧号、每帧毫秒、是否循环、剑尖位置。
"""
import json
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import heroine as hz
import anims
from rig import RAMPS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLS = 16

# 2P：同一个人物，粉色换成青色
P2_SWAP = {
    "7a2e52": "1e4a64", "b95f84": "3e7494", "ea8cad": "6aa8c8", "fbc4d6": "a8d8e8",
    "7a3a58": "2a5a78", "d07898": "6ab0d0", "f4aac6": "a8dcf0", "fff0f6": "e8faff",
    "240a18": "0e2030", "4a1a32": "1a3448", "6a2846": "2a5070", "9a4a6c": "4a7a98",
    "2a0e1c": "0e1e2c", "5a2040": "1e3a52", "7a3050": "2a5070", "a04a70": "4a7a98",
    "8a2048": "8a8aa0", "c43e6e": "c8c8dc", "f2608f": "f4f0f8", "ffa0c0": "ffffff",
    "ec8a9a": "e8a0a8", "b85a70": "b06a78",
}


def render_anim(a):
    frames = a["frames"]
    poses = [f[0] for f in frames]
    durs = [f[1] / 1000.0 for f in frames]
    sk = [hz.skeleton(p) for p in poses]
    roots = [s["bun"] for s in sk]
    wind = a.get("wind") or [(0.0, 0.0)] * len(frames)
    wind = [(-(a.get("speed", 0.0)) * 0.3 + w[0], w[1]) for w in wind]
    speed = a.get("speed", 0.0)
    hairs = hz.simulate_hair(roots, durs, wind, a.get("loop", False), [speed * d * 0.22 for d in durs])
    out = []
    for f, p, h in zip(frames, poses, hairs):
        opt = f[2] if len(f) > 2 else {}
        img, meta = hz.draw(p, h, smear=opt.get("smear"), flip=opt.get("flip", False))
        out.append((img, meta))
    return out


def swap(img, table):
    px = img.load()
    out = img.copy()
    po = out.load()
    cache = {}
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            key = "%02x%02x%02x" % c[:3]
            if key in table:
                if key not in cache:
                    h = table[key]
                    cache[key] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
                po[x, y] = cache[key]
    return out


def build_all(names=None):
    A = anims.build()
    if names:
        A = {k: v for k, v in A.items() if k in names}
    rendered = {k: render_anim(v) for k, v in A.items()}
    return A, rendered


def write_assets(A, rendered):
    total = sum(len(v) for v in rendered.values())
    rows = (total + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * hz.W, rows * hz.H), (0, 0, 0, 0))
    data = {"frame": [hz.W, hz.H], "origin": [hz.OX, hz.OY], "cols": COLS, "anims": {}}
    i = 0
    for name, frames in rendered.items():
        idx, tips, hbs = [], [], []
        for img, meta in frames:
            sheet.alpha_composite(img, ((i % COLS) * hz.W, (i // COLS) * hz.H))
            idx.append(i)
            t = meta.get("tip")
            tips.append([round(t[0], 1), round(t[1], 1)] if t else None)
            hbs.append([round(meta["hand_b"][0], 1), round(meta["hand_b"][1], 1)])
            i += 1
        data["anims"][name] = {"frames": idx, "ms": [f[1] for f in A[name]["frames"]],
                               "loop": A[name].get("loop", False), "tips": tips, "hb": hbs}
        for key in ("events", "phases"):
            if A[name].get(key):
                data["anims"][name][key] = A[name][key]
    out_dir = os.path.join(ROOT, "assets", "sprites")
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "heroine.png"))
    swap(sheet, P2_SWAP).save(os.path.join(out_dir, "heroine_p2.png"))
    with open(os.path.join(out_dir, "heroine.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("%d 帧，%d 个动作" % (i, len(rendered)))


def write_previews(A, rendered, out, scale=5, box=(10, 14, 110, 86)):
    os.makedirs(out, exist_ok=True)
    bg = (44, 38, 62, 255)
    for name, frames in rendered.items():
        tiles = []
        for img, _ in frames:
            t = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), bg)
            t.alpha_composite(img.crop(box))
            # 地面线
            for x in range(t.width):
                t.putpixel((x, hz.OY - box[1]), (70, 62, 92, 255))
            tiles.append(t.resize((t.width * scale, t.height * scale), Image.NEAREST))
        durs = [f[1] for f in A[name]["frames"]]
        tiles[0].save(os.path.join(out, name + ".gif"), save_all=True, append_images=tiles[1:],
                      duration=durs, loop=0, disposal=2)
        # 逐帧对照图
        w, h = tiles[0].size
        strip = Image.new("RGBA", (w * len(tiles) + 4 * (len(tiles) - 1), h), (16, 12, 24, 255))
        for k, t in enumerate(tiles):
            strip.alpha_composite(t, (k * (w + 4), 0))
        strip.save(os.path.join(out, name + "_strip.png"))


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--preview":
        out = args[1]
        A, R = build_all(args[2:] or None)
        write_previews(A, R, out)
    else:
        A, R = build_all()
        write_assets(A, R)
