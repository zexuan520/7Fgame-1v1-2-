"""主角待机帧（逐像素）。layers 从后往前画；'.' 是透明；外轮廓自动描 1 像素。"""
from PIL import Image
import sys

PAL = {
    "K": "1c1424",  # 内描线
    "H": "2a2236", "h": "4e4466",            # 头发
    "S": "f4cdb0", "s": "d29a80", "r": "ec8a9a", "m": "b85a70",  # 皮肤、腮红、嘴
    "P": "ea8cad", "p": "b95f84", "D": "8a3a62", "Q": "fbc4d6",   # 粉衣
    "W": "f6f2f6", "w": "c9c0d4",            # 白
    "G": "5c5a6c", "g": "3c3a4a",            # 灰腰封
    "B": "2a2634", "b": "4a4660",            # 靴
    "F": "f2608f", "f": "c43e6e", "Y": "ffe08a", "J": "7ad8bc",   # 花、坠子
    "L": "f4aac6", "l": "fff0f6", "M": "7a3050", "T": "cfd0dc",   # 剑
}
OUTLINE = "1c1424"
W_, H_ = 48, 48

layers = [
  # 马尾
  [(3,9,"HH"),(4,8,"HhH"),(5,7,"HhH"),(6,7,"HhH"),(7,6,"HhH"),(8,6,"HH"),(9,6,"HH"),(10,5,"HH"),(11,5,"HH"),
   (12,5,"HH"),(13,5,"HH"),(14,5,"H"),(15,4,"HH"),(16,4,"H"),(17,4,"H"),(18,3,"H")],
  # 后袖
  [(y,8,"ppp") for y in range(16,25)] + [(25,8,"p.p"),(26,8,"p")],
  # 后脚靴
  [(38,11,"bB"),(39,11,"bB"),(40,11,"bBB"),(41,10,"bBB"),(42,10,"bBBBB"),(43,10,"BBBBBB")],
  # 长袍后片
  [(25,9,"pPPPPPPPP"),(26,8,"pPPPPPPPPP"),(27,8,"pPPPPPPPPP"),(28,7,"ppPPPPPPPP"),(29,7,"pPPPPPPPPP"),
   (30,6,"ppPPPPQPPP"),(31,6,"pPPPPQWQPP"),(32,5,"ppPPPPQPPPP"),(33,5,"pPPPPPPPPPP"),(34,4,"ppPPPPPPPPPP"),
   (35,4,"ppPPPQPPPPPP"),(36,4,"pPPPQWQPPPP"),(37,3,"ppPPPPQPPPPP"),(38,3,"pPP.pPPP.PPP"),(39,3,"pP..pPP..PP"),(40,3,"p....P....P")],
  # 前腿：白裤、绑带、黑靴
  [(25,16,"WWWW"),(26,16,"WWWWW"),(27,17,"WWWWW"),(28,17,"WWWWWw"),(29,18,"WWWWWw"),(30,18,"WWWWWw"),
   (31,19,"WWWWWw"),(32,19,"WWWWw"),(33,20,"WWWWw"),(34,20,"WWWw"),(35,20,"WWWw"),(36,20,"WWWw"),
   (37,20,"GGGG"),(38,20,"bBBB"),(39,20,"bBBB"),(40,20,"bBBB"),(41,20,"bBBBB"),(42,20,"bBBBBB"),(43,20,"BBBBBBB")],
  # 前襟
  [(25,14,"PPPPPP"),(26,14,"PPPPPPW"),(27,15,"PPPPPW"),(28,15,"PPPPW"),(29,16,"PPPW"),(30,16,"PPP"),(31,16,"P.P")],
  # 上身、腰封、坠子
  [(14,19,"ss"),(15,12,"pPPPPPWssWP"),(16,11,"ppPPPPPPWsWP"),(17,11,"ppPPPPPPPWWP")] +
  [(y,11,"ppPPPPPPPPWP") for y in range(18,22)] +
  [(22,11,"gGGGGGGGGGGG"),(23,11,"gGGGGGGGGGGG"),(24,11,"gggggggggggg"),(25,20,"F"),(26,20,"J"),(27,20,"f")],
  # 头
  [(3,13,"HHHHHHHH"),(4,12,"HHHHHHHHhHH"),(5,11,"HHHHHHHHHhhH"),(6,11,"HHHHHHHHHHHH"),(7,11,"HHHHHHHSHHSH"),
   (8,11,"HHHHHHSSSSSS"),(9,11,"HHHHsHSSSKSS"),(10,11,"HHHHsHSSSKSSS"),(11,11,"HHHHHHSSSSrS"),
   (12,12,"HHHsHSSSmS"),(13,13,"HssSSSSS")],
  # 发髻、花
  [(1,11,"HHH"),(2,10,"HhHHH"),(3,10,"HhHHH"),(4,11,"HHH"),(0,16,"FfF"),(1,16,"fYf"),(2,16,"FfF")],
  # 前袖
  [(15,19,"PP"),(16,19,"PPP"),(17,19,"PPPP"),(18,19,"PPPP"),(19,19,"PPPPP"),(20,19,"PPPPPP"),(21,19,"PPPPPPW"),
   (22,19,"pPPPPPW"),(23,19,"pPPPPP"),(24,19,"pPPQPP"),(25,19,"ppQWQP"),(26,19,"pPPQP"),(27,19,"p.PP"),(28,20,"P")],
]

img = Image.new("RGBA", (W_ + 2, H_ + 2), (0, 0, 0, 0))
px = img.load()
def put(x, y, c):
    if 0 <= x < W_ and 0 <= y < H_:
        px[x + 1, y + 1] = tuple(int(PAL[c][i:i+2], 16) for i in (0, 2, 4)) + (255,)
for layer in layers:
    for y, x, s in layer:
        for i, c in enumerate(s):
            if c != ".":
                put(x + i, y, c)
# 袖子和身子之间的分界、袖子上沿受光
for y in range(16, 22): put(18, y, "D")
for (x, y) in [(20, 15), (21, 16), (22, 17), (22, 18), (23, 19), (24, 20)]: put(x, y, "Q")
# 剑：剑柄、护手、剑身（两像素宽，上沿亮）、剑穗；手握在上面
def line(x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for k in range(n + 1):
        put(round(x0 + (x1 - x0) * k / n), round(y0 + (y1 - y0) * k / n), c)
for x in range(29, 43):
    y = 22 + round((x - 29) * 0.62)
    put(x, y, "l"); put(x, y + 1, "L")
put(43, 31, "l")
for (x, y) in [(23, 18)]: put(x, y, "T")
line(24, 19, 26, 21, "M")
put(29, 21, "T"); put(28, 22, "T"); put(27, 23, "T")
for (x, y, c) in [(22, 19, "F"), (22, 20, "F"), (21, 21, "f"), (21, 22, "F")]: put(x, y, c)
for (x, y, c) in [(26, 21, "S"), (27, 21, "S"), (26, 22, "s"), (27, 22, "S")]: put(x, y, c)
# 外轮廓
o = tuple(int(OUTLINE[i:i+2], 16) for i in (0, 2, 4)) + (255,)
src = img.copy(); sp = src.load()
for y in range(img.height):
    for x in range(img.width):
        if sp[x, y][3] == 0 and any(0 <= x+dx < img.width and 0 <= y+dy < img.height and sp[x+dx, y+dy][3] and sp[x+dx, y+dy][:3] != o[:3]
                                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
            px[x, y] = o
img.save(sys.argv[1])
big = Image.new("RGBA", img.size, (40, 34, 58, 255)); big.alpha_composite(img)
big.resize((img.width * 8, img.height * 8), Image.NEAREST).save(sys.argv[2])
