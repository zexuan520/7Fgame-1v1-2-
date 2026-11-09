"""把 AnimTest 连拍的帧（frame_000.png…）拼成联络表：python3 tools/anim_sheet.py 目录 输出.jpg [列数] [每几张取一张] [起始张]"""
import os, sys
from PIL import Image, ImageDraw

d, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 8
step = int(sys.argv[4]) if len(sys.argv) > 4 else 1
start = int(sys.argv[5]) if len(sys.argv) > 5 else 0
fs = sorted(f for f in os.listdir(d) if f.startswith("frame_"))[start::step]
ims = [Image.open(os.path.join(d, f)).convert("RGB") for f in fs]
w, h = ims[0].size
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * h), (20, 20, 20))
dr = ImageDraw.Draw(sheet)
for i, im in enumerate(ims):
    x, y = (i % cols) * w, (i // cols) * h
    sheet.paste(im, (x, y))
    dr.text((x + 4, y + 4), fs[i][6:9], fill=(255, 255, 0))
sheet.save(out, quality=88)
print(out, len(ims), "frames")
