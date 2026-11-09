"""小怪：第一幕骷髅一家（每种头上、肩上、身上各有一个认得出的记号）、第二幕铜俑和灰衣营、第三幕官道和宫里的人。
敌人眼睛统一是自己发亮的（红 = 普通，青 = 水，紫 = 术，绿 = 毒，橙 = 火），主角从不发光，一眼分得清敌我。
"""
import numpy as np
from forge import Forge, std_joints
from kit import (C, human_joints, legs, arms, torso, cross_collar, belt, skirt, flaps, head, mask_lower, hat_straw,
                 helm_round, hat_official, hair_bun, topknot, bandana, hood, tall_hat, pauldrons_square, pauldrons_round,
                 chest_plate, cape, back_flag, back_pole_lantern, backpack, quiver, lantern_hand, jag)
from chars import _skeleton


def _man(name, src, heavy=False, thigh=C["char"], shin=C["char"], boot=C["boot"], wraps=None, greave=None,
         sleeve=C["grey"], fore=None, hand=C["skin"], cuff=None, bracer=None, body=C["grey"], collar=None,
         sk=None, sk_dark=None, sk_bottom=29, sk_kind="robe", belt_col=C["char"], buckle=None,
         skin=C["skin"], hair=C["hair"], eyes=None, eye_glow=0.0, wide=0.0, beard=None, bald=False, fat=0.0):
    """普通人形。sk_kind：robe 长袍下摆 / flaps 甲裙 / None 不要；fat 加粗腰身"""
    J = human_joints(heavy)
    f = Forge(name, J, "本作自制 · " + src)
    z_leg = 7 if heavy else 6
    z_arm = 15 if heavy else 14
    rk = 1.12 if heavy else 1.0
    legs(f, thigh, shin, boot, z=z_leg, r=(4.4 * rk, 4.0 * rk, 3.9 * rk, 3.5 * rk), wraps=wraps, greave=greave, top=J["upperleg.r"][1] - 1)
    if sk_kind == "robe" and sk:
        skirt(f, sk, sk_dark, bottom=sk_bottom, r0=9.5 + fat * 0.6, r1=12.5 + fat)
    elif sk_kind == "flaps" and sk:
        flaps(f, sk, sk_dark or C["lacq"], bottom=sk_bottom)
    torso(f, body, rx=8 * rk + fat * 0.6, rz=11 * rk + fat, sh=13.5 * rk)
    if collar:
        cross_collar(f, collar[0], collar[1])
    if belt_col:
        belt(f, belt_col, buckle, rx=8.2 * rk + fat * 0.6, rz=11 * rk + fat)
    arms(f, sleeve, fore or sleeve, hand, z=z_arm, ru=(5.0 * rk, 4.6 * rk), rl=(3.9 * rk, 3.6 * rk), cuff=cuff, bracer=bracer,
         sh_y=J["upperarm.r"][1] - 1, wide=wide)
    head(f, skin, hair, eyes, eye_glow=eye_glow, beard=beard, bald=bald)
    return f


# ======================= 第一幕 · 骷髅一家 =======================

def skel_crawler():
    """腐骨虫：弓成一团的小骨头，发霉的黄绿骨色，背上一排骨刺，头顶长苔。顶视：一颗绿苔小头 + 一串刺"""
    f = _skeleton("skel_crawler", "本作自制 · 腐骨虫", shoulder="none", rag=None, hunch=8,
                  bones=("#b4bc78", "#7c8448", "#ccd496"))
    # 满身霉斑苔藓（黄绿一团，和白骨头分开）
    f.paint((f.part >= 0) & ((np.floor(f.X / 2) * 7 + np.floor(f.Y / 2) * 3 + np.floor(f.Z / 2) * 5) % 4 == 0), "#6f8a3a")
    hx = 8 * 0.6
    f.paint(f.ell((hx + 1.5, 80, 0), (9.4, 9.6, 9.0)) & f.side("y", ">", 85), "#6f8a3a", part="head")
    f.paint(f.ell((hx + 1.5, 80, 0), (9.4, 9.6, 9.0)) & f.side("y", ">", 85) & ((np.floor(f.X) + np.floor(f.Z)) % 3 == 0), "#8fb04a", part="head")
    for i, y in enumerate(range(48, 72, 5)):
        f.fill(f.cone(-6 + i * 0.4, 0, 2.2, y - 2, 0.3, y + 1) & f.side("x", "<", -4) | f.seg((-5 + i * 0.4, y, 0), (-11 + i * 0.4, y + 3, 0), 1.6, 0.4), "torso", "#e6e6c4")
    return f


def skel_assassin():
    """骨刺客：黑巾蒙面 + 头巾长飘带 + 斜挎黑布带，瘦。顶视：黑头巾 + 两条飘带"""
    f = _skeleton("skel_assassin", "本作自制 · 骨刺客", shoulder="none", rag="#2d2438", rag_d="#1a1522", hunch=4,
                  bones=("#b8b0c4", "#827a90", "#d6d0e0"))
    hx = 4 * 0.6
    # 一身黑布裹到腰（远看是一条黑影顶一颗白头，和别的骷髅一眼分开）
    wrap = f.ell((2, 57, 0), (8.6, 12.5, 12.4)) & f.side("y", ">", 46)
    f.fill(wrap, "torso", "#2d2438")
    f.paint(wrap & ((np.floor(f.Y) % 4) == 0), "#3d3248", part="torso")
    for s_, sd in ((1, "f"), (-1, "b")):
        f.fill(f.seg((0, 66, 13 * s_), (0, 52, 13 * s_), 3.6, 3.3), "arm_u_" + sd, "#2d2438")
    mask_lower(f, "#2d2438", cx=hx + 2, cy=79)
    f.paint(f.ell((hx + 1.5, 80, 0), (9.4, 9.6, 9.0)) & f.side("y", ">", 83), "#2d2438", part="head")
    f.fill(f.seg((hx - 7, 85, 2), (hx - 18, 77, 4), 1.8, 1.0) | f.seg((hx - 7, 85, -2), (hx - 17, 74, -4), 1.8, 1.0), "head", "#7a2a3a")
    f.fill(f.cyl(hx + 1.5, 0, 9.6, 83, 85.5), "head", "#7a2a3a")
    band = (np.abs((f.Y - 56) - f.Z * 0.9) < 2.2) & f.ell((1.5, 57, 0), (8.6, 12, 12.2)) & ~f.ell((1.5, 57, 0), (6.5, 10, 10))
    f.fill(band, "torso", "#2d2438")
    return f


def skel_charger():
    """冲阵骨：牛角盔 + 两肩带刺铁护肩 + 锈铁胸甲，块头大。顶视：两只白角 + 两块铁肩"""
    f = _skeleton("skel_charger", "本作自制 · 冲阵骨", head="horns", shoulder="pauldron", rag=C["rust"], rag_d=C["rag_d"], hunch=4)
    p = f.ell((0, 68, 13), (8.5, 6, 8)) & f.side("y", ">", 63)
    f.fill(p, "arm_u_f", C["iron"])
    f.paint(p & f.side("y", ">", 70), C["iron_l"], part="arm_u_f")
    f.fill(f.seg((-3, 70, 13), (-3, 78, 14), 1.4) | f.seg((2, 70, 13), (2, 79, 14), 1.4), "arm_u_f", C["iron_d"])
    pl = f.ell((3, 58, 0), (7, 9, 10.5)) & f.side("x", ">", 4)
    f.fill(pl, "torso", C["iron"])
    f.paint(pl & ((np.floor(f.Y) % 4) == 0), C["rust"], part="torso")
    return f


def skel_bomber():
    """爆骨鬼：肋骨笼里塞着一罐火药，从骨缝里透出橙光；头顶一截燃着的引信。顶视：亮橙肚子 + 头顶火星"""
    f = _skeleton("skel_bomber", "本作自制 · 爆骨鬼", shoulder="none", rag=None, hunch=2, eye=C["eye_o"])
    cage_c = (1, 58, 0)
    f.fill(f.ell(cage_c, (5.3, 8.0, 9.0)) & f.side("y", ">", 49), "torso", C["fire"], glow=0.55)
    f.fill(f.ell(cage_c, (3.5, 5.5, 6.5)), "torso", C["fire_y"], glow=0.8)
    pot = f.ell((5.5, 55, 0), (5, 6.5, 7))
    f.fill(pot, "torso", "#3a2a22")
    f.fill(f.ell((7.5, 55, 0), (3.6, 4.6, 5.2)), "torso", C["fire"], glow=0.6)
    f.fill(f.ell((9.5, 55, 0), (1.6, 2.6, 3.2)), "torso", C["fire_y"], glow=0.9)
    hx = 2 * 0.6
    f.fill(f.seg((hx, 88, 0), (hx - 3, 94, 2), 1.0), "head", C["wood_d"])
    f.fill(f.ell((hx - 3, 95, 2), (1.8, 1.8, 1.8)), "head", C["fire_y"], glow=0.9)
    for y in (44, 47):
        f.fill(f.ell((0, y, 0), (5.5, 1.3, 8.4)), "hips", C["paper_d"])
    return f


def skel_mage2():
    """幽魂术士：紫色尖兜帽 + 拖地的破法袍，眼睛紫光。顶视：紫色尖帽"""
    f = _skeleton("skel_mage2", "本作自制 · 幽魂术士", head="hood", shoulder="none", rag=C["purple"], rag_d=C["purple_d"], hunch=3, eye=C["eye_v"])
    hx = 3 * 0.6
    f.fill(f.cone(hx - 1, 0, 6, 89, 1, 104) | f.seg((hx - 1, 103, 0), (hx - 6, 107, 0), 1.2, 0.6), "head", C["purple"])
    robe = f.cone(0, 0, 9, 47, 13.5, 8, squash=1.2) & ~f.cone(0, 0, 6.5, 47, 11, 8, squash=1.2)
    robe &= f.Y > jag(f, 30, 22)
    robe &= ~(f.side("x", ">", 3) & (np.abs(f.Z) < 4))
    f.fill(robe, "hips", C["purple"])
    f.paint(robe & f.side("y", "<", 16), C["purple_d"], part="hips")
    f.fill(f.cyl(0, 0, 9.5, 44, 47, rz=11), "hips", C["brass_d"])
    return f


def skel_sporer():
    """瘴菇骨：头上顶一朵大毒菇（红伞白点，伞底发绿光），肩上也冒小菇。顶视：一把红伞"""
    f = _skeleton("skel_sporer", "本作自制 · 瘴菇骨", shoulder="none", rag="#4a4a2a", rag_d="#2e2e1a", hunch=5, eye=C["eye_g"])
    hx = 5 * 0.6
    cap = f.ell((hx, 92, 0), (14, 6.5, 14)) & f.side("y", ">", 89)
    f.fill(cap, "head", "#a8402c")
    rr = (f.X - hx) ** 2 + f.Z ** 2
    for (sx, sz, sr) in ((4, 3, 2.6), (-5, 5, 2.2), (0, -6, 2.8), (-4, -2, 1.8), (7, -4, 2.0), (-8, -6, 1.6), (2, 9, 1.8)):
        f.paint(cap & f.ell((hx + sx, 97, sz), (sr, 4, sr)), "#f2e6c8", part="head")
    f.fill(f.cyl(hx, 0, 13.5, 88.5, 89.5) & (rr > 16), "head", C["eye_g"], glow=0.5)
    f.fill(f.cyl(hx, 0, 3.5, 84, 90), "head", "#e8e0c0")
    for s, sd in ((1, "f"), (-1, "b")):
        f.fill(f.ell((0, 72, 13 * s), (4, 2.2, 4)) & f.side("y", ">", 71), "arm_u_" + sd, "#a8402c")
        f.fill(f.cyl(0, 13 * s, 1.4, 67, 72), "arm_u_" + sd, "#e8e0c0")
    return f


def skel_coffin():
    """抬棺骨：肩上横扛一根抬棺木杠，草绳头箍，粗麻破布。顶视：一根横木"""
    f = _skeleton("skel_coffin", "本作自制 · 抬棺骨", shoulder="none", rag="#8a7a52", rag_d="#5a4e32", hunch=4)
    f.fill(f.box(-6, -1, 68, 73, -24, 24), "torso", C["wood"])
    f.paint(f.box(-7, 0, 72, 73, -25, 25), C["wood_l"], part="torso")
    for z in (-21, 21):
        f.fill(f.box(-7, 0, 66, 74, z - 1, z + 1), "torso", "#b8a070")
    hx = 4 * 0.6
    f.fill(f.cyl(hx + 1.5, 0, 9.8, 84, 86.5), "head", "#b8a070")
    return f


def skel_bellmonk():
    """铜钟僧：光头骷髅 + 橘黄袈裟斜披 + 一挂大念珠。顶视：白头 + 一大片橘黄"""
    f = _skeleton("skel_bellmonk", "本作自制 · 铜钟僧", shoulder="none", rag=None, hunch=2)
    sash = f.ell((1, 57, 0), (8.6, 13, 12.2)) & ~f.ell((1, 57, 0), (6.0, 10.5, 9.8)) & ((f.Y - 56) > -f.Z * 1.1 - 4)
    f.fill(sash, "torso", C["saffron"])
    f.paint(sash & ((np.floor(f.Y) % 5) == 0), C["saffron_d"], part="torso")
    f.fill(f.ell((0, 66, -8), (8, 5, 7)) & f.side("y", ">", 62), "torso", C["saffron"])
    robe = f.cone(0, 0, 9, 47, 12.5, 14, squash=1.2) & ~f.cone(0, 0, 6.5, 47, 10, 14, squash=1.2)
    robe &= ~(f.side("x", ">", 3) & (np.abs(f.Z) < 4) & f.side("y", "<", 40))
    f.fill(robe, "hips", C["maroon"])
    f.paint(robe & f.side("y", "<", 18), C["maroon_d"], part="hips")
    ang = np.arctan2(f.Z, f.X - 1)
    beads = (np.abs(np.sqrt((f.X - 1) ** 2 + f.Z ** 2) - 9.5) < 1.6) & (np.abs(f.Y - (66 - 6 * np.cos(ang).clip(0))) < 1.6)
    f.fill(beads, "torso", C["wood_d"])
    f.paint(beads & ((np.floor(ang * 6) % 2) == 0), C["brass"], part="torso")
    return f


def skel_drowned():
    """水骨：青灰泡发的骨头，挂着水草，眼睛青光。顶视：青白头 + 垂下来的暗绿水草"""
    f = _skeleton("skel_drowned", "本作自制 · 水骨", shoulder="none", rag="#2c4a3e", rag_d="#1a2e26", hunch=5, eye=C["eye_c"],
                  bones=("#8fbcb6", "#5a8884", "#b4dcd6"))
    hx = 5 * 0.6
    # 披一身水草（暗绿一大片盖住肩背），身上挂着发青光的水珠
    shawl = f.ell((-1, 63, 0), (9.5, 8, 14)) & f.side("y", ">", 54)
    f.fill(shawl, "torso", "#2f5a44")
    f.paint(shawl & ((np.floor(f.Z) % 3) == 0), "#3f7458", part="torso")
    for (x, y, z) in ((4, 52, 8), (5, 48, -7), (3, 40, 4), (-2, 30, -5), (6, 58, -3)):
        f.fill(f.ell((x, y, z), (1.2, 1.6, 1.2)), "torso" if y > 46 else "hips", C["eye_c"], glow=0.6)
    for z, x, L in ((-6, -3, 16), (-2, -6, 20), (3, -5, 14), (7, -1, 12), (0, 2, 10)):
        f.fill(f.seg((hx + x, 88, z), (hx + x - 2, 88 - L, z * 1.15), 1.4, 0.8), "head", "#2f5a44")
    for s, sd in ((1, "f"), (-1, "b")):
        f.fill(f.seg((0, 68, 13 * s), (-1, 54, 14 * s), 1.6, 0.8), "arm_u_" + sd, "#2f5a44")
    f.paint(f.side("y", ">", 0) & ((np.floor(f.X * 0.7) * 7 + np.floor(f.Y * 0.7) * 3 + np.floor(f.Z * 0.7)) % 23 == 0), "#4c6a62", part="torso")
    return f


def skel_chainmonk():
    """灯奴僧：深蓝僧袍，铁链缠身，腰上吊一盏青灯。顶视：白头 + 灰链 + 一点青光"""
    f = _skeleton("skel_chainmonk", "本作自制 · 灯奴僧", shoulder="none", rag=None, hunch=3, eye=C["eye_c"])
    robe = f.cone(0, 0, 9, 47, 13, 12, squash=1.2) & ~f.cone(0, 0, 6.5, 47, 10.5, 12, squash=1.2)
    robe &= ~(f.side("x", ">", 3) & (np.abs(f.Z) < 4) & f.side("y", "<", 40))
    f.fill(robe, "hips", C["navy"])
    f.paint(robe & f.side("y", "<", 16), C["navy_d"], part="hips")
    f.fill(f.ell((0, 66, 0), (8, 5, 13)) & f.side("y", ">", 62), "torso", C["navy"])
    for k in range(3):
        ch = (np.abs((f.Y - (52 + k * 5)) - f.Z * 0.5) < 1.3) & f.ell((1.5, 57, 0), (9.2, 13, 12.8)) & ~f.ell((1.5, 57, 0), (7.6, 11.5, 11))
        f.fill(ch, "torso", C["iron"])
        f.paint(ch & ((np.floor(f.Z) % 3) == 0), C["iron_l"], part="torso")
    f.fill(f.seg((6, 44, -8), (8, 36, -10), 0.7), "hips", C["iron_d"])
    f.fill(f.ell((8, 33, -10), (2.6, 3.4, 2.6)), "hips", C["eye_c"], glow=0.5)
    return f


def skel_flame():
    """披火骨：烧焦的黑骨头，骨缝里透火，头顶一簇火焰。顶视：一团火"""
    f = _skeleton("skel_flame", "本作自制 · 披火骨", shoulder="none", rag=None, hunch=3, eye=C["eye_y"],
                  bones=("#5c4a40", "#3a2e28", "#7a6658"))
    cage_c = (1.5, 58, 0)
    f.fill(f.ell(cage_c, (5.3, 8.0, 9.0)) & f.side("y", ">", 49), "torso", C["fire"], glow=0.5)
    hx = 3 * 0.6
    for (x, z, h, r) in ((0, 0, 104, 4.5), (-3, 4, 99, 3.2), (-2, -4, 100, 3.4), (3, 2, 97, 2.6), (-6, 0, 98, 3)):
        fl = f.cone(hx + x, z, r, 86, 0.4, h)
        f.fill(fl, "head", C["fire"], glow=0.6)
        f.paint(fl & f.side("y", ">", h - (h - 86) * 0.45), C["fire_y"], part="head", glow=0.8)
    f.paint((f.part >= 0) & ((np.floor(f.X / 3) * 13 + np.floor(f.Y / 3) * 7 + np.floor(f.Z / 3) * 3) % 17 == 0) & (f.glow == 0), C["fire_r"], glow=0.4)
    return f


def skel_lampkid():
    """引魂灯童：小骸骨穿白纸衣，戴黑瓜皮帽，眼睛青光（手里那盏灯是另挂的）。顶视：黑帽 + 白衣"""
    f = _skeleton("skel_lampkid", "本作自制 · 引魂灯童", shoulder="none", rag=None, hunch=2, eye=C["eye_c"])
    robe = f.cone(0, 0, 9.5, 66, 12.5, 22, squash=1.15) & ~f.cone(0, 0, 7, 66, 10, 22, squash=1.15)
    robe &= f.Y > jag(f, 30, 10)
    f.fill(robe & f.side("y", "<", 47), "hips", C["paper"])
    f.fill(robe & f.side("y", ">", 47), "torso", C["paper"])
    f.paint(robe & f.side("y", "<", 28), C["paper_d"], part="hips")
    hx = 2 * 0.6
    f.fill(f.ell((hx + 1, 84, 0), (9.6, 7, 9.2)) & f.side("y", ">", 84), "head", C["lacq"])
    f.fill(f.ell((hx + 1, 91, 0), (1.6, 1.6, 1.6)), "head", C["red"])
    return f


def skel_eel():
    """井鳗骨：弓得很低，脊背到头顶一道青色鱼鳍。顶视：一条青鳍"""
    f = _skeleton("skel_eel", "本作自制 · 井鳗骨", shoulder="none", rag=None, hunch=9, eye=C["eye_c"],
                  bones=("#9cc8bc", "#628e84", "#c4e6dc"))
    for y in range(44, 92, 2):
        h = 8 + 5 * np.sin((y - 44) / 48 * np.pi)
        x = -4 + (y - 44) * 0.12
        fin = f.box(x - h, x - 1, y, y + 2, -1.2, 1.2)
        f.fill(fin, "torso" if y < 70 else "head", "#3a9a90")
        f.paint(fin & f.side("x", "<", x - h + 2), C["eye_c"], part="torso" if y < 70 else "head", glow=0.45)   # 鳍边发青光
    return f


def lamp_node():
    """护体灯：长明帝身边的石灯笼，短腿，灯心发金光。顶视：方灯顶"""
    J = std_joints(neck=58, sh_y=50, sh_z=11, hip_y=24, leg_z=6, knee_y=13, ankle_y=4, elbow_y=44, wrist_y=40)
    f = Forge("lamp_node", J, "本作自制 · 护体灯")
    st, std_, stl = "#9a958a", "#66625a", "#bdb8ac"
    for s, sd in ((1, "f"), (-1, "b")):
        f.fill(f.seg((0, 23, 6 * s), (0, 13, 6 * s), 3.5), "leg_u_" + sd, std_)
        f.fill(f.box(-4, 6, 0, 13, 6 * s - 3.5, 6 * s + 3.5), "leg_l_" + sd, st)
        f.fill(f.seg((0, 50, 11 * s), (0, 44, 11 * s), 2.2), "arm_u_" + sd, std_)
        f.fill(f.seg((0, 44, 11 * s), (0, 40, 11 * s), 2.0), "arm_l_" + sd, std_)
    f.fill(f.box(-9, 9, 22, 30, -9, 9), "hips", std_)
    f.fill(f.box(-7, 7, 30, 46, -7, 7), "torso", st)
    f.fill(f.box(-10, 10, 46, 50, -10, 10), "torso", stl)
    f.fill(f.box(-8, 8, 50, 62, -8, 8), "head", st)
    f.carve(f.box(-9, 9, 52, 60, -5, 5) | f.box(-5, 5, 52, 60, -9, 9), "head")
    f.fill(f.box(-5, 5, 52, 60, -5, 5), "head", C["gold_l"], glow=0.7)
    roof = f.cone(0, 0, 15, 62, 2, 72) & (np.abs(f.X) < 15) & (np.abs(f.Z) < 15)
    f.fill(roof, "head", std_)
    f.paint(roof & f.side("y", "<", 64), stl, part="head")
    f.fill(f.cone(0, 0, 2.5, 72, 0.5, 78), "head", C["gold"])
    return f


# ======================= 第二幕 · 铜俑、烛国、活人 =======================

def bronze_twin():
    """殉灯俑：成对的铜俑，铜绿斑驳，发髻、札甲都是铜的，眼里有火。顶视：铜发髻 + 铜肩"""
    B, Bd, Bl = C["bronze"], C["bronze_d"], C["bronze_l"]
    f = _man("bronze_twin", "殉灯俑", thigh=Bd, shin=B, boot=Bd, sleeve=B, fore=B, hand=Bl, body=B,
             sk=B, sk_dark=Bd, sk_kind="flaps", belt_col=Bd, skin=Bl, hair=Bd, eyes=C["eye_o"], eye_glow=0.6)
    chest_plate(f, B, Bd, Bl)
    pauldrons_round(f, B, Bd, Bl, r=(6.5, 4.5, 6.5))
    topknot(f, col=Bd, tie=B)
    f.paint((f.part >= 0) & ((np.floor(f.X / 5) * 7 + np.floor(f.Y / 4) * 3 + np.floor(f.Z / 5) * 5) % 9 == 0) & (f.glow == 0), C["patina"])
    return f


def bronze_oiler():
    """泼油俑：胖铜俑，背着一口大油罐，罐口冒火。顶视：一口黑罐 + 一圈火"""
    B, Bd, Bl = C["bronze"], C["bronze_d"], C["bronze_l"]
    f = _man("bronze_oiler", "泼油俑", heavy=True, thigh=Bd, shin=B, boot=Bd, sleeve=B, hand=Bl, body=B, fat=3,
             sk=B, sk_dark=Bd, belt_col=Bd, skin=Bl, hair=Bd, eyes=C["eye_o"], eye_glow=0.6, bald=True)
    f.fill(f.ell((-14, 62, 0), (8, 12, 9)), "torso", "#2c2420")
    f.fill(f.cyl(-14, 0, 5, 72, 76), "torso", "#2c2420")
    f.fill(f.cyl(-14, 0, 4.2, 75, 77), "torso", C["fire"], glow=0.7)
    f.fill(f.cone(-14, 0, 3.5, 77, 0.5, 84), "torso", C["fire_y"], glow=0.8)
    f.fill(f.box(-10, 9, 60, 63, -13, 13) & f.ell((-3, 61, 0), (14, 4, 14)) & ~f.ell((-3, 61, 0), (12, 2.5, 12)), "torso", C["wood_d"])
    f.paint((f.part >= 0) & ((np.floor(f.X / 5) * 7 + np.floor(f.Y / 4) * 3 + np.floor(f.Z / 5) * 5) % 9 == 0) & (f.glow == 0), C["patina"])
    return f


def zhu_armored():
    """烛国甲士：一身黄铜重甲，盔顶一簇铜焰（焰尖发光），面甲只露一道发光的眼缝。顶视：铜盔 + 火苗盔缨"""
    B, Bd, Bl = C["brass"], C["brass_d"], C["brass_l"]
    f = _man("zhu_armored", "烛国甲士", heavy=True, thigh=Bd, shin=B, boot=C["lacq"], greave=Bl, sleeve=Bd, fore=B, hand=Bd,
             body=Bd, sk=B, sk_dark=Bd, sk_kind="flaps", belt_col=C["lacq"], buckle=Bl, skin=Bd, hair=Bd)
    chest_plate(f, B, Bd, Bl)
    pauldrons_round(f, B, Bd, Bl, z=15, r=(8, 6, 8), spikes=Bl)
    helm_round(f, B, Bd, r=(9.5, 9.5, 9), rim=11, nose=False)
    f.fill(f.box(5.5, 9.5, 72, 86, -7, 7) & f.ell((1, 80, 0), (9, 10, 8.6)), "head", Bd)
    f.fill(f.box(8.5, 10, 79, 81, -5, 5), "head", C["fire"], glow=0.7)
    for (x, z, h) in ((0, 0, 104), (-3, 0, 99), (2.5, 0, 98)):
        fl = f.cone(x, z, 3.2, 90, 0.4, h)
        f.fill(fl, "head", B)
        f.paint(fl & f.side("y", ">", h - 5), C["fire"], part="head", glow=0.6)
    return f


def red_armor():
    """赤甲武士：朱漆札甲 + 黑面具 + 金色月牙盔饰，眼睛红光。顶视：红肩 + 一弯金月"""
    R, Rd, Rl = "#b0302a", "#6e1a16", "#d85048"
    f = _man("red_armor", "赤甲武士", heavy=True, thigh=C["lacq"], shin=R, boot=C["lacq"], sleeve=C["lacq"], fore=R, hand=C["lacq"],
             body=C["lacq"], sk=R, sk_dark=Rd, sk_kind="flaps", belt_col=C["gold_d"], skin=C["lacq"], hair=C["lacq"], eyes=C["eye"], eye_glow=0.6)
    chest_plate(f, R, Rd, Rl)
    pauldrons_square(f, R, Rd, Rl, edge=C["gold_d"], zin=9, zout=22)
    helm_round(f, C["lacq"], C["lacq_l"], r=(9.5, 8.5, 9), rim=12, nose=False)
    moon = (np.abs(np.sqrt((f.Z) ** 2 + (f.Y - 86) ** 2) - 11) < 1.6) & f.side("y", ">", 90) & (np.abs(f.X - 7) < 1)
    f.fill(moon, "head", C["gold"])
    return f


def digger():
    """挖掘队头领：粗壮矿工，皮围裙、卷袖露胳膊、大胡子，布帽前一盏发亮的矿灯，背一捆镐。顶视：矿灯黄光 + 皮背包"""
    f = _man("digger", "挖掘队头领", heavy=True, thigh=C["leather_d"], shin=C["grey_d"], boot=C["boot"], wraps=C["boot_l"],
             sleeve="#7a6a58", fore=C["skin_d"], hand=C["skin_d"], body="#7a6a58", fat=2,
             sk=C["leather"], sk_dark=C["leather_d"], belt_col=C["leather_d"], buckle=C["iron_l"], beard="#4a3020")
    f.fill(f.box(5, 10, 34, 62, -7, 7) & f.ell((3, 50, 0), (8.5, 16, 10)), "torso", C["leather"])
    f.fill(f.ell((0.5, 85, 0), (8.2, 4.5, 8.2)) & f.side("y", ">", 84), "head", "#5a4a38")
    f.fill(f.box(7, 10, 84, 88, -2, 2), "head", C["iron_d"])
    f.fill(f.box(9, 11, 85, 87, -1.2, 1.2), "head", C["fire_y"], glow=0.8)
    backpack(f, C["leather"], C["leather_d"], strap=C["leather_d"], h=74, w=9)
    f.fill(f.seg((-12, 70, -6), (-12, 92, -9), 1.2) | f.seg((-12, 92, -14), (-12, 92, -3), 1.4), "torso", C["iron"])
    return f


def grey_guard():
    """灰衣盾兵：比刀手更厚，圆盔带护颈 + 红缨，方肩甲。顶视：圆盔 + 红缨 + 大方肩"""
    f = _man("grey_guard", "灰衣盾兵", heavy=True, thigh=C["grey_d"], shin=C["steel"], boot=C["lacq"], greave=C["steel_l"],
             sleeve=C["grey"], fore=C["steel_d"], hand=C["grey_d"], body=C["grey"], sk=C["steel"], sk_dark=C["steel_d"], sk_kind="flaps",
             belt_col=C["lacq"], buckle=C["brass"])
    chest_plate(f, C["steel"], C["steel_d"], C["steel_l"])
    pauldrons_square(f, C["steel"], C["steel_d"], C["steel_l"], edge=C["lacq"], zin=9, zout=22)
    mask_lower(f, C["grey"])
    helm_round(f, C["steel"], C["steel_d"], crest="tassel")
    f.fill(f.cone(0, 0, 10.5, 72, 9.5, 82) & ~f.cone(0, 0, 8.5, 72, 7.5, 82) & f.side("x", "<", 2), "head", C["steel_d"])
    for s in (1, -1):
        f.fill(f.cyl(0, 15 * s, 5.2, 56, 60), "arm_u_" + ("f" if s > 0 else "b"), C["red"])
    return f


def grey_bow():
    """灰衣弩手：轻装，灰布小斗笠 + 红头巾 + 背箭筒。顶视：灰斗笠 + 箭羽一点红"""
    f = _man("grey_bow", "灰衣弩手", thigh=C["grey_d"], shin=C["grey_l"], boot=C["lacq"], wraps=C["grey_d"],
             sleeve=C["grey"], fore=C["grey_l"], hand=C["skin"], bracer=C["leather_d"], body=C["grey"], collar=(C["grey_l"], C["grey_d"]),
             sk=C["grey"], sk_dark=C["grey_d"], belt_col=C["leather_d"], buckle=C["brass"])
    f.fill(f.box(-8.5, 8.5, 50, 64, -9, 9) & f.ell((0, 57, 0), (9, 12, 11.6)), "torso", C["leather"])
    mask_lower(f, C["grey_d"])
    # 弩手：深绿兜帽 + 深绿短斗篷（灰衣五兵种里唯一的绿色，远看就知道是放冷箭的）
    hood(f, "#3e5a44", pointed=False)
    cape(f, "#3e5a44", "#2a3e2e", top=68, bottom=40, w=12, back=-7)
    quiver(f)
    for s in (1, -1):
        f.fill(f.cyl(0, 14 * s, 5.0, 56, 59), "arm_u_" + ("f" if s > 0 else "b"), C["red"])
    return f


def grey_spear():
    """灰衣枪兵：尖顶盔 + 红缨，札甲，绑腿。顶视：尖盔一点红"""
    f = _man("grey_spear", "灰衣枪兵", thigh=C["grey_d"], shin=C["grey_l"], boot=C["lacq"], wraps=C["grey_d"],
             sleeve=C["grey"], fore=C["steel_d"], hand=C["grey_d"], body=C["grey"], sk=C["steel"], sk_dark=C["steel_d"], sk_kind="flaps",
             belt_col=C["lacq"], buckle=C["brass"])
    chest_plate(f, C["steel"], C["steel_d"], C["steel_l"])
    pauldrons_round(f, C["steel"], C["steel_d"], C["steel_l"], r=(7, 4.5, 6.5))
    mask_lower(f, C["grey"])
    helm_round(f, C["steel"], C["steel_d"], r=(8.6, 7.5, 8.2), crest="spike", crest_col=C["steel_l"])
    f.fill(f.seg((0, 95, 0), (-5, 99, 0), 2.4, 3.0), "head", C["red"])
    # 枪兵：白布十字背带 + 背后一面小号旗（三角红旗，比旗手的小），顶视多一个尖角
    for sgn in (1, -1):
        f.fill((np.abs((f.Y - 57) - sgn * f.Z * 0.9) < 1.5) & f.ell((0, 57, 0), (9.4, 13, 12.4)) & ~f.ell((0, 57, 0), (7.6, 11.4, 10.6)), "torso", C["cream"])
    f.fill(f.seg((-9, 50, 0), (-10, 92, 0), 0.9), "torso", C["wood_d"])
    tri = f.box(-10.6, -9.4, 76, 92, 0, 14) & ((f.Z) < (f.Y - 76) * 0.9)
    f.fill(tri, "torso", C["red"])
    return f


def grey_flag():
    """灰衣旗手：背一面红边灰旗（顶视最大的一块颜色），小圆盔。"""
    f = _man("grey_flag", "灰衣旗手", thigh=C["grey_d"], shin=C["grey_l"], boot=C["lacq"], wraps=C["grey_d"],
             sleeve=C["grey"], fore=C["grey_l"], body=C["grey"], collar=(C["grey_l"], C["grey_d"]), sk=C["grey"], sk_dark=C["grey_d"],
             belt_col=C["lacq"], buckle=C["brass"])
    helm_round(f, C["steel"], C["steel_d"], r=(8.4, 6.5, 8), nose=False)
    back_flag(f, C["red"], cloth2=C["grey_l"])
    for s in (1, -1):
        f.fill(f.cyl(0, 14 * s, 5.0, 56, 59), "arm_u_" + ("f" if s > 0 else "b"), C["red"])
    return f


def grey_officer():
    """灰衣军官：黑钢札甲 + 红披风 + 大红翎盔，铜边方肩。顶视：红翎 + 红披风"""
    f = _man("grey_officer", "灰衣军官", heavy=True, thigh=C["lacq"], shin=C["steel_d"], boot=C["lacq"], greave=C["steel"],
             sleeve=C["lacq_l"], fore=C["steel_d"], hand=C["lacq"], body=C["lacq_l"], sk=C["steel_d"], sk_dark=C["lacq"], sk_kind="flaps",
             belt_col=C["brass_d"], buckle=C["brass_l"], beard=C["hair"])
    chest_plate(f, C["steel_d"], C["lacq"], C["steel"])
    cape(f, C["red"], C["red_d"], top=68, bottom=24, w=13, back=-8)
    pauldrons_square(f, C["steel_d"], C["lacq"], C["steel"], edge=C["brass"], zin=9, zout=23)
    helm_round(f, C["steel_d"], C["lacq"], crest="plume", crest_col=C["red"])
    return f


def aqi():
    """阿七：灰衣营逃兵。敞怀的旧灰衣（臂章撕了）、红头巾长飘带、乱发、缠绷带的左臂。顶视：乱发 + 红头巾"""
    f = _man("aqi", "阿七", thigh=C["char"], shin=C["grey_l"], boot=C["boot"], wraps=C["grey_d"], sleeve=C["grey"], fore=C["skin"],
             body=C["grey"], collar=(C["skin"], C["grey_d"]), sk=C["grey"], sk_dark=C["grey_d"], belt_col=C["leather_d"], buckle=C["brass"])
    for (x, z, h) in ((0, 0, 93), (-3, 4, 91), (-3, -4, 91), (2, 3, 90), (2, -3, 90), (-6, 0, 90)):
        f.fill(f.cone(x, z, 3.5, 85, 0.5, h), "head", C["hair"])
    bandana(f, C["red"])
    f.paint(f.box(-9, 9, 40, 50, -20, -10), C["paper"], part="arm_l_b")
    f.fill(f.cyl(0, -14, 4.6, 54, 58), "arm_u_b", C["paper_d"])
    f.fill(f.box(-6, 6, 44, 50, 9, 13) & f.ell((0, 47, 11), (6, 4, 3)), "torso", C["leather"])
    return f


# ======================= 第三幕 =======================

def zhu_lampman():
    """灯兵：靛蓝号衣 + 圆盔，背一根竹竿挑着灯。顶视：高处一盏亮灯"""
    f = _man("zhu_lampman", "灯兵", thigh=C["navy_d"], shin=C["grey_l"], boot=C["lacq"], wraps=C["navy_d"], sleeve=C["navy"],
             body=C["navy"], collar=(C["paper"], C["navy_d"]), sk=C["navy"], sk_dark=C["navy_d"], belt_col=C["lacq"], buckle=C["brass"])
    f.fill(f.box(5, 9, 50, 62, -5, 5), "torso", C["paper"])
    f.fill(f.box(8.5, 9.5, 53, 59, -2, 2), "torso", C["red"])
    helm_round(f, C["lacq_l"], C["lacq"], r=(8.4, 6.5, 8), nose=False)
    back_pole_lantern(f, C["fire_y"])
    return f


def scarecrow():
    """稻草人：麻袋头缝着两只发光的眼，破草帽，袖口、领口支棱着稻草。顶视：破草帽"""
    S, Sd, Sl = C["straw"], C["straw_d"], C["straw_l"]
    sack = "#b59b6a"
    f = _man("scarecrow", "稻草人", thigh="#6a5a3a", shin=S, boot=Sd, sleeve="#7a4a3a", fore=S, hand=Sl, body="#7a4a3a",
             sk=None, belt_col="#8a6a3a", skin=sack, hair=sack, eyes=C["eye_o"], eye_glow=0.7)
    f.paint((f.part == 0) & ((np.floor(f.X / 3) + np.floor(f.Y / 3) + np.floor(f.Z / 3)) % 4 == 0), "#5a6a3a")
    f.carve(f.box(7, 10, 74, 76, -4, 4), "head")
    f.fill(f.box(6, 9, 74, 76, -4, 4), "head", C["gap"])
    for z in (-3, -1, 1, 3):
        f.fill(f.box(7, 10, 73, 77, z - 0.4, z + 0.4), "head", "#3a2a1a")
    hat = f.cone(0.5, 0, 16, 86, 6, 92) | f.cyl(0.5, 0, 6, 86, 96)
    hat &= ~((np.floor(f.X / 3) * 5 + np.floor(f.Z / 3)) % 7 == 0)        # 破洞多一点
    hat &= ~((f.X > 6) & (f.Z > 4))                                       # 帽檐缺一大块
    f.fill(hat, "head", "#5a4630")                                        # 发黑的旧草帽（主角的斗笠是亮黄，别撞）
    f.paint(hat & ((np.floor(f.X) + np.floor(f.Z)) % 4 == 0), "#3e3020", part="head")
    for s, sd in ((1, "f"), (-1, "b")):
        for k in range(5):
            f.fill(f.seg((0, 37, 14 * s), (np.cos(k * 1.3) * 4, 30, 14 * s + np.sin(k * 1.3) * 4), 0.8), "arm_l_" + sd, Sl)
    for k in range(6):
        f.fill(f.seg((0, 46, 0), (np.cos(k) * 11, 38, np.sin(k) * 13), 0.9), "hips", Sl)
    return f


def zhu_lampguard():
    """镇灯卫：暗铜札甲、高顶盔插黄翎、胸前一盏灯纹（发光）。顶视：黄翎 + 铜肩"""
    B, Bd, Bl = "#8a6a3e", "#55402a", "#b08a54"
    f = _man("zhu_lampguard", "镇灯卫", heavy=True, thigh=Bd, shin=B, boot=C["lacq"], greave=Bl, sleeve=C["navy"], fore=B, hand=Bd,
             body=C["navy"], sk=B, sk_dark=Bd, sk_kind="flaps", belt_col=C["lacq"], buckle=C["brass"])
    chest_plate(f, B, Bd, Bl)
    f.fill(f.ell((9, 59, 0), (1.2, 3.2, 2.4)), "torso", C["fire_y"], glow=0.7)
    pauldrons_round(f, B, Bd, Bl, z=15, r=(7.5, 5, 7.5))
    mask_lower(f, C["navy_d"])
    helm_round(f, B, Bd, r=(8.6, 10, 8.4), crest="plume", crest_col=C["fire_y"])
    return f


def torcher():
    """纵火手：暗红兜帽 + 蒙面，腰挂一排火罐（发光），一只手里攥着燃着的罐。顶视：红兜帽 + 一圈火点"""
    f = _man("torcher", "纵火手", thigh=C["char"], shin=C["rag"], boot=C["boot"], wraps=C["rag_d"], sleeve="#6a2a20",
             body="#6a2a20", sk="#6a2a20", sk_dark="#3e1610", belt_col=C["leather_d"])
    hood(f, "#7a3024", light="#9a4030")
    mask_lower(f, C["char"])
    for k, z in enumerate((-10, -5, 5, 10)):
        f.fill(f.ell((5 - abs(z) * 0.3, 42, z), (2.4, 3.2, 2.4)), "torso", "#3a2a22")
        f.fill(f.ell((5 - abs(z) * 0.3, 45.5, z), (1.4, 1.2, 1.4)), "torso", C["fire"], glow=0.6)
    f.fill(f.ell((1.5, 24, 14), (3.2, 4.0, 3.2)), "arm_l_f", "#3a2a22")
    f.fill(f.cone(1.5, 14, 2, 27, 0.4, 33), "arm_l_f", C["fire_y"], glow=0.8)
    return f


def courier():
    """驿卒：红边小斗笠、红坎肩、斜挎信包、绑腿，跑得快的样子。顶视：小斗笠 + 红边"""
    f = _man("courier", "驿卒", thigh=C["navy_d"], shin=C["paper"], boot=C["boot"], wraps=C["paper_d"], sleeve=C["navy"],
             body=C["navy"], sk=C["navy"], sk_dark=C["navy_d"], belt_col=C["red_d"])
    f.fill(f.box(-8.6, 8.6, 50, 66, -10, 10) & f.ell((0, 58, 0), (9, 12, 11.8)), "torso", C["red"])
    f.paint(f.box(-10, 10, 50, 66, -2, 2) & f.side("x", ">", 6), C["navy"], part="torso")
    hat_straw(f, r=13, h=9, col="#2e2a30", dark="#1e1b20", light="#46404a", band=C["red"])   # 黑漆驿笠 + 红边（主角是黄斗笠）
    f.fill(f.box(-6, 6, 38, 48, 10, 15), "torso", C["leather"])
    f.fill((np.abs((f.Y - 56) + f.Z * 0.85) < 1.4) & f.ell((0, 57, 0), (9.2, 13, 12.2)) & ~f.ell((0, 57, 0), (7.4, 11.4, 10.4)), "torso", C["leather_d"])
    return f


def lancer():
    """冲骑：钢蓝札甲 + 蓝披风 + 翎盔，壮。顶视：翎 + 披风"""
    f = _man("lancer", "冲骑", heavy=True, thigh=C["navy_d"], shin=C["steel"], boot=C["lacq"], greave=C["steel_l"], sleeve=C["navy"],
             fore=C["steel"], hand=C["steel_d"], body=C["navy"], sk=C["steel"], sk_dark=C["steel_d"], sk_kind="flaps", belt_col=C["lacq"], buckle=C["brass"])
    chest_plate(f, C["steel"], C["steel_d"], C["steel_l"])
    cape(f, C["navy_l"], C["navy_d"], bottom=26, w=13, back=-8)
    pauldrons_round(f, C["steel"], C["steel_d"], C["steel_l"], z=15, r=(8, 5.5, 7.5))
    mask_lower(f, C["steel_d"])
    helm_round(f, C["steel"], C["steel_d"], crest="plume", crest_col=C["paper"])
    return f


def wardbell():
    """镇魂铃：黄道袍黑边、前襟贴符、宽袖，黑色高方帽。顶视：黑方帽 + 黄袍"""
    Y, Yd = "#d0a838", "#8e7020"
    f = _man("wardbell", "镇魂铃", thigh=C["char"], shin=C["paper"], boot=C["lacq"], sleeve=Y, body=Y, collar=(C["paper"], C["lacq"]),
             sk=Y, sk_dark=C["lacq"], sk_bottom=12, belt_col=C["lacq"], wide=4.5, beard=C["hair_g"])
    f.fill(f.box(-6, 6, 86, 98, -6, 6), "head", C["lacq"])
    f.fill(f.box(-7, 7, 96, 98, -7, 7), "head", C["lacq_l"])
    for z in (-5, 5):
        f.fill(f.box(8.2, 9.2, 44, 58, z - 1.6, z + 1.6), "torso", C["paper"])
        f.fill(f.box(9, 9.6, 46, 56, z - 0.4, z + 0.4), "torso", C["red"])
    return f


def goldguard():
    """金吾卫：金甲、带翼金盔、红披风，块头大。顶视：金翼 + 红披风"""
    G, Gd, Gl = C["gold"], C["gold_d"], C["gold_l"]
    f = _man("goldguard", "金吾卫", heavy=True, thigh=C["red_d"], shin=G, boot=C["lacq"], greave=Gl, sleeve=C["red"], fore=G, hand=Gd,
             body=C["red"], sk=G, sk_dark=Gd, sk_kind="flaps", belt_col=C["lacq"], buckle=Gl)
    chest_plate(f, G, Gd, Gl)
    cape(f, C["red"], C["red_d"], bottom=24, w=13, back=-8)
    pauldrons_round(f, G, Gd, Gl, z=15, r=(8.5, 6, 8))
    mask_lower(f, Gd)
    helm_round(f, G, Gd, r=(9.2, 8.5, 8.8), crest="tassel", crest_col=C["red"])
    for s in (1, -1):
        f.fill(f.seg((-1, 86, 8 * s), (-4, 94, 15 * s), 1.6, 0.8) | f.seg((-3, 86, 8 * s), (-7, 92, 14 * s), 1.4, 0.6), "head", Gl)
    return f


def censer():
    """提炉官：乌纱帽 + 绯红宽袖官袍 + 玉带。顶视：帽翅一根横杠"""
    f = _man("censer", "提炉官", thigh=C["char"], shin=C["char"], boot=C["lacq"], sleeve=C["red"], body=C["red"],
             collar=(C["paper"], C["red_d"]), sk=C["red"], sk_dark=C["red_d"], sk_bottom=10, belt_col="#d8e8d0", buckle=C["gold"], wide=4.5)
    f.fill(f.box(7.6, 9.4, 50, 62, -6, 6), "torso", C["gold"])
    f.fill(f.box(8.8, 9.8, 52, 60, -4, 4), "torso", "#3a6a5a")
    hat_official(f)
    return f


def palace_ghost():
    """宫灯魂 / 宫人魂：宫女，大发髻插簪，淡紫长裙、长袖拖地，脸色惨白。顶视：两团发髻"""
    L, Ld = "#c8b8dc", "#8e7aa8"
    f = _man("palace_ghost", "宫人魂", thigh=L, shin=L, boot=Ld, sleeve=L, hand=C["skin_pale"], body=L, collar=(C["paper"], Ld),
             sk=L, sk_dark=Ld, sk_bottom=4, sk_kind="robe", belt_col=Ld, skin=C["skin_pale"], eyes=C["gap"], wide=5.5)
    for s in (1, -1):
        f.fill(f.ell((-1.5, 90, 5 * s), (4, 4, 4)), "head", C["hair"])
    hair_bun(f, top=88, big=True)
    return f


def chief_lu():
    """司主陆长庚：黑袍红里，高冠，长灰须。顶视：黑高冠"""
    f = _man("chief_lu", "司主陆长庚", heavy=True, thigh=C["char"], shin=C["char"], boot=C["lacq"], sleeve=C["lacq_l"], body=C["lacq_l"],
             collar=(C["red"], C["lacq"]), sk=C["lacq_l"], sk_dark=C["red_d"], sk_bottom=8, belt_col=C["red_d"], buckle=C["gold"],
             wide=5.0, beard=C["hair_g"], skin=C["skin_old"])
    tall_hat(f, C["lacq"], band=C["gold"], h=12, r0=6.5, r1=5.5)
    f.fill(f.box(-9, 9, 97, 99, -3, 3), "head", C["gold"])
    return f


def summoner():
    """招魂巫：骨面具 + 插满纸符的高角冠，黑绿袍挂骨串，眼睛绿光。顶视：一对角 + 一圈白纸条"""
    f = _man("summoner", "招魂巫", thigh=C["char"], shin=C["char"], boot=C["boot"], sleeve="#26382c", body="#26382c",
             sk="#26382c", sk_dark="#141e18", sk_bottom=10, belt_col=C["bone_d"], wide=4, skin=C["bone"], eyes=C["eye_g"], eye_glow=0.6)
    f.paint(f.side("x", ">", 1.5) & f.side("y", "<", 86), C["bone"], part="head")
    f.fill(f.cyl(0.5, 0, 9, 85, 89), "head", "#26382c")
    for s in (1, -1):
        f.fill(f.seg((0, 88, 6 * s), (-1, 96, 11 * s), 2.0, 1.4) | f.seg((-1, 96, 11 * s), (-5, 104, 10 * s), 1.4, 0.6), "head", C["bone_l"])
    for k in range(8):
        a = k / 8 * 2 * np.pi
        f.fill(f.box(-0.6, 0.6, 76, 88, -0.6, 0.6) & f.ell((0.5 + np.cos(a) * 9, 82, np.sin(a) * 9), (1.6, 7, 1.6)), "head", C["paper"])
    for k in range(7):
        a = (k - 3) * 0.35
        f.fill(f.ell((np.cos(a) * 9, 63 - abs(k - 3) * 1.5, np.sin(a) * 11), (1.6, 1.6, 1.6)), "torso", C["bone_l"])
    return f


FOES = {
    "skel_crawler": skel_crawler, "skel_assassin": skel_assassin, "skel_charger": skel_charger, "skel_bomber": skel_bomber,
    "skel_mage2": skel_mage2, "skel_sporer": skel_sporer, "skel_coffin": skel_coffin, "skel_bellmonk": skel_bellmonk,
    "skel_drowned": skel_drowned, "skel_chainmonk": skel_chainmonk, "skel_flame": skel_flame, "skel_lampkid": skel_lampkid,
    "skel_eel": skel_eel, "lamp_node": lamp_node,
    "bronze_twin": bronze_twin, "bronze_oiler": bronze_oiler, "zhu_armored": zhu_armored, "red_armor": red_armor, "digger": digger,
    "grey_guard": grey_guard, "grey_bow": grey_bow, "grey_spear": grey_spear, "grey_flag": grey_flag, "grey_officer": grey_officer,
    "aqi": aqi,
    "zhu_lampman": zhu_lampman, "scarecrow": scarecrow, "zhu_lampguard": zhu_lampguard, "torcher": torcher, "courier": courier,
    "lancer": lancer, "wardbell": wardbell, "goldguard": goldguard, "censer": censer, "palace_ghost": palace_ghost,
    "chief_lu": chief_lu, "summoner": summoner,
}
