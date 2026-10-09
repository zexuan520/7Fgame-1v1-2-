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
  [(y,9,"pp") for y in range(16,23)] + [(23,9,"p")],
  # 后腿：袍子下面露一截白裤，再是靴子
  [(y,11,"www") for y in range(33,38)] + [(38,11,"bB"),(39,11,"bB"),(40,11,"bBB"),(41,10,"bBB"),(42,10,"bBBBB"),(43,10,"BBBBBB")],
  # 长袍后片（到小腿上面就收住）
  [(25,10,"pPPPPPPP"),(26,10,"pPPPPPPPP"),(27,9,"ppPPPPPPPP"),(28,9,"pPPPPPQPPP"),(29,9,"pPPPPQWQPP"),
   (30,8,"ppPPPPPQPPP"),(31,8,"pPPPPPPPPPP"),(32,8,"ppPPQPPPPPP"),(33,8,"pPPQWQPPPPP"),(34,8,"pPPPQPPPPP"),
   (35,8,"pP.pPPP.PP"),(36,8,"p..PP...P")],
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
  # 剑鞘、剑柄（插在腰封上：鞘尾斜向后下，剑柄朝前上）
  [],
  # 前袖：胳膊自然垂着，手搭在剑柄上
  [(15,19,"PP"),(16,18,"PPPQ"),(17,18,"PPPPQ"),(18,18,"PPPPQ"),(19,18,"pPPPPQ"),(20,18,"pPPPPP"),
   (21,18,"pPPPPW"),(22,18,"pPPPP"),(23,18,"pPPQ"),(24,18,"pP.P"),(25,18,"p")],
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
# 剑鞘：两像素宽，上沿亮一点，鞘尾包银
for x in range(5, 21):
    y = 25 + round((20 - x) * 0.53)
    put(x, y, "D"); put(x, y + 1, "M")
put(4, 33, "T"); put(4, 34, "T"); put(5, 34, "T")
# 护手、剑柄、柄尾和剑穗
put(21, 23, "T"); put(21, 24, "T"); put(22, 25, "T")
for (x, y) in [(22, 23), (23, 23), (24, 22), (25, 22), (26, 21)]: put(x, y, "M")
put(27, 20, "T"); put(27, 21, "T")
for (x, y, c) in [(28, 21, "F"), (28, 22, "F"), (28, 23, "f"), (27, 24, "F")]: put(x, y, c)
# 手搭在剑柄上
for (x, y, c) in [(23, 22, "S"), (24, 23, "S"), (23, 24, "s"), (24, 24, "S")]: put(x, y, c)
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
