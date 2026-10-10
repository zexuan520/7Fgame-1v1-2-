"""荒村场景件的预览：每个件按几种天色各画一张，放大拼在一起。
  python3 tools/sprites/vpreview.py 输出.png [件名...] [--moods dusk,night]"""
import sys
from PIL import Image
import village as V
from scenery import MOODS

BG = {"dusk": (122, 44, 69), "night": (22, 33, 62), "fog": (132, 140, 150), "graves": (26, 42, 38),
      "bamboo": (30, 64, 40), "camp": (62, 18, 20)}

def main():
    args = sys.argv[1:]
    out = args.pop(0)
    moods = ["dusk", "night", "fog"]
    if "--moods" in args:
        i = args.index("--moods")
        moods = args[i + 1].split(",")
        del args[i:i + 2]
    src = V.PIECES
    layer = lambda n: V.LAYER[V.layer_of(n)]
    if "--props" in args:
        args.remove("--props")
        import props as PR
        src = PR.PIECES
        layer = lambda n: {"fog": 0.0}
    names = args or list(src)
    scale = int(dict(a.split("=") for a in []).get("s", 3)) if False else 3
    rows = []
    for n in names:
        cv, meta = src[n]()
        L = layer(n)
        tiles = []
        for m in moods:
            t = Image.new("RGBA", (cv.w + 8, cv.h + 8), BG[m] + (255,))
            t.alpha_composite(cv.render(m, L["fog"], flip=MOODS[m]["side"] > 0 and src is V.PIECES, dark=L.get("dark", 0.0)), (4, 4))
            tiles.append(t.resize((t.width * scale, t.height * scale), Image.NEAREST))
        rows.append(tiles)
    W = max(sum(t.width for t in r) for r in rows)
    H = sum(r[0].height for r in rows)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    y = 0
    for r in rows:
        x = 0
        for t in r:
            img.alpha_composite(t, (x, y))
            x += t.width
        y += r[0].height
    img.save(out)

main()
