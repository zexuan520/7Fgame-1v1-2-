"""开发用：敌人几个姿势拼一张放大图"""
import sys
from PIL import Image, ImageDraw
import humanoid as hu
import enemies as en

def sheet(rows, path, scale=4, box=(16, 8, 112, 92)):
    tiles = []
    for kind, names in rows:
        C = en.COSTUMES[kind]
        row = []
        for n in names:
            img, _ = hu.draw(en.get(kind, n), C, tails=hu.default_tails(hu.skeleton(en.get(kind, n), C)["tails"]))
            t = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (44, 38, 62, 255))
            t.alpha_composite(img.crop(box))
            for x in range(t.width):
                t.putpixel((x, hu.OY - box[1]), (70, 62, 92, 255))
            row.append(t)
        tiles.append(row)
    w, h = tiles[0][0].size
    cols = max(len(r) for r in tiles)
    out = Image.new("RGBA", (cols * (w + 2), len(tiles) * (h + 2)), (10, 8, 16, 255))
    for y, r in enumerate(tiles):
        for x, t in enumerate(r):
            out.alpha_composite(t, (x * (w + 2), y * (h + 2)))
    out.resize((out.width * scale, out.height * scale), Image.NEAREST).save(path)

if __name__ == "__main__":
    S = sys.argv[1]
    sheet([("ronin", ["shoulder", "stalk", "raise1", "cut1"]),
           ("archer", ["bow_idle", "bow_ready", "bow_draw", "kick"]),
           ("shield", ["shield_stance", "bash", "spear_prep", "spear"]),
           ("liu", ["liu_calm", "st_gedan", "grab_reach", "iai_cut"]),
           ("tutor", ["st_gedan", "raise1", "sweep_cut", "hit"])], S)
