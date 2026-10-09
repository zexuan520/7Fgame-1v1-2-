"""开发用：把所有动作的前几帧拼成几张总览图（放大 3 倍），方便一眼检查"""
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import build

def main(out, names=None, per=6, scale=3, box=(10, 10, 110, 86)):
    A, R = build.build_all(names)
    os.makedirs(out, exist_ok=True)
    rows = []
    for name, frames in R.items():
        w, h = box[2] - box[0], box[3] - box[1]
        k = min(per, len(frames))
        row = Image.new("RGBA", (k * (w + 2) + 70, h), (14, 10, 22, 255))
        for i in range(k):
            t = Image.new("RGBA", (w, h), (44, 38, 62, 255))
            t.alpha_composite(frames[i][0].crop(box))
            row.alpha_composite(t, (70 + i * (w + 2), 0))
        ImageDraw.Draw(row).text((2, 2), name, fill=(230, 220, 240, 255))
        rows.append(row.resize((row.width * scale, row.height * scale), Image.NEAREST))
    for g in range(0, len(rows), 6):
        part = rows[g:g + 6]
        H = sum(r.height + 6 for r in part)
        W = max(r.width for r in part)
        img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        y = 0
        for r in part:
            img.alpha_composite(r, (0, y))
            y += r.height + 6
        img.save(os.path.join(out, "grid%02d.png" % (g // 6)))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:] or None)
