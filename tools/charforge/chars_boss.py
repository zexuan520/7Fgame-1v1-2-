"""头目：比小怪多一层细节（游戏里放大 1.5~2.2 倍），每个都有一个“远看就知道是谁”的大记号。"""
import numpy as np
from forge import Forge, std_joints
from kit import (C, human_joints, legs, arms, torso, cross_collar, belt, skirt, flaps, head, mask_lower, hat_straw,
                 helm_round, crown_mian, hair_bun, topknot, hood, tall_hat, pauldrons_square, pauldrons_round,
                 chest_plate, cape, back_flag, back_pole_lantern, jag)
from chars import _skeleton
from chars_foes import _man


def boss_sakura():
    """夜樱剑鬼：灰紫皮肤的鬼武者，一对白角、一大把白发披到腰，深梅色袍子上落满樱瓣，右肩袒露。顶视：白发 + 两只角 + 粉点"""
    P, Pd = "#4a2440", "#2c1428"
    skin = "#9a8aa8"
    f = _man("boss_sakura", "夜樱剑鬼", heavy=True, thigh=Pd, shin=P, boot=C["lacq"], sleeve=P, fore=skin, hand=skin, body=P,
             collar=(C["paper"], Pd), sk=P, sk_dark=Pd, sk_bottom=12, belt_col=C["red"], buckle=C["gold"],
             skin=skin, hair=C["hair_w"], eyes=C["eye"], eye_glow=0.6, wide=0)
    f.paint(f.side("z", ">", 6) & f.side("y", ">", 56) & (f.part == 0), skin, part="torso")
    f.fill(f.seg((0, 66, 15), (0, 51, 15), 5.4, 5.0), "arm_u_f", skin)
    for (x, z, h) in ((-2, 0, 96), (-6, 3, 92), (-6, -3, 92)):
        f.fill(f.cone(x, z, 4, 86, 1, h), "head", C["hair_w"])
    f.fill(f.ell((-9, 70, 0), (5, 16, 9)) & f.side("x", "<", -5), "torso", C["hair_w"])
    f.fill(f.seg((-6, 86, 0), (-10, 70, 0), 6, 5), "head", C["hair_w"])
    for s in (1, -1):
        f.fill(f.seg((1, 87, 5 * s), (0, 93, 8 * s), 2.0, 1.6) | f.seg((0, 93, 8 * s), (3, 100, 9 * s), 1.6, 0.6), "head", C["bone_l"])
    pet = (f.part >= 0) & (f.part != 2) & ((np.floor(f.X / 3) * 11 + np.floor(f.Y / 3) * 5 + np.floor(f.Z / 3) * 7) % 13 == 0) & \
        (np.abs(f.col[..., 0] - 0x4a) < 30) & (f.glow == 0)
    f.paint(pet, C["pink_l"])
    f.paint(pet & ((np.floor(f.Y) % 2) == 0), C["pink"])
    return f


def boss_bones():
    """百骨将：大骷髅将军，头戴骷髅攒成的冠，两肩堆满小骷髅，背后一面破军旗。顶视：一圈小骷髅 + 一面黑红旗"""
    f = _skeleton("boss_bones", "本作自制 · 百骨将", head="bare", shoulder="none", rag=C["maroon"], rag_d=C["maroon_d"], hunch=4)
    hx = 4 * 0.6
    B, Bd, Bl, G = C["bone"], C["bone_d"], C["bone_l"], C["gap"]

    def skull(part, c, r):
        f.fill(f.ell(c, (r, r * 1.05, r)), part, Bl)
        for s in (1, -1):
            f.fill(f.ell((c[0] + r * 0.75, c[1], c[2] + s * r * 0.38), (r * 0.25, r * 0.28, r * 0.25)), part, G)

    for s, sd in ((1, "f"), (-1, "b")):
        z = 14 * s
        for (dx, dy, dz, r) in ((0, 69, 0, 4.0), (-4, 67, 3, 3.2), (4, 67, -2, 3.2), (-1, 72, 3, 3.0), (2, 66, 5, 2.8)):
            skull("arm_u_" + sd, (dx, dy, z + dz * s), r)
    for k in range(5):
        a = (k - 2) * 0.55
        skull("head", (hx + 1.5 + np.cos(a) * 7.5 - 2, 89, np.sin(a) * 8), 3.0)
    f.fill(f.cyl(hx, 0, 9.4, 86, 88.5), "head", C["iron_d"])
    f.fill(f.cyl(-9, 0, 1.4, 40, 118), "torso", C["wood_d"])
    fl = f.box(-10, -8, 90, 116, 0, 18) & ~(((np.floor(f.Z / 3) * 7 + np.floor(f.Y / 3)) % 5 == 0) & f.side("y", "<", 96))
    f.fill(fl, "torso", C["maroon"])
    f.paint(fl & f.ell((-9, 104, 9), (3, 5, 5)), C["bone_l"], part="torso")
    chest = f.ell((3, 58, 0), (7.5, 9.5, 11)) & f.side("x", ">", 4)
    f.fill(chest, "torso", C["iron"])
    f.paint(chest & ((np.floor(f.Y) % 4) == 0), C["rust"], part="torso")
    return f


def boss_jiguang():
    """寂光：古寺老禅师，你的师父。光头、白长眉白须，灰僧袍外搭朱红袈裟，一挂大念珠。顶视：光头 + 一大片朱红"""
    f = _man("boss_jiguang", "寂光", heavy=True, thigh=C["grey_d"], shin=C["grey_l"], boot=C["boot"], wraps=C["grey_d"],
             sleeve=C["grey"], fore=C["grey"], hand=C["skin_old"], body=C["grey"], sk=C["grey"], sk_dark=C["grey_d"], sk_bottom=10,
             belt_col=None, skin=C["skin_old"], bald=True, beard=C["hair_w"], wide=5)
    for s in (1, -1):
        f.fill(f.seg((7, 83, 3 * s), (6, 79, 8 * s), 1.2, 0.8), "head", C["hair_w"])
    sash = f.ell((0.5, 57, 0), (9.0, 15, 12.6)) & ~f.ell((0.5, 57, 0), (6.6, 12.5, 10.2)) & ((f.Y - 56) > -f.Z * 1.0 - 8)
    f.fill(sash, "torso", "#a8302a")
    f.paint(sash & ((np.floor(f.Y / 4) + np.floor(f.Z / 4)) % 2 == 0), "#8a2420", part="torso")
    f.fill(f.ell((0, 66, -9), (8.5, 5.5, 7.5)) & f.side("y", ">", 62), "torso", "#a8302a")
    f.fill(f.box(-9, 9, 30, 46, -13, -5) & f.cone(0, 0, 10.5, 46, 13.5, 30, squash=1.25) & ~f.cone(0, 0, 8, 46, 11, 30, squash=1.25), "hips", "#a8302a")
    ang = np.arctan2(f.Z, f.X - 1)
    beads = (np.abs(np.sqrt((f.X - 1) ** 2 + f.Z ** 2) - 10.5) < 1.8) & (np.abs(f.Y - (66 - 8 * np.cos(ang).clip(0))) < 1.8)
    f.fill(beads, "torso", C["wood_d"])
    f.paint(beads & ((np.floor(ang * 5) % 3) == 0), C["gold"], part="torso")
    for s in (1, -1):
        f.fill(f.ell((0.5, 82, 6.5 * s), (0.9, 0.9, 0.9)), "head", C["gold"])
    return f


def boss_kurong():
    """井中人·枯荣：半边是枯骨、半边长满青苔和小花，湿透的黑长发盖住脸，身上滴着青光的水。顶视：黑发 + 一边白一边绿"""
    f = _skeleton("boss_kurong", "本作自制 · 枯荣", shoulder="none", rag=C["teal"], rag_d=C["teal_d"], hunch=6, eye=C["eye_c"],
                  bones=("#c8d2c8", "#8c9a90", "#e2ece4"))
    hx = 6 * 0.6
    moss = (f.part >= 0) & f.side("z", "<", -1) & (f.glow == 0)
    f.paint(moss, "#3f6a3a")
    f.paint(moss & ((np.floor(f.X / 2) * 5 + np.floor(f.Y / 2) * 3 + np.floor(f.Z / 2)) % 7 == 0), "#6a9a4a")
    f.paint(moss & ((np.floor(f.X / 3) * 5 + np.floor(f.Y / 3) * 7 + np.floor(f.Z / 3) * 3) % 19 == 0), C["pink_l"])
    hair = f.ell((hx, 84, 0), (10.5, 8, 10)) & f.side("y", ">", 80)
    f.fill(hair, "head", C["hair"])
    for k in range(9):
        a = (k / 9) * 2 * np.pi
        x, z = np.cos(a) * 8.5 + hx, np.sin(a) * 8.5
        f.fill(f.seg((x, 84, z), (x * 1.05 + (2 if np.cos(a) > 0.3 else 0), 62 - (k % 3) * 5, z * 1.15), 2.2, 1.2), "head", C["hair"])
    for (x, z) in ((hx + 9, 3), (hx + 7, -5), (hx - 6, 7)):
        f.fill(f.ell((x, 58, z), (1.0, 1.6, 1.0)), "head", C["eye_c"], glow=0.7)
    return f


def boss_general():
    """不夜将军：黄铜鬼面重甲，盔上一簇大铜焰（焰尖发光），胸口一盏灯纹，红披风。顶视：大火苗盔缨 + 红披风"""
    B, Bd, Bl = C["brass"], C["brass_d"], C["brass_l"]
    f = _man("boss_general", "不夜将军", heavy=True, thigh=Bd, shin=B, boot=C["lacq"], greave=Bl, sleeve=C["red_d"], fore=B, hand=Bd,
             body=C["red_d"], sk=B, sk_dark=Bd, sk_kind="flaps", belt_col=C["lacq"], buckle=Bl, skin=Bd, hair=Bd)
    chest_plate(f, B, Bd, Bl)
    f.fill(f.ell((9.5, 58, 0), (1.4, 4, 3)), "torso", C["fire_y"], glow=0.8)
    cape(f, C["red"], C["red_d"], bottom=18, w=14, back=-8)
    pauldrons_round(f, B, Bd, Bl, z=15, r=(9, 6.5, 8.5), spikes=Bl)
    helm_round(f, B, Bd, r=(9.8, 9.5, 9.4), rim=11.5, nose=False)
    f.fill(f.box(5.5, 10, 70, 86, -7.5, 7.5) & f.ell((1, 79, 0), (9.5, 11, 9)), "head", Bd)
    for s in (1, -1):
        f.fill(f.box(9, 10.5, 79, 81.5, 3.2 * s - 1.6, 3.2 * s + 1.6), "head", C["fire"], glow=0.8)
        f.fill(f.seg((2, 88, 8 * s), (0, 94, 14 * s), 2.0, 1.0), "head", Bl)
    f.fill(f.box(9, 10.5, 72, 75, -4, 4), "head", C["gap"])
    for (x, z, h, r) in ((0, 0, 112, 4.2), (-4, 0, 104, 3.4), (3, 0, 102, 3.0), (-1, 3.5, 103, 2.6), (-1, -3.5, 103, 2.6)):
        fl = f.cone(x, z, r, 90, 0.4, h)
        f.fill(fl, "head", B)
        f.paint(fl & f.side("y", ">", h - (h - 90) * 0.4), C["fire"], part="head", glow=0.7)
    return f


def jin():
    """执灯使·烬：寂光大弟子，你的师兄。高瘦，黑红长衣，白发高马尾，右臂裂着火纹，腰挂一盏燃灯。顶视：白马尾 + 腰间橙光"""
    D, Dd = "#2a1e24", "#160e12"
    f = _man("jin", "执灯使·烬", thigh=Dd, shin=D, boot=C["lacq"], sleeve=D, fore="#5a2a22", hand=C["skin"], body=D,
             collar=(C["red"], Dd), sk=D, sk_dark=C["red_d"], sk_bottom=14, belt_col=C["red_d"], buckle=C["gold"], hair=C["hair_w"])
    f.paint((f.part == PART("arm_l_f")) & ((np.floor(f.X / 2) * 7 + np.floor(f.Y / 2) * 3 + np.floor(f.Z / 2) * 5) % 5 == 0), C["fire"], glow=0.6)
    f.fill(f.seg((-3, 88, 0), (-6, 94, 0), 2.4, 2.4), "head", C["hair_w"])
    f.fill(f.seg((-6, 94, 0), (-14, 80, 0), 2.6, 1.6) | f.seg((-14, 80, 0), (-15, 66, 1), 1.6, 0.8), "head", C["hair_w"])
    f.fill(f.cyl(-3.5, 0, 2.6, 87, 89.5), "head", C["red"])
    f.fill(f.seg((7, 44, -9), (9, 38, -11), 0.7), "hips", C["iron_d"])
    f.fill(f.ell((9, 34, -11), (3.0, 4.0, 3.0)), "hips", C["paper"])
    f.fill(f.ell((9, 34, -11), (3.1, 2.8, 3.1)), "hips", C["fire"], glow=0.7)
    f.fill(f.ell((-1, 66, -10), (8.5, 6, 8)) & f.side("y", ">", 60), "torso", C["red_d"])
    return f


def boss_fire():
    """火师焦明：烧焦的橙黑袍子，背一只大酒葫芦，头发像火苗往上窜，双手发火光。顶视：火苗头 + 葫芦"""
    O, Od = "#a8501e", "#5a2610"
    f = _man("boss_fire", "火师焦明", heavy=True, thigh=C["char"], shin=Od, boot=C["boot"], sleeve=O, fore=Od, hand=C["fire"], body=O,
             collar=(C["char"], Od), sk=O, sk_dark=C["char"], sk_bottom=14, belt_col=C["char"], buckle=C["brass"], beard=C["char"])
    for s, sd in ((1, "f"), (-1, "b")):
        f.paint(f.ell((0.5, 32, 14 * s), (5, 5, 5)) & (f.part == PART("arm_l_" + sd)), C["fire"], glow=0.7)
    for (x, z, h, r) in ((-1, 0, 104, 5), (-5, 3, 98, 3.4), (-4, -3, 99, 3.6), (2, 2, 96, 3), (-8, 0, 96, 3)):
        fl = f.cone(x, z, r, 85, 0.4, h)
        f.fill(fl, "head", C["fire"], glow=0.6)
        f.paint(fl & f.side("y", ">", h - (h - 85) * 0.45), C["fire_y"], part="head", glow=0.8)
    f.fill(f.ell((-14, 52, 0), (6, 8, 6)) | f.ell((-14, 66, 0), (4.4, 5, 4.4)), "torso", "#c8902a")
    f.fill(f.cyl(-14, 0, 4.6, 59, 61), "torso", C["red"])
    f.fill(f.cyl(-14, 0, 1.6, 70, 74), "torso", C["wood_d"])
    f.paint((f.part >= 0) & (f.part != 2) & ((np.floor(f.X / 3) * 13 + np.floor(f.Y / 3) * 7 + np.floor(f.Z / 3) * 3) % 13 == 0) & (f.glow == 0), C["char"])
    return f


def boss_huo():
    """押灯将霍长风：银蓝重甲、高翎盔、长须，背后两根竹竿挑着两盏灯，深蓝披风。顶视：白翎 + 两盏亮灯"""
    S, Sd, Sl = "#8a9ab0", "#56627a", "#b8c4d6"
    f = _man("boss_huo", "押灯将霍长风", heavy=True, thigh=C["navy_d"], shin=S, boot=C["lacq"], greave=Sl, sleeve=C["navy"], fore=S, hand=Sd,
             body=C["navy"], sk=S, sk_dark=Sd, sk_kind="flaps", belt_col=C["lacq"], buckle=C["gold"], beard=C["hair"])
    chest_plate(f, S, Sd, Sl)
    cape(f, C["navy_l"], C["navy_d"], bottom=18, w=14, back=-8)
    pauldrons_round(f, S, Sd, Sl, z=15, r=(9, 6.5, 8.5))
    helm_round(f, S, Sd, r=(9.4, 10, 9), crest="plume", crest_col=C["paper"])
    for z in (-7, 7):
        f.fill(f.seg((-9, 44, z), (-11, 106, z * 1.3), 1.2), "torso", C["wood"])
        f.fill(f.ell((-11, 101, z * 1.3), (3.6, 4.6, 3.6)), "torso", C["paper"])
        f.fill(f.ell((-11, 101, z * 1.3), (3.7, 3.2, 3.7)), "torso", C["fire_y"], glow=0.6)
    return f


def boss_emperor():
    """长明帝：明黄龙袍、冕旒、长须，宽袖拖地，眼睛泛金光。顶视：冕旒长方板 + 一大片明黄"""
    Y, Yd, Yl = "#e0b030", "#9a7418", "#f6d870"
    f = _man("boss_emperor", "长明帝", heavy=True, thigh=Yd, shin=Yd, boot=C["lacq"], sleeve=Y, hand=C["skin_pale"], body=Y,
             collar=(C["paper"], C["red"]), sk=Y, sk_dark=C["red"], sk_bottom=4, belt_col="#d8e8d0", buckle=C["red"], wide=6,
             skin=C["skin_pale"], eyes=C["eye_y"], eye_glow=0.7, beard=C["hair"], fat=1.5)
    dragon = (f.part == PART("torso")) & (np.abs(np.sin(f.Y * 0.35) * 5 - f.Z) < 1.6) & f.side("x", ">", 4) & f.side("y", ">", 48)
    f.paint(dragon, C["red"], part="torso")
    f.paint((f.part == PART("hips")) & (np.abs(np.sin(f.Y * 0.3) * 6 - f.Z) < 1.6) & f.side("x", ">", 4), C["red"], part="hips")
    f.paint((f.part >= 0) & (f.part != 2) & (np.abs(f.col[..., 0] - 0xe0) < 20) & ((np.floor(f.Y) % 9) == 0), Yl)
    crown_mian(f, y0=88)
    return f


def boss_king():
    """烛王：锈铜古甲、干瘪的鬼脸、头戴插满蜡烛的王冠（烛火都亮着），破旧的长王袍。顶视：一圈小火苗"""
    B, Bd, Bl = "#8a6a44", "#4e3a24", "#ae8a5a"
    f = _man("boss_king", "烛王", heavy=True, thigh=Bd, shin=B, boot=C["lacq"], greave=Bl, sleeve=C["purple_d"], fore=B, hand=Bd,
             body=C["purple_d"], sk=C["purple"], sk_dark=C["purple_d"], sk_bottom=6, belt_col=C["gold_d"], buckle=C["gold"],
             skin="#8a7a6a", hair=C["hair_g"], eyes=C["eye_o"], eye_glow=0.7, beard=C["hair_g"])
    chest_plate(f, B, Bd, Bl)
    cape(f, C["purple"], C["purple_d"], bottom=4, w=15, back=-8)
    pauldrons_round(f, B, Bd, Bl, z=15, r=(9, 6.5, 8.5))
    f.fill(f.cyl(0.5, 0, 9.5, 86, 90) & ~f.cyl(0.5, 0, 7.5, 86, 91), "head", C["gold"])
    for k in range(7):
        a = k / 7 * 2 * np.pi
        x, z = 0.5 + np.cos(a) * 8.5, np.sin(a) * 8.5
        f.fill(f.cyl(x, z, 1.4, 90, 95 + (k % 3)), "head", C["paper"])
        f.fill(f.cone(x, z, 1.2, 95 + (k % 3), 0.2, 99 + (k % 3)), "head", C["fire_y"], glow=0.8)
    return f


def PART(n):
    from forge import PART_IDS
    return PART_IDS.index(n)


BOSSES = {
    "boss_sakura": boss_sakura, "boss_bones": boss_bones, "boss_jiguang": boss_jiguang, "boss_kurong": boss_kurong,
    "boss_general": boss_general, "jin": jin, "boss_fire": boss_fire, "boss_huo": boss_huo, "boss_emperor": boss_emperor,
    "boss_king": boss_king,
}
