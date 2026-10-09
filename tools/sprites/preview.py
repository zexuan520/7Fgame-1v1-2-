"""开发用：把几个姿势画出来拼成一张放大图"""
import sys
from PIL import Image
import heroine as hz

def sheet(poses, path, scale=6, bg=(40, 34, 58, 255)):
    imgs = [hz.draw(p)[0] for p in poses]
    w, h = imgs[0].size
    out = Image.new("RGBA", (w * len(imgs), h), bg)
    for i, im in enumerate(imgs):
        out.alpha_composite(im, (i * w, 0))
    out.resize((out.width * scale, out.height * scale), Image.NEAREST).save(path)

if __name__ == "__main__":
    P = hz.pose
    sheet([P(), P(hf=(5.5, -21.5), hb=(-3, -14)), P(sw=1.9, hf=(7, -22), grip2=True, lean=0.15, hip=(0, -17), ff=(6, 0), fb=(-5, 0))], sys.argv[1])

def crop_sheet(poses, path, scale=8, box=(14, 22, 74, 78), bg=(40, 34, 58, 255), hairs=None):
    imgs = [hz.draw(p, hairs[i] if hairs else None)[0].crop(box) for i, p in enumerate(poses)]
    w, h = imgs[0].size
    out = Image.new("RGBA", (w * len(imgs) + 2 * (len(imgs) - 1), h), (20, 16, 30, 255))
    for i, im in enumerate(imgs):
        tile = Image.new("RGBA", im.size, bg)
        tile.alpha_composite(im)
        out.alpha_composite(tile, (i * (w + 2), 0))
    out.resize((out.width * scale, out.height * scale), Image.NEAREST).save(path)
