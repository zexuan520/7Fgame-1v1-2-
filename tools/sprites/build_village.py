"""把荒村场景件按每种天色打成图集。

  python3 tools/sprites/build_village.py
输出 assets/scenes/village_<天色>.png 和 village.json；房间摆设另出 props_<天色>.png 和 props.json。
JSON：pieces[名字] = {rect: [x, y, w, h], origin: [x, y], layer, windows, smoke}，
天色的光在右边时整张图已经翻转过，moods[天色][名字] 里是翻转后的 origin/windows/smoke。
"""
import json
import os
from PIL import Image
import village as V
from scenery import MOODS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ATLAS_W = 512


def pack(sizes):
    """按高度从大到小排成一行行。"""
    order = sorted(sizes, key=lambda k: -sizes[k][1])
    x = y = row_h = 0
    out = {}
    for k in order:
        w, h = sizes[k]
        if x + w > ATLAS_W:
            x, y, row_h = 0, y + row_h + 1, 0
        out[k] = [x, y, w, h]
        x += w + 1
        row_h = max(row_h, h)
    return out, y + row_h


def flip_meta(meta, w):
    m = {"origin": [w - 1 - meta["origin"][0], meta["origin"][1]]}
    m["windows"] = [[w - v[0] - v[2]] + list(v[1:]) for v in meta.get("windows", [])]
    m["smoke"] = [[w - 1 - v[0], v[1]] for v in meta.get("smoke", [])]
    return m


def main():
    pieces = {n: f() for n, f in V.PIECES.items()}
    rects, H = pack({n: (cv.w, cv.h) for n, (cv, _) in pieces.items()})
    out_dir = os.path.join(ROOT, "assets", "scenes")
    os.makedirs(out_dir, exist_ok=True)
    data = {"pieces": {}, "moods": {}}
    for n, (cv, meta) in pieces.items():
        data["pieces"][n] = {"rect": rects[n], "layer": V.layer_of(n), "tile": meta.get("tile", False)}
    for mood, M in MOODS.items():
        img = Image.new("RGBA", (ATLAS_W, H), (0, 0, 0, 0))
        flip = M["side"] > 0
        md = {}
        for n, (cv, meta) in pieces.items():
            L = V.LAYER[V.layer_of(n)]
            # 地面贴图不翻（翻了也一样能拼），其余跟着光翻
            f = flip and not meta.get("tile", False)
            im = cv.render(mood, L["fog"], flip=f, dark=L.get("dark", 0.0))
            x, y = rects[n][:2]
            img.alpha_composite(im, (x, y))
            m = flip_meta(meta, cv.w) if f else {"origin": meta["origin"], "windows": meta.get("windows", []),
                                                    "smoke": meta.get("smoke", [])}
            md[n] = m
        img.save(os.path.join(out_dir, "village_%s.png" % mood))
        data["moods"][mood] = md
    with open(os.path.join(out_dir, "village.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"), default=lambda o: o.item() if hasattr(o, "item") else o)
    print("%d 个件，图集 %dx%d，%d 种天色" % (len(pieces), ATLAS_W, H, len(MOODS)))
    build_props(out_dir)


def build_props(out_dir):
    """房间摆设：不翻转、不加雾，每种天色一张图集。"""
    import props as PR
    pieces = {n: f() for n, f in PR.PIECES.items()}
    rects, H = pack({n: (cv.w, cv.h) for n, (cv, _) in pieces.items()})
    data = {}
    for n, (cv, meta) in pieces.items():
        data[n] = {"rect": rects[n], "origin": meta["origin"], "windows": meta.get("windows", [])}
    for mood in MOODS:
        img = Image.new("RGBA", (ATLAS_W, H), (0, 0, 0, 0))
        for n, (cv, meta) in pieces.items():
            img.alpha_composite(cv.render(mood), tuple(rects[n][:2]))
        img.save(os.path.join(out_dir, "props_%s.png" % mood))
    with open(os.path.join(out_dir, "props.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"), default=lambda o: o.item() if hasattr(o, "item") else o)
    print("摆设 %d 个，图集 %dx%d" % (len(pieces), ATLAS_W, H))


if __name__ == "__main__":
    main()
