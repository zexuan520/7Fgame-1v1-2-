"""主角新造型（2026-11-09“把主角模型做得更帅”）：三个方案，挑定一个替换 hero_canren。
共同的改法（老主角的毛病：斗笠半径 19 盖住整个人，顶视就是一张草帽圆盘；米白绑腿、米白小臂显得土；腰身直筒）：
  - 头身拉长到约 1:4.5：腿长 3 小格、腰收窄、肩加宽，倒三角
  - 下身全换深色（炭黑裤、黑靴），亮色只留给头顶记号、袍子（皮肤换色那块）和一点朱红
  - 背后加长的衣摆/披风往后拖：斜俯视下人物朝哪、跑多快一眼看得出（顶视剪影是“前尖后长”的水滴，不再是圆盘）
  - 袍子仍用绿色系（robe），皮肤 swap_green 换色照旧
"""
import numpy as np
from forge import Forge, std_joints
from kit import C, jag

SIDES = ((1, "f"), (-1, "b"))
# 新骨架：脖子 74、胯 45、膝 24（腿长 3 小格），肩宽 13.5
HERO_J = dict(neck=74, sh_y=68, sh_z=13.5, hip_y=45, leg_z=5.5, knee_y=24, ankle_y=6)


def _legs(f, pants=C["char"], shin=C["char"], boot=C["boot"], wrap=C["char_l"], boot_l=C["boot_l"], wide=0.0):
    """修长的腿：大腿 4.2→3.7，小腿 3.6→3.0；wide>0 是宽腿裤（下面张开）"""
    for s, sd in SIDES:
        z = 5.5 * s
        pu, pl = "leg_u_" + sd, "leg_l_" + sd
        f.fill(f.seg((0, 44, z), (0, 24, z), 4.2 + wide * 0.3, 3.7 + wide * 0.6), pu, pants)
        f.fill(f.seg((0, 24, z), (0, 9, z), 3.6 + wide * 0.6, 3.0 + wide), pl, shin)
        if wrap:
            for y in range(11, 22, 3):
                f.paint(f.box(-9, 9, y, y + 1, z - 7, z + 7), wrap, part=pl)
        f.fill(f.box(-3.5, 9.5, 0, 9, z - 3.8, z + 3.8) & f.ell((2.5, 2, z), (8.2, 10, 4.8)), pl, boot)
        if boot_l:
            f.paint(f.box(-5, 11, 7.5, 9, z - 5, z + 5), boot_l, part=pl)
        f.paint(f.box(6, 11, 0, 1.5, z - 5, z + 5), C["lacq"], part=pl)


def _torso(f, cloth, waist=7.0):
    """倒三角上身：腰收到 waist，胸背 7.5，肩宽 14"""
    f.fill(f.ell((0, 60, 0), (7.4, 12, 10.5)), "torso", cloth)
    f.fill(f.ell((0, 50, 0), (6.6, 6, waist + 2)), "torso", cloth)
    f.fill(f.ell((0, 67.5, 0), (7.0, 5.5, 14.0)), "torso", cloth)


def _arms(f, sleeve, fore, hand=C["skin"], bracer=C["lacq"], bracer_l=C["lacq_l"], cuff=None, wide=0.0, bare_f=False):
    for s, sd in SIDES:
        z = 13.5 * s
        pu, pl = "arm_u_" + sd, "arm_l_" + sd
        sl = C["skin"] if (bare_f and s > 0) else sleeve
        f.fill(f.seg((0, 67, z), (0, 53, z), 4.8, 4.2), pu, sl)
        if cuff and not (bare_f and s > 0):
            f.fill(f.cyl(0, z, 4.9, 52, 55), pu, cuff)
        f.fill(f.seg((0, 53, z), (0, 41, z), 3.7, 3.4), pl, fore)
        if wide > 0:
            sw = f.cone(0, z, 4.2 + wide, 40, 4.2, 54) & ~f.cone(0, z, 3.4 + wide - 1.2, 39, 3.4, 55)
            f.fill(sw, pl, sleeve)
        if bracer:
            f.fill(f.cyl(0, z, 4.1, 41, 48), pl, bracer)
            f.paint(f.cyl(0, z, 4.3, 47, 48) | f.cyl(0, z, 4.3, 41, 42), bracer_l, part=pl)
        f.fill(f.ell((0.6, 37, z), (3.9, 4.4, 3.9)), pl, hand)


def _head(f, hair=C["hair"], skin=C["skin"], cy=82.0, mask=None):
    """脸窄一点、下巴尖一点；眼睛是一道细横缝（凌厉）"""
    f.fill(f.ell((0.5, cy, 0), (7.2, 8.4, 7.0)), "head", hair)
    face = f.ell((1.4, cy - 0.6, 0), (7.0, 8.0, 6.6)) & f.side("x", ">", 1.8) & f.side("y", "<", cy + 5)
    f.paint(face, skin, part="head")
    f.paint(face & f.side("y", "<", cy - 4.5) & f.side("x", ">", 6), C["skin_d"], part="head")
    # 眉眼：一道黑横缝，外眼角往上挑
    for s in (1, -1):
        f.paint(f.box(6, 10, cy - 0.5, cy + 1.2, s * 1.6 - 1.4 if s > 0 else -3.0, s * 1.6 + 1.6 if s > 0 else -0.2), C["gap"], part="head")
        f.paint(f.box(6, 10, cy + 1.2, cy + 2.4, s * 3.2 - 0.8 if s > 0 else -4.0, s * 3.2 + 0.8 if s > 0 else -2.4), C["gap"], part="head")
    if mask:
        m = f.ell((1.6, cy - 0.6, 0), (7.3, 8.3, 6.9)) & f.side("x", ">", 1.0) & f.side("y", "<", cy - 2.6)
        f.fill(m, "head", mask)
        f.paint(m & f.side("y", ">", cy - 3.6), C["red_d"], part="head")


def _sheath(f, col=C["lacq"], fit=C["brass"]):
    """背后斜挂的刀鞘：右肩上露出刀柄，顶视一道斜线"""
    f.fill(f.seg((-8.5, 74, 9), (-9.5, 40, -10), 1.9), "torso", col)
    f.fill(f.seg((-8.4, 74, 9), (-8, 82, 13), 1.4), "torso", C["leather_d"])
    f.fill(f.seg((-8.4, 73, 8.4), (-8.4, 70, 6.6), 2.6), "torso", fit)
    f.fill(f.seg((-9.4, 43, -8.4), (-9.6, 40, -10), 2.3), "torso", fit)


def _coat_tail(f, col, dark, trim, top=47, front_y=34, back_y=12, r0=8.6, r1=13.5, slit=True):
    """长衫下摆（胯部件）：前短后长，背后从中间开衩成两片燕尾，往后拖。trim 下摆滚边"""
    cut = front_y + (back_y - front_y) * np.clip((-f.X + 6) / 16, 0, 1)      # 越往后越长
    sk = f.cone(-1.5, 0, r1, back_y - 2, r0, top, squash=1.18) & ~f.cone(-1.5, 0, r1 - 2.6, back_y - 2, r0 - 2.6, top, squash=1.18)
    sk &= f.side("y", "<", top) & (f.Y > cut)
    sk &= ~(f.side("x", ">", 1) & (np.abs(f.Z) < 6.5) & f.side("y", "<", top - 4))      # 前面大开衩，腿全露
    if slit:
        sk &= ~(f.side("x", "<", -4) & (np.abs(f.Z) < 1.6) & f.side("y", "<", 36))       # 背后燕尾缝
    f.fill(sk, "hips", col)
    f.fill(f.cone(-0.5, 0, r0 - 0.8, top - 5, r0 - 0.2, top, squash=1.18), "hips", col)
    f.paint(sk & (f.Y < cut + 3), dark, part="hips")
    f.paint(sk & (f.Y < cut + 1.4), trim, part="hips")
    # 衣摆内侧（开衩的切面）用暗色，翻起来时有层次
    f.paint(sk & f.side("x", ">", 1) & (np.abs(f.Z) < 8.5), dark, part="hips")


# ================= 方案 A · 斗笠刀客（保留斗笠，改尖改小） =================

def hero_a():
    """斗笠刀客：尖顶小斗笠（半径 19→14，压低遮眼）+ 背后一圈黑纱 + 立领长衫燕尾 + 左肩一片黑漆护肩 + 背刀。
    顶视：一颗尖顶草帽 + 后面拖一条燕尾，比老主角“草帽圆盘”瘦一圈，人看得见"""
    f = Forge("hero_a", std_joints(**HERO_J), "本作自制 · 主角残刃（斗笠刀客）")
    _legs(f)
    _coat_tail(f, C["robe"], C["robe_d"], C["red_d"])
    _torso(f, C["robe"])
    # 立领 + 黑里衣 V 领 + 朱红滚边
    f.paint(f.side("x", ">", 2) & (np.abs(f.Z + 1.2) < (f.Y - 54) * 0.40) & f.side("y", ">", 54), C["char"], part="torso")
    f.paint(f.side("x", ">", 2) & (np.abs(np.abs(f.Z + 1.2) - (f.Y - 54) * 0.40) < 1.1) & f.side("y", ">", 54), C["red"], part="torso")
    f.fill(f.cyl(0.5, 0, 6.2, 71, 75) & ~f.cyl(0.5, 0, 4.4, 70, 76), "torso", C["robe_d"])
    # 斜挎皮带 + 铜扣（右肩到左腰），腰上黑宽腰封 + 红绳结垂下
    band = (np.abs((f.Y - 60) - f.Z * 0.95) < 1.7) & f.ell((0, 59, 0), (8.4, 14, 12)) & ~f.ell((0, 59, 0), (6.6, 12, 10)) & f.side("y", ">", 47)
    f.fill(band, "torso", C["leather_d"])
    f.fill(f.box(6.5, 9, 57, 61, 0.5, 3.5), "torso", C["brass"])
    f.fill(f.ell((0, 48, 0), (7.6, 4.0, 9.8)), "torso", C["char"])
    f.paint(f.ell((0, 48, 0), (7.7, 4.1, 9.9)) & (np.abs(f.Y - 48) < 0.6), C["char_l"], part="torso")
    f.fill(f.box(6, 9.5, 44, 50, 3, 6.5), "torso", C["red"])
    f.fill(f.seg((8, 44, 4.5), (8.5, 33, 5.5), 1.1) | f.seg((8, 44, 4.5), (8.5, 35, 3.0), 1.0), "hips", C["red"])
    # 左肩：一片黑漆札甲护肩，朱红编绳（不对称）
    for i, y in enumerate((70, 67.5, 65)):
        p = f.ell((-0.5, y, -14.5 - i * 0.6), (7.4 - i * 0.2, 2.2, 6.6)) & f.side("y", ">", y - 1.6)
        f.fill(p, "arm_u_b", C["lacq"])
        f.paint(p & f.side("y", ">", y + 0.8), C["lacq_l"], part="arm_u_b")
    f.paint(f.box(-9, 9, 63, 72, -24, -5) & (np.abs(f.X - 0.5) < 0.8), C["red"], part="arm_u_b")
    _arms(f, C["robe"], C["char"], cuff=C["robe_d"])
    _sheath(f)
    # 头：脸 + 长马尾（从帽后甩出）
    _head(f)
    f.fill(f.seg((-6, 85, 0), (-13, 76, -0.5), 2.8, 2.2) | f.seg((-13, 76, -0.5), (-16, 63, -1), 2.2, 1.0), "head", C["hair"])
    f.fill(f.cyl(-6.2, 0, 2.4, 83, 86.5), "head", C["red"])
    # 尖顶斗笠：半径 14、高 15，帽檐往下压到眉毛（脸一半在阴影里）
    hy = 85.5
    hat = f.cone(0.5, 0, 14, hy, 1.0, hy + 15) & ~f.cone(0.5, 0, 12.6, hy - 0.5, 0, hy + 12.5)
    f.fill(hat, "head", C["straw"])
    r = np.sqrt((f.X - 0.5) ** 2 + f.Z ** 2)
    f.paint(hat & ((np.floor(r / 2.2) % 3) == 0), C["straw_d"], part="head")
    f.paint(hat & (r > 12.8), C["straw_l"], part="head")
    f.paint(hat & (r > 5.5) & (r < 7.2), C["red"], part="head")      # 帽上一道朱红箍
    f.fill(f.cone(0.5, 0, 1.6, hy + 14, 0.4, hy + 17.5), "head", C["brass"])
    # 背后半圈黑纱（帽檐垂下来，从后面和侧面看是一片黑影）
    veil = f.cyl(0.5, 0, 13.6, hy - 8, hy) & ~f.cyl(0.5, 0, 12.4, hy - 9, hy + 1) & f.side("x", "<", -2.5)
    veil &= f.Y > hy - 8 + (np.floor(np.arctan2(f.Z, f.X) * 5) % 2) * 1.2      # 纱边一高一低
    f.fill(veil, "head", C["char"])
    return f


# ================= 方案 B · 披发浪客（不戴帽，乱发 + 半边破披风） =================

def hero_b():
    """披发浪客：往后梳的长乱发 + 朱红额带 + 黑面巾遮半脸 + 左肩半边破披风拖到小腿 + 右臂缠布露膀子。
    顶视：一团往后炸开的黑发 + 一大片披风（皮肤换色就换这片），很像“一个人走江湖”"""
    f = Forge("hero_b", std_joints(**HERO_J), "本作自制 · 主角残刃（披发浪客）")
    _legs(f, pants=C["char_l"], shin=C["char_l"], wrap=C["cream_d"], wide=0.8)
    # 短下摆：深色裙甲式两片（前短后长）
    _coat_tail(f, C["char"], C["lacq"], C["red_d"], front_y=36, back_y=24, slit=False)
    _torso(f, C["char"])
    # 交领黑衣 + 朱红里衬
    f.paint(f.side("x", ">", 2) & (np.abs(f.Z + 1.2) < (f.Y - 55) * 0.45) & f.side("y", ">", 55), C["red_d"], part="torso")
    f.paint(f.side("x", ">", 2) & (np.abs(np.abs(f.Z + 1.2) - (f.Y - 55) * 0.45) < 1.0) & f.side("y", ">", 55), C["char_l"], part="torso")
    # 朱红腰带，一条长带尾垂在右胯
    f.fill(f.ell((0, 48, 0), (7.6, 3.6, 9.8)), "torso", C["red"])
    f.fill(f.seg((3, 46, 9), (2, 30, 11), 1.8, 1.2), "hips", C["red"])
    f.fill(f.seg((0, 46, 9.5), (-2, 34, 12), 1.6, 1.0), "hips", C["red_d"])
    # 右臂露膀子缠白布；左臂黑袖 + 铁护臂
    _arms(f, C["char"], C["char"], bracer=C["iron"], bracer_l=C["iron_l"], bare_f=True)
    for y in range(54, 66, 3):
        f.paint(f.cyl(0, 13.5, 5.2, y, y + 1.6), C["cream"], part="arm_u_f")
    for y in range(42, 52, 2):
        f.paint(f.cyl(0, 13.5, 4.2, y, y + 1), C["cream_d"], part="arm_l_f")
    # 半边破披风：从左肩斜搭，盖住后背和左半身，下沿撕成参差布条，拖到小腿
    cp_top = 72
    outer = f.ell((-1.5, 60, -2.5), (10.2, 18, 15.5))
    inner = f.ell((-1.5, 60, -2.5), (8.6, 16.5, 14))
    cp = outer & ~inner & ((f.X < 1.5) | (f.Z < -6))           # 背后 + 左侧
    cp &= f.Y < cp_top - np.clip(f.Z - 4, 0, 20) * 0.9         # 右肩那边低一点（斜搭）
    cp &= f.Y > 44
    f.fill(cp, "torso", C["robe"])
    # 披风下半截（挂到胯部件上跟着动）：后片 + 撕裂下沿
    lower = f.cone(-2, -1.5, 14.5, 18, 10.5, 46, squash=1.15) & ~f.cone(-2, -1.5, 13, 18, 9.0, 46, squash=1.15)
    lower &= (f.X < -1) | (f.Z < -8)
    lower &= f.Y < 46.5
    cut = jag(f, 30, 16, n=22)
    cut = cut - np.clip(-f.X - 2, 0, 10) * 0.6                  # 背后最长
    lower &= f.Y > cut
    f.fill(lower, "hips", C["robe"])
    f.paint(lower & (f.Y < cut + 3), C["robe_d"], part="hips")
    f.paint(cp & f.side("y", "<", 48), C["robe_d"], part="torso")
    # 披风领口：一圈灰白狼毛围肩（顶视是肩上一道亮弧，和黑发对比，一眼认得），铜扣
    fur = f.ell((-1.5, 70, -2), (9.4, 4.4, 15.5)) & f.side("y", ">", 67.5) & ~f.ell((1.5, 71, 0), (5.2, 6, 5.6))
    f.fill(fur, "torso", "#b9b2a4")
    f.paint(fur & ((np.floor(f.X / 1.5) + np.floor(f.Z / 1.5) + np.floor(f.Y)) % 3 == 0), "#8c8578", part="torso")
    f.paint(fur & f.side("y", ">", 73), "#d8d2c4", part="torso")
    f.fill(f.ell((4.5, 69, 7), (2, 2, 2)), "torso", C["brass"])
    # 左肩铁护肩（披风底下露出一角）
    p = f.ell((-0.5, 66.5, -15.5), (6.5, 4.5, 5.5)) & f.side("y", ">", 63)
    f.fill(p, "arm_u_b", C["iron"])
    f.paint(p & f.side("y", ">", 69), C["iron_l"], part="arm_u_b")
    _sheath(f, col=C["lacq"], fit=C["iron_l"])
    # 头：黑面巾遮下半脸 + 朱红额带
    _head(f, mask=C["lacq"])
    hb = f.ell((0.5, 82, 0), (7.6, 8.8, 7.4)) & ~f.ell((0.5, 82, 0), (6.6, 7.8, 6.4)) & (np.abs(f.Y - 85.5) < 1.3)
    f.fill(hb, "head", C["red"])
    # 乱发：头顶一大把往后梳，几绺炸开的发尖，长到背上
    f.fill(f.ell((-1.0, 85.5, 0), (8.2, 5.4, 7.8)) & f.side("y", ">", 85), "head", C["hair"])
    strands = [((-2, 89, 0), (-15, 84, 0), 3.4, 1.4), ((-1, 88, 4), (-13, 83, 7), 2.8, 1.0), ((-1, 88, -4), (-13, 83, -7), 2.8, 1.0),
               ((2, 90, 2), (-10, 88, 3), 2.4, 0.8), ((2, 90, -2), (-10, 89, -2.5), 2.4, 0.8), ((-5, 84, 0), (-12, 64, 0), 3.4, 1.4),
               ((-5, 84, 3.5), (-11, 67, 6), 2.6, 1.0), ((-5, 84, -3.5), (-11, 66, -6), 2.6, 1.0), ((5, 89, 3), (7, 84, 7.5), 1.6, 0.8),
               ((5, 89, -3), (8, 83, -7), 1.6, 0.8)]
    for a, b, r0, r1 in strands:
        f.fill(f.seg(a, b, r0, r1), "head", C["hair"])
    f.paint(f.ell((-1, 88, 0), (8, 3, 7)) & f.side("y", ">", 89.5) & (f.part == 2), C["char_l"], part="head")   # 头顶一缕高光
    return f


# ================= 方案 C · 白衣剑客（束发玉冠 + 广袖长袍） =================

def hero_c():
    """白衣剑客：高束发髻配银冠 + 长发披到后背 + 广袖长袍到脚踝（燕尾开衩）+ 玉佩红穗。
    顶视：一个小银冠 + 一条长发 + 一大片袍子（皮肤换色），仙侠味；默认青衫是青蓝，白霜皮肤就是一身白"""
    f = Forge("hero_c", std_joints(**HERO_J), "本作自制 · 主角残刃（白衣剑客）")
    _legs(f, wrap=None)
    _coat_tail(f, C["robe"], C["robe_d"], C["cream"], front_y=24, back_y=8, r1=15)
    # 内层米白中衣下摆（开衩里露一点）
    inner_sk = f.cone(-0.5, 0, 10, 26, 7.5, 44, squash=1.18) & ~f.cone(-0.5, 0, 8.6, 26, 6.0, 44, squash=1.18) & f.side("x", ">", 0)
    inner_sk &= ~(np.abs(f.Z) < 4.6) & f.side("y", "<", 44)
    f.fill(inner_sk, "hips", C["cream"])
    _torso(f, C["robe"])
    # 交领：两层（米白中衣 + 深色外缘）
    f.paint(f.side("x", ">", 2) & (np.abs(f.Z + 1.5) < (f.Y - 50) * 0.42) & f.side("y", ">", 50), C["cream"], part="torso")
    f.paint(f.side("x", ">", 2) & (np.abs(np.abs(f.Z + 1.5) - (f.Y - 50) * 0.42) < 1.3) & f.side("y", ">", 50), C["robe_d"], part="torso")
    # 宽腰带（深色）+ 玉佩 + 红穗
    f.fill(f.ell((0, 48, 0), (7.6, 3.8, 9.8)), "torso", C["char"])
    f.paint(f.ell((0, 48, 0), (7.7, 3.9, 9.9)) & (np.abs(f.Y - 48) < 0.7), C["brass"], part="torso")
    f.fill(f.ell((7.6, 41, 5), (1.4, 2.6, 2.4)), "hips", C["patina"])
    f.fill(f.seg((7.4, 44.5, 5), (7.6, 43, 5), 0.6), "hips", C["red"])
    f.fill(f.seg((7.6, 38.6, 5), (8, 31, 5.4), 1.2, 0.8), "hips", C["red"])
    # 广袖：大袖口往下张开，里衬米白
    _arms(f, C["robe"], C["cream"], bracer=C["char"], bracer_l=C["char_l"], wide=4.5)
    for s, sd in SIDES:
        z = 13.5 * s
        f.paint(f.cone(0, z, 8.9, 40, 4.2, 54) & f.side("y", "<", 42.5), C["robe_d"], part="arm_l_" + sd)
    # 背剑（细长剑鞘竖背，比刀鞘更直）
    f.fill(f.seg((-8.5, 76, 6), (-9, 40, -6), 1.5), "torso", C["char"])
    f.fill(f.seg((-8.5, 76, 6), (-8.2, 84, 8.5), 1.0), "torso", C["cream_d"])
    f.fill(f.seg((-8.5, 75, 5.6), (-8.5, 73, 4.8), 2.4), "torso", C["brass"])
    # 头：长发披背 + 高髻 + 银冠 + 两缕鬓发
    _head(f)
    f.fill(f.box(-9, -3, 58, 84, -5.5, 5.5) & f.ell((-6, 72, 0), (4.5, 16, 6.2)), "head", C["hair"])    # 后背长发
    f.fill(f.seg((-6, 70, 0), (-8, 56, 0), 3.4, 2.0), "head", C["hair"])
    for s in (1, -1):
        f.fill(f.seg((5.5, 86, 5.6 * s), (6.5, 75, 6.6 * s), 1.4, 0.9), "head", C["hair"])
    f.fill(f.ell((-0.5, 91, 0), (4.0, 4.4, 3.6)), "head", C["hair"])
    crown = f.box(-3.5, 3.5, 90, 95, -2.6, 2.6) & f.ell((-0.2, 92, 0), (4.0, 4.8, 3.0))
    f.fill(crown, "head", C["grey_l"])
    f.paint(crown & f.side("y", ">", 94), "#f0f2f6", part="head")
    f.fill(f.seg((-0.5, 93, -6.5), (-0.5, 93, 6.5), 0.8), "head", C["gold_l"])        # 簪子横穿
    # 发带：冠后两条米白长带垂到背中
    f.fill(f.seg((-3.5, 91, 1.5), (-10, 70, 3.5), 1.2, 0.8) | f.seg((-3.5, 91, -1.5), (-10, 72, -3.5), 1.2, 0.8), "head", C["cream"])
    return f


HEROES = {"hero_a": hero_a, "hero_b": hero_b, "hero_c": hero_c}
