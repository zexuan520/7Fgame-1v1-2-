"""地上的法阵贴图 assets/fx/magic_01.png：八卦符阵（替换原来素材库里的五角形阵——五芒星是西式的，和本作的道门、灯冢题材不搭）。
白色 + 透明度，游戏里按用途染色（召唤预警、头目落点、灯阵……）。256×256，4 倍超采样画再缩。

用法：python3 tools/charforge/fx_bagua.py
"""
import math, os
from PIL import Image, ImageDraw

S = 1024
C = S / 2
im = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(im)


def ring(r, w, a=255):
    d.ellipse([C - r, C - r, C + r, C + r], outline=a, width=w)


def bar(ang, r0, r1, half_w, a=255):
    """沿半径方向 r0→r1、绕圆心角 ang 的一段弧形横杠（卦爻）"""
    pts = []
    n = 10
    da = half_w / ((r0 + r1) / 2)
    for i in range(n + 1):
        t = ang - da + 2 * da * i / n
        pts.append((C + math.cos(t) * r1, C + math.sin(t) * r1))
    for i in range(n, -1, -1):
        t = ang - da + 2 * da * i / n
        pts.append((C + math.cos(t) * r0, C + math.sin(t) * r0))
    d.polygon(pts, fill=a)


# 外圈：粗细两道
ring(500, 14)
ring(470, 6, 200)
# 外圈上一圈小刻度（符文点）
for i in range(48):
    t = i / 48 * math.tau
    r = 485
    s = 7 if i % 6 else 12
    d.ellipse([C + math.cos(t) * r - s, C + math.sin(t) * r - s, C + math.cos(t) * r + s, C + math.sin(t) * r + s], fill=230)
# 八卦：先天八卦，每卦三爻，阳爻整条、阴爻中间断开
GUA = ["111", "110", "101", "100", "011", "010", "001", "000"]   # 乾兑离震巽坎艮坤（内→外）
for k, g in enumerate(GUA):
    ang = k / 8 * math.tau - math.pi / 2
    for j, yao in enumerate(g):
        r0 = 340 + j * 38
        r1 = r0 + 22
        hw = 92
        if yao == "1":
            bar(ang, r0, r1, hw)
        else:
            gap = 18
            # 阴爻：左右两段
            for sgn in (-1, 1):
                mid = ang + sgn * (hw + gap) / 2 / ((r0 + r1) / 2)
                bar(mid, r0, r1, (hw - gap) / 2)
# 内圈
ring(318, 10)
ring(250, 5, 190)
# 太极：外圈 + S 形分界（只画线，染色后不会一大片实心）
ring(170, 12)
d.arc([C - 85, C - 170, C + 85, C], 90, 270, fill=255, width=12)
d.arc([C - 85, C, C + 85, C + 170], 270, 90, fill=255, width=12)
for cy in (-85, 85):
    d.ellipse([C - 22, C + cy - 22, C + 22, C + cy + 22], fill=255)
# 内外圈之间八条辐线（连着八卦，像符阵的“脉”）
for k in range(8):
    t = (k + 0.5) / 8 * math.tau - math.pi / 2
    d.line([(C + math.cos(t) * 252, C + math.sin(t) * 252), (C + math.cos(t) * 316, C + math.sin(t) * 316)], fill=200, width=6)

a = im.resize((256, 256), Image.LANCZOS)
out = Image.merge("RGBA", (Image.new("L", a.size, 255),) * 3 + (a,))
path = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fx", "magic_01.png")
out.save(os.path.normpath(path))
print("→", os.path.normpath(path))
